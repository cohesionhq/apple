import Foundation

/// The commands this app sends, with their wire names and arguments.
extension CohesionClient {
    // MARK: Server

    public func about() async throws -> ServerAbout {
        try await call("about")
    }

    // MARK: Workspaces

    public func listWorkspaces() async throws -> [Workspace] {
        try await call("listWorkspaces", keeping: .whole)
    }

    /// The workspaces as last listed. Each list command that keeps its reply
    /// has one of these beside it, for the screen that opens on the list.
    public func keptWorkspaces() -> [Workspace]? {
        keptReply("listWorkspaces")
    }

    // MARK: Diagrams

    /// Mermaid `source` as cohesiond draws it, laid out for `width` points or
    /// at the size it wants when that's `nil`. An answer that would stay the
    /// same is kept for `keptMermaid`, for as long as this client lasts.
    public func renderMermaid(
        _ source: String,
        width: Int?,
        format: MermaidFormat = .svg
    ) async throws -> RenderedMermaid {
        let rendered: RenderedMermaid = try await call("renderMermaid", [
            "source": source,
            "width": width,
            "format": format.rawValue,
        ])
        if case .refused(let reason) = rendered, !reason.isLasting { return rendered }
        keep(rendered, for: RenderedMermaidKey(source: source, width: width, format: format))
        return rendered
    }

    /// What `renderMermaid` kept for `source` at `width`, which needs no
    /// connection and no request.
    public func keptMermaid(_ source: String, width: Int?, format: MermaidFormat = .svg) -> RenderedMermaid? {
        renderedMermaid[RenderedMermaidKey(source: source, width: width, format: format)]
    }

    // MARK: Tasks

    /// A page of the tasks in `scope` with one of `statuses`, the tags
    /// `tags` asks for and, unless empty, one of `priorities` and one of
    /// `sizes`, ordered by `sort`: `limit` of them from `offset`. `dueBefore`
    /// and `dueAfter` (`"YYYY-MM-DD"`) keep those due strictly between those
    /// days, and `assignee` those assigned to them. Every workspace's tasks
    /// when `workspaceID` is `nil`. `keeping` keeps the page for `keptTasks`:
    /// only the first page a list opens on is worth it.
    public func listTasks(
        in workspaceID: Int?,
        scope: TaskScope,
        statuses: [TaskStatus],
        tags: TagFilter,
        priorities: Set<TaskPriority>,
        sizes: Set<TaskSize>,
        sort: TaskSort,
        descending: Bool,
        offset: Int = 0,
        limit: Int = 50,
        dueBefore: String? = nil,
        dueAfter: String? = nil,
        assignee: TaskAssignee? = nil,
        keeping: Bool = false
    ) async throws -> TaskPage {
        try await call("listTasks", Self.taskListArguments(
            workspaceID, scope, statuses, tags, priorities, sizes, sort, descending,
            offset, limit, dueBefore, dueAfter, assignee
        ), keeping: keeping ? .whole : nil)
    }

    /// The page `listTasks` with the same arguments last kept.
    public func keptTasks(
        in workspaceID: Int?,
        scope: TaskScope,
        statuses: [TaskStatus],
        tags: TagFilter,
        priorities: Set<TaskPriority>,
        sizes: Set<TaskSize>,
        sort: TaskSort,
        descending: Bool,
        offset: Int = 0,
        limit: Int = 50,
        dueBefore: String? = nil,
        dueAfter: String? = nil,
        assignee: TaskAssignee? = nil
    ) -> TaskPage? {
        keptReply("listTasks", Self.taskListArguments(
            workspaceID, scope, statuses, tags, priorities, sizes, sort, descending,
            offset, limit, dueBefore, dueAfter, assignee
        ))
    }

    private static func taskListArguments(
        _ workspaceID: Int?,
        _ scope: TaskScope,
        _ statuses: [TaskStatus],
        _ tags: TagFilter,
        _ priorities: Set<TaskPriority>,
        _ sizes: Set<TaskSize>,
        _ sort: TaskSort,
        _ descending: Bool,
        _ offset: Int,
        _ limit: Int,
        _ dueBefore: String?,
        _ dueAfter: String?,
        _ assignee: TaskAssignee?
    ) -> [String: Any?] {
        let folder: Any = switch scope {
        case .inbox: "inbox"
        case .folder(let id): id
        case .all, .done, .cancelled: "any"
        }
        var due: [String: String] = [:]
        due["before"] = dueBefore
        due["after"] = dueAfter
        return [
            "workspace_id": workspaceID,
            "folder": folder,
            "statuses": statuses.map(\.rawValue),
            "tags": tags.wireValue,
            "priorities": priorities.isEmpty ? nil : priorities.map(\.rawValue).sorted(),
            "sizes": sizes.isEmpty ? nil : sizes.map(\.rawValue).sorted(),
            "sort": sort.rawValue,
            "descending": descending,
            "offset": offset,
            "limit": limit,
            "due_date": due.isEmpty ? nil : due,
            "assignee": assignee?.wireValue,
        ]
    }

    /// Task `taskID`, whatever its status: in workspace `workspaceID`, or in
    /// whichever holds it when that's `nil`; `nil` once it's deleted, if it
    /// never existed, or if it's in another workspace.
    public func task(_ taskID: Int, in workspaceID: Int? = nil) async throws -> TaskItem? {
        let page: TaskPage = try await call("listTasks", [
            "ids": [taskID],
            "workspace_id": workspaceID,
            "statuses": TaskStatus.allCases.map(\.rawValue),
            "limit": 1,
        ])
        return page.tasks.first
    }

    public func listTaskFolders(in workspaceID: Int) async throws -> [TaskFolder] {
        try await call("listTaskFolders", ["workspace_id": workspaceID], keeping: .whole)
    }

    public func keptTaskFolders(in workspaceID: Int) -> [TaskFolder]? {
        keptReply("listTaskFolders", ["workspace_id": workspaceID])
    }

    /// Colors the folder's icon, or clears its color when `color` is `nil`.
    public func setColor(of folder: TaskFolder, to color: AgentColor?, in workspaceID: Int) async throws -> TaskFolder {
        try await call("setTaskFolderColor", [
            "workspace_id": workspaceID,
            "folder_id": folder.id,
            "color": color?.rawValue,
        ])
    }

