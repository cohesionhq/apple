import CohesionCore
import CohesionUI
import SwiftUI

/// The Dashboard's recap, in the order to deal with it, as the web's: the
/// sessions that need the user, those finished or failed and still unread,
/// then the agents with unread messages, newest first; then the sessions still
/// working, in a section of their own. Each row opens its session or chat, and
/// a section with nothing in it is gone.
struct WhatsNewSection: View {
    let agents: [Agent]
    /// Every actor's sessions not yet resolved, latest status change first.
    let sessions: [ActorSession]
    let openAgent: (Int) -> Void
    let openActorSession: (Int) -> Void

    private var needsYou: [ActorSession] {
        sessions.filter { $0.status == .needsAttention }
    }

    private var finishedUnread: [ActorSession] {
        sessions.filter { $0.isUnread && ($0.status == .idle || $0.status == .failed) }
    }

    private var working: [ActorSession] {
        sessions.filter { $0.status == .working }
    }

    private var unreadAgents: [Agent] {
        agents.filter(\.isUnread).sorted {
            ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast)
        }
    }

    var body: some View {
        let recap = needsYou + finishedUnread
        let unreadAgents = unreadAgents
        let working = working
        if !(recap.isEmpty && unreadAgents.isEmpty) {
            Section {
                ForEach(recap) { session in
                    LinkRow { openActorSession(session.id) } label: {
                        RecapSessionLabel(session: session)
                    }
                }
                ForEach(unreadAgents) { agent in
                    LinkRow { openAgent(agent.id) } label: {
                        UnreadAgentLabel(agent: agent)
                    }
                }
            } header: {
                DashboardSectionHeader(title: "What’s New", count: recap.count + unreadAgents.count)
            }
        }
        if !working.isEmpty {
            Section {
                ForEach(working) { session in
                    LinkRow { openActorSession(session.id) } label: {
                        RecapSessionLabel(session: session)
                    }
                }
            } header: {
                DashboardSectionHeader(title: "Working", count: working.count)
            }
        }
    }
}

/// A Dashboard section's heading: its title and, after it, how many rows it
/// has, as the web's sections carry their count.
private struct DashboardSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .foregroundStyle(.primary)
            Text(count, format: .number)
                .foregroundStyle(.secondary)
        }
        .font(.title3.weight(.semibold))
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A session in the recap: its status's icon where a row's symbol goes, so
/// its title starts where an agent's name does, over its status and how long
/// ago it changed; amber while it needs the user, its title shimmering while
/// it works.
private struct RecapSessionLabel: View {
    let session: ActorSession

    @Environment(AppModel.self) private var model
    /// An agent avatar's slot beside it.
    @ScaledMetric(relativeTo: .body) private var slot = 28

    var body: some View {
        let status = model.vocabulary.label(of: session.status)
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .lineLimit(2)
                    .workingShimmer(session.status == .working, dimmed: 0.35)
                TimelineView(.everyMinute) { _ in
                    Text("\(status) · \(ago(session.statusChangedAt))")
                        .font(.subheadline)
                        .foregroundStyle(session.status.wordsStyle)
                        .lineLimit(1)
                }
            }
        } icon: {
            ActorSessionStatusIcon(status: session.status)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: slot, height: slot)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowLabel(session, status: status))
    }
}

/// How long ago `date` was, "now" under a minute or for a time just ahead on
/// a clock that's off, where the format would say "in 0s".
private func ago(_ date: Date) -> String {
    guard Date.now.timeIntervalSince(date) >= 60 else { return "now" }
    return date.formatted(.relative(presentation: .numeric, unitsStyle: .narrow))
}

/// A row that's one link, opening full-page content: all of it taps, with the
/// chevron a pushing row has.
private struct LinkRow<Label: View>: View {
    let open: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: open) {
            HStack {
                label()
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        // A list's own button on iOS, which highlights the row; the Mac would
        // draw it as a push button.
        #if os(macOS)
        .buttonStyle(.plain)
        #else
        .tint(.primary)
        #endif
        .padding(.vertical, 2)
    }
}

/// An agent with unread messages: its avatar where a row's symbol goes, its
/// name, and how long ago the latest came.
private struct UnreadAgentLabel: View {
    let agent: Agent

    /// About a sidebar symbol's size, growing with the name beside it.
    @ScaledMetric(relativeTo: .body) private var diameter = 28

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .lineLimit(1)
                // Keeps its "5m ago" true on a page left open.
                TimelineView(.everyMinute) { _ in
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } icon: {
            AgentAvatar(agent: agent, diameter: diameter, fit: .symbol)
        }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        guard let lastMessageAt = agent.lastMessageAt else { return "New message" }
        return "New message · \(ago(lastMessageAt))"
    }
}
