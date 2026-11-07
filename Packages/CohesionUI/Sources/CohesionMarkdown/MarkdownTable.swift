import SwiftUI

/// A Markdown table: a semibold header over rows set apart by hairlines,
/// each column as wide as its widest cell. Cells don't wrap, so a table
/// wider than the screen scrolls sideways, as a code block does. Its text
/// isn't selectable, even in selectable Markdown: each selectable `Text`
/// is updated on every frame of a scroll, and a table is dozens of them.
public struct MarkdownTable: View {
    public init(table: Markdown.Table, styling: @escaping (AttributedString) -> AttributedString = { $0 }) {
        self.table = table
        self.styling = styling
    }

    public let table: Markdown.Table
    /// Restyles a cell's text, as `MarkdownText` shades its code spans.
    public var styling: (AttributedString) -> AttributedString = { $0 }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(table.header.indices, id: \.self) { column in
                        cell(table.header[column], column: column)
                            .fontWeight(.semibold)
                            .gridColumnAlignment(alignment(of: column))
                    }
                }
                ForEach(table.rows.indices, id: \.self) { row in
                    Divider()
                        .gridCellUnsizedAxes(.horizontal)
                    GridRow {
                        ForEach(table.rows[row].indices, id: \.self) { column in
                            cell(table.rows[row][column], column: column)
                        }
                    }
                }
            }
            .textSelection(.disabled)
        }
    }

    private func cell(_ text: AttributedString, column: Int) -> some View {
        Text(styling(text))
            .multilineTextAlignment(textAlignment(of: column))
            .fixedSize(horizontal: true, vertical: false)
            .padding(.vertical, MarkdownMetrics.tableCellPadding.height)
            // The outer columns line up with the text around the table.
            .padding(.leading, column == 0 ? 0 : MarkdownMetrics.tableCellPadding.width)
            .padding(.trailing, column == table.header.count - 1 ? 0 : MarkdownMetrics.tableCellPadding.width)
    }

    private func alignment(of column: Int) -> HorizontalAlignment {
        switch table.alignments[column] {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    private func textAlignment(of column: Int) -> TextAlignment {
        switch table.alignments[column] {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}
