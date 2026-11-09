import CohesionCore
import CohesionUI
import SwiftUI
import WidgetKit

/// The agents that need the user: those the agents list marks unread, in
/// its order. Tapping one opens its chat.
struct AgentsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Agents", provider: AgentsProvider()) { entry in
            AgentsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Agents")
        .description("The agents that need you.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// The agents as one listing found them.
nonisolated struct AgentsEntry: TimelineEntry {
    let date: Date
    let state: State

    enum State {
        /// The agents that need the user; empty when none do.
        case agents([Agent])
        case unpaired
        /// The listing failed, as it does away from the server's network.
        case unreachable
    }
}

/// Lists the agents with the app's pairing. The app and agent pushes reload
/// it; otherwise WidgetKit's budget decides when it next looks.
nonisolated struct AgentsProvider: TimelineProvider {
    func placeholder(in context: Context) -> AgentsEntry {
        AgentsEntry(date: .now, state: .agents([]))
    }

    func getSnapshot(in context: Context, completion: @escaping (AgentsEntry) -> Void) {
        Task { completion(await Self.entry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AgentsEntry>) -> Void) {
        Task {
            let entry = await Self.entry()
            completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(15 * 60))))
        }
    }

    @MainActor
    private static func entry() async -> AgentsEntry {
        let client: CohesionClient?
        switch Pairing.read() {
        case .paired(let pairing): client = try? CohesionClient(pairing: pairing)
        case .unpaired: client = nil
        // Not a reason to ask for pairing: the next look can read it.
        case .unavailable: return AgentsEntry(date: .now, state: .unreachable)
        }
        guard let client else { return AgentsEntry(date: .now, state: .unpaired) }
        do {
            let agents = try await client.listAgents()
            return AgentsEntry(date: .now, state: .agents(agents.filter(\.isUnread)))
        } catch {
            return AgentsEntry(date: .now, state: .unreachable)
        }
    }
}

struct AgentsWidgetView: View {
    let entry: AgentsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch entry.state {
        case .agents(let agents) where family == .systemSmall:
            SmallAgents(agents: agents)
        case .agents(let agents) where agents.isEmpty:
            WidgetMessage(text: "All caught up.", systemImage: "checkmark.circle")
        case .agents(let agents):
            AgentsSpread(agents: agents, isLarge: family == .systemLarge)
        case .unpaired:
            WidgetMessage(text: "Open Cohesion to pair.", systemImage: "link")
        case .unreachable:
            WidgetMessage(text: "Can’t reach Cohesion.", systemImage: "wifi.exclamationmark")
        }
    }
}

/// The count and the first agents' avatars, or a check when none need the
/// user; tapping opens the chat when one agent needs the user, else the app.
private struct SmallAgents: View {
    let agents: [Agent]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Three overlapping slots span the width, so three avatars fill
            // it and fewer keep the same size.
            HStack(spacing: -8) {
                ForEach(0..<3, id: \.self) { slot in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if agents.isEmpty && slot == 0 {
                                CaughtUpMark()
                            } else if slot < agents.count {
                                let agent = agents[slot]
                                GeometryReader { proxy in
                                    AgentAvatar(
                                        name: agent.name,
                                        emoji: agent.emoji,
                                        color: agent.color,
                                        diameter: proxy.size.width
                                    )
                                }
                            }
                        }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if agents.isEmpty {
                Text("All caught up.")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text(agents.count, format: .number)
                    .font(.largeTitle.weight(.semibold))
                // Read on from the count: "3 need you", as the larger sizes say it.
                Text(agents.count == 1 ? agents[0].name : "need you")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(agents.count == 1 ? AppLink.agent(agents[0].id).url : nil)
    }
}

/// A dashed circle around a check, in an avatar's place when no agent needs
/// the user.
private struct CaughtUpMark: View {
    var body: some View {
        GeometryReader { proxy in
            Image(systemName: "checkmark")
                .font(.system(size: proxy.size.width * 0.4, weight: .semibold))
                .frame(width: proxy.size.width, height: proxy.size.height)
                .overlay {
                    Circle().strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                }
                .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }
}

/// The small widget's look, given room: the agents' avatars overlapping,
/// each a link to its chat and larger than the small's, then how many need
/// the user beside who they are. A large widget adds a row per agent under
/// them, saying what each is doing.
private struct AgentsSpread: View {
    let agents: [Agent]
    let isLarge: Bool

