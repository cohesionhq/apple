import CohesionCore
import CohesionUI
import SwiftUI

/// An extension to review before installing it: a registry's entry, whose
/// script cohesiond fetches once the review opens, or a script from a file
/// or the clipboard it has already read.
struct ExtensionReview: Identifiable {
    enum Source {
        case registry(RegistryResult)
        /// `origin` is the file's name, or `nil` for the clipboard.
        case script(ExtensionPreview, origin: String?)
    }

    let id = UUID()
    let source: Source
}

/// What installing did, for the screen that opened the review.
enum ExtensionInstall {
    /// A new extension, `nil` when the list no longer shows it.
    case added(ExtensionSummary?, name: String)
    case updated(name: String, version: Int)
}

/// The review before installing, as the web's: the extension's icon, name
/// and description, what it will be able to do and when it runs, then its
/// identifier, where it came from and its script. A registry's entry
/// marks where the script differs from what the registry listed. Install
/// sends back exactly the script shown.
struct ReviewExtensionView: View {
    let review: ExtensionReview
    /// Called once the extension is installed, before the sheet closes.
    let onInstall: (ExtensionInstall) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    /// The script as cohesiond read it; `nil` while a registry's loads.
    @State private var preview: ExtensionPreview?
    /// Why the registry's script couldn't be fetched.
    @State private var loadError: String?
    @State private var isInstalling = false
    /// Why cohesiond refused the script, shown under it.
    @State private var installError: String?
    @State private var error: (any Error)?

