import CohesionCore
import CohesionUI
import SwiftUI

/// One of the workspace's pages: what a shell's lists open from `WorkspaceSections`.
public enum WorkspacePage: Hashable {
    /// Where a workspace opens: a message to an agent, tasks and a glimpse of
    /// today's journal.
    case dashboard
    /// Today's journal entry.
    case today
    case journal
    case documents
    /// The workspace's contacts, which push one.
    case contacts
    case tasks(TaskScope)
    /// A saved task view.
    case taskView(Int)
    case articles(ArticleListFilter)
    /// One kind's resources, imported through a connector.
    case resources(kindID: Int)

    /// Whether this is one of the task lists, a saved view among them.
    public var isTaskList: Bool {
        switch self {
        case .tasks, .taskView: true
        default: false
        }
    }
}

extension EnvironmentValues {
    /// Whether one Tasks row stands for the task lists, with each list's title
    /// menu moving between them, as beside the iPad's sidebar.
    @Entry public var tasksAreOneRow = false
}

/// What a sidebar opens beside it.
public enum SidebarItem: Hashable {
    case page(WorkspacePage)
    case agent(Int)
    case actorSession(Int)
}

/// A sidebar's list, in the iPhone's tabs' order: Today and the task lists,
/// then the agents and the actor sessions, so they show without scrolling,
/// then the Library's pages, then the kinds of resource the workspace shows
/// and the feeds, each a section that collapses. The iPad's and the Mac's
/// sidebars both list this; what's around it is theirs.
public struct SidebarSections: View {
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
    /// Every actor's sessions; the section lists the current ones.
    let actorSessions: [ActorSession]
    let agentActions: AgentActions
    let moveSavedViews: (IndexSet, Int) -> Void
    let moveFeeds: (IndexSet, Int) -> Void
    let addFeed: () -> Void
    let newAgent: () -> Void
    let newActorSession: () -> Void
    let resolveActorSession: (ActorSession) -> Void

    /// The sections the user collapsed; remembered across launches. Stored
    /// by hand rather than with `@AppStorage`, which drops the section's
    /// animation.
    @State private var collapsed = Set(
        (UserDefaults.standard.stringArray(forKey: collapsedKey) ?? []).compactMap(SectionKey.init(rawValue:))
    ) {
        didSet { UserDefaults.standard.set(collapsed.map(\.rawValue), forKey: Self.collapsedKey) }
    }

    private enum SectionKey: String {
        case actors
    }

    private static var collapsedKey: String { "sidebarCollapsedSections" }

    private func isExpanded(_ key: SectionKey) -> Binding<Bool> {
        Binding {
            !collapsed.contains(key)
        } set: { expanded in
            if expanded { collapsed.remove(key) } else { collapsed.insert(key) }
        }
    }

    public init(
        folders: [TaskFolder],
        savedViews: [SavedTaskView],
        feeds: [FeedSummary],
        kinds: [ConnectorKind],
        moveKinds: @escaping (IndexSet, Int) -> Void,
        editKinds: @escaping () -> Void,
        agents: [Agent],
        teams: [AgentTeam]?,
        actors: [Actor],
        actorSessions: [ActorSession],
        agentActions: AgentActions,
        moveSavedViews: @escaping (IndexSet, Int) -> Void,
        moveFeeds: @escaping (IndexSet, Int) -> Void,
        addFeed: @escaping () -> Void,
        newAgent: @escaping () -> Void,
        newActorSession: @escaping () -> Void,
        resolveActorSession: @escaping (ActorSession) -> Void
    ) {
        self.folders = folders
        self.savedViews = savedViews
        self.feeds = feeds
        self.kinds = kinds
        self.moveKinds = moveKinds
        self.editKinds = editKinds
        self.agents = agents
        self.teams = teams
        self.actors = actors
        self.actorSessions = actorSessions
        self.agentActions = agentActions
        self.moveSavedViews = moveSavedViews
        self.moveFeeds = moveFeeds
        self.addFeed = addFeed
        self.newAgent = newAgent
        self.newActorSession = newActorSession
        self.resolveActorSession = resolveActorSession
    }

