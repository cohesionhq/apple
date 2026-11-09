import ActivityKit
import CohesionCore
import CohesionUI
import SwiftUI
import WidgetKit

/// Every cohesiond activity in one Live Activity: the counts by status, a
/// row for each of the top activities and a bar of where everything stands;
/// in the island, the Cohesion mark beside a ring of the counts.
struct ActivitiesLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CohesionActivitiesAttributes.self) { context in
            Banner(state: context.state)
                .widgetURL(context.state.lead(at: .now)?.kind.link?.url)
        } dynamicIsland: { context in
            island(context.state)
                .widgetURL(context.state.lead(at: .now)?.kind.link?.url)
        }
    }

    private func island(_ state: CohesionActivitiesAttributes.ContentState) -> DynamicIsland {
        let shown = state.shown(at: .now)
        return DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                Mark(size: 20)
                    .padding(.leading, 8)
            }
            DynamicIslandExpandedRegion(.trailing) {
                Counts(state: state)
                    .padding(.trailing, 8)
                    .padding(.top, 4)
            }
            DynamicIslandExpandedRegion(.bottom) {
                VStack(spacing: 4) {
                    ForEach(shown.prefix(3)) { ActivityRow(summary: $0) }
                    SegmentBar(state: state)
                        .padding(.top, 6)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 8)
                .padding(.top, 2)
            }
        } compactLeading: {
            // Padded on every side, since in landscape the island stands
            // upright and the hardware is above or below rather than beside.
            Mark(size: 20)
                .padding(4)
        } compactTrailing: {
            StatusRing(state: state)
                .padding(4)
        } minimal: {
            StatusRing(state: state)
        }
    }
}

// MARK: - Lock Screen

/// The mark and the counts, how many more there are than rows, a row for
/// each of the top three activities, and the bar.
private struct Banner: View {
    let state: CohesionActivitiesAttributes.ContentState

    var body: some View {
        let now = Date.now
        let shown = state.shown(at: now).prefix(3)
        let more = state.moreCount(beyond: shown.count, at: now)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Mark(size: 18)
                Counts(state: state)
                Spacer(minLength: 0)
                if more > 0 {
                    Text("+\(more) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(shown) { ActivityRow(summary: $0) }
            SegmentBar(state: state)
        }
        .padding(14)
    }
}

// MARK: - Pieces

/// A row for one activity: its symbol, title, and its status or how long
/// it has run; dimmed once it succeeded or was cancelled.
private struct ActivityRow: View {
    let summary: CohesionActivitiesAttributes.Summary

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: summary.status.symbol)
                .foregroundStyle(summary.status.tint)
                .font(.caption)
                .frame(width: 16)
            Text(summary.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 4)
            if summary.status == .running || summary.status == .waiting {
                Elapsed(since: summary.startDate)
                    .font(.caption2)
            } else {
                Text(summary.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(summary.isFinished ? .secondary : summary.status.tint)
                    .lineLimit(1)
            }
        }
        .opacity(summary.isFinished ? 0.5 : 1)
    }
}

/// Each nonzero count beside its symbol, the most pressing first.
private struct Counts: View {
    let state: CohesionActivitiesAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            ForEach(state.counts, id: \.status) { count in
                HStack(spacing: 2) {
                    Image(systemName: count.status.symbol)
                        .imageScale(.small)
                    Text(count.count, format: .number)
                        .monospacedDigit()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(count.status.tint)
            }
        }
        .fixedSize()
    }
}

/// A thin bar split by the share of activities in each state, so it greys
/// as they finish.
private struct SegmentBar: View {
    let state: CohesionActivitiesAttributes.ContentState

    var body: some View {
        GeometryReader { geometry in
            let total = max(state.totalCount, 1)
            let gaps = CGFloat(max(state.counts.count - 1, 0)) * 2
            HStack(spacing: 2) {
                ForEach(state.counts.reversed(), id: \.status) { count in
                    Capsule()
                        .fill(count.status.tint)
                        .frame(width: (geometry.size.width - gaps) * CGFloat(count.count) / CGFloat(total))
                }
            }
        }
        .frame(height: 4)
        .background(.quaternary, in: .capsule)
    }
}

