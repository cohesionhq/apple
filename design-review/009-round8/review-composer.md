## Scores

| Category | Score | One-line reason |
| --- | ---: | --- |
| Native | 7.3 | Glass tab bar and grouped lists feel current, but pushed screens keep the tab bar and the Workspace tab replays navigation iOS already solves with a stack. |
| Typography | 7.4 | SF hierarchy is mostly right on dashboard and chat, yet metadata jumps between caption and subheadline and widgets truncate titles awkwardly. |
| Hierarchy | 6.9 | The composer and permission cards read clearly; Intelligence, Feeds, and the Workspace hub spread attention across duplicate entry points and empty canvas. |
| Spacing & density | 7.1 | Task and actor-session density suits a pro tool, but Feeds/Workspace leave huge dead zones and content visibly scrolls under the floating tab bar. |
| Color & contrast | 7.6 | Indigo, orange “needs you,” red failure, and agent hues are mostly coherent; flags, tab badges, and the Live Activity strip introduce extra semantics. |
| Iconography | 7.0 | SF Symbols and settings tiles read well, but agent marks mix emoji, initials, and symbols—and widget avatars break the in-app avatar language. |
| Consistency & polish | 6.6 | Shell patterns (titles, toolbars, tab visibility, status phrasing) shift between tabs, pushes, sheets, iPad, and extensions without feeling like one system. |
| Overall | 7.2 | A credible native professional app with moments of personality, not yet the tight, opinionated visual system an outsider would attribute to a dedicated product design pass. |

## Problems

1. **03-iphone-workspace-light.png**, **13-ipad-split-view-light.png** — The Workspace tab is a second app map (Today, Journal, Tasks, Views) beside Intelligence and the iPad sidebar, so users choose among three navigation models. **Fix:** Retire the tab as a folder list; make Workspace a true “Studio” surface (recents, pinned pages, connectors only) or fold those links into Dashboard + sidebar and free a tab slot.

2. **04-iphone-feeds-light.png** — The feed list sits in a single top card with most of the screen blank, so the tab feels like a stub, not a destination. **Fix:** Either use an undivided `List`/`ContentUnavailable`-style layout that breathes with content, or add a second pane (unread preview, last fetched) so the viewport earns its height.

3. **07-iphone-tasks-light.png**, **08-iphone-journal-light.png**, **10-iphone-documents-light.png**, **12-iphone-contact-light.png** — The floating tab bar stays visible on pushed stack screens, which reads web-like and steals vertical space from lists. **Fix:** Hide the tab bar on push (standard `TabView` + navigation stack behavior) and rely on back navigation; keep tabs only at the four roots.

4. **03-iphone-workspace-light.png**, **12-iphone-contact-light.png** — List rows and placeholders show through under the tab bar (“Launch this week,” “Press to…”), so layers feel unfinished. **Fix:** Add bottom safe-area padding to scroll content equal to tab bar height + margin, or clip scroll views above the bar.

5. **02-iphone-intelligence-light.png** — Pinned Atlas/Scout orbs plus a full Agents list duplicates the same entities and splits focus with the Actors section. **Fix:** One agents surface: pinned row *or* list with pin affordance; move “needs you” actors to a single accented strip at the top (orange), not a third section fighting the grid.

6. **01-iphone-dashboard-light.png**, **13-ipad-split-view-light.png** — The What’s New count appears as a tiny superscript “4,” easy to miss for a section that drives return visits. **Fix:** Put the count in the section header trailing slot as `.subheadline` `.secondary` (“4 updates”) or an unobtrusive capsule, matching Reminders/News patterns.

7. **02-iphone-intelligence-light.png** — The Intelligence tab uses a **red** “1” badge while in-app urgency is **orange** (“needs you”). **Fix:** Use orange (or split badge types: orange = needs you, indigo = unread message) and align copy with What’s New and Actors.

8. **05-iphone-agent-chat-light.png**, **13b-ipad-agent-chat-light.png** — The markdown table is tight and visually flat next to bubbles and cards; the last row sits under the composer. **Fix:** Table with `.footnote` in cells, 12–16pt horizontal inset, row dividers; add scroll padding above the glass input so the table never tucks under it.

9. **06-iphone-actor-session-light.png**, **13d-ipad-actor-session-light.png** — Allow / Deny / More are similarly weighted pills; Deny doesn’t read as secondary to Allow. **Fix:** Primary filled Allow (indigo), Deny as `.bordered` or plain label button, More as icon-only `.borderless`—matching permission sheets in Shortcuts and Screen Time.

10. **50-widget-agents-small-light.png**, **51-widget-agents-medium-light.png**, **52-widget-agents-large-light.png** — Avatars mix 3D-style emoji, a calendar graphic, and a letter “M,” unlike the disciplined agent discs in **02** and **13**. **Fix:** Same avatar rules as in-app (emoji at fixed optical size, initials semibold, symbols in `.symbol` rows)—no stock calendar emoji as agent identity.

