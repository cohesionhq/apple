import Foundation

/// A place in the app a `cohesionplus://` URL opens, such as a Live
/// Activity's tap, or a `cohesion://` link in Markdown that one agent, task,
/// document or actor session writes to another. Each case is one kind of thing
/// the app can show.
public enum AppLink: Hashable, Sendable {
    /// An agent's chat: `cohesionplus://agent/<id>`, or
    /// `cohesion://agent/<id>` in Markdown.
    case agent(Int)
    /// An actor session's transcript: `cohesionplus://actor-session/<id>`, or
    /// `cohesion://actor-session/<id>` in Markdown.
    case actorSession(Int)
    /// A task: `cohesionplus://task/<workspaceId>/<id>`, or
    /// `cohesion://task/<workspaceId>/<id>` in Markdown. `workspaceID` is
    /// `nil` for the older `…/task/<id>`, which names no workspace.
    case task(Int, workspaceID: Int?)
    /// A document, a journal entry too:
    /// `cohesionplus://document/<workspaceId>/<id>`, or
    /// `cohesion://document/<workspaceId>/<id>` in Markdown. `workspaceID` is
    /// `nil` for the older `…/document/<id>`, which names no workspace.
    case document(Int, workspaceID: Int?)
    /// The agents and actor sessions: `cohesionplus://agents`.
    case agents
    /// A new task in the window's workspace: `cohesionplus://new-task`.
    case newTask
    /// A new session for an actor: `cohesionplus://new-actor-session`.
    case newActorSession

    public static let scheme = "cohesionplus"
    /// The scheme of the links agents, tasks, documents and actor sessions
    /// write to each other, which the web UI opens too.
    public static let internalScheme = "cohesion"

    /// The link `url` names; `nil` for any other URL, since anything on the
    /// device can open one, and any agent can write one.
    public init?(url: URL) {
        guard let scheme = url.scheme, scheme == Self.scheme || scheme == Self.internalScheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.query == nil, components.fragment == nil
        else { return nil }
        let path = components.path.split(separator: "/")
        if path.isEmpty {
            switch components.host {
            case "agents": self = .agents
            case "new-task": self = .newTask
            case "new-actor-session": self = .newActorSession
            default: return nil
            }
            return
        }
        let ids = path.compactMap { Int($0) }.filter { $0 > 0 }
        guard ids.count == path.count else { return nil }
        switch (components.host, ids.count) {
        case ("agent", 1): self = .agent(ids[0])
        case ("actor-session", 1): self = .actorSession(ids[0])
        case ("task", 1): self = .task(ids[0], workspaceID: nil)
        case ("task", 2): self = .task(ids[1], workspaceID: ids[0])
        case ("document", 1): self = .document(ids[0], workspaceID: nil)
        case ("document", 2): self = .document(ids[1], workspaceID: ids[0])
        default: return nil
        }
    }

    public var url: URL {
        switch self {
        case .agent(let id): URL(string: "\(Self.scheme)://agent/\(id)")!
        case .actorSession(let id): URL(string: "\(Self.scheme)://actor-session/\(id)")!
        case .task(let id, let workspaceID): URL(string: "\(Self.scheme)://task/\(Self.path(id, in: workspaceID))")!
        case .document(let id, let workspaceID): URL(string: "\(Self.scheme)://document/\(Self.path(id, in: workspaceID))")!
        case .agents: URL(string: "\(Self.scheme)://agents")!
        case .newTask: URL(string: "\(Self.scheme)://new-task")!
        case .newActorSession: URL(string: "\(Self.scheme)://new-actor-session")!
        }
    }

    /// `<workspaceId>/<id>`, or `<id>` alone when the workspace isn't known.
    private static func path(_ id: Int, in workspaceID: Int?) -> String {
        switch workspaceID {
        case .some(let workspaceID): "\(workspaceID)/\(id)"
        case .none: "\(id)"
        }
    }
}
