import SwiftUI

/// A white symbol on a colored rounded square with a gradient, as the
/// Settings app draws its rows' icons. It scales with Dynamic Type.
public struct SymbolIcon: View {
    let systemImage: String
    let color: Color

    @ScaledMetric(relativeTo: .body) private var side = 29

    public init(systemImage: String, color: Color) {
        self.systemImage = systemImage
        self.color = color
    }

    public var body: some View {
        Image(systemName: systemImage)
            .resizable()
            .scaledToFit()
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .frame(width: side * 0.6, height: side * 0.6)
            .frame(width: side, height: side)
            .background(color.gradient, in: .rect(cornerRadius: side * 0.23, style: .continuous))
            .accessibilityHidden(true)
    }
}

extension Label where Title == Text, Icon == SymbolIcon {
    /// A row's title beside its `SymbolIcon`.
    public init(_ title: String, systemImage: String, color: Color) {
        self.init {
            Text(title)
        } icon: {
            SymbolIcon(systemImage: systemImage, color: color)
        }
    }
}
