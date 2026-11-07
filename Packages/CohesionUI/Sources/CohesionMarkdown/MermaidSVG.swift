import Foundation

/// Cleans the SVG cohesiond draws before a web view shows it. A diagram's
/// labels, colours and links come from whatever an agent wrote, so what's
/// kept is what a drawing needs: scripts, HTML, animation, links and anything
/// from outside go, whatever Pele made of them.
nonisolated enum MermaidSVG {
    /// `svg` with only what's safe to show, or nil when it isn't an SVG.
    static func sanitized(_ svg: String) -> String? {
        let parser = XMLParser(data: Data(svg.utf8))
        let writer = Writer()
        parser.delegate = writer
        guard parser.parse(), writer.sawRoot else { return nil }
        return writer.output
    }

    /// What a drawing is made of.
    private static let drawn: Set<String> = [
        "svg", "g", "defs", "symbol", "use", "title", "desc",
        "path", "rect", "circle", "ellipse", "line", "polygon", "polyline", "image",
        "text", "tspan", "textPath",
        "linearGradient", "radialGradient", "stop", "pattern", "marker", "clipPath", "mask",
    ]

    /// Shown without the element around them: a link can't be followed here.
    private static let unwrapped: Set<String> = ["a"]

    /// Whether `name="value"` on `element` draws without reaching outside
    /// the document or running anything.
    private static func isSafe(_ name: String, _ value: String, on element: String) -> Bool {
        let name = name.lowercased()
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if name.hasPrefix("on") { return false }
        if name == "href" || name == "xlink:href" {
            return value.hasPrefix("#") || (element == "image" && value.hasPrefix("data:image/"))
        }
        // An escape can spell out what the check below looks for.
        if name == "style", value.contains("\\") { return false }
        return !value.components(separatedBy: "url(").dropFirst().contains { reference in
            !reference.drop { $0 == " " || $0 == "\"" || $0 == "'" }.hasPrefix("#")
        }
    }

    /// Writes what `drawn` keeps as `XMLParser` reads it.
    private final class Writer: NSObject, XMLParserDelegate {
        var output = ""
        var sawRoot = false
        /// How deep in an element that isn't drawn the parser is, which
        /// goes with everything inside it.
        private var dropped = 0

        func parser(
            _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String]
        ) {
            if !sawRoot {
                guard elementName == "svg" else {
                    parser.abortParsing()
                    return
                }
                sawRoot = true
            }
            if dropped > 0 || !(MermaidSVG.drawn.contains(elementName) || MermaidSVG.unwrapped.contains(elementName)) {
                dropped += 1
                return
            }
            guard !MermaidSVG.unwrapped.contains(elementName) else { return }
            output += "<\(elementName)"
            for (name, value) in attributes.sorted(by: { $0.key < $1.key })
            where MermaidSVG.isSafe(name, value, on: elementName) && name.allSatisfy(Self.isAttributeNameCharacter) {
                output += " \(name)=\"\(Self.escaped(value).replacingOccurrences(of: "\"", with: "&quot;"))\""
            }
            output += ">"
        }

        func parser(
            _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?
        ) {
            if dropped > 0 {
                dropped -= 1
            } else if !MermaidSVG.unwrapped.contains(elementName) {
                output += "</\(elementName)>"
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if dropped == 0 { output += Self.escaped(string) }
        }

        private static func isAttributeNameCharacter(_ character: Character) -> Bool {
            character.isLetter || character.isNumber || character == "-" || character == ":" || character == "_"
        }

        private static func escaped(_ text: String) -> String {
            text
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
        }
    }
}
