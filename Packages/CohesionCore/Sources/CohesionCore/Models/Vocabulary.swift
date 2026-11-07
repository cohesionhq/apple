import Foundation

/// What cohesiond calls its kinds, each list in the order to show it, as its
/// `hello` sends them. The app words none of these itself; until a hello
/// arrives every list is empty and a kind reads as its wire name.
public struct Vocabulary: Decodable {
    public var permissions: [Described<ExtensionPermissionKind>] = []
    public var hooks: [HookWording] = []
    /// Most to least pressing.
    public var taskPriorities: [Labeled<TaskPriority>] = []
    /// Smallest to largest; empty from a cohesiond older than sizes.
    public var taskSizes: [SizeWording] = []
    public var agentColors: [Labeled<AgentColor>] = []
    public var agentPersonalities: [Labeled<AgentPersonality>] = []
    public var agentVerbosities: [Labeled<AgentVerbosity>] = []
    public var tiers: [Described<IntelligenceTier>] = []
    /// Shortest first; empty from a cohesiond older than spend limits.
    public var spendPeriods: [Described<SpendPeriod>] = []
    /// Providers with a built-in endpoint preset.
    public var providers: [ProviderWording] = []
    public var dialects: [Labeled<EndpointDialect>] = []
    /// The emoji an agent message can be reacted with.
    public var agentReactions: [String] = []
    public var actorSessionStatuses: [Labeled<ActorSessionStatus>] = []

    enum CodingKeys: String, CodingKey {
        case permissions, hooks, tiers, providers, dialects
        case taskPriorities = "task_priorities"
        case taskSizes = "task_sizes"
        case agentColors = "agent_colors"
        case agentPersonalities = "agent_personalities"
        case agentVerbosities = "agent_verbosities"
        case agentReactions = "agent_reactions"
        case actorSessionStatuses = "actor_session_statuses"
        case spendPeriods = "spend_periods"
    }

