import CohesionCore
import CohesionUI
import SwiftUI

/// What the registries offer, as the web's Browse tab: a search over every
/// extension granted `registry`, then a section per registry, leaving out
/// what's installed. Install… opens the review of the real script.
struct BrowseExtensionsView: View {
    @Environment(AppModel.self) private var model

    @State private var query = ""
    /// `nil` until the first search answers.
    @State private var sections: [RegistrySection]?
    /// Why the last search failed, until one succeeds.
    @State private var searchError: String?
    /// The query last searched, so only typing waits before searching.
    @State private var searched: String?
    /// The identifiers of the installed extensions, which aren't offered.
    @State private var installed: Set<String> = []
    @State private var review: ExtensionReview?

    var body: some View {
        List {
            if let searchError, sections == nil {
                ContentUnavailableView {
                    Label("Couldn’t Search", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(searchError)
                } actions: {
                    Button("Try Again") { Task { await search() } }
                }
                .listRowBackground(Color.clear)
            } else if let sections {
                if sections.isEmpty {
                    ContentUnavailableView(
                        "No Registries",
                        systemImage: "storefront",
                        description: Text("No registries yet. A registry is an extension that lists others: install one from a file, then turn on “Offer extensions to browse” on its page.")
                    )
                    .listRowBackground(Color.clear)
                }
                ForEach(sections) { section in
                    registry(section)
                }
            } else {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .searchable(text: $query, prompt: "Search Extensions")
        .navigationTitle("Browse Extensions")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadInstalled() }
        .task(id: trimmedQuery) { await search() }
        .refreshable {
            searched = nil
            await search()
        }
        .reviewsExtensions($review, reload: loadInstalled)
    }

    @ViewBuilder
    private func registry(_ section: RegistrySection) -> some View {
        Section {
            if let error = section.error {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Couldn’t reach this registry.")
                    Text(error)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            } else {
                let offered = section.results.filter { !installed.contains($0.manifest.identifier) }
                ForEach(offered, id: \.sourceURL) { result in
                    RegistryRow(result: result) {
                        review = ExtensionReview(source: .registry(result))
                    }
                }
                if offered.isEmpty {
                    Text(trimmedQuery.isEmpty ? "Everything it lists is installed." : "No matches.")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(section.name)
        } footer: {
            if let searchError, section.id == sections?.first?.id {
                Text(searchError)
                    .foregroundStyle(.red)
            }
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    private func loadInstalled() async {
        guard let client = model.client else { return }
        do {
            installed = Set(try await client.listExtensions().map(\.scriptIdentifier))
        } catch {
            // Without the list nothing is hidden; installing an installed one reviews it as an update.
        }
    }

    /// Searches the registries; typing waits a moment first, as the web's
    /// search does, so each keystroke doesn't ask them.
    private func search() async {
        guard let client = model.client else { return }
        let query = trimmedQuery
        if let searched, searched != query {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
        }
        searched = query
        do {
            sections = try await client.searchRegistries(for: query)
            searchError = nil
        } catch where !Task.isCancelled {
            searchError = error.localizedDescription
        } catch {}
    }
}

/// A registry's extension: its icon, name and version over its author and
/// description, and Install….
private struct RegistryRow: View {
    let result: RegistryResult
    let onInstall: () -> Void

    var body: some View {
        let manifest = result.manifest
        HStack(spacing: 12) {
            ServiceIcon(icon: manifest.icon, name: manifest.name, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(manifest.name)
                        .lineLimit(1)
                    Text(manifest.version, format: .number)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                if !detail.isEmpty {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Button("Install…", action: onInstall)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Install \(manifest.name)")
        }
    }

    /// "By Someone · What it does", each part only when there is one.
    private var detail: String {
        let manifest = result.manifest
        return [
            manifest.author.flatMap { $0.isEmpty ? nil : "By \($0)" },
            manifest.description.flatMap { $0.isEmpty ? nil : $0 },
        ]
        .compactMap(\.self)
        .joined(separator: " · ")
    }
}
