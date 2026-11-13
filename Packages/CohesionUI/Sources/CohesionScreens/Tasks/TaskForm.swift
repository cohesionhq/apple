import CohesionCore
import CohesionMarkdown
import CohesionUI
import SwiftUI

/// The fields of a task, shared by the new-task sheet and the task detail screen.
struct TaskForm: View {
    @Binding var draft: TaskDraft
    /// The task's workspace, whose tags the form lists and creates.
    let workspaceID: Int
    let folders: [TaskFolder]
    /// The workspace's tags as the screen opening the form had them, shown
    /// until the form lists them itself.
    let tags: [Tag]
    /// New tasks always start incomplete, so only existing ones show a status.
    var showsStatus = false
    /// Only existing tasks are assigned, as on the web; to the user, an
    /// agent or one of `contacts`.
    var showsAssignee = false
    /// The task's workspace's contacts, for the assignee picker.
    var contacts: [Contact] = []
    /// A new task's title takes the keyboard when the form first appears.
    var focusesTitle = false

    @Environment(AppModel.self) private var model

    @FocusState private var isTitleFocused: Bool
    /// Set once the title has taken focus, so coming back from the notes
    /// editor doesn't raise the keyboard again.
    @State private var hasFocusedTitle = false
    /// The workspace's tags as last listed here, kept current as cohesiond
    /// changes them, so one created from the picker shows at once.
    @State private var listedTags: [Tag]?

    private var shownTags: [Tag] { listedTags ?? tags }

    var body: some View {
        Form {
            Section {
                // The task's name heads the sheet, above what's said of it.
                TextField("Title", text: $draft.title)
                    .font(.title3.weight(.semibold))
                    .focused($isTitleFocused)
            }
            // Notes are Markdown: read rendered here, written in their own
            // editor, as a document is.
            Section("Notes") {
                if !draft.description.isEmpty {
                    MarkdownText(markdown: draft.description)
                }
                NavigationLink(draft.description.isEmpty ? "Add Notes" : "Edit Notes") {
                    NotesEditor(text: $draft.description)
                }
            }
            Section {
                if showsStatus {
                    Picker("Status", selection: $draft.status) {
                        ForEach(TaskStatus.allCases) { Text($0.label).tag($0) }
                    }
                    // A value in secondary, as Settings shows one, so the
                    // accent stays on what acts.
                    .tint(.secondary)
                }
                if showsAssignee {
                    AssigneePicker(selection: $draft.assignee, contacts: contacts)
                        .tint(.secondary)
                }
                Picker("Priority", selection: $draft.priority) {
                    ForEach(model.vocabulary.taskPriorities, id: \.kind) { PriorityLabel(priority: $0).tag($0.kind) }
                }
                .tint(.secondary)
                // A cohesiond older than sizes names none.
                if model.vocabulary.taskSizes.count > 1 {
                    SizeSlider(size: $draft.size, sizes: model.vocabulary.taskSizes)
                }
                Picker("Folder", selection: $draft.folderID) {
                    Text("Inbox").tag(Int?.none)
                    ForEach(folders) { Text($0.title).tag(Optional($0.id)) }
                }
                .tint(.secondary)
                // Shown with no tags too, since the picker creates them.
                NavigationLink {
                    TagPicker(selection: $draft.tagIDs, tags: shownTags, create: createTag)
                } label: {
                    LabeledContent("Tags") {
                        let names = shownTags.filter { draft.tagIDs.contains($0.id) }.map(\.name)
                        // A value whatever it holds, as the rows around it have.
                        if names.isEmpty {
                            Text("None")
                        } else {
                            Text(names, format: .list(type: .and))
                        }
                    }
                }
            }
            Section {
                OptionalDatePicker("Start Date", selection: $draft.startDate)
                OptionalDatePicker("Due Date", selection: $draft.dueDate)
            }
        }
        .onAppear {
            guard focusesTitle, !hasFocusedTitle else { return }
            hasFocusedTitle = true
            isTitleFocused = true
        }
        .task(id: workspaceID) { await watchTags() }
    }

