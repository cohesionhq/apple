## Scores

| Category | Score | One-line reason |
| --- | ---: | --- |
| Native | 7.4 | Grouped lists, split view, and glass chrome read iOS 27, but Intelligence and iPad tasks feel like overloaded custom inventories beside first-party calm. |
| Typography | 7.0 | Large titles and reader serif land well; chat tables, task metadata, and widget truncation push too much into caption-scale secondary. |
| Hierarchy | 6.7 | Dashboard, permission cards, and agent chat have a focal point; Intelligence, iPad All tasks, and dense rows fight for attention at once. |
| Spacing & density | 6.9 | Card rhythm is mostly even, yet widgets leave dead space, Feeds/Extensions feel hollow, and iPad task rows pack badges without a scan line. |
| Color & contrast | 7.5 | Orange / red / green semantics are clear in What's New and actors; accent indigo sometimes colors chrome that should stay label-like. |
| Iconography | 7.1 | Workspace and status SF Symbols cohere; Extensions letter tiles and widget 3D emoji break the family next to flat agent discs. |
| Consistency & polish | 6.8 | Selection, section headers, toolbar clusters, and truncation differ screen to screen; round-5 widgets improved agents but tasks sizes still feel uneven. |
| Overall | 7.0 | A believable professional SwiftUI product with sprinkles of personality—not yet the tight, editorial finish of a shipped Apple-tier design. |

## Problems

1. **02-iphone-intelligence-light.png** — Three competing bands (pinned grid, long Agents list, Actors cards) with no single “do this next” story. **Fix:** Make Actors needing attention a hero strip (or first section) above the fold; collapse Agents to one scannable list with pinned as horizontal chips only when unread/needs-you; demote Teams to a toolbar action.

2. **13c-ipad-tasks-light.png**, **07-iphone-tasks-light.png** — Each row stacks title, date, assignee avatar, size capsule, multiple tags, and flag; the eye cannot find overdue or “needs you” in one pass. **Fix:** One metadata line max (due + assignee); move tags/size to swipe actions or detail; use `.subheadline` secondary for dates, reserve orange flag + bold date only for urgent/overdue.

3. **05-iphone-agent-chat-light.png**, **13b-ipad-agent-chat-light.png** — Markdown table and checklist use near-body sizes with tight leading, so the reply reads like a doc dump. **Fix:** Cap content width on iPad (~680pt), style tables as inset grouped mini-cards with `.footnote` headers, and separate “summary” prose from tabular data with section titles in `.title3` semibold.

4. **50-widget-agents-small-light.png** — Copy reads “Need you” (ungrammatical) under the count. **Fix:** Use “Need you” → “Need you” is wrong; correct string: “Need your attention” or “3 need you” matching medium/large; prefer `.headline` for count and `.subheadline` secondary for the phrase.

5. **50-widget-agents-small-light.png**, **51-widget-agents-medium-light.png**, **52-widget-agents-large-light.png** — Overlapping avatars mix flat initial “M”, 3D-style telescope/calendar emoji, and saturated discs without shared lighting. **Fix:** Match in-app `AgentAvatar` rules only—emoji or glyph at fixed disc scale, no photographic emoji assets; align overlap offset and stroke to one spec across sizes.

6. **44-extensions-light.png** — Gray squares with single letters read like a debug list, not a marketplace. **Fix:** Connector-provided glyphs or SF Symbol by category (`.puzzlepiece.extension`, repo, calendar) in `.fill` at 22pt on tinted rounded rects using each extension’s brand hue at low saturation—not neutral gray boxes.

7. **55-widget-tasks-large-light.png**, **56-widget-tasks-extralarge-light.png** — Large and extra-large layouts leave a tall empty bottom while only five rows show. **Fix:** On large sizes, show more tasks or add a second column / grouped “Overdue” block; tune `contentMargins` so header-to-first-row spacing matches inter-row rhythm (WidgetKit `containerBackground` + consistent 12pt grid).

8. **53-widget-tasks-small-light.png**, **54-widget-tasks-medium-light.png** — Titles truncate (“Review the ro…”) while flags and dates misalign row to row. **Fix:** Single-line `.lineLimit(1)` with tail truncation only after prioritizing layout; pin flags in a fixed trailing column; use `.minimumScaleFactor(0.9)` before ellipsis on small.

9. **04-iphone-feeds-light.png** — One short card on a tall canvas; “Feeds” large title then vast gray field. **Fix:** Add recents/unread preview rows under the list or collapse to compact grouped style with `.contentMargins` reduced; consider a second section “Latest” with article titles to earn the tab.

10. **03-iphone-workspace-light.png** — Every row uses the same indigo glyph weight; Workspace reads as monochrome utility, not a designed hub. **Fix:** Keep indigo for navigation affordance but vary symbol style (outline vs fill) by section; use `.secondary` for folder/list icons and accent only for “Today” and primary destinations.

