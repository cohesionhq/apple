import CohesionCore
import CohesionMarkdown
import CohesionUI
import PhotosUI
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// An agent's conversation, and a field to send it a message with photos
/// attached. What the user said sits in accent bubbles on the trailing edge;
/// the agent's replies are flat Markdown across the column, as an actor session's
/// transcript has them, under a caption naming the agent where its turn
/// starts. Messages that arrive while it's shown rise in; the history it
/// opens with stays put. Long-pressing one of the agent's messages reacts to
/// it, which starts the agent's turn on the reaction. A reply quotes the
/// message it answers above it, and where the agent reacted to an earlier
/// message of the user's, a line says so; tapping either scrolls to that
/// message. A fork's steps collapse into one row, where it woke, that opens
/// them in a sheet.
@MainActor 
public struct AgentChatView: View {
    let agent: Agent
    /// Called after the agent is edited or deleted from its info sheet.
    let onChange: () async -> Void

    @Environment(AppModel.self) private var model
    @Environment(WindowModel.self) private var window
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var messages: [AgentMessage] = []
    @State private var draft = ""
    /// Counts sends, giving the field a new identity each time: a focused
    /// field can keep drawing what was sent after `draft` empties, until
    /// something else redraws it.
    @State private var sends = 0
    @FocusState private var isComposing: Bool
    /// The images to send with `draft`.
    @State private var images: [AttachmentUpload] = []
    @State private var attachPresentation = AttachPresentation()
    /// The message being sent, shown until its saved copy loads. Once
    /// cohesiond accepts it, the next load to finish clears it: that load
    /// holds the copy, or failed.
    @State private var pending: PendingMessage?
    /// Whether `pending` is on its way, which brings up the indicator: a
    /// beat after it shows, so the two don't land and scroll at once.
    @State private var isSending = false
    /// The images of the messages that have some, by message, as they load.
    @State private var attachments: [Int: [PlatformImage]] = [:]
    /// The messages whose images are being fetched, so a load while they
    /// are doesn't fetch them again.
    @State private var fetchingAttachments: Set<Int> = []
    /// Reactions sent but not yet loaded back, by message; `""` for one
    /// taken back.
    @State private var sentReactions: [Int: String] = [:]
    /// The newest message before `pending` was sent. Once a load brings in
    /// its saved copy, that copy stands in its place.
    @State private var pendingAfter = 0
    /// What cohesiond says the agent is doing, as of the last load that also
    /// brought its messages, so the reply lands as the caption leaves. It
    /// keeps the indicator up after a send whose connection dropped, while
    /// the daemon still answers it.
    @State private var activity: String?
    /// Whether the agent's conversation has a turn running, as of the last
    /// load, which the send button stops while there's nothing to send.
    @State private var isTurnRunning = false
    @State private var error: (any Error)?
    /// The newest message the feed has shown, nil until the first load, so
    /// only messages newer than it animate in.
    @State private var newestID: Int?
    /// The messages the last load brought in, which rise in.
    @State private var arriving: Set<Int> = []
    @State private var isShowingInfo = false
    /// The memory line tapped, shown in a sheet.
    @State private var viewedMemory: ViewedMemory?
    /// The fork whose row was tapped, or a quote of one of its steps, shown
    /// in a sheet.
    @State private var viewedFork: ViewedFork?
    /// The runs going on, as of the last load, whose forks' rows shimmer.
    @State private var runningRuns: Set<Int> = []
    /// Where the info sheet zooms out of and back into: the header.
    @Namespace private var header
    /// Picks waiting on the agent's reply, by choice message: shown on
    /// their card until a load brings the pick back saved.
    @State private var picks: [Int: Int] = [:]
    @State private var position = ScrollPosition(edge: .bottom)
    /// Counts loads started.
    @State private var loads = 0
    /// The newest load whose messages the feed shows, so one that finishes
    /// after a newer one leaves the feed to it rather than putting back older
    /// messages, while one whose newer load failed still shows.
    @State private var applied = 0
    /// Whether the conversation has messages older than the feed's first,
    /// which "Load earlier messages" brings in a page at a time.
    @State private var hasEarlier = false
    @State private var isLoadingEarlier = false
    /// The message a tapped quote or reaction line scrolled to, lit for a
    /// moment so it stands out.
    @State private var revealed: Int?

    public init(agent: Agent, onChange: @escaping () async -> Void) {
        self.agent = agent
        self.onChange = onChange
    }

    public var body: some View {
        ScrollViewReader { proxy in
            feed(proxy)
        }
    }

    private func feed(_ proxy: ScrollViewProxy) -> some View {
        ScrollView {
            // Not lazy: a lazy stack guesses the height of rows it hasn't
            // laid out, and a tall reply above throws the guess off by enough
            // that a message sent or arriving lands under the composer, with
            // the feed scrolled up. The feed holds a page of messages, and
            // more only as earlier pages are asked for, so measuring them
            // all is cheap.
            VStack(alignment: .leading, spacing: 8) {
                // Worked out once a redraw rather than once a row: the feed
                // redraws on every keystroke in the composer.
                let runs = CollapsedRuns(messages)
                let layout = FeedLayout(runs.shown)
                if hasEarlier {
                    Button(isLoadingEarlier ? "Loading…" : "Load earlier messages", action: loadEarlier)
                        .buttonStyle(.bordered)
                        .disabled(isLoadingEarlier)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
                ForEach(Array(runs.shown.enumerated()), id: \.element.id) { index, message in
                    // A message grouped under the first of its run shows there.
                    if !layout.grouped.contains(message.id) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let reacted = layout.reactionLines[index] {
                                ReactionLines(messages: reacted) { reveal($0, proxy) }
                            }
                            if layout.triggerStarts.contains(message.id), let trigger = trigger(of: message) {
                                TriggerView(text: trigger)
                            } else if layout.runEnds.contains(message.id) {
                                RuleDivider()
                                    .padding(.bottom, FeedLayout.ruleGap)
                            }
                            if layout.captioned.contains(message.id) {
                                ReplyCaption(title: agent.name)
                            }
                            if let replyTo = message.replyTo {
                                QuoteLine(quoted: runs.byID[replyTo]) { reveal(replyTo, proxy) }
                            }
                            if let fork = runs.fork(anchoredAt: message) {
                                ForkRow(fork: fork, isRunning: runningRuns.contains(fork.id)) {
                                    viewedFork = ViewedFork(fork: fork, revealing: nil)
                                }
                                .litWhile(revealed == message.id)
                                .id(message.id)
                            } else if let group = layout.groups[message.id] {
                                BookkeepingGroup(messages: group) { viewedMemory = $0 }
                            } else {
                                MessageView(
                                    message: message,
                                    reaction: reaction(of: message),
                                    images: attachments[message.id],
                                    picked: picks[message.id],
                                    respond: respond,
                                    pick: pick,
                                    react: react,
                                    viewMemory: { viewedMemory = $0 }
                                )
                                // Redrawn only when what it shows changes, not on each
                                // load or keystroke: its closures never compare equal.
                                .equatable()
                                .litWhile(revealed == message.id)
                                // On the message alone, which a tapped quote
                                // scrolls to, not the lines above it.
                                .id(message.id)
                            }
                        }
                        .padding(.top, layout.gap(above: message))
                        .transition(arriving.contains(message.id) ? .rise : .identity)
                    }
                }
                if let reacted = layout.reactionLines[runs.shown.count] {
                    ReactionLines(messages: reacted) { reveal($0, proxy) }
                }
                if let pending, !delivered(pending.text, after: pendingAfter) {
                    VStack(alignment: .leading, spacing: 8) {
                        if layout.endsInRun {
                            RuleDivider()
                                .padding(.bottom, FeedLayout.ruleGap)
                        }
                        // Spaced as the saved copy that takes its place is.
                        VStack(alignment: .trailing, spacing: 4) {
                            if !pending.images.isEmpty {
                                AttachedImages(images: pending.images, count: pending.images.count, reaction: nil)
                            }
                            if !pending.text.isEmpty {
                                UserBubble(text: pending.text, reaction: nil)
                            }
                        }
                        .opacity(pending.sentAfter != nil ? 1 : 0.5)
                    }
                    .padding(.top, messages.last?.sender == .user ? 0 : FeedLayout.blockGap)
                    // Its saved copy takes its place in the same spot, so it
                    // leaves at once rather than sliding out over the copy.
                    .transition(.asymmetric(insertion: .rise, removal: .identity))
                }
                // A message or pick on its way has no activity yet.
                if isSending || !picks.isEmpty || activity != nil {
                    WorkingIndicator(activity: activity)
                        // Where the reply's caption will land.
                        .padding(.top, FeedLayout.blockGap)
                        .transition(.rise)
                }
            }
            .frame(maxWidth: conversationColumnWidth, alignment: .leading)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .environment(\.agentColor, agent.color.color)
        .scrollPosition($position)
        .sensoryFeedback(.selection, trigger: revealed) { _, revealed in revealed != nil }
        // Opens at the end, sits there while the feed is shorter than the
        // screen, and stays there as the content grows (a message, the
        // indicator, a photo loading, the keyboard) in the same layout pass,
        // so the feed never shows a frame short of its end. The rows' own
        // transitions supply the motion; scrolling after the fact, animated,
        // is what flashed.
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { composer }
        // The header, as Messages draws a contact: the avatar up in the
        // navigation bar over a pill just below it, in a bar of its own that
        // carries the bar's blur and the feed's top down past it. It lives
        // in the chat rather than the navigation bar, which clips its items
        // to its bounds while a push slides them in.
        .safeAreaBar(edge: .top) {
            ChatHeader(agent: agent) { isShowingInfo = true }
                // Before it rises, so the zoom's source spans the avatar
                // rather than clipping it until the sheet is gone.
                .matchedTransitionSource(id: agent.id, in: header)
                #if os(iOS)
                .padding(.top, -53)
                #endif
        }
        // Hard, as Messages has it: the feed doesn't read through the header.
        .scrollEdgeEffectStyle(.hard, for: .top)
        .navigationTitle(agent.name)
        .navigationBarTitleDisplayMode(.inline)
        #if os(iOS)
        .toolbar(removing: .title)
        #endif
        .sizedSheet(isPresented: $isShowingInfo) {
            AgentInfoView(agent: agent, onChange: onChange)
                .zoomTransition(from: agent.id, in: header)
        }
        .sizedSheet(item: $viewedMemory) { viewed in
            MemorySheet(agent: agent, viewed: viewed)
        }
        .sizedSheet(item: $viewedFork) { viewed in
            // As the feed has it now, so a fork still going fills in; one a
            // load has since dropped from the feed stays as it was opened.
            let fork = CollapsedRuns(messages).forks[viewed.id] ?? viewed.fork
            ForkSheet(
                agent: agent,
                fork: fork,
                isRunning: runningRuns.contains(fork.id),
                activity: activity,
                revealing: viewed.revealing
            )
        }
        .task { await watch() }
        .onAppear { model.shownAgentIDs.append(agent.id) }
        .onDisappear {
            // Another window may show the same chat.
            if let index = model.shownAgentIDs.firstIndex(of: agent.id) {
                model.shownAgentIDs.remove(at: index)
            }
        }
        .refreshable { await load(.asked) }
        .onChange(of: scenePhase) { _, phase in
            // A turn may have finished while the app was away.
            if phase == .active { Task { await load() } }
        }
        .onChange(of: model.failedReplies[agent.id], initial: true) { restoreFailedReply() }
        .errorAlert(window.errorHeldForSheets($error))
    }

