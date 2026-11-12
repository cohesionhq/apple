---
name: add-feature
description: Recipe and wiring checklist for adding a feature to or fixing a bug in Cohesion's apps the way this codebase does it. Covers a new cohesiond command, a reply model, an invalidation that reloads a view, a screen, a deep link, and code shared with the extensions, plus how to read the real protocol and replies. Use when implementing any task in this repo that touches what the app sends, shows or reloads, or when the daemon seems to lack something the task needs.
---

# Add a feature

Read `ARCHITECTURE.md` for the map and `CLAUDE.md` for the principles.
Most features here are a cohesiond command the app doesn't call yet, shown
in a view that reloads on the right invalidation. `ClientsView.swift` in
`CohesionScreens` is a small, complete example: a list, `listClients`, `.clients` reloads,
and rename and revoke actions.

## Checklist

Most mistakes here are a step forgotten, not a hard one got wrong. Before
`verify-change`, go down this list and tick or skip each item on purpose;
the sections below and the linked docs say how.

- [ ] **Daemon support.** The command, field, invalidation or rule exists
  in cohesiond. If not, report the daemon change; don't fake it (§1).
- [ ] **Command**: a public method in `CohesionCore`'s
  `Connection/Commands.swift` (§2).
- [ ] **Model**: a public `Decodable` in `CohesionCore`'s `Models/`, checked against a real reply
  from `cohesion api`, not guessed (§3).
- [ ] **Reload**: an `Invalidation` case in `CohesionCore`'s `Connection/Changes.swift` if
  the kind is new, and the view watching it with `changes(matching:)` (§4).
- [ ] **Every navigation**, in `Cohesion/Views/RootView.swift`,
  `CohesionMac/MacRootView.swift` and `CohesionScreens/WorkspaceSections.swift`:
  a workspace page is a `WorkspacePage`, built in `WorkspacePageView`, listed
  in the sidebars (`SidebarSections`: `WorkspaceSections` for the task lists,
  `LibrarySection` and `WorkspaceSources` for the rest) and on the iPhone's
  tab for it (`TaskListsView` on Tasks, `LibraryView` on Library); an
  agent or actor screen is a `SidebarItem` on iPad and the Mac and an
  `AgentsRoute` pushed from the Agents tab. A screen on one only is a
  bug, and a new screen never adds a fifth tab (§5).
- [ ] **The Mac**: the screen builds and makes sense there. A sheet is
  `sizedSheet`; what iOS alone has goes through `Platform.swift` or
  `#if os(iOS)`; a window-wide action is a command in `MacCommands` too.
- [ ] **Link**: an `AppLink` case for a target a notification, widget,
  Live Activity or Markdown link opens, handled in `RootView`'s `open(_:)`
  and in `WindowModel.follow` (§5, `docs/platform-integrations.md`).
- [ ] **Windows**: what one window shows (a selection, a path, the
  workspace, a list) lives in the view, its shell or `WindowModel`, never `AppModel`, which
  every window shares (`docs/design.md`, "Multiple windows").
- [ ] **Sheets with links**: every sheet whose text can hold a link
  applies `presentsLinkedItems()` at its content (`CLAUDE.md`, "Links").
- [ ] **Where it lives**: what an extension uses is in `CohesionCore` or
  `CohesionUI`, public, and builds there (§6).
- [ ] **Errors**: `.errorAlert($error)` for a failed action or a load the
  user asked for, none for an automatic load (`LoadOrigin`) or a cancelled
  one; a `Toast` for a link whose target is gone
  ("Task not found.") (§5).
- [ ] **Avatars**: `AgentAvatar`, never a glyph sized by eye
  (`CLAUDE.md`, "Conventions").
- [ ] **Copy**: every new string checked against `docs/design.md` and
  listed in the report (§7).
- [ ] **Design**: accent, agent colors, haptics, accessibility labels and
  iPad pointer and keyboard as in `docs/design.md`; a daemon value's symbol
  or color goes in `ProtocolPresentation.swift`.
- [ ] **Docs**: `ARCHITECTURE.md` for a new file, flow or target; the
  known-warnings list in `verify-change` if it moved.
- [ ] **Parity**: report which parity rows change, and to what
  (`docs/parity-with-web.md`).

## 1. Find what the daemon offers

The daemon owns the rules, so first learn what it already does. Read; don't
change it from here.

- Commands and their args: `../cohesion/cohesion-core/src/protocol/*_requests.rs`.
- Invalidation kinds: `../cohesion/cohesion-core/src/invalidation.rs`.
- Meanings: `../cohesion/docs/architecture.md`, and `../cohesion/web/`
  for how the web UI shows the same thing (the app usually mirrors it).
