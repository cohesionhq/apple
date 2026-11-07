import CohesionCore
import CohesionUI
import SwiftUI

/// Every client cohesiond trusts, whether each is connected now, and
/// renaming or revoking one.
public struct ClientsView: View {
    @Environment(AppModel.self) private var model

    @State private var clients: [Client] = []
    @State private var isLoaded = false
    /// The client being renamed and the name being typed for it.
    @State private var renaming: (client: Client, name: String)?
    @State private var revoking: Client?
    @State private var error: (any Error)?

    public init() {}

    public var body: some View {
        List(clients) { client in
            LabeledContent(client.clientName) {
                Text(client.online ? "Online" : "Offline")
            }
            .swipeActions {
                Button("Revoke", systemImage: "xmark.circle", role: .destructive) { revoking = client }
            }
            .contextMenu {
                Button("Rename…", systemImage: "pencil") { renaming = (client, client.clientName) }
                Button("Revoke…", systemImage: "xmark.circle", role: .destructive) { revoking = client }
            }
        }
        .overlay {
            if !isLoaded { ProgressView() }
        }
        .navigationTitle("Clients")
        .alert(
            "Rename Client",
            isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
        ) {
            TextField("Name", text: Binding(get: { renaming?.name ?? "" }, set: { renaming?.name = $0 }))
            Button("Cancel", role: .cancel) {}
            Button("Rename") { rename() }
        }
        .confirmationDialog(
            "Revoke \(revoking?.clientName ?? "")?",
            isPresented: Binding(get: { revoking != nil }, set: { if !$0 { revoking = nil } }),
            titleVisibility: .visible,
            presenting: revoking
        ) { client in
            Button("Revoke", role: .destructive) {
                run { try await $0.revoke(client) }
            }
        } message: { _ in
            Text("It can’t connect or offer anything to Cohesion until it’s set up again. Any models it offers go with it, and any default that uses one is unset. So do any accounts it offers, and what was imported from them.")
        }
        .task { await watch() }
        .refreshable { await load(.asked) }
        .errorAlert($error)
    }

    private func rename() {
        guard let (client, name) = renaming else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != client.clientName else { return }
        run { try await $0.rename(client, to: trimmed) }
    }

    /// Keeps the list current while it is shown, so a client connecting or
    /// leaving shows; the stream also yields once on connecting, which does
    /// the first load.
    private func watch() async {
        guard let client = model.client else { return }
        for await origin in client.loads(matching: { $0 == .clients }) {
            await load(origin)
        }
    }

    private func load(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client else { return }
        await origin.run {
            let loaded = try await client.listClients()
            withAnimation {
                clients = loaded
                isLoaded = true
            }
        } failed: { self.error = $0 }
    }

    private func run(_ action: @escaping (CohesionClient) async throws -> Void) {
        guard let client = model.client else { return }
        Task {
            do { try await action(client) } catch { self.error = error }
        }
    }
}
