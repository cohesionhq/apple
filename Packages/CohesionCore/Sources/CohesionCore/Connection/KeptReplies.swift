import Foundation

/// The last reply to each command that keeps one, as cohesiond sent it, on
/// the device for one server. Only the lists a screen opens on (the agents,
/// task folders, feeds…) are kept, so the screen shows them at once on the
/// next launch while it asks again; what opens from them is always asked for.
public nonisolated struct KeptReplies {
    /// How much of a command's reply `CohesionClient.call` keeps.
    public enum Keeping {
        case whole
        /// The reply with these string fields of each listed item emptied:
        /// what the list doesn't show and has no place on the device, such
        /// as a document's contents.
        case blanking(Set<String>)
    }

    private let directory: URL

    public init(server: String) {
        directory = Self.root.appending(
            path: server.filter { $0.isLetter || $0.isNumber },
            directoryHint: .isDirectory
        )
    }

    /// Where every server's replies are; a cache, which the system may empty.
    private static var root: URL {
        URL.cachesDirectory.appending(path: "Replies", directoryHint: .isDirectory)
    }

    /// The name `type` with `args` is kept under: the command, then its
    /// arguments by name.
    public static func key(_ type: String, _ args: [String: Any?]?) -> String {
        let args = (args ?? [:]).compactMapValues { $0 }.sorted { $0.key < $1.key }
        return ([type] + args.map { "\($0.key)=\($0.value)" })
            .joined(separator: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "=" }
    }

    public func reply(for key: String) -> Data? {
        try? Data(contentsOf: url(for: key))
    }

    /// Keeps `reply`, a whole reply frame, as `keeping` says.
    public func keep(_ reply: Data, for key: String, _ keeping: Keeping) {
        var reply = reply
        switch keeping {
        case .whole: break
        case .blanking(let fields):
            guard var frame = (try? JSONSerialization.jsonObject(with: reply)) as? [String: Any],
                  var ok = frame["ok"] as? [String: Any],
                  let items = ok["data"] as? [[String: Any]]
            else { return }
            ok["data"] = items.map { item in
                var item = item
                for field in fields where item[field] is String { item[field] = "" }
                return item
            }
            frame["ok"] = ok
            guard let blanked = try? JSONSerialization.data(withJSONObject: frame) else { return }
            reply = blanked
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? reply.write(to: url(for: key), options: .atomic)
    }

    /// Forgets every server's replies, as unpairing does.
    public static func forgetAll() {
        try? FileManager.default.removeItem(at: root)
    }

    private func url(for key: String) -> URL {
        directory.appending(path: "\(key).json")
    }
}
