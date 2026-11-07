import CohesionCore
import CohesionUI
import SwiftUI

/// A note for today's journal entry, added as a paragraph of its own after
/// whatever the entry holds, which creates the entry if there's none yet. It
/// closes once the note is in; a failure stays open with the note and says so.
struct QuickJournalSheet: View {
    let workspaceID: Int
    /// Called once cohesiond has the note, as the sheet closes.
    let onAdded: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var note = ""
    @State private var isAdding = false
    @State private var error: (any Error)?
    @FocusState private var isWriting: Bool

    private var trimmed: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                TextField("Write about today…", text: $note, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(4...10)
                    .focused($isWriting)
                Spacer(minLength: 0)
            }
            .padding()
            // Anywhere on the sheet's paper puts the cursor in the field.
            .contentShape(.rect)
            .onTapGesture { isWriting = true }
            .navigationTitle("Quick Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                        .disabled(isAdding)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to Journal", systemImage: "checkmark", role: .confirm, action: add)
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(trimmed.isEmpty || isAdding)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isAdding)
        .onAppear { isWriting = true }
        .errorAlert($error)
    }

    private func add() {
        guard let client = model.client else { return }
        let text = trimmed
        let day = CalendarDay.string(.now)
        isAdding = true
        Task {
            do {
                let entry = try await client.journalEntry(on: day, in: workspaceID)
                // cohesiond starts a new line; a blank one before it makes a
                // paragraph, unless the entry already ends on a line of its own.
                let contents = entry?.contents ?? ""
                let needsBlankLine = !contents.isEmpty && !contents.hasSuffix("\n")
                try await client.appendToJournal((needsBlankLine ? "\n" : "") + text, on: day, in: workspaceID)
                onAdded()
                dismiss()
            } catch {
                self.error = error
            }
            isAdding = false
        }
    }
}
