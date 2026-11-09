## Scores

| Category | Score | One-line reason |
| --- | --- | --- |
| Native | 6.7 | Grouped lists and sheets feel iOS-appropriate, but the persistent floating tab bar on pushed screens, hybrid nav models, and uneven Liquid Glass material use read custom-first rather than system-first. |
| Typography | 7.0 | SF scales are mostly correct and the article reader is excellent, yet greetings, section headers, and task metadata don’t share one disciplined type ramp. |
| Hierarchy | 6.4 | Strong moments (actor permission, What’s New) compete with flat hubs (Feeds, Extensions) and a cluttered Intelligence landing where pinned heroes and lists fight for attention. |
| Spacing & density | 6.2 | iPhone task rows and chat are appropriately dense for a pro tool, but iPad dashboard dead space, sparse Feeds, and widget whitespace throw rhythm off. |
| Color & contrast | 7.1 | Indigo, per-agent color, and orange “needs you” land well; red does too many jobs (failed, overdue, badges, flags) and blurs the semantic system. |
| Iconography | 6.6 | SF Symbols are consistent in chrome, but agent identity mixes emoji, 3D-ish glyphs, initials, and Settings-style colored tiles without one family rule. |
| Consistency & polish | 6.1 | Tab roots, pushed workspace children, Settings-style sheets, and extension surfaces look like related apps sharing data, not one visual system. |
| Overall | 6.5 | Credible native productivity app with clear product thinking; not yet the tight, opinionated craft of a flagship Apple-design-tier release. |

## Problems

1. **07-iphone-tasks-light.png, 08-iphone-journal-light.png, 10-iphone-documents-light.png, 12-iphone-contact-light.png** — The floating tab bar remains visible on pushed Workspace destinations, which splits wayfinding between “where I am in the stack” and “which tab I’m in.” Hide the tab bar when `navigationPath` is non-empty (or fold Workspace into a single-stack sidebar pattern on iPhone) and rely on the standard back affordance plus large title.

2. **02-iphone-intelligence-light.png** — Pinned agent circles and the “Agents” inset list duplicate the same entities in two visual languages. Replace the hero row with a single section: pinned agents as the first rows in one list (larger avatar, optional subtitle), or a horizontal `ScrollView` that matches list row avatar sizing—not a separate metaphor.

3. **02-iphone-intelligence-light.png, 01-iphone-dashboard-light.png** — The Intelligence tab badge uses red, which your system reserves for failure; it reads as “something broke,” not “something needs you.” Use orange (attention) or a neutral label dot with a numeric badge in `.secondary` fill, reserving red for failed actor runs and error toasts only.

4. **13-ipad-split-view-light.png** — The dashboard column is mostly empty below What’s New; the iPad canvas feels like a phone layout dropped into a wide stage. Introduce a true two-column dashboard (composer + What’s New left, Working / sessions / pinned task right), or a narrower content column with a deliberate empty margin—not an accidental void.

5. **01-iphone-dashboard-light.png, 13-ipad-split-view-light.png** — The greeting competes with What’s New for primary attention (“Let’s get going, Jackson Zamorano” is long and headline-heavy). Use a shorter large title (“Good morning”) and `.subheadline` `.secondary` for the date and optional first name on one line.

6. **04-iphone-feeds-light.png** — One short card floating in a sea of background reads unfinished, not minimal. Either extend the grouped list to fill the content area (with section headers and pull-to-refresh affordance) or add a designed empty/loading state with illustration, last-updated metadata, and a single primary “Add feed” action outside the list.

7. **03-iphone-workspace-light.png** — Workspace reads as a generic settings directory; it doesn’t signal “your studio” or recency. Add per-row metadata (counts, “updated 2h ago” on Documents), or a compact “Recents” section above the directory so the tab feels lived-in.

8. **05-iphone-agent-chat-light.png, 13b-ipad-agent-chat-light.png** — Markdown tables on phone width crush columns and break scanability. Render tables as stacked cards (task name primary, due/owner as `.caption` rows) or a horizontally scrolling monospaced block with a clear “Table” caption—not a shrunken grid.

9. **07-iphone-tasks-light.png, 13c-ipad-tasks-light.png** — Task rows stack date, assignee avatar, agent chip, size, tags, and flag into one noisy metadata band. Collapse to at most two secondary tokens on the row (due date + assignee *or* agent); move size/tags to the sheet and use `.caption` `.secondary` consistently.

10. **26-task-detail-light.png** — “Set Size” in indigo among gray picker values looks like a promotional link, not an unset field. Use `.secondary` “None” with chevron like Tags/Folder, or a single accent only on the row’s control when editing—not inline marketing color.

11. **54-widget-tasks-medium-light.png, 55-widget-tasks-large-light.png, 56-widget-tasks-extralarge-light.png** — Overdue dates in red and flags in orange/red overload urgency semantics on a glance surface. Pick one glance signal (e.g. orange flag only for “needs you,” red date only when overdue) and gray everything else; match in-app task list rules exactly.

12. **12-iphone-contact-light.png** — The “MC” monogram on pale gray has weak contrast and doesn’t match agent avatar richness. Use a deterministic tinted disc (contact hash color + semibold initial) at the same diameter rules as `AgentAvatar`, or a photo placeholder style Contacts uses.

