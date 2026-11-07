import AppIntents
import CohesionCore
import CohesionScreens
import SwiftUI

/// Includes the intents the controls and Shortcuts run from `CohesionCore`.
nonisolated struct CohesionAppIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [CohesionCoreIntents.self] }
}

@main
struct CohesionApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    init() {
        // An intent can launch the app, and needs this as soon as it does.
        AppDependencyManager.shared.add(dependency: AppLinkOpener { AppDelegate.model.pendingLink = $0 })
    }

    var body: some Scene {
        // Each window shows its own workspace and screens over the app's one
        // pairing and connection, so pairing or unpairing in one applies to
        // all. The id names the windows' scenes across launches.
        WindowGroup(id: "main") {
            WindowContent { RootView() }
                .environment(appDelegate.model)
                .environment(appDelegate.push)
        }
        .commands {
            SettingsCommand()
            DashboardCommand()
        }
    }
}

/// Settings… (⌘,) in the app menu, opening settings in the focused window,
/// and unavailable until the window is paired.
private struct SettingsCommand: Commands {
    @FocusedValue(\.isShowingSettings) private var isShowingSettings

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { isShowingSettings?.wrappedValue = true }
                .keyboardShortcut(",")
                .disabled(isShowingSettings == nil)
        }
    }
}

/// Dashboard (⇧⌘D) in the View menu, opening it in the focused window, and
/// unavailable until the window is paired.
private struct DashboardCommand: Commands {
    @FocusedValue(\.showDashboard) private var showDashboard

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Dashboard") { showDashboard?() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(showDashboard == nil)
        }
    }
}
