## Scores

| Category | Score | One-line reason |
| --- | --- | --- |
| Native | 7.6 | Glass tab bar, toolbars and grouped lists are right. The Dashboard composer, the contact action row, the chat header hairline and the iPad sidebar's solid selection are not iOS 27. |
| Typography | 7.4 | The scale is sound and the article serif is lovely. Some trailing values are body-sized, chat footnotes are tiny and tertiary, and section-header styles compete. |
| Hierarchy | 7.2 | The orange "Needs you" leads well. But tab titles have four treatments, the Dashboard's main action is split across three controls, and the medium and large widgets bury the point. |
| Spacing & density | 7.0 | List rhythm is good. iPad task columns drift, the medium and small widgets are a third empty, the iPad Dashboard wastes the canvas, and top insets vary. |
| Color & contrast | 7.4 | The semantic palette is mostly honoured. Orange is used for "Not Fetched", red for a priority flag, flags come in four greys, and "need you" is grey in the widget. |
| Iconography | 7.1 | SF Symbols throughout, but working and done each have two glyphs, tab glyphs mix fill and weight, the size glyph is unclear, and extensions use grey monograms. |
| Consistency & polish | 6.8 | The same user is "J" and "JZ", the widget sentence contradicts its own rows, 13c has no sidebar selection, and code blocks are clipped. |
| Overall | 7.2 | It looks carefully built and is mostly native, but it doesn't yet read as one designer's system across tabs, iPad and widgets. |

## Problems

1. **01, 02, 03, 04, 07, 08, 10: every top-level screen titles itself differently.**
   - Dashboard uses a custom greeting.
   - Intelligence uses a Large Title.
   - Workspace has an emoji, a bold title and a chevron, inline with the gear.
   - Feeds has a title menu indented to x≈45 instead of the 28pt margin.
   - Inbox has a leading inline title; Journal and Documents have centred inline titles.

   Fix: give tab roots one system, a `.large` navigation title with `toolbarTitleMenu` for the Workspace and Feeds pickers, on the standard leading margin. Give pushed lists one system: inline and centred, Inbox included. Keep the greeting, but render it as the Dashboard's large title so it sits on the same baseline as the others.

2. **01 / 13: the Dashboard's main action is three loose pieces.**
   - A white card with a border and drop shadow that is neither a glass field nor a list cell.
   - A detached "Atlas ⌃⌄" pill below it.
   - A "Quick Journal…" outline pill.

   Fix: make one glass composer bar, the same component as the chat's "Message Atlas" bar. Put the agent avatar as a menu button at its leading edge, with attach and send inside. Move Quick Journal into the toolbar as a `square.and.pencil` button, or into the composer's `+` menu. Remove the outline pills: there are no other bordered capsules anywhere in the app.

3. **01 vs 02/03/04: the Dashboard alone is a plain white list.** Every other tab is a grouped inset list on `systemGroupedBackground`, and the Dashboard's "What's New 4" header is a different style (title3, secondary, with a tertiary count) from "Agents" and "Tasks". Fix: either make the Dashboard `.insetGrouped` with standard headers, or make it deliberately different (a plain list with prominent headers) and apply that header style to Intelligence's sections too. Today it looks accidental.

4. **01, 13, 57, 58, 59: status glyphs and colours disagree between the app and the Live Activity.**
   - Working is a dashed grey circle in the app (13, "Working 1") but indigo `arrow.triangle.2.circlepath` in the Live Activity.
   - Done is a grey outline `checkmark.circle` in the app but a green filled check in the Live Activity. Green is meant to say "connected".

   Fix: define one glyph and colour per session state in ProtocolPresentation and use it everywhere: needs-you `hand.raised.fill` orange, working one spinner or arrows glyph in indigo, done `checkmark.circle` secondary, failed `xmark.circle.fill` red. Don't make done green.

5. **50 / 51 / 52: the Agents widget contradicts itself and drops the semantic colour.**
   - In 52 the header says "Ada, Milo, and Juno need you", but Ada's row says "Reading 12 of 40 sources" and only Milo and Juno say "Needs you".
   - "need you" is grey in all three sizes, while everywhere else it is orange.
   - The small widget has no label saying what "3" counts.
   - The medium's right half is empty.

   Fix: count only agents in the needs-you state. Render the number and "need you" in orange. In the medium, put the avatars left and two needs-you rows right (name plus what they need). In the large, shrink the avatar stack to about 44pt and list four or five agents so the bottom fifth isn't blank.

6. **13c: the iPad task table's columns float, and nothing in the sidebar is selected.**
   - The date shifts right when there's no assignee ("Nov 11", x≈1140 against 1110).
   - The assignee shifts right when there's no date (Relay).

   Fix: use fixed-width trailing columns (`Grid` or a `Table`-like layout with `.frame(width:)`), leaving empty cells empty. Highlight "Tasks" in the sidebar for any task view.