    /// Creates the task with its tags on.
    public func createTask(_ draft: TaskDraft, in workspaceID: Int) async throws -> TaskItem {
        try await call("createTask", [
            "workspace_id": workspaceID,
            "title": draft.title,
            "description": draft.description,
            "priority": draft.priority.rawValue,
            "size": draft.size?.rawValue,
            "folder_id": draft.folderID,
            "start_date": draft.startDate.map(CalendarDay.string),
            "due_date": draft.dueDate.map(CalendarDay.string),
            "tag_ids": draft.tagIDs.sorted(),
        ])
    }

    /// Sends one command for each field `draft` changes on `task`.
    public func update(_ task: TaskItem, to draft: TaskDraft) async throws {
        let original = TaskDraft(task)
        let ids: [String: Any?] = ["workspace_id": task.workspaceID, "task_id": task.id]
        func send(_ type: String, _ args: [String: Any?]) async throws {
            let _: TaskItem = try await call(type, ids.merging(args) { $1 })
        }

        if draft.title != original.title {
            try await send("renameTask", ["title": draft.title])
        }
        if draft.description != original.description {
            try await send("editTaskDescription", ["description": draft.description])
        }
        if draft.priority != original.priority {
            try await send("setTaskPriority", ["priority": draft.priority.rawValue])
        }
        if draft.size != original.size {
            try await send("setTaskSize", ["size": draft.size.map { $0.rawValue as Any } ?? NSNull()])
        }
        if draft.assignee != original.assignee {
            try await send("setTaskAssignee", ["assignee": draft.assignee?.wireValue ?? NSNull()])
        }
        if draft.startDate != original.startDate || draft.dueDate != original.dueDate {
            // A null day clears it, so it must be sent rather than left out.
            try await send("scheduleTask", [
                "start_date": draft.startDate.map { CalendarDay.string($0) as Any } ?? NSNull(),
                "due_date": draft.dueDate.map { CalendarDay.string($0) as Any } ?? NSNull(),
            ])
        }
        if draft.folderID != original.folderID {
            try await send("moveTask", ["folder_id": draft.folderID])
        }
        if draft.status != original.status {
            try await setStatus(draft.status, of: task)
        }
        for tagID in draft.tagIDs.subtracting(original.tagIDs) {
            _ = try await setTag(tagID, on: task, tagged: true)
        }
        for tagID in original.tagIDs.subtracting(draft.tagIDs) {
            _ = try await setTag(tagID, on: task, tagged: false)
        }
    }

    public func setStatus(_ status: TaskStatus, of task: TaskItem) async throws {
        try await setStatus(status, ofTask: task.id, in: task.workspaceID)
    }

    public func setStatus(_ status: TaskStatus, ofTask taskID: Int, in workspaceID: Int) async throws {
        let _: [TaskItem] = try await call("changeTasksStatus", [
            "workspace_id": workspaceID,
            "task_ids": [taskID],
            "status": status.rawValue,
        ])
    }

    public func setPriority(_ priority: TaskPriority, of task: TaskItem) async throws {
        let _: TaskItem = try await call("setTaskPriority", [
            "workspace_id": task.workspaceID,
            "task_id": task.id,
            "priority": priority.rawValue,
        ])
    }

    /// Sets the task's size; `nil` clears it.
    public func setSize(_ size: TaskSize?, of task: TaskItem) async throws {
        let _: TaskItem = try await call("setTaskSize", [
            "workspace_id": task.workspaceID,
            "task_id": task.id,
            // A null size clears it, so it must be sent rather than left out.
            "size": size.map { $0.rawValue as Any } ?? NSNull(),
        ])
    }

    /// Assigns the task to `assignee`; `nil` leaves it unassigned.
    public func setAssignee(_ assignee: TaskAssignee?, of task: TaskItem) async throws {
        let _: TaskItem = try await call("setTaskAssignee", [
            "workspace_id": task.workspaceID,
            "task_id": task.id,
            // A null assignee unassigns, so it must be sent rather than left out.
            "assignee": assignee?.wireValue ?? NSNull(),
        ])
    }

    public func delete(_ task: TaskItem) async throws {
        let _: TaskItem = try await call("deleteTask", [
            "workspace_id": task.workspaceID,
            "task_id": task.id,
        ])
    }

    // MARK: Saved Task Views

    /// The workspace's saved views, in their order.
    public func listSavedTaskViews(in workspaceID: Int) async throws -> [SavedTaskView] {
        try await call("listSavedTaskViews", ["workspace_id": workspaceID], keeping: .whole)
    }

    public func keptSavedTaskViews(in workspaceID: Int) -> [SavedTaskView]? {
        keptReply("listSavedTaskViews", ["workspace_id": workspaceID])
    }

    /// Saves `query` under `name`, last among the workspace's views.
    public func saveTaskView(_ query: TaskQuery, named name: String, in workspaceID: Int) async throws -> SavedTaskView {
        try await call("createSavedTaskView", query.arguments.merging([
            "workspace_id": workspaceID,
            "name": name,
        ]) { $1 })
    }

    /// Makes `view` keep `query` instead, under the same name and place.
    public func update(_ view: SavedTaskView, to query: TaskQuery) async throws -> SavedTaskView {
        try await call("updateSavedTaskView", query.arguments.merging([
            "workspace_id": view.workspaceID,
            "view_id": view.id,
        ]) { $1 })
    }

    public func rename(_ view: SavedTaskView, to name: String) async throws {
        let _: SavedTaskView = try await call("renameSavedTaskView", [
            "workspace_id": view.workspaceID,
            "view_id": view.id,
            "name": name,
        ])
    }

    /// Puts the workspace's views in the order of `ids`; replies with them in that order.
    public func reorderSavedTaskViews(_ ids: [Int], in workspaceID: Int) async throws -> [SavedTaskView] {
        try await call("reorderSavedTaskViews", ["workspace_id": workspaceID, "view_ids": ids])
    }

    /// Deletes the view; its tasks stay as they are.
    public func delete(_ view: SavedTaskView) async throws {
        let _: SavedTaskView = try await call("deleteSavedTaskView", [
            "workspace_id": view.workspaceID,
            "view_id": view.id,
        ])
    }

    // MARK: Tags

    /// The workspace's task tags, by name.
    public func listTaskTags(in workspaceID: Int) async throws -> [Tag] {
        try await call("listTags", ["workspace_id": workspaceID], keeping: .whole)
    }

