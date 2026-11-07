import CohesionCore
import CohesionUI
import PhotosUI
import SwiftUI

/// A half-height sheet that hands an actor a new session, asking what it
/// should work on as the web's form does, in the composer: the field takes
/// the keyboard at once, with any photos and why the last start failed;
/// Start confirms; and the bottom bar holds the attach button, a chip that
/// picks the actor, and where it offers a choice, on its own glass, a
/// button whose menu picks the mode, the model and its effort. It starts on the actor, model and effort last
/// picked, while that actor's client is online, else on the first online
/// actor.
struct NewActorSessionView: View {
    let actors: [Actor]
    let clients: [Client]
    /// Opens the session once started.
    let started: (ActorSession) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var prompt = ""
    @State private var images: [AttachmentUpload] = []
    @State private var actorID: Int?
    /// The actor's mode; empty for none.
    @State private var mode = ""
    /// The model; empty for none.
    @State private var modelID = ""
    /// The model's effort; empty for its default.
    @State private var effort = ""
    @State private var isStarting = false
    /// Why the last start failed, under the field until the next.
    @State private var failure: String?
    @State private var toast: Toast?

    var body: some View {
        NavigationStack {
            ActorComposer(
                placeholder: placeholder,
                text: $prompt,
                images: $images,
                isDisabled: isDisabled,
                canSend: canStart,
                isSending: isStarting,
                sendLabel: "Start",
                failure: failure,
                send: start,
                attach: { items in Task { await attach(items) } }
            ) {
                actorChip
            } options: {
                if let actor, actor.modes.count > 1 || !actor.models.isEmpty {
                    settingsChip(of: actor)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
            .onAppear(perform: chooseActor)
            .onChange(of: actors.map(\.id)) { chooseActor() }
            .onChange(of: clients.map(\.online)) { chooseActor() }
            .onChange(of: failure) { _, failure in
                if let failure { AccessibilityNotification.Announcement(failure).post() }
            }
            .toast($toast)
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Chips

    private var actorChip: some View {
        Menu {
            Picker("Actor", selection: Binding {
                actorID
            } set: { id in
                guard let id, let picked = actors.first(where: { $0.id == id }) else { return }
                actorID = id
                settle(on: picked)
                remember()
            }) {
                ForEach(actors) { actor in
                    let online = isOnline(actor)
                    VStack {
                        Text(actor.scopeName)
                        Text(online ? actor.title : "\(actor.title), offline")
                    }
                    .tag(Optional(actor.id))
                    .disabled(!online)
                }
            }
            .pickerStyle(.inline)
        } label: {
            ComposerChipLabel(title: actor?.scopeName ?? "Choose an actor", systemImage: "folder")
        }
        .buttonBorderShape(.capsule)
    }

    /// A button that opens Mode, Model and Effort, each a submenu showing
    /// what's picked, where the actor (or for Effort, the picked model)
    /// offers a choice. Only VoiceOver reads what's picked off the button,
    /// which keeps the bar narrow enough for any phone.
    private func settingsChip(of actor: Actor) -> some View {
        Menu {
            if actor.modes.count > 1 {
                Picker(selection: $mode) {
                    ForEach(actor.modes, id: \.identifier) { option in
                        VStack {
                            Text(option.title)
                            if let description = option.description {
                                Text(description)
                            }
                        }
                        .tag(option.identifier)
                    }
                } label: {
                    Label("Mode", systemImage: "arrow.trianglehead.branch")
                }
                .pickerStyle(.menu)
            }
            if !actor.models.isEmpty {
                Picker(selection: Binding {
                    modelID
                } set: { picked in
                    modelID = picked
                    // Another model's efforts are its own.
                    if !efforts.contains(where: { $0.identifier == effort }) { effort = "" }
                    remember()
                }) {
                    ForEach(actor.models, id: \.identifier) { option in
                        Text(option.title).tag(option.identifier)
                    }
                } label: {
                    Label("Model", systemImage: "cpu")
                }
                .pickerStyle(.menu)
            }
            if !efforts.isEmpty {
                Picker(selection: Binding {
                    effort
                } set: { picked in
                    effort = picked
                    remember()
                }) {
                    Text("Default").tag("")
                    ForEach(efforts, id: \.identifier) { option in
                        Text(option.title).tag(option.identifier)
                    }
                } label: {
                    Label("Effort", systemImage: "brain")
                }
                .pickerStyle(.menu)
            }
        } label: {
            Label("Mode, Model and Effort", systemImage: "receipt")
                .labelStyle(.iconOnly)
        }
        .buttonBorderShape(.circle)
        .accessibilityValue(settingsLabel(of: actor))
    }

    /// What's picked, as offered, for VoiceOver: "Plan · Opus · High", "Opus",
    /// or "Choose a model".
    private func settingsLabel(of actor: Actor) -> String {
        var parts: [String] = []
        if actor.modes.count > 1 {
            parts.append(actor.modes.first { $0.identifier == mode }?.title ?? actor.modes[0].title)
        }
        if !actor.models.isEmpty {
            parts.append(modelLabel(of: actor))
        }
        return parts.joined(separator: " · ")
    }

    /// "Opus", "Opus · High", or "Choose a model".
    private func modelLabel(of actor: Actor) -> String {
        guard let picked = actor.models.first(where: { $0.identifier == modelID }) else { return "Choose a model" }
        guard let effort = picked.efforts.first(where: { $0.identifier == effort }) else { return picked.title }
        return "\(picked.title) · \(effort.title)"
    }

    // MARK: State

    private var actor: Actor? {
        actors.first { $0.id == actorID }
    }

    /// The efforts the picked model takes, least first.
    private var efforts: [ActorEffort] {
        actor?.models.first { $0.identifier == modelID }?.efforts ?? []
    }

    private var isDisabled: Bool {
        guard let actor else { return true }
        return isStarting || !isOnline(actor)
    }

    private var placeholder: String {
        guard let actor else { return "No actor is online." }
        return "What should \(actor.product) work on?"
    }

    private var canStart: Bool {
        !isDisabled && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isOnline(_ actor: Actor) -> Bool {
        clients.first { $0.id == actor.clientID }?.online ?? false
    }

    /// Picks the actor last picked if its client is online, else the first
    /// online one, else none, while none is picked; the model and effort
    /// last picked carry over where the actor offers them.
    private func chooseActor() {
        if let actorID, actors.contains(where: { $0.id == actorID }) { return }
        let pick = ActorPick.load()
        let online = actors.filter(isOnline)
        guard let chosen = online.first(where: { $0.id == pick?.actorID }) ?? online.first else {
            actorID = nil
            return
        }
        actorID = chosen.id
        if let pick {
            modelID = pick.model
            effort = pick.effort
        }
        settle(on: chosen)
    }

    /// Fits the mode, model and effort to `actor`: its first mode; the model
    /// if it offers it, else its first; the effort if that model takes it,
    /// else the default.
    private func settle(on actor: Actor) {
        mode = actor.modes.first?.identifier ?? ""
        if !actor.models.contains(where: { $0.identifier == modelID }) {
            modelID = actor.models.first?.identifier ?? ""
        }
        let efforts = actor.models.first { $0.identifier == modelID }?.efforts ?? []
        if !efforts.contains(where: { $0.identifier == effort }) { effort = "" }
    }

    private func remember() {
        guard let actorID else { return }
        ActorPick(actorID: actorID, model: modelID, effort: effort).save()
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

    private func start() {
        guard let client = model.client, let actor, canStart else { return }
        isStarting = true
        failure = nil
        Task {
            do {
                let session = try await client.startSession(
                    on: actor,
                    prompt: prompt,
                    images: images,
                    mode: mode.isEmpty ? nil : mode,
                    model: modelID.isEmpty ? nil : modelID,
                    effort: effort.isEmpty ? nil : effort
                )
                // The sketch attached becomes the new session's.
                if let pairing = model.pairing, let sketch = images.first(where: { $0.drawing != nil })?.drawing {
                    SketchThread(server: pairing.serverFingerprint, kind: .actorSession(session.id)).save(sketch)
                }
                dismiss()
                started(session)
            } catch {
                failure = error.localizedDescription
            }
            isStarting = false
        }
    }
}

/// The actor, model and effort last picked for a new session, as the web keeps
/// them under `cohesion.actorPick`; the mode is never remembered.
private struct ActorPick: Codable {
    let actorID: Int
    let model: String
    let effort: String

    private static let key = "cohesion.actorPick"

    enum CodingKeys: String, CodingKey {
        case model, effort
        case actorID = "actor_id"
    }

    static func load() -> ActorPick? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(ActorPick.self, from: $0) }
    }

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}
