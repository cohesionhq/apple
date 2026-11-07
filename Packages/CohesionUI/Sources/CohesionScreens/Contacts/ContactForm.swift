import CohesionCore
import CohesionMarkdown
import CohesionUI
import SwiftUI

/// A contact not yet created: blank, or filled in from one picked in the
/// system's contacts.
public struct ContactDraft: Identifiable {
    public let id = UUID()
    public var firstName = ""
    public var middleName = ""
    public var lastName = ""
    public var notes = ""
    public var emails: [MethodField] = [MethodField()]
    public var phones: [MethodField] = [MethodField()]
    public var photo: AttachmentUpload?

    public init(firstName: String = "", middleName: String = "", lastName: String = "", notes: String = "") {
        self.firstName = firstName
        self.middleName = middleName
        self.lastName = lastName
        self.notes = notes
    }

    /// One email address or phone number being written.
    public struct MethodField: Identifiable {
        public let id = UUID()
        public var value = ""

        public init(value: String = "") {
            self.value = value
        }
    }

    /// The written emails, then phones, in their order, without blanks.
    var methods: [NewContactMethod] {
        func written(_ fields: [MethodField], _ kind: ContactMethodKind) -> [NewContactMethod] {
            fields
                .map { $0.value.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { NewContactMethod(kind: kind, value: $0) }
        }
        return written(emails, .email) + written(phones, .phone)
    }
}

/// Creates a contact, or edits one's names and notes, in a sheet. A new
/// one also takes its email addresses, phone numbers and photo, as the
/// system's contact picker may bring several; an existing one's are changed
/// on its page, as the web does.
struct ContactForm: View {
    enum Subject {
        case new(ContactDraft)
        case edit(Contact)
    }

    let subject: Subject
    /// Called with a contact just created, and why its photo didn't save
    /// if it didn't.
    var onCreate: (Contact, (any Error)?) -> Void = { _, _ in }

    @Environment(AppModel.self) private var model
    @Environment(WindowModel.self) private var window
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ContactDraft
    @State private var isChoosingPhoto = false
    @State private var isSaving = false
    @State private var error: (any Error)?

    init(subject: Subject, onCreate: @escaping (Contact, (any Error)?) -> Void = { _, _ in }) {
        self.subject = subject
        self.onCreate = onCreate
        switch subject {
        case .new(let draft):
            _draft = State(initialValue: draft)
        case .edit(let contact):
            _draft = State(initialValue: ContactDraft(
                firstName: contact.firstName,
                middleName: contact.middleName ?? "",
                lastName: contact.lastName,
                notes: contact.notes
            ))
        }
    }

