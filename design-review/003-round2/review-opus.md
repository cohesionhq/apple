## Scores

| Category | Score | One-line reason |
| --- | --- | --- |
| Native | 7.2 | Glass toolbars, tab bar, inset-grouped lists and sheets are correct, but custom chat/session headers fight the scroll-edge system and iPad sidebar chrome collides with content. |
| Typography | 7.0 | Body and list type is mostly standard and the article's serif adds personality, but metadata often drops to caption2/tertiary, inline code is heavier than body, and there are five different title treatments. |
| Hierarchy | 6.6 | Dashboard, Intelligence and the actor session lack a clear focal action; the permission card, the most important thing on its screen, is the muddiest element there. |
| Spacing & density | 6.5 | The iPhone list rhythm is fine, but there are dead gaps (Dashboard composer to What's New), cramped right edges (table, iPad toolbar), and iPad detail panes waste width. |
| Color & contrast | 6.8 | Indigo is used with restraint, but priority flags reuse orange and red, gray-on-gray cards and tertiary text weaken contrast, and toolbar tint varies. |
| Iconography | 6.5 | SF Symbols throughout, but the tab bar mixes heavy filled blocks with thin outlines, status icons mix fill and outline, and some glyphs are unclear (All Feeds, Dashboard). |
| Consistency & polish | 5.9 | Visible overlaps (iPad Settings pill, chat header over text), the tab bar shows on one detail screen and not another, and lists, metadata and tint differ from screen to screen. |
| Overall | 6.5 | It reads as a competent native app that is about two rounds from looking designed; the collisions alone would stop a professional from believing a designer signed off. |

## Problems

1. **13-ipad-split-view, 13b, 13c, 13d**: the floating "Settings" glass pill at the bottom of the sidebar sits on top of the Actors row ("to the change sock…", "Needs you"). In 13d it also covers the selected row's indigo fill. **Fix:** move Settings to the sidebar's top toolbar as a gear next to `…`, or make it the last plain row of the list. If it has to stay pinned, use `.safeAreaInset(edge: .bottom)` so the list's content inset clears it.
2. **13b-ipad-agent-chat, 13d-ipad-actor-session, 06-iphone-actor-session**: the custom headers float over scrolled content without enough separation. In 13b, "Raise the middle card less… lift makes the outer two" reads through and around the Atlas capsule. In 13d, the tiny "apple" subtitle sits on top of diff lines. **Fix:** use the real navigation title with `.navigationSubtitle` (or a `.principal` toolbar item) and let the system scroll-edge effect handle it, with `.scrollEdgeEffectStyle(.hard, for: .top)` on dense transcripts. Set the subtitle in .subheadline secondary, not caption2.
3. **06-iphone-actor-session, 13d**: the permission card is the main action on the screen, but it is gray card + gray command box + gray note field + gray Deny button, so it reads as disabled. **Fix:**
   - Make the card a white or `.regularMaterial` surface with a 1pt orange-tinted stroke, or a 6% orange tint.
   - Put the command on `.quaternary` fill.
   - Make Deny `.bordered` (not a solid gray fill) and keep Allow `.borderedProminent`.
   - Make `…` a borderless icon button.
   - Use .subheadline secondary for "in /Users/…", not caption tertiary.
4. **05 vs 06**: the agent chat hides the tab bar, but the actor session keeps it. In 06 that stacks a spinner circle, follow-up field, stop button and tab bar into about 200pt of bottom chrome. **Fix:** hide the tab bar on every transcript screen (`.toolbarVisibility(.hidden, for: .tabBar)`). Fold the spinner and stop button into the composer: the field gets a trailing stop button while the session is working and send otherwise, and the working state moves to the header subtitle.
5. **13d-ipad-actor-session**: "Allowed for this session." is drawn as an indigo user bubble, so a system decision looks like something the user typed. The permission card also stops at about 520pt while the transcript column is about 740pt. **Fix:** render decisions as a centered .footnote secondary system row with a checkmark.shield glyph, and make every card in the transcript the column's full width.
6. **07-iphone-tasks, 13c-ipad-tasks, 26-task-detail**: priority flags are orange, red, gray and light gray. Orange already means "needs you" and red means failed, and the gray "Medium" flag looks like "no priority". **Fix:** show priority with the flag glyph's fill and count (`flag`, `flag.fill`, `exclamationmark`/`!!` style) in one neutral or indigo tint, or use a dedicated priority hue that isn't in the status palette. Hide the flag entirely for no priority.
7. **07, 13c**: the task metadata line uses three treatments side by side: size as a gray pill with a ruler glyph, tags as gray pills, and folder as plain text. Size and tag pills are indistinguishable. **Fix:** keep only tags as pills, using a lighter `.quaternary` fill with a `#` prefix or tag glyph. Show size and folder as plain .subheadline secondary text separated by `·`.
8. **13c-ipad-tasks**: there is one 1100pt-wide list with flags stranded about 800pt from their titles, and the toolbar's glass group nearly touches the right edge (about 8pt margin). **Fix:** on regular width use a SwiftUI `Table` (Title, Due, Assignee, Size, Folder, Priority columns) or cap the list at a readable width. Respect the standard 20pt trailing toolbar margin.
9. **All screens**: the title style changes from screen to screen:
   - Large title: Intelligence, Feeds, Extensions.
   - Inline centered: Journal, Documents, Task.
   - Inline leading: Inbox.
   - Title menu: Workspace "Studio".
   - No bar at all: Dashboard.

   **Fix:** use large titles on all root tabs (Workspace can be a large title with the workspace menu as `.toolbarTitleMenu`) and inline centered titles on all pushed screens, including Inbox.
10. **01-iphone-dashboard, 13**: What's New is a plain list on a white background, while every other tab uses inset-grouped cards on gray. Titles truncate to one line ("Add backoff to the change socket's rec…"). The gap between composer and section is about 110pt. Dashboard is the only tab without the settings gear. **Fix:**
    - Use the same inset-grouped card style.
    - Allow 2 lines for titles.
    - Close the gap to about 32pt.
    - Add the gear (or a profile avatar) to the toolbar like the other tabs.
11. **01, 13**: the greeting uses the full name over two lines ("Fresh start, / Jackson Zamorano"), which reads like a form. The most important item, the orange Needs-you row, has the same weight as the Done and Failed rows. **Fix:** use the first name only on one line. Pull Needs-you items into a highlighted card above What's New, with the orange glyph and an inline "Review" button, so the screen has one clear action.
12. **Tab bar (all iPhone shots)**: Dashboard (filled stacked bars) and Workspace (filled 2×2 grid) are heavy solid blocks, while Intelligence (sparkles) and Feeds (antenna) are thin outlines. The Dashboard glyph reads as "list", not "home". **Fix:** use one rendering for all four (outline when unselected, fill when selected), e.g. `house`/`rectangle.grid.1x2`, `sparkles`, `square.grid.2x2`, `dot.radiowaves.up.forward`.
13. **01, 13**: the status icons mix styles: a filled orange hand disc, an outline gray check circle, an outline red xmark circle, an agent avatar disc and a dotted spinner circle. **Fix:** use one style, all `.fill` circles tinted by status (orange, green/secondary, red), at the same 28pt as the agent avatar.
14. **02-iphone-intelligence**:
    - The pinned avatars are about 60pt and dominate the screen, while list avatars are about 24pt.
    - Scout's label is light gray with no explanation (offline? paused?).
    - The Juniper row is shorter than the others because it has no team.
    - "Teams" (a navigation action) sits inside the Agents content list.

    **Fix:**
    - Shrink pins to 48pt with .footnote labels.
    - Show offline as a status dot or "Offline" subtitle, not dimmed text.
    - Give every agent row a subtitle (team or "No team") so heights match.
    - Move Teams to the toolbar `…` menu or its own section footer link.
15. **26-task-detail**:
    - The Notes section shows text and then a separate "Edit Notes ›" row; make notes an inline editable `TextField(axis: .vertical)`.
    - The Size row shows two values ("None  Set Size"); make it a menu picker like the rows around it.
    - The Status "Incomplete" picker duplicates the checkbox; replace it with a completion toggle or drop it.
    - The JZ avatar touches "You"; add 6pt of spacing.
16. **14-settings, 17-agent-info**: a prominent indigo checkmark (confirm) closes sheets that have nothing to confirm. **Fix:** use a plain glass `xmark` close button (or "Done" text). Keep the prominent checkmark for editing sheets like the task sheet, where it already correctly appears gray until there are changes.
17. **05-iphone-agent-chat, 06, 34-article**: inline code chips render larger and darker than the surrounding body text (`hellocohesion.io`, `scenePhase`, `@Observable`), and code blocks clip mid-word ("Dura", "isn't t") with no scroll affordance. **Fix:** set inline code to monospaced at 0.9× body size with a `.quaternary` background. Give code blocks a trailing fade mask (or wrap lines on compact width) and full 16pt internal padding. In 34, keep the block's bottom out from under the device corner.
18. **05-iphone-agent-chat**: the Markdown table runs into the right margin ("Owner" sits about 30pt from the edge against 28pt on the left, and the column is cramped). The cue banner truncates ("Cue 'Morning briefing' fired: The…"). **Fix:** put tables in a horizontally scrolling container with equal margins and .subheadline type. Trim the cue banner text to "Morning briefing · 2 steps" with the bolt.
19. **05, 13b**: the header subtitle "Chief of staff: plans my week and k…" always truncates. **Fix:** drop the description from the header and show the name plus a live status ("Working…", "Online"), leaving the description to the info sheet.
20. **05, 06, 13b, 17**: too much small tertiary text: the "• Atlas" sender label, "Bash swift test…" tool rows, "Noted:…" and "Context rebuilt…" lines (caption2 tertiary), and "tokens" under 48K. **Fix:** set these at a .footnote minimum in secondary. Sender labels get .footnote semibold in the agent's color.
21. **13b-ipad-agent-chat**: in the A/B/C slot-choice card, the unselected options are light gray on gray and look disabled, and the selected option's check is faint. **Fix:** draw the options as white rows on the card, with the selected one getting an indigo 1.5pt border and a filled `checkmark.circle.fill`. Keep the A/B/C letters at .subheadline secondary.
22. **44-extensions-light**: every extension has an identical gray letter tile, the descriptions truncate, and the `+` is indigo while the `+` buttons in Documents, Intelligence and Inbox are black. **Fix:** give tiles real icons, or tint letter tiles from a stable hash of the identifier. Allow 2-line descriptions. Make all toolbar glyphs one tint (label color), with indigo only on the prominent confirm button.
23. **34-article-light**: within one glass group, the refresh and share icons are indigo and `…` is black. The bullets are tiny gray dots that don't optically align with the serif cap height. **Fix:** use one tint in the group, and make the bullets body-weight `•` in primary at the first line's baseline.
24. **12-iphone-contact**:
    - The quick-action buttons are bare indigo glyphs, unlike Contacts' platter buttons.
    - "Email" appears both as an action and as a row.
    - "Add Email…" and "Add Phone…" show in read mode.
    - The avatar is a flat gray disc.

    **Fix:**
    - Put the four actions in equal-width glass platters.
    - Move the Add rows behind Edit.
    - Tint the avatar with a stable per-contact color, as agents have.
25. **04-iphone-feeds-light**: the tab is five rows and 60% empty space, and the "All Feeds" glyph reads as a jar. **Fix:** make Feeds a reading river: the latest unread articles as cards with source, title and two-line excerpt, plus a feed filter in the title menu. Use `tray.full` or `square.stack` for All.
26. **10-iphone-documents-light**: the rows have no leading glyph (Workspace, Feeds and Journal rows do), and the relative dates are long and inconsistently capitalised ("40 minutes ago", "yesterday" under a "Today" header). **Fix:** add a `doc.text` glyph in indigo and use short times (".subheadline secondary": "40m", "5h", "Yesterday", "Nov 5").
27. **03-iphone-workspace-light**: Launch, Product and Admin share the same folder glyph. Inbox and All use near-identical tray glyphs. The connectors the index promises aren't visible above the fold. **Fix:** let folders carry a user color or emoji, and use `tray` for Inbox and `square.stack.3d.up` (or `list.bullet`) for All. Collapse Views into a disclosure group so the Tasks and connectors sections fit.
28. **13-ipad-split-view, sidebar**:
    - "New Agent" is black and "Teams" indigo, side by side.
    - The pin glyphs on Atlas and Scout add noise to every row.
    - The selected row uses a full-saturation indigo fill, heavier than iPadOS's selection.
    - The Tasks icon (`checklist`, two-tone) is a different family from its outline neighbours.

    **Fix:**
    - Give both action rows the same accent style.
    - Show pinned agents in their own "Pinned" group instead of the pin glyphs.
    - Use the system sidebar selection (tinted, not solid).
    - Use the outline `checklist` to match.
29. **13-ipad-split-view-light**: the Working row's title is gray and looks disabled. The content column is centered with about 225pt of dead margin on the left and a lot of empty space below. **Fix:** keep titles primary and show "working" with an animated indicator. On regular width, lay out What's New and Working as two columns, or add a Today and tasks column beside them.
30. **17-agent-info-light**: the "Context 48K tokens" card is a bare number with a stacked unit and no meaning (48K of what?). The sheet has no primary action. **Fix:** show a context gauge (`Gauge` / progress bar, "48K of 200K") and add a "Message Atlas" prominent button plus a Pin toggle under the header.
31. **08-iphone-journal-light**: "Saturday 7" reads oddly, and the Today card's "Morning" subtitle is unexplained. **Fix:** use "Saturday, Nov 7" (or a leading day-number badge column for some personality) and label the Today subtitle "Morning entry".

## What works

- The indigo accent is mostly reserved for interactive elements and selection, and the orange hand for "Needs you" is used consistently across the Dashboard, Intelligence, the sidebar and the permission card.
- The Settings and agent-info screens use squircle colored icons in inset-grouped lists, which is exactly the iOS Settings idiom and reads instantly.
- The article reader's serif type (New York) and generous measure give the app a real personality without breaking nativeness.
- The agent chat's mix of indigo user bubbles and unbubbled Markdown assistant replies reads well for long, structured answers.
- On the task sheet, the gray-until-dirty confirm checkmark next to an xmark close is correct iOS 26/27 behaviour.

## To reach 9+

1. **Fix every collision and chrome-stacking issue**: move the iPad sidebar Settings pill, use system titles and subtitles with proper scroll-edge effects on chat and session screens, hide the tab bar on all transcripts, and merge the spinner and stop button into the composer. This raises Consistency, Native and Overall the most.
2. **Redesign the permission and choice cards as the hero of their screens**: white or material surface with an orange accent stroke, bordered Deny, readable .subheadline secondary metadata, and options that don't look disabled. Do the same for the Dashboard's Needs-you items as a prominent card with an inline action. This lifts Hierarchy.
3. **Unify the visual system**: one title convention (large on tabs, inline centered on pushes), one toolbar tint, one list style (inset-grouped everywhere, including the Dashboard), one icon rendering in the tab bar and status icons, and one metadata pattern for tasks (plain secondary text plus tag pills). This lifts Consistency and Iconography.
4. **Take priority off the status palette** and raise every caption2/tertiary label to a .footnote secondary minimum. Make inline code smaller than body, not larger. This lifts Color & contrast and Typography.
5. **Use the iPad's width**: a `Table` for tasks, two columns on the Dashboard, consistent transcript column widths. On iPhone, make Feeds a reading river rather than a five-row list. This lifts Spacing & density and makes the app feel designed rather than assembled from lists.