    /// How arriving messages rise in: none under Reduce Motion.
    private var arrival: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.2)
    }

    /// Scrolls to message `id`, which a quote or reaction line names, and
    /// lights it for a moment; a fork's step is in the fork's sheet, which
    /// opens on it.
    private func reveal(_ id: Int, _ proxy: ScrollViewProxy) {
        let runs = CollapsedRuns(messages)
        if let message = runs.byID[id], message.runPart == .step, let run = message.runID, let fork = runs.forks[run] {
            viewedFork = ViewedFork(fork: fork, revealing: id)
            return
        }
        withAnimation(reduceMotion ? nil : .smooth) { proxy.scrollTo(id, anchor: .center) }
        withAnimation(.easeOut(duration: 0.2)) { revealed = id }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard revealed == id else { return }
            withAnimation(.easeOut(duration: 0.4)) { revealed = nil }
        }
    }

    /// A floating glass field with the attach menu (paste, photos, and on
    /// iPad the chat's sketch) and the send button inside it, under the
    /// images to send.
    private var composer: some View {
        VStack(spacing: 0) {
            if !images.isEmpty {
                DraftImages(images: $images)
                    .transition(.opacity)
            }
            composerRow
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
        .frame(maxWidth: conversationColumnWidth)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }

    private func attach(_ items: [PhotosPickerItem]) {
        Task {
            let loaded = await AttachmentUpload.load(items)
            withAnimation(arrival) {
                images.append(contentsOf: loaded.prefix(max(0, AttachmentUpload.limit - images.count)))
            }
        }
    }

    private var composerRow: some View {
        let sketchThread = model.pairing.map { SketchThread(server: $0.serverFingerprint, kind: .agent(agent.id)) }
        return HStack(alignment: .bottom, spacing: 4) {
            AttachMenu(images: $images, sketchThread: sketchThread, presentation: $attachPresentation) {
                Image(systemName: "photo.on.rectangle")
                    .frame(width: 22, height: 22)
                    .padding(6)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(5)
            TextField("Message \(agent.name)", text: $draft, axis: .vertical)
                .lineLimit(1...6)
                .focused($isComposing)
                .onSubmit {
                    if canSend { send() }
                }
                .id(sends)
                .padding(.vertical, 11)
            // While a turn runs, an empty field's button stops it; anything
            // typed is sent into the turn instead.
            if showsStop {
                Button(action: stop) {
                    Image(systemName: "stop.fill")
                        .frame(width: 22, height: 22)
                        .symbolEffect(.bounce.up, value: reduceMotion ? 0 : sends)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Stop")
                .padding(5)
            } else {
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .fontWeight(.semibold)
                        .frame(width: 22, height: 22)
                        .symbolEffect(.bounce.up, value: reduceMotion ? 0 : sends)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .disabled(!canSend)
                .accessibilityLabel("Send")
                .padding(5)
            }
        }
        .attachPresenter($attachPresentation, images: $images, sketchThread: sketchThread, attach: attach)
    }

    private var showsStop: Bool {
        isTurnRunning && pending == nil && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && images.isEmpty
    }

    private var canSend: Bool {
        pending == nil && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty)
    }

    /// `message`'s reaction, or the one sent for it that hasn't loaded back.
    private func reaction(of message: AgentMessage) -> String? {
        guard let sent = sentReactions[message.id] else { return message.reaction }
        return sent.isEmpty ? nil : sent
    }

    /// What woke the run `message` opens; a job that doesn't say reads
    /// "Job", as the web's feed has it. A question that opens a run says what
    /// woke it itself, so it has none.
    private func trigger(of message: AgentMessage) -> String? {
        guard message.ask == nil else { return nil }
        return message.runDescription ?? (message.sender == .backgroundAgent ? "Job" : nil)
    }

    /// Loads the conversation, then reloads it whenever cohesiond reports the
    /// agent changed while it's on screen. Requests to the agent return
    /// before its turn runs, so this is how what it posts shows up, along
    /// with notes from jobs.
    private func watch() async {
        guard let client = model.client else { return }
        // Its socket connects while the first load runs.
        let changes = client.changes(matching: { [id = agent.id] in $0 == .agent(id) })
        await load(.asked)
        try? await client.markRead(agent.id)
        for await _ in changes {
            await load()
        }
    }

    /// The messages a load fetches at least, and an earlier page holds.
    private static let page = 100
    /// How many of its latest runs a load reads for the ones going on.
    private static let latestRuns = 10

    /// Reloads the feed: as many of the newest messages as it shows, so
    /// earlier pages stay and pick up what changed in them. A failed fetch is
    /// tried twice more before it's an error, which a load nobody asked for
    /// keeps to itself, and the feed keeps the last load that worked.
    private func load(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client else { return }
        loads += 1
        let load = loads
        let limit = max(Self.page, messages.count)
        do {
            async let current = client.agent(agent.id)
            let loaded = try await retrying(while: { load > applied }) {
                try await client.listMessages(of: agent.id, limit: limit)
            }
            guard load > applied else { return }
            applied = load
            let feed = merged(loaded, limit: limit)
            // Most changes cohesiond reports while the agent works (what it
            // says it's doing, a read) leave its messages as they were, and
            // putting back an equal feed would redraw it for nothing.
            if feed != self.messages {
                // The saved copy of a message being sent replaces its stand-in,
                // already on screen, so it doesn't rise in again.
                arriving = Set(feed.lazy.filter { message in
                    guard let newestID else { return false }
                    return message.id > newestID && !(pending != nil && message.sender == .user)
                }.map(\.id))
                newestID = max(newestID ?? 0, feed.last?.id ?? 0)
                // The saved copy of a message being sent keeps the photos already
                // on screen rather than fetching them again.
                if let pending, !pending.images.isEmpty,
                   let saved = feed.last(where: { $0.id > pendingAfter && $0.sender == .user && $0.text == pending.text }) {
                    attachments[saved.id] = attachments[saved.id] ?? pending.images
                }
                // Only a load with messages to rise in animates: a row inserted
                // under animation slides in, which the saved copy of a sent
                // message, in its stand-in's spot, mustn't.
                withAnimation(arriving.isEmpty ? nil : arrival) { self.messages = feed }
            }
            // Started after cohesiond accepted the message, which it saved
            // first, so its copy is in the feed now and stands in its place.
            if let sentAfter = pending?.sentAfter, load > sentAfter { pending = nil }
            fetchAttachments(of: feed)
            let shown = try await current
            guard load == applied else { return }
            let isTurnRunning = shown.foregroundStarted != nil
            if shown.isWorking != (activity != nil) || isTurnRunning != self.isTurnRunning {
                withAnimation(arrival) {
                    activity = shown.activity
                    self.isTurnRunning = isTurnRunning
                }
            } else {
                // New words mid-turn: the caption fades them in itself.
                activity = shown.activity
            }
            // What the agent posts while the conversation is shown is read.
            if shown.isUnread { try? await client.markRead(agent.id) }
            // Only forks in the feed need it, and only while the agent works.
            if !shown.isWorking {
                runningRuns = []
            } else if feed.contains(where: { $0.runPart == .step }),
                      let runs = try? await client.listRuns(of: agent.id, limit: Self.latestRuns), load == applied {
                runningRuns = Set(runs.compactMap { run in
                    if case .running = run.state { run.id } else { nil }
                })
            }
        } catch where !Task.isCancelled {
            // A load cut short by leaving the screen isn't an error, and
            // neither is one a newer load stands in for.
            guard load == loads, load > applied else { return }
            if origin == .asked { self.error = error }
            if let sentAfter = pending?.sentAfter, load > sentAfter { withAnimation(arrival) { pending = nil } }
        } catch {}
    }

    /// `fetch`, tried again after a second and then two while `stillWanted`
    /// says its result would be used.
    private func retrying<T>(
        while stillWanted: () -> Bool,
        _ fetch: () async throws -> T
    ) async throws -> T {
        for delay in [1, 2] {
            do {
                return try await fetch()
            } catch where !Task.isCancelled && stillWanted() {
                try await Task.sleep(for: .seconds(delay))
            }
        }
        return try await fetch()
    }

    /// The feed with `loaded`, the newest `limit` messages, in it. Fewer
    /// than `limit` is the whole conversation. Otherwise the shown messages
    /// older than `loaded`, which newer ones pushed out of it, stay above it,
    /// unless it holds none of the shown messages: more than `limit` arrived
    /// at once and some between may be missing, so the feed starts over.
    private func merged(_ loaded: [AgentMessage], limit: Int) -> [AgentMessage] {
        guard loaded.count == limit, let first = loaded.first else {
            hasEarlier = false
            return loaded
        }
        let kept = messages.prefix { $0.id < first.id }
        guard !kept.isEmpty, kept.count < messages.count else {
            hasEarlier = true
            return loaded
        }
        return kept + loaded
    }

    /// Brings in the page of messages before the feed's first, above it,
    /// where the scroll position stays.
    private func loadEarlier() {
        guard let client = model.client, let first = messages.first, !isLoadingEarlier else { return }
        isLoadingEarlier = true
        Task {
            do {
                let earlier = try await client.listMessages(of: agent.id, before: first.id, limit: Self.page)
                // A load that started the feed over since leaves it as is.
                if messages.first?.id == first.id {
                    messages = earlier.filter { $0.id < first.id } + messages
                    hasEarlier = earlier.count == Self.page
                    fetchAttachments(of: earlier)
                }
            } catch where !Task.isCancelled {
                self.error = error
            } catch {}
            isLoadingEarlier = false
        }
    }

    /// Fetches the images of `loaded`'s messages that have some not yet
    /// shown, apart from the load, so a message never waits on the photos
    /// above it. A failed fetch leaves grey squares, tried again on the next
    /// load.
    private func fetchAttachments(of loaded: [AgentMessage]) {
        guard let client = model.client else { return }
        let missing = loaded.filter {
            $0.attachmentCount > 0 && attachments[$0.id] == nil && !fetchingAttachments.contains($0.id)
        }
        guard !missing.isEmpty else { return }
        fetchingAttachments.formUnion(missing.map(\.id))
        Task {
            for message in missing {
                if let fetched = try? await client.attachments(of: message) {
                    withAnimation(arrival) { attachments[message.id] = fetched.compactMap(\.image) }
                }
                fetchingAttachments.remove(message.id)
            }
        }
    }

    private func send() {
        guard let client = model.client else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let uploads = images
        draft = ""
        // The new field takes the focus once it's in, so the keyboard stays up.
        sends += 1
        if isComposing { DispatchQueue.main.async { isComposing = true } }
        withAnimation(arrival) { images = [] }
        let lastID = messages.last?.id ?? 0
        pendingAfter = lastID
        withAnimation(arrival) { pending = PendingMessage(text: text, images: uploads.map(\.preview)) }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(arrival) { isSending = true }
            do {
                try await client.deliver(text, images: uploads, to: agent.id, after: lastID)
                // It stays until a load started from here on finishes, which
                // brings its saved copy: one already running may predate it.
                withAnimation(arrival) { pending?.sentAfter = loads }
                await load()
            } catch {
                withAnimation(arrival) { pending = nil }
                self.error = error
                draft = text
                images = uploads + images
            }
            withAnimation(arrival) { isSending = false }
        }
    }

    /// Puts a reply a notification couldn't send into the field, after
    /// anything already typed there.
    private func restoreFailedReply() {
        guard let reply = model.failedReplies.removeValue(forKey: agent.id) else { return }
        draft = draft.isEmpty ? reply : draft + "\n" + reply
    }

    /// Reacts to the agent's `message` with `reaction`, or takes the
    /// reaction back with `nil`. It shows at once; the agent's turn on it
    /// runs on in cohesiond, so the working indicator follows the loads.
    private func react(_ message: AgentMessage, _ reaction: String?) {
        guard let client = model.client else { return }
        withAnimation(arrival) { sentReactions[message.id] = reaction ?? "" }
        Task {
            do {
                try await client.react(to: message, with: reaction)
            } catch {
                self.error = error
            }
            await load()
            sentReactions[message.id] = nil
        }
    }

    /// Whether the feed holds `text` from the user, newer than message `lastID`.
    private func delivered(_ text: String, after lastID: Int) -> Bool {
        messages.contains { $0.id > lastID && $0.sender == .user && $0.text == text }
    }

    /// Picks option `option` of `choice`; the agent works on it like a sent
    /// message, so the indicator shows until cohesiond says it's done.
    private func pick(_ option: Int, in choice: AgentMessage) {
        guard let client = model.client else { return }
        withAnimation(arrival) { picks[choice.id] = option }
        Task {
            do {
                try await client.pick(option, in: choice)
            } catch {
                self.error = error
            }
            await load()
            // Saved, the pick is on the choice; failed, the card offers its answers again.
            withAnimation(arrival) { picks[choice.id] = nil }
        }
    }

    /// Stops the conversation's running turn; what it was doing shows as
    /// stopped once cohesiond says the turn is over.
    private func stop() {
        guard let client = model.client else { return }
        withAnimation(arrival) { isTurnRunning = false }
        Task {
            do {
                try await client.stopTurn(of: agent.id)
            } catch {
                self.error = error
            }
            await load()
        }
    }

    private func respond(to proposal: AgentMessage, approve: Bool) {
        guard let client = model.client else { return }
        Task {
            do {
                try await client.respond(to: proposal, approve: approve)
            } catch {
                self.error = error
            }
            await load()
        }
    }
}

