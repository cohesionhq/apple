import CohesionCore
import CohesionUI
import SwiftUI

extension EnvironmentValues {
    /// The user's profile, which draws them where a task is assigned to
    /// them; `nil` until it loads, or from a daemon from before profiles.
    @Entry var profile: Profile?
}

/// Who a task is assigned to, as the app shows them: the user by their
/// profile, an agent, or a contact.
enum ShownAssignee: Identifiable {
    case user(Profile?)
    case agent(Agent)
    case contact(Contact)

    /// Who `assignee` is; `nil` when no one is, or when the agent or contact
    /// is no longer in `agents` or `contacts`, as the web shows a deleted
    /// one's tasks until the daemon's unassigning reaches the list.
    init?(_ assignee: TaskAssignee?, agents: [Agent], contacts: [Contact], profile: Profile?) {
        switch assignee {
        case nil: return nil
        case .user: self = .user(profile)
        case .agent(let id):
            guard let agent = agents.first(where: { $0.id == id }) else { return nil }
            self = .agent(agent)
        case .contact(let id):
            guard let contact = contacts.first(where: { $0.id == id }) else { return nil }
            self = .contact(contact)
        }
    }

    /// Who a task can be assigned to: the user, then each agent, then each
    /// contact of the task's workspace, as the web lists them.
    static func choices(agents: [Agent], contacts: [Contact], profile: Profile?) -> [ShownAssignee] {
        [.user(profile)] + agents.map(Self.agent) + contacts.map(Self.contact)
    }

    var assignee: TaskAssignee {
        switch self {
        case .user: .user
        case .agent(let agent): .agent(agent.id)
        case .contact(let contact): .contact(contact.id)
        }
    }

    var id: TaskAssignee { assignee }

    /// "You" for the user, as the web calls them.
    var label: String {
        switch self {
        case .user: "You"
        case .agent(let agent): agent.name
        case .contact(let contact): contact.fullName
        }
    }

    /// The avatar: the agent's, or a person's photo or initials.
    @ViewBuilder
    func avatar(diameter: CGFloat, fit: AgentAvatar.Fit = .standard) -> some View {
        switch self {
        case .user(let profile):
            ContactPhotoView(photo: profile?.photo ?? .none, name: profile?.name, diameter: diameter)
        case .agent(let agent):
            AgentAvatar(name: agent.name, emoji: agent.emoji, color: agent.color, diameter: diameter, fit: fit)
        case .contact(let contact):
            ContactPhotoView(photo: contact.photo, name: contact.fullName, diameter: diameter)
        }
    }

    /// The avatar as an image for a menu item, which shows only images: a
    /// 24pt disc, as an agent's in a menu.
    func menuImage(scale: CGFloat) -> Image {
        if case .agent(let agent) = self { return AgentAvatar.menuImage(of: agent, scale: scale) }
        return AgentAvatar.menuImage(of: avatar(diameter: 24), scale: scale)
    }
}

/// A picker of who to assign a task to, each by their avatar and name,
/// then None; for a menu or a form's row.
struct AssigneePicker: View {
    @Binding var selection: TaskAssignee?
    /// The task's workspace's contacts.
    let contacts: [Contact]

    @Environment(\.agents) private var agents
    @Environment(\.profile) private var profile
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Picker("Assignee", selection: $selection) {
            ForEach(ShownAssignee.choices(agents: agents, contacts: contacts, profile: profile)) { choice in
                Label { Text(choice.label) } icon: { choice.menuImage(scale: displayScale) }
                    .tag(Optional(choice.assignee))
            }
            Text("None").tag(TaskAssignee?.none)
        }
    }
}
