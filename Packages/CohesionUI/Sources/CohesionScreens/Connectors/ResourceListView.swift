import CohesionCore
import CohesionUI
import SwiftUI

/// One kind's resources in a workspace, as the web's page for it lists
/// them: filtered by title and, once they come from more than one
/// account, by account; sorted by title, last update or a metadata key
/// the kind's connector declares. Refresh asks the services for the
/// latest copies, and Import… brings in more.
struct ResourceListView: View {
    let workspaceID: Int
    let kind: ConnectorKind
    /// Every connector account, for each resource's.
    let accounts: [ConnectorAccount]
    /// Which says whether a client's account is online.
    let clients: [Client]

    @Environment(AppModel.self) private var model

    @State private var resources: [Resource] = []
    @State private var isLoaded = false
    @State private var query = ""
    /// The account the list is narrowed to; `nil` for all of them.
    @State private var accountID: Int?
    @State private var order: ResourceOrder
    @State private var isRefreshing = false
    @State private var isImporting = false
    @State private var notice: Toast?
    @State private var error: (any Error)?

    init(workspaceID: Int, kind: ConnectorKind, accounts: [ConnectorAccount], clients: [Client]) {
        self.workspaceID = workspaceID
        self.kind = kind
        self.accounts = accounts
        self.clients = clients
        _order = State(initialValue: ResourceOrder.remembered(for: kind))
    }

    var body: some View {
        List(shown) { resource in
            NavigationLink {
                ResourceView(workspaceID: workspaceID, resourceID: resource.id, kind: kind)
            } label: {
                ResourceRow(resource: resource, connector: kind.connector, account: showsAccounts ? account(resource) : nil)
            }
        }
        .overlay {
            if !isLoaded {
                ProgressView()
            } else if resources.isEmpty {
                ContentUnavailableView {
                    Label("No \(kind.kind.plural)", systemImage: "square.stack.3d.down.right")
                } description: {
                    Text("No \(kind.kind.plural.lowercased()) yet.")
                } actions: {
                    Button("Import…") { isImporting = true }
                }
            } else if shown.isEmpty {
                ContentUnavailableView.search
            }
        }
        .searchable(text: $query, prompt: "Filter by title")
        .navigationTitle(kind.kind.plural)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Import…", systemImage: "square.and.arrow.down") { isImporting = true }
            }
            ToolbarItem(placement: .primaryAction) {
                if isRefreshing {
                    ProgressView()
                } else {
                    Button("Refresh", systemImage: "arrow.clockwise", action: refresh)
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                sortMenu
            }
            if showsAccounts {
                ToolbarItem(placement: .secondaryAction) {
                    accountMenu
                }
            }
        }
        .sizedSheet(isPresented: $isImporting) {
            ImportResourcesView(workspaceID: workspaceID, kind: kind, accounts: accounts, clients: clients)
        }
        .task(id: order) { await watch() }
        .onChange(of: order) { order.remember(for: kind) }
        .refreshable { await load(.asked) }
        .errorAlert($error)
        .toast($notice)
    }

    /// The resources the filters leave.
    private var shown: [Resource] {
        let query = query.trimmingCharacters(in: .whitespaces)
        return resources.filter { resource in
            (accountID == nil || resource.accountID == accountID)
                && (query.isEmpty || resource.title.localizedStandardContains(query))
        }
    }

    /// Each account the resources came from, once, by description.
    private var sources: [ConnectorAccount] {
        var seen = Set<Int>()
        return resources.compactMap { resource in
            seen.insert(resource.accountID).inserted ? account(resource) : nil
        }
    }

    /// Whether the resources come from more than one account, so each
    /// row says which and the list narrows to one.
    private var showsAccounts: Bool { sources.count > 1 }

    private func account(_ resource: Resource) -> ConnectorAccount? {
        accounts.first { $0.id == resource.accountID }
    }

    /// Title, last update, then the keys the kind's connector declares,
    /// then a direction named for the key.
    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: Binding {
                order.sort
            } set: {
                order = ResourceOrder(sort: $0, descending: $0 == .lastUpdated)
            }) {
                ForEach(ResourceSort.options(for: kind.connector), id: \.self) { Text($0.label).tag($0) }
            }
            Picker("Direction", selection: $order.descending) {
                Text(order.sort.directions.ascending).tag(false)
                Text(order.sort.directions.descending).tag(true)
            }
        } label: {
            Label("Sort By", systemImage: "arrow.up.arrow.down")
            Text(order.sort.label)
        }
    }

    private var accountMenu: some View {
        Menu {
            Picker("Account", selection: $accountID) {
                Text("All").tag(Int?.none)
                ForEach(sources) { Text($0.description).tag(Optional($0.id)) }
            }
        } label: {
            Label("Account", systemImage: "person.crop.circle")
            Text(sources.first { $0.id == accountID }?.description ?? "All")
        }
    }

    /// Keeps the list current while it is shown; the stream also yields
    /// once on connecting, which does the first load.
    private func watch() async {
        guard let client = model.client else { return }
        let workspaceID = workspaceID
        for await origin in client.loads(matching: { $0 == .resources(workspaceID: workspaceID) }) {
            await load(origin)
        }
    }

    private func load(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client else { return }
        await origin.run {
            let loaded = try await client.listResources(
                of: kind,
                in: workspaceID,
                sort: order.sort,
                descending: order.descending
            )
            withAnimation {
                resources = loaded
                isLoaded = true
                // The account filtered by may have nothing left.
                if !sources.contains(where: { $0.id == accountID }) { accountID = nil }
            }
        } failed: { self.error = $0 }
    }

    /// Asks each connector for the latest copy of every resource in the
    /// workspace, and says what changed.
    private func refresh() {
        guard let client = model.client else { return }
        isRefreshing = true
        Task {
            do {
                let summary = try await client.refreshResources(in: workspaceID)
                notice = summary.toast
            } catch {
                self.error = error
            }
            isRefreshing = false
        }
    }
}

