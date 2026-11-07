import CohesionCore
import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Draws the small SVGs extension manifests give as icons, which neither
/// `AsyncImage` nor the platform's images decode. It covers what icons use: `svg`, `g`
/// and the basic shapes and paths, filled or stroked in flat colours, with
/// transforms and opacity. Anything else (gradients, text, images, clips,
/// CSS, `<use>`) fails the whole icon, so it shows as its initial rather
/// than half drawn.
public nonisolated enum SVGIcon {
    /// `data` drawn into a square `side` points across, or nil when it
    /// isn't an SVG this can draw.
    public static func image(from data: Data, side: CGFloat, scale: CGFloat) -> PlatformImage? {
        guard let root = SVGElement.parse(data), root.name == "svg" else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)
        #if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        var drew = true
        let image = UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
            do {
                try draw(root, style: SVGStyle(), viewport: bounds.size, root: bounds, in: context.cgContext)
            } catch {
                drew = false
            }
        }
        return drew ? image : nil
        #else
        let pixels = Int((side * scale).rounded(.up))
        guard let context = CGContext(
            data: nil,
            width: pixels,
            height: pixels,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        // An SVG's y runs down, a bitmap context's up.
        context.translateBy(x: 0, y: CGFloat(pixels))
        context.scaleBy(x: scale, y: -scale)
        guard (try? draw(root, style: SVGStyle(), viewport: bounds.size, root: bounds, in: context)) != nil,
              let image = context.makeImage()
        else { return nil }
        return NSImage(cgImage: image, size: bounds.size)
        #endif
    }

    /// Draws `element` and its children; `root` is the image's bounds when
    /// `element` is the outermost `svg`.
    private static func draw(
        _ element: SVGElement, style inherited: SVGStyle, viewport: CGSize, root: CGRect? = nil, in context: CGContext
    ) throws {
        let attributes = element.attributes
        for name in ["clip-path", "mask", "filter"] where attributes[name].map({ $0 != "none" }) ?? false {
            throw SVGUnsupported()
        }
        if attributes["display"] == "none" { return }
        var style = inherited
        try style.apply(attributes)

        context.saveGState()
        defer { context.restoreGState() }
        if let transform = attributes["transform"] {
            context.concatenate(try transformation(transform))
        }
        let opacity = try attributes["opacity"].map(SVGStyle.opacity) ?? 1
        if opacity < 1 {
            context.setAlpha(opacity)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
        }
        defer { if opacity < 1 { context.endTransparencyLayer() } }

        switch element.name {
        case "svg":
            let frame = try root ?? CGRect(
                x: element.length("x", relativeTo: viewport.width),
                y: element.length("y", relativeTo: viewport.height),
                width: element.length("width", relativeTo: viewport.width, default: viewport.width),
                height: element.length("height", relativeTo: viewport.height, default: viewport.height))
            guard frame.width > 0, frame.height > 0 else { return }
            var viewBox: CGRect
            if let value = attributes["viewBox"] {
                viewBox = try rectangle(value)
            } else if root != nil {
                // The outermost `svg` without a `viewBox` draws in its own
                // width and height, scaled to the image.
                guard let width = attributes["width"], let height = attributes["height"] else { throw SVGUnsupported() }
                viewBox = CGRect(x: 0, y: 0, width: try length(width), height: try length(height))
            } else {
                viewBox = CGRect(origin: .zero, size: frame.size)
            }
            guard viewBox.width > 0, viewBox.height > 0 else { throw SVGUnsupported() }
            if root == nil { context.clip(to: frame) }
            context.concatenate(fitting(viewBox, in: frame, stretched: attributes["preserveAspectRatio"] == "none"))
            for child in element.children {
                try draw(child, style: style, viewport: viewBox.size, in: context)
            }
        case "g":
            for child in element.children {
                try draw(child, style: style, viewport: viewport, in: context)
            }
        case "title", "desc", "metadata", "defs":
            // Nothing drawn; what `defs` holds only shows through a
            // reference, and every reference is unsupported.
            break
        case let name where name.contains(":"):
            // An editor's own markup, such as Inkscape's.
            break
        default:
            guard let path = try shape(element, viewport: viewport) else { return }
            style.paint(path, in: context)
        }
    }

    /// The outline of a basic shape or path, or nil when it has no area to
    /// draw, such as a rectangle without a width.
    private static func shape(_ element: SVGElement, viewport: CGSize) throws -> CGPath? {
        let diagonal = (viewport.width * viewport.width + viewport.height * viewport.height).squareRoot() / 2.squareRoot()
        switch element.name {
        case "rect":
            let rect = try CGRect(
                x: element.length("x", relativeTo: viewport.width),
                y: element.length("y", relativeTo: viewport.height),
                width: element.length("width", relativeTo: viewport.width),
                height: element.length("height", relativeTo: viewport.height))
            guard rect.width > 0, rect.height > 0 else { return nil }
            let rx = try element.attributes["rx"].map { try length($0, relativeTo: viewport.width) }
            let ry = try element.attributes["ry"].map { try length($0, relativeTo: viewport.height) }
            let cornerWidth = min(max(rx ?? ry ?? 0, 0), rect.width / 2)
            let cornerHeight = min(max(ry ?? rx ?? 0, 0), rect.height / 2)
            return CGPath(roundedRect: rect, cornerWidth: cornerWidth, cornerHeight: cornerHeight, transform: nil)
        case "circle":
            let r = try element.length("r", relativeTo: diagonal)
            guard r > 0 else { return nil }
            let cx = try element.length("cx", relativeTo: viewport.width)
            let cy = try element.length("cy", relativeTo: viewport.height)
            return CGPath(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r), transform: nil)
        case "ellipse":
            let rx = try element.length("rx", relativeTo: viewport.width)
            let ry = try element.length("ry", relativeTo: viewport.height)
            guard rx > 0, ry > 0 else { return nil }
            let cx = try element.length("cx", relativeTo: viewport.width)
            let cy = try element.length("cy", relativeTo: viewport.height)
            return CGPath(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: 2 * rx, height: 2 * ry), transform: nil)
        case "line":
            let path = CGMutablePath()
            try path.move(to: CGPoint(
                x: element.length("x1", relativeTo: viewport.width), y: element.length("y1", relativeTo: viewport.height)))
            try path.addLine(to: CGPoint(
                x: element.length("x2", relativeTo: viewport.width), y: element.length("y2", relativeTo: viewport.height)))
            return path
        case "polyline", "polygon":
            var scanner = SVGScanner(element.attributes["points"] ?? "")
            var points: [CGPoint] = []
            while !scanner.isAtEnd {
                points.append(CGPoint(x: try scanner.number(), y: try scanner.number()))
            }
            guard !points.isEmpty else { return nil }
            let path = CGMutablePath()
            path.addLines(between: points)
            if element.name == "polygon" { path.closeSubpath() }
            return path
        case "path":
            return try SVGPath.parse(element.attributes["d"] ?? "")
        default:
            throw SVGUnsupported()
        }
    }

    /// Maps `viewBox` onto `frame`: scaled to fit and centred, or stretched
    /// to fill it.
    private static func fitting(_ viewBox: CGRect, in frame: CGRect, stretched: Bool) -> CGAffineTransform {
        var scaleX = frame.width / viewBox.width
        var scaleY = frame.height / viewBox.height
        if !stretched {
            scaleX = min(scaleX, scaleY)
            scaleY = scaleX
        }
        let x = frame.minX + (frame.width - viewBox.width * scaleX) / 2 - viewBox.minX * scaleX
        let y = frame.minY + (frame.height - viewBox.height * scaleY) / 2 - viewBox.minY * scaleY
        return CGAffineTransform(a: scaleX, b: 0, c: 0, d: scaleY, tx: x, ty: y)
    }

    /// A `viewBox`: its x, y, width and height.
    private static func rectangle(_ value: String) throws -> CGRect {
        var scanner = SVGScanner(value)
        let rect = try CGRect(x: scanner.number(), y: scanner.number(), width: scanner.number(), height: scanner.number())
        guard scanner.isAtEnd else { throw SVGUnsupported() }
        return rect
    }

    /// A `transform` list, applied right to left as SVG does.
    private static func transformation(_ value: String) throws -> CGAffineTransform {
        var scanner = SVGScanner(value)
        var result = CGAffineTransform.identity
        while !scanner.isAtEnd {
            let name = scanner.word()
            guard scanner.consume(UInt8(ascii: "(")) else { throw SVGUnsupported() }
            var values: [CGFloat] = []
            while !scanner.consume(UInt8(ascii: ")")) {
                values.append(try scanner.number())
            }
            let transform: CGAffineTransform
            switch (name, values.count) {
            case ("matrix", 6):
                transform = CGAffineTransform(
                    a: values[0], b: values[1], c: values[2], d: values[3], tx: values[4], ty: values[5])
            case ("translate", 1), ("translate", 2):
                transform = CGAffineTransform(translationX: values[0], y: values.count == 2 ? values[1] : 0)
            case ("scale", 1), ("scale", 2):
                transform = CGAffineTransform(scaleX: values[0], y: values.count == 2 ? values[1] : values[0])
            case ("rotate", 1), ("rotate", 3):
                let rotation = CGAffineTransform(rotationAngle: values[0] * .pi / 180)
                transform = values.count == 3
                    ? CGAffineTransform(translationX: -values[1], y: -values[2])
                        .concatenating(rotation)
                        .concatenating(CGAffineTransform(translationX: values[1], y: values[2]))
                    : rotation
            case ("skewX", 1):
                transform = CGAffineTransform(a: 1, b: 0, c: tan(values[0] * .pi / 180), d: 1, tx: 0, ty: 0)
            case ("skewY", 1):
                transform = CGAffineTransform(a: 1, b: tan(values[0] * .pi / 180), c: 0, d: 1, tx: 0, ty: 0)
            default:
                throw SVGUnsupported()
            }
            result = transform.concatenating(result)
        }
        return result
    }

    /// A length in user units: a bare number or pixels, or a percentage of
    /// `reference`.
    fileprivate static func length(_ value: String, relativeTo reference: CGFloat = 0) throws -> CGFloat {
        let value = value.trimmingCharacters(in: .whitespaces)
        if value.hasSuffix("%"), let percent = Double(value.dropLast()) {
            return CGFloat(percent) / 100 * reference
        }
        guard let number = Double(value.hasSuffix("px") ? String(value.dropLast(2)) : value) else {
            throw SVGUnsupported()
        }
        return CGFloat(number)
    }
}