    public func keptTaskTags(in workspaceID: Int) -> [Tag]? {
        keptReply("listTags", ["workspace_id": workspaceID])
    }

    public func createTaskTag(named name: String, in workspaceID: Int) async throws -> Tag {
        try await call("createTag", ["workspace_id": workspaceID, "name": name])
    }

    public func rename(_ tag: Tag, to name: String) async throws {
        let _: Tag = try await call("renameTag", [
            "workspace_id": tag.workspaceID,
            "tag_id": tag.id,
            "name": name,
        ])
    }

    /// Deletes the tag, taking it off every task it's on.
    public func delete(_ tag: Tag) async throws {
        let _: Tag = try await call("deleteTag", ["workspace_id": tag.workspaceID, "tag_id": tag.id])
    }

    /// Puts tag `tagID` on `task`, or takes it off; returns the task as it now is.
    public func setTag(_ tagID: Int, on task: TaskItem, tagged: Bool) async throws -> TaskItem {
        try await call("setTagged", [
            "workspace_id": task.workspaceID,
            "tag_id": tagID,
            "task_id": task.id,
            "tagged": tagged,
        ])
    }

    // MARK: Contacts

    /// The workspace's contacts, by last name, then first name. Kept whole,
    /// photos too, so the list shows them at once.
    public func listContacts(in workspaceID: Int) async throws -> [Contact] {
        try await call("listContacts", ["workspace_id": workspaceID], keeping: .whole)
    }

    public func keptContacts(in workspaceID: Int) -> [Contact]? {
        keptReply("listContacts", ["workspace_id": workspaceID])
    }

    /// Creates a contact with `methods` in their order; an empty middle
    /// name is none.
    public func createContact(
        firstName: String,
        middleName: String,
        lastName: String,
        notes: String,
        methods: [NewContactMethod],
        in workspaceID: Int
    ) async throws -> Contact {
        try await call("createContact", [
            "workspace_id": workspaceID,
            "first_name": firstName,
            "middle_name": middleName,
            "last_name": lastName,
            "notes": notes,
            "methods": methods.map(\.wireValue),
        ])
    }

    /// Replaces the contact's names and notes; an empty middle name is none.
    public func updateContact(
        _ contact: Contact,
        firstName: String,
        middleName: String,
        lastName: String,
        notes: String
    ) async throws {
        let _: Contact = try await call("updateContact", [
            "workspace_id": contact.workspaceID,
            "contact_id": contact.id,
            "first_name": firstName,
            "middle_name": middleName,
            "last_name": lastName,
            "notes": notes,
        ])
    }

    public func delete(_ contact: Contact) async throws {
        let _: Contact = try await call("deleteContact", [
            "workspace_id": contact.workspaceID,
            "contact_id": contact.id,
        ])
    }

    /// Sets the contact's photo, replacing any it had, or removes it when
    /// `photo` is `nil`.
    public func setPhoto(of contact: Contact, to photo: AttachmentUpload?) async throws {
        let _: Contact = try await call("setContactPhoto", [
            "workspace_id": contact.workspaceID,
            "contact_id": contact.id,
            "photo": photo.map { ["media_type": $0.mediaType, "data": $0.data] },
        ])
    }

    /// Adds an email address or phone number after the contact's others.
    public func addMethod(_ kind: ContactMethodKind, _ value: String, to contact: Contact) async throws {
        let _: JSONValue = try await call("addContactMethod", [
            "workspace_id": contact.workspaceID,
            "contact_id": contact.id,
            "kind": kind.rawValue,
            "value": value,
        ])
    }

    public func updateMethod(_ method: ContactMethod, of contact: Contact, kind: ContactMethodKind, value: String) async throws {
        let _: JSONValue = try await call("updateContactMethod", [
            "workspace_id": contact.workspaceID,
            "method_id": method.id,
            "kind": kind.rawValue,
            "value": value,
        ])
    }

    public func deleteMethod(_ method: ContactMethod, of contact: Contact) async throws {
        let _: JSONValue = try await call("deleteContactMethod", [
            "workspace_id": contact.workspaceID,
            "method_id": method.id,
        ])
    }

    // MARK: Profile

    /// The user's profile; `nil` from a daemon from before profiles, which
    /// doesn't know the command.
    public func profile() async throws -> Profile? {
        do {
            return try await call("getProfile")
        } catch let error as ServerError where error.code == ServerError.badRequest {
            return nil
        }
    }

    /// Sets the user's name; cohesiond trims it, and removes it when empty.
    public func setProfileName(_ name: String) async throws -> Profile {
        try await call("setProfileName", ["name": name])
    }

    /// Sets the user's photo, replacing any they had, or removes it when
    /// `photo` is `nil`.
    public func setProfilePhoto(_ photo: AttachmentUpload?) async throws -> Profile {
        try await call("setProfilePhoto", [
            "photo": photo.map { ["media_type": $0.mediaType, "data": $0.data] },
        ])
    }

    // MARK: Articles

    /// One page of the articles `filter` covers, most recently published
    /// first, without their contents: up to `limit` of them after skipping
    /// `offset`. cohesiond lists at most 500 at a time.
    public func listArticles(
        filter: ArticleListFilter,
        offset: Int = 0,
        limit: Int = 50
    ) async throws -> ArticlePage {
        try await call("listArticles", [
            "filter": filter.wireValue,
            "offset": offset,
            "limit": limit,
        ])
    }

    /// Marks an article read or unread.
    public func setRead(_ articleID: Int, _ read: Bool) async throws -> Article {
        try await call("setArticleRead", ["article_id": articleID, "read": read])
    }

    /// Marks every unread article `filter` covers as read.
    public func markAllRead(filter: ArticleListFilter) async throws {
        let _: ArticlesMarkedRead = try await call("markArticlesRead", [
            "filter": filter.wireValue,
        ])
    }

    // MARK: Feeds

    /// The feeds in their order, with their unread counts.
    public func listFeeds() async throws -> [FeedSummary] {
        try await call("listFeeds", keeping: .whole)
    }

    public func keptFeeds() -> [FeedSummary]? {
        keptReply("listFeeds")
    }

    /// Reads the feed at `url` and follows it. Answers once its articles are in.
    public func addFeed(_ url: String) async throws -> Feed {
        try await call("addFeed", ["url": url])
    }

