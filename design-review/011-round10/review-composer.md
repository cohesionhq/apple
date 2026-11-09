## Scores

| Category | Score | One-line reason |
| --- | ---: | --- |
| Native | 7.3 | Grouped glass cards and SF chrome read iOS 27, but the persistent custom tab bar, floating tool clusters, and sheet-heavy IA feel more “Cohesion UI kit” than stock HIG in places. |
| Typography | 7.4 | Large titles and chat Markdown are strong; list metadata, feed bylines, and widget truncations sit too close in weight and size to titles. |
| Hierarchy | 6.8 | Home and permission moments are clear; task rows, Intelligence, and Feeds flatten everything to one band of equal-importance text. |
| Spacing & density | 6.7 | Card rhythm is mostly even, yet the bottom tab bar eats list tails and iPad task rows stretch into low-signal whitespace. |
| Color & contrast | 7.1 | Indigo / orange “needs you” / red failure / green connected show up often, but red also marks overdue tasks and flags, diluting the language. |
| Iconography | 6.9 | In-app SF Symbols and agent discs work; widgets and some avatars jump to 3D emoji and Settings-style rainbow tiles. |
| Consistency & polish | 6.5 | Section headers, toolbars, task metadata, and navigation chrome shift dialect screen to screen. |
| Overall | 6.9 | Credible professional beta with personality, not yet the tight, single-authored system an ADL-level ship implies. |

## Problems

1. **01-iphone-dashboard-light.png, 02-iphone-intelligence-light.png, 07-iphone-tasks-light.png, 08-iphone-journal-light.png** — The floating tab bar covers the last grouped rows (e.g. What’s New item 4, the second Actor card). **Fix:** Add a bottom scroll content inset matching the tab bar height (or adopt the system tab bar placement) so the final row clears the glass pill with ~8pt breathing room.

2. **07-iphone-tasks-light.png, 13c-ipad-tasks-light.png, 54–56-widget-tasks-*.png** — Task title, due date, assignee avatar, size pill, `#tag`, and flag all read as one horizontal band. **Fix:** Two-line row only—title `.body` semibold, one `.subheadline` secondary line for due · assignee · size; pin flag and overdue to the trailing edge in a fixed 44pt column.

3. **54-widget-tasks-medium-light.png, 55-widget-tasks-large-light.png, 56-widget-tasks-extralarge-light.png** — Past-due dates use **red**, which your product maps to **failed**, not lateness. **Fix:** Show overdue in `.secondary` with an orange dot or “Overdue” `.caption` in orange; reserve red for failure states (actor/session errors).

4. **07-iphone-tasks-light.png, 13c-ipad-tasks-light.png** — Orange flags read like “needs you,” which elsewhere is the open-hand / orange label pattern. **Fix:** Use indigo-tinted flags (or neutral gray fill) for priority; keep orange exclusively for attention/blocking states.

5. **02-iphone-intelligence-light.png** — Pinned agent circles float above an unrelated “Agents” list with different label sizes and no shared container. **Fix:** One “Agents” section: horizontal pinned strip (44pt discs + `.caption2` names) on top of the grouped list, or merge pins as the first rows with the same row height as Ledger/Relay.

6. **02-iphone-intelligence-light.png** — Section headers “Agents” / “Actors” use faint all-caps gray while **03-iphone-workspace-light.png** uses bolder “Tasks” / “Views.” **Fix:** Standardize on one list header style—`.footnote` uppercase secondary with 16pt top padding before each inset group.

7. **04-iphone-feeds-light.png** — Title, author, source, unread dot, “Not Fetched,” and time compete on two tight lines; one title ellipsizes against orange status. **Fix:** Line 1: title `.body` + trailing time `.caption` tertiary; line 2: author · feed `.subheadline` secondary; unread = 6pt indigo dot on the title baseline; “Not Fetched” only as `.caption` orange, never inline mid-title.

8. **05-iphone-agent-chat-light.png, 13b-ipad-agent-chat-light.png** — The task table is cramped and clips above the composer; poll/options and checklist blocks lack vertical separation from prose. **Fix:** On iPhone, replace wide tables with stacked mini-cards (task / due / owner); add 20pt section gaps before interactive blocks; use `.headline` only for agent section titles, not every bold span in Markdown.

9. **06-iphone-actor-session-light.png, 13d-ipad-actor-session-light.png** — “Run a command?” is the right hero, but Allow / Deny / `…` sit as three peer pills with unequal prominence. **Fix:** Full-width **Allow** `.borderedProminent` (indigo), **Deny** as `.borderless` destructive below or beside at equal height, overflow in the card top-trailing `…` only—drop the third circle button.

