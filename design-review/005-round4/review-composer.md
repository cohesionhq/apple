## Scores

| Category | Score | One-line reason |
| --- | ---: | --- |
| Native | 6.4 | Liquid Glass cards and inset lists land, but the floating tab bar on every level, top-left Settings on tab roots, and chat/actor chrome fight UIKit navigation expectations. |
| Typography | 7.3 | SF hierarchy is mostly sound and the article serif reader feels intentional; tab roots and widgets mix title sizes, weights, and secondary styles without a single scale. |
| Hierarchy | 6.6 | Dashboard composer, feeds, and permission cards compete for attention; task and actor rows pack too much metadata at equal visual weight. |
| Spacing & density | 6.7 | Generous padding reads premium on iPad, but iPhone lists (Inbox, Feeds, Documents) leave huge dead zones above the tab bar while other screens feel cramped. |
| Color & contrast | 7.1 | Orange/red/green semantics work in-app and on Live Activity; widgets grey out “Needs you,” and overdue red dates aren’t distinguished from priority flags. |
| Iconography | 7.6 | SF Symbol weight is consistent; agent discs and Settings-style tiles are clear, though status glyphs (hand vs exclamation) vary between dashboard and actors. |
| Consistency & polish | 6.3 | Navigation title placement, section headers, metadata alignment, and “Need you” copy drift across iPhone, iPad, and extensions. |
| Overall | 6.8 | Credible native product with distinctive agents and glass surfaces—not yet the tight, single-system feel of a designed-ship candidate. |

## Problems

1. **01-iphone-dashboard-light.png, 13-ipad-split-view-light.png** — Greeting, composer, and “What’s New” all read as equally primary; “Working” fades without a structural frame. **Fix:** Two clearly labeled sections (`.headline` headers, optional collapse), composer in a single hero card with one accent (indigo send), and “Working” at `.secondary` with a thinner row style than “What’s New.”

2. **03-iphone-workspace-light.png, 07-iphone-tasks-light.png, 08-iphone-journal-light.png, 10-iphone-documents-light.png, 12-iphone-contact-light.png** — Floating tab bar remains visible on pushed workspace destinations, implying parallel navigation while the user is in a stack. **Fix:** Hide the custom tab bar whenever `navigationPath` is non-empty (or use system tab + navigation); keep workspace entry only at the tab root.

3. **01–04, 02-iphone-intelligence-light.png (tab roots)** — Settings gear in the top-leading corner on every tab root is non-standard and steals hierarchy from titles. **Fix:** Move Settings to trailing toolbar on Dashboard (or profile avatar menu); use large-title layout with gear as `.toolbar` trailing on other roots.

4. **02-iphone-intelligence-light.png** — Pinned agents as large circles then inset “Agents” list creates two competing browse patterns and a density cliff. **Fix:** One pattern: pinned row of `.symbol` avatars (match list row size) or grid only on iPad; drop duplicate listing of the same agents.

5. **04-iphone-feeds-light.png** — One short inset card floating in empty space; “Feeds” large title plus empty lower half feels like a stub screen. **Fix:** Full-height inset list edge-to-edge (standard `List`/`Form`), or empty-state illustration + primary “Add feed”; align with Workspace section rhythm.

6. **05-iphone-agent-chat-light.png, 13b-ipad-agent-chat-light.png** — Centered avatar + “Atlas ›” chip instead of `navigationTitle` + inline subtitle breaks chat conventions and wastes vertical space. **Fix:** Leading back, trailing agent info; title “Atlas” large or inline; avatar only in toolbar or first message cluster.

7. **05-iphone-agent-chat-light.png** — Markdown table and numbered list run edge-to-edge with tight column gutters; table is clipped by the composer. **Fix:** Horizontally scrollable table in a rounded secondary background; body at readable measure (~ readableContentGuide); sticky composer with standard `.safeAreaInset`.

8. **06-iphone-actor-session-light.png, 13d-ipad-actor-session-light.png** — Permission card is the right focal point, but step headers (“Write”, “Bash”) and timestamps don’t form a clear timeline. **Fix:** Vertical timeline spine, `.caption` monospaced paths, `.subheadline` for descriptions; pin permission card with subtle elevation and orange border only on the header strip, not the whole card.

9. **07-iphone-tasks-light.png, 13c-ipad-tasks-light.png** — Task rows stack title, due date, assignee, size chips, and tags at similar weight; flags and dates both signal urgency. **Fix:** Title `.body`; one metadata line `.subheadline` + `.secondary` (due · assignee); tags only in detail or max one capsule; orange flag *or* orange due, not both without legend.

10. **07-iphone-tasks-light.png** — Inbox with two items leaves a tall empty card and vast whitespace above the tab bar. **Fix:** List fills safe area; for sparse data use smaller grouped section without min-height card; optional “Add task” row.