7. **13, 13b, 13d: the iPad sidebar's selection is a solid indigo capsule with white text.** It is heavier than any iOS 27 sidebar and turns the actor's orange "Needs you" glyph and label white-grey in 13d, so the most important signal disappears on the selected row. Fix: use the system sidebar selection (the tinted glass highlight with the label still in label colour), and keep the orange status glyph orange when selected.

8. **07, 13c, 26, 54–56: priority flags use four colours that collide with other meanings.** They come in orange, red, mid-grey and light grey. Red already means failed and overdue (the dates next to them are red), and two greys can't be told apart at a glance. Fix: show a flag only for high (orange) and urgent (orange with `exclamationmark`, or a filled flag plus a bold title). Show nothing for medium and low in rows, and keep the full scale in the task sheet.

9. **04: Feeds rows have three problems.**
   - Author and feed are separated by a double space ("Ines Kowalski  Swift Field Notes") and read as one long name.
   - "Not Fetched" is orange, but nothing needs the user.
   - The reading list sits in an inset card, which crowds two-line titles.

   Fix: use "Ines Kowalski · Swift Field Notes" in `.subheadline` secondary. Make "Not fetched" secondary, with an `exclamationmark.icloud` glyph or a tertiary label. Use a `.plain` list with full-bleed separators for articles.

10. **06, 34: code blocks are hard-clipped mid-character** ("-> Dura", "Double(atte", "isn't"), with no fade, scroll indicator or wrap. Fix: either wrap with a hanging indent, or keep horizontal scroll with a trailing fade gradient and a persistent indicator, as 13d does on the wider canvas.

11. **05, 06, 13b, 13d: the chat and session headers fight the content.**
    - A hard hairline sits under a floating glass header.
    - In 13b the scrolled text ("Raise the middle card less") collides with the "Atlas ›" pill.
    - In 05 the table text shows through the composer ("2026-11-15", "Book flights…").
    - There's a stray blue blob at the top right of 13b.

    Fix: remove the hairline and rely on `.scrollEdgeEffectStyle(.soft)` at the top and bottom so content fades under the bars. On iPhone, make the title the "Atlas ›" pill alone with a 28pt avatar inside it; the stacked 40pt avatar plus pill is too tall.

12. **26: the task sheet mixes five control idioms.**
    - Status, Assignee, Priority and Folder use menu pickers with `⌃⌄`.
    - Size is an accent "Set Size" button.
    - Tags is a "None ›" navigation row.
    - Notes is a separate "Edit Notes ›" row under the note text.
    - Start and Due use toggles.
    - The "JZ" avatar butts against "You" with no gap.
    - The confirm ✓ is a grey filled circle that reads as disabled.

    Fix: make Size a menu picker showing "None". Make the note text itself tappable and drop "Edit Notes". Put 6pt between avatar and name. Show the confirm button as `.glassProminent` accent when there are changes.

13. **07/13c vs 26: the same user has two monograms**, "J" in rows and "JZ" in the sheet. Fix: use the same initials everywhere (the two-letter form), from the same avatar component.

14. **53 / 54: the small and medium Tasks widgets leave a third of their height empty.** Each shows two tasks and "7 more", and the medium has the same two rows as the small. Fix: fit three rows in the small and four in the medium (use `.subheadline` titles and 20pt checkboxes, which are currently about 30pt). Choose one row layout for all sizes: 55 uses two-line rows with the date underneath, while 54 and 56 put the date trailing.

15. **56: the extra-large Tasks widget is the large widget stretched.** About 900pt separates titles from dates, so the eye can't follow a row. Fix: use two columns (Overdue | Today) or add the list and assignee as middle columns, keeping the row width under about 600pt.

16. **57 / 58: the Live Activity's progress bar and counts run in opposite orders.** The counts are needs-you, working, done; the bar is green, indigo, orange. In 58 the bar's left edge (x≈103) doesn't line up with the glyph column (x≈85) or the logo. "+3 more" in the header is ambiguous: three more what? Fix: order the bar segments like the counts (or drop the bar, since the counts already say it), align it to the row inset, and replace "+3 more" with "3 done" or remove it.

17. **12: the contact view looks dated and its separators are misaligned.**
    - Message, Call, FaceTime and Email are bare accent icons with labels. iOS 27 Contacts uses glass tiles.
    - The separator under "Add Email…" starts at the text (x≈130), while those above start at x≈62.

    Fix: put the four actions in equal-width `.glass` rounded tiles, and inset all separators to the text leading. Consider showing "Add…" rows only in edit mode.

18. **01–04 tab bar: the tab glyphs mix fill and weight.**
    - Dashboard (two stacked bars, filled) and Workspace (grid, filled) are heavy.
    - Feeds is a light outline.
    - Dashboard's glyph reads as "list" or "menu", not dashboard.

    Fix: use all-outline glyphs at one weight (the system fills the selected one). Use `house` or `rectangle.3.group` for Dashboard and `dot.radiowaves.up.forward` at matching weight for Feeds.

