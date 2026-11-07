import CohesionCore
import CohesionUI
import SwiftUI

/// The cues an agent set to wake itself. Swiping one removes it.
struct AgentCuesView: View {
    let agent: Agent

    @Environment(AppModel.self) private var model

    @State private var cues: [AgentCue] = []
    @State private var isLoaded = false
    @State private var removing: AgentCue?
    @State private var error: (any Error)?

    var body: some View {
        List {
            if !cues.isEmpty {
                Section {
                    ForEach(cues) { cue in
                        NavigationLink {
                            CueDetailView(cue: cue)
                        } label: {
                            CueRow(cue: cue)
                        }
                        .swipeActions {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                removing = cue
                            }
                        }
                    }
                } footer: {
                    Text("The agent set these to wake itself up.")
                }
            }
        }
        .overlay {
            if !isLoaded {
                ProgressView()
            } else if cues.isEmpty {
                ContentUnavailableView("No Cues", systemImage: "alarm", description: Text("It hasn’t set any."))
            }
        }
        .navigationTitle("Cues")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Remove “\(removing?.title(in: model.vocabulary) ?? "")”?",
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            titleVisibility: .visible,
            presenting: removing
        ) { cue in
            Button("Remove Cue", role: .destructive) { remove(cue) }
        } message: { _ in
            Text("The agent stops waking for it. Its other cues stay.")
        }
        .task { await watch() }
        .refreshable { await load(.asked) }
        .errorAlert($error)
    }

    private func watch() async {
        guard let client = model.client else { return }
        for await origin in client.loads(matching: { [id = agent.id] in $0 == .agent(id) }) {
            await load(origin)
        }
    }

    private func load(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client else { return }
        await origin.run {
            let loaded = try await client.listCues(of: agent.id)
            withAnimation { cues = loaded }
            isLoaded = true
        } failed: { self.error = $0 }
    }

    private func remove(_ cue: AgentCue) {
        guard let client = model.client else { return }
        Task {
            do {
                try await client.remove(cue)
                withAnimation { cues.removeAll { $0.id == cue.id } }
            } catch {
                self.error = error
            }
        }
    }
}

/// A cue's title, when it fires and its effort, and the start of what it
/// tells the agent to do.
private struct CueRow: View {
    let cue: AgentCue

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(cue.title(in: model.vocabulary))
            Text(cue.summary(in: model.vocabulary))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(cue.instructions)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

/// All of a cue: its instructions and the check that decides whether it wakes the agent.
private struct CueDetailView: View {
    let cue: AgentCue

    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                Text(cue.summary(in: model.vocabulary))
                    .foregroundStyle(.secondary)
                Text(cue.instructions)
                    .textSelection(.enabled)
            }
            Section {
                Text(cue.script)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            } header: {
                Text("Check")
            } footer: {
                Text("Runs each time, and wakes the agent only when it returns something; that result is handed to the agent.")
            }
        }
        .navigationTitle(cue.title(in: model.vocabulary))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension AgentCue {
    /// "When a task is created · Medium effort", without the hook when the title already says it; a
    /// foreground cue says it wakes the conversation once instead of an effort.
    func summary(in vocabulary: Vocabulary) -> String {
        let effortLabel = switch effort {
        case .background(let tier): "\(vocabulary.title(of: tier)) effort"
        case .foreground: "Once, in this conversation"
        }
        let when = "When \(vocabulary.clause(of: hook))"
        return title(in: vocabulary) == when ? effortLabel : "\(when) · \(effortLabel)"
    }
}
