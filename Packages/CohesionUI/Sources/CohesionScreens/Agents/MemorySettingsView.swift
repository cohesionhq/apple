import CohesionCore
import CohesionUI
import SwiftUI

/// Settings › Memories, as the web's: the global memories every agent
/// sees, then each team's under its title, then each agent's own under its
/// avatar and name, each oldest first. Swiping one forgets it.
public struct MemorySettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.agents) private var agents
    @Environment(\.agentTeams) private var teams

    @State private var global: [Memory] = []
    /// Every team's and agent's own memories, each once.
    @State private var others: [Memory] = []
    @State private var isLoaded = false
    @State private var forgetting: Memory?
    @State private var error: (any Error)?

    public init() {}

    public var body: some View {
        List {
            if isLoaded {
                Section {
                    if global.isEmpty {
                        Text("No global memories yet.")
                            .foregroundStyle(.secondary)
                    }
                    rows(global)
                } header: {
                    Text("Global")
                } footer: {
                    Text("Every agent sees these.")
                }
            }
            ForEach(teams ?? []) { team in
                let shared = others.filter { $0.scope == .team(team.id) }
                if !shared.isEmpty {
                    Section {
                        rows(shared)
                    } header: {
                        Text(team.title)
                    } footer: {
                        Text("Every agent on \(team.title) sees these.")
                    }
                }
            }
            ForEach(agents) { agent in
                let own = others.filter { $0.scope == .agent(agent.id) }
                if !own.isEmpty {
                    Section {
                        rows(own)
                    } header: {
                        Label {
                            Text(agent.name)
                        } icon: {
                            AgentAvatar(agent: agent, diameter: 20)
                        }
                    } footer: {
                        Text("Only \(agent.name) sees these.")
                    }
                }
            }
        }
        .overlay {
            if !isLoaded { ProgressView() }
        }
        .navigationTitle("Memories")
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
        // An agent added or deleted changes whose memories to read.
        .task(id: agents.map(\.id)) { await watch() }
        .refreshable { await load(.asked) }
        .errorAlert($error)
    }

    private func rows(_ memories: [Memory]) -> some View {
        ForEach(memories) { memory in
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
    }

    /// Loads the memories, then reloads them whenever cohesiond reports
    /// one remembered or forgotten; the stream also yields once on
    /// connecting, which does the first load.
    private func watch() async {
        guard let client = model.client else { return }
        for await origin in client.loads(matching: { $0 == .memories }) {
            await load(origin)
        }
    }

    /// The global memories, then each agent's: an agent's list holds its
    /// team's too, so a team's are read through its agents, and a team
    /// with none shows none, as on the web.
    private func load(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client else { return }
        await origin.run {
            async let loadedGlobal = client.listMemories(of: nil)
            var seen: [Int: Memory] = [:]
            for agent in agents {
                for memory in try await client.listMemories(of: agent.id) where memory.scope != .global {
                    seen[memory.id] = memory
                }
            }
            let loaded = try await loadedGlobal
            withAnimation {
                global = loaded
                others = seen.values.sorted { $0.id < $1.id }
                isLoaded = true
            }
        } failed: { self.error = $0 }
    }

    /// Takes the row out at once; a failed forget reloads the list.
    private func forget(_ memory: Memory) {
        guard let client = model.client else { return }
        withAnimation {
            global.removeAll { $0.id == memory.id }
            others.removeAll { $0.id == memory.id }
        }
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
