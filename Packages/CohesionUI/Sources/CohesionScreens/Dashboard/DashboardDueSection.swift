import CohesionCore
import CohesionUI
import SwiftUI

/// The Dashboard's tasks due, as the web's "Due": the workspace's open tasks
/// due today or earlier, soonest first. Each leads with its own checkbox,
/// which completes it here, and opens in a sheet, as a task's link does, with
/// "Overdue" in red or "Today" at its end. Gone when nothing is due.
struct DashboardDueSection: View {
    let workspaceID: Int

    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    @State private var tasks: [TaskItem] = []
    /// Tasks just ticked, shown checked until the list drops them.
    @State private var completed: Set<Int> = []
    @State private var error: (any Error)?

    var body: some View {
        Section {
            ForEach(tasks) { task in
                row(task)
            }
            if tasks.isEmpty {
                // Nothing to show, but something to hang the load on: a
                // section with no rows isn't drawn, so its task wouldn't run.
                Color.clear
                    .frame(height: 0)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityHidden(true)
            }
        } header: {
            if !tasks.isEmpty {
                DashboardSectionHeader(title: "Due", count: tasks.count)
            }
        }
        .onAppear {
            // As last listed, from launching too, while they're asked again.
            if tasks.isEmpty, let page = model.client.flatMap(keptDue) { tasks = page.tasks }
        }
        .task(id: workspaceID) { await watch() }
        .errorAlert($error)
    }

    private func row(_ task: TaskItem) -> some View {
        let isDone = completed.contains(task.id)
        return HStack(spacing: 12) {
            Button {
                complete(task)
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundStyle(isDone ? Color.accentColor : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
            .sensoryFeedback(.success, trigger: isDone) { _, isDone in isDone }
            .accessibilityLabel("Mark Complete")
            Button {
                openURL(AppLink.task(task.id, workspaceID: task.workspaceID).url)
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(task.title)
                        .strikethrough(isDone)
                        .foregroundStyle(isDone ? .secondary : .primary)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    dueWords(task)
                        .font(.subheadline)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    /// "Overdue" in red for a day past, else "Today", as a task's row says it.
    @ViewBuilder
    private func dueWords(_ task: TaskItem) -> some View {
        if let day = task.dueDate.flatMap({ CalendarDay.date($0) }),
           day < Calendar.current.startOfDay(for: .now) {
            Text("Overdue").foregroundStyle(.red)
        } else {
            Text("Today").foregroundStyle(.secondary)
        }
    }

    private func complete(_ task: TaskItem) {
        guard let client = model.client else { return }
        withAnimation(.snappy) { _ = completed.insert(task.id) }
        Task {
            do {
                try await client.setStatus(.completed, of: task)
            } catch {
                withAnimation(.snappy) { _ = completed.remove(task.id) }
                self.error = error
            }
        }
    }

    /// Loads the tasks due, and again whenever the workspace's tasks change.
    private func watch() async {
        guard let client = model.client else { return }
        for await origin in client.loads(matching: { $0 == .taskList(workspaceID: workspaceID) }) {
            await origin.run {
                let page = try await listDue(client)
                withAnimation {
                    tasks = page.tasks
                    completed.formIntersection(page.tasks.map(\.id))
                }
            } failed: { self.error = $0 }
        }
    }

    /// The workspace's open tasks due today or earlier, soonest first, kept
    /// for the next launch.
    private func listDue(_ client: CohesionClient) async throws -> TaskPage {
        try await client.listTasks(
            in: workspaceID, scope: .all, statuses: [.incomplete], tags: TagFilter(), priorities: [], sizes: [],
            sort: .dueDate, descending: false, limit: Self.limit, dueBefore: DashboardTaskFilter.today.dueBefore(.now),
            keeping: true
        )
    }

    /// What `listDue` last kept today.
    private func keptDue(_ client: CohesionClient) -> TaskPage? {
        client.keptTasks(
            in: workspaceID, scope: .all, statuses: [.incomplete], tags: TagFilter(), priorities: [], sizes: [],
            sort: .dueDate, descending: false, limit: Self.limit, dueBefore: DashboardTaskFilter.today.dueBefore(.now)
        )
    }

    private static let limit = 20
}
