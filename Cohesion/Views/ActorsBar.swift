import CohesionCore
import CohesionScreens
import CohesionUI
import SwiftUI

/// The iPhone tab bar's accessory, on every tab: where the actor sessions
/// stand, as the Live Activity's dots (`StatusDots`, a dot per session, the
/// most pressing first) and a line of counts ("1 needs you, 1 working"), which
/// opens the sessions; then New Task, so a task can be captured from anywhere.
/// It counts every session not resolved (`current`), done and failed
/// included, as the Live Activity and the Actors list do. The line leaves
/// done out unless that's all there is ("All done").
/// Beside the tab bar collapsed on scrolling, it has half the width, and the
/// line names only the most pressing count.
struct ActorsBar: View {
    /// Every actor's current sessions.
    let sessions: [ActorSession]
    let showSessions: () -> Void
    let newTask: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    /// The statuses counted, the most pressing first, as the Live Activity
    /// orders its own.
    private static let counted: [ActorSessionStatus] = [.needsAttention, .working, .failed]

    var body: some View {
        let isInline = placement == .inline
        HStack(spacing: isInline ? 8 : 12) {
            Button(action: showSessions) {
                HStack(spacing: isInline ? 8 : 10) {
                    StatusDots(tints: dots, side: isInline ? 18 : 22)
                    Text(isInline ? shortSummary : summary)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Actor Sessions")
            .accessibilityValue(summary)
            Button("New Task", systemImage: "plus", action: newTask)
                .labelStyle(.iconOnly)
                .font(.title3.weight(.semibold))
        }
        .padding(.horizontal, isInline ? 12 : 16)
    }

    /// A dot per session in its status's tint, the most pressing first.
    private var dots: [Color] {
        (Self.counted + [.idle]).flatMap { status in
            repeatElement(status.tint ?? .secondary, count: count(status))
        }
    }

    /// Each count but done's, the most pressing first: "1 needs you, 1
    /// working".
    private var summary: String {
        let parts = Self.counted.compactMap { status in
            count(status) > 0 ? phrase(status) : nil
        }
        return parts.isEmpty ? settled : parts.joined(separator: ", ")
    }

    /// The most pressing count alone, for the bar beside the collapsed tab bar.
    private var shortSummary: String {
        Self.counted.first { count($0) > 0 }.map(phrase) ?? settled
    }

    /// What the bar says with nothing going on or failed.
    private var settled: String {
        sessions.isEmpty ? "No sessions" : "All done"
    }

    /// "1 needs you", in the vocabulary's words for the status.
    private func phrase(_ status: ActorSessionStatus) -> String {
        "\(count(status)) \(model.vocabulary.label(of: status).localizedLowercase)"
    }

    private func count(_ status: ActorSessionStatus) -> Int {
        sessions.count { $0.status == status }
    }
}

/// What the bar opens: the current sessions, the iPhone's one list of them
/// (the Agents tab lists only agents), with New Session. A session opens
/// where the Agents tab pushes it, closing the sheet, since a transcript is
/// full-page content.
struct ActorSessionsSheet: View {
    let open: (Int) -> Void

    @Environment(WindowModel.self) private var window
    @Environment(\.dismiss) private var dismiss
    /// The session tapped, which opens on the Agents tab instead of here.
    @State private var path: [Int] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ActorSessionsSection(
                    actors: window.actors,
                    sessions: window.actorSessions,
                    resolve: window.resolve,
                    newSession: {
                        dismiss()
                        window.isStartingActorSession = true
                    }
                ) { $0 }
            }
            .navigationTitle("Actors")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Int.self) { _ in EmptyView() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", role: .close) { dismiss() }
                }
            }
        }
        .onChange(of: path) {
            guard let id = path.first else { return }
            dismiss()
            open(id)
        }
    }
}
