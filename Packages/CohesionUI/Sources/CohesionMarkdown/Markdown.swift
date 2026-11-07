import Foundation

/// A line-by-line reading of Markdown: each source line is a heading, a
/// list item, a quote, an image, a paragraph or part of a fenced code block,
/// with bold, italic, code and link spans inside it.
/// Ported from the Apple app's `CohesionCore`, so text reads the same in
/// both.
public enum Markdown {
    public enum LineKind {
        case paragraph
        case heading(Int)
        case bullet(indent: Int)
        case numbered(indent: Int)
        /// A line holding only an image, `![alt](source)`, or a linked one,
        /// `[![alt](source)](destination)`; the link is dropped.
        case image(alt: String, source: String)
        /// A line of a blockquote; the `>` markers are the line's marker, and
        /// nesting levels read as one.
        case quote
        /// The opening ``` or ~~~ line of a fenced code block. Only `lines(in:)`
        /// sees the lines after it, so `parseLine` alone reports nothing past it.
        case fenceOpen
        /// A line inside a fenced code block, taken literally.
        case code
        /// The line closing a fenced code block.
        case fenceClose
    }

    public struct Span {
        public var range: Range<Int>
        public var bold: Bool
        public var italic: Bool
        public var isMarker: Bool
        /// Destination of the link this span belongs to, if any. Markers never carry one.
        public var link: String?
        /// Inside a `` `code span` ``, where nothing else is markup.
        public var code: Bool = false
    }

    public struct Line {
        public var kind: LineKind
        public var marker: Range<Int>?
        public var spans: [Span]
    }

    public static func parseLine(_ text: Substring) -> Line {
        let units = Array(text.utf16)
        if fenceOpening(units) != nil {
            return Line(kind: .fenceOpen, marker: nil, spans: [])
        }
        if let image = blockImage(units) {
            return Line(kind: image, marker: nil, spans: [])
        }
        let (kind, marker) = parseBlockPrefix(units)
        let start = marker?.upperBound ?? 0
        let spans = parseSpans(units, start: start)
        return Line(kind: kind, marker: marker, spans: spans)
    }

    /// The lines of `text`, except that a paragraph with images among its
    /// text reads as its pieces, each image a line of its own.
    public static func lines(in text: String) -> [(text: Substring, line: Line)] {
        sourceLines(in: text).flatMap { splittingImages($0.text, line: $0.line) }
    }