13. **50-widget-agents-small-light.png, 51-widget-agents-medium-light.png, 52-widget-agents-large-light.png** — Widget avatars use emoji/3D calendar props that don’t match in-app agent discs (initials, flat glyphs). Reuse the same avatar renderer at widget scale: flat emoji or symbol on saturated agent color, no mismatched “realistic” emoji assets.

14. **14-settings-light.png, 17-agent-info-light.png, 44-extensions-light.png** — Settings, agent info, and extensions share the iOS Settings colored-tile pattern while tab roots use floating glass and oversized titles; the app feels like two products. Define one “form sheet” style (corner radius, section headers, icon treatment) that still uses Cohesion grouping—tinted symbols on `.quaternary` circles, not rainbow Settings clones.

15. **06-iphone-actor-session-light.png, 13d-ipad-actor-session-light.png** — The permission card sits mid-scroll while the follow-up bar anchors the bottom; on long transcripts the critical “Needs you” moment can scroll away. Pin a compact permission strip above the composer when action is required, or auto-scroll the orange card into view with a sticky header.

16. **06-iphone-actor-session-light.png** — Event types (“Write,” “Bash”) and timings use similar weights; the session title truncates aggressively in the nav bar. Put repo/summary in `.footnote` `.secondary` under a shorter nav title, and style step labels as `.caption` `.secondary` caps with monospaced command paths below.

17. **08-iphone-journal-light.png** — “Today” sits in an isolated card while November entries use a different section pattern; month header weight doesn’t match Dashboard/Tasks section language. Unify: one grouped style, month as `Section` header (`.footnote` `.secondary` uppercase or title3 depending on design.md), Today as first row with “Morning” subtitle not a lone card.

18. **10-iphone-documents-light.png** — Timestamps sit on the trailing edge beside chevrons, causing collision with long titles. Move relative time to a second line under the title in `.caption` `.secondary`, trailing chevron only.

19. **57-live-activity-lockscreen-light.png, 58-live-activity-expanded-light.png** — The tri-color segmented bar at the bottom has no explained meaning next to numeric badges in the header. Remove decorative bars or map them 1:1 to documented states (done / running / needs you) with accessibility labels; prefer ActivityKit’s compact layout patterns.

20. **59-live-activity-compact-light.png** — The compact ring splits green/orange/indigo without a legible primary read at pill scale. For “1 needs you,” use orange accent on the app icon corner or a single digit in `.caption.weight(.semibold)` with orange tint, not a pie chart.

21. **05-iphone-agent-chat-light.png** — The cue banner reads as another message genus; hierarchy between automation, user bubble, and agent body blurs. Style cues as `.footnote` inset bar (icon + one line + chevron), user bubbles as only human-sent content, agent content flush left without competing banners.

22. **13c-ipad-tasks-light.png** — The tasks column uses full width while the sidebar carries agents; the list rows stretch metadata to the edges. Constrain list readable width (e.g. 680–720pt) or add a secondary inspector column on iPad for task preview without opening a sheet.

23. **34-article-light.png** — Three glass toolbar circles plus large serif title is elegant but heavy; share/sync/more compete equally. Keep back + `Menu` with Share and Refresh inside; reserve toolbar for one primary action.

24. **02-iphone-intelligence-light.png, 01-iphone-dashboard-light.png** — “What’s New,” Intelligence actors, and sidebar “Actors” all surface session state with slightly different row templates. One row component: leading status glyph, title, `.caption` status · time, trailing chevron—reuse on Dashboard, Intelligence, and iPad sidebar footer.

## What works

- **06-iphone-actor-session-light.png, 13d-ipad-actor-session-light.png** — The orange-bordered permission card with indigo Allow / neutral Deny is immediately legible and correctly prioritizes human-in-the-loop over transcript history.
- **01-iphone-dashboard-light.png, 13-ipad-split-view-light.png** — What’s New status copy (Needs you / Done / Failed) with color-aligned icons implements the product’s semantic palette in a scannable feed.
- **34-article-light.png** — Reader typography (serif body, monospace code chips, comfortable measure) feels intentional and “designed,” not default `Text` dump.
- **13-ipad-split-view-light.png, 13b-ipad-agent-chat-light.png** — Sidebar agent list with pins, team grouping, and orange “Needs you” in Actors is a strong iPad-native mental model for a multi-agent workspace.
- **57-live-activity-lockscreen-light.png** — Per-row status icon + title + trailing state/timer is the right information density for lock-screen glances once color semantics are tightened.

## To reach 9+

1. **Ship one navigation and chrome contract** — Tab roots: large title + floating tab bar; pushed content: no tab bar, standard nav bar; sheets: consistent dismiss and toolbar label colors (per INDEX, not preview tint). iPad: sidebar selection drives detail, no duplicate tab metaphor in the content column.

2. **Lock semantic color to four roles globally** — Indigo = brand/interactive; orange = needs you; red = failed/destructive only; green = connected/success. Audit badges, due dates, flags, and Live Activity segments in app + widgets in one pass.

3. **Redesign Intelligence as the product’s hero surface** — Merge pinned agents, agent directory, and actor sessions into one scannable command center (not circles + list + duplicate dashboard feed); that single screen should answer “what needs me now?”

4. **iPad spatial system** — Fixed content widths for chat and actor transcripts, two-column dashboard, tasks list that doesn’t rubber-band across the full display; treat empty space as composed margin, not missing layout.

5. **Single avatar and list-row design system** — Same agent disc rules in app, widgets, notifications, and Live Activity; one inset-grouped row style for tasks, sessions, feeds, and extensions so every surface feels like one designer owns the component library.
