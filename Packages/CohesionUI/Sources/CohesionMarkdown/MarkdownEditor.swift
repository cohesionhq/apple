import SwiftUI
#if canImport(UIKit)
import UIKit

/// Edits Markdown as its source, styled line by line as it is typed (see
/// `MarkdownParagraphStyler`). Return continues a list, and Bold and Italic
/// wrap the selection in `**` and `_`. Tapping a link while not editing
/// follows it through the environment's `openURL`, as Notes does; while
/// editing, a tap places the caret.
/// Ported from the Apple app's `CohesionUI`, so a document edits the same in
/// both.
public struct MarkdownEditor: UIViewRepresentable {
    @Binding var text: String
    /// Inset inside the text container, so the scroll indicator stays at
    /// the view's edge.
    var padding: CGFloat

    public init(text: Binding<String>, padding: CGFloat) {
        _text = text
        self.padding = padding
    }

    public func makeUIView(context: Context) -> NativeTextView {
        // TextKit 2, and only `.textLayoutManager` is touched afterwards:
        // reading `.layoutManager` would silently fall back to TextKit 1.
        let textView = NativeTextView(usingTextLayoutManager: true)
        // The container's own 5pt padding would add to `padding`.
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        (textView.textLayoutManager!.textContentManager as! NSTextContentStorage).delegate = context.coordinator.styler
        textView.backgroundColor = .clear
        // Markdown punctuation stays literal.
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.linkTextAttributes = MarkdownParagraphStyler.linkAttributes
        textView.textContainerInset = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textColor = .label
        textView.typingAttributes = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label,
        ]
        textView.text = text

        let linkTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.followLink(_:)))
        linkTap.delegate = context.coordinator
        textView.addGestureRecognizer(linkTap)
        context.coordinator.openURL = context.environment.openURL

        textView.onToggle = { [weak textView] delimiter in
            guard let textView else { return }
            context.coordinator.toggle(delimiter: delimiter, in: textView)
        }
        return textView
    }

    public func updateUIView(_ textView: NativeTextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.openURL = context.environment.openURL
        // A keystroke comes back through the binding unchanged, so the
        // equality check is what keeps typing from re-entering here; a write
        // from elsewhere lands even while the caret is in the editor. Only
        // an IME composition in progress is left alone.
        if textView.text != text, textView.markedTextRange == nil {
            let selection = textView.selectedRange
            let length = (text as NSString).length
            textView.text = text
            textView.selectedRange = NSRange(
                location: min(selection.location, length),
                length: min(selection.length, max(0, length - selection.location))
            )
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: MarkdownEditor
        let styler = MarkdownParagraphStyler()
        /// Where a tapped link goes, so a `cohesion://` link opens in the app.
        var openURL: OpenURLAction?
        private var isUpdating = false

        init(parent: MarkdownEditor) {
            self.parent = parent
        }

        public func textViewDidChange(_ textView: UITextView) {
            guard !isUpdating else { return }
            parent.text = textView.text
        }

        public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n",
                let edit = MarkdownEditing.returnEdit(in: textView.text as NSString, selection: textView.selectedRange)
            else { return true }
            apply(edit, to: textView)
            return false
        }

        func toggle(delimiter: String, in textView: UITextView) {
            apply(MarkdownEditing.toggleEdit(delimiter: delimiter, in: textView.text as NSString, selection: textView.selectedRange), to: textView)
        }

        @objc func followLink(_ recognizer: UITapGestureRecognizer) {
            guard let textView = recognizer.view as? UITextView,
                  let url = link(at: recognizer.location(in: textView), in: textView)
            else { return }
            openURL?(url)
        }

        /// A tap on a link begins only while not editing, so typing still
        /// places the caret anywhere.
        public func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let textView = recognizer.view as? UITextView, !textView.isFirstResponder else { return false }
            return link(at: recognizer.location(in: textView), in: textView) != nil
        }

        /// The text view's own taps wait for a link tap to fail, so
        /// following a link doesn't also start editing.
        public func gestureRecognizer(
            _ recognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy other: UIGestureRecognizer
        ) -> Bool {
            other.view === recognizer.view
        }

        /// The link under `point`. The styler adds links to the paragraphs
        /// it lays out, not to the text, so it's read from the laid-out
        /// paragraph.
        private func link(at point: CGPoint, in textView: UITextView) -> URL? {
            guard let character = textView.characterRange(at: point),
                  let layoutManager = textView.textLayoutManager,
                  let contentManager = layoutManager.textContentManager
            else { return nil }
            let offset = textView.offset(from: textView.beginningOfDocument, to: character.start)
            let documentStart = contentManager.documentRange.location
            guard let location = contentManager.location(documentStart, offsetBy: offset),
                  let paragraph = layoutManager.textLayoutFragment(for: location)?.textElement as? NSTextParagraph,
                  let paragraphStart = paragraph.elementRange?.location
            else { return nil }
            let index = contentManager.offset(from: paragraphStart, to: location)
            guard index >= 0, index < paragraph.attributedString.length else { return nil }
            let value = paragraph.attributedString.attribute(.link, at: index, effectiveRange: nil)
            return value as? URL ?? (value as? String).flatMap { URL(string: $0) }
        }

        /// Makes `edit` through the text view, so it joins the undo stack.
        private func apply(_ edit: MarkdownEditing.Edit, to textView: UITextView) {
            let start = textView.position(from: textView.beginningOfDocument, offset: edit.range.location)!
            let end = textView.position(from: start, offset: edit.range.length)!
            textView.replace(textView.textRange(from: start, to: end)!, withText: edit.replacement)
            textView.selectedRange = edit.selection
            isUpdating = true
            parent.text = textView.text
            isUpdating = false
        }
    }

    /// Routes the edit menu's and keyboard's Bold and Italic to Markdown.
    public final class NativeTextView: UITextView {
        var onToggle: ((String) -> Void)?

        public override func toggleBoldface(_ sender: Any?) {
            onToggle?("**")
        }

        public override func toggleItalics(_ sender: Any?) {
            onToggle?("_")
        }
    }
}
#else
import AppKit

