import CohesionCore
import CohesionUI
import SwiftUI

/// A contact's or the user's photo on a disc, or, without one, an empty
/// disc with `name`'s initials or else a person glyph, half its diameter,
/// as the web draws it, so names line up.
struct ContactPhotoView: View {
    let photo: ContactPhoto
    /// Drawn as initials when there is no photo; the contacts list leaves
    /// it out, for the glyph.
    var name: String?
    /// 40 spans a row's two lines of text.
    var diameter: CGFloat = 40

    var body: some View {
        Group {
            if let image = photo.image {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Group {
                    if let initials {
                        Text(initials)
                            .font(.system(size: diameter * 0.5, weight: .semibold))
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: diameter * 0.5))
                    }
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.fill.tertiary)
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }

    /// The first word's and the last word's first letters, capitalized, as
    /// the web's; `nil` for no name.
    private var initials: String? {
        let words = (name ?? "").split(whereSeparator: \.isWhitespace)
        guard let first = words.first?.first else { return nil }
        let last = words.count > 1 ? words.last?.first.map(String.init) ?? "" : ""
        return (String(first) + last).uppercased()
    }
}

/// A contact in the list: their photo, their name, and the first way to
/// reach them, as the web's row has them.
struct ContactRow: View {
    let contact: Contact

    var body: some View {
        HStack {
            ContactPhotoView(photo: contact.photo)
            VStack(alignment: .leading) {
                Text(contact.fullName)
                if let first = contact.methods.first {
                    Text(first.value)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension [Contact] {
    /// The contacts whose full name holds every word of `query`, ignoring
    /// case, as the web's filter matches; all of them for an empty one.
    func matching(_ query: String) -> [Contact] {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return self }
        return filter { contact in
            words.allSatisfy { contact.fullName.localizedCaseInsensitiveContains($0) }
        }
    }
}
