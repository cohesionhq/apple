import CohesionCore
import CohesionUI
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

extension View {
    /// Presents the system's photo library while `isPresented`, with its
    /// square crop, and hands the cropped photo, ready to send as a
    /// contact's or the user's photo, to `onPick` once the picker has gone;
    /// `nil` when it won't encode. The library runs out of the app's
    /// process, so it needs no access to the user's photos.
    func photoCropPicker(isPresented: Binding<Bool>, onPick: @escaping (AttachmentUpload?) -> Void) -> some View {
        #if os(iOS)
        background(PhotoCropPicker(isPresented: isPresented, onPick: onPick))
        #else
        // The Mac has no system crop: a file picked, cut to its middle square.
        fileImporter(isPresented: isPresented, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            Task {
                onPick(await Task.detached { AttachmentUpload.squarePhoto(at: url) }.value)
            }
        }
        #endif
    }
}

#if os(macOS)
private extension AttachmentUpload {
    /// The image at `url` cut to its middle square, ready to send as a
    /// contact's or the user's photo.
    nonisolated static func squarePhoto(at url: URL) -> AttachmentUpload? {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        guard let image = NSImage(contentsOf: url),
              let bitmap = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        let side = min(bitmap.width, bitmap.height)
        let square = CGRect(x: (bitmap.width - side) / 2, y: (bitmap.height - side) / 2, width: side, height: side)
        guard let cropped = bitmap.cropping(to: square) else { return nil }
        return prepare(NSImage(cgImage: cropped, size: square.size), side: photoSide)
    }
}
#else

/// Presents `UIImagePickerController` with editing on from a view of its
/// own, since `PhotosPicker` has no crop.
private struct PhotoCropPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (AttachmentUpload?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, controller.presentedViewController == nil else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = [UTType.image.identifier]
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        controller.present(picker, animated: true)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: PhotoCropPicker?

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            finish(picker) { parent in
                Task {
                    let photo = await Task.detached(operation: {
                        image.flatMap { AttachmentUpload.prepare($0, side: AttachmentUpload.photoSide) }
                    }).value
                    parent.onPick(photo)
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            finish(picker) { _ in }
        }

        /// Clears `isPresented` and dismisses the picker, then runs `then`
        /// once it's gone, so an alert it leads to can present.
        private func finish(_ picker: UIImagePickerController, then: @escaping (PhotoCropPicker) -> Void) {
            guard let parent else { return }
            parent.isPresented = false
            picker.dismiss(animated: true) { then(parent) }
        }
    }
}
#endif
