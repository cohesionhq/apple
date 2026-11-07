/// Where an activity stands, as cohesiond's `ActivityStatus` says.
nonisolated public enum ActivityStatus: String, Codable, Hashable {
    case running, waiting, paused, succeeded, failed, cancelled

    public var hasEnded: Bool {
        switch self {
        case .running, .waiting, .paused: false
        case .succeeded, .failed, .cancelled: true
        }
    }
}

/// Where every activity stands together, the most pressing first.
nonisolated public enum ActivityOverallStatus: String, Codable, Hashable {
    case needsAttention, failed, running, done

    /// Read from the counts when the push names none.
    public init(needsAttention: Int, failed: Int, running: Int) {
        self = needsAttention > 0 ? .needsAttention
            : failed > 0 ? .failed
            : running > 0 ? .running
            : .done
    }
}