/// A resource's connector icon and title, with its account when the list
/// mixes several, and when it last changed at its service.
private struct ResourceRow: View {
    let resource: Resource
    let connector: Connector
    /// Shown only when the list mixes accounts.
    let account: ConnectorAccount?

    @ScaledMetric(relativeTo: .body) private var iconSize = 24

    var body: some View {
        HStack(spacing: 12) {
            ServiceIcon(icon: connector.icon, name: connector.title, size: iconSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(resource.title)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    if let account {
                        Text(account.description)
                    }
                    if account != nil, resource.lastUpdated != nil {
                        Text("·")
                    }
                    if let lastUpdated = resource.lastUpdated {
                        Text(lastUpdated, format: .relative(presentation: .named))
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
    }
}

/// The order a kind's resources list in.
struct ResourceOrder: Hashable {
    var sort: ResourceSort
    var descending: Bool

    /// Most recently updated first.
    static let standard = ResourceOrder(sort: .lastUpdated, descending: true)

    private static let key = "resourceOrders"

    /// The order `kind`'s list last had, if its connector still declares
    /// the key; most recently updated first at first.
    static func remembered(for kind: ConnectorKind) -> ResourceOrder {
        let stored = UserDefaults.standard.dictionary(forKey: key)?[String(kind.id)] as? [String: Any]
        guard let sort = (stored?["sort"] as? String).flatMap({ ResourceSort(wireValue: $0) }),
              ResourceSort.options(for: kind.connector).contains(sort)
        else { return .standard }
        return ResourceOrder(sort: sort, descending: stored?["descending"] as? Bool ?? false)
    }

    func remember(for kind: ConnectorKind) {
        var orders = UserDefaults.standard.dictionary(forKey: Self.key) ?? [:]
        orders[String(kind.id)] = ["sort": sort.wireValue, "descending": descending]
        UserDefaults.standard.set(orders, forKey: Self.key)
    }
}

extension ResourceSort {
    /// Title, last update, then each metadata key `connector` declares
    /// but its address, which nothing sorts by.
    static func options(for connector: Connector) -> [ResourceSort] {
        [.title, .lastUpdated] + connector.metadataKeys.filter { $0 != .url }.map(ResourceSort.metadata)
    }

    var label: LocalizedStringKey {
        switch self {
        case .title: "Title"
        case .lastUpdated: "Last Updated"
        case .metadata(let key):
            switch key {
            case .dateCreated: "Date Created"
            case .dateModified: "Date Modified"
            case .dateDue: "Due Date"
            case .dateStart: "Start Date"
            case .dateEnd: "End Date"
            case .author: "Author"
            case .url: "Address"
            case .location: "Location"
            case .folder: "Folder"
            case .category: "Category"
            case .keywords: "Tags"
            case .status: "Status"
            }
        }
    }

    /// The ascending and descending directions, named for this key.
    var directions: (ascending: LocalizedStringKey, descending: LocalizedStringKey) {
        switch self {
        case .lastUpdated: ("Oldest First", "Newest First")
        case .metadata(.dateCreated), .metadata(.dateModified), .metadata(.dateDue), .metadata(.dateStart),
             .metadata(.dateEnd):
            ("Earliest First", "Latest First")
        default: ("A to Z", "Z to A")
        }
    }
}

extension ResourceRefreshSummary {
    /// What the refresh did, as the web's toast says it.
    var toast: Toast {
        if updated == 0 && failed == 0 {
            return Toast(kind: .info, message: "Everything is up to date.")
        }
        let message = failed > 0 ? "Updated \(updated) of \(checked); \(failed) failed." : "Updated \(updated) of \(checked)."
        return Toast(kind: failed > 0 ? .error : .info, message: message)
    }
}
