#if DEBUG
import CohesionCore
import CohesionMarkdown
import CohesionUI
import SwiftUI

// The screens a shell pushes or presents, over `PreviewData`, one preview
// each. The tabs and what they push are the iOS shell's previews
// (`Cohesion/Previews/ShellPreviews.swift`).

/// `content` once `load` has answered from the preview's client.
private struct PreviewLoaded<Value, Content: View>: View {
    let load: (CohesionClient) async throws -> Value
    @ViewBuilder let content: (Value) -> Content

    @Environment(\.cohesionClient) private var client
    @State private var value: Value?

    var body: some View {
        if let value {
            content(value)
        } else {
            Color.clear.task {
                guard let client else { return }
                value = try? await load(client)
            }
        }
    }
}

/// A sheet's content over a dimmed screen, as a sheet shows on a phone.
private struct PreviewSheet<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var isPresented = true

    var body: some View {
        Color.clear.sheet(isPresented: $isPresented) { content() }
    }
}

private func agent(_ window: WindowModel, _ id: Int = 1) -> Agent? {
    window.agents.first { $0.id == id }
}

// MARK: Pairing

#Preview("Pairing") {
    PairingView()
        .previewWindow()
}

#Preview("Revoked") {
    RevokedView()
        .previewWindow()
}

// MARK: Agents

#Preview("Agent Info") {
    PreviewWindow(workspaceID: 1) { window in
        PreviewSheet {
            if let agent = agent(window) { AgentInfoView(agent: agent) {} }
        }
    }
}

#Preview("New Agent") {
    PreviewSheet { AgentForm { _ in } }
        .previewWindow()
}

#Preview("Agent Memories") {
    PreviewWindow(workspaceID: 1) { window in
        PreviewPushed(backTitle: "Info") {
            if let agent = agent(window) { MemoriesView(agent: agent) }
        }
    }
}

#Preview("Agent Usage") {
    PreviewWindow(workspaceID: 1) { window in
        PreviewPushed(backTitle: "Info") {
            if let agent = agent(window) { AgentUsageView(agent: agent) }
        }
    }
}

#Preview("Agent Runs") {
    PreviewWindow(workspaceID: 1) { window in
        PreviewPushed(backTitle: "Info") {
            if let agent = agent(window) { AgentRunsView(agent: agent) }
        }
    }
}

#Preview("Agent Cues") {
    PreviewWindow(workspaceID: 1) { window in
        PreviewPushed(backTitle: "Info") {
            if let agent = agent(window) { AgentCuesView(agent: agent) }
        }
    }
}

// MARK: Actors

#Preview("New Actor Session") {
    PreviewWindow(workspaceID: 1) { window in
        PreviewSheet {
            NewActorSessionView(actors: window.actors, clients: window.clients) { _ in }
        }
    }
}

#Preview("Actor Usage") {
    PreviewWindow(workspaceID: 1) { window in
        PreviewSheet {
            NavigationStack { ActorUsageView(actors: window.actors, usage: window.actorUsage) }
        }
    }
}

// MARK: Tasks

#Preview("New Task") {
    PreviewWindow(workspaceID: 1) { window in
        PreviewSheet {
            NewTaskView(workspaceID: 1, folderID: nil, tagIDs: [], folders: window.folders, tags: window.tags) {}
        }
    }
}

#Preview("Task Detail") {
    PreviewWindow(workspaceID: 1) { window in
        PreviewLoaded { client in
            let query = TaskQuery(scope: .inbox)
            return try await client.listTasks(
                in: 1, scope: query.scope, statuses: [.incomplete], tags: query.tags,
                priorities: query.priorities, sizes: query.sizes, sort: query.sort, descending: query.descending
            ).tasks.first
        } content: { task in
            if let task {
                PreviewSheet {
                    TaskDetailView(task: task, folders: window.folders, tags: window.tags, contacts: window.contacts) {}
                }
            }
        }
    }
}

#Preview("Task Filter") {
    @Previewable @State var query = TaskQuery(scope: .inbox)
    PreviewWindow(workspaceID: 1) { window in
        PreviewSheet { TaskFilterView(query: $query, tags: window.tags) }
    }
}

#Preview("Tags") {
    PreviewWindow(workspaceID: 1) { window in
        PreviewSheet { TagsView(workspaceID: 1, tags: window.tags) }
    }
}

// MARK: Journal and documents

