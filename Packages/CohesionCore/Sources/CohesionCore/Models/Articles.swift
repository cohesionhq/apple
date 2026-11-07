import Foundation

extension URL {
    /// The address's host without a leading `www.`.
    public var siteName: String {
        guard let host = host() else { return absoluteString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

/// A web page a feed brought in, with the readable text it had when it was
/// last fetched. It belongs to no workspace: every workspace shares the feeds.
public struct Article: Decodable, Identifiable {
    public let id: Int
    /// The item's link in the feed.
    public let url: URL
    public let title: String
    /// Who the page or feed says wrote it.
    public let author: String?
    /// When the page or feed says it was published, else when it was brought in.
    public let publishedAt: Date
    public let snapshot: ArticleSnapshot
    /// The page's text as of the snapshot; empty unless it was captured.
    public let contents: String
    /// Whether it has been read.
    public var read: Bool

    enum CodingKeys: String, CodingKey {
        case id, url, title, author, snapshot, contents, read
        case publishedAt = "published_at"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        publishedAt = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .publishedAt))
        snapshot = try container.decode(ArticleSnapshot.self, forKey: .snapshot)
        contents = try container.decodeIfPresent(String.self, forKey: .contents) ?? ""
        read = try container.decode(Bool.self, forKey: .read)
    }

    /// The address's host without a leading `www.`.
    public var host: String { url.siteName }
}

/// An article as a list shows it: without its text.
public struct ArticleSummary: Decodable, Identifiable {
    public let id: Int
    public let url: URL
    public let title: String
    public let author: String?
    public let publishedAt: Date
    public let snapshot: ArticleSnapshot
    /// The feed it came from.
    public let feedID: Int
    public let read: Bool

    enum CodingKeys: String, CodingKey {
        case id, url, title, author, snapshot, read
        case publishedAt = "published_at"
        case feedID = "feed_id"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        publishedAt = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .publishedAt))
        snapshot = try container.decode(ArticleSnapshot.self, forKey: .snapshot)
        feedID = try container.decode(Int.self, forKey: .feedID)
        read = try container.decode(Bool.self, forKey: .read)
    }
}

/// One page of an article listing.
public struct ArticlePage: Decodable {
    public let articles: [ArticleSummary]
    /// How many articles the whole listing has, on any page.
    public let total: Int
}

/// What `markArticlesRead` replies with.
public struct ArticlesMarkedRead: Decodable {
    public let marked: Int
}

/// How an article's page was last fetched.
public enum ArticleSnapshot: Decodable {
    /// The page was fetched and its text is the article's `contents`.
    /// `finalURL` is where it was read from, after redirects; `truncated`,
    /// whether its text was cut short because the page was too long.
    case captured(finalURL: URL, fetchedAt: Date, truncated: Bool)
    /// The page has never been fetched successfully.
    case failed(ArticleFetchFailure, attemptedAt: Date)

    private enum CodingKeys: String, CodingKey {
        case state, failure, truncated
        case finalURL = "final_url"
        case fetchedAt = "fetched_at"
        case attemptedAt = "attempted_at"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .state) {
        case "captured":
            self = .captured(
                finalURL: try container.decode(URL.self, forKey: .finalURL),
                fetchedAt: Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .fetchedAt)),
                truncated: try container.decode(Bool.self, forKey: .truncated)
            )
        default:
            self = .failed(
                try container.decode(ArticleFetchFailure.self, forKey: .failure),
                attemptedAt: Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .attemptedAt))
            )
        }
    }

    public var isCaptured: Bool {
        if case .captured = self { true } else { false }
    }
}

/// Why a page couldn't be fetched.
public enum ArticleFetchFailure: Decodable {
    case unreachable
    case status(code: Int)
    case unsupportedContent
    case tooLarge
    case notAFeed

    private enum CodingKeys: String, CodingKey {
        case kind, code
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "status": self = .status(code: try container.decode(Int.self, forKey: .code))
        case "unsupportedContent": self = .unsupportedContent
        case "tooLarge": self = .tooLarge
        case "notAFeed": self = .notAFeed
        default: self = .unreachable
        }
    }

    /// Why the page couldn't be fetched, as the web UI words it.
    public var sentence: String {
        switch self {
        case .unreachable: "The site didn’t answer: the address may be wrong, or the site may be down."
        case .status(let code): "The site answered with error \(code)."
        case .unsupportedContent: "The address isn’t a web page or plain text."
        case .tooLarge: "The page is over 5 MB, too large to save."
        case .notAFeed: "The address isn’t an RSS or Atom feed."
        }
    }
}

/// An article after its page was fetched again.
public struct RefetchedArticle: Decodable {
    public let article: Article
    /// Why this fetch failed, when it did. An article fetched before keeps that
    /// snapshot.
    public let failure: ArticleFetchFailure?

    /// What to tell the user about a failed fetch; `nil` when it worked.
    public var failureMessage: String? {
        guard let failure else { return nil }
        if article.snapshot.isCaptured {
            return "Couldn’t fetch the page again, so it keeps its earlier text. \(failure.sentence)"
        }
        return "Couldn’t fetch the page. \(failure.sentence)"
    }
}

/// Which articles a list shows.
public enum ArticleListFilter: Hashable {
    /// Every article from a feed.
    case feed(Int)
    /// Every article from every feed, together.
    case allFeeds

    /// As `listArticles` takes it.
    public var wireValue: Any {
        switch self {
        case .feed(let id): ["feed": id]
        case .allFeeds: "feeds"
        }
    }
}

/// An RSS or Atom feed; cohesiond reads it every hour. Feeds are followed
/// once for every workspace.
public struct Feed: Decodable, Identifiable {
    public let id: Int
    public let url: URL
    public let title: String
    public let status: FeedStatus
}

/// A feed as the feed list shows it, in the user's order.
public struct FeedSummary: Decodable, Identifiable {
    public let id: Int
    public let url: URL
    public let title: String
    public let fullPagePolicy: FeedFullPagePolicy
    public let status: FeedStatus
    /// How many of its articles are unread.
    public let unread: Int

    public init(
        id: Int,
        url: URL,
        title: String,
        fullPagePolicy: FeedFullPagePolicy,
        status: FeedStatus,
        unread: Int
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.fullPagePolicy = fullPagePolicy
        self.status = status
        self.unread = unread
    }

    enum CodingKeys: String, CodingKey {
        case id, url, title, status, unread
        case fullPagePolicy = "full_page_policy"
    }
}

/// When a feed item's page is fetched rather than read from the feed.
public enum FeedFullPagePolicy: String, Decodable, CaseIterable {
    /// Only when the feed gives an excerpt rather than the whole text.
    case whenExcerpt
    case always
}

/// How a feed was last read.
public enum FeedStatus: Decodable {
    /// Read at `at`, adding `added` new articles.
    case refreshed(at: Date, added: Int)
    /// Couldn't be read at `at`; the articles already in stay.
    case failed(ArticleFetchFailure, at: Date)

    private enum CodingKeys: String, CodingKey {
        case state, at, added, failure
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let at = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .at))
        switch try container.decode(String.self, forKey: .state) {
        case "failed":
            self = .failed(try container.decode(ArticleFetchFailure.self, forKey: .failure), at: at)
        default:
            self = .refreshed(at: at, added: try container.decode(Int.self, forKey: .added))
        }
    }
}
