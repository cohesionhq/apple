import SwiftUI
import UIKit

extension View {
    /// Titles the window, as the iPad's app switcher, Stage Manager and
    /// the app's windows show it.
    func windowTitle(_ title: String) -> some View {
        background(SceneTitle(title: title))
    }
}

private struct SceneTitle: UIViewRepresentable {
    let title: String

    func makeUIView(context: Context) -> SceneTitleView {
        let view = SceneTitleView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: SceneTitleView, context: Context) {
        view.title = title
    }
}

/// Sets its scene's title once it's in a window, and as the title changes.
private final class SceneTitleView: UIView {
    var title = "" {
        didSet { apply() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        apply()
    }

    private func apply() {
        window?.windowScene?.title = title
    }
}