    public var body: some View {
        WorkspaceSections(
            folders: folders,
            savedViews: savedViews,
            moveSavedViews: moveSavedViews
        ) { SidebarItem.page($0) }
        AgentSections(
            layout: .sidebar(newAgent: newAgent),
            agents: agents,
            teams: teams,
            actions: agentActions
        ) { SidebarItem.agent($0.id) }
        ActorSessionsSection(
            actors: actors, sessions: actorSessions, resolve: resolveActorSession, newSession: newActorSession,
            isExpanded: isExpanded(.actors)
        ) {
            SidebarItem.actorSession($0)
        }
        LibrarySection { SidebarItem.page($0) }
        // What comes into the workspace from elsewhere, last.
        WorkspaceSources(
            feeds: FeedSection(feeds: feeds, moveFeeds: moveFeeds, addFeed: addFeed) {
                SidebarItem.page(.articles($0))
            },
            kinds: kinds,
            moveKinds: moveKinds,
            editKinds: editKinds
        ) { SidebarItem.page($0) }
    }
}

/// A sidebar's first section: Today, where the workspace opens (the
/// Dashboard), then its task lists, as one Tasks row beside the iPad's sidebar
/// (`tasksAreOneRow`) or a section of their own. Its other pages are the
/// `LibrarySection`, after the agents and actors, as the iPhone's tabs order
/// them; `link` makes each row's value.
public struct WorkspaceSections<Link: Hashable>: View {
    public let folders: [TaskFolder]
    /// The workspace's saved task views, in their order.
    public let savedViews: [SavedTaskView]
    public let moveSavedViews: (IndexSet, Int) -> Void
    public let link: (WorkspacePage) -> Link

    public init(
        folders: [TaskFolder],
        savedViews: [SavedTaskView],
        moveSavedViews: @escaping (IndexSet, Int) -> Void,
        link: @escaping (WorkspacePage) -> Link
    ) {
        self.folders = folders
        self.savedViews = savedViews
        self.moveSavedViews = moveSavedViews
        self.link = link
    }

    /// The sections the user collapsed; remembered across launches.
    /// Stored by hand rather than with `@AppStorage`, which drops the
    /// section's animation.
    @State private var collapsed = Set(
        (UserDefaults.standard.stringArray(forKey: collapsedKey) ?? []).compactMap(SectionKey.init(rawValue:))
    ) {
        didSet { UserDefaults.standard.set(collapsed.map(\.rawValue), forKey: Self.collapsedKey) }
    }

    private enum SectionKey: String {
        case tasks
    }

    // Computed, since a generic type can't store a static.
    private static var collapsedKey: String { "workspaceCollapsedSections" }

    public var body: some View {
        TaskSection(
            folders: folders,
            savedViews: savedViews,
            moveSavedViews: moveSavedViews,
            isExpanded: isExpanded(.tasks),
            link: link
        ) {
            NavigationLink(value: link(.dashboard)) {
                Label("Today", systemImage: "sun.max")
            }
        }
    }

    private func isExpanded(_ key: SectionKey) -> Binding<Bool> {
        Binding {
            !collapsed.contains(key)
        } set: { expanded in
            if expanded { collapsed.remove(key) } else { collapsed.insert(key) }
        }
    }
}

/// What the workspace keeps, in a sidebar: Documents, Journal (today's entry
/// first) and Contacts, as the iPhone's Library tab lists them.
public struct LibrarySection<Link: Hashable>: View {
    public let link: (WorkspacePage) -> Link

    public init(link: @escaping (WorkspacePage) -> Link) {
        self.link = link
    }

    public var body: some View {
        Section("Library") {
            row(.documents, "Documents", systemImage: "doc.text")
            row(.journal, "Journal", systemImage: "book.closed")
            row(.contacts, "Contacts", systemImage: "person.crop.circle")
        }
    }

    private func row(_ page: WorkspacePage, _ title: String, systemImage: String) -> some View {
        NavigationLink(value: link(page)) {
            Label(title, systemImage: systemImage)
        }
    }
}

