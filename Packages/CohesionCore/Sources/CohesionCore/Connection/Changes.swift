import Foundation
import Synchronization

/// Data cohesiond reports changed, as named in its `invalidate` pushes. Only
/// the kinds the app watches are told apart.
public enum Invalidation: Decodable, Equatable {
    /// Anything about an agent changed: its row, messages, cues or runs.
    case agent(Int)
    /// The teams of agents changed: one was created, renamed or deleted.
    case agentTeams
    /// A workspace's task folders changed.
    case taskFolders(workspaceID: Int)
    /// The tasks in one of a workspace's lists changed.
    case taskList(workspaceID: Int)
    /// A workspace's saved task views changed: one was created, changed,
    /// renamed, reordered or deleted, or lost a folder or tag it used.
    case savedTaskViews(workspaceID: Int)
    /// A workspace's tags changed: one was created, renamed or deleted.
    case tags(workspaceID: Int)
    /// A workspace's contacts changed: one was created, changed or deleted,
    /// or one of its methods was added, changed or removed.
    case contacts(workspaceID: Int)
    /// The user's profile changed: their name or photo was set or removed.
    case profile
    /// A workspace's documents changed, journal entries among them.
    case documents(workspaceID: Int)
    /// The feed list changed, or a feed's unread count did. Feeds are shared
    /// by every workspace.
    case feeds
    /// A feed's article changed: one was added or removed, fetched again,
    /// renamed, or marked read or unread.
    case feedArticles
    /// The endpoints, the models they offer, or the tier defaults changed.
    case intelligence
    /// A client was paired, renamed or revoked, or one connected or left.
    case clients
    /// A connector account was added, re-authenticated or removed.
    case connectorAccounts
    /// A workspace's resources changed: one was imported, refreshed or
    /// removed.
    case resources(workspaceID: Int)
    /// The kinds of resource a workspace shows changed: one was shown,
    /// hidden or moved.
    case resourceKinds(workspaceID: Int)
    /// A memory was remembered or forgotten, or an agent's went with it.
    case memories
    /// A client offered an actor, changed one or stopped offering it.
    case actors
    /// An actor session was started, said something, changed where it stands
    /// or ended.
    case actorSessions
    /// What was said in an actor session changed.
    case actorSession(Int)
    /// How much of its plan an actor has used changed.
    case actorUsage
    /// A note for whoever is looking, such as an agent's, to show once;
    /// nothing stores it.
    case notification(Notice)
    case other

    private enum CodingKeys: String, CodingKey {
        case kind, id
    }

    /// A `taskList` key's `id`; the list's folder isn't told apart.
    private struct TaskListKey: Decodable {
        let workspaceID: Int

        private enum CodingKeys: String, CodingKey {
            case workspaceID = "workspace_id"
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "agent": self = .agent(try container.decode(Int.self, forKey: .id))
        case "agentTeams": self = .agentTeams
        case "taskFolders": self = .taskFolders(workspaceID: try container.decode(Int.self, forKey: .id))
        case "taskList": self = .taskList(workspaceID: try container.decode(TaskListKey.self, forKey: .id).workspaceID)
        case "savedTaskViews": self = .savedTaskViews(workspaceID: try container.decode(Int.self, forKey: .id))
        case "tags": self = .tags(workspaceID: try container.decode(Int.self, forKey: .id))
        case "contacts": self = .contacts(workspaceID: try container.decode(Int.self, forKey: .id))
        case "profile": self = .profile
        case "documents": self = .documents(workspaceID: try container.decode(Int.self, forKey: .id))
        case "feeds": self = .feeds
        case "feedArticles": self = .feedArticles
        case "intelligence": self = .intelligence
        case "clients": self = .clients
        case "connectorAccounts": self = .connectorAccounts
        case "resources": self = .resources(workspaceID: try container.decode(Int.self, forKey: .id))
        case "resourceKinds": self = .resourceKinds(workspaceID: try container.decode(Int.self, forKey: .id))
        case "memories": self = .memories
        case "actors": self = .actors
        case "actorSessions": self = .actorSessions
        case "actorSession": self = .actorSession(try container.decode(Int.self, forKey: .id))
        case "actorUsage": self = .actorUsage
        case "notification":
            // A note this build can't read is skipped rather than failing the whole push.
            self = (try? container.decode(Notice.self, forKey: .id)).map(Self.notification) ?? .other
        default: self = .other
        }
    }
}

