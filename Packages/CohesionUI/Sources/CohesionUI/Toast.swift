import SwiftUI

/// A short message over the top of the screen that goes on its own: an
/// error cohesiond sent back, or a note it pushed.
public struct Toast: Identifiable, Equatable {
    public enum Kind {
        case info, error
    }

    public let id = UUID()
    public let kind: Kind
    public var title: String?
    public let message: String
    /// What tapping the toast opens; without it the toast is only shown.
    public var link: URL?

    public init(kind: Kind, title: String? = nil, message: String, link: URL? = nil) {
        self.kind = kind
        self.title = title
        self.message = message
        self.link = link
    }

    public static func error(_ error: any Error) -> Toast {
        Toast(kind: .error, message: error.localizedDescription)
    }

    public static func error(_ message: String) -> Toast {
        Toast(kind: .error, message: message)
    }
}

extension View {
    /// Shows `toast` over the top edge for a few seconds, or until swiped up.
    public func toast(_ toast: Binding<Toast?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?

    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    banner(toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: toast.id) {
                            AccessibilityNotification.Announcement(
                                [toast.title, toast.message].compactMap(\.self).joined(separator: ". ")
                            ).post()
                            try? await Task.sleep(for: .seconds(4))
                            withAnimation { self.toast = nil }
                        }
                }
            }
            .animation(.default, value: toast)
    }

    @ViewBuilder
    private func banner(_ toast: Toast) -> some View {
        if let link = toast.link {
            Button {
                self.toast = nil
                openURL(link)
            } label: {
                bannerContent(toast)
            }
            .buttonStyle(.plain)
        } else {
            bannerContent(toast)
        }
    }

    private func bannerContent(_ toast: Toast) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(toast.kind == .error ? AnyShapeStyle(.red) : AnyShapeStyle(.tint))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                if let title = toast.title {
                    Text(title)
                        .fontWeight(.semibold)
                }
                Text(toast.message)
            }
            .font(.subheadline)
            if toast.link != nil {
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .padding(.horizontal)
        .padding(.top, 8)
        .gesture(DragGesture().onEnded { drag in
            if drag.translation.height < 0 { self.toast = nil }
        })
    }
}

/// Lays its views out in rows, starting a new row when the next doesn't
/// fit, each row against `alignment`'s edge and each view centred in its
/// row's height.
public struct FlowLayout: Layout {
    public var alignment = HorizontalAlignment.leading
    public var spacing: CGFloat = 6

    public init(alignment: HorizontalAlignment = HorizontalAlignment.leading, spacing: CGFloat = 6) {
        self.alignment = alignment
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = alignment == .trailing ? bounds.maxX - row.width : bounds.minX
            for index in row.indices {
                let size = size(of: subviews[index], width: bounds.width)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// Its ideal size, or a row's width when that's wider, so a long title
    /// truncates rather than runs off the edge.
    private func size(of subview: LayoutSubview, width: CGFloat) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        return ideal.width > width ? subview.sizeThatFits(ProposedViewSize(width: width, height: nil)) : ideal
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = size(of: subviews[index], width: width)
            // A point to spare: the width given back to place in can be the
            // measured one rounded down to the pixel.
            if !row.indices.isEmpty && row.width + spacing + size.width > width + 1 {
                rows.append(row)
                row = Row()
            }
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
