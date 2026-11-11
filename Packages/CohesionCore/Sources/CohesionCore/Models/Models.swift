import Foundation

/// What cohesiond says about itself.
public struct ServerAbout: Decodable {
    public let version: String
}

/// A client cohesiond trusts, as the clients list shows it.
public struct Client: Decodable, Identifiable {
    public let id: Int
    public let clientName: String
    /// Whether the client has a session open now. The one place presence is
    /// said: an actor can take a session while its client is online.
    public let online: Bool

    enum CodingKeys: String, CodingKey {
        case id, online
        case clientName = "client_name"
    }
}

/// A top-level container for documents and tasks.
public struct Workspace: Decodable, Identifiable, Hashable {
    public let id: Int
    public let title: String
    public let emoji: String?

    public var displayName: String {
        [emoji, title].compactMap(\.self).joined(separator: " ")
    }
}

// MARK: - Tasks

/// A to-do item in a workspace. Named apart from Swift's `Task`.
public struct TaskItem: Decodable, Identifiable, Hashable {
    public let id: Int
    public let workspaceID: Int
    public let folderID: Int?
    public let title: String
    public let description: String
    public var status: TaskStatus
    public var priority: TaskPriority
    /// `nil` when it has none, or from a cohesiond older than sizes.
    public var size: TaskSize?
    /// Who it's assigned to; `nil` when no one is, or from a cohesiond older
    /// than assignees.
    public var assignee: TaskAssignee?
    /// `"YYYY-MM-DD"`, a calendar day.
    public let startDate: String?
    public let dueDate: String?
    public var tagIDs: [Int]

    enum CodingKeys: String, CodingKey {
        case id, title, description, status, priority, size, assignee
        case workspaceID = "workspace_id"
        case folderID = "task_folder_id"
        case startDate = "start_date"
        case dueDate = "due_date"
        case tagIDs = "tag_ids"
    }
}

/// Who a task is assigned to: the user, one of their agents, or a contact
/// of the task's workspace. Tagged by `kind` on the wire.
public enum TaskAssignee: Decodable, Hashable {
    case user
    case agent(Int)
    case contact(Int)

    private enum CodingKeys: String, CodingKey {
        case kind
        case agentID = "agent_id"
        case contactID = "contact_id"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "agent": self = .agent(try container.decode(Int.self, forKey: .agentID))
        case "contact": self = .contact(try container.decode(Int.self, forKey: .contactID))
        case "user": self = .user
        case let kind:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: container, debugDescription: "Unknown assignee \(kind)"
            )
        }
    }

    /// As `setTaskAssignee` takes it.
    public var wireValue: [String: Any] {
        switch self {
        case .user: ["kind": "user"]
        case .agent(let id): ["kind": "agent", "agent_id": id]
        case .contact(let id): ["kind": "contact", "contact_id": id]
        }
    }
}

/// Which of a workspace's tasks a list shows: one of the lists every
/// workspace has, or a folder's open tasks. On the wire, as a saved view's
/// `scope`, a list's name or the folder's id.
public enum TaskScope: Hashable, Decodable {
    /// The open tasks in no folder.
    case inbox
    case folder(Int)
    /// Every open task, in any folder or the inbox.
    case all
    /// Every completed task.
    case done
    /// Every cancelled task.
    case cancelled

    /// The folder a task added here goes into; `nil` for the inbox.
    public var folderID: Int? {
        if case .folder(let id) = self { id } else { nil }
    }

    /// Whether it lists only finished tasks, so it never shows open ones.
    public var isFinished: Bool { self == .done || self == .cancelled }

    /// Whether it spans every folder, so its rows say which each is in.
    public var spansFolders: Bool { !(folderID != nil || self == .inbox) }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let id = try? container.decode(Int.self) {
            self = .folder(id)
            return
        }
        switch try container.decode(String.self) {
        case "inbox": self = .inbox
        case "done": self = .done
        case "cancelled": self = .cancelled
        default: self = .all
        }
    }

    /// As a saved view's `scope` takes it.
    public var wireValue: Any {
        switch self {
        case .inbox: "inbox"
        case .folder(let id): id
        case .all: "all"
        case .done: "done"
        case .cancelled: "cancelled"
        }
    }
}

/// Which tags a listed task must carry, and which it must not; empty lists
/// filter nothing.
public struct TagFilter: Decodable, Hashable {
    public var with: Set<Int> = []
    public var without: Set<Int> = []

