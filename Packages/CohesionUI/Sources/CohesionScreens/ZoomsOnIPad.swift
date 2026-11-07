import SwiftUI

extension View {
    /// On iPad, opens by zooming out of the row marked with `id` in
    /// `namespace`; on iPhone, it's pushed, and on the Mac it replaces the
    /// list.
    func zoomsOnIPad(from id: some Hashable, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
        modifier(ZoomsOnIPad(id: AnyHashable(id), namespace: namespace))
        #else
        self
        #endif
    }
}

#if os(iOS)
private struct ZoomsOnIPad: ViewModifier {
    let id: AnyHashable
    let namespace: Namespace.ID

    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}
#endif