11. **08-iphone-journal-light.png vs 10-iphone-documents-light.png** — Journal snippets left under titles; document times right-aligned; section headers differ (“November 2026” vs “Today/This Week”). **Fix:** One workspace list template: leading title, trailing relative time `.caption` `.secondary`, shared section header style.

12. **14-settings-light.png, 17-agent-info-light.png, 26-task-detail-light.png** — Sheets mix centered heroes, iOS Settings tiles, and form rows, but dismiss controls vary (X indigo vs X grey) and “Context / 48K tokens” isn’t styled like other value rows. **Fix:** Shared sheet header (avatar optional); values right-aligned `.secondary`; one dismiss tint (indigo for brand sheets, red only for destructive).

13. **26-task-detail-light.png** — “Set Size” in indigo reads as primary action while Status/Priority use grey chevrons; toggles and rows feel like mixed Settings and Reminders. **Fix:** All editable values use the same trailing control style; indigo reserved for Save/complete in toolbar, not inline placeholders.

14. **44-extensions-light.png** — Version `v4` inline with title squeezes the subtitle; secondary line truncates early. **Fix:** Version `.caption2` `.tertiary` under title or trailing; description two lines `.subheadline` `.secondary`; consider connectivity/status glyph per extension.

15. **13-ipad-split-view-light.png, 13c-ipad-tasks-light.png** — Sidebar packs Studio, six destinations, six agents, actors, and badges into one scroll without strong section separation; selection highlight differs (Dashboard indigo pill vs Tasks subtle). **Fix:** `sidebar` list with standard section headers, pinned agents subsection, one selection background style; collapse “Actors” when empty.

16. **50-widget-agents-small-light.png, 51-widget-agents-medium-light.png, 52-widget-agents-large-light.png** — Header “Need You” (title case) vs in-app “Needs you”; status lines grey even when attention is required. **Fix:** Copy `Needs you` everywhere; status `.caption` `.orange` when blocked; keep agent color on avatar only.

17. **53–56 widget tasks** — Overdue dates in red without label; only some rows show dates (uneven height); extra-large widget is ~40% empty. **Fix:** Date + role: `.caption` red for overdue, `.secondary` for upcoming; consistent row template; extra-large adds fourth metadata column or second section (Overdue / Today).

18. **54-widget-tasks-medium-light.png, 55-widget-tasks-large-light.png** — Due dates sit under title on first rows but disappear on later rows, breaking scan rhythm. **Fix:** Trailing column for due date on every row (WidgetKit `HStack` + `Spacer()`), flags only when priority ≠ medium.

19. **57-live-activity-lockscreen-light.png, 58-live-activity-expanded-light.png** — Summary chips (`1` `2` `3`) plus segmented green/purple/orange bar compete with row content; meaning of segments isn’t obvious. **Fix:** Drop redundant counts if rows are listed; bar becomes thin progress for “active sessions” only, or remove; tighten to 2–3 rows max with orange only on “Needs you”.

20. **59-live-activity-compact-light.png** — Trailing ring segments are clever but illegible at glance; “3” center competes with colors. **Fix:** Compact: app icon leading, single orange dot if any need-you, else purple pulse; save multicolor ring for minimal analytics, not status.

21. **34-article-light.png** — Reader is strong, but toolbar icons float without grouping and fetched URL line competes with byline. **Fix:** Byline one line; source + fetched `.caption2` `.tertiary` below; toolbar uses standard share group spacing.

22. **03-iphone-workspace-light.png** — Center “Studio” menu without large title makes Workspace feel like a modal picker, unlike Intelligence/Feeds. **Fix:** Large title “Workspace” with Studio as `.principal` menu or first section header; match other tab roots.

## What works

- Semantic status color on dashboard and actor flows (orange needs you, red failed, green/done) is immediately readable and on-brand.
- Agent identity (disc color, emoji/symbol avatars) stays consistent from Intelligence through chat and iPad sidebar.
- Article reader typography (serif body, inline code chips) feels deliberate and native-adjacent for long-form content.
- Actor permission UI centers a single clear action (Allow) with restrained orange framing—right product moment for a pro tool.
- iPad split view with agents and actors in the sidebar is the right structural bet for this product; chat and sessions use the canvas well.

## To reach 9+

1. **Navigation system reset on iPhone** — System tab bar at roots only; standard `NavigationStack` large titles; no tab bar on pushes; Settings out of the top-leading corner.
2. **One list language for Workspace** — Shared row, section header, and timestamp rules across Tasks, Journal, Documents, Contacts, Feeds (stop one-off floating cards).
3. **Dashboard editorial layout** — Single hero composer, two scannable sections (attention vs background work), strict type roles so the eye hits “needs you” first.
4. **Task row simplification** — One metadata line, encoded urgency (date color + one icon), tags deferred to detail; apply on iPhone and iPad task shots.
5. **Extension surfaces pass** — Widgets and Live Activity use the same status copy and orange for “Needs you,” aligned rows, and no decorative chrome that doesn’t encode meaning (count chips, mystery segmented bars).
