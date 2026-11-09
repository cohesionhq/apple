## Scores

| Category | Score | One-line reason |
| --- | ---: | --- |
| Native | 7.0 | Liquid Glass tab bar and inset lists land, but the tab bar on pushed screens and Feeds’ disconnected card fight standard iOS navigation and list patterns. |
| Typography | 7.3 | SF hierarchy is mostly sound and the article serif is a nice touch, yet task metadata, widgets, and actor logs swing between too small and too dense. |
| Hierarchy | 6.5 | Strong moments (dashboard composer, permission card) are undercut by empty Inbox/Feeds canvases and crowded iPad task rows with no clear scan path. |
| Spacing & density | 6.2 | Extreme empty zones on iPhone list screens sit next to over-packed task metadata and actor transcripts without a coherent rhythm. |
| Color & contrast | 7.5 | Indigo accent and orange/red/green semantics mostly read, but gray “Needs you” on widgets, rainbow Settings icons, and priority flags vs actor orange blur meaning. |
| Iconography | 6.8 | SF Symbols are consistent in chrome, while agent discs mix 3D emoji, initials, and glyphs and Extensions use anonymous letter tiles. |
| Consistency & polish | 6.4 | Toolbar controls alternate circles vs pills, greetings differ iPhone/iPad, and preview-only indigo bar items risk judging the wrong product. |
| Overall | 6.9 | Clearly a real native app with intent, not yet the tight, opinionated whole a pro would attribute to a single design system. |

## Problems

1. **`07-iphone-tasks-light.png`, `04-iphone-feeds-light.png`** — Two tasks (or five feed rows) float in a single inset card while ~70% of the canvas is blank, so the screen reads “empty prototype” not “inbox.” **Fix:** Use a full-height `List`/`ScrollView` with standard section insets; show a designed empty state only when count is zero, otherwise let rows extend to the tab bar with consistent horizontal margins matching Journal/Documents.

2. **`07-iphone-tasks-light.png`, `08-iphone-journal-light.png`, `10-iphone-documents-light.png`, `12-iphone-contact-light.png`** — The tab bar remains visible on pushed workspace routes, stealing vertical space and breaking the usual “tabs = top level only” model. **Fix:** Hide `tabBar` on `WorkspaceRoute` pushes (as Intelligence already does for chat/sessions) or move Today/Journal/Documents/Contacts/Tasks under a single stack without persistent tabs.

3. **`04-iphone-feeds-light.png`** — The feed list occupies the top third; the rest is flat background with no secondary content or affordance. **Fix:** Either stretch the grouped list to fill with `.contentMargins` / scroll edge, or add a purposeful bottom zone (last refreshed, OPML, reading stats)—not dead air.

4. **`52-widget-agents-large-light.png`, `51-widget-agents-medium-light.png`** — Status copy “Needs you” for Milo/Juno is **gray**, not orange, so widget color language disagrees with Dashboard and Live Activity. **Fix:** Render “Needs you” in `.orange` (or orange `.secondary` at minimum); reserve gray for neutral activity strings.

5. **`50-widget-agents-small-light.png`** — Label reads “3” + lowercase “need you,” unlike Title Case elsewhere (“Needs you · 2m ago”). **Fix:** Use `3 need you` → **`3 Need You`** or a full sentence matching medium/large widgets for voice consistency.

6. **`53-widget-tasks-small-light.png`** — First task truncates to “Review the ro…”. **Fix:** Single-line `.minimumScaleFactor` only as last resort; prefer smaller `.subheadline` or a shorter preview field from the model; ensure 2-line small widget layout respects ~38pt readable width.

7. **`54-widget-tasks-medium-light.png`, `55-widget-tasks-large-light.png`, `56-widget-tasks-extralarge-light.png`** — Rows without dates/flags (e.g. “Plan the offsite”) are shorter than peers, so the list rhythm wobbles. **Fix:** Reserve a fixed metadata baseline (invisible placeholder or `Spacer(minLength:)`) so every row shares the same vertical metrics.

8. **`05-iphone-agent-chat-light.png`, `13b-ipad-agent-chat-light.png`** — Markdown **table** and wide code blocks sit flush in the transcript with no horizontal containment; on iPhone this will feel broken. **Fix:** Wrap tables in a rounded, horizontally scrollable card (muted grouped background, monospaced grid) matching the article reader’s code treatment.

9. **`05-iphone-agent-chat-light.png`** — The cue strip (“Cue ‘Morning briefing’ fired…”) competes with the nav title for attention and reads as a second nav bar. **Fix:** Demote to a single `.footnote` / `.caption` row below the agent header, or a collapsible “Activity” chip—not full-width banner under the status area.

10. **`06-iphone-actor-session-light.png`, `13d-ipad-actor-session-light.png`** — Code blocks truncate mid-token (`Durat`, `atte`), which looks like a rendering bug. **Fix:** Enable horizontal scroll inside code containers with visible fade/scroll indicator, or wrap at sensible boundaries with syntax-aware layout.

11. **`06-iphone-actor-session-light.png`** — Permission card is strong, but **Allow** (indigo) and **stop** (red square) plus spinning ring create three competing primaries at the bottom. **Fix:** Keep Allow as the only filled accent; make Stop `.bordered` destructive; ring as `.secondary` progress only.

