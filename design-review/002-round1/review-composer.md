## Scores

| Category | Score | One-line reason |
| --- | ---: | --- |
| Native | 6.4 | Liquid Glass shows up on chrome and composers, but the persistent custom tab bar, mixed navigation titles, and tab bar on deep actor/chat flows fight standard iOS patterns. |
| Typography | 6.7 | SF scale is mostly correct and the article reader is strong, yet truncation, faint tertiary copy, and uneven title treatments undermine legibility. |
| Hierarchy | 6.1 | Dashboard and permission screens split attention across equally loud regions; chat and task lists bury the primary action in metadata noise. |
| Spacing & density | 6.5 | Grouped lists on Journal/Documents rhythm well, but Feeds and iPhone task lists feel hollow while iPad tasks and Intelligence feel overcrowded. |
| Color & contrast | 6.0 | Status semantics (orange/red/green) read in activity feeds, but Settings-style rainbow icons, chat blues, and tag confetti dilute indigo and agent color meaning. |
| Iconography | 7.0 | Thin SF Symbols and agent marks are clear; extension placeholders and mixed activity-row glyphs feel unfinished. |
| Consistency & polish | 5.9 | Back/done chrome, title placement, list containment, and when the tab bar appears vary screen to screen; one sheet still shows a layout bleed. |
| Overall | 6.3 | Credible native shell with moments of character, not yet the tight, semantic system a pro tool at award level would show. |

## Problems

1. **02-iphone-intelligence-light.png** — The last Actor rows sit under the floating tab bar and read as clipped/incomplete. Reserve bottom safe-area inset equal to tab bar height plus margin, or use scroll content margins on tab roots.

2. **06-iphone-actor-session-light.png, 13d-ipad-actor-session-light.png** — The four-tab bar remains visible during a high-stakes permission flow, competing with Allow/Deny and the follow-up field. Hide the tab bar on pushed session routes (or use a compact accessory) until the user dismisses the session.

3. **06-iphone-actor-session-light.png, 13d-ipad-actor-session-light.png** — “Run a command?” presents four buttons at similar visual weight (solid, outline, gray, red text). Make **Allow** the single filled `.borderedProminent` control; put “Allow for session”, “Deny”, and “Deny and stop” in a `Menu` or stacked `.bordered` secondary actions below.

4. **14-settings-light.png, 17-agent-info-light.png** — Multicolor gradient row icons read like a consumer utility app, not your indigo + agent semantic system. Use monochromatic SF Symbols in agent/accent tints (or agent-colored glyphs only on agent screens), with indigo for navigation affordances.

5. **05-iphone-agent-chat-light.png, 13b-ipad-agent-chat-light.png** — User bubbles read purple, links and status use bright blue, while the brand is indigo—three “active” hues in one thread. Map user messages to indigo (or Atlas’s agent color), links to `.tint`, and status dots to agent color or `.secondary`, consistently.

6. **03-iphone-workspace-light.png** — A ghost task row appears behind/under the tab bar, signaling z-order or preview/layout bleed. Ensure workspace lists do not render under the tab bar container and that pushed workspace children are full-screen without tab-root underlay.

7. **01-iphone-dashboard-light.png, 13-ipad-split-view-light.png** — What’s New titles truncate mid-thought (“rec…”, “k…”), wasting the dashboard’s main story. Allow two lines with `.lineLimit(2)` on titles; keep status on one line in `.subheadline` + semantic color.

8. **04-iphone-feeds-light.png** — One short card floating in a sea of empty background makes the tab feel like a stub, not a tool. Use full-height inset grouped list (like Workspace) or add section headers and recent-article previews to justify the space.

9. **13-ipad-split-view-light.png** — Dashboard detail is a narrow centered column with wide dead margins; on iPad this feels like a blown-up iPhone mock, not a designed split view. Left-align content to the split gutter with a readable max width (~640–720pt) and let What’s New use horizontal list rows or a second column for density.

10. **07-iphone-tasks-light.png, 13c-ipad-tasks-light.png** — Task rows pack title, date, assignee, size pill, tags, and flag into one visual band; on iPad it becomes illegible wallpaper. Standardize: title `.body`; one metadata line `.subheadline .secondary` (date · assignee); tags in a capped trailing stack (max 2 visible); flag only when non-default.

11. **08-iphone-journal-light.png** — `NOVEMBER 2026` in all-caps shouts over “Today” and fights iOS date styling. Use `.title3` or `.footnote` **Title Case** month grouping via formatted dates, not tracked caps.