/// What comes into the workspace from elsewhere: the kinds of resource it
/// shows, then the feeds, a section that collapses. A sidebar lists them
/// last; the Library tab lists the kinds after its feeds.
public struct WorkspaceSources<Link: Hashable>: View {
    /// The feeds and what their section does; `nil` to leave them out.
    public let feeds: FeedSection<Link>?
    public let kinds: [ConnectorKind]
    public let moveKinds: (IndexSet, Int) -> Void
    public let editKinds: () -> Void
    public let link: (WorkspacePage) -> Link

    public init(
        feeds: FeedSection<Link>?,
        kinds: [ConnectorKind],
        moveKinds: @escaping (IndexSet, Int) -> Void,
        editKinds: @escaping () -> Void,
        link: @escaping (WorkspacePage) -> Link
    ) {
        self.feeds = feeds
        self.kinds = kinds
        self.moveKinds = moveKinds
        self.editKinds = editKinds
        self.link = link
    }

    /// Whether the feeds are collapsed; remembered across launches.
    @State private var isFeedsCollapsed = UserDefaults.standard.bool(forKey: feedsCollapsedKey) {
        didSet { UserDefaults.standard.set(isFeedsCollapsed, forKey: Self.feedsCollapsedKey) }
    }

    // Computed, since a generic type can't store a static.
    private static var feedsCollapsedKey: String { "workspaceFeedsCollapsed" }

    public var body: some View {
        connectorSection
        if let feeds {
            Section("Feeds", isExpanded: Binding {
                !isFeedsCollapsed
            } set: { expanded in
                withAnimation { isFeedsCollapsed = !expanded }
            }) { feeds }
        }
    }

    /// The kinds of resource the workspace shows, each opening its
    /// resources, as the web's sidebar lists them after the workspace's
    /// pages. Its section action, Edit, chooses them. It doesn't collapse, and
    /// sits above the feeds.
    private var connectorSection: some View {
        Section {
            ForEach(kinds) { entry in
                NavigationLink(value: link(.resources(kindID: entry.id))) {
                    ResourceKindLabel(entry: entry, namesConnector: kinds.contains {
                        $0.id != entry.id && $0.kind.plural == entry.kind.plural
                    })
                }
            }
            .onMove(perform: moveKinds)
        } header: {
            Text("Connectors")
        }
        .sectionActions {
            Button("Edit", systemImage: "slider.horizontal.3", action: editKinds)
        }
    }

}

/// Today, then the task lists: beside the iPad's sidebar one Tasks row after
/// it, opening the list last open; elsewhere a section of their own. `#if`, as iOS decides by what's around the list and the Mac always
/// lists them.
private struct TaskSection<Link: Hashable, Pages: View>: View {
    let folders: [TaskFolder]
    let savedViews: [SavedTaskView]
    let moveSavedViews: (IndexSet, Int) -> Void
    let isExpanded: Binding<Bool>
    let link: (WorkspacePage) -> Link
    @ViewBuilder let pages: () -> Pages

    #if os(iOS)
    @Environment(\.tasksAreOneRow) private var isOneRow
    @Environment(WindowModel.self) private var window
    #endif

    var body: some View {
        #if os(iOS)
        if isOneRow {
            Section {
                pages()
                NavigationLink(value: link(window.lastTaskPage)) {
                    Label("Tasks", systemImage: "checklist")
                }
            }
        } else {
            Section(content: pages)
            lists
        }
        #else
        Section(content: pages)
        lists
        #endif
    }

    /// The inbox and folders; then, as views of them, every open task, those
    /// done and those cancelled, and the saved views, in a section of their
    /// own that shows and hides with the first. The web's Tasks page lists
    /// them in this order.
    @ViewBuilder
    private var lists: some View {
        Section("Tasks", isExpanded: isExpanded) {
            row(.tasks(.inbox), "Inbox", systemImage: "tray")
            ForEach(folders) { folder in
                row(.tasks(.folder(folder.id)), folder.title, systemImage: "folder")
            }
        }
        if isExpanded.wrappedValue {
            Section("Views") {
                row(.tasks(.all), "All", systemImage: "tray.2")
                row(.tasks(.done), "Done", systemImage: "checkmark.circle")
                row(.tasks(.cancelled), "Cancelled", systemImage: "xmark.circle")
                ForEach(savedViews) { view in
                    row(.taskView(view.id), view.name, systemImage: "bookmark")
                }
                .onMove(perform: moveSavedViews)
            }
        }
    }

