import CohesionCore
import CohesionUI
import SwiftUI

/// Which kinds of resource the workspace shows in the sidebar, and in what
/// order, as the web's "Show in sidebar" dialog has it: the kinds shown, in
/// the sidebar's order, which reorder by dragging, then the rest. A tap on
/// a row saves at once, and a checkmark marks a kind shown; a hidden kind
/// keeps its resources.
struct ResourceKindsView: View {
    /// Every kind the workspace can show.
    let kinds: [ConnectorKind]
    /// The kinds it shows, in their order.
    let shown: [ConnectorKind]
    /// Shows the kind or hides it at once, then saves it; a failed save puts
    /// back cohesiond's.
    let setShown: (ConnectorKind, Bool) async throws -> Void
    /// Moves the shown kinds at once, then saves their order; a failed
    /// save puts back cohesiond's.
    let move: (IndexSet, Int) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var error: (any Error)?
    /// Counts the times the list has been built again.
    @State private var listBuild = 0
    /// Builds the list again once a row's move has finished.
    @State private var pendingBuild: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if !shown.isEmpty {
                    Section("Shown") {
                        ForEach(shown) { row($0, isShown: true) }
                            .onMove { source, destination in run { try await move(source, destination) } }
                    }
                }
                if !hidden.isEmpty {
                    Section("Hidden") {
                        ForEach(hidden) { row($0, isShown: false) }
                    }
                }
            }
            // A row that joins the shown kinds gets no handle until the list
            // is built again, so a change to which kinds are shown does that
            // after the row's move; a change to their order doesn't. Another
            // tap puts it off, so it never cuts a move short.
            .id(listBuild)
            .onChange(of: Set(shown.map(\.id))) {
                pendingBuild?.cancel()
                pendingBuild = Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    if !Task.isCancelled { listBuild += 1 }
                }
            }
            .overlay {
                if kinds.isEmpty {
                    ContentUnavailableView(
                        "No Accounts",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("No accounts to import from yet.")
                    )
                }
            }
            // Always editing, so the shown kinds keep their handles.
            #if os(iOS)
            .environment(\.editMode, .constant(.active))
            #endif
            .navigationTitle("Show in Sidebar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .errorAlert($error)
    }

    private var hidden: [ConnectorKind] {
        kinds.filter { kind in !shown.contains { $0.id == kind.id } }
    }

    private func row(_ entry: ConnectorKind, isShown: Bool) -> some View {
        // Plain, so the tap doesn't rest on selecting a row in edit mode.
        Button {
            run { try await setShown(entry, !isShown) }
        } label: {
            HStack {
                ResourceKindLabel(entry: entry)
                Spacer()
                if isShown {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isShown ? .isSelected : [])
    }

    private func run(_ action: @escaping () async throws -> Void) {
        Task {
            do { try await action() } catch { self.error = error }
        }
    }
}

/// A kind's plural name beside its connector's icon, as the sidebar lists
/// it.
struct ResourceKindLabel: View {
    let entry: ConnectorKind
    /// Whether the title names the connector too ("Linear Issues"), where
    /// another connector's kind has the same name.
    var namesConnector = false

    @ScaledMetric(relativeTo: .body) private var iconSize = 20

    var body: some View {
        Label {
            Text(namesConnector ? "\(entry.connector.title) \(entry.kind.plural)" : entry.kind.plural)
        } icon: {
            ServiceIcon(icon: entry.connector.icon, name: entry.connector.title, size: iconSize)
        }
    }
}
