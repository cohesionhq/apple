import SwiftUI

/// Renders Markdown as the Apple app's `MarkdownText` does. Every source line
/// stays its own block: line breaks are kept rather than reflowed into
/// paragraphs, and blank lines keep their height. An image in a paragraph
/// shows as a block of its own, splitting the text around it. Consecutive quote lines form one quote, the
/// lines of a fenced code block one code block, and a GFM table's lines one table.
public struct MarkdownText: View {
    /// How the text is set.
    public enum Style {
        /// The system's body text, line for line, for a message or a plan.
        case compact
        /// An actor's words in a session's transcript, a long run of prose,
        /// lists and code: the system's body text with open leading, and
        /// paragraphs set apart by space rather than blank lines.
        case transcript
        /// A long read: a serif face a size up, open leading, and spacing
        /// that sets paragraphs apart and binds a heading to what follows
        /// it. Blank lines only separate blocks, so runs of them don't
        /// leave holes in the page.
        case article
    }

    /// What leads a list item: a bullet's or number's text, or a task
    /// item's box, ticked once it's done.
    private enum ListMarker {
        case text(String)
        case task(done: Bool)
    }

    private enum Block {
        case heading(level: Int, text: AttributedString)
        case listItem(marker: ListMarker, indent: Int, text: AttributedString)
        case paragraph(AttributedString)
        case image(alt: String, source: URL?)
        /// Consecutive `>` lines, joined with line breaks.
        case quote(AttributedString)
        /// The lines between a pair of fences, taken literally.
        case code(String)
        /// The lines of a ```` ```mermaid ```` block, drawn as a diagram once
        /// they parse.
        case diagram(String)
        case table(Markdown.Table)
        /// An empty source line, laid out at a full line's height.
        case blank
    }

    private struct IdentifiedBlock: Identifiable {
        let id: Int
        let block: Block
        let isFirst: Bool
        let isLast: Bool
    }

    private let blocks: [IdentifiedBlock]
    private let style: Style
    private let selectable: Bool

    /// The article style's body size; it follows Dynamic Type from the
    /// body style's default.
    @ScaledMetric(relativeTo: .body) private var articleSize: CGFloat = MarkdownMetrics.articleBodySize
    /// The transcript style's extra leading; it follows Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var transcriptLeading: CGFloat = MarkdownMetrics.transcriptLeading

    /// `base` is the address relative links and images resolve against.
    /// With `diagrams`, a ```` ```mermaid ```` block is drawn as a diagram, as
    /// the web UI draws it in agent chat and transcripts only. Without
    /// `selectable`, a long press is left to what's around the text.
    public init(
        markdown: String,
        base: URL? = nil,
        style: Style = .compact,
        diagrams: Bool = false,
        selectable: Bool = true
    ) {
        self.style = style
        self.selectable = selectable
        blocks = Self.makeBlocks(from: markdown, base: base, style: style, diagrams: diagrams)
    }

    public var body: some View {
        if selectable {
            text.textSelection(.enabled)
        } else {
            text
        }
    }

    private var text: some View {
        Group {
            if style == .transcript {
                // Not lazy: a message sits in a transcript's stack, which
                // measures it whole, and a lazy stack's guess at blocks it
                // hasn't laid out (a diagram drawing in) leaves the
                // transcript shorter than what it draws.
                VStack(alignment: .leading, spacing: 0) { blockViews }
            } else {
                // Lazy: a fetched page can run to thousands of lines.
                LazyVStack(alignment: .leading, spacing: 0) { blockViews }
            }
        }
        .font(bodyFont)
        .lineSpacing(leading)
    }

    private var blockViews: some View {
        ForEach(blocks) { item in
            blockView(for: item.block)
                .padding(.top, item.isFirst ? 0 : spacing(above: item.block))
                // The last block owns no gap, so it doesn't pad the bottom of whatever contains it.
                .padding(.bottom, item.isLast ? 0 : spacing(below: item.block))
        }
    }

    private var bodyFont: Font {
        switch style {
        case .compact, .transcript: .body
        case .article: .system(size: articleSize, design: .serif)
        }
    }

