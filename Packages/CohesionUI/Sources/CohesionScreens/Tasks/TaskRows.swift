import CohesionCore
import CohesionUI
import SwiftUI

/// The rows of a list of tasks, with what a row does: tapping it, its
/// checkbox, swiping it and its menu. Changes show at once and go to
/// cohesiond; a failed one reloads the list. A task list presents the sheets
/// `edit` and `manageTags` ask for.
struct TaskRows: View {
    @Binding var tasks: [TaskItem]
    /// How many tasks the whole list has.
    @Binding var total: Int
    /// What the list shows, which says what a change can move or remove.
    let query: TaskQuery
    /// The statuses the list shows; a task leaving them falls out of it.
    let statuses: [TaskStatus]
    let folders: [TaskFolder]
    /// The workspace's task tags, by name.
    let tags: [Tag]
    /// The workspace's contacts, who its tasks can be assigned to.
    let contacts: [Contact]
    @Binding var error: (any Error)?
    let edit: (TaskItem) -> Void
    let manageTags: () -> Void
    let reload: () async -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.agents) private var agents
    @Environment(\.profile) private var profile

    private var scope: TaskScope { query.scope }

    var body: some View {
        ForEach(tasks) { task in
            Button {
                edit(task)
            } label: {
                TaskRow(
                    task: task,
                    list: list(of: task),
                    tags: tags(on: task),
                    assignee: ShownAssignee(task.assignee, agents: agents, contacts: contacts, profile: profile)
                ) { toggle(task) }
                    .contentShape(.rect)
            }
            // Plain, so the row keeps its own colors rather than the tint.
            .buttonStyle(.plain)
            .swipeActions {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    delete(task)
                }
            }
            // Sections divide it: its ID, its status, its fields,
            // forwarding it, and deleting it.
            .contextMenu {
                Section {
                    // The bare number, as the CLI's task commands take it.
                    Button("Copy ID", systemImage: "doc.on.doc") {
                        Pasteboard.general.string = String(task.id)
                    }
                }
                Section {
                    if task.status == .incomplete {
                        Button("Complete", systemImage: "checkmark.circle") {
                            setStatus(.completed, of: task)
                        }
                        Button("Cancel", systemImage: "xmark.circle") {
                            setStatus(.cancelled, of: task)
                        }
                    } else {
                        Button("Reopen", systemImage: "arrow.uturn.backward.circle") {
                            setStatus(.incomplete, of: task)
                        }
                    }
                }
                Section {
                    priorityMenu(of: task)
                    if !model.vocabulary.taskSizes.isEmpty {
                        sizeMenu(of: task)
                    }
                    tagsMenu(of: task)
                    assigneeMenu(of: task)
                }
                Section {
                    ForwardMenu(item: AgentForwardedItem(
                        kind: .task, workspaceID: task.workspaceID, id: task.id, title: task.title
                    ))
                }
                Section {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        delete(task)
                    }
                }
            }
        }
    }

    /// A submenu of the tags, each checked when on the task, then
    /// "Manage Tags…".
    private func tagsMenu(of task: TaskItem) -> some View {
        Menu {
            ForEach(tags) { tag in
                Toggle(tag.name, isOn: Binding {
                    task.tagIDs.contains(tag.id)
                } set: {
                    setTag(tag, on: task, tagged: $0)
                })
            }
            Section {
                Button("Manage Tags…", action: manageTags)
            }
        } label: {
            Label("Tags", systemImage: "tag")
        }
    }

    /// "Assign to": a submenu of the user, the agents and the contacts, then
    /// None; the picker checks who the task is assigned to.
    private func assigneeMenu(of task: TaskItem) -> some View {
        Menu {
            AssigneePicker(selection: Binding {
                task.assignee
            } set: {
                setAssignee($0, of: task)
            }, contacts: contacts)
        } label: {
            Label("Assign To", systemImage: "person.crop.circle")
        }
    }

    /// A submenu of the priorities, in the vocabulary's order; the picker
    /// checks the task's current one.
    private func priorityMenu(of task: TaskItem) -> some View {
        Menu {
            Picker("Priority", selection: Binding {
                task.priority
            } set: {
                setPriority($0, of: task)
            }) {
                ForEach(model.vocabulary.taskPriorities, id: \.kind) { PriorityLabel(priority: $0).tag($0.kind) }
            }
        } label: {
            Label("Priority", systemImage: "flag")
        }
    }

    /// A submenu of the sizes, smallest first, then none; the picker checks
    /// the task's current one.
    private func sizeMenu(of task: TaskItem) -> some View {
        Menu {
            Picker("Size", selection: Binding {
                task.size
            } set: {
                setSize($0, of: task)
            }) {
                ForEach(model.vocabulary.taskSizes, id: \.kind) { Text($0.label).tag(Optional($0.kind)) }
                Text("None").tag(TaskSize?.none)
            }
        } label: {
            Label("Size", systemImage: "ruler")
        }
    }

    /// The tags on `task`, by name.
    private func tags(on task: TaskItem) -> [Tag] {
        tags.filter { task.tagIDs.contains($0.id) }
    }

    /// The list `task` is in, shown only when this list spans them all.
    private func list(of task: TaskItem) -> String? {
        guard scope.spansFolders else { return nil }
        guard let folderID = task.folderID else { return "Inbox" }
        return folders.first { $0.id == folderID }?.title
    }

    private func toggle(_ task: TaskItem) {
        setStatus(task.status == .completed ? .incomplete : .completed, of: task)
    }

    /// Updates the row at once, then lets a finished task fall out of the
    /// list once its new status has had a moment on screen.
    private func setStatus(_ status: TaskStatus, of task: TaskItem) {
        guard let client = model.client,
              let index = tasks.firstIndex(where: { $0.id == task.id })
        else { return }
        withAnimation(.snappy) { tasks[index].status = status }
        Task {
            do {
                try await client.setStatus(status, of: task)
                if !statuses.contains(status) {
                    try await Task.sleep(for: .milliseconds(600))
                    let shown = tasks.count
                    withAnimation { tasks.removeAll { $0.id == task.id && $0.status == status } }
                    total -= shown - tasks.count
                }
            } catch {
                self.error = error
                await reload()
            }
        }
    }

    /// Updates the row at once; a failed change reloads the list, and so
    /// does a change while the list is sorted or narrowed by priority.
    private func setPriority(_ priority: TaskPriority, of task: TaskItem) {
        guard let client = model.client,
              let index = tasks.firstIndex(where: { $0.id == task.id })
        else { return }
        withAnimation(.snappy) { tasks[index].priority = priority }
        Task {
            do {
                try await client.setPriority(priority, of: task)
                // The server orders by priority, so the row may belong elsewhere.
                if query.sort == .priority || !query.priorities.isEmpty { await reload() }
            } catch {
                self.error = error
                await reload()
            }
        }
    }

    /// Updates the row at once; a failed change reloads the list, and so
    /// does a change while the list is sorted or narrowed by size.
    private func setSize(_ size: TaskSize?, of task: TaskItem) {
        guard let client = model.client,
              let index = tasks.firstIndex(where: { $0.id == task.id })
        else { return }
        withAnimation(.snappy) { tasks[index].size = size }
        Task {
            do {
                try await client.setSize(size, of: task)
                // The server orders by size, so the row may belong elsewhere.
                if query.sort == .size || !query.sizes.isEmpty { await reload() }
            } catch {
                self.error = error
                await reload()
            }
        }
    }

    /// Updates the row at once; a failed change reloads the list.
    private func setAssignee(_ assignee: TaskAssignee?, of task: TaskItem) {
        guard let client = model.client,
              let index = tasks.firstIndex(where: { $0.id == task.id })
        else { return }
        withAnimation(.snappy) { tasks[index].assignee = assignee }
        Task {
            do {
                try await client.setAssignee(assignee, of: task)
            } catch {
                self.error = error
                await reload()
            }
        }
    }

    /// Updates the row at once; a failed change reloads the list, and so
    /// does changing a tag the list is narrowed by.
    private func setTag(_ tag: Tag, on task: TaskItem, tagged: Bool) {
        guard let client = model.client,
              let index = tasks.firstIndex(where: { $0.id == task.id })
        else { return }
        withAnimation(.snappy) {
            tasks[index].tagIDs.removeAll { $0 == tag.id }
            if tagged { tasks[index].tagIDs.append(tag.id) }
        }
        Task {
            do {
                _ = try await client.setTag(tag.id, on: task, tagged: tagged)
                if query.tags.with.contains(tag.id) || query.tags.without.contains(tag.id) { await reload() }
            } catch {
                self.error = error
                await reload()
            }
        }
    }

    private func delete(_ task: TaskItem) {
        guard let client = model.client else { return }
        withAnimation { tasks.removeAll { $0.id == task.id } }
        total -= 1
        Task {
            do {
                try await client.delete(task)
            } catch {
                self.error = error
                await reload()
            }
        }
    }
}

