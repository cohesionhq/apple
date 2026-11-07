import CohesionCore
import SwiftUI
import WebKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

extension EnvironmentValues {
    /// The client a diagram asks to be drawn. Set for a window's whole
    /// content, since Markdown knows nothing of the app's model.
    @Entry public var cohesionClient: CohesionClient?
}

/// A ```` ```mermaid ```` block drawn by cohesiond and shown as the web UI
/// shows it, in the app's colours and the system font, following light and
/// dark. It's asked for once it's on screen and connected, laid out for the
/// width it first has: a resize scales what's drawn, and a diagram laid out
/// wider than it was asked to be scrolls sideways when it doesn't fit.
/// `fallback` shows until the source draws, and for good if it never does: a
/// block still streaming in, or one that isn't a diagram, stays the code it
/// was written as, as it does on a daemon without the command.
public struct MarkdownDiagram<Fallback: View>: View {
    public let source: String
    @ViewBuilder public let fallback: Fallback

    public init(source: String, @ViewBuilder fallback: () -> Fallback) {
        self.source = source
        self.fallback = fallback()
    }

    @Environment(\.cohesionClient) private var client
    @Environment(\.colorScheme) private var colorScheme
    /// The width to lay out for, taken once: asking again would mean a new
    /// layout for every step of a resize.
    @State private var layoutWidth: Int?
    @State private var isOnScreen = false
    /// The diagram as last drawn; kept while a new source draws, so a
    /// growing diagram doesn't flash back to code.
    @State private var drawing: Drawing?

    /// A diagram as received, cleaned and ready to show.
    private struct Drawing: Equatable {
        let svg: String
        let width: CGFloat
        let height: CGFloat
        /// The width it was asked for; it can come back wider.
        let layoutWidth: Int
    }

    /// What asking depends on.
    private struct Request: Equatable {
        let source: String
        let width: Int?
        let isOnScreen: Bool
        let isConnected: Bool
    }

    public var body: some View {
        Group {
            if let drawing {
                diagram(drawing)
            } else {
                fallback
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onGeometryChange(for: CGFloat.self, of: \.size.width) { width in
                        if layoutWidth == nil, width >= 1 { layoutWidth = Int(width) }
                    }
            }
        }
        .onScrollVisibilityChange(threshold: 0.01) { isOnScreen = $0 }
        .task(id: Request(
            source: source,
            width: layoutWidth,
            isOnScreen: isOnScreen,
            isConnected: client?.connection == .connected
        )) {
            await draw()
        }
    }

    /// Shows what's kept for the source, or asks for it when it can. A
    /// failed request leaves things as they are.
    private func draw() async {
        guard let client, let layoutWidth else { return }
        let rendered: RenderedMermaid
        if let kept = client.keptMermaid(source, width: layoutWidth) {
            rendered = kept
        } else {
            guard isOnScreen, client.connection == .connected else { return }
            // A diagram streaming in changes with every delta, and a request
            // already sent still costs the daemon its layout: only what the
            // source settles on is asked for.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled,
                  let reply = try? await client.renderMermaid(source, width: layoutWidth),
                  !Task.isCancelled
            else { return }
            rendered = reply
        }
        switch rendered {
        case .svg(let svg, let width, let height):
            guard width > 0, height > 0, let svg = MermaidSVG.sanitized(svg) else {
                drawing = nil
                return
            }
            drawing = Drawing(svg: svg, width: width, height: height, layoutWidth: layoutWidth)
        case .refused:
            drawing = nil
        }
    }

