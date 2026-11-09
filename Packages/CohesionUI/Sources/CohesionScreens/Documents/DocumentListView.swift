import CohesionCore
import CohesionMarkdown
import CohesionUI
import SwiftUI

/// A workspace's documents, journal entries aside, most recently modified
/// first and grouped by when; a document opens in the Markdown editor,
/// zooming out of its row on iPad. It's pushed in the iPhone's Workspace
/// tab and shown on a stack of its own beside the iPad's sidebar.
struct DocumentListView: View {
    let workspaceID: Int

    @Environment(AppModel.self) private var model

    @State private var documents: [Document] = []
    /// A document just created, opened once it is.
    @State private var created: Int?
    @State private var query = ""
    /// The documents whose title matches `query`, once cohesiond answers.
    @State private var found: [Document]?
    @State private var isLoaded = false
    @State private var isCreating = false
    @State private var deleting: Document?
    @State private var error: (any Error)?
    /// Where an opened document zooms out of, on iPad.
    @Namespace private var rows

    /// How long typing in the search field has to pause before it searches.
    private static let searchDelay = Duration.milliseconds(250)

    /// When a document changed, as words near now ("Yesterday", "5 hours
    /// ago"), capitalised as the rest of the row's words are.
    private static let modifiedStyle = Date.RelativeFormatStyle(presentation: .named, capitalizationContext: .beginningOfSentence)

    var body: some View {
        List {
            ForEach(groups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.documents) { document in
                        NavigationLink {
                            DocumentView(workspaceID: workspaceID, documentID: document.id)
                                .zoomsOnIPad(from: document.id, in: rows)
                        } label: {
                            // A glyph, as Workspace's other lists' rows have.
                            LabeledContent {
                                Text(document.modified, format: Self.modifiedStyle)
                                    .font(.subheadline)
                            } label: {
                                Label(document.title, systemImage: "doc.text")
                            }
                        }
                        .matchedTransitionSource(id: document.id, in: rows)
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                deleting = document
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if !isLoaded {
                ProgressView()
            } else if found?.isEmpty == true {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(text: $query)
        .navigationTitle("Documents")
        .navigationDestination(item: $created) { id in
            DocumentView(workspaceID: workspaceID, documentID: id)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isCreating {
                    ProgressView()
                } else {
                    Button("New Document", systemImage: "plus", action: create)
                }
            }
        }
        .confirmationDialog(
            deleting.map { "Delete “\($0.title)”?" } ?? "",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { document in
            Button("Delete Document", role: .destructive) { delete(document) }
        } message: { _ in
            Text("Can’t be undone.")
        }
        .onAppear {
            // As last listed, until the first load.
            guard !isLoaded, let kept = model.client?.keptDocuments(in: workspaceID) else { return }
            documents = kept
            isLoaded = true
        }
        .task(id: query) { await search(.asked) }
        .task { await watch() }
        .refreshable { await load(.asked) }
        .errorAlert($error)
    }

    /// The documents shown, by when they were last modified: today, in the
    /// six days before, and earlier. Empty groups are left out.
    private var groups: [(title: String, documents: [Document])] {
        let shown = query.isEmpty ? documents : found ?? []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!
        let grouped = Dictionary(grouping: shown) { document in
            document.modified >= today ? 0 : document.modified >= weekStart ? 1 : 2
        }
        return [(0, "Today"), (1, "This Week"), (2, "Earlier")].compactMap { index, title in
            grouped[index].map { (title, $0.sorted { $0.modified > $1.modified }) }
        }
    }

    private func load(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client else { return }
        await origin.run {
            let loaded = try await client.listDocuments(in: workspaceID)
            withAnimation {
                documents = loaded
                isLoaded = true
            }
            if !query.isEmpty { await search(origin) }
        } failed: { self.error = $0 }
    }

    /// Asks cohesiond for the documents matching `query` once typing pauses.
    private func search(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client else { return }
        guard !query.isEmpty else {
            found = nil
            return
        }
        await origin.run {
            try await Task.sleep(for: Self.searchDelay)
            let matches = try await client.searchDocuments(query, in: workspaceID)
            withAnimation { found = matches }
        } failed: { self.error = $0 }
    }

    /// Keeps the list current while it is shown; the stream also yields
    /// once on connecting, which does the first load.
    private func watch() async {
        guard let client = model.client else { return }
        let workspaceID = workspaceID
        for await origin in client.loads(matching: { $0 == .documents(workspaceID: workspaceID) }) {
            await load(origin)
        }
    }

    /// Creates an untitled document and opens it.
    private func create() {
        guard let client = model.client else { return }
        isCreating = true
        Task {
            do {
                let document = try await client.createDocument(titled: "Untitled", in: workspaceID)
                documents.insert(document, at: 0)
                created = document.id
            } catch {
                self.error = error
            }
            isCreating = false
        }
    }

    private func delete(_ document: Document) {
        guard let client = model.client else { return }
        Task {
            do {
                try await client.delete(document)
                withAnimation { documents.removeAll { $0.id == document.id } }
            } catch {
                self.error = error
            }
        }
    }
}