    public init(with: Set<Int> = [], without: Set<Int> = []) {
        self.with = with
        self.without = without
    }

    public var isEmpty: Bool { with.isEmpty && without.isEmpty }

    /// As `listTasks` and the saved views take it.
    public var wireValue: [String: [Int]] {
        ["with": with.sorted(), "without": without.sorted()]
    }
}

/// What a task list shows past its scope's statuses: the tags,
/// priorities and sizes that narrow it, and its order. A saved view keeps
/// one with its scope.
public struct TaskQuery: Hashable {
    public var scope: TaskScope
    public var tags = TagFilter()
    /// Every priority when empty.
    public var priorities: Set<TaskPriority> = []
    /// Every task, sized or not, when empty; an unsized task matches no
    /// other.
    public var sizes: Set<TaskSize> = []
    public var sort = TaskSort.created
    public var descending = false

    public init(
        scope: TaskScope,
        tags: TagFilter = TagFilter(),
        priorities: Set<TaskPriority> = [],
        sizes: Set<TaskSize> = [],
        sort: TaskSort = TaskSort.created,
        descending: Bool = false
    ) {
        self.scope = scope
        self.tags = tags
        self.priorities = priorities
        self.sizes = sizes
        self.sort = sort
        self.descending = descending
    }

    /// Whether it narrows the list at all.
    public var isFiltered: Bool { !tags.isEmpty || !priorities.isEmpty || !sizes.isEmpty }

    /// Lists every task its scope holds again.
    public mutating func clearFilters() {
        tags = TagFilter()
        priorities = []
        sizes = []
    }

    /// As `createSavedTaskView` and `updateSavedTaskView` take it.
    public var arguments: [String: Any?] {
        [
            "scope": scope.wireValue,
            "tags": tags.wireValue,
            "priorities": priorities.map(\.rawValue),
            "sizes": sizes.map(\.rawValue).sorted(),
            "sort": sort.rawValue,
            "descending": descending,
        ]
    }
}

/// A way of looking at a workspace's tasks kept under a name: which tasks
/// it lists, the tags, priorities and sizes that narrow them, and their
/// order.
public struct SavedTaskView: Decodable, Identifiable, Hashable {
    public let id: Int
    public let workspaceID: Int
    public let name: String
    public let scope: TaskScope
    public let tags: TagFilter
    /// Every priority when empty.
    public let priorities: Set<TaskPriority>
    /// Every task, sized or not, when empty.
    public let sizes: Set<TaskSize>
    public let sort: TaskSort
    public let descending: Bool

    /// What it lists, and in what order.
    public var query: TaskQuery {
        TaskQuery(
            scope: scope,
            tags: tags,
            priorities: priorities,
            sizes: sizes,
            sort: sort,
            descending: descending
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, name, scope, tags, priorities, sizes, sort, descending
        case workspaceID = "workspace_id"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        workspaceID = try container.decode(Int.self, forKey: .workspaceID)
        name = try container.decode(String.self, forKey: .name)
        scope = try container.decode(TaskScope.self, forKey: .scope)
        tags = try container.decode(TagFilter.self, forKey: .tags)
        priorities = try container.decode(Set<TaskPriority>.self, forKey: .priorities)
        // A cohesiond older than sizes leaves them out.
        sizes = try container.decodeIfPresent(Set<TaskSize>.self, forKey: .sizes) ?? []
        sort = try container.decode(TaskSort.self, forKey: .sort)
        descending = try container.decode(Bool.self, forKey: .descending)
    }
}

/// A named group of tasks in a workspace.
public struct TaskFolder: Decodable, Identifiable, Hashable {
    public let id: Int
    public let title: String

    public init(id: Int, title: String) {
        self.id = id
        self.title = title
    }
}

/// A name a workspace puts on its tasks to group them across folders.
public struct Tag: Decodable, Identifiable, Hashable {
    public let id: Int
    public let workspaceID: Int
    public let name: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case workspaceID = "workspace_id"
    }
}

/// The task a tag was put on or taken off, as `setTagged` replies with it.
public struct TaggedTask: Decodable {
    public let task: TaskItem
}

/// One page of a task listing, as `listTasks` replies with it.
public struct TaskPage: Decodable {
    public let tasks: [TaskItem]
    /// How many tasks the whole listing has, on any page.
    public let total: Int
}

public enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case incomplete, completed, cancelled

    public var id: Self { self }
}