/// A task's checkbox, title, and under it in one wrapping line when it is
/// due, who it's assigned to, its size, its tags and the list it's in (for
/// All), then a flag for any priority.
private struct TaskRow: View {
    let task: TaskItem
    let list: String?
    let tags: [Tag]
    let assignee: ShownAssignee?
    let toggle: () -> Void

    @Environment(AppModel.self) private var model

    private var isDone: Bool { task.status == .completed }

    var body: some View {
        HStack {
            Button(action: toggle) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundStyle(isDone ? Color.accentColor : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: isDone)
            }
            .buttonStyle(.borderless)
            .sensoryFeedback(.success, trigger: isDone) { _, isDone in isDone }
            .accessibilityLabel(isDone ? "Mark Incomplete" : "Mark Complete")

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .multilineTextAlignment(.leading)
                    .strikethrough(task.status != .incomplete)
                    .foregroundStyle(task.status.titleStyle)
                let due = task.dueDate.flatMap { CalendarDay.date($0) }
                if due != nil || task.size != nil || assignee != nil || list != nil || !tags.isEmpty {
                    // One grammar: plain secondary words, each with at most a
                    // small glyph, no capsules, so the title stays the row.
                    FlowLayout(spacing: 10) {
                        if let due {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                Text(Self.dueWords(due))
                            }
                            // Red once an open task's day has passed, as
                            // Reminders marks it.
                            .foregroundStyle(isOverdue(due) ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                            .accessibilityElement(children: .combine)
                        }
                        if let assignee {
                            HStack(spacing: 4) {
                                assignee.avatar(diameter: 16)
                                Text(assignee.label)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Assigned to \(assignee.label)")
                        }
                        if let size = task.size {
                            sizePill(size)
                        }
                        ForEach(tags) { tag in
                            Text(verbatim: "#\(tag.name)")
                                .accessibilityLabel("Tag: \(tag.name)")
                        }
                        if let list {
                            Text(list)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            .animation(.snappy, value: task.status)

            Spacer()

            if let tint = task.priority.tint {
                Image(systemName: TaskPriority.flagSymbol)
                    .imageScale(.small)
                    .foregroundStyle(tint)
                    .accessibilityLabel(model.vocabulary.label(of: task.priority))
            }
        }
    }

    /// A due day in words near today ("Today", "Tomorrow", "Yesterday"),
    /// else its month and day.
    private static func dueWords(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.month().day())
    }

    /// Whether an open task's due day is before today.
    private func isOverdue(_ day: Date) -> Bool {
        task.status == .incomplete && day < Calendar.current.startOfDay(for: .now)
    }

    /// A size in grey words after a ruler: a measure, not a status, so it
    /// takes none of the colours that say one.
    private func sizePill(_ size: TaskSize) -> some View {
        let label = model.vocabulary.label(of: size)
        return HStack(spacing: 3) {
            Image(systemName: "ruler")
                .imageScale(.small)
            Text(label)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Size: \(label)")
    }
}
