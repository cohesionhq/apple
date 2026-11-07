import CohesionCore
import CohesionUI
import SwiftUI

/// The images attached to a message: above the user's text on the trailing
/// edge, below an agent's on the leading edge, wrapping; grey squares until
/// they load. Tapping one opens it.
struct AttachedImages: View {
    /// Loaded, or nil while they load.
    let images: [PlatformImage]?
    let count: Int
    /// The agent's reaction, on the images when the message has no text.
    let reaction: String?
    /// The side of the feed the sender's messages sit on.
    var edge = HorizontalEdge.trailing

    @State private var shown: ShownImage?

    var body: some View {
        FlowLayout(alignment: edge == .trailing ? .trailing : .leading) {
            if let images {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    Button {
                        shown = ShownImage(image: image)
                    } label: {
                        Image(platformImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: side, height: side)
                            .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Attached image \(index + 1)")
                }
            } else {
                ForEach(0..<count, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.fill.tertiary)
                        .frame(width: side, height: side)
                }
            }
        }
        .reactions(reaction, on: edge)
        .frame(maxWidth: .infinity, alignment: edge == .trailing ? .trailing : .leading)
        .padding(edge == .trailing ? .leading : .trailing, bubbleInset)
        .fullScreenCover(item: $shown) { shown in
            ImageViewer(image: shown.image)
        }
    }

    /// One image fills a bubble's width; several share rows, wrapping.
    private var side: CGFloat { count == 1 ? 200 : 96 }
}

struct ShownImage: Identifiable {
    let id = UUID()
    let image: PlatformImage
}

/// One image, full screen on black, until Done.
struct ImageViewer: View {
    let image: PlatformImage

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Image(platformImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", systemImage: "checkmark", role: .confirm) { dismiss() }
                    }
                }
        }
    }
}

/// The images about to be sent, above the composer's field, each with a
/// button to take it out.
struct DraftImages: View {
    @Binding var images: [AttachmentUpload]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(images.enumerated()), id: \.element.id) { index, upload in
                    Image(platformImage: upload.preview)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(.rect(cornerRadius: 10))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                withAnimation { images.removeAll { $0.id == upload.id } }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.6))
                            }
                            .accessibilityLabel("Remove image \(index + 1)")
                            .padding(3)
                        }
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
        }
        .scrollIndicators(.hidden)
    }
}
