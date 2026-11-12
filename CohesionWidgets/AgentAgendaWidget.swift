import AppIntents
import CohesionCore
import CohesionUI
import SwiftUI
import WidgetKit

/// The agenda of an agent picked in the widget's settings, as the web's
/// column beside the conversation draws it: a dot a step, finished ones in
/// green, the one the agent is on in the accent, the rest in grey, and that
/// step's text. On the Lock Screen, the agent's name over the step it's on.
/// Tapping it opens the agent's chat.
struct AgentAgendaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AgentAgenda", intent: AgentAgendaConfiguration.self, provider: AgentAgendaProvider()) { entry in
            AgentAgendaWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Agenda")
        .description("The agenda of an agent you pick.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
        .promptsForUserConfiguration()
    }
}

/// Which agent an Agenda widget shows, set in its Edit Widget sheet.
struct AgentAgendaConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Agenda"
    static let description = IntentDescription("Pick the agent whose agenda this widget shows.")

    @Parameter(title: "Agent") var agent: AgentEntity?
}

/// The agenda as one listing found it.
nonisolated struct AgentAgendaEntry: TimelineEntry {
    let date: Date
    let state: State

    enum State {
        /// The agent and its agenda, in order, finished items included.
        case agenda(Agent, [AgentAgendaItem])
        /// A made-up agent one step into its agenda, for the gallery and the
        /// placeholder, drawn on the main actor where its models decode.
        case sample
        /// No agent is picked yet.
        case noAgent
        /// The agent picked isn't there any more.
        case agentGone
        case unpaired
        /// The keychain can't be read yet, which says nothing of the pairing.
        case restoring
        /// The listing failed, as it does away from the server's network.
        case unreachable
    }
}

/// Where an agenda stands, which is what its widget leads with.
enum AgendaProgress: Equatable {
    /// It has no items.
    case clear
    /// Every item is finished.
    case done
    /// The agent is on this step, the first not yet finished.
    case on(AgentAgendaItem)

    init(_ items: [AgentAgendaItem]) {
        if let current = AgentAgendaItem.current(in: items) {
            self = .on(current)
        } else {
            self = items.isEmpty ? .clear : .done
        }
    }

    /// The step's text, or that there's none to do.
    var line: String {
        switch self {
        case .clear: "All clear"
        case .done: "All done"
        case .on(let item): item.text
        }
    }
}

/// Lists the agent and its agenda with the app's pairing. The app reloads it
/// when the agents change, as an agenda's change does, and agent pushes
/// reload it; otherwise WidgetKit's budget decides when it next looks.
nonisolated struct AgentAgendaProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> AgentAgendaEntry {
        AgentAgendaEntry(date: .now, state: .sample)
    }

    func snapshot(for configuration: AgentAgendaConfiguration, in context: Context) async -> AgentAgendaEntry {
        // The gallery shows what the widget looks like before an agent is picked.
        if context.isPreview && configuration.agent == nil {
            return placeholder(in: context)
        }
        return await Self.entry(for: configuration)
    }

    func timeline(for configuration: AgentAgendaConfiguration, in context: Context) async -> Timeline<AgentAgendaEntry> {
        let entry = await Self.entry(for: configuration)
        return Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(15 * 60)))
    }

    @MainActor
    private static func entry(for configuration: AgentAgendaConfiguration) async -> AgentAgendaEntry {
        guard let agentID = configuration.agent?.id else { return AgentAgendaEntry(date: .now, state: .noAgent) }
        let client: CohesionClient?
        switch Pairing.read() {
        case .paired(let pairing): client = try? CohesionClient(pairing: pairing)
        case .unpaired: client = nil
        // Not a reason to ask for pairing: the next look can read it.
        case .unavailable: return AgentAgendaEntry(date: .now, state: .restoring)
        }
        guard let client else { return AgentAgendaEntry(date: .now, state: .unpaired) }
        do {
            guard let agent = try await client.listAgents().first(where: { $0.id == agentID }) else {
                return AgentAgendaEntry(date: .now, state: .agentGone)
            }
            let items = try await client.listAgenda(of: agentID)
            return AgentAgendaEntry(date: .now, state: .agenda(agent, items))
        } catch {
            return AgentAgendaEntry(date: .now, state: .unreachable)
        }
    }
}

