import CohesionCore
import CohesionUI
import SwiftUI

/// How many of an agent's latest runs its Usage and Runs pages read.
private let runLimit = 50

/// What an agent's latest runs (jobs and forks) used in all. The
/// conversation's own turns aren't runs, so they aren't counted.
struct AgentUsageView: View {
    let agent: Agent

    @State private var runs: [AgentRun]?

    var body: some View {
        List {
            if let runs {
                Section {
                    LabeledContent("Runs", value: runs.count.formatted())
                    LabeledContent(
                        "Tokens",
                        value: "\(tokenCount(runs.map(\.inputTokens).reduce(0, +))) in · \(tokenCount(runs.map(\.outputTokens).reduce(0, +))) out"
                    )
                    LabeledContent("Cost", value: usd(runs.compactMap(\.cost).reduce(0, +)))
                } footer: {
                    Text(runs.count == runLimit
                        ? "Across its last \(runLimit) runs. Chatting with it isn’t counted."
                        : "Across its runs. Chatting with it isn’t counted.")
                }
            }
        }
        .overlay {
            if runs == nil { ProgressView() }
        }
        .navigationTitle("Usage")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(LoadsRuns(agent: agent, runs: $runs))
    }
}

/// An agent's latest runs.
struct AgentRunsView: View {
    let agent: Agent

    @State private var runs: [AgentRun]?

    var body: some View {
        List(runs ?? []) { run in
            RunRow(run: run)
        }
        .overlay {
            if runs == nil {
                ProgressView()
            } else if runs?.isEmpty == true {
                ContentUnavailableView(
                    "No Runs",
                    systemImage: "bolt",
                    description: Text("One starts each time one of its cues wakes it, another agent asks it something, or an actor session it follows moves on.")
                )
            }
        }
        .navigationTitle("Runs")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(LoadsRuns(agent: agent, runs: $runs))
    }
}

/// Keeps `runs` to the agent's latest, `nil` until they've loaded: cohesiond
/// reports a run as a change to the agent.
private struct LoadsRuns: ViewModifier {
    let agent: Agent
    @Binding var runs: [AgentRun]?

    @Environment(AppModel.self) private var model

    @State private var error: (any Error)?

    func body(content: Content) -> some View {
        content
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
            let loaded = try await client.listRuns(of: agent.id, limit: runLimit)
            withAnimation { runs = loaded }
        } failed: { self.error = $0 }
    }
}

/// How a run went, what woke it, when, and what it used.
private struct RunRow: View {
    let run: AgentRun

    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            outcomeIcon
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .lineLimit(2)
                    Spacer()
                    Text(run.startedAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if cueName != nil {
                    Text("When \(model.vocabulary.clause(of: run.hook))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                usage
                if case .failed(_, let error) = run.state, !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AgentRun.State.failedTint)
                }
            }
        }
    }

    /// The cue's name, or what woke it when the cue has no name of its own.
    private var title: String {
        cueName ?? "When \(model.vocabulary.clause(of: run.hook))"
    }

    private var cueName: String? {
        run.cueName.flatMap { $0 == run.hook.rawValue ? nil : $0 }
    }

    /// How long it took, the tokens sent (up) and received (down), and the cost.
    private var usage: some View {
        HStack(spacing: 12) {
            if let duration {
                Text(duration)
            }
            Label(tokenCount(run.inputTokens), systemImage: "arrow.up")
                .accessibilityLabel("\(tokenCount(run.inputTokens)) input tokens")
            Label(tokenCount(run.outputTokens), systemImage: "arrow.down")
                .accessibilityLabel("\(tokenCount(run.outputTokens)) output tokens")
            if let cost = run.cost {
                Text(usd(cost))
            }
        }
        .labelStyle(.titleAndIcon)
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }

    private var duration: String? {
        let endedAt: Date
        switch run.state {
        case .running: return nil
        case .completed(let at), .failed(let at, _): endedAt = at
        }
        let seconds = Int(endedAt.timeIntervalSince(run.startedAt))
        return seconds < 60 ? "\(seconds)s" : "\(Int((Double(seconds) / 60).rounded()))m"
    }

    @ViewBuilder
    private var outcomeIcon: some View {
        switch run.state {
        case .running:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Running")
        case .completed:
            Image(systemName: AgentRun.State.completedSymbol)
                .foregroundStyle(AgentRun.State.completedTint)
                .accessibilityLabel("Completed")
        case .failed:
            Image(systemName: AgentRun.State.failedSymbol)
                .foregroundStyle(AgentRun.State.failedTint)
                .accessibilityLabel("Failed")
        }
    }
}
