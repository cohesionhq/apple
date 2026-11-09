import CohesionCore
import CohesionUI
import SwiftUI

/// "Done, Fix the build, unread", as a session row reads aloud.
func rowLabel(_ session: ActorSession, status: String) -> String {
    "\(status), \(session.title)" + (session.isUnread ? ", unread" : "")
}

/// Where an actor works: the last part of its scope, "cohesion".
/// Pressing it shows the whole path.
struct ActorPlace: View {
    let actor: Actor

    var body: some View {
        Text(actor.scopeName)
            .lineLimit(1)
            .contextMenu {
                Section(actor.scope) {
                    Button("Copy", systemImage: "doc.on.doc") { Pasteboard.general.string = actor.scope }
                }
            }
    }
}

/// The icon of where a session stands: a dotted circle while it works, an amber
/// raised hand while it needs the user, a check once done, a red cross once
/// failed, a circled check once resolved. Read state isn't shown. It pops in
/// again whenever the status changes. On a selected row's accent it takes the
/// row's colour, as amber or red on the accent can't be read.
struct ActorSessionStatusIcon: View {
    let status: ActorSessionStatus

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        ZStack {
            symbol
                .id(status)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
        }
        .animation(.spring(duration: 0.3), value: status)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var symbol: some View {
        let image = Image(systemName: status.symbol)
        if let tint = status.tint, prominence != .increased {
            image.foregroundStyle(tint)
        } else {
            image
        }
    }
}

/// An actor session in the lists of them: its title, which shimmers while it
/// works, over its status as an icon and its name, amber while it needs the
/// user.
struct ActorSidebarRow: View {
    let session: ActorSession

    @Environment(AppModel.self) private var model
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        let status = model.vocabulary.label(of: session.status)
        VStack(alignment: .leading, spacing: 2) {
            Text(session.title)
                .lineLimit(1)
                .workingShimmer(session.status == .working, dimmed: 0.35)
            HStack(spacing: 4) {
                ActorSessionStatusIcon(status: session.status)
                Text(status)
                    .lineLimit(1)
            }
            .font(.subheadline)
            // Selected, the row's own secondary: see `ActorSessionStatusIcon`.
            .foregroundStyle(prominence == .increased ? AnyShapeStyle(.secondary) : session.status.wordsStyle)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowLabel(session, status: status))
    }
}