/// An arc for each status in its tint, its length its share of the counts,
/// clockwise from the top in the counts' order, around how many need the
/// user, in amber, while any do (what the island leads with); else how many
/// are running; else a check once everything is done. One status is a whole
/// ring.
private struct StatusRing: View {
    let state: CohesionActivitiesAttributes.ContentState
    var diameter: CGFloat = 20
    var lineWidth: CGFloat = 3

    /// The gap between arcs, as a share of the ring.
    private static let gap = 0.05
    /// The least of the ring an arc takes, so one of many still shows.
    private static let minimumShare = 0.1

    private struct Arc {
        let status: ActivityStatus
        let from: Double
        let to: Double
    }

    private var arcs: [Arc] {
        let counts = state.counts
        guard counts.count > 1 else {
            return counts.map { Arc(status: $0.status, from: 0, to: 1) }
        }
        let total = Double(counts.reduce(0) { $0 + $1.count })
        let shares = counts.map { max(Double($0.count) / total, Self.minimumShare) }
        let scale = (1 - Double(counts.count) * Self.gap) / shares.reduce(0, +)
        var cursor = Self.gap / 2
        return zip(counts, shares).map { count, share in
            defer { cursor += share * scale + Self.gap }
            return Arc(status: count.status, from: cursor, to: cursor + share * scale)
        }
    }

