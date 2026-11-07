import CohesionCore
import CohesionScreens
import Contacts
import ContactsUI
import SwiftUI

extension View {
    /// Presents the system's contact picker while `isPresented`, and hands
    /// the person picked to `onPick` as a draft once the picker has gone.
    /// The picker runs out of the app's process, so it needs no access to
    /// the user's contacts.
    func contactPicker(isPresented: Binding<Bool>, onPick: @escaping (ContactDraft) -> Void) -> some View {
        background(ContactPicker(isPresented: isPresented, onPick: onPick))
    }
}

extension ContactDraft {
    /// `contact` as a new contact: its given, middle and family names, its
    /// email addresses and phone numbers in its order, and its photo at the
    /// size a contact's photo is sent. Its notes stay behind, since reading
    /// them takes an entitlement the app doesn't have.
    init(_ contact: CNContact) {
        func available(_ key: String) -> Bool { contact.isKeyAvailable(key) }
        self.init(
            firstName: available(CNContactGivenNameKey) ? contact.givenName : "",
            middleName: available(CNContactMiddleNameKey) ? contact.middleName : "",
            lastName: available(CNContactFamilyNameKey) ? contact.familyName : ""
        )
        let emails = available(CNContactEmailAddressesKey)
            ? contact.emailAddresses.map { MethodField(value: $0.value as String) } : []
        let phones = available(CNContactPhoneNumbersKey)
            ? contact.phoneNumbers.map { MethodField(value: $0.value.stringValue) } : []
        // A field to write in when the contact has none, as a blank form has.
        self.emails = emails.isEmpty ? [MethodField()] : emails
        self.phones = phones.isEmpty ? [MethodField()] : phones
        let image = available(CNContactImageDataKey) ? contact.imageData : nil
        let thumbnail = available(CNContactThumbnailImageDataKey) ? contact.thumbnailImageData : nil
        photo = (image ?? thumbnail).flatMap { AttachmentUpload.prepare($0, side: AttachmentUpload.photoSide) }
    }
}

/// Presents `CNContactPickerViewController` from a view of its own, since
/// the picker can't be a SwiftUI sheet's content.
private struct ContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (ContactDraft) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, controller.presentedViewController == nil else { return }
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        controller.present(picker, animated: true)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPicker?

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let draft = ContactDraft(contact)
            finish(picker) { $0.onPick(draft) }
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            finish(picker) { _ in }
        }

        /// Clears `isPresented`, then runs `then` once the picker, which
        /// dismisses itself, is gone, so a sheet it opens can present.
        private func finish(_ picker: CNContactPickerViewController, then: @escaping (ContactPicker) -> Void) {
            guard let parent else { return }
            parent.isPresented = false
            if let coordinator = picker.transitionCoordinator {
                coordinator.animate(alongsideTransition: nil) { _ in then(parent) }
            } else {
                then(parent)
            }
        }
    }
}
