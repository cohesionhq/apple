import CohesionCore
import SwiftUI

// What the daemon's values look like here: the SF Symbol and color of each,
// and the one place to change them. A screen reads these rather than switch
// over a wire value itself. A case with no look of its own, or one a screen
// only draws from inside its own switch, is a static named for the case.

// MARK: - Agents

extension AgentColor {
    public var color: Color {
        switch self {
        case .blue: .blue
        case .green: .green
        case .orange: .orange
        case .purple: .purple
        case .red: .red
        case .pink: .pink
        case .teal: .teal
        case .yellow: .yellow
        }
    }
}

public extension AgentMessage {
    /// The icon of its quiet line, as the web's feed picks it: a memory's
    /// brain, a rebuilt context's fold, an info mark for the rest.
    var quietSymbol: String {
        switch content {
        case .memory: "brain"
        case .rebuiltContext: "rectangle.compress.vertical"
        default: "info.circle"
        }
    }
}

public extension AgentMessage.Content {
    /// The line saying which script API module the sender loaded.
    static let documentationSymbol = "book"
    static let errorSymbol = "exclamationmark.triangle"
    static let errorTint = Color.red
    static let forwardSymbol = "arrowshape.turn.up.right"
}

public extension AgentCodeExecution.Outcome {
    var symbol: String {
        switch self {
        case .succeeded: "wand.and.stars"
        case .failed: "exclamationmark.triangle"
        case .cancelled: "stop.circle"
        }
    }

    /// A failed script's error.
    static let failedTint = Color.red
}

/// A running run has no symbol: it shows a spinner.
public extension AgentRun.State {
    static let completedSymbol = "checkmark.circle.fill"
    static let completedTint = Color.green
    static let failedSymbol = "xmark.circle.fill"
    /// The failed run's mark and its error.
    static let failedTint = Color.red
}

public extension AgentAsk.Reply {
    static let waitingSymbol = "hourglass"
    /// "No answer", and why.
    static let unansweredTint = Color.red
}

/// A pending proposal has no symbol: it shows its buttons.
public extension AgentProposal.Status {
    static let approvedSymbol = "checkmark"
    static let deniedSymbol = "xmark"
    static let withdrawnSymbol = "arrow.uturn.backward"
}

public extension AgentForwardedItem.Kind {
    var symbol: String {
        switch self {
        case .task: "checklist"
        case .document: "doc.text"
        case .journal: "book.closed"
        }
    }
}

// MARK: - Actors

public extension ActorSessionStatus {
    /// One family of circled marks: a dotted circle while it works, a raised
    /// hand while it needs the user, a filled check once done or resolved, a
    /// filled cross once failed. Filled, so none reads as a checkbox beside
    /// a task's.
    var symbol: String {
        switch self {
        case .working: "circle.dotted"
        case .needsAttention: "hand.raised.circle.fill"
        case .idle: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .resolved: "checkmark.circle.fill"
        }
    }

    /// The icon's color; `nil` where it takes its surroundings' color.
    /// Working is the brand's, so the one live state reads as alive.
    var tint: Color? {
        switch self {
        case .needsAttention: .orange
        case .working: .brand
        case .failed: .red
        case .idle, .resolved: .secondary
        }
    }

    /// A session row's status words, in its icon's colour where it has one
    /// (amber while it needs the user, the brand's while working, red once
    /// failed), secondary otherwise.
    var wordsStyle: AnyShapeStyle {
        tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.secondary)
    }
}

/// How full an actor's usage or context reads.
public enum ActorUsageTone {
    /// Orange past 80% used, red past 95%; `nil` below.
    public static func tint(of share: Double) -> Color? {
        if share >= 0.95 { return .red }
        if share >= 0.8 { return .orange }
        return nil
    }
}

// MARK: - Activities

public extension Color {
    /// The app's purple, by name; `.accentColor` is the system's blue in a
    /// widget.
    static let brand = Color("AccentColor")
}

public extension ActivityOverallStatus {
    /// As an actor session's status is drawn in the app: amber needs you,
    /// the brand while working, red failed, grey done.
    var tint: Color {
        switch self {
        case .needsAttention: .orange
        case .running: .brand
        case .failed: .red
        case .done: .secondary
        }
    }
}

