## Scores

| Category | Score | One-line reason |
| --- | --- | --- |
| Native | 7.8 | Glass toolbars, tab bar, inset-grouped lists and sheets are right, but the chat headers use a hard hairline where Liquid Glass wants a scroll-edge effect, and content collides under them. |
| Typography | 7.5 | Good body sizes and a nice serif reader, but there are two section-header styles, caption2 tertiary notes in chat, and four different title treatments. |
| Hierarchy | 7.3 | Dashboard and the permission card lead well, but the agents widgets give their space to hero avatars, and the task sheet buries "complete". |
| Spacing & density | 7.3 | The iPhone rhythm is mostly consistent. The iPad Dashboard is 40% empty, the medium widgets are half empty, and transcript cards come in two widths. |
| Color & contrast | 7.5 | Orange, red and indigo mostly keep their meaning, but orange also marks "Not Fetched" and unread agents, and gray flags and dimmed rows read as disabled. |
| Iconography | 7.2 | One SF family, but the Dashboard tab glyph doesn't read, folder icons repeat, extensions are identical gray monograms, and the Contacts glyph is filled among outlines. |
| Consistency & polish | 6.9 | The greeting copy differs between devices, initials are J vs JZ, empty-value styles mix, title alignment varies, and the widget sizes disagree on the count. |
| Overall | 7.3 | It reads as a careful, mostly native app. The edge collisions, title patterns and widget layouts still give away that no designer finished it. |

## Problems

1. **13b, 13d, 05, 06: transcript content collides with the header.** On iPad the transcript text and the diff sit right behind "Atlas ›" and the session title, and the two overlap. On iPhone a hard 1px hairline separates the header. 13b also has a stray blue blob at the top-right corner, and 06 a gray smear above the status bar. Fix: drop the divider and use the soft top scroll-edge effect (`.scrollEdgeEffectStyle(.soft, for: .top)`). Inset the first message below the header's full height, and remove the blob and smear artifacts.
2. **05: the composer floats over the table with no bottom edge effect.** "Record demo video 2026-11-12 You" reads straight through the glass, and the following paragraph shows below the composer. Fix: put the composer in a bottom safe-area bar with the soft scroll-edge effect so text fades out under it, and add bottom content inset so the last line clears it.
3. **50 vs 51/52: the widget sizes disagree.** Small says "3 need you" and medium/large say "2 … need you". The small is counting unread agents but labels them in orange "need you", which breaks orange = needs you. Fix: the small shows the same "needs you" metric as the others. If it must show unread, say "3 unread" in label/secondary color and save orange for permission waits.
4. **51, 52: the agents widgets spend their space on hero avatars.**
   - Medium: about 290pt of avatars, then one line of text, with the right half empty.
   - Large: avatars a third of the height, duplicated by the list below, then about 20% empty at the bottom.

   Fix: medium = a "2 need you" headline plus 3 rows (28pt avatar, name, status). Large = the same header with a small 24pt overlapping stack, then up to 6 rows, the needs-you rows first.
