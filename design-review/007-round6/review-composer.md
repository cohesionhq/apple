## Scores

| Category | Score | One-line reason |
| --- | ---: | --- |
| Native | 7.3 | Liquid Glass tab bar and inset groups read iOS 27, but nested Workspace stacks still show the tab bar and several screens fight standard navigation title patterns. |
| Typography | 7.1 | Large titles and the article serif land well; task metadata, widget footers, and mixed centered vs leading titles weaken the scale. |
| Hierarchy | 6.7 | Composer, permission cards, and chat bubbles focus attention; hub tabs (Feeds, Workspace, Intelligence) and crowded toolbar triads lack a single obvious primary action. |
| Spacing & density | 6.4 | iPad task lists feel right for a pro tool, while Feeds, sparse Inbox, and large task widgets swing between empty and cramped. |
| Color & contrast | 7.2 | Indigo accent and orange “needs you” are consistent in-product; overdue/red, gray flags, and iPad “Tomorrow” pink muddy priority semantics. |
| Iconography | 6.6 | SF Symbol sidebars and status glyphs cohere; widget agent marks (emoji, skeuomorphic calendar) break the in-app avatar language. |
| Consistency & polish | 6.5 | Toolbars, section headers, task rows, and agent presentation shift between iPhone tabs, iPad sidebar, sheets, and extensions without one finished system. |
| Overall | 6.8 | Clearly a capable native client, not yet the unified, opinionated visual system an Apple Design Award jury would credit to a single design pass. |

## Problems

1. **`07-iphone-tasks-light.png`, `13c-ipad-tasks-light.png`, `54–56-widget-tasks-*.png`** — Due-date and metadata type is very small and low-contrast under titles, so flags and dates compete at the wrong weight. Use one row spec: title `.body`, metadata `.subheadline` + `.secondary`, dates monospaced only when overdue (`.red`), and keep priority on the flag—not redundant red dates on every past day in widgets.

2. **`04-iphone-feeds-light.png`** — One short card floats in a large empty field; the screen reads unfinished rather than intentionally calm. Anchor a full-height inset grouped list under the large title (or add a second section placeholder), and tighten large-title-to-content spacing to match Dashboard/Intelligence.

3. **`08-iphone-journal-light.png`, `10-iphone-documents-light.png`, `12-iphone-contact-light.png`, `07-iphone-tasks-light.png`, `03-iphone-workspace-light.png`** — The floating tab bar stays visible on pushed Workspace destinations, so users get stack back buttons and tab switching at once. Hide the tab bar on drill-in (`hidesBottomBarWhenPushed`) or re-home these lists in one persistent split on iPhone where it makes sense.

4. **`02-iphone-intelligence-light.png`, `13-ipad-split-view-light.png`, `13b-ipad-agent-chat-light.png`** — Agents appear as pinned circles, sidebar rows, and grouped list rows with different subtitles and adornments. Collapse to one list-row component (avatar, name, team, badge) everywhere; use a horizontal pin strip only if it reuses that same row at smaller scale.

5. **`01-iphone-dashboard-light.png`, `13-ipad-split-view-light.png`** — The greeting out-shouts the composer, which should be the screen’s job-one control. Drop the greeting to `.title2` or `.title3` regular, keep the date at `.subheadline` secondary, and let the composer card carry the visual weight (shadow/material, not headline size).

6. **`03-iphone-workspace-light.png`** — There is no screen title—only the workspace switcher—so hierarchy depends on remembering which tab you tapped. Add a large title “Workspace” (or make the switcher the large-title control with clear typographic role) and align its vertical position with Intelligence/Feeds.

7. **`05-iphone-agent-chat-light.png`, `13b-ipad-agent-chat-light.png`** — The in-message table and terminal block read as cramped appendices; the eye loses the narrative thread. Wrap tables in a rounded, inset material with horizontal scroll, row dividers, and header row `.footnote` semibold; add 12–16pt more vertical rhythm between assistant blocks.

8. **`06-iphone-actor-session-light.png`, `13d-ipad-actor-session-light.png`** — The permission card is correct hero content, but three full-width pills plus follow-up bar stack heavily on iPhone. Keep **Allow** filled primary; style **Deny** as `.bordered` or inline text button; tuck **More** into the card header as a toolbar `…` to recover transcript space.

9. **`26-task-detail-light.png`** — Mark-complete in the trailing toolbar is visually weaker than Close, though completing is the main outcome. Use a prominent trailing **Mark Complete** (filled or tinted) when incomplete; reserve the checkmark-in-circle for the done state only.

10. **`44-extensions-light.png`, `14-settings-light.png`** — Extensions use anonymous gray initial tiles while Settings uses saturated glyph tiles, so server configuration feels like two apps. Give each extension a colored symbol tile (same grid, corner radius, and glyph weight as Settings) or monochrome symbols with one accent—pick one system.

11. **`50–52-widget-agents-*.png` vs `02-iphone-intelligence-light.png`** — Widget facepile uses emoji telescope and realistic calendar icons instead of agent discs from the app. Render widgets with the same avatar pipeline (emoji at 24pt scaled, initials semibold, agent hue) so home screen and in-app identity match.