/// A fork's steps, gathered under what woke it.
private struct ForkRun {
    /// The run's id.
    let id: Int
    /// What stands for it in the feed: its trigger, or its first step when
    /// the trigger isn't loaded.
    let anchor: AgentMessage
    let steps: [AgentMessage]

    /// Whether another agent's question woke it, which keeps its line, opening
    /// the question, at the head of the steps.
    var opensOnQuestion: Bool {
        anchor.runPart == .trigger && anchor.ask != nil
    }

    /// What its sheet lists.
    var lines: [AgentMessage] {
        opensOnQuestion ? [anchor] + steps : steps
    }

    /// What woke it, in one line, as the web's feed words it.
    var title: String {
        guard anchor.runPart == .trigger, let excerpt = anchor.excerpt else {
            return anchor.runDescription ?? "An earlier run"
        }
        guard anchor.ask == nil, let description = anchor.runDescription else { return excerpt }
        return "\(excerpt): \(description)"
    }
}

/// A fork open in a sheet.
private struct ViewedFork: Identifiable {
    /// The fork as it was opened.
    let fork: ForkRun
    /// The step to open on, which a quote named.
    let revealing: Int?

    var id: Int { fork.id }
}

/// The messages with each fork's steps gathered under what woke it, by the
/// `runID` and `runPart` cohesiond gives each, as the web's feed has them. A
/// fork's messages may fall among others, so they go by run, not position.
private struct CollapsedRuns {
    /// What the feed shows, in order: everything but steps, and the first
    /// step of a fork whose trigger isn't loaded, which stands for it. A
    /// message from a cohesiond that sorts none is shown like any other.
    var shown: [AgentMessage] = []
    /// The forks with steps, by run.
    var forks: [Int: ForkRun] = [:]
    /// Every message by id, for the quotes of replies.
    var byID: [Int: AgentMessage] = [:]

