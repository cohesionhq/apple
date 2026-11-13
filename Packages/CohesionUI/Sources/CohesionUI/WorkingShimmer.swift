import SwiftUI

public extension View {
    /// Sweeps a soft light across the text that says an agent or actor session
    /// is working, the one sign of it where that text is shown. Still under
    /// Reduce Motion.
    /// `dimmed` is how much of the text shows outside the band: a row's name
    /// is dark text on a light row, so it dips further than a caption does to
    /// show as much.
    func workingShimmer(_ isWorking: Bool, dimmed: Double = 0.55) -> some View {
        modifier(WorkingShimmer(isWorking: isWorking, dimmed: dimmed))
    }
}

/// Dims the text and lets a band of it through at full strength, so the text
/// keeps whatever style it has: secondary, a selected row's, a material's.
/// Every shimmer runs off the clock, so a name in the sidebar and the caption
/// in its chat sweep in step.
private struct WorkingShimmer: ViewModifier {
    let isWorking: Bool
    let dimmed: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seconds from one sweep's start to the next, the web's beat
    /// (`web/src/lib/ui/motion.ts`).
    private static let beat: TimeInterval = 2.5
    /// Seconds of each beat the band takes to cross the text, slowing as it
    /// goes, as the web's does. For the rest of the beat the text rests dimmed.
    private static let crossing: TimeInterval = 0.9
    private static let easing = UnitCurve.easeOut
    /// How much of the text's width the band spans, the web's share. Half of
    /// that span is brighter than halfway.
    private static let share = 0.6
    /// Where the band's center sets off and ends, as shares of the text's width:
    /// just clear of each edge, so the crossing shows as soon as the beat falls.
    private static let centerStart = -0.4
    private static let centerEnd = 1.4
    /// The band's strength from edge to edge: a raised cosine, so it fades in
    /// and out with no edge to see, like a light passing over.
    private static func stops(dimmed: Double) -> [Gradient.Stop] { (0...8).map { step in
        let location = Double(step) / 8
        let strength = (1 - cos(2 * .pi * location)) / 2
        return Gradient.Stop(color: .black.opacity(dimmed + (1 - dimmed) * strength), location: location)
    } }

    func body(content: Content) -> some View {
        let shimmers = isWorking && !reduceMotion
        // A branch rather than an always-on mask: a name at rest renders
        // exactly as any other text does, and the text holds no state to lose.
        Group {
            if shimmers {
                // A quick crossing of a wide band: 60 frames a second keeps
                // it smooth on a long title.
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
                    content.mask(Self.band(at: context.date.timeIntervalSinceReferenceDate, dimmed: dimmed))
                }
            } else {
                content
            }
        }
        // The text eases between its full strength and the dimmed.
        .animation(.easeInOut(duration: 0.3), value: shimmers)
    }

    /// The mask at `time`: a band which enters past one edge and leaves past the
    /// other, the text dimmed until the next beat. Its place depends only on the
    /// time and the text's width, so texts of any length stay in step.
    private static func band(at time: TimeInterval, dimmed: Double) -> LinearGradient {
        let progress = time.truncatingRemainder(dividingBy: beat) / crossing
        let center = centerStart + (centerEnd - centerStart) * easing.value(at: min(progress, 1))
        return LinearGradient(
            stops: stops(dimmed: dimmed),
            startPoint: UnitPoint(x: center - share / 2, y: 0.5),
            endPoint: UnitPoint(x: center + share / 2, y: 0.5)
        )
    }
}
