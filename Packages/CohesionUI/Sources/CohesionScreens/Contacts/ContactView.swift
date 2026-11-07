import CohesionCore
import CohesionMarkdown
import CohesionUI
import SwiftUI

/// A way to get in touch through one of a contact's methods, each opening
/// the system's app for it: Messages, Phone and FaceTime for a phone
/// number, Mail for an email address.
enum ContactAction: CaseIterable, Identifiable {
    case message
    case call
    case faceTime
    case email

    var id: Self { self }

    /// The kind of method it goes through.
    var kind: ContactMethodKind {
        switch self {
        case .message, .call, .faceTime: .phone
        case .email: .email
        }
    }

    var title: String {
        switch self {
        case .message: "Message"
        case .call: "Call"
        case .faceTime: "FaceTime"
        case .email: "Email"
        }
    }

    var systemImage: String {
        switch self {
        case .message: "message.fill"
        case .call: "phone.fill"
        case .faceTime: "video.fill"
        case .email: "envelope.fill"
        }
    }

    /// Where `method` goes with this action: a phone number as its digits
    /// and any `+`, as the web dials it; `nil` when the method is of the
    /// other kind or has nothing to dial.
    func url(for method: ContactMethod) -> URL? {
        guard method.kind == kind else { return nil }
        switch self {
        case .message, .call, .faceTime:
            let number = method.value.filter { $0.isASCII && ($0.isNumber || $0 == "+") }
            guard !number.isEmpty else { return nil }
            let scheme = switch self {
            case .message: "sms"
            case .faceTime: "facetime"
            default: "tel"
            }
            return URL(string: "\(scheme):\(number)")
        case .email:
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = method.value
            return components.url
        }
    }
}

/// A contact: their photo and name, buttons to message, call, FaceTime or
/// email them, their email addresses and phone numbers (each added,
/// edited or removed here), and their notes. The menu edits their names
/// and notes, changes their photo, or deletes them. Shown from the list it
/// is open from, so it follows cohesiond's changes to the contact as that
/// list does.
struct ContactView: View {
    let contact: Contact

    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    @State private var isEditing = false
    /// The method being added or edited.
    @State private var methodForm: MethodForm.Subject?
    @State private var removing: ContactMethod?
    @State private var isDeleting = false
    @State private var isChoosingPhoto = false
    @State private var isRemovingPhoto = false
    @State private var error: (any Error)?
    @ScaledMetric(relativeTo: .title3) private var actionGlyphHeight: CGFloat = 24