/// A transient note cohesiond pushes, shown once as a toast.
public struct Notice: Decodable, Equatable {
    public let title: String
    public let message: String
}

/// Where the change socket stands, as the sidebar's dot shows it.
public enum ConnectionState {
    /// The first socket hasn't been greeted yet.
    case connecting
    case connected
    /// A socket that was greeted dropped, and another is on its way.
    case reconnecting
    /// cohesiond revoked this client: it ended every socket, and no other
    /// follows until the app pairs again.
    case revoked
}

/// The server frames the app reads off the socket. The only reply is the
/// subscribe's, since commands go over HTTPS.
private struct PushFrame: Decodable {
    let type: String
    let keys: [Invalidation]?
    /// Why an `evicted` frame's session ended.
    let reason: EvictionReason?
}

/// Why cohesiond ended a session. Only `revoked` reaches the app, since
/// `replaced` goes to a client that offers, which it never does.
private enum EvictionReason: String, Decodable {
    case replaced
    case revoked
}

/// A `hello`'s vocabulary, read apart from its frame so one this build can't
/// decode (a kind newer than it knows) leaves the socket open.
private struct HelloFrame: Decodable {
    let vocabulary: Vocabulary
}

/// Who's listening on a client's one change socket, and what holds it open.
final class ChangeSocket {
    var listeners: [UUID: ([Invalidation]?) -> Void] = [:]
    var task: Task<Void, Never>?
    /// Whether the socket is subscribed now, so someone starting to listen
    /// won't hear it subscribe.
    var isSubscribed = false
}

