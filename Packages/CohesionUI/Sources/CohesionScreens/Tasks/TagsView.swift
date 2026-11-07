import CohesionCore
import CohesionUI
import SwiftUI

/// A sheet that creates the workspace's task tags, renames one in place
/// (Return or leaving the field saves) and deletes them.
struct TagsView: View {
    let workspaceID: Int
    /// The workspace's task tags, kept current as cohesiond changes them.
    let tags: [Tag]

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    /// Each row's field, as typed; a row not in it shows the tag's own name.
    @State private var drafts: [Int: String] = [:]
    /// The names being saved, so Return and then leaving the field save once.
    @State private var renaming: [Int: String] = [:]
    @FocusState private var focused: Int?
    @State private var deleting: Tag?
    @State private var isCreating = false
    @State private var error: (any Error)?

    var body: some View {
        NavigationStack {
            Form {
                if !tags.isEmpty {
                    Section {
                        ForEach(tags) { tag in
                            TextField(tag.name, text: Binding {
                                drafts[tag.id] ?? tag.name
                            } set: {
                                drafts[tag.id] = $0
                            })
                            .focused($focused, equals: tag.id)
                            .onSubmit { rename(tag) }
                            .swipeActions {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    deleting = tag
                                }
                            }
                        }
                    }
                }
                Section {
                    TextField("New Tag", text: $name)
                        .onSubmit(create)
                    Button("Create", action: create)
                        .disabled(isCreating || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) {
                        if let tag = tags.first(where: { $0.id == focused }) { rename(tag) }
                        dismiss()
                    }
                }
            }
            .onChange(of: focused) { left, _ in
                if let tag = tags.first(where: { $0.id == left }) { rename(tag) }
            }
            .onChange(of: tags) {
                // A saved name now shows as the tag's own; a deleted tag has no row.
                drafts = drafts.filter { id, draft in
                    tags.contains { $0.id == id && $0.name != draft }
                }
            }
            .confirmationDialog(
                deleting.map { "Delete “\($0.name)”?" } ?? "",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible,
                presenting: deleting
            ) { tag in
                Button("Delete Tag", role: .destructive) { delete(tag) }
            } message: { _ in
                Text("It comes off every task it’s on.")
            }
            .errorAlert($error)
        }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let client = model.client, !trimmed.isEmpty, !isCreating else { return }
        isCreating = true
        Task {
            do {
                _ = try await client.createTaskTag(named: trimmed, in: workspaceID)
                name = ""
            } catch {
                self.error = error
            }
            isCreating = false
        }
    }

    /// Saves the row's field; an empty or unchanged one goes back to the
    /// tag's own name.
    private func rename(_ tag: Tag) {
        guard let client = model.client, let draft = drafts[tag.id] else { return }
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != tag.name else {
            drafts[tag.id] = nil
            return
        }
        guard renaming[tag.id] != trimmed else { return }
        renaming[tag.id] = trimmed
        Task {
            do {
                try await client.rename(tag, to: trimmed)
            } catch {
                self.error = error
            }
            renaming[tag.id] = nil
        }
    }

    private func delete(_ tag: Tag) {
        guard let client = model.client else { return }
        Task {
            do {
                try await client.delete(tag)
            } catch {
                self.error = error
            }
        }
    }
}
