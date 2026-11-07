import CohesionCore
import CohesionUI
import SwiftUI

/// How much of its limits a session has used, as its actor last said: a ring
/// in the accent that fills as the session's context window does (orange past
/// 80%, red past 95%), which opens a sheet of the tokens and, under them,
/// the account its actor draws on and each of its plan limits and when it
/// resets. Plan limits without a context window open from a plain gauge
/// instead.
struct ActorUsageButton: View {
    let context: ContextUsage?
    /// The actor's plan limits, in the order to show them.
    let plan: [PlanUsage]
    /// The account whose plan it is, shared with the actors on it; `nil`
    /// for an actor's own limits.
    var account: String?
    /// Whether it floats on its own glass, as beside an actor session's Follow
    /// up, rather than taking a toolbar's.
    var isFloating = false

    @State private var isShowing = false
    /// The ring, as big as a symbol beside it at the reader's text size.
    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 18

    var body: some View {
        Button {
            isShowing = true
        } label: {
            Group {
                if let context {
                    ZStack {
                        Circle()
                            .stroke(.tint.opacity(0.25), lineWidth: 2.5)
                        Circle()
                            .trim(from: 0, to: context.share)
                            .stroke(ActorUsageTone.tint(of: context.share).map(AnyShapeStyle.init) ?? AnyShapeStyle(.tint), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: ringSize, height: ringSize)
                } else {
                    Image(systemName: "gauge.with.dots.needle.33percent")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: isFloating ? 22 : nil, height: isFloating ? 22 : nil)
            .padding(isFloating ? 11 : 0)
            .contentShape(.circle)
        }
        .buttonBorderShape(.circle)
        .floatingGlass(isFloating)
        .accessibilityLabel(context.map { "Context \(percent($0.share)) full" } ?? "Plan usage")
        .sizedSheet(isPresented: $isShowing) {
            ScrollView { details }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let context {
                UsageLimitRow(
                    label: "Context",
                    used: context.share,
                    note: "\(tokenCount(context.usedTokens)) of \(tokenCount(context.totalTokens)) tokens"
                )
            }
            if let account, !plan.isEmpty {
                Text(account)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, context == nil ? 0 : 8)
            }
            ForEach(Array(plan.enumerated()), id: \.offset) { _, limit in
                UsageLimitRow(limit)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom)
    }
}

/// A limit's name and share used over a bar, orange past 80% and red past
/// 95%, and a note under it, such as when it resets.
struct UsageLimitRow: View {
    let label: String
    /// From 0 to 1.
    let used: Double
    let note: String?

    init(label: String, used: Double, note: String?) {
        self.label = label
        self.used = used
        self.note = note
    }

    /// A plan limit, with when it resets.
    init(_ limit: PlanUsage, label: String? = nil) {
        self.init(label: label ?? limit.label, used: limit.used, note: limit.resetsAt.map(Self.resets))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                Text(percent(used))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(max(used, 0), 1))
                .tint(ActorUsageTone.tint(of: used) ?? .accentColor)
            if let note {
                Text(note)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// "Resets at 15:10" within a day, else "Resets Mon 15:10".
    nonisolated private static func resets(_ date: Date) -> String {
        if date.timeIntervalSinceNow < 86_400 {
            return "Resets at \(date.formatted(date: .omitted, time: .shortened))"
        }
        return "Resets \(date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))"
    }
}

private extension View {
    /// Its own interactive glass circle, as the foot's Stop has, when `isFloating`.
    @ViewBuilder
    func floatingGlass(_ isFloating: Bool) -> some View {
        if isFloating {
            buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .contentShape(.hoverEffect, .circle)
                .hoverEffect(.highlight)
        } else {
            self
        }
    }
}

private func percent(_ share: Double) -> String {
    share.formatted(.percent.precision(.fractionLength(0)))
}
