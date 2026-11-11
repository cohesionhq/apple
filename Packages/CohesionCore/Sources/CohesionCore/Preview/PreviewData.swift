#if DEBUG
import CoreGraphics
import Foundation
import ImageIO

/// What a `#Preview`'s client answers with in place of cohesiond: one
/// believable person's Cohesion, its two workspaces, agents, actors, tasks,
/// documents, feeds, connectors, extensions and models, with every date
/// relative to when it's asked, so "5m ago" and "Today" read as they would.
///
/// The ids stay the same from one preview to the next: workspace 1 "Studio"
/// and 2 "Home"; agents 1 Atlas (pinned, the rich chat), 2 Scout (pinned,
/// working), 3 Quill (unread), 4 Ledger (a proposal waiting), 5 Relay (a
/// failed job), 6 Juniper; teams 1 Research and 2 Ops; actor sessions 1 (needs
/// you, the rich transcript), 2 (working), 3 (done, unread), 4 (failed) and
/// 5 (done, read); tasks 1–13 in Studio and 14–16 in Home; documents 1–6 in
/// Studio; contacts 1–8 in Studio; feeds 1–4 and articles 1–9.
nonisolated public enum PreviewData {
    /// The JSON of `type`'s reply data, or nil for a command previews don't answer.
    public static func reply(_ type: String, _ args: [String: Any]) -> String? {
        let fixtures = Fixtures(now: .now)
        guard let value = fixtures.reply(type, args) else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])
        else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// The vocabulary cohesiond's hello sends, every list worded and ordered
    /// as its `Vocabulary::new` does.
    @MainActor public static let vocabulary: Vocabulary = {
        let data = try! JSONSerialization.data(withJSONObject: VocabularyWords.json)
        return try! JSONDecoder().decode(Vocabulary.self, from: data)
    }()

    /// A mock-up of a pricing page as a PNG, base64-encoded: the image the
    /// user attached in Atlas's chat and actor session 2.
    static let screenshotPNG: String = {
        let width = 720
        let height = 480
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return "" }
        let colors = [
            CGColor(srgbRed: 0.33, green: 0.40, blue: 0.96, alpha: 1),
            CGColor(srgbRed: 0.66, green: 0.35, blue: 0.92, alpha: 1),
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
            context.drawLinearGradient(
                gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
        }
        // Three pricing cards, the middle one raised.
        for index in 0..<3 {
            let raised = index == 1
            let card = CGRect(
                x: 48 + CGFloat(index) * 216, y: raised ? 48 : 72, width: 192, height: raised ? 384 : 336)
            context.setFillColor(CGColor(gray: 1, alpha: raised ? 1 : 0.9))
            context.addPath(CGPath(roundedRect: card, cornerWidth: 18, cornerHeight: 18, transform: nil))
            context.fillPath()
            // The price, the plan's name and its features, as bars.
            context.setFillColor(CGColor(srgbRed: 0.2, green: 0.22, blue: 0.3, alpha: 1))
            context.fill(CGRect(x: card.minX + 24, y: card.maxY - 64, width: 96, height: 26))
            context.setFillColor(CGColor(gray: 0.55, alpha: 1))
            context.fill(CGRect(x: card.minX + 24, y: card.maxY - 92, width: 64, height: 12))
            context.setFillColor(CGColor(gray: 0.82, alpha: 1))
            for line in 0..<5 {
                context.fill(CGRect(
                    x: card.minX + 24, y: card.maxY - 132 - CGFloat(line) * 26,
                    width: CGFloat(130 - (line % 3) * 22), height: 10))
            }
            // The button.
            context.setFillColor(raised
                ? CGColor(srgbRed: 0.33, green: 0.40, blue: 0.96, alpha: 1)
                : CGColor(gray: 0.9, alpha: 1))
            context.addPath(CGPath(
                roundedRect: CGRect(x: card.minX + 24, y: card.minY + 24, width: card.width - 48, height: 40),
                cornerWidth: 10, cornerHeight: 10, transform: nil))
            context.fillPath()
        }
        guard let image = context.makeImage() else { return "" }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)
        else { return "" }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return "" }
        return (data as Data).base64EncodedString()
    }()

    /// A service's icon: its initial on a rounded square of `color`, as a
    /// `data:` URL of an SVG.
    static func icon(_ initial: String, _ color: String) -> String {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">\
        <rect width="64" height="64" rx="14" fill="\(color)"/>\
        <text x="32" y="43" font-family="-apple-system, Helvetica, sans-serif" font-size="30" \
        font-weight="600" fill="#fff" text-anchor="middle">\(initial)</text></svg>
        """
        return "data:image/svg+xml;base64," + Data(svg.utf8).base64EncodedString()
    }
}

// MARK: - Fixtures

/// Every fixture, its dates counted back from `now`.
nonisolated private struct Fixtures {
    let now: Date

    // MARK: Dates

    var nowSeconds: Int { Int(now.timeIntervalSince1970) }

    func secondsAgo(_ seconds: Double) -> Int { Int(now.timeIntervalSince1970 - seconds) }
    func minutesAgo(_ minutes: Double) -> Int { secondsAgo(minutes * 60) }
    func hoursAgo(_ hours: Double) -> Int { secondsAgo(hours * 3600) }
    func daysAgo(_ days: Double) -> Int { secondsAgo(days * 86400) }
    func fromNow(minutes: Double = 0, hours: Double = 0, days: Double = 0) -> Int {
        secondsAgo(-(minutes * 60 + hours * 3600 + days * 86400))
    }

    /// `offset` days from today at `hour`:`minute`, never later than a
    /// minute ago for today or earlier.
    func on(_ offset: Int, at hour: Int, _ minute: Int = 0) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
        let time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        let seconds = Int(time.timeIntervalSince1970)
        return offset <= 0 ? min(seconds, nowSeconds - 60) : seconds
    }

    /// `offset` days from today as `"YYYY-MM-DD"`.
    func day(_ offset: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: offset, to: now) ?? now
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // MARK: Answering

    func reply(_ type: String, _ args: [String: Any]) -> Any? {
        let workspace = args["workspace_id"] as? Int
        switch type {
        // Server
        case "about":
            return ["version": "0.42.0"]
        case "renderMermaid":
            return ["kind": "refused", "reason": "unsupported"]

        // Workspaces
        case "listWorkspaces":
            return workspaces

        // Tasks
        case "listTasks":
            return taskPage(args)
        case "listTaskFolders":
            return folders.filter { $0.workspace == workspace }.map { ["id": $0.id, "title": $0.title] }
        case "listTags":
            return tags.filter { $0.workspace == workspace }
                .sorted { $0.name < $1.name }
                .map { ["id": $0.id, "workspace_id": $0.workspace, "name": $0.name] }
        case "listSavedTaskViews":
            return savedViews.filter { ($0["workspace_id"] as? Int) == workspace }

        // Contacts and the profile
        case "listContacts":
            return contacts.filter { ($0["workspace_id"] as? Int) == workspace }
        case "getProfile":
            return ["name": "Jackson", "photo": ["kind": "none"]]

        // Feeds and articles
        case "listFeeds":
            return feeds
        case "listArticles":
            return articlePage(args)
        case "getArticle":
            return (args["article_id"] as? Int).flatMap(article)
        case "setArticleRead":
            guard let id = args["article_id"] as? Int, var article = article(id) else { return nil }
            article["read"] = args["read"] as? Bool ?? true
            return article

        // Journal and documents
        case "getJournal":
            guard let date = args["date"] as? String else { return nil }
            guard let entry = journal.first(where: { $0.workspace == workspace && day($0.offset) == date })
            else { return NSNull() }
            return ["id": entry.id, "contents": entry.contents]
        case "listDocuments":
            let type = args["document_type"] as? String ?? "normal"
            return allDocuments
                .filter { ($0["workspace_id"] as? Int) == workspace && ($0["document_type"] as? String) == type }
                .sorted { ($0["modified"] as? Int ?? 0) > ($1["modified"] as? Int ?? 0) }
        case "searchDocuments":
            let query = (args["query"] as? String ?? "").lowercased()
            return allDocuments.filter {
                ($0["workspace_id"] as? Int) == workspace
                    && (query.isEmpty || ($0["title"] as? String ?? "").lowercased().contains(query))
            }
        case "getDocument":
            let id = args["document_id"] as? Int
            return allDocuments.first { ($0["id"] as? Int) == id && ($0["workspace_id"] as? Int) == workspace }

        case "listDocumentFolders":
            return workspace == 1 ? documentFolders : []
        case "listDocumentFolderProperties":
            return args["folder_id"] as? Int == 1 ? modelProperties : []
        case "listTableRows":
            return args["folder_id"] as? Int == 1 ? modelRows : []
        case "getTableRow", "setDocumentValue":
            let id = args["document_id"] as? Int
            return modelRows.first { $0["document_id"] as? Int == id }

        // Agents
        case "listIntelligenceAgents":
            return agents
        case "getIntelligenceAgent", "markAgentRead":
            let id = args["agent_id"] as? Int
            return agents.first { ($0["id"] as? Int) == id }
        case "listAgentTeams":
            return [["id": 2, "title": "Ops"], ["id": 1, "title": "Research"]]
        case "listAgentMessages":
            guard let id = args["agent_id"] as? Int else { return nil }
            var messages = agentMessages(id)
            if let before = args["before"] as? Int { messages = messages.filter { ($0["id"] as? Int ?? 0) < before } }
            let limit = args["limit"] as? Int ?? 100
            return Array(messages.suffix(limit))
        case "listAgentMessageAttachments":
            let id = args["message_id"] as? Int
            return id == 1014
                ? [["id": id ?? 0, "media_type": "image/png", "data": PreviewData.screenshotPNG]]
                : []
        case "listAgentCues":
            return cues(args["agent_id"] as? Int)
        case "listAgentRuns":
            let runs = runs(args["agent_id"] as? Int)
            return Array(runs.prefix(args["limit"] as? Int ?? 50))
        case "listMemories":
            return memories(of: args["agent_id"] as? Int)

        // Actors
        case "listActors":
            return actors
        case "listActorUsage":
            return actorUsage
        case "listActorSessions":
            return actorSessions
        case "getActorSession":
            let id = args["id"] as? Int
            return actorSessions.first { ($0["id"] as? Int) == id }
        case "markActorSessionRead":
            let id = args["session_id"] as? Int
            guard var session = actorSessions.first(where: { ($0["id"] as? Int) == id }) else { return nil }
            session["unread"] = false
            session["read_at"] = nowSeconds
            return session
        case "listActorSessionMessages":
            return actorSessionMessages(args["session_id"] as? Int)
        case "listActorSessionMessageAttachments":
            return (args["message_id"] as? Int) == 2101
                ? [["id": 2101, "media_type": "image/png", "data": PreviewData.screenshotPNG]]
                : []
        case "listClients":
            return clients

        // Models
        case "listIntelligenceEndpoints":
            return endpoints
        case "listEndpointModels":
            let id = args["endpoint_id"] as? Int
            return endpointModels.filter { ($0["endpoint_id"] as? Int) == id }
                .sorted { ($0["model_name"] as? String ?? "") < ($1["model_name"] as? String ?? "") }
        case "listIntelligenceDefaults":
            return [
                ["id": 1, "tier": "agent", "endpoint_model_id": 2],
                ["id": 2, "tier": "low", "endpoint_model_id": 3],
                ["id": 3, "tier": "medium", "endpoint_model_id": 2],
                ["id": 4, "tier": "high", "endpoint_model_id": 1],
            ]
        case "listIntelligenceSpend":
            return [
                ["period": "hour", "spent": 0.42, "reached": false],
                ["period": "day", "limit": 20.0, "spent": 6.85, "reached": false],
                ["period": "month", "limit": 250.0, "spent": 142.1, "reached": false],
            ] as [[String: Any]]
        case "listCatalogModels":
            if let provider = args["provider_identifier"] as? String {
                return catalog.filter { ($0["provider_identifier"] as? String) == provider }
            }
            return catalog

        // Connectors
        case "listConnectorAccounts":
            return connectorAccounts
        case "listWorkspaceResourceKinds":
            return (workspace == 2 ? [5] : [1, 3, 2]).map { ["kind_id": $0] }
        case "listResources":
            return resourceList(args)
        case "getResource":
            let id = args["resource_id"] as? Int
            return resources.first { ($0["id"] as? Int) == id }
        case "listConnectorOrganizationUnits":
            return organizationUnits(args["account_id"] as? Int)
        case "searchConnectorResources":
            return importable(args)

        // Extensions
        case "listExtensions":
            return extensions
        case "listExtensionPermissions":
            return extensionPermissions(args["extension_id"] as? Int)
        case "listExtensionHooks":
            return extensionHooks(args["extension_id"] as? Int)
        case "searchExtensionRegistries":
            return registrySearch(args["query"] as? String ?? "")
        case "previewExtension":
            return extensionPreview(sourceURL: args["source_url"] as? String)
        case "previewExtensionScript":
            return extensionPreview(script: args["script"] as? String)

        default:
            return nil
        }
    }

    // MARK: Workspaces

    var workspaces: [[String: Any]] {
        [
            ["id": 1, "title": "Studio", "emoji": "🎨"],
            ["id": 2, "title": "Home", "emoji": "🏡"],
        ]
    }

    // MARK: Tasks

    struct Folder {
        let id: Int
        let workspace: Int
        let title: String
    }

    var folders: [Folder] {
        [
            Folder(id: 1, workspace: 1, title: "Launch"),
            Folder(id: 2, workspace: 1, title: "Product"),
            Folder(id: 3, workspace: 1, title: "Admin"),
            Folder(id: 4, workspace: 2, title: "Errands"),
            Folder(id: 5, workspace: 2, title: "House"),
        ]
    }

    struct TaskTag {
        let id: Int
        let workspace: Int
        let name: String
    }

    var tags: [TaskTag] {
        [
            TaskTag(id: 1, workspace: 1, name: "design"),
            TaskTag(id: 2, workspace: 1, name: "waiting"),
            TaskTag(id: 3, workspace: 1, name: "quick win"),
            TaskTag(id: 4, workspace: 1, name: "q4"),
            TaskTag(id: 5, workspace: 2, name: "weekend"),
        ]
    }

    var savedViews: [[String: Any]] {
        [
            [
                "id": 1, "workspace_id": 1, "name": "Launch this week", "scope": 1,
                "tags": ["with": [4], "without": [Int]()], "priorities": [String](), "sizes": [Int](),
                "sort": "dueDate", "descending": false,
            ],
            [
                "id": 2, "workspace_id": 1, "name": "Urgent anywhere", "scope": "all",
                "tags": ["with": [Int](), "without": [Int]()], "priorities": ["urgent", "high"], "sizes": [Int](),
                "sort": "priority", "descending": true,
            ],
        ]
    }

    /// Who a task is assigned to, as the wire tags it.
    enum Assignee {
        case user, agent(Int), contact(Int)

        var json: [String: Any] {
            switch self {
            case .user: ["kind": "user"]
            case .agent(let id): ["kind": "agent", "agent_id": id]
            case .contact(let id): ["kind": "contact", "contact_id": id]
            }
        }
    }

    struct FixtureTask {
        let id: Int
        let workspace: Int
        let folder: Int?
        let title: String
        var description = ""
        var status = "incomplete"
        var priority = "none"
        var size: Int?
        var assignee: Assignee?
        /// Days from today.
        var start: Int?
        var due: Int?
        var tags: [Int] = []
    }

    var tasks: [FixtureTask] {
        [
            FixtureTask(
                id: 1, workspace: 1, folder: 1, title: "Finalize launch checklist",
                description: """
                Everything that has to be true before we flip the switch on the 18th.

                - [x] Pricing page live behind the flag
                - [x] Status page and support inbox ready
                - [ ] Demo video recorded
                - [ ] Press kit out to Maya
                - [ ] Changelog post scheduled

                See [Launch Plan](cohesion://document/1/1).
                """,
                priority: "high", size: 3, assignee: .user, due: 0, tags: [4]),
            FixtureTask(
                id: 2, workspace: 1, folder: 1, title: "Review pricing page copy",
                description: "Tighten the plan descriptions and make the annual discount obvious. Notes in [Pricing Notes](cohesion://document/1/3).",
                priority: "medium", size: 2, assignee: .agent(3), due: 1, tags: [1]),
            FixtureTask(
                id: 3, workspace: 1, folder: 1, title: "Send press kit to Maya",
                description: "Logo pack, screenshots, the one-pager and founder bio, as one zip with a README.",
                priority: "high", size: 1, assignee: .contact(1), due: -2, tags: [2]),
            FixtureTask(
                id: 4, workspace: 1, folder: 1, title: "Record demo video",
                description: """
                Two minutes, no voice-over. Storyboard:

                1. Morning on the Dashboard
                2. Ask Atlas what's at risk
                3. Hand a fix to Claude Code and approve it from the phone
                """,
                priority: "urgent", size: 4, assignee: .user, start: 0, due: 3, tags: [1, 4]),
            FixtureTask(
                id: 5, workspace: 1, folder: 2, title: "Fix iPad sidebar spacing",
                description: "The section headers sit 4pt too close to the first row in compact width.",
                priority: "low", size: 1, due: 7, tags: [3]),
            FixtureTask(
                id: 6, workspace: 1, folder: 2, title: "Draft Q4 roadmap",
                description: "Start from the [Q3 Plan](cohesion://document/1/2) retro. Three themes at most.",
                priority: "medium", size: 5, assignee: .agent(1), start: 2, due: 9, tags: [4]),
            FixtureTask(
                id: 7, workspace: 1, folder: 2, title: "Triage open GitHub issues",
                description: "Label, dedupe and close anything stale over 90 days.",
                size: 2, assignee: .agent(5)),
            FixtureTask(
                id: 8, workspace: 1, folder: 3, title: "Renew domain names",
                description: "hellocohesion.io and cohesion.app lapse on Friday.",
                priority: "urgent", size: 1, assignee: .user, due: -1, tags: [3]),
            FixtureTask(
                id: 9, workspace: 1, folder: nil, title: "Book flights for the Lisbon offsite",
                description: "Arrive the 3rd, leave the 7th. Aisle seats.",
                priority: "medium", assignee: .user, due: 6),
            FixtureTask(
                id: 10, workspace: 1, folder: nil, title: "Reply to Tom about the 1099s",
                description: "He needs the contractor list and totals by end of day.",
                priority: "high", size: 1, assignee: .contact(4), due: 0, tags: [2]),
            FixtureTask(
                id: 11, workspace: 1, folder: 2, title: "Set up staging database",
                description: "Postgres 17 on the build server, nightly restore from production.",
                status: "completed", priority: "medium", size: 3, due: -3),
            FixtureTask(
                id: 12, workspace: 1, folder: 1, title: "Sponsor a booth at SwiftConf",
                description: "Decided to skip this year; revisit in spring.",
                status: "cancelled", priority: "low", size: 4),
            FixtureTask(
                id: 13, workspace: 1, folder: nil, title: "Clean up old feature flags",
                status: "completed", priority: "low", size: 2, assignee: .agent(5), tags: [3]),
            FixtureTask(
                id: 14, workspace: 2, folder: 4, title: "Pick up dry cleaning",
                priority: "low", size: 1, assignee: .user, due: 0),
            FixtureTask(
                id: 15, workspace: 2, folder: 5, title: "Repot the fiddle-leaf fig",
                description: "The 12-inch terracotta pot is in the garage.",
                priority: "none", size: 2, assignee: .agent(6), due: 5, tags: [5]),
            FixtureTask(
                id: 16, workspace: 2, folder: nil, title: "Call the plumber about the water heater",
                priority: "high", size: 1, assignee: .contact(9), due: 1),
            // An inbox as full as a real one, so its list reads at length.
            FixtureTask(
                id: 17, workspace: 1, folder: nil, title: "Read the Liquid Glass design notes",
                priority: "none", size: 2, due: 2),
            FixtureTask(
                id: 18, workspace: 1, folder: nil, title: "Ask Priya for the investor update draft",
                priority: "medium", assignee: .user, due: 1, tags: [2]),
            FixtureTask(
                id: 19, workspace: 1, folder: nil, title: "Expense the conference hotel",
                priority: "low", size: 1),
            FixtureTask(
                id: 20, workspace: 1, folder: nil, title: "Try the new Xcode build cache",
                priority: "none", size: 3, assignee: .agent(5)),
            FixtureTask(
                id: 21, workspace: 1, folder: nil, title: "Schedule the team retro",
                priority: "medium", assignee: .user, due: 3),
        ]
    }

    func json(_ task: FixtureTask) -> [String: Any] {
        var json: [String: Any] = [
            "id": task.id,
            "workspace_id": task.workspace,
            "title": task.title,
            "description": task.description,
            "status": task.status,
            "priority": task.priority,
            "tag_ids": task.tags,
        ]
        json["task_folder_id"] = task.folder
        json["size"] = task.size
        json["assignee"] = task.assignee?.json
        json["start_date"] = task.start.map(day)
        json["due_date"] = task.due.map(day)
        return json
    }

    /// `listTasks`, filtered, ordered and paged as cohesiond does.
    func taskPage(_ args: [String: Any]) -> [String: Any] {
        var matching = tasks
        if let workspace = args["workspace_id"] as? Int {
            matching = matching.filter { $0.workspace == workspace }
        }
        if let ids = args["ids"] as? [Int] {
            matching = matching.filter { ids.contains($0.id) }
        }
        switch args["folder"] {
        case let folder as String where folder == "inbox":
            matching = matching.filter { $0.folder == nil }
        case let folder as Int:
            matching = matching.filter { $0.folder == folder }
        default:
            break
        }
        if let statuses = args["statuses"] as? [String] {
            matching = matching.filter { statuses.contains($0.status) }
        }
        if let tags = args["tags"] as? [String: [Int]] {
            let with = Set(tags["with"] ?? [])
            let without = Set(tags["without"] ?? [])
            matching = matching.filter { with.isSubset(of: $0.tags) && without.isDisjoint(with: $0.tags) }
        }
        if let priorities = args["priorities"] as? [String] {
            matching = matching.filter { priorities.contains($0.priority) }
        }
        if let sizes = args["sizes"] as? [Int] {
            matching = matching.filter { $0.size.map(sizes.contains) ?? false }
        }
        if let due = args["due_date"] as? [String: String] {
            matching = matching.filter { task in
                guard let date = task.due.map(day) else { return false }
                return (due["before"].map { date < $0 } ?? true) && (due["after"].map { date > $0 } ?? true)
            }
        }
        if let assignee = args["assignee"] as? [String: Any] {
            matching = matching.filter { task in
                guard let json = task.assignee?.json else { return false }
                return json["kind"] as? String == assignee["kind"] as? String
                    && json["agent_id"] as? Int == assignee["agent_id"] as? Int
                    && json["contact_id"] as? Int == assignee["contact_id"] as? Int
            }
        }
        let ranks = ["none": 0, "low": 1, "medium": 2, "high": 3, "urgent": 4]
        let descending = args["descending"] as? Bool ?? false
        /// The key to order by; `nil` sorts last either way.
        func key(_ task: FixtureTask) -> String? {
            switch args["sort"] as? String {
            case "title": task.title.lowercased()
            case "priority": String(ranks[task.priority] ?? 0)
            case "size": task.size.map(String.init)
            case "startDate": task.start.map(day)
            case "dueDate": task.due.map(day)
            default: String(format: "%06d", task.id)
            }
        }
        matching.sort { first, second in
            switch (key(first), key(second)) {
            case let (a?, b?) where a != b: descending ? a > b : a < b
            case (_?, nil): true
            case (nil, _?): false
            default: first.id < second.id
            }
        }
        let offset = args["offset"] as? Int ?? 0
        let limit = args["limit"] as? Int ?? 50
        let page = matching.dropFirst(offset).prefix(limit)
        return ["tasks": page.map(json), "total": matching.count]
    }

    // MARK: Contacts

    func contact(
        _ id: Int, _ workspace: Int, _ first: String, _ middle: String? = nil, last: String,
        notes: String, methods: [(String, String)]
    ) -> [String: Any] {
        var json: [String: Any] = [
            "id": id,
            "workspace_id": workspace,
            "first_name": first,
            "last_name": last,
            "notes": notes,
            "photo": ["kind": "none"],
            "methods": methods.enumerated().map { index, method in
                ["id": id * 10 + index, "kind": method.0, "value": method.1] as [String: Any]
            },
        ]
        json["middle_name"] = middle
        return json
    }

    /// By last name, then first, as cohesiond lists them.
    var contacts: [[String: Any]] {
        let all: [[String: Any]] = [
            contact(
                1, 1, "Maya", last: "Chen",
                notes: "**Senior reporter, The Ledger Daily.** Covering the launch on the 18th.\n\nPrefers press assets as one zip.",
                methods: [("email", "maya.chen@ledgerdaily.example"), ("phone", "+1 (415) 555-0142")]),
            contact(
                2, 1, "Daniel", last: "Okafor",
                notes: "Design partner at **Northwind Labs**. Ran the onboarding study in August.",
                methods: [("email", "daniel@northwind.example"), ("phone", "+1 (646) 555-0187")]),
            contact(
                3, 1, "Priya", last: "Raman",
                notes: "Angel investor. Quarterly update goes out the first Monday of the month.",
                methods: [("email", "priya@ramanventures.example")]),
            contact(
                4, 1, "Tom", last: "Becker",
                notes: "Accountant at **Becker CPA**. Needs the contractor list for 1099s.",
                methods: [("email", "tom@beckercpa.example"), ("phone", "+1 (510) 555-0119"), ("phone", "+1 (510) 555-0120")]),
            contact(
                5, 1, "Sofia", last: "Álvarez",
                notes: "Freelance motion designer; did the launch teaser.",
                methods: [("email", "hola@sofiaalvarez.example"), ("phone", "+34 612 555 014")]),
            contact(
                6, 1, "Lena", "Marie", last: "Fischer",
                notes: "Head of IT at **Kessler & Roth**, the pilot customer. Wants SSO before the rollout.",
                methods: [("email", "l.fischer@kesslerroth.example"), ("phone", "+49 30 5550 1723")]),
            contact(
                7, 1, "Marcus", last: "Hill",
                notes: "Runs the iOS meetup. Offered a lightning-talk slot in December.",
                methods: [("email", "marcus@iosmeetup.example")]),
            contact(
                8, 1, "Aiko", last: "Tanaka",
                notes: "Contract iOS engineer, available from January.",
                methods: [("email", "aiko.tanaka@example.com"), ("phone", "+81 90 5550 2231")]),
            contact(
                9, 2, "Frank", last: "Russo",
                notes: "Plumber. Replaced the kitchen faucet last spring.",
                methods: [("phone", "+1 (415) 555-0163")]),
            contact(
                10, 2, "Grace", last: "Kim",
                notes: "Neighbor at 41. Has a spare key.",
                methods: [("phone", "+1 (415) 555-0178"), ("email", "grace.kim@example.com")]),
        ]
        return all.sorted {
            let first = ($0["last_name"] as? String ?? "", $0["first_name"] as? String ?? "")
            let second = ($1["last_name"] as? String ?? "", $1["first_name"] as? String ?? "")
            return first < second
        }
    }

    // MARK: Feeds and articles

    func feed(
        _ id: Int, _ title: String, _ url: String, unread: Int, policy: String = "whenExcerpt",
        status: [String: Any]
    ) -> [String: Any] {
        ["id": id, "title": title, "url": url, "unread": unread, "full_page_policy": policy, "status": status]
    }

    var feeds: [[String: Any]] {
        [
            feed(
                1, "Swift Field Notes", "https://swiftfieldnotes.dev/feed.xml", unread: 2,
                status: ["state": "refreshed", "at": minutesAgo(12), "added": 1]),
            feed(
                2, "The Pragmatic Designer", "https://pragmaticdesigner.co/rss", unread: 1, policy: "always",
                status: ["state": "refreshed", "at": minutesAgo(12), "added": 0]),
            feed(
                3, "Indie Dev Monthly", "https://indiedevmonthly.com/atom.xml", unread: 2,
                status: ["state": "refreshed", "at": minutesAgo(12), "added": 2]),
            feed(
                4, "Ops Weekly", "https://opsweekly.io/feed", unread: 0,
                status: ["state": "failed", "at": minutesAgo(12), "failure": ["kind": "status", "code": 503]]),
        ]
    }

    struct FixtureArticle {
        let id: Int
        let feed: Int
        let title: String
        let url: String
        let author: String?
        /// Hours ago.
        let published: Double
        let read: Bool
        /// `nil` for a page never fetched.
        let contents: String?
    }

    var articleFixtures: [FixtureArticle] {
        [
            FixtureArticle(
                id: 1, feed: 1, title: "Observation, Two Years In",
                url: "https://swiftfieldnotes.dev/2026/observation-two-years-in", author: "Ines Kowalski",
                published: 1.5, read: false,
                contents: """
                Two years after `@Observable` replaced `ObservableObject` in most of our code, the wins are clear — and so are the sharp edges.

                ## What got better

                - **Fewer redraws.** Views read only what they touch, so a list row no longer redraws when an unrelated property changes.
                - **Less ceremony.** No more `@Published` on every property, no `objectWillChange` to forward.

                ## What still bites

                Observation tracks *reads during body*. Read a property in a `Task` and nothing re-runs when it changes:

                ```swift
                .task {
                    // Runs once: model.query isn't tracked here.
                    await search(model.query)
                }
                ```

                Use `.task(id: model.query)` instead, and the work restarts each time it changes.

                > The rule of thumb: if you want SwiftUI to react, read it in `body`.

                ## Migrating the rest

                We moved the last 40 view models in a week, one screen at a time, with no behavior changes along the way.
                """),
            FixtureArticle(
                id: 2, feed: 3, title: "How We Priced Our App the Second Time",
                url: "https://indiedevmonthly.com/issues/58/pricing-again", author: "Ravi Patel",
                published: 4, read: false,
                contents: """
                Our first pricing page had four plans and a comparison table with 31 rows. Conversions were fine; support emails asking *which plan do I need?* were not.

                ## Three plans, one question

                We cut to three plans and put one question at the top: **how many people will use it?**

                | Plan | Price | For |
                | --- | --- | --- |
                | Solo | $8/mo | Just you |
                | Team | $14/seat | 2–20 people |
                | Company | Talk to us | SSO, audit logs |

                Annual billing saves two months, and we say so in the button, not a footnote.

                ## What changed

                Trial-to-paid went from 9% to 13% in six weeks. Support questions about plans dropped by two thirds.
                """),
            FixtureArticle(
                id: 3, feed: 2, title: "Empty States Are Onboarding",
                url: "https://pragmaticdesigner.co/empty-states-are-onboarding", author: "Hana Ito",
                published: 7, read: false,
                contents: """
                The first screen most people see in your app is an empty one. Treat it as the start of a conversation.

                1. **Say what goes here.** "No tasks yet" says nothing; "Tasks you add, or agents assign you, show up here" says everything.
                2. **Offer one action.** Not three.
                3. **Don't decorate.** An illustration that takes half the screen pushes the action below the fold.
                """),
            FixtureArticle(
                id: 4, feed: 1, title: "Swift Testing's Parameterized Tests in Practice",
                url: "https://swiftfieldnotes.dev/2026/parameterized-tests", author: "Ines Kowalski",
                published: 26, read: false,
                contents: """
                `@Test(arguments:)` replaced a dozen copy-pasted XCTest methods in our date parsing suite.

                ```swift
                @Test(arguments: ["2026-11-09", "2026-02-29", "1999-12-31"])
                func parses(_ day: String) throws {
                    #expect(CalendarDay.date(day) != nil)
                }
                ```

                Each argument shows up as its own test in the navigator, and a failure names the input that broke.
                """),
            FixtureArticle(
                id: 5, feed: 3, title: "The Launch Checklist I Wish I'd Had",
                url: "https://indiedevmonthly.com/issues/57/launch-checklist", author: "Ravi Patel",
                published: 30, read: false,
                contents: """
                - Status page **before** the launch, not after the first outage
                - A support inbox someone actually reads
                - Press kit as one zip: logo, screenshots, a one-pager, a bio
                - A changelog post ready to publish the minute it's live
                - Someone *not* on the team clicking through signup on a fresh phone
                """),
            FixtureArticle(
                id: 6, feed: 2, title: "Designing for Glanceability",
                url: "https://pragmaticdesigner.co/glanceability", author: "Hana Ito",
                published: 52, read: true, contents: nil),
            FixtureArticle(
                id: 7, feed: 4, title: "Postgres Upgrades Without the Drama",
                url: "https://opsweekly.io/2026/45/postgres-upgrades", author: nil,
                published: 75, read: true,
                contents: """
                Logical replication to a new major version, a cutover window of under a minute, and a rollback plan you rehearse before you need it.
                """),
            FixtureArticle(
                id: 8, feed: 1, title: "Typed Throws, a Year Later",
                url: "https://swiftfieldnotes.dev/2026/typed-throws", author: "Ines Kowalski",
                published: 120, read: true,
                contents: "Typed throws earned their place at module boundaries, and nowhere else."),
            FixtureArticle(
                id: 9, feed: 4, title: "On-Call Without Burnout",
                url: "https://opsweekly.io/2026/44/on-call", author: "Dee Mensah",
                published: 170, read: true,
                contents: "Rotations of one week, a handoff note every Monday, and a rule: no pages for anything that can wait until morning."),
        ]
    }

    func snapshot(_ article: FixtureArticle) -> [String: Any] {
        if article.contents != nil {
            return [
                "state": "captured", "final_url": article.url,
                "fetched_at": secondsAgo(article.published * 3600 - 120), "truncated": false,
            ]
        }
        return [
            "state": "failed", "failure": ["kind": "status", "code": 403],
            "attempted_at": secondsAgo(article.published * 3600 - 120),
        ]
    }

    func summary(_ article: FixtureArticle) -> [String: Any] {
        var json: [String: Any] = [
            "id": article.id, "url": article.url, "title": article.title,
            "published_at": secondsAgo(article.published * 3600), "snapshot": snapshot(article),
            "feed_id": article.feed, "read": article.read,
        ]
        json["author"] = article.author
        return json
    }

    func article(_ id: Int) -> [String: Any]? {
        guard let article = articleFixtures.first(where: { $0.id == id }) else { return nil }
        var json = summary(article)
        json["feed_id"] = nil
        json["contents"] = article.contents ?? ""
        return json
    }

    func articlePage(_ args: [String: Any]) -> [String: Any] {
        var matching = articleFixtures
        if let filter = args["filter"] as? [String: Int], let feed = filter["feed"] {
            matching = matching.filter { $0.feed == feed }
        }
        let offset = args["offset"] as? Int ?? 0
        let limit = args["limit"] as? Int ?? 50
        return [
            "articles": matching.dropFirst(offset).prefix(limit).map(summary),
            "total": matching.count,
        ]
    }

    // MARK: Journal and documents

    struct JournalDay {
        let id: Int
        let workspace: Int
        /// Days from today.
        let offset: Int
        let contents: String
    }

    var journal: [JournalDay] {
        [
            JournalDay(id: 101, workspace: 1, offset: 0, contents: """
            ## Morning
            Slept badly, but the coffee is good. **Launch is nine days out.**

            - Atlas flagged the press kit as overdue: sending it before lunch
            - Claude Code is on the reconnect backoff; check back after standup

            ## Afternoon
            Pricing review with Daniel went well. He wants the annual toggle to default *on*.
            """),
            JournalDay(id: 102, workspace: 1, offset: -1, contents: """
            Long design review. We cut the comparison table and kept three plans.

            > "If someone has to ask which plan they need, the page failed." — Daniel

            Tomorrow: demo storyboard, then the [Q4 roadmap](cohesion://task/1/6) outline.
            """),
            JournalDay(id: 103, workspace: 1, offset: -2, contents: """
            Staging database is up. Restores from last night's backup in **4 minutes**.

            - [x] Postgres 17 on the build server
            - [x] Nightly restore job
            - [ ] Alerting when it fails
            """),
            JournalDay(id: 104, workspace: 1, offset: -3, contents: "Quiet day. Wrote most of the changelog post and walked to the bay at sunset."),
            JournalDay(id: 105, workspace: 1, offset: -5, contents: """
            ### Weekly review
            1. Shipped: share extension, Live Activities for actor sessions
            2. Slipped: SSO for Kessler & Roth (next week)
            3. Learned: people pin two agents, rarely more
            """),
            JournalDay(id: 106, workspace: 1, offset: -7, contents: "First full day with the new agents setup. Scout's morning digest is already the first thing I read."),
            JournalDay(id: 201, workspace: 2, offset: 0, contents: "Farmers market: figs, sourdough, the good tomatoes."),
        ]
    }

    var documents: [[String: Any]] {
        [
            document(1, 1, "Launch Plan", modified: minutesAgo(40), """
            # Launch Plan

            **Date:** November 18 · **Owner:** Jackson

            ## Goals
            1. 2,000 signups in the first week
            2. A piece in *The Ledger Daily*
            3. No pages after 10 PM

            ## Timeline

            | When | What | Who |
            | --- | --- | --- |
            | Nov 11 | Press kit out | [Maya](cohesion://task/1/3) |
            | Nov 13 | Demo video | [Record it](cohesion://task/1/4) |
            | Nov 17 | Changelog scheduled | Quill |
            | Nov 18 | Launch, 9 AM Pacific | Everyone |

            ## Risks
            - The demo video slips, and the post goes out without it
            - Signup spikes past the database's connection limit
            """),
            document(2, 1, "Q3 Plan", modified: daysAgo(12), """
            # Q3 Plan

            ## Themes
            - **Agents that act.** Cues, jobs and proposals.
            - **Actors everywhere.** Claude Code and Codex sessions from the phone.
            - **Quiet by default.** Fewer notifications, better ones.

            ## Retro
            Shipped two of three. Notifications slipped to Q4; see the [roadmap draft](cohesion://task/1/6).
            """),
            document(3, 1, "Pricing Notes", modified: hoursAgo(5), """
            # Pricing Notes

            - Three plans: **Solo**, **Team**, **Company**
            - Annual saves two months; say it in the button
            - Remove the 31-row comparison table

            ```
            Solo     $8 / month
            Team     $14 / seat / month
            Company  Talk to us
            ```
            """),
            document(4, 1, "Interview Guide", modified: daysAgo(4), """
            # Interview Guide

            1. Walk me through the last time you handed work to an AI tool.
            2. What did you check before trusting the result?
            3. Where were you when it finished?

            *Listen for:* the moment they stopped watching.
            """),
            document(5, 1, "Brand Voice", modified: daysAgo(9), """
            # Brand Voice

            Plain, warm, brief. We say what a thing does, not how excited we are about it.

            | Instead of | Say |
            | --- | --- |
            | Supercharge your workflow | Hand off the busywork |
            | Seamless integration | Works with GitHub and Linear |
            """),
            document(6, 1, "Design Review — Nov 8", modified: daysAgo(1), """
            # Design Review — Nov 8

            **Attendees:** Jackson, Daniel, Sofia

            ## Decisions
            - Cut the comparison table
            - Annual toggle defaults on
            - Dashboard leads with *What's New*

            ## Follow-ups
            - [ ] [Review pricing page copy](cohesion://task/1/2)
            - [ ] [Fix iPad sidebar spacing](cohesion://task/1/5)
            """),
            document(7, 2, "Packing List", modified: daysAgo(2), "- Passport\n- Chargers\n- Rain jacket\n- Book for the flight"),
            document(8, 2, "Recipes to Try", modified: daysAgo(6), "## Fig and goat cheese tart\n\nPuff pastry, figs, honey, thyme. 25 minutes at 200°C."),
            document(31, 1, "Claude Opus 5.5", modified: daysAgo(3), folder: 1, """
            # Claude Opus 5.5

            The default for agents and long-running work.
            """),
        ]
    }

    func document(_ id: Int, _ workspace: Int, _ title: String, modified: Int, folder: Int? = nil, _ contents: String) -> [String: Any] {
        [
            "id": id, "workspace_id": workspace, "document_type": "normal", "title": title,
            "contents": contents, "modified": modified, "folder_id": folder ?? NSNull(),
        ]
    }

    /// Studio's document folders: Models, a table, and Meetings, a plain one.
    var documentFolders: [[String: Any]] {
        [
            ["id": 1, "workspace_id": 1, "parent_id": NSNull(), "title": "Models", "sort_order": 0, "deleted": false, "is_table": true],
            ["id": 2, "workspace_id": 1, "parent_id": NSNull(), "title": "Meetings", "sort_order": 1, "deleted": false, "is_table": false],
        ]
    }

    /// The Models table's columns: one of each type but a plain decimal.
    var modelProperties: [[String: Any]] {
        func property(_ id: Int, _ name: String, _ type: String, options: [[String: Any]]? = nil) -> [String: Any] {
            var property: [String: Any] = [
                "id": id, "folder_id": 1, "name": name, "data_type": type, "sort_order": id, "formula": NSNull(),
            ]
            property["options"] = options
            return property
        }
        func option(_ id: Int, _ name: String, _ color: String?) -> [String: Any] {
            ["id": id, "property_id": 1, "name": name, "color": color ?? NSNull(), "sort_order": id]
        }
        return [
            property(1, "Provider", "choice", options: [
                option(1, "Anthropic", "orange"), option(2, "OpenAI", "green"), option(3, "Local", nil),
            ]),
            property(2, "Context", "integer"),
            property(3, "Input Price", "currency"),
            property(4, "Released", "date"),
            property(5, "Default", "checkbox"),
            property(6, "Notes", "text"),
        ]
    }

    /// The Models table's rows, documents 31 to 34.
    var modelRows: [[String: Any]] {
        func row(_ id: Int, _ title: String, _ cells: [(Int, String, Any)]) -> [String: Any] {
            [
                "document_id": id, "folder_id": 1, "title": title,
                "cells": cells.map { ["property_id": $0.0, "value": ["type": $0.1, "value": $0.2]] },
            ]
        }
        return [
            row(31, "Claude Opus 5.5", [
                (1, "choice", 1), (2, "integer", 1_000_000), (3, "currency", 5), (4, "date", "2026-09-30"),
                (5, "checkbox", true), (6, "text", "Agents and long work"),
            ]),
            row(32, "Claude Haiku 5.5", [
                (1, "choice", 1), (2, "integer", 200_000), (3, "currency", 0.8), (4, "date", "2026-09-30"),
                (5, "checkbox", false), (6, "text", "Background runs"),
            ]),
            row(33, "GPT-6", [(1, "choice", 2), (2, "integer", 400_000), (3, "currency", 2.5), (4, "date", "2025-12-11")]),
            row(34, "Qwen on the Mac Studio", [(1, "choice", 3), (2, "integer", 128_000), (3, "currency", 0)]),
        ]
    }

    /// The documents and the journal entries, which are documents too.
    var allDocuments: [[String: Any]] {
        documents + journal.map { entry in
            [
                "id": entry.id, "workspace_id": entry.workspace, "document_type": "journal",
                "title": day(entry.offset), "contents": entry.contents,
                "modified": entry.offset == 0 ? minutesAgo(25) : on(entry.offset, at: 21, 30),
                "journal_date": day(entry.offset),
            ] as [String: Any]
        }
    }

    // MARK: Agents

    func agent(
        _ id: Int, _ name: String, _ color: String, _ emoji: String?, _ personality: String,
        _ verbosity: String, role: String, activity: String? = nil, started: Int? = nil,
        unread: Bool = false, pinned: Bool = false, team: Int? = nil, context: Int? = nil, last: Int?
    ) -> [String: Any] {
        var json: [String: Any] = [
            "id": id, "agent_name": name, "agent_color": color, "agent_personality": personality,
            "agent_verbosity": verbosity, "agent_role": role, "agent_unread": unread, "pinned": pinned,
        ]
        json["agent_emoji"] = emoji
        json["activity"] = activity
        json["foreground_started"] = started
        json["team_id"] = team
        json["context_tokens"] = context
        json["last_message_at"] = last
        return json
    }

    /// In the user's order, the pinned first.
    var agents: [[String: Any]] {
        [
            agent(
                1, "Atlas", "blue", "🧭", "professional", "detailed",
                role: "Chief of staff: plans my week and keeps launches on track",
                pinned: true, context: 48_210, last: minutesAgo(3)),
            agent(
                2, "Scout", "green", nil, "friendly", "brief",
                role: "Research: reads the feeds and digs into questions",
                activity: "Reading the Q3 plan", started: minutesAgo(2), pinned: true, team: 1,
                context: 21_877, last: minutesAgo(2)),
            agent(
                3, "Quill", "purple", "✍️", "candid", "detailed",
                role: "Editor for docs, posts and the changelog",
                unread: true, team: 1, context: 12_404, last: minutesAgo(25)),
            agent(
                4, "Ledger", "orange", "📊", "professional", "terse",
                role: "Tracks spend, invoices and renewals",
                team: 2, context: 6_020, last: hoursAgo(3)),
            agent(
                5, "Relay", "teal", nil, "balanced", "brief",
                role: "Triage for GitHub and Linear",
                team: 2, last: hoursAgo(9)),
            agent(
                6, "Juniper", "pink", "🌿", "playful", "brief",
                role: "Home: groceries, plants and the family calendar",
                context: 3_310, last: daysAgo(1)),
        ]
    }

    /// One line of a message, as cohesiond words its excerpt.
    func line(_ text: String, cut: Int = 200) -> String {
        var line = text
        for mark in ["**", "__", "`"] { line = line.replacingOccurrences(of: mark, with: "") }
        line = line.replacingOccurrences(of: "\n", with: " ")
        while line.contains("  ") { line = line.replacingOccurrences(of: "  ", with: " ") }
        line = line.trimmingCharacters(in: .whitespaces)
        return line.count > cut ? String(line.prefix(cut)) + "…" : line
    }

    func message(
        _ id: Int, _ sentAt: Int, _ sender: String, _ content: [String: Any],
        run: Int? = nil, runDescription: String? = nil, part: String? = nil,
        reaction: String? = nil, reactedAt: Int? = nil, replyTo: Int? = nil,
        excerpt: String? = nil, verb: String? = nil, attachments: Int = 0
    ) -> [String: Any] {
        let excerpt = excerpt ?? (content["text"] as? String).map { line($0) }
            ?? (attachments == 1 ? "1 image" : "")
        var json: [String: Any] = [
            "id": id, "sent_at": sentAt, "sender": sender, "message_content": content,
            "excerpt": excerpt, "attachment_count": attachments,
        ]
        json["run_id"] = run
        json["run_description"] = runDescription
        json["run_part"] = part
        json["reaction"] = reaction
        json["reacted_at"] = reaction == nil ? nil : (reactedAt ?? sentAt + 30)
        json["reply_to"] = replyTo
        json["excerpt_verb"] = verb
        if let reaction {
            json["reaction_excerpt"] = "\(reaction) to “\(line(excerpt, cut: 140))”"
            json["reaction_excerpt_verb"] = "Reacted"
        }
        return json
    }

    func text(_ text: String) -> [String: Any] { ["kind": "text", "text": text] }

    func code(_ title: String, _ code: String, result: String) -> [String: Any] {
        ["kind": "codeExecution", "title": title, "code": code, "outcome": ["status": "succeeded", "result": result]]
    }

    func agentMessages(_ agentID: Int) -> [[String: Any]] {
        switch agentID {
        case 1: atlasMessages
        case 2: scoutMessages
        case 3: quillMessages
        case 4: ledgerMessages
        case 5: relayMessages
        case 6: juniperMessages
        default: []
        }
    }

    /// Atlas's conversation: a morning job, a long exchange with a table, a
    /// link, a reaction, a forward, a memory, a fork woken by Scout's
    /// question, an image, a choice and a note.
    var atlasMessages: [[String: Any]] {
        let morning = "The day started"
        return [
            // The morning briefing's job, collapsed under its trigger.
            message(
                1001, hoursAgo(5), "backgroundAgent",
                ["kind": "woke", "by": ["kind": "cue", "cue_name": "Morning briefing", "hook": "day:start"]],
                run: 501, runDescription: morning, part: "trigger",
                excerpt: "Cue “Morning briefing” fired", verb: "Woke"),
            message(
                1002, hoursAgo(5) + 4, "backgroundAgent", ["kind": "documentation", "module": "tasks"],
                run: 501, runDescription: morning, part: "step", excerpt: "Learning about tasks"),
            message(
                1003, hoursAgo(5) + 9, "backgroundAgent",
                code(
                    "Listing today's tasks",
                    """
                    const due = await cohesion.tasks.list({
                      workspace: 1,
                      statuses: ["incomplete"],
                      due: { before: "\(day(1))" },
                    });
                    return due.map(t => `${t.title} (${t.priority})`);
                    """,
                    result: "[\"Finalize launch checklist (high)\", \"Send press kit to Maya (high)\", \"Renew domain names (urgent)\", \"Reply to Tom about the 1099s (high)\"]"),
                run: 501, runDescription: morning, part: "step", excerpt: "Listing today's tasks"),
            message(
                1004, hoursAgo(5) + 20, "backgroundAgent",
                text("☀️ **Good morning.** Four things are due today or overdue, two of them launch work. The press kit to Maya is the one to do first."),
                run: 501, runDescription: morning, part: "surfaced"),

            // The morning's conversation.
            message(
                1005, hoursAgo(3), "user",
                text("Morning! Can you look over what's due this week and tell me what's at risk?")),
            message(
                1006, hoursAgo(3) + 6, "agent",
                code(
                    "Checking this week's tasks",
                    """
                    const week = await cohesion.tasks.list({
                      workspace: 1,
                      due: { before: "\(day(7))" },
                      sort: "dueDate",
                    });
                    return week.length;
                    """,
                    result: "9")),
            message(
                1007, hoursAgo(3) + 18, "agent",
                text("""
                ## This week

                Nine tasks are due before next Monday. Three are at risk:

                1. **Send press kit to Maya** is two days overdue, and her piece runs Thursday.
                2. **Renew domain names**: `hellocohesion.io` lapses on Friday.
                3. **Record demo video** is large and starts today, with nothing blocked out for it.

                | Task | Due | Owner |
                | --- | --- | --- |
                | Finalize launch checklist | Today | You |
                | Review pricing page copy | Tomorrow | Quill |
                | Record demo video | \(day(3)) | You |
                | Book flights for Lisbon | \(day(6)) | You |

                Want me to draft the email for [Send press kit to Maya](cohesion://task/1/3)?
                """),
                reaction: "👍", reactedAt: hoursAgo(3) + 60),
            message(1008, hoursAgo(3) + 75, "user", text("Yes please, keep it short."), replyTo: 1007),
            message(
                1009, hoursAgo(3) + 95, "agent",
                text("""
                Here's a draft:

                > Hi Maya — attached is everything for Thursday: logos, screenshots, a one-pager and my bio, in one zip with a README. Happy to jump on a call if anything's missing. — Jackson

                I kept it to three sentences. I can send it from your account once you approve.
                """)),
            message(
                1010, hoursAgo(2), "user",
                ["kind": "forward", "note": "Also attach the new screenshots from Sofia",
                 "item": ["kind": "task", "workspace_id": 1, "id": 3, "title": "Send press kit to Maya"]],
                excerpt: "Also attach the new screenshots from Sofia"),
            message(
                1011, hoursAgo(2) + 12, "agent",
                ["kind": "memory", "memory": "Maya Chen prefers press assets as a single zip with a README.", "change": "remembered"],
                excerpt: "Maya Chen prefers press assets as a single zip with a README.", verb: "Remembered"),

            // A fork Scout's question woke, collapsed under it.
            message(
                1012, minutesAgo(90), "backgroundAgent",
                ["kind": "askedByAgent", "agent": ["id": 2, "name": "Scout"],
                 "question": "What launch date are we telling press?",
                 "reply": ["status": "answered", "text": "November 18, 9 AM Pacific. Embargo lifts at the same time."]],
                run: 502, part: "trigger", excerpt: "Scout asked: What launch date are we telling press?"),
            message(
                1013, minutesAgo(90) + 8, "backgroundAgent",
                code(
                    "Reading the launch plan",
                    "const plan = await cohesion.documents.get({ workspace: 1, id: 1 });\nreturn plan.contents.split(\"\\n\").slice(0, 4).join(\"\\n\");",
                    result: "# Launch Plan\n\n**Date:** November 18 · **Owner:** Jackson"),
                run: 502, part: "step", excerpt: "Reading the launch plan"),

            message(
                1014, minutesAgo(60), "user",
                text("Here's the new pricing page mock. Thoughts?"),
                reaction: "🎉", reactedAt: minutesAgo(59), attachments: 1),
            message(
                1015, minutesAgo(58), "agent",
                text("""
                It reads much better than the table. A few notes:

                - **Raise the middle card less.** It already wins on color; the lift makes the outer two look disabled.
                - The buttons say *Choose*. Say what happens: **Start free trial**.
                - Put "2 months free" on the annual toggle itself, not under it.
                """)),
            message(
                1016, minutesAgo(30), "user",
                text("Can you block time for the demo recording this week?")),
            message(
                1017, minutesAgo(29), "agent",
                ["kind": "choice", "question": "Which slot works for the demo recording?",
                 "options": ["Wednesday 10:00–12:00", "Thursday 15:00–17:00", "Friday 9:30–11:30"], "selected": 1],
                excerpt: "Which slot works for the demo recording?"),
            message(
                1018, minutesAgo(27), "agent",
                text("Done: **Record demo video** now starts Thursday at 3 PM, and I made it urgent so it tops your list.")),
            message(
                1019, minutesAgo(26), "agent",
                ["kind": "note", "note": "Demo recording is Thursday 3–5 PM; remind Jackson to charge the mic the night before."],
                excerpt: "Demo recording is Thursday 3–5 PM; remind Jackson to charge the mic the night before.",
                verb: "Noted"),
            message(
                1020, minutesAgo(10), "agent",
                ["kind": "rebuiltContext", "reason": "cacheExpired"],
                excerpt: "Context rebuilt because provider cache expired"),
            message(1021, minutesAgo(4), "user", text("What's left for launch?")),
            message(
                1022, minutesAgo(3), "agent",
                text("""
                ### Left for launch

                - [x] Pricing page
                - [x] Status page
                - [ ] Press kit: *drafted, waiting on Sofia's screenshots*
                - [ ] Demo video: Thursday 3 PM
                - [ ] Changelog post: Quill has a draft

                If the demo slips, publish without it and add it Friday. To check the domains yourself:

                ```sh
                whois hellocohesion.io | grep -i expir
                ```
                """)),
        ]
    }

    var scoutMessages: [[String: Any]] {
        [
            message(
                1101, hoursAgo(4), "user",
                text("Pull together what our three closest competitors shipped this quarter.")),
            message(
                1102, hoursAgo(4) + 40, "agent",
                text("""
                On it. So far:

                - **Linear** shipped agents that triage incoming issues.
                - **Notion** added scheduled automations.
                - **Raycast** put AI commands in its free plan.

                I'll check our own launch date with Atlas before writing it up.
                """)),
            message(
                1103, minutesAgo(90), "agent",
                ["kind": "askedAgent", "agent": ["id": 1, "name": "Atlas"],
                 "question": "What launch date are we telling press?",
                 "reply": ["status": "answered", "text": "November 18, 9 AM Pacific. Embargo lifts at the same time."]],
                excerpt: "Asked Atlas: What launch date are we telling press?"),
            message(1104, minutesAgo(3), "user", text("Also compare their pricing pages to ours.")),
            message(
                1105, minutesAgo(2), "agent", ["kind": "documentation", "module": "documents"],
                excerpt: "Learning about documents"),
        ]
    }

    var quillMessages: [[String: Any]] {
        [
            message(
                1201, minutesAgo(50), "user",
                ["kind": "forward", "note": "Can you tighten this before Daniel sees it?",
                 "item": ["kind": "document", "workspace_id": 1, "id": 3, "title": "Pricing Notes"]],
                excerpt: "Can you tighten this before Daniel sees it?"),
            message(
                1202, minutesAgo(25), "agent",
                text("""
                Tightened. The big changes:

                1. Each plan now leads with **who it's for**, not a feature list.
                2. "Talk to us" became **Book a call**, which says what happens.
                3. Cut "seamless" twice.

                The edits are in [Pricing Notes](cohesion://document/1/3).
                """)),
        ]
    }

    var ledgerMessages: [[String: Any]] {
        [
            message(
                1301, hoursAgo(3), "backgroundAgent",
                ["kind": "woke", "by": ["kind": "cue", "cue_name": "Renewals", "hook": "day:start"]],
                run: 601, runDescription: "The day started", part: "trigger",
                excerpt: "Cue “Renewals” fired", verb: "Woke"),
            message(
                1302, hoursAgo(3) + 30, "backgroundAgent",
                ["kind": "proposal", "action": "Cancel the unused Figma Professional seat ($15/month)",
                 "justification": "Nobody has opened it since August, and it renews on the 14th.", "status": "pending"],
                run: 601, runDescription: "The day started", part: "surfaced",
                excerpt: "Cancel the unused Figma Professional seat ($15/month)"),
        ]
    }

    var relayMessages: [[String: Any]] {
        [
            message(
                1401, hoursAgo(9), "backgroundAgent",
                ["kind": "woke", "by": ["kind": "cue", "cue_name": "New issues", "hook": "resource:import"]],
                run: 701, runDescription: "“Crash when sharing a URL with no title” was imported", part: "trigger",
                excerpt: "Cue “New issues” fired", verb: "Woke"),
            message(
                1402, hoursAgo(9) + 20, "backgroundAgent",
                ["kind": "codeExecution", "title": "Labeling the issue",
                 "code": "await github.addLabels(\"cohesionhq/apple\", 214, [\"bug\", \"share-extension\"]);",
                 "outcome": ["status": "failed", "error": "GitHub answered 403: Resource not accessible by integration"]],
                run: 701, part: "step", excerpt: "Labeling the issue"),
            message(
                1403, hoursAgo(9) + 25, "backgroundAgent",
                ["kind": "error", "error": "The GitHub extension can't write labels. Grant it the issues scope and I'll try again."],
                run: 701, part: "surfaced",
                excerpt: "The GitHub extension can't write labels. Grant it the issues scope and I'll try again."),
        ]
    }

    var juniperMessages: [[String: Any]] {
        [
            message(1501, daysAgo(1) - 600, "user", text("What should we make for dinner Saturday? Grace is coming over.")),
            message(
                1502, daysAgo(1), "agent",
                ["kind": "choice", "question": "Pick a direction 🍽️",
                 "options": ["Fig and goat cheese tart", "Roast chicken with lemon", "Mushroom risotto"]],
                excerpt: "Pick a direction 🍽️"),
        ]
    }

    func cues(_ agentID: Int?) -> [[String: Any]] {
        switch agentID {
        case 1:
            [
                ["id": 1, "name": "Morning briefing", "hook": "day:start", "effort": "medium",
                 "script": "return true;",
                 "instructions": "Summarize what's due today and overdue in Studio, most pressing first, in three sentences or fewer."],
                ["id": 2, "name": "task:assigned", "hook": "task:assigned", "effort": "low",
                 "script": "return task.assignee?.kind === \"agent\" && task.assignee.agent_id === 1 ? task : null;",
                 "instructions": "Plan the task you were assigned and say when you'll have a first draft."],
                ["id": 3, "name": "Wrap-up", "hook": "day:end", "effort": "foreground",
                 "script": "return true;",
                 "instructions": "Recap what moved today and what's first tomorrow."],
            ]
        case 2:
            [["id": 4, "name": "New articles", "hook": "feed:article", "effort": "low",
              "script": "return article.title.match(/pricing|launch|agents/i) ? article : null;",
              "instructions": "Read it and tell me in one line if it matters for our launch."]]
        case 4:
            [["id": 5, "name": "Renewals", "hook": "day:start", "effort": "medium", "script": "return true;",
              "instructions": "Check subscriptions renewing in the next week and propose cancelling unused ones."]]
        case 5:
            [["id": 6, "name": "New issues", "hook": "resource:import", "effort": "high",
              "script": "return resource.kind === \"com.cohesion.github.issue\" ? resource : null;",
              "instructions": "Label the issue and link duplicates."]]
        default:
            []
        }
    }

    func run(
        _ id: Int, _ hook: String, _ cue: String?, started: Int, ended: Int? = nil, error: String? = nil,
        input: Int, cacheWrite: Int = 0, output: Int, cost: Double?
    ) -> [String: Any] {
        var state: [String: Any] = ["status": "running"]
        if let ended {
            state = error.map { ["status": "failed", "ended_at": ended, "error": $0] }
                ?? ["status": "completed", "ended_at": ended]
        }
        var json: [String: Any] = [
            "id": id, "hook": hook, "started_at": started, "state": state,
            "input_tokens": input, "cache_write_tokens": cacheWrite, "output_tokens": output,
        ]
        json["cue_name"] = cue
        json["cost"] = cost
        return json
    }

    /// Newest first.
    func runs(_ agentID: Int?) -> [[String: Any]] {
        switch agentID {
        case 1:
            [
                run(502, "agent:message", nil, started: minutesAgo(90), ended: minutesAgo(90) + 21,
                    input: 3_204, cacheWrite: 1_120, output: 188, cost: 0.0214),
                run(501, "day:start", "Morning briefing", started: hoursAgo(5), ended: hoursAgo(5) + 26,
                    input: 8_412, cacheWrite: 2_048, output: 412, cost: 0.0561),
                run(498, "day:end", "Wrap-up", started: on(-1, at: 23), ended: on(-1, at: 23) + 31,
                    input: 11_930, output: 655, cost: 0.0802),
                run(497, "task:assigned", "task:assigned", started: daysAgo(1) - 3600, ended: daysAgo(1) - 3590,
                    error: "The model provider answered 529: Overloaded.", input: 1_204, output: 0, cost: 0.0036),
                run(495, "day:start", "Morning briefing", started: on(-1, at: 6), ended: on(-1, at: 6) + 22,
                    input: 7_985, cacheWrite: 1_900, output: 380, cost: 0.0517),
                run(490, "day:start", "Morning briefing", started: on(-2, at: 6), ended: on(-2, at: 6) + 19,
                    input: 7_412, output: 351, cost: 0.0468),
            ]
        case 2:
            [
                run(610, "feed:article", "New articles", started: minutesAgo(1), input: 2_100, output: 0, cost: nil),
                run(605, "feed:article", "New articles", started: hoursAgo(2), ended: hoursAgo(2) + 9,
                    input: 2_884, output: 96, cost: 0.0031),
            ]
        case 4:
            [run(601, "day:start", "Renewals", started: hoursAgo(3), ended: hoursAgo(3) + 40,
                 input: 5_330, output: 290, cost: 0.0322)]
        case 5:
            [run(701, "resource:import", "New issues", started: hoursAgo(9), ended: hoursAgo(9) + 25,
                 error: "The script threw: GitHub answered 403.", input: 4_002, output: 210, cost: 0.0611)]
        default:
            []
        }
    }

    func memory(_ id: Int, _ scope: [String: Any], days: Double, _ text: String) -> [String: Any] {
        ["id": id, "scope": scope, "created_at": daysAgo(days), "memory": text]
    }

    /// Oldest first: the global ones, then the team's and the agent's.
    var allMemories: [[String: Any]] {
        let global: [String: Any] = ["kind": "global"]
        return [
            memory(1, global, days: 40, "Jackson works 9–6 Pacific; nothing gets scheduled before 9."),
            memory(2, global, days: 31, "The company is Cohesion; the product launches on November 18."),
            memory(3, global, days: 22, "Prefers concise answers that lead with the decision."),
            memory(4, ["kind": "team", "team_id": 1], days: 20, "Cite sources with links when summarizing articles."),
            memory(5, ["kind": "team", "team_id": 1], days: 14, "Competitors to track: Linear, Notion and Raycast."),
            memory(6, ["kind": "team", "team_id": 2], days: 12, "Invoices go to Tom Becker by the 5th of each month."),
            memory(7, ["kind": "agent", "agent_id": 1], days: 9, "Weekly review is Fridays at 4 PM."),
            memory(8, ["kind": "agent", "agent_id": 4], days: 6, "The Figma plan renews on the 14th."),
            memory(9, ["kind": "agent", "agent_id": 2], days: 3, "Jackson reads the morning digest on his phone; keep it under 120 words."),
            memory(10, ["kind": "agent", "agent_id": 1], days: 0.08, "Maya Chen prefers press assets as a single zip with a README."),
        ]
    }

    /// What `agentID` sees: its own, its team's and the global ones; only
    /// the global ones for `nil`.
    func memories(of agentID: Int?) -> [[String: Any]] {
        let team = agents.first { ($0["id"] as? Int) == agentID }?["team_id"] as? Int
        return allMemories.filter { memory in
            guard let scope = memory["scope"] as? [String: Any] else { return false }
            switch scope["kind"] as? String {
            case "global": return true
            case "team": return team != nil && scope["team_id"] as? Int == team
            case "agent": return agentID != nil && scope["agent_id"] as? Int == agentID
            default: return false
            }
        }
    }

    // MARK: Actors and clients

    var clients: [[String: Any]] {
        [
            ["id": 1, "client_name": "Jackson’s MacBook Pro", "online": true],
            ["id": 2, "client_name": "Jackson’s iPhone", "online": true],
            ["id": 3, "client_name": "Build Server", "online": true],
            ["id": 4, "client_name": "Studio iMac", "online": false],
        ]
    }

    var claudeModes: [[String: Any]] {
        [
            ["identifier": "default", "title": "Ask First", "description": "Asks before each edit and command."],
            ["identifier": "acceptEdits", "title": "Accept Edits", "description": "Edits files without asking; still asks before commands."],
            ["identifier": "plan", "title": "Plan", "description": "Plans first, and changes nothing until you approve."],
            ["identifier": "bypassPermissions", "title": "Bypass Permissions", "description": "Does anything without asking."],
        ]
    }

    var claudeModels: [[String: Any]] {
        let efforts: [[String: Any]] = [
            ["identifier": "low", "title": "Low"],
            ["identifier": "medium", "title": "Medium"],
            ["identifier": "high", "title": "High"],
        ]
        return [
            ["identifier": "opus", "title": "Opus", "efforts": efforts],
            ["identifier": "sonnet", "title": "Sonnet", "efforts": efforts],
            ["identifier": "haiku", "title": "Haiku", "efforts": [[String: Any]]()],
        ]
    }

    var actors: [[String: Any]] {
        [
            ["id": 1, "client_id": 1, "product": "Claude Code", "scope": "/Users/jackson/Developer/apple",
             "title": "Claude Code on Jackson’s MacBook Pro", "modes": claudeModes, "models": claudeModels],
            ["id": 2, "client_id": 1, "product": "Claude Code", "scope": "/Users/jackson/Developer/cohesion",
             "title": "Claude Code on Jackson’s MacBook Pro", "modes": claudeModes, "models": claudeModels],
            ["id": 3, "client_id": 3, "product": "Codex", "scope": "/srv/cloud",
             "title": "Codex on Build Server",
             "modes": [
                ["identifier": "auto", "title": "Auto", "description": "Edits and runs commands in the workspace; asks to go further."],
                ["identifier": "read-only", "title": "Read Only", "description": "Reads and answers; changes nothing."],
                ["identifier": "full-access", "title": "Full Access", "description": "Edits and runs anything, network too."],
             ],
             "models": [
                ["identifier": "gpt-5-codex", "title": "GPT-5 Codex", "efforts": [
                    ["identifier": "low", "title": "Low"], ["identifier": "medium", "title": "Medium"],
                    ["identifier": "high", "title": "High"],
                ]],
             ]],
            ["id": 4, "client_id": 4, "product": "Claude Code", "scope": "/Users/jackson/Sites/hellocohesion.com",
             "title": "Claude Code on Studio iMac", "modes": claudeModes, "models": claudeModels],
        ]
    }

    var actorUsage: [[String: Any]] {
        [
            ["actor_ids": [1, 2, 4],
             "pool": ["id": "anthropic:acct_7f3a91", "name": "jackson@example.com"],
             "plan": [
                ["label": "5-hour limit", "used": 0.42, "resets_at": fromNow(hours: 2.2)],
                ["label": "Weekly limit", "used": 0.67, "resets_at": fromNow(days: 3)],
                ["label": "Weekly Opus limit", "used": 0.86, "resets_at": fromNow(days: 3)],
             ]],
            ["actor_ids": [3],
             "plan": [
                ["label": "5-hour limit", "used": 0.12, "resets_at": fromNow(hours: 4.5)],
                ["label": "Weekly limit", "used": 0.31, "resets_at": fromNow(days: 5)],
             ]],
        ]
    }

    func session(
        _ id: Int, actor: Int, _ title: String, _ status: String, changed: Int, unread: Bool,
        read: Int? = nil, mode: String? = nil, model: String? = nil, effort: String? = nil,
        context: (Int, Int)? = nil
    ) -> [String: Any] {
        var json: [String: Any] = [
            "id": id, "actor_id": actor, "title": title, "status": status,
            "status_changed_at": changed, "unread": unread,
        ]
        json["read_at"] = read
        json["mode"] = mode
        json["model"] = model
        json["effort"] = effort
        json["context"] = context.map { ["used_tokens": $0.0, "total_tokens": $0.1] }
        return json
    }

    /// Latest status change first.
    var actorSessions: [[String: Any]] {
        [
            session(
                2, actor: 1, "Polish the iPad sidebar spacing", "working", changed: secondsAgo(30), unread: false,
                read: minutesAgo(6), model: "sonnet", context: (41_200, 200_000)),
            session(
                1, actor: 1, "Add backoff to the change socket's reconnect", "needsAttention",
                changed: minutesAgo(2), unread: false, read: minutesAgo(9), mode: "acceptEdits", model: "opus",
                effort: "high", context: (84_350, 200_000)),
            session(
                3, actor: 3, "Bump the companion to v9 and run the push tests", "idle", changed: minutesAgo(18),
                unread: true, read: hoursAgo(1), mode: "auto", context: (63_900, 272_000)),
            session(
                4, actor: 2, "Move the feed fetcher to the new HTTP client", "failed", changed: hoursAgo(1),
                unread: true, read: hoursAgo(2), model: "sonnet", context: (120_480, 200_000)),
            session(
                5, actor: 4, "Write the November changelog post", "idle", changed: daysAgo(1), unread: false,
                read: daysAgo(1) + 600, mode: "plan", context: (22_015, 200_000)),
        ]
    }

    func said(_ id: Int, _ sentAt: Int, _ content: [String: Any], answered: Bool = false, attachments: Int = 0) -> [String: Any] {
        ["id": id, "sent_at": sentAt, "content": content, "answered": answered, "attachment_count": attachments]
    }

    func actorText(_ text: String) -> [String: Any] { ["sender": "actor", "kind": "text", "text": text] }
    func userText(_ text: String) -> [String: Any] { ["sender": "user", "kind": "text", "text": text] }

    func tool(_ tool: String, _ summary: String, ended: Int?) -> [String: Any] {
        var json: [String: Any] = ["sender": "actor", "kind": "toolUse", "tool": tool, "summary": summary]
        json["ended_at"] = ended
        return json
    }

    func actorSessionMessages(_ sessionID: Int?) -> [[String: Any]] {
        switch sessionID {
        case 1: backoffTranscript
        case 2:
            [
                said(2101, minutesAgo(8), userText("The section headers sit too close to the first row on iPad in compact width. Here's what it looks like."), attachments: 1),
                said(2102, minutesAgo(8) + 5, actorText("Looking at the sidebar's list style and its section headers.")),
                said(2103, minutesAgo(8) + 9, tool("Read", "Cohesion/Views/Sidebar.swift", ended: minutesAgo(8) + 10)),
                said(2104, minutesAgo(8) + 12, tool("Grep", "\"listSectionSpacing\" in Cohesion/", ended: minutesAgo(8) + 13)),
                said(2105, minutesAgo(7), actorText("The compact layout drops the `.listSectionSpacing(.compact)` the regular one sets. Adding it there, then checking the header's top padding.")),
                said(2106, secondsAgo(30), tool("Edit", "Cohesion/Views/Sidebar.swift", ended: nil)),
            ]
        case 3:
            [
                said(2201, minutesAgo(40), userText("Bump the companion to v9 and run the push tests.")),
                said(2202, minutesAgo(40) + 20, tool("Edit", "companion/manifest.json", ended: minutesAgo(40) + 22)),
                said(2203, minutesAgo(39), tool("Bash", "npm test -- push", ended: minutesAgo(20))),
                said(2204, minutesAgo(18), actorText("""
                Bumped the companion to **v9**. All 48 push tests pass.

                - `registerDevice` now takes the phone's token itself
                - Removed the old cloud registration path
                """)),
            ]
        case 4:
            [
                said(2301, hoursAgo(1.5), userText("Move the feed fetcher to the new HTTP client.")),
                said(2302, hoursAgo(1.5) + 30, tool("Read", "cohesion-internet/src/feeds.rs", ended: hoursAgo(1.5) + 31)),
                said(2303, hoursAgo(1.5) + 60, tool("Edit", "cohesion-internet/src/feeds.rs", ended: hoursAgo(1.5) + 62)),
                said(2304, hoursAgo(1.2), tool("Bash", "cargo test -p cohesion-internet", ended: hoursAgo(1) - 30)),
                said(2305, hoursAgo(1), actorText("""
                The tests fail on redirects: the new client doesn't follow them by default.

                ```
                test feeds::follows_redirects ... FAILED
                expected 200, got 301
                ```

                I stopped here so you can decide whether redirects should be followed for every request or only feeds.
                """)),
            ]
        case 5:
            [
                said(2401, daysAgo(1) - 1800, userText("Write the November changelog post from the merged PRs.")),
                said(2402, daysAgo(1) - 1500, ["sender": "actor", "kind": "plan", "plan": """
                1. List the PRs merged since October 15
                2. Group them: **New**, **Better**, **Fixed**
                3. Draft `content/changelog/2026-11.md` in the house voice
                """], answered: true),
                said(2403, daysAgo(1) - 1400, ["sender": "user", "kind": "plan", "request_id": 2402, "approved": true]),
                said(2404, daysAgo(1) - 1300, tool("Bash", "gh pr list --state merged --limit 60", ended: daysAgo(1) - 1290)),
                said(2405, daysAgo(1) - 900, tool("Write", "content/changelog/2026-11.md", ended: daysAgo(1) - 890)),
                said(2406, daysAgo(1), actorText("The post is in `content/changelog/2026-11.md`: 6 new, 9 better, 14 fixed.")),
            ]
        default:
            []
        }
    }

    /// Session 1: a question answered, a file change allowed, tools with
    /// timings, and a command waiting on the user.
    var backoffTranscript: [[String: Any]] {
        let start = minutesAgo(40)
        return [
            said(2001, start, userText("""
            The change socket gives up after a few failed reconnects. Add exponential backoff with jitter, cap it at 30 seconds, and make sure returning to the foreground reconnects at once.
            """)),
            said(2002, start + 6, actorText("I'll start by reading how the socket reconnects today.")),
            said(2003, start + 8, tool("Read", "Packages/CohesionCore/Sources/CohesionCore/Connection/Changes.swift", ended: start + 9)),
            said(2004, start + 10, tool("Grep", "\"reconnect\" in Packages/", ended: start + 11)),
            said(2005, start + 40, actorText("""
            ## What I found

            `ChangeSocket` retries **three times** with a fixed 2-second delay, then stops for good:

            - `reconnect()` is called from the receive loop's `catch`
            - nothing resets the attempt count once a connection succeeds
            - a return to the foreground waits out whatever delay is pending

            Two questions before I change it.
            """)),
            said(2006, start + 45, ["sender": "actor", "kind": "question", "questions": [
                ["header": "Backoff cap", "question": "How long should the longest wait between reconnects be?",
                 "options": [
                    ["label": "30 seconds", "description": "What you asked for; quick to recover on Wi-Fi."],
                    ["label": "60 seconds", "description": "Easier on the battery when the server is down for a while."],
                 ],
                 "multi_select": false, "allows_other": true],
                ["header": "Foreground", "question": "Should returning to the foreground skip the pending wait?",
                 "options": [
                    ["label": "Yes", "description": "Reconnect at once."],
                    ["label": "No", "description": "Keep the backoff going."],
                 ],
                 "multi_select": false, "allows_other": false],
            ] as [[String: Any]]], answered: true),
            said(2007, start + 120, ["sender": "user", "kind": "answers", "request_id": 2006, "answers": [
                ["selected": ["30 seconds"]], ["selected": ["Yes"]],
            ]]),
            said(2008, start + 140, ["sender": "actor", "kind": "permission",
                "subject": ["kind": "fileChange", "changes": [
                    ["path": "Packages/CohesionCore/Sources/CohesionCore/Connection/Changes.swift", "change": "update",
                     "diff": """
                     @@ -88,7 +88,9 @@
                     -    private let retryLimit = 3
                     -    private let retryDelay: Duration = .seconds(2)
                     +    /// The wait before reconnect attempt `n`: doubling from a second,
                     +    /// capped at 30, give or take a fifth.
                     +    static func delay(attempt: Int) -> Duration {
                     +        .seconds(min(30, pow(2, Double(attempt))) * .random(in: 0.8...1.2))
                     +    }
                     """],
                    ["path": "Packages/CohesionCore/Tests/CohesionCoreTests/BackoffTests.swift", "change": "add"],
                ] as [[String: Any]]],
                "reason": "Replaces the fixed retry with a capped, jittered backoff.",
                "decisions": ["allow", "allowForSession", "deny", "abort"]], answered: true),
            said(2009, start + 170, ["sender": "user", "kind": "permission", "request_id": 2008, "decision": "allowForSession"]),
            said(2010, start + 175, tool("Edit", "Connection/Changes.swift", ended: start + 177)),
            said(2011, start + 180, tool("Edit", "Connection/CohesionClient.swift", ended: start + 181)),
            said(2012, start + 190, tool("Write", "Tests/CohesionCoreTests/BackoffTests.swift", ended: start + 192)),
            said(2013, start + 260, actorText("""
            The delay now doubles from a second up to the cap, with jitter so a room of phones doesn't reconnect in step:

            ```swift
            static func delay(attempt: Int) -> Duration {
                .seconds(min(30, pow(2, Double(attempt))) * .random(in: 0.8...1.2))
            }
            ```

            `scenePhase` becoming `.active` cancels the pending wait and reconnects at once.
            """)),
            said(2014, start + 270, tool("Bash", "swift test --filter BackoffTests", ended: start + 311)),
            said(2015, minutesAgo(2) - 20, actorText("All **6** tests pass. Next I'd like to build the app to check nothing else used the old `retryLimit`.")),
            said(2016, minutesAgo(2), ["sender": "actor", "kind": "permission",
                "subject": ["kind": "command",
                            "command": "xcodebuild -scheme Cohesion -destination 'generic/platform=iOS Simulator' build",
                            "cwd": "/Users/jackson/Developer/apple"],
                "reason": "Builds the app to check nothing else used the removed retryLimit.",
                "decisions": ["allow", "allowForSession", "deny", "abort"]]),
        ]
    }

    // MARK: Models

    var endpoints: [[String: Any]] {
        [
            ["id": 1, "name": "Anthropic", "backend": [
                "kind": "integrated", "provider_identifier": "anthropic",
                "usage_url": "https://console.anthropic.com/usage",
            ]],
            ["id": 2, "name": "OpenAI", "backend": [
                "kind": "integrated", "provider_identifier": "openai",
                "usage_url": "https://platform.openai.com/usage",
            ]],
            ["id": 3, "name": "ChatGPT", "backend": [
                "kind": "account", "provider_identifier": "openai", "account_id": 5,
            ]],
            ["id": 4, "name": "Studio Ollama", "backend": [
                "kind": "integrated", "provider_identifier": "ollama",
            ]],
        ]
    }

    var endpointModels: [[String: Any]] {
        [
            ["id": 1, "endpoint_id": 1, "model_identifier": "claude-opus-4-5", "model_name": "Claude Opus 4.5"],
            ["id": 2, "endpoint_id": 1, "model_identifier": "claude-sonnet-4-5", "model_name": "Claude Sonnet 4.5"],
            ["id": 3, "endpoint_id": 1, "model_identifier": "claude-haiku-4-5", "model_name": "Claude Haiku 4.5"],
            ["id": 4, "endpoint_id": 2, "model_identifier": "gpt-5", "model_name": "GPT-5"],
            ["id": 5, "endpoint_id": 2, "model_identifier": "gpt-5-mini", "model_name": "GPT-5 mini"],
            ["id": 6, "endpoint_id": 3, "model_identifier": "gpt-5-codex", "model_name": "GPT-5 Codex"],
            ["id": 7, "endpoint_id": 4, "model_identifier": "llama3.3:70b", "model_name": "llama3.3:70b"],
        ]
    }

    func catalogModel(
        _ id: Int, _ provider: String, _ providerName: String, _ identifier: String, _ name: String,
        context: Int?, input: Double?, output: Double?, cacheRead: Double? = nil, cacheWrite: Double? = nil
    ) -> [String: Any] {
        var json: [String: Any] = [
            "id": id, "provider_identifier": provider, "provider_name": providerName,
            "model_identifier": identifier, "model_name": name,
        ]
        json["context_size"] = context
        json["input_token_cost"] = input
        json["output_token_cost"] = output
        json["cache_read_token_cost"] = cacheRead
        json["cache_write_token_cost"] = cacheWrite
        return json
    }

    var catalog: [[String: Any]] {
        [
            catalogModel(1, "anthropic", "Anthropic", "claude-opus-4-5", "Claude Opus 4.5",
                         context: 200_000, input: 5, output: 25, cacheRead: 0.5, cacheWrite: 6.25),
            catalogModel(2, "anthropic", "Anthropic", "claude-sonnet-4-5", "Claude Sonnet 4.5",
                         context: 200_000, input: 3, output: 15, cacheRead: 0.3, cacheWrite: 3.75),
            catalogModel(3, "anthropic", "Anthropic", "claude-haiku-4-5", "Claude Haiku 4.5",
                         context: 200_000, input: 1, output: 5, cacheRead: 0.1, cacheWrite: 1.25),
            catalogModel(4, "anthropic", "Anthropic", "claude-opus-4-1", "Claude Opus 4.1",
                         context: 200_000, input: 15, output: 75, cacheRead: 1.5, cacheWrite: 18.75),
            catalogModel(5, "openai", "OpenAI", "gpt-5", "GPT-5",
                         context: 400_000, input: 1.25, output: 10, cacheRead: 0.125),
            catalogModel(6, "openai", "OpenAI", "gpt-5-mini", "GPT-5 mini",
                         context: 400_000, input: 0.25, output: 2, cacheRead: 0.025),
            catalogModel(7, "openai", "OpenAI", "gpt-5-nano", "GPT-5 nano",
                         context: 400_000, input: 0.05, output: 0.4, cacheRead: 0.005),
            catalogModel(8, "openai", "OpenAI", "gpt-5-codex", "GPT-5 Codex",
                         context: 400_000, input: 1.25, output: 10, cacheRead: 0.125),
            catalogModel(9, "ollama", "Ollama", "llama3.3:70b", "Llama 3.3 70B",
                         context: 128_000, input: nil, output: nil),
        ]
    }

    // MARK: Connectors

    var github: [String: Any] {
        [
            "id": 1, "identifier": "com.cohesion.github", "title": "GitHub", "icon": PreviewData.icon("G", "#24292f"),
            "kinds": [
                ["id": 1, "identifier": "issue", "title": "Issue", "plural": "Issues"],
                ["id": 2, "identifier": "pull", "title": "Pull Request", "plural": "Pull Requests"],
            ],
            "metadata_keys": ["dateCreated", "dateModified", "author", "url", "status"],
        ]
    }

    var linear: [String: Any] {
        [
            "id": 2, "identifier": "com.cohesion.linear", "title": "Linear", "icon": PreviewData.icon("L", "#5e6ad2"),
            "kinds": [
                ["id": 3, "identifier": "issue", "title": "Issue", "plural": "Issues"],
                ["id": 4, "identifier": "project", "title": "Project", "plural": "Projects"],
            ],
            "metadata_keys": ["dateCreated", "dateModified", "dateDue", "status", "author"],
        ]
    }

    var notes: [String: Any] {
        [
            "id": 3, "identifier": "com.apple.notes", "title": "Notes", "icon": PreviewData.icon("N", "#e8b400"),
            "kinds": [["id": 5, "identifier": "note", "title": "Note", "plural": "Notes"]],
            "metadata_keys": ["dateCreated", "dateModified", "folder"],
        ]
    }

    var calendar: [String: Any] {
        [
            "id": 4, "identifier": "com.google.calendar", "title": "Google Calendar",
            "kinds": [["id": 6, "identifier": "event", "title": "Event", "plural": "Events"]],
            "metadata_keys": ["dateStart", "dateEnd", "location"],
        ]
    }

    var connectorAccounts: [[String: Any]] {
        [
            ["id": 3, "host": ["kind": "client", "client_id": 1], "connector": notes,
             "description": "Jackson’s MacBook Pro", "importable": true],
            ["id": 4, "host": ["kind": "orphaned"], "connector": calendar,
             "description": "jackson@example.com", "importable": false],
            ["id": 2, "host": ["kind": "extension"], "connector": linear,
             "description": "Cohesion (hellocohesion)", "importable": true],
            ["id": 1, "host": ["kind": "extension"], "connector": github,
             "description": "jacksonzamorano", "importable": true],
        ]
    }

    func resource(_ id: Int, account: Int, kind: Int, _ title: String, updated: Int, _ contents: String) -> [String: Any] {
        [
            "id": id, "account_id": account, "kind_id": kind, "title": title, "content_kind": "markdown",
            "contents": contents, "last_updated": updated,
        ]
    }

    var resources: [[String: Any]] {
        [
            resource(1, account: 1, kind: 1, "Crash when sharing a URL with no title", updated: hoursAgo(9), """
            # Crash when sharing a URL with no title
            **cohesionhq/apple#214** · opened by `mrivera` · **Open**

            Sharing a link from Safari's reading list crashes the share extension.

            ```
            Fatal error: Unexpectedly found nil while unwrapping an Optional value
            ShareToAgentView.swift:118
            ```

            **Labels:** bug, share-extension
            """),
            resource(2, account: 1, kind: 1, "Widgets show stale tasks after midnight", updated: daysAgo(2), """
            # Widgets show stale tasks after midnight
            **cohesionhq/apple#209** · **Open**

            The Tasks widget's *Today* list keeps yesterday's tasks until the app opens.
            """),
            resource(3, account: 1, kind: 1, "Support Markdown tables in the journal", updated: daysAgo(5), """
            # Support Markdown tables in the journal
            **cohesionhq/cohesion#1180** · **Closed**

            Tables render in documents but show as plain text in journal entries.
            """),
            resource(4, account: 1, kind: 1, "Actor sessions list flickers on reconnect", updated: daysAgo(8), """
            # Actor sessions list flickers on reconnect
            **cohesionhq/apple#198** · **Open**

            Every reconnect empties the list for a frame before the reply arrives.
            """),
            resource(5, account: 1, kind: 1, "Add Linear as a connector", updated: daysAgo(30), """
            # Add Linear as a connector
            **cohesionhq/cohesion#1102** · **Closed**
            """),
            resource(10, account: 1, kind: 2, "Backoff with jitter for the change socket", updated: minutesAgo(15), """
            # Backoff with jitter for the change socket
            **cohesionhq/apple#216** · **Draft**

            Replaces the fixed three retries with a capped, jittered backoff.
            """),
            resource(11, account: 1, kind: 2, "Companion v9: register devices directly", updated: hoursAgo(20), """
            # Companion v9: register devices directly
            **cohesionhq/cloud#88** · **Merged**
            """),
            resource(12, account: 1, kind: 2, "iPad sidebar spacing", updated: daysAgo(3), """
            # iPad sidebar spacing
            **cohesionhq/apple#211** · **Open** · 2 approvals
            """),
            resource(6, account: 2, kind: 3, "COH-412 SSO for Kessler & Roth", updated: hoursAgo(6), """
            # COH-412 SSO for Kessler & Roth
            **In Progress** · Due \(day(5)) · Assignee: Jackson

            SAML with Okta. Lena Fischer is the contact.

            - [x] Metadata exchanged
            - [ ] Test tenant
            - [ ] Rollout plan
            """),
            resource(7, account: 2, kind: 3, "COH-398 Rate-limit the public share links", updated: daysAgo(1), """
            # COH-398 Rate-limit the public share links
            **Todo** · Priority: High
            """),
            resource(8, account: 2, kind: 3, "COH-371 Onboarding checklist on the Dashboard", updated: daysAgo(4), """
            # COH-371 Onboarding checklist on the Dashboard
            **Backlog**
            """),
            resource(9, account: 2, kind: 3, "COH-355 Export a workspace as Markdown", updated: 0, """
            # COH-355 Export a workspace as Markdown
            **Done**
            """),
            resource(13, account: 3, kind: 5, "Garden plan", updated: daysAgo(3), "Tomatoes along the south fence, basil between them, figs in pots."),
            resource(14, account: 3, kind: 5, "Gift ideas", updated: daysAgo(12), "- Grace: a good bread knife\n- Mom: the photo book from Lisbon"),
        ]
    }

    /// The kind ids by their names, `connector.kind`.
    var kindIDs: [String: Int] {
        [
            "com.cohesion.github.issue": 1, "com.cohesion.github.pull": 2,
            "com.cohesion.linear.issue": 3, "com.cohesion.linear.project": 4,
            "com.apple.notes.note": 5, "com.google.calendar.event": 6,
        ]
    }

    func resourceList(_ args: [String: Any]) -> [[String: Any]] {
        guard let kind = (args["kind"] as? String).flatMap({ kindIDs[$0] }) else { return [] }
        let workspace = args["workspace_id"] as? Int
        var matching = resources.filter { resource in
            let id = resource["kind_id"] as? Int
            return id == kind && (workspace == 2 ? id == 5 : id != 5)
        }
        let descending = args["descending"] as? Bool ?? false
        if args["sort"] as? String == "title" {
            matching.sort {
                let order = ($0["title"] as? String ?? "") < ($1["title"] as? String ?? "")
                return descending ? !order : order
            }
        } else {
            // By when each last changed; those that don't say last.
            matching.sort {
                let (a, b) = ($0["last_updated"] as? Int ?? 0, $1["last_updated"] as? Int ?? 0)
                if a == 0 || b == 0 { return b == 0 && a != 0 }
                return descending ? a > b : a < b
            }
        }
        return matching
    }

    func organizationUnits(_ accountID: Int?) -> [[String: Any]] {
        switch accountID {
        case 1:
            [
                ["id": "cohesionhq/apple", "display": "cohesionhq/apple"],
                ["id": "cohesionhq/cohesion", "display": "cohesionhq/cohesion"],
                ["id": "cohesionhq/cloud", "display": "cohesionhq/cloud"],
            ]
        case 2:
            [["id": "team-coh", "display": "Cohesion"], ["id": "team-web", "display": "Website"]]
        case 3:
            [["id": "folder-notes", "display": "Notes"], ["id": "folder-home", "display": "Home"]]
        default:
            []
        }
    }

    func importable(_ args: [String: Any]) -> [[String: Any]] {
        let kind = args["kind_id"] as? Int
        let all: [(Int, String, String, Double?, Bool)] = [
            (1, "cohesionhq/apple#214", "Crash when sharing a URL with no title", 9, true),
            (1, "cohesionhq/apple#209", "Widgets show stale tasks after midnight", 48, true),
            (1, "cohesionhq/apple#215", "VoiceOver reads the agent's emoji twice", 3, false),
            (1, "cohesionhq/apple#213", "Mac: Settings window opens behind the main one", 30, false),
            (1, "cohesionhq/cohesion#1190", "Journal search skips entries older than a year", 72, false),
            (2, "cohesionhq/apple#216", "Backoff with jitter for the change socket", 0.25, true),
            (2, "cohesionhq/apple#217", "Share extension: handle pages with no title", 1, false),
            (3, "COH-412", "COH-412 SSO for Kessler & Roth", 6, true),
            (3, "COH-420", "COH-420 Weekly digest email", 20, false),
            (3, "COH-418", "COH-418 Pin agents on the Mac sidebar", nil, false),
            (4, "proj-launch", "November launch", 2, false),
            (5, "note-garden", "Garden plan", 72, true),
            (5, "note-lisbon", "Lisbon offsite ideas", 100, false),
        ]
        let search = (args["search"] as? String)?.lowercased()
        return all
            .filter { item in item.0 == kind && (search.map { item.2.lowercased().contains($0) } ?? true) }
            .map { item in
                var json: [String: Any] = ["identifier": item.1, "title": item.2, "imported": item.4]
                json["last_updated"] = item.3.map { secondsAgo($0 * 3600) }
                return json
            }
    }

    // MARK: Extensions

    var extensions: [[String: Any]] {
        [
            ["id": 1, "name": "iOS Companion", "version": 9, "script_identifier": "com.hellocohesion.ios-companion",
             "description": "Sends pushes and Live Activities to your iPhone through Cohesion Cloud.",
             "author": "Cohesion", "icon": PreviewData.icon("C", "#007aff"), "priority": 0],
            ["id": 2, "name": "GitHub", "version": 4, "script_identifier": "com.cohesion.github",
             "description": "Imports issues and pull requests from your repositories.",
             "author": "Cohesion", "icon": PreviewData.icon("G", "#24292f"), "priority": 10],
            ["id": 3, "name": "Linear", "version": 3, "script_identifier": "com.cohesion.linear",
             "description": "Imports Linear issues and projects.",
             "author": "Cohesion", "icon": PreviewData.icon("L", "#5e6ad2"), "priority": 10],
            ["id": 4, "name": "Done Stamp", "version": 1, "script_identifier": "com.example.done-stamp",
             "description": "Adds the date to a task's description when it's completed.",
             "author": "Sam Rivera", "priority": 20],
            ["id": 5, "name": "Cohesion Registry", "version": 2, "script_identifier": "com.hellocohesion.registry",
             "description": "Lists the extensions Cohesion publishes, to browse and install.",
             "author": "Cohesion", "icon": PreviewData.icon("R", "#34c759"), "priority": 30],
        ]
    }

    /// Each extension's permissions and hooks, and whether each is on.
    /// Done Stamp has every one off, waiting on the user.
    var extensionGrants: [Int: (permissions: [(String, Bool)], hooks: [(String, Bool)])] {
        [
            1: (
                [("cohesion:read", true), ("network", true), ("service:isolated", true),
                 ("notifications", true), ("actors", true)],
                [("notification:send", true), ("actor:moved", true), ("activity:started", true),
                 ("activity:updated", true), ("activity:ended", true), ("client:revoke", true)]),
            2: (
                [("network", true), ("oauth", true), ("connector", true), ("timer", false)],
                [("launch", true)]),
            3: ([("network", true), ("oauth", true), ("connector", true)], []),
            4: ([("cohesion:read", false), ("cohesion:write", false)], [("task:status", false)]),
            5: ([("network", true), ("registry", true)], [("timer", false)]),
        ]
    }

    func extensionPermissions(_ id: Int?) -> [[String: Any]] {
        guard let id, let grants = extensionGrants[id] else { return [] }
        return grants.permissions.enumerated().map { index, grant in
            ["id": id * 100 + index, "permission": grant.0, "enabled": grant.1]
        }
    }

    func extensionHooks(_ id: Int?) -> [[String: Any]] {
        guard let id, let grants = extensionGrants[id] else { return [] }
        return grants.hooks.enumerated().map { index, grant in
            ["id": id * 100 + index, "hook": grant.0, "enabled": grant.1]
        }
    }

    var registryResults: [[String: Any]] {
        [
            registryResult(
                "com.hellocohesion.daily-digest", "Daily Digest", 3,
                "Emails you the day's finished tasks and journal at 6 PM.", icon: PreviewData.icon("D", "#ff9500"),
                permissions: ["cohesion:read", "network", "timer"], hooks: ["day:end"]),
            registryResult(
                "com.hellocohesion.calendar", "Calendar Sync", 5,
                "Shows tasks with due dates on your calendar, and events as tasks.", icon: PreviewData.icon("C", "#ff3b30"),
                permissions: ["cohesion:read", "cohesion:write", "network", "oauth", "connector"],
                hooks: ["task:duedate", "task:delete"]),
            registryResult(
                "com.hellocohesion.readwise", "Readwise Import", 2,
                "Brings your Readwise highlights in as documents.", icon: PreviewData.icon("R", "#1c1c1e"),
                permissions: ["cohesion:write", "network", "timer"], hooks: []),
            registryResult(
                "com.cohesion.github", "GitHub", 5,
                "Imports issues and pull requests from your repositories.", icon: PreviewData.icon("G", "#24292f"),
                permissions: ["network", "oauth", "connector", "timer"], hooks: ["launch"]),
            registryResult(
                "com.hellocohesion.slack", "Slack Notifier", 1,
                "Posts to a Slack channel when an actor session needs you.", icon: PreviewData.icon("S", "#4a154b"),
                permissions: ["network", "actors", "notifications"], hooks: ["actor:moved", "notification:send"]),
        ]
    }

    func manifest(
        _ identifier: String, _ name: String, _ version: Int, _ description: String, icon: String?,
        author: String = "Cohesion", permissions: [String], hooks: [String]
    ) -> [String: Any] {
        var json: [String: Any] = [
            "identifier": identifier, "name": name, "version": version, "description": description,
            "author": author, "permissions": permissions, "hooks": hooks,
        ]
        json["icon"] = icon
        return json
    }

    func registryResult(
        _ identifier: String, _ name: String, _ version: Int, _ description: String, icon: String?,
        permissions: [String], hooks: [String]
    ) -> [String: Any] {
        [
            "manifest": manifest(identifier, name, version, description, icon: icon, permissions: permissions, hooks: hooks),
            "source_url": "https://registry.hellocohesion.com/extensions/\(identifier).js",
        ]
    }

    func registrySearch(_ query: String) -> [[String: Any]] {
        let query = query.lowercased()
        let results = registryResults.filter { result in
            guard !query.isEmpty else { return true }
            let manifest = result["manifest"] as? [String: Any] ?? [:]
            return [manifest["name"], manifest["description"]]
                .compactMap { $0 as? String }
                .contains { $0.lowercased().contains(query) }
        }
        return [
            ["extension_id": 5, "name": "Cohesion Registry", "results": results],
        ]
    }

    func extensionPreview(sourceURL: String?) -> [String: Any]? {
        guard let result = registryResults.first(where: { ($0["source_url"] as? String) == sourceURL }) ?? registryResults.first,
              let manifest = result["manifest"] as? [String: Any]
        else { return nil }
        let identifier = manifest["identifier"] as? String
        var json: [String: Any] = ["script": script(for: manifest), "manifest": manifest]
        json["installed"] = extensions.first { ($0["script_identifier"] as? String) == identifier }
        return json
    }

    func extensionPreview(script: String?) -> [String: Any] {
        let manifest = manifest(
            "com.example.done-stamp", "Done Stamp", 2,
            "Adds the date to a task's description when it's completed.", icon: nil, author: "Sam Rivera",
            permissions: ["cohesion:read", "cohesion:write"], hooks: ["task:status"])
        return [
            "script": script ?? self.script(for: manifest), "manifest": manifest,
            "installed": extensions[3],
        ]
    }

    func script(for manifest: [String: Any]) -> String {
        let name = manifest["name"] as? String ?? "Extension"
        return """
        export const manifest = {
          identifier: "\(manifest["identifier"] as? String ?? "")",
          name: "\(name)",
          version: \(manifest["version"] as? Int ?? 1),
          permissions: \((manifest["permissions"] as? [String] ?? []).map { "\"\($0)\"" }.joined(separator: ", ").wrapped),
          hooks: \((manifest["hooks"] as? [String] ?? []).map { "\"\($0)\"" }.joined(separator: ", ").wrapped),
        };

        export async function onTaskStatus(task) {
          if (task.status !== "completed") return;
          const stamp = new Date().toISOString().slice(0, 10);
          await cohesion.tasks.editDescription(task.id, `${task.description}\\n\\nDone ${stamp}`);
        }
        """
    }
}

nonisolated private extension String {
    /// The string in brackets, as a JavaScript array literal.
    var wrapped: String { "[\(self)]" }
}

// MARK: - Vocabulary

/// The words cohesiond's hello sends, as its `Vocabulary::new` words them.
nonisolated private enum VocabularyWords {
    static var json: [String: Any] {
        [
            "permissions": permissions.map { ["kind": $0.0, "title": $0.1, "description": $0.2] },
            "hooks": hooks.map { kind, clause in
                [
                    "kind": kind,
                    "extension_clause": kind == "launch" ? "Cohesion starts, or this extension is updated" : clause,
                    "cue_clause": kind == "agent:message" ? "a message appears in another agent’s conversation"
                        : kind == "agent:reaction" ? "someone reacts to a message in another agent’s conversation"
                        : clause,
                ]
            },
            "task_priorities": [
                ["kind": "urgent", "label": "Urgent"], ["kind": "high", "label": "High"],
                ["kind": "medium", "label": "Medium"], ["kind": "low", "label": "Low"],
                ["kind": "none", "label": "No priority"],
            ],
            "task_sizes": [
                ["kind": 1, "label": "Tiny", "color": "teal"], ["kind": 2, "label": "Small", "color": "green"],
                ["kind": 3, "label": "Medium", "color": "blue"], ["kind": 4, "label": "Large", "color": "purple"],
                ["kind": 5, "label": "Huge", "color": "pink"],
            ] as [[String: Any]],
            "agent_colors": ["blue", "green", "orange", "purple", "red", "pink", "teal", "yellow"].map {
                ["kind": $0, "label": $0.capitalized]
            },
            "agent_personalities": ["balanced", "friendly", "professional", "candid", "playful"].map {
                ["kind": $0, "label": $0.capitalized]
            },
            "agent_verbosities": ["terse", "brief", "detailed", "thorough"].map {
                ["kind": $0, "label": $0.capitalized]
            },
            "tiers": [
                ["kind": "agent", "title": "Agent", "description": "Every agent conversation and any script that names no tier."],
                ["kind": "low", "title": "Low", "description": "Cues an agent marks as quick checks."],
                ["kind": "medium", "title": "Medium", "description": "Cues an agent marks as ordinary work."],
                ["kind": "high", "title": "High", "description": "Cues an agent marks as hard reasoning."],
            ],
            "spend_periods": [
                ["kind": "hour", "title": "Per hour", "description": "What model calls cost in the last 60 minutes."],
                ["kind": "day", "title": "Per day", "description": "What model calls cost in the last 24 hours."],
                ["kind": "month", "title": "Per month", "description": "What model calls cost in the last 30 days."],
            ],
            "providers": [
                ["kind": "openAi", "label": "OpenAI", "provider_identifier": "openai"],
                ["kind": "anthropic", "label": "Anthropic", "provider_identifier": "anthropic"],
                ["kind": "xai", "label": "xAI", "provider_identifier": "xai"],
                ["kind": "mistral", "label": "Mistral", "provider_identifier": "mistral"],
                ["kind": "fireworks", "label": "Fireworks", "provider_identifier": "fireworks-ai"],
                ["kind": "deepInfra", "label": "DeepInfra", "provider_identifier": "deepinfra"],
                ["kind": "togetherAI", "label": "Together AI", "provider_identifier": "togetherai"],
                ["kind": "openRouter", "label": "OpenRouter", "provider_identifier": "openrouter"],
            ],
            "dialects": [
                ["kind": "chatCompletions", "label": "Chat Completions"],
                ["kind": "messages", "label": "Messages"],
                ["kind": "responses", "label": "Responses"],
                ["kind": "statelessResponses", "label": "Responses (stateless)"],
            ],
            "agent_reactions": ["👍", "👎", "❤️", "😂", "😮", "😢", "🎉", "🙏"],
            "actor_session_statuses": [
                ["kind": "working", "label": "Working"],
                ["kind": "needsAttention", "label": "Needs you"],
                ["kind": "idle", "label": "Done"],
                ["kind": "failed", "label": "Failed"],
                ["kind": "resolved", "label": "Resolved"],
            ],
        ]
    }

    static let permissions: [(String, String, String)] = [
        ("cohesion:read", "Read your data", "See your workspaces, journals, documents and tasks."),
        ("cohesion:write", "Change your data", "Create, edit and delete what’s in your workspaces."),
        ("network", "Use the network", "Send requests to the internet."),
        ("timer", "Run on a schedule", "Run code on a repeating timer."),
        ("registry", "Offer extensions to browse", "List extensions for you to browse and install."),
        ("oauth", "Sign in to a service for you", "Connect accounts at a service and keep them signed in."),
        ("connector", "Import from a service", "Bring an account’s pages and records in as resources."),
        ("service", "Run as a service", "Answer requests from Cohesion’s apps, the CLI, agents and scripts."),
        ("service:isolated", "Run as a service for your apps", "Answer requests from Cohesion’s apps, the web UI and the CLI only."),
        ("services", "Use other extensions’ services", "Call what other installed extensions offer as services."),
        ("usage", "See model usage", "See how many tokens Cohesion’s models used and what they cost."),
        ("intelligence", "Set up and manage endpoints", "Set up the endpoints and models Cohesion’s agents use."),
        ("notifications", "Send you notifications", "Send notifications that extensions can deliver to your devices."),
        ("actors", "Use actors", "Read, dispatch, and interact with actors."),
    ]

    static let hooks: [(String, String)] = [
        ("launch", "Cohesion starts"),
        ("task:create", "a task is created"),
        ("task:status", "a task’s status changes"),
        ("task:rename", "a task is renamed"),
        ("task:move", "a task moves to another folder"),
        ("task:priority", "a task’s priority changes"),
        ("task:size", "a task’s size changes"),
        ("task:assigned", "a task’s assignee changes"),
        ("task:description", "a task’s description changes"),
        ("task:startdate", "a task’s start date changes"),
        ("task:duedate", "a task’s due date changes"),
        ("task:start", "a task is started"),
        ("task:due", "a task is due"),
        ("task:tagged", "a tag is added to or removed from a task"),
        ("task:delete", "a task is deleted"),
        ("taskfolder:create", "a task folder is created"),
        ("taskfolder:delete", "a task folder is deleted"),
        ("workspace:create", "a workspace is created"),
        ("workspace:delete", "a workspace is deleted"),
        ("journal:settled", "you finish an edit to a journal entry"),
        ("document:settled", "you finish an edit to a document"),
        ("resource:import", "a resource is imported"),
        ("resource:update", "a refresh brings in a newer copy of a resource"),
        ("resource:delete", "a resource is removed"),
        ("feed:article", "a feed brings in a new article"),
        ("feed:delete", "you stop following a feed"),
        ("article:read", "an article is marked read"),
        ("agent:message", "a message appears in an agent’s conversation"),
        ("agent:reaction", "someone reacts to a message in an agent’s conversation"),
        ("agent:turn:start", "an agent starts replying to you"),
        ("agent:turn:end", "an agent finishes replying to you"),
        ("activity:started", "an activity starts"),
        ("activity:updated", "an activity’s progress, status or title changes"),
        ("activity:ended", "an activity ends"),
        ("actor:moved", "an actor makes progress"),
        ("day:start", "the day starts at 6:00 AM"),
        ("day:end", "the day ends at 11:00 PM"),
        ("timer", "a minute begins"),
        ("extension:update", "an update is available for an installed extension"),
        ("notification:send", "a notification is sent"),
        ("client:revoke", "a client is revoked"),
    ]
}
#endif
