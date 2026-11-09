## Scores

| Category | Score | One-line reason |
| --- | --- | --- |
| Native | 6.8 | Strong Liquid Glass tab bar and grouped lists, but a persistent four-tab bar on pushed lists and uneven navigation chrome read more “custom shell” than stock depth. |
| Typography | 7.1 | SF hierarchy is mostly disciplined and the article serif is a nice exception; task metadata, feeds, and widgets cram too many sizes into one row. |
| Hierarchy | 6.4 | Actor permission and iPad Dashboard land well; Intelligence, task rows, and chat tables split attention among equals instead of one primary focus. |
| Spacing & density | 6.7 | iPad Dashboard breathing room is professional; iPhone tasks, Intelligence, and medium widgets run tight and rhythm varies screen to screen. |
| Color & contrast | 7.0 | Orange/red/green/indigo semantics mostly hold in-app; Settings rainbow tiles, widget red dates, and overloaded orange on permission cards dilute meaning. |
| Iconography | 6.6 | Agent discs and the orange “needs you” hand are distinctive; workspace outlines, Settings tiles, and extension monograms feel like separate families. |
| Consistency & polish | 6.3 | Repeated patterns (section counts, row chrome, tab bar presence, metadata strips) drift between tabs, sheets, and extensions. |
| Overall | 6.6 | Credible native professional tool with personality, not yet the tight, single-voice system an Apple Design Award screen implies. |

## Problems

1. **07-iphone-tasks-light.png, 13c-ipad-tasks-light.png** — Each row stacks title plus date, assignee avatar, size, tags, and flag on one or two lines, so nothing reads as primary. **Fix:** One `.subheadline` secondary line (due · assignee · one tag); move size, extra tags, and flag to swipe actions or the detail sheet only.

2. **02-iphone-intelligence-light.png, 13-ipad-split-view-light.png** — Pinned hero avatars and the full Agents list duplicate the same destinations with different layouts. **Fix:** Choose one pattern (sidebar-style list with pins, or a single horizontal “Pinned” strip); demote the other to a compact row or remove it on iPhone.

3. **01-iphone-dashboard-light.png** — The Atlas composer occupies prime vertical space while “Due” carries overdue work; greeting + field compete with actionable tasks. **Fix:** Collapse the composer to one line when Due has items, or place Due above the field with a shorter greeting (`.title2` / `.title3`, not display-scale).

4. **07-iphone-tasks-light.png, 08-iphone-journal-light.png, 10-iphone-documents-light.png, 12-iphone-contact-light.png** — The root tab bar stays visible on pushed Workspace routes, which is atypical for hierarchical drill-in and steals bottom inset. **Fix:** Hide the tab bar on nested navigation stacks; keep only back affordance and in-context actions.

5. **14-settings-light.png, 17-agent-info-light.png, 44-extensions-light.png** — Saturated per-row icon tiles echo system Settings but clash with the app’s indigo + agent palette. **Fix:** Monochrome SF Symbols at `.secondary` with optional small agent-colored avatar only where identity matters—not a full rainbow grid.

6. **04-iphone-feeds-light.png** — Author, source, “Not Fetched,” and timestamp share one line, causing ellipsis fights with the chevron. **Fix:** Title on line one; `.subheadline` secondary for author · source; timestamp right-aligned on line two or as `.caption` tertiary.

7. **05-iphone-agent-chat-light.png** — The three-column Markdown table is illegible at phone width. **Fix:** Replace with stacked cards (task / due / owner), a single summary sentence, or horizontal scroll with fixed column headers—not a squeezed table.

8. **06-iphone-actor-session-light.png, 13d-ipad-actor-session-light.png** — Permission UI uses orange border, orange glyph, orange copy, plus indigo Allow; the card shouts from every edge. **Fix:** One orange signal (icon + “Needs you” label); neutral card fill; indigo for Allow only.

9. **54-widget-tasks-medium-light.png, 55-widget-tasks-large-light.png, 56-widget-tasks-extralarge-light.png** — “Nov 3/4/5” render in red without “Overdue,” so red reads like failure, not lateness. **Fix:** Match in-app: red only with “Overdue” or relative “3d late”; future/near dates stay `.secondary`.

10. **50-widget-agents-small-light.png, 51-widget-agents-medium-light.png** — The oversized “3” dominates the small widget and fights the avatar stack. **Fix:** At small size, lead with avatars + one `.headline` line (“3 need you”); drop the display-scale numeral.

11. **52-widget-agents-large-light.png** — Header repeats small/medium (avatars + “3” + sentence) then lists agents; vertical hierarchy is redundant. **Fix:** Large widget: drop the big numeral; open with sentence + list, or numeral as a small badge on the stack.

