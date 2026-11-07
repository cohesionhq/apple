import Foundation


/// An agent on a client's device, such as Claude Code in one directory,
/// that Cohesion hands sessions to. It shares its client's online state, which
/// the clients list says.
public struct Actor: Decodable, Identifiable, Hashable {
    public let id: Int
    /// The client that offers it.
    public let clientID: Int
    /// The agent's product, such as "Claude Code".
    public let product: String
    /// Where it works, such as a directory.
    public let scope: String
    /// How it can run a session, the first the default.
    public let modes: [ActorMode]
    /// The models it can run a session on, the first the default.
    public let models: [ActorModel]
    /// The product on its client's name, such as "Claude Code on Sam's
    /// MacBook Pro".
    public let title: String

    /// Where it works, by its last part: "cohesion" for a project's directory.
    public var scopeName: String {
        scope.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init) ?? scope
    }

    enum CodingKeys: String, CodingKey {
        case id, product, scope, modes, models, title
        case clientID = "client_id"
    }
}

/// One way an actor can run a session, such as accepting edits on its own.
public struct ActorMode: Decodable, Hashable {
    public let identifier: String
    public let title: String
    /// What it lets the actor do without asking.
    public let description: String?
}

/// A model an actor can run a session on.
public struct ActorModel: Decodable, Hashable {
    public let identifier: String
    public let title: String
    /// The reasoning efforts it takes, least first; none when it takes no setting.
    public let efforts: [ActorEffort]
}

public struct ActorEffort: Decodable, Hashable {
    public let identifier: String
    public let title: String
}

/// A whole unit of work handed to an actor, such as a Claude Code session. It stays until
/// the user resolves it, and never ends for good: saying something to one
/// that is done, failed or resolved starts it again.
public struct ActorSession: Decodable, Identifiable, Hashable {
    public let id: Int
    public let actorID: Int
    /// The first line of the prompt that started it, as cohesiond set it.
    public let title: String
    /// The actor's mode it runs in; `nil` for the actor's default.
    public let mode: String?
    /// The model it started on; `nil` for the actor's default.
    public let model: String?
    /// The reasoning effort it started with; `nil` for the model's default.
    public let effort: String?
    /// When its status last changed, which orders the sessions.
    public let statusChangedAt: Date
    public let status: ActorSessionStatus
    /// Whether its actor finished a stretch of work since the user last read it.
    public var isUnread: Bool
    /// When the user last read it; `nil` if never.
    public var readAt: Date?
    /// How full its context window is, as its actor last said; `nil` until it does.
    public let context: ContextUsage?

    enum CodingKeys: String, CodingKey {
        case id, title, mode, model, effort, status, context
        case actorID = "actor_id"
        case statusChangedAt = "status_changed_at"
        case isUnread = "unread"
        case readAt = "read_at"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        actorID = try container.decode(Int.self, forKey: .actorID)
        title = try container.decode(String.self, forKey: .title)
        mode = try container.decodeIfPresent(String.self, forKey: .mode)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        effort = try container.decodeIfPresent(String.self, forKey: .effort)
        statusChangedAt = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .statusChangedAt))
        status = try container.decode(ActorSessionStatus.self, forKey: .status)
        isUnread = try container.decode(Bool.self, forKey: .isUnread)
        readAt = try container.decodeIfPresent(Double.self, forKey: .readAt).map(Date.init(timeIntervalSince1970:))
        context = try container.decodeIfPresent(ContextUsage.self, forKey: .context)
    }

    /// Where it ranks in the sidebar: what needs the user, then what works,
    /// then what finished unread, then the rest.
    public var sidebarRank: Int {
        switch status {
        case .needsAttention: 0
        case .working: 1
        case .idle, .failed: isUnread ? 2 : 3
        case .resolved: 4
        }
    }
}

extension [ActorSession] {
    /// What the sidebar lists, as the web's does: every session cohesiond
    /// lists, which leaves the resolved out, by `sidebarRank`, then in
    /// cohesiond's order.
    public var current: [ActorSession] {
        enumerated()
            .sorted { ($0.element.sidebarRank, $0.offset) < ($1.element.sidebarRank, $1.offset) }
            .map(\.element)
    }

