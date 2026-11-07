import Foundation

/// A provider connection models are reached through, under a unique name. Its key never leaves cohesiond.
public struct IntelligenceEndpoint: Decodable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    /// What serves the endpoint.
    public let backend: Backend

    /// What serves an endpoint, as the reply tags it with `kind`.
    public enum Backend: Decodable, Hashable {
        /// Cohesion's built-in backends: a provider's API, or a server described by hand.
        case integrated(providerIdentifier: String, usageURL: URL?)
        /// A built-in backend signed in with an extension's account, such as a ChatGPT sign-in. Removing the
        /// account removes the endpoint.
        case account(providerIdentifier: String, accountID: Int, usageURL: URL?)

        enum CodingKeys: String, CodingKey {
            case kind
            case providerIdentifier = "provider_identifier"
            case accountID = "account_id"
            case usageURL = "usage_url"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(String.self, forKey: .kind) {
            case "integrated":
                self = .integrated(
                    providerIdentifier: try container.decode(String.self, forKey: .providerIdentifier),
                    usageURL: try container.decodeIfPresent(URL.self, forKey: .usageURL))
            case "account":
                self = .account(
                    providerIdentifier: try container.decode(String.self, forKey: .providerIdentifier),
                    accountID: try container.decode(Int.self, forKey: .accountID),
                    usageURL: try container.decodeIfPresent(URL.self, forKey: .usageURL))
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .kind, in: container, debugDescription: "Unknown endpoint backend")
            }
        }
    }

    public var providerIdentifier: String {
        switch backend {
        case .integrated(let providerIdentifier, _), .account(let providerIdentifier, _, _): providerIdentifier
        }
    }

    /// Where a person sees what the endpoint has used.
    public var usageURL: URL? {
        switch backend {
        case .integrated(_, let usageURL), .account(_, _, let usageURL): usageURL
        }
    }

    /// Whether it signs in with an extension's account rather than a key.
    public var isAccountEndpoint: Bool {
        guard case .account = backend else { return false }
        return true
    }
}

/// A model an endpoint offers, imported from the catalog or added by hand. Every model picker lists these.
public struct EndpointModel: Decodable, Identifiable, Hashable {
    public let id: Int
    public let endpointID: Int
    public let modelIdentifier: String
    public let modelName: String

    enum CodingKeys: String, CodingKey {
        case id
        case endpointID = "endpoint_id"
        case modelIdentifier = "model_identifier"
        case modelName = "model_name"
    }
}

/// The endpoint model a tier uses. Only tiers that are set have one.
public struct IntelligenceDefault: Decodable, Identifiable, Hashable {
    public let id: Int
    public let tier: IntelligenceTier
    public let endpointModelID: Int

    enum CodingKeys: String, CodingKey {
        case id, tier
        case endpointModelID = "endpoint_model_id"
    }
}

/// A model the models.dev catalog lists for a provider, priced in dollars per million tokens. Endpoints import
/// models from it; pickers never list it.
public struct CatalogModel: Decodable, Identifiable, Hashable {
    public let id: Int
    public let providerIdentifier: String
    public let providerName: String
    public let modelIdentifier: String
    public let modelName: String
    public let contextSize: Int?
    public let inputTokenCost: Double?
    public let outputTokenCost: Double?
    public let cacheReadTokenCost: Double?
    public let cacheWriteTokenCost: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case providerIdentifier = "provider_identifier"
        case providerName = "provider_name"
        case modelIdentifier = "model_identifier"
        case modelName = "model_name"
        case contextSize = "context_size"
        case inputTokenCost = "input_token_cost"
        case outputTokenCost = "output_token_cost"
        case cacheReadTokenCost = "cache_read_token_cost"
        case cacheWriteTokenCost = "cache_write_token_cost"
    }
}

/// The kinds of work that each have a default model.
public enum IntelligenceTier: String, Codable {
    case agent, low, medium, high
}

/// What every model call cost over one spend period, against its limit.
/// At a limit, jobs and agents' forks make no model calls; the user's own
/// messages still do, and count.
public struct IntelligenceSpend: Decodable, Hashable {
    public let period: SpendPeriod
    /// In US dollars; `nil` when the period has no limit.
    public let limit: Double?
    /// In US dollars.
    public let spent: Double
    public let reached: Bool
}

/// How far back a spend limit counts, rolling: the last 60 minutes, 24
/// hours or 30 days.
public enum SpendPeriod: String, Codable {
    case hour, day, month
}

/// A provider with a built-in endpoint, or `custom` for any other.
public enum EndpointPreset: Hashable {
    case provider(ProviderWording)
    case custom

    /// As `createIntelligenceEndpoint` takes it.
    public var kind: String {
        switch self {
        case .provider(let provider): provider.kind
        case .custom: "custom"
        }
    }

    public var label: String {
        switch self {
        case .provider(let provider): provider.label
        case .custom: "Custom"
        }
    }

    /// Built-in presets need a key; a custom endpoint may run without one.
    public var requiresAPIKey: Bool { self != .custom }
}

/// The API a custom endpoint speaks.
public enum EndpointDialect: String, Decodable {
    case chatCompletions, messages, responses
    /// Responses with nothing stored on the server, as a ChatGPT plan requires.
    case statelessResponses
}
