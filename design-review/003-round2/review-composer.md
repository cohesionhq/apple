## Scores

| Category | Score | One-line reason |
| --- | ---: | --- |
| Native | 6.4 | Liquid Glass touches land in places, but a persistent custom tab bar, pushed stacks that still show tabs, and chat headers that don’t match standard navigation undermine iOS 27 patterns. |
| Typography | 7.1 | Large titles and body text are generally SF-appropriate, yet metadata, paths, and captions swing between too light and too bold without a strict scale. |
| Hierarchy | 6.3 | The dashboard composer and permission cards compete well for attention; many lists (Feeds, Inbox, Extensions) leave the eye wandering in empty space with no primary action. |
| Spacing & density | 5.9 | Card-in-void layouts and iPad task rows stretched edge-to-edge feel like prototypes, not a dense professional workspace tool. |
| Color & contrast | 7.0 | Indigo accent and orange “needs you” read clearly, but failure state copy, tertiary paths, and indigo used for non-tappable contact fields dilute the semantic palette. |
| Iconography | 7.3 | SF Symbol weight is mostly consistent; agent avatars and extension list marks mix emoji, initials, and Settings-style tiles without one row language. |
| Consistency & polish | 6.1 | Tab chrome, section containers, and toolbars differ tab-to-tab; visible clipping, ghost UI, and overlapping sidebar toasts signal an unfinished pass. |
| Overall | 6.5 | Direction is credible and several flows feel “designed,” but inconsistency and empty density would make a design lead send this back for a structural pass, not ship. |

## Problems

1. **`07-iphone-tasks-light.png`, `13c-ipad-tasks-light.png`** — Two tasks floating in a vast white field reads as a broken load or mock data, not a calm inbox. Use a full-height plain `List`, a deliberate empty state (“Inbox is clear” + secondary actions), or seed previews with enough rows to judge rhythm; on iPad, constrain row content width (`conversationColumnWidth`) instead of spanning the entire detail pane.

2. **`04-iphone-feeds-light.png`** — The feed list sits in a single short card with ~60% dead space below; hierarchy says “minor widget,” not a primary tab. Adopt the same full-bleed list pattern as Documents/Journal (plain or grouped to the safe area), with “Add Feed” as a trailing toolbar `+` or bottom-affixed row only if the list is scroll-filled.

3. **`06-iphone-actor-session-light.png`, `07-iphone-tasks-light.png`, `08-iphone-journal-light.png`, `10-iphone-documents-light.png`** — The four-tab bar remains visible on pushed workspace routes, which fights standard hide-on-push behavior and steals vertical space from transcripts and lists. Hide the tab bar on non-root routes in each tab’s `NavigationStack`, matching Intelligence chat/session pushes.

4. **`03-iphone-workspace-light.png`** — Faint “cancelled” / close chrome bleeds through above the tab bar, suggesting a stray overlay or z-order bug. Remove the ghost layer or dismiss the underlying sheet before the workspace root is shown.

5. **`02-iphone-intelligence-light.png`** — The second actor session card is clipped by the floating tab bar, truncating copy and breaking tap targets. Add bottom content inset equal to tab bar + safe area, or hide the tab bar on this stack when the list exceeds the viewport.

6. **`01-iphone-dashboard-light.png`, `13-ipad-split-view-light.png`** — “Failed” rows use a red icon but grey status sublines, so failure doesn’t read as urgently as “Needs you” (orange icon + orange text). Pair failed icon with `.subheadline` in `.red` (or secondary tinted red) for the status phrase, per design semantics.

7. **`05-iphone-agent-chat-light.png`, `13b-ipad-agent-chat-light.png`** — The oversized centered avatar + glass “Atlas ›” capsule is closer to a marketing hero than Messages/Mail navigation. Collapse to inline nav bar title (avatar as `.symbol` or small leading accessory) with `.subheadline` role text; reserve large avatar for the agent info sheet only.

8. **`05-iphone-agent-chat-light.png`** — Table and body text appear to double/bleed under the glass composer, hurting legibility and native scroll-edge behavior. Use scroll content margins / `safeAreaInset(edge: .bottom)` for the composer so content never draws under interactive glass.

9. **`06-iphone-actor-session-light.png`, `13d-ipad-actor-session-light.png`** — Workspace path `in /Users/jackson/...` and helper copy are extremely low contrast on grey cards. Set paths to `.caption` / `.secondary` minimum; never `.tertiary` on tinted card backgrounds in light mode.

10. **`26-task-detail-light.png`** — Trailing toolbar uses a grey filled circle with checkmark, which reads disabled and conflicts with sheet confirm pattern (`checkmark` + `.confirm` in accent). Use indigo confirm checkmark; keep complete action visually distinct from Cancel `xmark`.

11. **`26-task-detail-light.png`** — Attribute pickers (Status, Assignee, Priority) all render as indigo menu values, same as tappable links elsewhere. Show current value in `.primary` or `.secondary` and reserve accent for the control affordance (chevrons / `Picker` label), not every value string.

12. **`12-iphone-contact-light.png`** — Email and phone values are indigo like links though they may not navigate. Render values in `.body` / `.primary`; indigo only on “Message/Email” actions and explicit `Link` rows.

13. **`17-agent-info-light.png`** — Rainbow Settings-style squares for Identity/Memories/Usage mirror iOS Settings but detach from Atlas’s agent color thread. Use `SymbolIcon` with hues tied to agent color or a single neutral tile style used app-wide (Settings, Extensions, Agents).

