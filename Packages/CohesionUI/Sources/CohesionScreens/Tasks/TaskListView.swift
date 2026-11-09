import CohesionCore
import CohesionUI
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// The tasks in one folder, in the inbox, in all of them, or those done or
/// cancelled; the lists spanning folders name each task's under its title.
/// Any list can be narrowed by tags, which a task must have or must not,
/// by priority and by size. The lists share one order, which outlives the app; a
/// saved view keeps its own, with its narrowing, and can take the list's
/// changes or be saved under another name.
struct TaskListView: View {
    let workspaceID: Int
    /// The saved view the list shows, if it is one.
    let view: SavedTaskView?
    let title: String
    let folders: [TaskFolder]
    /// The workspace's task tags, by name.
    let tags: [Tag]
    /// The workspace's contacts, who its tasks can be assigned to.
    let contacts: [Contact]
    /// Opens a view just saved.
    let openView: (SavedTaskView) -> Void

    @Environment(AppModel.self) private var model

    @AppStorage("taskSort") private var storedSort = TaskSort.created
    @AppStorage("taskSortDescending") private var storedDescending = false
    @State private var query: TaskQuery
    @State private var tasks: [TaskItem] = []
    /// How many tasks the whole list has; `tasks` holds the pages loaded
    /// so far.
    @State private var total = 0
    @State private var showsCompleted = false
    @State private var isLoaded = false
    @State private var isAdding = false
    @State private var editing: TaskItem?
    @State private var isManagingTags = false
    @State private var isFiltering = false
    /// Why the naming alert is up: to save the list as a view, or rename it.
    @State private var naming: ViewNaming?
    @State private var name = ""
    @State private var isConfirmingDelete = false
    @State private var error: (any Error)?

    /// A list of `scope`'s tasks, in the order the lists share.
    init(
        workspaceID: Int,
        scope: TaskScope,
        title: String,
        folders: [TaskFolder],
        tags: [Tag],
        contacts: [Contact],
        openView: @escaping (SavedTaskView) -> Void
    ) {
        self.workspaceID = workspaceID
        self.view = nil
        self.title = title
        self.folders = folders
        self.tags = tags
        self.contacts = contacts
        self.openView = openView
        let defaults = UserDefaults.standard
        _query = State(initialValue: TaskQuery(
            scope: scope,
            sort: defaults.string(forKey: "taskSort").flatMap(TaskSort.init(rawValue:)) ?? .created,
            descending: defaults.bool(forKey: "taskSortDescending")
        ))
    }

    /// The tasks `view` lists, in its order.
    init(
        view: SavedTaskView,
        folders: [TaskFolder],
        tags: [Tag],
        contacts: [Contact],
        openView: @escaping (SavedTaskView) -> Void
    ) {
        self.workspaceID = view.workspaceID
        self.view = view
        self.title = view.name
        self.folders = folders
        self.tags = tags
        self.contacts = contacts
        self.openView = openView
        _query = State(initialValue: view.query)
    }

    private var scope: TaskScope { query.scope }

    private enum ViewNaming {
        case new, rename
    }

