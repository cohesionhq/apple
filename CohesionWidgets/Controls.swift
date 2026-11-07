import AppIntents
import CohesionCore
import SwiftUI
import WidgetKit

/// Includes the intents the controls run from `CohesionCore`.
nonisolated struct CohesionWidgetsIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [CohesionCoreIntents.self] }
}

/// Opens the new task sheet.
struct AddTaskControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "AddTask") {
            ControlWidgetButton(action: AddTaskIntent()) {
                Label("Add Task", systemImage: "checklist")
                    .tint(.accentColor)
            }
        }
        .displayName("Add Task")
        .description("Opens a new task.")
    }
}

/// Opens the chat of the agent picked in the control's settings, or the list
/// of agents until one is.
struct AgentChatControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: "AgentChat", provider: AgentChatControlProvider()) { agent in
            ControlWidgetButton(action: OpenAgentChatIntent(agent: agent)) {
                Label(agent?.name ?? "Chat with Agent", systemImage: "bubble.left.and.text.bubble.right")
                    .tint(.accentColor)
            }
        }
        .displayName("Chat with Agent")
        .description("Opens a chat with the agent you pick.")
        .promptsForUserConfiguration()
    }
}

/// Which agent an `AgentChatControl` opens, picked when adding it.
struct AgentChatControlConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Chat with Agent"

    @Parameter(title: "Agent") var agent: AgentEntity?
}

/// Hands the control the agent picked, which needs no connection.
nonisolated struct AgentChatControlProvider: AppIntentControlValueProvider {
    func previewValue(configuration: AgentChatControlConfiguration) -> AgentEntity? {
        configuration.agent
    }

    func currentValue(configuration: AgentChatControlConfiguration) async throws -> AgentEntity? {
        configuration.agent
    }
}

/// Opens the actor composer.
struct NewActorSessionControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "NewActorSession") {
            ControlWidgetButton(action: NewActorSessionIntent()) {
                Label("New Actor Session", systemImage: "terminal")
                    .tint(.accentColor)
            }
        }
        .displayName("New Actor Session")
        .description("Opens a new session for an actor.")
    }
}