/// Something in an icon `SVGIcon` doesn't draw.
nonisolated private struct SVGUnsupported: Error {}

/// One element of a parsed SVG, with its `style` declarations folded into
/// its attributes.
nonisolated private struct SVGElement {
    let name: String
    var attributes: [String: String]
    var children: [SVGElement] = []

    /// The outermost element of `data`, or nil when it isn't XML.
    static func parse(_ data: Data) -> SVGElement? {
        let parser = XMLParser(data: data)
        let builder = Builder()
        parser.delegate = builder
        guard parser.parse() else { return nil }
        return builder.root
    }

    /// The length attribute `name`, or `defaultValue` when it's missing.
    func length(_ name: String, relativeTo reference: CGFloat, default defaultValue: CGFloat = 0) throws -> CGFloat {
        try attributes[name].map { try SVGIcon.length($0, relativeTo: reference) } ?? defaultValue
    }

    /// Builds the tree as `XMLParser` reads it.
    private final class Builder: NSObject, XMLParserDelegate {
        var root: SVGElement?
        private var stack: [SVGElement] = []

        func parser(
            _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String]
        ) {
            var attributes = attributes
            for declaration in (attributes["style"] ?? "").split(separator: ";") {
                let parts = declaration.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { continue }
                attributes[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1]
                    .replacingOccurrences(of: "!important", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            stack.append(SVGElement(name: elementName, attributes: attributes))
        }

        func parser(
            _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?
        ) {
            guard let element = stack.popLast() else { return }
            if stack.isEmpty {
                root = element
            } else {
                stack[stack.count - 1].children.append(element)
            }
        }
    }
}

/// The paint an element inherits from its parents, with its own on top.
nonisolated private struct SVGStyle {
    /// A fill or stroke: nothing, or a flat colour.
    enum Paint {
        case none
        case color(CGColor)
        /// `currentColor`, resolved when painting.
        case current
    }

    var color = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
    var fill = Paint.color(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
    var fillOpacity: CGFloat = 1
    var fillRule = CGPathFillRule.winding
    var stroke = Paint.none
    var strokeOpacity: CGFloat = 1
    var strokeWidth: CGFloat = 1
    var lineCap = CGLineCap.butt
    var lineJoin = CGLineJoin.miter
    var miterLimit: CGFloat = 4

    /// Takes on the presentation attributes `attributes` sets.
    mutating func apply(_ attributes: [String: String]) throws {
        func value(_ name: String) -> String? {
            attributes[name].flatMap { $0 == "inherit" ? nil : $0.trimmingCharacters(in: .whitespaces) }
        }
        if let color = value("color") {
            guard case .color(let resolved) = try Self.paint(color) else { throw SVGUnsupported() }
            self.color = resolved
        }
        if let fill = value("fill") { self.fill = try Self.paint(fill) }
        if let opacity = value("fill-opacity") { fillOpacity = try Self.opacity(opacity) }
        if let rule = value("fill-rule") { fillRule = rule == "evenodd" ? .evenOdd : .winding }
        if let stroke = value("stroke") { self.stroke = try Self.paint(stroke) }
        if let opacity = value("stroke-opacity") { strokeOpacity = try Self.opacity(opacity) }
        if let width = value("stroke-width") { strokeWidth = try SVGIcon.length(width) }
        if let cap = value("stroke-linecap") {
            lineCap = switch cap { case "round": .round; case "square": .square; default: .butt }
        }
        if let join = value("stroke-linejoin") {
            lineJoin = switch join { case "round": .round; case "bevel": .bevel; default: .miter }
        }
        if let limit = value("stroke-miterlimit") { miterLimit = try SVGIcon.length(limit) }
        if let dashes = value("stroke-dasharray"), dashes != "none" { throw SVGUnsupported() }
    }

    /// Fills, then strokes, `path`.
    func paint(_ path: CGPath, in context: CGContext) {
        if let fill = resolved(fill, opacity: fillOpacity) {
            context.addPath(path)
            context.setFillColor(fill)
            context.fillPath(using: fillRule)
        }
        if let stroke = resolved(stroke, opacity: strokeOpacity), strokeWidth > 0 {
            context.addPath(path)
            context.setStrokeColor(stroke)
            context.setLineWidth(strokeWidth)
            context.setLineCap(lineCap)
            context.setLineJoin(lineJoin)
            context.setMiterLimit(miterLimit)
            context.strokePath()
        }
    }

    private func resolved(_ paint: Paint, opacity: CGFloat) -> CGColor? {
        switch paint {
        case .none: nil
        case .color(let color): color.copy(alpha: color.alpha * opacity)
        case .current: color.copy(alpha: color.alpha * opacity)
        }
    }

    /// An opacity, as a number or a percentage, clamped to 0…1.
    static func opacity(_ value: String) throws -> CGFloat {
        let value = value.trimmingCharacters(in: .whitespaces)
        let number = value.hasSuffix("%") ? Double(value.dropLast()).map { $0 / 100 } : Double(value)
        guard let number else { throw SVGUnsupported() }
        return CGFloat(min(max(number, 0), 1))
    }

    /// The colours CSS names that icons tend to use.
    private static let named: [String: UInt32] = [
        "black": 0x000000, "white": 0xFFFFFF, "red": 0xFF0000, "green": 0x008000, "blue": 0x0000FF,
        "yellow": 0xFFFF00, "orange": 0xFFA500, "purple": 0x800080, "gray": 0x808080, "grey": 0x808080,
        "silver": 0xC0C0C0,
    ]

    /// A `fill` or `stroke` value: `none`, `currentColor`, a hex or `rgb()`
    /// colour, or one of `named`.
    static func paint(_ value: String) throws -> Paint {
        let value = value.lowercased()
        if value == "none" || value == "transparent" { return .none }
        if value == "currentcolor" { return .current }
        if let rgb = named[value] {
            return .color(color(red: rgb >> 16, green: rgb >> 8 & 0xFF, blue: rgb & 0xFF))
        }
        if value.hasPrefix("#") {
            let hex = Array(value.dropFirst())
            guard hex.allSatisfy(\.isHexDigit) else { throw SVGUnsupported() }
            // `#rgb` and `#rgba` double each digit.
            let digits = hex.count <= 4 ? hex.flatMap { [$0, $0] } : hex
            guard digits.count == 6 || digits.count == 8, let number = UInt32(String(digits), radix: 16) else {
                throw SVGUnsupported()
            }
            let rgb = digits.count == 8 ? number >> 8 : number
            let alpha = digits.count == 8 ? CGFloat(number & 0xFF) / 255 : 1
            return .color(color(red: rgb >> 16, green: rgb >> 8 & 0xFF, blue: rgb & 0xFF, alpha: alpha))
        }
        if value.hasPrefix("rgb"), let open = value.firstIndex(of: "("), value.hasSuffix(")") {
            let parts = value[value.index(after: open)..<value.index(before: value.endIndex)]
                .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "/" })
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 3 || parts.count == 4 else { throw SVGUnsupported() }
            let channels = try parts.prefix(3).map { part -> CGFloat in
                if part.hasSuffix("%") { return try opacity(part) }
                guard let number = Double(part) else { throw SVGUnsupported() }
                return CGFloat(min(max(number, 0), 255) / 255)
            }
            let alpha = try parts.count == 4 ? opacity(parts[3]) : 1
            return .color(CGColor(srgbRed: channels[0], green: channels[1], blue: channels[2], alpha: alpha))
        }
        throw SVGUnsupported()
    }

    private static func color(red: UInt32, green: UInt32, blue: UInt32, alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: alpha)
    }
}

