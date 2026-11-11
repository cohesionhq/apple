import CohesionCore
import CohesionUI
import SwiftUI

/// A document folder that is a table, each of its documents a row: on iPad
/// a column for the title and one per property, in their order; on iPhone
/// a list of the titles alone. A row opens its document. Pushed from the
/// documents' list.
struct DocumentTableView: View {
    let folder: DocumentFolder

    @Environment(AppModel.self) private var model
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    @State private var properties: [DocumentFolderProperty] = []
    @State private var rows: [DocumentTableRow] = []
    @State private var isLoaded = false
    @State private var selection: DocumentTableRow.ID?
    /// The row whose document is open, from the table.
    @State private var opened: Int?
    @State private var error: (any Error)?

    var body: some View {
        Group {
            if isWide { table } else { list }
        }
        .overlay {
            if !isLoaded {
                ProgressView()
            } else if rows.isEmpty {
                ContentUnavailableView("No Documents", systemImage: DocumentFolder.tableSymbol)
            }
        }
        .navigationTitle(folder.title)
        .navigationDestination(item: $opened) { id in
            DocumentView(workspaceID: folder.workspaceID, documentID: id)
        }
        .task { await watch() }
        .refreshable { await load(.asked) }
        .errorAlert($error)
    }

    /// Whether there's the room for a column per property, as an iPad's
    /// regular width has.
    private var isWide: Bool {
        #if os(iOS)
        sizeClass == .regular
        #else
        true
        #endif
    }

    private var table: some View {
        Table(rows, selection: $selection) {
            TableColumn("Title") { row in
                Text(row.title)
            }
            TableColumnForEach(properties) { property in
                TableColumn(property.name) { row in
                    PropertyValueView(property: property, value: row.values[property.id])
                }
                .alignment(property.isNumeric ? .numeric : .leading)
            }
        }
        .contextMenu(forSelectionType: DocumentTableRow.ID.self) { _ in
        } primaryAction: { ids in
            opened = ids.first
        }
    }

    private var list: some View {
        List(rows) { row in
            NavigationLink {
                DocumentView(workspaceID: folder.workspaceID, documentID: row.id)
            } label: {
                Text(row.title)
            }
        }
    }

    private func load(_ origin: LoadOrigin = .automatic) async {
        guard let client = model.client else { return }
        await origin.run {
            async let loadedProperties = client.listProperties(ofFolder: folder.id, in: folder.workspaceID)
            async let loadedRows = client.listRows(ofFolder: folder.id, in: folder.workspaceID)
            let (properties, rows) = try await (loadedProperties, loadedRows)
            withAnimation {
                self.properties = properties
                self.rows = rows
                isLoaded = true
            }
        } failed: { self.error = $0 }
    }

    /// Keeps the table current while it is shown; the stream also yields
    /// once on connecting, which does the first load.
    private func watch() async {
        guard let client = model.client else { return }
        let folderID = folder.id
        for await origin in client.loads(matching: { $0 == .documentTable(folderID: folderID) }) {
            await load(origin)
        }
    }
}

/// A row's value for a property as a table's cell shows it: text and numbers in the
/// reader's locale, an amount to two places with no currency sign (a table
/// names none), a day as "Nov 3" (with its year outside this one), a box for
/// a checkbox and a pill for a choice, as the web's table draws them.
struct PropertyValueView: View {
    let property: DocumentFolderProperty
    let value: PropertyValue?

    var body: some View {
        switch value {
        case .text(let text):
            Text(text)
        case .integer(let number):
            Text(number, format: .number)
        case .decimal(let number):
            Text(number, format: .number)
        case .currency(let amount):
            Text(amount, format: .number.precision(.fractionLength(2)))
        case .date(let day):
            Text(Self.words(day: day))
        case .checkbox(let checked):
            checkbox(checked)
        case .choice(let id):
            if case .choice(let options) = property.type, let option = options.first(where: { $0.id == id }) {
                ChoicePill(option: option)
            }
        case .other:
            EmptyView()
        case nil:
            // An empty checkbox is a box all the same.
            if property.type == .checkbox { checkbox(false) }
        }
    }

    private func checkbox(_ checked: Bool) -> some View {
        Image(systemName: PropertyValue.checkboxSymbol(checked: checked))
            .foregroundStyle(checked ? Color.accentColor : .secondary)
            .accessibilityLabel(checked ? "Checked" : "Not checked")
    }

    /// A `"YYYY-MM-DD"` day as "Nov 3", or "Nov 3, 2025" outside this year;
    /// as it came if it isn't one.
    private static func words(day: String) -> String {
        guard let date = CalendarDay.date(day) else { return day }
        let calendar = Calendar.current
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: .now)
        return sameYear
            ? date.formatted(.dateTime.month(.abbreviated).day())
            : date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}

/// A choice's option as a pill: in its color, or quiet as a tag's when it
/// has none.
private struct ChoicePill: View {
    let option: PropertyOption

    var body: some View {
        Text(option.name)
            .font(.caption.weight(.medium))
            .foregroundStyle(option.tint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.primary))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(option.tint.map { AnyShapeStyle($0.opacity(0.15)) } ?? AnyShapeStyle(.fill.tertiary), in: .capsule)
    }
}
