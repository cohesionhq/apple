import AppIntents
import CohesionCore
import CohesionUI
import SwiftUI
import WidgetKit

/// A view of the tasks, picked in the widget's settings, as Reminders and
/// Things list one on the Home Screen: its name and count, then a row per
/// task with a checkbox that completes it. Tapping a row opens the task.
struct TasksWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Tasks", intent: TasksWidgetConfiguration.self, provider: TasksProvider()) { entry in
            TasksWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tasks")
        .description("The tasks in a view you pick, with a checkbox to complete each.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

/// The tasks as one listing found them.
nonisolated struct TasksEntry: TimelineEntry {
    let date: Date
    let state: State

    enum State {
        case tasks(TasksListing)
        case unpaired
        /// The keychain can't be read yet, which says nothing of the pairing.
        case restoring
        /// The listing failed, as it does away from the server's network;
        /// `waiting` tasks are completed here but not yet there.
        case unreachable(waiting: Int)
        /// The folder, tag, saved view or workspace picked isn't there, or
        /// the view picked belongs to another workspace.
        case viewGone
    }
}

/// A view's name, its open tasks and what it says with none.
nonisolated struct TasksListing {
    let title: String
    let systemImage: String
    let empty: String
    let tasks: [TaskItem]
    /// How many tasks the whole view has, past those listed.
    let total: Int
    /// Each workspace's name, by id, when the rows span them all.
    let workspaceNames: [Int: String]?
}

/// Lists the view picked with the app's pairing. The app reloads it when
/// tasks change; otherwise WidgetKit's budget decides when it next looks.
nonisolated struct TasksProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TasksEntry {
        let listing = TasksListing(title: "Tasks", systemImage: "checklist", empty: "", tasks: [], total: 0, workspaceNames: nil)
        return TasksEntry(date: .now, state: .tasks(listing))
    }

    func snapshot(for configuration: TasksWidgetConfiguration, in context: Context) async -> TasksEntry {
        await Self.entry(for: configuration)
    }

    func timeline(for configuration: TasksWidgetConfiguration, in context: Context) async -> Timeline<TasksEntry> {
        let entry = await Self.entry(for: configuration)
        return Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(15 * 60)))
    }

    @MainActor
    private static func entry(for configuration: TasksWidgetConfiguration) async -> TasksEntry {
        let pairing: Pairing
        switch Pairing.read() {
        case .paired(let paired): pairing = paired
        case .unpaired: return TasksEntry(date: .now, state: .unpaired)
        // Not a reason to ask for pairing: the next look can read it.
        case .unavailable: return TasksEntry(date: .now, state: .restoring)
        }
        guard let client = try? CohesionClient(pairing: pairing) else {
            return TasksEntry(date: .now, state: .unpaired)
        }
        // Cut short, it stops at the request cancelled and says what's left.
        let waiting = (try? await WidgetDeadline.run(seconds: 5) {
            await PendingCompletions.send(with: client, server: pairing.serverFingerprint)
        }) ?? []
        do {
            let listing = try await WidgetDeadline.run(seconds: 10) {
                try await Self.listing(for: configuration, with: client, leavingOut: waiting)
            }
            return TasksEntry(date: .now, state: listing.map { .tasks($0) } ?? .viewGone)
        } catch {
            return TasksEntry(date: .now, state: .unreachable(waiting: waiting.count))
        }
    }

    /// The view's tasks; `nil` when what it names isn't there.
    @MainActor
    private static func listing(
        for configuration: TasksWidgetConfiguration,
        with client: CohesionClient,
        leavingOut waiting: Set<Int>
    ) async throws -> TasksListing? {
        let workspaceID = configuration.workspace?.workspaceID
        let view = configuration.view.flatMap { TasksViewChoice(id: $0.id) } ?? .filter(.today)
        if let owner = view.workspaceID, owner != workspaceID { return nil }

        let workspaces = try await client.listWorkspaces()
        let workspace = workspaces.first { $0.id == workspaceID }
        if workspaceID != nil, workspace == nil { return nil }
        guard let shape = try await TasksViewShape(view, in: workspaceID, with: client) else { return nil }

        let page = try await client.listTasks(
            in: workspaceID,
            scope: shape.query.scope,
            statuses: shape.statuses,
            tags: shape.query.tags,
            priorities: shape.query.priorities,
            sizes: shape.query.sizes,
            sort: shape.query.sort,
            descending: shape.query.descending,
            limit: 24,
            dueBefore: shape.dueBefore,
            dueAfter: shape.dueAfter,
            assignee: shape.assignee
        )
        let tasks = page.tasks.filter { !waiting.contains($0.id) }
        return TasksListing(
            title: [workspace?.emoji, shape.title].compactMap(\.self).joined(separator: " "),
            systemImage: shape.systemImage,
            empty: shape.empty,
            tasks: tasks,
            total: page.total - (page.tasks.count - tasks.count),
            workspaceNames: workspaceID == nil
                ? Dictionary(uniqueKeysWithValues: workspaces.map { ($0.id, $0.displayName) })
                : nil
        )
    }
}

