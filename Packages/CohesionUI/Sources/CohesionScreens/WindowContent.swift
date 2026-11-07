import Combine
import CohesionCore
import CohesionMarkdown
import CohesionUI
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// One window: pairing until the app is paired, then `content`, the app's
/// shell, with the window's `WindowModel` in the environment. The pairing is
/// read before any of them shows. Only a keychain that still can't be read, as
/// before the device's first unlock, shows neither, and is read again.
public struct WindowContent<Content: View>: View {
    @ViewBuilder let content: () -> Content

    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    /// The window's workspace, restored with it.
    @SceneStorage("workspaceID") private var storedWorkspaceID: Int?
    /// Made on appearing, once the window's stored workspace can be read.
    @State private var window: WindowModel?

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        Group {
            if let window {
                paired
                    .environment(window)
                    .onChange(of: window.selectedWorkspaceID, initial: true) { _, id in storedWorkspaceID = id }
                    .onChange(of: model.client == nil) { _, unpaired in
                        if unpaired {
                            // Its workspace and lists belong to the server left.
                            self.window = WindowModel(app: model, workspaceID: nil)
                        } else if window.selectedWorkspaceID == nil {
                            // A launch that couldn't read its defaults made the
                            // window before the pairing came back.
                            window.selectedWorkspaceID = model.lastWorkspaceID
                        }
                    }
            } else {
                Color.clear
                    .onAppear {
                        // Before anything shows: an app launched before the
                        // device's first unlock read nothing when it started.
                        model.restorePairing()
                        window = WindowModel(app: model, workspaceID: storedWorkspaceID)
                    }
            }
        }
        .onChange(of: model.client?.connection == .revoked) { _, revoked in
            if revoked { model.forgetRevokedPairing() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, model.isRestoringPairing { model.restorePairing() }
        }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            if model.isRestoringPairing { model.restorePairing() }
        }
        #endif
    }

    @ViewBuilder
    private var paired: some View {
        if model.client != nil {
            content()
                .environment(\.cohesionClient, model.client)
        } else if model.isRestoringPairing {
            ProgressView("Restoring your pairing…")
        } else if model.wasRevoked {
            RevokedView()
        } else {
            PairingView()
        }
    }
}

extension View {
    /// What every shell's window does while it's open: keeps its lists
    /// current, shows them as last sent at first, and takes the lists from
    /// the window for the screens under it.
    public func keepsWindowLists(_ window: WindowModel) -> some View {
        @Bindable var window = window
        return task(id: window.selectedWorkspaceID) {
            await window.load()
            await window.watch()
        }
        .task { await window.watchAgents() }
        .task { await window.watchTeams() }
        .task { await window.watchProfile() }
        .task { await window.watchActors() }
        .task { await window.watchActorUsage() }
        .task { await window.watchNotices() }
        .onAppear { window.showKeptOnce() }
        .onChange(of: window.selectedWorkspaceID) { window.showKeptOfWorkspace() }
        .errorAlert(window.errorHeldForSheets($window.error))
        .toast($window.notice)
        // For "Forward" in the items' menus, sheets included.
        .environment(\.agents, window.agents)
        .environment(\.agentTeams, window.teams)
        // For tasks' assignees, sheets included.
        .environment(\.profile, window.profile)
    }

    /// The sheets the window's lists open, whatever the shell: `openFeed`,
    /// `openActorSession`, `openContact` and `openAgent` show what one of them
    /// just made.
    public func windowSheets(
        _ window: WindowModel,
        openFeed: @escaping (Int) -> Void,
        openActorSession: @escaping (Int) -> Void,
        openContact: @escaping (Int) -> Void,
        openAgent: @escaping (Int) -> Void
    ) -> some View {
        @Bindable var window = window
        return sizedSheet(isPresented: $window.isAddingFeed) {
            AddFeedView { added in
                await window.load()
                openFeed(added.id)
            }
        }
        .sizedSheet(isPresented: $window.isEditingKinds) {
            ResourceKindsView(
                kinds: window.connectorAccounts.importableKinds,
                shown: window.shownKinds,
                setShown: window.setKind,
                move: window.moveKinds
            )
        }
        .sizedSheet(isPresented: $window.isEditingSavedViews) {
            EditSavedViewsView()
        }
        .sizedSheet(isPresented: $window.showsNewTask) {
            if let workspaceID = window.selectedWorkspaceID {
                NewTaskView(
                    workspaceID: workspaceID,
                    folderID: nil,
                    tagIDs: [],
                    folders: window.folders,
                    tags: window.tags,
                    onAdd: {}
                )
                .presentsLinkedItems()
            }
        }
        .sizedSheet(isPresented: $window.isStartingActorSession) {
            NewActorSessionView(actors: window.actors, clients: window.clients) { session in
                window.list(startedSession: session)
                openActorSession(session.id)
            }
        }
        .sizedSheet(isPresented: $window.isShowingActorUsage) {
            NavigationStack { ActorUsageView(actors: window.actors, usage: window.actorUsage) }
                .presentationDetents([.medium, .large])
        }
        .sizedSheet(item: $window.newContact) { draft in
            ContactForm(subject: .new(draft)) { created, photoError in
                Task {
                    await window.loadContacts()
                    openContact(created.id)
                    window.error = photoError
                }
            }
        }
        .sizedSheet(isPresented: $window.isCreatingAgent) {
            AgentForm { created in
                await window.loadAgents()
                openAgent(created.id)
            }
        }
        .teamDialogs(naming: $window.namingTeam, deleting: $window.deletingTeam) {
            await window.loadTeams()
            await window.loadAgents()
        }
    }
}

