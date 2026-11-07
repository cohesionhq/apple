import CohesionCore
import CohesionUI
import SwiftUI

/// The memories an agent sees, by who sees them: its own, its team's, then
/// the global ones every agent shares, each oldest first. Swiping one
/// forgets it.
struct MemoriesView: View {
    let agent: Agent

    @Environment(AppModel.self) private var model
    @Environment(\.agentTeams) private var teams

    @State private var memories: [Memory] = []
    @State private var isLoaded = false
    @State private var forgetting: Memory?
    @State private var error: (any Error)?

    var body: some View {
        List {
            ForEach(scopes, id: \.self) { scope in
                Section {
                    ForEach(memories.filter { $0.scope == scope }) { memory in
                        MemoryRow(memory: memory)
                            .swipeActions {
                                Button("Forget", systemImage: "trash", role: .destructive) {
                                    forgetting = memory
                                }
                            }
                            .contextMenu {
                                Button("Copy", systemImage: "doc.on.doc") {
                                    Pasteboard.general.string = memory.memory
                                }
                                Button("Forget", systemImage: "trash", role: .destructive) {
                                    forgetting = memory
                                }
                            }
                    }
                } header: {
                    Text(title(of: scope))
                } footer: {
                    Text(footer(of: scope))
                }
            }
        }
        .overlay {
            if !isLoaded {
                ProgressView()
            } else if memories.isEmpty {
                ContentUnavailableView("No Memories", systemImage: "brain")
            }
        }
        .navigationTitle("Memories")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Forget Memory?",
            isPresented: Binding(get: { forgetting != nil }, set: { if !$0 { forgetting = nil } }),
            titleVisibility: .visible,
            presenting: forgetting
        ) { memory in
            Button("Forget", role: .destructive) { forget(memory) }
        } message: { memory in
            Text(memory.memory)
        }
        .task { await watch() }
        .refreshable { await load(.asked) }
        .errorAlert($error)
    }

    private var scopes: [Memory.Scope] { memories.scopes }

    private func title(of scope: Memory.Scope) -> String {
        scope.title(for: agent, teams: teams)
    }

    private func footer(of scope: Memory.Scope) -> String {
        switch scope {
        case .agent: "Only \(agent.name) sees these."
        case .team: scope.teamTitle(teams).map { "Every agent on \($0) sees these." } ?? "Every agent on its team sees these."
        case .global: "Every agent sees these."
        }
    }

    /// Loads the memories, then reloads them whenever cohesiond reports
    /// one remembered or forgotten; the stream also yields once on
    /// connecting, which does the first load.
    private func watch() async {
        guard let client = model.client else { return }
        // A team renamed retitles its section, through `agentTeams`; its
        // memories go with a deleted one.
        for await origin in client.loads(matching: { $0 == .memories }) {
            await load(origin)
        }
    }

    private func load(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client else { return }
        await origin.run {
            let loaded = try await client.listMemories(of: agent.id)
            withAnimation { memories = loaded }
            isLoaded = true
        } failed: { self.error = $0 }
    }

    /// Takes the row out at once; a failed forget reloads the list.
    private func forget(_ memory: Memory) {
        guard let client = model.client else { return }
        withAnimation { memories.removeAll { $0.id == memory.id } }
        Task {
            do {
                try await client.forget(memory)
            } catch {
                self.error = error
                await load()
            }
        }
    }
}

extension [Memory] {
    /// The scopes the memories are in, in the order the agent's prompt
    /// takes them: its own, its team's, then the global ones.
    var scopes: [Memory.Scope] {
        let order = { (scope: Memory.Scope) -> Int in
            switch scope {
            case .agent: 0
            case .team: 1
            case .global: 2
            }
        }
        return Set(map(\.scope)).sorted { order($0) < order($1) }
    }
}

extension Memory.Scope {
    /// The title of the scope's section among `agent`'s memories.
    func title(for agent: Agent, teams: [AgentTeam]?) -> String {
        switch self {
        case .agent: agent.name
        case .team: teamTitle(teams) ?? "Team"
        case .global: "Global"
        }
    }

    /// The title of the team that sees it, among `teams`.
    func teamTitle(_ teams: [AgentTeam]?) -> String? {
        guard case .team(let id) = self else { return nil }
        return teams?.first { $0.id == id }?.title
    }
}

/// A memory and when it was remembered.
struct MemoryRow: View {
    let memory: Memory

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(memory.memory)
                .textSelection(.enabled)
            Text(memory.createdAt, format: .dateTime.month().day().year())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
