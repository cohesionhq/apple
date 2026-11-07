import CohesionCore
import CohesionUI
import SwiftUI

extension EnvironmentValues {
    /// Every team of agents, by title; `nil` when the daemon has no teams,
    /// which hides everything about them.
    @Entry public var agentTeams: [AgentTeam]?
}

/// "Move To" in an agent's menu: each team, checked for the one it's on,
/// then no team, then a new one to move it onto.
public struct MoveToTeamMenu: View {
    public let agent: Agent
    public let teams: [AgentTeam]
    public let move: (Int?) -> Void
    public let newTeam: () -> Void

    public var body: some View {
        Menu("Move To", systemImage: "person.2") {
            Picker("Team", selection: Binding(get: { agent.teamID }, set: { if $0 != agent.teamID { move($0) } })) {
                ForEach(teams) { team in
                    Text(team.title).tag(Int?.some(team.id))
                }
                Text("No Team").tag(Int?.none)
            }
            .pickerStyle(.inline)
            Button("New Team…", systemImage: "plus", action: newTeam)
        }
    }
}

/// A team being named in `teamDialogs`: a new one, which the agent given
/// moves onto once it exists, or one being renamed.
public enum TeamNaming: Hashable, Identifiable {
    case new(moving: Agent?)
    case rename(AgentTeam)

    public var id: Self { self }
}

extension View {
    /// Names a new team or renames one in an alert, and deletes one after
    /// a confirmation, calling `onChange` once cohesiond has done it.
    public func teamDialogs(
        naming: Binding<TeamNaming?>,
        deleting: Binding<AgentTeam?>,
        onChange: @escaping () async -> Void
    ) -> some View {
        modifier(TeamDialogs(naming: naming, deleting: deleting, onChange: onChange))
    }
}

private struct TeamDialogs: ViewModifier {
    @Binding var naming: TeamNaming?
    @Binding var deleting: AgentTeam?
    let onChange: () async -> Void

    @Environment(AppModel.self) private var model

    @State private var title = ""
    @State private var error: (any Error)?

    func body(content: Content) -> some View {
        content
            .onChange(of: naming) {
                if case .rename(let team) = naming { title = team.title } else { title = "" }
            }
            .alert(
                { if case .rename = naming { "Rename Team" } else { "New Team" } }(),
                isPresented: Binding(get: { naming != nil }, set: { if !$0 { naming = nil } }),
                presenting: naming
            ) { naming in
                TextField("Title", text: $title)
                Button("Cancel", role: .cancel) {}
                Button({ if case .rename = naming { "Rename" } else { "Create" } }()) { save(naming) }
                    .disabled(trimmedTitle.isEmpty)
            } message: { naming in
                if case .new(let agent?) = naming {
                    Text("\(agent.name) moves onto it.")
                }
            }
            .confirmationDialog(
                "Delete “\(deleting?.title ?? "")”?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible,
                presenting: deleting
            ) { team in
                Button("Delete Team", role: .destructive) {
                    run { try await $0.delete(team) }
                }
            } message: { _ in
                Text("Its agents stay, on no team, and its memories are forgotten.")
            }
            .errorAlert($error)
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespaces) }

    private func save(_ naming: TeamNaming) {
        let title = trimmedTitle
        switch naming {
        case .new(let agent):
            run { client in
                let team = try await client.createAgentTeam(title)
                if let agent { _ = try await client.setTeam(of: agent, to: team.id) }
            }
        case .rename(let team):
            guard title != team.title else { return }
            run { _ = try await $0.rename(team, to: title) }
        }
    }

    private func run(_ action: @escaping (CohesionClient) async throws -> Void) {
        guard let client = model.client else { return }
        Task {
            do {
                try await action(client)
            } catch {
                self.error = error
            }
            await onChange()
        }
    }
}
