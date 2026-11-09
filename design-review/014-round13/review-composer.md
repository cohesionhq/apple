## Scores

| Category | Score | One-line reason |
| --- | --- | --- |
| Native | 6.7 | Inset groups and materials land, but a persistent floating tab bar on pushed lists and uneven large-title behavior fight standard iOS navigation. |
| Typography | 7.0 | SF is mostly correct; task rows, feed metadata, and widget footers collapse too many weights/sizes into one band. |
| Hierarchy | 6.4 | Actor permission and dashboard composer read clearly; Tasks, All tasks, and Intelligence bury the primary scan line under badges and dates. |
| Spacing & density | 6.6 | Dashboard and sheets breathe, but list screens and widgets swing between wasted vertical space and overcrowded metadata rails. |
| Color & contrast | 7.1 | Indigo/orange/red semantics work for “needs you” and failure; priority flags and orange overload on Tasks dilute meaning. |
| Iconography | 6.8 | Agent discs and SF Symbols hold together; Extensions monograms, widget “emoji” avatars, and mixed flag colors feel like a second family. |
| Consistency & polish | 6.2 | Navigation chrome (title size/position, toolbar capsules, tab visibility) changes screen to screen without a deliberate pattern. |
| Overall | 6.7 | Credible native product with character, but not yet a single visual system a reviewer would call fully art-directed. |

## Problems

1. **01-iphone-dashboard-light, 13-ipad-split-view-light** — The greeting and “Due” compete with the glass composer for top-of-screen dominance; “What’s New” is cut by the iPhone tab bar. **Fix:** Treat the composer as the sole hero (one max width, fixed vertical slot); move “Due” under a tighter `.headline` section with `.subheadline` count; on iPhone use bottom safe-area inset so the last section scrolls fully above the tab bar.

2. **01-iphone-dashboard-light, 02-iphone-intelligence-light, 03–08, 04, 10, 12 (iPhone pushes)** — The four-tab floating pill remains on detail screens (Tasks, Journal, Documents, Contact), implying tabs switch context instead of “back within Workspace.” **Fix:** Hide the tab bar when `navigationPath` is non-empty; use standard push with `.navigationBarTitleDisplayMode(.large)` only on tab roots.

3. **03-iphone-workspace-light** — “Launch this week” ghosts under the tab bar, signaling broken scroll insets. **Fix:** Apply `safeAreaInset(edge: .bottom)` for the tab bar height on all grouped lists; verify `contentMargins` on iOS 17+ list styles.

4. **02-iphone-intelligence-light, 05-iphone-agent-chat-light** — Pinned Atlas/Scout use faint gray captions under large discs while list agents use bold titles; two different “agent” row languages on one tab. **Fix:** One pinned pattern: `.title3` name in `.primary`, team in `.subheadline` `.secondary`; list rows match iPad sidebar density.

5. **07-iphone-tasks-light, 13c-ipad-tasks-light, 54–56-widget-tasks-*** — Each row stacks title, date, assignee avatar, size pill, folder, waiting state, and flag—professional tools still need one primary secondary line. **Fix:** Line 1: title + completion control; line 2: single metadata chip row (due + assignee only); move size/tags to task detail or swipe actions; align iPad trailing columns to a 3-column grid (due | assignee | priority).

6. **07-iphone-tasks-light, 13c-ipad-tasks-light, 55-widget-tasks-large-light** — Flag colors (orange, indigo, purple, red, gray) don’t read as one priority system next to orange “needs you” elsewhere. **Fix:** Map priority to fixed glyphs in `ProtocolPresentation`—e.g. high = indigo flag fill, medium = outline, low = hidden; reserve orange exclusively for blocked/needs-you on tasks, not priority.

7. **04-iphone-feeds-light** — Headline, source, and timestamp fight the same visual band; unread dot + chevron add leading/trailing noise. **Fix:** Title `.body` semibold; source `.subheadline` `.secondary` on line 2; timestamp `.caption` `.tertiary` trailing on line 1 only; shrink chevron or use full-row tap without disclosure on feeds.

8. **05-iphone-agent-chat-light, 13b-ipad-agent-chat-light** — User bubbles, system cards, cue pills, and Markdown tables use different corner radii and padding; the table reads like pasted web. **Fix:** Define two message containers only—`AgentBlock` (full width, material) and `UserBubble` (indigo fill); tables use inset `.grouped` mini-cards with `.caption` header row and horizontal scroll on iPhone.

9. **06-iphone-actor-session-light, 13d-ipad-actor-session-light** — Log lines mix verb weight, timestamps, and checkmarks without a consistent column; permission card is strong but the stop control reads as destructive for “pause.” **Fix:** Two-column log grid (action + path | duration); timestamps `.caption2` `.tertiary` monospaced; style stop as `.bordered` secondary with square icon, red only on confirm.

10. **08-iphone-journal-light, 10-iphone-documents-light** — Journal uses centered inline “Journal” while Documents uses large title + search; Documents section headers (“Today”) compete with row titles. **Fix:** Workspace drill-downs share one pattern: large title + optional search; section headers `.footnote` `.secondary` uppercase or small caps with extra top padding only.