    init(_ messages: [AgentMessage]) {
        var triggers: [Int: AgentMessage] = [:]
        var steps: [Int: [AgentMessage]] = [:]
        for message in messages {
            byID[message.id] = message
            guard let run = message.runID else { continue }
            if message.runPart == .trigger { triggers[run] = message }
            if message.runPart == .step { steps[run, default: []].append(message) }
        }
        for (run, steps) in steps {
            forks[run] = ForkRun(id: run, anchor: triggers[run] ?? steps[0], steps: steps)
        }
        shown = messages.filter { message in
            guard message.runPart == .step, let run = message.runID else { return true }
            return forks[run]?.anchor.id == message.id
        }
    }

    /// The fork whose row `message` is in the feed. A fork with no steps has
    /// no row: its trigger shows as its own line does.
    func fork(anchoredAt message: AgentMessage) -> ForkRun? {
        guard let run = message.runID, let fork = forks[run], fork.anchor.id == message.id else { return nil }
        return fork
    }
}

private extension AgentMessage {
    /// Whether, shown in the feed, it stands for its fork: a trigger, or the
    /// first step of a fork with none. It says what woke the fork, so it has
    /// no rule above it or below it.
    var opensFork: Bool {
        runPart == .trigger || runPart == .step
    }
}

/// How the feed sets its messages out, worked out in one pass over them.
private struct FeedLayout {
    /// Messages that open a block: a change of speaker, or of run. Blocks are spaced apart, while a turn's messages and the code it
    /// ran sit close together, like a thread of texts.
    var blockStarts = Set<Int>()
    /// The agent's flat replies straight after another of the same block,
    /// which stand a little further apart than the block's other messages,
    /// so that they don't read as paragraphs of one reply.
    var followingReplies = Set<Int>()
    /// The first reply or question of each stretch of the agent's foreground
    /// turn, whose caption names the agent, with no bubble left to set it
    /// apart. A job or fork has its trigger instead.
    var captioned = Set<Int>()
    /// Messages that begin a job or fork, which show what woke it. A run's
    /// later messages share the trigger, so it's shown once.
    var triggerStarts = Set<Int>()
    /// Foreground messages that follow a job or fork, which a bare rule
    /// sets apart from it.
    var runEnds = Set<Int>()
    /// The agent's reactions to the user's messages that get a line of their
    /// own, by the index of the message the line goes before (the count of
    /// the messages for the end): where the agent reacted, by `reactedAt`. A
    /// reaction to the message just above that spot has none, since its
    /// badge already sits there. In the second the agent reacted, the user's
    /// messages come before the line and the agent's after it, as its turn
    /// reacts and then replies. As the web's feed places them.
    var reactionLines: [Int: [AgentMessage]] = [:]
    /// Runs of two or more of the agent's bookkeeping lines with one verb
    /// (`Noted`, `Remembered`), back to back in one block, by their first
    /// message, which shows them all under the verb.
    var groups: [Int: [AgentMessage]] = [:]
    /// The messages after the first of each of `groups`, which it shows.
    var grouped = Set<Int>()
    /// Whether the last message is of a run a bare rule would end, for the
    /// message on its way under it.
    var endsInRun = false

    /// The space a block adds over the feed's own, 28 points between blocks
    /// and as an actor session's transcript has between speakers.
    static let blockGap: CGFloat = 20
    /// What a following reply adds over the feed's own: 14 points between
    /// them, as an actor's messages have.
    static let replyGap: CGFloat = 6
    /// What a bare rule ending a run adds below itself, to sit as far from
    /// the message under it as from the one over it.
    static let ruleGap: CGFloat = 12

    /// The space `message` adds above itself.
    func gap(above message: AgentMessage) -> CGFloat {
        if blockStarts.contains(message.id) { return Self.blockGap }
        return followingReplies.contains(message.id) ? Self.replyGap : 0
    }

    init(_ messages: [AgentMessage]) {
        var previous: Source?
        var previousWasReply = false
        // Whether this stretch of the agent's foreground turn has its caption.
        var hasCaption = false
        // The first message of the run of bookkeeping lines being read.
        var groupStart: AgentMessage?
        // Whether the previous message stands for its fork on its own line.
        var previousOpensFork = false
        for (index, message) in messages.enumerated() {
            // A rebuilt context has no run of its own: it stands in whichever
            // run it fell in, rather than splitting it in two.
            let source = if message.content == .rebuiltContext, let previous, previous.runID != nil {
                previous
            } else {
                Source(message)
            }
            if let start = groupStart, let verb = message.excerptVerb, verb == start.excerptVerb,
               source == previous, reactionLines[index] == nil {
                groups[start.id, default: [start]].append(message)
                grouped.insert(message.id)
            } else {
                groupStart = message.excerptVerb != nil ? message : nil
            }
            if let run = source.runID, run != previous?.runID, !message.opensFork { triggerStarts.insert(message.id) }
            if let previous {
                if source != previous { blockStarts.insert(message.id) }
                if previous.runID != nil && source.runID == nil && !previousOpensFork { runEnds.insert(message.id) }
            }
            if message.content != .rebuiltContext { previousOpensFork = message.opensFork }
            let isReply = message.sender != .user && message.text != nil
            if isReply && previousWasReply && source == previous { followingReplies.insert(message.id) }
            if source.sender == .agent && source.runID == nil {
                var opensTurn = isReply
                if case .choice = message.content { opensTurn = true }
                if opensTurn && !hasCaption {
                    captioned.insert(message.id)
                    hasCaption = true
                }
            } else {
                hasCaption = false
            }
            previous = source
            previousWasReply = isReply
            guard message.sender == .user, message.reaction != nil, message.excerpt != nil,
                  let reactedAt = message.reactedAt
            else { continue }
            var at = index + 1
            while at < messages.count, messages[at].sentAt <= reactedAt,
                  !(messages[at].sentAt == reactedAt && messages[at].sender != .user) {
                at += 1
            }
            if at > index + 1 { reactionLines[at, default: []].append(message) }
        }
        endsInRun = previous?.runID != nil && !previousOpensFork
    }
}

