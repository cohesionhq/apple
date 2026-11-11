import CohesionCore
import CohesionUI
import SwiftUI

/// A skill as a chip: its wand and name. Tapping it shows the skill's
/// prompt in a sheet; in the composer, its × takes the skill off the
/// message.
struct SkillChip: View {
    let name: String
    let prompt: String
    /// Takes the skill off the message being written; none in the feed.
    var dismiss: (() -> Void)?

    @State private var isShowingPrompt = false

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isShowingPrompt = true
            } label: {
                Label(name, systemImage: AgentSkill.symbol)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skill \(name)")
            .accessibilityHint("Shows its prompt")
            if let dismiss {
                Button("Remove Skill", systemImage: "xmark.circle.fill", action: dismiss)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.receivedBubble, in: .capsule)
        .overlay {
            Capsule().strokeBorder(.separator)
        }
        .sizedSheet(isPresented: $isShowingPrompt) {
            SkillPromptSheet(name: name, prompt: prompt)
        }
    }
}

/// A skill's prompt, as it stood when it was sent or as it is now in the
/// composer.
private struct SkillPromptSheet: View {
    let name: String
    let prompt: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Prompt") {
                    Text(prompt)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// The user running one of the agent's skills: the skill's chip, then the
/// photos and the note if there are any, as a forward is laid out. The
/// agent's reaction sits on the last of them.
struct SkillMessageView: View {
    let message: AgentMessage
    let name: String
    let prompt: String
    let note: String
    let reaction: String?
    let images: [PlatformImage]?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            SkillChip(name: name, prompt: prompt)
                .reactions(note.isEmpty && message.attachmentCount == 0 ? reaction : nil, on: .trailing)
                .padding(.leading, bubbleInset)
            if message.attachmentCount > 0 {
                AttachedImages(images: images, count: message.attachmentCount, reaction: note.isEmpty ? reaction : nil)
            }
            if !note.isEmpty {
                UserBubble(text: note, reaction: reaction)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// The skills a `/` opening the composer offers, over it: each one's name
/// and what it's for, the closest match first. Picking one makes it the
/// message's chip.
struct SkillPicker: View {
    /// The agent's skills matching what follows the `/`.
    let offered: [AgentSkill]
    /// Whether the agent has any skills at all, which says why none are offered.
    let hasSkills: Bool
    let pick: (AgentSkill) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if offered.isEmpty {
                    Text(hasSkills ? "No skills match." : "No skills yet.")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                ForEach(offered) { skill in
                    Button {
                        pick(skill)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(skill.name)
                                .fontWeight(.medium)
                            if !skill.description.isEmpty {
                                Text(skill.description)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: 240)
        .fixedSize(horizontal: false, vertical: true)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Skills")
    }
}