    /// The lines of `text`, one for each line of the source.
    static func sourceLines(in text: String) -> [(text: Substring, line: Line)] {
        // The fence that is open, if any; it closes on a bare fence of the same
        // character at least as long, and an unclosed one runs to the end.
        var openFence: (character: UInt16, length: Int)?
        return text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            guard let fence = openFence else {
                if let opening = fenceOpening(Array(line.utf16)) {
                    openFence = (opening.character, opening.length)
                }
                return (text: line, line: parseLine(line))
            }
            if let closing = fenceOpening(Array(line.utf16)), closing.isBare,
                closing.character == fence.character, closing.length >= fence.length
            {
                openFence = nil
                return (text: line, line: Line(kind: .fenceClose, marker: nil, spans: []))
            }
            return (text: line, line: Line(kind: .code, marker: nil, spans: []))
        }
    }

    /// Whether a fence's opening line starts a Mermaid diagram: the first
    /// word of its info string is `mermaid`, in any case, as the web UI
    /// reads it. `mmd` and `mermaid-js` aren't.
    public static func opensDiagram(_ fence: Substring) -> Bool {
        let info = fence.drop { $0 == " " }.drop { $0 == "`" || $0 == "~" }
        return info.split(whereSeparator: \.isWhitespace).first?.lowercased() == "mermaid"
    }

    /// A line of three or more backticks or tildes, up to three spaces in, with an optional info string
    /// after. A backtick fence's info can't hold a backtick, which keeps ```` ```code``` ```` an inline span.
    private static func fenceOpening(_ units: [UInt16]) -> (character: UInt16, length: Int, isBare: Bool)? {
        var start = 0
        while start < units.count, start < 4, units[start] == 0x20 { start += 1 }
        guard start <= 3, start < units.count, units[start] == 0x60 || units[start] == 0x7E else { return nil }
        let character = units[start]
        var end = start
        while end < units.count, units[end] == character { end += 1 }
        guard end - start >= 3 else { return nil }
        let info = units[end...]
        if character == 0x60, info.contains(0x60) { return nil }
        return (character, end - start, info.allSatisfy(isWhitespace))
    }

    /// The line's text without its markup; link destinations resolve
    /// against `base`, so a page's relative links reach its site.
    public static func attributedContent(of text: Substring, line: Line, base: URL?) -> AttributedString {
        let utf16 = text.utf16
        var result = AttributedString()
        for span in line.spans where !span.isMarker {
            let lower = utf16.index(utf16.startIndex, offsetBy: span.range.lowerBound)
            let upper = utf16.index(utf16.startIndex, offsetBy: span.range.upperBound)
            var piece = AttributedString(text[lower..<upper])
            var intent: InlinePresentationIntent = []
            if span.bold { intent.insert(.stronglyEmphasized) }
            if span.italic { intent.insert(.emphasized) }
            if span.code { intent.insert(.code) }
            if !intent.isEmpty {
                piece.inlinePresentationIntent = intent
            }
            if let destination = span.link {
                piece.link = URL(string: destination, relativeTo: base)?.absoluteURL
            }
            result += piece
        }
        return result
    }

    /// A GFM table: a header row, a delimiter row of dashes setting each
    /// column's alignment, and the rows after it that hold a `|`.
    public struct Table {
        public enum Alignment {
            case leading, center, trailing
        }

        public var header: [AttributedString]
        public var alignments: [Alignment]
        /// Each as wide as the header: a short row is padded with empty
        /// cells and a long one cut, as GFM reads them.
        public var rows: [[AttributedString]]
    }

    /// The table starting at `lines[start]`, and the index of the line after
    /// it. A table needs a paragraph line with a `|` followed by a delimiter
    /// row with as many cells; a cell's text is inline Markdown only.
    public static func table(in lines: [(text: Substring, line: Line)], at start: Int, base: URL?)
        -> (table: Table, end: Int)?
    {
        guard start + 1 < lines.count,
            case .paragraph = lines[start].line.kind, lines[start].text.contains("|"),
            case .paragraph = lines[start + 1].line.kind
        else { return nil }
        let header = tableCells(in: lines[start].text)
        let delimiters = tableCells(in: lines[start + 1].text)
        guard delimiters.count == header.count else { return nil }
        var alignments: [Table.Alignment] = []
        for cell in delimiters {
            let dashes = cell.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            guard !dashes.isEmpty, dashes.allSatisfy({ $0 == "-" }) else { return nil }
            switch (cell.hasPrefix(":"), cell.hasSuffix(":")) {
            case (true, true): alignments.append(.center)
            case (false, true): alignments.append(.trailing)
            default: alignments.append(.leading)
            }
        }
        func content(of cells: [Substring]) -> [AttributedString] {
            (0..<header.count).map { column in
                guard column < cells.count else { return AttributedString() }
                let text = Substring(cells[column].replacingOccurrences(of: "\\|", with: "|"))
                let spans = parseSpans(Array(text.utf16), start: 0)
                return attributedContent(of: text, line: Line(kind: .paragraph, marker: nil, spans: spans), base: base)
            }
        }
        var rows: [[AttributedString]] = []
        var end = start + 2
        while end < lines.count, case .paragraph = lines[end].line.kind, lines[end].text.contains("|") {
            rows.append(content(of: tableCells(in: lines[end].text)))
            end += 1
        }
        return (Table(header: content(of: header), alignments: alignments, rows: rows), end)
    }

    /// A table row's cells, trimmed: split at each `|` not escaped as `\|`,
    /// less the optional pipes at either end.
    private static func tableCells(in row: Substring) -> [Substring] {
        var row = row.trimmingCharacters(in: .whitespaces)[...]
        if row.hasPrefix("|") { row = row.dropFirst() }
        if row.hasSuffix("|"), !row.hasSuffix("\\|") { row = row.dropLast() }
        var cells: [Substring] = []
        var cellStart = row.startIndex
        var index = row.startIndex
        while index < row.endIndex {
            if row[index] == "\\" {
                index = row.index(after: index)
                if index == row.endIndex { break }
            } else if row[index] == "|" {
                cells.append(row[cellStart..<index])
                cellStart = row.index(after: index)
            }
            index = row.index(after: index)
        }
        cells.append(row[cellStart...])
        return cells.map { Substring($0.trimmingCharacters(in: .whitespaces)) }
    }

    private static func parseBlockPrefix(_ units: [UInt16]) -> (kind: LineKind, marker: Range<Int>?) {
        var i = 0
        var spaces = 0
        var tabs = 0
        while i < units.count {
            if units[i] == 0x20 {
                spaces += 1
                i += 1
            } else if units[i] == 0x09 {
                tabs += 1
                i += 1
            } else {
                break
            }
        }
        let indentEnd = i
        let indent = spaces / 2 + tabs

        if indentEnd < units.count, units[indentEnd] == 0x3E {
            var m = indentEnd
            while m < units.count, units[m] == 0x3E || units[m] == 0x20 {
                m += 1
            }
            return (.quote, 0..<m)
        }

        if indentEnd < units.count, units[indentEnd] == 0x23 {
            var h = indentEnd
            while h < units.count, units[h] == 0x23 {
                h += 1
            }
            let hashCount = h - indentEnd
            if hashCount <= 6, h < units.count, units[h] == 0x20 {
                var m = h
                while m < units.count, units[m] == 0x20 {
                    m += 1
                }
                return (.heading(min(hashCount, 3)), 0..<m)
            }
        }

        if indentEnd < units.count,
            units[indentEnd] == 0x2D || units[indentEnd] == 0x2A || units[indentEnd] == 0x2B,
            indentEnd + 1 < units.count, units[indentEnd + 1] == 0x20
        {
            var m = indentEnd + 1
            while m < units.count, units[m] == 0x20 {
                m += 1
            }
            return (.bullet(indent: indent), 0..<m)
        }

        if indentEnd < units.count, units[indentEnd] >= 0x30, units[indentEnd] <= 0x39 {
            var d = indentEnd
            while d < units.count, d - indentEnd < 9, units[d] >= 0x30, units[d] <= 0x39 {
                d += 1
            }
            if d < units.count, units[d] == 0x2E || units[d] == 0x29, d + 1 < units.count, units[d + 1] == 0x20 {
                var m = d + 1
                while m < units.count, units[m] == 0x20 {
                    m += 1
                }
                return (.numbered(indent: indent), 0..<m)
            }
        }

        return (.paragraph, nil)
    }

    private static func isDelimiter(_ u: UInt16) -> Bool { u == 0x2A || u == 0x5F }

    /// Any ASCII punctuation, as CommonMark allows.
    private static func isEscapable(_ u: UInt16) -> Bool {
        (u >= 0x21 && u <= 0x2F) || (u >= 0x3A && u <= 0x40) || (u >= 0x5B && u <= 0x60) || (u >= 0x7B && u <= 0x7E)
    }

    /// `![` opening an image whose `[` starts a link at `pos + 1`.
    private static func isImageBang(_ units: [UInt16], at pos: Int) -> Bool {
        units[pos] == 0x21 && pos + 1 < units.count && units[pos + 1] == 0x5B && inlineLink(units, at: pos + 1) != nil
    }

    /// The image a line holds and nothing else, outside surrounding spaces.
    private static func blockImage(_ units: [UInt16]) -> LineKind? {
        var start = 0
        var end = units.count
        while start < end, isWhitespace(units[start]) { start += 1 }
        while end > start, isWhitespace(units[end - 1]) { end -= 1 }
        guard let image = image(units, at: start), image.end == end else { return nil }
        return image.kind
    }

    /// An image, `![alt](source)`, or a linked one, `[![alt](source)](destination)`, starting at `pos`;
    /// `end` is just past it.
    private static func image(_ units: [UInt16], at pos: Int) -> (end: Int, kind: LineKind)? {
        let count = units.count
        if pos + 1 < count, units[pos] == 0x21, units[pos + 1] == 0x5B,
            let image = inlineLink(units, at: pos + 1, allowsEmptyLabel: true)
        {
            return (image.end, .image(alt: unescaped(units[(pos + 2)..<image.labelEnd]), source: image.destination))
        }
        if pos + 2 < count, units[pos] == 0x5B, units[pos + 1] == 0x21, units[pos + 2] == 0x5B,
            let wrapper = inlineLink(units, at: pos),
            let image = inlineLink(units, at: pos + 2, allowsEmptyLabel: true), image.end == wrapper.labelEnd
        {
            return (wrapper.end, .image(alt: unescaped(units[(pos + 3)..<image.labelEnd]), source: image.destination))
        }
        return nil
    }

    /// The ranges of the images among a paragraph's text. One inside a code span or a link's label stays
    /// where it is.
    private static func imageRanges(_ units: [UInt16]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var pos = 0
        while pos < units.count {
            let u = units[pos]
            if u == 0x5C {
                pos += 2
            } else if u == 0x60 {
                var runEnd = pos + 1
                while runEnd < units.count, units[runEnd] == u { runEnd += 1 }
                pos = codeSpanEnd(units, run: pos..<runEnd) ?? runEnd
            } else if let image = image(units, at: pos) {
                ranges.append(pos..<image.end)
                pos = image.end
            } else if u == 0x5B, let link = inlineLink(units, at: pos) {
                pos = link.end
            } else {
                pos += 1
            }
        }
        return ranges
    }

    /// Just past the backtick run that closes the code span `run` opens, if one does.
    private static func codeSpanEnd(_ units: [UInt16], run: Range<Int>) -> Int? {
        var k = run.upperBound
        while k < units.count {
            guard units[k] == 0x60 else {
                k += 1
                continue
            }
            var e = k
            while e < units.count, units[e] == 0x60 { e += 1 }
            if e - k == run.count { return e }
            k = e
        }
        return nil
    }

    /// A paragraph line with images among its text, as its pieces: each image a line of its own, as the
    /// web UI sets an image as a block, and the text between them paragraphs. Any other line is itself.
    private static func splittingImages(_ text: Substring, line: Line) -> [(text: Substring, line: Line)] {
        guard case .paragraph = line.kind else { return [(text, line)] }
        let units = Array(text.utf16)
        let images = imageRanges(units)
        guard !images.isEmpty else { return [(text, line)] }
        let utf16 = text.utf16
        func piece(_ range: Range<Int>) -> Substring {
            text[utf16.index(utf16.startIndex, offsetBy: range.lowerBound)..<utf16.index(utf16.startIndex, offsetBy: range.upperBound)]
        }
        var pieces: [(text: Substring, line: Line)] = []
        func appendText(_ range: Range<Int>) {
            var lower = range.lowerBound
            var upper = range.upperBound
            while lower < upper, isWhitespace(units[lower]) { lower += 1 }
            while upper > lower, isWhitespace(units[upper - 1]) { upper -= 1 }
            guard lower < upper else { return }
            let fragment = piece(lower..<upper)
            // Read only as text: a fragment starting `# ` is no heading.
            pieces.append((fragment, Line(kind: .paragraph, marker: nil, spans: parseSpans(Array(fragment.utf16), start: 0))))
        }
        var cursor = 0
        for range in images {
            appendText(cursor..<range.lowerBound)
            let source = piece(range)
            pieces.append((source, Line(kind: image(units, at: range.lowerBound)!.kind, marker: nil, spans: [])))
            cursor = range.upperBound
        }
        appendText(cursor..<units.count)
        return pieces
    }

    private static func unescaped(_ units: ArraySlice<UInt16>) -> String {
        var result: [UInt16] = []
        var i = units.startIndex
        while i < units.endIndex {
            if units[i] == 0x5C, i + 1 < units.endIndex, isEscapable(units[i + 1]) {
                i += 1
            }
            result.append(units[i])
            i += 1
        }
        return String(decoding: result, as: UTF16.self)
    }

    nonisolated private static func isWhitespace(_ u: UInt16) -> Bool { u == 0x20 || u == 0x09 }

    private static func isAlnum(_ u: UInt16) -> Bool {
        (u >= 0x30 && u <= 0x39) || (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A)
    }

    /// A `[label](destination)` link, located from the opening bracket.
    private struct InlineLink {
        /// Offset of the closing `]`, where the label stops and the trailing marker starts.
        var labelEnd: Int
        /// Offset just past the closing `)`.
        var end: Int
        var destination: String
    }

    /// An empty label is a link with nothing to click, so it stays literal text, unless it is an image's
    /// alt text, which CommonMark allows to be empty.
    private static func inlineLink(_ units: [UInt16], at open: Int, allowsEmptyLabel: Bool = false) -> InlineLink? {
        let end = units.count
        var i = open + 1
        var depth = 0
        var labelEnd = -1
        while i < end {
            let u = units[i]
            if u == 0x5C {
                i += 2
                continue
            }
            if u == 0x5B {
                depth += 1
            } else if u == 0x5D {
                if depth == 0 {
                    labelEnd = i
                    break
                }
                depth -= 1
            }
            i += 1
        }
        guard allowsEmptyLabel ? labelEnd >= open + 1 : labelEnd > open + 1, labelEnd + 1 < end, units[labelEnd + 1] == 0x28 else { return nil }

        var j = labelEnd + 2
        var parens = 0
        var close = -1
        while j < end {
            let u = units[j]
            if u == 0x5C {
                j += 2
                continue
            }
            if u == 0x28 {
                parens += 1
            } else if u == 0x29 {
                if parens == 0 {
                    close = j
                    break
                }
                parens -= 1
            }
            j += 1
        }
        guard close > 0 else { return nil }

        let destination = linkDestination(units, from: labelEnd + 2, to: close)
        guard !destination.isEmpty else { return nil }
        return InlineLink(labelEnd: labelEnd, end: close + 1, destination: destination)
    }

    private static func linkDestination(_ units: [UInt16], from lower: Int, to upper: Int) -> String {
        var text = String(decoding: units[lower..<upper], as: UTF16.self).trimmingCharacters(in: .whitespaces)
        if text.count >= 2, text.hasPrefix("<"), text.hasSuffix(">") {
            text = String(text.dropFirst().dropLast())
        } else if let space = text.firstIndex(where: { $0 == " " || $0 == "\t" }) {
            // Anything after the destination is a title, which this renderer does not show.
            text = String(text[text.startIndex..<space])
        }
        return text
    }

    private static let autolinkPrefixes: [[UInt16]] = ["https://", "http://", "mailto:"].map { Array($0.utf16) }

    /// `h` and `m` are the only characters an autolink can start with.
    private static func isAutolinkLead(_ u: UInt16) -> Bool { u == 0x68 || u == 0x6D }

    private static func isTrailingPunctuation(_ u: UInt16) -> Bool {
        // Sentence punctuation and closing markup that a bare URL almost never ends with.
        u == 0x2E || u == 0x2C || u == 0x3B || u == 0x3A || u == 0x21 || u == 0x3F
            || u == 0x2A || u == 0x5F || u == 0x27 || u == 0x22 || u == 0x5D || u == 0x7D
    }

    /// The range of a bare URL starting at `pos`, written without any markup around it.
    private static func autolink(_ units: [UInt16], at pos: Int, start: Int) -> Range<Int>? {
        guard pos == start || !isAlnum(units[pos - 1]) else { return nil }
        let end = units.count
        guard
            let prefix = autolinkPrefixes.first(where: { prefix in
                pos + prefix.count <= end && Array(units[pos..<(pos + prefix.count)]) == prefix
            })
        else { return nil }

        var runEnd = pos + prefix.count
        var parens = 0
        while runEnd < end {
            let u = units[runEnd]
            if isWhitespace(u) || u == 0x3C || u == 0x3E {
                break
            }
            if u == 0x28 {
                parens += 1
            } else if u == 0x29 {
                if parens == 0 { break }
                parens -= 1
            }
            runEnd += 1
        }
        while runEnd > pos + prefix.count, isTrailingPunctuation(units[runEnd - 1]) {
            runEnd -= 1
        }
        guard runEnd > pos + prefix.count else { return nil }
        return pos..<runEnd
    }

    private static func parseSpans(_ units: [UInt16], start: Int) -> [Span] {
        let end = units.count
        guard start < end else { return [] }

        struct Piece {
            var range: Range<Int>
            var bold: Bool
            var italic: Bool
            var isMarker: Bool
            var link: String?
            var code = false
        }

        var pieces: [Piece] = []
        var bold = false
        var italic = false
        // Set while the cursor is inside a link label; `linkLabelEnd` is where the label stops.
        var link: String?
        var linkLabelEnd = -1
        var linkEnd = -1
        var pos = start

        while pos < end {
            if pos == linkLabelEnd {
                pieces.append(Piece(range: pos..<linkEnd, bold: false, italic: false, isMarker: true, link: nil))
                pos = linkEnd
                link = nil
                linkLabelEnd = -1
                continue
            }

            let u = units[pos]

            if u == 0x5C, pos + 1 < end, isEscapable(units[pos + 1]) {
                pieces.append(Piece(range: pos..<(pos + 1), bold: false, italic: false, isMarker: true, link: nil))
                pieces.append(Piece(range: (pos + 1)..<(pos + 2), bold: bold, italic: italic, isMarker: false, link: link))
                pos += 2
                continue
            }

            if u == 0x60 {
                var runEnd = pos + 1
                while runEnd < end, units[runEnd] == u { runEnd += 1 }
                let length = runEnd - pos
                // A span can't outlast the link label it is in.
                let limit = link == nil ? end : linkLabelEnd
                var closer: Range<Int>?
                var k = runEnd
                while k < limit {
                    guard units[k] == u else {
                        k += 1
                        continue
                    }
                    var e = k
                    while e < limit, units[e] == u { e += 1 }
                    if e - k == length {
                        closer = k..<e
                        break
                    }
                    k = e
                }
                guard let closer else {
                    pieces.append(Piece(range: pos..<runEnd, bold: bold, italic: italic, isMarker: false, link: link))
                    pos = runEnd
                    continue
                }
                // One space padding each side is markup, so a span can start or end with a backtick.
                var contentStart = runEnd
                var contentEnd = closer.lowerBound
                if contentEnd - contentStart >= 2, units[contentStart] == 0x20, units[contentEnd - 1] == 0x20,
                    !units[contentStart..<contentEnd].allSatisfy({ $0 == 0x20 })
                {
                    contentStart += 1
                    contentEnd -= 1
                }
                pieces.append(Piece(range: pos..<contentStart, bold: false, italic: false, isMarker: true, link: nil))
                if contentEnd > contentStart {
                    pieces.append(
                        Piece(range: contentStart..<contentEnd, bold: bold, italic: italic, isMarker: false, link: link, code: true))
                }
                pieces.append(Piece(range: contentEnd..<closer.upperBound, bold: false, italic: false, isMarker: true, link: nil))
                pos = closer.upperBound
                continue
            }

            // An image inside text reads as a link to it; its `!` is markup.
            if link == nil, isImageBang(units, at: pos) {
                pieces.append(Piece(range: pos..<(pos + 1), bold: false, italic: false, isMarker: true, link: nil))
                pos += 1
                continue
            }

            if u == 0x5B, link == nil, let match = inlineLink(units, at: pos) {
                pieces.append(Piece(range: pos..<(pos + 1), bold: false, italic: false, isMarker: true, link: nil))
                link = match.destination
                linkLabelEnd = match.labelEnd
                linkEnd = match.end
                pos += 1
                continue
            }

            if link == nil, isAutolinkLead(u), let range = autolink(units, at: pos, start: start) {
                let destination = String(decoding: units[range], as: UTF16.self)
                pieces.append(Piece(range: range, bold: bold, italic: italic, isMarker: false, link: destination))
                pos = range.upperBound
                continue
            }

            if isDelimiter(u) {
                var runEnd = pos + 1
                while runEnd < end, units[runEnd] == u {
                    runEnd += 1
                }
                let length = runEnd - pos
                let isUnderscore = u == 0x5F
                let relevantState = length == 1 ? italic : bold
                let opening = !relevantState

                let valid: Bool
                if opening {
                    let next: UInt16? = runEnd < end ? units[runEnd] : nil
                    var ok = next != nil && !isWhitespace(next!)
                    if isUnderscore {
                        let prev: UInt16? = pos > start ? units[pos - 1] : nil
                        ok = ok && (prev == nil || !isAlnum(prev!))
                    }
                    valid = ok
                } else {
                    let prev: UInt16? = pos > start ? units[pos - 1] : nil
                    var ok = prev != nil && !isWhitespace(prev!)
                    if isUnderscore {
                        let next: UInt16? = runEnd < end ? units[runEnd] : nil
                        ok = ok && (next == nil || !isAlnum(next!))
                    }
                    valid = ok
                }

                if valid {
                    if length == 1 {
                        pieces.append(Piece(range: pos..<runEnd, bold: false, italic: false, isMarker: true, link: nil))
                        italic.toggle()
                    } else if length == 2 {
                        pieces.append(Piece(range: pos..<runEnd, bold: false, italic: false, isMarker: true, link: nil))
                        bold.toggle()
                    } else {
                        let markerEnd = pos + 3
                        pieces.append(Piece(range: pos..<markerEnd, bold: false, italic: false, isMarker: true, link: nil))
                        bold.toggle()
                        italic.toggle()
                        if runEnd > markerEnd {
                            pieces.append(Piece(range: markerEnd..<runEnd, bold: bold, italic: italic, isMarker: false, link: link))
                        }
                    }
                    pos = runEnd
                    continue
                }

                pieces.append(Piece(range: pos..<runEnd, bold: bold, italic: italic, isMarker: false, link: link))
                pos = runEnd
                continue
            }

            var runEnd = pos + 1
            while runEnd < end {
                if runEnd == linkLabelEnd {
                    break
                }
                let c = units[runEnd]
                if c == 0x5C, runEnd + 1 < end, isEscapable(units[runEnd + 1]) {
                    break
                }
                if isDelimiter(c) || c == 0x60 {
                    break
                }
                if link == nil, c == 0x5B, inlineLink(units, at: runEnd) != nil {
                    break
                }
                if link == nil, isImageBang(units, at: runEnd) {
                    break
                }
                if link == nil, isAutolinkLead(c), autolink(units, at: runEnd, start: start) != nil {
                    break
                }
                runEnd += 1
            }
            pieces.append(Piece(range: pos..<runEnd, bold: bold, italic: italic, isMarker: false, link: link))
            pos = runEnd
        }

        var spans: [Span] = []
        for piece in pieces {
            if let last = spans.indices.last,
                spans[last].bold == piece.bold,
                spans[last].italic == piece.italic,
                spans[last].isMarker == piece.isMarker,
                spans[last].link == piece.link,
                spans[last].code == piece.code,
                spans[last].range.upperBound == piece.range.lowerBound
            {
                spans[last].range = spans[last].range.lowerBound..<piece.range.upperBound
            } else {
                spans.append(
                    Span(range: piece.range, bold: piece.bold, italic: piece.italic, isMarker: piece.isMarker, link: piece.link, code: piece.code)
                )
            }
        }
        return spans
    }
}
