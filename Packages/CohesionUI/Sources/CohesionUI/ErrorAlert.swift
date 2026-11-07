import SwiftUI

extension View {
    /// Shows `error` in an alert until it is dismissed.
    public func errorAlert(_ error: Binding<(any Error)?>) -> some View {
        alert(
            "Something Went Wrong",
            isPresented: Binding(
                get: { error.wrappedValue != nil },
                set: { if !$0 { error.wrappedValue = nil } }
            ),
            presenting: error.wrappedValue
        ) { _ in
            Button("OK") {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}