    public init() {}

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        permissions = try container.decode([Described<ExtensionPermissionKind>].self, forKey: .permissions)
        hooks = try container.decode([HookWording].self, forKey: .hooks)
        taskPriorities = try container.decode([Labeled<TaskPriority>].self, forKey: .taskPriorities)
        // A cohesiond older than sizes leaves them out.
        taskSizes = try container.decodeIfPresent([SizeWording].self, forKey: .taskSizes) ?? []
        agentColors = try container.decode([Labeled<AgentColor>].self, forKey: .agentColors)
        agentPersonalities = try container.decode([Labeled<AgentPersonality>].self, forKey: .agentPersonalities)
        agentVerbosities = try container.decode([Labeled<AgentVerbosity>].self, forKey: .agentVerbosities)
        tiers = try container.decode([Described<IntelligenceTier>].self, forKey: .tiers)
        // A cohesiond older than spend limits leaves them out.
        spendPeriods = try container.decodeIfPresent([Described<SpendPeriod>].self, forKey: .spendPeriods) ?? []
        providers = try container.decode([ProviderWording].self, forKey: .providers)
        dialects = try container.decode([Labeled<EndpointDialect>].self, forKey: .dialects)
        agentReactions = try container.decode([String].self, forKey: .agentReactions)
        actorSessionStatuses = try container.decode([Labeled<ActorSessionStatus>].self, forKey: .actorSessionStatuses)
    }

    /// A kind with the name a person knows it by.
    public struct Labeled<Kind: Decodable & Equatable>: Decodable {
        public let kind: Kind
        public let label: String
    }

    /// A task size's name, and the color its chip is tinted.
    public struct SizeWording: Decodable {
        public let kind: TaskSize
        public let label: String
        /// `nil` from a cohesiond older than sizes' colors.
        public let color: AgentColor?
    }

    /// A kind with a short title and a one-line description under it.
    public struct Described<Kind: Decodable & Equatable>: Decodable {
        public let kind: Kind
        public let title: String
        public let description: String
    }

    /// When a hook fires, as clauses that finish "When …".
    public struct HookWording: Decodable {
        public let kind: HookKind
        /// As an extension's hook.
        public let extensionClause: String
        /// As an agent's cue or run.
        public let cueClause: String

        enum CodingKeys: String, CodingKey {
            case kind
            case extensionClause = "extension_clause"
            case cueClause = "cue_clause"
        }
    }

    public func label(of priority: TaskPriority) -> String {
        taskPriorities.first { $0.kind == priority }?.label ?? priority.rawValue
    }

    public func label(of size: TaskSize) -> String {
        taskSizes.first { $0.kind == size }?.label ?? String(size.rawValue)
    }

    public func color(of size: TaskSize) -> AgentColor? {
        taskSizes.first { $0.kind == size }?.color
    }

    public func label(of color: AgentColor) -> String {
        agentColors.first { $0.kind == color }?.label ?? color.rawValue
    }

    public func label(of personality: AgentPersonality) -> String {
        agentPersonalities.first { $0.kind == personality }?.label ?? personality.rawValue
    }

    public func label(of verbosity: AgentVerbosity) -> String {
        agentVerbosities.first { $0.kind == verbosity }?.label ?? verbosity.rawValue
    }

    public func title(of tier: IntelligenceTier) -> String {
        tiers.first { $0.kind == tier }?.title ?? tier.rawValue
    }

    public func title(of period: SpendPeriod) -> String {
        spendPeriods.first { $0.kind == period }?.title ?? period.rawValue
    }

    public func description(of period: SpendPeriod) -> String? {
        spendPeriods.first { $0.kind == period }?.description
    }

    public func label(of dialect: EndpointDialect) -> String {
        dialects.first { $0.kind == dialect }?.label ?? dialect.rawValue
    }

    public func label(of status: ActorSessionStatus) -> String {
        actorSessionStatuses.first { $0.kind == status }?.label ?? status.rawValue
    }

    /// When `hook` fires as an agent's cue, as the end of "When …".
    public func clause(of hook: HookKind) -> String {
        hooks.first { $0.kind == hook }?.cueClause ?? hook.rawValue
    }

    /// When `hook` fires as an extension's, as the end of "When …".
    public func extensionClause(of hook: HookKind) -> String {
        hooks.first { $0.kind == hook }?.extensionClause ?? hook.rawValue
    }

    /// What `permission` allows, with a line saying more; a permission
    /// newer than the hello reads as its wire name.
    public func wording(of permission: ExtensionPermissionKind) -> (title: String, description: String?) {
        guard let wording = permissions.first(where: { $0.kind == permission }) else {
            return (permission.rawValue, nil)
        }
        return (wording.title, wording.description)
    }

    /// The vocabulary's place for `permission`, for sorting; one it doesn't
    /// list goes last.
    public func rank(of permission: ExtensionPermissionKind) -> Int {
        permissions.firstIndex { $0.kind == permission } ?? permissions.count
    }

    /// The vocabulary's place for `hook`, for sorting; one it doesn't list
    /// goes last.
    public func rank(of hook: HookKind) -> Int {
        hooks.firstIndex { $0.kind == hook } ?? hooks.count
    }

    /// What to call an endpoint's provider: its preset's name, or a custom endpoint's identifier.
    public func label(ofProvider providerIdentifier: String) -> String {
        providers.first { $0.providerIdentifier == providerIdentifier }?.label ?? providerIdentifier
    }
}

/// A provider preset, and the catalog provider it reads models from. Its
/// `kind` stays a string so a preset newer than this build still shows.
public struct ProviderWording: Decodable, Hashable {
    public let kind: String
    public let label: String
    public let providerIdentifier: String

    enum CodingKeys: String, CodingKey {
        case kind, label
        case providerIdentifier = "provider_identifier"
    }
}
