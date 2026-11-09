# Design

How Cohesion's apps look and read. Native, system-standard SwiftUI first: use
the platform's controls, text styles and colors, and add to them only
where this page says. Direction: the apps' surface and the goal's
"Character" (`docs/product-direction.md`).

## Color

- **Accent**: `AccentColor` in `Cohesion/Assets.xcassets`, the brand
  indigo, lighter in dark mode. It is every app target's global accent, so
  `.tint` and `Color.accentColor` reach it. Use it for the main action,
  selection, progress and the user's own things (their reactions, a picked
  option). Don't add other brand colors.
- **Agent colors**: an agent's `AgentColor` maps to a system color
  (`.blue`, `.green`…) in `ProtocolPresentation.swift`. Agents' avatars and their own chat accents
  (`\.agentColor`) use it; nothing else does. The notification service
  keeps its own copy of the mapping in `NotificationService.swift`; change
  both together.
- **Needs you**: orange for what waits on the user or isn't right yet (an
  actor session needing attention, a reconnecting socket, an inactive
  extension, an article not fetched). Red for failed or revoked, green for
  connected.
- **Everything else** is the system's: `.primary`, `.secondary`, grouped
  backgrounds. Dark mode follows the system; there's no app setting.

## Layout: iPhone and iPad

`RootView` shows tabs in a compact width and two columns otherwise. Both
follow the order of the web's sidebar (the workspace's pages, then the
agents, then the actors), leaving out what the apps have no screen for:

