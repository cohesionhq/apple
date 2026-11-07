import CohesionCore
import CohesionMarkdown
import CohesionUI
import SwiftUI

/// An article's page as it was fetched, or why it couldn't be, with fetching
/// again, renaming, sharing and read state.
struct ArticleView: View {
    let articleID: Int

    @Environment(AppModel.self) private var model

    @State private var article: Article?
    /// Opening marks the article read once; marking it unread afterwards
    /// sticks.
    @State private var didMarkRead = false
    @State private var isMissing = false
    @State private var isFetching = false
    @State private var isRenaming = false
    @State private var newTitle = ""
    @State private var notice: String?
    @State private var error: (any Error)?

    /// The widest the text column grows, so a line stays an easy read on
    /// an iPad or in landscape; it follows Dynamic Type with the text.
    @ScaledMetric(relativeTo: .body) private var measure = MarkdownMetrics.articleMeasure

    var body: some View {
        Group {
            if let article {
                page(of: article)
            } else if isMissing {
                ContentUnavailableView("Article Not Found", systemImage: "newspaper")
            } else {
                ProgressView()
            }
        }
        // The title heads the page, where a long one can wrap.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let article {
                toolbar(for: article)
            }
        }
        .alert("Rename Article", isPresented: $isRenaming) {
            TextField("Title", text: $newTitle)
            Button("Cancel", role: .cancel) {}
            Button("Rename", action: rename)
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .alert(
            "Couldn’t Fetch the Page",
            isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } }),
            presenting: notice
        ) { _ in
            Button("OK") {}
        } message: { notice in
            Text(notice)
        }
        .task { await watch() }
        .errorAlert($error)
    }

    private func page(of article: Article) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(article.title)
                    .font(.system(.title, design: .serif, weight: .bold))
                    .textSelection(.enabled)
                    .padding(.bottom, 12)
                details(of: article)
                    .padding(.bottom, 28)
                switch article.snapshot {
                case .captured(let finalURL, _, _):
                    MarkdownText(markdown: article.contents, base: finalURL, style: .article)
                case .failed(let failure, let attemptedAt):
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Couldn’t fetch this page.")
                            .fontWeight(.medium)
                        Text("\(failure.sentence) Tried \(attemptedAt, format: .relative(presentation: .named)).")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.fill.tertiary, in: .rect(cornerRadius: 12))
                }
            }
            .frame(maxWidth: measure, alignment: .leading)
            // The column is centred once the screen is wider than it.
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .refreshable { await load(.asked) }
    }

    /// Who wrote it and when it was published; the site, linked to the
    /// page, and when it was fetched; then whether its text was cut.
    private func details(of article: Article) -> some View {
        var site = AttributedString(article.host)
        site.link = article.url
        return VStack(alignment: .leading, spacing: 4) {
            if let author = article.author {
                Text("\(author) · \(article.publishedAt, format: .dateTime.day().month().year())")
            } else {
                Text(article.publishedAt, format: .dateTime.day().month().year())
            }
            switch article.snapshot {
            case .captured(_, let fetchedAt, let truncated):
                Text("\(site) · Fetched \(fetchedAt, format: .relative(presentation: .named))")
                if truncated {
                    Text("The page was too long, so its text is cut short.")
                }
            case .failed:
                Text(site)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    @ToolbarContentBuilder
    private func toolbar(for article: Article) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if isFetching {
                ProgressView()
            } else {
                Button("Fetch Again", systemImage: "arrow.clockwise", action: fetchAgain)
            }
        }
        ToolbarItem(placement: .primaryAction) {
            ShareLink(item: article.url)
        }
        ToolbarItem(placement: .secondaryAction) {
            Button(
                article.read ? "Mark as Unread" : "Mark as Read",
                systemImage: article.read ? "circle" : "checkmark.circle"
            ) {
                setRead(!article.read)
            }
        }
        ToolbarItem(placement: .secondaryAction) {
            Button("Rename", systemImage: "pencil") {
                newTitle = article.title
                isRenaming = true
            }
        }
        ToolbarItem(placement: .secondaryAction) {
            Button("Copy Address", systemImage: "doc.on.doc") {
                Pasteboard.general.url = article.url
            }
        }
    }

    private func load(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client else { return }
        await origin.run {
            do {
                let loaded = try await client.article(articleID)
                article = loaded
                if !loaded.read && !didMarkRead {
                    didMarkRead = true
                    article = try await client.setRead(articleID, true)
                }
            } catch let error as ServerError where error.code == ServerError.notFound {
                // Deleted, here or elsewhere.
                article = nil
                isMissing = true
            }
        } failed: { self.error = $0 }
    }

    /// Keeps the page current while it is shown; the stream also yields
    /// once on connecting, which does the first load.
    private func watch() async {
        guard let client = model.client else { return }
        for await origin in client.loads(matching: { $0 == .feedArticles }) {
            await load(origin)
        }
    }

    private func fetchAgain() {
        guard let client = model.client, let article else { return }
        isFetching = true
        Task {
            do {
                let fetched = try await client.refetch(article.id)
                self.article = fetched.article
                notice = fetched.failureMessage
            } catch {
                self.error = error
            }
            isFetching = false
        }
    }

    private func setRead(_ read: Bool) {
        guard let client = model.client, let article else { return }
        Task {
            do {
                self.article = try await client.setRead(article.id, read)
            } catch {
                self.error = error
            }
        }
    }

    private func rename() {
        guard let client = model.client, let article else { return }
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        Task {
            do {
                self.article = try await client.rename(article.id, to: title)
            } catch {
                self.error = error
            }
        }
    }
}
