import CohesionCore
import CohesionUI
import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
    /// Lets the `ForwardMenu`s in this view forward their item: picking an
    /// agent opens `ForwardComposer` in a sheet over it, and a toast says
    /// when it went. A sheet presents only from the topmost one, so a view
    /// shown in a sheet applies this itself.
    func forwardsItems() -> some View {
        modifier(ForwardsItems())
    }
}

/// A forward being written: the agent picked in a `ForwardMenu`, and the item.
struct ForwardDraft: Identifiable {
    let agent: Agent
    let item: AgentForwardedItem

    var id: String { "\(agent.id)-\(item.kind)-\(item.id)" }
}

extension EnvironmentValues {
    /// Every agent, which a `ForwardMenu` lists.
    @Entry var agents: [Agent] = []
    /// Opens the composer on a forward; `nil` where `forwardsItems()`
    /// isn't applied, which hides `ForwardMenu`.
    @Entry var forward: ForwardAction?
}

/// What `forwardsItems()` puts in the environment: opening its composer.
struct ForwardAction {
    fileprivate let open: (ForwardDraft) -> Void

    func callAsFunction(_ draft: ForwardDraft) {
        open(draft)
    }
}

private struct ForwardsItems: ViewModifier {
    @State private var draft: ForwardDraft?
    @State private var notice: Toast?

    func body(content: Content) -> some View {
        content
            .environment(\.forward, ForwardAction { draft = $0 })
            .sizedSheet(item: $draft) { draft in
                ForwardComposer(draft: draft) {
                    notice = Toast(kind: .info, message: "Forwarded “\(draft.item.shownTitle)” to \(draft.agent.name).")
                }
            }
            .toast($notice)
    }
}

/// "Forward" in an item's menu: a submenu of the agents, each opening the
/// composer on `item`, as the web's "Forward" menu does.
struct ForwardMenu: View {
    let item: AgentForwardedItem

    @Environment(\.agents) private var agents
    @Environment(\.forward) private var forward
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        if let forward {
            Menu("Forward", systemImage: "arrowshape.turn.up.right") {
                ForEach(agents) { agent in
                    Button {
                        forward(ForwardDraft(agent: agent, item: item))
                    } label: {
                        Label { Text(agent.name) } icon: { AgentAvatar.menuImage(of: agent, scale: displayScale) }
                    }
                }
            }
            .disabled(agents.isEmpty)
        }
    }
}

/// A forwarded item as a chip of its own: its kind's icon on a tile, the
/// title, then `Task #42` quietly. In an agent's chat, tapping it opens the
/// item as its `cohesion://` link does.
struct ForwardChip: View {
    let item: AgentForwardedItem
    /// Opens the item; without it the chip is only shown.
    var open: (() -> Void)?

    var body: some View {
        if let open {
            Button(action: open) { chip }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the \(item.kindName.lowercased())")
        } else {
            chip
        }
    }

    private var chip: some View {
        HStack(spacing: 8) {
            Image(systemName: item.kind.symbol)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(.background, in: .rect(cornerRadius: 8))
            Text(item.shownTitle)
                .fontWeight(.medium)
                .lineLimit(1)
            Text(item.kindLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .padding(.leading, 4)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .background(Color.receivedBubble, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).strokeBorder(.separator)
        }
        .accessibilityElement(children: .combine)
    }
}

extension AgentForwardedItem {
    /// The link the item opens as.
    var link: AppLink {
        switch kind {
        case .task: .task(id, workspaceID: workspaceID)
        case .document, .journal: .document(id, workspaceID: workspaceID)
        }
    }

    /// The title as the app shows it: a journal entry's day in words, as
    /// the journal titles it.
    var shownTitle: String {
        guard kind == .journal, let day = CalendarDay.date(title) else { return title }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var kindName: String {
        switch kind {
        case .task: "Task"
        case .document: "Document"
        case .journal: "Journal entry"
        }
    }

    /// The chip's quiet half: `Task #42`, with the id the app copies, or
    /// `Document`.
    var kindLabel: String {
        kind == .task ? "\(kindName) #\(id)" : kindName
    }
}

/// The sheet "Forward" opens: the agent, the item and an optional note.
/// The agent gets the note and the item's link, which it reads with its
/// code tool. A failure shows here, with the note kept.
private struct ForwardComposer: View {
    let draft: ForwardDraft
    /// Called once cohesiond has the forward, as the sheet closes.
    let onSent: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var note = ""
    @State private var isSending = false
    @State private var error: (any Error)?
    @FocusState private var isWriting: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                ForwardChip(item: draft.item)
                TextField("Add a note…", text: $note, axis: .vertical)
                    .lineLimit(4...10)
                    .focused($isWriting)
                    .padding(12)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 12))
                Spacer(minLength: 0)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        AgentAvatar(agent: draft.agent, diameter: 24)
                        Text("Forward to \(draft.agent.name)")
                            .font(.headline)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                        .disabled(isSending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Forward", systemImage: "checkmark", role: .confirm, action: send)
                        .disabled(isSending)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isSending)
        .onAppear { isWriting = true }
        .errorAlert($error)
    }

    private func send() {
        guard let client = model.client else { return }
        isSending = true
        Task {
            do {
                try await client.send(
                    note.trimmingCharacters(in: .whitespacesAndNewlines),
                    forwarding: draft.item,
                    to: draft.agent.id
                )
                #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
                onSent()
                dismiss()
            } catch {
                self.error = error
            }
            isSending = false
        }
    }
}
