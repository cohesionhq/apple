import Foundation

/// What cohesiond draws a diagram as.
public enum MermaidFormat: String {
    /// Takes its colours from `--pele-*` CSS variables, has no background
    /// and scales from its `viewBox`, so neither a theme change nor a resize
    /// asks again.
    case svg
}

/// Why cohesiond didn't draw a diagram. The source shows as code either way.
public enum MermaidRefusal: String, Decodable {
    /// Not a kind of diagram the renderer knows, or not a diagram at all.
    case unsupported
    /// The source doesn't parse: mistyped, or still streaming in.
    case syntax
    case semantic
    case tooLarge
    case tooSlow
    /// Too many diagrams were already waiting; asking again later may work.
    case busy
    /// The renderer failed, which isn't the diagram's fault.
    case failed

    /// Whether the same source would get the same answer.
    var isLasting: Bool {
        self != .busy && self != .failed
    }
}

/// A diagram as cohesiond drew it, or why it didn't.
public enum RenderedMermaid: Decodable {
    /// `width` and `height` are the size it was laid out at, which it scales
    /// from.
    case svg(String, width: Double, height: Double)
    case refused(MermaidRefusal)

    private enum CodingKeys: String, CodingKey {
        case kind, svg, width, height, reason
    }

    private enum Kind: String, Decodable {
        case svg, refused
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .svg:
            self = .svg(
                try container.decode(String.self, forKey: .svg),
                width: try container.decode(Double.self, forKey: .width),
                height: try container.decode(Double.self, forKey: .height)
            )
        case .refused:
            self = .refused(try container.decode(MermaidRefusal.self, forKey: .reason))
        }
    }
}

/// What a kept diagram is kept under: a new width is a new layout.
struct RenderedMermaidKey: Hashable {
    let source: String
    let width: Int?
    let format: MermaidFormat
}
