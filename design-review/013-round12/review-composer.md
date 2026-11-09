## Scores

| Category | Score | One-line reason |
| --- | ---: | --- |
| Native | 7.4 | Liquid Glass tab bar and grouped lists land well, but chat chrome, tab bar on pushed lists, and widget emoji avatars fight UIKit expectations. |
| Typography | 7.1 | Large titles and the article reader are strong; task and feed metadata sit too close in size and weight to primary labels. |
| Hierarchy | 6.7 | Dashboard composer and permission cards read clearly; Intelligence, task rows, and chat transcripts compete for attention. |
| Spacing & density | 7.3 | Airy cards and iPad columns suit a pro tool, yet iPhone task metadata feels cramped and chat tables run into the composer. |
| Color & contrast | 7.5 | Indigo, orange “needs you,” and red overdue are mostly consistent; flags, dates, badges, and the Live Activity bar blur meaning. |
| Iconography | 6.4 | In-app agent discs cohere, but custom tab marks, mixed avatar treatments, and skeuomorphic widget icons break one family. |
| Consistency & polish | 6.8 | Toolbars and grouped sections repeat, but section headers, widget copy, navigation depth, and settings vs workspace icon languages diverge. |
| Overall | 7.0 | Credible native productivity app with personality, not yet the tight, authored system an Apple Design Award entrant would show. |

## Problems

1. **`50-widget-agents-small-light.png`, `51-widget-agents-medium-light.png`, `52-widget-agents-large-light.png`** — Widget agents use 3D telescope/calendar emoji-style art while the app uses flat colored discs with initials/symbols (`02`, `05`). **Fix:** Render the same `AgentAvatar` asset pipeline in widgets; ban full-color emoji assets at widget sizes.

2. **`50-widget-agents-small-light.png`, `51-widget-agents-medium-light.png`** — Small widget shows “3 need you” but medium shows “2” with different agents named; grammar flips between count-only and sentence. **Fix:** One rule: always `"\(n)"` + `.title2` and `.subheadline` orange caption using the same string model as Intelligence (“2 need you” or “Milo and Juno need you”), never both patterns across sizes.

3. **`07-iphone-tasks-light.png`, `54-widget-tasks-medium-light.png`, `55-widget-tasks-large-light.png`, `56-widget-tasks-extralarge-light.png`** — Task titles share the row with calendar, assignee avatar, size, and tags at nearly equal visual weight. **Fix:** Title on line one (`.body`); single `.caption` secondary row with 2–3 spaced tokens max; move tags and size to the task sheet unless filtering.

4. **`07-iphone-tasks-light.png`, `13c-ipad-tasks-light.png`** — Orange and red flags sit beside red due strings without a legend; orange also means “needs you” elsewhere. **Fix:** Reserve orange for human/agent attention only; use indigo or labeled priority for priority; use red only for overdue/failed; add accessibility labels, not color alone.

5. **`05-iphone-agent-chat-light.png`, `13b-ipad-agent-chat-light.png`** — Agent replies read as one continuous document; user bubble is clear but Atlas content lacks turn boundaries. **Fix:** Wrap each agent turn in a subtle inset grouped background (or increase inter-turn spacing to ≥24pt) and label the first line with `.caption` secondary “Atlas” once per turn, not mid-paragraph.

6. **`05-iphone-agent-chat-light.png`** — Markdown table extends under the glass composer with no breathing room. **Fix:** Inset tables in a rounded `.regularMaterial` container with horizontal scroll and ≥16pt bottom padding above the input bar.

7. **`02-iphone-intelligence-light.png`** — Pinned Atlas/Scout circles and the full Agents list repeat the same destinations with two layouts. **Fix:** Keep either a single horizontal “Pinned” strip (max 4) *or* list-only with pin affordance; demote unpinned agents to list alone.

8. **`03-iphone-workspace-light.png`, `13-ipad-split-view-light.png`** — “Studio” large title carries a palette emoji while the rest of the app avoids emoji in chrome. **Fix:** Show workspace glyph in the sidebar/avatar slot only; title text plain “Studio” in `.largeTitle`.

9. **`01-iphone-dashboard-light.png`, `13-ipad-split-view-light.png`** — “Overdue” is red on the trailing edge but task titles use the same weight as “Today” items. **Fix:** Use `.body.semibold` for overdue titles or a 3pt leading red accent bar so overdue scans before metadata.

10. **`04-iphone-feeds-light.png`** — “Not Fetched” orange sits inline in the byline and fights the article title. **Fix:** Trailing capsule badge (`.caption2` on `.quaternary` fill, orange text) aligned with the timestamp column.

11. **`06-iphone-actor-session-light.png`, `13d-ipad-actor-session-light.png`** — Tool log lines (“Edit … ✓ 2s”) use the same voice and size as explanatory prose. **Fix:** Tool rows in `.caption.monospaced` or `.subheadline` secondary with checkmark in tertiary; keep narrative in `.body`.

