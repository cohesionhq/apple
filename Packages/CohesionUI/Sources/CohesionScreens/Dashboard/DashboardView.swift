import CohesionCore
import CohesionUI
import SwiftUI

/// Where a workspace opens, to recap and quickly dispatch: a greeting for the
/// time of day, a message to an agent, the tasks due, and what's new, as the
/// web's Dashboard. Wide, as an iPad's pane is, what's new is a column beside
/// the rest rather than under it.
struct DashboardView: View {
    let workspaceID: Int
    let openAgent: (Int) -> Void
    let openActorSession: (Int) -> Void

    @Environment(WindowModel.self) private var window
    @Environment(\.profile) private var profile
    @Environment(\.scenePhase) private var scenePhase

    /// Read as the page opens and on coming back to the app, which on a
    /// phone can be days later.
    @State private var hour = Calendar.current.component(.hour, from: .now)
    /// One line per visit.
    @State private var pick = Double.random(in: 0..<1)
    @State private var isAddingToJournal = false
    /// Counts notes added to the journal, for the haptic.
    @State private var journalAdds = 0
    @State private var notice: Toast?
    @FocusState private var isComposing: Bool
    /// Where the composer is on screen, for a tap outside it. Only the tap
    /// reads it, so scrolling doesn't redraw the page.
    @State private var composerFrame = CGRect.zero
    /// The pane's width, which decides one column or two.
    @State private var pageWidth: CGFloat = 0

    /// Whether the pane holds two columns side by side, each at a reading
    /// width.
    private var isTwoColumn: Bool { pageWidth >= 900 }

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            List {
                VStack(alignment: .leading, spacing: 4) {
                    Text(DashboardGreeting.line(hour: hour, name: profile?.name, pick: pick))
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    // Read with the hour, so a page left open overnight moves on.
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .id(hour)
                }
                // Keeps its lines while its row shrinks away under it.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .modifier(BareRow())
                DashboardComposer(isComposing: $isComposing) { agent in
                    notice = Toast(kind: .info, message: "Sent to \(agent.name).", link: AppLink.agent(agent.id).url)
                }
                #if os(iOS)
                .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { composerFrame = $0 }
                #endif
                // What's New's heading brings its own room above it.
                .padding(.bottom, 4)
                .modifier(BareRow())
                DashboardDueSection(workspaceID: workspaceID)
                if !isTwoColumn { whatsNew }
            }
            .listStyle(.plain)
        if isTwoColumn {
            List { whatsNew }
                .listStyle(.plain)
                .frame(maxWidth: 440)
        }
        }
        // The list's own margins in a pane no wider than the column, or the
        // two columns.
        .centeredColumn(maxWidth: isTwoColumn ? 1120 : conversationColumnWidth)
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { pageWidth = $0 }
        .scrollDismissesKeyboard(.interactively)
        #if os(iOS)
        // Beside the rows' own taps, which still open what they hold. The
        // composer's controls keep the keyboard up, as sending does.
        .gesture(TapAnywhere { location in
            if !composerFrame.contains(location) { isComposing = false }
        })
        #endif
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        #if os(iOS)
        // The greeting heads the page; the title names the window.
        .toolbar(removing: .title)
        #endif
        .toolbar {
            // A toolbar button, as Notes and Journal start an entry, rather
            // than a second control beside the composer.
            ToolbarItem(placement: .primaryAction) {
                Button("Quick Journal", systemImage: "square.and.pencil") { isAddingToJournal = true }
            }
        }
        .sizedSheet(isPresented: $isAddingToJournal) {
            QuickJournalSheet(workspaceID: workspaceID) {
                journalAdds += 1
                notice = Toast(kind: .info, message: "Added to today’s journal.")
            }
        }
        .sensoryFeedback(.success, trigger: journalAdds)
        .toast($notice)
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            hour = Calendar.current.component(.hour, from: .now)
        }
        .refreshable { await window.refresh() }
    }

    /// What's New: under the rest in one column, a column of its own in two.
    private var whatsNew: some View {
        WhatsNewSection(
            agents: window.agents,
            sessions: window.actorSessions,
            openAgent: openAgent,
            openActorSession: openActorSession
        )
    }
}

/// A list row that's only what it holds: the page's greeting and composer read
/// as the page, not as items of a list.
private struct BareRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#if os(iOS)
/// A tap anywhere on a view, where in the window it landed, that leaves the
/// tap to what's under it too. A SwiftUI tap gesture there, even a
/// simultaneous one, cancels the touch for a list's rows, whose buttons then
/// never fire.
private struct TapAnywhere: UIGestureRecognizerRepresentable {
    let tapped: (CGPoint) -> Void

    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let recognizer = UITapGestureRecognizer()
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer, context: Context) {
        guard recognizer.state == .ended else { return }
        tapped(context.converter.location(in: .global))
    }

    /// Lets the tap recognize alongside the rows' and the scroll view's own.
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
#endif
