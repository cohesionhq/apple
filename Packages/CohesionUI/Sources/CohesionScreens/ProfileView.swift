import CohesionCore
import CohesionUI
import SwiftUI

/// Settings › Profile: the user's photo, added, changed or removed here,
/// and their name, saved on Return or when the field loses focus, as the
/// web saves them. Loaded only while it is shown.
public struct ProfileView: View {
    @Environment(AppModel.self) private var model

    /// `nil` until it loads; then `.some(nil)` from a daemon from before
    /// profiles.
    @State private var profile: Profile??
    /// The typed name, reset to the saved one whenever that changes.
    @State private var name = ""
    @State private var isSavingName = false
    @FocusState private var isNameFocused: Bool
    @State private var isChoosingPhoto = false
    @State private var isRemovingPhoto = false
    @State private var error: (any Error)?

    public init() {}

    public var body: some View {
        Form {
            switch profile {
            case .some(.some(let profile)): sections(profile)
            case .some(.none):
                ContentUnavailableView(
                    "No Profile",
                    systemImage: "person.crop.circle",
                    description: Text("This server’s version of Cohesion doesn’t have a profile.")
                )
            case .none: EmptyView()
            }
        }
        .overlay {
            if profile == nil { ProgressView() }
        }
        .navigationTitle("Profile")
        .photoCropPicker(isPresented: $isChoosingPhoto, onPick: setPhoto)
        .onChange(of: isNameFocused) { _, focused in
            if !focused { commitName() }
        }
        .onDisappear { commitName() }
        .task { await watch() }
        .errorAlert($error)
    }

    @ViewBuilder
    private func sections(_ profile: Profile) -> some View {
        Section {
            ContactPhotoView(photo: profile.photo, name: profile.name, diameter: 96)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .accessibilityLabel(profile.photo.image == nil ? "No photo" : "Photo")
        }
        Section {
            if profile.photo.image == nil {
                Button("Add Photo…", systemImage: "photo") { isChoosingPhoto = true }
            } else {
                Button("Change Photo…", systemImage: "photo") { isChoosingPhoto = true }
                Button("Remove Photo…", systemImage: "photo.badge.minus", role: .destructive) {
                    isRemovingPhoto = true
                }
                // On the button, so on iPad it points at the button that asked.
                .confirmationDialog("Remove Your Photo?", isPresented: $isRemovingPhoto, titleVisibility: .visible) {
                    Button("Remove", role: .destructive) {
                        run { try await $0.setProfilePhoto(nil) }
                    }
                } message: {
                    Text("Can’t be undone.")
                }
            }
        }
        Section("Name") {
            TextField("Your name", text: $name)
                .textContentType(.name)
                .submitLabel(.done)
                .focused($isNameFocused)
                .disabled(isSavingName)
                .onSubmit { isNameFocused = false }
        }
    }

    private var savedName: String {
        (profile ?? nil)?.name ?? ""
    }

    /// Saves the typed name if it differs from the saved one; on failure the
    /// field goes back to the saved name.
    private func commitName() {
        guard let client = model.client, case .some(.some) = profile,
              name.trimmingCharacters(in: .whitespaces) != savedName
        else { return }
        let typed = name
        isSavingName = true
        Task {
            do {
                show(try await client.setProfileName(typed))
            } catch {
                name = savedName
                self.error = error
            }
            isSavingName = false
        }
    }

    /// Keeps the profile current while it is shown; the stream also yields
    /// once on connecting, which does the first load.
    private func watch() async {
        guard let client = model.client else { return }
        for await origin in client.loads(matching: { $0 == .profile }) {
            await origin.run {
                show(try await client.profile())
            } failed: { self.error = $0 }
        }
    }

    private func show(_ loaded: Profile?) {
        let wasSaved = name == savedName
        profile = .some(loaded)
        // Keep what's being typed; otherwise follow the saved name.
        if wasSaved || !isNameFocused { name = loaded?.name ?? "" }
    }

    private func setPhoto(_ photo: AttachmentUpload?) {
        guard let photo else {
            error = PhotoError()
            return
        }
        run { try await $0.setProfilePhoto(photo) }
    }

    private func run(_ action: @escaping (CohesionClient) async throws -> Profile) {
        guard let client = model.client else { return }
        Task {
            do { show(try await action(client)) } catch { self.error = error }
        }
    }
}
