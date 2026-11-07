import CohesionCore
import SwiftUI

#if canImport(UIKit)
import UIKit

/// The system's clipboard.
public typealias Pasteboard = UIPasteboard

extension Image {
    public init(platformImage image: PlatformImage) {
        self.init(uiImage: image)
    }
}
#else
import AppKit

/// The system's clipboard, by the names `UIPasteboard` has for what the
/// screens copy and paste.
public struct Pasteboard {
    public static var general: Pasteboard { Pasteboard() }

    public var string: String? {
        get { NSPasteboard.general.string(forType: .string) }
        nonmutating set {
            NSPasteboard.general.clearContents()
            if let newValue { NSPasteboard.general.setString(newValue, forType: .string) }
        }
    }

    public var url: URL? {
        get { NSURL(from: NSPasteboard.general).map { $0 as URL } }
        nonmutating set {
            NSPasteboard.general.clearContents()
            if let newValue { NSPasteboard.general.writeObjects([newValue as NSURL]) }
        }
    }

    public var images: [PlatformImage]? {
        NSPasteboard.general.readObjects(forClasses: [NSImage.self]) as? [NSImage]
    }
}

extension Image {
    public init(platformImage image: PlatformImage) {
        self.init(nsImage: image)
    }
}

// What the screens ask of iOS's keyboards, navigation bars and pointer has
// no counterpart on the Mac; these leave the screens' code as it is.

/// What a field's keyboard is for; the Mac has only the one keyboard.
public enum MacKeyboardKind {
    case URL, emailAddress, phonePad, decimalPad
}

/// How a field capitalizes; the Mac's fields don't.
public enum MacAutocapitalization {
    case never
}

/// What a field holds, for iOS's autofill.
public enum MacTextContentKind {
    case name, givenName, middleName, familyName, emailAddress, telephoneNumber, URL
}

/// How a navigation bar shows its title; the Mac has a window's title.
public enum MacTitleDisplayMode {
    case inline, large, automatic
}

/// How the keyboard is dismissed by scrolling; the Mac's stays put.
public enum MacKeyboardDismissMode {
    case interactively
}

extension View {
    public func keyboardType(_ kind: MacKeyboardKind) -> some View { self }
    public func textInputAutocapitalization(_ style: MacAutocapitalization?) -> some View { self }
    public func textContentType(_ kind: MacTextContentKind) -> some View { self }
    public func navigationBarTitleDisplayMode(_ mode: MacTitleDisplayMode) -> some View { self }
    public func hoverEffect() -> some View { self }
    public func hoverEffect(_ effect: MacHoverEffect) -> some View { self }

    /// A sheet, since a Mac window has no full-screen cover.
    public func fullScreenCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item) { content($0).frame(minWidth: 640, minHeight: 480) }
    }

    /// A sheet, since a Mac window has no full-screen cover.
    public func fullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented) { content().frame(minWidth: 640, minHeight: 480) }
    }
}

/// A pointer's highlight; the Mac's controls draw their own.
public enum MacHoverEffect {
    case highlight
}

extension ContentShapeKinds {
    public static var hoverEffect: ContentShapeKinds { .interaction }
}
#endif

extension View {
    /// Opens by zooming out of the view marked with `id` in `namespace` on
    /// iOS; on the Mac, where a push has no zoom, as any push does.
    public func zoomTransition(from id: some Hashable, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
        navigationTransition(.zoom(sourceID: id, in: namespace))
        #else
        self
        #endif
    }

    /// A sheet, at a size of its own on the Mac, where one fits its content
    /// and a form's fields would collapse; iOS's sheets size themselves.
    public func sizedSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented) { content().macSheetFrame() }
    }

    /// A sheet, at a size of its own on the Mac, where one fits its content
    /// and a form's fields would collapse; iOS's sheets size themselves.
    public func sizedSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item) { content($0).macSheetFrame() }
    }

    fileprivate func macSheetFrame() -> some View {
        #if os(macOS)
        frame(minWidth: 480, idealWidth: 520, minHeight: 420, idealHeight: 560)
        #else
        self
        #endif
    }
}