/// The key a task list is ordered by, as `listTasks` takes it.
public enum TaskSort: String, Decodable, CaseIterable, Identifiable {
    case created, title, priority, size, startDate, dueDate

    public var id: Self { self }
}

public enum TaskPriority: String, Codable, Hashable {
    case none, low, medium, high, urgent
}

/// How much time or effort a task takes, from 1 (the least) to 5 (the
/// most); a bare number on the wire. Only the vocabulary names one.
public struct TaskSize: RawRepresentable, Codable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

// MARK: - Agents

/// A persistent assistant the user chats with.
public struct Agent: Decodable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let color: AgentColor
    public let emoji: String?
    public let personality: AgentPersonality
    public let verbosity: AgentVerbosity
    /// What the user wants from the agent; empty when unset.
    public let role: String
    /// What the agent is doing while it works; `nil` when it isn't working.
    public let activity: String?
    /// When its conversation's running turn started, which the user can
    /// stop; `nil` when none is running. Jobs don't count.
    public let foregroundStarted: Date?
    public let isUnread: Bool
    /// Whether the agent is pinned, ahead of the others.
    public let isPinned: Bool
    /// The team it's on; `nil` when it's on none, or the daemon has no
    /// teams. Pinning is apart from teams: a pinned agent stays on its team.
    public let teamID: Int?
    /// How many tokens its conversation's live thread held at its latest
    /// request; `nil` with no thread, or before a new one's first request
    /// is answered.
    public let contextTokens: Int?
    /// When its conversation last had a message; `nil` before the first.
    public let lastMessageAt: Date?

    public var isWorking: Bool { activity != nil }

    /// The agent's status line: what it is doing while it works, else its role.
    public var status: String {
        activity ?? role
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name = "agent_name"
        case color = "agent_color"
        case emoji = "agent_emoji"
        case personality = "agent_personality"
        case verbosity = "agent_verbosity"
        case role = "agent_role"
        case activity
        case foregroundStarted = "foreground_started"
        case isUnread = "agent_unread"
        case isPinned = "pinned"
        case teamID = "team_id"
        case contextTokens = "context_tokens"
        case lastMessageAt = "last_message_at"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        color = try container.decode(AgentColor.self, forKey: .color)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji)
        personality = try container.decode(AgentPersonality.self, forKey: .personality)
        verbosity = try container.decode(AgentVerbosity.self, forKey: .verbosity)
        role = try container.decode(String.self, forKey: .role)
        activity = try container.decodeIfPresent(String.self, forKey: .activity)
        foregroundStarted = try container.decodeIfPresent(Double.self, forKey: .foregroundStarted)
            .map(Date.init(timeIntervalSince1970:))
        isUnread = try container.decode(Bool.self, forKey: .isUnread)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        teamID = try container.decodeIfPresent(Int.self, forKey: .teamID)
        contextTokens = try container.decodeIfPresent(Int.self, forKey: .contextTokens)
        lastMessageAt = try container.decodeIfPresent(Double.self, forKey: .lastMessageAt)
            .map(Date.init(timeIntervalSince1970:))
    }
}

/// A team of agents: a named group whose members see each other in their
/// prompts and share the team's memories.
public struct AgentTeam: Decodable, Identifiable, Hashable {
    public let id: Int
    /// Unique among teams, ignoring case.
    public let title: String
}

/// The manner an agent speaks in.
public enum AgentPersonality: String, Decodable {
    case balanced, friendly, professional, candid, playful
}

/// How much an agent says, from least to most.
public enum AgentVerbosity: String, Decodable {
    case terse, brief, detailed, thorough
}

/// A hook, as cohesiond names it (`task:create`): what an agent's cue waits
/// on, or an extension runs on.
public struct HookKind: Decodable, Hashable {
    public let rawValue: String

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }
}

/// What an agent set to wake itself: when `hook` fires and `script`
/// returns something, a job starts with `instructions`, or, for
/// a `foreground` cue, its conversation takes a turn on them once.
public struct AgentCue: Decodable, Identifiable {
    public let id: Int
    public let name: String
    public let hook: HookKind
    public let script: String
    public let instructions: String
    public let effort: AgentCueEffort

    /// Cues migrated from an agent's single trigger are named after their
    /// hook, so those read as the hook's clause instead.
    public func title(in vocabulary: Vocabulary) -> String {
        name == hook.rawValue ? "When \(vocabulary.clause(of: hook))" : name
    }
}