/// Who sent a message, telling runs apart. A question between agents is the
/// agent's own, however it came, within the run it belongs to.
private struct Source: Equatable {
    let sender: AgentMessage.Sender
    let runID: Int?

    init(_ message: AgentMessage) {
        if message.ask != nil {
            (sender, runID) = (.agent, message.runID)
        } else {
            (sender, runID) = (message.sender, message.runID)
        }
    }
}

/// The chat's header: the agent's avatar, to be raised into the navigation
/// bar so it tops out level with the back button, just over `HeaderPill`. Tapping either opens the agent's info.
private struct ChatHeader: View {
    let agent: Agent
    let showInfo: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Button(action: showInfo) {
                AgentAvatar(agent: agent, diameter: 48)
            }
            .buttonStyle(.plain)
            // `HeaderPill` speaks for the header.
            .accessibilityHidden(true)
            // Over the pill's edge, clear of its name.
            .zIndex(1)
            HeaderPill(agent: agent, showInfo: showInfo)
        }
    }
}

/// The foot of the chat's header: a glass pill with the agent's name, under
/// its avatar, as Messages draws a contact. Its role is on its info sheet,
/// which a cut-off line here would only repeat.
private struct HeaderPill: View {
    let agent: Agent
    let showInfo: () -> Void

    var body: some View {
        Button(action: showInfo) {
            HStack(spacing: 2) {
                Text(agent.name)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassEffect(.regular.interactive(), in: .capsule)
            .frame(maxWidth: 220)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(agent.name)
        .accessibilityHint("Shows the agent's info")
        .accessibilityAddTraits(.isButton)
    }
}

/// An agent or actor session at work: a caption at the foot of its transcript,
/// saying what it's doing and shimmering. In an agent's chat it's where the
/// reply's caption will land; an actor session has no color of its own, so its
/// dot is the accent.
struct WorkingIndicator: View {
    /// The agent's activity, as cohesiond words it. An actor session has none,
    /// and an agent has none yet while a message is on its way.
    var activity: String?

    var body: some View {
        let words = activity.flatMap { $0.isEmpty ? nil : $0 }
        ReplyCaption(title: words ?? "Working…", isWorking: true)
            .accessibilityRemoveTraits(.isHeader)
            .accessibilityLabel(words ?? "Working")
    }
}

/// A message on its way to cohesiond, shown until its saved copy loads.
private struct PendingMessage {
    let text: String
    let images: [PlatformImage]
    /// The loads started by the time cohesiond accepted it, `nil` until
    /// then, while it shows faded. A load started after holds its saved
    /// copy, which shows in its place unfaded: it's saved.
    var sentAfter: Int?
}

extension AnyTransition {
    /// A message arriving in the feed: up 8 points as it fades in.
    static var rise: AnyTransition {
        .offset(y: 8).combined(with: .opacity)
    }
}

/// One message, drawn by what it holds. Equal while what it shows is,
/// whatever its closures, which do the same from one redraw to the next.
private struct MessageView: View, Equatable {
    let message: AgentMessage
    /// The reaction to show, which may be ahead of `message`'s.
    let reaction: String?
    /// The attached images, once loaded.
    let images: [PlatformImage]?
    /// The pick of this choice waiting on the agent's reply, if any.
    let picked: Int?
    var respond: (AgentMessage, Bool) -> Void = { _, _ in }
    var pick: (Int, AgentMessage) -> Void = { _, _ in }
    var react: (AgentMessage, String?) -> Void = { _, _ in }
    /// Opens a memory line in a sheet.
    let viewMemory: (ViewedMemory) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.message == rhs.message && lhs.reaction == rhs.reaction && lhs.picked == rhs.picked
            && lhs.images?.count == rhs.images?.count
            && zip(lhs.images ?? [], rhs.images ?? []).allSatisfy { $0 === $1 }
    }

    var body: some View {
        switch message.content {
        case .text(let text):
            if message.sender == .user {
                VStack(alignment: .trailing, spacing: 4) {
                    if message.attachmentCount > 0 {
                        // The agent's reaction sits on the text, or on the
                        // photos when there's none.
                        AttachedImages(
                            images: images,
                            count: message.attachmentCount,
                            reaction: text.isEmpty ? reaction : nil
                        )
                    }
                    if !text.isEmpty {
                        UserBubble(text: text, reaction: reaction)
                    }
                }
            } else {
                // The user's reaction goes under all of it. An agent's images
                // always come with text, which the long press copies.
                VStack(alignment: .leading, spacing: 6) {
                    AgentReply(text: text)
                    if message.attachmentCount > 0 {
                        AttachedImages(
                            images: images,
                            count: message.attachmentCount,
                            reaction: nil,
                            edge: .leading
                        )
                    }
                }
                .reactions(reaction, on: .leading, anchor: .below, copying: text) { react(message, $0) }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .memory(let memory, let change):
            Button {
                viewMemory(ViewedMemory(id: message.id, text: memory, change: change))
            } label: {
                StatusView(text: message.line ?? memory, symbol: message.quietSymbol)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(quietLineTapArea)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows the memory")
        case .askedAgent(let ask):
            AskView(ask: ask, title: message.excerpt ?? "Asked \(ask.agent.name)", isAsker: true)
        case .askedByAgent(let ask):
            AskView(ask: ask, title: message.excerpt ?? "\(ask.agent.name) asked", isAsker: false)
        case .codeExecution(let execution):
            CodeExecutionView(execution: execution)
        case .proposal(let proposal):
            ProposalView(proposal: proposal) { approve in
                respond(message, approve)
            }
            .reactions(reaction, on: .leading)
            .padding(.trailing, bubbleInset)
        case .choice(let choice):
            ChoiceView(choice: choice, picked: picked) { option in
                pick(option, message)
            }
            .reactions(reaction, on: .leading)
            .padding(.trailing, bubbleInset)
        case .documentation(let module):
            StatusView(text: "Learning about \(module)", symbol: AgentMessage.Content.documentationSymbol)
        case .error(let error):
            Label(error, systemImage: AgentMessage.Content.errorSymbol)
                .font(.callout)
                .foregroundStyle(AgentMessage.Content.errorTint)
                .textSelection(.enabled)
        case .forward(let note, let item):
            if message.sender == .user {
                ForwardView(
                    message: message,
                    note: note,
                    item: item,
                    reaction: reaction,
                    images: images
                )
            } else {
                excerptLine
            }
        case .rebuiltContext, .unknown:
            excerptLine
        }
    }

    /// A kind this build has no view for, as a quiet line of its excerpt.
    @ViewBuilder
    private var excerptLine: some View {
        if let line = message.line {
            StatusView(text: line, symbol: message.quietSymbol)
        }
    }
}

/// The user forwarding an item: "Forwarded", the item's chip set apart,
/// then the photos and the note if there are any. The agent's reaction sits
/// on the last of them.
private struct ForwardView: View {
    let message: AgentMessage
    let note: String
    let item: AgentForwardedItem
    let reaction: String?
    let images: [PlatformImage]?

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Label("Forwarded", systemImage: AgentMessage.Content.forwardSymbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            ForwardChip(item: item) { openURL(item.link.url) }
                .reactions(note.isEmpty && message.attachmentCount == 0 ? reaction : nil, on: .trailing)
                .padding(.leading, bubbleInset)
            if message.attachmentCount > 0 {
                AttachedImages(images: images, count: message.attachmentCount, reaction: note.isEmpty ? reaction : nil)
            }
            if !note.isEmpty {
                UserBubble(text: note, reaction: reaction)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// The message a reply answers, in one muted line behind a bar, like a
/// quote in a text thread; one not loaded, or gone, reads as an earlier
/// message. Tapping it scrolls to the message.
private struct QuoteLine: View {
    let quoted: AgentMessage?
    let reveal: () -> Void

    var body: some View {
        Group {
            if let quoted, let excerpt = quoted.line {
                Button(action: reveal) { line(excerpt) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Replying to “\(excerpt)”")
                    .accessibilityHint("Shows the message")
            } else {
                line("An earlier message")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, bubbleInset)
    }

    private func line(_ text: String) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(.quaternary)
                .frame(width: 3)
            Text(text)
                .lineLimit(1)
        }
        .fixedSize(horizontal: false, vertical: true)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .contentShape(.rect)
    }
}

/// Where the agent reacted to earlier messages of the user's: a quiet line
/// like a memory's for one, and for several `Reacted` once with a line for
/// each under it. A line scrolls to its message.
private struct ReactionLines: View {
    /// One or more, each with a reaction.
    let messages: [AgentMessage]
    /// Scrolls to the message with this id.
    let reveal: (Int) -> Void

    /// The web's smile-plus, the react control's icon.
    private static let symbol = "face.smiling"

    var body: some View {
        if messages.count == 1, let message = messages.first {
            line(message.reactionLine, of: message)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                StatusView(text: messages[0].reactionExcerptVerb ?? "Reacted", symbol: Self.symbol)
                    .fontWeight(.semibold)
                ForEach(messages) { message in
                    line(message.reactionExcerpt ?? message.reactionLine, of: message)
                        .padding(.leading, 12)
                }
            }
        }
    }

    private func line(_ text: String, of message: AgentMessage) -> some View {
        Button { reveal(message.id) } label: {
            StatusView(text: text, symbol: messages.count == 1 ? Self.symbol : nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(quietLineTapArea)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows the message")
    }
}

private struct UserBubble: View {
    let text: String
    /// The agent's reaction to it.
    let reaction: String?

    var body: some View {
        UserBubbleLayout {
            Text(markdown(text))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(.white)
                .background(.tint, in: .rect(cornerRadius: bubbleCornerRadius))
                .textSelection(.enabled)
                .reactions(reaction, on: .trailing)
        }
    }
}

/// Takes the column's width and sets the bubble on its trailing edge, no wider
/// than 70% of a wide column, as an actor session's transcript has it, or short of
/// the far edge by `bubbleInset` on a phone, where the agent's flat text fills
/// the column and that gap is what tells the two sides apart.
private struct UserBubbleLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let bubble = subviews.first?.sizeThatFits(widest(in: proposal.width)) ?? .zero
        return CGSize(width: proposal.width ?? bubble.width, height: bubble.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(
            at: CGPoint(x: bounds.maxX, y: bounds.minY),
            anchor: .topTrailing,
            proposal: widest(in: bounds.width)
        )
    }

    private func widest(in column: CGFloat?) -> ProposedViewSize {
        guard let column else { return .unspecified }
        return ProposedViewSize(width: column < 600 ? max(0, column - bubbleInset) : column * 0.7, height: nil)
    }
}

/// The agent's text, flat across the column in the transcript's Markdown, with
/// its ```` ```mermaid ```` blocks drawn as diagrams. It isn't selectable, so
/// that a long press reacts to it or copies it.
private struct AgentReply: View {
    let text: String

    var body: some View {
        MarkdownText(markdown: text, style: .transcript, diagrams: true, selectable: false)
    }
}

/// Names the agent over the start of its turn: a dot in its color and its name,
/// which, with no bubble, say whose the flat text under them is. While the turn
/// hasn't come, the same dot and what the agent's doing (`WorkingIndicator`).
private struct ReplyCaption: View {
    let title: String
    var isWorking = false

    @Environment(\.agentColor) private var agentColor
    @ScaledMetric(relativeTo: .caption) private var dotDiameter: CGFloat = 8

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(agentColor)
                .frame(width: dotDiameter, height: dotDiameter)
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                // New words fade in over the old on the one line, so nothing
                // around them moves.
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: title)
                .workingShimmer(isWorking)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// What woke a job or fork, as a rule with it centered in it.
private struct TriggerView: View {
    let text: String

    var body: some View {
        RuleDivider {
            Label(text, systemImage: "bolt.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

/// A horizontal rule across the feed, with an optional label centered in it.
private struct RuleDivider<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if Content.self == EmptyView.self {
            // One line: two halves would leave the spacing between them.
            rule
        } else {
            HStack(spacing: 8) {
                rule
                content.layoutPriority(1)
                rule
            }
        }
    }

    private var rule: some View {
        VStack { Divider() }
    }
}

extension RuleDivider where Content == EmptyView {
    init() {
        self.init { EmptyView() }
    }
}

/// A run of the agent's bookkeeping lines with one verb: the verb once, as
/// a heading, then what each line says under it. A memory's line opens it,
/// as on its own.
private struct BookkeepingGroup: View {
    /// Two or more, sharing an `excerptVerb`.
    let messages: [AgentMessage]
    let viewMemory: (ViewedMemory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            StatusView(text: messages[0].excerptVerb ?? "", symbol: messages[0].quietSymbol)
                .fontWeight(.semibold)
            ForEach(messages) { message in
                detail(of: message)
                    .padding(.leading, 12)
                    .id(message.id)
            }
        }
    }

    @ViewBuilder
    private func detail(of message: AgentMessage) -> some View {
        if case .memory(let memory, let change) = message.content {
            Button {
                viewMemory(ViewedMemory(id: message.id, text: memory, change: change))
            } label: {
                StatusView(text: memory)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows the memory")
        } else {
            StatusView(text: message.excerpt ?? "")
        }
    }
}

/// The width every quiet line's leading icon takes, so their text lines up.
private let quietSymbolWidth: CGFloat = 16

/// Where a quiet line that opens something takes a tap: past the line, into
/// the space around it, as the line alone is a small target.
private var quietLineTapArea: some Shape { Rectangle().inset(by: -4) }

/// A status change, or a memory remembered or forgotten: one quiet line on
/// the leading edge, like a script the agent ran.
private struct StatusView: View {
    let text: String
    /// The SF Symbol before the words; none for a line under a heading.
    var symbol: String?

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol)
                    .imageScale(.small)
                    .frame(width: quietSymbolWidth)
                    .accessibilityHidden(true)
            }
            Text(text)
                .lineLimit(1)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

/// A script the agent ran: one quiet line that opens the code in a sheet.
private struct CodeExecutionView: View {
    let execution: AgentCodeExecution

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: execution.outcome.symbol).frame(width: quietSymbolWidth)
                Text(execution.title)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .imageScale(.small)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .contentShape(quietLineTapArea)
        }
        .buttonStyle(.plain)
        .sizedSheet(isPresented: $isPresented) {
            CodeExecutionSheet(execution: execution)
        }
    }
}

/// A question between this agent and another: one quiet line, like a
/// script the agent ran, saying who asked whom and what, with how it
/// stands when it has no answer yet. It opens the question and its answer
/// in a sheet.
private struct AskView: View {
    let ask: AgentAsk
    /// The message's excerpt: who asked whom, and the question.
    let title: String
    /// Whether this agent asked, rather than answered.
    let isAsker: Bool

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .lineLimit(1)
                switch ask.reply {
                case .waiting:
                    Text("Waiting")
                        .layoutPriority(1)
                case .unanswered:
                    Text("No answer")
                        .foregroundStyle(AgentAsk.Reply.unansweredTint)
                        .layoutPriority(1)
                case .answered:
                    EmptyView()
                }
                Image(systemName: "chevron.right")
                    .imageScale(.small)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .contentShape(quietLineTapArea)
        }
        .buttonStyle(.plain)
        .sizedSheet(isPresented: $isPresented) {
            AskSheet(ask: ask, isAsker: isAsker)
        }
    }
}

/// A question between agents and how it was answered, with the other
/// agent's chat a tap away.
private struct AskSheet: View {
    let ask: AgentAsk
    let isAsker: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Question") {
                    Text(markdown(ask.question))
                        .textSelection(.enabled)
                }
                switch ask.reply {
                case .waiting:
                    Section {
                        Label("Waiting for an answer.", systemImage: AgentAsk.Reply.waitingSymbol)
                            .foregroundStyle(.secondary)
                    }
                case .answered(let text):
                    Section("Answer") {
                        Text(markdown(text))
                            .textSelection(.enabled)
                    }
                case .unanswered(let reason):
                    Section("No answer") {
                        Text(reason)
                            .foregroundStyle(AgentAsk.Reply.unansweredTint)
                            .textSelection(.enabled)
                    }
                }
                Section {
                    // A link, so the sheet's own `openURL` follows it.
                    Link(destination: AppLink.agent(ask.agent.id).url) {
                        Label("Open \(ask.agent.name)", systemImage: "bubble.left.and.bubble.right")
                    }
                }
            }
            .navigationTitle(isAsker ? "Asked \(ask.agent.name)" : "\(ask.agent.name) asked")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) { dismiss() }
                }
            }
        }
        // Its text can link, and the other agent's chat navigates, which
        // closes this sheet first.
        .presentsLinkedItems()
        .presentationDetents([.medium, .large])
    }
}

