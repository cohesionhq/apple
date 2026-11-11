import CohesionCore
import CohesionUI
import Observation
import SwiftUI

/// What one window shows, apart from the app's other windows: its workspace
/// and the lists its shell shows, kept current while it's open, and which of
/// the shared sheets it has up. The pairing, the connection and the
/// workspaces themselves are the app's, in `AppModel`, shared by every
/// window. Where the window is, its selection or its stacks, is its shell's.
@Observable
public final class WindowModel {
    public let app: AppModel

    /// Restored with the window; a new window opens on the workspace last
    /// picked in any.
    public var selectedWorkspaceID: Int? {
        didSet { app.lastWorkspaceID = selectedWorkspaceID }
    }

    public var selectedWorkspace: Workspace? {
        app.workspaces.first { $0.id == selectedWorkspaceID }
    }

    public internal(set) var folders: [TaskFolder] = []
    public internal(set) var tags: [Tag] = []
    /// The workspace's saved task views, in their order.
    public internal(set) var savedViews: [SavedTaskView] = []
    public internal(set) var feeds: [FeedSummary] = []
    /// Every connector account, with the connector each is one of.
    public internal(set) var connectorAccounts: [ConnectorAccount] = []
    /// The ids of the kinds of resource the workspace shows, in their order.
    private var shownKindIDs: [Int] = []
    /// The workspace's contacts, by last name, then first name.
    public internal(set) var contacts: [Contact] = []
    public internal(set) var agents: [Agent] = []
    /// The user's, which draws them where a task is assigned to them.
    public internal(set) var profile: Profile?
    /// The teams agents are grouped under, by title; `nil` when the
    /// daemon has none.
    public internal(set) var teams: [AgentTeam]?
    public internal(set) var actors: [Actor] = []
    /// Every actor's sessions, latest status change first.
    public internal(set) var actorSessions: [ActorSession] = []
    /// The plan usage the actors report, one entry a pool.
    public internal(set) var actorUsage: [ActorUsage] = []
    /// Which says whether an actor's client is online.
    public internal(set) var clients: [Client] = []

    /// Goes up each time the lists are listed anew, for the shell to close
    /// what's gone from them.
    public private(set) var listings = 0

    /// A note cohesiond pushed, or a link's target that's gone, shown once.
    public var notice: Toast?
    public var error: (any Error)?
    /// Whether the sketch canvas is up, which holds back `errorHeldForSheets`.
    var isSketching = false

    public var isAddingFeed = false
    public var isEditingKinds = false
    public var isEditingSavedViews = false
    /// The task list last open in this window, which the iPad sidebar's Tasks
    /// row opens.
    public var lastTaskPage = WorkspacePage.tasks(.inbox)
    /// Whether a new task's sheet is asked for, from outside the app; it
    /// shows once the window knows its workspace.
    public var isAddingTask = false
    /// Whether the new task's sheet is up.
    var showsNewTask: Bool {
        get { isAddingTask && selectedWorkspaceID != nil }
        set { isAddingTask = newValue }
    }
    public var isStartingActorSession = false
    public var isShowingActorUsage = false
    public var isCreatingAgent = false
    public var isPickingContact = false
    /// A contact being created, blank or from the system's picker.
    public var newContact: ContactDraft?
    public var namingTeam: TeamNaming?
    public var deletingTeam: AgentTeam?

    /// Whether the lists as last listed have been shown, once a launch.
    private var hasShownKept = false

    public init(app: AppModel, workspaceID: Int?) {
        self.app = app
        selectedWorkspaceID = workspaceID ?? app.lastWorkspaceID
    }

    /// `error`, for an alert above the sketch canvas or a sheet for something
    /// new, kept from showing until they close: SwiftUI closes a cover or a
    /// sheet to show an alert from a view beneath it, refuses a sheet while an
    /// alert is presenting, and a load being retried can fail at any time. A link
    /// waiting to open holds it too, since it may be such a sheet.
    func errorHeldForSheets(_ error: Binding<(any Error)?>) -> Binding<(any Error)?> {
        Binding {
            let isHeld = self.isSketching || self.showsNewTask || self.isStartingActorSession
                || self.app.pendingLink != nil
            return isHeld ? nil : error.wrappedValue
        } set: {
            error.wrappedValue = $0
        }
    }

    /// Reloads the workspaces, selecting the first when this window's is gone.
    public func loadWorkspaces() async throws {
        try await app.loadWorkspaces()
        if selectedWorkspace == nil {
            selectedWorkspaceID = app.workspaces.first?.id
        }
    }

    /// The kinds of resource the workspace shows, in their order, those
    /// whose connector has an account that can import.
    public var shownKinds: [ConnectorKind] {
        let kinds = connectorAccounts.importableKinds
        return shownKindIDs.compactMap { id in kinds.first { $0.id == id } }
    }

