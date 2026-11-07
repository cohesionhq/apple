#if os(iOS)
import AppIntents

/// The intents the app and the widgets share, for each target's own
/// `AppIntentsPackage` to include. iOS only: the Mac has no controls.
public nonisolated struct CohesionCoreIntents: AppIntentsPackage {}

/// Shows a link in the app, as a notification's tap does. The app registers
/// it on launch; the intents below run only in the app, so nothing else needs it.
public nonisolated struct AppLinkOpener: Sendable {
    public let open: @MainActor @Sendable (AppLink) -> Void

    public init(open: @escaping @MainActor @Sendable (AppLink) -> Void) {
        self.open = open
    }
}

/// Opens the new task sheet, in the workspace the window shows.
public struct AddTaskIntent: AppIntent {
    public static let title: LocalizedStringResource = "Add Task"
    public static let description = IntentDescription("Opens a new task in Cohesion.")
    public static var supportedModes: IntentModes { .foreground }
    public static var allowedExecutionTargets: IntentExecutionTargets { .main }
    /// Before the device's first unlock the app couldn't read its pairing.
    public static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }

    @Dependency private var opener: AppLinkOpener

    public init() {}

    public func perform() async throws -> some IntentResult {
        await opener.open(.newTask)
        return .result()
    }
}

/// Opens the actor composer, on the actor last picked.
public struct NewActorSessionIntent: AppIntent {
    public static let title: LocalizedStringResource = "New Actor Session"
    public static let description = IntentDescription("Opens a new session for an actor in Cohesion.")
    public static var supportedModes: IntentModes { .foreground }
    public static var allowedExecutionTargets: IntentExecutionTargets { .main }
    /// Before the device's first unlock the app couldn't read its pairing.
    public static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }

    @Dependency private var opener: AppLinkOpener

    public init() {}

    public func perform() async throws -> some IntentResult {
        await opener.open(.newActorSession)
        return .result()
    }
}

/// Opens an agent's chat, or the list of agents when none is named.
public struct OpenAgentChatIntent: AppIntent {
    public static let title: LocalizedStringResource = "Chat with Agent"
    public static let description = IntentDescription("Opens a chat with an agent in Cohesion.")
    public static var supportedModes: IntentModes { .foreground }
    public static var allowedExecutionTargets: IntentExecutionTargets { .main }
    /// Before the device's first unlock the app couldn't read its pairing.
    public static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }
    public static var parameterSummary: some ParameterSummary {
        Summary("Chat with \(\.$agent)")
    }

    @Parameter(title: "Agent") public var agent: AgentEntity?

    @Dependency private var opener: AppLinkOpener

    public init() {}

    public init(agent: AgentEntity?) {
        self.agent = agent
    }

    public func perform() async throws -> some IntentResult {
        await opener.open(agent.map { .agent($0.id) } ?? .agents)
        return .result()
    }
}

/// Opens a task's detail, for a row of the Tasks widget's small size, where a
/// `Link` doesn't work. Not offered in Shortcuts, which has no way to name a task.
public struct OpenTaskIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Task"
    public static var isDiscoverable: Bool { false }
    public static var supportedModes: IntentModes { .foreground }
    public static var allowedExecutionTargets: IntentExecutionTargets { .main }
    /// Before the device's first unlock the app couldn't read its pairing.
    public static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }

    @Parameter(title: "Task") public var taskID: Int
    @Parameter(title: "Workspace") public var workspaceID: Int

    @Dependency private var opener: AppLinkOpener

    public init() {}

    public init(taskID: Int, workspaceID: Int) {
        self.taskID = taskID
        self.workspaceID = workspaceID
    }

    public func perform() async throws -> some IntentResult {
        await opener.open(.task(taskID, workspaceID: workspaceID))
        return .result()
    }
}

/// An agent, as a control or a shortcut names it.
public struct AgentEntity: AppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Agent"
    public static let defaultQuery = AgentEntityQuery()

    public let id: Int
    @Property(title: "Name") public var name: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

/// The agents, from cohesiond with the app's pairing.
public nonisolated struct AgentEntityQuery: EntityQuery {
    public init() {}

    /// The agents named that are still there. Away from the server there's
    /// no telling, so each keeps its id: a control still opens its chat at
    /// once, where the app says it can't connect.
    public func entities(for identifiers: [Int]) async throws -> [AgentEntity] {
        let agents = await withTaskGroup(of: [AgentEntity]?.self) { group in
            group.addTask { try? await Self.agents() }
            group.addTask {
                try? await Task.sleep(for: .seconds(3))
                return nil
            }
            defer { group.cancelAll() }
            return await group.next() ?? nil
        }
        guard let agents else { return identifiers.map { AgentEntity(id: $0, name: "Agent") } }
        return agents.filter { identifiers.contains($0.id) }
    }

    /// Every agent, in the agents list's order, for the picker.
    public func suggestedEntities() async throws -> [AgentEntity] {
        try await Self.agents()
    }

    @MainActor
    private static func agents() async throws -> [AgentEntity] {
        switch Pairing.read() {
        case .paired(let pairing):
            try await CohesionClient(pairing: pairing).listAgents().map {
                AgentEntity(id: $0.id, name: $0.name)
            }
        case .unpaired: []
        case .unavailable: throw PairingError.unavailable
        }
    }
}
#endif
