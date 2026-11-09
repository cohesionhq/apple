import CohesionCore
import CohesionUI
import SwiftUI

/// A sheet about one agent: how much its conversation holds, then a page each
/// for its identity, memories, usage, cues and runs, with delete.
struct AgentInfoView: View {
    let agent: Agent
    /// Called after an edit or delete, so the agent list catches up.
    let onChange: () async -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    /// The agent's `contextTokens`, kept current while the sheet is open.
    @State private var contextTokens: Int?
    @State private var isConfirmingDelete = false
    @State private var error: (any Error)?

    init(agent: Agent, onChange: @escaping () async -> Void) {
        self.agent = agent
        self.onChange = onChange
        _contextTokens = State(initialValue: agent.contextTokens)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    identity
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                context
                Section {
                    NavigationLink {
                        AgentForm(agent: agent) { _ in await onChange() }
                    } label: {
                        Label("Identity", systemImage: "person.text.rectangle.fill", color: .blue)
                    }
                    NavigationLink {
                        MemoriesView(agent: agent)
                    } label: {
                        Label("Memories", systemImage: "brain", color: .pink)
                    }
                    NavigationLink {
                        AgentUsageView(agent: agent)
                    } label: {
                        Label("Usage", systemImage: "chart.bar.fill", color: .green)
                    }
                    NavigationLink {
                        AgentCuesView(agent: agent)
                    } label: {
                        Label("Cues", systemImage: "alarm.fill", color: .teal)
                    }
                    NavigationLink {
                        AgentRunsView(agent: agent)
                    } label: {
                        Label("Runs", systemImage: "bolt.fill", color: .purple)
                    }
                }
                Section {
                    Button("Delete Agent", role: .destructive) {
                        isConfirmingDelete = true
                    }
                }
            }
            // Named in the header under the avatar; the bar's title is
            // for VoiceOver and the window.
            .navigationTitle(agent.name)
            .navigationBarTitleDisplayMode(.inline)
            #if os(iOS)
            .toolbar(removing: .title)
            #endif
            .toolbar {
                // Nothing here waits to be saved, so it closes rather than confirms.
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", role: .close) { dismiss() }
                }
            }
            .task { await watchContext() }
            .refreshable { await loadContext(.asked) }
            .confirmationDialog(
                "Delete \(agent.name)?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete Agent", role: .destructive, action: delete)
            } message: {
                Text("Deletes its conversation and runs. Can’t be undone.")
            }
            .errorAlert($error)
        }
    }

    /// The agent as its chat's header draws it, larger: its avatar over its
    /// name and role, as the system's contact cards open.
    private var identity: some View {
        VStack(spacing: 8) {
            AgentAvatar(agent: agent, diameter: 72)
            Text(agent.name)
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if !agent.role.isEmpty {
                Text(agent.role)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    /// What the conversation's live thread held at its latest request: the
    /// count and "tokens" on the one line, as a row's value is, or a dash
    /// when there's none to show. The count rolls to each new value as a turn
    /// works.
    private var context: some View {
        Section {
            LabeledContent("Context") {
                HStack(spacing: 4) {
                    Text(contextTokens.map(tokenCount) ?? "—")
                        .contentTransition(.numericText(value: Double(contextTokens ?? 0)))
                    if contextTokens != nil {
                        Text("tokens")
                    }
                }
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Context")
            .accessibilityValue(contextTokens.map { "\(tokenCount($0)) tokens" } ?? "Unavailable")
        }
    }

    /// Keeps `contextTokens` current: it moves with each request of a turn,
    /// which cohesiond reports as a change to the agent.
    private func watchContext() async {
        guard let client = model.client else { return }
        for await origin in client.loads(matching: { [id = agent.id] in $0 == .agent(id) }) {
            await loadContext(origin)
        }
    }

    private func loadContext(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client else { return }
        await origin.run {
            let tokens = try await client.agent(agent.id).contextTokens
            withAnimation { contextTokens = tokens }
        } failed: { self.error = $0 }
    }

    private func delete() {
        guard let client = model.client else { return }
        Task {
            do {
                try await client.delete(agent)
                dismiss()
                await onChange()
            } catch {
                self.error = error
            }
        }
    }
}

/// "850", "12K", "1.2M", as the web app writes token counts.
func tokenCount(_ count: Int) -> String {
    if count >= 1_000_000 {
        return (Double(count) / 1_000_000).formatted(.number.precision(.fractionLength(0...1))) + "M"
    }
    if count >= 1_000 { return "\(Int((Double(count) / 1_000).rounded()))K" }
    return String(count)
}

/// "$3.00"; amounts under a cent keep two significant digits ("$0.0042").
func usd(_ amount: Double) -> String {
    if amount > 0 && amount < 0.01 {
        return "$" + amount.formatted(.number.precision(.significantDigits(2)))
    }
    return "$" + amount.formatted(.number.precision(.fractionLength(2)))
}
