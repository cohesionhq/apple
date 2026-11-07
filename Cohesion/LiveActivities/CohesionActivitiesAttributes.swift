import ActivityKit
import CohesionCore
import Foundation

/// Every cohesiond activity in one Live Activity. The cloud starts it with a
/// push when the first activity starts, updates the same one as any of them
/// changes, drops a finished activity five minutes after it finished, and
/// ends it once none are left.
///
/// The cloud sends this exactly; every key may be missing, and a value newer
/// than this build falls back rather than failing the push:
///
/// ```json
/// "attributes": { "registrationCode": "…" },
/// "content-state": {
///   "overall": "running" | "needsAttention" | "done" | "failed",
///   "runningCount": 2,          // running or waiting
///   "needsAttentionCount": 1,   // paused: waiting on the user
///   "doneCount": 3,             // succeeded or cancelled
///   "failedCount": 0,
///   "activities": [             // at most 4, most useful first
///     {
///       "id": 9,              // the daemon's id; a number or a string
///       "title": "Q3 research",
///       "kind": { "kind": "actorSession", "actorSessionId": 3 },
///       "status": "running",    // cohesiond's ActivityStatus
///       "statusLabel": "Running",
///       "progress": "Read 12 of 40 sources",
///       "startedAt": 1793000000, // Unix seconds
///       "finishedAt": 1793000600 // Unix seconds, once it ended
///     }
///   ]
/// }
/// ```
///
/// The counts cover every activity, not only those listed. The cloud orders
/// `activities`: needing the user, longest waiting first; failed, latest
/// first; running or waiting, latest started first; then succeeded or
/// cancelled, latest finished first. A missing `overall` is read from the
/// counts.
nonisolated struct CohesionActivitiesAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var overall: OverallStatus
        var runningCount: Int
        var needsAttentionCount: Int
        var doneCount: Int
        var failedCount: Int
        /// The most important activities, first first.
        var activities: [Summary]

        /// Every activity the counts cover.
        var totalCount: Int { runningCount + needsAttentionCount + doneCount + failedCount }

        /// How much it matters next to other Live Activities, by the most
        /// pressing thing it counts; the cloud sends the same as
        /// `relevance-score`.
        var relevanceScore: Double {
            if needsAttentionCount > 0 { 100 }
            else if failedCount > 0 { 75 }
            else if runningCount > 0 { 50 }
            else { 25 }
        }

        init(
            overall: OverallStatus? = nil,
            runningCount: Int = 0,
            needsAttentionCount: Int = 0,
            doneCount: Int = 0,
            failedCount: Int = 0,
            activities: [Summary] = []
        ) {
            self.runningCount = runningCount
            self.needsAttentionCount = needsAttentionCount
            self.doneCount = doneCount
            self.failedCount = failedCount
            self.activities = activities
            self.overall = overall ?? OverallStatus(
                needsAttention: needsAttentionCount, failed: failedCount, running: runningCount
            )
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            func count(_ key: CodingKeys) -> Int {
                max(0, (try? container.decodeIfPresent(Int.self, forKey: key)) ?? 0)
            }
            self.init(
                overall: (try? container.decodeIfPresent(String.self, forKey: .overall)).flatMap { OverallStatus(rawValue: $0) },
                runningCount: count(.runningCount),
                needsAttentionCount: count(.needsAttentionCount),
                doneCount: count(.doneCount),
                failedCount: count(.failedCount),
                // One malformed entry drops only itself.
                activities: ((try? container.decodeIfPresent([Lenient<Summary>].self, forKey: .activities)) ?? [])
                    .compactMap(\.value)
            )
        }
    }

    /// One activity, as much as fits in a row.
    struct Summary: Codable, Hashable, Identifiable {
        /// The daemon's id for the activity, which another daemon on the
        /// same account may also use.
        var activityID: String
        var title: String
        var kind: ActivityKind
        var status: ActivityStatus
        /// What the daemon calls `status`, such as "Needs you" for `paused`.
        var statusLabel: String?
        /// What the work last said it is doing.
        var progress: String?
        /// Unix seconds.
        var startedAt: Int?
        /// When it succeeded, failed or was cancelled, in Unix seconds.
        var finishedAt: Int?

        var startDate: Date? { startedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) } }
        var finishDate: Date? { finishedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) } }

        /// Its kind with its id, which two daemons' activities don't share
        /// unless they are of the same actor session too.
        var id: String { "\(kind.key)/\(activityID)" }

        private enum CodingKeys: String, CodingKey {
            case kind, status, statusLabel, progress, startedAt, finishedAt, title
            case activityID = "id"
        }

        init(
            id: String,
            title: String,
            kind: ActivityKind = .unknown,
            status: ActivityStatus,
            statusLabel: String? = nil,
            progress: String? = nil,
            startedAt: Int? = nil,
            finishedAt: Int? = nil
        ) {
            self.activityID = id
            self.title = title
            self.kind = kind
            self.status = status
            self.statusLabel = statusLabel
            self.progress = progress
            self.startedAt = startedAt
            self.finishedAt = finishedAt
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            activityID = (try? container.decodeIfPresent(Int.self, forKey: .activityID)).map(String.init)
                ?? (try? container.decodeIfPresent(String.self, forKey: .activityID)) ?? ""
            title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? ""
            kind = (try? container.decodeIfPresent(ActivityKind.self, forKey: .kind)) ?? .unknown
            // A status newer than this build reads as still going, so its
            // row neither claims success nor asks for the user.
            status = (try? container.decodeIfPresent(String.self, forKey: .status))
                .flatMap { ActivityStatus(rawValue: $0) } ?? .running
            statusLabel = try? container.decodeIfPresent(String.self, forKey: .statusLabel)
            progress = try? container.decodeIfPresent(String.self, forKey: .progress)
            startedAt = try? container.decodeIfPresent(Int.self, forKey: .startedAt)
            finishedAt = try? container.decodeIfPresent(Int.self, forKey: .finishedAt)
        }
    }

    /// Where everything stands together.
    typealias OverallStatus = ActivityOverallStatus

    /// The cloud's code, which proves a push token registered for this Live
    /// Activity belongs to it.
    var registrationCode: String

    init(registrationCode: String = "") {
        self.registrationCode = registrationCode
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        registrationCode = (try? container.decodeIfPresent(String.self, forKey: .registrationCode)) ?? ""
    }
}