    private func row(_ page: WorkspacePage, _ title: String, systemImage: String) -> some View {
        NavigationLink(value: link(page)) {
            Label(title, systemImage: systemImage)
        }
    }
}

/// Every feed together, then each, with their unread counts, then Add
/// Feed: a section of the iPad's sidebar, and of the iPhone's Library tab.
public struct FeedSection<Link: Hashable>: View {
    public let feeds: [FeedSummary]
    public let moveFeeds: (IndexSet, Int) -> Void
    public let addFeed: () -> Void
    /// Each row's value, from the articles it lists.
    public let link: (ArticleListFilter) -> Link

    public init(
        feeds: [FeedSummary],
        moveFeeds: @escaping (IndexSet, Int) -> Void,
        addFeed: @escaping () -> Void,
        link: @escaping (ArticleListFilter) -> Link
    ) {
        self.feeds = feeds
        self.moveFeeds = moveFeeds
        self.addFeed = addFeed
        self.link = link
    }

    public var body: some View {
        NavigationLink(value: link(.allFeeds)) {
            FeedLabel(title: "All Feeds", systemImage: "square.stack", unread: feeds.reduce(0) { $0 + $1.unread })
        }
        ForEach(feeds) { feed in
            NavigationLink(value: link(.feed(feed.id))) {
                FeedLabel(title: feed.title, systemImage: "dot.radiowaves.up.forward", unread: feed.unread)
            }
        }
        .onMove(perform: moveFeeds)
        Button("Add Feed", systemImage: "plus", action: addFeed)
    }
}

/// The Actors section, after the agents, as the web's sidebar has it: the
/// sessions not yet resolved, those needing the user first, with a button
/// for `newSession` in its section actions, if it has one.
/// Swiping or pressing a session offers to resolve it, asking first when it is
/// going on.
/// With no actor offered, or no session yet, it says so. It collapses when
/// given `isExpanded`.
public struct ActorSessionsSection<Link: Hashable>: View {
    public let actors: [Actor]
    /// Every actor's sessions not yet resolved, latest status change first.
    public let sessions: [ActorSession]
    public let resolve: (ActorSession) -> Void
    public let link: (Int) -> Link
    public let newSession: (() -> Void)?
    /// Whether the section is open, if it collapses.
    public let isExpanded: Binding<Bool>?

    public init(
        actors: [Actor],
        sessions: [ActorSession],
        resolve: @escaping (ActorSession) -> Void,
        newSession: (() -> Void)? = nil,
        isExpanded: Binding<Bool>? = nil,
        link: @escaping (Int) -> Link
    ) {
        self.actors = actors
        self.sessions = sessions
        self.resolve = resolve
        self.link = link
        self.newSession = newSession
        self.isExpanded = isExpanded
    }

    /// The session going on that the user asked to resolve, until they confirm.
    @State private var resolving: ActorSession?

    public var body: some View {
        if let isExpanded {
            Section(isExpanded: isExpanded) { rows } header: { header }
                .sectionActions { actions }
        } else {
            Section { rows } header: { header }
                .sectionActions { actions }
        }
    }

