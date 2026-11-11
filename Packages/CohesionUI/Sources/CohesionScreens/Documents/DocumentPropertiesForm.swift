import CohesionCore
import CohesionUI
import SwiftUI

/// A table row's values, each editable as its property's type allows: the
/// document's inspector, beside it on iPad and a sheet on iPhone. A
/// formula's value is shown, not edited.
struct DocumentPropertiesForm: View {
    let document: Document
    let properties: [DocumentFolderProperty]
    @Binding var row: DocumentTableRow?

    @Environment(AppModel.self) private var model
    @State private var error: (any Error)?

    var body: some View {
        Form {
            Section("Properties") {
                ForEach(properties) { property in
                    PropertyEditor(property: property, value: row?.values[property.id]) {
                        set($0, for: property)
                    }
                }
            }
        }
        .errorAlert($error)
    }

    /// Shows the value at once and sends it; cohesiond's row replaces it,
    /// or the one before comes back if it refused.
    private func set(_ value: PropertyValue?, for property: DocumentFolderProperty) {
        guard let client = model.client, let previous = row else { return }
        row?.values[property.id] = value
        Task {
            do {
                row = try await client.setValue(value, of: property, for: document)
            } catch {
                row = previous
                self.error = error
            }
        }
    }
}

/// One property's editor, by its type: a field for text and numbers, a
/// switch for a checkbox, a date picker, a menu of a choice's options.
private struct PropertyEditor: View {
    let property: DocumentFolderProperty
    let value: PropertyValue?
    let set: (PropertyValue?) -> Void

    var body: some View {
        if property.isFormula {
            LabeledContent(property.name) {
                PropertyValueView(property: property, value: value)
            }
        } else {
            switch property.type {
            case .text:
                ValueField(name: property.name, text: text) { update($0.isEmpty ? nil : .text($0)) }
            case .integer:
                ValueField(name: property.name, text: text, isNumeric: true) { typed in
                    guard !typed.isEmpty else { return update(nil) }
                    guard let number = try? Int(typed, format: .number) else { return false }
                    return update(.integer(number))
                }
            case .decimal:
                ValueField(name: property.name, text: text, isNumeric: true) { typed in
                    guard !typed.isEmpty else { return update(nil) }
                    guard let number = try? Double(typed, format: .number) else { return false }
                    return update(.decimal(number))
                }
            case .currency:
                ValueField(name: property.name, text: text, isNumeric: true) { typed in
                    guard !typed.isEmpty else { return update(nil) }
                    guard let amount = try? Double(typed, format: .number) else { return false }
                    return update(.currency(amount))
                }
            case .checkbox:
                Toggle(property.name, isOn: Binding {
                    value == .checkbox(true)
                } set: {
                    update(.checkbox($0))
                })
            case .date:
                dateEditor
            case .choice(let options):
                Picker(property.name, selection: Binding {
                    if case .choice(let id) = value { id } else { nil }
                } set: { (id: Int?) in
                    update(id.map { .choice($0) })
                }) {
                    Text("None").tag(Int?.none)
                    ForEach(options) { option in
                        Text(option.name).tag(Optional(option.id))
                    }
                }
            case .other:
                LabeledContent(property.name) {
                    PropertyValueView(property: property, value: value)
                }
            }
        }
    }

    /// Sends a value unless it's the one held already, as a field's text
    /// read again once it shows formatted is; always reads as taken.
    @discardableResult
    private func update(_ new: PropertyValue?) -> Bool {
        if new != value { set(new) }
        return true
    }

    /// The value as its field starts out: numbers in the reader's locale,
    /// an amount to two places.
    private var text: String {
        switch value {
        case .text(let text): text
        case .integer(let number): number.formatted(.number)
        case .decimal(let number): number.formatted(.number)
        case .currency(let amount): amount.formatted(.number.precision(.fractionLength(2)))
        default: ""
        }
    }

    /// A picker once the day is set, cleared from its menu; a button to set
    /// it to today before.
    @ViewBuilder
    private var dateEditor: some View {
        if case .date(let day) = value, let date = CalendarDay.date(day) {
            DatePicker(property.name, selection: Binding {
                date
            } set: {
                update(.date(CalendarDay.string($0)))
            }, displayedComponents: .date)
            .contextMenu {
                Button("Clear", systemImage: "xmark.circle", role: .destructive) { set(nil) }
            }
            .swipeActions {
                Button("Clear", systemImage: "xmark.circle", role: .destructive) { set(nil) }
            }
        } else {
            LabeledContent(property.name) {
                Button("Add Date") { set(.date(CalendarDay.string(.now))) }
            }
        }
    }
}

/// A value typed in a field, sent when Return is pressed or the field loses
/// focus; text that doesn't read as the type goes back to the value.
private struct ValueField: View {
    let name: String
    let text: String
    var isNumeric = false
    /// Takes the typed text, saying whether it read as a value.
    let commit: (String) -> Bool

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        LabeledContent {
            TextField(name, text: $draft)
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                #if os(iOS)
                .keyboardType(isNumeric ? .numbersAndPunctuation : .default)
                #endif
                .onSubmit(send)
        } label: {
            Text(name)
        }
        .onAppear { draft = text }
        .onChange(of: text) { if !isFocused { draft = text } }
        .onChange(of: isFocused) {
            guard !isFocused else { return }
            send()
            // As the value reads, formatted, once editing ends.
            draft = text
        }
    }

    private func send() {
        let typed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard typed != text else { return }
        if !commit(typed) { draft = text }
    }
}
