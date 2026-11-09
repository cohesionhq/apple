Design review of the nineteen baseline PNGs in `design-review/001-baseline` (per `CORE.txt` and `INDEX.md`). Scores reflect light-mode iPhone and iPad landscape only; dark mode and Dynamic Type are out of scope except where a core file itself appears wrong (e.g. agent info).

## Scores

| Category | Score | One-line reason |
| --- | ---: | --- |
| Native | 6.4 | Floating four-tab bar on every push, glass circles for back, and mega-radius grouped cards fight standard navigation and list idioms. |
| Typography | 6.7 | SF is mostly correct, but title styles swing (centered vs large left), journal previews show raw Markdown, and chat metadata is too faint. |
| Hierarchy | 6.1 | Strong moments (dashboard composer, permission card) sit beside flat lists, noisy task metadata, and headers that don’t anchor the screen. |
| Spacing & density | 5.9 | iPhone lists float in huge empty fields; iPad task rows are crammed; sidebar and detail columns don’t share one rhythm. |
| Color & contrast | 6.0 | Status colors work on What’s New, but rainbow settings icons, multicolor task chips, and link-colored form values blur meaning. |
| Iconography | 6.3 | Agent discs read well; extension/connectors letter tiles, emoji “needs you,” and mixed symbol weights feel un系统. |
| Consistency & polish | 5.6 | Nav chrome, permission actions, chat bubbles, and settings icon treatment change screen to screen; agent info reads as dark in a light baseline. |
| Overall | 6.2 | Credible native shell and personality, but not yet a single designed system a pro would trust at a glance. |

## Problems

1. **`17-agent-info-light.png`** — Presented as dark UI in the light baseline; breaks review comparability and suggests preview/theme wiring is wrong. **Fix:** Re-shoot in explicit light appearance; use standard sheet background and grouped list colors from the rest of settings.

2. **`07-iphone-tasks-light.png`, `08-iphone-journal-light.png`, `10-iphone-documents-light.png`, `12-iphone-contact-light.png`** — Main tab bar stays visible on pushed Workspace stacks, so users get two navigation systems and the tab bar steals vertical space from shallow lists. **Fix:** Hide the tab bar on drill-in (`toolbarVisibility` / stack policy) and rely on back + optional bottom accessory only where needed.

3. **`01-iphone-dashboard-light.png`, `02-iphone-intelligence-light.png`, `04-iphone-feeds-light.png`, `03-iphone-workspace-light.png`** — Competing top patterns: no large title on Dashboard/Intelligence, large left title on Feeds, centered “🎨 Studio” on Workspace, gear-only entry to Settings. **Fix:** Pick one primary pattern per level (e.g. large title + trailing actions on tab roots; inline centered title only on push).

4. **`01-iphone-dashboard-light.png`, `13-ipad-split-view-light.png`** — “Needs you” uses ✋ emoji + orange text on What’s New, while tasks use orange **flags** (`07-iphone-tasks-light.png`, `13c-ipad-tasks-light.png`). **Fix:** One “needs attention” treatment everywhere (e.g. orange SF Symbol + `.subheadline` in `.orange`, no emoji in product chrome).

5. **`14-settings-light.png`, `17-agent-info-light.png`, `44-extensions-light.png`** — Settings-style rows use saturated rainbow icon wells (Profile orange, Memories pink, etc.) unlike the restrained indigo + agent palette elsewhere. **Fix:** Neutral gray wells + indigo glyph for server settings, or agent-color only where the row is agent-scoped; match Extensions’ calmer list.

6. **`26-task-detail-light.png`** — Status, assignee, priority, folder values are all indigo and read as links, same as real tappables. **Fix:** Labels `.body` primary; values `.body` secondary until focused; reserve indigo for explicit controls and the enabled checkmark.

7. **`13c-ipad-tasks-light.png`, `07-iphone-tasks-light.png`** — Task rows stack date, avatar, size pill, multiple tags, and a flag—metadata rivals the title. **Fix:** One metadata line (due + assignee); move size/tags to trailing capsule or detail; keep title as the only bold line.

8. **`08-iphone-journal-light.png`** — Preview lines show `## Morning`, `### Weekly review` (raw Markdown). **Fix:** Strip or render heading level for previews; use `.subheadline` `.secondary` for excerpt, never wire format.

9. **`02-iphone-intelligence-light.png`** — Pinned Atlas/Scout hero discs plus full Agents list duplicates wayfinding and pushes “Actors” below the fold. **Fix:** Either pin strip *or* list with section headers; pin as compact horizontal scroll above a single Agents section.

10. **`05-iphone-agent-chat-light.png`, `13b-ipad-agent-chat-light.png`** — iPhone chat is document-like (tables, full width); iPad uses bubbles, selection cards, and “Atlas” labels—different products. **Fix:** One chat grammar: aligned max width, consistent user bubble, agent name only on first block in a turn; reuse permission/selection card component on both.