    /// Reads a feed now.
    public func refreshFeed(_ feedID: Int) async throws -> Feed {
        try await call("refreshFeed", ["feed_id": feedID])
    }

    /// Reads every feed now.
    public func refreshFeeds() async throws -> [Feed] {
        try await call("refreshFeeds")
    }

    /// Puts the feeds in the order of `ids`; replies with them in that order.
    public func reorderFeeds(_ ids: [Int]) async throws -> [FeedSummary] {
        try await call("reorderFeeds", ["feed_ids": ids])
    }

    public func renameFeed(_ feedID: Int, to title: String) async throws {
        let _: JSONValue = try await call("renameFeed", ["feed_id": feedID, "title": title])
    }

    public func setFullPagePolicy(_ policy: FeedFullPagePolicy, ofFeed feedID: Int) async throws {
        let _: JSONValue = try await call("setFeedFullPagePolicy", [
            "feed_id": feedID,
            "full_page_policy": policy.rawValue,
        ])
    }

    /// Stops following the feed; its articles go with it.
    public func deleteFeed(_ feedID: Int) async throws {
        let _: JSONValue = try await call("deleteFeed", ["feed_id": feedID])
    }

    /// An article, whole. Doesn't mark it read.
    public func article(_ articleID: Int) async throws -> Article {
        try await call("getArticle", ["article_id": articleID])
    }

    /// Fetches an article's page again; a failure keeps any earlier text.
    public func refetch(_ articleID: Int) async throws -> RefetchedArticle {
        try await call("resnapshotArticle", ["article_id": articleID])
    }

    public func rename(_ articleID: Int, to title: String) async throws -> Article {
        try await call("renameArticle", ["article_id": articleID, "title": title])
    }

    // MARK: Journal

    /// The entry for `day` (`"YYYY-MM-DD"`), or `nil` if nothing was written
    /// that day.
    public func journalEntry(on day: String, in workspaceID: Int) async throws -> JournalEntry? {
        try await call("getJournal", ["workspace_id": workspaceID, "date": day])
    }

    /// Replaces the text of `day`'s entry, creating it if nothing was
    /// written that day.
    public func writeJournal(_ contents: String, on day: String, in workspaceID: Int) async throws -> JournalEntry {
        try await call("editJournal", ["workspace_id": workspaceID, "date": day, "content": contents])
    }

    /// Adds `content` on a new line at the end of `day`'s entry, creating it
    /// if nothing was written that day. cohesiond does it in one step, so
    /// nothing written meanwhile is lost.
    public func appendToJournal(_ content: String, on day: String, in workspaceID: Int) async throws {
        let _: JournalEntry = try await call("appendToJournal", ["workspace_id": workspaceID, "date": day, "content": content])
    }

    // MARK: Documents

    /// The workspace's documents, journal entries aside, most recently
    /// modified first. Only the documents' list is kept, not the journal's,
    /// and without what the documents say.
    public func listDocuments(_ type: DocumentType = .normal, in workspaceID: Int) async throws -> [DocumentSummary] {
        try await call(
            "listDocuments",
            ["workspace_id": workspaceID, "document_type": type.rawValue],
            // The list doesn't show the opening.
            keeping: type == .normal ? .blanking(["opening"]) : nil
        )
    }

    public func keptDocuments(in workspaceID: Int) -> [DocumentSummary]? {
        keptReply("listDocuments", ["workspace_id": workspaceID, "document_type": DocumentType.normal.rawValue])
    }

    /// The documents whose title contains `query`, journal entries aside.
    public func searchDocuments(_ query: String, in workspaceID: Int) async throws -> [DocumentSummary] {
        let found: [DocumentSummary] = try await call("searchDocuments", [
            "workspace_id": workspaceID,
            "query": query,
        ])
        return found.filter { $0.type == .normal }
    }

    public func document(_ documentID: Int, in workspaceID: Int) async throws -> Document {
        try await call("getDocument", ["workspace_id": workspaceID, "document_id": documentID])
    }

    public func createDocument(titled title: String, in workspaceID: Int) async throws -> Document {
        try await call("createDocument", ["workspace_id": workspaceID, "title": title, "contents": ""])
    }

    /// Replaces the document's text.
    public func edit(_ document: Document, contents: String) async throws -> Document {
        try await call("editDocument", [
            "workspace_id": document.workspaceID,
            "document_id": document.id,
            "contents": contents,
        ])
    }

    public func rename(_ document: Document, to title: String) async throws -> Document {
        try await call("renameDocument", [
            "workspace_id": document.workspaceID,
            "document_id": document.id,
            "title": title,
        ])
    }

    public func delete(_ document: Document) async throws {
        try await deleteDocument(document.id, in: document.workspaceID)
    }

    /// Deletes a document as a list shows it.
    public func delete(_ document: DocumentSummary) async throws {
        try await deleteDocument(document.id, in: document.workspaceID)
    }

    private func deleteDocument(_ documentID: Int, in workspaceID: Int) async throws {
        let _: JSONValue = try await call("deleteDocument", [
            "workspace_id": workspaceID,
            "document_id": documentID,
        ])
    }

    // MARK: Document folders and tables

    /// The workspace's document folders, each with its parent, in their
    /// order among their siblings; the Inbox isn't one.
    public func listDocumentFolders(in workspaceID: Int) async throws -> [DocumentFolder] {
        try await call("listDocumentFolders", ["workspace_id": workspaceID])
    }

    /// A table's properties, its columns, in their order; none for a
    /// folder that isn't a table.
    public func listProperties(ofFolder folderID: Int, in workspaceID: Int) async throws -> [DocumentFolderProperty] {
        try await call("listDocumentFolderProperties", ["workspace_id": workspaceID, "folder_id": folderID])
    }

    /// A table's rows, the documents in its folder with their values, in the
    /// order they were created.
    public func listRows(ofFolder folderID: Int, in workspaceID: Int) async throws -> [DocumentTableRow] {
        try await call("listTableRows", [
            "workspace_id": workspaceID,
            "folder_id": folderID,
            "filters": [Any](),
        ])
    }

    /// The document in its table's folder as a row, with its values.
    public func tableRow(of document: Document, inFolder folderID: Int) async throws -> DocumentTableRow {
        try await call("getTableRow", [
            "workspace_id": document.workspaceID,
            "folder_id": folderID,
            "document_id": document.id,
        ])
    }

