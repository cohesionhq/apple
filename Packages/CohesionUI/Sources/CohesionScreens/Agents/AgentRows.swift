import CohesionCore
import CohesionUI
import SwiftUI

/// What the agents' menus do, wherever the agents are listed: pinning,
/// moving between teams, and a team's rename and delete.
public struct AgentActions {
    public var setPinned: (Agent, Bool) -> Void = { _, _ in }
    public var setTeam: (Agent, Int?) -> Void = { _, _ in }
    /// Names a new team, moving the agent given onto it.
    public var newTeam: (Agent?) -> Void = { _ in }
    public var renameTeam: (AgentTeam) -> Void = { _ in }
    public var deleteTeam: (AgentTeam) -> Void = { _ in }

    public init(
        setPinned: @escaping (Agent, Bool) -> Void = { _, _ in },
        setTeam: @escaping (Agent, Int?) -> Void = { _, _ in },
        newTeam: @escaping (Agent?) -> Void = { _ in },
        renameTeam: @escaping (AgentTeam) -> Void = { _ in },
        deleteTeam: @escaping (AgentTeam) -> Void = { _ in }
    ) {
        self.setPinned = setPinned
        self.setTeam = setTeam
        self.newTeam = newTeam
        self.renameTeam = renameTeam
        self.deleteTeam = deleteTeam
    }
}

/// The unpinned agents on one team, or on none.
public struct AgentGroup: Identifiable {
    public let team: AgentTeam?
    public let agents: [Agent]

    public var id: Int? { team?.id }

    /// The unpinned agents under each team with any, in the teams' order,
    /// then those on no team; `nil` when no team has an unpinned agent, so
    /// the list stays as it is without teams. A pinned agent shows only
    /// with the pinned, whatever its team.
    public static func groups(of agents: [Agent], teams: [AgentTeam]?) -> [AgentGroup]? {
        guard let teams else { return nil }
        let unpinned = agents.filter { !$0.isPinned }
        let groups = teams.compactMap { team in
            let members = unpinned.filter { $0.teamID == team.id }
            return members.isEmpty ? nil : AgentGroup(team: team, agents: members)
        }
        guard !groups.isEmpty else { return nil }
        let unteamed = unpinned.filter { agent in !teams.contains { $0.id == agent.teamID } }
        return unteamed.isEmpty ? groups : groups + [AgentGroup(team: nil, agents: unteamed)]
    }
}

/// Where `AgentSections` is listed, which decides whether its section collapses,
/// what it lists and which actions it has. The team menu is the same in each.
public enum AgentSectionLayout {
    /// A tab's list, which doesn't collapse. The pinned are left out, for the
    /// tab's `PinnedAgents` above it, and the tab's toolbar makes new agents.
    case list
    /// A sidebar's, which collapses, remembered across launches, with New Agent
    /// as a section action.
    case sidebar(newAgent: () -> Void)
}

/// One Agents section in every shell: the pinned first, unless a tab's grid has
/// them, then each team's, then those on no team, a row's team as its subline.
/// The layout is the shell's.
public struct AgentSections<Link: Hashable>: View {
    public let layout: AgentSectionLayout
    public let agents: [Agent]
    /// `nil` when the daemon has no teams.
    public let teams: [AgentTeam]?
    public let actions: AgentActions
    public let link: (Agent) -> Link

    public init(
        layout: AgentSectionLayout,
        agents: [Agent],
        teams: [AgentTeam]?,
        actions: AgentActions,
        link: @escaping (Agent) -> Link
    ) {
        self.layout = layout
        self.agents = agents
        self.teams = teams
        self.actions = actions
        self.link = link
    }

    /// Whether the user collapsed the section. Stored by hand rather than with
    /// `@AppStorage`, which drops the section's animation.
    @State private var isCollapsed = UserDefaults.standard.bool(forKey: collapsedKey) {
        didSet { UserDefaults.standard.set(isCollapsed, forKey: Self.collapsedKey) }
    }

    // Computed, since a generic type can't store a static.
    private static var collapsedKey: String { "agentsCollapsed" }

    private var isExpanded: Binding<Bool> {
        Binding { !isCollapsed } set: { isCollapsed = !$0 }
    }

    public var body: some View {
        switch layout {
        case .list:
            Section {
                unpinnedRows
            } header: {
                Text("Agents")
            }
            .sectionActions {
                teamsMenu
            }
        case .sidebar(let newAgent):
            Section(isExpanded: isExpanded) {
                rows(agents.filter(\.isPinned), team: { agent in teams?.first { $0.id == agent.teamID } })
                unpinnedRows
            } header: {
                Text("Agents")
            }
            .sectionActions {
                Button("New Agent", systemImage: "plus", action: newAgent)
                teamsMenu
            }
        }
    }

    /// Every team's rename and delete, once there are teams.
    @ViewBuilder
    private var teamsMenu: some View {
        if let teams, !teams.isEmpty {
            Menu("Teams", systemImage: "person.2") {
                TeamMenuItems(teams: teams, actions: actions)
            }
        }
    }

    @ViewBuilder
    private var unpinnedRows: some View {
        if let groups = AgentGroup.groups(of: agents, teams: teams) {
            ForEach(groups) { group in
                rows(group.agents, team: { _ in group.team })
            }
        } else {
            rows(agents.filter { !$0.isPinned }, team: { _ in nil })
        }
    }

