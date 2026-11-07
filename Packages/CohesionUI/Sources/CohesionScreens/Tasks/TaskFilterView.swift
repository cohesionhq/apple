import CohesionCore
import CohesionUI
import SwiftUI

/// A sheet that narrows a task list: the priorities and sizes a listed
/// task has one of, and for each tag whether a listed task must have it, must not, or
/// either. Changes apply as they are made.
struct TaskFilterView: View {
    @Binding var query: TaskQuery
    /// The workspace's task tags, by name.
    let tags: [Tag]

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(model.vocabulary.taskPriorities, id: \.kind) { priority in
                        Toggle(priority.label, isOn: Binding {
                            query.priorities.contains(priority.kind)
                        } set: {
                            if $0 {
                                query.priorities.insert(priority.kind)
                            } else {
                                query.priorities.remove(priority.kind)
                            }
                        })
                    }
                } header: {
                    Text("Priority")
                } footer: {
                    Text("With none on, every priority is listed.")
                }
                // A cohesiond older than sizes names none.
                if !model.vocabulary.taskSizes.isEmpty {
                    Section {
                        ForEach(model.vocabulary.taskSizes, id: \.kind) { size in
                            Toggle(size.label, isOn: Binding {
                                query.sizes.contains(size.kind)
                            } set: {
                                if $0 {
                                    query.sizes.insert(size.kind)
                                } else {
                                    query.sizes.remove(size.kind)
                                }
                            })
                        }
                    } header: {
                        Text("Size")
                    } footer: {
                        Text("With none on, every task is listed, sized or not.")
                    }
                }
                Section {
                    ForEach(tags) { tag in
                        Picker(tag.name, selection: match(of: tag)) {
                            Text("Either").tag(TagMatch.either)
                            Text("With").tag(TagMatch.with)
                            Text("Without").tag(TagMatch.without)
                        }
                    }
                    if tags.isEmpty {
                        Text("No tags yet.")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Tags")
                } footer: {
                    if !tags.isEmpty {
                        Text("Lists tasks with every tag marked With, and none marked Without.")
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear", systemImage: "arrow.counterclockwise") { query.clearFilters() }
                    .disabled(!query.isFiltered)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Whether a listed task must have a tag, must not, or either.
    private enum TagMatch {
        case either, with, without
    }

    private func match(of tag: Tag) -> Binding<TagMatch> {
        Binding {
            if query.tags.with.contains(tag.id) { .with }
            else if query.tags.without.contains(tag.id) { .without }
            else { .either }
        } set: { match in
            query.tags.with.remove(tag.id)
            query.tags.without.remove(tag.id)
            switch match {
            case .either: break
            case .with: query.tags.with.insert(tag.id)
            case .without: query.tags.without.insert(tag.id)
            }
        }
    }
}
