import CohesionCore
import CohesionUI
import SwiftUI
import UniformTypeIdentifiers

/// The installed extensions, each leading to its permissions and hooks,
/// and adding one: browsing the registries, or a script from a file or the
/// clipboard, each reviewed before it installs.
public struct ExtensionsView: View {
    @Environment(AppModel.self) private var model

    @State private var extensions: [ExtensionSummary] = []
    @State private var isLoaded = false
    @State private var isBrowsing = false
    @State private var isChoosingFile = false
    /// Whether cohesiond is reading a script from a file or the clipboard.
    @State private var isReading = false
    @State private var review: ExtensionReview?
    @State private var notice: Toast?
    @State private var error: (any Error)?

    public init() {}

    public var body: some View {
        List(extensions) { extensionSummary in
            NavigationLink {
                ExtensionView(extensionSummary: extensionSummary) {
                    extensions.removeAll { $0.id == extensionSummary.id }
                }
            } label: {
                ExtensionRow(extensionSummary: extensionSummary)
            }
        }
        .overlay {
            if !isLoaded {
                ProgressView()
            } else if extensions.isEmpty {
                ContentUnavailableView {
                    Label("No extensions installed yet.", systemImage: "puzzlepiece.extension")
                } actions: {
                    Button("Browse Extensions") { isBrowsing = true }
                }
            }
        }
        .navigationTitle("Extensions")
        #if os(iOS)
        // Inline, as Settings above it is: a page pushed in a sheet.
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isReading {
                    ProgressView()
                } else {
                    Menu("Add Extension", systemImage: "plus") {
                        Button("Browse Extensions", systemImage: "storefront") { isBrowsing = true }
                        Button("Install from File…", systemImage: "doc") { isChoosingFile = true }
                        Button("Install from Clipboard…", systemImage: "doc.on.clipboard", action: installFromClipboard)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $isBrowsing) { BrowseExtensionsView() }
        // `.ts` is also MPEG transport stream's extension, so that type is
        // accepted for a TypeScript script; cohesiond reads whatever is chosen.
        .fileImporter(
            isPresented: $isChoosingFile,
            allowedContentTypes: [.javaScript, .sourceCode, .plainText, .mpeg2TransportStream]
        ) { result in
            switch result {
            case .success(let url): installFromFile(url)
            case .failure(let error): self.error = error
            }
        }
        // cohesiond names no invalidation for the list, so it loads on showing and on a pull.
        .task { await load(.asked) }
        .refreshable { await load(.asked) }
        .reviewsExtensions($review, reload: { await load() })
        .toast($notice)
        .errorAlert($error)
    }

    private func installFromFile(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let script = try? String(contentsOf: url, encoding: .utf8) else {
            notice = .error("Couldn’t read \(url.lastPathComponent).")
            return
        }
        read(script, origin: url.lastPathComponent)
    }

    private func installFromClipboard() {
        guard let script = Pasteboard.general.string, !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            notice = .error("Couldn’t find a script on the clipboard.")
            return
        }
        read(script, origin: nil)
    }

    /// Has cohesiond read `script`'s manifest, then reviews it.
    private func read(_ script: String, origin: String?) {
        guard let client = model.client else { return }
        isReading = true
        Task {
            defer { isReading = false }
            do {
                let preview = try await client.previewExtension(script: script)
                review = ExtensionReview(source: .script(preview, origin: origin))
            } catch {
                self.error = error
            }
        }
    }

    private func load(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client else { return }
        await origin.run {
            // Alphabetical, as the web UI lists them.
            extensions = try await client.listExtensions()
                .sorted { $0.scriptIdentifier.localizedStandardCompare($1.scriptIdentifier) == .orderedAscending }
            isLoaded = true
        } failed: { self.error = $0 }
    }
}

/// An installed extension's icon and name over its description, up to two
/// lines, with its version at the trailing edge, clear of the name. A label,
/// so the row's separator starts where its text does.
private struct ExtensionRow: View {
    let extensionSummary: ExtensionSummary

    @ScaledMetric(relativeTo: .body) private var iconSize = 32

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(extensionSummary.name)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("v\(extensionSummary.version.formatted())")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                if !extensionSummary.description.isEmpty {
                    Text(extensionSummary.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        } icon: {
            ServiceIcon(icon: extensionSummary.icon, name: extensionSummary.name, size: iconSize)
        }
    }
}