    /// Sets the document's value for one of its table's properties, or
    /// empties it for `nil`; refused for a formula's.
    public func setValue(_ value: PropertyValue?, of property: DocumentFolderProperty, for document: Document) async throws -> DocumentTableRow {
        try await call("setDocumentValue", [
            "workspace_id": document.workspaceID,
            "folder_id": property.folderID,
            "document_id": document.id,
            "property_id": property.id,
            "value": value?.wire,
        ])
    }

    // MARK: Agents

    public func listAgents() async throws -> [Agent] {
        try await call("listIntelligenceAgents", keeping: .whole)
    }

    public func keptAgents() -> [Agent]? {
        keptReply("listIntelligenceAgents")
    }

    /// Pins the agent after the other pinned agents, or unpins it.
    public func setPinned(_ agent: Agent, _ pinned: Bool) async throws -> Agent {
        try await call("setAgentPinned", ["agent_id": agent.id, "pinned": pinned])
    }

    /// Puts the agents in the order of `ids`; replies with them in that order.
    public func reorderAgents(_ ids: [Int]) async throws -> [Agent] {
        try await call("reorderIntelligenceAgents", ["agent_ids": ids])
    }

    /// Puts the agent on team `teamID`, or on none when it's `nil`; its pin
    /// stays as it was.
    public func setTeam(of agent: Agent, to teamID: Int?) async throws -> Agent {
        try await call("setAgentTeam", ["agent_id": agent.id, "team_id": teamID])
    }

    /// A blank name lets cohesiond pick an unused one.
    public func createAgent(
        name: String,
        color: AgentColor,
        emoji: String?,
        personality: AgentPersonality,
        verbosity: AgentVerbosity,
        teamID: Int? = nil
    ) async throws -> Agent {
        try await call("createIntelligenceAgent", [
            "name": name.isEmpty ? nil : name,
            "color": color.rawValue,
            "emoji": emoji,
            "personality": personality.rawValue,
            "verbosity": verbosity.rawValue,
            "team_id": teamID,
        ])
    }

    /// Sends only what differs from `agent`; a blank emoji clears it.
    public func update(
        _ agent: Agent,
        name: String,
        color: AgentColor,
        emoji: String,
        personality: AgentPersonality,
        verbosity: AgentVerbosity
    ) async throws -> Agent {
        try await call("updateIntelligenceAgent", [
            "agent_id": agent.id,
            "name": name == agent.name ? nil : name,
            "color": color == agent.color ? nil : color.rawValue,
            "emoji": emoji == (agent.emoji ?? "") ? nil : emoji,
            "personality": personality == agent.personality ? nil : personality.rawValue,
            "verbosity": verbosity == agent.verbosity ? nil : verbosity.rawValue,
        ])
    }

    public func delete(_ agent: Agent) async throws {
        let _: Agent = try await call("deleteIntelligenceAgent", ["agent_id": agent.id])
    }

    public func listCues(of agentID: Int) async throws -> [AgentCue] {
        try await call("listAgentCues", ["agent_id": agentID])
    }

    public func remove(_ cue: AgentCue) async throws {
        // cohesiond answers `null`.
        let _: JSONValue = try await call("removeAgentCue", ["cue_id": cue.id])
    }

    /// The agent's agenda, in order, finished items included.
    public func listAgenda(of agentID: Int) async throws -> [AgentAgendaItem] {
        try await call("listAgentAgenda", ["agent_id": agentID])
    }

    /// Every skill, each agent's and each team's, by name;
    /// `AgentSkill.of(_:in:)` picks one agent's.
    public func listSkills() async throws -> [AgentSkill] {
        try await call("listAgentSkills")
    }

    /// The `limit` most recent runs, jobs and forks, newest first.
    public func listRuns(of agentID: Int, limit: Int = 50) async throws -> [AgentRun] {
        try await call("listAgentRuns", ["agent_id": agentID, "limit": limit])
    }

    /// The memories the agent sees, oldest first: its own, its team's and
    /// the global ones; only the global ones for `nil`.
    public func listMemories(of agentID: Int?) async throws -> [Memory] {
        let filter: Any = agentID.map { ["seenBy": $0] } ?? "global"
        return try await call("listMemories", ["filter": filter])
    }

    public func forget(_ memory: Memory) async throws {
        let _: Memory = try await call("forgetMemory", ["memory_id": memory.id])
    }

    public func agent(_ agentID: Int) async throws -> Agent {
        try await call("getIntelligenceAgent", ["agent_id": agentID])
    }

    /// The `limit` most recent messages older than message `before`, or
    /// than none when it's `nil`, oldest first.
    public func listMessages(of agentID: Int, before: Int? = nil, limit: Int = 100) async throws -> [AgentMessage] {
        try await call("listAgentMessages", ["agent_id": agentID, "before": before, "limit": limit])
    }

    /// Sends `message`, with `images` attached, forwarding `item` or
    /// running skill `skill` when given (`message` is then its note, and may
    /// be empty; a message does one or the other). cohesiond saves
    /// it and answers at once: a turn the agent is running takes it in, or
    /// it queues the agent's turn on it; what the turn posts arrives with
    /// the agent's change pushes.
    public func send(
        _ message: String,
        images: [AttachmentUpload] = [],
        forwarding item: AgentForwardedItem? = nil,
        running skill: AgentSkill? = nil,
        to agentID: Int,
        resendsIfDropped: Bool = true
    ) async throws {
        // cohesiond answers `null`.
        let _: JSONValue = try await call("sendAgentMessage", [
            "agent_id": agentID,
            "message": message,
            "attachments": images.wireValue,
            "forward": item?.wireValue,
            "skill": skill?.id,
        ], resendsIfDropped: resendsIfDropped)
    }

    /// Sends `text` with `images`, running `skill` when given, with `text` as
    /// its note. A send whose connection dropped (a
    /// timeout, the app suspended) may still have been saved, which
    /// cohesiond keeps answering, so it counts as sent if the agent's
    /// messages since `lastID` hold it, and is sent again only if they
    /// don't and it never reached cohesiond: sending blind would post it twice.
    public func deliver(
        _ text: String,
        images: [AttachmentUpload] = [],
        running skill: AgentSkill? = nil,
        to agentID: Int,
        after lastID: Int
    ) async throws {
        do {
            try await send(text, images: images, running: skill, to: agentID, resendsIfDropped: false)
        } catch let failure as URLError {
            guard let saved = try? await listMessages(of: agentID) else { throw failure }
            if saved.contains(where: {
                $0.id > lastID && $0.sender == .user && $0.typed == text && $0.skillName == skill?.name
            }) { return }
            guard failure.code == .networkConnectionLost else { throw failure }
            try await send(text, images: images, running: skill, to: agentID, resendsIfDropped: false)
        }
    }

