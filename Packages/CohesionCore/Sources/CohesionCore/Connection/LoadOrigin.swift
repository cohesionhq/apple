import Foundation

/// Why a screen is loading, which decides whether a failure says so: only a
/// load the user asked for alerts. Anything else keeps what's on screen, and
/// the next change, reconnect or return to the foreground loads it again.
public enum LoadOrigin {
    /// Opening a screen, pulling to refresh, Reload.
    case asked
    /// A change cohesiond reported, a socket reconnecting, the app returning
    /// to the foreground or launching, or the reload after an action.
    case automatic

    /// Runs `load`, tried again after 1, 2 and 4 seconds while the server
    /// can't be reached; a reply refusing it would only refuse it again.
    /// `failed` hears the last failure of a load that was asked for. A load
    /// cut short by leaving the screen isn't a failure.
    public func run(_ load: () async throws -> Void, failed: (any Error) -> Void = { _ in }) async {
        for delay in [1, 2, 4, nil] as [Int?] {
            do {
                return try await load()
            } catch {
                guard !Task.isCancelled else { return }
                if error is URLError, let delay {
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { return }
                } else {
                    if self == .asked { failed(error) }
                    return
                }
            }
        }
    }
}
