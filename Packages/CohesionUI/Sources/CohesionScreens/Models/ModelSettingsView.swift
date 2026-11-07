import CohesionCore
import CohesionUI
import SwiftUI

/// Settings → Agents: tier defaults, endpoints with the models each offers,
/// spend limits and the catalog, as the web app's Agents settings show them.
public struct ModelSettingsView: View {
    @Environment(AppModel.self) private var model

    @State private var endpoints: [IntelligenceEndpoint] = []
    @State private var models: [EndpointModel] = []
    @State private var defaults: [IntelligenceDefault] = []
    @State private var catalog: [CatalogModel] = []
    /// `nil` from a cohesiond older than spend limits, which hides them.
    @State private var spend: [IntelligenceSpend]?
    @State private var isLoaded = false
    /// Counts loads, so only the latest one's results land.
    @State private var loads = 0
    @State private var isAddingEndpoint = false
    @State private var addingModelsTo: IntelligenceEndpoint?
    @State private var deletingEndpoint: IntelligenceEndpoint?
    /// The endpoint whose platform dashboard is being set, in an alert.
    @State private var editingUsage: IntelligenceEndpoint?
    @State private var usageURL = ""
    /// The period whose spend limit is being set, in an alert.
    @State private var editingLimit: IntelligenceSpend?
    @State private var limitAmount = ""
    @State private var error: (any Error)?

    public init() {}

