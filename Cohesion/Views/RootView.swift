import CohesionCore
import CohesionScreens
import CohesionUI
import SwiftUI
import WidgetKit

/// The iPhone's four tabs: the Dashboard first, where the app opens, then the
/// agents and actor sessions, then the workspace's pages and the feeds, in the
/// web's order.
enum RootTab: Hashable {
    case dashboard
    /// The agents, then the actor sessions.
    case intelligence
    case workspace
    case feeds
}

/// What the Workspace tab pushes on iPhone: one of the workspace's pages, or a
/// contact from its contacts.
enum WorkspaceRoute: Hashable {
    case page(WorkspacePage)
    case contact(Int)
}

/// What the Intelligence and Dashboard tabs push on iPhone: a conversation, or
/// an actor session.
enum AgentsRoute: Hashable {
    case agent(Int)
    case actorSession(Int)
}

/// On iPhone, four tabs: the Dashboard, where the app opens, with no
/// navigation bar; Intelligence, the agents and actor sessions; then, in the
/// web's order, Workspace, whose first screen is the workspace's pages as the
/// iPad's sidebar lists them, the Dashboard and feeds aside, and Feeds.
/// Each pushes what's opened from it; an agent's chat, and an actor
/// session's, hides the tab bar, so its composer is alone at the bottom. On
/// iPad, two columns: the `Sidebar`, laid out as the web's, and whatever
/// is open from it. A window resized between the two keeps what it shows.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(WindowModel.self) private var window
    @Environment(PushRegistration.self) private var push
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase

    @State private var tab = RootTab.dashboard
    /// What the Dashboard tab has opened from it, on iPhone.
    @State private var dashboardPath: [AgentsRoute] = []
    /// What the Workspace tab has open, on iPhone.
    @State private var workspacePath: [WorkspaceRoute] = []
    /// The feed whose articles the Feeds tab shows, on iPhone.
    @State private var feedPath: [ArticleListFilter] = []
    /// The open conversation, on iPhone. Stored rather than derived for the
    /// stack, which a binding made afresh on each render unsettles under the
    /// open chat.
    @State private var agentPath: [AgentsRoute] = []
    /// The open contact's id on the Contacts list's stack, on iPad.
    @State private var contactPath: [Int] = []
    /// What's open beside the sidebar, on iPad.
    @State private var selection: SidebarItem?
    @State private var isShowingSettings = false
    /// A task or document link from outside the app, for
    /// `presentsLinkedItems` to show over whatever is open.
    @State private var linkRequest: AppLink?

    var body: some View {
        @Bindable var window = window

        return Group {
            if sizeClass == .compact {
                tabs
            } else {
                NavigationSplitView {
                    sidebar
                } detail: {
                    detail
                }
                // The sidebar stays beside what's open in portrait too, rather
                // than over it, as the web's does.
                .navigationSplitViewStyle(.balanced)
                // Set here, where the window's size class is what's asked,
                // rather than read from inside a column.
                .environment(\.tasksAreOneRow, true)
            }
        }
        .environment(\.isShowingSettings, $isShowingSettings)
        // ⌘, opens settings in the window it's pressed in.
        .focusedSceneValue(\.isShowingSettings, $isShowingSettings)
        // As does ⇧⌘D the Dashboard.
        .focusedSceneValue(\.showDashboard, ShowDashboardAction(action: showDashboard))
        .task {
            if let client = model.client {
                await push.refresh(using: client)
                await push.reportMissingLiveActivity(using: client)
            }
        }
        // The Tasks widget shows these, however it's set up.
        .task {
            guard let client = model.client else { return }
            for await _ in client.changes(matching: {
                switch $0 {
                case .taskList, .taskFolders, .tags, .savedTaskViews: true
                default: false
                }
            }) {
                WidgetCenter.shared.reloadTimelines(ofKind: "Tasks")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Anything may have changed while the app was away.
            guard phase == .active else { return }
            openPendingLink()
            Task {
                await window.load()
                await window.loadActors()
            }
            if let client = model.client {
                Task {
                    await push.refresh(using: client)
                    await push.reportMissingLiveActivity(using: client)
                }
            }
        }
        .onChange(of: model.pendingLink, initial: true) { openPendingLink() }
        // A Live Activity, a widget or a link opens in the window it's sent to.
        .onOpenURL { url in
            if let link = AppLink(url: url) { open(link) }
        }
        .onAppear {
            // Side by side, an empty detail column is wasted; start on the Dashboard.
            if sizeClass == .regular && selection == nil { selection = .page(.dashboard) }
        }
        .onChange(of: sizeClass) { _, sizeClass in
            // A window resized between tabs and the sidebar keeps what it shows.
            if sizeClass == .compact { showInTabs() } else { showInSidebar() }
        }
        .onChange(of: window.selectedWorkspaceID) {
            // The pages open belong to the workspace left; the feeds are every
            // workspace's, so the Feeds tab stays. Beside a sidebar, a workspace
            // opens on its Dashboard, as on the web; the Dashboard tab just
            // shows the new one.
            dashboardPath = []
            workspacePath = []
            contactPath = []
            window.lastTaskPage = .tasks(.inbox)
            switch selection {
            case .agent, .actorSession: break
            case .page, nil: selection = .page(.dashboard)
            }
        }
        .onChange(of: window.listings) { closeWhatsGone() }
        .onChange(of: agentPath) {
            // Opening a conversation marks it read.
            Task { await window.loadAgents() }
        }
        .onChange(of: dashboardPath) {
            Task { await window.loadAgents() }
        }
        .onChange(of: selection) {
            if case .page(let page) = selection, page.isTaskList { window.lastTaskPage = page }
            Task { await window.loadAgents() }
        }
        .onChange(of: window.agents) {
            // The Agents widget shows the unread ones.
            WidgetCenter.shared.reloadTimelines(ofKind: "Agents")
        }
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack { SettingsView() }
        }
        .windowSheets(
            window,
            openFeed: { id in
                feedPath = [.feed(id)]
                selection = .page(.articles(.feed(id)))
            },
            openActorSession: open(sessionID:),
            openContact: open(contactID:),
            openAgent: open(agentID:)
        )
        .contactPicker(isPresented: $window.isPickingContact) { window.newContact = $0 }
        .presentsLinkedItems(request: $linkRequest)
        .windowTitle(windowTitle)
        .environment(\.openURL, OpenURLAction { url in
            window.follow(url, openAgent: open(agentID:), openActorSession: open(sessionID:), openAgents: openAgents) {
                linkRequest = $0
            }
        })
        .keepsWindowLists(window)
    }

    // MARK: iPhone

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Dashboard", systemImage: "rectangle.grid.1x2", value: .dashboard) {
                NavigationStack(path: $dashboardPath) {
                    page(.dashboard)
                        // Its greeting heads it; what it opens has a bar.
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationDestination(for: AgentsRoute.self, destination: conversationDestination)
                }
            }
            Tab("Intelligence", systemImage: "sparkles.2", value: .intelligence) {
                NavigationStack(path: $agentPath) {
                    agentList
                        .navigationDestination(for: AgentsRoute.self, destination: conversationDestination)
                }
            }
            .badge(window.agents.count { $0.isUnread })
            Tab("Workspace", systemImage: "square.grid.2x2", value: .workspace) {
                NavigationStack(path: $workspacePath) {
                    workspaceList
                        .navigationDestination(for: WorkspaceRoute.self, destination: workspaceDestination)
                }
            }
            Tab("Feeds", systemImage: "dot.radiowaves.up.forward", value: .feeds) {
                NavigationStack(path: $feedPath) {
                    feedList
                        .navigationDestination(for: ArticleListFilter.self) { self.page(.articles($0)) }
                }
            }
        }
    }

    @ViewBuilder
    private func conversationDestination(_ route: AgentsRoute) -> some View {
        switch route {
        case .agent(let id): pushedChat(id)
        case .actorSession(let id):
            actorSessionView(id)
                // The tab bar would sit under the composer.
                .background(HidesTabBar())
        }
    }

    @ViewBuilder
    private func workspaceDestination(_ route: WorkspaceRoute) -> some View {
        switch route {
        case .page(let page): self.page(page)
        case .contact(let id): ContactPage(contactID: id)
        }
    }

    /// The workspace's pages, as the iPad's sidebar leads with them.
    private var workspaceList: some View {
        List {
            WorkspaceSections(
                // In a tab of its own, as are the feeds.
                showsDashboard: false,
                folders: window.folders,
                savedViews: window.savedViews,
                // In a tab of their own.
                feeds: nil,
                kinds: window.shownKinds,
                moveSavedViews: window.moveSavedViews,
                moveKinds: window.moveShownKinds,
                editKinds: { window.isEditingKinds = true }
            ) { WorkspaceRoute.page($0) }
        }
        .tabRootToolbar()
        .refreshable { await window.load(.asked) }
    }

    /// Every feed together, then each, as the iPad's sidebar lists them.
    private var feedList: some View {
        List {
            FeedSection(feeds: window.feeds, moveFeeds: window.moveFeeds, addFeed: { window.isAddingFeed = true }) { $0 }
        }
        .navigationTitle("Feeds")
        .tabRootToolbar(showsWorkspaces: false)
        .refreshable { await window.load(.asked) }
    }

    private var agentList: some View {
        List {
            if !window.pinnedAgents.isEmpty {
                // A row of its own so it scrolls with the rest; a section
                // header would stick under the title and fade. Unheaded and
                // without the row's insets, as Messages shows its pins.
                Section {
                    PinnedAgents(agents: window.pinnedAgents, open: { agentPath = [.agent($0.id)] }) { agent in
                        AgentMenuItems(agent: agent, actions: window.agentActions)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                }
                // Under the list's 35pt above a first section, so the pins
                // sit as far under the navigation bar as their names sit
                // above the next section's title.
                .listSectionMargins(.top, 30)
            }
            AgentSections(
                layout: .list,
                agents: window.agents,
                teams: window.teams,
                actions: window.agentActions
            ) { AgentsRoute.agent($0.id) }
            ActorSessionsSection(actors: window.actors, sessions: window.actorSessions, resolve: window.resolve) { AgentsRoute.actorSession($0) }
        }
        .overlay {
            if window.agents.isEmpty && window.actors.isEmpty && window.actorSessions.isEmpty {
                ContentUnavailableView {
                    Label("No Agents", systemImage: "bubble.left.and.bubble.right")
                } actions: {
                    Button("New Agent") { window.isCreatingAgent = true }
                }
            }
        }
        // Untitled, with the tab naming it, and inline so no empty large
        // title sits over the list.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("New", systemImage: "plus") {
                    Button("New Agent", systemImage: "bubble.left.and.bubble.right") {
                        window.isCreatingAgent = true
                    }
                    if window.teams != nil {
                        Button("New Team", systemImage: "person.2") {
                            window.namingTeam = .new(moving: nil)
                        }
                    }
                    Button("New Session", systemImage: "apple.terminal") {
                        window.isStartingActorSession = true
                    }
                    .disabled(window.actors.isEmpty)
                }
            }
            ActorUsageMenu(actors: window.actors, usage: window.actorUsage) { window.isShowingActorUsage = true }
        }
        .tabRootToolbar(showsWorkspaces: false)
        .refreshable { await window.refresh() }
    }

    @ViewBuilder
    private func pushedChat(_ agentID: Int) -> some View {
        if let agent = window.agents.first(where: { $0.id == agentID }) {
            AgentChatView(agent: agent, onChange: window.loadAgents)
                // The tab bar would sit under the composer.
                .background(HidesTabBar())
                .id(agentID)
        }
    }

    // MARK: iPad

    private var sidebar: some View {
        Sidebar(
            selection: $selection,
            folders: window.folders,
            savedViews: window.savedViews,
            feeds: window.feeds,
            kinds: window.shownKinds,
            moveKinds: window.moveShownKinds,
            editKinds: { window.isEditingKinds = true },
            agents: window.agents,
            teams: window.teams,
            actors: window.actors,
            actorSessions: window.actorSessions,
            actorUsage: window.actorUsage,
            agentActions: window.agentActions,
            moveSavedViews: window.moveSavedViews,
            moveFeeds: window.moveFeeds,
            addFeed: { window.isAddingFeed = true },
            newAgent: { window.isCreatingAgent = true },
            newActorSession: { window.isStartingActorSession = true },
            resolveActorSession: window.resolve,
            showActorUsage: { window.isShowingActorUsage = true },
            showSettings: { isShowingSettings = true }
        )
    }

    @ViewBuilder
    private var detail: some View {
        Group {
            switch selection {
            case .page(.today):
                NavigationStack { page(.today) }
            case .page(.contacts):
                NavigationStack(path: $contactPath) {
                    page(.contacts)
                        .navigationDestination(for: Int.self) { ContactPage(contactID: $0) }
                }
                .listStyle(.plain)
            case .page(let page):
                // The lists fill the pane edge to edge, beside the sidebar,
                // rather than as cards.
                NavigationStack { self.page(page) }
                    .listStyle(.plain)
            case .agent(let id):
                if let agent = window.agents.first(where: { $0.id == id }) {
                    NavigationStack {
                        AgentChatView(agent: agent, onChange: window.loadAgents)
                    }
                }
            case .actorSession(let id):
                NavigationStack { actorSessionView(id) }
            case nil:
                ContentUnavailableView("Nothing Selected", systemImage: "sidebar.left")
            }
        }
        // A fresh list for each selection and workspace.
        .id([AnyHashable(selection), AnyHashable(window.selectedWorkspaceID)])
    }

    /// One of the workspace's pages: pushed in the Workspace tab on
    /// iPhone, beside the sidebar on iPad. A contact is pushed on the tab's
    /// stack on iPhone, by id on the detail's on iPad.
    @ViewBuilder
    private func page(_ page: WorkspacePage) -> some View {
        if sizeClass == .compact {
            WorkspacePageView(
                page: page,
                contactLink: { WorkspaceRoute.contact($0) },
                openSavedView: open,
                openPage: { workspacePath.append(.page($0)) },
                openAgent: { dashboardPath.append(.agent($0)) },
                openActorSession: { dashboardPath.append(.actorSession($0)) }
            )
        } else {
            WorkspacePageView(
                page: page,
                contactLink: { $0 },
                openSavedView: open,
                openPage: { selection = .page($0) },
                openAgent: { selection = .agent($0) },
                openActorSession: { selection = .actorSession($0) }
            )
        }
    }

    /// Opens in the tabs what the sidebar had open, as the window narrows.
    private func showInTabs() {
        switch selection {
        case .page(.dashboard):
            tab = .dashboard
            dashboardPath = []
        case .page(.contacts):
            tab = .workspace
            workspacePath = [.page(.contacts)] + contactPath.map(WorkspaceRoute.contact)
        case .page(.articles(let filter)):
            tab = .feeds
            feedPath = [filter]
        case .page(let page):
            tab = .workspace
            workspacePath = [.page(page)]
        case .agent(let id):
            tab = .intelligence
            agentPath = [.agent(id)]
        case .actorSession(let id):
            tab = .intelligence
            agentPath = [.actorSession(id)]
        case nil: tab = .dashboard
        }
    }

    /// Opens beside the sidebar what the tabs had open, as the window widens.
    private func showInSidebar() {
        switch tab {
        case .dashboard:
            switch dashboardPath.last {
            case .agent(let id): selection = .agent(id)
            case .actorSession(let id): selection = .actorSession(id)
            case nil: selection = .page(.dashboard)
            }
        case .workspace:
            switch workspacePath.last {
            case .page(let page): selection = .page(page)
            case .contact:
                selection = .page(.contacts)
                contactPath = workspacePath.compactMap { if case .contact(let id) = $0 { id } else { nil } }
            case nil: selection = .page(.dashboard)
            }
        case .feeds: selection = .page(.articles(feedPath.last ?? .allFeeds))
        case .intelligence:
            switch agentPath.last {
            case .agent(let id): selection = .agent(id)
            case .actorSession(let id): selection = .actorSession(id)
            case nil: if selection == nil { selection = .page(.dashboard) }
            }
        }
    }

    // MARK: Both

    /// What the window is titled: what it shows, as the web titles a page,
    /// so windows tell apart in the app switcher and Stage Manager.
    private var windowTitle: String {
        if sizeClass == .compact {
            switch tab {
            case .dashboard:
                switch dashboardPath.last {
                case .agent(let id): window.agentName(id)
                case .actorSession(let id): window.actorSessionTitle(id)
                case nil: "Dashboard"
                }
            case .workspace:
                switch workspacePath.last {
                case .page(let page): window.title(of: page)
                case .contact(let id): window.contactName(id)
                case nil: window.selectedWorkspace?.displayName ?? "Cohesion"
                }
            case .feeds: feedPath.last.map(window.title(of:)) ?? "Feeds"
            case .intelligence:
                switch agentPath.last {
                case .agent(let id): window.agentName(id)
                case .actorSession(let id): window.actorSessionTitle(id)
                case nil: "Intelligence"
                }
            }
        } else {
            switch selection {
            case .page(.contacts): contactPath.last.map(window.contactName) ?? "Contacts"
            case .page(let page): window.title(of: page)
            case .agent(let id): window.agentName(id)
            case .actorSession(let id): window.actorSessionTitle(id)
            case nil: window.selectedWorkspace?.displayName ?? "Cohesion"
            }
        }
    }

    /// Opens the Dashboard: its tab on iPhone, beside the sidebar on iPad.
    private func showDashboard() {
        tab = .dashboard
        dashboardPath = []
        selection = .page(.dashboard)
    }

    /// Opens the agent's chat: in the Intelligence tab on iPhone, beside
    /// the sidebar on iPad.
    private func open(agentID id: Int) {
        tab = .intelligence
        agentPath = [.agent(id)]
        selection = .agent(id)
    }

    /// Opens what a tapped notification is about, in the first window
    /// active to take it.
    private func openPendingLink() {
        guard scenePhase == .active, let link = model.takePendingLink() else { return }
        open(link)
    }

    /// Opens a link from outside the app over whatever this window shows.
    private func open(_ link: AppLink) {
        isShowingSettings = false
        switch link {
        case .agent(let agentID): open(agentID: agentID)
        case .actorSession(let sessionID): open(sessionID: sessionID)
        case .task, .document: linkRequest = link
        case .agents: openAgents()
        case .newTask: window.isAddingTask = true
        case .newActorSession: window.isStartingActorSession = true
        }
    }

    /// Opens the agents and actor sessions: the Intelligence tab's list on
    /// iPhone; on iPad the sidebar already shows them.
    private func openAgents() {
        tab = .intelligence
        agentPath = []
    }

    /// Opens the session: in the Intelligence tab on iPhone, beside the
    /// sidebar on iPad. One that's gone says so there.
    private func open(sessionID id: Int) {
        tab = .intelligence
        agentPath = [.actorSession(id)]
        selection = .actorSession(id)
    }

    /// Opens the contact: on the Workspace tab's Contacts on iPhone, on the
    /// Contacts list beside the sidebar on iPad.
    private func open(contactID id: Int) {
        tab = .workspace
        workspacePath = [.page(.contacts), .contact(id)]
        contactPath = [id]
        selection = .page(.contacts)
    }

    private func actorSessionView(_ sessionID: Int) -> some View {
        ActorSessionView(sessionID: sessionID, actors: window.actors, clients: window.clients)
            .id(sessionID)
    }

    /// Opens a view just saved in place of the list it was saved from.
    private func open(_ view: SavedTaskView) {
        window.list(savedView: view)
        workspacePath = [.page(.taskView(view.id))]
        selection = .page(.taskView(view.id))
    }

    /// Closes what's open that the lists no longer hold: a deleted agent's
    /// conversation, contact, saved view or feed, and what's on top of them.
    private func closeWhatsGone() {
        if case .feed(let id) = feedPath.first, !window.feeds.contains(where: { $0.id == id }) {
            feedPath = []
        }
        switch window.lastTaskPage {
        case .tasks(.folder(let id)) where !window.folders.contains(where: { $0.id == id }),
             .taskView(let id) where !window.savedViews.contains(where: { $0.id == id }):
            window.lastTaskPage = .tasks(.inbox)
        default: break
        }
        if let open = contactPath.first, !window.contacts.contains(where: { $0.id == open }) {
            contactPath = []
        }
        func isGone(_ route: WorkspaceRoute) -> Bool {
            switch route {
            case .page(.taskView(let id)): !window.savedViews.contains { $0.id == id }
            case .page(.articles(.feed(let id))): !window.feeds.contains { $0.id == id }
            case .page(.resources(let id)): !window.shownKinds.contains { $0.id == id }
            case .contact(let id): !window.contacts.contains { $0.id == id }
            default: false
            }
        }
        if let index = workspacePath.firstIndex(where: isGone) {
            workspacePath.removeSubrange(index...)
        }
        if case .page(let page) = selection, isGone(.page(page)) {
            selection = .page(.dashboard)
        }
        if case .agent(let open) = agentPath.first, !window.agents.contains(where: { $0.id == open }) {
            agentPath = []
        }
        if case .agent(let open) = dashboardPath.first, !window.agents.contains(where: { $0.id == open }) {
            dashboardPath = []
        }
        if case .agent(let id) = selection, !window.agents.contains(where: { $0.id == id }) {
            selection = .page(.dashboard)
        }
    }
}

