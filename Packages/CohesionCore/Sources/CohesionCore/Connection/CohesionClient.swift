import CryptoKit
import Foundation
import Observation
import Security

/// Sends commands to cohesiond over mutual TLS, one HTTPS request each, and
/// listens for its change pushes over a WebSocket.
@Observable
public final class CohesionClient {
    @ObservationIgnored private let session: URLSession
    @ObservationIgnored private let baseURL: URL
    /// The replies kept on the device, in the app only.
    @ObservationIgnored private let kept: KeptReplies?
    /// The diagrams cohesiond has drawn, in memory only: a diagram streaming
    /// in leaves one for every step that parsed.
    @ObservationIgnored private(set) var renderedMermaid: [RenderedMermaidKey: RenderedMermaid] = [:]
    /// The one socket every `changes` and `notices` shares.
    @ObservationIgnored let changeSocket = ChangeSocket()
    /// How to word and order cohesiond's kinds, as its latest `hello` sent it.
    public var vocabulary = Vocabulary()
    /// Where the change socket stands.
    public var connection = ConnectionState.connecting
    #if DEBUG
    /// The replies a preview's client answers with in place of cohesiond's,
    /// by command type and arguments: the JSON of the reply's `data`.
    @ObservationIgnored var previewReplies: ((String, [String: Any]) -> String?)?
    #endif

    /// `keepsReplies` keeps the last reply to each command that asks
    /// (`keeping`) for `keptReply` to read, on later launches too.
    public init(pairing: Pairing, keepsReplies: Bool = false) throws {
        let delegate = TrustDelegate(
            identity: try pairing.identity(),
            serverFingerprint: pairing.serverFingerprint
        )
        session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        // IPv6 addresses need brackets in a URL.
        let host = pairing.host.contains(":") ? "[\(pairing.host)]" : pairing.host
        baseURL = URL(string: "https://\(host):\(pairing.port)")!
        kept = keepsReplies ? KeptReplies(server: pairing.serverFingerprint) : nil
    }

    #if DEBUG
    /// A client for `#Preview`s, connected to nothing: each command is
    /// answered by `replies` (the JSON of its reply's `data`, or `nil` to
    /// fail it), and the change socket counts as subscribed, so each screen
    /// loads once.
    public init(previewReplies replies: @escaping (_ type: String, _ args: [String: Any]) -> String?, vocabulary: Vocabulary = Vocabulary()) {
        session = URLSession(configuration: .ephemeral)
        baseURL = URL(string: "https://preview.invalid")!
        kept = nil
        previewReplies = replies
        self.vocabulary = vocabulary
        connection = .connected
        changeSocket.isSubscribed = true
    }
    #endif

    deinit {
        session.invalidateAndCancel()
    }

    /// Asks cohesiond to trust `pairing`'s certificate.
    ///
    /// cohesiond judges a connection by its certificate when it opens, so the
    /// connection that registered stays unregistered; this one is thrown away
    /// and commands go through a new client.
    public static func register(_ pairing: Pairing, setupKey: String, clientName: String) async throws {
        let client = try CohesionClient(pairing: pairing)
        let _: Registered = try await client.post("register", ["setup_key": setupKey, "client_name": clientName])
    }

    /// Runs `type` with `args`, whose `nil` values are left out. Unless
    /// `resendsIfDropped` is false, a command whose connection had died is
    /// sent again; a caller for whom a second copy would do it twice passes
    /// false and handles `URLError.networkConnectionLost` itself.
    /// `keeping` says how much of the reply to keep for `keptReply`, when
    /// this client keeps replies.
    public func call<Reply: Decodable>(
        _ type: String,
        _ args: [String: Any?]? = nil,
        resendsIfDropped: Bool = true,
        keeping: KeptReplies.Keeping? = nil
    ) async throws -> Reply {
        var body: [String: Any] = ["type": type]
        body["args"] = args?.compactMapValues { $0 }
        #if DEBUG
        if let previewReplies {
            return try previewReply(type, previewReplies(type, args?.compactMapValues { $0 } ?? [:]))
        }
        #endif
        return try await post(
            "command",
            body,
            resendsIfDropped: resendsIfDropped,
            keeping: keeping.map { (KeptReplies.key(type, args), $0) }
        )
    }

    /// The reply `type` with `args` last had, from an earlier launch too, if
    /// it was kept; what a screen shows until it has the reply again.
    public func keptReply<Reply: Decodable>(_ type: String, _ args: [String: Any?]? = nil) -> Reply? {
        #if DEBUG
        if let previewReplies {
            return try? previewReply(type, previewReplies(type, args?.compactMapValues { $0 } ?? [:]))
        }
        #endif
        guard let data = kept?.reply(for: KeptReplies.key(type, args)) else { return nil }
        return (try? JSONDecoder().decode(ReplyFrame<Reply>.self, from: data))?.ok?.data
    }