/// Reads a path's `d`.
nonisolated private enum SVGPath {
    static func parse(_ d: String) throws -> CGPath? {
        var scanner = SVGScanner(d)
        let path = CGMutablePath()
        var command: UInt8?
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        // The control point a smooth curve reflects, and whether the last
        // segment was cubic (`C`, `S`) or quadratic (`Q`, `T`).
        var lastControl: CGPoint?
        var lastWasCubic = false

        while !scanner.isAtEnd {
            if let letter = scanner.letter() {
                command = letter
            } else if command == nil {
                throw SVGUnsupported()
            }
            guard let letter = command else { throw SVGUnsupported() }
            let relative = letter >= UInt8(ascii: "a")
            let origin = relative ? current : .zero
            func point() throws -> CGPoint {
                let x = try scanner.number()
                let y = try scanner.number()
                return CGPoint(x: origin.x + x, y: origin.y + y)
            }
            // Every command but a move needs a current point.
            if path.isEmpty && letter | 0x20 != UInt8(ascii: "m") { throw SVGUnsupported() }

            var control: CGPoint?
            var isCubic = false
            switch letter | 0x20 {
            case UInt8(ascii: "m"):
                current = try point()
                subpathStart = current
                path.move(to: current)
                // Pairs after a move are lines.
                command = relative ? UInt8(ascii: "l") : UInt8(ascii: "L")
            case UInt8(ascii: "l"):
                current = try point()
                path.addLine(to: current)
            case UInt8(ascii: "h"):
                current = CGPoint(x: origin.x + (try scanner.number()), y: current.y)
                path.addLine(to: current)
            case UInt8(ascii: "v"):
                current = CGPoint(x: current.x, y: origin.y + (try scanner.number()))
                path.addLine(to: current)
            case UInt8(ascii: "c"):
                let first = try point()
                let second = try point()
                current = try point()
                path.addCurve(to: current, control1: first, control2: second)
                control = second
                isCubic = true
            case UInt8(ascii: "s"):
                let first = lastWasCubic ? reflect(lastControl, about: current) : current
                let second = try point()
                current = try point()
                path.addCurve(to: current, control1: first, control2: second)
                control = second
                isCubic = true
            case UInt8(ascii: "q"):
                let quad = try point()
                current = try point()
                path.addQuadCurve(to: current, control: quad)
                control = quad
            case UInt8(ascii: "t"):
                let quad = !lastWasCubic && lastControl != nil ? reflect(lastControl, about: current) : current
                current = try point()
                path.addQuadCurve(to: current, control: quad)
                control = quad
            case UInt8(ascii: "a"):
                let rx = try scanner.number()
                let ry = try scanner.number()
                let rotation = try scanner.number()
                let largeArc = try scanner.flag()
                let sweep = try scanner.flag()
                let end = try point()
                addArc(to: path, from: current, to: end, radii: CGSize(width: rx, height: ry),
                       rotation: rotation * .pi / 180, largeArc: largeArc, sweep: sweep)
                current = end
            case UInt8(ascii: "z"):
                path.closeSubpath()
                current = subpathStart
                command = nil
            default:
                throw SVGUnsupported()
            }
            lastControl = control
            lastWasCubic = isCubic
        }
        return path.isEmpty ? nil : path
    }

    private static func reflect(_ point: CGPoint?, about center: CGPoint) -> CGPoint {
        guard let point else { return center }
        return CGPoint(x: 2 * center.x - point.x, y: 2 * center.y - point.y)
    }

    /// An elliptical arc, converted from SVG's endpoints to a centre and
    /// angles (SVG 1.1, appendix F.6.5).
    private static func addArc(
        to path: CGMutablePath, from start: CGPoint, to end: CGPoint, radii: CGSize,
        rotation: CGFloat, largeArc: Bool, sweep: Bool
    ) {
        guard start != end else { return }
        var rx = abs(radii.width)
        var ry = abs(radii.height)
        guard rx > 0, ry > 0 else {
            path.addLine(to: end)
            return
        }
        let cosine = cos(rotation)
        let sine = sin(rotation)
        let dx = (start.x - end.x) / 2
        let dy = (start.y - end.y) / 2
        let x1 = cosine * dx + sine * dy
        let y1 = -sine * dx + cosine * dy
        // Radii too small to reach the end grow until they just do.
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 {
            rx *= lambda.squareRoot()
            ry *= lambda.squareRoot()
        }
        let numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
        let coefficient = (largeArc != sweep ? 1 : -1) * max(0, numerator / denominator).squareRoot()
        let cx1 = coefficient * rx * y1 / ry
        let cy1 = -coefficient * ry * x1 / rx
        let center = CGPoint(
            x: cosine * cx1 - sine * cy1 + (start.x + end.x) / 2,
            y: sine * cx1 + cosine * cy1 + (start.y + end.y) / 2)
        let ux = (x1 - cx1) / rx, uy = (y1 - cy1) / ry
        let vx = (-x1 - cx1) / rx, vy = (-y1 - cy1) / ry
        let startAngle = atan2(uy, ux)
        var delta = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }
        // A unit circle, scaled to the radii, rotated and moved to the centre.
        let transform = CGAffineTransform(scaleX: rx, y: ry)
            .concatenating(CGAffineTransform(rotationAngle: rotation))
            .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        path.addRelativeArc(center: .zero, radius: 1, startAngle: startAngle, delta: delta, transform: transform)
    }
}