12. **`50-widget-agents-small-light.png`, `51-widget-agents-medium-light.png`** — Copy alternates “need you” (lowercase, orphaned) with a full sentence in medium; tone feels unedited. Standardize on one string catalog entry (e.g. “3 need you” / “Ada, Milo, and Juno need you”) with Title Case rules matching notifications.

13. **`55-widget-tasks-large-light.png`, `56-widget-tasks-extralarge-light.png`** — Rows are tighter than Apple’s Reminders widget; flags and dates don’t share a baseline column. Fixed row height (~44pt), right-aligned metadata column, flag always trailing; dates left of flag in `.caption` secondary.

14. **`13c-ipad-tasks-light.png`** — “Tomorrow” in pink/magenta reads as a fourth semantic color beside red overdue and orange needs-you. Map dates to: overdue `.red`, today `.primary`, future `.secondary`—no novelty hues for scheduling.

15. **`02-iphone-intelligence-light.png`, `01-iphone-dashboard-light.png`** — Dashboard “What’s New” and Intelligence “Actors” both surface the same permission item with similar orange treatment, blurring tab purpose. Differentiate: Dashboard = cross-domain activity feed with neutral rows; Intelligence = live ops board with stronger status chrome and actor-first sort.

16. **`08-iphone-journal-light.png`** — “Today” sits alone in one card, then “November 2026” and a second card—rhythm feels accidental. Either fold Today into the month list as the first row (bold, no duplicate container) or style Today as a distinct hero only if it always includes preview text.

17. **`12-iphone-contact-light.png`** — Four indigo actions (Message, Call, FaceTime, Mail) share equal loudness; nothing says primary contact method. Use symbol + `.caption` in label color; apply accent only to the default action, or use Contact card–style bordered buttons.

18. **`17-agent-info-light.png`** — “48K” / “tokens” splits awkwardly with tokens at caption size, hurting scanability. Single trailing value: `48K tokens` in `.body` monospaced digits + `.footnote` secondary unit, one baseline.

19. **`57-live-activity-lockscreen-light.png`, `58-live-activity-expanded-light.png`** — The tricolor capsule under rows looks decorative; meaning (counts? progress?) isn’t obvious at a glance. Replace with labeled summary (“1 needs you · 2 running · 3 done”) or remove the bar and rely on the header chips you already show.

20. **`59-live-activity-compact-light.png`** — Compact trailing ring packs green, orange, and indigo segments plus “3”; busy on the Island. Simplify to app glyph leading, single orange dot or digit when anything needs you, otherwise a muted indigo activity indicator.

21. **`34-article-light.png`** — Editorial typography is strong, but the clustered glass toolbar (reload, share, more) competes with the serif headline when scrolled. Collapse to back + overflow in one trailing capsule until scroll crosses the title, matching Reading List/Safari reader chrome.

22. **`07-iphone-tasks-light.png`** — Only two tasks in a vast empty card makes Inbox feel broken, not focused. When count is low, shrink the group to content height or show a compact list style without a tall empty platter; keep empty-state illustration/copy for zero tasks.

## What works

- **Dashboard composer + What’s New** (`01`, `13`) — The input field, agent picker pill, and status-colored activity rows give the product a distinctive “mission control” feel without abandoning iOS list grammar.
- **Actor permission card** (`06`, `13d`) — Orange border, hand glyph, and indigo **Allow** make “needs you” impossible to miss; this is the right level of drama for a pro tool.
- **Article reader** (`34`) — Serif headline/body, restrained chrome, and inline code chips deliver editorial quality that separates Cohesion from a generic Markdown viewer.
- **iPad sidebar + selection** (`13`, `13b`, `13c`, `13d`) — Workspace switcher, pinned agents, and indigo selection capsule feel first-class on iPad, not a blown-up phone UI.
- **Live Activity status vocabulary** (`57`, `58`) — Orange “Needs you,” timers for running work, and header count chips align with the in-app semantic colors and are glanceable on the lock screen.

## To reach 9+

1. **Unify navigation chrome** — One rule set for large vs inline titles, when the tab bar hides, and toolbar tint (respecting the package-preview note); apply across Workspace drill-ins, sheets, and Settings pushes so the shell feels designed, not assembled.
2. **Ship one task-row design system** — Same typography, metadata order, date colors, and flag semantics on iPhone list, iPad list, task sheet, and widgets `53–56`; fix spacing and alignment in widgets to match Reminders-quality density.
3. **Rebalance hub screens** — Redesign Feeds and sparse lists (Inbox, Workspace landing) for intentional density: full-height groups, clear primary actions, and section headers that match Dashboard/iPad “What’s New 4” styling.
4. **Single agent identity pipeline** — Same disc renderer for Intelligence pins, sidebar, chat header, notifications, widgets `50–52`, and Live Activity; retire emoji/skeuomorphic one-offs on widgets.
5. **Clarify tab and color semantics** — Document and enforce orange = needs human, red = failed/overdue, green = connected/done, indigo = brand/action; remove pink “Tomorrow,” gray-redundant overdue styling, and decorative Live Activity bars that don’t encode meaning.