public extension ActivityStatus {
    /// The same marks as an actor session's status (`ActorSessionStatus`),
    /// so the Live Activity and the app say each state one way.
    var symbol: String {
        switch self {
        case .running: ActorSessionStatus.working.symbol
        case .waiting: "hourglass"
        case .paused: ActorSessionStatus.needsAttention.symbol
        case .succeeded: ActorSessionStatus.idle.symbol
        case .failed: ActorSessionStatus.failed.symbol
        case .cancelled: "stop.circle"
        }
    }

    var tint: Color {
        switch self {
        case .running: .brand
        case .waiting: .secondary
        case .paused: .orange
        case .succeeded: .secondary
        case .failed: .red
        case .cancelled: .secondary
        }
    }
}

// MARK: - Tasks

public extension TaskStatus {
    /// The style of a task's title in a row.
    var titleStyle: HierarchicalShapeStyle {
        self == .incomplete ? .primary : .secondary
    }
}

public extension Vocabulary {
    /// A task size's color, the daemon's agent color for it; secondary when
    /// it names none.
    func tint(of size: TaskSize) -> Color {
        color(of: size)?.color ?? .secondary
    }
}

public extension TaskPriority {
    static let flagSymbol = "flag.fill"

    /// The flag's color, as the web tints it: grey for low, the accent for
    /// medium, a yellow-orange for high (clear of the amber that says
    /// "needs you") and red for urgent; `nil` for no priority.
    var tint: Color? {
        flagColor.map(Color.init)
    }

    /// The flag as an image for a menu's item, which draws only images and
    /// tints them like its text; kept in color. `nil` for no priority.
    var menuFlag: Image? {
        #if os(iOS)
        guard let flagColor, let flag = UIImage(systemName: Self.flagSymbol) else { return nil }
        return Image(uiImage: flag.withTintColor(flagColor, renderingMode: .alwaysOriginal))
        #else
        guard let flagColor,
              let flag = NSImage(systemSymbolName: Self.flagSymbol, accessibilityDescription: nil)?
                  .withSymbolConfiguration(.init(paletteColors: [flagColor]))
        else { return nil }
        return Image(nsImage: flag)
        #endif
    }

    #if os(iOS)
    private var flagColor: UIColor? {
        switch self {
        case .none: nil
        case .low: .tertiaryLabel
        case .medium: UIColor(named: "AccentColor") ?? .tintColor
        case .high: UIColor { $0.userInterfaceStyle == .dark ? Self.highDark : Self.highLight }
        case .urgent: .systemRed
        }
    }
    #else
    private var flagColor: NSColor? {
        switch self {
        case .none: nil
        case .low: .tertiaryLabelColor
        case .medium: NSColor(named: "AccentColor") ?? .controlAccentColor
        case .high: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? Self.highDark : Self.highLight }
        case .urgent: .systemRed
        }
    }
    #endif

    #if os(iOS)
    private typealias PlatformColor = UIColor
    #else
    private typealias PlatformColor = NSColor
    #endif

    /// High's yellow-orange, deep enough to read on white, lifted in the dark.
    private static let highLight = PlatformColor(displayP3Red: 0.85, green: 0.60, blue: 0.02, alpha: 1)
    private static let highDark = PlatformColor(displayP3Red: 1.0, green: 0.78, blue: 0.24, alpha: 1)
}

// MARK: - Extensions

public extension ExtensionPermissionKind {
    /// The symbol beside the permission, as the web UI shows each with an icon.
    var systemImage: String {
        switch rawValue {
        case "cohesion:read": "eye"
        case "cohesion:write": "pencil.line"
        case "network": "globe"
        case "timer": "alarm"
        case "registry": "storefront"
        case "oauth": "key"
        case "connector": "cable.connector"
        case "service": "arrowshape.turn.up.left"
        case "service:isolated": "lock"
        case "services": "square.stack.3d.up"
        case "usage": "gauge.with.dots.needle.50percent"
        case "intelligence": "cpu"
        case "notifications": "bell"
        case "actors": "apple.terminal"
        default: "puzzlepiece.extension"
        }
    }
}

// MARK: - Articles

public extension ArticleSnapshot {
    /// "Not Fetched", on an article with no snapshot captured.
    static let notFetchedTint = Color.orange
}
