import ActivityKit
import CohesionCore
import CohesionScreens
import Foundation
import Observation
import os
import UIKit
import UserNotifications

/// This device's registration for agent notifications and Live Activities.
///
/// The phone has no cloud identity, so it asks cohesiond's iOS Companion
/// extension for a short-lived grant, then registers its APNs token, and its
/// push-to-start token for Live Activities, with Cohesion Cloud directly
/// using that grant. A Live Activity the cloud starts carries a code that
/// registers that activity's own token.
///
/// Registering is idempotent, so the app registers again at every launch and
/// return to the foreground rather than trusting what it last sent: the cloud
/// may have dropped a token, and a token sent with no paired server, or
/// before iOS had one, would otherwise wait until something changed.
@Observable @MainActor
final class PushRegistration: PairingObserver {
    static let companionIdentifier = "com.hellocohesion.ios-companion"
    /// How long a registration is trusted, however recently it was tried.
    private static let maxAge: TimeInterval = 24 * 60 * 60
    /// How soon a return to the foreground registers again when nothing
    /// changed.
    private static let minimumInterval: TimeInterval = 10 * 60
    /// The longest wait between retries.
    private static let maxBackoff: TimeInterval = 5 * 60

    enum Status {
        case unavailable(reason: String)
        case notRequested
        case denied
        case registering
        case registered(account: String, at: Date)
        case failed(String)

        var description: String {
            switch self {
            case .unavailable(let reason): reason
            case .notRequested: "Off"
            case .denied: "Notifications are turned off for Cohesion in the Settings app."
            case .registering: "Registering…"
            case .registered(let account, _): "On for \(account)"
            case .failed(let message): message
            }
        }
    }

    private(set) var status: Status
    /// A setup problem that doesn't stop notifications but makes them
    /// worse, found at the last registration.
    private(set) var warning: String?
    /// Whether the user turned notifications off for the app; the device
    /// still registers, for Live Activities, which don't need them.
    private(set) var notificationsDenied = false
    /// Whether the user allows the app's Live Activities, in the Settings app.
    private(set) var liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    /// Whether the user allows the Live Activity's more frequent updates,
    /// in the Settings app.
    private(set) var frequentPushesEnabled = ActivityAuthorizationInfo().frequentPushesEnabled

    /// The push-to-start token iOS last yielded, lowercase hex.
    private var yieldedStartToken: String?
    /// The push-to-start token iOS holds for `CohesionActivitiesAttributes`
    /// Live Activities, lowercase hex; `nil` until it has one. `pushToStartToken` is often still `nil` when
    /// `pushToStartTokenUpdates` has yielded, so the yield wins.
    private var liveActivityStartToken: String? {
        yieldedStartToken ?? Activity<CohesionActivitiesAttributes>.pushToStartToken.map(Self.hex)
    }
    /// A push-to-start token iOS yielded that the cloud doesn't have yet.
    private var pendingStartToken: String?
    private var startTokenRetry: Task<Void, Never>?
    /// The Live Activities whose push tokens are being followed.
    private var watchedActivityIDs: Set<String> = []
    /// The Live Activities the app ended itself, whose end the cloud isn't
    /// told of, so a sweep doesn't make it start them again.
    private var sweptActivityIDs: Set<String> = []
    /// The report that no Live Activity is running under way, which another
    /// caller skips rather than sending its own.
    private var missingActivityReport: Task<Void, Never>?
    /// When the cloud last heard that no Live Activity is running.
    private var lastMissingActivityReport: Date?

    /// The registration under way, which another caller waits for rather
    /// than starting its own.
    private var registration: Task<Bool, Never>?
    private var lastAttempt: Date?

    /// The APNs token request under way, which every caller shares.
    private var tokenRequest: Task<Data, any Error>?
    /// Waits for the token APNs hands the app delegate.
    private var tokenContinuation: CheckedContinuation<Data, any Error>?
    private var tokenRequestNumber = 0

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Cohesion", category: "push")