/// Edits Markdown as its source, styled line by line as it is typed (see
/// `MarkdownParagraphStyler`), as on iOS. Return continues a list, and ⌘B
/// and ⌘I wrap the selection in `**` and `_`. Clicking a link while not
/// editing follows it through the environment's `openURL`; while editing,
/// a click places the caret.
public struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    /// Inset inside the text container, so the scroller stays at the view's
    /// edge.
    var padding: CGFloat

    public init(text: Binding<String>, padding: CGFloat) {
        _text = text
        self.padding = padding
    }

    public func makeNSView(context: Context) -> NSScrollView {
        // TextKit 2, and only `.textLayoutManager` is touched afterwards:
        // reading `.layoutManager` would silently fall back to TextKit 1.
        let textView = NativeTextView(usingTextLayoutManager: true)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = .width
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        // The container's own 5pt padding would add to `padding`.
        textView.textContainer?.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        textView.textContentStorage?.delegate = context.coordinator.styler
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        // Markdown punctuation stays literal.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.linkTextAttributes = MarkdownParagraphStyler.linkAttributes
        textView.textContainerInset = NSSize(width: padding, height: padding)
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textColor = .labelColor
        textView.typingAttributes = [
            .font: NSFont.preferredFont(forTextStyle: .body),
            .foregroundColor: NSColor.labelColor,
        ]
        textView.string = text
        context.coordinator.openURL = context.environment.openURL
        textView.followLink = { [weak textView, coordinator = context.coordinator] point in
            guard let textView, let url = coordinator.link(at: point, in: textView) else { return false }
            coordinator.openURL?(url)
            return true
        }
        textView.onToggle = { [weak textView, coordinator = context.coordinator] delimiter in
            guard let textView else { return }
            coordinator.toggle(delimiter: delimiter, in: textView)
        }

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.openURL = context.environment.openURL
        guard let textView = scrollView.documentView as? NativeTextView else { return }
        // A keystroke comes back through the binding unchanged, so the
        // equality check is what keeps typing from re-entering here; a write
        // from elsewhere lands even while the caret is in the editor. Only
        // an IME composition in progress is left alone.
        if textView.string != text, !textView.hasMarkedText() {
            let selection = textView.selectedRange()
            let length = (text as NSString).length
            textView.string = text
            textView.setSelectedRange(NSRange(
                location: min(selection.location, length),
                length: min(selection.length, max(0, length - selection.location))
            ))
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        let styler = MarkdownParagraphStyler()
        /// Where a clicked link goes, so a `cohesion://` link opens in the app.
        var openURL: OpenURLAction?
        private var isUpdating = false

        init(parent: MarkdownEditor) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        public func textView(
            _ textView: NSTextView,
            shouldChangeTextIn range: NSRange,
            replacementString text: String?
        ) -> Bool {
            guard !isUpdating, text == "\n",
                  let edit = MarkdownEditing.returnEdit(in: textView.string as NSString, selection: textView.selectedRange())
            else { return true }
            apply(edit, to: textView)
            return false
        }

        func toggle(delimiter: String, in textView: NSTextView) {
            apply(MarkdownEditing.toggleEdit(delimiter: delimiter, in: textView.string as NSString, selection: textView.selectedRange()), to: textView)
        }

        /// The link under `point`, in the view's coordinates. The styler adds
        /// links to the paragraphs it lays out, not to the text, so it's read
        /// from the laid-out paragraph.
        func link(at point: CGPoint, in textView: NSTextView) -> URL? {
            let offset = textView.characterIndexForInsertion(at: textView.convert(point, to: nil).screenPoint(in: textView))
            guard let layoutManager = textView.textLayoutManager,
                  let contentManager = layoutManager.textContentManager,
                  let location = contentManager.location(contentManager.documentRange.location, offsetBy: offset),
                  let paragraph = layoutManager.textLayoutFragment(for: location)?.textElement as? NSTextParagraph,
                  let paragraphStart = paragraph.elementRange?.location
            else { return nil }
            let index = contentManager.offset(from: paragraphStart, to: location)
            guard index >= 0, index < paragraph.attributedString.length else { return nil }
            let value = paragraph.attributedString.attribute(.link, at: index, effectiveRange: nil)
            return value as? URL ?? (value as? String).flatMap { URL(string: $0) }
        }

        /// Makes `edit` through the text view, so it joins the undo stack.
        private func apply(_ edit: MarkdownEditing.Edit, to textView: NSTextView) {
            isUpdating = true
            defer { isUpdating = false }
            guard textView.shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return }
            textView.replaceCharacters(in: edit.range, with: edit.replacement)
            textView.didChangeText()
            textView.setSelectedRange(edit.selection)
            parent.text = textView.string
        }
    }

    /// Routes ⌘B and ⌘I to Markdown, and a click on a link while not editing
    /// to the link.
    public final class NativeTextView: NSTextView {
        var onToggle: ((String) -> Void)?
        /// Follows the link at a point in the view, returning whether there
        /// was one.
        var followLink: ((CGPoint) -> Bool)?

        public override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard window?.firstResponder === self,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
            else { return super.performKeyEquivalent(with: event) }
            switch event.charactersIgnoringModifiers {
            case "b": onToggle?("**")
            case "i": onToggle?("_")
            default: return super.performKeyEquivalent(with: event)
            }
            return true
        }

        public override func mouseDown(with event: NSEvent) {
            if window?.firstResponder !== self, followLink?(convert(event.locationInWindow, from: nil)) == true { return }
            super.mouseDown(with: event)
        }
    }
}

private extension CGPoint {
    /// This point, in `view`'s window, on the screen.
    func screenPoint(in view: NSView) -> CGPoint {
        view.window?.convertPoint(toScreen: self) ?? self
    }
}
#endif