extension CohesionClient {
    /// Yields whenever cohesiond reports a change `matches` accepts, while
    /// the stream lasts.
    ///
    /// Each `hello` updates `vocabulary`. It also yields on starting to
    /// listen once the socket is subscribed, each time the socket subscribes,
    /// including after the app returns from the background, and when
    /// cohesiond drops pushes, because changes may have been missed. Yields
    /// that arrive during a reload collapse into one.
    public func changes(matching matches: @escaping (Invalidation) -> Bool) -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let listener = listen { keys in
                // `nil` for a subscribe's reply or a reset: anything may have changed.
                if keys?.contains(where: matches) ?? true { continuation.yield() }
            }
            continuation.onTermination = { _ in
                Task { @MainActor in self.stopListening(listener) }
            }
        }
    }

    /// `changes`, saying why each is worth loading: the first opens the
    /// screen listening, so it's `asked`; the rest are `automatic`.
    public func loads(matching matches: @escaping (Invalidation) -> Bool) -> AsyncStream<LoadOrigin> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            var origin = LoadOrigin.asked
            let listener = listen { keys in
                guard keys?.contains(where: matches) ?? true else { return }
                continuation.yield(origin)
                origin = .automatic
            }
            continuation.onTermination = { _ in
                Task { @MainActor in self.stopListening(listener) }
            }
        }
    }

    /// Yields each note cohesiond pushes, as it arrives.
    public func notices() -> AsyncStream<Notice> {
        AsyncStream { continuation in
            let listener = listen { keys in
                for case .notification(let notice) in keys ?? [] { continuation.yield(notice) }
            }
            continuation.onTermination = { _ in
                Task { @MainActor in self.stopListening(listener) }
            }
        }
    }

    /// Hands `receive` each `invalidate`'s keys, or `nil` once subscribed and
    /// on a `reset`, over the client's one socket, opening it for the first
    /// to listen. Until `stopListening` is called with what this returns.
    private func listen(_ receive: @escaping ([Invalidation]?) -> Void) -> UUID {
        let listener = UUID()
        changeSocket.listeners[listener] = receive
        if changeSocket.isSubscribed { receive(nil) }
        #if DEBUG
        if previewReplies != nil { return listener }
        #endif
        if changeSocket.task == nil, connection != .revoked {
            changeSocket.task = Task { await holdSocket() }
        }
        return listener
    }

    /// Closes the socket once the last to listen has stopped.
    private func stopListening(_ listener: UUID) {
        changeSocket.listeners[listener] = nil
        guard changeSocket.listeners.isEmpty else { return }
        changeSocket.task?.cancel()
        changeSocket.task = nil
        changeSocket.isSubscribed = false
    }

    private func tellListeners(_ keys: [Invalidation]?) {
        for receive in changeSocket.listeners.values { receive(keys) }
    }

    /// Holds a subscribed socket open until cancelled, reconnecting after a
    /// backoff that doubles to 10 seconds. Updates `vocabulary` on each
    /// `hello`, and `connection` as it goes. Once cohesiond revokes the
    /// client, it stops for good.
    private func holdSocket() async {
        var backoff = Duration.milliseconds(500)
        while !Task.isCancelled, connection != .revoked {
            let socket = webSocket()
            socket.resume()
            let heartbeat = Task { await keepAlive(socket) }
            do {
                while connection != .revoked {
                    let message = try await withTaskCancellationHandler {
                        try await socket.receive()
                    } onCancel: {
                        socket.cancel()
                    }
                    guard case .string(let text) = message else { continue }
                    let data = Data(text.utf8)
                    let frame = try JSONDecoder().decode(PushFrame.self, from: data)
                    switch frame.type {
                    case "hello":
                        backoff = .milliseconds(500)
                        connection = .connected
                        if let hello = try? JSONDecoder().decode(HelloFrame.self, from: data) {
                            vocabulary = hello.vocabulary
                        }
                        try await socket.send(.string(#"{"type":"subscribe","id":1}"#))
                    case "reply":
                        changeSocket.isSubscribed = true
                        tellListeners(nil)
                    case "reset":
                        tellListeners(nil)
                    case "invalidate":
                        tellListeners(frame.keys ?? [])
                    case "evicted" where frame.reason == .revoked:
                        connection = .revoked
                    default:
                        break
                    }
                }
            } catch {
                // A client cohesiond no longer knows, revoked while this one
                // was away, is refused before it's greeted.
                if (socket.response as? HTTPURLResponse)?.statusCode == 403 { connection = .revoked }
            }
            heartbeat.cancel()
            socket.cancel()
            // Everyone stopped listening, which closed the socket; nothing
            // dropped, and a socket opened since is another's.
            if Task.isCancelled { break }
            changeSocket.isSubscribed = false
            if connection == .revoked { break }
            if connection == .connected { connection = .reconnecting }
            try? await Task.sleep(for: backoff)
            backoff = min(backoff * 2, .seconds(10))
        }
    }

    /// Pings `socket` every 15 seconds and cancels it once a pong is late, so
    /// a connection that died quietly (a network change, a stay in the
    /// background) fails `receive()` and reconnects, rather than leaving it
    /// waiting on pushes that never come.
    private func keepAlive(_ socket: URLSessionWebSocketTask) async {
        let pong = Pong()
        while true {
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            let answered = pong.answered.withLock { answered in
                defer { answered = false }
                return answered
            }
            guard answered else {
                socket.cancel()
                return
            }
            socket.sendPing { error in
                if error == nil { pong.answered.withLock { $0 = true } }
            }
        }
    }
}

/// Whether the last ping was answered; pongs land on URLSession's queue.
private nonisolated final class Pong: Sendable {
    let answered = Mutex(true)
}