    /// How many are working or need the user.
    public var goingCount: Int { count { $0.status.isGoing } }
}

/// How full a session's context window is, in tokens.
public struct ContextUsage: Decodable, Hashable {
    public let usedTokens: Int
    /// The most it can hold, more than zero.
    public let totalTokens: Int

    /// How full it is, from 0 to 1.
    public var share: Double { min(Double(usedTokens) / Double(totalTokens), 1) }

    enum CodingKeys: String, CodingKey {
        case usedTokens = "used_tokens"
        case totalTokens = "total_tokens"
    }
}

/// How much of its plan's limits a usage pool has used, as the latest
/// report among its actors said; only while one of their clients is
/// connected. A pool is an account several actors draw on, or a single
/// actor whose limits are its own.
public struct ActorUsage: Decodable {
    /// The actors drawing on it, least id first.
    public let actorIDs: [Int]
    /// In the order to show them; none when the actors run on no plan.
    public let plan: [PlanUsage]
    /// The account the actors share; `nil` for a single actor's own limits.
    public let pool: UsagePool?

    enum CodingKeys: String, CodingKey {
        case plan, pool
        case actorIDs = "actor_ids"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        actorIDs = try container.decode([Int].self, forKey: .actorIDs)
        plan = try container.decodeIfPresent([PlanUsage].self, forKey: .plan) ?? []
        pool = try container.decodeIfPresent(UsagePool.self, forKey: .pool)
    }
}

/// An account several actors draw on, whose one set of plan limits they share.
public struct UsagePool: Decodable {
    /// Names the account for good, the same from every actor drawing on it.
    public let id: String
    /// The account, as people read it: "sam@example.com".
    public let name: String
}

/// One limit of an actor's plan, such as its five-hour limit.
public struct PlanUsage: Decodable {
    /// What the limit is, in a few words: "5-hour limit".
    public let label: String
    /// How much of it is used, from 0 to 1.
    public let used: Double
    /// `nil` when unknown.
    public let resetsAt: Date?

    enum CodingKeys: String, CodingKey {
        case label, used
        case resetsAt = "resets_at"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        used = try container.decode(Double.self, forKey: .used)
        resetsAt = try container.decodeIfPresent(Double.self, forKey: .resetsAt).map(Date.init(timeIntervalSince1970:))
    }
}

/// An image that came with a message in an actor session, the user's or the actor's.
public struct ActorSessionAttachment: Decodable, Identifiable {
    public let id: Int
    public let mediaType: String
    /// The image, base64-encoded.
    public let data: String

    enum CodingKeys: String, CodingKey {
        case id, data
        case mediaType = "media_type"
    }

    public var image: PlatformImage? {
        PlatformImage.decoding(base64: data)
    }
}

/// Where an actor session stands: as its actor last reported, or resolved,
/// which only the user (or an agent for them) says.
public enum ActorSessionStatus: String, Decodable, Hashable {
    case working, needsAttention, idle, failed
    /// The user is done with it: lists leave it out, and cohesiond deletes
    /// it once it has sat resolved for the actor session retention.
    case resolved

    /// Whether the session is going on: working, or waiting on the user.
    public var isGoing: Bool {
        self == .working || self == .needsAttention
    }
}

/// One entry in an actor session's transcript.
public struct ActorSessionMessage: Decodable, Identifiable {
    public let id: Int
    public let sentAt: Date
    /// Who said it and what, tagged by `sender` on the wire.
    public let content: Content
    /// Whether the user has responded to it; only a request can be.
    public var answered: Bool
    /// How many images came with it; `attachments(ofActorSessionMessage:)` fetches them.
    public let attachmentCount: Int

    public enum Content: Decodable {
        case actor(ActorMessageContent)
        case user(ActorUserContent)