10. **01-iphone-dashboard-light.png** — Atlas chip (indigo border + agent color) and “Quick Journal…” share the same pill language as primary navigation. **Fix:** Keep Atlas as the only tinted chip; render Quick Journal as `.gray` bordered tertiary or a trailing toolbar “Journal” SF Symbol on the composer card.

11. **03-iphone-workspace-light.png** — “Studio” large title with palette emoji reads consumer/playful vs the sober lists below. **Fix:** Large title plain “Studio”; show workspace glyph only in the menu chevron row or sidebar, not in the navigation title slot.

12. **10-iphone-documents-light.png** — Timestamps sit on the same baseline as titles, hurting scan-by-name. **Fix:** Title `.body` on line 1; relative time `.caption` tertiary right-aligned or on line 2 under the title, matching Documents/Journal patterns.

13. **08-iphone-journal-light.png** — “November 2026” floats in the margin between two cards. **Fix:** Attach as `Section` header to the month group (`.footnote` secondary) with 8pt gap to the inset card, same as Documents’ “This Week.”

14. **12-iphone-contact-light.png** — Four indigo Communication actions mirror Contacts.app but dominate a sparse record. **Fix:** If actions aren’t fully native, collapse to one primary row (email tappable + copy) and secondary phone; use `.title2` for the name, `.subheadline` for employer in Notes only.

15. **14-settings-light.png, 17-agent-info-light.png, 44-extensions-light.png** — Rainbow rounded-square icons differ from the restrained indigo + agent-color language in the main app. **Fix:** Monochrome SF Symbol on `Color.accentColor.opacity(0.15)` circle in-app; reserve multi-hue tiles for true third-party brands (Extensions) only.

16. **50–52-widget-agents-*.png** — Widget avatars use 3D emoji (telescope, JUL calendar) while in-app agents use flat colored discs. **Fix:** Rasterize the same `AgentAvatar` at widget sizes; no emoji assets that don’t appear in **02** / **13b**.

17. **50-widget-agents-small-light.png, 51-widget-agents-medium-light.png** — “need you” is lowercase and disconnected from the brand phrase “Needs you.” **Fix:** Sentence case **Needs you** in `.subheadline` secondary; count uses `.title` semibold with tighter spacing to the avatar stack.

18. **53-widget-tasks-small-light.png** — “Review the ro…” truncates ugly in the smallest slot. **Fix:** Show one full title + “+8 more” summary, or `.minimumScaleFactor(0.85)` with a single line—never mid-word chop on the hero task.

19. **57–58-live-activity-*.png** — Header glyph counts (hand 1, loop 2, check 3) and the bottom tri-color bar have no learned meaning on first glance. **Fix:** Replace the bar with labeled chips (“1 needs you · 2 running · 3 done”) or drop the bar; use the open-hand SF Symbol consistently with in-app “Needs you.”

20. **59-live-activity-compact-light.png** — Compact shows orange **1** without a shape hint at glance distance. **Fix:** Pair indigo app glyph with a tiny orange hand badge (or orange ring segment + hand, not bare numeral).

## What works

- **01-iphone-dashboard-light.png** — Greeting, composer, and What’s New form a believable “open the app and work” landing; status lines (Needs you / Done / Failed) are immediately readable.
- **06-iphone-actor-session-light.png** — Orange-bordered permission card correctly hijacks attention in a dense technical transcript.
- **34-article-light.png** — Serif article title, restrained metadata, and inline code chips feel editorial and native without mimicking the web app.
- **13-ipad-split-view-light.png** — Sidebar + canvas gives a serious iPad productivity frame; agent colors and actor urgency survive the layout scale-up.
- **05-iphone-agent-chat-light.png** — Indigo user bubbles and structured agent replies (lists, code, links) deliver distinct product personality inside a familiar chat pattern.

## To reach 9+

1. **One task row grammar** across **07**, **13c**, and **53–56**: title + single metadata line + fixed trailing due/priority/attention—no third line of chips unless the sheet is open.

2. **Lock semantic color**: orange = needs you only; red = failed/error only; green = connected/success; overdue = typographic/secondary treatment, not red wash.

3. **End the tab-bar overlap class of bugs** on every stacked list (**01**, **02**, **07**, **08**, workspace drill-ins) via consistent bottom safe area/insets.

4. **Single avatar renderer** from Intelligence through widgets (**50–52**) and Live Activity (**57–59**) so agent identity doesn’t change surface-to-surface.

5. **Collapse UI dialects** to two toolbar patterns (root large-title + trailing menu vs pushed inline title + back) and one section-header style, retiring one-off centered titles (**13c**) and mismatched header weights (**02** vs **03**).