    private var leading: CGFloat {
        switch style {
        case .compact: 0
        case .transcript: transcriptLeading
        case .article: articleSize * MarkdownMetrics.articleLeading
        }
    }

    /// The scale of the article style's body size, so its gaps grow with
    /// the text.
    private var em: CGFloat { articleSize }

    @ViewBuilder
    private func blockView(for block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(shadingCode(in: text))
                .font(headingFont(for: level))
                .frame(maxWidth: .infinity, alignment: .leading)
        case .listItem(let marker, let indent, let text):
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                switch marker {
                case .text(let marker):
                    Text(marker)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(minWidth: markerWidth, alignment: .leading)
                    Text(shadingCode(in: text))
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .task(let done):
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(done ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                        .accessibilityLabel(done ? "Done" : "Not done")
                        .frame(minWidth: markerWidth * 1.6, alignment: .leading)
                    Text(shadingCode(in: text))
                        .foregroundStyle(done ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.leading, CGFloat(indent) * indentStep)
        case .paragraph(let text):
            Text(shadingCode(in: text))
        case .quote(let text):
            Text(shadingCode(in: text))
                .italic(style == .article)
                .foregroundStyle(.secondary)
                .padding(.leading, style == .article ? em : MarkdownMetrics.quoteInset)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(.tint)
                        .frame(width: MarkdownMetrics.quoteBarWidth)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
        case .code(let text):
            codeBlock(text)
        case .diagram(let source):
            MarkdownDiagram(source: source) {
                codeBlock(source)
            }
        case .table(let table):
            MarkdownTable(table: table, styling: shadingCode)
        case .image(let alt, let source):
            AsyncImage(url: source) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: MarkdownMetrics.blockCornerRadius))
                case .failure:
                    // The alt text stands in, as a browser shows it.
                    if !alt.isEmpty {
                        Text(alt)
                            .foregroundStyle(.secondary)
                    }
                default:
                    RoundedRectangle(cornerRadius: MarkdownMetrics.blockCornerRadius)
                        .fill(.fill.tertiary)
                        .aspectRatio(16 / 9, contentMode: .fit)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // An image with no alt text is decorative, so VoiceOver skips it.
            .accessibilityHidden(alt.isEmpty)
            .accessibilityLabel(alt)
        case .blank:
            // A space rather than an empty string: an empty `Text` collapses to no height.
            Text(verbatim: " ")
        }
    }

    private func codeBlock(_ text: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(verbatim: text)
                .font(codeFont)
                // Lines keep their length, so a long one scrolls rather than wraps.
                .fixedSize(horizontal: true, vertical: false)
                .padding(MarkdownMetrics.codePadding)
        }
        .background(.fill.tertiary, in: .rect(cornerRadius: MarkdownMetrics.blockCornerRadius))
    }

    private func headingFont(for level: Int) -> Font {
        switch (style, level) {
        case (.compact, 1): .title2.bold()
        case (.compact, 2): .title3.bold()
        case (.compact, _): .body.bold().scaled(by: 1.1)
        // A transcript's headings head a reply, not a page, so stay near the body's size.
        case (.transcript, 1): .title3.bold()
        case (.transcript, 2): .headline
        case (.transcript, _): .body.weight(.semibold)
        case (.article, 1): .system(size: em * 1.5, weight: .bold, design: .serif)
        case (.article, 2): .system(size: em * 1.3, weight: .bold, design: .serif)
        case (.article, _): .system(size: em * 1.1, weight: .semibold, design: .serif)
        }
    }

    private var codeFont: Font {
        switch style {
        case .compact: .system(.callout, design: .monospaced)
        case .transcript: .system(.subheadline, design: .monospaced)
        // A size under the serif body, whose x-height is smaller than the monospaced face's.
        case .article: .system(size: em * 0.82, design: .monospaced)
        }
    }

    private var indentStep: CGFloat {
        style == .article ? em * 1.2 : MarkdownMetrics.indentStep
    }

    private var markerWidth: CGFloat {
        style == .article ? em * 1.2 : MarkdownMetrics.markerWidth
    }

    private func spacing(above block: Block) -> CGFloat {
        switch (style, block) {
        // A heading sits closer to the text it heads than to the text before it.
        case (.article, .heading): em * 0.8
        // A figure, a code block, a table or a quote stands apart from the text around it.
        case (.article, .image), (.article, .code), (.article, .table), (.article, .quote): em * 0.4
        case (.transcript, .heading): MarkdownMetrics.transcriptSpacing
        case (.transcript, .image), (.transcript, .code), (.transcript, .diagram), (.transcript, .table), (.transcript, .quote): 4
        default: 0
        }
    }

    private func spacing(below block: Block) -> CGFloat {
        switch (style, block) {
        case (.compact, .listItem): MarkdownMetrics.listSpacing
        case (.compact, _): MarkdownMetrics.blockSpacing
        case (.transcript, .listItem): MarkdownMetrics.listSpacing * 2
        case (.transcript, .heading): MarkdownMetrics.blockSpacing
        case (.transcript, _): MarkdownMetrics.transcriptSpacing
        case (.article, .listItem): em * 0.35
        case (.article, .heading): em * 0.4
        case (.article, .image), (.article, .code), (.article, .table), (.article, .quote): em * 1.2
        case (.article, _): em * 0.8
        }
    }

    /// Gives code spans, which `Markdown.attributedContent` marks with the code intent, a subtle background,
    /// and in an article the code block's size.
    private func shadingCode(in text: AttributedString) -> AttributedString {
        var shaded = text
        let codeRanges = text.runs.filter { $0.inlinePresentationIntent?.contains(.code) == true }.map(\.range)
        for range in codeRanges {
            shaded[range].backgroundColor = Color.secondary.opacity(0.15)
            if style == .article {
                shaded[range].swiftUI.font = codeFont
            }
        }
        return shaded
    }

    private static func makeBlocks(from markdown: String, base: URL?, style: Style, diagrams: Bool) -> [IdentifiedBlock] {
        // The next number at each list depth. A numbered list counts up from
        // its first item, whatever its later items are written as; a
        // shallower item or any other line but a blank one ends the deeper
        // lists.
        var nextNumber: [Int: Int] = [:]
        var blocks: [Block] = []
        // The quote or code block being collected; any other line ends it.
        var quote: AttributedString?
        var code: [String]?
        // Whether the code block being collected is a diagram.
        var isDiagram = false
        func flush() {
            if let text = quote {
                blocks.append(.quote(text))
                quote = nil
            }
            if let lines = code {
                let text = lines.joined(separator: "\n")
                blocks.append(isDiagram ? .diagram(text) : .code(text))
                code = nil
            }
        }
        let lines = Markdown.lines(in: markdown)
        var index = 0
        while index < lines.count {
            if let (table, end) = Markdown.table(in: lines, at: index, base: base) {
                nextNumber.removeAll()
                flush()
                blocks.append(.table(table))
                index = end
                continue
            }
            let (text, line) = lines[index]
            index += 1
            let content = Markdown.attributedContent(of: text, line: line, base: base)
            switch line.kind {
            case .quote:
                nextNumber.removeAll()
                if var open = quote {
                    open += AttributedString("\n") + content
                    quote = open
                } else {
                    flush()
                    quote = content
                }
                continue
            case .fenceOpen:
                nextNumber.removeAll()
                flush()
                code = []
                isDiagram = diagrams && Markdown.opensDiagram(text)
                continue
            case .code:
                code?.append(String(text))
                continue
            case .fenceClose:
                flush()
                continue
            case .heading, .bullet, .numbered, .image, .paragraph:
                flush()
            }
            switch line.kind {
            case .heading(let level):
                nextNumber.removeAll()
                blocks.append(.heading(level: level, text: content))
            case .bullet(let indent):
                nextNumber = nextNumber.filter { $0.key < indent }
                if let (done, rest) = taskItem(content) {
                    blocks.append(.listItem(marker: .task(done: done), indent: indent, text: rest))
                } else {
                    blocks.append(.listItem(marker: .text("•"), indent: indent, text: content))
                }
            case .numbered(let indent):
                nextNumber = nextNumber.filter { $0.key <= indent }
                let (written, delimiter) = numberedMarker(in: text, line: line)
                let number = nextNumber[indent] ?? written
                nextNumber[indent] = number + 1
                blocks.append(.listItem(marker: .text("\(number)\(delimiter)"), indent: indent, text: content))
            case .image(let alt, let source):
                nextNumber.removeAll()
                blocks.append(.image(alt: alt, source: URL(string: source, relativeTo: base)?.absoluteURL))
            case .paragraph:
                if text.isEmpty {
                    // An article and a transcript space their blocks themselves.
                    if style == .compact {
                        blocks.append(.blank)
                    }
                } else {
                    nextNumber.removeAll()
                    blocks.append(.paragraph(content))
                }
            case .quote, .fenceOpen, .code, .fenceClose:
                break
            }
        }
        flush()

        return blocks.enumerated().map { offset, block in
            IdentifiedBlock(id: offset, block: block, isFirst: offset == 0, isLast: offset == blocks.count - 1)
        }
    }

    /// The number a numbered item is written with, and the `.` or `)` after it.
    /// A GFM task item's state and its text after the box, when `content`
    /// opens with one ("[ ] ", "[x] ").
    private static func taskItem(_ content: AttributedString) -> (done: Bool, rest: AttributedString)? {
        let characters = content.characters
        guard characters.count > 4 else { return nil }
        let done: Bool
        switch String(characters.prefix(4)) {
        case "[ ] ": done = false
        case "[x] ", "[X] ": done = true
        default: return nil
        }
        let start = content.index(content.startIndex, offsetByCharacters: 4)
        return (done, AttributedString(content[start...]))
    }

    private static func numberedMarker(in text: Substring, line: Markdown.Line) -> (number: Int, delimiter: Character) {
        let range = line.marker!
        let utf16 = text.utf16
        let lower = utf16.index(utf16.startIndex, offsetBy: range.lowerBound)
        let upper = utf16.index(utf16.startIndex, offsetBy: range.upperBound)
        var marker = text[lower..<upper].trimmingCharacters(in: .whitespaces)
        let delimiter = marker.removeLast()
        return (Int(marker)!, delimiter)
    }
}