/// What a view asks `listTasks` for and how it's named.
private struct TasksViewShape {
    var title: String
    var systemImage: String
    var empty: String
    var query: TaskQuery
    var statuses: [TaskStatus] = [.incomplete]
    var dueBefore: String?
    var dueAfter: String?
    var assignee: TaskAssignee?

    /// `nil` when the folder, tag or saved view named isn't there. Anything
    /// but a saved view lists soonest due first, undated last.
    init?(_ view: TasksViewChoice, in workspaceID: Int?, with client: CohesionClient) async throws {
        let soonest = TaskQuery(scope: .all, sort: .dueDate)
        switch view {
        case .filter(let filter):
            title = filter.title
            empty = filter.empty
            query = filter.query
            dueBefore = filter.dueBefore(.now)
            assignee = filter.assignee
            systemImage = switch filter {
            case .today: "sun.max"
            case .overdue: "exclamationmark.circle"
            case .highPriority: "flag"
            case .assignedToYou: "person.crop.circle"
            }
        case .upcoming:
            title = "Upcoming"
            systemImage = "calendar"
            empty = "Nothing coming up."
            query = soonest
            dueAfter = CalendarDay.string(.now)
        case .inbox:
            title = "Inbox"
            systemImage = "tray"
            empty = "No tasks yet."
            query = TaskQuery(scope: .inbox, sort: .dueDate)
        case .all:
            title = "All"
            systemImage = "tray.full"
            empty = "No tasks yet."
            query = soonest
        case .folder(let id, let workspaceID):
            guard let folder = try await client.listTaskFolders(in: workspaceID).first(where: { $0.id == id }) else {
                return nil
            }
            title = folder.title
            systemImage = "folder"
            empty = "No tasks yet."
            query = TaskQuery(scope: .folder(id), sort: .dueDate)
        case .tag(let id, let workspaceID):
            guard let tag = try await client.listTaskTags(in: workspaceID).first(where: { $0.id == id }) else {
                return nil
            }
            title = tag.name
            systemImage = "tag"
            empty = "No matches."
            query = TaskQuery(scope: .all, tags: TagFilter(with: [id]), sort: .dueDate)
        case .savedView(let id, let workspaceID):
            guard let saved = try await client.listSavedTaskViews(in: workspaceID).first(where: { $0.id == id }) else {
                return nil
            }
            title = saved.name
            systemImage = "square.stack.3d.up"
            empty = "No matches."
            query = saved.query
            statuses = switch saved.scope {
            case .done: [.completed]
            case .cancelled: [.cancelled]
            case .inbox, .folder, .all: [.incomplete]
            }
        }
    }
}

struct TasksWidgetView: View {
    let entry: TasksEntry

