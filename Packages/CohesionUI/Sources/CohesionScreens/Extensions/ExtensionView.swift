import CohesionCore
import CohesionUI
import SwiftUI

/// An installed extension: what it is, its permissions and hooks as
/// switches, its identifier and run order, and uninstalling it. A fresh
/// install has everything off, so it says it's inactive until something is
/// enabled.
struct ExtensionView: View {
    let extensionSummary: ExtensionSummary
    /// Called once the extension is uninstalled, before the view goes back.
    let onUninstall: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var permissions: [ExtensionPermission] = []
    @State private var hooks: [ExtensionHook] = []
    @State private var isLoaded = false
    /// The permission or hook whose change is on its way, so its switch
    /// waits for the reply.
    @State private var pending: Grant?
    @State private var isConfirmingUninstall = false
    @State private var error: (any Error)?

    /// A permission or a hook, the two things a switch here turns on.
    private enum Grant: Hashable {
        case permission(ExtensionPermissionKind)
        case hook(HookKind)
    }

    var body: some View {
        let vocabulary = model.vocabulary
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        ServiceIcon(icon: extensionSummary.icon, name: extensionSummary.name, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(extensionSummary.name)
                                .font(.headline)
                            Text(byline)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !extensionSummary.description.isEmpty {
                        Text(extensionSummary.description)
                            .foregroundStyle(.secondary)
                    }
                }
                if let inert {
                    Label(
                        "\(extensionSummary.name) is inactive until you enable its \(inert) below.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.orange)
                }
            }
            if isLoaded {
                Section("Permissions") {
                    if permissions.isEmpty {
                        Text("It asks for no permissions.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(permissions.sorted { vocabulary.rank(of: $0.permission) < vocabulary.rank(of: $1.permission) }) { permission in
                        let wording = vocabulary.wording(of: permission.permission)
                        Toggle(isOn: binding(for: .permission(permission.permission), enabled: permission.enabled)) {
                            Label {
                                Text(wording.title)
                                if let description = wording.description {
                                    Text(description)
                                }
                            } icon: {
                                Image(systemName: permission.permission.systemImage)
                            }
                        }
                        .disabled(pending == .permission(permission.permission))
                    }
                }
                Section {
                    if hooks.isEmpty {
                        Text("It runs on no hooks.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(hooks.sorted { vocabulary.rank(of: $0.hook) < vocabulary.rank(of: $1.hook) }) { hook in
                        Toggle(
                            "When \(vocabulary.extensionClause(of: hook.hook))",
                            isOn: binding(for: .hook(hook.hook), enabled: hook.enabled)
                        )
                        .disabled(pending == .hook(hook.hook))
                    }
                } header: {
                    Text("Hooks")
                } footer: {
                    Text("A change applies the next time it fires.")
                }
            }
            Section("Details") {
                LabeledContent("Identifier") {
                    Text(extensionSummary.scriptIdentifier)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
                LabeledContent("Run order", value: extensionSummary.priority, format: .number)
            }
            Section {
                Button("Uninstall", role: .destructive) { isConfirmingUninstall = true }
                    .confirmationDialog(
                        "Uninstall \(extensionSummary.name)?",
                        isPresented: $isConfirmingUninstall,
                        titleVisibility: .visible
                    ) {
                        Button("Uninstall", role: .destructive, action: uninstall)
                    } message: {
                        Text("It stops running and loses the access you gave it.")
                    }
            }
        }
        .overlay {
            if !isLoaded { ProgressView() }
        }
        .navigationTitle(extensionSummary.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load(.asked) }
        .refreshable { await load(.asked) }
        .errorAlert($error)
    }

    /// "Version 3 · by Someone", without the author when there is none.
    private var byline: String {
        let version = "Version \(extensionSummary.version)"
        return extensionSummary.author.isEmpty ? version : "\(version) · by \(extensionSummary.author)"
    }

    /// What to enable, while everything it asks for is off, else nil:
    /// "permissions and hooks", or just one of them.
    private var inert: String? {
        guard isLoaded, !(permissions.isEmpty && hooks.isEmpty),
            !permissions.contains(where: \.enabled), !hooks.contains(where: \.enabled)
        else { return nil }
        return grantNoun(permissions: permissions.count, hooks: hooks.count)
    }

    private func load(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client else { return }
        await origin.run {
            async let permissions = client.listPermissions(of: extensionSummary)
            async let hooks = client.listHooks(of: extensionSummary)
            (self.permissions, self.hooks) = try await (permissions, hooks)
            isLoaded = true
        } failed: { self.error = $0 }
    }

    /// A switch for `grant` that sends the change, then shows it: the reply
    /// carries nothing, so the row is updated in place.
    private func binding(for grant: Grant, enabled: Bool) -> Binding<Bool> {
        Binding {
            enabled
        } set: { enabled in
            guard let client = model.client else { return }
            pending = grant
            Task {
                do {
                    switch grant {
                    case .permission(let kind):
                        try await client.setPermission(kind, of: extensionSummary, enabled: enabled)
                        if let index = permissions.firstIndex(where: { $0.permission == kind }) {
                            permissions[index].enabled = enabled
                        }
                    case .hook(let kind):
                        try await client.setHook(kind, of: extensionSummary, enabled: enabled)
                        if let index = hooks.firstIndex(where: { $0.hook == kind }) {
                            hooks[index].enabled = enabled
                        }
                    }
                } catch {
                    self.error = error
                }
                pending = nil
            }
        }
    }

    private func uninstall() {
        guard let client = model.client else { return }
        Task {
            do {
                try await client.uninstall(extensionSummary)
                onUninstall()
                dismiss()
            } catch {
                self.error = error
            }
        }
    }
}

/// What to enable before an extension with `permissions` and `hooks` runs,
/// as the copy around a fresh install names it: "permissions and hooks", or
/// just one of them.
func grantNoun(permissions: Int, hooks: Int) -> String {
    if permissions > 0 && hooks > 0 { return "permissions and hooks" }
    return permissions > 0 ? "permissions" : "hooks"
}
