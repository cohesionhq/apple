import AppIntents
import CohesionCore
import Foundation

/// What a Tasks widget shows, set in its Edit Widget sheet: a workspace, or
/// all of them, and a view of its tasks. The view's choices follow the
/// workspace.
struct TasksWidgetConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Tasks"
    static let description = IntentDescription("Pick the tasks this widget shows.")

    @Parameter(title: "Workspace") var workspace: TasksWorkspaceEntity?
    @Parameter(title: "View") var view: TasksViewEntity?
}

/// Which of a workspace's tasks a Tasks widget lists. A folder, tag or saved
/// view names the workspace it's in, so one left behind by picking another
/// workspace can be told from one that's there.
enum TasksViewChoice: Hashable {
    case filter(DashboardTaskFilter)
    case upcoming
    case inbox
    case all
    case folder(Int, workspaceID: Int)
    case tag(Int, workspaceID: Int)
    case savedView(Int, workspaceID: Int)

    /// As a widget's settings store it.
    var id: String {
        switch self {
        case .filter(let filter): filter.rawValue
        case .upcoming: "upcoming"
        case .inbox: "inbox"
        case .all: "all"
        case .folder(let id, let workspaceID): "folder/\(workspaceID)/\(id)"
        case .tag(let id, let workspaceID): "tag/\(workspaceID)/\(id)"
        case .savedView(let id, let workspaceID): "savedView/\(workspaceID)/\(id)"
        }
    }

    init?(id: String) {
        if let filter = DashboardTaskFilter(rawValue: id) {
            self = .filter(filter)
            return
        }
        switch id {
        case "upcoming": self = .upcoming
        case "inbox": self = .inbox
        case "all": self = .all
        default:
            let parts = id.split(separator: "/")
            guard parts.count == 3, let workspaceID = Int(parts[1]), let id = Int(parts[2]) else { return nil }
            switch parts[0] {
            case "folder": self = .folder(id, workspaceID: workspaceID)
            case "tag": self = .tag(id, workspaceID: workspaceID)
            case "savedView": self = .savedView(id, workspaceID: workspaceID)
            default: return nil
            }
        }
    }

    /// The workspace it belongs to; `nil` for those every workspace has.
    var workspaceID: Int? {
        switch self {
        case .filter, .upcoming, .inbox, .all: nil
        case .folder(_, let workspaceID), .tag(_, let workspaceID), .savedView(_, let workspaceID): workspaceID
        }
    }

    /// Its name, when it isn't one the user gave it.
    var builtInTitle: String? {
        switch self {
        case .filter(let filter): filter.title
        case .upcoming: "Upcoming"
        case .inbox: "Inbox"
        case .all: "All"
        case .folder, .tag, .savedView: nil
        }
    }

    /// The views every workspace has, in the order the picker lists them.
    static let builtIn: [TasksViewChoice] = [
        .filter(.today), .upcoming, .filter(.overdue), .filter(.highPriority), .filter(.assignedToYou), .inbox, .all,
    ]
}

/// A workspace to pick, or all of them.
struct TasksWorkspaceEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Workspace"
    static let defaultQuery = TasksWorkspaceEntityQuery()
    /// The `id` of All Workspaces, which no workspace has.
    static let allID = 0

    let id: Int
    @Property(title: "Name") var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    /// The workspace it picks; `nil` for all of them.
    var workspaceID: Int? { id == Self.allID ? nil : id }

    init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    static var all: TasksWorkspaceEntity { TasksWorkspaceEntity(id: allID, name: "All Workspaces") }
}

/// All Workspaces, then the workspaces, from cohesiond with the app's pairing.
nonisolated struct TasksWorkspaceEntityQuery: EntityQuery {
    /// Those named. Away from the server there's no telling what they're
    /// called or whether they're there, so each keeps its id.
    func entities(for identifiers: [Int]) async throws -> [TasksWorkspaceEntity] {
        let workspaces = try? await TasksPickerLookup.workspaces()
        return identifiers.compactMap { id in
            if id == TasksWorkspaceEntity.allID { return .all }
            guard let workspaces else { return TasksWorkspaceEntity(id: id, name: "Workspace") }
            return workspaces.first { $0.id == id }
        }
    }

    func suggestedEntities() async throws -> [TasksWorkspaceEntity] {
        [.all] + ((try? await TasksPickerLookup.workspaces()) ?? [])
    }

    func defaultResult() async -> TasksWorkspaceEntity? { .all }
}

/// A view of the tasks to pick.
struct TasksViewEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "View"
    static let defaultQuery = TasksViewEntityQuery()

    let id: String
    @Property(title: "Name") var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(_ view: TasksViewChoice, name: String) {
        self.init(id: view.id, name: name)
    }
}

/// The views every workspace has, and those of the workspace the widget has
/// picked: its folders, tags and saved views.
nonisolated struct TasksViewEntityQuery: EntityQuery {
    @IntentParameterDependency<TasksWidgetConfiguration>(\.$workspace) var configuration

    /// Those named, whether or not they're still there: the widget says so
    /// itself when one is gone, rather than quietly showing another.
    func entities(for identifiers: [String]) async throws -> [TasksViewEntity] {
        await TasksPickerLookup.views(for: identifiers)
    }

    func suggestedEntities() async throws -> IntentItemCollection<TasksViewEntity> {
        var sections = await [IntentItemSection(items: TasksPickerLookup.builtInViews().map { IntentItem($0) })]
        if let workspaceID = configuration?.workspace.workspaceID,
           let named = try? await TasksPickerLookup.namedViews(in: workspaceID) {
            sections += named.filter { !$0.views.isEmpty }.map { section in
                IntentItemSection(section.title, items: section.views.map { IntentItem($0) })
            }
        }
        return IntentItemCollection(sections: sections)
    }

    func defaultResult() async -> TasksViewEntity? {
        await TasksPickerLookup.builtInViews().first
    }
}