/// Where a cue wakes its agent, and on what model.
public enum AgentCueEffort: Decodable, Hashable {
    /// A job each time it fires, on that tier's default model.
    case background(IntelligenceTier)
    /// A turn of the agent's conversation, once; the cue goes as it fires.
    case foreground

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = raw == "foreground" ? .foreground : .background(IntelligenceTier(rawValue: raw) ?? .medium)
    }
}

/// One time a cue woke an agent: how it went and what it cost.
public struct AgentRun: Decodable, Identifiable {
    public let id: Int
    public let hook: HookKind
    /// `nil` for runs from before agents had several cues.
    public let cueName: String?
    public let startedAt: Date
    public let state: State
    /// Prompt tokens across the run that weren't read from the cache: its
    /// input and cache writes, as the web app counts them.
    public let inputTokens: Int
    public let outputTokens: Int
    /// In dollars; `nil` when nothing was priced.
    public let cost: Double?

    /// Where a run stands, tagged by `status` on the wire.
    public enum State: Decodable {
        case running
        case completed(endedAt: Date)
        case failed(endedAt: Date, error: String)

        enum CodingKeys: String, CodingKey {
            case status, outcome, error
            case endedAt = "ended_at"
        }

        /// A run as an older cohesiond sends it, with `outcome`, `ended_at`
        /// and `error` beside its other fields. Reads them as cohesiond's
        /// migration to `state` does, so a run says the same either way: one
        /// that ended with no time ended at `startedAt`, one that failed with
        /// no error has an empty one, and what its outcome rules out is
        /// dropped.
        init(olderRunFrom decoder: any Decoder, startedAt: Date) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let endedAt = try container.decodeIfPresent(Double.self, forKey: .endedAt)
                .map(Date.init(timeIntervalSince1970:)) ?? startedAt
            switch try container.decode(String.self, forKey: .outcome) {
            case "running": self = .running
            case "completed": self = .completed(endedAt: endedAt)
            case "failed":
                self = .failed(
                    endedAt: endedAt, error: try container.decodeIfPresent(String.self, forKey: .error) ?? "")
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .outcome, in: container, debugDescription: "Unknown run outcome")
            }
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let status = try container.decode(String.self, forKey: .status)
            if status == "running" {
                self = .running
                return
            }
            let endedAt = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .endedAt))
            switch status {
            case "completed": self = .completed(endedAt: endedAt)
            case "failed": self = .failed(endedAt: endedAt, error: try container.decode(String.self, forKey: .error))
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .status, in: container, debugDescription: "Unknown run status")
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, hook, state, cost
        case cueName = "cue_name"
        case startedAt = "started_at"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheWriteTokens = "cache_write_tokens"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        hook = try container.decode(HookKind.self, forKey: .hook)
        cueName = try container.decodeIfPresent(String.self, forKey: .cueName)
        startedAt = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .startedAt))
        state = try container.decodeIfPresent(State.self, forKey: .state)
            ?? State(olderRunFrom: decoder, startedAt: startedAt)
        inputTokens = try container.decode(Int.self, forKey: .inputTokens)
            + container.decode(Int.self, forKey: .cacheWriteTokens)
        outputTokens = try container.decode(Int.self, forKey: .outputTokens)
        cost = try container.decodeIfPresent(Double.self, forKey: .cost)
    }
}

/// A fact an agent keeps across conversations, in its own words.
public struct Memory: Decodable, Identifiable {
    public let id: Int
    /// Who sees it.
    public let scope: Scope
    public let createdAt: Date
    public let memory: String

    /// Who sees a memory: one agent, one team's agents, or every agent.
    public enum Scope: Decodable, Hashable {
        case agent(Int)
        case team(Int)
        case global

        enum CodingKeys: String, CodingKey {
            case kind
            case agentID = "agent_id"
            case teamID = "team_id"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(String.self, forKey: .kind) {
            case "agent": self = .agent(try container.decode(Int.self, forKey: .agentID))
            case "team": self = .team(try container.decode(Int.self, forKey: .teamID))
            case "global": self = .global
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .kind, in: container, debugDescription: "Unknown memory scope")
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, memory, scope
        case agentID = "agent_id"
        case createdAt = "created_at"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        if container.contains(.scope) {
            scope = try container.decode(Scope.self, forKey: .scope)
        } else {
            // A daemon from before teams names the agent, or none for a global one.
            scope = try container.decodeIfPresent(Int.self, forKey: .agentID).map(Scope.agent) ?? .global
        }
        createdAt = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .createdAt))
        memory = try container.decode(String.self, forKey: .memory)
    }
}

