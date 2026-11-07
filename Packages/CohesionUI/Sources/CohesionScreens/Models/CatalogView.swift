import CohesionCore
import CohesionUI
import SwiftUI

/// The catalog models of the configured endpoints' providers, searchable and sortable,
/// with a button that refreshes the catalog from the providers.
struct CatalogView: View {
    @Binding var models: [CatalogModel]
    let hasEndpoints: Bool

    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var sort = Sort.provider
    @State private var isRefreshing = false
    @State private var error: (any Error)?

    enum Sort: String, CaseIterable, Identifiable {
        case provider, name, context, input, output

        var id: Self { self }

        var label: LocalizedStringKey {
            switch self {
            case .provider: "Provider"
            case .name: "Name"
            case .context: "Context Size"
            case .input: "Input Price"
            case .output: "Output Price"
            }
        }
    }

    var body: some View {
        List {
            if !hasEndpoints {
                Text("Add an endpoint to see its models.")
                    .foregroundStyle(.secondary)
            } else if rows.isEmpty {
                Text(query.isEmpty ? "The catalog is empty." : "No models match.")
                    .foregroundStyle(.secondary)
            }
            ForEach(rows) { row in
                CatalogRow(model: row)
            }
        }
        .navigationTitle("Catalog")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Filter models")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu("Sort", systemImage: "arrow.up.arrow.down") {
                    Picker("Sort", selection: $sort) {
                        ForEach(Sort.allCases) { Text($0.label).tag($0) }
                    }
                }
                if isRefreshing {
                    ProgressView()
                } else {
                    Button("Refresh Catalog", systemImage: "arrow.clockwise", action: refresh)
                        .disabled(!hasEndpoints)
                }
            }
        }
        .errorAlert($error)
    }

    private var rows: [CatalogModel] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let matching = q.isEmpty ? models : models.filter { model in
            [model.modelName, model.modelIdentifier, model.providerName, model.providerIdentifier]
                .contains { $0.lowercased().contains(q) }
        }
        let byName: (CatalogModel, CatalogModel) -> Bool = {
            $0.modelName.localizedStandardCompare($1.modelName) == .orderedAscending
        }
        // Unknown numbers sort last.
        func byNumber<T: Comparable>(_ key: KeyPath<CatalogModel, T?>) -> (CatalogModel, CatalogModel) -> Bool {
            { a, b in
                switch (a[keyPath: key], b[keyPath: key]) {
                case let (x?, y?): x == y ? byName(a, b) : x < y
                case (_?, nil): true
                case (nil, _?): false
                case (nil, nil): byName(a, b)
                }
            }
        }
        let compare: (CatalogModel, CatalogModel) -> Bool = switch sort {
        case .provider: { a, b in
            a.providerName == b.providerName
                ? byName(a, b)
                : a.providerName.localizedStandardCompare(b.providerName) == .orderedAscending
        }
        case .name: byName
        case .context: byNumber(\.contextSize)
        case .input: byNumber(\.inputTokenCost)
        case .output: byNumber(\.outputTokenCost)
        }
        return matching.sorted(by: compare)
    }

    private func refresh() {
        guard let client = model.client else { return }
        isRefreshing = true
        Task {
            do {
                try await client.updateModelCatalog()
                models = try await client.listCatalogModels()
            } catch {
                self.error = error
            }
            isRefreshing = false
        }
    }
}

private struct CatalogRow: View {
    let model: CatalogModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.modelName)
                Spacer()
                Text(model.providerName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label(model.contextSize.map(tokens) ?? "—", systemImage: "text.alignleft")
                Label(price(model.inputTokenCost), systemImage: "arrow.down")
                Label(price(model.outputTokenCost), systemImage: "arrow.up")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .labelStyle(CompactLabelStyle())
        }
        .accessibilityElement(children: .combine)
    }

    private func tokens(_ count: Int) -> String {
        count.formatted(.number.notation(.compactName))
    }

    /// Per million tokens.
    private func price(_ cost: Double?) -> String {
        cost.map { $0.formatted(.currency(code: "USD")) } ?? "—"
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}
