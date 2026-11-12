import CohesionCore
import CohesionUI
import SwiftUI

/// What the workspace keeps and reads, as the iPhone's Library tab opens on
/// it: the documents changed last, as cards that open them, then Documents
/// and Journal, Contacts, the feeds and the kinds of resource the workspace
/// shows, each row opening its page through `link`. The iPad's sidebar lists
/// the same pages in its Library section.
public struct LibraryView<Link: Hashable>: View {
    let workspaceID: Int
    let feeds: [FeedSummary]
    let kinds: [ConnectorKind]
    let moveFeeds: (IndexSet, Int) -> Void
    let addFeed: () -> Void
    let moveKinds: (IndexSet, Int) -> Void
    let editKinds: () -> Void
    let link: (WorkspacePage) -> Link

    @Environment(AppModel.self) private var model

    @State private var documents: [DocumentSummary] = []
    @State private var error: (any Error)?

    /// How many of the documents changed last show as cards.
    private static var recentCount: Int { 6 }

    /// When a document changed, as words near now ("Yesterday", "5 hours
    /// ago"), as the documents' list says it.
    private static var modifiedStyle: Date.RelativeFormatStyle {
        Date.RelativeFormatStyle(presentation: .named, capitalizationContext: .beginningOfSentence)
    }

    public init(
        workspaceID: Int,
        feeds: [FeedSummary],
        kinds: [ConnectorKind],
        moveFeeds: @escaping (IndexSet, Int) -> Void,
        addFeed: @escaping () -> Void,
        moveKinds: @escaping (IndexSet, Int) -> Void,
        editKinds: @escaping () -> Void,
        link: @escaping (WorkspacePage) -> Link
    ) {
        self.workspaceID = workspaceID
        self.feeds = feeds
        self.kinds = kinds
        self.moveFeeds = moveFeeds
        self.addFeed = addFeed
        self.moveKinds = moveKinds
        self.editKinds = editKinds
        self.link = link
    }

    public var body: some View {
        List {
            if !recent.isEmpty {
                Section {
                    recentCards
                } header: {
                    // Where the other sections' headers are, which the
                    // section's margins would otherwise put there.
                    Text("Recent")
                        .padding(.leading, Self.headerIndent)
                }
                // Edge to edge, so the cards scroll off the screen's edge
                // rather than being cut at the section's.
                .listSectionMargins(.horizontal, 0)
            }
            Section {
                row(.documents, "Documents", systemImage: "doc.text.fill", color: .blue)
                row(.journal, "Journal", systemImage: "book.closed.fill", color: .brown)
                row(.contacts, "Contacts", systemImage: "person.crop.circle.fill", color: .gray)
            }
            Section("Feeds") {
                FeedSection(feeds: feeds, moveFeeds: moveFeeds, addFeed: addFeed) { link(.articles($0)) }
            }
            WorkspaceSources(feeds: nil, kinds: kinds, moveKinds: moveKinds, editKinds: editKinds, link: link)
        }
        .navigationTitle("Library")
        .onAppear {
            if documents.isEmpty, let kept = model.client?.keptDocuments(in: workspaceID) { documents = kept }
        }
        .task(id: workspaceID) { await watch() }
        .errorAlert($error)
    }

    /// The documents changed last, newest first.
    private var recent: [DocumentSummary] {
        Array(documents.sorted { $0.modified > $1.modified }.prefix(Self.recentCount))
    }

    /// An inset grouped list's section margin, which the recent cards' row
    /// gives back as its scroll content's, so the first card lines up with
    /// the rows under it.
    private static var sectionMargin: CGFloat { 16 }

    /// How much further in than an edge-to-edge section's the other
    /// sections' headers are.
    private static var headerIndent: CGFloat { 20 }

    /// The recent documents as cards in a row that scrolls to the screen's
    /// edges.
    private var recentCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(recent) { document in
                    NavigationLink {
                        DocumentView(workspaceID: workspaceID, documentID: document.id)
                    } label: {
                        RecentDocumentCard(document: document, modifiedStyle: Self.modifiedStyle)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentMargins(.horizontal, Self.sectionMargin, for: .scrollContent)
        .scrollClipDisabled()
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func row(_ page: WorkspacePage, _ title: String, systemImage: String, color: Color) -> some View {
        NavigationLink(value: link(page)) {
            Label(title, systemImage: systemImage, color: color)
        }
    }

    /// Keeps the recent documents current while the Library is shown; the
    /// stream also yields once on connecting, which does the first load.
    private func watch() async {
        guard let client = model.client else { return }
        let workspaceID = workspaceID
        for await origin in client.loads(matching: {
            switch $0 {
            case .documents(workspaceID), .documentText(workspaceID, _): true
            default: false
            }
        }) {
            await origin.run {
                documents = try await client.listDocuments(in: workspaceID)
            } failed: { self.error = $0 }
        }
    }
}

/// A recent document: its symbol, its title and when it changed, on a card.
private struct RecentDocumentCard: View {
    let document: DocumentSummary
    let modifiedStyle: Date.RelativeFormatStyle

    /// A grouped list's row color, so a card reads as one of its rows.
    private static var cardColor: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    @ScaledMetric(relativeTo: .body) private var width = 132
    @ScaledMetric(relativeTo: .body) private var height = 112

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "doc.text.fill")
                .font(.title3)
                .foregroundStyle(.blue)
            Spacer(minLength: 8)
            Text(document.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(document.modified, format: modifiedStyle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .padding(12)
        .background(Self.cardColor, in: .rect(cornerRadius: 16, style: .continuous))
        .contentShape(.rect(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