    init() {
        if let stored = Stored.load() {
            status = .registered(account: stored.account, at: stored.registeredAt)
        } else {
            status = .notRequested
        }
    }

    /// Whether the cloud has this device from an earlier registration, even
    /// if the latest attempt failed.
    var isStoredRegistration: Bool {
        Stored.load() != nil
    }

    // MARK: Actions

    /// Asks permission to notify, then registers this device's token. A
    /// refusal still registers, for Live Activities.
    func requestAndRegister(using client: CohesionClient) async {
        Stored.optedOut = false
        status = .registering
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            notificationsDenied = !granted
            Self.log.info("Notification permission \(granted ? "granted" : "refused", privacy: .public)")
            guard granted || liveActivitiesEnabled else {
                status = .denied
                return
            }
            let token = try await deviceToken()
            await register(token: token, using: client)
        } catch {
            Self.log.error("Couldn't request permission or a token: \(error.localizedDescription, privacy: .public)")
            status = .failed(error.localizedDescription)
        }
    }

    /// Registers `token` at the cloud with a grant from the companion.
    /// Returns whether the cloud has it.
    @discardableResult
    func register(token: Data, using client: CohesionClient) async -> Bool {
        if let registration {
            _ = await registration.value
            return Stored.load()?.token == Self.hex(token)
        }
        let task = Task { await performRegistration(token: token, using: client) }
        registration = task
        defer { registration = nil }
        return await task.value
    }

    private func performRegistration(token: Data, using client: CohesionClient) async -> Bool {
        status = .registering
        lastAttempt = .now
        let environment = Self.environment
        let startToken = liveActivityStartToken
        Self.log.info("Registering (\(environment, privacy: .public), start token \(startToken == nil ? "missing" : "present", privacy: .public))")
        do {
            let (grant, agentLookup) = try await companionGrant(using: client)
            Self.log.debug("Got a grant for \(grant.account, privacy: .private)")
            let hex = Self.hex(token)
            var body = [
                "grant": grant.grant,
                "token": hex,
                "topic": try Self.topic(),
                "environment": environment,
                "name": UIDevice.current.name,
            ]
            body["liveActivityToken"] = startToken
            let _: DeviceRegistration? = try await send("POST", to: grant.registrationURL, body)
            let stored = Stored(
                token: hex,
                liveActivityToken: startToken,
                environment: environment,
                registrationURL: grant.registrationURL,
                account: grant.account,
                registeredAt: .now
            )
            stored.save()
            status = .registered(account: stored.account, at: stored.registeredAt)
            warning = agentLookup ? nil : Self.agentLookupWarning
            Self.log.info("Registered")
            return true
        } catch let error as PushError where error.isSetupProblem {
            Self.log.error("Can't register: \(error.localizedDescription, privacy: .public)")
            status = .unavailable(reason: error.localizedDescription)
        } catch {
            Self.log.error("Registering failed: \(error.localizedDescription, privacy: .public)")
            status = .failed(error.localizedDescription)
        }
        return false
    }

    /// Removes this device from the cloud with a fresh grant, so it stops
    /// getting notifications, and keeps it from registering again on its
    /// own until the user turns notifications back on.
    func unregister(using client: CohesionClient) async {
        Stored.optedOut = true
        guard Stored.load() != nil else {
            status = .notRequested
            return
        }
        status = .registering
        do {
            try await removeRegistration(using: client)
            status = .notRequested
            warning = nil
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Forgets the registration on unpairing, removing it from the cloud
    /// while the old server can still grant that. The local copy goes even
    /// when the cloud can't be reached, so the next server starts clean.
    func forget(using client: CohesionClient?) async {
        Self.log.info("Forgetting the registration")
        // Their agent ids mean nothing, or another agent, on the next server,
        // and a reply typed into one would go there.
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        pendingStartToken = nil
        if let client, Stored.load() != nil {
            try? await removeRegistration(using: client)
        }
        Stored.remove()
        Stored.optedOut = false
        lastAttempt = nil
        status = .notRequested
        warning = nil
    }

    /// Registers from scratch with a newly paired server.
    func didPair(using client: CohesionClient) async {
        Self.log.info("Paired; registering from scratch")
        Stored.remove()
        lastAttempt = nil
        status = .notRequested
        await refresh(using: client)
    }

    private func removeRegistration(using client: CohesionClient) async throws {
        guard let stored = Stored.load() else { return }
        do {
            let (grant, _) = try await companionGrant(using: client)
            let _: JSONValue? = try await send("DELETE", to: grant.registrationURL, [
                "grant": grant.grant,
                "token": stored.token,
            ])
            Stored.remove()
            Self.log.info("Unregistered")
        } catch {
            Self.log.error("Unregistering failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// What a refresh came to.
    enum Refresh {
        /// The cloud has what this device would send.
        case current
        case failed
        /// The device isn't to register: the user turned it off, or there is
        /// nothing it would be notified of.
        case ineligible
    }

    /// Registers again at launch and on returning to the foreground: always
    /// when a token or the APNs environment changed, the cloud lacks the
    /// push-to-start token, or the registration is a day old, and otherwise
    /// at most every few minutes. A device never registered registers when
    /// it may notify or show Live Activities, unless the user turned it off.
    @discardableResult
    func refresh(using client: CohesionClient) async -> Refresh {
        if let registration {
            _ = await registration.value
        }
        guard !Stored.optedOut else {
            Self.log.debug("Not refreshing: turned off")
            return .ineligible
        }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let mayNotify = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
        notificationsDenied = settings.authorizationStatus == .denied
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        frequentPushesEnabled = ActivityAuthorizationInfo().frequentPushesEnabled
        let stored = Stored.load()
        guard stored != nil || mayNotify || liveActivitiesEnabled else {
            if notificationsDenied { status = .denied }
            Self.log.debug("Not refreshing: never registered, and nothing to register for")
            return .ineligible
        }
        let token: Data
        do {
            // APNs may hand out a new token at any launch.
            token = try await deviceToken()
        } catch {
            Self.log.error("No APNs token: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
        let startToken = liveActivityStartToken
        let reasons = [
            stored == nil ? "unregistered" : nil,
            stored.map { $0.token != Self.hex(token) } == true ? "token changed" : nil,
            stored.map { $0.environment != Self.environment } == true ? "environment changed" : nil,
            startToken != nil && startToken != stored?.liveActivityToken ? "start token unsent" : nil,
            stored.map { Date.now.timeIntervalSince($0.registeredAt) > Self.maxAge } == true ? "stale" : nil,
            lastAttempt.map { Date.now.timeIntervalSince($0) > Self.minimumInterval } ?? true ? "due" : nil,
        ].compactMap(\.self)
        guard !reasons.isEmpty else {
            Self.log.debug("Not refreshing: registered moments ago")
            return .current
        }
        Self.log.info("Refreshing: \(reasons.joined(separator: ", "), privacy: .public)")
        return await register(token: token, using: client) ? .current : .failed
    }

    // MARK: Live Activities

    /// Follows iOS's Live Activity push tokens and settings for as long as
    /// the app runs: the push-to-start token, which registers again through
    /// `client` (the paired server, when there is one), and each Live
    /// Activity's own token. Called at launch, since iOS launches the app in
    /// the background to hand over the token of a Live Activity a push
    /// started; ends Live Activities left behind first.
    func watchLiveActivities(client: @escaping () -> CohesionClient?) {
        sweepStaleActivities()
        Task {
            for await token in Activity<CohesionActivitiesAttributes>.pushToStartTokenUpdates {
                let hex = Self.hex(token)
                Self.log.info("New push-to-start token")
                yieldedStartToken = hex
                pendingStartToken = hex
                sendPendingStartToken(client: client)
            }
        }
        Task {
            for activity in Activity<CohesionActivitiesAttributes>.activities {
                Self.log.info("Live Activity running at launch: \(Self.describe(activity), privacy: .public)")
                watch(activity, client: client)
            }
            for await activity in Activity<CohesionActivitiesAttributes>.activityUpdates {
                Self.log.info("Live Activity started: \(Self.describe(activity), privacy: .public)")
                watch(activity, client: client)
            }
        }
        Task {
            for await enabled in ActivityAuthorizationInfo().activityEnablementUpdates {
                Self.log.info("Live Activities \(enabled ? "enabled" : "disabled", privacy: .public)")
                liveActivitiesEnabled = enabled
            }
        }
        Task {
            for await enabled in ActivityAuthorizationInfo().frequentPushEnablementUpdates {
                Self.log.info("Frequent Live Activity updates \(enabled ? "enabled" : "disabled", privacy: .public)")
                frequentPushesEnabled = enabled
            }
        }
    }

    /// Registers the pending push-to-start token, retrying with backoff
    /// until the cloud has it, however long there is no paired server, so a
    /// yield is never dropped. A newer yield replaces the pending token.
    private func sendPendingStartToken(client: @escaping () -> CohesionClient?) {
        guard startTokenRetry == nil else { return }
        startTokenRetry = Task {
            var delay: TimeInterval = 2
            while let pending = pendingStartToken {
                if let client = client() {
                    switch await refresh(using: client) {
                    case .current where Stored.load()?.liveActivityToken == pending, .ineligible:
                        if pendingStartToken == pending { pendingStartToken = nil }
                        continue
                    case .current, .failed:
                        break
                    }
                }
                Self.log.info("Push-to-start token unsent; retrying in \(Int(delay))s")
                try? await Task.sleep(for: .seconds(delay))
                delay = min(delay * 2, Self.maxBackoff)
            }
            startTokenRetry = nil
        }
    }

    /// Registers the token `activity` has, then each iOS gives it after,
    /// until it ends. `pushTokenUpdates` yields only when the token changes,
    /// and iOS makes a pushed Live Activity's token before it launches the
    /// app, so the one it already has is registered first.
    /// Tells the cloud once when it ends or is dismissed, unless the app
    /// ended it, so the cloud starts a fresh one.
    private func watch(_ activity: Activity<CohesionActivitiesAttributes>, client: @escaping () -> CohesionClient?) {
        guard watchedActivityIDs.insert(activity.id).inserted else { return }
        Task {
            for await state in activity.activityStateUpdates {
                Self.log.info("Live Activity \(activity.id, privacy: .public) is now \(String(describing: state), privacy: .public)")
                guard state == .ended || state == .dismissed else { continue }
                if sweptActivityIDs.remove(activity.id) == nil {
                    await reportDismissal(code: activity.attributes.registrationCode, client: client)
                }
                break
            }
        }
        Task {
            for await content in activity.contentUpdates {
                Self.log.info("Live Activity updated: \(Self.describe(activity, content), privacy: .public)")
            }
        }
        Task {
            if let token = activity.pushToken {
                await register(liveActivityToken: token, code: activity.attributes.registrationCode)
            }
            for await token in activity.pushTokenUpdates {
                await register(liveActivityToken: token, code: activity.attributes.registrationCode)
            }
            watchedActivityIDs.remove(activity.id)
        }
    }

    /// Registers a Live Activity's push token at the cloud this device
    /// registered with, proving it with the code from the activity's
    /// attributes. Retries with backoff while the cloud can't be reached or
    /// the device isn't registered yet; gives up on a refusal, which no
    /// retry would change.
    private func register(liveActivityToken token: Data, code: String) async {
        // The code comes from a push; it only ever goes back to the cloud.
        guard !code.isEmpty, code.count <= 128, let topic = try? Self.topic() else {
            Self.log.error("Live Activity token not registered: bad code")
            return
        }
        var delay: TimeInterval = 2
        for attempt in 1...6 {
            if attempt > 1 {
                try? await Task.sleep(for: .seconds(delay))
                delay = min(delay * 2, Self.maxBackoff)
            }
            guard let stored = Stored.load(),
                  let url = URL(string: stored.registrationURL)?.appending(path: "live-activities")
            else {
                Self.log.info("Live Activity token waits for the device's registration (attempt \(attempt))")
                continue
            }
            do {
                let _: JSONValue? = try await send("POST", to: url.absoluteString, [
                    "code": code,
                    "token": Self.hex(token),
                    "topic": topic,
                    "environment": Self.environment,
                ])
                Self.log.info("Registered a Live Activity token")
                return
            } catch let error as PushError where error.isRetryable {
                Self.log.error("Live Activity token failed (attempt \(attempt)): \(error.localizedDescription, privacy: .public)")
            } catch {
                Self.log.error("Live Activity token refused: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
        Self.log.error("Live Activity token given up on")
    }

    /// Tells the cloud, at launch and on returning to the foreground, that
    /// no Live Activity is running, so it starts a fresh one if it has
    /// activities to show: the app can't see every dismissal as it happens.
    /// At most every few minutes once the cloud has heard, except that a
    /// cloud that started one moments ago is asked once more shortly after.
    func reportMissingLiveActivity(using client: CohesionClient) async {
        guard missingActivityReport == nil,
              liveActivitiesEnabled,
              !Activity<CohesionActivitiesAttributes>.activities.contains(where: { $0.activityState == .active }),
              lastMissingActivityReport.map({ Date.now.timeIntervalSince($0) > Self.minimumInterval }) ?? true,
              let stored = Stored.load()
        else { return }
        let task = Task {
            Self.log.info("No Live Activity running; telling the cloud")
            switch await reportDismissal(["deviceToken": stored.token], client: { client }) {
            case .some(let reply) where reply.isCoolingDown:
                lastMissingActivityReport = .now
                try? await Task.sleep(for: .seconds(15))
                guard !Activity<CohesionActivitiesAttributes>.activities.contains(where: { $0.activityState == .active })
                else { return }
                Self.log.info("Asking the cloud again for a Live Activity")
                if case nil = await reportDismissal(["deviceToken": stored.token], client: { client }) {
                    lastMissingActivityReport = nil
                }
            case .some:
                lastMissingActivityReport = .now
            case nil:
                break
            }
        }
        missingActivityReport = task
        defer { missingActivityReport = nil }
        await task.value
    }

    /// Tells the cloud the Live Activity registered with `code` ended or was
    /// dismissed.
    private func reportDismissal(code: String, client: @escaping () -> CohesionClient?) async {
        // The code comes from a push; it only ever goes back to the cloud.
        guard !code.isEmpty, code.count <= 128 else {
            Self.log.error("Live Activity dismissal not reported: bad code")
            return
        }
        Self.log.info("Telling the cloud a Live Activity ended")
        _ = await reportDismissal(["code": code], client: client)
    }

    /// Sends `body` to the cloud's Live Activity dismissal endpoint and
    /// returns its reply, or `nil` when it failed; a failure waits for the
    /// next return to the foreground. A cloud that knows neither the code nor
    /// the device has lost the registration, so the device registers again.
    private func reportDismissal(_ body: [String: String], client: () -> CohesionClient?) async -> LiveActivityDismissal? {
        guard let stored = Stored.load(),
              let url = URL(string: stored.registrationURL)?.appending(path: "live-activities/dismissed")
        else {
            Self.log.info("Live Activity dismissal not reported: not registered")
            return nil
        }
        do {
            guard let reply: LiveActivityDismissal = try await send("POST", to: url.absoluteString, body) else {
                Self.log.error("Live Activity dismissal reported, with an empty reply")
                return nil
            }
            Self.log.info("Live Activity dismissal reported: \(reply.event.rawValue, privacy: .public), delivered \(reply.delivered), tracked \(reply.tracked)\(reply.reason.map { " (\($0))" } ?? "", privacy: .public)")
            return reply
        } catch PushError.grantExpired {
            Self.log.error("The cloud doesn't know this device; registering again")
            if let client = client(), let token = try? await deviceToken() {
                lastAttempt = nil
                await register(token: token, using: client)
            }
        } catch {
            Self.log.error("Live Activity dismissal not reported: \(error.localizedDescription, privacy: .public)")
        }
        return nil
    }

    /// Ends Live Activities left behind, as when their end push never came,
    /// so they don't hold one of the few slots iOS allows: one past its
    /// stale date, all but the latest heard from when there are several,
    /// and one with nothing left going whose last activity finished well
    /// past the five minutes after which the cloud ends it.
    private func sweepStaleActivities() {
        let activities = Activity<CohesionActivitiesAttributes>.activities
        let active = activities.filter { $0.activityState == .active }
        let latest = active.max { $0.content.state.lastHeard < $1.content.state.lastHeard }?.id
        for activity in activities {
            let dismissal: ActivityUIDismissalPolicy?
            switch activity.activityState {
            case .stale:
                dismissal = .immediate
            case .active where activity.id != latest:
                dismissal = .immediate
            case .active where activity.content.state.isLeftBehind:
                // Its last word stays on the Lock Screen a while, as an end
                // push would have left it.
                dismissal = .default
            default:
                dismissal = nil
            }
            guard let dismissal else { continue }
            Self.log.info("Ending a left-behind Live Activity: \(Self.describe(activity), privacy: .public)")
            sweptActivityIDs.insert(activity.id)
            Task { await activity.end(nil, dismissalPolicy: dismissal) }
        }
    }

    /// A Live Activity's id, state and counts for the log, with the
    /// relevance score iOS has next to the one its counts call for.
    private static func describe(
        _ activity: Activity<CohesionActivitiesAttributes>,
        _ content: ActivityContent<CohesionActivitiesAttributes.ContentState>? = nil
    ) -> String {
        let content = content ?? activity.content
        let state = content.state
        return "\(activity.id) \(activity.activityState) \(state.overall.rawValue)"
            + " needsYou=\(state.needsAttentionCount) failed=\(state.failedCount)"
            + " running=\(state.runningCount) done=\(state.doneCount)"
            + " listed=\(state.activities.count) relevance=\(content.relevanceScore) (expected \(state.relevanceScore))"
    }

    // MARK: App delegate

    func didRegister(deviceToken: Data) {
        Self.log.debug("APNs gave a token")
        tokenContinuation?.resume(returning: deviceToken)
        tokenContinuation = nil
    }

    func didFailToRegister(_ error: any Error) {
        Self.log.error("APNs gave no token: \(error.localizedDescription, privacy: .public)")
        tokenContinuation?.resume(throwing: PushError.noToken(error.localizedDescription))
        tokenContinuation = nil
    }

    // MARK: Steps

    /// Asks iOS for the APNs token, which arrives through the app delegate.
    /// A request still waiting answers every caller.
    private func deviceToken() async throws -> Data {
        if let tokenRequest { return try await tokenRequest.value }
        tokenRequestNumber += 1
        let number = tokenRequestNumber
        let request = Task<Data, any Error> {
            try await withCheckedThrowingContinuation { continuation in
                tokenContinuation = continuation
                UIApplication.shared.registerForRemoteNotifications()
                Task {
                    // iOS never answers without a network connection; give up.
                    try? await Task.sleep(for: .seconds(30))
                    guard number == tokenRequestNumber, let continuation = tokenContinuation else { return }
                    tokenContinuation = nil
                    continuation.resume(throwing: PushError.noToken("Apple's push service didn't respond."))
                }
            }
        }
        tokenRequest = request
        defer { tokenRequest = nil }
        return try await request.value
    }

    /// A grant from the iOS Companion extension, checking first that it is
    /// signed in, and whether it can look agents up for the pushes it sends.
    private func companionGrant(using client: CohesionClient) async throws -> (DeviceGrant, agentLookup: Bool) {
        do {
            let status = try await client.callExtension(Self.companionIdentifier, "status").decode(as: CompanionStatus.self)
            guard status.signedIn else { throw PushError.notSignedIn }
            let grant = try await client.callExtension(Self.companionIdentifier, "deviceGrant").decode(as: DeviceGrant.self)
            return (grant, status.agentLookup)
        } catch let error as ServerError where error.code == ServerError.notFound {
            // cohesiond has no extension with the companion's identifier.
            throw PushError.companionNotInstalled
        } catch let error as ServerError where error.message.localizedCaseInsensitiveContains("permission") {
            throw PushError.clientPermissionDisabled
        }
    }

    /// Sends `body` to the cloud, which has a real certificate, so this is
    /// plain HTTPS rather than the paired client's mutual TLS.
    private func send<Reply: Decodable>(_ method: String, to urlString: String, _ body: [String: String]) async throws -> Reply? {
        guard let url = URL(string: urlString) else { throw PushError.cloudRejected("The cloud's registration address is invalid.") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch is URLError {
            throw PushError.cloudUnreachable
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let message = (try? JSONDecoder().decode(CloudMessage.self, from: data))?.message
                ?? String(decoding: data, as: UTF8.self)
            Self.log.error("\(method, privacy: .public) \(url.path(), privacy: .public): \(code)")
            if code == 404 { throw PushError.grantExpired(message) }
            throw PushError.cloudRejected(message, retryable: code >= 500 || code == 429)
        }
        return data.isEmpty ? nil : try JSONDecoder().decode(Reply.self, from: data)
    }

    // MARK: Values

    private static let agentLookupWarning =
        "Enable the iOS Companion extension\u{2019}s \u{201C}cohesion:read\u{201D} permission so notifications show each agent\u{2019}s name, emoji and color."

    private static func hex(_ token: Data) -> String {
        token.map { String(format: "%02x", $0) }.joined()
    }

    private static func topic() throws -> String {
        guard let identifier = Bundle.main.bundleIdentifier else { throw PushError.noToken("The app has no bundle identifier.") }
        return identifier
    }

    /// Which APNs gateway the cloud should use for this build's token: the
    /// `aps-environment` the build was signed with, as its provisioning
    /// profile says, since that, not the build configuration, decides which
    /// gateway issued the token. App Store and TestFlight builds carry no
    /// profile and always use production; the simulator uses development.
    private static let environment: String = {
        #if targetEnvironment(simulator)
        return "development"
        #else
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let profile = try? Data(contentsOf: url),
              // The profile is a CMS envelope around a plain XML plist.
              let start = profile.firstRange(of: Data("<?xml".utf8)),
              let end = profile.firstRange(of: Data("</plist>".utf8)),
              let plist = try? PropertyListSerialization.propertyList(
                  from: profile[start.lowerBound..<end.upperBound], format: nil
              ) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let environment = entitlements["aps-environment"] as? String
        else { return "production" }
        return environment
        #endif
    }()
}

private extension CohesionActivitiesAttributes.ContentState {
    /// The latest start or finish it lists, in Unix seconds.
    var lastHeard: Int {
        activities.flatMap { [$0.startedAt, $0.finishedAt].compactMap(\.self) }.max() ?? 0
    }

    /// Whether the cloud should have ended it: nothing is going, and nothing
    /// listed finished in the last quarter hour, three times the five minutes
    /// the cloud keeps a finished activity, so a late end push wins.
    var isLeftBehind: Bool {
        guard runningCount == 0, needsAttentionCount == 0,
              activities.allSatisfy(\.status.hasEnded)
        else { return false }
        let finishes = activities.map(\.finishedAt)
        // A cloud that sends no finish times leaves nothing to judge by.
        if finishes.contains(nil) { return false }
        let latest = finishes.compactMap(\.self).max() ?? 0
        return Date.now.timeIntervalSince1970 - TimeInterval(latest) > 15 * 60
    }
}

/// An error body from the cloud.
private struct CloudMessage: Decodable {
    let message: String
}

/// The cloud's reply to a Live Activity dismissal.
private struct LiveActivityDismissal: Decodable {
    enum Event: String, Decodable {
        /// The cloud pushed a fresh Live Activity.
        case start
        case none
    }

    let event: Event
    /// How many devices the start reached.
    let delivered: Int
    /// How many of the user's activities the cloud is following.
    let tracked: Int
    /// Why nothing started.
    let reason: String?

    /// Whether nothing started only because the cloud started one moments
    /// ago, which may have been on its way.
    var isCoolingDown: Bool {
        guard event == .none, let reason else { return false }
        return ["cooldown", "cool down", "just started", "recently"].contains { reason.localizedCaseInsensitiveContains($0) }
    }
}

/// Why this device couldn't register, in words for the user.
enum PushError: LocalizedError {
    case companionNotInstalled
    case clientPermissionDisabled
    case notSignedIn
    case cloudUnreachable
    case grantExpired(String)
    /// `retryable` when the cloud failed rather than refused.
    case cloudRejected(String, retryable: Bool = false)
    case noToken(String)

    /// A problem the user fixes in cohesiond rather than by trying again.
    var isSetupProblem: Bool {
        switch self {
        case .companionNotInstalled, .clientPermissionDisabled, .notSignedIn: true
        default: false
        }
    }

    /// Whether trying the same request again may work.
    var isRetryable: Bool {
        switch self {
        case .cloudUnreachable: true
        case .cloudRejected(_, let retryable): retryable
        default: false
        }
    }

    var errorDescription: String? {
        switch self {
        case .companionNotInstalled:
            "The iOS Companion extension isn't installed in Cohesion."
        case .clientPermissionDisabled:
            "The iOS Companion extension's \u{201C}service\u{201D} permission isn't enabled. Turn it on in Cohesion's extension settings."
        case .notSignedIn:
            "The iOS Companion extension isn't signed in to Cohesion Cloud."
        case .cloudUnreachable:
            "Couldn't reach Cohesion Cloud."
        case .grantExpired(let message):
            "The registration grant expired. Try again. (\(message))"
        case .cloudRejected(let message, _):
            "Cohesion Cloud refused the registration: \(message)"
        case .noToken(let reason):
            "This device couldn't get a push token. \(reason)"
        }
    }
}

// MARK: - Storage

/// The last successful registration, kept in `UserDefaults`.
private struct Stored {
    private enum Key {
        static let token = "push.token"
        static let liveActivityToken = "push.liveActivityToken"
        static let environment = "push.environment"
        static let registrationURL = "push.registrationURL"
        static let account = "push.account"
        static let registeredAt = "push.registeredAt"
        static let optedOut = "push.optedOut"
    }

    /// Lowercase hex.
    let token: String
    /// The push-to-start token sent with it, lowercase hex.
    let liveActivityToken: String?
    /// The APNs gateway the token was sent for; `nil` from a build before it
    /// was kept, which registers again.
    let environment: String?
    let registrationURL: String
    let account: String
    let registeredAt: Date

    /// Whether the user turned notifications off here, so the app doesn't
    /// register again on its own.
    static var optedOut: Bool {
        get { UserDefaults.standard.bool(forKey: Key.optedOut) }
        set { UserDefaults.standard.set(newValue, forKey: Key.optedOut) }
    }

    static func load() -> Stored? {
        let defaults = UserDefaults.standard
        guard let token = defaults.string(forKey: Key.token),
              let registrationURL = defaults.string(forKey: Key.registrationURL),
              let account = defaults.string(forKey: Key.account),
              let registeredAt = defaults.object(forKey: Key.registeredAt) as? Date
        else { return nil }
        return Stored(
            token: token,
            liveActivityToken: defaults.string(forKey: Key.liveActivityToken),
            environment: defaults.string(forKey: Key.environment),
            registrationURL: registrationURL,
            account: account,
            registeredAt: registeredAt
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(token, forKey: Key.token)
        defaults.set(liveActivityToken, forKey: Key.liveActivityToken)
        defaults.set(environment, forKey: Key.environment)
        defaults.set(registrationURL, forKey: Key.registrationURL)
        defaults.set(account, forKey: Key.account)
        defaults.set(registeredAt, forKey: Key.registeredAt)
    }

    static func remove() {
        let defaults = UserDefaults.standard
        for key in [Key.token, Key.liveActivityToken, Key.environment, Key.registrationURL, Key.account, Key.registeredAt] {
            defaults.removeObject(forKey: key)
        }
    }
}
