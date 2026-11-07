import CryptoKit
import Foundation
import Security

/// What a setup code tells a new client: `base64("<key>|<address>|<fingerprint>")`.
/// The address is an ip or a DNS name, which means cohesiond's default port,
/// or `host:port` (`[v6]:port` for IPv6).
public struct SetupCode {
    /// The port cohesiond listens on unless the setup code's address names another.
    public static let defaultPort = 3000

    /// The secret cohesiond expects on `/register`.
    public let key: String
    /// The ip or DNS name cohesiond can be reached at.
    public let host: String
    /// The HTTPS port clients connect to.
    public let port: Int
    /// SHA-256 of cohesiond's public key, which its certificate must match.
    public let fingerprint: String

    public init(_ code: String) throws(PairingError) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed),
              let text = String(data: data, encoding: .utf8)
        else { throw .invalidSetupCode }
        let parts = text.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 3 else { throw .invalidSetupCode }
        let address = try Self.address(String(parts[1]))
        key = String(parts[0])
        host = address.host
        port = address.port
        fingerprint = String(parts[2])
    }

    /// Splits `host`, `host:port` or `[v6]:port`; a bare IPv6 address has several colons and no port.
    private static func address(_ text: String) throws(PairingError) -> (host: String, port: Int) {
        let host: Substring
        let portText: Substring
        if text.hasPrefix("[") {
            guard let close = text.firstIndex(of: "]"),
                  text[text.index(after: close)...].hasPrefix(":")
            else { throw .invalidSetupCode }
            host = text[text.index(after: text.startIndex)..<close]
            portText = text[text.index(close, offsetBy: 2)...]
        } else if text.filter({ $0 == ":" }).count == 1, let colon = text.firstIndex(of: ":") {
            host = text[..<colon]
            portText = text[text.index(after: colon)...]
        } else {
            return (text, defaultPort)
        }
        guard let port = UInt16(portText), port > 0 else { throw .invalidSetupCode }
        return (String(host), Int(port))
    }
}

public enum PairingError: LocalizedError {
    case invalidSetupCode
    case cannotCreateIdentity
    /// The keychain can't be read yet, as before the device's first unlock.
    case unavailable

    public var errorDescription: String? {
        switch self {
        case .invalidSetupCode: "That isn't a valid setup code."
        case .cannotCreateIdentity: "Couldn't create a certificate."
        case .unavailable: "Unlock this device to use Cohesion."
        }
    }
}

/// What the keychain says of this device's pairing.
public enum SavedPairing {
    case paired(Pairing)
    /// No pairing is saved.
    case unpaired
    /// The keychain can't be read now, as before the device's first unlock,
    /// which says nothing about whether a pairing is saved.
    case unavailable
}

/// This device's registration with one cohesiond, kept in the keychain.
public struct Pairing: Codable {
    public let host: String
    public let port: Int
    public let serverFingerprint: String
    /// The raw P-256 private key whose certificate cohesiond trusts.
    public let privateKey: Data
    /// DER of this device's self-signed certificate.
    public let certificate: Data

    /// A new key and certificate for the server a setup code names.
    public init(setupCode: SetupCode, clientName: String) throws {
        let key = P256.Signing.PrivateKey()
        host = setupCode.host
        port = setupCode.port
        serverFingerprint = setupCode.fingerprint
        privateKey = key.rawRepresentation
        certificate = try SelfSignedCertificate.make(for: key, name: clientName)
    }

    /// Reads a pairing saved before the port was configurable as being on the default port.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        host = try container.decode(String.self, forKey: .host)
        port = try container.decodeIfPresent(Int.self, forKey: .port) ?? SetupCode.defaultPort
        serverFingerprint = try container.decode(String.self, forKey: .serverFingerprint)
        privateKey = try container.decode(Data.self, forKey: .privateKey)
        certificate = try container.decode(Data.self, forKey: .certificate)
    }

    /// The certificate and key, as URLSession presents them for client authentication.
    public func identity() throws(PairingError) -> SecIdentity {
        let key = try? P256.Signing.PrivateKey(rawRepresentation: privateKey)
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
        ]
        guard let key,
              let secKey = SecKeyCreateWithData(key.x963Representation as CFData, attributes as CFDictionary, nil),
              let secCertificate = SecCertificateCreateWithData(nil, certificate as CFData),
              let identity = SecIdentityCreate(nil, secCertificate, secKey)
        else { throw .cannotCreateIdentity }
        return identity
    }
}

// MARK: - Keychain

extension Pairing {
    private static let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: "Cohesion",
        kSecAttrAccount: "pairing",
    ]

    /// Reads the saved pairing, leaving the keychain as it is whatever it says.
    public static func read() -> SavedPairing {
        var query = query
        query[kSecReturnData] = true
        var result: CFTypeRef?
        switch SecItemCopyMatching(query as CFDictionary, &result) {
        case errSecSuccess:
            guard let data = result as? Data,
                  let pairing = try? JSONDecoder().decode(Pairing.self, from: data)
            else { return .unpaired }
            return .paired(pairing)
        case errSecItemNotFound:
            return .unpaired
        default:
            return .unavailable
        }
    }

    /// The saved pairing, for what has nothing to say while it can't be read.
    public static func load() -> Pairing? {
        if case .paired(let pairing) = read() { pairing } else { nil }
    }

    public func save() {
        Self.remove()
        var item = Self.query
        item[kSecValueData] = try? JSONEncoder().encode(self)
        item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    public static func remove() {
        SecItemDelete(query as CFDictionary)
    }
}
