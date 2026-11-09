#if DEBUG
import CohesionCore
import CohesionMarkdown
import CohesionScreens
import SwiftUI

/// The iOS shell over `PreviewData`, as `CohesionApp` sets up a window.
private struct ShellPreview<Content: View>: View {
    @State private var app: AppModel
    @State private var window: WindowModel
    @State private var push = PushRegistration()
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        let app = AppModel.preview()
        _app = State(initialValue: app)
        _window = State(initialValue: .preview(app: app))
        self.content = content
    }

    var body: some View {
        content()
            .environment(\.cohesionClient, app.client)
            .environment(app)
            .environment(window)
            .environment(push)
    }
}

#Preview("iPhone · Dashboard") {
    ShellPreview { RootView(previewTab: .dashboard) }
}

#Preview("iPhone · Intelligence") {
    ShellPreview { RootView(previewTab: .intelligence) }
}

#Preview("iPhone · Workspace") {
    ShellPreview { RootView(previewTab: .workspace) }
}

#Preview("iPhone · Feeds") {
    ShellPreview { RootView(previewTab: .feeds) }
}

#Preview("iPhone · Agent Chat") {
    ShellPreview { RootView(previewTab: .intelligence, agentPath: [.agent(1)]) }
}

#Preview("iPhone · Actor Session") {
    ShellPreview { RootView(previewTab: .intelligence, agentPath: [.actorSession(1)]) }
}

#Preview("iPhone · Tasks") {
    ShellPreview { RootView(previewTab: .workspace, workspacePath: [.page(.tasks(.inbox))]) }
}

#Preview("iPhone · Journal") {
    ShellPreview { RootView(previewTab: .workspace, workspacePath: [.page(.journal)]) }
}

#Preview("iPhone · Today") {
    ShellPreview { RootView(previewTab: .workspace, workspacePath: [.page(.today)]) }
}

#Preview("iPhone · Documents") {
    ShellPreview { RootView(previewTab: .workspace, workspacePath: [.page(.documents)]) }
}

#Preview("iPhone · Contacts") {
    ShellPreview { RootView(previewTab: .workspace, workspacePath: [.page(.contacts)]) }
}

#Preview("iPhone · Contact") {
    ShellPreview { RootView(previewTab: .workspace, workspacePath: [.page(.contacts), .contact(1)]) }
}

#Preview("iPad · Split View") {
    ShellPreview { RootView() }
}

#Preview("iPad · Agent Chat") {
    ShellPreview { RootView(selection: .agent(1)) }
}

#Preview("iPad · Tasks") {
    ShellPreview { RootView(selection: .page(.tasks(.all))) }
}

#Preview("iPad · Actor Session") {
    ShellPreview { RootView(selection: .actorSession(1)) }
}

#Preview("Settings") {
    ShellPreview {
        NavigationStack { SettingsView() }
    }
}
#endif