    /// The most avatars drawn; past it, a disc says how many more.
    private var slots: Int { isLarge ? 5 : 4 }
    private var diameter: CGFloat { isLarge ? 96 : 56 }

    var body: some View {
        VStack(alignment: .leading, spacing: isLarge ? 14 : 4) {
            avatars
            if !isLarge { Spacer(minLength: 0) }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(agents.count, format: .number)
                    .font(.largeTitle.weight(.semibold))
                Text(sentence)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .accessibilityElement(children: .combine)
            if isLarge {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(agents.prefix(3)) { agent in
                        Link(destination: AppLink.agent(agent.id).url) {
                            AgentRow(agent: agent, diameter: 32)
                        }
                    }
                    if agents.count > 3 {
                        Text("\(agents.count - 3) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var avatars: some View {
        let shown = agents.count > slots ? slots - 1 : agents.count
        return HStack(spacing: -diameter * 0.2) {
            ForEach(agents.prefix(shown)) { agent in
                Link(destination: AppLink.agent(agent.id).url) {
                    AgentAvatar(name: agent.name, emoji: agent.emoji, color: agent.color, diameter: diameter)
                }
                .accessibilityLabel(agent.name)
            }
            if agents.count > shown {
                Text("+\(agents.count - shown)")
                    .font(.system(size: diameter * 0.32, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: diameter, height: diameter)
                    .background(.fill.secondary, in: .circle)
            }
        }
    }

    /// Who needs the user, by name: "Ada, Milo and Juno need you."
    private var sentence: String {
        let names = agents.map(\.name).formatted(.list(type: .and))
        return agents.count == 1 ? "\(names) needs you." : "\(names) need you."
    }
}

/// The agent's avatar beside its name and what it is doing, or that it
/// needs the user when it isn't working.
private struct AgentRow: View {
    let agent: Agent
    var diameter: CGFloat = 32

    var body: some View {
        HStack(spacing: 10) {
            AgentAvatar(name: agent.name, emoji: agent.emoji, color: agent.color, diameter: diameter)
            VStack(alignment: .leading, spacing: 0) {
                Text(agent.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(agent.activity ?? "Needs you")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

/// A symbol over a line of text, in place of a widget's content.
struct WidgetMessage: View {
    let text: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Small", as: .systemSmall) {
    AgentsWidget()
} timeline: {
    AgentsEntry.threeAgents
    AgentsEntry.oneAgent
    AgentsEntry.caughtUp
    AgentsEntry.unpaired
    AgentsEntry.unreachable
}

#Preview("Medium", as: .systemMedium) {
    AgentsWidget()
} timeline: {
    AgentsEntry.threeAgents
    AgentsEntry.oneAgent
    AgentsEntry.caughtUp
    AgentsEntry.unpaired
    AgentsEntry.unreachable
}

#Preview("Large", as: .systemLarge) {
    AgentsWidget()
} timeline: {
    AgentsEntry.threeAgents
    AgentsEntry.oneAgent
    AgentsEntry.caughtUp
    AgentsEntry.unpaired
    AgentsEntry.unreachable
}

private extension AgentsEntry {
    static let caughtUp = AgentsEntry(date: .now, state: .agents([]))
    static let oneAgent = AgentsEntry(date: .now, state: .agents(Array(Agent.previews.prefix(1))))
    static let threeAgents = AgentsEntry(date: .now, state: .agents(Agent.previews))
    static let unpaired = AgentsEntry(date: .now, state: .unpaired)
    static let unreachable = AgentsEntry(date: .now, state: .unreachable)
}

private extension Agent {
    static let previews = try! JSONDecoder().decode([Self].self, from: Data(#"""
        [{"id":1,"agent_name":"Ada","agent_color":"purple","agent_emoji":"🔭","agent_personality":"balanced",
          "agent_verbosity":"brief","agent_role":"Research","activity":"Reading 12 of 40 sources",
          "agent_unread":true,"pinned":true},
         {"id":2,"agent_name":"Milo","agent_color":"teal","agent_emoji":null,"agent_personality":"friendly",
          "agent_verbosity":"terse","agent_role":"Inbox","activity":null,"agent_unread":true,"pinned":false},
         {"id":3,"agent_name":"Juno","agent_color":"orange","agent_emoji":"📅","agent_personality":"professional",
          "agent_verbosity":"detailed","agent_role":"Calendar","activity":null,"agent_unread":true,"pinned":false}]
        """#.utf8))
}
