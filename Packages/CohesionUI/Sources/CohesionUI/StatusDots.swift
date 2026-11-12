import SwiftUI

/// A dot for each thing counted, in its status's tint, the most pressing
/// first, filling a square grid row by row: 2×2 up to four, then 3×3, the
/// first nine beyond that. The grid stays square: slots past the last dot, and
/// all four while there are none, are faint hollow rings, so an empty slot
/// never reads as done's grey. The Live Activity draws its activities with it
/// and the iPhone's tab bar its actor sessions. It says nothing to VoiceOver
/// itself; whoever shows it labels it with the counts.
public struct StatusDots: View {
    /// Each dot's tint, the most pressing first.
    let tints: [Color]
    let side: CGFloat
    /// An empty slot's ring.
    let ring: Color

    /// The most dots the grid holds, 3×3.
    public static let capacity = 9

    public init(tints: [Color], side: CGFloat = 20, ring: Color = Color.secondary.opacity(0.5)) {
        self.tints = tints
        self.side = side
        self.ring = ring
    }

    public var body: some View {
        let dots = Array(tints.prefix(Self.capacity))
        let columns = dots.count > 4 ? 3 : 2
        let spacing = side * 0.1
        let diameter = (side - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            ForEach(0..<columns, id: \.self) { row in
                GridRow {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        Group {
                            if index < dots.count {
                                Circle().fill(dots[index])
                            } else {
                                Circle().strokeBorder(ring, lineWidth: 1)
                            }
                        }
                        .frame(width: diameter, height: diameter)
                    }
                }
            }
        }
        .frame(width: side, height: side)
        .accessibilityElement(children: .ignore)
    }
}
