import CohesionCore
import CohesionUI
import SwiftUI

/// Shown once cohesiond revoked this client, whose pairing is gone: nothing
/// reconnects, and pairing again is the way back.
struct RevokedView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label("This client was revoked", systemImage: "xmark.shield")
        } description: {
            Text("Pair it again to reconnect.")
        } actions: {
            Button("Pair Again", action: model.pairAgain)
                .buttonStyle(.borderedProminent)
        }
    }
}