/// A fork in the feed: one quiet line saying what woke it and how many steps it
/// took, the count rolling as a fork still going adds to it. It opens the steps
/// in a sheet.
private struct ForkRow: View {
    let fork: ForkRun
    let isRunning: Bool
    let open: () -> Void

    @Environment(\.agentColor) private var agentColor

    private var stepCount: String {
        fork.steps.count == 1 ? "1 step" : "\(fork.steps.count) steps"
    }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .imageScale(.small)
                    .foregroundStyle(agentColor)
                    .accessibilityHidden(true)
                Text(fork.title)
                    .lineLimit(1)
                    .workingShimmer(isRunning)
                Spacer(minLength: 8)
                // At the trailing edge, as the web's feed has it.
                Text(stepCount)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(fork.steps.count)))
                    .lineLimit(1)
                    .layoutPriority(1)
                Image(systemName: "chevron.right")
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            // A row on a faint fill, as it opens a sheet of its own.
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.fill.quaternary, in: .rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityHint("Shows the steps")
    }
}

/// A fork's steps as a transcript of it: what woke it, then each step as the
/// quiet line it is in the chat, opening what it points at over the sheet.
/// While the fork goes on, the same caption as the chat's at its foot.
private struct ForkSheet: View {
    let agent: Agent
    let fork: ForkRun
    let isRunning: Bool
    let activity: String?
    /// The step to open on, lit for a moment.
    let revealing: Int?

