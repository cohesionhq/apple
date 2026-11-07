import CohesionCore
import CohesionUI
import SwiftUI

/// The Dashboard's recap, one section that's gone when there's nothing in it:
/// the sessions that need the user, those finished or failed and still unread,
/// every session working as chips, then the agents with unread messages, newest
/// first. Each opens its session or chat.
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
        let needsYou = needsYou
        let finishedUnread = finishedUnread
        let working = working
        let unreadAgents = unreadAgents
        if !(needsYou.isEmpty && finishedUnread.isEmpty && working.isEmpty && unreadAgents.isEmpty) {
            Section {
                ForEach(needsYou + finishedUnread) { session in
                    LinkRow { openActorSession(session.id) } label: {
                        ActorSidebarRow(session: session, isAttentionAmber: true)
                    }
                }
                if !working.isEmpty {
                    WorkingChips(sessions: working, open: openActorSession)
                }
                ForEach(unreadAgents) { agent in
                    LinkRow { openAgent(agent.id) } label: {
                        UnreadAgentLabel(agent: agent)
                    }
                }
            } header: {
                Text("What’s New")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .textCase(nil)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }
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

/// Every session working at once, as chips that wrap onto as many lines as
/// they need. Each has a button style of its own, or a tap in the row would
/// press them all.
private struct WorkingChips: View {
    let sessions: [ActorSession]
    let open: (Int) -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(sessions) { session in
                Button {
                    open(session.id)
                } label: {
                    HStack(spacing: 4) {
                        ActorSessionStatusIcon(status: session.status)
                        Text(session.title)
                            .lineLimit(1)
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(.primary)
                .accessibilityLabel(rowLabel(session, status: model.vocabulary.label(of: session.status)))
            }
        }
        .padding(.vertical, 4)
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
        // Under a minute is "now", as is a time just ahead on a clock that's
        // off; the format would say "in 0s".
        guard Date.now.timeIntervalSince(lastMessageAt) >= 60 else { return "New message · now" }
        return "New message · \(lastMessageAt.formatted(.relative(presentation: .numeric, unitsStyle: .narrow)))"
    }
}