        private enum CodingKeys: String, CodingKey {
            case sender
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(String.self, forKey: .sender) {
            case "user": self = .user(try ActorUserContent(from: decoder))
            default: self = .actor(try ActorMessageContent(from: decoder))
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, content, answered
        case sentAt = "sent_at"
        case attachmentCount = "attachment_count"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        sentAt = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .sentAt))
        content = try container.decode(Content.self, forKey: .content)
        answered = try container.decode(Bool.self, forKey: .answered)
        attachmentCount = try container.decode(Int.self, forKey: .attachmentCount)
    }
}

/// What an actor says in a session. The last three are requests, which the
/// session waits on the user to respond to.
public enum ActorMessageContent: Decodable {
    /// Its own words, as Markdown.
    case text(String)
    case toolUse(ActorToolUse)
    case question([ActorQuestion])
    case permission(ActorPermissionRequest)
    /// A plan, as Markdown, to approve before it starts.
    case plan(String)
    /// A kind from a newer cohesiond than this build knows; not shown.
    case unknown

    private enum CodingKeys: String, CodingKey {
        case kind, text, questions, plan
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "text": self = .text(try container.decode(String.self, forKey: .text))
        case "toolUse": self = .toolUse(try ActorToolUse(from: decoder))
        case "question": self = .question(try container.decode([ActorQuestion].self, forKey: .questions))
        case "permission": self = .permission(try ActorPermissionRequest(from: decoder))
        case "plan": self = .plan(try container.decode(String.self, forKey: .plan))
        default: self = .unknown
        }
    }
}

/// A tool an actor ran, and when it ended.
public struct ActorToolUse: Decodable {
    /// As the actor names it, such as "Edit".
    public let tool: String
    /// What it did, in a line, such as "src/main.rs".
    public let summary: String
    /// `nil` while it runs, and for one whose actor never said it ended.
    public let endedAt: Date?

    enum CodingKeys: String, CodingKey {
        case tool, summary
        case endedAt = "ended_at"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tool = try container.decode(String.self, forKey: .tool)
        summary = try container.decode(String.self, forKey: .summary)
        endedAt = try container.decodeIfPresent(Double.self, forKey: .endedAt).map(Date.init(timeIntervalSince1970:))
    }
}

/// One question an actor asks.
public struct ActorQuestion: Decodable {
    /// A short label for it, such as "Auth method".
    public let header: String?
    public let question: String
    /// The answers to pick from; none for a question answered in words.
    public let options: [Option]
    public let multiSelect: Bool
    /// Whether the user may answer in their own words instead.
    public let allowsOther: Bool

    /// Whether it takes an answer in words.
    public var takesWords: Bool { allowsOther || options.isEmpty }

    public struct Option: Decodable {
        public let label: String
        /// What picking it means.
        public let description: String?

        public init(label: String, description: String?) {
            self.label = label
            self.description = description
        }
    }

    enum CodingKeys: String, CodingKey {
        case header, question, options
        case multiSelect = "multi_select"
        case allowsOther = "allows_other"
    }
}

/// Something an actor needs the user's leave to do.
public struct ActorPermissionRequest: Decodable {
    public let subject: Subject
    /// Why it wants to, in its words.
    public let reason: String?
    /// The decisions it takes, in the order to offer them.
    public let decisions: [ActorPermissionDecision]

    public enum Subject: Decodable {
        /// A shell command, and the directory it runs in.
        case command(String, cwd: String?)
        case fileChange([ActorFileChange])
        /// Any other tool, with its input.
        case tool(name: String, input: JSONValue)
        /// A kind from a newer cohesiond than this build knows.
        case unknown