12. **`08-iphone-journal-light.png`** — “Today” floats in its own card while older entries use a month header plus one card. **Fix:** One grouped list: section “Today”, then “November 2026”, same row style throughout.

13. **`12-iphone-contact-light.png`** — Quick actions are four small indigo glyphs in a row, unlike Contacts’ circular prominent actions. **Fix:** Use `ContactAction` style circular buttons (symbol + `.caption2` label) on `.ultraThinMaterial` or system contact layout.

14. **`26-task-detail-light.png`** — “Set Size” in indigo reads as a lone text link amid chevron picker rows. **Fix:** Full tappable row with leading icon, “Size” label, trailing “Not set” + chevron, same as Status/Folder.

15. **`57-live-activity-lockscreen-light.png`, `58-live-activity-expanded-light.png`** — Three-color segmented bar under the list has no explained mapping to sessions. **Fix:** Drop the decorative bar or replace with a single “3 active” caption; keep orange hand + purple activity ring language from the header chips only.

16. **`59-live-activity-compact-light.png`** — Compact trailing ring shows orange “1” without the hand metaphor used everywhere else for “needs you”. **Fix:** Center the orange `hand.raised` symbol (or fill that quadrant only) so compact matches lock screen semantics.

17. **`13c-ipad-tasks-light.png`** — Due, assignee, and flag columns float far right with no headers, producing a wide spreadsheet on an empty canvas. **Fix:** Cap list width (~700pt), add faint column headers on first scroll, or switch to a single secondary metadata line until Regular width.

18. **`44-extensions-light.png`** — Gray initial tiles (G, L, …) look like placeholders next to polished Settings icons (`14-settings-light.png`). **Fix:** Per-extension branded symbols or consistent SF Symbol metaphors on subtle tinted rects matching Settings row grammar.

19. **`02-iphone-intelligence-light.png`, tab on `01`, `07`, etc.** — Intelligence tab shows a red “1” badge while orange marks “needs you” in content; users can read badge as urgent attention. **Fix:** Badge = unread messages only (indigo dot or neutral count); keep orange strictly in-row for sessions/agents that need approval.

20. **`07-iphone-tasks-light.png`, `08-iphone-journal-light.png`, `10-iphone-documents-light.png`, `12-iphone-contact-light.png`** — Root tab bar stays visible on pushed workspace destinations, unlike typical stack navigation. **Fix:** Hide tab bar when navigating past Workspace hub (`.toolbar(.hidden, for: .tabBar)` on drill-in) or present tasks/journal/docs as sidebar selections on iPhone with collapsible back affordance.

21. **`05-iphone-agent-chat-light.png`** — Header stack (back, centered avatar, cue banner) doesn’t match standard chat or thread patterns. **Fix:** Inline `.principal` title with agent avatar leading, subtitle “Chief of staff” in `.footnote` secondary; move cue banner below nav as inset banner.

22. **`17-agent-info-light.png`** — Hero sheet is sparse: giant compass, single Context row, then Settings-style list; feels like two apps stitched. **Fix:** Pull role description and context into one inset group; secondary actions (chat, pin) as prominent buttons under the avatar before the settings list.

## What works

- **iPad dashboard triad (`13-ipad-split-view-light.png`)** — Sidebar, Due workboard, and What’s New column read like a designed control surface for a pro user.
- **Permission interrupt (`06-iphone-actor-session-light.png`, `13d-ipad-actor-session-light.png`)** — Orange-framed “Run a command?” with indigo primary Allow is the clearest hierarchy in the set.
- **Dashboard composer (`01-iphone-dashboard-light.png`, `13-ipad-split-view-light.png`)** — “Give Atlas something to do…” with agent picker is an obvious single main action.
- **Activity status copy (`01-iphone-dashboard-light.png`, `13-ipad-split-view-light.png`)** — “Needs you · 2m ago”, “Done · 18m ago”, “Failed · 1h ago” with matching icons teaches the color system quickly.
- **Article reader (`34-article-light.png`)** — Serif display title, comfortable measure, and inline code styling feel intentional and native-adjacent without mimicking the web UI.

## To reach 9+

1. **One avatar and icon system** — Same agent disc, symbol weight, and no emoji in widgets/Live Activity as in Intelligence and chat (`50–52`, `57–59`, `02`).
2. **iPhone task row v2** — Strict two-line model and disambiguated priority vs attention vs due (`07`, widgets `53–56`, `13c`).
3. **Navigation depth polish** — Hide tab bar on drill-in; normalize agent chat and actor session nav bars to iOS thread patterns (`05`, `06`, `07–12`).
4. **Semantic color chart enforced in UI** — Orange = needs you; red = overdue/failed; indigo = brand/selection/unread; remove ambiguous multi-color bars and redundant red on non-overdue widget dates (`54–58`, `04`).
5. **iPad content measure and columns** — Constrain transcript and task list width, add column semantics or collapse metadata on iPhone first (`13b`, `13c`, `13d`).