- **iPhone (and a narrow iPad window)**: four tabs (`RootTab`).
  **Dashboard** (`rectangle.grid.1x2`) comes first and is picked at launch: it
  has no navigation bar, its greeting heading it, and pushes the chats and
  sessions its rows open, so Settings is on the other tabs and the workspace menu on Workspace's.
  Then **Intelligence** (`sparkles.2`), titled large as Feeds is:
  it lists the pinned agents as a grid, four across, then the sidebar's one section without
  them (each team's, then those on no team, a row's team as its subline), which doesn't
  collapse, and whose section action, Teams, renames or deletes a team, as the
  sidebar's does; then
  the current actor sessions, pushing a chat or a transcript (`AgentsRoute`),
  which hides the tab bar; while some actor reports its plan, the
  navigation bar's overflow menu (`ellipsis`) holds Actor Usage, a sheet.
  Then, in the web's order, **Workspace**,
  titled with the workspace's name, whose title menu picks another; its
  first screen is the sidebar's workspace part, the same
  `WorkspaceSections` without the Dashboard or feeds: Today, Journal, Documents,
  Contacts, then Tasks, then Connectors (the kinds of resource the workspace
  shows, then Edit…), each row pushing its page (`WorkspaceRoute`). And
  **Feeds**, All Feeds and each feed with its unread count, then Add Feed
  (the sidebar's `FeedSection`), pushing the feed's articles, which push
  the reader. Settings is a button on each tab's first screen
  (`tabRootToolbar`), but for the Dashboard's.
  - **A new screen joins one of these tabs**, never a fifth: a
    workspace page is a row in `WorkspaceSections` (so the iPad's sidebar
    gets it too), a feed screen is pushed from Feeds, an agent or actor
    screen from Intelligence.
- **iPad**: a two-column `NavigationSplitView`, balanced so the sidebar
  stays beside the detail in portrait too. The sidebar (`Sidebar`) is
  headed by the workspace's name, whose title menu picks another, and
  lists Dashboard, Today, Journal, Documents, Contacts and Tasks; then Feeds, a
  section that collapses and lists what the web's Articles page lists in its
  own column; then Connectors, the kinds
  of resource the workspace shows (each by its connector's icon, as the
  web lists them after its pages), then Edit…; then Agents, one section
  (pinned first, then each team's, then those on no team, a row's team as its
  subline; New Agent and Teams, which renames or deletes a team, are section
  actions) and
  Actors (the current sessions; New Session is a section action), with each
  section's collapse remembered across launches; the sidebar's navigation bar
  has the same overflow menu with Actor Usage. Settings, with the
  connection's dot, is at the foot. The detail shows what's selected
  (`SidebarItem`), the Dashboard at launch and on switching workspace; Contacts opens the list, which pushes
  a contact. Pushes zoom from their source (`zoomsOnIPad`).
  - Tasks is one row (`TaskSection`), to leave the list room, which opens the
    list last open in the window, or the inbox on launch or on switching
    workspace. The list's title menu (`TaskListMenu`) moves between the inbox,
    folders, All, Done, Cancelled and saved views, and Edit Views… reorders the
    views. A compact width and the Mac list them all as a section instead.
  - An agent's row, here and on the iPhone, is its avatar where a row's symbol
    goes, its name, which shimmers while it works, its team, a pin if it's pinned
    (only here, since the iPhone's pinned are in its grid), and a dot while
    unread: no counts.
    An actor session's row is its title, which shimmers while it works,
    over its status as an icon and its name in secondary text, both amber when
    it needs the user, wherever it's listed: no leading space, no unread mark.
  - The detail's lists (tasks, journal, documents, contacts, articles,
    resources)
    are plain, not inset-grouped.
  - An agent's chat and an actor session's transcript, with what floats at
    their foot, share one column (`conversationColumnWidth`), centred in
    a wider pane.
  - The iPhone's pinned grid is a list row, never a section header,
    which would stick under the title and fade rather than scroll. As in
    Messages, it has no heading and no row insets, and names its agents
    in secondary text under their avatars, an unread one with a dot after
    its name, the size of a row's.
  - Counts in the sidebar are trailing text, not `.badge`: a badged row
    in a split view's selectable list takes two or three taps to select.
- **A window resized between the two keeps what it shows**: `RootView`
  maps the sidebar's selection to a tab and its path, and back.
- **Every new screen gets both.** A screen reachable on iPad but
  not a tab (or the reverse) is a bug. Check a regular and a compact width.
- Links follow "Links" in `CLAUDE.md`: one-row content and documents in a
  sheet, full-page content navigates.
- **A sheet's toolbar actions are icons with a role**, titled for
  VoiceOver: Cancel is `xmark` with `.cancel`; the action that finishes
  the sheet (Done, Add, Save, Attach) is `checkmark` with `.confirm`,
  except a composer's Send or Start, `arrow.up` with `.confirm` as the
  agent chat's Send; a Done or Close on the leading side is `xmark` with
  `.close`.
- **A row that opens a page, in a list of pages, has a `SymbolIcon`**
  (`Label(_:systemImage:color:)`), a white symbol on a colored gradient, as
  Settings and an agent's sheet do. Memories is `brain` on pink in both.

## The Dashboard

Recap and quick dispatch, in the platform's controls, one list in every shell: a
plain `List` centred in `conversationColumnWidth`, the greeting and composer as
rows without separators or backgrounds. The greeting leads the page at a large
title's size, leading-aligned as a large title is, with the day under it in
secondary text, as the web's Dashboard has it. The composer sits in the page under the greeting, not
at the foot like the chat's: no keyboard comes up on opening it (the Mac's field
takes focus, as its keyboard takes no room). It's one sheet of glass, and nothing
on it has glass of its own: a borderless field, with attach and send at the
trailing end. Attach floats above the sheet rather than on it, because interactive
glass takes the touches meant for the part of an open menu that lies over it. Under
the sheet, each with glass of its own, are the agent menu, leading, and Quick
Journal…, trailing, which stack when they don't fit. A tap anywhere in the composer
outside its controls, the gap under the sheet included, focuses the field. On iOS the
keyboard closes with a tap on the page outside the composer, scrolling the page,
or Done, a glass button in the page's bottom safe area with the chat composer's
margins, there only while the composer has the focus.

