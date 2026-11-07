import CohesionCore
import SwiftUI
import UIKit

/// Hosts `ShareToAgentView` for the web page another app shares.
///
/// The pairing comes from the app's keychain group, so the extension talks
/// to cohesiond with the app's certificate.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = extensionContext
        Task {
            let url = await sharedURL()
            show(ShareToAgentView(
                client: Pairing.load().flatMap { try? CohesionClient(pairing: $0) },
                url: url,
                onFinish: { context?.completeRequest(returningItems: nil) },
                onCancel: { context?.cancelRequest(withError: CocoaError(.userCancelled)) }
            ))
        }
    }

    /// The URL attachment the activation rule requires; it comes from outside,
    /// so anything but a web address is `nil`.
    private func sharedURL() async -> URL? {
        guard let provider = (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap({ $0.attachments ?? [] })
            .first(where: { $0.canLoadObject(ofClass: URL.self) })
        else { return nil }
        return await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                let isWebAddress = url?.host() != nil && ["http", "https"].contains(url?.scheme?.lowercased())
                continuation.resume(returning: isWebAddress ? url : nil)
            }
        }
    }

    private func show(_ root: ShareToAgentView) {
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}
