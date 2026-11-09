## Scores

| Category | Score | One-line reason |
| --- | --- | --- |
| Native | 7.6 | Glass tab bar, glass toolbar groups, inset-grouped lists and a real iPad sidebar are right. Floating gear buttons, title placement that changes from screen to screen, and chat headers with no scroll-edge treatment let it down. |
| Typography | 7.4 | The serif article reader and the chat body are good. The two-line 34pt greeting, tertiary metadata at caption sizes, and widget type that doesn't scale on XL are weak spots. |
| Hierarchy | 7.0 | The Dashboard and the permission card point at the right thing. The Intelligence and Workspace screens have no main action, the chat header fights with content, and several screens have no clear primary action. |
| Spacing & density | 7.2 | The iPhone list rhythm is consistent. Widgets and the iPad content column leave big dead areas, the permission card is half-width on iPad, and the iPad chat's user bubbles and cards end at different right edges. |
| Color & contrast | 6.9 | Indigo and orange carry their meaning in the app. Settings-style multicolour icons, an orange priority flag, green "done" in the Live Activity and system blue in widgets all dilute that semantic palette. |
| Iconography | 6.8 | The indigo outline icons in Workspace are coherent. Elsewhere glyph meanings clash (lightning means a cue in chat but "Runs" in Agent Info), some marks are ambiguous (All Feeds, the Dashboard tab), and status icons mix filled and outline. |
| Consistency & polish | 6.6 | Toolbar tint, title position, close-button tint, greeting copy, list style and widget layouts all change between screens that should match. |
| Overall | 7.1 | Reads as a careful, competent native app. It doesn't yet read as one designed system with a signature of its own. |

## Problems

1. **01-iphone-dashboard, 13-ipad-split-view: the greeting differs between devices at the same moment.** Both show "Monday, November 9", but iPhone says "Good morning, Jackson Zamorano" and iPad says "Let's get going, Jackson Zamorano". On iPhone the greeting also wraps to two lines of ~34pt bold, which uses a fifth of the screen.
   - Fix: use one greeting rule on both devices.
   - Use the first name only ("Good morning, Jackson") at `.largeTitle` so it fits on one line.
   - Put the date above it as `.subheadline` secondary, like a Today-style eyebrow.

2. **06-iphone-actor-session, 13b-ipad-agent-chat, 13d-ipad-actor-session: content collides with the header.** Transcript text and code scroll under the title and the "Atlas >" pill. There is a hard hairline but no scroll-edge blur. In 13b the "Atlas" pill sits on top of body text, and in 06 the "Write Tests/…" row is cut by the hairline.
   - Fix: drop the hairline and apply the soft scroll-edge effect (`.scrollEdgeEffectStyle(.soft, for: .top)`) so content fades under the glass title.
   - Put the avatar and name inside a single glass capsule in the principal toolbar slot.

3. **07-iphone-tasks, 08-iphone-journal, 10-iphone-documents, 02-iphone-intelligence, 03-iphone-workspace: the title moves around.** Inbox is leading-aligned next to the back button. Journal and Documents are centred inline. Intelligence, Feeds and Extensions are large titles. Workspace is a centred menu title.
   - Fix: use a large title on every tab root (Dashboard, Intelligence, Workspace with the "Studio" switcher as a title menu, Feeds).
   - Use a centred `.inline` title on every pushed screen. Inbox should be centred like Journal.

4. **14-settings, 17-agent-info: multicolour icon tiles break the semantic palette.** The Settings icon tiles are orange, magenta, pink, blue, teal, red and green. Orange already means "needs you", red failed and green connected, so an orange Profile tile, a red Notifications tile and a green Live Activities tile spend those meanings on decoration.
   - Fix: use monochrome indigo-tinted glyphs, or indigo, grey and neutral tiles, as in the Workspace list.
   - Keep orange, red and green for status only.

5. **01-iphone-dashboard, 13-ipad-split-view: the status glyphs in What's New mix styles.** "Needs you" is a filled orange disc, "Failed" is a filled red disc, "Done" is a hairline outline check, "Working" is a dotted outline, and the Quill row uses an agent avatar in the same column. The outlined rows look disabled next to the filled ones.
   - Fix: use one treatment for all of them: filled 28pt discs (`checkmark.circle.fill` in secondary grey, `hand.raised.circle.fill` orange, `xmark.circle.fill` red, and a determinate indigo ring for Working).
   - Move agent messages into their own "Messages" group, or put a small status badge on the avatar.

6. **13-ipad-split-view: the Working row is greyed out.** "Polish the iPad sidebar spacing / Working · now" is in tertiary grey, so the one live item reads as disabled.
   - Fix: title in primary and "Working" in indigo, with an animated indigo progress ring as its glyph.

7. **34-article, 44-extensions vs 07-iphone-tasks, 10-iphone-documents: toolbar tint is inconsistent.** Refresh, share and + are indigo in the article and Extensions, but + and the filter are black in Inbox, Documents and Intelligence. The close X is indigo in 17-agent-info and 26-task-detail but black in 14-settings.
   - Fix: make toolbar glyphs `.primary` (label colour) everywhere. Reserve indigo for the one confirm action (`.glassProminent` ✓ on a sheet).