11. **13-ipad-split-view-light.png**, **13b-ipad-agent-chat-light.png** — Sidebar uses filled indigo pill for Dashboard and a different filled treatment for selected Atlas; two selection languages on one chrome. **Fix:** One pattern everywhere—either `List` selection background + leading accent bar, or uniform capsule; agent selection should mirror sidebar nav, not a second highlight shape.

12. **01-iphone-dashboard-light.png**, **13-ipad-split-view-light.png** — Composer + Atlas / Quick Journal chips sit between greeting and What's New without clear primary vs secondary; chips compete with the text field send affordance. **Fix:** One primary composer; secondary actions as `.bordered` or menu under the field; Quick Journal as trailing accessory, not equal pill.

13. **06-iphone-actor-session-light.png**, **13d-ipad-actor-session-light.png** — Navigation title truncates (“Add backoff to the change …”); permission card is strong but the session identity is lost. **Fix:** `LineLimit(2)` subheadline title with repo on second line; or marquee only in nav subtitle `.caption` secondary; keep full title visible in content header.

14. **26-task-detail-light.png** — Destructive/primary chrome mixes indigo on the close control and toggles while status reads muted gray. **Fix:** In app shell, toolbar buttons label-colored; reserve accent for “Due Date” on state and primary completion; “Set Size” as `.foregroundStyle(.secondary)` link style, not accent blue.

15. **34-article-light.png** — Reader personality is good, but metadata stack (author, domain, fetched) has weak separation from title. **Fix:** Title `.title` bold; meta line single `.subheadline` secondary with middot separators; domain link accent; “Fetched…” as `.caption` tertiary below a hairline.

16. **08-iphone-journal-light.png** — “Today” floats in its own card while November entries sit below, splitting “current” journal from archive awkwardly. **Fix:** Merge Today into the dated list as first row with “Morning” subtitle, or style Today as inset hero only when empty; one continuous timeline metaphor.

17. **12-iphone-contact-light.png** — Hero avatar and four indigo actions dominate; contact fields feel like an afterthought on a tall sheet. **Fix:** Shrink action row to `.caption` labels with 44pt hit targets; pull email/phone up under name; Notes as expandable section; match Contacts.app proportions.

18. **57-live-activity-lockscreen-light.png**, **58-live-activity-expanded-light.png** — Bottom segmented green/purple/orange bar lacks a legend and competes with per-row status. **Fix:** Remove or replace with a single summary (“3 running · 1 needs you”); if kept, match segment order to row sort and add accessibility labels; donumb segment count to ≤3 states users already know.

19. **59-live-activity-compact-light.png** — Trailing ring with “3” is attractive but ambiguous (sessions? agents? unread?). **Fix:** Use compact leading agent/actor glyph + trailing orange dot when any need you; ring only when multiple active and no attention required.

20. **14-settings-light.png**, **17-agent-info-light.png** — Settings uses uppercase section headers; agent sheet uses mixed case—fine individually but adjacent products feel like different apps. **Fix:** Standardize on iOS 27 `.headerProminence` sentence case section headers everywhere; same grouped inset corner radius and inter-section gap (24pt).

## What works

- **Dashboard greeting + What's New (01, 13)** — Semantic orange/red/green with hand/check/X icons makes actor and agent activity scannable without reading every title.
- **Actor permission card (06, 13d)** — Orange “needs you” framing, command preview, and Allow/Deny hierarchy are exactly how a pro tool should interrupt the user.
- **Agent chat voice (05, 13b)** — Indigo user bubbles, inline choices, and checklists give personality beyond a generic chat wrapper while staying native.
- **Article reader (34)** — Serif body and restrained chrome differentiate Feeds from workspace lists without breaking iOS reader expectations.
- **Agents widgets medium/large (51–52)** — Overlapping discs plus named “need you” copy is glanceable and on-brand once avatar assets align with the app.

## To reach 9+

1. **Redesign Intelligence hierarchy (02)** — One attention-first layout: needs-you actors up top, pinned agents as a single scannable row, everything else behind progressive disclosure.
2. **Simplify task row grammar app-wide (07, 13c, widgets 53–56)** — One metadata rule (due, assignee, one flag), shared trailing column, and widget layouts that fill each size without truncation or dead space.
3. **Constrain and typographically stage agent chat content (05, 13b)** — Max width, table/footnote system, and clear “answer / evidence / next step” blocks so Markdown never overwhelms the conversation.
4. **Unify iPad chrome and selection (13, 13b, 13c, 13d)** — One sidebar selection model, consistent detail column width, and session titles that stay readable in the nav bar.
5. **Finish the extension surface + widget icon system (44, 50–52)** — Replace placeholder letter tiles and mismatched emoji with the same avatar/disc language as agents, and polish widget copy, alignment, and density through every size class.