    var body: some View {
        switch entry.state {
        case .tasks(let listing):
            TasksList(listing: listing, today: entry.date)
        case .unpaired:
            WidgetMessage(text: "Open Cohesion to pair.", systemImage: "link")
        case .restoring:
            WidgetMessage(text: "Restoring your pairing…", systemImage: "lock")
        case .unreachable(let waiting) where waiting == 1:
            WidgetMessage(text: "Can’t reach Cohesion. 1 task will complete when it can.", systemImage: "wifi.exclamationmark")
        case .unreachable(let waiting) where waiting > 1:
            WidgetMessage(text: "Can’t reach Cohesion. \(waiting) tasks will complete when it can.", systemImage: "wifi.exclamationmark")
        case .unreachable:
            WidgetMessage(text: "Can’t reach Cohesion.", systemImage: "wifi.exclamationmark")
        case .viewGone:
            WidgetMessage(text: "This view is gone. Edit the widget to pick another.", systemImage: "questionmark.folder")
        }
    }
}

/// The view's name and count, then as many rows as fit at the text size in
/// use, then how many more there are.
private struct TasksList: View {
    let listing: TasksListing
    let today: Date

    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if listing.tasks.isEmpty {
                WidgetMessage(text: LocalizedStringKey(listing.empty), systemImage: "checkmark.circle")
            } else {
                ViewThatFits(in: .vertical) {
                    ForEach(Array((1...listing.tasks.count).reversed()), id: \.self) { shown in
                        rows(shown: shown)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: listing.systemImage)
                .foregroundStyle(Color.widgetAccent)
                .widgetAccentable()
                .accessibilityHidden(true)
            Text(listing.title)
                .fontWeight(.semibold)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(listing.total, format: .number)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(listing.total) tasks")
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    /// The first `shown` rows.
    private func rows(shown: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: family == .systemExtraLarge ? 10 : 6) {
                ForEach(listing.tasks.prefix(shown)) { task in
                    TaskWidgetRow(task: task, workspaceNames: listing.workspaceNames, today: today)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if listing.total > shown {
                Text("\(listing.total - shown) more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A task's checkbox, title and flag, with when it's due: under the title
/// where there's room for that, after it in a medium widget, and left out in
/// a small one.
private struct TaskWidgetRow: View {
    let task: TaskItem
    let workspaceNames: [Int: String]?
    let today: Date

    @Environment(\.widgetFamily) private var family

    var body: some View {
        HStack(spacing: 8) {
            if task.status == .incomplete {
                Toggle(isOn: false, intent: CompleteTaskIntent(taskID: task.id, workspaceID: task.workspaceID)) {
                    Text("Complete “\(task.title)”")
                }
                .toggleStyle(TaskCheckbox())
            } else {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            opensTask {
                HStack(spacing: 6) {
                    switch family {
                    case .systemSmall:
                        title
                    // One line each where it's wide: an extra large widget is
                    // one list, its dates and flags in a column at the end.
                    case .systemMedium, .systemExtraLarge:
                        title
                        Spacer(minLength: 0)
                        due
                        flag
                    default:
                        VStack(alignment: .leading, spacing: 0) {
                            title
                            details
                        }
                        Spacer(minLength: 0)
                        flag
                    }
                }
                .contentShape(.rect)
            }
        }
    }

    /// A `Link`, or in a small widget, where one doesn't work, a button.
    @ViewBuilder
    private func opensTask(@ViewBuilder _ label: () -> some View) -> some View {
        if family == .systemSmall {
            Button(intent: OpenTaskIntent(taskID: task.id, workspaceID: task.workspaceID), label: label)
                .buttonStyle(.plain)
        } else {
            Link(destination: AppLink.task(task.id, workspaceID: task.workspaceID).url, label: label)
        }
    }

    private var title: some View {
        Text(task.title)
            .font(family == .systemSmall ? .footnote : .subheadline)
            .strikethrough(task.status != .incomplete)
            .foregroundStyle(task.status.titleStyle)
            .lineLimit(1)
    }

    /// When it's due, and which workspace it's in when the rows span them.
    @ViewBuilder
    private var details: some View {
        let workspace = workspaceNames?[task.workspaceID]
        if task.dueDate != nil || workspace != nil {
            HStack(spacing: 4) {
                due
                if task.dueDate != nil, workspace != nil {
                    Text(verbatim: "·").foregroundStyle(.secondary)
                }
                if let workspace {
                    Text(workspace).foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .lineLimit(1)
        }
    }

    /// Today, Tomorrow or the day it's due, red once it's past, as the app's
    /// rows have it (orange is for what needs the user).
    @ViewBuilder
    private var due: some View {
        if let dueDate = task.dueDate, let day = CalendarDay.date(dueDate) {
            Group {
                if Calendar.current.isDate(day, inSameDayAs: today) {
                    Text("Today")
                } else if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today),
                          Calendar.current.isDate(day, inSameDayAs: tomorrow) {
                    Text("Tomorrow")
                } else {
                    Text(day, format: .dateTime.month().day())
                }
            }
            .font(.caption)
            .foregroundStyle(day < Calendar.current.startOfDay(for: today) ? Color.red : .secondary)
            .lineLimit(1)
            .fixedSize()
        }
    }

    @ViewBuilder
    private var flag: some View {
        let image = Image(systemName: TaskPriority.flagSymbol)
            .imageScale(.small)
            .accessibilityHidden(true)
        if let tint = task.priority.tint {
            image.foregroundStyle(tint)
        } else {
            // Its room kept, so the dates before it line up down the list.
            image.hidden()
        }
    }
}

/// A circle that fills as soon as it's tapped, ahead of the widget reloading.
private struct TaskCheckbox: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Label {
                configuration.label
            } icon: {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(configuration.isOn ? Color.widgetAccent : .secondary)
                    .widgetAccentable()
                    .contentShape(.circle)
            }
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.plain)
    }
}

extension TasksListing {
    /// What the previews show.
    static let sample = TasksListing(
        title: "Today",
        systemImage: "sun.max",
        empty: "",
        tasks: TaskItem.samples,
        total: TaskItem.samples.count,
        workspaceNames: nil
    )
}

private extension TaskItem {
    static let samples = try! JSONDecoder().decode([Self].self, from: Data(#"""
        [{"id":1,"workspace_id":1,"task_folder_id":null,"title":"Review the roadmap","description":"",
          "status":"incomplete","priority":"high","start_date":null,"due_date":"2026-11-03","tag_ids":[]},
         {"id":2,"workspace_id":1,"task_folder_id":null,"title":"Book the venue","description":"",
          "status":"incomplete","priority":"none","start_date":null,"due_date":"2026-11-04","tag_ids":[]},
         {"id":3,"workspace_id":1,"task_folder_id":null,"title":"Reply to Sam","description":"",
          "status":"incomplete","priority":"urgent","start_date":null,"due_date":"2026-11-05","tag_ids":[]},
         {"id":4,"workspace_id":1,"task_folder_id":null,"title":"Renew the certificate","description":"",
          "status":"incomplete","priority":"low","start_date":null,"due_date":null,"tag_ids":[]},
         {"id":5,"workspace_id":1,"task_folder_id":null,"title":"Plan the offsite","description":"",
          "status":"incomplete","priority":"none","start_date":null,"due_date":null,"tag_ids":[]}]
        """#.utf8))
}

#Preview("Small", as: .systemSmall) {
    TasksWidget()
} timeline: {
    TasksEntry(date: .now, state: .tasks(.sample))
    TasksEntry(date: .now, state: .unreachable(waiting: 1))
}

#Preview("Medium", as: .systemMedium) {
    TasksWidget()
} timeline: {
    TasksEntry(date: .now, state: .tasks(.sample))
    TasksEntry(date: .now, state: .restoring)
}

#Preview("Large", as: .systemLarge) {
    TasksWidget()
} timeline: {
    TasksEntry(date: .now, state: .tasks(.sample))
    TasksEntry(date: .now, state: .viewGone)
}

#Preview("Extra Large", as: .systemExtraLarge) {
    TasksWidget()
} timeline: {
    TasksEntry(date: .now, state: .tasks(.sample))
}
