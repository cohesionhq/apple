import CohesionCore
import CohesionUI
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import PencilKit
#endif

/// The conversation a sketch belongs to: one sketch per agent's chat or
/// actor session, kept on this device as a PencilKit file beside the
/// server's other threads, so it can be opened and edited again.
struct SketchThread {
    enum Kind {
        case agent(Int)
        case actorSession(Int)
    }

    /// The paired server's fingerprint, which keeps one server's threads
    /// apart from another's with the same ids.
    let server: String
    let kind: Kind

    #if os(iOS)
    /// The thread's sketch, `nil` for none or one that won't read.
    func load() -> PKDrawing? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PKDrawing(data: data)
    }
    #endif

    /// Keeps `drawing` (a `PKDrawing`'s data representation) as the thread's sketch.
    func save(_ drawing: Data) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? drawing.write(to: url, options: .atomic)
    }

    private var url: URL {
        let name = switch kind {
        case .agent(let id): "agent-\(id).drawing"
        case .actorSession(let id): "actor-session-\(id).drawing"
        }
        return URL.applicationSupportDirectory
            .appending(path: "Sketches", directoryHint: .isDirectory)
            .appending(path: server.filter { $0.isLetter || $0.isNumber }, directoryHint: .isDirectory)
            .appending(path: name)
    }
}

extension AttachmentUpload {
    /// The picked photos as uploads, in order, leaving out any that won't load.
    static func load(_ items: [PhotosPickerItem]) async -> [AttachmentUpload] {
        await loadAll(items).uploads
    }

    /// The picked photos as uploads, in order, and whether any were left
    /// out for not loading as an image.
    static func loadAll(_ items: [PhotosPickerItem]) async -> (uploads: [AttachmentUpload], failed: Bool) {
        var uploads: [AttachmentUpload] = []
        var failed = false
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let upload = await Task.detached(operation: { AttachmentUpload.prepare(data) }).value
            else {
                failed = true
                continue
            }
            uploads.append(upload)
        }
        return (uploads, failed)
    }
}

#if os(iOS)
extension AttachmentUpload {
    /// `drawing` as an image to send: its strokes on white, in their light
    /// colors, with a margin, carrying the drawing to edit again.
    static func sketch(_ drawing: PKDrawing) -> AttachmentUpload? {
        let bounds = drawing.bounds.insetBy(dx: -24, dy: -24)
        guard !drawing.strokes.isEmpty, bounds.width > 0, bounds.height > 0 else { return nil }
        // Within the longest side the models look at, so it stays a PNG.
        let scale = min(2, 1568 / max(bounds.width, bounds.height))
        var strokes = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            strokes = drawing.image(from: bounds, scale: scale)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: bounds.size))
            strokes.draw(at: .zero)
        }
        guard let png = image.pngData(), var upload = prepare(png) else { return nil }
        upload.drawing = drawing.dataRepresentation()
        return upload
    }
}
#endif

/// What the attach menu has open, which `attachPresenter` presents.
struct AttachPresentation {
    var isPicking = false
    #if os(iOS)
    var sketch: PKDrawing?
    #else
    var isImportingFiles = false
    #endif
}

/// The composer's attach button: a menu that pastes the images copied,
/// picks photos, on the Mac picks image files too, and on iPad opens the thread's sketch to draw on or edit,
/// attaching it as an image in place of the one attached before. Without a
/// `sketchThread` (a session not started yet), the sketch lives only in the
/// attached image until the thread exists. What it opens is presented by
/// `attachPresenter`.
struct AttachMenu<Label: View>: View {
    @Binding var images: [AttachmentUpload]
    let sketchThread: SketchThread?
    @Binding var presentation: AttachPresentation
    @ViewBuilder let label: Label

    @Environment(WindowModel.self) private var window

    private var room: Int { max(0, AttachmentUpload.limit - images.count) }

    var body: some View {
        Menu {
            Button("Paste Image", systemImage: "doc.on.clipboard", action: paste)
                .disabled(room == 0)
            Button("Choose Photos…", systemImage: "photo.on.rectangle") { presentation.isPicking = true }
                .disabled(room == 0)
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                Button("Sketch…", systemImage: "pencil.and.scribble", action: openSketch)
                    .disabled(room == 0 && !images.contains { $0.drawing != nil })
            }
            #else
            Button("Choose Files…", systemImage: "doc") { presentation.isImportingFiles = true }
                .disabled(room == 0)
            #endif
        } label: {
            label
        }
        .accessibilityLabel("Attach Images")
    }

    /// Attaches the images copied, as many as there's room for; nothing
    /// when none are.
    private func paste() {
        let copied = Pasteboard.general.images ?? []
        let room = room
        Task {
            let uploads = await Task.detached {
                copied.prefix(room).compactMap { $0.encodedData.flatMap { AttachmentUpload.prepare($0) } }
            }.value
            withAnimation { images.append(contentsOf: uploads.prefix(max(0, AttachmentUpload.limit - images.count))) }
        }
    }

    #if os(iOS)
    private func openSketch() {
        window.isSketching = true
        if let attached = images.first(where: { $0.drawing != nil })?.drawing,
           let drawing = try? PKDrawing(data: attached) {
            presentation.sketch = drawing
        } else {
            presentation.sketch = sketchThread?.load() ?? PKDrawing()
        }
    }
    #endif
}