/// One entry in an agent's conversation.
public struct AgentMessage: Decodable, Identifiable, Equatable {
    public let id: Int
    /// The job or fork that sent it; `nil` in the conversation.
    public let runID: Int?
    /// What woke the job or fork that sent it; `nil` in the conversation.
    public let runDescription: String?
    /// What it is to the fork `runID` names, as cohesiond sorts it; `nil` in
    /// the conversation, and from an older cohesiond.
    public let runPart: RunPart?
    public let sentAt: Date
    public let sender: Sender
    /// What it says, tagged by `kind` on the wire.
    public let content: Content
    /// One of the vocabulary's `agentReactions`, from the side that didn't send the message: the
    /// user on the agent's messages, the agent on the user's.
    public let reaction: String?
    /// When `reaction` was last set or cleared.
    public let reactedAt: Date?
    /// The message of the same conversation this one replies to, quoted
    /// above it.
    public let replyTo: Int?
    /// The message in one line, as cohesiond words it: what a reply quoting
    /// it or a line about a reaction to it shows, and how a kind this build
    /// has no view for shows. An older cohesiond sends none, and a text
    /// message's text stands in. For the agent's bookkeeping, what follows
    /// `excerptVerb`.
    public let excerpt: String?
    /// What the agent did, for a line of its bookkeeping (`Remembered`,
    /// `Forgot`, `Noted`, `Woke`): the heading of a run of such lines, and
    /// the start of `line`. `nil` for other kinds, and from an older
    /// cohesiond, whose `excerpt` already starts with it.
    public let excerptVerb: String?
    /// What follows `reactionExcerptVerb` in the line about `reaction`: the
    /// emoji and the message it reacts to, quoted (`👍 to “Done.”`). `nil`
    /// with no reaction, and from an older cohesiond.
    public let reactionExcerpt: String?
    /// `Reacted` when there's a `reaction`: the heading of a run of lines
    /// about reactions, and the start of `reactionLine`.
    public let reactionExcerptVerb: String?
    /// How many images came with it, the user's or the agent's;
    /// `attachments(of:)` fetches them.
    public let attachmentCount: Int

    public enum Sender: String, Decodable {
        case user, agent, backgroundAgent
    }

    /// Where a fork's message goes.
    public enum RunPart: String, Decodable {
        /// What woke the fork: its `woke` line, or another agent's question.
        case trigger
        /// Work it did on the way, which goes under the trigger.
        case step
        /// What it has to show the user, which stays in the transcript.
        case surfaced
    }

    public enum Content: Decodable, Equatable {
        case text(String)
        case error(String)
        /// The script API module the sender loaded.
        case documentation(String)
        case codeExecution(AgentCodeExecution)
        case proposal(AgentProposal)
        case choice(AgentChoice)
        /// A memory the agent remembered or forgot.
        case memory(String, MemoryChange)
        /// The user forwarding an item, with what they wrote with it, or
        /// an empty note.
        case forward(note: String, item: AgentForwardedItem)
        /// The agent's question to another agent, and its answer.
        case askedAgent(AgentAsk)
        /// Another agent's question to the agent, and the answer it gave.
        case askedByAgent(AgentAsk)
        /// The agent's context was built again, shown as the message's
        /// excerpt. It carries no run, even in the middle of one.
        case rebuiltContext
        /// A kind from a newer cohesiond than this build knows, shown as
        /// the message's excerpt.
        case unknown

        public enum Keys: String, CodingKey {
            case kind, text, error, module, memory, change, note, item
        }

        public enum MemoryChange: String, Decodable {
            case remembered, forgotten
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            switch try container.decode(String.self, forKey: .kind) {
            case "text": self = .text(try container.decode(String.self, forKey: .text))
            case "error": self = .error(try container.decode(String.self, forKey: .error))
            case "documentation": self = .documentation(try container.decode(String.self, forKey: .module))
            case "codeExecution": self = .codeExecution(try AgentCodeExecution(from: decoder))
            case "proposal": self = .proposal(try AgentProposal(from: decoder))
            case "choice": self = .choice(try AgentChoice(from: decoder))
            case "memory":
                self = .memory(
                    try container.decode(String.self, forKey: .memory),
                    try container.decode(MemoryChange.self, forKey: .change)
                )
            case "forward":
                self = .forward(
                    note: try container.decode(String.self, forKey: .note),
                    item: try container.decode(AgentForwardedItem.self, forKey: .item)
                )
            case "askedAgent": self = .askedAgent(try AgentAsk(from: decoder))
            case "askedByAgent": self = .askedByAgent(try AgentAsk(from: decoder))
            case "rebuiltContext": self = .rebuiltContext
            default: self = .unknown
            }
        }
    }

