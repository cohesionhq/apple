import CohesionCore
import CohesionUI
import SwiftUI

/// A memory line tapped in an agent's chat: the text the conversation
/// recorded and who sees it, then everything the agent remembers now, its
/// own, its team's and the global ones. A memory forgotten since says so.
/// Read-only, as the web's dialog is; the agent's Memories screen forgets.
struct MemorySheet: View {
    let agent: Agent
    let viewed: ViewedMemory

    @Environment(AppModel.self) private var model
    @Environment(\.agentTeams) private var teams
    @Environment(\.dismiss) private var dismiss

    /// What the agent remembers now; `nil` until loaded.
    @State private var current: [Memory]?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(viewed.text)
                        .textSelection(.enabled)
                } footer: {
                    if failed {
                        Text("Couldn’t load \(agent.name)’s memories.")
                            .foregroundStyle(.red)
                    } else if current != nil {
                        Text(kept.map(seers) ?? "No longer remembered.")
                    }
                }
                if let current {
                    if current.isEmpty {
                        Section {
                            Text("No memories yet.")
                                .foregroundStyle(.secondary)
                        } header: {
                            heading(nil, isFirst: true)
                        }
                    }
                    ForEach(Array(current.scopes.enumerated()), id: \.element) { index, scope in
                        Section {
                            ForEach(current.filter { $0.scope == scope }) { memory in
                                MemoryRow(memory: memory)
                                    .listRowBackground(memory.id == kept?.id ? Color.accentColor.opacity(0.12) : nil)
                            }
                        } header: {
                            heading(scope, isFirst: index == 0)
                        }
                    }
                } else if !failed {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(viewed.change == .forgotten ? "Forgotten memory" : "Memory")
            .navigationSubtitle("\(agent.name) \(viewed.change == .forgotten ? "forgot" : "remembered") this.")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task { await watch() }
    }

    /// The memory still kept with the text the conversation recorded; the
    /// line names no memory, so the text is all there is to match.
    private var kept: Memory? {
        current?.first { $0.memory == viewed.text }
    }

    /// Who sees `memory`.
    private func seers(_ memory: Memory) -> String {
        switch memory.scope {
        case .agent: "Only \(agent.name) sees this."
        case .team: memory.scope.teamTitle(teams).map { "Agents on \($0) see this." } ?? "Agents on its team see this."
        case .global: "Every agent sees this."
        }
    }

    /// A section's header among the current memories: the scope's title,
    /// under "What … remembers now" on the first section.
    private func heading(_ scope: Memory.Scope?, isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if isFirst {
                Text("What \(agent.name) remembers now")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            if let scope {
                Text(scope.title(for: agent, teams: teams))
            }
        }
    }

    /// Loads what the agent remembers, again whenever a memory is
    /// remembered or forgotten; the stream yields once on connecting, which
    /// does the first load.
    private func watch() async {
        guard let client = model.client else { return }
        for await _ in client.changes(matching: { $0 == .memories }) {
            do {
                let loaded = try await client.listMemories(of: agent.id)
                withAnimation { current = loaded }
                failed = false
            } catch where !Task.isCancelled {
                // A load cut short by closing the sheet isn't a failure.
                failed = current == nil
            } catch {}
        }
    }
}

/// A memory line tapped in the chat: what it recorded, which the sheet
/// matches to what the agent remembers now.
struct ViewedMemory: Identifiable {
    let id: Int
    let text: String
    let change: AgentMessage.Content.MemoryChange
}