    private var isNew: Bool {
        if case .new = subject { true } else { false }
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !isSaving && !trimmed(draft.firstName).isEmpty && !trimmed(draft.lastName).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if isNew { photoSection }
                Section {
                    TextField("First name", text: $draft.firstName)
                        .textContentType(.givenName)
                    TextField("Middle name (optional)", text: $draft.middleName)
                        .textContentType(.middleName)
                    TextField("Last name", text: $draft.lastName)
                        .textContentType(.familyName)
                }
                .autocorrectionDisabled()
                if isNew {
                    methodSection("Emails", kind: .email, fields: $draft.emails)
                    methodSection("Phones", kind: .phone, fields: $draft.phones)
                }
                // Markdown, read rendered here and written in its own
                // editor, as a task's notes are.
                Section("Notes") {
                    if !draft.notes.isEmpty {
                        MarkdownText(markdown: draft.notes)
                    }
                    NavigationLink(draft.notes.isEmpty ? "Add Notes" : "Edit Notes") {
                        NotesEditor(text: $draft.notes)
                    }
                }
            }
            .navigationTitle(isNew ? "New Contact" : "Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(isNew ? "Create" : "Save", systemImage: "checkmark", role: .confirm, action: save)
                            .disabled(!canSave)
                    }
                }
            }
            .photoCropPicker(isPresented: $isChoosingPhoto, onPick: choosePhoto)
            .errorAlert($error)
            .presentsLinkedItems()
        }
        .interactiveDismissDisabled(isSaving)
    }

    /// The photo to create the contact with, and buttons to choose or
    /// remove it.
    private var photoSection: some View {
        Section {
            HStack(spacing: 16) {
                ContactPhotoView(
                    photo: draft.photo.map { .image($0.preview) } ?? .none,
                    diameter: 64
                )
                VStack(alignment: .leading, spacing: 8) {
                    Button(draft.photo == nil ? "Add Photo…" : "Change Photo…") { isChoosingPhoto = true }
                    if draft.photo != nil {
                        Button("Remove Photo", role: .destructive) { draft.photo = nil }
                    }
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func methodSection(
        _ title: String,
        kind: ContactMethodKind,
        fields: Binding<[ContactDraft.MethodField]>
    ) -> some View {
        Section(title) {
            ForEach(fields) { $field in
                TextField(kind.label, text: $field.value)
                    .keyboardType(kind == .email ? .emailAddress : .phonePad)
                    .textContentType(kind == .email ? .emailAddress : .telephoneNumber)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .onDelete { fields.wrappedValue.remove(atOffsets: $0) }
            Button(kind == .email ? "Add Email" : "Add Phone", systemImage: "plus") {
                fields.wrappedValue.append(ContactDraft.MethodField())
            }
        }
    }

    private func choosePhoto(_ photo: AttachmentUpload?) {
        guard let photo else {
            error = PhotoError()
            return
        }
        draft.photo = photo
    }

    private func save() {
        guard let client = model.client, canSave, let workspaceID = window.selectedWorkspaceID else { return }
        isSaving = true
        let firstName = trimmed(draft.firstName)
        let middleName = trimmed(draft.middleName)
        let lastName = trimmed(draft.lastName)
        let notes = trimmed(draft.notes)
        Task {
            do {
                switch subject {
                case .new:
                    let created = try await client.createContact(
                        firstName: firstName,
                        middleName: middleName,
                        lastName: lastName,
                        notes: notes,
                        methods: draft.methods,
                        in: workspaceID
                    )
                    // The contact is made either way; a photo that didn't
                    // save is said where it opens.
                    var photoError: (any Error)?
                    if let photo = draft.photo {
                        do { try await client.setPhoto(of: created, to: photo) } catch { photoError = error }
                    }
                    dismiss()
                    onCreate(created, photoError)
                case .edit(let contact):
                    try await client.updateContact(
                        contact,
                        firstName: firstName,
                        middleName: middleName,
                        lastName: lastName,
                        notes: notes
                    )
                    dismiss()
                }
            } catch {
                self.error = error
            }
            isSaving = false
        }
    }
}

/// Adds an email address or phone number to a contact, or changes one:
/// what it says, then its type, which only an edit offers, as the web's
/// dialog does.
struct MethodForm: View {
    enum Subject: Identifiable {
        case add(ContactMethodKind)
        case edit(ContactMethod)

        var id: String {
            switch self {
            case .add(let kind): "add-\(kind.rawValue)"
            case .edit(let method): "edit-\(method.id)"
            }
        }
    }

    let contact: Contact
    let subject: Subject

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var kind: ContactMethodKind
    @State private var value: String
    @State private var isSaving = false
    @State private var error: (any Error)?
    @FocusState private var isFocused: Bool

    init(contact: Contact, subject: Subject) {
        self.contact = contact
        self.subject = subject
        switch subject {
        case .add(let kind):
            _kind = State(initialValue: kind)
            _value = State(initialValue: "")
        case .edit(let method):
            _kind = State(initialValue: method.kind)
            _value = State(initialValue: method.value)
        }
    }

    private var trimmed: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var title: String {
        switch subject {
        case .add(let kind): "Add \(kind.label)"
        case .edit(let method): "Edit \(method.kind.label)"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(kind.label, text: $value)
                    .keyboardType(kind == .email ? .emailAddress : .phonePad)
                    .textContentType(kind == .email ? .emailAddress : .telephoneNumber)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(save)
                if case .edit = subject {
                    Picker("Type", selection: $kind) {
                        ForEach(ContactMethodKind.allCases) { Text($0.label).tag($0) }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(isAdding ? "Add" : "Save", systemImage: "checkmark", role: .confirm, action: save)
                            .disabled(trimmed.isEmpty)
                    }
                }
            }
            .onAppear { isFocused = true }
            .errorAlert($error)
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(isSaving)
    }

    private var isAdding: Bool {
        if case .add = subject { true } else { false }
    }

    private func save() {
        guard let client = model.client, !trimmed.isEmpty, !isSaving else { return }
        isSaving = true
        Task {
            do {
                switch subject {
                case .add: try await client.addMethod(kind, trimmed, to: contact)
                case .edit(let method): try await client.updateMethod(method, of: contact, kind: kind, value: trimmed)
                }
                dismiss()
            } catch {
                self.error = error
            }
            isSaving = false
        }
    }
}
