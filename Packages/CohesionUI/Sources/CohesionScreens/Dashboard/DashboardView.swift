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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    /// The composer's height and the room for the page, which place it when
    /// it's lifted.
    @State private var composerHeight: CGFloat = 0
    @State private var pageHeight: CGFloat = 0
    /// Whether the message has wrapped past one line, as the composer measures.
    @State private var isPastOneLine = false
    /// Whether the page has faded and left the composer in the middle of it.
    @State private var isLifted = false
    /// The whole page's fade under Reduce Motion, in place of the move.
    @State private var pageOpacity = 1.0
    /// The pane's width, which decides one column or two.
    @State private var pageWidth: CGFloat = 0

    /// Whether the pane holds two columns side by side, each at a reading
    /// width.
    private var isTwoColumn: Bool { pageWidth >= 900 }

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
        ScrollViewReader { proxy in
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
                // Lifted, the invisible greeting's row is the room over the
                // composer, which stays in its row and so keeps the keyboard.
                .frame(height: isLifted ? max(0, (pageHeight - composerHeight) / 2) : nil)
                .opacity(isLifted ? 0 : 1)
                .accessibilityHidden(isLifted)
                .listRowInsets(.vertical, isLifted ? 0 : nil)
                .modifier(BareRow())
                .id(pageTop)
                DashboardComposer(isComposing: $isComposing, isPastOneLine: $isPastOneLine) { agent in
                    notice = Toast(kind: .info, message: "Sent to \(agent.name).", link: AppLink.agent(agent.id).url)
                }
                #if os(iOS)
                .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) {
                    composerFrame = $0
                    composerHeight = $0.height
                }
                #endif
                // What's New's heading brings its own room above it.
                .padding(.bottom, isLifted ? 0 : 4)
                .listRowInsets(.vertical, isLifted ? 0 : nil)
                .modifier(BareRow())
                // Gone rather than invisible, so nothing can tap or scroll to it.
                if !isLifted {
                    DashboardDueSection(workspaceID: workspaceID)
                    if !isTwoColumn { whatsNew }
                }
            }
            .listStyle(.plain)
            .opacity(pageOpacity)
            #if os(iOS)
            .onChange(of: wantsLift) { moveComposer(proxy) }
            #endif
        }
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
        #if os(iOS)
        // Inside the Done button's inset, so it's the room above that.
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { pageHeight = $0 }
        #endif
        .scrollDismissesKeyboard(.interactively)
        #if os(iOS)
        // Beside the rows' own taps, which still open what they hold. The
        // composer's controls keep the keyboard up, as sending does.
        .simultaneousGesture(SpatialTapGesture(coordinateSpace: .global).onEnded { tap in
            if !composerFrame.contains(tap.location) { isComposing = false }
        })
        // Over the keyboard like the chat's composer, with its margins: a
        // keyboard toolbar item sits where the system puts it, and any sheet
        // from here would show it too.
        .safeAreaInset(edge: .bottom) {
            if isComposing && !isAddingToJournal {
                Button("Done") { isComposing = false }
                    .buttonStyle(.glass)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
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

    /// A long message being written makes the composer the focus of the page.
    private var whatsNew: some View {
        WhatsNewSection(
            agents: window.agents,
            sessions: window.actorSessions,
            openAgent: openAgent,
            openActorSession: openActorSession
        )
    }

    private var wantsLift: Bool {
        isComposing && isPastOneLine
    }

    /// Fades the page and lifts the composer, or puts them back. Under Reduce
    /// Motion nothing moves: the page fades out and back with the composer in
    /// its new place.
    private func moveComposer(_ proxy: ScrollViewProxy) {
        let place = {
            isLifted = wantsLift
            // From What's New, which is going, back to where the room over the
            // composer starts.
            if isLifted { proxy.scrollTo(pageTop, anchor: .top) }
        }
        guard reduceMotion else {
            withAnimation(.snappy) { place() }
            return
        }
        withAnimation(.easeOut(duration: 0.12)) {
            pageOpacity = 0
        } completion: {
            place()
            withAnimation(.easeIn(duration: 0.12)) { pageOpacity = 1 }
        }
    }
}

/// The greeting's row, which the page scrolls back to.
private let pageTop = "pageTop"

/// A list row that's only what it holds: the page's greeting and composer read
/// as the page, not as items of a list.
private struct BareRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