    /// Lists the workspace's tags again whenever cohesiond changes them; a
    /// failed listing keeps the ones shown.
    private func watchTags() async {
        guard let client = model.client else { return }
        for await _ in client.changes(matching: { $0 == .tags(workspaceID: workspaceID) }) {
            if let tags = try? await client.listTaskTags(in: workspaceID) { listedTags = tags }
        }
    }

    /// Creates a tag named `name` and puts it on the task, listing the
    /// tags again so it shows without waiting for the invalidation.
    private func createTag(named name: String) async throws {
        guard let client = model.client else { return }
        let tag = try await client.createTaskTag(named: name, in: workspaceID)
        listedTags = try await client.listTaskTags(in: workspaceID)
        draft.tagIDs.insert(tag.id)
    }
}

/// A task's or a contact's notes in the Markdown editor. Edits go to the
/// draft, so they save with the rest of the form.
struct NotesEditor: View {
    @Binding var text: String

    var body: some View {
        MarkdownEditor(text: $text, padding: 16)
            // As a document: text scrolls on under the home indicator, and
            // the keyboard still shortens the view.
            .ignoresSafeArea(.container, edges: .bottom)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Start writing…")
                        .foregroundStyle(.tertiary)
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// The workspace's tags, each checked when it is on the task, and a field
/// that creates one and puts it on.
private struct TagPicker: View {
    @Binding var selection: Set<Int>
    let tags: [Tag]
    /// Creates a tag by the name given and checks it.
    let create: (String) async throws -> Void

    @State private var name = ""
    @State private var isCreating = false
    @State private var error: (any Error)?

    var body: some View {
        List {
            if !tags.isEmpty {
                Section {
                    ForEach(tags) { tag in
                        Button {
                            if selection.contains(tag.id) {
                                selection.remove(tag.id)
                            } else {
                                selection.insert(tag.id)
                            }
                        } label: {
                            HStack {
                                Text(tag.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selection.contains(tag.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .accessibilityAddTraits(selection.contains(tag.id) ? .isSelected : [])
                    }
                }
            }
            Section {
                TextField("New Tag", text: $name)
                    .onSubmit(createTag)
                Button("Create", action: createTag)
                    .disabled(isCreating || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Tags")
        .errorAlert($error)
    }

    private func createTag() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isCreating else { return }
        isCreating = true
        Task {
            do {
                try await create(trimmed)
                name = ""
            } catch {
                self.error = error
            }
            isCreating = false
        }
    }
}

/// A task's size on a slider, smallest to largest, named by the vocabulary
/// above it, with a button that clears it. With no size it reads None with a
/// button that sets the middle one and brings the slider.
private struct SizeSlider: View {
    @Binding var size: TaskSize?
    /// Smallest to largest; at least two.
    let sizes: [Vocabulary.SizeWording]

    @Environment(AppModel.self) private var model

    var body: some View {
        if let size {
            let label = model.vocabulary.label(of: size)
            VStack(alignment: .leading) {
                HStack {
                    Text("Size")
                    Spacer()
                    Text(label)
                        .foregroundStyle(.secondary)
                    Button("Clear Size", systemImage: "xmark.circle.fill") {
                        withAnimation { self.size = nil }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.tertiary)
                }
                Slider(value: position(of: size), in: 0...Double(sizes.count - 1), step: 1) {
                    Text("Size")
                }
                .accessibilityValue(label)
            }
        } else {
            // One control, rather than "None" beside a button.
            LabeledContent("Size") {
                Button("Set Size") {
                    withAnimation { size = sizes[sizes.count / 2].kind }
                }
                .buttonStyle(.borderless)
            }
        }
    }

    /// The size's place among `sizes`.
    private func position(of size: TaskSize) -> Binding<Double> {
        Binding {
            Double(sizes.firstIndex { $0.kind == size } ?? sizes.count / 2)
        } set: {
            self.size = sizes[Int($0.rounded())].kind
        }
    }
}

/// A toggle that, when on, shows a date picker for a day that may be unset.
private struct OptionalDatePicker: View {
    let title: LocalizedStringKey
    @Binding var selection: Date?

    init(_ title: LocalizedStringKey, selection: Binding<Date?>) {
        self.title = title
        _selection = selection
    }

    var body: some View {
        Toggle(title, isOn: Binding(
            get: { selection != nil },
            set: { selection = $0 ? Calendar.current.startOfDay(for: .now) : nil }
        ))
        if let date = selection {
            DatePicker(
                title,
                selection: Binding(get: { date }, set: { selection = $0 }),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
        }
    }
}

/// A sheet for adding a task to a workspace.
struct NewTaskView: View {
    let workspaceID: Int
    let folders: [TaskFolder]
    let tags: [Tag]
    let onAdd: () async -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var draft = TaskDraft()
    @State private var isSaving = false
    @State private var error: (any Error)?

    /// Files the new task in `folderID` unless the user picks another, and
    /// starts it with `tagIDs`, the ones the list asks for.
    init(
        workspaceID: Int,
        folderID: Int?,
        tagIDs: Set<Int>,
        folders: [TaskFolder],
        tags: [Tag],
        onAdd: @escaping () async -> Void
    ) {
        self.workspaceID = workspaceID
        self.folders = folders
        self.tags = tags
        self.onAdd = onAdd
        var draft = TaskDraft()
        draft.folderID = folderID
        draft.tagIDs = tagIDs
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            TaskForm(draft: $draft, workspaceID: workspaceID, folders: folders, tags: tags, focusesTitle: true)
                .navigationTitle("New Task")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add", systemImage: "checkmark", role: .confirm, action: add)
                            .disabled(draft.title.isEmpty || isSaving)
                    }
                }
                .errorAlert($error)
        }
    }

    private func add() {
        guard let client = model.client else { return }
        isSaving = true
        Task {
            do {
                _ = try await client.createTask(draft, in: workspaceID)
                await onAdd()
                dismiss()
            } catch {
                self.error = error
            }
            isSaving = false
        }
    }
}

/// A sheet for editing an existing task, sending only the fields that changed.
struct TaskDetailView: View {
    let task: TaskItem
    let folders: [TaskFolder]
    let tags: [Tag]
    /// The task's workspace's contacts, who it can be assigned to.
    let contacts: [Contact]
    let onSave: () async -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var draft: TaskDraft
    @State private var isSaving = false
    @State private var error: (any Error)?

    init(
        task: TaskItem,
        folders: [TaskFolder],
        tags: [Tag],
        contacts: [Contact],
        onSave: @escaping () async -> Void
    ) {
        self.task = task
        self.folders = folders
        self.tags = tags
        self.contacts = contacts
        self.onSave = onSave
        _draft = State(initialValue: TaskDraft(task))
    }

    var body: some View {
        NavigationStack {
            TaskForm(
                draft: $draft,
                workspaceID: task.workspaceID,
                folders: folders,
                tags: tags,
                showsStatus: true,
                showsAssignee: true,
                contacts: contacts
            )
                .navigationTitle("Task")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm, action: save)
                            .disabled(draft == TaskDraft(task) || draft.title.isEmpty || isSaving)
                    }
                }
                .errorAlert($error)
        }
        // Unsaved edits aren't lost to a stray swipe.
        .interactiveDismissDisabled(draft != TaskDraft(task))
    }

    private func save() {
        guard let client = model.client else { return }
        isSaving = true
        Task {
            do {
                try await client.update(task, to: draft)
                await onSave()
                dismiss()
            } catch {
                self.error = error
            }
            isSaving = false
        }
    }
}