    @ViewBuilder
    private var rows: some View {
        let current = sessions.current
        if actors.isEmpty {
            Text("No actors ready")
                .foregroundStyle(.secondary)
        } else if sessions.isEmpty {
            Text("No sessions yet.")
                .foregroundStyle(.secondary)
        }
        ForEach(current) { session in
            NavigationLink(value: link(session.id)) {
                ActorSidebarRow(session: session)
            }
            .swipeActions {
                resolveButton(session)
                    .tint(.accentColor)
            }
            .contextMenu {
                resolveButton(session)
            }
            .confirmationDialog(
                "Resolve “\(session.title)”?",
                isPresented: Binding(
                    get: { resolving?.id == session.id },
                    set: { if !$0 { resolving = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Resolve") { resolve(session) }
            } message: {
                Text("Its actor stops what it’s doing, and the session leaves your list. Send a message to pick it back up.")
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        if let newSession {
            Button("New Session", systemImage: "plus", action: newSession)
                .disabled(actors.isEmpty)
        }
    }

    private var header: some View {
        Text("Actors")
    }

    /// Not destructive, since a message picks the session back up.
    private func resolveButton(_ session: ActorSession) -> some View {
        Button("Resolve", systemImage: "archivebox") {
            if session.status.isGoing { resolving = session } else { resolve(session) }
        }
    }
}

/// A feed row's label with its unread count trailing, as a badge shows it.
/// Not `.badge`: in a split view's selectable list, a badged row takes two
/// or three taps to select.
public struct FeedLabel: View {
    public let title: String
    public let systemImage: String
    public let unread: Int

    public init(title: String, systemImage: String, unread: Int) {
        self.title = title
        self.systemImage = systemImage
        self.unread = unread
    }

    public var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            if unread > 0 {
                Text(unread, format: .number)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

/// The connection to cohesiond as a dot: green while connected, a grey ring
/// while connecting, an amber ring while reconnecting, red once revoked.
public struct ConnectionDot: View {
    let connection: ConnectionState

    public init(connection: ConnectionState) {
        self.connection = connection
    }

    public var body: some View {
        Group {
            switch connection {
            case .connected:
                Circle().fill(.green)
            case .connecting:
                Circle().stroke(.gray, lineWidth: 1.5)
            case .reconnecting:
                Circle().stroke(.orange, lineWidth: 1.5)
            case .revoked:
                Circle().fill(.red)
            }
        }
        .frame(width: 7, height: 7)
    }
}

extension ConnectionState {
    /// How the connection stands, in a word.
    public var label: String {
        switch self {
        case .connected: "Connected"
        case .connecting: "Connecting"
        case .reconnecting: "Reconnecting"
        case .revoked: "Revoked"
        }
    }
}

/// The paired server's address, the key its certificate is pinned to and its
/// version while connected, and the app's own version and build, which stay
/// on this device.
public struct AboutSection: View {
    @Environment(AppModel.self) private var model

    /// The version cohesiond last gave; `nil` until it answers, or if it won't.
    @State private var serverVersion: String?

    public init() {}

    public var body: some View {
        Section {
            LabeledContent("Server", value: model.pairing?.host ?? "")
                // On one row, since on the section it would run for each.
                .task { await watchServerVersion() }
            LabeledContent("Server Key") {
                Text(model.pairing?.serverFingerprint.prefix(16) ?? "")
                    .font(.body.monospaced())
            }
            if model.client?.connection == .connected, let serverVersion {
                LabeledContent("Server Version", value: serverVersion)
            }
            LabeledContent("Version", value: bundleString("CFBundleShortVersionString"))
            LabeledContent("Build", value: bundleString("CFBundleVersion"))
        }
    }

    /// Asks each time the socket subscribes and on a reset, never for a
    /// change, so a server that restarted on a new version reads as that one.
    private func watchServerVersion() async {
        guard let client = model.client else { return }
        for await _ in client.changes(matching: { _ in false }) {
            serverVersion = try? await client.about().version
        }
    }

    /// A string from the app's Info.plist.
    private func bundleString(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}

/// Unpair, once the user has said so.
public struct UnpairButton: View {
    @Environment(AppModel.self) private var model

    @State private var isConfirming = false

    public init() {}

    public var body: some View {
        Button("Unpair", role: .destructive) {
            isConfirming = true
        }
        .confirmationDialog(
            "Unpair from this server?",
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button("Unpair", role: .destructive, action: model.unpair)
        } message: {
            Text("You'll need a new setup code to pair again.")
        }
    }
}
