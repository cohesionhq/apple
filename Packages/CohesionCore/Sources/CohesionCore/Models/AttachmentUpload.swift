import Foundation
import ImageIO
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// An image ready to attach to a message: scaled down to what the models
/// look at and encoded for cohesiond.
public nonisolated struct AttachmentUpload: Identifiable {
    public let id = UUID()
    public let mediaType: String
    /// The image, base64-encoded.
    public let data: String
    /// What the composer and the message waiting to send show.
    public let preview: PlatformImage
    /// The PencilKit drawing this image was rendered from, when it's the
    /// thread's sketch, so editing the sketch replaces it.
    public var drawing: Data?

    public init(mediaType: String, data: String, preview: PlatformImage, drawing: Data? = nil) {
        self.mediaType = mediaType
        self.data = data
        self.preview = preview
        self.drawing = drawing
    }

    /// The most images one message carries, as cohesiond allows.
    public static let limit = 10

    /// The longest side the models look at; a larger image is scaled down.
    private static let maxSide: CGFloat = 1568

    /// The most bytes an image is sent as is: 5 MB once base64-encoded.
    private static let maxBytes = 5 * 1024 * 1024 / 4 * 3

    /// The formats sent as they are when they fit.
    private static let passThroughTypes: [UTType] = [.png, .jpeg, .gif, .webP]

    /// The longest side a contact's photo is sent at, as the web sends it.
    public static let photoSide: CGFloat = 512

    /// `data` (any image format the platform reads) as it is when it's a PNG, JPEG,
    /// GIF or WebP within `maxBytes` and `side`, else as JPEG on white, its
    /// longest side at most `side` points (`maxSide` unless given); nil when
    /// it isn't an image.
    public static func prepare(_ data: Data, side: CGFloat? = nil) -> AttachmentUpload? {
        let maxSide = side ?? Self.maxSide
        guard let image = PlatformImage(data: data) else { return nil }
        if data.count <= maxBytes,
           image.longestPixelSide <= maxSide,
           let source = CGImageSourceCreateWithData(data as CFData, nil),
           let identifier = CGImageSourceGetType(source) as String?,
           let type = UTType(identifier), passThroughTypes.contains(type),
           let mediaType = type.preferredMIMEType {
            return AttachmentUpload(mediaType: mediaType, data: data.base64EncodedString(), preview: image)
        }
        return prepare(image, side: maxSide)
    }

    /// `image` as JPEG on white, its longest side at most `side` points;
    /// nil when it won't encode.
    public static func prepare(_ image: PlatformImage, side maxSide: CGFloat) -> AttachmentUpload? {
        let original = image.fullSize
        let scale = min(1, maxSide / max(original.width, original.height))
        let size = CGSize(width: (original.width * scale).rounded(), height: (original.height * scale).rounded())
        guard let scaled = image.jpeg(at: size) else { return nil }
        return AttachmentUpload(mediaType: "image/jpeg", data: scaled.data.base64EncodedString(), preview: scaled.image)
    }
}

extension [AttachmentUpload] {
    /// As a command's `attachments` takes them; `nil` for none.
    public var wireValue: [[String: String]]? {
        isEmpty ? nil : map { ["media_type": $0.mediaType, "data": $0.data] }
    }
}

private extension PlatformImage {
    #if canImport(UIKit)
    nonisolated var longestPixelSide: CGFloat {
        max(size.width * scale, size.height * scale)
    }

    /// The size scaling down starts from.
    nonisolated var fullSize: CGSize { size }

    /// The image at `size` points, one pixel a point, on white, as JPEG.
    nonisolated func jpeg(at size: CGSize) -> (data: Data, image: PlatformImage)? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let scaled = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            draw(in: CGRect(origin: .zero, size: size))
        }
        return scaled.jpegData(compressionQuality: 0.85).map { ($0, scaled) }
    }
    #else
    nonisolated var longestPixelSide: CGFloat {
        let rep = representations.max { $0.pixelsWide < $1.pixelsWide }
        return CGFloat(max(rep?.pixelsWide ?? 0, rep?.pixelsHigh ?? 0))
    }

    /// The size scaling down starts from: its pixels, since a retina
    /// screenshot's points are half of them.
    nonisolated var fullSize: CGSize {
        guard let rep = representations.max(by: { $0.pixelsWide < $1.pixelsWide }), rep.pixelsWide > 0 else { return size }
        return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }

    /// The image at `size` points, one pixel a point, on white, as JPEG.
    nonisolated func jpeg(at size: CGSize) -> (data: Data, image: PlatformImage)? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 3,
            hasAlpha: false,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor.white.setFill()
        CGRect(origin: .zero, size: size).fill()
        draw(in: CGRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]),
              let image = NSImage(data: data)
        else { return nil }
        return (data, image)
    }
    #endif
}
