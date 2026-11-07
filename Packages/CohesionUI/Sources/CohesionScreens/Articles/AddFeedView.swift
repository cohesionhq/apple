import CohesionCore
import CohesionUI
import SwiftUI

/// A sheet asking for a feed's address to follow. cohesiond reads the feed
/// and its articles before answering, so adding waits on the site.
struct AddFeedView: View {
    let onAdd: (Feed) async -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var address = ""
    @State private var isAdding = false
    @State private var error: (any Error)?

    private var trimmed: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Address", text: $address, prompt: Text(verbatim: "https://example.com/feed.xml"))
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(add)
                } footer: {
                    Text("Cohesion reads the feed now and every hour, for every workspace.")
                }
            }
            .navigationTitle("Add Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isAdding {
                        ProgressView()
                    } else {
                        Button("Add", systemImage: "checkmark", role: .confirm, action: add)
                            .disabled(trimmed.isEmpty)
                    }
                }
            }
            .errorAlert($error)
        }
        .interactiveDismissDisabled(isAdding)
    }

    private func add() {
        guard let client = model.client, !trimmed.isEmpty, !isAdding else { return }
        isAdding = true
        Task {
            do {
                let feed = try await client.addFeed(trimmed)
                dismiss()
                await onAdd(feed)
            } catch {
                self.error = error
            }
            isAdding = false
        }
    }
}