    var body: some View {
        ZStack {
            if state.counts.isEmpty {
                Circle().strokeBorder(.quaternary, lineWidth: lineWidth)
            }
            ForEach(arcs, id: \.status) { arc in
                // Inset by half the stroke so it stays inside the frame.
                Circle()
                    .inset(by: lineWidth / 2)
                    .trim(from: arc.from, to: arc.to)
                    .stroke(arc.status.tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            center
        }
        .frame(width: diameter, height: diameter)
    }

    @ViewBuilder private var center: some View {
        let needs = state.needsAttentionCount
        let shown = needs > 0 ? needs : state.runningCount
        if shown > 0 {
            Text(shown, format: .number)
                .font(.system(size: diameter * 0.45, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(lineWidth)
                .foregroundStyle(needs > 0 ? AnyShapeStyle(.orange) : AnyShapeStyle(.primary))
        } else {
            Image(systemName: state.overall.ringSymbol)
                .font(.system(size: diameter * 0.4, weight: .bold))
                .foregroundStyle(state.overall.tint)
        }
    }
}

/// The Cohesion mark, in the brand's colors.
private struct Mark: View {
    let size: CGFloat

    var body: some View {
        Image("CohesionMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Cohesion")
    }
}

/// How long an activity has been going, at the width of an hours-long count,
/// since a timer claims all the width it is offered. Nothing without a start.
private struct Elapsed: View {
    let since: Date?

    var body: some View {
        if let since {
            Text(verbatim: "0:00:00")
                .hidden()
                .overlay(alignment: .trailing) {
                    Text(timerInterval: since...Date.distantFuture, countsDown: false)
                        .multilineTextAlignment(.trailing)
                }
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

// MARK: - Values

private extension CohesionActivitiesAttributes.ContentState {
    /// Each nonzero count with the status whose symbol and tint show it,
    /// the most pressing first.
    var counts: [(status: ActivityStatus, count: Int)] {
        [
            (.paused, needsAttentionCount),
            (.running, runningCount),
            (.failed, failedCount),
            (.succeeded, doneCount),
        ]
        .filter { $0.count > 0 }
    }

    /// The activities to show at `now`, in the cloud's order, sorted again
    /// in case a cloud sends them otherwise, without any that aged out.
    func shown(at now: Date) -> [CohesionActivitiesAttributes.Summary] {
        activities.filter { !$0.hasAgedOut(at: now) }
            .enumerated()
            .sorted { a, b in
                if a.element.rank != b.element.rank { return a.element.rank < b.element.rank }
                if a.element.sortsBefore(b.element) { return true }
                if b.element.sortsBefore(a.element) { return false }
                return a.offset < b.offset
            }
            .map(\.element)
    }

    /// The activity the Live Activity leads with, and that tapping opens.
    func lead(at now: Date) -> CohesionActivitiesAttributes.Summary? { shown(at: now).first }

    /// How many the counts cover beyond the `shown` rows, less those that
    /// aged out here.
    func moreCount(beyond shown: Int, at now: Date) -> Int {
        let agedOut = activities.count(where: { $0.hasAgedOut(at: now) })
        return max(0, totalCount - agedOut - shown)
    }
}

private extension CohesionActivitiesAttributes.Summary {
    /// Whether it succeeded or was cancelled, and so shows dimmed.
    var isFinished: Bool { status == .succeeded || status == .cancelled }

    /// Whether it ended more than five minutes before `now`, when the cloud
    /// drops it; hidden here too in case that push comes late.
    func hasAgedOut(at now: Date) -> Bool {
        guard status.hasEnded, let finishDate else { return false }
        return now.timeIntervalSince(finishDate) > 5 * 60
    }

    /// Where it sorts: needing the user, failed, going, then finished.
    var rank: Int {
        switch status {
        case .paused: 0
        case .failed: 1
        case .running, .waiting: 2
        case .succeeded, .cancelled: 3
        }
    }

    /// Whether it sorts before `other` in the same rank: the latest failed
    /// or finished, the latest started. Those needing the user keep the
    /// cloud's order, since only the cloud knows how long each has waited.
    func sortsBefore(_ other: Self) -> Bool {
        switch status {
        case .paused: false
        case .failed, .succeeded, .cancelled: (finishedAt ?? 0) > (other.finishedAt ?? 0)
        case .running, .waiting: (startedAt ?? 0) > (other.startedAt ?? 0)
        }
    }

    /// The daemon's word for the status, or this build's when the push has
    /// none.
    var label: String {
        if let statusLabel { return statusLabel }
        return switch status {
        case .running: "Running"
        case .waiting: "Waiting"
        case .paused: "Needs you"
        case .succeeded: "Done"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }
}

// MARK: - Previews

#Preview("Lock Screen", as: .content, using: CohesionActivitiesAttributes.preview) {
    ActivitiesLiveActivity()
} contentStates: {
    CohesionActivitiesAttributes.ContentState.oneRunning
    CohesionActivitiesAttributes.ContentState.severalRunning
    CohesionActivitiesAttributes.ContentState.oneNeedsYou
    CohesionActivitiesAttributes.ContentState.mixed
    CohesionActivitiesAttributes.ContentState.finishing
    CohesionActivitiesAttributes.ContentState.allDone
    CohesionActivitiesAttributes.ContentState.failed
    CohesionActivitiesAttributes.ContentState.longTitle
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: CohesionActivitiesAttributes.preview) {
    ActivitiesLiveActivity()
} contentStates: {
    CohesionActivitiesAttributes.ContentState.oneRunning
    CohesionActivitiesAttributes.ContentState.severalRunning
    CohesionActivitiesAttributes.ContentState.oneNeedsYou
    CohesionActivitiesAttributes.ContentState.mixed
    CohesionActivitiesAttributes.ContentState.finishing
    CohesionActivitiesAttributes.ContentState.allDone
    CohesionActivitiesAttributes.ContentState.failed
    CohesionActivitiesAttributes.ContentState.longTitle
}

#Preview("Compact", as: .dynamicIsland(.compact), using: CohesionActivitiesAttributes.preview) {
    ActivitiesLiveActivity()
} contentStates: {
    CohesionActivitiesAttributes.ContentState.oneRunning
    CohesionActivitiesAttributes.ContentState.severalRunning
    CohesionActivitiesAttributes.ContentState.oneNeedsYou
    CohesionActivitiesAttributes.ContentState.mixed
    CohesionActivitiesAttributes.ContentState.finishing
    CohesionActivitiesAttributes.ContentState.allDone
    CohesionActivitiesAttributes.ContentState.failed
    CohesionActivitiesAttributes.ContentState.longTitle
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: CohesionActivitiesAttributes.preview) {
    ActivitiesLiveActivity()
} contentStates: {
    CohesionActivitiesAttributes.ContentState.oneRunning
    CohesionActivitiesAttributes.ContentState.severalRunning
    CohesionActivitiesAttributes.ContentState.oneNeedsYou
    CohesionActivitiesAttributes.ContentState.mixed
    CohesionActivitiesAttributes.ContentState.finishing
    CohesionActivitiesAttributes.ContentState.allDone
    CohesionActivitiesAttributes.ContentState.failed
    CohesionActivitiesAttributes.ContentState.longTitle
}

// Light and dark: the canvas's Variants menu, Color Scheme Variants.

private extension CohesionActivitiesAttributes {
    static let preview = CohesionActivitiesAttributes(registrationCode: "preview")
}

private extension CohesionActivitiesAttributes.ContentState {
    typealias Summary = CohesionActivitiesAttributes.Summary

    static func ago(_ seconds: Int) -> Int { Int(Date.now.timeIntervalSince1970) - seconds }

    static let research = Summary(
        id: "9", title: "Q3 research", kind: .actorSession(sessionID: 7), status: .running,
        statusLabel: "Running", progress: "Read 12 of 40 sources", startedAt: ago(39)
    )
    static let digest = Summary(
        id: "10", title: "Inbox digest", kind: .actorSession(sessionID: 3), status: .running,
        statusLabel: "Running", startedAt: ago(312)
    )
    static let changelog = Summary(
        id: "11", title: "Draft the changelog", kind: .actorSession(sessionID: 2), status: .waiting,
        statusLabel: "Waiting", startedAt: ago(1_260)
    )
    static let question = Summary(
        id: "12", title: "Budget review", kind: .actorSession(sessionID: 4), status: .paused,
        statusLabel: "Needs you", progress: "Which quarter should I compare?", startedAt: ago(840)
    )
    static let finished = Summary(
        id: "13", title: "Summarise standup", kind: .actorSession(sessionID: 5), status: .succeeded,
        statusLabel: "Done", startedAt: ago(2_400), finishedAt: ago(60)
    )
    static let broken = Summary(
        id: "14", title: "Sync calendar", kind: .actorSession(sessionID: 6), status: .failed,
        statusLabel: "Failed", progress: "The calendar server refused the login",
        startedAt: ago(1_800), finishedAt: ago(120)
    )
    /// Finished seven minutes ago, so hidden though the cloud still lists it.
    static let agedOut = Summary(
        id: "18", title: "Tidy the inbox", kind: .actorSession(sessionID: 8), status: .succeeded,
        statusLabel: "Done", startedAt: ago(900), finishedAt: ago(420)
    )

    static let oneRunning = Self(runningCount: 1, activities: [research])
    static let severalRunning = Self(runningCount: 3, activities: [research, digest, changelog])
    static let oneNeedsYou = Self(needsAttentionCount: 1, activities: [question])
    static let mixed = Self(
        runningCount: 2, needsAttentionCount: 1, doneCount: 3,
        activities: [question, research, digest, finished]
    )
    /// Listed out of order, as a cloud might, with one that aged out.
    static let finishing = Self(
        runningCount: 1, doneCount: 3,
        activities: [agedOut, finished, research, finished.with(id: "19", title: "Inbox digest")]
    )
    static let allDone = Self(doneCount: 4, activities: [finished, finished.with(id: "15", title: "Q3 research")])
    static let failed = Self(doneCount: 1, failedCount: 1, activities: [broken, finished])
    static let longTitle = Self(
        runningCount: 1, needsAttentionCount: 1,
        activities: [
            question.with(id: "16", title: "Compare every vendor contract renewing before the end of the fiscal year"),
            research.with(id: "17", title: "Research the history of distributed consensus protocols since Paxos"),
        ]
    )
}

private extension CohesionActivitiesAttributes.Summary {
    func with(id: String, title: String) -> Self {
        var copy = self
        copy.activityID = id
        copy.title = title
        return copy
    }
}
