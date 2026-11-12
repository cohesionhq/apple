import CohesionCore
import CohesionMarkdown
import CohesionUI
import PhotosUI
import SwiftUI

/// One actor session, drawn as the web draws it: what the user said in accent
/// bubbles on the trailing edge, their images over them; the actor's words
/// flat across the column, the tools it ran as quiet lines that say how
/// long each took and open what they did, and its requests as cards, each
/// answerable until answered or the session stops going on; the actor's images
/// under its message. It draws the latest page of messages, and earlier
/// pages as they're asked for. At the foot, a glass Follow Up button opens
/// the composer, a half-height sheet that says what to do next,
/// with any photos, while the actor's client is online, even while it
/// works; its bottom bar holds how full the context is and the plan's
/// limits and the mode on its own glass. How full the context is also
/// floats before the capsule, and Stop after it while the session is going
/// on. The header
/// names the session and where its actor works. Opening it,
/// and any stretch of work finishing while it's open, marks it read.
public struct ActorSessionView: View {
    let sessionID: Int
    /// Every actor offered, which names the session's.
    let actors: [Actor]
    /// Every client, which says whether the actor's is online, and its name.
    let clients: [Client]

    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    /// Whether the session was pushed, so there's somewhere to go back to.
    @Environment(\.isPresented) private var isPresented

    @State private var session: ActorSession?
    @State private var transcript = Transcript()
    /// The id of the earliest message drawn, a page from the end when the
    /// transcript first loads; `nil` until it holds a message shown.
    @State private var shownFrom: Int?
    /// Whether cohesiond says there's no such session.
    @State private var isMissing = false
    /// Whether the session couldn't be loaded, with nothing to show of it.
    @State private var didFailToLoad = false
    @State private var draft = ""
    /// Photos to send with the next message.
    @State private var images: [AttachmentUpload] = []
    /// The images of the messages that have some, by message, as they load.
    @State private var attachments: [Int: [PlatformImage]] = [:]
    /// How much of its plan the session's actor's pool has used, when a client says.
    @State private var usage: ActorUsage?
    /// Counts sends, giving the field a new identity each time, as the
    /// agent's chat does, so it doesn't keep drawing what was sent.
    @State private var sends = 0
    @State private var isConfirmingStop = false
    @State private var toast: Toast?
    /// Count loads started, so one that finishes after a newer one has
    /// begun leaves the session, or the transcript, to it.
    @State private var sessionLoads = 0
    @State private var messageLoads = 0
    @State private var position = ScrollPosition(edge: .bottom)
    /// What keeping to the end tracks from one scroll frame to the next.
    @State private var following = ScrollFollowing()
    /// The transcript column's width, which bubbles and cards take a share of.
    @State private var columnWidth: CGFloat = 0
    /// Whether the composer's sheet is up.
    @State private var isComposing = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    public init(sessionID: Int, actors: [Actor], clients: [Client]) {
        self.sessionID = sessionID
        self.actors = actors
        self.clients = clients
    }

