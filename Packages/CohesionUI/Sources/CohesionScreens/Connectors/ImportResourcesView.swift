import CohesionCore
import CohesionUI
import SwiftUI

/// Imports items of one kind into the workspace from its connector's
/// accounts, as the web's import dialog does: the account (when there are
/// several) and one of its groups or all, then a search over what it
/// offers. Import brings an item in, and its row turns to Imported in
/// place. A client's account lists what its client offered, but imports
/// only while the client is online.
struct ImportResourcesView: View {
    let workspaceID: Int
    let kind: ConnectorKind
    /// Every connector account; those of the kind's connector that can
    /// import are offered.
    let accounts: [ConnectorAccount]
    /// Which says whether a client's account is online.
    let clients: [Client]

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    /// The chosen account; the first until another is picked.
    @State private var accountID: Int?
    /// The chosen group; `nil` for all of them.
    @State private var unitID: String?
    /// `nil` while the chosen account's groups load.
    @State private var units: [OrganizationUnit]?
    @State private var query = ""
    /// `nil` until the first search of the chosen account answers.
    @State private var results: [ImportableResource]?
    /// Why the last search failed, until one succeeds.
    @State private var searchError: String?
    /// The query last searched, so only typing waits before searching.
    @State private var searched: String?
    /// The identifiers of the items being imported.
    @State private var importing: Set<String> = []
    @State private var notice: Toast?
    @State private var error: (any Error)?

    var body: some View {
        NavigationStack {
            Group {
                if offered.isEmpty {
                    ContentUnavailableView(
                        "No Accounts",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("No accounts to import from yet.")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Import from \(kind.connector.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .errorAlert($error)
        .toast($notice)
    }

    private var list: some View {
        List {
            Section {
                if offered.count > 1 {
                    Picker("Account", selection: Binding { account?.id } set: { accountID = $0 }) {
                        ForEach(offered) { account in
                            Text(label(of: account)).tag(Optional(account.id))
                        }
                    }
                }
                Picker("Group", selection: $unitID) {
                    Text("All").tag(String?.none)
                    ForEach(units ?? []) { Text($0.display).tag(Optional($0.id)) }
                }
                .disabled(units == nil)
            } footer: {
                if let account, isOffline {
                    Text("\(account.description) is offline. Its items import once it reconnects.")
                }
            }
            results(of: account)
        }
        .searchable(text: $query, prompt: account.map { "Search \($0.description)" } ?? "Search")
        .task(id: account?.id) { await loadUnits() }
        .task(id: Search(accountID: account?.id, unitID: unitID, query: trimmedQuery)) { await search() }
    }

    @ViewBuilder
    private func results(of account: ConnectorAccount?) -> some View {
        if let searchError, results == nil {
            ContentUnavailableView {
                Label("Couldn’t Search", systemImage: "exclamationmark.triangle")
            } description: {
                Text(searchError)
            } actions: {
                Button("Try Again") { Task { await search() } }
            }
            .listRowBackground(Color.clear)
        } else if let results {
            Section {
                ForEach(results) { row in
                    ImportableRow(
                        row: row,
                        connector: kind.connector,
                        isImporting: importing.contains(row.identifier)
                    ) {
                        importResource(row)
                    }
                }
                if results.isEmpty {
                    Text(trimmedQuery.isEmpty ? "Nothing to import." : "No matches.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                if let searchError {
                    Text(searchError)
                        .foregroundStyle(.red)
                        .textCase(nil)
                }
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

    /// The accounts of the kind's connector whose items can be imported.
    private var offered: [ConnectorAccount] {
        accounts.filter { $0.importable && $0.connector.id == kind.connector.id }
    }

    /// The chosen account, or the first while none is, or the chosen one
    /// has gone.
    private var account: ConnectorAccount? {
        offered.first { $0.id == accountID } ?? offered.first
    }

    /// Whether the chosen account is a client's whose client isn't online.
    private var isOffline: Bool {
        account.map { !$0.isOnline(clients: clients) } ?? false
    }

    /// An account as the picker names it, with a client's online state.
    private func label(of account: ConnectorAccount) -> String {
        guard case .client = account.host else { return account.description }
        return "\(account.description) · \(account.isOnline(clients: clients) ? "Online" : "Offline")"
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    /// What a search depends on; a change to any of it searches again.
    private struct Search: Hashable {
        let accountID: Int?
        let unitID: String?
        let query: String
    }

    /// A new account has its own groups, and its own results.
    private func loadUnits() async {
        unitID = nil
        units = nil
        results = nil
        searchError = nil
        searched = nil
        guard let client = model.client, let account else { return }
        // An offline client can't list its groups; the footer says it's offline.
        if isOffline {
            units = []
            return
        }
        do {
            units = try await client.listOrganizationUnits(of: account)
        } catch where !Task.isCancelled {
            units = []
            self.error = error
        } catch {}
    }

    /// Searches the chosen account; typing waits a moment first, as the
    /// web's search does, so each keystroke doesn't ask the service.
    private func search() async {
        guard let client = model.client, let account else { return }
        let query = trimmedQuery
        if let searched, searched != query {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
        }
        searched = query
        do {
            let found = try await client.searchImportableResources(
                of: account,
                kind: kind.kind.id,
                unit: unitID,
                search: query.isEmpty ? nil : query,
                in: workspaceID
            )
            withAnimation {
                results = found
                searchError = nil
            }
        } catch where !Task.isCancelled {
            searchError = error.localizedDescription
        } catch {}
    }

    private func importResource(_ row: ImportableResource) {
        guard let client = model.client, let account else { return }
        importing.insert(row.identifier)
        Task {
            do {
                let resource = try await client.importResource(row.identifier, from: account, into: workspaceID)
                if let index = results?.firstIndex(where: { $0.identifier == row.identifier }) {
                    withAnimation { results?[index].imported = true }
                }
                notice = Toast(kind: .info, message: "Imported “\(resource.title)”.")
            } catch {
                self.error = error
            }
            importing.remove(row.identifier)
        }
    }
}

/// An item an account offers: its title and when it last changed, then
/// Import, or Imported once the workspace has it.
private struct ImportableRow: View {
    let row: ImportableResource
    let connector: Connector
    let isImporting: Bool
    let importResource: () -> Void

    @ScaledMetric(relativeTo: .body) private var iconSize = 24

    var body: some View {
        HStack(spacing: 12) {
            ServiceIcon(icon: connector.icon, name: connector.title, size: iconSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .lineLimit(2)
                if let lastUpdated = row.lastUpdated {
                    Text("Updated \(lastUpdated, format: .relative(presentation: .named))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if row.imported {
                Text("Imported")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if isImporting {
                ProgressView()
            } else {
                Button("Import", action: importResource)
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Import \(row.title)")
            }
        }
        .sensoryFeedback(.success, trigger: row.imported) { _, imported in imported }
    }
}