12. **`02-iphone-intelligence-light.png`, `13-ipad-split-view-light.png`** — Pinned Atlas uses a **photographic/3D compass** while Scout uses a flat initial; list rows use flat glyphs. **Fix:** One avatar grammar everywhere (flat symbol or initial at 0.5× disc, per your own avatar rules)—no mixed emoji renders in product UI.

13. **`01-iphone-dashboard-light.png`, `13-ipad-split-view-light.png`** — Greeting copy differs (“Good morning” vs “Let’s get going”) without a product reason showing in UI. **Fix:** Pick one voice rule (time-based greeting vs action greeting) and apply on both form factors.

14. **`13-ipad-split-view-light.png`** — “New message · 25m ago” uses a **purple hand** icon, which is not in the orange/red/green semantic set and reads as a fourth status color. **Fix:** Unread agent traffic → accent dot or agent color on the row; reserve orange for user-blocking states only.

15. **`13c-ipad-tasks-light.png`, `07-iphone-tasks-light.png`** — Task subtitles pack date, avatar, agent, tags, and list name into one `.caption` line with multiple hues; scan cost is high. **Fix:** Two-tier metadata: line 1 due + assignee (`.subheadline` `.secondary`); line 2 tags/list (`.caption`); cap at 2–3 chips then “+N”; align flag and circle on a grid.

16. **`14-settings-light.png`, `17-agent-info-light.png`** — Saturated **multi-color** row icons (Settings salad, agent sheet) clash with the restrained indigo + semantic chrome elsewhere. **Fix:** Monochrome SF Symbol on `secondarySystemGroupedBackground` circle with optional agent color only on agent rows—or indigo template icons app-wide for settings-style surfaces.

17. **`26-task-detail-light.png`** — **“Set Size”** in accent color looks like the main CTA amid gray field values; **Done** in the bar is disabled with no obvious next step. **Fix:** Unset fields use `.secondary` “None” / “Add size”; reserve accent for toggles and real actions; enable Done when minimally valid or remove until editable.

18. **`44-extensions-light.png`** — Gray gradient **letter avatars** feel like placeholders; version badges (`v4`) float between title and chevron without alignment. **Fix:** Connector brand marks or single-weight symbols; pin version as `.caption2` `.tertiary` under title, right-aligned as a column.

19. **`03-iphone-workspace-light.png`** — “Cancelled” row is **clipped** by the tab bar. **Fix:** `.safeAreaInset(edge: .bottom)` on scroll content equal to tab bar height, or hide tab bar on this hierarchy.

20. **`07-iphone-tasks-light.png`, `10-iphone-documents-light.png`** — Toolbar uses **pill-grouped** controls on tasks but **separate glass circles** on documents/back navigation screens. **Fix:** Standardize on one pattern per context (split view uses grouped trailing items; iPhone push uses circular bar items only).

21. **`57-live-activity-lockscreen-light.png`, `58-live-activity-expanded-light.png`** — Bottom **tri-color bar** has no legend; users cannot tell green vs indigo vs orange segments. **Fix:** Tie segments to labeled counts in the header only and drop the bar, or add accessibility labels and match segment order to the row list.

22. **`12-iphone-contact-light.png`** — Contact reads as stock Contacts: all four actions indigo, tab bar still showing, no Cohesion link to tasks/messages with agents. **Fix:** At minimum hide tab bar and tint only the primary action; optionally add a “In Cohesion” section (linked tasks, last agent mention) for product personality.

## What works

- **Dashboard + iPad home (`01`, `13`)** — Greeting, composer, and “What’s New” with orange/gray/red status lines give a distinctive entry that still feels iOS-native.
- **Actor permission card (`06`, `13d`)** — Orange border, hand icon, command block, and Allow/Deny hierarchy make “needs you” impossible to miss.
- **Article reader (`34`)** — Serif body, comfortable measure, inline code pills, and fenced blocks deliver a deliberate reading mode worth keeping.
- **iPad split structure (`13`, `13b`, `13c`, `13d`)** — Sidebar order (workspace → agents → actors) and indigo selection on Atlas/Tasks match how pros expect a workspace tool on iPad.
- **Live Activity compact (`59`)** — Indigo mark plus segmented ring and orange count communicate state at a glance without clutter.

## To reach 9+

1. **Kill the “empty ocean” list pattern** — Refactor Inbox, Feeds, and similar screens to full-height lists with real empty states only when counts are zero (`04`, `07`).
2. **Unify navigation chrome** — Hide the tab bar on workspace pushes and align toolbar geometry (circles vs pills) across tasks, documents, journal, contacts (`07`, `08`, `10`, `12`, `19`).
3. **Lock semantic color globally** — Orange always means user action required (widgets, flags copy, actor rows); stop gray “Needs you” and ad hoc purple status icons (`52`, `13` iPad row).
4. **One agent avatar system** — Flat discs with consistent glyph sizing from Intelligence through widgets and Live Activity (`02`, `50–52`, `13b`).
5. **Task metadata redesign** — Fixed two-line grid on iPhone and iPad, calmer caption scale, aligned flags/dates so dense pro data scans like Reminders/Omni, not a tag cloud (`07`, `13c`, widgets `54–56`).
