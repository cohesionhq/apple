import CohesionCore
import CohesionMarkdown
import CohesionUI
import SwiftUI

/// A document in the Markdown editor, titled in the navigation bar, where
/// tapping the title renames it. Edits save themselves a moment after
/// typing stops, and when the document closes or the app leaves the
/// foreground, as the journal's do. A row of a table has its properties in
/// an inspector, beside it on iPad and a sheet on iPhone.
struct DocumentView: View {
    let workspaceID: Int
    let documentID: Int

    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    /// The document as cohesiond last sent it; `nil` until it loads.
    @State private var document: Document?
    @State private var title = ""
    @State private var text = ""
    /// The text cohesiond last confirmed; the draft is unsaved while `text`
    /// differs from it.
    @State private var saved = ""
    @State private var saveTask: Task<Void, Never>?
    /// Its table's properties, none unless it's a row of one.
    @State private var properties: [DocumentFolderProperty] = []
    /// Its values, as a row of its table.
    @State private var row: DocumentTableRow?
    @State private var showsProperties = false
    @State private var isConfirmingDelete = false
    /// Set once deleting starts, so the change it announces doesn't load it.
    @State private var isDeleted = false
    @State private var error: (any Error)?

    /// How long typing has to pause before the draft saves.
    private static let saveDelay = Duration.milliseconds(800)

    var body: some View {
        Group {
            if document != nil {
                MarkdownEditor(text: $text, padding: 16)
                    // As in the journal: text scrolls on under the home
                    // indicator, and the keyboard still shortens the view.
                    .ignoresSafeArea(.container, edges: .bottom)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Start writing…")
                                .foregroundStyle(.tertiary)
                                .padding(16)
                                .allowsHitTesting(false)
                        }
                    }
            } else {
                ProgressView()
            }
        }
        .navigationTitle($title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.editor)
        .toolbar {
            if !properties.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Properties", systemImage: "info.circle") {
                        showsProperties.toggle()
                    }
                }
            }
            ToolbarItemGroup(placement: .secondaryAction) {
                Button("Copy as Markdown", systemImage: "doc.on.doc") {
                    Pasteboard.general.string = text
                }
                if let document {
                    ForwardMenu(item: AgentForwardedItem(
                        kind: document.type == .journal ? .journal : .document,
                        workspaceID: document.workspaceID,
                        id: document.id,
                        title: document.journalDate ?? document.title
                    ))
                }
                Button("Delete…", systemImage: "trash", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
        }
        .confirmationDialog(
            "Delete “\(document?.title ?? title)”?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Document", role: .destructive, action: delete)
        } message: {
            Text("Can’t be undone.")
        }
        .inspector(isPresented: Binding { showsProperties && !properties.isEmpty } set: { showsProperties = $0 }) {
            if let document {
                DocumentPropertiesForm(document: document, properties: properties, row: $row)
                    .presentationDetents([.medium, .large])
            }
        }
        .onChange(of: title) { rename() }
        .onChange(of: text) { scheduleSave() }
        .onChange(of: scenePhase) {
            if scenePhase != .active { saveNow() }
        }
        .onDisappear { saveNow() }
        .task { await watch() }
        .task(id: document?.folderID) { await watchTable() }
        .forwardsItems()
        .errorAlert($error)
    }

    /// Takes cohesiond's copy, unless the draft has edits it doesn't have
    /// yet; those win, and their save brings it back here.
    private func load(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client, text == saved, !isDeleted else { return }
        await origin.run {
            let loaded = try await client.document(documentID, in: workspaceID)
            // Typing during the fetch keeps the draft.
            guard text == saved else { return }
            document = loaded
            title = loaded.title
            saved = loaded.contents
            text = loaded.contents
        } failed: { self.error = $0 }
    }

    /// Keeps the document current while it is shown, so a write from
    /// another client or an agent lands; the stream also yields once on
    /// connecting, which does the first load.
    private func watch() async {
        guard let client = model.client else { return }
        let workspaceID = workspaceID
        let documentID = documentID
        for await origin in client.loads(matching: {
            switch $0 {
            case .documents(workspaceID), .documentText(workspaceID, documentID): true
            default: false
            }
        }) {
            await load(origin)
        }
    }

    /// Keeps the document's properties and values current while it's a row
    /// of a table; the stream also yields once, which does the first load.
    /// A document in the Inbox or a plain folder has none.
    private func watchTable() async {
        guard let client = model.client, let document, let folderID = document.folderID else {
            properties = []
            row = nil
            return
        }
        for await origin in client.loads(matching: { $0 == .documentTable(folderID: folderID) }) {
            await origin.run {
                async let loadedProperties = client.listProperties(ofFolder: folderID, in: document.workspaceID)
                async let loadedRow = client.tableRow(of: document, inFolder: folderID)
                let (properties, row) = try await (loadedProperties, loadedRow)
                self.properties = properties
                self.row = properties.isEmpty ? nil : row
            } failed: { self.error = $0 }
        }
    }

    /// Sends a title the bar committed; one cohesiond refuses goes back to
    /// the one it has.
    private func rename() {
        guard let client = model.client, let document else { return }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard trimmed != document.title else { return }
        Task {
            do {
                self.document = try await client.rename(document, to: trimmed)
            } catch {
                title = document.title
                self.error = error
            }
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
        guard let client = model.client, let document else { return }
        let contents = text
        guard contents != saved else { return }
        do {
            _ = try await client.edit(document, contents: contents)
            saved = contents
        } catch where !Task.isCancelled {
            self.error = error
        } catch {}
    }

    /// Deletes the document, dropping any unsaved edits, and goes back to
    /// the list.
    private func delete() {
        guard let client = model.client, let document else { return }
        saveTask?.cancel()
        saved = text
        isDeleted = true
        Task {
            do {
                try await client.delete(document)
                dismiss()
            } catch {
                isDeleted = false
                self.error = error
            }
        }
    }
}