/// Hides the tab bar while the screen it's in is shown, as part of the
/// navigation transition, so the bar leaves with the push and returns with a
/// swipe back as it's dragged. SwiftUI's `toolbarVisibility(_:for:)` only
/// brings the bar back once the swipe lets go, where it pops in.
private struct HidesTabBar: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            setTabBarHidden(true)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            setTabBarHidden(false)
        }

        /// Follows the transition under way, if any; a swipe back that's
        /// called off puts the bar back as it was.
        private func setTabBarHidden(_ hidden: Bool) {
            guard let tabBarController else { return }
            guard let transitionCoordinator else {
                tabBarController.setTabBarHidden(hidden, animated: false)
                return
            }
            transitionCoordinator.animate { _ in
                tabBarController.setTabBarHidden(hidden, animated: false)
            } completion: { context in
                if context.isCancelled { tabBarController.setTabBarHidden(!hidden, animated: false) }
            }
        }
    }
}

extension EnvironmentValues {
    /// Whether the window shows settings, which any tab's first screen opens.
    @Entry var isShowingSettings: Binding<Bool>?
}

extension FocusedValues {
    /// Whether the focused window shows settings, for the Settings… command.
    @Entry var isShowingSettings: Binding<Bool>?
}

extension View {
    /// The settings button on a tab's first screen, and for the Workspace
    /// tab, the workspace's name as its title, which picks another.
    func tabRootToolbar(showsWorkspaces: Bool = true) -> some View {
        modifier(TabRootToolbar(showsWorkspaces: showsWorkspaces))
    }
}

