import CohesionCore
import CohesionUI
import PhotosUI
import SwiftUI

/// The Dashboard's centrepiece, a message to an agent, on one sheet of glass:
/// a borderless field over a row with who it goes to (a menu of every agent)
/// at its leading edge and the chat's attach menu and send button at its
/// trailing edge, as one bar, the chat composer's look. The reply
/// waits in the agent's conversation, which `onSent`'s toast opens; a failed
/// send puts everything back. Apart from the Dashboard so typing redraws only
/// this.
struct DashboardComposer: View {
    /// Whether the field has the focus, which the page takes away to close the
    /// keyboard.
    @FocusState.Binding var isComposing: Bool
    /// Whether the message has wrapped past one line, which lifts the composer
    /// on iOS.
    @Binding var isPastOneLine: Bool
    let onSent: (Agent) -> Void

    @Environment(AppModel.self) private var model
    @Environment(WindowModel.self) private var window
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The agent picked here while it lasts, else the first in the list.
    @State private var chosenID: Int?
    @State private var draft = ""
    /// The images to send with `draft`.
    @State private var images: [AttachmentUpload] = []
    @State private var attachPresentation = AttachPresentation()
    /// Counts sends, giving the field a new identity each time: a focused
    /// field can keep drawing what was sent after `draft` empties.
    @State private var sends = 0
    /// Counts sends that landed, for the haptic.
    @State private var delivered = 0
    @State private var error: (any Error)?
    /// One line's height at the current text size, to measure the field by.
    @State private var lineHeight: CGFloat = 0
    @ScaledMetric(relativeTo: .subheadline) private var avatarDiameter = 20

    /// Pinned first, in their order, then the latest to talk, as the web
    /// orders the picker.
    private var agents: [Agent] {
        window.pinnedAgents + window.agents.filter { !$0.isPinned }.sorted {
            ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast)
        }
    }

    private var agent: Agent? {
        agents.first { $0.id == chosenID } ?? agents.first
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty
    }

    var body: some View {
        VStack(spacing: 14) {
            if let agent {
                glassSheet(agent)
            } else {
                Text("No agents yet.")
                    .foregroundStyle(.secondary)
                Button("New Agent") { window.isCreatingAgent = true }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            }
        }
        .frame(maxWidth: .infinity)
        // With no border, the sheet around the field is the field too, and so
        // is the gap under it; the controls keep their own taps.
        .contentShape(.rect)
        .onTapGesture { isComposing = true }
        .sensoryFeedback(.success, trigger: delivered)
        .errorAlert(window.errorHeldForSheets($error))
        #if os(macOS)
        // A Mac's keyboard is always there, and takes no room to come up.
        .onAppear { isComposing = true }
        #endif
    }

    /// Who the message goes to: a menu of every agent, so it holds however
    /// many there are.
    private func agentPicker(_ agent: Agent) -> some View {
        Menu {
            Picker("Agent", selection: Binding {
                agent.id
            } set: {
                chosenID = $0
                isComposing = true
            }) {
                ForEach(agents) { agent in
                    Label { Text(agent.name) } icon: { AgentAvatar.menuImage(of: agent, scale: displayScale) }
                        .tag(agent.id)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 6) {
                AgentAvatar(agent: agent, diameter: avatarDiameter)
                Text(agent.name)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(.rect)
        }
        // On the sheet's glass, so none of its own.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Agent")
        .accessibilityValue(agent.name)
    }

    /// The one sheet of glass: what's on it draws no glass of its own.
    private func glassSheet(_ agent: Agent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !images.isEmpty {
                DraftImages(images: $images)
                    .transition(.opacity)
            }
            TextField("Give \(agent.name) something to do…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused($isComposing)
                .onSubmit {
                    if canSend { send(to: agent) }
                }
                .id(sends)
                .accessibilityLabel("Message")
                .background {
                    Text(verbatim: "X")
                        .lineLimit(1)
                        .hidden()
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { lineHeight = $0 }
                }
                // Only a message's lines: the placeholder wraps at the largest
                // text sizes.
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
                    isPastOneLine = !draft.isEmpty && height > lineHeight * 1.5
                }
                .onChange(of: draft.isEmpty) {
                    if draft.isEmpty { isPastOneLine = false }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 6)
            HStack(spacing: 4) {
                agentPicker(agent).hidden()
                Spacer(minLength: 0)
                attachMenu.hidden()
                sendButton(to: agent)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
        // The menus above the glass rather than on it, in the places the row
        // leaves for them: interactive glass here takes the touches meant for
        // the part of an open menu that lies over it, so its items wouldn't run.
        .overlay(alignment: .bottom) {
            HStack(spacing: 4) {
                agentPicker(agent)
                Spacer(minLength: 0)
                attachMenu
                sendButton(to: agent).hidden()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .attachPresenter($attachPresentation, images: $images, sketchThread: nil, attach: attach)
    }

    private var attachMenu: some View {
        AttachMenu(images: $images, sketchThread: nil, presentation: $attachPresentation) {
            Image(systemName: "photo.on.rectangle")
                .frame(width: 22, height: 22)
                .padding(6)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .foregroundStyle(.secondary)
    }

    private func sendButton(to agent: Agent) -> some View {
        Button {
            send(to: agent)
        } label: {
            Image(systemName: "arrow.up")
                .fontWeight(.semibold)
                .frame(width: 22, height: 22)
                .symbolEffect(.bounce.up, value: reduceMotion ? 0 : sends)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .disabled(!canSend)
        .accessibilityLabel("Send")
    }

    private func attach(_ items: [PhotosPickerItem]) {
        Task {
            let loaded = await AttachmentUpload.load(items)
            withAnimation {
                images.append(contentsOf: loaded.prefix(max(0, AttachmentUpload.limit - images.count)))
            }
        }
    }

    private func send(to agent: Agent) {
        guard let client = model.client else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let uploads = images
        draft = ""
        images = []
        // The new field takes the focus once it's in, so the keyboard stays up.
        sends += 1
        if isComposing { DispatchQueue.main.async { isComposing = true } }
        Task {
            do {
                try await client.send(text, images: uploads, to: agent.id)
                delivered += 1
                onSent(agent)
            } catch {
                self.error = error
                draft = text
                images = uploads + images
            }
        }
    }
}
