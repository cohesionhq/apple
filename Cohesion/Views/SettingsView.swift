import CohesionCore
import CohesionScreens
import CohesionUI
import SwiftUI
import UIKit

/// Settings as the Settings app lays them out: the paired server's
/// settings in one section, this device's in another, each a row with an
/// icon that opens its own page; the server's About page is the last of
/// its rows.
struct SettingsView: View {
    @Environment(PushRegistration.self) private var push
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Server") {
                NavigationLink { ProfileView() } label: {
                    Label("Profile", systemImage: "person.crop.circle.fill", color: .orange)
                }
                NavigationLink { ModelSettingsView() } label: {
                    Label("Agents", systemImage: "sparkles", color: .purple)
                }
                NavigationLink { MemorySettingsView() } label: {
                    Label("Memories", systemImage: "brain", color: .pink)
                }
                NavigationLink { ClientsView() } label: {
                    Label("Clients", systemImage: "laptopcomputer.and.iphone", color: .blue)
                }
                NavigationLink { ExtensionsView() } label: {
                    Label("Extensions", systemImage: "puzzlepiece.extension.fill", color: .teal)
                }
                NavigationLink {
                    Form { AboutSection() }
                        .navigationTitle("About")
                } label: {
                    Label("About", systemImage: "info", color: .gray)
                }
            }
            Section("This \(UIDevice.current.model)") {
                NavigationLink {
                    Form { NotificationsSection() }
                        .navigationTitle("Notifications")
                } label: {
                    LabeledContent {
                        Text(push.status.summary)
                    } label: {
                        Label("Notifications", systemImage: "bell.badge.fill", color: .red)
                    }
                }
                NavigationLink {
                    Form { LiveActivitiesSection() }
                        .navigationTitle("Live Activities")
                } label: {
                    LabeledContent {
                        Text(push.liveActivitiesEnabled ? "On" : "Off")
                    } label: {
                        Label("Live Activities", systemImage: "platter.filled.top.iphone", color: .green)
                    }
                }
            }
            Section {
                UnpairButton()
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Nothing here waits to be saved, so it closes rather than confirms.
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark", role: .close) { dismiss() }
            }
        }
    }
}

private extension PushRegistration.Status {
    /// The status in a word, for the row that opens the notifications page.
    var summary: String {
        switch self {
        case .registered: "On"
        case .registering: "Registering…"
        case .notRequested, .denied, .failed, .unavailable: "Off"
        }
    }
}

/// Whether agent messages reach this device, and the button that changes it.
private struct NotificationsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(PushRegistration.self) private var push
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            LabeledContent("Status") {
                Text(push.status.description)
                    .multilineTextAlignment(.trailing)
            }
            if push.notificationsDenied, case .registered = push.status {
                Label("Notifications are turned off for Cohesion in the Settings app. Live Activities still show.", systemImage: "bell.slash")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                }
            }
            if let warning = push.warning {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if case .registered(let account, let date) = push.status {
                LabeledContent("Account", value: account)
                LabeledContent("Registered", value: date.formatted(date: .abbreviated, time: .shortened))
            }
            switch push.status {
            case .registering:
                ProgressView()
                    .frame(maxWidth: .infinity)
            case .denied:
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                }
            case .registered:
                Button("Register Again") { run { await push.requestAndRegister(using: $0) } }
                Button("Turn Off", role: .destructive) { run { await push.unregister(using: $0) } }
            case .failed, .unavailable:
                Button(push.isStoredRegistration ? "Register Again" : "Enable Notifications") {
                    run { await push.requestAndRegister(using: $0) }
                }
                if push.isStoredRegistration {
                    Button("Turn Off", role: .destructive) { run { await push.unregister(using: $0) } }
                }
            case .notRequested:
                Button("Enable Notifications") { run { await push.requestAndRegister(using: $0) } }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Agent messages, and a note when an extension update is available, are sent through Cohesion Cloud. cohesiond needs the iOS Companion extension installed, with its oauth, network and service:isolated permissions enabled, and signed in to Cohesion Cloud.")
        }
    }

    private func run(_ action: @escaping (CohesionClient) async -> Void) {
        guard let client = model.client else { return }
        Task { await action(client) }
    }
}

/// Whether iOS lets the app show Live Activities, and update them often,
/// which only the Settings app can change.
private struct LiveActivitiesSection: View {
    @Environment(PushRegistration.self) private var push
    @Environment(\.openURL) private var openURL

    var body: some View {
        let enabled = push.liveActivitiesEnabled
        let frequent = push.frequentPushesEnabled
        Section {
            LabeledContent("Status", value: enabled ? "On" : "Off")
            if !enabled {
                Label("Live Activities are turned off for Cohesion in the Settings app, so running work won\u{2019}t show on the Lock Screen or in the Dynamic Island.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                openSettings
            } else {
                LabeledContent("Frequent Updates", value: frequent ? "On" : "Off")
                if !frequent {
                    Label("Frequent updates are turned off for Cohesion in the Settings app, so iOS may hold back progress and show it late.", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    openSettings
                }
            }
        } header: {
            Text("Live Activities")
        } footer: {
            Text("Agent runs and actor sessions on the Lock Screen and in the Dynamic Island, sent through Cohesion Cloud.")
        }
    }

    private var openSettings: some View {
        Button("Open Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        }
    }
}
