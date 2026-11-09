#if DEBUG
import CohesionCore
import CohesionMarkdown
import CohesionUI
import SwiftUI

extension AppModel {
    /// An app for `#Preview`s, answered by `PreviewData` rather than a server.
    public static func preview() -> AppModel {
        AppModel(previewClient: CohesionClient(previewReplies: PreviewData.reply, vocabulary: PreviewData.vocabulary))
    }
}

extension WindowModel {
    /// A window for `#Preview`s on `PreviewData`'s workspace, its lists
    /// already shown, as a window shows them on launching.
    public static func preview(app: AppModel, workspaceID: Int = 1) -> WindowModel {
        let window = WindowModel(app: app, workspaceID: workspaceID)
        window.showKeptOnce()
        if let client = app.client {
            window.profile = client.keptReply("getProfile")
            window.actorUsage = client.keptReply("listActorUsage") ?? []
        }
        return window
    }
}

/// A screen in a window of `PreviewData`, as a shell shows it: the app, the
/// window and its lists in the environment.
struct PreviewWindow<Content: View>: View {
    @State private var app: AppModel
    @State private var window: WindowModel
    @ViewBuilder let content: (WindowModel) -> Content

    init(workspaceID: Int, @ViewBuilder content: @escaping (WindowModel) -> Content) {
        let app = AppModel.preview()
        _app = State(initialValue: app)
        _window = State(initialValue: .preview(app: app, workspaceID: workspaceID))
        self.content = content
    }

    var body: some View {
        content(window)
            .keepsWindowLists(window)
            .environment(\.cohesionClient, app.client)
            .environment(app)
            .environment(window)
            .tint(Color.previewAccent)
    }
}

extension Color {
    /// The app's `AccentColor`, which a package's preview can't read from the
    /// app's asset catalog.
    public static var previewAccent: Color {
        #if os(iOS)
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(displayP3Red: 0.420, green: 0.425, blue: 0.920, alpha: 1)
                : UIColor(displayP3Red: 0.369, green: 0.373, blue: 0.890, alpha: 1)
        })
        #else
        Color.accentColor
        #endif
    }
}

/// Shows `content` pushed on a stack, with the back button a pushed screen has.
struct PreviewPushed<Content: View>: View {
    let backTitle: String
    @ViewBuilder let content: () -> Content
    @State private var path = [0]

    var body: some View {
        NavigationStack(path: $path) {
            Color.clear
                .navigationTitle(backTitle)
                .navigationDestination(for: Int.self) { _ in content() }
        }
    }
}

extension View {
    /// The view in a preview window of `PreviewData`'s workspace.
    func previewWindow(workspaceID: Int = 1) -> some View {
        PreviewWindow(workspaceID: workspaceID) { _ in self }
    }
}
#endif
