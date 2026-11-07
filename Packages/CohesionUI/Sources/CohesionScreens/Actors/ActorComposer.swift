import CohesionCore
import CohesionUI
import PhotosUI
import SwiftUI

/// What an actor session is written in, new or going on: the content of a
/// half-height sheet's navigation stack, whose glass the field sits on,
/// with the images to send over it and why the last send failed under it.
/// The toolbar holds the rest: the send button as the sheet's confirming
/// action, and along the bottom (on iPad, a strip in the bottom safe area) the attach menu (paste, photos, and on iPad
/// the thread's sketch), `controls` (chips such as the actor or the context
/// ring) sharing one glass surface, `options` (the mode, model and effort)
/// on a surface of their own.
/// The field takes the keyboard as the sheet opens. The caller adds the
/// title and the leading action.
struct ActorComposer<Controls: View, Options: View>: View {
    let placeholder: String
    @Binding var text: String
    @Binding var images: [AttachmentUpload]
    /// A new value gives the field a new identity, so it doesn't keep
    /// drawing what was sent.
    var fieldID = 0
    /// Whether the field, attach button and send button are off, such as
    /// while the actor's client is offline; `controls` decide their own.
    let isDisabled: Bool
    /// Whether there's something to send, beyond `isDisabled`.
    let canSend: Bool
    /// Whether what was sent is on its way, which the send button shows.
    var isSending = false
    /// What the send button says: "Send", "Start".
    var sendLabel = "Send"
    /// Why the last send failed, under the field until the next.
    var failure: String?
    let send: () -> Void
    let attach: ([PhotosPickerItem]) -> Void
    /// Where the attach menu's sketch is kept; `nil` for a session not started yet.
    var sketchThread: SketchThread?
    @ViewBuilder let controls: Controls
    @ViewBuilder let options: Options

    @FocusState private var isFocused: Bool
    @State private var attachPresentation = AttachPresentation()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !images.isEmpty {
                    DraftImages(images: $images)
                        .padding(.horizontal, 8)
                        .transition(.opacity)
                }
                TextField(placeholder, text: $text, axis: .vertical)
                    .focused($isFocused)
                    .onSubmit {
                        if !isDisabled && canSend && !isSending { send() }
                    }
                    .id(fieldID)
                    .disabled(isDisabled)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .accessibilityLabel("Message")
                if let failure {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                        Text(failure)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 20)
                    .accessibilityElement(children: .combine)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Anywhere on the sheet's paper puts the cursor in the field.
        .contentShape(.rect)
        .onTapGesture { isFocused = true }
        .animation(reduceMotion ? nil : .smooth, value: images.count)
        .animation(reduceMotion ? nil : .smooth, value: failure)
        .onAppear { isFocused = true }
        .attachPresenter($attachPresentation, images: $images, sketchThread: sketchThread, attach: attach)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSending {
                    ProgressView()
                } else {
                    Button(sendLabel, systemImage: "arrow.up", role: .confirm, action: send)
                        .disabled(isDisabled || !canSend)
                }
            }
            #if os(iOS)
            if !stripOnTop {
                ToolbarItem(placement: .bottomBar) {
                    AttachMenu(images: $images, sketchThread: sketchThread, presentation: $attachPresentation) {
                        Label("Attach Images", systemImage: "photo.on.rectangle")
                    }
                    .disabled(isDisabled)
                }
                // It stays out of the overflow menu, whatever else the bar holds.
                .visibilityPriority(.high)
                ToolbarSpacer(.fixed, placement: .bottomBar)
                ToolbarItemGroup(placement: .bottomBar) { controls }
                ToolbarSpacer(.fixed, placement: .bottomBar)
                ToolbarItemGroup(placement: .bottomBar) { options }
            }
            #endif
        }
        #if os(macOS)
        // A Mac sheet's toolbar has no bottom bar, so the same controls are a
        // strip under the field.
        .safeAreaInset(edge: .bottom) { strip }
        #else
        .safeAreaInset(edge: .bottom) {
            if stripOnTop { strip }
        }
        #endif
    }

    /// Whether the controls are a strip in the bottom safe area rather than the
    /// bottom bar: on iPad, where the keyboard's shortcut bar floats over
    /// the sheet's bottom edge, which the toolbar doesn't avoid.
    private var stripOnTop: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

    private var strip: some View {
        HStack(spacing: 8) {
            AttachMenu(images: $images, sketchThread: sketchThread, presentation: $attachPresentation) {
                Label("Attach Images", systemImage: "photo.on.rectangle")
                    .labelStyle(.iconOnly)
            }
            #if os(macOS)
            .menuStyle(.borderlessButton)
            #endif
            .fixedSize()
            .disabled(isDisabled)
            controls
            Spacer()
            options
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

/// A chip in a composer's strip: what it picks, as a symbol where given,
/// its current choice, and a chevron saying it opens a menu.
struct ComposerChipLabel: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .imageScale(.small)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}