12. **26-task-detail-light.png** — Nearly every value (Incomplete, You, Medium, Inbox) is indigo, so nothing reads as “set” vs “default” vs “destructive”. Labels `.primary`; values `.secondary` until tap target; indigo only on chevrons, active toggles, and editable controls.

13. **05-iphone-agent-chat-light.png, 13b-ipad-agent-chat-light.png** — Agent subtitle truncates in the header pill (“k…”), hiding role context. Either two-line `.subheadline` centered under the name or drop subtitle from chat chrome and rely on agent info.

14. **06-iphone-actor-session-light.png, 13d-ipad-actor-session-light.png** — Paths (`in /Users/...`), “Bash”, and session subtitle “apple” are too faint for professional use. Minimum `.footnote` with `.foregroundStyle(.secondary)`; never `.tertiary` on actionable context.

15. **12-iphone-contact-light.png** — Four indigo Phone-app actions (Message, Call, FaceTime, Email) imply system integrations; if not wired, they erode trust. Show only supported actions as prominent; demote or omit the rest with `.secondary` labels.

16. **34-article-light.png** — Source, fetch time, and author share one crowded metadata line. Stack: byline `.subheadline`; source link on its own line; “Fetched …” as `.caption` `.tertiary` below.

17. **44-extensions-light.png** — Gray initial squares look like wireframes beside polished agent avatars elsewhere. Use real service icons (same family as connectors) at 28–32pt in rounded rects with consistent padding.

18. **01-iphone-dashboard-light.png vs 02-iphone-intelligence-light.png vs 04-iphone-feeds-light.png** — Tab roots mix custom top bars (settings + workspace pill), large titles, and centered inline titles (Inbox, Journal). Pick one root pattern per tab: large title + trailing actions, or inline title—apply across Dashboard, Intelligence, Workspace, Feeds.

19. **02-iphone-intelligence-light.png** — Pinned Atlas/Scout labels are small and low-contrast under large circles. Use `.subheadline` `.semibold` under avatars and ensure 44pt minimum touch targets for the grid cells.

20. **13b-ipad-agent-chat-light.png** — The slot-picker card is flat gray and visually subordinate to body text though it’s the main interactive moment. Give interactive cards a clear glass edge, 16pt inner padding, and a tinted header bar using the agent color at low opacity.

21. **05-iphone-agent-chat-light.png** — Inline Markdown table stretches edge-to-edge and fights message margins. Inset tables in a rounded `.background(.quaternary)` container with horizontal padding matching bubble inset.

22. **07-iphone-tasks-light.png** — Inbox uses inline nav title with a heavy trailing pill of three tools; Documents/Journal use centered titles and simpler chrome. Align task list navigation with Documents: large/centered title or collapsible large title, filter in a single trailing menu.

## What works

- Dashboard greeting + glass composer and Atlas / Quick Journal pills feel like a deliberate home surface, not a generic list app (`01-iphone-dashboard-light.png`, `13-ipad-split-view-light.png`).
- What’s New status copy and color (Needs you / Done / Failed / New message) is immediately scannable and matches the product’s orange/red semantics (`01-iphone-dashboard-light.png`).
- iPad sidebar grouping (workspace pages, connectors, feeds) with a green connected dot on Settings reads as a serious pro layout (`13-ipad-split-view-light.png`, `13c-ipad-tasks-light.png`).
- Article reader serif body, code highlighting, and restrained chrome are the strongest “designed iOS” moment in the set (`34-article-light.png`).
- Agent avatars and per-agent color in Intelligence lists add personality without breaking list structure (`02-iphone-intelligence-light.png`, `17-agent-info-light.png`).

## To reach 9+

1. **Navigation contract** — Tab bar only on the four roots; hidden on chat, actor sessions, and sheet stacks; unify large vs inline titles and circular back/done buttons across all pushes.
2. **Color system enforcement** — Retire rainbow Settings icons; lock accent to indigo, agent discs to daemon colors, and orange/red/green to status only; audit chat links, toggles, and task fields for indigo overuse.
3. **Actor session focal layout** — Permission cards with one primary action, readable paths/commands, no tab bar, and a single bottom composer—treat it like an alert surface, not another tab.
4. **Task & metadata grammar** — One row template for iPhone and iPad (title, one secondary line, capped tags, semantic flag), applied in Inbox and All tasks so density scales without turning into badge soup.
5. **iPad content architecture** — Stop centering iPhone-width columns in split view; left-align primary content, use sidebar selection state (indigo fill) consistently, and allocate horizontal space for chat transcripts and task tables without truncation.
