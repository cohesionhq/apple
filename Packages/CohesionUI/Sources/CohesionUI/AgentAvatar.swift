import CohesionCore
import SwiftUI

/// The agent's emoji, or its initial, on its color. The glyph is sized
/// from the disc by `fit`, an emoji by the size it draws at.
public struct AgentAvatar: View {
    public let name: String
    public let emoji: String?
    public let color: AgentColor
    /// The disc's diameter; 40 spans a row's two lines of text.
    public var diameter: CGFloat = 40
    public var fit = Fit.standard

    public init(name: String, emoji: String?, color: AgentColor, diameter: CGFloat = 40, fit: Fit = .standard) {
        self.name = name
        self.emoji = emoji
        self.color = color
        self.diameter = diameter
        self.fit = fit
    }

    /// How much of the disc the glyph takes.
    public enum Fit {
        /// Half the diameter for an emoji and for an initial, as the
        /// notification extension's `INPerson` avatar draws it.
        case standard
        /// The initial at 0.45, where a symbol goes beside a menu item's or
        /// the sidebar's text.
        case symbol

        public func ratio(emoji: Bool) -> CGFloat {
            switch self {
            case .standard: 0.5
            case .symbol: emoji ? 0.5 : 0.45
            }
        }
    }

    /// The smallest font size at which an emoji draws at its size; below it
    /// Apple Color Emoji draws up to a fifth larger, so a small disc's emoji
    /// is drawn here and scaled down to its share.
    private static let emojiFontSize: CGFloat = 24

    public var body: some View {
        glyph
            .foregroundStyle(.white)
            .frame(width: diameter, height: diameter)
            .background(color.color.gradient, in: .circle)
            .clipShape(.circle)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var glyph: some View {
        if let emoji {
            let size = diameter * fit.ratio(emoji: true)
            let fontSize = max(size, Self.emojiFontSize)
            Text(emoji)
                .font(.system(size: fontSize))
                .fixedSize()
                .scaleEffect(size / fontSize)
        } else {
            Text(name.prefix(1))
                .font(.system(size: diameter * fit.ratio(emoji: false), weight: .semibold))
        }
    }
}

extension AgentAvatar {
    /// The agent's avatar as an image for a menu item, which shows only
    /// images: a 24pt disc that fits its glyph for a menu, kept in color
    /// rather than tinted like a symbol.
    public static func menuImage(of agent: Agent, scale: CGFloat) -> Image {
        let avatar = AgentAvatar(name: agent.name, emoji: agent.emoji, color: agent.color, diameter: 24, fit: .symbol)
        return menuImage(of: avatar, scale: scale)
    }

    /// `avatar`, any view, as an image for a menu item, kept in color rather
    /// than tinted like a symbol.
    public static func menuImage(of avatar: some View, scale: CGFloat) -> Image {
        let renderer = ImageRenderer(content: avatar)
        renderer.scale = scale
        #if canImport(UIKit)
        guard let image = renderer.uiImage else { return Image(systemName: "person.crop.circle") }
        return Image(uiImage: image.withRenderingMode(.alwaysOriginal))
        #else
        guard let image = renderer.nsImage else { return Image(systemName: "person.crop.circle") }
        return Image(nsImage: image)
        #endif
    }
}