#Preview {
    ScrollView {
        MarkdownText(markdown: """
            # Heading 1
            ## Heading 2
            ### Heading 3

            A **bold** paragraph long enough to wrap onto a second line so the leading edge is easy to check.

            - A list item, also long enough to wrap so its hanging indent lines up under the first word.
            - Another item with a [link](https://example.com) in it
              - A nested item
            1. First
            1. Second, written as 1.

            1. Third, after a blank line

            ![An image](https://example.com/image.png)
            ![](https://example.com/image.png)
            Text\\. with an escaped full stop

            > A quote with **bold** and a [link](https://example.com), long enough to wrap onto a second line.
            > Its second line, in the same quote.
            >> A nested quote reads as one level.

            Some `inline code`, ``code with a ` backtick``, and `*not italic*` or `\\*` left alone.

            | Name | Centered | Count |
            |:-----|:--------:|------:|
            | `code` | **bold** | 1 |
            | A cell long enough to push the table past the screen, so it scrolls sideways | a \\| b | 1,000 |
            | A short row |

            ```swift
            let greeting = "Hello, world"   // a long line scrolls sideways rather than wrapping, as code should
            print(greeting) // **no markup** in here

            ```
            ```Mermaid title
            graph LR
                A[Draft] --> B{Ready?}
                B -->|Yes| C[Ship]
                B -->|No| A
            ```
            ```mermaid
            not a diagram, so it stays code
            ```
            ~~~
            A tilde fence, left open
            """, diagrams: true)
        .padding()
    }
}

#Preview("Article") {
    ScrollView {
        MarkdownText(markdown: """
            The first paragraph of a long read, long enough to wrap across several lines so the leading and the measure are easy to judge at a glance.


            A second paragraph after two blank lines, which leave one gap rather than two, with *an aside* and a [link](https://example.com).

            ## A section
            Text straight under its heading, which sits closer to it than to the paragraph above.

            - A list item, long enough to wrap so its hanging indent lines up under the first word.
            - Another item
              - A nested item

            > A quote, set in italic and long enough to wrap onto a second line.

            ```
            let code = "set a size under the body"
            ```
            The paragraph after the code block, with some `inline code`.
            """, style: .article)
        .padding()
    }
}