- A real reply's shape, from a daemon the `cohesion` CLI is paired with.
  Use read-only commands only:

  ```sh
  cohesion api '{"type":"listClients"}'
  cohesion -w <workspace> api '{"type":"listTaskFolders","args":{"workspace_id":1}}'
  ```

  The envelope is `{"ok":{"type":…,"data":…}}`; the model decodes `data`.
  Never send a command that writes, and never run `cohesion switch`.

**If the daemon lacks it** (a command, a field, an invalidation or a
rule), don't fake it in the app and don't edit `../cohesion`. Build what
works with today's protocol, or nothing if nothing does, and put the
exact daemon change needed under caveats in the report. It goes to
cohesionhq/cohesion first.

## 2. Command

Add a method to `Connection/Commands.swift` in `CohesionCore` under the right
`// MARK:`, with a `///` comment when the name doesn't say it all:

```swift
/// Revokes the client: cohesiond stops trusting its certificate, and
/// what it offered goes with it.
public func revoke(_ client: Client) async throws {
    let _: JSONValue = try await call("deleteClient", ["id": client.id])
}
```

`type` is camelCase and arg keys are snake_case. A `nil` value is left out,
so optional args are plain optionals. Decode a reply you don't use as
`JSONValue`. Command names appear nowhere else.

## 3. Model

Add a public `Decodable` to the matching file in `CohesionCore`'s `Models/`,
with a `public init` if a screen makes one. Fields are camelCase in Swift and
mapped to snake_case with `CodingKeys`; enum raw values are already camelCase. Use an enum, not a string or a pair of
bools, and keep fields that belong to one case inside that case. Decode
only what the app shows. Words for the daemon's kinds come from
`Vocabulary` (`model.vocabulary`), not hard-coded labels.

## 4. Reload on change

If the data can change while the view is open, the view watches for it:

```swift
.task { await watch() }

private func watch() async {
    guard let client = model.client else { return }
    for await origin in client.loads(matching: { $0 == .clients }) {
        await load(origin)
    }
}

private func load(_ origin: LoadOrigin = .automatic) async {
    guard let client = model.client else { return }
    await origin.run {
        clients = try await client.listClients()
    } failed: { self.error = $0 }
}
```

The stream yields once on subscribe, which does the first load: that one
and `.refreshable { await load(.asked) }` alert when they fail. Every other
load keeps what's on screen and stays quiet, after retrying quietly. Use
`changes(matching:)` for a load that's never asked for, as `WindowModel`'s are. A kind the
app doesn't know yet gets a case in `Invalidation` in
`Connection/Changes.swift` (with its `///` and decoding), not its own
socket or polling.

## 5. View

Put the view in `CohesionScreens/<Area>/`, public only if a shell opens it.
What a window lists goes in `WindowModel`. Wire iPhone navigation and the
iPad's sidebar in `Cohesion/Views/RootView.swift` (`RootTab`,
`WorkspaceRoute`, `AgentsRoute`, `page(_:)`, and `showInTabs`/`showInSidebar`,
which carry what's open across a resize), the Mac's in
`CohesionMac/MacRootView.swift`, and what they share in
`CohesionScreens/WorkspaceSections.swift` (`WorkspacePage`, `SidebarItem`,
`WorkspaceSections`, `LibrarySection`, `SidebarSections`, `FeedSection`), the
iPhone's `TaskListsView` and `LibraryView`, and `WorkspacePageView`.
`RootView` picks tabs in a compact width and the sidebar otherwise, so an iPad
in Split View shows the tabs: check both.
Show errors with `.errorAlert($error)`, through `LoadOrigin` for a load: only
one the user asked for alerts, and a cancelled one never does. A link to something that's gone is a
`Toast` (`.toast($notice)`), as `keepsWindowLists` does. Avatars follow the sizing
rule in `CLAUDE.md`.

A screen that something outside the app opens gets an `AppLink` case
(`cohesionplus://…`) with strict parsing, since anything on the device can
open one. `docs/platform-integrations.md` lists everywhere a new case is
opened from.

## 6. Shared with the extensions

`CohesionShare` and `CohesionWidgets` link `CohesionCore` and `CohesionUI`, so
code added there must build in the extensions, and on the Mac: no UI in
`CohesionCore`, no `AppModel` in either. Live Activity `ContentState` and the push payload are a contract with
Cohesion Cloud. Change them only alongside Cohesion Cloud, which is a stop
and report. `docs/platform-integrations.md` says what each extension,
entitlement and contract needs.

## 7. Copy

Decide it yourself, following "Copy" in `docs/design.md`: the models'
words, no internals ("Cohesion", not "cohesiond"), buttons that say what
they do, `…` for a button that opens a dialog. Match what the web UI calls
the same thing. List each new string under "Choices made without asking"
in the report.

Then go down the checklist again, run `verify-change`, then `finish-task`.
