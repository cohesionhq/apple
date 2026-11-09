import CohesionCore
import CohesionUI
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Registers this device with cohesiond using the setup code it printed.
struct PairingView: View {
    /// The name a new client is offered: the device's name and the app's,
    /// as `generatedClientName(device:client:)` formats them. What the user
    /// types over it is registered as typed.
    private static var generatedName: String {
        #if os(iOS)
        let device: String? = UIDevice.current.name
        #else
        let device = Host.current().localizedName
        #endif
        let app = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        return generatedClientName(device: device, client: app ?? "Cohesion")
    }

    @Environment(AppModel.self) private var model

    @State private var setupCode = ""
    @State private var clientName = generatedName
    @State private var isPairing = false
    @State private var error: (any Error)?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Setup Code", text: $setupCode, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                } footer: {
                    Text("cohesiond prints a setup code when it starts.")
                }
                Section {
                    TextField("Name", text: $clientName)
                } footer: {
                    Text("How Cohesion lists this app.")
                }
                Section {
                    Button(action: pair) {
                        if isPairing {
                            ProgressView()
                        } else {
                            Text("Pair")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(setupCode.isEmpty || clientName.isEmpty || isPairing)
                }
            }
            .navigationTitle("Pair with Cohesion")
            .errorAlert($error)
        }
    }

    private func pair() {
        isPairing = true
        Task {
            do {
                try await model.pair(setupCode: setupCode, clientName: clientName)
            } catch {
                self.error = error
            }
            isPairing = false
        }
    }
}