    public var body: some View {
        Group {
            if let session {
                transcript(of: session)
            } else if isMissing {
                ContentUnavailableView {
                    Label("Session not found.", systemImage: "questionmark.circle")
                } actions: {
                    if isPresented {
                        Button("Back to actors") { dismiss() }
                    }
                }
            } else if didFailToLoad {
                ContentUnavailableView {
                    Label("Couldn’t Load Session", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("Try Again") {
                        didFailToLoad = false
                        Task { await load() }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(session?.title ?? "Actors")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let session {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text(barTitle(session.title))
                            .font(.headline)
                            .lineLimit(1)
                            .accessibilityLabel(session.title)
                        if let actor {
                            ActorPlace(actor: actor)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .confirmsStop(session, isPresented: $isConfirmingStop, stop: stop)
        .task { await watchSession() }
        .task { await watchMessages() }
        .onChange(of: scenePhase) { _, phase in
            // The actor may have moved on while the app was away.
            if phase == .active { Task { await load() } }
        }
        .toast(shown($toast, inSheet: false))
    }

    /// How many characters of its title a pushed session's bar shows.
    private static let barTitleLength = 26

    /// `title` as the bar shows it: cut short when the session was pushed on
    /// a phone, since the back button pushes a long title, and the actor's
    /// place under it, off centre. A regular width has room for it.
    private func barTitle(_ title: String) -> String {
        guard isPresented, sizeClass != .regular, title.count > Self.barTitleLength else { return title }
        return "\(title.prefix(Self.barTitleLength))…"
    }

    /// `binding` where it shows: the composer's sheet while it's up, else
    /// the screen, so a toast shows once, on top.
    private func shown<Value>(_ binding: Binding<Value?>, inSheet: Bool) -> Binding<Value?> {
        Binding { isComposing == inSheet ? binding.wrappedValue : nil } set: { binding.wrappedValue = $0 }
    }

    /// The session's actor, unless no client offers it any longer.
    private var actor: Actor? {
        actors.first { $0.id == session?.actorID }
    }

    private var actorClient: Client? {
        guard let actor else { return nil }
        return clients.first { $0.id == actor.clientID }
    }

    private var isOnline: Bool { actorClient?.online ?? false }

    // MARK: Transcript

    /// How many messages a page holds, as the agent chat's does.
    private static let page = 100

    /// The messages drawn: those shown from `shownFrom` on.
    private var window: ArraySlice<ActorSessionMessage> {
        let shown = transcript.shown
        guard let shownFrom else { return shown[...] }
        return shown[(shown.firstIndex { $0.id >= shownFrom } ?? shown.endIndex)...]
    }

    private func transcript(of session: ActorSession) -> some View {
        let window = window
        return ScrollView {
            // Not lazy, as the agent chat's feed isn't: a lazy stack guesses
            // the height of rows it hasn't laid out, which throws off
            // keeping to the end. A page at a time keeps measuring them cheap.
            VStack(alignment: .leading, spacing: 0) {
                if window.startIndex > 0 {
                    Button("Load earlier messages", action: showEarlier)
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 24)
                }
                ForEach(Array(window.enumerated()), id: \.element.id) { offset, message in
                    item(message, in: session)
                        .padding(.top, offset == 0 ? 0 : gap(between: window[window.startIndex + offset - 1], and: message))
                }
                if session.status == .working {
                    WorkingIndicator()
                        .padding(.top, 20)
                        .transition(.rise)
                }
            }
            .animation(.default, value: session.status == .working)
            .frame(maxWidth: conversationColumnWidth, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { columnWidth = $0 }
            .padding(.horizontal)
            .padding(.top)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition($position)
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .onScrollPhaseChange { _, phase in
            following.isScrolling = phase == .tracking || phase == .interacting || phase == .decelerating
            if following.isScrolling { following.keptFromEnd = nil }
        }
        .onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
            ScrollMetrics(
                // From the content's top, as `ScrollPosition` measures it.
                offset: geometry.contentOffset.y + geometry.contentInsets.top,
                fromEnd: geometry.contentSize.height + geometry.contentInsets.bottom
                    - geometry.containerSize.height - geometry.contentOffset.y,
                contentHeight: geometry.contentSize.height,
                viewportHeight: geometry.containerSize.height
            )
        } action: { old, new in
            following.metrics = new
            follow(from: old, to: new)
        }
        .scrollDismissesKeyboard(.interactively)
        // A bar, so the transcript blurs out under the foot's glass.
        .safeAreaBar(edge: .bottom, spacing: 24) { foot(of: session) }
        // Text fades out under the bar and the foot, as the agent chat's does.
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .sizedSheet(isPresented: $isComposing) { composer(of: session) }
    }

    /// The space between two messages shown one after the other: none
    /// between tools, more between the user and the actor than within one.
    private func gap(between previous: ActorSessionMessage, and current: ActorSessionMessage) -> CGFloat {
        if previous.isToolUse && current.isToolUse { return 0 }
        return previous.isUser != current.isUser ? 28 : 14
    }

    /// Draws the page before the earliest message drawn above it, keeping
    /// what's on screen where it was, and fetches the page's images.
    private func showEarlier() {
        let window = window
        guard window.startIndex > 0 else { return }
        shownFrom = transcript.shown[max(0, window.startIndex - Self.page)].id
        following.isFollowing = false
        following.keptFromEnd = following.metrics.fromEnd
        Task { await fetchAttachments() }
    }

    /// Keeps to the end as the transcript or the screen changes size while
    /// following, or as far from it as `keptFromEnd` says; scrolling up
    /// stops following, and coming back within 48 points of the end starts
    /// it again.
    private func follow(from old: ScrollMetrics, to new: ScrollMetrics) {
        if let keptFromEnd = following.keptFromEnd {
            // What grew above the viewport pushes it down by as much.
            if new.fromEnd != keptFromEnd { position.scrollTo(y: new.offset + new.fromEnd - keptFromEnd) }
        } else if following.isFollowing && (new.contentHeight != old.contentHeight || new.viewportHeight != old.viewportHeight) {
            position.scrollTo(edge: .bottom)
        } else if new.fromEnd <= 48 {
            following.isFollowing = true
        } else if following.isScrolling && new.offset < old.offset {
            following.isFollowing = false
        }
    }

    /// The widest a bubble or card gets: most of the column, or all of it
    /// on a phone.
    private var bubbleWidth: CGFloat {
        guard columnWidth > 0 else { return .infinity }
        return columnWidth < 600 ? columnWidth : columnWidth * 0.7
    }

    @ViewBuilder
    private func item(_ message: ActorSessionMessage, in session: ActorSession) -> some View {
        switch message.content {
        case .user(.permission(_, let decision, nil)):
            // A decision with no note of the user's is the session's record,
            // not something they said: a line across it, not their bubble.
            Label(decisionWords(decision), systemImage: decision == .allow || decision == .allowForSession ? "checkmark.shield" : "xmark.shield")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        case .user(let content):
            VStack(alignment: .trailing, spacing: 6) {
                if message.attachmentCount > 0 {
                    ActorImages(images: attachments[message.id], count: message.attachmentCount, isUser: true)
                }
                Text(verbatim: userText(content))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .foregroundStyle(.white)
                    .background(.tint, in: .rect(cornerRadius: bubbleCornerRadius))
                    .textSelection(.enabled)
                    .frame(maxWidth: bubbleWidth, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        case .actor(let content):
            VStack(alignment: .leading, spacing: 6) {
                actorItem(content, of: message, in: session)
                if message.attachmentCount > 0 {
                    ActorImages(images: attachments[message.id], count: message.attachmentCount, isUser: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func actorItem(_ content: ActorMessageContent, of message: ActorSessionMessage, in session: ActorSession) -> some View {
        // A request is settled once answered, or once the session stopped going on.
        let isSettled = message.answered || !session.status.isGoing
        switch content {
        case .text(let text):
            ActorText(text: text)
        case .toolUse(let use):
            ActorToolRow(
                use: use,
                startedAt: message.sentAt,
                nextSentAt: transcript.nextSentAt[message.id],
                isRunning: session.status == .working && use.endedAt == nil
            )
        case .question(let questions):
            ActorQuestionCard(
                requestID: message.id,
                questions: questions,
                answers: transcript.answers[message.id],
                isSettled: isSettled,
                respond: { await say($0) }
            )
            // Settling shows the answers picked rather than what was being picked.
            .id("\(message.id)-\(isSettled)")
            .frame(maxWidth: bubbleWidth, alignment: .leading)
        case .permission(let request):
            ActorPermissionCard(requestID: message.id, request: request, isSettled: isSettled, respond: { await say($0) })
                .frame(maxWidth: bubbleWidth, alignment: .leading)
        case .plan(let plan):
            ActorPlanCard(requestID: message.id, plan: plan, isSettled: isSettled, respond: { await say($0) })
                .frame(maxWidth: bubbleWidth, alignment: .leading)
        case .unknown:
            EmptyView()
        }
    }

    // MARK: Foot

    /// The capsule that opens the composer, "Follow up…" (or why it can't),
    /// with how many photos wait to go but never the draft; the context
    /// ring before it, and Stop after it while the session is going on.
    private func foot(of session: ActorSession) -> some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                usageButton(of: session, isFloating: true)
                Button {
                    isComposing = true
                } label: {
                    HStack(spacing: 8) {
                        Text(placeholder)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !images.isEmpty {
                            Label("\(images.count)", systemImage: "photo")
                                .labelStyle(.titleAndIcon)
                                .font(.subheadline)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                .contentShape(.hoverEffect, .capsule)
                .hoverEffect(.highlight)
                .accessibilityLabel(placeholder)
                .accessibilityHint(images.isEmpty ? "" : "\(images.count) images attached")
                if session.status.isGoing {
                    Button {
                        isConfirmingStop = true
                    } label: {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(.red)
                            .frame(width: 22, height: 22)
                            .padding(11)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .contentShape(.hoverEffect, .circle)
                    .hoverEffect(.highlight)
                    .accessibilityLabel("Stop")
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.smooth, value: session.status.isGoing)
        .frame(maxWidth: conversationColumnWidth)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }

    /// The composer's half-height sheet, which leaves the transcript under
    /// it to scroll and its requests to answer. Closing it keeps the draft;
    /// sending closes it.
    private func composer(of session: ActorSession) -> some View {
        NavigationStack {
            ActorComposer(
                placeholder: placeholder,
                text: $draft,
                images: $images,
                fieldID: sends,
                isDisabled: isComposerDisabled,
                canSend: canSend,
                send: {
                    send()
                    isComposing = false
                },
                attach: { items in Task { await attach(items) } },
                sketchThread: model.pairing.map { SketchThread(server: $0.serverFingerprint, kind: .actorSession(sessionID)) }
            ) {
                usageButton(of: session, isFloating: false)
            } options: {
                if let actor, actor.modes.count > 1 {
                    modeChip(of: session, on: actor)
                }
            }
            .navigationTitle(session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", role: .close) { isComposing = false }
                }
            }
            .toast(shown($toast, inSheet: true))
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }

    /// The context ring, or the plan's gauge, opening the session's context
    /// and its actor's account's plan limits; only once a client says either.
    @ViewBuilder
    private func usageButton(of session: ActorSession, isFloating: Bool) -> some View {
        if session.context != nil || usage?.plan.isEmpty == false {
            ActorUsageButton(
                context: session.context,
                plan: usage?.plan ?? [],
                account: usage?.pool?.name,
                isFloating: isFloating
            )
        }
    }

    private var placeholder: String {
        guard let actor else { return "Its actor is no longer offered." }
        guard isOnline else { return "\(actor.title) is offline." }
        return "Follow up…"
    }

    /// Only an actor no longer offered, or offline, keeps the user from
    /// saying more; a session at work takes more at any time.
    private var isComposerDisabled: Bool { actor == nil || !isOnline }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The session's mode, opening the actor's to switch to from the next step
    /// on, even while it works.
    private func modeChip(of session: ActorSession, on actor: Actor) -> some View {
        let current = session.mode ?? actor.modes[0].identifier
        return Menu {
            Picker("Mode", selection: Binding {
                current
            } set: { mode in
                if mode != current { setMode(mode) }
            }) {
                ForEach(actor.modes, id: \.identifier) { mode in
                    VStack {
                        Text(mode.title)
                        if let description = mode.description {
                            Text(description)
                        }
                    }
                    .tag(mode.identifier)
                }
            }
            .pickerStyle(.inline)
        } label: {
            ComposerChipLabel(
                title: actor.modes.first { $0.identifier == current }?.title ?? current
            )
        }
        .buttonBorderShape(.capsule)
        .disabled(!isOnline)
    }

    // MARK: Loading

    /// Loads the session, then reloads it, with its actor's plan usage,
    /// whenever cohesiond reports a session or plan usage changed.
    private func watchSession() async {
        guard let client = model.client else { return }
        await loadSession()
        for await _ in client.changes(matching: { $0 == .actorSessions || $0 == .actorUsage }) {
            await loadSession()
        }
    }

    /// Loads what was said in the session, then reloads it only when
    /// cohesiond reports this session or a message in its transcript
    /// changed: a long one is the most there is to fetch, and other sessions
    /// change often while their actors work.
    private func watchMessages() async {
        guard let client = model.client else { return }
        await loadMessages()
        for await _ in client.changes(matching: { [sessionID] in
            switch $0 {
            case .actorSession(sessionID), .actorSessionMessage(sessionID, _): true
            default: false
            }
        }) {
            await loadMessages()
        }
    }

    private func load() async {
        async let session: Void = loadSession()
        async let messages: Void = loadMessages()
        _ = await (session, messages)
    }

    private func loadSession() async {
        guard let client = model.client else { return }
        sessionLoads += 1
        let load = sessionLoads
        // Asked for or not, a failure never alerts here: the transcript stays
        // as it is, and with nothing to show the screen offers to try again.
        await LoadOrigin.asked.run {
            do {
                async let session = client.actorSession(sessionID)
                // An older cohesiond, or a client that never says, leaves no usage.
                async let usage = try? client.listActorUsage()
                let loadedSession = try await session
                let loadedUsage = await usage
                guard load == sessionLoads else { return }
                self.session = loadedSession
                // The plan is its actor's pool's, shared with the actors on its account.
                self.usage = loadedUsage?.first { $0.actorIDs.contains(loadedSession.actorID) }
                isMissing = false
                didFailToLoad = false
                // What the actor finishes while the session is shown is read.
                if loadedSession.isUnread { markRead(loadedSession) }
            } catch let error as ServerError where error.code == ServerError.notFound {
                guard load == sessionLoads else { return }
                session = nil
                isMissing = true
            }
        } failed: { _ in
            if load == sessionLoads, session == nil { didFailToLoad = true }
        }
    }

    private func loadMessages() async {
        guard let client = model.client else { return }
        messageLoads += 1
        let load = messageLoads
        await LoadOrigin.automatic.run {
            do {
                let loaded = Transcript(try await client.listMessages(ofActorSession: sessionID))
                guard load == messageLoads else { return }
                transcript = loaded
                if shownFrom == nil {
                    shownFrom = loaded.shown.suffix(Self.page).first?.id
                }
                await fetchAttachments()
            } catch let error as ServerError where error.code == ServerError.notFound {
                // `loadSession` says the session is gone.
            }
        }
    }

    /// Fetches the images of the messages drawn that have some not yet
    /// fetched. A failed fetch leaves grey squares, tried again on the next
    /// load.
    private func fetchAttachments() async {
        guard let client = model.client else { return }
        for message in window where message.attachmentCount > 0 && attachments[message.id] == nil {
            if let fetched = try? await client.attachments(ofActorSessionMessage: message) {
                attachments[message.id] = fetched.compactMap(\.image)
            }
        }
    }

    /// Marks the session read here at once, then with cohesiond.
    private func markRead(_ session: ActorSession) {
        guard let client = model.client else { return }
        self.session?.isUnread = false
        self.session?.readAt = .now
        // Nothing asked for it; a failure leaves it for the next load.
        Task { try? await client.markRead(session) }
    }

    // MARK: Saying

    /// Says `content` in the session, with `images`, then shows it; `false`,
    /// with the error shown, when cohesiond or the actor refused it.
    private func say(_ content: ActorUserContent, images: [AttachmentUpload] = []) async -> Bool {
        guard let client = model.client else { return false }
        do {
            let said = try await client.say(content, images: images, in: sessionID)
            // The photos already on screen stand in for fetching them back.
            if !images.isEmpty { attachments[said.id] = images.map(\.preview) }
            transcript.add(said)
            if shownFrom == nil { shownFrom = said.id }
            following.isFollowing = true
            position.scrollTo(edge: .bottom)
            await load()
            return true
        } catch {
            toast = .error(error)
            return false
        }
    }

    /// Sends the field as typed, clearing it at once; what didn't send
    /// comes back to edit.
    private func send() {
        guard !isComposerDisabled && canSend else { return }
        let text = draft
        let uploads = images
        draft = ""
        images = []
        // The new field takes the place of one that may still draw what was sent.
        sends += 1
        following.isFollowing = true
        Task {
            if await !say(.text(text), images: uploads) {
                if draft.isEmpty { draft = text }
                images = uploads + images
            }
        }
    }

    private func attach(_ items: [PhotosPickerItem]) async {
        let (loaded, failed) = await AttachmentUpload.loadAll(items)
        let room = max(0, AttachmentUpload.limit - images.count)
        images.append(contentsOf: loaded.prefix(room))
        if loaded.count > room {
            toast = .error("A message can have up to 10 images.")
        } else if failed {
            toast = .error("That file isn’t an image that can be attached.")
        }
    }

    private func setMode(_ mode: String) {
        guard let client = model.client, let session else { return }
        Task {
            do {
                self.session = try await client.setMode(mode, of: session)
            } catch {
                toast = .error(error)
            }
        }
    }

    private func stop() {
        guard let client = model.client, let session else { return }
        Task {
            do {
                self.session = try await client.stop(session)
            } catch {
                toast = .error(error)
            }
        }
    }
}

/// Where the transcript is scrolled to, and how big it and its viewport are.
private struct ScrollMetrics: Equatable {
    let offset: CGFloat
    /// How far the end of the transcript is below the viewport's.
    let fromEnd: CGFloat
    let contentHeight: CGFloat
    let viewportHeight: CGFloat
}

/// What keeping a transcript to its end tracks as it scrolls. A class that
/// isn't observed, so updating it on every frame of a scroll redraws
/// nothing: written as the view's state, each frame dirtied the whole
/// transcript, and its tables most of all.
private final class ScrollFollowing {
    /// Where the transcript is scrolled to, as last measured.
    var metrics = ScrollMetrics(offset: 0, fromEnd: 0, contentHeight: 0, viewportHeight: 0)
    /// Whether the transcript keeps to its end as it grows.
    var isFollowing = true
    /// Whether the user is moving the transcript, rather than it growing.
    var isScrolling = false
    /// How far the end was below the viewport when an earlier page was
    /// drawn, which the transcript keeps to as that page lays out and its
    /// diagrams draw, until the user scrolls again.
    var keptFromEnd: CGFloat?
}

/// What was said in a session, oldest first, with what drawing it takes worked
/// out once a change rather than once a redraw: the screen redraws on every
/// keystroke in the composer, and a long session runs to thousands of messages.
private struct Transcript {
    private(set) var messages: [ActorSessionMessage]
    /// The messages the transcript draws.
    private(set) var shown: [ActorSessionMessage] = []
    /// When the message after each tool use came, by the tool use's id,
    /// which ends a tool its actor never said ended.
    private(set) var nextSentAt: [Int: Date] = [:]
    /// What the user answered each question with, one per question, by the
    /// question's id.
    private(set) var answers: [Int: [ActorAnswer]] = [:]

    init(_ messages: [ActorSessionMessage] = []) {
        self.messages = messages
        derive()
    }

    /// Adds what the user just said, unless a load already brought it in,
    /// marking the request it responds to answered.
    mutating func add(_ said: ActorSessionMessage) {
        if !messages.contains(where: { $0.id == said.id }) { messages.append(said) }
        if case .user(let content) = said.content, let requestID = content.requestID,
           let index = messages.firstIndex(where: { $0.id == requestID }) {
            messages[index].answered = true
        }
        derive()
    }

    private mutating func derive() {
        shown = messages.filter(\.isShown)
        nextSentAt = [:]
        answers = [:]
        for (index, message) in messages.enumerated() {
            if message.isToolUse && index + 1 < messages.count {
                nextSentAt[message.id] = messages[index + 1].sentAt
            }
            if case .user(.answers(let requestID, let answered)) = message.content {
                answers[requestID] = answered
            }
        }
    }
}

/// The actor's words, set for reading at length. A view of its own, so the
/// Markdown is read again only when the text changes, not on every redraw
/// of the transcript.
private struct ActorText: View {
    let text: String

    var body: some View {
        MarkdownText(markdown: text, style: .transcript, diagrams: true)
    }
}

/// A permission decision, as the transcript records it.
private func decisionWords(_ decision: ActorPermissionDecision) -> String {
    switch decision {
    case .allow: "Allowed"
    case .allowForSession: "Allowed for this session"
    case .deny: "Denied"
    case .abort: "Denied, and asked it to stop"
    }
}

/// What the user said, as their bubble shows it.
private func userText(_ content: ActorUserContent) -> String {
    switch content {
    case .text(let text):
        return text
    case .answers(_, let answers):
        return answers
            .map { ($0.selected + [$0.other].compactMap(\.self)).joined(separator: ", ") }
            .joined(separator: "\n")
    case .permission(_, let decision, let message):
        let decided = decisionWords(decision)
        return message.map { "\(decided): \($0)" } ?? "\(decided)."
    case .plan(_, let approved, let feedback):
        if approved { return "Approved the plan." }
        return feedback.map { "Asked for changes: \($0)" } ?? "Asked for changes."
    case .unknown:
        return ""
    }
}

private extension ActorSessionMessage {
    /// Whether the user said it, which puts it, and its images, on the trailing edge.
    var isUser: Bool {
        if case .user = content { return true }
        return false
    }

    var isToolUse: Bool {
        if case .actor(.toolUse) = content { return true }
        return false
    }

    /// Whether the transcript draws it: answers show in the question card
    /// they answer, and kinds newer than this build don't show.
    var isShown: Bool {
        switch content {
        case .user(.answers), .user(.unknown), .actor(.unknown): false
        default: true
        }
    }
}

/// The images that came with a message: on the trailing edge for the
/// user's, the leading edge for the actor's, wrapping; grey squares until
/// they load. Tapping one opens it.
private struct ActorImages: View {
    /// `nil` while they load.
    let images: [PlatformImage]?
    let count: Int
    let isUser: Bool

    @State private var shown: ShownImage?

    var body: some View {
        FlowLayout(alignment: isUser ? .trailing : .leading) {
            if let images {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    Button {
                        shown = ShownImage(image: image)
                    } label: {
                        thumbnail(image)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isUser ? "Attached image \(index + 1)" : "Image \(index + 1)")
                }
            } else {
                ForEach(0..<count, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.fill.tertiary)
                        .frame(width: 128, height: 128)
                }
            }
        }
        .fullScreenCover(item: $shown) { shown in
            ImageViewer(image: shown.image)
        }
    }

    /// At most 240 points a side, keeping its shape.
    private func thumbnail(_ image: PlatformImage) -> some View {
        let scale = min(1, 240 / max(image.size.width, image.size.height, 1))
        return Image(platformImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: image.size.width * scale, height: image.size.height * scale)
            .clipShape(.rect(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(.separator, lineWidth: 0.5) }
    }
}

/// A tool the actor ran, as a quiet line: its name and what it did, then
/// how long it took, counting up while it runs and after a checkmark once
/// done. Tapping it opens `ActorToolSheet`.
private struct ActorToolRow: View {
    let use: ActorToolUse
    let startedAt: Date
    /// When the next message came, which ends a tool its actor never said ended.
    let nextSentAt: Date?
    let isRunning: Bool

    @State private var isShowingDetail = false

    var body: some View {
        Button {
            isShowingDetail = true
        } label: {
            if isRunning {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    row(now: timeline.date)
                }
            } else {
                row(now: .now)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows what it did.")
        .sizedSheet(isPresented: $isShowingDetail) {
            ActorToolSheet(use: use, startedAt: startedAt, nextSentAt: nextSentAt, isRunning: isRunning)
        }
    }

    private func row(now: Date) -> some View {
        HStack(spacing: 6) {
            Text(use.tool)
                .fontWeight(.semibold)
            Text(use.summary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let took = use.took(from: startedAt, nextSentAt: nextSentAt, isRunning: isRunning, now: now) {
                HStack(spacing: 3) {
                    if !isRunning {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .accessibilityLabel("Done")
                    }
                    Text(elapsed(took))
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityElement(children: .combine)
                .accessibilityValue(isRunning ? "Running" : "")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
        .contentShape(.rect)
    }
}

/// A tool the actor ran, opened from its line: what it did in full, when it
/// started and how long it took, counting up while it runs.
private struct ActorToolSheet: View {
    let use: ActorToolUse
    let startedAt: Date
    let nextSentAt: Date?
    let isRunning: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !use.summary.isEmpty {
                    Section {
                        Text(verbatim: use.summary)
                            .textSelection(.enabled)
                    }
                }
                Section {
                    LabeledContent("Started") {
                        Text(startedAt, format: .dateTime.month().day().hour().minute().second())
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        if let took = use.took(from: startedAt, nextSentAt: nextSentAt, isRunning: isRunning, now: timeline.date) {
                            LabeledContent(isRunning ? "Running for" : "Took", value: elapsed(took))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle(use.tool)
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

private extension ActorToolUse {
    /// How long it took by cohesiond's clock, from `startedAt`: to its end,
    /// to `now` while it runs, or else to `nextSentAt`; `nil` for the last
    /// message.
    func took(from startedAt: Date, nextSentAt: Date?, isRunning: Bool, now: Date) -> TimeInterval? {
        if let endedAt { return endedAt.timeIntervalSince(startedAt) }
        if isRunning { return now.timeIntervalSince(startedAt) }
        return nextSentAt.map { $0.timeIntervalSince(startedAt) }
    }
}

/// "<1s", "45s", "3m 12s", "1h 5m".
private func elapsed(_ interval: TimeInterval) -> String {
    let seconds = Int(max(interval, 0))
    switch seconds {
    case ..<1: return "<1s"
    case ..<60: return "\(seconds)s"
    case ..<3_600: return "\(seconds / 60)m \(seconds % 60)s"
    default: return "\(seconds / 3_600)h \(seconds % 3_600 / 60)m"
    }
}

private extension View {
    /// Asks before stopping `session`.
    func confirmsStop(_ session: ActorSession?, isPresented: Binding<Bool>, stop: @escaping () -> Void) -> some View {
        confirmationDialog(
            "Stop “\(session?.title ?? "")”?",
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            Button("Stop", role: .destructive, action: stop)
        } message: {
            Text("Its actor stops what it’s doing. Send a message to pick it back up.")
        }
    }
}