        private enum CodingKeys: String, CodingKey {
            case kind, command, cwd, changes, name, input
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(String.self, forKey: .kind) {
            case "command":
                self = .command(
                    try container.decode(String.self, forKey: .command),
                    cwd: try container.decodeIfPresent(String.self, forKey: .cwd)
                )
            case "fileChange": self = .fileChange(try container.decode([ActorFileChange].self, forKey: .changes))
            case "tool":
                self = .tool(
                    name: try container.decode(String.self, forKey: .name),
                    input: try container.decodeIfPresent(JSONValue.self, forKey: .input) ?? .null
                )
            default: self = .unknown
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case subject, reason, decisions
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subject = try container.decode(Subject.self, forKey: .subject)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        // A decision newer than this build is left off rather than hiding the request.
        decisions = try container.decode([String].self, forKey: .decisions)
            .compactMap(ActorPermissionDecision.init(rawValue:))
    }
}

/// What the user decides about a permission request.
public enum ActorPermissionDecision: String, Decodable {
    /// This once.
    case allow
    /// This and the like for the rest of the session.
    case allowForSession
    /// Not this; the actor carries on without it.
    case deny
    /// Not this, and stop what it is doing.
    case abort
}

/// One file an actor asks to change.
public struct ActorFileChange: Decodable {
    public let path: String
    public let change: Kind
    /// The change as a unified diff, when the actor has one.
    public let diff: String?

    public enum Kind: String, Decodable {
        case add, update, delete
    }
}

/// The answer to one of an actor's questions.
public struct ActorAnswer {
    /// The labels of the options picked.
    public let selected: [String]
    /// The answer in the user's own words, where the question allows it.
    public let other: String?

    public init(selected: [String], other: String?) {
        self.selected = selected
        self.other = other
    }
}

/// What the user says in an actor session. Every kind but `text` responds to
/// the request message `requestID`.
public enum ActorUserContent: Decodable {
    case text(String)
    /// One per question, in order.
    case answers(requestID: Int, [ActorAnswer])
    /// With a note to the actor, such as why not.
    case permission(requestID: Int, ActorPermissionDecision, message: String?)
    /// With what to change, when not approved.
    case plan(requestID: Int, approved: Bool, feedback: String?)
    /// A kind from a newer cohesiond than this build knows; not shown.
    case unknown

    private enum CodingKeys: String, CodingKey {
        case kind, text, answers, decision, message, approved, feedback
        case requestID = "request_id"
    }

    private struct WireAnswer: Decodable {
        let selected: [String]
        let other: String?
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "text": self = .text(try container.decode(String.self, forKey: .text))
        case "answers":
            self = .answers(
                requestID: try container.decode(Int.self, forKey: .requestID),
                try container.decode([WireAnswer].self, forKey: .answers).map {
                    ActorAnswer(selected: $0.selected, other: $0.other)
                }
            )
        case "permission":
            guard let decision = ActorPermissionDecision(rawValue: try container.decode(String.self, forKey: .decision))
            else { self = .unknown; return }
            self = .permission(
                requestID: try container.decode(Int.self, forKey: .requestID),
                decision,
                message: try container.decodeIfPresent(String.self, forKey: .message)
            )
        case "plan":
            self = .plan(
                requestID: try container.decode(Int.self, forKey: .requestID),
                approved: try container.decode(Bool.self, forKey: .approved),
                feedback: try container.decodeIfPresent(String.self, forKey: .feedback)
            )
        default: self = .unknown
        }
    }

    /// The request it responds to; `nil` for text.
    public var requestID: Int? {
        switch self {
        case .answers(let requestID, _), .permission(let requestID, _, _), .plan(let requestID, _, _): requestID
        case .text, .unknown: nil
        }
    }

    /// The content as `sendActorSessionMessage` takes it, its `nil`s left out.
    public var arguments: [String: Any] {
        let fields: [String: Any?] = switch self {
        case .text(let text):
            ["kind": "text", "text": text]
        case .answers(let requestID, let answers):
            [
                "kind": "answers",
                "request_id": requestID,
                "answers": answers.map { answer -> [String: Any] in
                    var wire: [String: Any] = ["selected": answer.selected]
                    wire["other"] = answer.other
                    return wire
                },
            ]
        case .permission(let requestID, let decision, let message):
            ["kind": "permission", "request_id": requestID, "decision": decision.rawValue, "message": message]
        case .plan(let requestID, let approved, let feedback):
            ["kind": "plan", "request_id": requestID, "approved": approved, "feedback": feedback]
        case .unknown:
            [:]
        }
        return fields.compactMapValues { $0 }
    }
}