#Preview("Journal Entries") {
    PreviewPushed(backTitle: "Journal") { JournalListView(workspaceID: 1) }
        .previewWindow()
}

#Preview("Quick Journal") {
    PreviewSheet { QuickJournalSheet(workspaceID: 1) {} }
        .previewWindow()
}

#Preview("Document") {
    PreviewLoaded { client in
        try await client.listDocuments(in: 1).first
    } content: { document in
        if let document {
            PreviewSheet { DocumentView(workspaceID: 1, documentID: document.id) }
        }
    }
    .previewWindow()
}

// MARK: Contacts

#Preview("Edit Contact") {
    PreviewWindow(workspaceID: 1) { window in
        if let contact = window.contacts.first {
            PreviewSheet { ContactForm(subject: .edit(contact)) }
        }
    }
}

// MARK: Feeds

#Preview("Articles") {
    PreviewWindow(workspaceID: 1) { window in
        PreviewPushed(backTitle: "Feeds") {
            ArticleListView(filter: .allFeeds, title: "All Feeds", feeds: window.feeds)
        }
    }
}

#Preview("Article") {
    PreviewLoaded { client in
        try await client.listArticles(filter: .allFeeds).articles.first
    } content: { article in
        if let article {
            PreviewPushed(backTitle: "All Feeds") { ArticleView(articleID: article.id) }
        }
    }
    .previewWindow()
}

#Preview("Add Feed") {
    PreviewSheet { AddFeedView { _ in } }
        .previewWindow()
}

// MARK: Connectors

#Preview("Resources") {
    PreviewWindow(workspaceID: 1) { window in
        if let kind = window.shownKinds.first {
            PreviewPushed(backTitle: "Workspace") {
                ResourceListView(workspaceID: 1, kind: kind, accounts: window.connectorAccounts, clients: window.clients)
            }
        }
    }
}

#Preview("Resource") {
    PreviewWindow(workspaceID: 1) { window in
        if let kind = window.shownKinds.first {
            PreviewLoaded { client in
                try await client.listResources(of: kind, in: 1, sort: .title, descending: false).first
            } content: { resource in
                if let resource {
                    PreviewPushed(backTitle: kind.kind.plural) {
                        ResourceView(workspaceID: 1, resourceID: resource.id, kind: kind)
                    }
                }
            }
        }
    }
}

#Preview("Import Resources") {
    PreviewWindow(workspaceID: 1) { window in
        if let kind = window.shownKinds.first {
            PreviewSheet {
                ImportResourcesView(workspaceID: 1, kind: kind, accounts: window.connectorAccounts, clients: window.clients)
            }
        }
    }
}

#Preview("Resource Kinds") {
    PreviewWindow(workspaceID: 1) { window in
        PreviewSheet {
            ResourceKindsView(
                kinds: window.connectorAccounts.importableKinds,
                shown: window.shownKinds,
                setShown: { _, _ in },
                move: { _, _ in }
            )
        }
    }
}

// MARK: Settings

#Preview("Profile") {
    PreviewPushed(backTitle: "Settings") { ProfileView() }
        .previewWindow()
}

#Preview("Agents Settings") {
    PreviewPushed(backTitle: "Settings") { ModelSettingsView() }
        .previewWindow()
}

#Preview("Memories Settings") {
    PreviewPushed(backTitle: "Settings") { MemorySettingsView() }
        .previewWindow()
}

#Preview("Clients") {
    PreviewPushed(backTitle: "Settings") { ClientsView() }
        .previewWindow()
}

#Preview("Extensions") {
    PreviewPushed(backTitle: "Settings") { ExtensionsView() }
        .previewWindow()
}

#Preview("Extension") {
    PreviewLoaded { client in
        try await client.listExtensions().first
    } content: { summary in
        if let summary {
            PreviewPushed(backTitle: "Extensions") { ExtensionView(extensionSummary: summary) {} }
        }
    }
    .previewWindow()
}

#Preview("Browse Extensions") {
    PreviewSheet { NavigationStack { BrowseExtensionsView() } }
        .previewWindow()
}

#Preview("Review Extension") {
    PreviewLoaded { client in
        try await client.searchRegistries(for: "").first?.results.first
    } content: { result in
        if let result {
            PreviewSheet { ReviewExtensionView(review: ExtensionReview(source: .registry(result))) { _ in } }
        }
    }
    .previewWindow()
}
#endif