    private func rows(_ agents: [Agent], team: @escaping (Agent) -> AgentTeam?) -> some View {
        ForEach(agents) { agent in
            NavigationLink(value: link(agent)) {
                AgentRow(agent: agent, team: team(agent))
            }
            .contextMenu {
                AgentMenuItems(agent: agent, actions: actions)
            }
        }
    }
}

/// Every team, each opening its rename and delete, so a team with no agents to
/// list can be reached too.
struct TeamMenuItems: View {
    let teams: [AgentTeam]
    let actions: AgentActions

    var body: some View {
        ForEach(teams) { team in
            Menu(team.title) {
                Button("Rename…", systemImage: "pencil") { actions.renameTeam(team) }
                Button("Delete…", systemImage: "trash", role: .destructive) { actions.deleteTeam(team) }
            }
        }
    }
}

/// An agent's menu: pin or unpin it, and the team it's on.
public struct AgentMenuItems: View {
    public let agent: Agent
    public let actions: AgentActions

    public init(agent: Agent, actions: AgentActions) {
        self.agent = agent
        self.actions = actions
    }

    @Environment(\.agentTeams) private var teams

    public var body: some View {
        Button(agent.isPinned ? "Unpin" : "Pin", systemImage: agent.isPinned ? "pin.slash" : "pin") {
            actions.setPinned(agent, !agent.isPinned)
        }
        if let teams {
            MoveToTeamMenu(agent: agent, teams: teams) { teamID in
                actions.setTeam(agent, teamID)
            } newTeam: {
                actions.newTeam(agent)
            }
        }
    }
}

/// An agent as every shell lists it, as the web's sidebar does: its avatar
/// where a row's symbol goes, its name, which shimmers while it works, its team
/// beneath it, a pin if it's pinned, and a dot while unread.
public struct AgentRow: View {
    public let agent: Agent
    public let team: AgentTeam?

    public init(agent: Agent, team: AgentTeam? = nil) {
        self.agent = agent
        self.team = team
    }

    /// About a sidebar symbol's size, growing with the name beside it.
    @ScaledMetric(relativeTo: .body) private var diameter = 28

    public var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading) {
                    Text(agent.name)
                        .fontWeight(agent.isUnread ? .semibold : .regular)
                        .lineLimit(1)
                        .workingShimmer(agent.isWorking, dimmed: 0.35)
                        // The row has no words to say so.
                        .accessibilityValue(agent.isWorking ? "Working" : "")
                    if let team {
                        Text(team.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } icon: {
                AgentAvatar(agent: agent, diameter: diameter, fit: .symbol)
            }
            Spacer(minLength: 0)
            if agent.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Pinned")
            }
            AgentUnreadDot(agent: agent)
        }
    }
}

/// An accent dot while the agent is unread.
private struct AgentUnreadDot: View {
    let agent: Agent

    var body: some View {
        if agent.isUnread {
            Circle()
                .fill(.tint)
                .frame(width: 8, height: 8)
                .accessibilityLabel("Unread")
        }
    }
}

/// The pinned agents as a grid of large avatars, three to a row, as Messages
/// shows pinned conversations, each named in secondary text. An unread one
/// has a dot after its name; a working one's name shimmers. Each avatar spans
/// most of its column, so it grows with the width there is. Its avatars are
/// plain-styled menus, so in a list row each is its own target rather than
/// the row being one.
public struct PinnedAgents<Actions: View>: View {
    public let agents: [Agent]
    public let open: (Agent) -> Void
    /// What the agent's menu offers under its name.
    @ViewBuilder public let actions: (Agent) -> Actions

    public init(
        agents: [Agent],
        open: @escaping (Agent) -> Void,
        @ViewBuilder actions: @escaping (Agent) -> Actions
    ) {
        self.agents = agents
        self.open = open
        self.actions = actions
    }

    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 8) {
            ForEach(agents) { agent in
                // A menu rather than a context menu, which a section header
                // doesn't open. It covers the avatar, so it leads with the
                // agent's own.
                Menu {
                    Section {
                        Label {
                            Text(agent.name)
                            if !agent.status.isEmpty { Text(agent.status) }
                        } icon: {
                            AgentAvatar.menuImage(of: agent, scale: displayScale)
                        }
                    }
                    actions(agent)
                } label: {
                    VStack(spacing: 6) {
                        GeometryReader { column in
                            AgentAvatar(agent: agent, diameter: column.size.width * Self.span)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .aspectRatio(1 / Self.span, contentMode: .fit)
                        HStack(spacing: 4) {
                            Text(agent.name)
                                .font(.footnote)
                                .fontWeight(agent.isUnread ? .semibold : .regular)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .workingShimmer(agent.isWorking)
                                .accessibilityValue(agent.isWorking ? "Working" : "")
                            AgentUnreadDot(agent: agent)
                        }
                    }
                    // Below only, so the first row sits close under the
                    // navigation bar.
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect(cornerRadius: 12))
                } primaryAction: {
                    open(agent)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
            }
        }
    }

    @Environment(\.displayScale) private var displayScale

    /// How much of its column an avatar spans.
    private static var span: CGFloat { 0.78 }
}

extension AgentAvatar {
    public init(agent: Agent, diameter: CGFloat = 40, fit: Fit = .standard) {
        self.init(name: agent.name, emoji: agent.emoji, color: agent.color, diameter: diameter, fit: fit)
    }
}
