import CohesionCore
import CohesionMarkdown
import CohesionUI
import SwiftUI

/// Says a response to a request, `true` once cohesiond took it; the
/// transcript shows why it didn't.
typealias ActorResponder = (ActorUserContent) async -> Bool

/// An actor's questions: each with its options to pick (one, or several
/// where it allows) and, where it allows, an answer in the user's own
/// words. Sending answers every question at once; once settled, the card
/// is read-only, the options answered tinted and checked, the rest faded,
/// and an answer in words shown as one more picked row.
struct ActorQuestionCard: View {
    let requestID: Int
    let questions: [ActorQuestion]
    /// What the user answered, one per question; `nil` until they do.
    let answers: [ActorAnswer]?
    /// Whether it no longer takes a response.
    let isSettled: Bool
    let respond: ActorResponder

    @State private var picked: [[String]]
    @State private var other: [String]
    @State private var isSending = false

    init(
        requestID: Int,
        questions: [ActorQuestion],
        answers: [ActorAnswer]?,
        isSettled: Bool,
        respond: @escaping ActorResponder
    ) {
        self.requestID = requestID
        self.questions = questions
        self.answers = answers
        self.isSettled = isSettled
        self.respond = respond
        _picked = State(initialValue: questions.indices.map { answers?[safe: $0]?.selected ?? [] })
        _other = State(initialValue: questions.indices.map { _ in "" })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                VStack(alignment: .leading, spacing: 6) {
                    if let header = question.header {
                        Text(header)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    Text(question.question)
                        .fontWeight(.medium)
                    ForEach(question.options, id: \.label) { option in
                        let isPicked = picked[index].contains(option.label)
                        OptionButton(
                            option: option,
                            isPicked: isPicked,
                            isMultiple: question.multiSelect
                        ) {
                            toggle(option.label, in: index)
                        }
                        .disabled(isSettled)
                        .opacity(isSettled && !isPicked ? 0.5 : 1)
                    }
                    if isSettled, let words = answers?[safe: index]?.other {
                        OptionButton(
                            option: ActorQuestion.Option(label: words, description: nil),
                            isPicked: true,
                            isMultiple: question.multiSelect
                        ) {}
                        .disabled(true)
                    }
                    if question.takesWords && !isSettled {
                        TextField(
                            question.options.isEmpty ? "Your answer…" : "Something else…",
                            text: $other[index],
                            axis: .vertical
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.fill.tertiary, in: .rect(cornerRadius: 8))
                        .accessibilityLabel("Answer in your own words")
                    }
                }
            }
            if !isSettled {
                Button(isSending ? "Sending…" : "Send answers", action: send)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!isComplete || isSending)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .actorCard()
    }

