import Foundation

/// A service connector extensions or clients reach, with the kinds of item
/// its accounts import. Every account of one connector shares it.
public struct Connector: Decodable, Identifiable, Hashable {
    public let id: Int
    /// Identifies the connector to its hosts, such as `com.example.notion`.
    public let identifier: String
    /// The service's name, such as "Notion".
    public let title: String
    /// A `data:image/…` or `https://` URL.
    public let icon: String?
    public let kinds: [ResourceKind]
    /// The metadata keys its resources may carry, which their list sorts
    /// by; a key newer than this build is left out.
    public let metadataKeys: [MetadataKey]

    enum CodingKeys: String, CodingKey {
        case id, identifier, title, icon, kinds
        case metadataKeys = "metadata_keys"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        identifier = try container.decode(String.self, forKey: .identifier)
        title = try container.decode(String.self, forKey: .title)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        kinds = try container.decode([ResourceKind].self, forKey: .kinds)
        metadataKeys = try container.decode([String].self, forKey: .metadataKeys).compactMap(MetadataKey.init(rawValue:))
    }
}

/// A kind of item a connector imports, such as a page or an email.
public struct ResourceKind: Decodable, Identifiable, Hashable {
    public let id: Int
    /// Its short key within its connector, such as `page`.
    public let identifier: String
    /// Its name for one, such as "Page".
    public let title: String
    /// Its name for several, such as "Pages", which titles their list.
    public let plural: String
}

/// What a resource's metadata may say, as its connector fills it.
public enum MetadataKey: String, Decodable, Hashable {
    case dateCreated, dateModified, dateDue, dateStart, dateEnd
    case author, url, location, folder, category, keywords, status
}

/// A kind of resource and the connector that declares it: one of the
/// workspace's resource pages.
public struct ConnectorKind: Identifiable, Hashable {
    public let connector: Connector
    public let kind: ResourceKind

    public init(connector: Connector, kind: ResourceKind) {
        self.connector = connector
        self.kind = kind
    }

    public var id: Int { kind.id }

    /// The kind as a resource names it: its connector's identifier and its
    /// own, such as `com.example.notion.page`.
    public var name: String { "\(connector.identifier).\(kind.identifier)" }
}

/// What serves a connector account.
public enum AccountHost: Decodable, Hashable {
    /// An extension, which holds the account's credential.
    case `extension`
    /// A client offering the connector, reachable while it is online.
    case client(id: Int)
    /// Nothing any more: its extension was uninstalled, or its client
    /// revoked or no longer offering the connector.
    case orphaned
    /// A host newer than this build.
    case other

    private enum CodingKeys: String, CodingKey {
        case kind
        case clientID = "client_id"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "extension": self = .extension
        case "client": self = .client(id: try container.decode(Int.self, forKey: .clientID))
        case "orphaned": self = .orphaned
        default: self = .other
        }
    }
}

/// An account added through a connector, without its credential.
public struct ConnectorAccount: Decodable, Identifiable, Hashable {
    public let id: Int
    public let host: AccountHost
    public let connector: Connector
    /// Its name or email, or its client's name.
    public let description: String
    /// Whether its items can be browsed and imported: an orphaned
    /// account's, or one that is only a sign-in, can't.
    public let importable: Bool

    /// Whether it can reach its service now: a client's account only while
    /// its client is online.
    public func isOnline(clients: [Client]) -> Bool {
        guard case .client(let id) = host else { return true }
        return clients.first { $0.id == id }?.online ?? false
    }
}

extension [ConnectorAccount] {
    /// Every kind of every connector with an account that can import, in
    /// the accounts' order, each once: what a workspace can show.
    public var importableKinds: [ConnectorKind] {
        var seen = Set<Int>()
        return filter(\.importable)
            .map(\.connector)
            .filter { seen.insert($0.id).inserted }
            .flatMap { connector in connector.kinds.map { ConnectorKind(connector: connector, kind: $0) } }
    }
}

/// A kind of resource a workspace shows in its sidebar.
public struct WorkspaceResourceKind: Decodable {
    public let kindID: Int

    enum CodingKeys: String, CodingKey {
        case kindID = "kind_id"
    }
}

/// A read-only copy of an item imported into a workspace from a connected
/// service, which cohesiond refreshes from it.
public struct Resource: Decodable, Identifiable, Hashable {
    public let id: Int
    public let accountID: Int
    public let kindID: Int
    public let title: String
    public let contentKind: ResourceContentKind
    public let contents: String
    /// When the item last changed at its service; nil when the service
    /// doesn't say, which the wire sends as 0.
    public let lastUpdated: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, contents
        case accountID = "account_id"
        case kindID = "kind_id"
        case contentKind = "content_kind"
        case lastUpdated = "last_updated"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        accountID = try container.decode(Int.self, forKey: .accountID)
        kindID = try container.decode(Int.self, forKey: .kindID)
        title = try container.decode(String.self, forKey: .title)
        contentKind = try container.decode(ResourceContentKind.self, forKey: .contentKind)
        contents = try container.decode(String.self, forKey: .contents)
        let seconds = try container.decode(Double.self, forKey: .lastUpdated)
        lastUpdated = seconds == 0 ? nil : Date(timeIntervalSince1970: seconds)
    }
}

/// What a resource's contents hold.
public enum ResourceContentKind: String, Decodable, Hashable {
    case markdown, text, json
}

/// The order a workspace's resources list in.
public enum ResourceSort: Hashable {
    case title
    case lastUpdated
    case metadata(MetadataKey)

    public var wireValue: String {
        switch self {
        case .title: "title"
        case .lastUpdated: "lastUpdated"
        case .metadata(let key): key.rawValue
        }
    }

    public init?(wireValue: String) {
        switch wireValue {
        case "title": self = .title
        case "lastUpdated": self = .lastUpdated
        default:
            guard let key = MetadataKey(rawValue: wireValue) else { return nil }
            self = .metadata(key)
        }
    }
}

/// A group an account files its items under, such as a team space.
public struct OrganizationUnit: Decodable, Identifiable, Hashable {
    public let id: String
    public let display: String
}

/// One item an account offers for import.
public struct ImportableResource: Decodable, Identifiable {
    public let identifier: String
    public let title: String
    /// When the item last changed at its service; nil when the service
    /// doesn't say.
    public let lastUpdated: Date?
    /// Whether the workspace already has it.
    public var imported: Bool

    public var id: String { identifier }

    enum CodingKeys: String, CodingKey {
        case identifier, title, imported
        case lastUpdated = "last_updated"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.decode(String.self, forKey: .identifier)
        title = try container.decode(String.self, forKey: .title)
        lastUpdated = try container.decodeIfPresent(Double.self, forKey: .lastUpdated)
            .map(Date.init(timeIntervalSince1970:))
        imported = try container.decode(Bool.self, forKey: .imported)
    }
}

/// What refreshing a workspace's resources did.
public struct ResourceRefreshSummary: Decodable {
    /// Resources fetched from their services.
    public let checked: Int
    /// Resources whose contents changed.
    public let updated: Int
    /// Resources that couldn't be fetched.
    public let failed: Int
}