struct AgentAgendaWidgetView: View {
    let entry: AgentAgendaEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch entry.state {
        case .agenda(let agent, let items):
            agenda(agent, items)
                .widgetURL(AppLink.agent(agent.id).url)
        case .sample:
            agenda(.placeholder, AgentAgendaItem.samples)
        case .noAgent:
            message("Edit the widget to pick an agent.", systemImage: "person.crop.circle.badge.questionmark")
        case .agentGone:
            message("This agent is gone. Edit the widget to pick another.", systemImage: "person.crop.circle.badge.questionmark")
        case .unpaired:
            message("Open Cohesion to pair.", systemImage: "link")
        case .restoring:
            message("Restoring your pairing…", systemImage: "lock")
        case .unreachable:
            message("Can’t reach Cohesion.", systemImage: "wifi.exclamationmark")
        }
    }

    @ViewBuilder
    private func agenda(_ agent: Agent, _ items: [AgentAgendaItem]) -> some View {
        switch family {
        case .accessoryRectangular: LockScreenAgenda(agent: agent, items: items)
        case .systemSmall: SmallAgenda(agent: agent, items: items)
        default: AgendaList(agent: agent, items: items)
        }
    }

    /// `WidgetMessage`, or on the Lock Screen, where it wouldn't fit, the
    /// text beside its symbol.
    @ViewBuilder
    private func message(_ text: LocalizedStringKey, systemImage: String) -> some View {
        if family == .accessoryRectangular {
            Label(text, systemImage: systemImage)
                .font(.caption)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            WidgetMessage(text: text, systemImage: systemImage)
        }
    }
}

