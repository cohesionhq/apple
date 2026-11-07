import CohesionCore
import CohesionUI
import SwiftUI
#if canImport(UIKit)
import UIKit

private typealias RowFont = UIFont
#else
import AppKit

private typealias RowFont = NSFont
#endif

/// A sheet that adds an endpoint from a provider preset, or a custom one.
struct EndpointForm: View {
    let onSave: (IntelligenceEndpoint) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    /// Starts on the first of the vocabulary's presets.
    @State private var preset: EndpointPreset?
    @State private var name = ""
    @State private var apiKey = ""
    @State private var usageURL = ""
    @State private var providerIdentifier = ""
    @State private var dialect = EndpointDialect.chatCompletions
    @State private var baseURL = ""
    @State private var isSaving = false
    @State private var error: (any Error)?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Provider", selection: $preset) {
                    ForEach(model.vocabulary.providers, id: \.self) { provider in
                        Text(provider.label).tag(EndpointPreset?.some(.provider(provider)))
                    }
                    Text(EndpointPreset.custom.label).tag(EndpointPreset?.some(.custom))
                }
                if preset == .custom {
                    Section {
                        TextField("Provider Identifier", text: $providerIdentifier)
                        Picker("Backend", selection: $dialect) {
                            ForEach(model.vocabulary.dialects, id: \.kind) { Text($0.label).tag($0.kind) }
                        }
                        TextField("Base URL", text: $baseURL, prompt: Text("https://…/v1"))
                            .keyboardType(.URL)
                        TextField("Platform Dashboard (optional)", text: $usageURL, prompt: Text("Platform Dashboard (optional)"))
                            .keyboardType(.URL)
                    }
                }
                Section {
                    TextField("Name (optional)", text: $name)
                    SecureField(preset?.requiresAPIKey == false ? "API Key (optional)" : "API Key", text: $apiKey)
                } footer: {
                    Text("Without a name, the endpoint is named after its provider. The key is never shown again.")
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .navigationTitle("Add Endpoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", systemImage: "checkmark", role: .confirm, action: save)
                        .disabled(!canSave)
                }
            }
            .errorAlert($error)
            .onChange(of: model.vocabulary.providers.first, initial: true) { _, first in
                if preset == nil, let first { preset = .provider(first) }
            }
        }
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces)
    }

    private var canSave: Bool {
        guard let preset else { return false }
        return !isSaving
            && (!preset.requiresAPIKey || !trimmed(apiKey).isEmpty)
            && (preset != .custom || (!trimmed(providerIdentifier).isEmpty && !trimmed(baseURL).isEmpty))
    }

    private func save() {
        guard let client = model.client, let preset else { return }
        isSaving = true
        Task {
            do {
                let created = try await client.createEndpoint(
                    preset: preset,
                    name: trimmed(name),
                    apiKey: trimmed(apiKey),
                    usageURL: preset == .custom ? trimmed(usageURL) : "",
                    providerIdentifier: trimmed(providerIdentifier),
                    dialect: dialect,
                    baseURL: trimmed(baseURL)
                )
                onSave(created)
                dismiss()
            } catch {
                self.error = error
            }
            isSaving = false
        }
    }
}

