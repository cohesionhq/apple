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

#Preview("iPhone · Today") {
    ShellPreview { RootView(previewTab: .today) }
}

#Preview("iPhone · Tasks") {
    ShellPreview { RootView(previewTab: .tasks, tasksPath: [.page(.tasks(.inbox))]) }
}

#Preview("iPhone · Task Lists") {
    ShellPreview { RootView(previewTab: .tasks, tasksPath: []) }
}

#Preview("iPhone · Agents") {
    ShellPreview { RootView(previewTab: .agents) }
}

#Preview("iPhone · Library") {
    ShellPreview { RootView(previewTab: .library) }
}

#Preview("iPhone · Agent Chat") {
    ShellPreview { RootView(previewTab: .agents, agentPath: [.agent(1)]) }
}

#Preview("iPhone · Actor Session") {
    ShellPreview { RootView(previewTab: .agents, agentPath: [.actorSession(1)]) }
}

#Preview("iPhone · Journal") {
    ShellPreview { RootView(previewTab: .library, libraryPath: [.page(.journal)]) }
}

#Preview("iPhone · Documents") {
    ShellPreview { RootView(previewTab: .library, libraryPath: [.page(.documents)]) }
}

#Preview("iPhone · Feeds") {
    ShellPreview { RootView(previewTab: .library, libraryPath: [.page(.articles(.allFeeds))]) }
}

#Preview("iPhone · Contacts") {
    ShellPreview { RootView(previewTab: .library, libraryPath: [.page(.contacts)]) }
}

#Preview("iPhone · Contact") {
    ShellPreview { RootView(previewTab: .library, libraryPath: [.page(.contacts), .contact(1)]) }
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