    /// The message's text, when it is a text message.
    public var text: String? {
        if case .text(let text) = content { return text }
        return nil
    }

    /// The question between agents it holds, when it holds one.
    public var ask: AgentAsk? {
        switch content {
        case .askedAgent(let ask), .askedByAgent(let ask): ask
        default: nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, sender
        case runID = "run_id"
        case runDescription = "run_description"
        case runPart = "run_part"
        case sentAt = "sent_at"
        case content = "message_content"
        case reaction, excerpt
        case excerptVerb = "excerpt_verb"
        case reactionExcerpt = "reaction_excerpt"
        case reactionExcerptVerb = "reaction_excerpt_verb"
        case reactedAt = "reacted_at"
        case replyTo = "reply_to"
        case attachmentCount = "attachment_count"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        runID = try container.decodeIfPresent(Int.self, forKey: .runID)
        runDescription = try container.decodeIfPresent(String.self, forKey: .runDescription)
        // A part from a newer cohesiond stays in the transcript, as today's do by default.
        runPart = try container.decodeIfPresent(String.self, forKey: .runPart).flatMap(RunPart.init)
        sentAt = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .sentAt))
        sender = try container.decode(Sender.self, forKey: .sender)
        content = try container.decode(Content.self, forKey: .content)
        // Older daemons send neither.
        reaction = try container.decodeIfPresent(String.self, forKey: .reaction)
        reactedAt = try container.decodeIfPresent(Double.self, forKey: .reactedAt).map(Date.init(timeIntervalSince1970:))
        attachmentCount = try container.decodeIfPresent(Int.self, forKey: .attachmentCount) ?? 0
        replyTo = try container.decodeIfPresent(Int.self, forKey: .replyTo)
        if let excerpt = try container.decodeIfPresent(String.self, forKey: .excerpt) {
            self.excerpt = excerpt
        } else if case .text(let text) = content, !text.isEmpty {
            self.excerpt = text
        } else {
            self.excerpt = nil
        }
        excerptVerb = try container.decodeIfPresent(String.self, forKey: .excerptVerb)
        reactionExcerpt = try container.decodeIfPresent(String.self, forKey: .reactionExcerpt)
        reactionExcerptVerb = try container.decodeIfPresent(String.self, forKey: .reactionExcerptVerb)
    }

    /// The message in one line: its excerpt, after its verb when it has one
    /// (`Noted: …`).
    public var line: String? {
        guard let excerpt else { return nil }
        return excerptVerb.map { "\($0): \(excerpt)" } ?? excerpt
    }

    /// The line about its reaction (`Reacted: 👍 to “Done.”`), worded here
    /// only for an older cohesiond, which sends none.
    public var reactionLine: String {
        if let reactionExcerptVerb, let reactionExcerpt {
            return "\(reactionExcerptVerb): \(reactionExcerpt)"
        }
        return "Reacted \(reaction ?? "") to “\(line ?? "")”"
    }
}

/// One agent's question to another, in the conversations of both: the
/// asker's as `askedAgent`, the answerer's as `askedByAgent`.
public struct AgentAsk: Decodable, Equatable {
    /// The other agent, as it was named when asked: the one asked in
    /// `askedAgent`, the one asking in `askedByAgent`.
    public let agent: Peer
    public let question: String
    public let reply: Reply

    public struct Peer: Decodable, Equatable {
        public let id: Int
        public let name: String
    }

    /// Where the question stands, tagged by `status` on the wire.
    public enum Reply: Decodable, Equatable {
        /// The agent asked is still answering.
        case waiting
        case answered(String)
        /// No answer came, for the reason given, such as the wait timing out.
        case unanswered(reason: String)

        enum CodingKeys: String, CodingKey {
            case status, text, reason
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(String.self, forKey: .status) {
            case "answered": self = .answered(try container.decode(String.self, forKey: .text))
            case "unanswered": self = .unanswered(reason: try container.decode(String.self, forKey: .reason))
            default: self = .waiting
            }
        }
    }
}

