import CohesionCore
import CohesionScreens
import CohesionUI
import SwiftUI

/// The iPad's sidebar: the workspace's pages (Dashboard, Today, Journal,
/// Documents, Contacts) with one Tasks row after them, then the agents and the
/// actor sessions, then the kinds of resource it shows and the feeds, each a
/// section that collapses, with Settings in its bar. The workspace's name
/// heads it, and picks another.
struct Sidebar: View {
    @Binding var selection: SidebarItem?
    let folders: [TaskFolder]
    /// The workspace's saved task views, in their order.
    let savedViews: [SavedTaskView]
    let feeds: [FeedSummary]
    /// The kinds of resource the workspace shows, in their order.
    let kinds: [ConnectorKind]
    let moveKinds: (IndexSet, Int) -> Void
    let editKinds: () -> Void
    let agents: [Agent]
    /// `nil` when the daemon has no teams.
    let teams: [AgentTeam]?
    let actors: [Actor]
    /// Every actor's sessions; the sidebar lists the current ones.
    let actorSessions: [ActorSession]
    /// The plan usage the actors report, for the overflow menu.
    let actorUsage: [ActorUsage]
    let agentActions: AgentActions
    let moveSavedViews: (IndexSet, Int) -> Void
    let moveFeeds: (IndexSet, Int) -> Void
    let addFeed: () -> Void
    let newAgent: () -> Void
    let newActorSession: () -> Void
    let resolveActorSession: (ActorSession) -> Void
    let showActorUsage: () -> Void
    let showSettings: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(WindowModel.self) private var window

    var body: some View {
        @Bindable var window = window

        List(selection: $selection) {
            SidebarSections(
                folders: folders,
                savedViews: savedViews,
                feeds: feeds,
                kinds: kinds,
                moveKinds: moveKinds,
                editKinds: editKinds,
                agents: agents,
                teams: teams,
                actors: actors,
                actorSessions: actorSessions,
                agentActions: agentActions,
                moveSavedViews: moveSavedViews,
                moveFeeds: moveFeeds,
                addFeed: addFeed,
                newAgent: newAgent,
                newActorSession: newActorSession,
                resolveActorSession: resolveActorSession
            )
        }
        .navigationTitle(window.selectedWorkspace?.displayName ?? "Cohesion")
        // Inline, so the title shows the chevron that opens the workspace menu.
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleMenu {
            Picker("Workspace", selection: $window.selectedWorkspaceID) {
                ForEach(model.workspaces) { workspace in
                    Text(workspace.displayName).tag(Optional(workspace.id))
                }
            }
        }
        .toolbar {
            // In the bar beside the overflow menu, as on the iPhone's tabs,
            // rather than a bottom bar that floats over the last rows. The
            // last to leave a narrow sidebar's bar, and then into the
            // overflow menu beside Actor Usage.
            ToolbarItem(placement: .primaryAction) {
                SettingsButton(action: showSettings)
            }
            .visibilityPriority(.high)
            ActorUsageMenu(actors: actors, usage: actorUsage, show: showActorUsage)
        }
    }
}

#Preview("Sidebar") {
    @Previewable @State var selection: SidebarItem? = .agent(2)
    let app = AppModel()

    // A stack rather than a split view, which a phone's width collapses.
    NavigationStack {
        Sidebar(
            selection: $selection,
            folders: [TaskFolder(id: 1, title: "Home"), TaskFolder(id: 2, title: "Work")],
            savedViews: [],
            feeds: [
                .preview(id: 1, title: "Daring Fireball", unread: 12),
                .preview(id: 2, title: "Six Colors", unread: 3),
            ],
            kinds: [],
            moveKinds: { _, _ in },
            editKinds: {},
            agents: [
                .preview(id: 1, name: "Ada", emoji: "🦉", color: .purple, isPinned: true),
                .preview(id: 2, name: "Bea", emoji: nil, color: .green, isUnread: true),
                .preview(id: 3, name: "Cal", emoji: "🛠️", color: .orange, isWorking: true),
            ],
            teams: [],
            actors: [],
            actorSessions: [],
            actorUsage: [],
            agentActions: AgentActions(),
            moveSavedViews: { _, _ in },
            moveFeeds: { _, _ in },
            addFeed: {},
            newAgent: {},
            newActorSession: {},
            resolveActorSession: { _ in },
            showActorUsage: {},
            showSettings: {}
        )
        .listStyle(.sidebar)
    }
    .environment(\.tasksAreOneRow, true)
    .environment(app)
    .environment(WindowModel(app: app, workspaceID: nil))
}

#Preview("Workspace Tab") {
    let app = AppModel()

    NavigationStack {
        List {
            WorkspaceSections(
                folders: [TaskFolder(id: 1, title: "Home"), TaskFolder(id: 2, title: "Work")],
                savedViews: [],
                feeds: nil,
                kinds: [],
                moveSavedViews: { _, _ in },
                moveKinds: { _, _ in },
                editKinds: {}
            ) { $0 }
        }
        .tabRootToolbar()
    }
    .environment(app)
    .environment(WindowModel(app: app, workspaceID: nil))
}

extension FeedSummary {
    /// A feed for previews.
    fileprivate static func preview(id: Int, title: String, unread: Int) -> FeedSummary {
        FeedSummary(
            id: id,
            url: URL(string: "https://example.com/feed")!,
            title: title,
            fullPagePolicy: .whenExcerpt,
            status: .refreshed(at: .now, added: 0),
            unread: unread
        )
    }
}

extension Agent {
    /// An agent for previews, decoded as cohesiond sends one.
    fileprivate static func preview(
        id: Int,
        name: String,
        emoji: String?,
        color: AgentColor,
        isPinned: Bool = false,
        isUnread: Bool = false,
        isWorking: Bool = false
    ) -> Agent {
        let json: [String: Any?] = [
            "id": id, "agent_name": name, "agent_color": color.rawValue, "agent_emoji": emoji,
            "agent_personality": "balanced", "agent_verbosity": "brief", "agent_role": "",
            "activity": isWorking ? "Thinking" : nil, "agent_unread": isUnread, "pinned": isPinned,
        ]
        let data = try! JSONSerialization.data(withJSONObject: json.compactMapValues { $0 })
        return try! JSONDecoder().decode(Agent.self, from: data)
    }
}
