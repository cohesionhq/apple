import CohesionCore
import CohesionUI
import SwiftUI

/// The share sheet's composer: the shared link, an optional note and the agent
/// to send them to. The link is the message, under the note if there is one;
/// the sheet closes once cohesiond has it, and the reply waits in the agent's
/// chat.
struct ShareToAgentView: View {
    private static let agentKey = "agentID"

    /// `nil` until the app is paired.
    let client: CohesionClient?
    /// `nil` when what was shared isn't a web address.
    let url: URL?
    let onFinish: () -> Void
    let onCancel: () -> Void

    @State private var agents: [Agent] = []
    @State private var isLoaded = false
    /// The agent the last link went to, remembered by the extension.
    @State private var agentID = UserDefaults.standard.object(forKey: ShareToAgentView.agentKey) as? Int
    @State private var note = ""
    @State private var isSending = false
    @State private var error: (any Error)?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Send to Agent")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", systemImage: "xmark", role: .cancel, action: onCancel)
                            .disabled(isSending)
                    }
                    if canCompose {
                        ToolbarItem(placement: .confirmationAction) {
                            if isSending {
                                ProgressView()
                            } else {
                                Button("Send", systemImage: "arrow.up", role: .confirm, action: send)
                                    .disabled(agentID == nil)
                            }
                        }
                    }
                }
                .errorAlert($error)
        }
        .interactiveDismissDisabled(isSending)
        .task { await loadAgents() }
    }

    private var canCompose: Bool {
        client != nil && url != nil && !agents.isEmpty
    }

    @ViewBuilder
    private var content: some View {
        if client == nil {
            ContentUnavailableView(
                "Not Paired",
                systemImage: "link",
                description: Text("Open Cohesion and pair it with your server, then share the link again.")
            )
        } else if url == nil {
            ContentUnavailableView(
                "No Link",
                systemImage: "link",
                description: Text("Only a web address can be sent to an agent.")
            )
        } else if canCompose, let url {
            form(url)
        } else if isLoaded {
            ContentUnavailableView(
                "No Agents Yet",
                systemImage: "person.crop.circle",
                description: Text("Create an agent in Cohesion, then share the link again.")
            )
        } else {
            ProgressView()
        }
    }

    private func form(_ url: URL) -> some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text(url.siteName)
                        .fontWeight(.medium)
                    Text(verbatim: url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .accessibilityElement(children: .combine)
                TextField("Add a note…", text: $note, axis: .vertical)
                    .lineLimit(1...6)
            }
            Picker("Send To", selection: $agentID) {
                ForEach(agents) { agent in
                    HStack(spacing: 12) {
                        AgentAvatar(name: agent.name, emoji: agent.emoji, color: agent.color, diameter: 30)
                        Text(agent.name)
                    }
                    .tag(Optional(agent.id))
                }
            }
            .pickerStyle(.inline)
        }
    }

    /// Loads the agents, pinned first, then the latest to talk, as the
    /// Dashboard's picker orders them; the first is chosen when the remembered
    /// one is gone.
    private func loadAgents() async {
        guard let client else { return }
        do {
            let all = try await client.listAgents()
            agents = all.filter(\.isPinned) + all.filter { !$0.isPinned }.sorted {
                ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast)
            }
            if !agents.contains(where: { $0.id == agentID }) {
                agentID = agents.first?.id
            }
        } catch {
            self.error = error
        }
        isLoaded = true
    }

    private func send() {
        guard let client, let url, let agentID, !isSending else { return }
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        Task {
            do {
                try await client.send(note.isEmpty ? url.absoluteString : "\(note)\n\n\(url.absoluteString)", to: agentID)
                UserDefaults.standard.set(agentID, forKey: Self.agentKey)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onFinish()
            } catch {
                self.error = error
            }
            isSending = false
        }
    }
}
