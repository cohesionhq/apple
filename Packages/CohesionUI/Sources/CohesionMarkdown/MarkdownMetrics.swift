import CoreGraphics

/// Layout constants shared by `MarkdownText` and `MarkdownEditor`'s
/// paragraph styler, so a document lays out the same read or edited.
public enum MarkdownMetrics {
    /// Leading inset added per level of list nesting.
    public static let indentStep: CGFloat = 16
    /// Distance from a list marker's start to its text, which is also the
    /// hanging indent wrapped lines fall back to.
    public static let markerWidth: CGFloat = 18
    /// Space below a list item. Tighter than `blockSpacing` so a list reads
    /// as one group.
    public static let listSpacing: CGFloat = 2
    /// Space below a heading, a paragraph, or a blank line.
    public static let blockSpacing: CGFloat = 6
    /// Width of the bar down a blockquote's leading edge.
    public static let quoteBarWidth: CGFloat = 3
    /// Gap between a blockquote's bar and its text.
    public static let quoteInset: CGFloat = 12
    /// Padding inside a fenced code block, around its text.
    public static let codePadding: CGFloat = 12
    /// Padding around a table cell's text, sideways and up and down, as
    /// the web UI pads a cell.
    public static let tableCellPadding = CGSize(width: 8, height: 4)
    /// Corner radius of a fenced code block's background, and of an image.
    public static let blockCornerRadius: CGFloat = 8
    /// `MarkdownText`'s article style's body size at the default Dynamic
    /// Type size; a size up from the system's 17, as a reader sets it.
    public static let articleBodySize: CGFloat = 19
    /// The article style's extra leading, as a fraction of its body size:
    /// a line about 1.5 times the text's size.
    public static let articleLeading: CGFloat = 0.3
    /// The transcript style's extra leading at the default Dynamic Type
    /// size, about a fifth of the body's 17 points.
    public static let transcriptLeading: CGFloat = 3.5
    /// Space below a block of the transcript style other than a list item
    /// or a heading, and above a heading: about the height of a line, which
    /// a blank line in the source left before.
    public static let transcriptSpacing: CGFloat = 14
    /// The widest an article's column grows, in points at the default
    /// Dynamic Type size: about 65 characters of the article style's body.
    public static let articleMeasure: CGFloat = 620
}