/// What the Edit Widget sheet's pickers list, read from cohesiond. It gives up
/// on the server after 3 seconds, so the sheet still opens away from it.
private enum TasksPickerLookup {
    static func workspaces() async throws -> [TasksWorkspaceEntity] {
        try await WidgetDeadline.run(seconds: 3) {
            try await client().listWorkspaces().map { TasksWorkspaceEntity(id: $0.id, name: $0.displayName) }
        }
    }

    static func namedViews(in workspaceID: Int) async throws -> [(title: LocalizedStringResource, views: [TasksViewEntity])] {
        try await WidgetDeadline.run(seconds: 3) {
            let client = try client()
            async let folders = client.listTaskFolders(in: workspaceID)
            async let tags = client.listTaskTags(in: workspaceID)
            async let savedViews = client.listSavedTaskViews(in: workspaceID)
            return try await [
                ("Folders", folders.map { TasksViewEntity(.folder($0.id, workspaceID: workspaceID), name: $0.title) }),
                ("Tags", tags.map { TasksViewEntity(.tag($0.id, workspaceID: workspaceID), name: $0.name) }),
                ("Saved Views", savedViews.map { TasksViewEntity(.savedView($0.id, workspaceID: workspaceID), name: $0.name) }),
            ]
        }
    }

    static func builtInViews() -> [TasksViewEntity] {
        TasksViewChoice.builtIn.map { TasksViewEntity($0, name: $0.builtInTitle ?? "") }
    }

    /// Those `identifiers` name, under their names as cohesiond has them when
    /// it can be asked.
    static func views(for identifiers: [String]) async -> [TasksViewEntity] {
        let views = identifiers.compactMap { TasksViewChoice(id: $0) }
        var named: [TasksViewEntity] = []
        for workspaceID in Set(views.compactMap { $0.workspaceID }) {
            let sections = try? await namedViews(in: workspaceID)
            named += sections?.flatMap(\.views) ?? []
        }
        return views.map { view in
            let name = view.builtInTitle ?? named.first { $0.id == view.id }?.name ?? "View"
            return TasksViewEntity(view, name: name)
        }
    }

    private static func client() throws -> CohesionClient {
        switch Pairing.read() {
        case .paired(let pairing): try CohesionClient(pairing: pairing)
        case .unpaired, .unavailable: throw PairingError.unavailable
        }
    }
}

/// Runs `work`, cancelling it after `seconds`: WidgetKit won't wait out a
/// request to a server that can't be reached.
enum WidgetDeadline {
    static func run<Value: Sendable>(seconds: Int, _ work: @escaping @MainActor () async throws -> Value) async throws -> Value {
        let running = Task { try await work() }
        let deadline = Task {
            try await Task.sleep(for: .seconds(seconds))
            running.cancel()
        }
        defer { deadline.cancel() }
        return try await running.value
    }
}

/// Completes a task from the widget's checkbox, keeping the tap until
/// cohesiond has it. It runs in the widget's extension, which alone holds it.
struct CompleteTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Task"
    static var isDiscoverable: Bool { false }
    static var supportedModes: IntentModes { .background }
    /// Before the device's first unlock the pairing it's kept against can't be read.
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }

    @Parameter(title: "Task") var taskID: Int
    @Parameter(title: "Workspace") var workspaceID: Int

    init() {}

    init(taskID: Int, workspaceID: Int) {
        self.taskID = taskID
        self.workspaceID = workspaceID
    }

    func perform() async throws -> some IntentResult {
        try await MainActor.run {
            switch Pairing.read() {
            case .paired(let pairing):
                PendingCompletions.add(taskID: taskID, workspaceID: workspaceID, server: pairing.serverFingerprint)
            // The widget says it isn't paired once it reloads.
            case .unpaired: break
            case .unavailable: throw PairingError.unavailable
            }
        }
        // WidgetKit reloads the widget after this, which sends what's waiting.
        return .result()
    }
}

/// Tasks completed from the widget that cohesiond hasn't heard of yet. A tap
/// away from the server waits here, in the extension's own defaults, and each
/// reload of the widget sends what's waiting; meanwhile the row stays gone.
enum PendingCompletions {
    /// One tap, on the server that was paired when it was made.
    struct Completion: Codable, Hashable {
        let taskID: Int
        let workspaceID: Int
        let server: String
    }

    private static let key = "pendingCompletions"

    private static var waiting: [Completion] {
        get {
            UserDefaults.standard.data(forKey: key)
                .flatMap { try? JSONDecoder().decode([Completion].self, from: $0) } ?? []
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: key)
        }
    }

    static func add(taskID: Int, workspaceID: Int, server: String) {
        let completion = Completion(taskID: taskID, workspaceID: workspaceID, server: server)
        if !waiting.contains(completion) { waiting.append(completion) }
    }

    /// Sends what's waiting for the paired server and returns the tasks still
    /// waiting. A tap from an earlier pairing means nothing to this server. A
    /// refusal is an answer, as for a task that's gone or read-only, so it
    /// isn't sent again; anything else is tried on the next reload.
    static func send(with client: CohesionClient, server: String) async -> Set<Int> {
        waiting.removeAll { $0.server != server }
        for completion in waiting {
            do {
                try await client.setStatus(.completed, ofTask: completion.taskID, in: completion.workspaceID)
            } catch let error as ServerError where !error.code.hasPrefix("http") {
            } catch {
                break
            }
            waiting.removeAll { $0 == completion }
        }
        return Set(waiting.map(\.taskID))
    }
}
