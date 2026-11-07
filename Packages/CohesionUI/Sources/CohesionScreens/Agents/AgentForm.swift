import CohesionCore
import CohesionUI
import SwiftUI

/// Creates an agent, or edits one on its Identity page: its name, emoji, color, team (once there
/// are teams), personality and verbosity. Creating is a sheet, so it brings its own navigation and
/// Cancel; editing is pushed from the agent's sheet, and also shows the agent's role.
struct AgentForm: View {
    /// The agent to edit; `nil` to create one.
    let agent: Agent?
    let onSave: (Agent) async -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.agentTeams) private var teams

    @State private var name: String
    @State private var emoji: String
    @State private var color: AgentColor
    @State private var personality: AgentPersonality
    @State private var verbosity: AgentVerbosity
    @State private var teamID: Int?
    @State private var isSaving = false
    @State private var error: (any Error)?

    init(agent: Agent? = nil, onSave: @escaping (Agent) async -> Void) {
        self.agent = agent
        self.onSave = onSave
        _name = State(initialValue: agent?.name ?? "")
        _emoji = State(initialValue: agent?.emoji ?? "")
        _color = State(initialValue: agent?.color ?? .blue)
        _personality = State(initialValue: agent?.personality ?? .balanced)
        _verbosity = State(initialValue: agent?.verbosity ?? .brief)
        _teamID = State(initialValue: agent?.teamID)
    }

    var body: some View {
        if agent == nil {
            NavigationStack { form }
        } else {
            form
        }
    }

    private var form: some View {
        Form {
            if let agent, !agent.role.isEmpty {
                Section("Role") {
                    Text(agent.role)
                }
            }
            Section {
                // A new agent left unnamed gets a name from cohesiond.
                TextField(agent == nil ? "Name (optional)" : "Name", text: $name)
                TextField("Emoji (optional)", text: $emoji)
            } footer: {
                Text("The emoji shows in place of the name’s initial.")
            }
            Section("Color") {
                HStack {
                    ForEach(model.vocabulary.agentColors, id: \.kind) { wording in
                        let option = wording.kind
                        Button {
                            color = option
                        } label: {
                            Circle()
                                .fill(option.color.gradient)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if option == color {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(wording.label)
                        .accessibilityAddTraits(option == color ? .isSelected : [])
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            if let teams, !teams.isEmpty {
                Section {
                    Picker("Team", selection: $teamID) {
                        ForEach(teams) { team in
                            Text(team.title).tag(Int?.some(team.id))
                        }
                        Text("No Team").tag(Int?.none)
                    }
                }
            }
            Section {
                Picker("Personality", selection: $personality) {
                    ForEach(model.vocabulary.agentPersonalities, id: \.kind) { option in
                        Text(option.label).tag(option.kind)
                    }
                }
                Picker("Verbosity", selection: $verbosity) {
                    ForEach(model.vocabulary.agentVerbosities, id: \.kind) { option in
                        Text(option.label).tag(option.kind)
                    }
                }
            }
        }
        .navigationTitle(agent == nil ? "New Agent" : "Identity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if agent == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(agent == nil ? "Create" : "Save", systemImage: "checkmark", role: .confirm, action: save)
                    .disabled(!canSave)
            }
        }
        .errorAlert($error)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var trimmedEmoji: String { emoji.trimmingCharacters(in: .whitespaces) }

    private var canSave: Bool {
        guard !isSaving else { return false }
        guard let agent else { return true }
        return !trimmedName.isEmpty && (isEdited(agent) || teamID != agent.teamID)
    }

    /// Whether anything `updateIntelligenceAgent` sets differs from `agent`.
    private func isEdited(_ agent: Agent) -> Bool {
        trimmedName != agent.name
            || color != agent.color
            || trimmedEmoji != (agent.emoji ?? "")
            || personality != agent.personality
            || verbosity != agent.verbosity
    }

    private func save() {
        guard let client = model.client else { return }
        isSaving = true
        Task {
            do {
                var saved: Agent
                if let agent {
                    saved = agent
                    if isEdited(agent) {
                        saved = try await client.update(
                            agent,
                            name: trimmedName,
                            color: color,
                            emoji: trimmedEmoji,
                            personality: personality,
                            verbosity: verbosity
                        )
                    }
                    if teamID != agent.teamID { saved = try await client.setTeam(of: agent, to: teamID) }
                } else {
                    saved = try await client.createAgent(
                        name: trimmedName,
                        color: color,
                        emoji: trimmedEmoji.isEmpty ? nil : trimmedEmoji,
                        personality: personality,
                        verbosity: verbosity,
                        teamID: teamID
                    )
                }
                await onSave(saved)
                dismiss()
            } catch {
                self.error = error
            }
            isSaving = false
        }
    }
}
