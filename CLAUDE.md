# CLAUDE.md

Cohesion's native apps, the alternative to the web UI: a SwiftUI
client of `cohesiond` for iPhone and iPad, with a share extension
(`CohesionShare`), widgets and Live Activities (`CohesionWidgets`), and a
notification service extension (`CohesionNotificationService`), and for the
Mac (`CohesionMac`), over the local packages in `Packages/`. The daemon,
its protocol and the web UI live in
[cohesionhq/cohesion](https://github.com/cohesionhq/cohesion); read its
`README.md` and `docs/architecture.md` for what a command or an
invalidation means. `ARCHITECTURE.md` maps this repo.

Skills in `.claude/skills/`: `add-feature` (how a change is built here,
and the checklist of everything a feature must be wired into),
`verify-change` (the build, known warnings, the simulator) and
`finish-task` (commit and report).

Docs in `docs/`:

- `product-direction.md`: the product direction the maintainers set, and
  what it says for the apps. On a product question it doesn't answer, ask
  the maintainers rather than guess.
- `design.md`: accent and agent colors, iPhone and iPad layout, copy,
  avatars, haptics, accessibility, iPad as a first-class target.
- `platform-integrations.md`: pairing and the keychain, pushes, Live
  Activities, widgets, the share extension, links, entitlements, and what to
  touch when adding to each.
- `parity-with-web.md`: how to compare a screen with the web UI.

## Design principles

- **The daemon owns the rules.** The app shows what a reply says and never
  recomputes a rule the daemon already applied: a client is online because
  the clients list says so, a name is taken because the command refused it.
  A rule the app seems to need belongs in the daemon: don't write it here;
  report the daemon change it needs.
- **Extend what exists.** A new command is a method in
  `Connection/Commands.swift`, a new model a `Decodable` in `Models/`, a
  refresh an invalidation handled in `Connection/Changes.swift` (all in
  `CohesionCore`). Reach for those before adding a manager, a cache or a
  dependency.
- **Screens are shared, shells aren't.** A screen lives in `CohesionScreens`
  and works on iOS and the Mac; only navigation, what a window's chrome does
  and what the platform alone offers are in an app target.
- **Lean on the type system.** An enum rather than a string or a pair of
  bools; fields that only make sense for one case live in that case.
- **No speculative generality.** Build what the task needs.

## Decide, then report

Work without stopping to ask. On an open design or copy question, take the
conservative choice (what the web UI and the rest of the app already do;
copy follows `docs/design.md`), keep going,
and list every such choice in the report so the maintainers can push back.

Stop and ask only when the task is truly blocked: it needs a new
dependency, target or extension; a protocol, daemon or cloud change (build
what today's protocol allows and report the change, which goes to
cohesionhq/cohesion first); something destructive or irreversible;
credentials, signing or provisioning; or it has no conservative reading.

## Workflow

- Work on `master` in the main checkout, not a worktree or branch, unless
  the work needs isolation.
- The checkout may hold others' uncommitted work: never stash, revert or
  commit it. Commit only your own paths (`git commit --only`).
- Run `verify-change` before reporting, and never deploy (no archive or
  TestFlight).
- Report briefly in `finish-task`'s format: what changed, commits, checks,
  choices made without asking, caveats, what to check manually.

## Keep the docs true

Keeping these docs in step with the product's intent and the code is part
of every task, not a separate chore:

- A change that makes `CLAUDE.md`, `ARCHITECTURE.md`, `docs/*.md` or a
  skill wrong fixes it in the same commit. Docs say how things are and the
  rules to follow, never plans.
- Where a doc and the code disagree and fixing it isn't your task, report
  the drift.
- When a change affects product direction (what the apps offer, a parity
  row, a rule in `docs/product-direction.md`), say so in the report so the
  maintainers can update it.

## Trust model

The app pairs with `/register` and pins the server's key; after that the
server is trusted. Validate only what comes from outside: shared URLs and
text from the share extension, and push payloads.

## Wire format

The models mirror `cohesion-core`'s protocol: struct fields are snake_case
on the wire (map them with `CodingKeys`), enums camelCase. Commands are
called by their camelCase `type` with snake_case `args`.

## Links

- `cohesion://` links (in Markdown agents, tasks and documents write) and
  `cohesionplus://` URLs (notifications, Live Activities, widgets) name
  the same targets and parse in one place, `AppLink`. A new kind of target
  is a case there, opened from both. Any other link goes to the system.
- One-row content, an item shown as a single row in a list with a small
  detail of its own (a task), opens in a sheet over whatever is on screen;
  it never pushes or switches tab. Full-page content (an agent's chat, an
  actor session's transcript) navigates. A document also opens in a sheet,
  since it has nowhere to push from everywhere a link can be tapped.
- Sheets come from `presentsLinkedItems()`. A sheet presents only from the
  topmost one, so every sheet whose text can hold a link applies it at the
  sheet's content; a link that navigates closes those sheets first.
- A target that's gone is a toast ("Task not found."), never an empty
  screen.

## Conventions

- Agent avatars size the glyph from the disc: half the diameter for an
  emoji and for an initial (semibold), centred and clipped to the disc.
  An emoji is sized by what it draws, not its font size (below 24pt it
  draws larger, so it's drawn at 24pt and scaled down). The only
  exception here is avatars where a symbol goes, in menu items and
  agents' rows (`.symbol`), whose initial takes 0.45. `AgentAvatar`
  and the notification service's `INPerson` image both follow it; never
  tune a size by eye.
- The SF Symbol and color of a value from the daemon live in
  `CohesionUI/ProtocolPresentation.swift`, as an extension on its type; a
  screen reads them rather than switch over the value itself. The one
  exception is the notification service, which links no package and keeps
  its own agent colors (`docs/design.md`).
- `///` comments say what a type or member is for; match the surrounding
  comment density and naming.

## Building

```sh
xcodebuild -scheme Cohesion -destination 'generic/platform=iOS Simulator' build
```

That builds the four iOS targets;

```sh
xcodebuild -scheme CohesionMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

builds the Mac app. `verify-change` says what passing means.
Simulator checks stay small: an end-state screenshot per affected device
with `simctl`, and the `device-interaction` skill only when a change needs a tap to
show; `verify-change` §5 has the rules.