    @ViewBuilder
    private func diagram(_ drawing: Drawing) -> some View {
        let page = MermaidPage(
            html: MermaidPage.html(svg: drawing.svg, variables: variables)
        )
        Group {
            if drawing.width > CGFloat(drawing.layoutWidth) {
                // Too wide for the width it was asked for, so scaling would
                // shrink its text: its own size, scrolling when it doesn't fit.
                ViewThatFits(in: .horizontal) {
                    page.frame(width: drawing.width, height: drawing.height)
                    ScrollView(.horizontal, showsIndicators: false) {
                        page.frame(width: drawing.width, height: drawing.height)
                    }
                }
            } else {
                page
                    .aspectRatio(drawing.width / drawing.height, contentMode: .fit)
                    .frame(idealWidth: drawing.width, maxWidth: drawing.width)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Diagram")
    }

    /// Pele's variables, from the same colours the web UI's tokens name: the
    /// page's text and greys over the page it sits on, and for charts the
    /// accent, then the agent colours.
    private var variables: [(String, String)] {
        var environment = EnvironmentValues()
        environment.colorScheme = colorScheme
        let page = Color.diagramPage.resolve(in: environment)
        let foreground = Color.primary.resolve(in: environment)
        func css(_ color: Color) -> String { color.resolve(in: environment).cssColor }
        func shade(_ amount: Float) -> String { page.mixed(with: foreground, amount).cssColor }
        let series: [Color] = [.accentColor, .green, .orange, .purple, .teal, .pink, .yellow, .red]
        return [
            ("bg", page.cssColor),
            ("fg", foreground.cssColor),
            ("muted", shade(0.6)),
            ("line", shade(0.5)),
            ("surface", shade(0.06)),
            ("surface-alt", shade(0.12)),
            ("border", shade(0.3)),
            ("accent", css(.accentColor)),
            ("font", "system-ui"),
        ] + series.enumerated().map { ("series-\($0.offset + 1)", css($0.element)) }
    }
}

extension Color {
    /// What a diagram sits on, which its edge labels are filled with: the page.
    fileprivate static var diagramPage: Color {
        #if canImport(UIKit)
        Color(UIColor.systemBackground)
        #else
        Color(NSColor.windowBackgroundColor)
        #endif
    }
}

extension Color.Resolved {
    /// The colour as CSS takes it.
    fileprivate var cssColor: String {
        let channels = [red, green, blue, opacity].map { Int((min(max($0, 0), 1) * 255).rounded()) }
        return "#" + channels.map { String(format: "%02x", $0) }.joined()
    }

    /// `amount` of `other` over this colour, opaque so that a shape filled
    /// with it hides the lines under it.
    fileprivate func mixed(with other: Color.Resolved, _ amount: Float) -> Color.Resolved {
        Color.Resolved(
            red: red + (other.red - red) * amount,
            green: green + (other.green - green) * amount,
            blue: blue + (other.blue - blue) * amount
        )
    }
}

/// A web view showing one cleaned diagram, the only thing here that draws
/// SVG with text and CSS. It's a picture and nothing else: no script runs,
/// nothing loads, nothing navigates, and touches and the scroll wheel pass
/// through to what's around it.
private struct MermaidPage {
    let html: String

    /// `svg` in a page of its own, filling it, on nothing, with `variables`
    /// (each a `--pele-` variable's name and value) set.
    static func html(svg: String, variables: [(String, String)]) -> String {
        let declarations = variables.map { "--pele-\($0.0):\($0.1);" }.joined()
        return """
            <!doctype html><html><head><meta charset="utf-8">\
            <meta name="viewport" content="width=device-width,initial-scale=1">\
            <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:">\
            <style>:root{\(declarations)}html,body{margin:0;background:transparent;overflow:hidden;\
            -webkit-text-size-adjust:100%}svg{display:block}</style></head><body>\(svg)</body></html>
            """
    }

    private func makeWebView(_ coordinator: Coordinator) -> PassThroughWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = PassThroughWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = coordinator
        #if canImport(UIKit)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        #else
        // The one way to take away a Mac web view's white page.
        webView.setValue(false, forKey: "drawsBackground")
        #endif
        return webView
    }

    /// Loads `html` unless it's already what's showing, so that an update
    /// that changes nothing doesn't draw it again.
    private func update(_ webView: WKWebView, _ coordinator: Coordinator) {
        guard coordinator.html != html else { return }
        coordinator.html = html
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var html: String?

        /// Only what's loaded here: nothing in a page goes anywhere else.
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            navigationAction.navigationType == .other ? .allow : .cancel
        }

        /// The system ends a web view's process as it pleases, as it often
        /// does in the background, which would leave the diagram blank.
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            if let html { webView.loadHTMLString(html, baseURL: nil) }
        }
    }
}

#if canImport(UIKit)
extension MermaidPage: UIViewRepresentable {
    func makeUIView(context: Context) -> PassThroughWebView {
        makeWebView(context.coordinator)
    }

    func updateUIView(_ webView: PassThroughWebView, context: Context) {
        update(webView, context.coordinator)
    }
}

private final class PassThroughWebView: WKWebView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}
#else
extension MermaidPage: NSViewRepresentable {
    func makeNSView(context: Context) -> PassThroughWebView {
        makeWebView(context.coordinator)
    }

    func updateNSView(_ webView: PassThroughWebView, context: Context) {
        update(webView, context.coordinator)
    }
}

private final class PassThroughWebView: WKWebView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
#endif
