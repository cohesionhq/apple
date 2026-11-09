## Scores

| Category | Score | One-line reason |
|---|---|---|
| Native | 7.3 | Glass toolbars, the floating tab bar, inset-grouped lists and sheets are right, but the chat header, the solid sidebar selection, checkmark buttons on read-only sheets and glass that doesn't clear content all break the system's own rules. |
| Typography | 7.0 | The article reader and chat Markdown are good, but the dashboard greeting is too large, section headers come in three styles, and the caption2 footnotes and XL widget text are too small. |
| Hierarchy | 6.5 | The most important action (the permission card) looks disabled, the dashboard greeting pushes What's New below the fold, and "Working" items look like disabled rows. |
| Spacing & density | 6.4 | Phone lists are even, but the large and XL widgets are 50–60% empty, sidebar rows are tall, the XL columns don't line up, and there's a dead gap above What's New. |
| Color & contrast | 6.3 | Orange, red and green each mean more than one thing (flags, overdue dates, done, stop), orange text sits on the indigo selection, and the cards are grey on grey. |
| Iconography | 6.8 | SF Symbols are mostly consistent, but the brand mark looks like the Feeds RSS glyph, the "All Feeds" glyph is unclear, extensions get placeholder letter tiles, and emoji avatars are hard to read at small sizes. |
| Consistency & polish | 6.0 | Title styles, where "add" lives, toolbar tint, relative-time format and the "working" state all vary from screen to screen. Glass overlaps text in several shots. |
| Overall | 6.6 | A careful developer clearly built it on good native foundations, but it doesn't yet read as one designer's system. |

## Problems

1. **06-iphone-actor-session, 13d-ipad-actor-session: the permission card is the screen's main action but looks disabled.** It is a systemGray6 card holding grey command and note wells, with a grey filled Deny button and a grey "…" circle. That is three nested greys, and only the thin orange stroke says "needs you."
   - Make the card `secondarySystemGroupedBackground` (white) with a 1.5pt orange stroke, or a 4% orange tint and an orange header row.
   - Keep the command block as the only inset fill (tertiarySystemFill).
   - Make Deny a `.glass` / bordered button, not grey filled, and fold "…" into a menu on Deny.
   - On iPhone, pin the card above the composer in a `safeAreaInset(edge: .bottom)` so it can't scroll away.

2. **13d-ipad-actor-session: on the selected sidebar row, orange "Needs you" text sits on the solid indigo pill and is nearly unreadable.**
   - Selected rows across the sidebar (13, 13b, 13d) are saturated filled capsules, which is heavier than the iPadOS 26 sidebar selection. Use the standard selection: a tinted indigo at about 15% opacity with primary text.
   - If the solid fill stays, turn every foreground on the selected row white, including the hand glyph and the status text.

3. **05-iphone-agent-chat, 13b-ipad-agent-chat, 06, 02, 03, 12: glass overlaps content that hasn't been inset.**
   - 05: the "Message Atlas" composer sits on top of the table rows ("Record demo video 2026‑11‑12 You"), so the placeholder and the table text collide.
   - 13b: "Raise the middle card less…" shows through behind the "Atlas >" header.
   - 06: the "Write Tests/…BackoffTests.swift" row is sliced in half by the title bar.
   - 03 and 12: tab-bar ghosts like "Cancelled" and "Prefers press assets" are readable through the glass.
   - Fix: put composers in `safeAreaInset(edge: .bottom)`, give the custom chat header a real `scrollEdgeEffectStyle(.soft)` backdrop, and end every scroll view with bottom padding equal to the bar height plus 16pt.

4. **07, 13c, 54–56, 57/58, 06: semantic colours drift.**
   - Orange means "needs you", but it is also the high-priority flag and, in the Tasks widgets, the colour of overdue dates. In the app (13c), overdue is red.
   - Red means failed, but it is also the urgent flag and the Stop button.
   - The Live Activity uses green for done, while the dashboard shows done as a grey check, and the brief says green means connected.
   - Fix:
     - Overdue is red everywhere, widgets included.
     - Priority flags use their own scale: indigo for high, red only for urgent, and no flag at medium or low. Then orange is never decoration.
     - Done is a grey or indigo check everywhere, the Live Activity included.
     - Stop is a neutral `stop.fill` in a glass button, not red.

