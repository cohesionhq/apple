import CohesionCore
import CohesionMarkdown
import CohesionUI
import SwiftUI

/// A day's journal entry in the Markdown editor, today's unless it's given
/// another. Edits save themselves a moment after typing stops, and when the
/// journal closes or the app leaves the foreground; nothing is saved for a
/// day until something is written.
struct JournalView: View {
    let workspaceID: Int
    /// The day to show, as `"YYYY-MM-DD"`; today's when nil.
    var entryDay: String?

    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    /// Today, as `"YYYY-MM-DD"`; saves go to it until the app next comes
    /// back on a later day.
    @State private var today = CalendarDay.string(.now)
    @State private var text = ""
    /// The text cohesiond last confirmed; the draft is unsaved while `text`
    /// differs from it.
    @State private var saved = ""
    @State private var isLoaded = false
    /// The entry's document, which "Forward" names; `nil` until something
    /// is written that day.
    @State private var entryID: Int?
    @State private var saveTask: Task<Void, Never>?
    @State private var error: (any Error)?

    /// How long typing has to pause before the draft saves.
    private static let saveDelay = Duration.milliseconds(800)

    var body: some View {
        Group {
            if isLoaded {
                MarkdownEditor(text: $text, padding: 16)
                    // Text scrolls on under the home indicator; the text
                    // view insets its content for it, so the last line still
                    // clears it. The keyboard still shortens the view.
                    .ignoresSafeArea(.container, edges: .bottom)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty && entryDay == nil {
                            Text("Write about today…")
                                .foregroundStyle(.tertiary)
                                .padding(16)
                                .allowsHitTesting(false)
                        }
                    }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(entryDay == nil ? "Today" : dayName)
        .navigationSubtitle(entryDay == nil ? dayName : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let entryID {
                ToolbarItem(placement: .secondaryAction) {
                    ForwardMenu(item: AgentForwardedItem(
                        kind: .journal, workspaceID: workspaceID, id: entryID, title: day
                    ))
                }
            }
        }
        .forwardsItems()
        .onChange(of: text) { scheduleSave() }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task { await turnTheDay() }
            } else {
                saveNow()
            }
        }
        .onDisappear { saveNow() }
        .task { await watch() }
        .errorAlert($error)
    }

    /// The day being written.
    private var day: String { entryDay ?? today }

    private var dayName: String {
        CalendarDay.date(day)!.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    /// Moves on to a new day's entry once yesterday's is saved; a day given
    /// to the view stays put.
    private func turnTheDay() async {
        let now = CalendarDay.string(.now)
        guard entryDay == nil, now != today, text == saved else { return }
        today = now
        isLoaded = false
        entryID = nil
        saved = ""
        text = ""
        await load()
    }

    /// Takes cohesiond's copy, unless the draft has edits it doesn't have
    /// yet; those win, and their save brings it back here.
    private func load(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client, text == saved else { return }
        await origin.run {
            let entry = try await client.journalEntry(on: day, in: workspaceID)
            let contents = entry?.contents ?? ""
            entryID = entry?.id ?? entryID
            // Typing during the fetch keeps the draft.
            guard text == saved else { return }
            saved = contents
            text = contents
            isLoaded = true
        } failed: { self.error = $0 }
    }

    /// Keeps the entry current while it is shown, so a write from another
    /// client or an agent lands; the stream also yields once on connecting,
    /// which does the first load.
    private func watch() async {
        guard let client = model.client else { return }
        let workspaceID = workspaceID
        for await origin in client.loads(matching: {
            // The entry may not exist yet, so any document's text, not just its id's.
            switch $0 {
            case .documents(workspaceID), .documentText(workspaceID, _): true
            default: false
            }
        }) {
            await load(origin)
        }
    }

    /// Saves once typing pauses. Each keystroke restarts the wait, and
    /// cancels a save still in flight, whose text the next one carries.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            do { try await Task.sleep(for: Self.saveDelay) } catch { return }
            await save()
        }
    }

    private func saveNow() {
        saveTask?.cancel()
        saveTask = Task { await save() }
    }

    private func save() async {
        guard let client = model.client else { return }
        let contents = text
        guard contents != saved else { return }
        do {
            entryID = try await client.writeJournal(contents, on: day, in: workspaceID).id
            saved = contents
        } catch where !Task.isCancelled {
            self.error = error
        } catch {}
    }
}
