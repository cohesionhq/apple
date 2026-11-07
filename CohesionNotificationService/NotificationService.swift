import Intents
import UIKit
import UserNotifications
import WidgetKit

/// Turns an agent push into a communication notification, with the agent's
/// emoji on its color as the sender's avatar.
final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var original: UNNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        original = request.content
        guard let sender = AgentSender(userInfo: request.content.userInfo) else {
            return finish(with: request.content)
        }
        // The agent is unread now, so the Agents widget shows it.
        WidgetCenter.shared.reloadAllTimelines()

        let person = INPerson(
            personHandle: INPersonHandle(value: sender.conversationID, type: .unknown),
            nameComponents: nil,
            displayName: sender.name,
            image: sender.avatar(),
            contactIdentifier: nil,
            customIdentifier: sender.conversationID
        )
        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: request.content.body,
            speakableGroupName: INSpeakableString(spokenPhrase: sender.name),
            conversationIdentifier: sender.conversationID,
            serviceName: "Cohesion",
            sender: person,
            attachments: nil
        )
        intent.setImage(person.image, forParameterNamed: \.sender)
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming
        interaction.donate(completion: nil)

        do {
            finish(with: try request.content.updating(from: intent))
        } catch {
            finish(with: request.content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let original { finish(with: original) }
    }

    private func finish(with content: UNNotificationContent) {
        contentHandler?(content)
        contentHandler = nil
    }
}

/// The agent a push is from, by its payload. Without the companion's
/// `cohesion:read` permission the payload has only the id, so the sender
/// shows as "Agent" with an initial on blue.
private struct AgentSender {
    let id: Int
    let name: String
    let emoji: String?
    let color: UIColor

    var conversationID: String { "agent-\(id)" }

    init?(userInfo: [AnyHashable: Any]) {
        let id: Int
        switch userInfo["agentId"] {
        case let value as Int: id = value
        case let value as NSNumber: id = value.intValue
        case let value as String:
            guard let value = Int(value) else { return nil }
            id = value
        default: return nil
        }
        self.id = id
        name = Self.nonEmpty(userInfo["agentName"] as? String) ?? "Agent"
        emoji = Self.nonEmpty(userInfo["agentEmoji"] as? String)
        color = Self.color(named: userInfo["agentColor"] as? String)
    }

    /// A 256-point circle in the agent's color, with its emoji or initial.
    func avatar() -> INImage? {
        let size = CGSize(width: 256, height: 256)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let data = renderer.pngData { context in
            color.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))

            let text: String
            let attributes: [NSAttributedString.Key: Any]
            if let emoji {
                text = emoji
                attributes = [.font: UIFont.systemFont(ofSize: size.height * 0.5)]
            } else {
                text = String(name.prefix(1)).uppercased()
                attributes = [
                    .font: UIFont.systemFont(ofSize: size.height * 0.5, weight: .semibold),
                    .foregroundColor: UIColor.white,
                ]
            }
            let string = NSAttributedString(string: text, attributes: attributes)
            let bounds = string.size()
            string.draw(at: CGPoint(x: (size.width - bounds.width) / 2, y: (size.height - bounds.height) / 2))
        }
        return INImage(imageData: data)
    }

    private static func nonEmpty(_ string: String?) -> String? {
        guard let string, !string.isEmpty else { return nil }
        return string
    }

    /// Mid-tone colors that hold white text and read on light and dark.
    private static func color(named name: String?) -> UIColor {
        switch name {
        case "green": UIColor(red: 0.20, green: 0.68, blue: 0.35, alpha: 1)
        case "orange": UIColor(red: 0.96, green: 0.55, blue: 0.10, alpha: 1)
        case "purple": UIColor(red: 0.62, green: 0.35, blue: 0.86, alpha: 1)
        case "red": UIColor(red: 0.90, green: 0.26, blue: 0.24, alpha: 1)
        case "pink": UIColor(red: 0.93, green: 0.30, blue: 0.52, alpha: 1)
        case "teal": UIColor(red: 0.13, green: 0.64, blue: 0.68, alpha: 1)
        case "yellow": UIColor(red: 0.93, green: 0.73, blue: 0.10, alpha: 1)
        default: UIColor(red: 0.18, green: 0.48, blue: 0.96, alpha: 1)
        }
    }
}