5. **50/51 agents widgets: the small widget says "3 Need you", but the medium shows Ada "Reading 12 of 40 sources", so only 2 need you.**
   - The count must count only the agents that need you, and it should be orange with a hand glyph.
   - On the medium widget, "Needs you" is grey `.secondary`; make it orange to match Dashboard and the Live Activity.
   - The widget sample data (Ada, Milo, Juno) doesn't match the app's agents (Atlas, Quill…). Use the same `PreviewData` so the widgets can be judged against the app.

6. **52, 55, 56: the large and XL widgets waste half their area.**
   - 52 large repeats the medium's three rows over a blank lower 60%.
   - 55 shows five tasks and then empty space.
   - In 56 XL, the two columns' rows don't line up (the left rows have dates, the right rows don't). The flags float mid-column, the bottom half is empty, and the 13pt text looks tiny in that panel.
   - Fix: row counts per family (medium 4, large 8–9, XL two aligned columns or one list with a trailing date column). The large agents widget should add each agent's last-message preview. Any empty tail gets a quiet "All caught up" footer, not blank space.
   - 54 medium shows only 2 tasks plus "3 more" when 3–4 fit.

7. **13-ipad-split-view, 57/58, 06: "Working" is drawn three ways.**
   - The dashboard's Working row is tertiary grey text with a dashed grey circle, so it reads as disabled.
   - The Live Activity uses indigo `arrow.triangle.2.circlepath`.
   - The actor session uses a spinner in a circular button.
   - Pick one indigo working mark (an animated ring or the circular arrows), and keep the title primary with "Working · now" in secondary.

8. **01-iphone-dashboard: the greeting runs to two lines of ~34pt bold with the full name and takes the top third of the screen.**
   - Use the first name only ("Let's get going, Jackson") at `.largeTitle` on one line, or a standard large title "Today" with the date as a subtitle.
   - Cut the ~70pt gap between the Atlas/Quick Journal row and What's New to 28pt, so 4 items show above the tab bar instead of 2.5.

9. **Titles differ by screen; set one rule.**
   - Large title: 02 Intelligence, 04 Feeds, 44 Extensions (a pushed page).
   - Centred inline: 08 Journal, 10 Documents, 14 Settings.
   - Leading inline: 07 Inbox.
   - Switcher pill with no title: 03 Workspace.
   - No title: 01 Dashboard, 13 iPad.
   - A title menu: 13c "All ⌄".
   - Rule: tab roots use a large title, and the Workspace root becomes large-title "Studio" with the switcher as a `toolbarTitleMenu`. Pushed screens (Inbox, Journal, Documents, Extensions) use a centred inline title.

10. **04, 12, 02, 13, 10, 44, 07: "add" lives in a different place on each screen.**
    - Inline accent rows: "Add Feed" (04), "Add Email…" / "Add Phone…" (12), "Teams" inside the Agents list (02), "New Agent" in the sidebar (13).
    - Toolbar +: Documents (10), Extensions (44), Inbox (07).
    - The toolbar + is black on 10 and indigo on 44.
    - Fix: creation is always a toolbar + in the label colour. Contact field additions move into Edit mode. "Teams" becomes a toolbar or menu destination, not a fake row in a data list.

11. **07-iphone-tasks, 13c-ipad-tasks: task metadata has too many styles.**
    - One line holds a calendar glyph and date, an avatar and name, a size chip with a ruler icon, tag chips that look identical to the size chip, and the folder as plain text. Then a trailing flag, and a grey flag even for Medium.
    - Drop the calendar glyph and colour the date only when it's due or overdue.
    - Hide the assignee when it's you.
    - Show size as plain secondary text, and tags as tinted `#waiting` text without capsules.
    - Show the folder only in cross-list views, and show the flag only for high or urgent.

12. **26-task-detail: the edit sheet mixes control styles.**
    - Size is an indigo "Set Size" button where every other row shows a grey value with up/down chevrons. Show "None ⌃⌄" like the rest.
    - Tags shows a bare chevron; show "None" or the tag count.
    - Notes need a second screen ("Edit Notes >"); make notes an inline multi-line `TextField(axis: .vertical)`.
    - Status "Incomplete" as a menu duplicates the checkbox; put a completion circle beside the title instead.

13. **05-iphone-agent-chat, 13b-ipad-agent-chat: the chat header (a 64pt avatar stacked over an "Atlas >" capsule) costs about 120pt and doesn't sit on its own background.**
    - Use a single glass title pill (28pt avatar plus name and chevron) in the principal toolbar slot, as Messages does on iOS 26.
    - Tint the hairline or the avatar ring with the agent's colour for personality.

14. **05-iphone-agent-chat: chat content details.**
    - The table runs edge to edge with no container, and its dates mix "Today", "Tomorrow" and "2026‑11‑12". Format every date in a reply the same way ("Thu, Nov 12").
    - Put tables in a rounded tertiary container with horizontal scroll.
    - The cue row truncates its own subject ("Cue "Morning briefing" fired: The…"). Shorten it to "Morning briefing · 2 steps".

15. **06-iphone-actor-session, 34-article: code blocks clip at the right edge with no sign they scroll.** Use a horizontal `ScrollView` with a trailing fade mask. In 34, the code block's bottom corners are also cut off by the screen edge, so add bottom padding.

16. **13 / 13b / 13c sidebar: low density and unexplained states.**
    - Scout is dimmed with no reason given. Show offline as a grey status dot on the avatar and keep the name primary.
    - Pinned agents repeat a grey pin glyph on every row. Make "Pinned" its own section instead.
    - Two-line agent rows (name over team) double the height. Put the team in a trailing caption or group agents by team.
    - "Teams" is indigo while "New Agent" is label colour. Use the same style for both.

17. **02-iphone-intelligence: the pinned row has two 120pt avatars, left-aligned, with a big empty right half, and Scout's label is dimmed.**
    - Use 64pt avatars in a 4-column grid like Phone's Favourites, with a status dot overlay (orange for needs you, indigo for working).
    - Put the Actors section, which holds the one item needing you, above Agents.

18. **57/58/59 Live Activity, 04 Feeds: the brand mark (a quarter-circle of indigo arcs) reads as the RSS/Feeds symbol used for the Feeds tab and feed rows.** In the Dynamic Island it looks like "a feed is updating." Use a distinct mark.
    - In 59, the compact trailing ring shows "3" with no meaning; show an orange `hand.raised.fill` plus the needs-you count when there is one.
    - In 57, "+3 more" sits on the counts row and doesn't say what it adds; spell it out ("+3 done").

19. **12-iphone-contact: the quick actions are bare icons and labels floating on the background.**
    - Make them iOS 26 Contacts-style glass tiles: equal-width rounded rects, icon over label.
    - The 160pt grey monogram is generic; tint it with a stable per-contact hue, or use indigo at low saturation.

20. **14-settings, 17-agent-info: read-only sheets end in a filled indigo checkmark.** That reads as "save", but nothing was edited. Use a plain xmark close button, or "Done".
    - 14: "Server" is jargon, and "About" doesn't belong in it. Use sections "Workspace", "This iPhone", then About on its own.
    - 17: "48K" stacked over a tiny tertiary "tokens" is odd. Show a gauge, "48K of 200K tokens", in one line.

21. **44-extensions: grey "G / L / D / I / C" letter tiles look like placeholders.** Give each extension a category symbol (`link`, `bell.badge`, `checkmark.seal`) in a tinted tile like Settings' rows, or use real marks when the extension provides one.

22. **01, 10, 34, 13, 08: relative times use five formats.**
    - Dashboard: "2m ago".
    - Documents: "40 minutes ago" and lowercase "yesterday".
    - Journal: "Yesterday".
    - Article: "Fetched 1 hour ago".
    - Dashboard: "now".
    - Use one formatter: abbreviated ("40m", "5h", "Yesterday", "Nov 3") and capitalised. Replace "Fetched" with "Updated".

23. **13b-ipad-agent-chat: the system notes "Noted: Demo recording…" and "Context rebuilt because provider cache expired" are caption2 tertiary (about 11pt grey).**
    - That is too small, and "provider cache" is internal jargon.
    - Use `.footnote` secondary for memory notes and hide cache events, or put them behind disclosure.

24. **13b-ipad-agent-chat: the answered choice card is grey on grey, and the selected option B has only a pale lavender check.**
    - Show the chosen option in primary text with a solid indigo check.
    - Dim the unchosen options to tertiary, and drop the card fill to quaternarySystemFill.

25. **34-article: small polish issues.**
    - The toolbar tints differ: refresh and share are indigo, "…" is black. Use one tint.
    - Bullets hang about 40pt deep with a tiny grey dot. Use about a 20pt indent and a label-colour bullet.
    - Space above headings is uneven: "What still bites" has its paragraph tight underneath, while "What got better" has more air. Use one heading rule.

26. **01 / 13 dashboard composer: the placeholder and the photo and send icons are very light grey on white, so the composer looks disabled.**
    - Use `.secondary` for the placeholder and icons, and tint send indigo once there is text.
    - The "Quick Journal…" capsule competes with the Atlas picker at equal weight. Make it a smaller icon-plus-label secondary button, or a toolbar item.

27. **53–56 Tasks widgets: the Today sun glyph is system blue, while the app's Today row (03, 13) is indigo.** Use the app's accent so the widget feels like the app.

28. **04-iphone-feeds: the "All Feeds" glyph (a stacked-cards outline) is unclear, and a Feeds tab with four sources is thin.** Use `tray.full` or `newspaper`. Consider opening the Feeds tab straight onto the unread article stream, with sources behind a filter menu, as Reeder and NetNewsWire do.

## What works

- The article reader's serif type (34): the size, line length and inline code treatment feel editorial and deliberate. Keep it.
- The What's New rows (01, 13): a status glyph plus a coloured status word and time is clear and easy to scan, and it uses the semantic palette correctly.
- The Live Activity's structure (57/58): counts by state, three rows and the proportional state bar make it a smart, glanceable summary.
- Settings-style coloured tiles in Settings and agent info (14, 17), and monochrome indigo outline glyphs for navigation (03, sidebar): a sensible split between the two icon styles.
- Chat Markdown (05, 13b): headings, lists, inline code and the compact tool-call rows ("Bash swift test … ✓ 41s") are well judged for a pro tool.

## To reach 9+

1. **Lock the semantic palette and audit every screen against it.** Orange is only needs-you, red is only failed or overdue, green is only connected. Flags get their own scale. Done is neutral everywhere, Live Activity and widgets included. (Raises Color, Consistency.)
2. **Fix glass and content layering.** Composers and bars go in safe-area insets, the chat header gets a proper scroll-edge backdrop, and no text collides with glass. Redo the permission card as a white card with an orange stroke and a clear primary action, pinned above the composer. (Raises Native, Hierarchy, Polish.)
3. **Write one navigation rule and apply it:** large titles on tab roots, centred inline titles on pushed screens, creation always as a toolbar +, close (not checkmark) on read-only sheets, standard sidebar selection with no orange on indigo. (Raises Native, Consistency.)
4. **Redesign the widgets per size.** Right counts with orange emphasis, row counts that fill each family, aligned XL columns, previews in the large agents widget, the app's indigo accent, and sample data matching the app. Give the brand a mark that isn't an RSS glyph. (Raises Spacing, Iconography, Overall.)
5. **Tighten type and density.** One section-header style; a one-line greeting with the first name; nothing below `.footnote` in the app; one relative-time formatter; one-line sidebar agent rows; task metadata reduced to date (when relevant), size text and tinted tags. (Raises Typography, Hierarchy, Spacing.)