    var body: some View {
        List {
            TaskRows(
                tasks: $tasks,
                total: $total,
                query: query,
                statuses: statuses,
                folders: folders,
                tags: tags,
                contacts: contacts,
                error: $error,
                edit: { editing = $0 },
                manageTags: { isManagingTags = true },
                reload: { await load() }
            )
            if tasks.count < total {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .task(id: tasks.count) { await loadMore() }
            }
        }
        .overlay {
            if isLoaded && tasks.isEmpty {
                if query.isFiltered {
                    ContentUnavailableView {
                        Label("No Matches", systemImage: "line.3.horizontal.decrease")
                    } actions: {
                        Button("Clear Filters") { query.clearFilters() }
                    }
                } else {
                    ContentUnavailableView("No Tasks", systemImage: "checkmark.circle")
                }
            }
        }
        // Wider than a chat's column: a row's due day, assignee and flag
        // have columns of their own here.
        .centeredColumn(maxWidth: 960)
        .navigationTitle(title)
        .navigationSubtitle(isChanged ? "Edited" : "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Task", systemImage: "plus") {
                    isAdding = true
                }
                .disabled(scope.isFinished)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(
                    "Filter",
                    systemImage: query.isFiltered
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle"
                ) {
                    isFiltering = true
                }
            }
            if !scope.isFinished {
                ToolbarItem(placement: .secondaryAction) {
                    Toggle("Show Completed", systemImage: "checkmark.circle", isOn: $showsCompleted)
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                sortMenu
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Manage Tags…", systemImage: "tag") {
                    isManagingTags = true
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                viewActions
            }
        }
        .sizedSheet(item: $editing) { task in
            TaskDetailView(task: task, folders: folders, tags: tags, contacts: contacts, onSave: { await load() })
                .presentsLinkedItems()
        }
        .sizedSheet(isPresented: $isAdding) {
            NewTaskView(
                workspaceID: workspaceID,
                folderID: scope.folderID,
                tagIDs: query.tags.with,
                folders: folders,
                tags: tags,
                onAdd: { await load() }
            )
            .presentsLinkedItems()
        }
        .sizedSheet(isPresented: $isManagingTags) {
            TagsView(workspaceID: workspaceID, tags: tags)
        }
        .sizedSheet(isPresented: $isFiltering) {
            TaskFilterView(query: $query, tags: tags)
        }
        .alert(naming == .rename ? "Rename View" : "Save View", isPresented: Binding {
            naming != nil
        } set: {
            if !$0 { naming = nil }
        }) {
            TextField("Name", text: $name)
            Button("Cancel", role: .cancel) {}
            Button(naming == .rename ? "Rename" : "Save", action: saveName)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            if naming == .new {
                Text("Keeps this list, how it’s filtered and its order.")
            }
        }
        .confirmationDialog(
            "Delete “\(view?.name ?? "")”?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete View", role: .destructive, action: deleteView)
        } message: {
            Text("Its tasks stay as they are.")
        }
        .forwardsItems()
        .task(id: Reload(query: query, showsCompleted: showsCompleted)) {
            await load(.asked, keepingPlace: false)
        }
        .onChange(of: query) {
            // The lists share one order; a saved view keeps its own.
            guard view == nil else { return }
            storedSort = query.sort
            storedDescending = query.descending
        }
        .refreshable { await load(.asked) }
        .errorAlert($error)
    }

    /// What a load depends on; a change to any of it reloads the list.
    private struct Reload: Hashable {
        let query: TaskQuery
        let showsCompleted: Bool
    }

    /// Whether the list no longer shows what its saved view keeps.
    private var isChanged: Bool {
        guard let view else { return false }
        return query != view.query
    }

    /// The key, then a direction named for it ("Newest First", "Z to A").
    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: Binding {
                query.sort
            } set: {
                query.sort = $0
                // Priority reads most urgent first; everything else starts ascending.
                query.descending = $0 == .priority
            }) {
                ForEach(TaskSort.allCases) { Text($0.label).tag($0) }
            }
            Picker("Direction", selection: $query.descending) {
                Text(query.sort.directions.ascending).tag(false)
                Text(query.sort.directions.descending).tag(true)
            }
        } label: {
            Label("Sort By", systemImage: "arrow.up.arrow.down")
            Text(query.sort.label)
        }
    }

    /// Saving the list as a view; for a view, keeping its changes, going
    /// back to what it keeps, renaming and deleting it.
    @ViewBuilder
    private var viewActions: some View {
        if let view {
            Section {
                if isChanged {
                    Button("Update “\(view.name)”", systemImage: "arrow.triangle.2.circlepath") {
                        updateView(view)
                    }
                    Button("Revert Changes", systemImage: "arrow.uturn.backward") {
                        query = view.query
                    }
                }
                Button("Save as New View…", systemImage: "plus.square.on.square") { startNaming(.new) }
                Button("Rename…", systemImage: "pencil") { startNaming(.rename) }
                Button("Delete View", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
            }
        } else {
            Section {
                Button("Save as View…", systemImage: "bookmark") { startNaming(.new) }
            }
        }
    }

    private func startNaming(_ purpose: ViewNaming) {
        name = purpose == .rename ? view?.name ?? "" : ""
        naming = purpose
    }

    private func saveName() {
        guard let client = model.client, let purpose = naming else { return }
        let name = name.trimmingCharacters(in: .whitespaces)
        Task {
            do {
                switch purpose {
                case .new:
                    openView(try await client.saveTaskView(query, named: name, in: workspaceID))
                case .rename:
                    if let view { try await client.rename(view, to: name) }
                }
            } catch {
                self.error = error
            }
        }
    }

    private func updateView(_ view: SavedTaskView) {
        guard let client = model.client else { return }
        Task {
            do {
                _ = try await client.update(view, to: query)
            } catch {
                self.error = error
            }
        }
    }

    private func deleteView() {
        guard let client = model.client, let view else { return }
        Task {
            do {
                try await client.delete(view)
            } catch {
                self.error = error
            }
        }
    }

    /// Reloads the first page or, keeping its place, as many tasks as are
    /// shown.
    private func load(_ origin: LoadOrigin = .automatic, keepingPlace: Bool = true) async {
        guard let client = model.client else { return }
        await origin.run {
            let wanted = keepingPlace ? max(tasks.count, 50) : 50
            var loaded: [TaskItem] = []
            var total = 0
            repeat {
                let page = try await client.listTasks(
                    in: workspaceID,
                    scope: scope,
                    statuses: statuses,
                    tags: query.tags,
                    priorities: query.priorities,
                    sizes: query.sizes,
                    sort: query.sort,
                    descending: query.descending,
                    offset: loaded.count,
                    limit: min(wanted - loaded.count, 500)
                )
                loaded += page.tasks
                total = page.total
                if page.tasks.isEmpty { break }
            } while loaded.count < min(wanted, total)
            withAnimation { self.tasks = loaded }
            self.total = total
            isLoaded = true
        } failed: { self.error = $0 }
    }

    /// Adds the next page, skipping tasks a shift in the list has already
    /// brought in.
    private func loadMore() async {
        guard let client = model.client else { return }
        await LoadOrigin.automatic.run {
            let page = try await client.listTasks(
                in: workspaceID,
                scope: scope,
                statuses: statuses,
                tags: query.tags,
                priorities: query.priorities,
                sizes: query.sizes,
                sort: query.sort,
                descending: query.descending,
                offset: tasks.count
            )
            let shown = Set(tasks.map(\.id))
            tasks += page.tasks.filter { !shown.contains($0.id) }
            total = page.total
        }
    }

    /// The statuses listed: a finished list's own, else every one while
    /// completed tasks are shown.
    private var statuses: [TaskStatus] {
        switch scope {
        case .done: [.completed]
        case .cancelled: [.cancelled]
        default: showsCompleted ? TaskStatus.allCases : [.incomplete]
        }
    }

}

/// A priority's name beside its flag, for the priority pickers' items.
struct PriorityLabel: View {
    let priority: Vocabulary.Labeled<TaskPriority>

    var body: some View {
        if let flag = priority.kind.menuFlag {
            Label { Text(priority.label) } icon: { flag }
        } else {
            Text(priority.label)
        }
    }
}

extension TaskStatus {
    var label: LocalizedStringKey {
        switch self {
        case .incomplete: "Incomplete"
        case .completed: "Completed"
        case .cancelled: "Cancelled"
        }
    }
}

extension TaskSort {
    var label: LocalizedStringKey {
        switch self {
        case .created: "Date Added"
        case .title: "Title"
        case .priority: "Priority"
        case .size: "Size"
        case .startDate: "Start Date"
        case .dueDate: "Due Date"
        }
    }

    /// The ascending and descending directions, named for this key.
    var directions: (ascending: LocalizedStringKey, descending: LocalizedStringKey) {
        switch self {
        case .created: ("Oldest First", "Newest First")
        case .title: ("A to Z", "Z to A")
        case .priority: ("Lowest First", "Highest First")
        case .size: ("Smallest First", "Largest First")
        case .startDate, .dueDate: ("Earliest First", "Latest First")
        }
    }
}