    /// The pinned agents, in their order.
    public var pinnedAgents: [Agent] { agents.filter(\.isPinned) }

    /// What the agents' menus do, in every shell.
    public var agentActions: AgentActions {
        AgentActions(
            setPinned: setPinned,
            setTeam: setTeam,
            newTeam: { [self] in namingTeam = .new(moving: $0) },
            renameTeam: { [self] in namingTeam = .rename($0) },
            deleteTeam: { [self] in deletingTeam = $0 }
        )
    }

    // MARK: Titles

    public func title(of page: WorkspacePage) -> String {
        switch page {
        case .dashboard: "Dashboard"
        case .today: "Today"
        case .journal: "Journal"
        case .documents: "Documents"
        case .contacts: "Contacts"
        case .tasks(let scope): title(of: scope)
        case .taskView(let id): savedViews.first { $0.id == id }?.name ?? "Tasks"
        case .articles(let filter): title(of: filter)
        case .resources(let kindID): shownKinds.first { $0.id == kindID }?.kind.plural ?? "Resources"
        }
    }

    public func title(of filter: ArticleListFilter) -> String {
        switch filter {
        case .feed(let id): feeds.first { $0.id == id }?.title ?? "Feed"
        case .allFeeds: "All Feeds"
        }
    }

    public func title(of scope: TaskScope) -> String {
        switch scope {
        case .inbox: "Inbox"
        case .folder(let id): folders.first { $0.id == id }?.title ?? "Inbox"
        case .all: "All"
        case .done: "Done"
        case .cancelled: "Cancelled"
        }
    }

    public func agentName(_ id: Int) -> String {
        agents.first { $0.id == id }?.name ?? "Agents"
    }

    public func actorSessionTitle(_ id: Int) -> String {
        actorSessions.first { $0.id == id }?.title ?? "Actors"
    }

    public func contactName(_ id: Int) -> String {
        contacts.first { $0.id == id }?.fullName ?? "Contacts"
    }

    // MARK: Showing what's kept

    /// Shows the lists as cohesiond last sent them, from an earlier launch
    /// too, so the app opens on them rather than on empty lists while
    /// `load` and the watches ask again. Once a launch.
    public func showKeptOnce() {
        guard !hasShownKept else { return }
        hasShownKept = true
        guard let client = app.client else { return }
        showKeptOfWorkspace()
        if let feeds = client.keptFeeds() { self.feeds = feeds }
        if let agents = client.keptAgents() { self.agents = agents }
        teams = client.keptAgentTeams()
        if let actors = client.keptActors() { self.actors = actors }
        if let sessions = client.keptActorSessions() { actorSessions = sessions }
        if let clients = client.keptClients() { self.clients = clients }
        if let accounts = client.keptConnectorAccounts() { connectorAccounts = accounts }
    }

    /// Shows the selected workspace's lists as last sent; a workspace
    /// whose lists weren't kept shows the ones before until `load` has its own.
    public func showKeptOfWorkspace() {
        guard let client = app.client, let workspaceID = selectedWorkspaceID else { return }
        if let folders = client.keptTaskFolders(in: workspaceID) { self.folders = folders }
        if let tags = client.keptTaskTags(in: workspaceID) { self.tags = tags }
        if let views = client.keptSavedTaskViews(in: workspaceID) { savedViews = views }
        if let contacts = client.keptContacts(in: workspaceID) { self.contacts = contacts }
        if let kinds = client.keptResourceKinds(in: workspaceID) { shownKindIDs = kinds.map(\.kindID) }
    }

    // MARK: Loading

    public func load(_ origin: LoadOrigin = .automatic) async {
        guard let client = app.client else { return }
        // A load cut short by switching workspace isn't an error.
        await origin.run {
            try await loadWorkspaces()
            if let workspaceID = selectedWorkspaceID {
                folders = try await client.listTaskFolders(in: workspaceID)
                tags = try await client.listTaskTags(in: workspaceID)
                savedViews = try await client.listSavedTaskViews(in: workspaceID)
                contacts = try await client.listContacts(in: workspaceID)
                listings += 1
                shownKindIDs = try await client.listResourceKinds(in: workspaceID).map(\.kindID)
            }
            connectorAccounts = try await client.listConnectorAccounts()
            feeds = try await client.listFeeds()
            agents = try await client.listAgents()
            await loadTeams()
            listings += 1
        } failed: { self.error = $0 }
    }

    /// Pull to refresh or Reload: the lists and the actors again, with one
    /// alert at most when they fail.
    public func refresh() async {
        await load(.asked)
        await loadActors(error == nil ? .asked : .automatic)
    }