8. **26-task-detail: the Done ✓ looks disabled, and "Set Size" breaks the column.** The ✓ is a grey glass circle that reads as disabled, but it is the sheet's primary action. "Set Size" is the only indigo value in a column of grey values with up/down chevrons.
   - Fix: make ✓ `.glassProminent` indigo whenever there are changes.
   - Show Size as "None ⌃⌄" in secondary, like the other pickers.

9. **07-iphone-tasks, 13c-ipad-tasks, 26-task-detail, 54/55/56 widgets: flags clash with the status colours.** The priority flags are orange and red, so an orange flag collides with "orange = needs you" and a red flag with "red = failed". "Medium" is also used for both Size (ruler chip) and Priority, which confuses them.
   - Fix: give priority its own encoding that doesn't use status colours, e.g. `exclamationmark` marks (!, !!, !!!) in label colour as Reminders does, or indigo shades.
   - Rename the size scale to S, M, L or to points.

10. **13c-ipad-tasks: task metadata uses three treatments in one line.** Size is a chip with an icon, tags are plain chips, and the folder ("Launch", "Product") is plain grey text. The rows are busy, and on iPad the list is plain, edge-to-edge, while on iPhone it's an inset card.
    - Fix: drop the chip backgrounds and use a single `.footnote` secondary line separated by "·" (date · assignee · size · #tag). Show the folder only in cross-folder views, as the first item.
    - Use the same list style (inset grouped) on both devices.

11. **17-agent-info vs 05-iphone-agent-chat: the lightning bolt means two things.** In Agent Info, Runs is a magenta lightning tile and Cues is an alarm clock. In chat, the cue chip "Cue 'Morning briefing' fired" uses the lightning bolt.
    - Fix: give each concept one glyph everywhere. Cue = `alarm` / `bolt.badge.clock`, run = `play.circle` or `list.bullet.rectangle`.

12. **04-iphone-feeds: the "All Feeds" icon reads as a jar or trash can.** It is not a recognisable "all" mark.
    - Fix: use `square.stack` or `tray.full`, as in Mail and Reminders.

13. **01, 02, 03, 04 (tab bar): the Dashboard tab glyph is ambiguous.** Two stacked bars read as a database or a "split" icon, and it's heavier than the Workspace grid beside it.
    - Fix: use `square.grid.2x2` for Workspace and `house` or `rectangle.stack` for Dashboard. Check that all four glyphs share the same optical weight.

14. **51-widget-agents-medium, 52-widget-agents-large, 53-56 tasks widgets: widgets use system blue.** The sparkle and sun icons are system blue, while the app's Today, sparkle and accent are indigo.
    - Fix: set the widget's `AccentColor` and tint to brand indigo.

15. **50/51/52 agents widgets: the header contradicts a row.** The header says "Need You 3", but Ada's status is "Reading 12 of 40 sources", which is working, not waiting on the user.
    - Fix: list only agents that actually need the user under "Need You". Alternatively, rename the header "Agents" and colour each row's status: orange "Needs you", indigo working text.

16. **52-widget-agents-large, 55-widget-tasks-large, 56-widget-tasks-extralarge, 54-widget-tasks-medium: large widget sizes are half empty.** The large widgets leave 40–50% blank. XL uses ~20% of its area for a single small-type list. Medium shows 2 rows plus "3 more" when 3 would fit.
    - Fix: fill each size to capacity. Large shows 6–7 rows, with upcoming tasks or recent agent messages filling the rest.
    - XL becomes two columns ("Today" and "Upcoming", or tasks plus agents) at `.body` size.
    - Medium shows 3 rows.

17. **54-widget-tasks-medium, 56-widget-tasks-extralarge: the trailing date column is ragged.** When a row has no flag, "Nov 4" shifts right into the flag slot, so the dates don't line up.
    - Fix: reserve a fixed-width flag slot, even when empty.
    - In 55, dates sit under the titles instead, so the sizes also disagree on layout. Pick one: trailing on medium, large and XL.

18. **57/58/59 Live Activity: three meaning problems.**
    - "Done" counts use a green check, but green means connected.
    - The running glyph `arrow.triangle.2.circlepath` reads as "sync/retry", not "working".
    - The compact ring's "3" doesn't say what it counts.
    - Fix: show done in secondary grey (`checkmark`), running as an indigo spinner or `ellipsis` progress.
    - Make the compact trailing slot the needs-you count in orange when non-zero, otherwise the running count.

19. **02-iphone-intelligence: agent rows are uneven and "Teams" is styled like an action.**
    - Juniper has no team line, so its row is shorter.
    - "Teams" is an indigo row inside the Agents list, styled like an action but used as navigation.
    - Pinned "Scout" has a grey label under a fully saturated avatar, and nothing explains what the grey means.
    - Fix: give every row the same height (show "No team" in tertiary, or centre a single line at a fixed height).
    - Move Teams to its own section or the toolbar ⋯ menu.
    - For an offline agent, desaturate the avatar and add a small status dot instead of greying only the label.

20. **13-ipad-split-view (sidebar): the two action rows look different.** "New Agent" has a black + in label colour, while "Teams" sits beside it in indigo.
    - In 13d, the selected actor row turns "Needs you" white, which loses the orange signal.
    - Fix: style both action rows the same (indigo + and label, or move them into the section header's + menu).
    - On a selected row, keep a small orange dot on the selection fill.

21. **06-iphone-actor-session, 13d-ipad-actor-session: the permission card has three greys and an odd width.**
    - The card stacks grey fill, a grey command block, a grey note field and a grey Deny button inside an orange border, so the layers are muddy.
    - On iPad the card is ~520pt wide in a ~740pt column, while the code block above spans the full column.
    - Fix: make the card fill `.background` (white) with the orange border and a faint orange tint, use a `.bordered` Deny, and keep the note field as the only grey.
    - Make the card full column width.

22. **05-iphone-agent-chat, 13b-ipad-agent-chat: the composer covers content and the chat column edges don't line up.**
    - The iPhone composer floats over the table with the table's text legible underneath.
    - The iPad user bubbles end at x≈1295 while the choice card ends at ≈1242.
    - The answered choice card greys out every option to the same low contrast, including the chosen one.
    - Fix: add a bottom scroll-edge effect behind the composer.
    - Align all chat blocks to one column width.
    - Keep the chosen option in primary text with an indigo fill, and dim only the others.

23. **12-iphone-contact: action buttons and edit rows are wrong for a view screen.**
    - The Message/Call/FaceTime/Email actions are bare glyphs and labels with no platters, unlike the system Contacts card.
    - "Add Email…" and "Add Phone…" rows appear while viewing, not editing.
    - Fix: put the four actions on 64×52 glass or `.secondarySystemBackground` platters.
    - Move the Add rows behind an Edit mode.

24. **44-extensions: the extension icons look like placeholders.** Grey monogram squircles (G, L, D, I, C) look unfinished, and every description is truncated.
    - Fix: use real extension icons, or an indigo-tinted SF Symbol per category.
    - Allow descriptions 2 lines at `.subheadline` secondary.

25. **17-agent-info: the Context row is stacked oddly.** "48K / tokens" is stacked right-aligned in two sizes, so the value reads ragged.
    - Fix: one line, "48K tokens", in `.body` secondary, or a small capacity gauge (`Gauge` in `.accessoryLinearCapacity`) under the label.

26. **08-iphone-journal: Journal has no way to write an entry.** There is no compose action, while Documents has +.
    - Fix: add a `square.and.pencil` toolbar button.
    - Also, Documents shows "yesterday" lowercase while section headers say "Today". Use `.relative(presentation: .named, unitsStyle: .wide)` with sentence case, or switch to absolute times past 24h.

27. **01-iphone-dashboard: the bottom row is hidden and the composer controls are faint.** The last What's New row (Quill) sits half under the tab bar with only its avatar showing. The composer placeholder and icons are tertiary grey, so the photo and send controls nearly vanish.
    - Fix: add bottom content inset so the last row clears the tab bar.
    - Make the attach glyph secondary, and the send button an indigo filled circle once the field has text.

## What works

- The serif (New York) article reader in 34: good measure, generous leading and a clear heading scale. It is the most "designed" screen.
- The orange "Needs you" thread runs from the Dashboard, the sidebar and the Intelligence Actors list to the permission card and the Live Activity. Users learn one signal and see it everywhere.
- The Workspace list (03): monochrome indigo outline glyphs at one weight, consistent row heights. Use this as the model for Settings and Agent Info.
- The iPad sidebar structure: workspace switcher, places, pinned agents and actors in collapsible sections. It's a real iPad layout, not a stretched phone.
- The Live Activity's segmented progress bar and per-row timers: dense, glanceable and on brand.

## To reach 9+

1. **One colour grammar.**
   - Strip decorative colour from Settings and Agent Info tiles, priority flags, widget system-blue and the Live Activity's green "done".
   - Orange, red, green and indigo then mean only needs-you, failed, connected and brand/active.
   - This lifts Color, Iconography and Consistency together.
2. **A chrome spec applied everywhere.**
   - Large titles on tab roots and centred inline titles on pushed screens.
   - Label-colour toolbar glyphs, with a single `.glassProminent` indigo confirm on sheets.
   - Soft scroll-edge effects top and bottom on chat and session screens, with no hairlines.
3. **One status-glyph and metadata system.**
   - A filled-disc status set shared by What's New, the sidebar, Actors and the Live Activity.
   - Single-line "·"-separated task metadata without chips.
   - One glyph per concept (cue, run, working, done).
4. **Rebuild the widgets for each size.**
   - Fill every family to capacity: two columns on XL, 6–7 rows on large.
   - A fixed trailing column for dates and flags, brand tint, and headers whose rows actually match them.
5. **Give the Dashboard and Intelligence a signature hero.**
   - A one-line greeting, then a "Needs you" strip of large orange-accented cards above What's New. Each card gets an inline Allow/Reply action so the screen's main action is obvious.
   - On Intelligence, a pinned-agents row with live status rings in each agent's colour.
   - This is where the app's own personality, beyond the iOS list app, should come from.