    /// Stops the running turn of the agent's conversation: a script it runs
    /// shows as cancelled, and the turn ends without another model call.
    public func stopTurn(of agentID: Int) async throws {
        // cohesiond answers `null`.
        let _: JSONValue = try await call("stopAgentTurn", ["agent_id": agentID])
    }

    /// The images attached to `message`, in the order sent.
    public func attachments(of message: AgentMessage) async throws -> [AgentAttachment] {
        try await call("listAgentMessageAttachments", ["message_ids": [message.id]])
    }

    /// Reacts to the agent's `message` with an emoji, or clears the
    /// reaction with `nil`. cohesiond answers at once, queueing the agent's
    /// turn on the reaction, which may post nothing.
    public func react(to message: AgentMessage, with reaction: String?) async throws {
        let _: JSONValue = try await call("setAgentMessageReaction", [
            "message_id": message.id,
            "reaction": reaction,
        ])
    }

    public func markRead(_ agentID: Int) async throws {
        let _: Agent = try await call("markAgentRead", ["agent_id": agentID])
    }

    public func respond(to proposal: AgentMessage, approve: Bool) async throws {
        let _: AgentMessage = try await call("respondToAgentProposal", [
            "message_id": proposal.id,
            "approve": approve,
        ])
    }

    /// Picks option `option` (an index) of `choice`. cohesiond records it
    /// and answers at once, queueing the agent's turn on it. The pick posts
    /// no message of its own.
    public func pick(_ option: Int, in choice: AgentMessage) async throws {
        let _: JSONValue = try await call("respondToAgentChoice", [
            "message_id": choice.id,
            "option": option,
        ])
    }

    // MARK: Agent teams

    /// Every team, by title; `nil` from a daemon from before teams, which
    /// doesn't know the command.
    public func listAgentTeams() async throws -> [AgentTeam]? {
        do {
            return try await call("listAgentTeams", keeping: .whole)
        } catch let error as ServerError where error.code == ServerError.badRequest {
            return nil
        }
    }

    /// `nil` when none were kept, as from a daemon from before teams.
    public func keptAgentTeams() -> [AgentTeam]? {
        keptReply("listAgentTeams")
    }

    public func createAgentTeam(_ title: String) async throws -> AgentTeam {
        try await call("createAgentTeam", ["title": title])
    }

    public func rename(_ team: AgentTeam, to title: String) async throws -> AgentTeam {
        try await call("renameAgentTeam", ["team_id": team.id, "title": title])
    }

    /// Deletes the team: its agents stay, on no team, and its memories are
    /// forgotten.
    public func delete(_ team: AgentTeam) async throws {
        let _: AgentTeam = try await call("deleteAgentTeam", ["team_id": team.id])
    }

    // MARK: Actors

    /// Every actor the clients offer.
    public func listActors() async throws -> [Actor] {
        try await call("listActors", keeping: .whole)
    }

    public func keptActors() -> [Actor]? {
        keptReply("listActors")
    }

    /// How much of its plan each actor whose client is connected has used;
    /// one whose client never said is left out.
    public func listActorUsage() async throws -> [ActorUsage] {
        try await call("listActorUsage")
    }

    /// Every actor session, latest status change first.
    public func listActorSessions() async throws -> [ActorSession] {
        try await call("listActorSessions", [:], keeping: .whole)
    }

    public func keptActorSessions() -> [ActorSession]? {
        keptReply("listActorSessions", [:])
    }

    /// Marks the session read; the next stretch of work its actor finishes marks it unread again.
    public func markRead(_ session: ActorSession) async throws {
        let _: ActorSession = try await call("markActorSessionRead", ["session_id": session.id])
    }

    public func actorSession(_ sessionID: Int) async throws -> ActorSession {
        try await call("getActorSession", ["id": sessionID])
    }

    /// What was said in session `sessionID`, oldest first.
    public func listMessages(ofActorSession sessionID: Int) async throws -> [ActorSessionMessage] {
        try await call("listActorSessionMessages", ["session_id": sessionID])
    }

    /// The images that came with `message`, in the order sent.
    public func attachments(ofActorSessionMessage message: ActorSessionMessage) async throws -> [ActorSessionAttachment] {
        try await call("listActorSessionMessageAttachments", ["message_ids": [message.id]])
    }

    /// Hands `actor` a new session, `prompt`, with `images` attached, on its
    /// defaults where `nil`. Its client must be online.
    public func startSession(
        on actor: Actor,
        prompt: String,
        images: [AttachmentUpload] = [],
        mode: String?,
        model: String?,
        effort: String?
    ) async throws -> ActorSession {
        try await call("startActorSession", [
            "actor_id": actor.id,
            "prompt": prompt,
            "attachments": images.wireValue,
            "mode": mode,
            "model": model,
            "effort": effort,
        ])
    }

    /// Says `content` in session `sessionID`, with `images` attached: more to do,
    /// which starts a session that is done or failed again, or a response to
    /// one of its requests.
    public func say(
        _ content: ActorUserContent, images: [AttachmentUpload] = [], in sessionID: Int
    ) async throws -> ActorSessionMessage {
        try await call("sendActorSessionMessage", [
            "session_id": sessionID,
            "content": content.arguments,
            "attachments": images.wireValue,
        ])
    }

    /// Runs the session in `mode`, one its actor offers, from its next step on,
    /// even while it works. Its client must be online.
    public func setMode(_ mode: String, of session: ActorSession) async throws -> ActorSession {
        try await call("setActorSessionMode", ["session_id": session.id, "mode": mode])
    }

    /// Stops what the session is doing, leaving it idle until the user says more.
    public func stop(_ session: ActorSession) async throws -> ActorSession {
        try await call("stopActorSession", ["session_id": session.id])
    }

    /// Resolves the session, stopping it first if it is going on: lists leave
    /// it out until the user says more in it.
    public func resolve(_ session: ActorSession) async throws -> ActorSession {
        try await call("resolveActorSession", ["session_id": session.id])
    }

