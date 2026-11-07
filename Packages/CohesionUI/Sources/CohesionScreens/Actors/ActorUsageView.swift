import CohesionCore
import CohesionUI
import SwiftUI

/// What one row of the actors' usage shows: an account several actors
/// share, or an actor whose limits are its own, with its plan's limits.
struct ActorUsageGroup: Identifiable {
    /// The pool's id for an account, the actor's for its own limits.
    let id: String
    /// The account, or where the actor works.
    let name: String
    /// Whether `name` is a directory, set in a monospaced font.
    let isScope: Bool
    /// Where the account's actors work, or the actor and its device.
    let detail: String
    let plan: [PlanUsage]
}

extension [ActorUsage] {
    /// The rows of usage to show, as the web's Actors page lists them: one
    /// for each pool reporting a plan with an actor still offered, in
    /// cohesiond's order.
    func groups(of actors: [Actor]) -> [ActorUsageGroup] {
        compactMap { usage in
            let members = actors.filter { usage.actorIDs.contains($0.id) }
            guard let first = members.first, !usage.plan.isEmpty else { return nil }
            if let pool = usage.pool {
                return ActorUsageGroup(
                    id: "pool:\(pool.id)",
                    name: pool.name,
                    isScope: false,
                    detail: members.map(\.scopeName).joined(separator: ", "),
                    plan: usage.plan
                )
            }
            return ActorUsageGroup(
                id: "actor:\(first.id)",
                name: first.scopeName,
                isScope: true,
                detail: first.title,
                plan: usage.plan
            )
        }
    }
}

/// How much of their plans' limits the actors have used, as the web's
/// Actors page shows under Usage, opened from the overflow menu: a
/// section for each account the actors share, with where they work under
/// it, and one for each actor whose limits are its own, named by its
/// directory with its device under it, with a bar for each limit. Usage is only shown;
/// nothing stops an actor at a limit.
struct ActorUsageView: View {
    let actors: [Actor]
    let usage: [ActorUsage]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let groups = usage.groups(of: actors)
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(Array(group.plan.enumerated()), id: \.offset) { _, limit in
                        UsageLimitRow(limit, label: shortLabel(limit.label))
                            .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text(group.name)
                        .font(group.isScope ? .headline.monospaced() : .headline)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                } footer: {
                    Text(group.detail)
                }
            }
        }
        .overlay {
            if groups.isEmpty {
                ContentUnavailableView(
                    "No Usage",
                    systemImage: "gauge.with.dots.needle.33percent",
                    description: Text("No connected actor is reporting its plan's limits.")
                )
            }
        }
        .navigationTitle("Actor Usage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", systemImage: "checkmark", role: .confirm) { dismiss() }
            }
        }
    }

    /// A limit's label without the word "limit", which a list of limits
    /// implies, as the web's list shortens it: "Weekly limit" is "Weekly".
    private func shortLabel(_ label: String) -> String {
        let short = label
            .replacing(/(?i)\blimits?\b/, with: "")
            .replacing(/\s+/, with: " ")
            .trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: ",.:;·–—-")))
        return short.isEmpty ? label : short
    }
}

/// The navigation bar's overflow menu where the agents and actors are
/// listed, holding Actor Usage; only while some actor reports its plan,
/// as the web shows Usage only then.
public struct ActorUsageMenu: ToolbarContent {
    let actors: [Actor]
    let usage: [ActorUsage]
    let show: () -> Void

    public init(actors: [Actor], usage: [ActorUsage], show: @escaping () -> Void) {
        self.actors = actors
        self.usage = usage
        self.show = show
    }

    public var body: some ToolbarContent {
        if !usage.groups(of: actors).isEmpty {
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis") {
                    Button("Actor Usage", systemImage: "gauge.with.dots.needle.33percent", action: show)
                }
            }
        }
    }
}