11. **53-widget-tasks-small-light.png** — “Review the ro…” truncates mid-word in the smallest widget. **Fix:** `.caption` task title with `lineLimit(1)` and slightly narrower checkbox column, or show one task plus count instead of two half-lines.

12. **54-widget-tasks-medium-light.png**, **55-widget-tasks-large-light.png**, **56-widget-tasks-extralarge-light.png** — Overdue dates are **red** with orange flags while the in-app list (**07**, **13c**) uses relative labels (“Today,” “Tomorrow”) and red mainly for overdue dates. **Fix:** Mirror in-app date styling: `.caption` `.secondary` for future, orange label only when “needs you,” red only for overdue—same rules in widgets at every size.

13. **57-live-activity-lockscreen-light.png**, **58-live-activity-expanded-light.png** — The green / indigo / orange segmented bar at the bottom has no explained meaning beside row icons and conflicts with green = connected elsewhere. **Fix:** Drop the bar or replace it with a single line of text (“3 running · 1 needs you”); do not add a third color legend users must learn.

14. **14-settings-light.png** — Rainbow Settings-style tiles sit next to agent colors and status colors, so “color” means decoration and urgency at once. **Fix:** Desaturate server row icons to indigo-gray glyphs on `.quaternary` fills, or one hue family; reserve saturated agent and status colors for agents and live state only.

15. **26-task-detail-light.png** — “Set Size” appears indigo while other unset pickers read neutral gray, implying only that field is special. **Fix:** Unset value `.secondary` for all pickers; indigo only on the chevron/control chrome if you need accent, or on the active toggle only.

16. **44-extensions-light.png** — Letter-on-gray-gradient icons read as placeholders next to the polished agent and settings icons. **Fix:** Monochrome SF symbols per extension category, or real connector glyphs at 29×29 on `.secondarySystemGroupedBackground`—no faux app-icon gradients.

17. **01-iphone-dashboard-light.png** — The omnibox send control stays gray though the field is the screen’s main action; attachment and send compete visually. **Fix:** Enable send with indigo fill when text is non-empty; keep attachment `.tertiary` until content exists—same pattern as Messages.

18. **08-iphone-journal-light.png** — “Today” floats in its own lone card above “November 2026,” breaking chronological scanning. **Fix:** One grouped list: Today as first row under a “Recent” header, or merge into the month group with a stronger Today row style (`.headline` + preview subline).

19. **13c-ipad-tasks-light.png** — The detail column title “All” with only a chevron hides that this is a view switcher central to tasks. **Fix:** Visible `Picker` or breadcrumb (“Tasks › All”) in the toolbar; match **07**’s explicit “Inbox”/back pattern on iPhone.

20. **34-article-light.png** — Toolbar actions float as separate glass circles without the grouped rhythm of Mail/Safari reader. **Fix:** Standard trailing `ToolbarItemGroup` with shared material, or inline text actions for Share/Reload on iPad width.

21. **59-live-activity-compact-light.png** — Compact trailing ring segments (green/orange/indigo) plus orange “1” duplicate lock-screen semantics in a tiny glyph users won’t decode. **Fix:** Compact: app icon + orange dot or “1” only; reserve multi-segment rings for a defined “session mix” if you document it in the expanded UI.

22. **05-iphone-agent-chat-light.png** — User bubble is solid indigo while system cues use gray pills; long agent replies run full width with no max readable measure on iPad-wide content in **13b**. **Fix:** Cap agent text column width (~readable measure) on iPad; keep user bubbles indigo but agent body on `.background` with subtle inset card for multi-paragraph replies.

## What works

- The floating glass tab bar with indigo selection capsule (**01**, **02**, **03**, **04**) reads as intentional iOS 27 chrome without mimicking the web UI.
- What’s New status rows (**01**, **13**) tie orange / gray / red to clear verbs (“Needs you,” “Done,” “Failed”)—strong semantic copy.
- Actor permission UI (**06**, **13d**) centers the orange-bordered card and command block; the screen’s job is obvious.
- iPad sidebar agent list with team subtitles, pins, and Quill’s activity dot (**13**, **13b**, **13c**) is the app’s most “designed” navigation picture.
- Article reader (**34**) serif title, restrained metadata line, and inline code chips feel appropriate for long-form reading inside a work app.

## To reach 9+

1. **One navigation story** — Eliminate Workspace-as-directory, hide tabs on push, and align iPhone tabs with iPad sidebar so each destination has a single front door.
2. **Avatar and widget parity** — Enforce one agent disc system through home-screen widgets and Live Activity icons (no emoji drift, no calendar clip art).
3. **Intelligence/Dashboard redesign** — Collapse duplicate agent surfaces; make composer + “needs you” the unmistakable top-of-funnel on both form factors.
4. **Typography contract for metadata** — One scale for dates, status, and counts across tasks, What’s New, widgets, and LA (e.g. `.caption` `.secondary` dates, `.subheadline` orange only for “Needs you”).
5. **Strip ambiguous color chrome** — Remove or label Live Activity segment bars; unify tab badges and flags with orange/red/green rules already used in What’s New and actor sessions.
