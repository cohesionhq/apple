#if canImport(UIKit)
import UIKit

/// An image as the platform draws it: `UIImage` on iOS, `NSImage` on the Mac.
public typealias PlatformImage = UIImage
#else
import AppKit

/// An image as the platform draws it: `UIImage` on iOS, `NSImage` on the Mac.
public typealias PlatformImage = NSImage
#endif

extension PlatformImage {
    /// The image a reply carries as base64, or nil when it isn't one.
    public nonisolated static func decoding(base64 data: String) -> PlatformImage? {
        Data(base64Encoded: data).flatMap(PlatformImage.init(data:))
    }
}
