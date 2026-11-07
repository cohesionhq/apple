import CohesionCore
import CohesionUI
import SwiftUI

extension View {
    /// Opens the `cohesion://` links tapped in this view's text that show
    /// in a sheet over it: a task, one row of a list with a small detail of
    /// its own, and a document. A link that navigates, to an agent's chat or
    /// an actor session, closes the sheet this view is in and goes on to the
    /// `openURL` around it, as does any other link. A sheet is presented
    /// only from the topmost one, so every sheet whose text has links applies
    /// this; `request` opens a link from outside the view, such as a tapped
    /// Live Activity.
    public func presentsLinkedItems(request: Binding<AppLink?>? = nil) -> some View {
        modifier(LinkedItemSheet(request: request))
    }
}

/// What a link shows in a sheet.
private enum LinkedItem: Identifiable {
    /// A task, with its workspace's folders, tags and contacts for the form.
    case task(TaskItem, folders: [TaskFolder], tags: [Tag], contacts: [Contact])
    /// A document, a journal entry too, and the workspace that holds it.
    case document(Int, workspaceID: Int)

    var id: AppLink {
        switch self {
        case .task(let task, _, _, _): .task(task.id, workspaceID: task.workspaceID)
        case .document(let id, let workspaceID): .document(id, workspaceID: workspaceID)
        }
    }
}

private struct LinkedItemSheet: ViewModifier {
    let request: Binding<AppLink?>?

    @Environment(AppModel.self) private var model
    @Environment(WindowModel.self) private var window
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    @State private var linked: LinkedItem?
    @State private var notice: Toast?
    @State private var error: (any Error)?

    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction(handler: follow))
            .onChange(of: request?.wrappedValue, initial: true) { _, link in
                guard let link else { return }
                request?.wrappedValue = nil
                _ = follow(link.url)
            }
            .sizedSheet(item: $linked) { item in
                Group {
                    switch item {
                    case .task(let task, let folders, let tags, let contacts):
                        TaskDetailView(task: task, folders: folders, tags: tags, contacts: contacts, onSave: {})
                    case .document(let id, let workspaceID):
                        NavigationStack {
                            DocumentView(workspaceID: workspaceID, documentID: id)
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("Done", systemImage: "xmark", role: .close) { linked = nil }
                                    }
                                }
                        }
                    }
                }
                .presentsLinkedItems()
                .id(item.id)
            }
            .toast($notice)
            .errorAlert($error)
    }

    private func follow(_ url: URL) -> OpenURLAction.Result {
        switch AppLink(url: url) {
        case .task(let id, let workspaceID):
            Task { await open(taskID: id, in: workspaceID) }
        case .document(let id, let workspaceID):
            Task { await open(documentID: id, in: workspaceID) }
        case .agent, .actorSession, .agents, .newTask, .newActorSession:
            // What it opens is pushed or is the window's, so nothing is left over it.
            linked = nil
            dismiss()
            openURL(url)
        case nil:
            openURL(url)
        }
        return .handled
    }

    /// Shows the task, with its workspace's folders, tags and contacts. A link that
    /// names no workspace finds it in whichever holds it.
    private func open(taskID id: Int, in workspaceID: Int?) async {
        guard let client = model.client else { return }
        do {
            guard let task = try await client.task(id, in: workspaceID) else {
                notice = .error("Task not found.")
                return
            }
            let folders = try await client.listTaskFolders(in: task.workspaceID)
            let tags = try await client.listTaskTags(in: task.workspaceID)
            let contacts = try await client.listContacts(in: task.workspaceID)
            linked = .task(task, folders: folders, tags: tags, contacts: contacts)
        } catch {
            self.error = error
        }
    }

    /// Shows the document from the workspace the link names. An older link
    /// names none, so the shown workspace is asked first, then the others in
    /// turn.
    private func open(documentID id: Int, in workspaceID: Int?) async {
        guard let client = model.client else { return }
        let shown = window.selectedWorkspaceID
        let workspaceIDs = workspaceID.map { [$0] }
            ?? [shown].compactMap(\.self) + model.workspaces.map(\.id).filter { $0 != shown }
        do {
            for workspaceID in workspaceIDs {
                do {
                    _ = try await client.document(id, in: workspaceID)
                } catch let error as ServerError where error.code == ServerError.notFound {
                    continue
                }
                linked = .document(id, workspaceID: workspaceID)
                return
            }
            notice = .error("Document not found.")
        } catch {
            self.error = error
        }
    }
}
