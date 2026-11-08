import Foundation

/// An installed extension, without its script.
public struct ExtensionSummary: Decodable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let version: Int
    /// The identifier its manifest declares, such as `com.example.done-stamp`.
    public let scriptIdentifier: String
    public let description: String
    public let author: String
    /// A `data:image/…` or `https://` URL.
    public let icon: String?
    /// Hook evaluation order: lower runs first, ties by `id`.
    public let priority: Int

    enum CodingKeys: String, CodingKey {
        case id, name, version, description, author, icon, priority
        case scriptIdentifier = "script_identifier"
    }
}

/// A permission an extension's manifest lists, as cohesiond names it
/// (`cohesion:read`). Kept as its name so one newer than this build still
/// shows.
public struct ExtensionPermissionKind: Decodable, Hashable {
    public let rawValue: String

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }
}

/// One permission an extension asked for, and whether it is granted.
public struct ExtensionPermission: Decodable, Identifiable {
    public let id: Int
    public let permission: ExtensionPermissionKind
    public var enabled: Bool
}

/// One hook an extension runs on, and whether it is on.
public struct ExtensionHook: Decodable, Identifiable {
    public let id: Int
    public let hook: HookKind
    public var enabled: Bool
}

/// What an extension's script declares about itself, as a registry lists
/// it or as cohesiond read it from the script.
public struct ExtensionManifest: Decodable, Hashable {
    /// Such as `com.example.done-stamp`; installing a script with one
    /// already installed replaces that extension.
    public let identifier: String
    public let name: String
    public let version: Int
    public let description: String?
    public let author: String?
    /// A `data:image/…` or `https://` URL.
    public let icon: String?
    public let permissions: [ExtensionPermissionKind]
    public let hooks: [HookKind]
}

/// An extension a registry offers: what it lists, and where its script is.
public struct RegistryResult: Decodable, Hashable {
    public let manifest: ExtensionManifest
    /// An `http` or `https` URL serving the script.
    public let sourceURL: String

    enum CodingKeys: String, CodingKey {
        case manifest
        case sourceURL = "source_url"
    }
}

/// One registry's answer to a search.
public struct RegistrySection: Decodable, Identifiable {
    /// The registry extension's id.
    public let id: Int
    /// The registry extension's name.
    public let name: String
    public let results: [RegistryResult]
    /// Why this registry gave no results.
    public let error: String?

    enum CodingKeys: String, CodingKey {
        case name, results, error
        case id = "extension_id"
    }
}

/// An extension script cohesiond read, for review before installing it.
public struct ExtensionPreview: Decodable {
    public let script: String
    /// The manifest the script itself declares.
    public let manifest: ExtensionManifest
    /// The installed extension with the same identifier, which installing
    /// this script replaces.
    public let installed: ExtensionSummary?
}

/// What an extension's client function returned.
public struct ExtensionCallResult: Decodable {
    public let result: JSONValue
}

/// Any JSON value, for replies whose shape depends on the extension.
public enum JSONValue: Codable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    /// The value decoded as `type`, by way of its JSON.
    public func decode<Value: Decodable>(as type: Value.Type) throws -> Value {
        try JSONDecoder().decode(type, from: JSONEncoder().encode(self))
    }
}

// MARK: - iOS Companion

/// The companion extension's `status` reply.
public struct CompanionStatus: Decodable {
    public let signedIn: Bool
    public let account: String?
    /// The Cohesion Cloud base URL.
    public let cloud: String
    /// Whether the companion can look agents up (its `cohesion:read`
    /// permission), so pushes carry each agent's name, emoji and color.
    /// Older companions don't send it; assume they can.
    public let agentLookup: Bool
    /// The companion's version; `nil` from one that doesn't say, which is
    /// older than any that registers devices itself.
    public let version: Int?

    /// The first companion version that takes the phone's push tokens
    /// itself (`registerDevice` and the calls after it).
    public static let firstDeviceRegistrationVersion = 9

    /// Whether the companion registers devices itself.
    public var supportsDeviceRegistration: Bool {
        (version ?? 0) >= Self.firstDeviceRegistrationVersion
    }

    private enum CodingKeys: String, CodingKey {
        case signedIn, account, cloud, agentLookup, version
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        signedIn = try container.decode(Bool.self, forKey: .signedIn)
        account = try container.decodeIfPresent(String.self, forKey: .account)
        cloud = try container.decode(String.self, forKey: .cloud)
        agentLookup = try container.decodeIfPresent(Bool.self, forKey: .agentLookup) ?? true
        version = try? container.decodeIfPresent(Int.self, forKey: .version)
    }
}
