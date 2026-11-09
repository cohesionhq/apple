import CohesionCore
import Foundation
import Observation

/// What the app does beyond the connection when it pairs and unpairs: on
/// iOS, registering for notifications.
public protocol PairingObserver: AnyObject {
    func didPair(using client: CohesionClient) async
    func forget(using client: CohesionClient?) async
}

/// The paired server, its connection and workspaces, shared by every
/// window; what one window shows is its `WindowModel`.
@Observable
public final class AppModel {
    private static let workspaceKey = "workspaceID"

    public private(set) var pairing: Pairing?
    public private(set) var client: CohesionClient?
    public private(set) var workspaces: [Workspace] = []
    /// Set when cohesiond revoked the pairing this app forgot, until the
    /// user goes on to pair again.
    public private(set) var wasRevoked = false
    /// Whether the keychain couldn't be read when last asked, as before the
    /// device's first unlock, so a saved pairing may yet be there.
    public private(set) var isRestoringPairing = false
    /// Told of pairing and unpairing; `nil` when the app has nothing to do.
    private let pairingObserver: (any PairingObserver)?
    /// What a tapped notification opens, until the active window's shell
    /// takes it with `takePendingLink()`.
    public var pendingLink: AppLink?
    /// The agents whose chats are on screen, in any window, whose
    /// notifications aren't shown; an agent once for each chat of its open.
    public var shownAgentIDs: [Int] = []
    /// Replies a notification couldn't send and the user tapped to go back
    /// to, by agent, until that agent's chat puts them in its field.
    public var failedReplies: [Int: String] = [:]

    /// The workspace last picked in any window, which a new window opens
    /// on; remembered across launches.
    public var lastWorkspaceID: Int? = UserDefaults.standard.object(forKey: AppModel.workspaceKey) as? Int {
        didSet { UserDefaults.standard.set(lastWorkspaceID, forKey: Self.workspaceKey) }
    }

    /// How to word cohesiond's kinds; empty until the server's first hello.
    public var vocabulary: Vocabulary {
        client?.vocabulary ?? Vocabulary()
    }

    public init(pairingObserver: (any PairingObserver)? = nil) {
        self.pairingObserver = pairingObserver
        restorePairing()
    }

    #if DEBUG
    /// An app for `#Preview`s, paired with `client` and on its workspaces as
    /// listed, with nothing read from or saved to the device.
    public init(previewClient client: CohesionClient) {
        pairingObserver = nil
        self.client = client
        workspaces = client.keptWorkspaces() ?? []
    }
    #endif

    /// Reads the saved pairing unless there's a connection already, blocking
    /// for the keychain's answer, which never waits on the user. A launch
    /// before the device's first unlock can't read it, nor the user's
    /// defaults, so each new window reads it again before it shows; one that
    /// still can't asks again when it becomes active, and the device
    /// unlocking does.
    public func restorePairing() {
        guard client == nil else { return }
        switch Pairing.read() {
        case .paired(let pairing):
            isRestoringPairing = false
            self.pairing = pairing
            client = try? CohesionClient(pairing: pairing, keepsReplies: true)
            // As last listed, so the selected workspace's lists show at once.
            workspaces = client?.keptWorkspaces() ?? []
            if let workspaceID = UserDefaults.standard.object(forKey: Self.workspaceKey) as? Int {
                lastWorkspaceID = workspaceID
            }
        case .unpaired:
            isRestoringPairing = false
        case .unavailable:
            isRestoringPairing = true
        }
    }

    /// Registers with the server that printed `setupCode`.
    public func pair(setupCode: String, clientName: String) async throws {
        let code = try SetupCode(setupCode)
        let pairing = try Pairing(setupCode: code, clientName: clientName)
        try await CohesionClient.register(pairing, setupKey: code.key, clientName: clientName)
        pairing.save()
        self.pairing = pairing
        let client = try CohesionClient(pairing: pairing, keepsReplies: true)
        self.client = client
        // The new server's companion may sign in to another cloud account.
        Task { [pairingObserver] in await pairingObserver?.didPair(using: client) }
    }

    /// Forgets a pairing cohesiond revoked, which can never connect again,
    /// and says so until the user pairs again.
    public func forgetRevokedPairing() {
        // Every window sees the revoke; the first forgets it.
        guard client != nil else { return }
        unpair()
        wasRevoked = true
    }

    /// Leaves the revoked notice for pairing.
    public func pairAgain() {
        wasRevoked = false
    }

    public func unpair() {
        // Removed from the cloud while the old server can still grant it.
        let oldClient = client
        Task { [pairingObserver] in await pairingObserver?.forget(using: oldClient) }
        Pairing.remove()
        // What the lists showed belongs to the server left.
        KeptReplies.forgetAll()
        pairing = nil
        client = nil
        workspaces = []
        failedReplies = [:]
        lastWorkspaceID = nil
    }

    /// Hands the pending link to the window that asks first, so only one
    /// opens it.
    public func takePendingLink() -> AppLink? {
        defer { pendingLink = nil }
        return pendingLink
    }

    public func loadWorkspaces() async throws {
        guard let client else { return }
        workspaces = try await client.listWorkspaces()
    }
}