    // MARK: Models

    /// Every client, each saying whether it is connected now.
    public func listClients() async throws -> [Client] {
        try await call("listClients", keeping: .whole)
    }

    public func keptClients() -> [Client]? {
        keptReply("listClients")
    }

    public func rename(_ client: Client, to name: String) async throws {
        let _: JSONValue = try await call("renameClient", ["id": client.id, "client_name": name])
    }

    /// Revokes the client: cohesiond stops trusting its certificate, and
    /// what it offered goes with it.
    public func revoke(_ client: Client) async throws {
        let _: JSONValue = try await call("deleteClient", ["id": client.id])
    }

    public func listEndpoints() async throws -> [IntelligenceEndpoint] {
        try await call("listIntelligenceEndpoints", [:])
    }

    /// Blank `name`, `apiKey` and `usageURL` are left out; the custom
    /// fields are sent only for `.custom`. cohesiond names the endpoint after
    /// its provider when `name` is blank, points it at the provider's usage
    /// page when `usageURL` is, and imports the preset's default model.
    public func createEndpoint(
        preset: EndpointPreset,
        name: String,
        apiKey: String,
        usageURL: String,
        providerIdentifier: String,
        dialect: EndpointDialect,
        baseURL: String
    ) async throws -> IntelligenceEndpoint {
        var args: [String: Any?] = [
            "preset": preset.kind,
            "name": name.isEmpty ? nil : name,
            "api_key": apiKey.isEmpty ? nil : apiKey,
            "usage_url": usageURL.isEmpty ? nil : usageURL,
        ]
        if preset == .custom {
            args["provider_identifier"] = providerIdentifier
            args["dialect"] = dialect.rawValue
            args["base_url"] = baseURL
        }
        return try await call("createIntelligenceEndpoint", args)
    }

    /// Points `endpoint` at the page showing what it has used, or with `nil`
    /// removes it.
    public func setUsageURL(_ url: String?, of endpoint: IntelligenceEndpoint) async throws {
        let _: IntelligenceEndpoint = try await call("setIntelligenceEndpointUsageUrl", [
            "id": endpoint.id,
            "usage_url": url,
        ])
    }

    public func delete(_ endpoint: IntelligenceEndpoint) async throws {
        let _: IntelligenceEndpoint = try await call("deleteIntelligenceEndpoint", ["id": endpoint.id])
    }

    /// The models `endpoint` offers, by name.
    public func listModels(of endpoint: IntelligenceEndpoint) async throws -> [EndpointModel] {
        try await call("listEndpointModels", ["endpoint_id": endpoint.id])
    }

    /// Imports `modelIdentifier` into `endpoint`: linked to the catalog model
    /// of its provider with that identifier, or, for one the catalog doesn't
    /// list, named by its identifier and unpriced.
    public func addModel(_ modelIdentifier: String, to endpoint: IntelligenceEndpoint) async throws -> EndpointModel {
        try await call("addEndpointModel", [
            "endpoint_id": endpoint.id,
            "model_identifier": modelIdentifier,
        ])
    }

    /// Removes `model` from its endpoint; a tier that used it is unset.
    public func remove(_ model: EndpointModel) async throws {
        let _: EndpointModel = try await call("removeEndpointModel", ["id": model.id])
    }

    /// The default of every tier that is set.
    public func listIntelligenceDefaults() async throws -> [IntelligenceDefault] {
        try await call("listIntelligenceDefaults")
    }

    public func setDefault(_ tier: IntelligenceTier, to model: EndpointModel) async throws {
        let _: JSONValue = try await call("setIntelligenceDefault", [
            "tier": tier.rawValue,
            "endpoint_model_id": model.id,
        ])
    }

    public func clearDefault(_ tier: IntelligenceTier) async throws {
        let _: JSONValue = try await call("clearIntelligenceDefault", ["tier": tier.rawValue])
    }

    /// What model calls cost over each spend period, against its limit,
    /// shortest period first.
    public func listIntelligenceSpend() async throws -> [IntelligenceSpend] {
        try await call("listIntelligenceSpend")
    }

    /// Limits what every model call together may cost over `period` to
    /// `amount` US dollars, replacing its limit if it has one.
    @discardableResult
    public func setSpendLimit(_ period: SpendPeriod, to amount: Double) async throws -> [IntelligenceSpend] {
        try await call("setIntelligenceSpendLimit", ["period": period.rawValue, "amount": amount])
    }

    /// Removes `period`'s spend limit.
    @discardableResult
    public func clearSpendLimit(_ period: SpendPeriod) async throws -> [IntelligenceSpend] {
        try await call("clearIntelligenceSpendLimit", ["period": period.rawValue])
    }

    /// Catalog models of `providerIdentifier`, or of every configured
    /// endpoint's provider.
    public func listCatalogModels(of providerIdentifier: String? = nil) async throws -> [CatalogModel] {
        try await call("listCatalogModels", ["provider_identifier": providerIdentifier])
    }

    /// Asks cohesiond to refresh its catalog from the providers.
    public func updateModelCatalog() async throws {
        let _: JSONValue = try await call("updateModelCatalog", [:])
    }

    // MARK: Connectors

    /// Every connector account, by description, then connector. Kept whole,
    /// so the sidebar shows the workspace's kinds at once.
    public func listConnectorAccounts() async throws -> [ConnectorAccount] {
        try await call("listConnectorAccounts", keeping: .whole)
    }

    public func keptConnectorAccounts() -> [ConnectorAccount]? {
        keptReply("listConnectorAccounts")
    }

    /// The kinds of resource the workspace shows, in their order.
    public func listResourceKinds(in workspaceID: Int) async throws -> [WorkspaceResourceKind] {
        try await call("listWorkspaceResourceKinds", ["workspace_id": workspaceID], keeping: .whole)
    }

    public func keptResourceKinds(in workspaceID: Int) -> [WorkspaceResourceKind]? {
        keptReply("listWorkspaceResourceKinds", ["workspace_id": workspaceID])
    }

    /// Shows the kind in the workspace, last, or hides it there; a hidden
    /// kind keeps its resources. Replies with the kinds shown now.
    public func setResourceKind(_ kindID: Int, shown: Bool, in workspaceID: Int) async throws -> [WorkspaceResourceKind] {
        try await call("setResourceKindShown", ["workspace_id": workspaceID, "kind_id": kindID, "shown": shown])
    }