/// Reads the numbers, flags and names of a path, `points`, `viewBox` or
/// `transform`, skipping the whitespace and commas between them.
nonisolated private struct SVGScanner {
    private let bytes: [UInt8]
    private var index = 0

    init(_ string: String) {
        bytes = Array(string.utf8)
    }

    /// Whether only separators are left.
    var isAtEnd: Bool {
        mutating get {
            skipSeparators()
            return index >= bytes.count
        }
    }

    /// The next byte, when it's a letter other than an exponent's `e`.
    mutating func letter() -> UInt8? {
        skipSeparators()
        guard index < bytes.count, isLetter(bytes[index]) else { return nil }
        defer { index += 1 }
        return bytes[index]
    }

    /// The run of letters next, such as a transform's name.
    mutating func word() -> String {
        skipSeparators()
        let start = index
        while index < bytes.count, isLetter(bytes[index]) || bytes[index] | 0x20 == UInt8(ascii: "e") { index += 1 }
        return String(decoding: bytes[start..<index], as: UTF8.self)
    }

    /// Steps past `byte` when it's next.
    mutating func consume(_ byte: UInt8) -> Bool {
        skipSeparators()
        guard index < bytes.count, bytes[index] == byte else { return false }
        index += 1
        return true
    }

    mutating func number() throws -> CGFloat {
        skipSeparators()
        let start = index
        if index < bytes.count, bytes[index] == UInt8(ascii: "-") || bytes[index] == UInt8(ascii: "+") { index += 1 }
        var digits = skipDigits()
        if index < bytes.count, bytes[index] == UInt8(ascii: ".") {
            index += 1
            digits += skipDigits()
        }
        guard digits > 0 else { throw SVGUnsupported() }
        if index < bytes.count, bytes[index] | 0x20 == UInt8(ascii: "e") {
            let mark = index
            index += 1
            if index < bytes.count, bytes[index] == UInt8(ascii: "-") || bytes[index] == UInt8(ascii: "+") { index += 1 }
            if skipDigits() == 0 { index = mark }
        }
        guard let number = Double(String(decoding: bytes[start..<index], as: UTF8.self)), number.isFinite else {
            throw SVGUnsupported()
        }
        return CGFloat(number)
    }

    /// An arc's flag: a single `0` or `1`, which needs nothing after it.
    mutating func flag() throws -> Bool {
        skipSeparators()
        guard index < bytes.count, bytes[index] == UInt8(ascii: "0") || bytes[index] == UInt8(ascii: "1") else {
            throw SVGUnsupported()
        }
        defer { index += 1 }
        return bytes[index] == UInt8(ascii: "1")
    }

    private mutating func skipSeparators() {
        while index < bytes.count, [0x20, 0x09, 0x0A, 0x0D, UInt8(ascii: ",")].contains(bytes[index]) { index += 1 }
    }

    private mutating func skipDigits() -> Int {
        let start = index
        while index < bytes.count, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(bytes[index]) { index += 1 }
        return index - start
    }

    private func isLetter(_ byte: UInt8) -> Bool {
        let lower = byte | 0x20
        return lower >= UInt8(ascii: "a") && lower <= UInt8(ascii: "z") && lower != UInt8(ascii: "e")
    }
}
