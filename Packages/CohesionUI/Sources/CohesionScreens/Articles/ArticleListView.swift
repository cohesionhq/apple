import CohesionCore
import CohesionUI
import SwiftUI

/// One list of articles: a feed or every feed together, most recently
/// published first; an article opens its page's text, zooming out of its row.
struct ArticleListView: View {
    let filter: ArticleListFilter
    let title: String
    /// Every feed, for the title of an article's feed and the one to read.
    let feeds: [FeedSummary]

    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    @State private var articles: [ArticleSummary] = []
    /// How many articles the whole list has; `articles` holds the pages
    /// loaded so far.
    @State private var total = 0
    /// Where an opened article zooms out of.
    @Namespace private var rows
    @State private var isLoaded = false
    @State private var isReading = false
    /// The new title being typed for the feed shown, while renaming it.
    @State private var feedTitle: String?
    @State private var isConfirmingFeedDelete = false
    @State private var notice: String?
    @State private var error: (any Error)?

    var body: some View {
        List {
            ForEach(articles) { article in
                NavigationLink {
                    ArticleView(articleID: article.id)
                        .zoomTransition(from: article.id, in: rows)
                } label: {
                    ArticleRow(article: article, feedTitle: feedTitle(of: article))
                }
                .matchedTransitionSource(id: article.id, in: rows)
                .swipeActions(edge: .leading) {
                    Button(
                        article.read ? "Mark Unread" : "Mark Read",
                        systemImage: article.read ? "circle" : "checkmark.circle"
                    ) {
                        setRead(article, !article.read)
                    }
                    .tint(.accentColor)
                }
                .contextMenu {
                    Button(
                        article.read ? "Mark as Unread" : "Mark as Read",
                        systemImage: article.read ? "circle" : "checkmark.circle"
                    ) {
                        setRead(article, !article.read)
                    }
                    Button("Open in Browser", systemImage: "safari") {
                        openURL(article.url)
                    }
                    Button("Copy Address", systemImage: "doc.on.doc") {
                        Pasteboard.general.url = article.url
                    }
                    ShareLink(item: article.url)
                }
            }
            if articles.count < total {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .task(id: articles.count) { await loadMore() }
            }
        }
        .overlay {
            if isLoaded && articles.isEmpty {
                ContentUnavailableView(
                    "No Articles Yet",
                    systemImage: "dot.radiowaves.up.forward",
                    description: Text("New articles arrive each time Cohesion reads the feed.")
                )
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isReading {
                    ProgressView()
                } else {
                    Button("Read Now", systemImage: "arrow.clockwise") { readNow() }
                }
            }
            ToolbarItemGroup(placement: .secondaryAction) {
                Button("Mark All as Read", systemImage: "checkmark.circle", action: markAllRead)
                    .disabled(articles.count == total && articles.allSatisfy(\.read))
                if let feed {
                    feedActions(feed)
                }
            }
        }
        .alert("Rename Feed", isPresented: Binding(get: { feedTitle != nil }, set: { if !$0 { feedTitle = nil } })) {
            TextField("Title", text: Binding(get: { feedTitle ?? "" }, set: { feedTitle = $0 }))
            Button("Cancel", role: .cancel) {}
            Button("Rename") { renameFeed() }
        }
        .confirmationDialog(
            "Delete “\(feed?.title ?? "")”?",
            isPresented: $isConfirmingFeedDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Feed", role: .destructive) { deleteFeed() }
        } message: {
            Text("Its articles are removed with it.")
        }
        .alert(
            "Couldn’t Read the Feed",
            isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } }),
            presenting: notice
        ) { _ in
            Button("OK") {}
        } message: { notice in
            Text(notice)
        }
        .task { await watch() }
        .refreshable { await load(.asked) }
        .errorAlert($error)
    }

    /// The feed this list shows, when it shows one.
    private var feed: FeedSummary? {
        guard case .feed(let id) = filter else { return nil }
        return feeds.first { $0.id == id }
    }

    /// Renaming, how the feed's articles are read, and deleting it.
    @ViewBuilder
    private func feedActions(_ feed: FeedSummary) -> some View {
        Section {
            Button("Rename…", systemImage: "pencil") { feedTitle = feed.title }
        }
        Section {
            Picker(
                "Fetch Whole Pages",
                systemImage: "doc.richtext",
                selection: Binding(get: { feed.fullPagePolicy }, set: { policy in
                    run { try await $0.setFullPagePolicy(policy, ofFeed: feed.id) }
                })
            ) {
                Text("When the Feed Has Excerpts").tag(FeedFullPagePolicy.whenExcerpt)
                Text("Always").tag(FeedFullPagePolicy.always)
            }
            .pickerStyle(.menu)
        }
        Section {
            Button("Delete…", systemImage: "trash", role: .destructive) { isConfirmingFeedDelete = true }
        }
    }

    private func renameFeed() {
        guard let feed, let title = feedTitle?.trimmingCharacters(in: .whitespaces),
              !title.isEmpty, title != feed.title else { return }
        run { try await $0.renameFeed(feed.id, to: title) }
    }

    /// The sidebar closes the list once the feed is gone.
    private func deleteFeed() {
        guard let feed else { return }
        run { try await $0.deleteFeed(feed.id) }
    }

    /// Sends a command; the sidebar's feeds follow the change cohesiond
    /// announces.
    private func run(_ action: @escaping (CohesionClient) async throws -> Void) {
        guard let client = model.client else { return }
        Task {
            do { try await action(client) } catch { self.error = error }
        }
    }

    /// All Feeds names each article's feed; a single feed's list says nothing.
    private func feedTitle(of article: ArticleSummary) -> String? {
        switch filter {
        case .allFeeds: feeds.first { $0.id == article.feedID }?.title
        case .feed: nil
        }
    }

    /// Loads the list again from the top, as many articles as it shows, so
    /// a reload keeps the pages scrolled to.
    private func load(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client else { return }
        await origin.run {
            let wanted = max(articles.count, 50)
            var loaded: [ArticleSummary] = []
            var total = 0
            repeat {
                let page = try await client.listArticles(
                    filter: filter,
                    offset: loaded.count,
                    limit: min(wanted - loaded.count, 500)
                )
                loaded += page.articles
                total = page.total
                if page.articles.isEmpty { break }
            } while loaded.count < min(wanted, total)
            withAnimation { self.articles = loaded }
            self.total = total
            isLoaded = true
        } failed: { self.error = $0 }
    }

    /// Adds the next page to the end. An article that moved up into it since
    /// the last page isn't shown twice.
    private func loadMore() async {
        guard let client = model.client else { return }
        await LoadOrigin.automatic.run {
            let page = try await client.listArticles(filter: filter, offset: articles.count)
            let shown = Set(articles.map(\.id))
            articles += page.articles.filter { !shown.contains($0.id) }
            total = page.total
        }
    }

    /// Keeps the list current while it is shown; the stream also yields
    /// once on connecting, which does the first load.
    private func watch() async {
        guard let client = model.client else { return }
        for await origin in client.loads(matching: { $0 == .feedArticles }) {
            await load(origin)
        }
    }

    private func readNow() {
        guard let client = model.client else { return }
        isReading = true
        Task {
            do {
                if case .feed(let id) = filter {
                    let read = try await client.refreshFeed(id)
                    if case .failed(let failure, _) = read.status {
                        notice = "Couldn’t read “\(read.title)”. \(failure.sentence)"
                    }
                } else {
                    _ = try await client.refreshFeeds()
                }
            } catch {
                self.error = error
            }
            isReading = false
        }
    }

    private func setRead(_ article: ArticleSummary, _ read: Bool) {
        guard let client = model.client else { return }
        Task {
            do {
                _ = try await client.setRead(article.id, read)
                await load()
            } catch {
                self.error = error
            }
        }
    }

    private func markAllRead() {
        guard let client = model.client else { return }
        Task {
            do {
                try await client.markAllRead(filter: filter)
                await load()
            } catch {
                self.error = error
            }
        }
    }
}

/// An article's title, unread until opened; who wrote it and which feed it
/// came from; whether its page was never fetched; and when it was published.
private struct ArticleRow: View {
    let article: ArticleSummary
    /// Its feed; `nil` leaves it out.
    let feedTitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(.tint)
                .frame(width: 8, height: 8)
                .opacity(article.read ? 0 : 1)
                .accessibilityLabel("Unread")
                .accessibilityHidden(article.read)
            VStack(alignment: .leading) {
                Text(article.title)
                    .fontWeight(article.read ? .regular : .semibold)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let author = article.author {
                        Text(author)
                    }
                    if let feedTitle {
                        Text(feedTitle)
                    }
                    if !article.snapshot.isCaptured {
                        Text("Not Fetched")
                            .foregroundStyle(ArticleSnapshot.notFetchedTint)
                    }
                    Spacer()
                    Text(article.publishedAt, format: .relative(presentation: .named))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
    }
}