    @Environment(\.dismiss) private var dismiss

    /// The memory line tapped, shown in a sheet.
    @State private var viewedMemory: ViewedMemory?
    @State private var revealed: Int?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    let lines = fork.lines
                    let layout = FeedLayout(lines)
                    VStack(alignment: .leading, spacing: 8) {
                        if !fork.opensOnQuestion {
                            Label(fork.title, systemImage: "bolt.fill")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(lines) { message in
                            if !layout.grouped.contains(message.id) {
                                line(message, group: layout.groups[message.id])
                                    .transition(.rise)
                            }
                        }
                        if isRunning {
                            WorkingIndicator(activity: activity)
                                .padding(.top, FeedLayout.blockGap)
                                .transition(.rise)
                        }
                    }
                    .frame(maxWidth: conversationColumnWidth, alignment: .leading)
                    .padding()
                    .frame(maxWidth: .infinity)
                }
                // Opens at the top, and follows a fork still going.
                .defaultScrollAnchor(.bottom, for: .sizeChanges)
                .task { await reveal(proxy) }
            }
            .environment(\.agentColor, agent.color.color)
            .sensoryFeedback(.selection, trigger: revealed) { _, revealed in revealed != nil }
            .navigationTitle("Run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) { dismiss() }
                }
            }
            .sizedSheet(item: $viewedMemory) { viewed in
                MemorySheet(agent: agent, viewed: viewed)
            }
        }
        // A question's sheet links to the other agent's chat, which navigates,
        // closing this sheet too.
        .presentsLinkedItems()
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func line(_ message: AgentMessage, group: [AgentMessage]?) -> some View {
        if let group {
            BookkeepingGroup(messages: group) { viewedMemory = $0 }
        } else {
            MessageView(
                message: message,
                reaction: nil,
                images: nil,
                picked: nil,
                viewMemory: { viewedMemory = $0 }
            )
            .equatable()
            .litWhile(revealed == message.id)
            .id(message.id)
        }
    }

    private func reveal(_ proxy: ScrollViewProxy) async {
        guard let revealing else { return }
        proxy.scrollTo(revealing, anchor: .center)
        withAnimation(.easeOut(duration: 0.2)) { revealed = revealing }
        try? await Task.sleep(for: .seconds(1.2))
        withAnimation(.easeOut(duration: 0.4)) { revealed = nil }
    }
}