11. **`06-iphone-actor-session-light.png`, `13d-ipad-actor-session-light.png`** — Permission actions are vertical full-width pills on iPhone vs horizontal quartet on iPad; Deny styling differs (gray vs red outline). **Fix:** Shared `PermissionPrompt` with adaptive layout (vertical on narrow, horizontal on regular); primary Allow filled indigo, destructive `.destructive` role consistently.

12. **`12-iphone-contact-light.png`** — Contact mimics Phone app (Message/Call/FaceTime/Email) but Cohesion is a workspace tool; actions likely don’t match real integrations. **Fix:** Replace with Cohesion actions (message in app, copy email, linked tasks) or drop the row until native behaviors exist.

13. **`34-article-light.png`** — Top chrome uses circular glass buttons; `26-task-detail-light.png` uses colored X/checkmark circles; `14-settings-light.png` uses checkmark only—sheet/header language isn’t one system. **Fix:** Standard sheet toolbar: leading Close (`.cancellationAction`), trailing Done (`.confirmationAction`), no custom tinted circles unless brand-critical.

14. **`10-iphone-documents-light.png`, `08-iphone-journal-light.png`, `07-iphone-tasks-light.png`** — Search or full-width chrome on some lists, single floating card on others; Documents uses multiple small cards per section while Journal is one tall card. **Fix:** Adopt one list container rule (inset grouped on system background *or* one elevated card with internal section headers, not both).

15. **`13-ipad-split-view-light.png`, `13b-ipad-agent-chat-light.png`, `13c-ipad-tasks-light.png`, `13d-ipad-actor-session-light.png`** — Sidebar packs Studio, six destinations, Connectors, Feeds, Settings with uneven type scale and duplicate “Issues” rows; detail columns are mostly empty or edge-to-edge without readable measure. **Fix:** Collapse Connectors into a single row + sheet; cap sidebar width; constrain detail content to ~680pt with consistent horizontal padding; Dashboard detail should not be an ocean of whitespace around a narrow feed.

16. **`44-extensions-light.png`** — Counts sit as bare numbers beside titles (“GitHub 4”) without badge styling; letter tiles look like placeholders. **Fix:** `.caption` secondary count in parentheses or trailing capsule; use SF symbols or branded glyphs where available.

17. **`05-iphone-agent-chat-light.png`, `06-iphone-actor-session-light.png`** — Agent subtitle and cue lines truncate at very small tertiary sizes; critical context (“Chief of staff…”, cue names) is hard to scan. **Fix:** Subtitle `.subheadline` `.secondary`, two lines max; cues as tappable rows with `.footnote` and chevron, not inline dim text.

18. **`02-iphone-intelligence-light.png`** — Tab badge “1” on Intelligence without visible in-tab explanation (which actor/agent needs attention). **Fix:** Surface the attention item at top of Intelligence (banner or pinned actor row in orange) so the badge is legible in context.

19. **`01-iphone-dashboard-light.png`, `13-ipad-split-view-light.png`** — What’s New rows use status under title but agent notification (“Quill · New message”) uses a different row grammar than tasks. **Fix:** Unified activity row: leading avatar/icon, title + `.subheadline` metadata, trailing chevron; status chip as secondary line for all types.

## What works

- **Dashboard composer** (`01-iphone-dashboard-light.png`, `13-ipad-split-view-light.png`) — Greeting + agent picker + Quick Journal gives a clear “start here” moment with personality without clutter.
- **Semantic status on What’s New** — Orange / gray done / red failed reads instantly and matches the product’s status language when emoji isn’t used.
- **Agent identity** — Colored discs and compass/initial avatars (`02-iphone-intelligence-light.png`, `05-iphone-agent-chat-light.png`) make agents recognizable at a glance.
- **Article reader** (`34-article-light.png`) — Serif body, code styling, and source line feel like a deliberate reading mode, not a generic list.
- **iPad sidebar + detail split** — Right structure for a pro tool (`13-ipad-split-view-light.png`); green settings dot for “connected” is subtle and on-brand.

## To reach 9+

1. **Unify navigation architecture** — Tab roots vs push vs sheet toolbars; hide tab bar on stack; one large-title/header rule so every screen’s top edge is predictable.

2. **Codify semantic color** — Indigo = brand/interactive; orange/red/green only for needs-you/failed/connected; demote task tag rainbow and settings icon circus to neutral chrome.

3. **One list & density system** — Shared row templates for tasks, activity, feeds, and journal; fix iPhone empty-card floating and iPad task metadata overload in the same grid/rhythm spec.

4. **Single chat + actor transcript language** — Same bubbles, width, permission card, and code blocks on iPhone and iPad; align with web refinement without copying layout verbatim.

5. **iPad content measure and sidebar diet** — Slim sidebar information architecture, consistent column padding, and max-width detail columns so intelligence and tasks feel edited, not dumped into a full-bleed log.