11. **12-iphone-contact-light** — Action buttons (Message/Call/FaceTime/Email) are indigo labels without filled prominence; contact sheet shows tab bar behind a person detail. **Fix:** Use `ContactActionButton` with symbol + `.subheadline` under circular `.ultraThinMaterial` wells; present without tab bar; email/phone as tappable rows only (actions duplicate row taps).

12. **14-settings-light, 17-agent-info-light, 44-extensions-light** — Settings uses saturated rounded squares per row; Extensions uses anonymous gray letter tiles—both break agent/semantic coloring rules from Intelligence. **Fix:** Settings icons: single indigo template on `.quaternary` fill, or agent-color only where row is agent-specific; Extensions use connector brand marks or one indigo puzzle glyph + name, not monogram placeholders.

13. **26-task-detail-light** — “Set Size” in indigo looks like primary CTA amid gray pickers; incomplete check in toolbar is visually weaker than close. **Fix:** Unset optional fields use `.secondary` “Add size” link style; primary sheet action is Mark complete (trailing, `.borderedProminent` when dirty).

14. **34-article-light** — Reader toolbar uses isolated circular glass buttons while Feeds uses a capsule cluster; serif body is excellent but metadata line is long and low-contrast. **Fix:** Unify reader toolbar with Feeds refresh/share/more capsule; break metadata into two lines (author · date | source · fetched) at `.subheadline` / `.caption`.

15. **13-ipad-split-view-light, 13b, 13c, 13d** — Sidebar selection (indigo capsule on Atlas/Tasks) vs content title (“All” with menu) doesn’t echo; three-column dashboard right rail duplicates Intelligence states in weaker typography. **Fix:** Selection drives detail title (“Tasks › All”); right column uses same row component as `What's New` on iPhone with icon + title + `.caption` status color tokens.

16. **50–52-widget-agents-*, 51-widget-agents-medium-light** — Overlapping header avatars use 3D telescope/calendar while in-app agents use flat discs; small widget “3 need you” vs medium “2” breaks trust. **Fix:** Widget avatars reuse `AgentAvatar` rendering only; header stack is decorative at `.accessory` size; copy always `N need you` tied to list rows below.

17. **53-widget-tasks-small-light** — Truncated “Review the ro…” with oversized circles wastes the only two lines. **Fix:** `.lineLimit(1)` with smaller leading control; prefer one full task title over two clipped; show count in header only.

18. **54–56-widget-tasks-*** — “Today” widget shows Nov 3–5 in red as if overdue in a today view; large/extra-large rows alternate date under title vs trailing date. **Fix:** Today configuration: omit past dates or section “Overdue” with orange header; one alignment rule (trailing `.caption` due) across all widget sizes.

19. **57-live-activity-lockscreen-light, 58-live-activity-expanded-light** — Segmented bottom bar (gray/indigo/orange) has no explained mapping; expanded island uses white-on-black while lock screen is light—feels like two products. **Fix:** Drop decorative bar or label counts (“1 waiting · 2 running · 3 done”); match Live Activity `.activityBackgroundTint` and typography to lock screen card; bold only “Needs you” row.

20. **59-live-activity-compact-light** — Compact trailing ring segments don’t match expanded legend; orange “1” is clear but left glyph is not the app icon users see on Home Screen. **Fix:** Compact leading = app icon; trailing = orange hand glyph when any session needs you, else indigo spinner—no tri-color ring unless Dynamic Island HIG requires it.

## What works

- **Dashboard + iPad split (`01`, `13`)** — Greeting, glass composer, and three-column “Due / What’s New / Working” tell a coherent “morning command center” story with correct semantic colors on actor states.
- **Actor permission (`06`, `13d`)** — Orange border, hand icon, and indigo Allow/Deny hierarchy make “needs you” unmistakable without screaming error UI.
- **Agent chat content (`05`, `13b`)** — Interactive choice card and launch checklist show product personality beyond lists; indigo user bubbles anchor the thread.
- **Article reader (`34`)** — Serif long-form, inline code chips, and code blocks feel deliberately editorial and native-adjacent.
- **Intelligence agent color system (`02`, sidebar in `13*`)** — Per-agent disc colors plus team subtitles give recognizable identity in a crowded ops tool.

## To reach 9+

1. **Navigation contract** — Tab bar only on four roots; pushed Workspace/Intelligence screens use standard large-title back stack and full-width scroll insets (`03`, `07`, `08`, `12`, floating tab issue).
2. **Task row redesign** — One metadata line and canonical priority/needs-you colors across iPhone, iPad, and task widgets (`07`, `13c`, `53–56`).
3. **Toolbar and title unification** — One rule for large vs inline titles and one glass capsule pattern for settings/more/filter (`04`, `08`, `10`, `34`, `44`).
4. **Widget/Live Activity parity** — Same `AgentAvatar` and status strings as in-app; remove ambiguous progress bars and align Today/overdue semantics (`50–59`).
5. **Feed and chat layout system** — Two-line feed rows and two container types for messages/tables so Intelligence content doesn’t read as nested web layouts (`04`, `05`, `13b`).
