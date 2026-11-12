import CohesionCore
import CohesionUI
import SwiftUI

/// The task lists, as the iPhone's Tasks tab opens on them: the inbox and the
/// folders, then the views of them (every open task, those done and those
/// cancelled, then the saved views, which reorder), in the web's Tasks page's
/// order, each a page's row with its `SymbolIcon` that `link` opens. The tab
/// reopens the list last open on top of it.
public struct TaskListsView<Link: Hashable>: View {
    let folders: [TaskFolder]
    let savedViews: [SavedTaskView]
    let moveSavedViews: (IndexSet, Int) -> Void
    let link: (WorkspacePage) -> Link

    public init(
        folders: [TaskFolder],
        savedViews: [SavedTaskView],
        moveSavedViews: @escaping (IndexSet, Int) -> Void,
        link: @escaping (WorkspacePage) -> Link
    ) {
        self.folders = folders
        self.savedViews = savedViews
        self.moveSavedViews = moveSavedViews
        self.link = link
    }

    public var body: some View {
        List {
            Section {
                row(.tasks(.inbox), "Inbox", systemImage: "tray.fill", color: .blue)
                ForEach(folders) { folder in
                    row(.tasks(.folder(folder.id)), folder.title, systemImage: "folder.fill", color: .indigo)
                }
            }
            Section("Views") {
                row(.tasks(.all), "All", systemImage: "tray.2.fill", color: .gray)
                row(.tasks(.done), "Done", systemImage: "checkmark.circle.fill", color: .green)
                row(.tasks(.cancelled), "Cancelled", systemImage: "xmark.circle.fill", color: .gray)
                ForEach(savedViews) { view in
                    row(.taskView(view.id), view.name, systemImage: "bookmark.fill", color: .pink)
                }
                .onMove(perform: moveSavedViews)
            }
        }
        .navigationTitle("Tasks")
    }

    private func row(_ page: WorkspacePage, _ title: String, systemImage: String, color: Color) -> some View {
        NavigationLink(value: link(page)) {
            Label(title, systemImage: systemImage, color: color)
        }
    }
}