private struct TabRootToolbar: ViewModifier {
    let showsWorkspaces: Bool

    @Environment(AppModel.self) private var model
    @Environment(WindowModel.self) private var window
    @Environment(\.isShowingSettings) private var isShowingSettings

    func body(content: Content) -> some View {
        @Bindable var window = window

        return Group {
            if showsWorkspaces {
                content
                    .navigationTitle(window.selectedWorkspace?.displayName ?? "Cohesion")
                    // Inline, so the title shows the chevron that opens the
                    // workspace menu.
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarTitleMenu {
                        Picker("Workspace", selection: $window.selectedWorkspaceID) {
                            ForEach(model.workspaces) { workspace in
                                Text(workspace.displayName).tag(Optional(workspace.id))
                            }
                        }
                    }
            } else {
                content
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SettingsButton { isShowingSettings?.wrappedValue = true }
            }
        }
    }
}

/// Settings, with a dot that says how the connection to cohesiond stands.
/// Titled at the iPad sidebar's foot.
struct SettingsButton: View {
    var showsTitle = false
    let action: () -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        Button(action: action) {
            // An HStack rather than a label, which a toolbar draws as its
            // symbol alone.
            HStack {
                Image(systemName: "gear")
                    .overlay(alignment: .topTrailing) { dot }
                if showsTitle { Text("Settings") }
            }
        }
        .accessibilityLabel("Settings")
        .accessibilityValue(connection.label)
    }

    private var connection: ConnectionState { model.client?.connection ?? .connecting }

    private var dot: some View {
        ConnectionDot(connection: connection)
            .offset(x: 3, y: -2)
    }
}