    /// Keeps the feeds, the connector accounts, and the selected
    /// workspace's folders, tags, contacts and shown kinds of resource,
    /// current while the app is shown.
    public func watch() async {
        guard let client = app.client else { return }
        let workspaceID = selectedWorkspaceID
        for await _ in client.changes(matching: { change in
            switch change {
            case .feeds, .connectorAccounts: true
            case .taskFolders(let id), .tags(let id), .savedTaskViews(let id),
                 .contacts(let id), .resourceKinds(let id):
                id == workspaceID
            case .agent, .agentTeams, .profile, .documents, .documentFolders, .documentTable, .taskList, .feedArticles, .intelligence, .clients, .memories, .agentSkills,
                 .resources,
                 .actors, .actorSessions, .actorSession, .actorUsage, .notification, .other: false
            }
        }) {
            await load()
        }
    }

    /// Keeps the agents current while the app is shown, so working
    /// indicators and unread dots follow cohesiond. Apart from `watch`,
    /// since an agent changes many times a turn and needs only its list
    /// again, not every workspace's.
    public func watchAgents() async {
        guard let client = app.client else { return }
        for await _ in client.changes(matching: { if case .agent = $0 { true } else { false } }) {
            await loadAgents()
        }
    }

    /// Keeps the teams current while the app is shown; an agent moving
    /// between them is a change to the agent, which `watchAgents` follows.
    public func watchTeams() async {
        guard let client = app.client else { return }
        for await _ in client.changes(matching: { $0 == .agentTeams }) {
            await loadTeams()
        }
    }

    /// Keeps the user's profile current while the app is shown; the stream
    /// also yields once on connecting, which does the first load.
    public func watchProfile() async {
        guard let client = app.client else { return }
        for await _ in client.changes(matching: { $0 == .profile }) {
            // Without it the user shows by a glyph, so a failed load isn't an error.
            if let profile = try? await client.profile(), profile != self.profile { self.profile = profile }
        }
    }

    /// Keeps the actors, their sessions and their clients' online state current
    /// while the app is shown; the stream also yields once on connecting,
    /// which does the first load.
    public func watchActors() async {
        guard let client = app.client else { return }
        for await _ in client.changes(matching: { change in
            switch change {
            case .actors, .actorSessions, .clients: true
            default: false
            }
        }) {
            await loadActors()
        }
    }

    /// Keeps the actors' plan usage current, apart from `watchActors`
    /// since it changes after every turn.
    public func watchActorUsage() async {
        guard let client = app.client else { return }
        for await _ in client.changes(matching: { $0 == .actorUsage }) {
            // An older cohesiond leaves no usage, as in a session's sheet.
            if let usage = try? await client.listActorUsage() { actorUsage = usage }
        }
    }

    /// Shows each note cohesiond pushes, as the web's toast does.
    public func watchNotices() async {
        guard let client = app.client else { return }
        for await notice in client.notices() {
            self.notice = Toast(kind: .info, title: notice.title, message: notice.message)
        }
    }

    public func loadActors(_ origin: LoadOrigin = .automatic) async {
        guard let client = app.client else { return }
        await origin.run {
            async let actors = client.listActors()
            async let sessions = client.listActorSessions()
            async let clients = client.listClients()
            let loaded = try await (actors, sessions, clients)
            // Animated, so a session joining or leaving the Actors section
            // slides rather than pops.
            withAnimation { (self.actors, actorSessions, self.clients) = loaded }
        } failed: { self.error = $0 }
    }

    /// The selected workspace's contacts again, as a contact just created
    /// opens on.
    public func loadContacts() async {
        guard let client = app.client, let workspaceID = selectedWorkspaceID else { return }
        do {
            contacts = try await client.listContacts(in: workspaceID)
            listings += 1
        } catch where !Task.isCancelled {
            self.error = error
        } catch {}
    }

    /// Leaves the teams as they were when they can't be loaded, as
    /// `loadAgents` does the agents.
    public func loadTeams() async {
        guard let client = app.client else { return }
        do {
            let teams = try await client.listAgentTeams()
            if teams != self.teams { self.teams = teams }
        } catch {}
    }

    public func loadAgents() async {
        guard let agents = try? await app.client?.listAgents(), agents != self.agents else { return }
        self.agents = agents
        listings += 1
    }

    // MARK: Changing them

    /// Resolves the session, which leaves the Actors section at once; one that
    /// is open stays open.
    public func resolve(_ session: ActorSession) {
        guard let client = app.client else { return }
        Task {
            do {
                let resolved = try await client.resolve(session)
                withAnimation { actorSessions.removeAll { $0.id == resolved.id } }
            } catch {
                self.error = error
            }
        }
    }

    /// Lists a session just started at once, ahead of the refetch its start
    /// sets off.
    public func list(startedSession session: ActorSession) {
        withAnimation {
            actorSessions.removeAll { $0.id == session.id }
            actorSessions.insert(session, at: 0)
        }
    }