19. **10: Documents' trailing dates compete with the titles.** "40 minutes ago" is body-sized secondary. Every row also has the identical indigo document icon, which adds nothing. Fix: use `.subheadline` secondary for dates, and either drop the icon or show a type or emoji icon when documents carry one. "Design Review — Nov 8  Yesterday" also shows the crowding.

20. **08: Journal has no compose action, and the "Today / Morning" card is cryptic.** Fix: add a toolbar `+` (or `square.and.pencil`), as Documents has. For today, either show the entry's first line as the other rows do, or show an accent "Write today's entry" row if it's empty.

21. **13b: the agent's footnotes are too faint.** "Noted: …" and "Context rebuilt because provider cache expired" are about 11pt tertiary. The question card is grey-on-grey, with unchosen options greyed out. Fix: use `.footnote` secondary for the footnotes. Give the question card's options white or `secondarySystemFill` rows with label-colour text, and dim only after an answer is chosen.

22. **02 / 13: the action rows aren't styled alike.**
    - "Teams" is an accent-coloured row inside the Agents card.
    - On iPad, "New Agent" is label-colour with an accent `+` while "Teams" beside it is fully accent.
    - Scout's offline state is conveyed only by a faded name.

    Fix: on both, make action rows plain navigation rows with standard tinted icons. Add a small grey status dot or "Offline" subtitle for Scout.

23. **13: the iPad Dashboard is a narrow column in a 13-inch landscape canvas.** The "Working" row's title is greyed out, so it reads as disabled. Fix: use two columns at this width: What's New and Working on the left; Today's tasks or pinned agents on the right. Render Working titles in label colour with an indigo spinner glyph.

24. **44: extensions show grey monogram squares.** They look like placeholders. The version ("v4") is top-aligned while the chevron is centred. Fix: use the extension's icon when one exists, or a tinted monogram (accent at about 15% with an accent glyph). Put the version in the subtitle line ("v4 · Imports issues…") or align it to the chevron.

25. **17: "Context 48K tokens" is a lone orphan row in its own card.** Fix: fold it into a compact stats row under the description ("48K context · 12 runs this week"), or into the Usage group. Tint the header subtly with the agent's colour, which is the personality trait the brief asks for.

26. **06 / 13d: the bottom bar's leading spinner sits inside a circular glass button,** so it reads as a tappable control. Fix: put the activity indicator inside the field's leading edge, or as a status line above the bar. Keep a single trailing stop button, which is fine in red only if red is reserved for "stop/destructive" and "failed".

27. **34: the article's inline code chips push up line height,** so lines of a paragraph sit at uneven spacing. "What still bites" has more space below it than above. Fix: set inline code at about 0.9em with no vertical padding, and give H2s about 1.2em of space above and 0.4em below.

## What works

- The orange `hand.raised.fill` with "Needs you" carries the app's colour logic. It works in the Dashboard rows, the actor list, the permission card's border and the Live Activity.
- The permission card (06, 13d) gives a clear question with the command in monospace, one prominent Allow, a glass Deny and overflow. It has a single main action and is legible.
- The article reader (34) uses New York with a generous measure and real typographic hierarchy, and feels designed.
- Settings and the agent info sheet (14, 17) use native grouped lists with Settings-style tiles. They are restrained, correct, and coherent with each other.
- The Live Activity (57–59) is compact and glanceable, and the compact ring with a count is a nice touch.

## To reach 9+

1. **One title and header system** (raises Hierarchy and Consistency). Use large navigation titles with `toolbarTitleMenu` on every tab root, centred inline titles on every pushed screen, and one section-header style. Make the Dashboard either grouped like the rest or plain everywhere.
2. **One status vocabulary in ProtocolPresentation, used in the app, widgets and Live Activity** (raises Color, Iconography and Consistency). Settle the working and done glyphs, keep done secondary rather than green, give "Not fetched" no orange, and use orange and red flags only for high and urgent.
3. **Rebuild the Dashboard's action as one glass composer bar** with the agent picker inside it, plus a two-column iPad Dashboard (raises Native, Hierarchy and Spacing).
4. **Fix the widgets' density and truth** (raises Spacing and Consistency). Make the Agents count match its rows and render it orange. Fill the small and medium Tasks widgets to their height with one row layout across sizes. Give the extra-large two columns.
5. **Do an iPad polish pass** (raises Native and Polish). Use the system sidebar selection, which also keeps "Needs you" orange. Use fixed table columns in Tasks and always highlight the selection. Rely on scroll-edge effects instead of hairlines, unclip code blocks, and use one avatar component so "You" has the same initials everywhere.