/// An item the user forwarded to an agent, which reads it from its
/// `cohesion://` link.
public struct AgentForwardedItem: Decodable, Hashable {
    public let kind: Kind
    public let workspaceID: Int
    public let id: Int
    /// The title when it was forwarded; a journal entry's is its day,
    /// `"YYYY-MM-DD"`.
    public let title: String

    public init(kind: Kind, workspaceID: Int, id: Int, title: String) {
        self.kind = kind
        self.workspaceID = workspaceID
        self.id = id
        self.title = title
    }

    public enum Kind: String, Decodable {
        case task, document
        /// A journal entry, a document too: its link and the forward that
        /// sends it name it as one.
        case journal
    }

    enum CodingKeys: String, CodingKey {
        case kind, id, title
        case workspaceID = "workspace_id"
    }

    /// The item as a message forwarding it names it; cohesiond fills in the
    /// title and tells a journal entry apart.
    public var wireValue: [String: Any] {
        ["kind": kind == .task ? "task" : "document", "workspace_id": workspaceID, "id": id]
    }
}

/// An image attached to an agent message, by the user or the agent.
public struct AgentAttachment: Decodable, Identifiable {
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

/// A script the agent ran from its chat.
public struct AgentCodeExecution: Decodable, Equatable {
    public let title: String
    public let code: String
    public let outcome: Outcome

    /// How the script ended, tagged by `status` on the wire.
    public enum Outcome: Decodable, Equatable {
        case succeeded(result: String)
        case failed(error: String)
        /// The user stopped the agent's turn while it ran.
        case cancelled

        enum CodingKeys: String, CodingKey {
            case status, result, error
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(String.self, forKey: .status) {
            case "succeeded": self = .succeeded(result: try container.decode(String.self, forKey: .result))
            case "failed": self = .failed(error: try container.decode(String.self, forKey: .error))
            default: self = .cancelled
            }
        }
    }
}

/// A question the agent asks with answers to pick from, lettered A, B, C…
public struct AgentChoice: Decodable, Equatable {
    public let question: String
    public let options: [String]
    /// The index in `options` of the user's pick; `nil` until they pick.
    public let selected: Int?
}

/// A change the agent or one of its jobs asks the user to approve.
public struct AgentProposal: Decodable, Equatable {
    public let action: String
    public let justification: String
    public let status: Status

    public enum Status: String, Decodable {
        case pending, approved, denied
        /// A later run of the same cue replaced it before the user answered.
        case withdrawn
    }
}

/// A day's journal entry: the workspace document cohesiond keeps for that
/// day, written as Markdown.
public struct JournalEntry: Decodable {
    /// The document's id, which a link or a forward names it by.
    public let id: Int
    public let contents: String
}

// MARK: - Documents

/// A Markdown document in a workspace; journal entries are documents too.
public struct Document: Decodable, Identifiable, Hashable {
    public let id: Int
    public let workspaceID: Int
    public let type: DocumentType
    public let title: String
    public let contents: String
    /// When the contents last changed.
    public let modified: Date
    /// For a journal entry, its day as `"YYYY-MM-DD"`.
    public let journalDate: String?
    /// The folder it's filed in, or `nil` in the Inbox; in a table's, it's
    /// a row. Absent from a daemon from before folders.
    public let folderID: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, contents, modified
        case workspaceID = "workspace_id"
        case type = "document_type"
        case journalDate = "journal_date"
        case folderID = "folder_id"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        workspaceID = try container.decode(Int.self, forKey: .workspaceID)
        type = try container.decode(DocumentType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        contents = try container.decode(String.self, forKey: .contents)
        modified = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .modified))
        journalDate = try container.decodeIfPresent(String.self, forKey: .journalDate)
        folderID = try container.decodeIfPresent(Int.self, forKey: .folderID)
    }
}

public enum DocumentType: String, Decodable {
    case normal
    /// A day's journal entry, which the journal shows.
    case journal
}

// MARK: - Document folders and tables

/// A folder documents are filed in. One with properties is a table, each of
/// its documents a row.
public struct DocumentFolder: Decodable, Identifiable, Hashable {
    public let id: Int
    public let workspaceID: Int
    /// The folder it sits in, or `nil` at the top level.
    public let parentID: Int?
    public let title: String
    /// Whether it has properties, so shows as a table.
    public let isTable: Bool

