import CohesionCore
import CohesionUI
import SwiftUI

/// A task list's title menu, moving between the lists in the order a sidebar's
/// section has them, where one row in the sidebar stands for them
/// (`tasksAreOneRow`).
struct TaskListMenu: ViewModifier {
    /// The list open.
    let page: WorkspacePage
    let open: (WorkspacePage) -> Void

    @Environment(\.tasksAreOneRow) private var isOneRow
    @Environment(WindowModel.self) private var window

    func body(content: Content) -> some View {
        #if os(iOS)
        if isOneRow {
            content
                // Inline, so the title shows the chevron that opens the menu.
                .navigationBarTitleDisplayMode(.inline)
                .toolbarTitleMenu { menu }
        } else {
            content
        }
        #else
        content
        #endif
    }

    @ViewBuilder
    private var menu: some View {
        Picker("Tasks", selection: Binding { page } set: { open($0) }) {
            Label("Inbox", systemImage: "tray").tag(WorkspacePage.tasks(.inbox))
            ForEach(window.folders) { folder in
                Label(folder.title, systemImage: "folder").tag(WorkspacePage.tasks(.folder(folder.id)))
            }
            Section {
                Label("All", systemImage: "tray.2").tag(WorkspacePage.tasks(.all))
                Label("Done", systemImage: "checkmark.circle").tag(WorkspacePage.tasks(.done))
                Label("Cancelled", systemImage: "xmark.circle").tag(WorkspacePage.tasks(.cancelled))
            }
            if !window.savedViews.isEmpty {
                Section {
                    ForEach(window.savedViews) { view in
                        Label(view.name, systemImage: "bookmark").tag(WorkspacePage.taskView(view.id))
                    }
                }
            }
        }
        if !window.savedViews.isEmpty {
            Button("Edit Views…", systemImage: "slider.horizontal.3") {
                window.isEditingSavedViews = true
            }
        }
    }
}

/// The saved task views in their order, to drag into another, for where a menu
/// lists them and can't.
struct EditSavedViewsView: View {
    @Environment(WindowModel.self) private var window
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(window.savedViews) { view in
                    Label(view.name, systemImage: "bookmark")
                }
                .onMove(perform: window.moveSavedViews)
            }
            // Always editing, so the views keep their handles.
            #if os(iOS)
            .environment(\.editMode, .constant(.active))
            #endif
            .navigationTitle("Edit Views")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) { dismiss() }
                }
            }
        }
    }
}
