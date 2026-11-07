import Foundation


/// A person a workspace keeps: their name, the ways to reach them, a photo
/// and notes.
public struct Contact: Decodable, Identifiable, Equatable {
    public let id: Int
    public let workspaceID: Int
    public let firstName: String
    /// `nil` when they have none; never empty.
    public let middleName: String?
    public let lastName: String
    /// Markdown.
    public let notes: String
    public let photo: ContactPhoto
    /// The email addresses and phone numbers that reach them, in the order
    /// they were added.
    public let methods: [ContactMethod]

    enum CodingKeys: String, CodingKey {
        case id, notes, photo, methods
        case workspaceID = "workspace_id"
        case firstName = "first_name"
        case middleName = "middle_name"
        case lastName = "last_name"
    }

    /// First, middle and last, as the web shows it.
    public var fullName: String {
        [firstName, middleName, lastName].compactMap(\.self).joined(separator: " ")
    }

    /// The methods of `kind`, in their order.
    public func methods(_ kind: ContactMethodKind) -> [ContactMethod] {
        methods.filter { $0.kind == kind }
    }
}

/// The user's own profile: their name and photo, which draw them where a
/// task is assigned to them.
public struct Profile: Decodable, Equatable {
    /// `nil` until they set one; never empty.
    public let name: String?
    public let photo: ContactPhoto
}

/// A contact's or the user's photo, or that there is none; tagged by `kind`
/// on the wire.
public enum ContactPhoto: Decodable, Equatable {
    case none
    /// Decoded once, as the reply is, rather than on every draw.
    case image(PlatformImage)

    private enum CodingKeys: String, CodingKey {
        case kind
        case data = "photo_data"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "image":
            let data = try container.decode(String.self, forKey: .data)
            // A photo that doesn't decode shows as none rather than failing the list.
            self = PlatformImage.decoding(base64: data).map(Self.image) ?? .none
        default: self = .none
        }
    }

    public var image: PlatformImage? {
        if case .image(let image) = self { image } else { nil }
    }
}

/// One way to reach a contact: an email address or a phone number.
public struct ContactMethod: Decodable, Identifiable, Equatable {
    public let id: Int
    public let kind: ContactMethodKind
    /// The address or number, as written; never empty.
    public let value: String
}

public enum ContactMethodKind: String, Decodable, CaseIterable, Identifiable {
    case email
    case phone

    public var id: Self { self }

    /// What the web calls it, as a label and as a choice.
    public var label: String {
        switch self {
        case .email: "Email"
        case .phone: "Phone"
        }
    }
}

/// An email address or phone number to create a contact with.
public struct NewContactMethod: Equatable {
    public var kind: ContactMethodKind
    public var value: String

    public init(kind: ContactMethodKind, value: String) {
        self.kind = kind
        self.value = value
    }

    public var wireValue: [String: String] {
        ["kind": kind.rawValue, "value": value]
    }
}