    /// Puts the kinds the workspace shows in the order of `kindIDs`, every
    /// one of them; replies with them in that order.
    public func reorderResourceKinds(_ kindIDs: [Int], in workspaceID: Int) async throws -> [WorkspaceResourceKind] {
        try await call("reorderWorkspaceResourceKinds", ["workspace_id": workspaceID, "kind_ids": kindIDs])
    }

    /// The workspace's resources of `kind` in `sort`'s order; those
    /// without a value for it come last either way.
    public func listResources(
        of kind: ConnectorKind,
        in workspaceID: Int,
        sort: ResourceSort,
        descending: Bool
    ) async throws -> [Resource] {
        try await call("listResources", [
            "workspace_id": workspaceID,
            "kind": kind.name,
            "sort": sort.wireValue,
            "descending": descending,
        ])
    }

    public func resource(_ resourceID: Int, in workspaceID: Int) async throws -> Resource {
        try await call("getResource", ["workspace_id": workspaceID, "resource_id": resourceID])
    }

    /// Removes the resource from the workspace; a refresh won't bring it
    /// back, but importing it again does.
    public func removeResource(_ resourceID: Int, in workspaceID: Int) async throws {
        let _: JSONValue = try await call("deleteResource", ["workspace_id": workspaceID, "resource_id": resourceID])
    }

    /// Asks each connector for the latest copy of every resource in the
    /// workspace; the changed ones arrive by invalidation.
    public func refreshResources(in workspaceID: Int) async throws -> ResourceRefreshSummary {
        try await call("refreshResources", ["workspace_id": workspaceID])
    }

    /// The groups the account files its items under.
    public func listOrganizationUnits(of account: ConnectorAccount) async throws -> [OrganizationUnit] {
        try await call("listConnectorOrganizationUnits", ["account_id": account.id])
    }

    /// What the account offers to import of `kindID`, in one group or all
    /// of them, matching `search` if there is one, marking what the
    /// workspace already has.
    public func searchImportableResources(
        of account: ConnectorAccount,
        kind kindID: Int,
        unit unitID: String?,
        search: String?,
        in workspaceID: Int
    ) async throws -> [ImportableResource] {
        try await call("searchConnectorResources", [
            "account_id": account.id,
            "workspace_id": workspaceID,
            "kind_id": kindID,
            "organization_unit_id": unitID,
            "search": search,
        ])
    }

    /// Imports the item into the workspace, or refreshes it if it's
    /// already there. A client's account imports only while it is online.
    public func importResource(_ identifier: String, from account: ConnectorAccount, into workspaceID: Int) async throws -> Resource {
        try await call("importResource", [
            "account_id": account.id,
            "workspace_id": workspaceID,
            "identifier": identifier,
        ])
    }

    // MARK: Extensions

    /// Every installed extension, in the order its hooks run.
    public func listExtensions() async throws -> [ExtensionSummary] {
        try await call("listExtensions")
    }

    public func listPermissions(of extensionSummary: ExtensionSummary) async throws -> [ExtensionPermission] {
        try await call("listExtensionPermissions", ["extension_ids": [extensionSummary.id]])
    }

    /// Grants or revokes `permission`; cohesiond restarts the extension's
    /// sandbox so it applies at once.
    public func setPermission(
        _ permission: ExtensionPermissionKind, of extensionSummary: ExtensionSummary, enabled: Bool
    ) async throws {
        let _: JSONValue = try await call("setExtensionPermission", [
            "extension_id": extensionSummary.id,
            "permission": permission.rawValue,
            "enabled": enabled,
        ])
    }

    public func listHooks(of extensionSummary: ExtensionSummary) async throws -> [ExtensionHook] {
        try await call("listExtensionHooks", ["extension_ids": [extensionSummary.id]])
    }

    /// Turns `hook` on or off; it applies the next time the hook fires.
    public func setHook(_ hook: HookKind, of extensionSummary: ExtensionSummary, enabled: Bool) async throws {
        let _: JSONValue = try await call("setExtensionHook", [
            "extension_id": extensionSummary.id,
            "hook": hook.rawValue,
            "enabled": enabled,
        ])
    }

    /// Removes the extension: cohesiond stops its sandbox and timers and
    /// drops its grants.
    public func uninstall(_ extensionSummary: ExtensionSummary) async throws {
        let _: JSONValue = try await call("uninstallExtension", ["extension_id": extensionSummary.id])
    }

    /// Asks every registry (an extension granted `registry`) for the
    /// extensions it offers matching `query`; `""` lists what it features.
    public func searchRegistries(for query: String) async throws -> [RegistrySection] {
        try await call("searchExtensionRegistries", ["query": query])
    }

    /// Downloads the script at `sourceURL` and reads its manifest, without
    /// installing it.
    public func previewExtension(at sourceURL: String) async throws -> ExtensionPreview {
        try await call("previewExtension", ["source_url": sourceURL])
    }

    /// Reads the manifest of a script from a file or the clipboard, without
    /// installing it.
    public func previewExtension(script: String) async throws -> ExtensionPreview {
        try await call("previewExtensionScript", ["script": script])
    }

    /// Installs `script`, or with `replacing` replaces the installed
    /// extension with its identifier. A new install starts with every
    /// permission and hook off; a replaced one keeps its grants.
    public func installExtension(_ script: String, replacing: Bool) async throws {
        let _: JSONValue = try await call("registerExtension", [
            "script": script,
            "allow_overwrite": replacing,
        ])
    }

    /// Runs client function `name` of the extension whose manifest declares
    /// `identifier`. cohesiond answers `notFound` when no such extension is
    /// installed, and refuses unless the user enabled its `service` permission.
    public func callExtension(_ identifier: String, _ name: String, args: [String: Any]? = nil) async throws -> JSONValue {
        let reply: ExtensionCallResult = try await call("callExtension", [
            "identifier": identifier,
            "name": name,
            "args": args,
        ])
        return reply.result
    }
}

/// Converts between dates and cohesiond's `"YYYY-MM-DD"` calendar days.
public enum CalendarDay {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public static func string(_ date: Date) -> String {
        formatter.string(from: date)
    }

    public static func date(_ string: String) -> Date? {
        formatter.date(from: string)
    }
}