/// The code of a script the agent ran, and what it returned.
private struct CodeExecutionSheet: View {
    let execution: AgentCodeExecution

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Code") {
                    Text(execution.code)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                }
                switch execution.outcome {
                case .failed(let error):
                    Section("Error") {
                        Text(error)
                            .font(.callout.monospaced())
                            .foregroundStyle(AgentCodeExecution.Outcome.failedTint)
                            .textSelection(.enabled)
                    }
                case .succeeded(let result):
                    Section("Result") {
                        Text(result)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                    }
                case .cancelled:
                    Section {
                        Label("Stopped before it finished.", systemImage: execution.outcome.symbol)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(execution.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// A change a job asks to make, with buttons while it waits.
private struct ProposalView: View {
    let proposal: AgentProposal
    let respond: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(proposal.action)
                .fontWeight(.medium)
            Text(proposal.justification)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            // Stacked, so the answer fades in over the buttons in their place
            // rather than below them as they go.
            ZStack(alignment: .leading) {
                switch proposal.status {
                case .pending:
                    HStack {
                        Button("Approve") { respond(true) }
                            .buttonStyle(.borderedProminent)
                        Button("Deny", role: .destructive) { respond(false) }
                            .buttonStyle(.bordered)
                    }
                    .controlSize(.small)
                    .padding(.top, 4)
                case .approved:
                    Label("Approved", systemImage: AgentProposal.Status.approvedSymbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .denied:
                    Label("Denied", systemImage: AgentProposal.Status.deniedSymbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .withdrawn:
                    Label("Replaced by a newer proposal", systemImage: AgentProposal.Status.withdrawnSymbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.receivedBubble, in: .rect(cornerRadius: bubbleCornerRadius))
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .smooth, value: proposal.status)
    }
}

private extension View {
    /// Lights a message a quote or reaction line revealed.
    func litWhile(_ isRevealed: Bool) -> some View {
        background {
            if isRevealed {
                // Out far enough that a reply's flat text clears the corners.
                RoundedRectangle(cornerRadius: bubbleCornerRadius + 4)
                    .fill(.tint.opacity(0.12))
                    .padding(-8)
                    .transition(.opacity)
            }
        }
    }
}

extension View {
    /// Shows `reaction` as a pill by `anchor` at `edge`: the leading one for
    /// the user's reaction to the agent, the trailing one for the agent's to
    /// the user. With `react`, long-pressing the message offers the reactions
    /// (picking the one shown takes it back) and, with `copying`, copies that
    /// text.
    func reactions(
        _ reaction: String?,
        on edge: HorizontalEdge,
        anchor: ReactionAnchor = .corner,
        copying text: String? = nil,
        react: ((String?) -> Void)? = nil
    ) -> some View {
        modifier(ReactionsModifier(reaction: reaction, edge: edge, anchor: anchor, text: text, react: react))
    }
}

/// Where a reaction sits on what it reacts to.
enum ReactionAnchor {
    /// Over the bottom corner of a bubble or card, which it stands off.
    case corner
    /// Under flat text, from its edge, since there's no bubble to hang off and
    /// over the text it would hide the last line.
    case below
}

private struct ReactionsModifier: ViewModifier {
    let reaction: String?
    let edge: HorizontalEdge
    let anchor: ReactionAnchor
    let text: String?
    let react: ((String?) -> Void)?

    @Environment(\.agentColor) private var agentColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        switch anchor {
        case .corner:
            menu(on: content)
                .overlay(alignment: edge == .leading ? .bottomLeading : .bottomTrailing) {
                    if let reaction {
                        // Mostly below the bubble, in from its corner, ringed in
                        // the background to stand off it.
                        pill(reaction)
                            .padding(Self.ring)
                            .background(.background, in: .capsule)
                            .offset(x: edge == .leading ? Self.inset : -Self.inset, y: Self.overhang)
                            // A new reaction replaces the old one, popping in.
                            .id(reaction)
                            .transition(pop)
                    }
                }
                // Room for the overhang, so it clears the next message.
                .padding(.bottom, reaction == nil ? 0 : Self.overhang)
                .animation(reduceMotion ? .easeOut(duration: 0.2) : .bouncy, value: reaction)
        case .below:
            VStack(alignment: edge == .leading ? .leading : .trailing, spacing: 6) {
                menu(on: content)
                if let reaction {
                    pill(reaction)
                        .id(reaction)
                        .transition(pop)
                }
            }
            .animation(reduceMotion ? .easeOut(duration: 0.2) : .bouncy, value: reaction)
        }
    }

    /// The emoji on a capsule: the agent's reaction in its color, the user's
    /// in the accent.
    private func pill(_ reaction: String) -> some View {
        Text(reaction)
            .font(.system(size: Self.emojiSize))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                edge == .trailing ? AnyShapeStyle(agentColor.gradient) : AnyShapeStyle(.tint),
                in: .capsule
            )
            .accessibilityLabel(edge == .trailing ? "Agent reacted \(reaction)" : "You reacted \(reaction)")
    }

    /// How a reaction comes and goes: scaling out of the message's corner,
    /// or only fading under Reduce Motion.
    private var pop: AnyTransition {
        reduceMotion
            ? .opacity
            : .scale(scale: 0.3, anchor: edge == .leading ? .topLeading : .topTrailing).combined(with: .opacity)
    }

    private static let emojiSize: CGFloat = 13
    /// The background ring around the pill.
    private static let ring: CGFloat = 2
    /// How far the pill sits in from the bubble's corner.
    private static let inset: CGFloat = 8
    /// How far the pill hangs below the bubble: most of its height, so it
    /// covers little of the last line.
    private static let overhang: CGFloat = 16

    /// Whether the long-press picker is up.
    @State private var isPicking = false

    /// Long-pressing opens a popover of the reactions on the message rather
    /// than a context menu, whose palette stays open after a tap and draws
    /// the emoji small in one row.
    @ViewBuilder
    private func menu(on content: Content) -> some View {
        if let react {
            content
                .contentShape(.rect(cornerRadius: bubbleCornerRadius))
                .onLongPressGesture { isPicking = true }
                .sensoryFeedback(.impact, trigger: isPicking) { _, isPicking in isPicking }
                .accessibilityAction(named: "React") { isPicking = true }
                .popover(isPresented: $isPicking) {
                    ReactionPicker(reaction: reaction, text: text) { picked in
                        isPicking = false
                        react(picked)
                    }
                    .presentationCompactAdaptation(.popover)
                }
        } else {
            content
        }
    }
}

/// The reactions in rows of four, the one shown marked (picking it takes
/// it back), and, with `text`, a button that copies it.
private struct ReactionPicker: View {
    let reaction: String?
    let text: String?
    let react: (String?) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private var rows: [ArraySlice<String>] {
        let reactions = model.vocabulary.agentReactions
        return stride(from: 0, to: reactions.count, by: 4).map {
            reactions[$0..<min($0 + 4, reactions.count)]
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                ForEach(rows, id: \.startIndex) { row in
                    GridRow {
                        ForEach(row, id: \.self) { emoji in
                            Button {
                                react(emoji == reaction ? nil : emoji)
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 32))
                                    .frame(width: 52, height: 52)
                                    .background(emoji == reaction ? AnyShapeStyle(.tint.opacity(0.25)) : AnyShapeStyle(.clear), in: .circle)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(emoji == reaction ? "Remove reaction \(emoji)" : "React \(emoji)")
                        }
                    }
                }
            }
            if let text {
                Divider()
                Button("Copy", systemImage: "doc.on.doc") {
                    Pasteboard.general.string = text
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
    }
}

/// The corner radius of the user's bubble, which proposal and choice cards
/// and an actor session's transcript share.
let bubbleCornerRadius: CGFloat = 18

extension Color {
    /// The grey of a received iMessage bubble, in light and dark mode. The
    /// agent's cards, and an actor's, share it.
    #if os(iOS)
    static let receivedBubble = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x26 / 255, green: 0x26 / 255, blue: 0x28 / 255, alpha: 1)
            : UIColor(red: 0xE9 / 255, green: 0xE9 / 255, blue: 0xEB / 255, alpha: 1)
    })
    #else
    static let receivedBubble = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(red: 0x26 / 255, green: 0x26 / 255, blue: 0x28 / 255, alpha: 1)
            : NSColor(red: 0xE9 / 255, green: 0xE9 / 255, blue: 0xEB / 255, alpha: 1)
    })
    #endif
}

/// The room the user's bubble on a phone, and a card or images, leave on
/// their far side, so the conversation's two sides read apart.
let bubbleInset: CGFloat = 48

/// The widest an agent's chat or an actor session's transcript gets, with what
/// floats at its foot, centred in anything wider. The Dashboard and a task
/// list keep to it too (`centeredColumn()`).
let conversationColumnWidth: CGFloat = 680

extension View {
    /// Keeps a list's rows to `conversationColumnWidth`, centred in a wider
    /// pane, as an iPad's detail is, so a row's trailing marks stay by its title.
    func centeredColumn() -> some View {
        modifier(CenteredColumn())
    }
}

private struct CenteredColumn: ViewModifier {
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            // By the safe area: on iPad, the split view's leaves a leading content
            // margin no effect, which pushes the page off centre.
            .safeAreaPadding(.horizontal, max(0, (width - conversationColumnWidth) / 2))
            #else
            .contentMargins(.horizontal, width > conversationColumnWidth ? (width - conversationColumnWidth) / 2 : nil, for: .scrollContent)
            #endif
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
    }
}

extension EnvironmentValues {
    /// The color of the agent whose conversation this is, which its
    /// caption's dot and its reactions are drawn in.
    @Entry var agentColor: Color = .accentColor
}

/// A question the agent asked, with a button for each answer while it
/// waits; once picked, the pick is marked with a check in an accent disc
/// and the rest fade.
private struct ChoiceView: View {
    let choice: AgentChoice
    /// A pick still waiting on the agent's reply.
    let picked: Int?
    let pick: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selected: Int? { choice.selected ?? picked }

    private static let pickDiameter: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(markdown(choice.question))
                .fontWeight(.medium)
            ForEach(Array(choice.options.enumerated()), id: \.offset) { index, option in
                Button {
                    pick(index)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(String(Character(UnicodeScalar(UInt8(65 + index)))))
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(option)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if selected == index {
                            // A check in an accent disc, drawn as a
                            // reaction is, on the option's first line.
                            Image(systemName: "checkmark")
                                .font(.system(size: Self.pickDiameter * 0.5, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: Self.pickDiameter, height: Self.pickDiameter)
                                .background(.tint, in: .circle)
                                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                                .accessibilityLabel("Picked")
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 8))
                    .opacity(selected == nil || selected == index ? 1 : 0.5)
                }
                .buttonStyle(.plain)
                .disabled(selected != nil)
                .accessibilityAddTraits(selected == index ? .isSelected : [])
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.receivedBubble, in: .rect(cornerRadius: bubbleCornerRadius))
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .bouncy, value: selected)
    }
}

/// Inline Markdown, keeping the text's line breaks.
private func markdown(_ text: String) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
}