    /// Adds a view just saved, for it to open at once.
    public func list(savedView view: SavedTaskView) {
        if !savedViews.contains(where: { $0.id == view.id }) { savedViews.append(view) }
    }

    private func setTeam(_ agent: Agent, _ teamID: Int?) {
        Task {
            do {
                _ = try await app.client?.setTeam(of: agent, to: teamID)
                await loadAgents()
            } catch {
                self.error = error
            }
        }
    }

    private func setPinned(_ agent: Agent, _ pinned: Bool) {
        Task {
            do {
                _ = try await app.client?.setPinned(agent, pinned)
                await loadAgents()
            } catch {
                self.error = error
            }
        }
    }

    /// Shows the kind or hides it at once, a newly shown one last, then saves
    /// it. The invalidation that follows brings cohesiond's list, rather than
    /// the reply, which could undo a later tap; a failed save reloads it.
    func setKind(_ entry: ConnectorKind, _ shown: Bool) async throws {
        guard let client = app.client, let workspaceID = selectedWorkspaceID else { return }
        withAnimation {
            if shown {
                shownKindIDs.append(entry.id)
            } else {
                shownKindIDs.removeAll { $0 == entry.id }
            }
        }
        do {
            _ = try await client.setResourceKind(entry.id, shown: shown, in: workspaceID)
        } catch {
            await load()
            throw error
        }
    }

    /// Moves the shown kinds, from a shell's list.
    public func moveShownKinds(from source: IndexSet, to destination: Int) {
        Task {
            do { try await moveKinds(from: source, to: destination) } catch { self.error = error }
        }
    }

    /// Shows the shown kinds' new order at once, then saves it; a failed
    /// save reloads cohesiond's order.
    func moveKinds(from source: IndexSet, to destination: Int) async throws {
        guard let client = app.client, let workspaceID = selectedWorkspaceID else { return }
        var ids = shownKinds.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        shownKindIDs = ids
        do {
            shownKindIDs = try await client.reorderResourceKinds(ids, in: workspaceID).map(\.kindID)
        } catch {
            await load()
            throw error
        }
    }

    /// Shows the new order at once, then saves it; a failed save reloads
    /// cohesiond's order.
    public func moveFeeds(from source: IndexSet, to destination: Int) {
        feeds.move(fromOffsets: source, toOffset: destination)
        let ids = feeds.map(\.id)
        Task {
            do {
                if let reordered = try await app.client?.reorderFeeds(ids) { feeds = reordered }
            } catch {
                self.error = error
                await load()
            }
        }
    }

    public func moveSavedViews(from source: IndexSet, to destination: Int) {
        guard let workspaceID = selectedWorkspaceID else { return }
        savedViews.move(fromOffsets: source, toOffset: destination)
        let ids = savedViews.map(\.id)
        Task {
            do {
                if let reordered = try await app.client?.reorderSavedTaskViews(ids, in: workspaceID) {
                    savedViews = reordered
                }
            } catch {
                self.error = error
                await load()
            }
        }
    }

    // MARK: Links

    /// What a link tapped in the app's text does: a `cohesion://` link to an
    /// agent or an actor session through `openAgent` and `openActorSession` (saying
    /// so when its target is gone), the agents through `openAgents`, a new
    /// task's or session's sheet here, a task or document through `openInSheet`, and any
    /// other through the system, as a browser would.
    public func follow(
        _ url: URL,
        openAgent: @escaping (Int) -> Void,
        openActorSession: @escaping (Int) -> Void,
        openAgents: () -> Void,
        openInSheet: (AppLink) -> Void
    ) -> OpenURLAction.Result {
        guard let link = AppLink(url: url) else {
            // A malformed internal link has nowhere to go outside the app either.
            return url.scheme == AppLink.internalScheme ? .discarded : .systemAction
        }
        switch link {
        case .agent(let id):
            guard agents.contains(where: { $0.id == id }) else {
                notice = .error("Agent not found.")
                return .handled
            }
            openAgent(id)
        case .actorSession(let id):
            Task {
                if await actorSessionExists(id) { openActorSession(id) }
            }
        case .task, .document: openInSheet(link)
        case .agents: openAgents()
        case .newTask: isAddingTask = true
        case .newActorSession: isStartingActorSession = true
        }
        return .handled
    }

    /// Whether to open the session a link names: not when it's gone, which
    /// says so rather than opening an empty transcript. Any other failure
    /// opens it, and the screen offers to try again.
    private func actorSessionExists(_ id: Int) async -> Bool {
        guard let client = app.client else { return false }
        do {
            _ = try await client.actorSession(id)
            return true
        } catch let error as ServerError where error.code == ServerError.notFound {
            notice = .error("Session not found.")
            return false
        } catch {
            return true
        }
    }
}
