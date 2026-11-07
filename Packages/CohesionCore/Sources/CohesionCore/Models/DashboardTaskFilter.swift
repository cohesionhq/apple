import Foundation

/// Which open tasks the Tasks widget lists, each one `listTasks` query. Named
/// for the Dashboard it began on; a widget's saved choice is its raw value.
public enum DashboardTaskFilter: String, CaseIterable, Identifiable {
    case today, assignedToYou, overdue, highPriority

    public var id: Self { self }

    public var title: String {
        switch self {
        case .today: "Today"
        case .assignedToYou: "Assigned to You"
        case .overdue: "Overdue"
        case .highPriority: "High Priority"
        }
    }

    /// What the list says with nothing in it.
    public var empty: String {
        switch self {
        case .today: "Nothing due today."
        case .assignedToYou: "Nothing on your plate."
        case .overdue: "Nothing overdue."
        case .highPriority: "Nothing urgent."
        }
    }

    /// Most urgent first for high priority, else soonest due first.
    public var query: TaskQuery {
        switch self {
        case .highPriority:
            TaskQuery(scope: .all, priorities: [.urgent, .high], sort: .priority, descending: true)
        case .today, .assignedToYou, .overdue:
            TaskQuery(scope: .all, sort: .dueDate)
        }
    }

    public var assignee: TaskAssignee? {
        self == .assignedToYou ? .user : nil
    }

    /// The day tasks are due before, as of `now`: today's include those
    /// overdue, as on the web.
    public func dueBefore(_ now: Date) -> String? {
        switch self {
        case .today: Calendar.current.date(byAdding: .day, value: 1, to: now).map { CalendarDay.string($0) }
        case .overdue: CalendarDay.string(now)
        case .assignedToYou, .highPriority: nil
        }
    }
}