14. **`44-extensions-light.png`** — Grey initial tiles (G, L, D…) look like placeholders vs branded `SymbolIcon` rows described for page lists. Replace with connector/extension glyphs on subtle gradients, or monochrome SF symbols at `.title3` semibold for parity with Workspace rows.

15. **`02-iphone-intelligence-light.png`** — Pinned avatar row plus inset “Agents” card duplicates the same entities with different containers and pin/unread cues only in one place. Either promote pinned agents solely in the grid (list = unpinned only) or drop the grid and use one inset list with pin badges—not both.

16. **`02-iphone-intelligence-light.png`** — “Scout” label appears washed out under its avatar compared to “Atlas,” breaking grid equality. Use `.footnote` / `.secondary` for all agent names under avatars at uniform opacity.

17. **`13-ipad-split-view-light.png`, `13b-ipad-agent-chat-light.png`, `13c-ipad-tasks-light.png`, `13d-ipad-actor-session-light.png`** — Orange “Needs you” toast overlaps the sidebar footer (Actors, Settings), clipping labels and implying broken layout. Pin toasts to the detail column or use compact banner inset that respects sidebar width.

18. **`13c-ipad-tasks-light.png`** — Task metadata (dates, avatars, size pills, tags, flags) spans the full 13" width, producing scan-line noise and weak title column alignment. Columnarize: title + one metadata line left, flag trailing; wrap tags on second line only when needed; max content width ~640pt centered.

19. **`03-iphone-workspace-light.png`, `02-iphone-intelligence-light.png`, `04-iphone-feeds-light.png`** — Title treatment varies (large “Intelligence”/“Feeds”, workspace name menu, no large title on Dashboard). Align tab roots: large title + trailing Settings on Intelligence/Feeds/Workspace; Dashboard stays greeting-led per spec.

20. **`08-iphone-journal-light.png`, `10-iphone-documents-light.png`** — Journal uses month section header + cards; Documents adds search and time-on-trailing rows—sibling workspace pages feel like different apps. Share one pattern: optional `.searchable`, consistent “Today / This week” headers in `.subheadline` uppercase or Apple's section header style, timestamps as trailing `.subheadline` `.secondary`.

21. **`01-iphone-dashboard-light.png`, `13-ipad-split-view-light.png`** — What's New titles ellipsize mid-thought while status sublines are small; session identity is unclear at a glance. Use two-line title at `.body` semibold, status in `.subheadline` `.secondary` (amber/red where semantic), defer truncation to subtitle.

22. **`06-iphone-actor-session-light.png`** — Nav title truncates the session name; “apple” repository label is microscopic under the title. Show full title on two lines in large inline mode, repo as `.caption` `.secondary` in the bar subtitle slot or first transcript metadata line.

23. **`07-iphone-tasks-light.png`** — Two tasks use different metadata grammar (one line vs pills + “waiting”). Standardize task row template: title, then one metadata row (due · assignee · tags) in `.subheadline`, size capsule only when set.

24. **`14-settings-light.png`, `44-extensions-light.png`** — Settings uses classic inset grouped list; Extensions uses one floating mega-card under large title—both are settings family but visually unrelated. Pick one: grouped inset for all settings descendants, or plain list with section headers matching Mac/iPad settings continuity.

25. **`34-article-light.png`** — Reader toolbar uses a tight cluster of circular glass buttons while other pushed views use leading back + trailing action groups; article feels attached to Safari, not Cohesion. Harmonize toolbar item spacing and roles with document/task sheets (back, share, more) without losing reader focus.

## What works

- **Dashboard greeting and glass composer** (`01-iphone-dashboard-light.png`, `13-ipad-split-view-light.png`) establish a native, product-specific entry point—not a generic list home—with Quick Journal and agent picker subordinate to the main field.
- **Semantic status in What's New** — Orange “Needs you,” red failure, and neutral “Done” icons give professionals scannable triage without reading every title.
- **Actor permission card** (`06-iphone-actor-session-light.png`, `13d-ipad-actor-session-light.png`) — Orange hand header, monospace command block, and indigo primary “Allow” make the one critical action obvious.
- **iPad sidebar agent roster** (`13-ipad-split-view-light.png`, `13b-ipad-agent-chat-light.png`) — Color per agent, selection pill, and team sublines match the web mental model while feeling at home on iPadOS.
- **Article reader typography** (`34-article-light.png`) — Serif body, clear “What got better” headings, and restrained code styling support long-form reading distinct from utility lists.

## To reach 9+

1. **One list architecture everywhere** — Implement design.md’s plain full-height lists on iPhone and iPad detail; retire short floating cards on Feeds, sparse Inbox, and Extensions unless they’re true widgets with intentional empty art.
2. **Navigation chrome contract** — Hide tab bar on all pushed routes; standardize tab roots (large title + settings) vs conversations (inline title, bottom composer inset); rebuild agent chat header to system nav conventions.
3. **Professional density on iPad** — Center and width-limit conversation and task content; reflow task metadata to two clear lines; eliminate full-bleed pill noise on `13c-ipad-tasks-light.png`.
4. **Typed metadata system-wide** — Enforce `.subheadline` + `.secondary` for dates/status, semantic orange/red only on status words, `.caption` minimum on cards—especially actor paths and dashboard failure lines.
5. **Single icon/row vocabulary** — Unify `SymbolIcon` gradient rows (workspace, settings subpages, extensions), agent grid/list duplication, and contact value colors so every list row reads as the same designed component family.