12. **12-iphone-contact-light.png** — Message, Call, FaceTime, and Email are all indigo, so no primary action and it reads like a link list. **Fix:** `.label`-colored symbols with captions; at most one indigo emphasis (e.g. Message) if you need a default.

13. **26-task-detail-light.png** — The title sits alone in a tall card, pushing metadata below the fold. **Fix:** Large editable title under the nav bar (Reminders-style); one grouped form for notes and fields.

14. **34-article-light.png** — Floating circular toolbar controls float over long-form serif body and feel like a different app chrome. **Fix:** Standard inline navigation bar (back, share, more) with `.toolbarBackground`; keep serif confined to content.

15. **13c-ipad-tasks-light.png** — Date pills, assignee chips, and flags form uneven columns so scans don’t line up row to row. **Fix:** Fixed grid (e.g. due 88pt, assignee flexible, flag 24pt) or drop to two columns (title block + trailing due/flag only).

16. **02-iphone-intelligence-light.png** — The Actors row is clipped by the tab bar, implying scroll/content inset bugs. **Fix:** Respect safe area / scroll content margins so the last section clears the glass tab bar.

17. **01-iphone-dashboard-light.png, 13-ipad-split-view-light.png** — What’s New row icons (hand, checkmark, agent disc, failure) sit at inconsistent visual weights. **Fix:** Uniform 28pt status circle + glyph; agent rows use the same disc size as status rows.

18. **57-live-activity-lockscreen-light.png, 58-live-activity-expanded-light.png** — The three-segment bottom bar (gray / indigo / orange) has no label and reads decorative. **Fix:** Remove it, or replace with a single “1 needs you · 2 working” caption using the same semantics as in-app.

19. **44-extensions-light.png** — The list card stops mid-sheet with a large empty gap, feeling unfinished. **Fix:** Full-height inset list, or a short footer (“5 extensions”) / `.contentMargins` so the sheet feels intentional.

20. **03-iphone-workspace-light.png** — “Studio” reads as a huge title with emoji while “Tasks” and “Views” are whisper-small caps; the workspace switcher and sections feel like different products. **Fix:** `.largeTitle` or inline picker for Studio; section headers at `.footnote` + `.secondary` consistently with Dashboard “Due”.

21. **59-live-activity-compact-light.png** — Compact trailing ring shows “1” in orange without the hand glyph used elsewhere for “needs you.” **Fix:** Reuse the orange hand (or orange dot + count) so compact matches lock screen and expanded Live Activity.

22. **53-widget-tasks-small-light.png** — “Review the ro…” truncates aggressively; checkbox + title compete in minimal width. **Fix:** Shorter row template (checkbox + single line, no header count on small), or title-only with due as `.caption2` under one task.

## What works

- **13-ipad-split-view-light.png** — Three-column Dashboard (Due + What’s New + composer) gives a designed “morning briefing” layout that feels iPad-native and on-brand.
- **06-iphone-actor-session-light.png** — The permission prompt’s copy, command preview, and Allow/Deny pairing make the blocking state obvious—a core differentiator done clearly.
- **02-iphone-intelligence-light.png, 05-iphone-agent-chat-light.png** — Agent-colored discs and chat attribution give personality without abandoning system typography.
- **01-iphone-dashboard-light.png, 13-ipad-split-view-light.png** — What’s New status colors (orange needs you, red failed, muted done) align with the product’s semantic palette in a scannable list.
- **34-article-light.png** — Serif headline/body with restrained chrome (aside from the toolbar issue) signals “reader” mode and elevates Feeds above a generic link list.

## To reach 9+

1. **Navigation chrome** — Hide the root tab bar on pushed Workspace (and similar) stacks; adopt consistent large titles / inline titles so depth matches iOS 27 expectations (**07, 08, 10, 12** and siblings).

2. **Task list IA** — Redesign phone and iPad task rows to title + one secondary metadata line; relocate size, tags, and neutral flags to detail or swipe (**07, 13c**).

3. **Settings & sheets visual system** — Replace rainbow Settings tiles with one icon treatment (glyph + optional identity color) across Settings, agent info, and extensions (**14, 17, 44**).

4. **Intelligence home** — Simplify to one entry pattern (pinned strip *or* list, plus Actors that isn’t truncated) so the tab has a single obvious next action (**02, 13**).

5. **Extension surfaces parity** — Widgets and Live Activities should use the same overdue / needs-you / failed language and weights as the app; simplify agents widget hierarchy and clarify or remove the LA progress strip (**50–56, 57–59**).
