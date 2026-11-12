import CohesionCore
import CohesionScreens
import CohesionUI
import SwiftUI
import WidgetKit

/// The iPhone's four tabs, in the order of what they're for: Today, the
/// Dashboard, where the app opens; Tasks; Agents, the agents and actor
/// sessions; and Library, what the workspace keeps and reads.
enum RootTab: Hashable {
    case today
    case tasks
    /// The agents, then the actor sessions.
    case agents
    case library
}

/// What the Tasks and Library tabs push on iPhone: one of the workspace's
/// pages, or a contact from its contacts.
enum WorkspaceRoute: Hashable {
    case page(WorkspacePage)
    case contact(Int)
}

/// What the Agents and Today tabs push on iPhone: a conversation, or an actor
/// session.
enum AgentsRoute: Hashable {
    case agent(Int)
    case actorSession(Int)
}

/// On iPhone, four tabs: Today, the Dashboard, where the app opens; Tasks, the
/// task lists, reopening the list last open; Agents, the agents and actor
/// sessions; and Library, the documents, journal, contacts, feeds and
/// connectors. Each pushes what's opened from it; an agent's chat, and an actor
/// session's, hides the tab bar, so its composer is alone at the bottom. Under
/// the tabs, the `ActorsBar` says where the actor sessions stand and adds a
/// task. On iPad, two columns: the `Sidebar`, in the tabs' order, and whatever
/// is open from it. A window resized between the two keeps what it shows.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(WindowModel.self) private var window
    @Environment(PushRegistration.self) private var push
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase

    @State private var tab = RootTab.today
    /// What the Today tab has opened from it, on iPhone.
    @State private var todayPath: [AgentsRoute] = []
    /// What the Tasks tab has open over its lists, on iPhone: the list last
    /// open, from launch.
    @State private var tasksPath: [WorkspaceRoute] = []
    /// Whether the Tasks tab has been put on the list last open, which it is
    /// once, at launch.
    @State private var hasOpenedTaskList = false
    /// What the Library tab has open, on iPhone.
    @State private var libraryPath: [WorkspaceRoute] = []
    /// The open conversation, on iPhone. Stored rather than derived for the
    /// stack, which a binding made afresh on each render unsettles under the
    /// open chat.
    @State private var agentPath: [AgentsRoute] = []
    /// The open contact's id on the Contacts list's stack, on iPad.
    @State private var contactPath: [Int] = []
    /// What's open beside the sidebar, on iPad.
    @State private var selection: SidebarItem?
    @State private var isShowingSettings = false
    /// Whether the actor sessions' sheet, from the tab bar's accessory, is up.
    @State private var isShowingSessions = false
    /// A task or document link from outside the app, for
    /// `presentsLinkedItems` to show over whatever is open.
    @State private var linkRequest: AppLink?

    init() {}

    #if DEBUG
    /// For `#Preview`s: open on `tab`, with `agentPath` pushed on the Agents
    /// tab, `tasksPath` on the Tasks tab's and `libraryPath` on the Library
    /// tab's; beside the sidebar, on `selection`.
    init(
        previewTab tab: RootTab = .today,
        agentPath: [AgentsRoute] = [],
        tasksPath: [WorkspaceRoute]? = nil,
        libraryPath: [WorkspaceRoute] = [],
        selection: SidebarItem? = nil
    ) {
        _tab = State(initialValue: tab)
        _agentPath = State(initialValue: agentPath)
        _tasksPath = State(initialValue: tasksPath ?? [])
        _hasOpenedTaskList = State(initialValue: tasksPath != nil)
        _libraryPath = State(initialValue: libraryPath)
        _selection = State(initialValue: selection)
    }
    #endif

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
            // Side by side, an empty detail column is wasted; start on Today.
            if sizeClass == .regular && selection == nil { selection = .page(.dashboard) }
            // The Tasks tab opens on the list last open, over the lists.
            if !hasOpenedTaskList {
                hasOpenedTaskList = true
                tasksPath = [.page(window.lastTaskPage)]
            }
        }
        .onChange(of: sizeClass) { _, sizeClass in
            // A window resized between tabs and the sidebar keeps what it shows.
            if sizeClass == .compact { showInTabs() } else { showInSidebar() }
        }
        .onChange(of: window.selectedWorkspaceID) {
            // The pages open belong to the workspace left. Beside a sidebar, a
            // workspace opens on Today, as on the web; the Today tab just
            // shows the new one, and Tasks its lists.
            todayPath = []
            tasksPath = []
            libraryPath = []
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
        .onChange(of: todayPath) {
            Task { await window.loadAgents() }
        }
        .onChange(of: tasksPath) {
            if case .page(let page) = tasksPath.last, page.isTaskList { window.lastTaskPage = page }
        }
        .onChange(of: selection) {
            if case .page(let page) = selection, page.isTaskList { window.lastTaskPage = page }
            Task { await window.loadAgents() }
        }
        .onChange(of: window.agents) {
            // The Agents widget shows the unread ones, and an agenda's change
            // posts a message, which changes its agent's row.
            WidgetCenter.shared.reloadTimelines(ofKind: "Agents")
            WidgetCenter.shared.reloadTimelines(ofKind: "AgentAgenda")
        }
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack { SettingsView() }
        }
        .windowSheets(
            window,
            openFeed: { id in
                tab = .library
                libraryPath = [.page(.articles(.feed(id)))]
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
            Tab("Today", systemImage: "sun.max", value: .today) {
                NavigationStack(path: $todayPath) {
                    page(.dashboard)
                        // Its greeting heads it, under a bar with the
                        // workspace menu and Settings, as every tab's first
                        // screen has.
                        .tabRootToolbar()
                        .navigationDestination(for: AgentsRoute.self, destination: conversationDestination)
                }
            }
            Tab("Tasks", systemImage: "checklist", value: .tasks) {
                NavigationStack(path: $tasksPath) {
                    TaskListsView(
                        folders: window.folders,
                        savedViews: window.savedViews,
                        moveSavedViews: window.moveSavedViews
                    ) { WorkspaceRoute.page($0) }
                    .tabRootToolbar()
                    .refreshable { await window.load(.asked) }
                    .navigationDestination(for: WorkspaceRoute.self, destination: workspaceDestination)
                }
            }
            Tab("Agents", systemImage: "sparkles.2", value: .agents) {
                NavigationStack(path: $agentPath) {
                    agentList
                        .navigationDestination(for: AgentsRoute.self, destination: conversationDestination)
                }
            }
            .badge(window.agents.count { $0.isUnread })
            Tab("Library", systemImage: "books.vertical", value: .library) {
                NavigationStack(path: $libraryPath) {
                    library
                        .navigationDestination(for: WorkspaceRoute.self, destination: workspaceDestination)
                }
            }
        }
        // Out of the way while reading; back on scrolling up.
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            ActorsBar(
                sessions: window.actorSessions.current,
                showSessions: { isShowingSessions = true },
                newTask: { window.isAddingTask = true }
            )
        }
        .sheet(isPresented: $isShowingSessions) {
            ActorSessionsSheet(open: open(sessionID:))
                .presentationDetents([.medium, .large])
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
        Group {
            switch route {
            case .page(let page): self.page(page)
            case .contact(let id): ContactPage(contactID: id)
            }
        }
        // Inline, as every pushed screen's title is; the tab's first screen
        // has the large one.
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The Library tab's first screen: the recent documents, then the
    /// workspace's other pages, the feeds and the connectors.
    @ViewBuilder
    private var library: some View {
        if let workspace = window.selectedWorkspace {
            LibraryView(
                workspaceID: workspace.id,
                feeds: window.feeds,
                kinds: window.shownKinds,
                moveFeeds: window.moveFeeds,
                addFeed: { window.isAddingFeed = true },
                moveKinds: window.moveShownKinds,
                editKinds: { window.isEditingKinds = true }
            ) { WorkspaceRoute.page($0) }
            .id(workspace.id)
            .tabRootToolbar()
            .refreshable { await window.load(.asked) }
        }
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
                // Close under the large title, as Messages' pins sit.
                .listSectionMargins(.top, 8)
            }
            AgentSections(
                layout: .list,
                agents: window.agents,
                teams: window.teams,
                actions: window.agentActions
            ) { AgentsRoute.agent($0.id) }
        }
        .overlay {
            if window.agents.isEmpty {
                ContentUnavailableView {
                    Label("No Agents", systemImage: "bubble.left.and.bubble.right")
                } actions: {
                    Button("New Agent") { window.isCreatingAgent = true }
                }
            }
        }
        // Titled large, as the Tasks and Library tabs are.
        .navigationTitle("Agents")
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

    /// One of the workspace's pages: pushed in the Tasks or Library tab on
    /// iPhone, beside the sidebar on iPad. A contact is pushed on the tab's
    /// stack on iPhone, by id on the detail's on iPad.
    @ViewBuilder
    private func page(_ page: WorkspacePage) -> some View {
        if sizeClass == .compact {
            WorkspacePageView(
                page: page,
                contactLink: { WorkspaceRoute.contact($0) },
                openSavedView: open,
                openPage: push(page:),
                openAgent: { todayPath.append(.agent($0)) },
                openActorSession: { todayPath.append(.actorSession($0)) }
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

    /// Pushes another of the workspace's pages on its tab: a task list on
    /// Tasks, any other page on Library.
    private func push(page: WorkspacePage) {
        if page.isTaskList {
            tab = .tasks
            tasksPath.append(.page(page))
        } else {
            tab = .library
            libraryPath.append(.page(page))
        }
    }

    /// Opens in the tabs what the sidebar had open, as the window narrows.
    private func showInTabs() {
        switch selection {
        case .page(.dashboard):
            tab = .today
            todayPath = []
        case .page(.contacts):
            tab = .library
            libraryPath = [.page(.contacts)] + contactPath.map(WorkspaceRoute.contact)
        case .page(let page) where page.isTaskList:
            tab = .tasks
            tasksPath = [.page(page)]
        case .page(let page):
            tab = .library
            libraryPath = [.page(page)]
        case .agent(let id):
            tab = .agents
            agentPath = [.agent(id)]
        case .actorSession(let id):
            tab = .agents
            agentPath = [.actorSession(id)]
        case nil: tab = .today
        }
    }

    /// Opens beside the sidebar what the tabs had open, as the window widens.
    private func showInSidebar() {
        switch tab {
        case .today:
            switch todayPath.last {
            case .agent(let id): selection = .agent(id)
            case .actorSession(let id): selection = .actorSession(id)
            case nil: selection = .page(.dashboard)
            }
        case .tasks:
            switch tasksPath.last {
            case .page(let page): selection = .page(page)
            case .contact, nil: selection = .page(window.lastTaskPage)
            }
        case .library:
            switch libraryPath.last {
            case .page(let page): selection = .page(page)
            case .contact:
                selection = .page(.contacts)
                contactPath = libraryPath.compactMap { if case .contact(let id) = $0 { id } else { nil } }
            case nil: selection = .page(.dashboard)
            }
        case .agents:
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
            case .today:
                switch todayPath.last {
                case .agent(let id): window.agentName(id)
                case .actorSession(let id): window.actorSessionTitle(id)
                case nil: "Today"
                }
            case .tasks: title(of: tasksPath.last) ?? "Tasks"
            case .agents:
                switch agentPath.last {
                case .agent(let id): window.agentName(id)
                case .actorSession(let id): window.actorSessionTitle(id)
                case nil: "Agents"
                }
            case .library: title(of: libraryPath.last) ?? "Library"
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

    /// What a page or contact pushed on a tab is titled.
    private func title(of route: WorkspaceRoute?) -> String? {
        switch route {
        case .page(let page): window.title(of: page)
        case .contact(let id): window.contactName(id)
        case nil: nil
        }
    }

    /// Opens Today, the Dashboard: its tab on iPhone, beside the sidebar on
    /// iPad.
    private func showDashboard() {
        tab = .today
        todayPath = []
        selection = .page(.dashboard)
    }

    /// Opens the agent's chat: in the Agents tab on iPhone, beside the
    /// sidebar on iPad.
    private func open(agentID id: Int) {
        tab = .agents
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

    /// Opens the agents and actor sessions: the Agents tab's list on iPhone,
    /// whose sessions are under the tabs (`ActorsBar`); on iPad the sidebar
    /// already shows them.
    private func openAgents() {
        tab = .agents
        agentPath = []
    }

    /// Opens the session: in the Agents tab on iPhone, beside the sidebar on
    /// iPad. One that's gone says so there.
    private func open(sessionID id: Int) {
        tab = .agents
        agentPath = [.actorSession(id)]
        selection = .actorSession(id)
    }

    /// Opens the contact: on the Library tab's Contacts on iPhone, on the
    /// Contacts list beside the sidebar on iPad.
    private func open(contactID id: Int) {
        tab = .library
        libraryPath = [.page(.contacts), .contact(id)]
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
        tasksPath = [.page(.taskView(view.id))]
        selection = .page(.taskView(view.id))
    }

    /// Closes what's open that the lists no longer hold: a deleted agent's
    /// conversation, contact, saved view or feed, and what's on top of them.
    private func closeWhatsGone() {
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
        if let index = tasksPath.firstIndex(where: isGone) {
            tasksPath.removeSubrange(index...)
        }
        if let index = libraryPath.firstIndex(where: isGone) {
            libraryPath.removeSubrange(index...)
        }
        if case .page(let page) = selection, isGone(.page(page)) {
            selection = .page(.dashboard)
        }
        if case .agent(let open) = agentPath.first, !window.agents.contains(where: { $0.id == open }) {
            agentPath = []
        }
        if case .agent(let open) = todayPath.first, !window.agents.contains(where: { $0.id == open }) {
            todayPath = []
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

        /// A screen shown at launch (restored, or a link) appears before
        /// it's in the tab bar controller, so `viewWillAppear` finds none.
        override func viewIsAppearing(_ animated: Bool) {
            super.viewIsAppearing(animated)
            if tabBarController?.isTabBarHidden == false { setTabBarHidden(true) }
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
    /// A tab's first screen's bar: the workspace's menu at the leading edge,
    /// which picks another, unless the tab isn't the workspace's, and Settings
    /// at the trailing edge with the tab's other buttons.
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
        let name = window.selectedWorkspace?.displayName ?? "Cohesion"

        return content.toolbar {
            if showsWorkspaces {
                // Where a back button would be, since a tab's first screen has
                // none, and the same on every tab that shows the workspace.
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Workspace", selection: $window.selectedWorkspaceID) {
                            ForEach(model.workspaces) { workspace in
                                Text(workspace.displayName).tag(Optional(workspace.id))
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(name)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                        }
                    }
                    .accessibilityLabel("Workspace")
                    .accessibilityValue(name)
                }
            }
            // At the trailing edge with the tab's other buttons, where an
            // iOS app's account or settings button sits, not in the back
            // button's place.
            ToolbarItem(placement: .topBarTrailing) {
                SettingsButton { isShowingSettings?.wrappedValue = true }
            }
        }
    }
}

/// Settings, with a dot that says how the connection to cohesiond stands.
struct SettingsButton: View {
    let action: () -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        Button(action: action) {
            // Titled, so it reads "Settings" in the overflow menu when the
            // bar is too narrow for it; the bar shows the gear alone.
            Label {
                Text("Settings")
            } icon: {
                Image(systemName: "gearshape")
                    // Only when something's wrong: a dot on a healthy
                    // connection reads as a notification.
                    .overlay(alignment: .topTrailing) {
                        if connection != .connected { dot }
                    }
            }
        }
        .accessibilityValue(connection.label)
    }

    private var connection: ConnectionState { model.client?.connection ?? .connecting }

    private var dot: some View {
        ConnectionDot(connection: connection)
            .offset(x: 3, y: -2)
    }
}