/// What an activity is, and so where tapping it goes. A kind newer than
/// this build, or one the daemon no longer has (`detachedRun`), is
/// `unknown`, so its row still shows.
nonisolated enum ActivityKind: Codable, Hashable {
    /// A stretch of an actor session's work.
    case actorSession(sessionID: Int)
    case unknown

    /// The kind and its actor session, as one string.
    var key: String {
        switch self {
        case .actorSession(let sessionID): "actorSession:\(sessionID)"
        case .unknown: "unknown"
        }
    }

    /// Where tapping it goes; `nil` just opens the app, as for a kind the
    /// app has no screen for.
    var link: AppLink? {
        switch self {
        case .actorSession(let sessionID): .actorSession(sessionID)
        case .unknown: nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case sessionID = "actorSessionId"
    }

    private enum Kind: String, Codable {
        case actorSession, unknown
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch Kind(rawValue: try container.decode(String.self, forKey: .kind)) {
        case .actorSession:
            self = .actorSession(sessionID: try container.decode(Int.self, forKey: .sessionID))
        case .unknown, nil:
            self = .unknown
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .actorSession(let sessionID):
            try container.encode(Kind.actorSession, forKey: .kind)
            try container.encode(sessionID, forKey: .sessionID)
        case .unknown:
            try container.encode(Kind.unknown, forKey: .kind)
        }
    }
}

/// Decodes a `Value`, or `nil` where it doesn't decode, so one bad element
/// doesn't fail its whole array.
private nonisolated struct Lenient<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: any Decoder) throws {
        value = try? Value(from: decoder)
    }
}