    public init(id: Int, workspaceID: Int, parentID: Int? = nil, title: String, isTable: Bool) {
        self.id = id
        self.workspaceID = workspaceID
        self.parentID = parentID
        self.title = title
        self.isTable = isTable
    }

    enum CodingKeys: String, CodingKey {
        case id, title
        case workspaceID = "workspace_id"
        case parentID = "parent_id"
        case isTable = "is_table"
    }
}

/// A table's column: a value each row may hold, of one type.
public struct DocumentFolderProperty: Decodable, Identifiable, Hashable {
    public let id: Int
    public let folderID: Int
    public let name: String
    public let type: PropertyType
    /// Whether a formula computes its values, so none is set by hand.
    public let isFormula: Bool

    /// What a property's values are, and a choice's options.
    public enum PropertyType: Hashable {
        case text, integer, decimal, currency, checkbox, date
        /// One of `options`, in their order.
        case choice([PropertyOption])
        /// A type this build doesn't know; its values show as empty.
        case other
    }

    enum CodingKeys: String, CodingKey {
        case id, name, options, formula
        case folderID = "folder_id"
        case dataType = "data_type"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        folderID = try container.decode(Int.self, forKey: .folderID)
        name = try container.decode(String.self, forKey: .name)
        isFormula = try container.contains(.formula) && !container.decodeNil(forKey: .formula)
        type = switch try container.decode(String.self, forKey: .dataType) {
        case "text": .text
        case "integer": .integer
        case "decimal": .decimal
        case "currency": .currency
        case "checkbox": .checkbox
        case "date": .date
        case "choice": .choice(try container.decode([PropertyOption].self, forKey: .options))
        default: .other
        }
    }

    /// Whether its values are numbers, which line up on the trailing edge.
    public var isNumeric: Bool {
        switch type {
        case .integer, .decimal, .currency: true
        default: false
        }
    }
}

/// One of a choice property's options.
public struct PropertyOption: Decodable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    /// The color it's drawn in, from the agents' palette, or `nil` for none.
    public let color: AgentColor?
}

/// A document in a table, with its values.
public struct DocumentTableRow: Decodable, Identifiable, Hashable {
    /// The document's id.
    public let id: Int
    public let title: String
    /// Its values by property id; a property it holds none in is absent.
    public var values: [Int: PropertyValue]

    private struct Cell: Decodable {
        let propertyID: Int
        let value: PropertyValue

        enum CodingKeys: String, CodingKey {
            case value
            case propertyID = "property_id"
        }
    }

    enum CodingKeys: String, CodingKey {
        case title, cells
        case id = "document_id"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        let cells = try container.decode([Cell].self, forKey: .cells)
        values = Dictionary(cells.map { ($0.propertyID, $0.value) }, uniquingKeysWith: { first, _ in first })
    }
}

/// A row's value for a property, of the property's type.
public enum PropertyValue: Decodable, Hashable {
    case text(String)
    case integer(Int)
    case decimal(Double)
    /// An amount; a table names no currency.
    case currency(Double)
    case checkbox(Bool)
    /// A day, as `"YYYY-MM-DD"`.
    case date(String)
    /// The id of one of its property's options.
    case choice(Int)
    /// A type this build doesn't know.
    case other

    enum CodingKeys: String, CodingKey {
        case type, value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self = switch try container.decode(String.self, forKey: .type) {
        case "text": .text(try container.decode(String.self, forKey: .value))
        case "integer": .integer(try container.decode(Int.self, forKey: .value))
        case "decimal": .decimal(try container.decode(Double.self, forKey: .value))
        case "currency": .currency(try container.decode(Double.self, forKey: .value))
        case "checkbox": .checkbox(try container.decode(Bool.self, forKey: .value))
        case "date": .date(try container.decode(String.self, forKey: .value))
        case "choice": .choice(try container.decode(Int.self, forKey: .value))
        default: .other
        }
    }

    /// The value as a command sends it, or `nil` for a type this build
    /// doesn't know.
    var wire: [String: Any]? {
        switch self {
        case .text(let text): ["type": "text", "value": text]
        case .integer(let number): ["type": "integer", "value": number]
        case .decimal(let number): ["type": "decimal", "value": number]
        case .currency(let amount): ["type": "currency", "value": amount]
        case .checkbox(let checked): ["type": "checkbox", "value": checked]
        case .date(let day): ["type": "date", "value": day]
        case .choice(let id): ["type": "choice", "value": id]
        case .other: nil
        }
    }
}
