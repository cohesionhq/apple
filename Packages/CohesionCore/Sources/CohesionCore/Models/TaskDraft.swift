import Foundation

/// The editable fields of a task, for the create and edit forms.
public struct TaskDraft: Equatable {
    public var title = ""
    public var description = ""
    public var priority = TaskPriority.none
    public var size: TaskSize?
    public var assignee: TaskAssignee?
    public var status = TaskStatus.incomplete
    public var folderID: Int?
    public var startDate: Date?
    public var dueDate: Date?
    public var tagIDs: Set<Int> = []

    public init(
        title: String = "",
        description: String = "",
        priority: TaskPriority = TaskPriority.none,
        size: TaskSize? = nil,
        assignee: TaskAssignee? = nil,
        status: TaskStatus = TaskStatus.incomplete,
        folderID: Int? = nil,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        tagIDs: Set<Int> = []
    ) {
        self.title = title
        self.description = description
        self.priority = priority
        self.size = size
        self.assignee = assignee
        self.status = status
        self.folderID = folderID
        self.startDate = startDate
        self.dueDate = dueDate
        self.tagIDs = tagIDs
    }

    public init() {}

    public init(_ task: TaskItem) {
        title = task.title
        description = task.description
        priority = task.priority
        size = task.size
        assignee = task.assignee
        status = task.status
        folderID = task.folderID
        startDate = task.startDate.flatMap { CalendarDay.date($0) }
        dueDate = task.dueDate.flatMap { CalendarDay.date($0) }
        tagIDs = Set(task.tagIDs)
    }
}