/// The agent's name, then the step it's on, or that there's none.
private struct LockScreenAgenda: View {
    let agent: Agent
    let items: [AgentAgendaItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(agent.name)
                .font(.headline)
                .widgetAccentable()
                .lineLimit(1)
            Text(AgendaProgress(items).line)
                .font(.subheadline)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The agent, then the dots, the step it's on and how many are done.
private struct SmallAgenda: View {
    let agent: Agent
    let items: [AgentAgendaItem]

    var body: some View {
        let progress = AgendaProgress(items)
        VStack(alignment: .leading, spacing: 6) {
            AgendaAgentHeader(agent: agent, items: items, showsSummary: false)
            Spacer(minLength: 0)
            if !items.isEmpty {
                AgendaDots(items: items)
            }
            Text(progress.line)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(progress == .clear ? .secondary : .primary)
                .lineLimit(3)
            if !items.isEmpty {
                AgendaSummary(items: items)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// The agent and how many steps are done, then a row a step as many as fit
/// around the one the agent is on, as the web's card lists them.
private struct AgendaList: View {
    let agent: Agent
    let items: [AgentAgendaItem]

    @Environment(\.widgetFamily) private var family

    var body: some View {
        let progress = AgendaProgress(items)
        VStack(alignment: .leading, spacing: 8) {
            AgendaAgentHeader(agent: agent, items: items, showsSummary: !items.isEmpty)
            if items.isEmpty {
                WidgetMessage(text: "All clear", systemImage: AgentAgendaItem.agendaSymbol)
            } else {
                AgendaDots(items: items)
                ViewThatFits(in: .vertical) {
                    ForEach(Array((1...items.count).reversed()), id: \.self) { shown in
                        rows(shown: shown, progress: progress)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// `shown` steps in a row from the one before the step the agent is on,
    /// so it has what came before it, or the last ones once all are done;
    /// then how many more are left, or that they're all done.
    private func rows(shown: Int, progress: AgendaProgress) -> some View {
        let currentIndex = items.firstIndex { !$0.isFinished } ?? items.count
        let start = max(0, min(currentIndex - 1, items.count - shown))
        let visible = items[start..<(start + shown)]
        let after = items.count - (start + shown)
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(visible) { item in
                AgendaRow(item: item, isCurrent: progress == .on(item))
            }
            if after > 0 {
                Text("\(after) more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if progress == .done {
                Text(progress.line)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The agent's avatar and name, and how many steps are done when shown.
private struct AgendaAgentHeader: View {
    let agent: Agent
    let items: [AgentAgendaItem]
    let showsSummary: Bool

    var body: some View {
        HStack(spacing: 6) {
            AgentAvatar(name: agent.name, emoji: agent.emoji, color: agent.color, diameter: 22)
                .accessibilityHidden(true)
            Text(agent.name)
                .fontWeight(.semibold)
                .lineLimit(1)
            Spacer(minLength: 0)
            if showsSummary {
                AgendaSummary(items: items)
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

/// "2 of 5 done", as the web's agenda heads itself.
private struct AgendaSummary: View {
    let items: [AgentAgendaItem]

    var body: some View {
        Text("\(items.count(where: \.isFinished)) of \(items.count) done")
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

/// A dot a step: the finished ones stacked in green, the one the agent is on
/// larger in the accent, set apart from those either side of it, and the rest
/// stacked in grey.
private struct AgendaDots: View {
    let items: [AgentAgendaItem]

    private let size: CGFloat = 10
    private let currentSize: CGFloat = 12

    var body: some View {
        let finished = items.filter(\.isFinished)
        let open = items.filter { !$0.isFinished }
        let dots = finished + open
        HStack(spacing: 0) {
            ForEach(Array(dots.enumerated()), id: \.element.id) { index, item in
                // A gap before the step the agent is on and the one after it;
                // every other dot tucks under the one before.
                let joined = !item.isFinished && index > 0 && index - finished.count <= 1
                let isCurrent = index == finished.count && !item.isFinished
                Circle()
                    .fill(item.isFinished ? AgentAgendaItem.finishedTint : isCurrent ? Color.brand : Color.secondary.opacity(0.5))
                    .frame(width: isCurrent ? currentSize : size, height: isCurrent ? currentSize : size)
                    .background(Circle().fill(.background).padding(-2))
                    .widgetAccentable(isCurrent)
                    .padding(.leading, index == 0 ? 0 : joined ? 6 : -3)
            }
        }
        .frame(height: currentSize + 4)
        .accessibilityHidden(true)
    }
}

/// One step: its dot, then its text, finished ones struck through.
private struct AgendaRow: View {
    let item: AgentAgendaItem
    let isCurrent: Bool

    var body: some View {
        Label {
            Text(item.text)
                .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                .strikethrough(item.isFinished)
                .foregroundStyle(isCurrent ? .primary : .secondary)
                .lineLimit(1)
        } icon: {
            Group {
                if item.isFinished {
                    Image(systemName: AgentAgendaItem.finishedSymbol)
                        .foregroundStyle(AgentAgendaItem.finishedTint)
                } else if isCurrent {
                    Image(systemName: AgentAgendaItem.currentSymbol)
                        .foregroundStyle(Color.brand)
                        .widgetAccentable()
                } else {
                    Image(systemName: AgentAgendaItem.openSymbol)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(item.isFinished ? "Done" : isCurrent ? "Next" : "To do")
    }
}

private extension Agent {
    /// The agent the gallery and the placeholder show.
    static let placeholder = try! JSONDecoder().decode(Self.self, from: Data(#"""
        {"id":0,"agent_name":"Ada","agent_color":"purple","agent_emoji":"🔭","agent_personality":"balanced",
         "agent_verbosity":"brief","agent_role":"Research","activity":null,"agent_unread":false,"pinned":false}
        """#.utf8))
}

private extension AgentAgendaItem {
    /// An agenda one step in, for the gallery, the placeholder and the previews.
    static let samples = decode(#"""
        [{"id":1,"position":1,"text":"Read the Mac app’s changelog","finished_at":1762800000},
         {"id":2,"position":2,"text":"Draft the launch post","finished_at":null},
         {"id":3,"position":3,"text":"Pick the screenshots","finished_at":null},
         {"id":4,"position":4,"text":"Send it to Daniel for review","finished_at":null},
         {"id":5,"position":5,"text":"Schedule the post","finished_at":null}]
        """#)

    static let finished = decode(#"""
        [{"id":1,"position":1,"text":"Read the Mac app’s changelog","finished_at":1762800000},
         {"id":2,"position":2,"text":"Draft the launch post","finished_at":1762800100},
         {"id":3,"position":3,"text":"Send it to Daniel for review","finished_at":1762800200}]
        """#)

    private static func decode(_ json: String) -> [Self] {
        try! JSONDecoder().decode([Self].self, from: Data(json.utf8))
    }
}

private extension AgentAgendaEntry {
    static let onAStep = AgentAgendaEntry(date: .now, state: .sample)
    static let done = AgentAgendaEntry(date: .now, state: .agenda(.placeholder, AgentAgendaItem.finished))
    static let clear = AgentAgendaEntry(date: .now, state: .agenda(.placeholder, []))
    static let noAgent = AgentAgendaEntry(date: .now, state: .noAgent)
    static let agentGone = AgentAgendaEntry(date: .now, state: .agentGone)
    static let unreachable = AgentAgendaEntry(date: .now, state: .unreachable)
}

#Preview("Small", as: .systemSmall) {
    AgentAgendaWidget()
} timeline: {
    AgentAgendaEntry.onAStep
    AgentAgendaEntry.done
    AgentAgendaEntry.clear
    AgentAgendaEntry.noAgent
}

#Preview("Medium", as: .systemMedium) {
    AgentAgendaWidget()
} timeline: {
    AgentAgendaEntry.onAStep
    AgentAgendaEntry.done
    AgentAgendaEntry.clear
    AgentAgendaEntry.agentGone
}

#Preview("Large", as: .systemLarge) {
    AgentAgendaWidget()
} timeline: {
    AgentAgendaEntry.onAStep
    AgentAgendaEntry.done
    AgentAgendaEntry.clear
    AgentAgendaEntry.unreachable
}

#Preview("Lock Screen", as: .accessoryRectangular) {
    AgentAgendaWidget()
} timeline: {
    AgentAgendaEntry.onAStep
    AgentAgendaEntry.done
    AgentAgendaEntry.clear
    AgentAgendaEntry.noAgent
}