    var body: some View {
        NavigationStack {
            Form {
                hero
                if let loadError {
                    Section {
                        Label("Couldn’t fetch the script: \(loadError)", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                        Button("Try Again") { Task { await load() } }
                    }
                } else if let preview {
                    contents(of: preview)
                } else {
                    Section {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Fetching the script…")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isInstalling {
                        ProgressView()
                    } else {
                        Button(isUpdate ? "Update" : "Install", systemImage: "checkmark", role: .confirm, action: install)
                            .disabled(preview == nil)
                    }
                }
            }
        }
        .interactiveDismissDisabled(isInstalling)
        .task { await load() }
        .errorAlert($error)
    }

    /// The icon on top, then "Add … to Cohesion" (or "Update …") over the
    /// author and version, from the registry's listing until the script is read.
    private var hero: some View {
        Section {
            VStack(spacing: 8) {
                ServiceIcon(icon: manifest.icon, name: manifest.name, size: 64)
                Text(isUpdate ? "Update \(manifest.name)" : "Add \(manifest.name) to Cohesion")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                Text(byline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let description = preview?.manifest.description, !description.isEmpty {
                    Text(description)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func contents(of preview: ExtensionPreview) -> some View {
        let vocabulary = model.vocabulary
        let comparison = comparison(of: preview)
        if !comparison.isEmpty {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("The script differs from what the registry listed:")
                        ForEach(comparison.lines, id: \.self) { line in
                            Text(line)
                                .font(.footnote)
                        }
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .foregroundStyle(.orange)
            }
        }
        Section {
            if preview.manifest.permissions.isEmpty {
                Text("None.")
                    .foregroundStyle(.secondary)
            }
            ForEach(preview.manifest.permissions.sorted { vocabulary.rank(of: $0) < vocabulary.rank(of: $1) }, id: \.self) { permission in
                let wording = vocabulary.wording(of: permission)
                LabeledContent {
                    if comparison.undeclaredPermissions.contains(permission) { NotListedBadge() }
                } label: {
                    Label {
                        Text(wording.title)
                        if let description = wording.description {
                            Text(description)
                        }
                    } icon: {
                        Image(systemName: permission.systemImage)
                    }
                }
            }
        } header: {
            Text("What It Asks For")
        }
        if !preview.manifest.hooks.isEmpty {
            Section {
                ForEach(preview.manifest.hooks.sorted { vocabulary.rank(of: $0) < vocabulary.rank(of: $1) }, id: \.self) { hook in
                    LabeledContent("When \(vocabulary.extensionClause(of: hook))") {
                        if comparison.undeclaredHooks.contains(hook) { NotListedBadge() }
                    }
                }
            } header: {
                Text("When It Runs")
            } footer: {
                note(on: preview)
            }
        }
        Section {
            LabeledContent("Identifier") {
                Text(preview.manifest.identifier)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
            }
            if let origin {
                LabeledContent("From") {
                    Text(origin)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
            }
            NavigationLink("Script") {
                ScriptView(script: preview.script)
            }
        } header: {
            Text("Details")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                // With no hooks, the note goes here rather than under them.
                if preview.manifest.hooks.isEmpty { note(on: preview) }
                if let installError {
                    Text(installError)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    /// What happens to the access the extension gets: kept by an update, or
    /// off until it's enabled on the extension's page.
    @ViewBuilder
    private func note(on preview: ExtensionPreview) -> some View {
        let manifest = preview.manifest
        if let installed = preview.installed {
            Text("Replaces version \(installed.version) and keeps the access you gave it.")
        } else if !manifest.permissions.isEmpty || !manifest.hooks.isEmpty {
            Text("\(manifest.name) will be inactive until you enable its \(grantNoun(permissions: manifest.permissions.count, hooks: manifest.hooks.count)) on its page.")
        }
    }

    /// What to show: the script's own manifest once it's read, else the
    /// registry's listing.
    private var manifest: ExtensionManifest {
        if let preview { return preview.manifest }
        switch review.source {
        case .registry(let result): return result.manifest
        case .script(let preview, _): return preview.manifest
        }
    }

    /// Whether installing replaces an installed extension.
    private var isUpdate: Bool {
        preview?.installed != nil
    }

    /// "By Someone · Version 3", without the author when there is none.
    private var byline: String {
        let version = "Version \(manifest.version)"
        guard let author = manifest.author, !author.isEmpty else { return version }
        return "By \(author) · \(version)"
    }

    /// Where the script came from: the registry's URL or the file's name.
    private var origin: String? {
        switch review.source {
        case .registry(let result): result.sourceURL
        case .script(_, let origin): origin
        }
    }

    /// Where the script differs from its registry's listing; nothing for a
    /// file or the clipboard, which have no listing.
    private func comparison(of preview: ExtensionPreview) -> Comparison {
        guard case .registry(let result) = review.source else { return Comparison() }
        let listed = result.manifest
        let real = preview.manifest
        var lines: [String] = []
        // A missing author or description reads as empty.
        let fields: [(label: String, listed: String, real: String)] = [
            ("Name", listed.name, real.name),
            ("Version", String(listed.version), String(real.version)),
            ("Author", listed.author ?? "", real.author ?? ""),
            ("Identifier", listed.identifier, real.identifier),
            ("Description", listed.description ?? "", real.description ?? ""),
        ]
        for field in fields where field.listed != field.real {
            lines.append("\(field.label): listed as “\(field.listed.isEmpty ? "(nothing)" : field.listed)”")
        }
        let vocabulary = model.vocabulary
        // Listed by the registry but not asked for: harmless, but still a mismatch.
        let dropped = listed.permissions.filter { !real.permissions.contains($0) }.map { vocabulary.wording(of: $0).title }
            + listed.hooks.filter { !real.hooks.contains($0) }.map { "When \(vocabulary.extensionClause(of: $0))" }
        if !dropped.isEmpty {
            lines.append("Listed, but the script doesn’t ask for: \(dropped.formatted(.list(type: .and)))")
        }
        // Asked for by the script, not listed by the registry.
        let undeclaredPermissions = Set(real.permissions.filter { !listed.permissions.contains($0) })
        let undeclaredHooks = Set(real.hooks.filter { !listed.hooks.contains($0) })
        return Comparison(lines: lines, undeclaredPermissions: undeclaredPermissions, undeclaredHooks: undeclaredHooks)
    }

    /// How the script read differs from what its registry listed.
    private struct Comparison {
        /// The listed fields that differ, and what was listed but not asked for.
        var lines: [String] = []
        var undeclaredPermissions: Set<ExtensionPermissionKind> = []
        var undeclaredHooks: Set<HookKind> = []

        var isEmpty: Bool {
            lines.isEmpty && undeclaredPermissions.isEmpty && undeclaredHooks.isEmpty
        }
    }

    private func load() async {
        switch review.source {
        case .script(let preview, _):
            self.preview = preview
        case .registry(let result):
            guard let client = model.client else { return }
            loadError = nil
            do {
                preview = try await client.previewExtension(at: result.sourceURL)
            } catch where !Task.isCancelled {
                loadError = error.localizedDescription
            } catch {}
        }
    }

    private func install() {
        guard let client = model.client, let preview else { return }
        isInstalling = true
        installError = nil
        Task {
            defer { isInstalling = false }
            do {
                try await client.installExtension(preview.script, replacing: preview.installed != nil)
                let manifest = preview.manifest
                if preview.installed != nil {
                    onInstall(.updated(name: manifest.name, version: manifest.version))
                } else {
                    // The reply carries nothing, so the new extension is found in the list.
                    let added = try? await client.listExtensions().first { $0.scriptIdentifier == manifest.identifier }
                    onInstall(.added(added, name: manifest.name))
                }
                dismiss()
            } catch let error as ServerError where error.code == ServerError.validationFailed {
                installError = error.message
            } catch {
                self.error = error
            }
        }
    }
}

/// Beside a permission or hook the script asks for that its registry didn't list.
private struct NotListedBadge: View {
    var body: some View {
        Text("Not Listed")
            .font(.caption.weight(.medium))
            .foregroundStyle(.orange)
    }
}

/// An extension's script, read-only.
private struct ScriptView: View {
    let script: String

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            Text(script)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("Script")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension View {
    /// Presents `review` in a sheet. Once it installs, a new extension's
    /// page opens, since it starts with everything off, and an update says
    /// so in a toast; `reload` runs after either, and after the opened
    /// page uninstalls.
    func reviewsExtensions(_ review: Binding<ExtensionReview?>, reload: @escaping () async -> Void) -> some View {
        modifier(ReviewsExtensions(review: review, reload: reload))
    }
}

private struct ReviewsExtensions: ViewModifier {
    @Binding var review: ExtensionReview?
    let reload: () async -> Void

    /// The extension just added, whose page is pushed.
    @State private var added: ExtensionSummary?
    @State private var notice: Toast?
    @State private var installs = 0

    func body(content: Content) -> some View {
        content
            .sizedSheet(item: $review) { review in
                ReviewExtensionView(review: review) { install in
                    installs += 1
                    switch install {
                    case .added(let summary?, _):
                        added = summary
                    case .added(nil, let name):
                        notice = Toast(kind: .info, message: "Installed \(name).")
                    case .updated(let name, let version):
                        notice = Toast(kind: .info, message: "Updated \(name) to \(version).")
                    }
                    Task { await reload() }
                }
            }
            .navigationDestination(item: $added) { summary in
                ExtensionView(extensionSummary: summary) {
                    Task { await reload() }
                }
            }
            .toast($notice)
            .sensoryFeedback(.success, trigger: installs)
    }
}
