import CohesionCore
import CohesionMarkdown
import CohesionUI
import SwiftUI

/// One imported resource, read-only as cohesiond keeps it: its kind, when
/// it last changed and where it came from, then its contents, Markdown as
/// a document reads, JSON indented, text as it is. Remove… takes it out of
/// the workspace.
struct ResourceView: View {
    let workspaceID: Int
    let resourceID: Int
    let kind: ConnectorKind

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var resource: Resource?
    @State private var isRemoving = false
    @State private var error: (any Error)?

    var body: some View {
        ScrollView {
            if let resource {
                VStack(alignment: .leading, spacing: 16) {
                    Text(resource.title)
                        .font(.title2.bold())
                    metadata(resource)
                    contents(resource)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        }
        .overlay {
            if resource == nil { ProgressView() }
        }
        .navigationTitle(resource?.title ?? kind.kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button("Remove…", systemImage: "trash", role: .destructive) { isRemoving = true }
                    .disabled(resource == nil)
            }
        }
        .confirmationDialog(
            "Remove “\(resource?.title ?? "")”?",
            isPresented: $isRemoving,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive, action: remove)
        } message: {
            Text("It leaves this workspace, and a refresh won’t bring it back. Import it again to restore it.")
        }
        .task { await watch() }
        .errorAlert($error)
    }

    /// Its kind, when it last changed if known, and the connector it came through.
    private func metadata(_ resource: Resource) -> some View {
        HStack(spacing: 6) {
            ServiceIcon(icon: kind.connector.icon, name: kind.connector.title, size: 16)
            if let lastUpdated = resource.lastUpdated {
                Text("\(kind.kind.title) · updated \(lastUpdated, format: .relative(presentation: .named)) · via \(kind.connector.title)")
            } else {
                Text("\(kind.kind.title) · via \(kind.connector.title)")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func contents(_ resource: Resource) -> some View {
        switch resource.contentKind {
        case .markdown:
            MarkdownText(markdown: resource.contents, style: .article)
                .textSelection(.enabled)
        case .text:
            Text(resource.contents)
                .textSelection(.enabled)
        case .json:
            ScrollView(.horizontal) {
                Text(Self.indented(resource.contents))
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(.fill.quaternary, in: .rect(cornerRadius: 8))
        }
    }

    /// JSON contents indented, keys sorted, since `JSONSerialization`
    /// keeps no order; as stored if they don't parse.
    private static func indented(_ contents: String) -> String {
        guard let data = contents.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed),
              let pretty = try? JSONSerialization.data(
                  withJSONObject: object,
                  options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]
              )
        else { return contents }
        return String(decoding: pretty, as: UTF8.self)
    }

    /// Keeps it current while it is shown, as its service's copy is
    /// refreshed; the stream also yields once on connecting, which does the
    /// first load.
    private func watch() async {
        guard let client = model.client else { return }
        let workspaceID = workspaceID
        for await origin in client.loads(matching: { $0 == .resources(workspaceID: workspaceID) }) {
            await origin.run {
                do {
                    resource = try await client.resource(resourceID, in: workspaceID)
                } catch let error as ServerError where error.code == ServerError.notFound && resource != nil {
                    // Removed elsewhere: back to the list, which no longer has it.
                    dismiss()
                }
            } failed: { self.error = $0 }
        }
    }

    private func remove() {
        guard let client = model.client else { return }
        Task {
            do {
                try await client.removeResource(resourceID, in: workspaceID)
                dismiss()
            } catch {
                self.error = error
            }
        }
    }
}