    public var body: some View {
        Form {
            if isLoaded {
                defaultsSection
                ForEach(endpoints) { endpoint in
                    endpointSection(endpoint)
                }
                Section {
                    Button("Add Endpoint", systemImage: "plus") { isAddingEndpoint = true }
                } footer: {
                    Text(endpoints.isEmpty
                        ? "No endpoints yet. Add one to start using models."
                        : "The providers Cohesion reaches models through, and the models each offers.")
                }
                if let spend {
                    spendSection(spend)
                }
                Section {
                    NavigationLink {
                        CatalogView(models: $catalog, hasEndpoints: !endpoints.isEmpty)
                    } label: {
                        LabeledContent("Catalog", value: catalog.count.formatted())
                    }
                } footer: {
                    Text("What the models.dev catalog lists for your endpoints' providers, priced per million tokens.")
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Agents")
        .navigationBarTitleDisplayMode(.inline)
        .task { await watch() }
        .refreshable { await load(.asked) }
        .sizedSheet(isPresented: $isAddingEndpoint) {
            // cohesiond imports the preset's default model with it.
            EndpointForm { _ in Task { await load() } }
        }
        .sizedSheet(item: $addingModelsTo) { endpoint in
            EndpointModelsForm(
                endpoint: endpoint,
                offered: models.filter { $0.endpointID == endpoint.id }.map(\.modelIdentifier)
            ) {
                Task { await load() }
            }
        }
        .confirmationDialog(
            "Delete \(deletingEndpoint?.name ?? "endpoint")?",
            isPresented: Binding(
                get: { deletingEndpoint != nil },
                set: { if !$0 { deletingEndpoint = nil } }
            ),
            titleVisibility: .visible,
            presenting: deletingEndpoint
        ) { endpoint in
            Button("Delete", role: .destructive) {
                run { try await $0.delete(endpoint) }
            }
        } message: { _ in
            Text("Its models go with it, and any default that uses one is unset.")
        }
        .alert("Platform Dashboard", isPresented: Binding {
            editingUsage != nil
        } set: {
            if !$0 { editingUsage = nil }
        }, presenting: editingUsage) { endpoint in
            TextField("https://…", text: $usageURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {}
            if endpoint.usageURL != nil {
                Button("Remove", role: .destructive) {
                    run { try await $0.setUsageURL(nil, of: endpoint) }
                }
            }
            Button("Save") {
                let url = usageURL.trimmingCharacters(in: .whitespaces)
                run { try await $0.setUsageURL(url.isEmpty ? nil : url, of: endpoint) }
            }
        } message: { endpoint in
            Text("Where you see what \(endpoint.name) has used.")
        }
        .alert(editingLimit.map { model.vocabulary.title(of: $0.period) } ?? "Spend Limit", isPresented: Binding {
            editingLimit != nil
        } set: {
            if !$0 { editingLimit = nil }
        }, presenting: editingLimit) { current in
            TextField("Amount in US dollars", text: $limitAmount)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) {}
            if current.limit != nil {
                Button("Remove Limit", role: .destructive) {
                    run { try await $0.clearSpendLimit(current.period) }
                }
            }
            let amount = typedAmount
            Button("Save") {
                if let amount { run { try await $0.setSpendLimit(current.period, to: amount) } }
            }
            .disabled(amount == nil)
        } message: { current in
            // "What model calls cost in the last 60 minutes: $1.20 spent of $5.00."
            let description = model.vocabulary.description(of: current.period)
            Text((description.map { "\($0): " } ?? "") + spentLine(current) + ".")
        }
        .errorAlert($error)
    }

    /// Each period's spend against its limit; tapping one sets the limit.
    private func spendSection(_ spend: [IntelligenceSpend]) -> some View {
        Section {
            ForEach(spend, id: \.period) { current in
                Button {
                    limitAmount = current.limit.map { $0.formatted(.number.precision(.fractionLength(2)).grouping(.never)) } ?? ""
                    editingLimit = current
                } label: {
                    LabeledContent {
                        Text(current.limit.map(usd) ?? "No Limit")
                    } label: {
                        Text(model.vocabulary.title(of: current.period))
                            .foregroundStyle(Color.primary)
                        Text(spentLine(current))
                            .monospacedDigit()
                        if current.reached {
                            Text("Reached")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .accessibilityHint("Sets the limit")
            }
        } header: {
            Text("Spend Limits")
        } footer: {
            Text("The most every model call together may cost, counted back from now. Once a limit is reached, agents call models only to answer your messages.")
        }
    }

    /// "$1.20 spent of $5.00", or "$1.20 spent" without a limit.
    private func spentLine(_ current: IntelligenceSpend) -> String {
        guard let limit = current.limit else { return "\(usd(current.spent)) spent" }
        return "\(usd(current.spent)) spent of \(usd(limit))"
    }

    /// The amount typed in the limit alert, without a leading "$"; `nil`
    /// until it reads as a number.
    private var typedAmount: Double? {
        var typed = limitAmount.trimmingCharacters(in: .whitespaces)
        if typed.hasPrefix("$") { typed.removeFirst() }
        return try? Double(typed, format: .number)
    }

    private var defaultsSection: some View {
        Section {
            ForEach(model.vocabulary.tiers, id: \.kind) { wording in
                let tier = wording.kind
                let current = defaults.first { $0.tier == tier }
                    .flatMap { tierDefault in models.first { $0.id == tierDefault.endpointModelID } }
                NavigationLink {
                    ModelPicker(
                        title: wording.title,
                        endpoints: endpoints,
                        models: models,
                        selection: current,
                        allowsNone: true
                    ) { picked in
                        run {
                            if let picked {
                                try await $0.setDefault(tier, to: picked)
                            } else {
                                try await $0.clearDefault(tier)
                            }
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(wording.title)
                        Text(current.map { title($0) } ?? "Not set")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Defaults")
        } footer: {
            Text("The model each kind of work uses when none is named.")
        }
    }

    /// `endpoint`'s provider, when its name doesn't say it, then the models it
    /// offers, which swipe to remove one, under its name, a link to its usage
    /// page and a menu to set that page or delete the endpoint.
    private func endpointSection(_ endpoint: IntelligenceEndpoint) -> some View {
        let offered = models.filter { $0.endpointID == endpoint.id }
        return Section {
            let provider = model.vocabulary.label(ofProvider: endpoint.providerIdentifier)
            let namesProvider = provider.caseInsensitiveCompare(endpoint.name) != .orderedSame
            if namesProvider || endpoint.isAccountEndpoint {
                VStack(alignment: .leading, spacing: 2) {
                    if namesProvider {
                        Text(provider)
                    }
                    if endpoint.isAccountEndpoint {
                        Text("Signed in with an account")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(offered) { endpointModel in
                modelRow(endpointModel)
                    .swipeActions {
                        Button("Remove", systemImage: "trash", role: .destructive) {
                            models.removeAll { $0.id == endpointModel.id }
                            run { try await $0.remove(endpointModel) }
                        }
                    }
            }
            if offered.isEmpty {
                Text("No models yet. Add some to pick them above.")
                    .foregroundStyle(.secondary)
            }
            Button("Add Models", systemImage: "plus") { addingModelsTo = endpoint }
        } header: {
            HStack {
                Text(endpoint.name)
                Spacer()
                Menu {
                    if let url = endpoint.usageURL {
                        Link(destination: url) {
                            Label("Open Platform Dashboard", systemImage: "arrow.up.right")
                        }
                    }
                    Button("Platform Dashboard…", systemImage: "chart.bar") {
                        usageURL = endpoint.usageURL?.absoluteString ?? ""
                        editingUsage = endpoint
                    }
                    Button("Delete…", systemImage: "trash", role: .destructive) {
                        deletingEndpoint = endpoint
                    }
                } label: {
                    // A 44pt target reaching into the header's margins, so
                    // the heading keeps its height.
                    Label("\(endpoint.name) Actions", systemImage: "ellipsis")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .padding(.vertical, -12)
                .padding(.trailing, -12)
            }
        }
    }

    /// One of an endpoint's models: its name over its identifier.
    private func modelRow(_ endpointModel: EndpointModel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(endpointModel.modelName)
            Text(endpointModel.modelIdentifier)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    /// `model`'s name with its endpoint's, such as "Claude Sonnet 5.5 · Anthropic".
    private func title(_ model: EndpointModel) -> String {
        let endpoint = endpoints.first { $0.id == model.endpointID }
        return endpoint.map { "\(model.modelName) · \($0.name)" } ?? model.modelName
    }

    /// Loads everything, then reloads it whenever cohesiond reports the
    /// endpoints, their models or the defaults changed while it's on screen.
    private func watch() async {
        guard let client = model.client else { return }
        await load(.asked)
        for await _ in client.changes(matching: { $0 == .intelligence }) {
            await load()
        }
    }

    private func load(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client else { return }
        loads += 1
        let load = loads
        await origin.run {
            let endpoints = try await client.listEndpoints()
            async let defaults = client.listIntelligenceDefaults()
            async let catalog = client.listCatalogModels()
            var models: [EndpointModel] = []
            for endpoint in endpoints {
                models += try await client.listModels(of: endpoint)
            }
            // A cohesiond older than spend limits doesn't know the command.
            let spend = try? await client.listIntelligenceSpend()
            let loaded = try await (endpoints, models, defaults, catalog)
            guard load == loads else { return }
            (self.endpoints, self.models, self.defaults, self.catalog) = (loaded.0, loaded.1, loaded.2, loaded.3)
            self.spend = spend
            isLoaded = true
        } failed: { self.error = $0 }
    }

    /// Runs `action`, then reloads, so what it changed shows, with what
    /// cohesiond changed along with it (a tier unset with its model), even
    /// if the change push is late.
    private func run(_ action: @escaping (CohesionClient) async throws -> Void) {
        guard let client = model.client else { return }
        Task {
            do {
                try await action(client)
            } catch {
                self.error = error
            }
            await load()
        }
    }
}

/// A searchable list of the models each endpoint offers, grouped by endpoint, to pick one from.
struct ModelPicker: View {
    let title: String
    let endpoints: [IntelligenceEndpoint]
    let models: [EndpointModel]
    let selection: EndpointModel?
    /// Whether to offer "Not Set", which picks `nil`.
    var allowsNone = false
    let onPick: (EndpointModel?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        let matching = filtered
        List {
            if allowsNone && query.isEmpty {
                Section {
                    row("Not Set", picks: nil)
                }
            }
            if matching.isEmpty {
                Text(query.isEmpty ? "Your endpoints offer no models yet." : "No models match.")
                    .foregroundStyle(.secondary)
            }
            ForEach(endpoints) { endpoint in
                let offered = matching.filter { $0.endpointID == endpoint.id }
                if !offered.isEmpty {
                    Section(endpoint.name) {
                        ForEach(offered) { model in
                            row(model.modelName, picks: model)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search models")
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
    }

    private var filtered: [EndpointModel] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return models }
        return models.filter { $0.modelName.lowercased().contains(q) || $0.modelIdentifier.lowercased().contains(q) }
    }

    private func row(_ label: String, picks model: EndpointModel?) -> some View {
        Button {
            if model != selection { onPick(model) }
            dismiss()
        } label: {
            HStack {
                Text(label)
                    .foregroundStyle(Color.primary)
                Spacer()
                if model == selection {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .accessibilityAddTraits(model == selection ? .isSelected : [])
    }
}
