import Foundation

/// The edits `MarkdownEditor` makes for the user: continuing a list on
/// return, and wrapping a selection in `**` or `_`.
/// Ported from the Apple app's `CohesionUI`, so editing behaves the same in
/// both.
enum MarkdownEditing {
    struct Edit {
        var range: NSRange
        var replacement: String
        var selection: NSRange
    }

    /// On a list item, starts the next item with the same marker (numbered
    /// one higher); on an empty item, removes its marker and ends the list.
    /// `nil` leaves the return to the text view.
    static func returnEdit(in text: NSString, selection: NSRange) -> Edit? {
        let lineRange = text.lineRange(for: NSRange(location: selection.location, length: 0))
        var lineContent = text.substring(with: lineRange)
        if lineContent.hasSuffix("\n") { lineContent.removeLast() }
        if lineContent.hasSuffix("\r") { lineContent.removeLast() }
        let line = Markdown.parseLine(Substring(lineContent))

        let isNumbered: Bool
        switch line.kind {
        case .bullet: isNumbered = false
        case .numbered: isNumbered = true
        case .paragraph, .heading, .image, .quote, .fenceOpen, .code, .fenceClose: return nil
        }

        let marker = line.marker!
        let lineContentNSString = lineContent as NSString
        let markerText = lineContentNSString.substring(with: NSRange(location: 0, length: marker.upperBound))
        let leadingWhitespace = String(markerText.prefix(while: { $0 == " " || $0 == "\t" }))

        if marker.upperBound >= lineContentNSString.length {
            let removeRange = NSRange(location: lineRange.location, length: marker.upperBound)
            return Edit(range: removeRange, replacement: "", selection: NSRange(location: lineRange.location, length: 0))
        }

        let newMarker: String
        if isNumbered {
            let rest = markerText.drop(while: { $0 == " " || $0 == "\t" })
            let digits = rest.prefix(while: { $0.isNumber })
            let punctuation = rest.dropFirst(digits.count).first!
            newMarker = "\(leadingWhitespace)\(Int(digits)! + 1)\(punctuation) "
        } else {
            let bulletChar = markerText.first(where: { $0 != " " && $0 != "\t" })!
            newMarker = "\(leadingWhitespace)\(bulletChar) "
        }

        let insertion = "\n" + newMarker
        return Edit(
            range: selection,
            replacement: insertion,
            selection: NSRange(location: selection.location + (insertion as NSString).length, length: 0)
        )
    }

    /// Wraps the selection in `delimiter`, or unwraps it if it already is;
    /// with nothing selected, inserts a pair with the caret between them.
    static func toggleEdit(delimiter: String, in text: NSString, selection: NSRange) -> Edit {
        let delimiterLength = (delimiter as NSString).length

        if selection.length == 0 {
            return Edit(
                range: selection,
                replacement: delimiter + delimiter,
                selection: NSRange(location: selection.location + delimiterLength, length: 0)
            )
        }

        let beforeRange = NSRange(location: selection.location - delimiterLength, length: delimiterLength)
        let afterRange = NSRange(location: selection.location + selection.length, length: delimiterLength)
        let isWrapped = beforeRange.location >= 0
            && NSMaxRange(afterRange) <= text.length
            && text.substring(with: beforeRange) == delimiter
            && text.substring(with: afterRange) == delimiter

        if isWrapped {
            let fullRange = NSRange(
                location: beforeRange.location,
                length: delimiterLength + selection.length + delimiterLength
            )
            return Edit(
                range: fullRange,
                replacement: text.substring(with: selection),
                selection: NSRange(location: beforeRange.location, length: selection.length)
            )
        }

        return Edit(
            range: selection,
            replacement: delimiter + text.substring(with: selection) + delimiter,
            selection: NSRange(location: selection.location + delimiterLength, length: selection.length)
        )
    }
}
