import CohesionCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// An extension's or a connector's icon, or its name's initial while there
/// is none to show: it gives none, or gives one that doesn't load or draw.
public struct ServiceIcon: View {
    /// A `data:image/…` or `https://` URL.
    public let icon: String?
    public let name: String
    public let size: CGFloat

    public init(icon: String?, name: String, size: CGFloat) {
        self.icon = icon
        self.name = name
        self.size = size
    }

    @Environment(\.displayScale) private var displayScale
    @State private var image: PlatformImage?

    public var body: some View {
        Group {
            if let image {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                // A Settings row's tile, in grey, so it reads as an icon
                // rather than a gap waiting for one.
                Text(name.prefix(1).uppercased())
                    .font(.system(size: size * 0.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.gradient)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.23, style: .continuous))
        .accessibilityHidden(true)
        .task(id: icon) {
            image = await Self.load(icon, side: size, scale: displayScale)
        }
    }

    /// The icon at `icon`, a `data:` or `https://` URL: a bitmap as it is,
    /// or an SVG drawn `side` points across, since the platform's images read no SVG.
    private static func load(_ icon: String?, side: CGFloat, scale: CGFloat) async -> PlatformImage? {
        guard let url = icon.flatMap(URL.init(string:)),
              let data = try? await URLSession.shared.data(from: url).0
        else { return nil }
        return PlatformImage(data: data) ?? SVGIcon.image(from: data, side: side, scale: scale)
    }
}
