import CohesionCore
import CohesionUI
import SwiftUI

/// A workspace's journal: today's entry, then the days before it that have
/// one, newest first. An entry zooms out of its row on iPad.
struct JournalListView: View {
    let workspaceID: Int

    @Environment(AppModel.self) private var model

    @State private var entries: [Document] = []
    @State private var error: (any Error)?
    /// Where an opened entry zooms out of, on iPad.
    @Namespace private var rows

    var body: some View {
        List {
            entryLink(day: nil, title: "Today", preview: today?.contents)
            ForEach(earlier) { entry in
                if let day = entry.journalDate, let date = CalendarDay.date(day) {
                    entryLink(
                        day: day,
                        title: date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()),
                        preview: entry.contents
                    )
                }
            }
        }
        .navigationTitle("Journal")
        .task { await watch() }
        .refreshable { await load(.asked) }
        .errorAlert($error)
    }

    /// Today's entry, once something is written in it.
    private var today: Document? {
        entries.first { $0.journalDate == CalendarDay.string(.now) }
    }

    /// The entries before today, newest first.
    private var earlier: [Document] {
        let today = CalendarDay.string(.now)
        return entries
            .filter { ($0.journalDate ?? today) < today }
            .sorted { ($0.journalDate ?? "") > ($1.journalDate ?? "") }
    }

    /// A row that opens the entry for `day`, today's when nil, with its
    /// first line under the title.
    private func entryLink(day: String?, title: String, preview: String?) -> some View {
        let id = day ?? "today"
        return NavigationLink {
            JournalView(workspaceID: workspaceID, entryDay: day)
                .zoomsOnIPad(from: id, in: rows)
        } label: {
            VStack(alignment: .leading) {
                Text(title)
                if let line = preview?.split(separator: "\n").first {
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .matchedTransitionSource(id: id, in: rows)
    }

    private func load(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client else { return }
        await origin.run {
            let loaded = try await client.listDocuments(.journal, in: workspaceID)
            withAnimation { entries = loaded }
        } failed: { self.error = $0 }
    }

    /// Keeps the list current while it is shown; the stream also yields
    /// once on connecting, which does the first load.
    private func watch() async {
        guard let client = model.client else { return }
        let workspaceID = workspaceID
        for await origin in client.loads(matching: { $0 == .documents(workspaceID: workspaceID) }) {
            await load(origin)
        }
    }
}