/// A sheet that imports models into `endpoint`: those its provider's catalog
/// lists, checked off a searchable list, and one it doesn't, by identifier.
/// Models the endpoint already offers show checked.
struct EndpointModelsForm: View {
    let endpoint: IntelligenceEndpoint
    /// Identifiers of the models `endpoint` already offers.
    let offered: [String]
    /// Called once importing stops, whether or not every model made it.
    let onSave: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var catalog: [CatalogModel] = []
    @State private var isLoaded = false
    @State private var checked: Set<String> = []
    @State private var typed = ""
    @State private var query = ""
    @State private var isSaving = false
    @State private var error: (any Error)?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if !isLoaded {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if catalog.isEmpty {
                        Text("The catalog lists no models for this provider yet.")
                            .foregroundStyle(.secondary)
                    } else if rows.isEmpty {
                        Text("No models match.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(rows) { row in
                        catalogRow(row)
                    }
                } header: {
                    Text("Catalog")
                } footer: {
                    if !rows.isEmpty {
                        Text("Prices are per million tokens.")
                    }
                }
                Section {
                    TextField("Model Identifier", text: $typed)
                } header: {
                    Text("Other Model")
                } footer: {
                    Text("A model the catalog doesn’t list, by its identifier.")
                }
            }
            .searchable(text: $query, prompt: "Filter models")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .navigationTitle("Add Models to \(endpoint.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", systemImage: "checkmark", role: .confirm, action: save)
                        .disabled(isSaving || picked.isEmpty)
                }
            }
            .task { await loadCatalog() }
            .errorAlert($error)
        }
    }

    /// The catalog models matching the filter, by name.
    private var rows: [CatalogModel] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let sorted = catalog.sorted {
            $0.modelName.localizedStandardCompare($1.modelName) == .orderedAscending
        }
        guard !q.isEmpty else { return sorted }
        return sorted.filter { $0.modelName.lowercased().contains(q) || $0.modelIdentifier.lowercased().contains(q) }
    }

    /// The identifiers to import: the checked catalog models, then the typed
    /// one, leaving out what the endpoint already offers.
    private var picked: [String] {
        let typed = typed.trimmingCharacters(in: .whitespaces)
        var wanted = catalog.map(\.modelIdentifier).filter { checked.contains($0) }
        if !typed.isEmpty && !wanted.contains(typed) {
            wanted.append(typed)
        }
        return wanted.filter { !offered.contains($0) }
    }

    private func catalogRow(_ row: CatalogModel) -> some View {
        let isOffered = offered.contains(row.modelIdentifier)
        let isChecked = isOffered || checked.contains(row.modelIdentifier)
        return Button {
            if checked.contains(row.modelIdentifier) {
                checked.remove(row.modelIdentifier)
            } else {
                checked.insert(row.modelIdentifier)
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    // The name is sized first, so a long identifier shortens
                    // in the width left over rather than squeezing it.
                    Text(row.modelName)
                        .foregroundStyle(Color.primary)
                        .layoutPriority(1)
                        .alignmentGuide(VerticalAlignment.center) { capitalsCentre($0, capHeight: nameCapHeight) }
                    Text(row.modelIdentifier)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .alignmentGuide(VerticalAlignment.center) { capitalsCentre($0, capHeight: identifierCapHeight) }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    if isChecked {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                HStack(alignment: .top, spacing: 8) {
                    price("Input", row.inputTokenCost)
                    price("Cache Read", row.cacheReadTokenCost)
                    price("Cache Write", row.cacheWriteTokenCost)
                    price("Output", row.outputTokenCost)
                }
            }
        }
        .disabled(isOffered)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }

    /// The middle of a line's capitals, which a row's name and identifier
    /// centre on: their line boxes' middles differ by font and size, and the
    /// text's own shape would move with its descenders.
    private func capitalsCentre(_ text: ViewDimensions, capHeight: CGFloat) -> CGFloat {
        text[.firstTextBaseline] - capHeight / 2
    }

    /// The cap height of a row's name, read at layout so it follows Dynamic Type.
    private var nameCapHeight: CGFloat {
        RowFont.preferredFont(forTextStyle: .body).capHeight
    }

    /// The cap height of a row's identifier, in `.caption.monospaced()`.
    private var identifierCapHeight: CGFloat {
        let size = RowFont.preferredFont(forTextStyle: .caption1).pointSize
        return RowFont.monospacedSystemFont(ofSize: size, weight: .regular).capHeight
    }

    /// One of a model's prices, in a column as wide as the others so they
    /// line up down the list; "—" when the catalog has none. `Color.secondary`
    /// because in a button's label `.secondary` is a fainter shade of the tint.
    private func price(_ label: LocalizedStringKey, _ cost: Double?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
            Text(cost.map(usd) ?? "—")
                .font(.caption.monospacedDigit())
        }
        .foregroundStyle(Color.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadCatalog() async {
        guard let client = model.client else { return }
        do {
            catalog = try await client.listCatalogModels(of: endpoint.providerIdentifier)
            isLoaded = true
        } catch where !Task.isCancelled {
            // A load cut short by closing the sheet isn't an error.
            self.error = error
        } catch {}
    }

    /// Imports the picked models in order. One that fails stops the rest;
    /// those before it stay imported, and drop out of `picked` once the
    /// list behind the sheet reloads.
    private func save() {
        guard let client = model.client else { return }
        isSaving = true
        Task {
            var failure: (any Error)?
            do {
                for identifier in picked {
                    _ = try await client.addModel(identifier, to: endpoint)
                }
            } catch {
                failure = error
            }
            onSave()
            isSaving = false
            if let failure {
                self.error = failure
            } else {
                dismiss()
            }
        }
    }
}