5. **02, 03/04, 07, 08/10: four title patterns.**
   - 02: large title below the toolbar.
   - 03/04: a title-sized menu ("Studio ⌄", "All Feeds ⌄") inside the toolbar row.
   - 07: "Inbox" inline and leading-aligned.
   - 08/10: inline and centered.

   Fix: every tab root gets a large title (the workspace and feed pickers become the large title's title menu), and every pushed screen gets a centered inline title. Inbox matches Journal and Documents.
6. **01 vs 13: the greeting differs.** iPhone says "Afternoon, Jackson" and iPad says "Good afternoon, Jackson". Use one string on both (the iPad's reads better).
7. **26 Task sheet: mixed empty values and a buried main action.**
   - Size shows "Set Size" in accent while Tags shows "None" in secondary with a chevron. Fix: "None" in secondary for every unset value.
   - Completing the task is hidden inside a "Status: Incomplete" picker. Fix: put the list's completion circle beside the title in the title card.
   - Notes is static text plus an "Edit Notes ›" row. Fix: make the notes text the tappable editor and drop the extra row.
8. **07, 13c vs 26: the user's initials differ.** Rows show "J" and the sheet shows "JZ". Use one monogram rule everywhere (two initials).
9. **07, 13c, 55, 56: low-priority flags read as disabled.** Medium is a gray flag and low an almost invisible light-gray flag, and both sit next to orange and red. Fix: show no flag for low, an outline flag in secondary for medium, and keep filled orange and red for high and urgent.
10. **13 iPad Dashboard: the bottom 40% of the canvas is empty, and the Working row looks dimmed.** "Polish the iPad sidebar spacing" is in tertiary and reads disabled. Fix: Working titles in label color. Use the space below Due for pinned agents or today's journal, or let Due and What's New grow to the bottom with more rows before "See all".
11. **01/13 vs 02: two section-header styles.** Dashboard uses large title3 gray headers with a lighter count ("Due 4", "What's New 4"). Intelligence and Workspace use small grouped headers ("Agents", "Tasks") with no count. Fix: one header style app-wide: headline in label color with the count in secondary, or the grouped style everywhere with counts.
12. **04 Feeds: the metadata row breaks several rules.**
   - "Not Fetched" is orange (a non-actionable state) and Title Case.
   - Author and feed are separated by a double space.
   - "yesterday" is lowercase where Documents says "Yesterday".

   Fix: "Not fetched" in secondary with a small exclamationmark glyph, " · " separators, and the same relative-date formatter as Documents.
13. **13b: the answered question card looks disabled.** Options A and C are tertiary text on a gray card on gray, and only a small check marks B. Fix: before answering, options in label color on `secondarySystemFill` rows. Once answered, the chosen option gets an accent-tinted fill and check, and the others secondary (not tertiary).
14. **13b, 05: run notes are too small and too faint.** "Noted: …" and "Context rebuilt because provider cache expired" are about caption2 in tertiary. Fix: .footnote in secondary with the glyph at the same weight.
15. **05: run steps and attribution have two styles.** The cue run is a filled gray capsule ("Cue … fired · 2 steps ›") while the tool step "Checking this week's tasks ›" is plain tertiary text. The briefing reply has no "• Atlas" sender label but the later reply does. Fix: one step style (plain secondary row with glyph and chevron), and the sender label on every agent turn after a user turn or step.
16. **13d, 06: transcript cards come in two widths and code is clipped with no affordance.**
   - On iPad, the diff and permission cards are about 520pt wide while the code block and text span the full 740pt column. Fix: every card full column width.
   - On iPhone, code is cut off at the right edge. Fix: horizontal scroll with a trailing fade, or soft-wrap with a hanging indent.
17. **06, 13d: the spinner in a glass circle left of "Follow up…" looks like a button.** Fix: put the working state in the header subtitle ("apple · Working 2m") or the field placeholder ("Working… follow up"), and keep only the stop button as a control.
18. **13 / 13b sidebar: the selection pill is too heavy.** A full indigo pill with white text is the loudest thing on screen and competes with each screen's main action. Fix: iPadOS 26's neutral selection (gray or glass fill, label text, accent glyph).
19. **13 / 13b sidebar: two more sidebar fixes.**
   - "Teams" is accent text while "New Agent" is label text with a gray "+". Fix: style both as secondary actions the same way (accent glyph, label text).
   - Feeds, a top-level tab on iPhone, isn't among the sidebar's top destinations. Fix: add it after Tasks.
20. **44 Extensions: every extension is the same gray letter tile** (G, L, D, I, C), so nothing identifies them. Fix: use the extension's own icon when it provides one. Otherwise give each a hashed tint from the agent palette, or use a `puzzlepiece.extension` glyph tile.
21. **03 Workspace: repeated and mismatched icons.**
   - Every task list uses the same folder glyph.
   - Inbox and All both use trays.
   - The Contacts glyph is filled while its neighbours are outlines.

   Fix: outline `person.crop.circle`, `square.stack` for All, and let lists carry their own color or emoji as Reminders does.
22. **12 Contact: edit rows shown in view mode, and uneven separators.**
   - "Add Email…" and "Add Phone…" are always visible, which clutters a read view. Fix: show them only in Edit.
   - The separator under Phone runs to the text margin while the one between the add rows is inset under the label. Fix: one inset rule per group.
   - The quick actions are bare tinted glyphs. Fix: iOS 26 Contacts' equal-width glass tiles.
23. **02 Intelligence: the pinned row and Scout's status.**
   - Two 120pt avatars sit left-aligned with the right half empty. Fix: a 4-up grid at about 64pt so pins scale.
   - Scout's name is tertiary with no explanation. Fix: an explicit status ("Offline" subtitle or a status dot) instead of only dimming.
24. **55 vs 54/56: the large Tasks widget changes layout.** It puts dates under titles, so row heights jump between one and two lines, while medium and extra large put dates trailing. Fix: trailing dates in the large too, with uniform rows. The medium (54) shows only 2 rows over a lot of empty space; fit 3–4.
25. **01, 13c: one overdue task is labelled two ways.** "Send press kit to Maya" is "Overdue" on the Dashboard and red "Nov 7" in All tasks. Fix: pick one rule (red date everywhere, or "Overdue" plus the date in the list).
26. **Tab bar (01–10): the Dashboard glyph doesn't say "dashboard".** Two heavy stacked bars read as a list or menu and are heavier than the sparkle and RSS glyphs beside them. Fix: an SF Symbol that means home or summary (`house`, `rectangle.3.group`) at the same weight as the other tabs.
27. **10 Documents: an icon that says nothing, and long dates.** The identical doc glyph on every row adds nothing, and "40 minutes ago" is long. Fix: drop the glyph (or show a doc's emoji), and use compact relative dates ("40 min", "5 hr").
28. **34 Article reader: refresh and inline code.**
   - Refresh is a top-level toolbar action. Fix: move it into the ⋯ menu and leave Share first.
   - Inline code pills are heavy and sit above the serif baseline. Fix: render inline code at about 0.9em with a lighter fill and baseline offset.
29. **17 Agent info: the context row and the missing primary action.**
   - "Context 48K tokens" sits alone in a group with no frame of reference. Fix: a small gauge or "48K of 200K".
   - The sheet has no primary action. Fix: a "Message" button under the description, as Contacts does.
30. **57: "+3 more" competes with the counts.** It sits in the header beside the status counts. Fix: put it as a footer line under the three rows, in secondary.

## What works

- The "needs you" language holds together: an orange hand glyph, orange text and an orange outlined permission card, used the same way on the Dashboard, Intelligence, actor session, sidebar and Live Activity.
- The permission card (06/13d) is a model card: one clear question, the command in monospace, the reason in secondary, and an obvious primary Allow.
- The article reader's serif type gives the app personality without breaking from native.
- The Live Activity and Dynamic Island are tight: the count chips, the segmented status bar and the compact ring with the needs-you count.
- Settings and agent info use native multicolor tile rows with a destructive row set apart, so they read instantly as iOS.

## To reach 9+

1. **Fix the scroll edges everywhere.** Use soft top and bottom scroll-edge effects in chat and sessions, no hairlines, and proper content insets so nothing collides with the header or composer (problems 1, 2).
2. **Pick one title system and one section-header system and apply them to every screen**, with the greeting string the same on both devices (problems 5, 6, 11).
3. **Rebuild the agents widgets around rows, not hero avatars.** Make all sizes show the same metric, and use orange only for "needs you" (problems 3, 4, 24).
4. **Make state color strict.** Nothing that looks disabled unless it is, no orange outside "needs you", one overdue treatment, and priority flags only where they mean something (problems 9, 10, 12, 13, 14, 25).
5. **Give the iPad layouts a designer's grid.** Fill the Dashboard canvas, give transcript cards one width, use a neutral sidebar selection with Feeds in it, and consider column headers and tighter rows for All tasks (problems 10, 16, 18, 19).