    private var isComplete: Bool {
        questions.indices.allSatisfy { index in
            !picked[index].isEmpty || !other[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func toggle(_ label: String, in index: Int) {
        if picked[index].contains(label) {
            picked[index].removeAll { $0 == label }
        } else if questions[index].multiSelect {
            picked[index].append(label)
        } else {
            picked[index] = [label]
        }
    }

    private func send() {
        let answers = questions.indices.map { index in
            let words = other[index].trimmingCharacters(in: .whitespacesAndNewlines)
            return ActorAnswer(selected: picked[index], other: words.isEmpty ? nil : words)
        }
        isSending = true
        Task {
            _ = await respond(.answers(requestID: requestID, answers))
            isSending = false
        }
    }
}

/// One of a question's options: a round mark, or a square one where several
/// may be picked, beside its label and what it means.
private struct OptionButton: View {
    let option: ActorQuestion.Option
    let isPicked: Bool
    let isMultiple: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: mark)
                    .foregroundStyle(isPicked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                    if let description = option.description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.fill.tertiary, in: .rect(cornerRadius: 8))
            .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    private var mark: String {
        switch (isMultiple, isPicked) {
        case (true, true): "checkmark.square.fill"
        case (true, false): "square"
        case (false, true): "largecircle.fill.circle"
        case (false, false): "circle"
        }
    }
}

/// Something an actor asks leave to do: the command and where it runs, the
/// files and how each changes, or the tool and its input; why, in its
/// words; and a button per decision it takes, with a note to send along.
/// Once decided, the card is read-only and the decision follows it.
struct ActorPermissionCard: View {
    let requestID: Int
    let request: ActorPermissionRequest
    let isSettled: Bool
    let respond: ActorResponder

    @State private var note = ""
    @State private var isSending = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Amber while it waits on the user, as the session's status is.
            Label {
                Text(title)
                    .fontWeight(.semibold)
            } icon: {
                if !isSettled {
                    Image(systemName: ActorSessionStatus.needsAttention.symbol)
                        .foregroundStyle(.orange)
                }
            }
            switch request.subject {
            case .command(let command, let cwd):
                CodeBlock(text: command)
                if let cwd {
                    Text("in \(cwd)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            case .fileChange(let changes):
                ForEach(Array(changes.enumerated()), id: \.offset) { _, change in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(label(of: change.change))
                                .foregroundStyle(.secondary)
                            Text(change.path)
                                .monospaced()
                        }
                        .font(.caption)
                        if let diff = change.diff { CodeBlock(text: diff) }
                    }
                }
            case .tool(_, let input):
                CodeBlock(text: Self.prettyJSON(input))
            case .unknown:
                EmptyView()
            }
            if let reason = request.reason {
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !isSettled {
                TextField("Add a note (optional)", text: $note, axis: .vertical)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 8))
                // One clear first choice, Allow, beside a quiet Deny; the
                // rest, for this session or stopping it, in a menu after them.
                HStack(spacing: 8) {
                    decisionButtons
                }
            }
        }
        .actorCard()
    }

    @ViewBuilder
    private var decisionButtons: some View {
        let decisions = request.decisions
        let more = decisions.filter { $0 != .allow && $0 != .deny }
        Group {
            if decisions.contains(.allow) {
                Button { decide(.allow) } label: { decisionLabel(.allow) }
                    .buttonStyle(.borderedProminent)
            }
            if decisions.contains(.deny) {
                Button { decide(.deny) } label: { decisionLabel(.deny) }
                    .buttonStyle(.bordered)
                    // Neutral: the accent is for the action that settles it.
                    .tint(.primary)
            }
            if !more.isEmpty {
                Menu {
                    ForEach(more, id: \.self) { decision in
                        Button(label(of: decision), role: decision == .abort ? .destructive : nil) { decide(decision) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(minHeight: 20)
                }
                .menuStyle(.button)
                .buttonStyle(.bordered)
                .tint(.primary)
                .accessibilityLabel("More Decisions")
            }
        }
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .disabled(isSending)
    }

    /// A decision's words, filling what its row leaves it.
    private func decisionLabel(_ decision: ActorPermissionDecision) -> some View {
        Text(label(of: decision))
            .font(.subheadline.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
    }

    private var title: String {
        switch request.subject {
        case .command: "Run a command?"
        case .fileChange(let changes): changes.count == 1 ? "Change a file?" : "Change \(changes.count) files?"
        case .tool(let name, _): "Use \(name)?"
        case .unknown: "Allow this?"
        }
    }

    private func label(of decision: ActorPermissionDecision) -> String {
        switch decision {
        case .allow: "Allow"
        case .allowForSession: "Allow for this session"
        case .deny: "Deny"
        case .abort: "Deny and stop"
        }
    }

    private func label(of change: ActorFileChange.Kind) -> String {
        switch change {
        case .add: "Add"
        case .update: "Edit"
        case .delete: "Delete"
        }
    }

    private func decide(_ decision: ActorPermissionDecision) {
        let words = note.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        Task {
            _ = await respond(.permission(requestID: requestID, decision, message: words.isEmpty ? nil : words))
            isSending = false
        }
    }

    private static func prettyJSON(_ value: JSONValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(value)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }
}

/// A plan an actor asks the user to approve before it starts, then
/// approving it or asking for changes, with what to change. Once decided,
/// the card is read-only and the decision follows it.
struct ActorPlanCard: View {
    let requestID: Int
    let plan: String
    let isSettled: Bool
    let respond: ActorResponder

    @State private var feedback = ""
    @State private var isSending = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarkdownText(markdown: plan)
            if !isSettled {
                TextField("What to change (optional)", text: $feedback, axis: .vertical)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 8))
                HStack {
                    Button("Ask for changes") { decide(approved: false) }
                        .buttonStyle(.bordered)
                    Button("Approve plan") { decide(approved: true) }
                        .buttonStyle(.borderedProminent)
                }
                .controlSize(.small)
                .disabled(isSending)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .actorCard()
    }

    private func decide(approved: Bool) {
        let words = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        Task {
            _ = await respond(.plan(requestID: requestID, approved: approved, feedback: words.isEmpty ? nil : words))
            isSending = false
        }
    }
}

/// Text taken literally, such as a command or a diff, in a box that
/// scrolls once it's taller than a long command.
private struct CodeBlock: View {
    let text: String

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
        .frame(maxHeight: 320)
        .background(.fill.tertiary, in: .rect(cornerRadius: 8))
    }

    private var content: some View {
        Text(text)
            .font(.caption.monospaced())
            .textSelection(.enabled)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// A request's card, on an agent's cards' grey, so a question reads the
    /// same in a chat and a transcript.
    fileprivate func actorCard() -> some View {
        padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.receivedBubble, in: .rect(cornerRadius: bubbleCornerRadius))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
