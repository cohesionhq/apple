import CohesionCore
import CohesionUI
import SwiftUI

/// An agent's agenda, beside its chat on iPad and the Mac and in a sheet on
/// iPhone: the steps it means to take, in order, the one it's on marked and
/// finished ones struck through, as the web's column beside the
/// conversation has them. The agent keeps it with its agenda tools; the
/// user only reads it.
struct AgentAgendaView: View {
    /// In order, finished items included.
    let items: [AgentAgendaItem]

    var body: some View {
        let current = AgentAgendaItem.current(in: items)?.id
        let finished = items.count(where: \.isFinished)
        List {
            Section {
                ForEach(items) { item in
                    row(item, isCurrent: item.id == current)
                }
            } header: {
                // A heading of its own: beside the chat there's no bar to title it.
                HStack(alignment: .firstTextBaseline) {
                    Text("Agenda")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("\(finished) of \(items.count) done")
                        .monospacedDigit()
                }
                .textCase(nil)
            }
        }
        .animation(.default, value: items)
    }

    private func row(_ item: AgentAgendaItem, isCurrent: Bool) -> some View {
        Label {
            Text(item.text)
                .strikethrough(item.isFinished)
                .foregroundStyle(item.isFinished ? .secondary : isCurrent ? .primary : .secondary)
        } icon: {
            Group {
                if item.isFinished {
                    Image(systemName: AgentAgendaItem.finishedSymbol)
                        .foregroundStyle(AgentAgendaItem.finishedTint)
                } else if isCurrent {
                    Image(systemName: AgentAgendaItem.currentSymbol)
                        .foregroundStyle(.tint)
                } else {
                    Image(systemName: AgentAgendaItem.openSymbol)
                        .foregroundStyle(.secondary)
                }
            }
            .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(item.isFinished ? "Done" : isCurrent ? "Next" : "To do")
    }
}