On iOS, a message that wraps past one line makes the composer the focus of the page,
while it has the focus: the greeting fades, What's New goes, and the composer moves
to the middle of the room above the keyboard and Done, with `.snappy`. Back to one
line, or closing the keyboard, restores the page. Under Reduce Motion nothing moves:
the page fades out and back with the composer in its new place. The composer stays in
its list row, so it keeps the keyboard, and the page still scrolls, for a composer
taller than the room at large text sizes. What's New can run longer than any screen,
so the page scrolls in the normal layout too.

Quick Journal is a sheet that's paper to write on: a field with no border or
background, and a tap anywhere on the sheet puts the cursor in it. Its `checkmark`
action, or ⌘Return, adds the note to today's entry as a paragraph of its own
(`appendToJournal`, so what the entry holds is never replaced), and a toast
confirms. A failure leaves the sheet open with the note and alerts.

What's New is a native section, gone when empty, in this order: the sessions
that need the user, their status's words amber as well as the icon; those
finished or failed and still unread; then agents with unread messages, newest
first. Under it, **Working** lists every working session, its title
shimmering. As the web's recap, the two are rows of one kind: a session's
status icon in the slot an agent's avatar takes, so every title starts at one
edge, over its status and how long ago it changed ("Needs you · 5m"), or for an
agent "New message · 5m" ("now" under a minute, or for a time ahead of this
device's clock). Each section's heading carries its count. What's listed is the
daemon's status and unread state, across the whole server as sessions and agents
are. A row opens the session or chat: pushed on the Dashboard tab's own
stack on iPhone (`dashboardPath`), so back returns here; selected beside the
sidebar on iPad and the Mac.

## Layout: the Mac

The screens are iOS's, and only the shell differs (`CohesionMac/`). Use the
Mac's way wherever the shell has a choice:

- **A window** is a `NavigationSplitView` that never collapses to tabs: the
  sidebar, the same `SidebarSections` as iPad's, but for Tasks, a section that
  collapses, beside what's selected, the
  Dashboard at launch and on switching workspace. A workspace picker is at the sidebar's head; the connection's dot
  and word and a Settings button are at its foot.
- **Settings is the app's Settings window** (⌘,), a tab a page, never a
  sheet. About unpairs. What's about this device on iOS (notifications, Live
  Activities) has no place there.
- **The menu bar carries what a window can do**, through `MacCommands`: new
  things under File (⇧⌘N a new agent, ⌥⌘N a new session), Dashboard (⇧⌘D) and
  Reload (⌘R) under View,
  and the window's workspace in a Workspace menu. ⌘N stays New Window.
- **A sheet is `sizedSheet`**, which gives it a size, since a Mac sheet fits its
  content and a form's fields collapse. Forms are `.grouped`, as iOS draws
  them, set at each scene's root.
- **An image is picked from a file too**: the attach menu adds Choose Files…,
  and a contact's or the user's photo is a file cut to its middle square, as
  the Mac has no system crop. There's no sketch or Add from Contacts….

## iPad is a first-class target

The target is up to a 13" iPad Pro with keyboard and trackpad. These are
the rules for new work; only multiple windows is built across the app
yet, so don't assume an existing pattern for the others:

- **Keyboard shortcuts** are designed for iPad (`.keyboardShortcut`,
  shown in the system's ⌘-hold overlay), not copied from the web's.
  One that acts on a window is a command in `CohesionApp`'s `.commands`,
  so it shows in the menu bar, reaching the focused window through a
  `FocusedValues` entry `RootView` sets with `.focusedSceneValue`, as
  Settings… (⌘,) does.
- **Pointer and hover**: controls get system hover effects; custom hit
  targets get a `contentShape` and a hover effect.
- **Multiple windows**: don't assume one scene. Each window has its own
  screens and selection (`RootView`'s state) and its own workspace
  (`WindowModel`, restored with the window), over the app's one pairing
  and connection (`AppModel`), so pairing or unpairing in one applies to
  all. Keep state that belongs to a window in its views or
  `WindowModel`, never in `AppModel`. A window is titled after what it
  shows (`windowTitle`), as the web titles a page.

## Conversations

An agent's chat reads as an actor session's transcript does, on every device:

- **The agent's reply is flat Markdown filling the column**
  (`MarkdownText`'s `.transcript`), with no bubble. Where the agent's turn
  starts, a caption above it (a dot in the agent's color, its name) says
  whose it is. A job, or a fork speaking after something else came between it
  and its row, has its trigger's rule instead, and a bare rule ends it.
- **The user's message is an accent bubble on the trailing edge**, at most
  70% of a column 600 points or wider; narrower, the chat's stops
  `bubbleInset` short of the far edge, the transcript's fills the column.
- **Cards stay cards**, one look in both: a received bubble's grey with its
  corners, an actor's questions and permissions as an agent's choices are;
  a permission's decisions are two equal columns, the allows over the
  denials. Quiet lines stay quiet, on the leading edge the
  text starts from.
- **A reaction** hangs off the bottom corner of a bubble or card, and sits
  under a flat reply at its leading edge, after its images. A reply's text
  isn't selectable, as the long press reacts to it or copies it.
- **Space**: 28 points between speakers or runs, 14 between flat replies,
  the transcript's own numbers; 8 within a block otherwise, quiet lines
  included, which have no padding of their own. Everything a fork posts is one
  run: the question that opened it, its own questions, and a "Context rebuilt"
  line that fell in it, though that line carries no run.
- **A fork's steps collapse into one row** on a faint fill, its bolt in the
  agent's color, where it woke, as soon as it
  has a step: what woke it, then its step count at the trailing edge, rolling
  as a fork still going adds to it. The row stands in for the trigger's rule, and
  ends with no bare rule unless the fork said something to the user. Which
  messages are steps is the daemon's `run_part`: what a fork surfaces (a reply,
  a choice, a failure) stays in the chat, as do reaction lines and "Context
  rebuilt". The row opens a sheet of the steps as the chat's quiet lines, each
  opening what it did before; a quote of a step opens that sheet on it. An actor
  session's tool rows are its own and don't change.

## An agent at work

One quiet sign: a soft light sweeping across text (`workingShimmer`) at the web's
pace: every 2.5 seconds a band with no hard edge, 60% of the text's width, crosses
in 0.9 seconds, slowing as it goes, the text dimmed between sweeps. Every shimmer
takes its phase from the time, so all on screen are in step. Its name shimmers
in the Intelligence tab's rows and pinned grid and in the sidebar; the foot of its chat is a caption,
where its reply's caption will land, and that shimmers. The caption says what the daemon's `activity` says, as the daemon
words it, or "Working…" when that's empty or hasn't come yet, as while a message
is on its way. New words fade in over the old on its one line, so nothing moves.
No spinner, and no other motion beside it. What it says it's doing also stays in
words where a row shows its status, but in a chat the caption is the one place
that says it: while the agent works, the header's pill is its name alone, and
its role comes back when the work stops. The name stays still; besides the
caption, the only shimmer in a chat is on the row of a fork still running, which
is in step with it, and that fork's sheet ends in the same caption. Under Reduce
Motion the text is plain, with nothing in its place.
Widgets can't animate and don't shimmer.

An actor session works the same way. Its row's title, in the sidebar and on the
Intelligence tab, shimmers, with no leading icon; its status sits in the subtitle. The foot of its transcript is the same caption, its dot the accent
since a session has no color of its own; the header's title stays still. A
session has a status rather than an activity, so its caption always says
"Working…".

## Copy

The web's copy rules are the source: "Copy" in cohesionhq/cohesion's
`web/README.md` (`../cohesion/web/README.md`). In short, as they apply
here:

1. **Capitals**: follow iOS, as the app does: title case for buttons, menu
   items, navigation titles and section headers ("New Task", "Move To");
   sentence case for descriptions, hints, toasts and errors. Only proper
   names keep capitals otherwise.
2. **One word per concept**, the daemon's: workspace, journal, document,
   task, folder (never "task list"), inbox, agent, actor session, cue, job,
   proposal, extension, permission, hook, connector, account, resource,
   model, client. Kinds' names and order come from `Vocabulary`.
3. **No internals**: no "daemon", `cohesiond`, raw enum or hook names, or
   ids. The server is "Cohesion".
4. **Buttons say what they do**: a verb and, when needed, its object. A
   confirmation repeats its verb. Delete is for what the user made, Remove
   for what lives elsewhere; extensions are uninstalled, clients revoked.
5. **Ellipsis** (`…`, one character) on a button or menu item that opens a
   form or picker before acting, and on a busy label ("Saving…").
6. **Confirmations** ask a question naming the thing: titles in curly
   quotes ("Delete “Groceries”?"), names without (“Delete Ada?”). The
   message says what goes with it, or "Can’t be undone."
7. **Empty states**: "No {things} yet."; "No matches." for a filter; a
   missing link target is a toast, "{Thing} not found."
8. **Errors** say what didn't happen, contracted ("Couldn’t…", "isn’t").
   The server's messages show as they come. Only what the user did alerts:
   an automatic load that fails keeps what's on screen and says nothing.
9. **Punctuation**: sentences end with a period, labels don't. Curly
   quotes and apostrophes (’ “ ”), "and" not "&", numerals for counts.
10. **Toasts** confirm in the past tense and name the thing ("Forwarded
    “Q3 plan”.").
11. **Shortcuts** are written as the system shows them (⌘K, ⇧⌘N).
12. **Tone**: plain, second person, no exclamation marks, "please" or
    "successfully".
13. **No hover-only text**: no `.help()`; what matters is on screen, and an
    icon-only control names itself.

Match what the web calls the same thing. Every new string goes in the
report under "Choices made without asking".

## Avatars

`AgentAvatar` draws every agent avatar: the glyph is half the disc, an
emoji or a semibold initial, white, on the agent's color gradient,
clipped to the circle. An emoji's share is the size it draws at: below
24pt Apple Color Emoji draws up to a fifth larger than its font size, so
a smaller one is drawn at 24pt and scaled down. `.symbol` (avatars where a
symbol goes, in menu items and agents' rows) takes the initial at
0.45. The notification service draws the standard ratios for `INPerson`.
A person (a contact, or the user) is `ContactPhotoView`: their photo on a disc,
or without one their initials, white on a grey gradient as the system's Contacts
draws them, in a list as on their page.
Never size a glyph by eye (`CLAUDE.md`, "Conventions").

## Haptics

Sparing, and only to confirm something the user just did:

- `.success` when an action lands (completing a task, sending a forward).
- `.selection` when a tap takes the user somewhere in place (the chat
  scrolling to and lighting a quoted message).
- `.impact` when a long press opens a picker (reactions).

Prefer `.sensoryFeedback` on the view; nothing buzzes for something the
user didn't do.

## Dynamic Type and accessibility

Best effort, but never skipped:

- Use text styles (`.body`, `.caption`…), not fixed sizes. A size that must
  be a number scales with `@ScaledMetric(relativeTo:)`. Fixed sizes are
  for glyphs sized from their container (avatars, rings).
- **Name every icon-only control**: a `Label` with a system image, or
  `.accessibilityLabel`. Hide decoration (`AgentAvatar` is
  `accessibilityHidden`, since the name is beside it).
- A gesture-only action gets an `.accessibilityAction` too (the chat's
  long press to react has "React").
- Honor Reduce Motion (`\.accessibilityReduceMotion`) for scrolling and
  decorative animation, as the chat does.
