#if canImport(UIKit)
import UIKit

private typealias StylerFont = UIFont
private typealias StylerColor = UIColor
#else
import AppKit

private typealias StylerFont = NSFont
private typealias StylerColor = NSColor
#endif

/// Styles each paragraph of `MarkdownEditor`'s source as TextKit lays it
/// out: headings large, bold and italic spans in their face, markers dimmed,
/// links in the accent and underlined, list items with hanging indents. The
/// characters stay the source's, so the text is still Markdown.
/// Ported from the Apple app's `CohesionUI`.
final class MarkdownParagraphStyler: NSObject, NSTextContentStorageDelegate {
    /// How a link run is drawn. The text view repeats these as its
    /// `linkTextAttributes`, so the system's own link tint can't override
    /// the styler's.
    static let linkAttributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: StylerColor.markdownLink,
        .underlineStyle: NSUnderlineStyle.single.rawValue,
    ]

    func textContentStorage(
        _ textContentStorage: NSTextContentStorage,
        textParagraphWith range: NSRange
    ) -> NSTextParagraph? {
        let original = textContentStorage.textStorage!.attributedSubstring(from: range).string
        let content = original.hasSuffix("\n") ? original.dropLast() : Substring(original)
        let line = Markdown.parseLine(content)

        let paragraphStyle = NSMutableParagraphStyle()
        switch line.kind {
        case .bullet(let indent), .numbered(let indent):
            paragraphStyle.firstLineHeadIndent = CGFloat(indent) * MarkdownMetrics.indentStep
            paragraphStyle.headIndent = CGFloat(indent) * MarkdownMetrics.indentStep + MarkdownMetrics.markerWidth
            paragraphStyle.paragraphSpacing = MarkdownMetrics.listSpacing
        case .heading, .paragraph, .image, .quote, .fenceOpen, .code, .fenceClose:
            paragraphStyle.paragraphSpacing = MarkdownMetrics.blockSpacing
        }

        let result = NSMutableAttributedString(
            string: original,
            attributes: [
                .font: StylerFont.preferredFont(forTextStyle: .body),
                .foregroundColor: StylerColor.markdownText,
                .paragraphStyle: paragraphStyle,
            ]
        )

        if case .heading(let level) = line.kind {
            let style: StylerFont.TextStyle = level <= 1 ? .title1 : level == 2 ? .title2 : .title3
            let headingFont = StylerFont.preferredFont(forTextStyle: style).addingTraits(bold: true, italic: false)
            result.addAttribute(.font, value: headingFont, range: NSRange(location: 0, length: result.length))
        }

        for span in line.spans {
            let spanRange = NSRange(location: span.range.lowerBound, length: span.range.count)
            if span.bold || span.italic {
                result.enumerateAttribute(.font, in: spanRange) { value, subrange, _ in
                    let font = value as! StylerFont
                    result.addAttribute(.font, value: font.addingTraits(bold: span.bold, italic: span.italic), range: subrange)
                }
            }
            if span.code {
                result.enumerateAttribute(.font, in: spanRange) { value, subrange, _ in
                    let font = value as! StylerFont
                    result.addAttribute(
                        .font, value: StylerFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular), range: subrange)
                }
            }
            if span.isMarker {
                result.addAttribute(.foregroundColor, value: StylerColor.markdownMarker, range: spanRange)
            }
            if let destination = span.link {
                result.addAttributes(Self.linkAttributes, range: spanRange)
                // Makes the run a real link to the text system, which
                // accessibility reads; the colour alone doesn't.
                result.addAttribute(.link, value: destination, range: spanRange)
            }
        }

        if let marker = line.marker {
            let markerRange = NSRange(location: marker.lowerBound, length: marker.count)
            result.addAttribute(.foregroundColor, value: StylerColor.markdownMarker, range: markerRange)
        }

        // The returned string must have exactly the source range's characters.
        return NSTextParagraph(attributedString: result)
    }
}

private extension StylerFont {
    func addingTraits(bold: Bool, italic: Bool) -> StylerFont {
        var traits = fontDescriptor.symbolicTraits
        #if canImport(UIKit)
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        return UIFont(descriptor: fontDescriptor.withSymbolicTraits(traits)!, size: 0)
        #else
        if bold { traits.insert(.bold) }
        if italic { traits.insert(.italic) }
        return NSFont(descriptor: fontDescriptor.withSymbolicTraits(traits), size: 0) ?? self
        #endif
    }
}

private extension StylerColor {
    /// The `AccentColor` asset, as `.tint` draws links in `MarkdownText`.
    static var markdownLink: StylerColor {
        #if canImport(UIKit)
        UIColor(named: "AccentColor") ?? .tintColor
        #else
        NSColor(named: "AccentColor") ?? .controlAccentColor
        #endif
    }

    static var markdownText: StylerColor {
        #if canImport(UIKit)
        .label
        #else
        .labelColor
        #endif
    }

    static var markdownMarker: StylerColor {
        #if canImport(UIKit)
        .secondaryLabel
        #else
        .secondaryLabelColor
        #endif
    }
}