    #if DEBUG
    /// `json` decoded as `type`'s reply, failing as cohesiond would for a
    /// command a preview doesn't answer.
    private func previewReply<Reply: Decodable>(_ type: String, _ json: String?) throws -> Reply {
        guard let json else {
            print("Preview: no reply for \(type)")
            throw ServerError(code: ServerError.notFound, message: "No preview reply for \(type).")
        }
        do {
            return try JSONDecoder().decode(Reply.self, from: Data(json.utf8))
        } catch {
            print("Preview: \(type)'s reply doesn't decode: \(error)")
            throw error
        }
    }
    #endif

    /// Keeps a drawn diagram, starting over once there are 100 of them.
    func keep(_ rendered: RenderedMermaid, for key: RenderedMermaidKey) {
        if renderedMermaid.count >= 100 { renderedMermaid.removeAll() }
        renderedMermaid[key] = rendered
    }

    /// A new, unstarted WebSocket to cohesiond's session route.
    public func webSocket() -> URLSessionWebSocketTask {
        var components = URLComponents(url: baseURL.appending(path: "connect"), resolvingAgainstBaseURL: false)!
        components.scheme = "wss"
        return session.webSocketTask(with: components.url!)
    }

    private func post<Reply: Decodable>(
        _ path: String,
        _ body: [String: Any],
        resendsIfDropped: Bool = true,
        keeping: (key: String, KeptReplies.Keeping)? = nil
    ) async throws -> Reply {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await resendsIfDropped ? data(for: request) : session.data(for: request)
        if let response = response as? HTTPURLResponse, response.statusCode != 200 {
            throw ServerError(code: "http\(response.statusCode)", message: String(decoding: data, as: UTF8.self))
        }
        let frame = try JSONDecoder().decode(ReplyFrame<Reply>.self, from: data)
        if let error = frame.error { throw error }
        if let (key, keeping) = keeping { kept?.keep(data, for: key, keeping) }
        return frame.ok!.data
    }

    /// Sends `request`, again once if the connection it went out on had
    /// died. cohesiond drops an HTTP/2 connection whose keepalive pings go
    /// unanswered, as they do while the app is suspended, and URLSession
    /// only learns so from the first request it sends on it after the app
    /// returns; that request never reached cohesiond.
    private func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError where error.code == .networkConnectionLost {
            return try await session.data(for: request)
        }
    }
}

/// The reply frame around a command's outcome.
private struct ReplyFrame<Reply: Decodable>: Decodable {
    struct Ok: Decodable {
        let data: Reply
    }

    let ok: Ok?
    let error: ServerError?
}

/// `/register`'s reply, read only for whether it succeeded: the client it
/// carries isn't the clients list's `Client`, which also says `online`.
private struct Registered: Decodable {}

/// Why cohesiond refused a command.
public struct ServerError: LocalizedError, Decodable {
    /// cohesiond's `ErrorCode` for a missing entity, such as an extension
    /// identifier nothing installed declares.
    public static let notFound = "notFound"
    /// cohesiond's `ErrorCode` for a request it can't read, such as a
    /// command newer than it.
    public static let badRequest = "badRequest"

    /// cohesiond's `ErrorCode` for a request it read but refused, such as
    /// an extension script without a valid manifest.
    public static let validationFailed = "validationFailed"

    public let code: String
    public let message: String

    public var errorDescription: String? { message }
}

/// Presents this device's certificate, and trusts only the server whose key
/// matches the fingerprint from its setup code.
///
/// cohesiond signs a fresh self-signed certificate on every start, so there's
/// no certificate authority to check against; its key is what stays the same.
private final class TrustDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let identity: SecIdentity
    private let serverFingerprint: String

    init(identity: SecIdentity, serverFingerprint: String) {
        self.identity = identity
        self.serverFingerprint = serverFingerprint
    }

    nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodClientCertificate:
            return (.useCredential, URLCredential(identity: identity, certificates: nil, persistence: .forSession))
        case NSURLAuthenticationMethodServerTrust:
            guard let trust = challenge.protectionSpace.serverTrust,
                  fingerprint(of: trust) == serverFingerprint
            else { return (.cancelAuthenticationChallenge, nil) }
            return (.useCredential, URLCredential(trust: trust))
        default:
            return (.performDefaultHandling, nil)
        }
    }

    /// Lowercase hex SHA-256 of the server certificate's SubjectPublicKeyInfo.
    private nonisolated func fingerprint(of trust: SecTrust) -> String? {
        guard let certificate = (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first,
              let key = SecCertificateCopyKey(certificate),
              let point = SecKeyCopyExternalRepresentation(key, nil) as Data?,
              let publicKey = try? P256.Signing.PublicKey(x963Representation: point)
        else { return nil }
        return SHA256.hash(data: publicKey.derRepresentation)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