extension View {
    /// Presents what the composer's `AttachMenu` opens. It goes on the
    /// composer rather than the menu: SwiftUI presents a cover or a picker
    /// declared in a sheet's toolbar item from the window's root, which
    /// closes the sheet, and the cover with it.
    func attachPresenter(
        _ presentation: Binding<AttachPresentation>,
        images: Binding<[AttachmentUpload]>,
        sketchThread: SketchThread?,
        attach: @escaping ([PhotosPickerItem]) -> Void
    ) -> some View {
        modifier(AttachPresenter(presentation: presentation, images: images, sketchThread: sketchThread, attach: attach))
    }
}

private struct AttachPresenter: ViewModifier {
    @Binding var presentation: AttachPresentation
    @Binding var images: [AttachmentUpload]
    let sketchThread: SketchThread?
    /// Adds the photos picked.
    let attach: ([PhotosPickerItem]) -> Void

    @Environment(WindowModel.self) private var window
    @State private var pickerItems: [PhotosPickerItem] = []

    private var room: Int { max(0, AttachmentUpload.limit - images.count) }

    func body(content: Content) -> some View {
        content
            .photosPicker(
                isPresented: $presentation.isPicking,
                selection: $pickerItems,
                maxSelectionCount: max(1, room),
                matching: .images
            )
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                pickerItems = []
                attach(items)
            }
            #if os(iOS)
            .fullScreenCover(isPresented: Binding { presentation.sketch != nil } set: { if !$0 { presentation.sketch = nil } }) {
                SketchSheet(drawing: presentation.sketch ?? PKDrawing(), attach: attachSketch)
                    .onDisappear { window.isSketching = false }
            }
            #else
            .fileImporter(isPresented: $presentation.isImportingFiles, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result { attach(files: urls) }
            }
            #endif
    }

    #if os(iOS)
    private func attachSketch(_ drawing: PKDrawing) {
        guard let upload = AttachmentUpload.sketch(drawing) else { return }
        sketchThread?.save(drawing.dataRepresentation())
        withAnimation {
            if let index = images.firstIndex(where: { $0.drawing != nil }) {
                images[index] = upload
            } else {
                images.append(upload)
            }
        }
    }
    #else
    /// Attaches the image files picked, as many as there's room for,
    /// leaving out any that won't load.
    private func attach(files urls: [URL]) {
        let room = room
        Task {
            let uploads = await Task.detached {
                urls.prefix(room).compactMap { url -> AttachmentUpload? in
                    let isScoped = url.startAccessingSecurityScopedResource()
                    defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
                    return (try? Data(contentsOf: url)).flatMap { AttachmentUpload.prepare($0) }
                }
            }.value
            withAnimation { images.append(contentsOf: uploads.prefix(max(0, AttachmentUpload.limit - images.count))) }
        }
    }
    #endif
}

private extension PlatformImage {
    /// The image's bytes for `AttachmentUpload` to prepare.
    nonisolated var encodedData: Data? {
        #if canImport(UIKit)
        pngData()
        #else
        tiffRepresentation
        #endif
    }
}

#if os(iOS)
/// The thread's sketch on a sheet of paper in the system's appearance with
/// the system's tool picker. Clear empties the canvas to start the thread's sketch afresh;
/// Cancel leaves the sketch as it was, cleared or not; Attach keeps the
/// edits and attaches the sketch, once there's something drawn.
private struct SketchSheet: View {
    @State var drawing: PKDrawing
    let attach: (PKDrawing) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SketchCanvas(drawing: $drawing)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Sketch")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Clear", systemImage: "arrow.counterclockwise") { drawing = PKDrawing() }
                            .disabled(drawing.strokes.isEmpty)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Attach", systemImage: "checkmark", role: .confirm) {
                            attach(drawing)
                            dismiss()
                        }
                        .disabled(drawing.strokes.isEmpty)
                    }
                }
        }
    }
}

/// A PencilKit canvas with the tool picker up, in the system's appearance:
/// in dark mode PencilKit shows the ink in its dark colors, while the image
/// sent is always the light rendering.
private struct SketchCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeCoordinator() -> Coordinator { Coordinator(drawing: $drawing) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .systemBackground
        canvas.isOpaque = true
        canvas.alwaysBounceVertical = false
        let picker = context.coordinator.picker
        picker.addObserver(canvas)
        picker.setVisible(true, forFirstResponder: canvas)
        DispatchQueue.main.async { canvas.becomeFirstResponder() }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing { canvas.drawing = drawing }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let drawing: Binding<PKDrawing>
        let picker = PKToolPicker()

        init(drawing: Binding<PKDrawing>) {
            self.drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvas: PKCanvasView) {
            drawing.wrappedValue = canvas.drawing
        }
    }
}
#endif
