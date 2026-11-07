import CohesionCore
import CohesionScreens
import UIKit
import UserNotifications
import WidgetKit

/// Receives the APNs token, notification taps and replies typed into a
/// notification, which SwiftUI has no scene-level hooks for, and hands them
/// to the app model.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static let agentMessageCategory = "AGENT_MESSAGE"
    /// The action on an agent's notifications that a reply is typed into.
    static let replyAction = "REPLY"
    /// The reply a notice of a failed one carries, for its tap to put back.
    private static let failedReplyKey = "failedReply"
    /// How long a reply has to get through. The system gives a response
    /// about 30 seconds, and the app must say the reply failed before they end.
    private static let replyDeadline: Duration = .seconds(20)
    /// A passive note that an installed extension has an update; tapping it
    /// just opens the app.
    static let extensionUpdateCategory = "EXTENSION_UPDATE"

    /// This device's registration for agent notifications.
    let push = AppDelegate.sharedPush
    private static let sharedPush = PushRegistration()
    /// Owned here so the delegate can reach it from launch on, and an intent
    /// that launched the app from before it; the app puts it in the environment.
    static let model = AppModel(pairingObserver: sharedPush)
    let model = AppDelegate.model

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set before launch finishes, so a tap that launched the app arrives.
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.agentMessageCategory,
                actions: [
                    // Sent from the background; an agent can act on what it's
                    // told, so a locked device asks for its owner first.
                    UNTextInputNotificationAction(
                        identifier: Self.replyAction,
                        title: "Reply",
                        options: [.authenticationRequired],
                        textInputButtonTitle: "Send",
                        textInputPlaceholder: "Message"
                    ),
                ],
                intentIdentifiers: []
            ),
            UNNotificationCategory(identifier: Self.extensionUpdateCategory, actions: [], intentIdentifiers: []),
        ])
        push.watchLiveActivities { [model] in model.client }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        push.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        push.didFailToRegister(error)
    }

    // MARK: UNUserNotificationCenterDelegate

    // Main-actor isolated, not `nonisolated`: the system hands back its
    // completion handler when these return, and traps one called off main.

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // A chat open on it, in any window, already shows the message; it
        // doesn't show that a reply failed.
        let userInfo = notification.request.content.userInfo
        if userInfo[Self.failedReplyKey] == nil,
           let agentID = Self.agentID(in: userInfo),
           model.shownAgentIDs.contains(agentID) {
            return []
        }
        return [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let agentID = Self.agentID(in: userInfo) else { return }
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            if let reply = userInfo[Self.failedReplyKey] as? String {
                model.failedReplies[agentID] = reply
            }
            model.pendingLink = .agent(agentID)
        case Self.replyAction:
            let text = (response as? UNTextInputNotificationResponse)?.userText
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else { return }
            await reply(text, to: agentID, agentName: userInfo["agentName"] as? String)
        default:
            break
        }
    }

    /// Sends what was typed into the agent's notification, as its chat would,
    /// and marks the conversation read, as opening the chat would. This may
    /// be all the app was launched for, so a reply that can't get through
    /// says so in a notification of its own, which keeps the text.
    private func reply(_ text: String, to agentID: Int, agentName: String?) async {
        // A launch before the device's first unlock couldn't read the pairing.
        model.restorePairing()
        do {
            guard let client = model.client else { throw ReplyError.unpaired }
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    // Also wakes a connection that died while the app was
                    // suspended, which the send itself wouldn't resend on.
                    let latest = try await client.listMessages(of: agentID, limit: 1)
                    try await client.deliver(text, to: agentID, after: latest.last?.id ?? 0)
                    try? await client.markRead(agentID)
                }
                group.addTask {
                    try await Task.sleep(for: Self.replyDeadline)
                    throw URLError(.timedOut)
                }
                defer { group.cancelAll() }
                try await group.next()
            }
            // The Agents widget shows the unread ones.
            WidgetCenter.shared.reloadTimelines(ofKind: "Agents")
        } catch {
            await notifyFailedReply(text, to: agentID, agentName: agentName, because: error)
        }
    }

    /// Says a reply failed and why. A tap opens the agent's chat with the
    /// reply in its field; until then the notification is where it's kept,
    /// so it outlives the app being terminated.
    private func notifyFailedReply(
        _ text: String,
        to agentID: Int,
        agentName: String?,
        because error: any Error
    ) async {
        let content = UNMutableNotificationContent()
        if let agentName, !agentName.isEmpty {
            content.title = "Couldn’t send your reply to \(agentName)"
        } else {
            content.title = "Couldn’t send your reply"
        }
        content.subtitle = error.localizedDescription
        content.body = text
        content.sound = .default
        content.threadIdentifier = "agent-\(agentID)"
        content.userInfo = ["agentId": agentID, Self.failedReplyKey: text]
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// The top-level `agentId` the cloud merges into the payload.
    private nonisolated static func agentID(in userInfo: [AnyHashable: Any]) -> Int? {
        switch userInfo["agentId"] {
        case let id as Int: id
        case let id as NSNumber: id.intValue
        case let id as String: Int(id)
        default: nil
        }
    }
}

/// Why a reply typed into a notification wasn't tried.
private enum ReplyError: LocalizedError {
    case unpaired

    var errorDescription: String? {
        switch self {
        case .unpaired: "This device isn’t paired with Cohesion."
        }
    }
}