    var body: some View {
        List {
            Section {
                header
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            Section {
                ForEach(contact.methods) { method in
                    methodRow(method)
                }
                Button("Add Email…", systemImage: "plus") { methodForm = .add(.email) }
                Button("Add Phone…", systemImage: "plus") { methodForm = .add(.phone) }
            }
            Section("Notes") {
                if contact.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("No notes.")
                        .foregroundStyle(.secondary)
                } else {
                    MarkdownText(markdown: contact.notes)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { menu }
        }
        .sizedSheet(isPresented: $isEditing) {
            ContactForm(subject: .edit(contact))
        }
        .sizedSheet(item: $methodForm) { subject in
            MethodForm(contact: contact, subject: subject)
        }
        .photoCropPicker(isPresented: $isChoosingPhoto, onPick: setPhoto)
        .errorAlert($error)
    }

    /// The photo, the name, then a button for each way to get in touch,
    /// as the system's Contacts app lays them out.
    private var header: some View {
        VStack(spacing: 12) {
            ContactPhotoView(photo: contact.photo, diameter: 96)
            Text(contact.fullName)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                ForEach(ContactAction.allCases) { action in
                    actionButton(action)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    /// The action through the contact's one method it fits, a menu of them
    /// when several do, or dimmed when none does.
    @ViewBuilder
    private func actionButton(_ action: ContactAction) -> some View {
        let reachable = contact.methods.compactMap { method in action.url(for: method).map { (method, $0) } }
        let label = VStack(spacing: 4) {
            // One height for every glyph, so the titles under them line up.
            Image(systemName: action.systemImage)
                .font(.title3)
                .frame(height: actionGlyphHeight)
            Text(action.title)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
        .contentShape(.rect(cornerRadius: 12))
        .hoverEffect()

        Group {
            if reachable.count > 1 {
                Menu {
                    ForEach(reachable, id: \.0.id) { method, url in
                        Button(method.value) { openURL(url) }
                    }
                } label: {
                    label
                }
            } else {
                Button {
                    if let url = reachable.first?.1 { openURL(url) }
                } label: {
                    label
                }
                .disabled(reachable.isEmpty)
            }
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(action.title)
    }

    /// An email address or phone number, which a tap emails or calls; its
    /// menu has every way through it, then Copy, Edit and Remove.
    private func methodRow(_ method: ContactMethod) -> some View {
        let primary = method.kind == .email ? ContactAction.email : .call
        return Button {
            if let url = primary.url(for: method) { openURL(url) }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(method.kind.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(method.value)
                    .foregroundStyle(.tint)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(primary.url(for: method) == nil ? "" : primary.title)
        .contextMenu {
            Section {
                ForEach(ContactAction.allCases) { action in
                    if let url = action.url(for: method) {
                        Button(action.title, systemImage: action.systemImage) { openURL(url) }
                    }
                }
            }
            Button("Copy", systemImage: "doc.on.doc") { Pasteboard.general.string = method.value }
            Button("Edit…", systemImage: "pencil") { methodForm = .edit(method) }
            Button("Remove…", systemImage: "trash", role: .destructive) { removing = method }
        }
        .swipeActions {
            Button("Remove", systemImage: "trash", role: .destructive) { removing = method }
            Button("Edit", systemImage: "pencil") { methodForm = .edit(method) }
        }
        // On the row, so on iPad it points at the method it removes.
        .confirmationDialog(
            "Remove \(method.value)?",
            isPresented: Binding(get: { removing?.id == method.id }, set: { if !$0 { removing = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                run { try await $0.deleteMethod(method, of: contact) }
            }
        } message: {
            Text("Can’t be undone.")
        }
    }

    private var menu: some View {
        Menu("Contact Actions", systemImage: "ellipsis") {
            Button("Edit…", systemImage: "pencil") { isEditing = true }
            if contact.photo.image == nil {
                Button("Add Photo…", systemImage: "photo") { isChoosingPhoto = true }
            } else {
                Button("Change Photo…", systemImage: "photo") { isChoosingPhoto = true }
                Button("Remove Photo…", systemImage: "photo.badge.minus") { isRemovingPhoto = true }
            }
            Section {
                Button("Delete…", systemImage: "trash", role: .destructive) { isDeleting = true }
            }
        }
        // On the menu, so on iPad they point at the button that asked.
        .confirmationDialog("Remove Photo?", isPresented: $isRemovingPhoto, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                run { try await $0.setPhoto(of: contact, to: nil) }
            }
        } message: {
            Text("Can’t be undone.")
        }
        .confirmationDialog("Delete \(contact.fullName)?", isPresented: $isDeleting, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                run { try await $0.delete(contact) }
            }
        } message: {
            Text("Its photo, email addresses, phone numbers and notes go with it.")
        }
    }

    private func setPhoto(_ photo: AttachmentUpload?) {
        guard let photo else {
            error = PhotoError()
            return
        }
        run { try await $0.setPhoto(of: contact, to: photo) }
    }

    private func run(_ action: @escaping (CohesionClient) async throws -> Void) {
        guard let client = model.client else { return }
        Task {
            do { try await action(client) } catch { self.error = error }
        }
    }
}

/// A picked photo that doesn't load as an image.
struct PhotoError: LocalizedError {
    var errorDescription: String? { "Couldn’t read that photo." }
}