/// What a shell's window gives its Dashboard command: opening it there.
public struct ShowDashboardAction {
    let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public func callAsFunction() {
        action()
    }
}

extension FocusedValues {
    /// Opens the focused window's Dashboard, for the Dashboard command.
    @Entry public var showDashboard: ShowDashboardAction?
}

/// One of the workspace's pages, in any shell. A contact is pushed by
/// `contactLink`'s value on the stack it's in.
public struct WorkspacePageView<ContactLink: Hashable>: View {
    let page: WorkspacePage
    let contactLink: (Int) -> ContactLink
    /// Opens a view just saved in place of the list it was saved from.
    let openSavedView: (SavedTaskView) -> Void
    /// Opens another of the workspace's pages, as a task list's title menu does.
    let openPage: (WorkspacePage) -> Void
    /// Opens an agent's chat, as the Dashboard's rows do.
    let openAgent: (Int) -> Void
    /// Opens an actor session, as the Dashboard's rows do.
    let openActorSession: (Int) -> Void

    @Environment(WindowModel.self) private var window
    /// What the contacts are filtered by, by name.
    @State private var contactQuery = ""

    public init(
        page: WorkspacePage,
        contactLink: @escaping (Int) -> ContactLink,
        openSavedView: @escaping (SavedTaskView) -> Void,
        openPage: @escaping (WorkspacePage) -> Void,
        openAgent: @escaping (Int) -> Void,
        openActorSession: @escaping (Int) -> Void
    ) {
        self.page = page
        self.contactLink = contactLink
        self.openSavedView = openSavedView
        self.openPage = openPage
        self.openAgent = openAgent
        self.openActorSession = openActorSession
    }

    public var body: some View {
        if let workspace = window.selectedWorkspace {
            switch page {
            case .dashboard: DashboardView(workspaceID: workspace.id, openAgent: openAgent, openActorSession: openActorSession).id(workspace.id)
            case .today: JournalView(workspaceID: workspace.id)
            case .journal: JournalListView(workspaceID: workspace.id)
            case .documents: DocumentListView(workspaceID: workspace.id)
            case .contacts: contactList
            case .tasks(let scope):
                TaskListView(
                    workspaceID: workspace.id,
                    scope: scope,
                    title: window.title(of: scope),
                    folders: window.folders,
                    tags: window.tags,
                    contacts: window.contacts,
                    openView: openSavedView
                )
                .modifier(TaskListMenu(page: page, open: openPage))
            case .taskView(let id):
                if let view = window.savedViews.first(where: { $0.id == id }) {
                    TaskListView(
                        view: view,
                        folders: window.folders,
                        tags: window.tags,
                        contacts: window.contacts,
                        openView: openSavedView
                    )
                    .modifier(TaskListMenu(page: page, open: openPage))
                }
            case .articles(let filter):
                ArticleListView(
                    filter: filter,
                    title: window.title(of: filter),
                    feeds: window.feeds
                )
            case .resources(let kindID):
                if let kind = window.shownKinds.first(where: { $0.id == kindID }) {
                    ResourceListView(
                        workspaceID: workspace.id,
                        kind: kind,
                        accounts: window.connectorAccounts,
                        clients: window.clients
                    )
                }
            }
        }
    }

    /// The workspace's contacts, filtered by name.
    private var contactList: some View {
        List {
            ForEach(window.contacts.matching(contactQuery)) { contact in
                NavigationLink(value: contactLink(contact.id)) {
                    ContactRow(contact: contact)
                }
            }
        }
        .overlay { contactsUnavailable }
        .navigationTitle("Contacts")
        .searchable(text: $contactQuery, prompt: "Filter by name")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { newContactMenu }
        }
        .refreshable { await window.load(.asked) }
    }

    /// Without contacts, a way to add one; with a filter nothing matches,
    /// that it doesn't.
    @ViewBuilder
    private var contactsUnavailable: some View {
        if window.contacts.isEmpty {
            ContentUnavailableView {
                Label("No Contacts", systemImage: "person.crop.circle")
            } description: {
                Text("No contacts yet.")
            } actions: {
                Button("New Contact") { window.newContact = ContactDraft() }
                #if os(iOS)
                Button("Add from Contacts…") { window.isPickingContact = true }
                #endif
            }
        } else if window.contacts.matching(contactQuery).isEmpty {
            ContentUnavailableView.search(text: contactQuery)
        }
    }

    @ViewBuilder
    private var newContactMenu: some View {
        #if os(iOS)
        Menu("New", systemImage: "plus") {
            Button("New Contact", systemImage: "person.crop.circle.badge.plus") {
                window.newContact = ContactDraft()
            }
            Button("Add from Contacts…", systemImage: "person.crop.rectangle.stack") {
                window.isPickingContact = true
            }
        }
        #else
        Button("New Contact", systemImage: "plus") { window.newContact = ContactDraft() }
        #endif
    }
}

/// A contact from the window's contacts, by id, when it's still there.
public struct ContactPage: View {
    let contactID: Int

    @Environment(WindowModel.self) private var window

    public init(contactID: Int) {
        self.contactID = contactID
    }

    public var body: some View {
        if let contact = window.contacts.first(where: { $0.id == contactID }) {
            ContactView(contact: contact)
        }
    }
}
