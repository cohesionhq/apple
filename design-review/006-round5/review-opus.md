## Scores

| Category | Score | One-line reason |
|---|---|---|
| Native | 7.6 | Glass toolbars, floating tab bar, inset grouped lists and the sidebar are all correct, but the Dashboard has no title bar, the scroll edges under custom headers are hard cuts, and the widgets use a flat grey background. |
| Typography | 7.3 | The base scale is sound and the serif reader is lovely, but section headers come in three styles, the Live Activity type is tiny, and the inline mono runs optically larger than the body text. |
| Hierarchy | 6.9 | "Needs you" reads well in lists, but the widgets bury it, "Working" looks disabled, the permission card's Deny looks inert, and the large Agents widget says the same thing twice. |
| Spacing & density | 7.0 | Lists have good rhythm. The widgets have dead areas of 30–60%, iPad detail panes leave huge empty margins, and the row-height rhythm breaks in the large Tasks widget and the Intelligence list. |
| Color & contrast | 7.2 | Indigo is used with restraint, but orange and red mean both "priority" and "needs you/failed", the tab badge is red for a "needs you", and answered choice cards are grey on grey. |
| Iconography | 7.0 | SF Symbols throughout, but the Dashboard and All Feeds glyphs are unclear, a sync icon stands for "running", the extension tiles are identical grey monograms, and the Atlas avatar reads as Safari. |
| Consistency & polish | 6.8 | Title placement differs on almost every screen, task rows differ between iPhone and iPad, widget rows change layout by size, and the sidebar's action rows are styled two ways. |
| Overall | 7.1 | A competent, clearly cared-for native app, but not yet one where every edge looks decided by one designer. The widgets especially still feel like first drafts. |

## Problems

1. **50/51/52 – Agents widgets: the facepile is the whole design, and it fights itself.** The discs overlap with no separating ring, so cyan bleeds straight into purple and orange and the overlap reads as a rendering error. Nothing is orange even though the whole widget is about "needs you". The medium leaves the top-right half empty. The large repeats the same three avatars twice: a huge facepile, then a list. It also contradicts itself: the headline says "Ada, Milo, and Juno need you" while Ada's row says "Reading 12 of 40 sources". **Fix:**
   - Give each disc a 2–3pt ring in the widget's background colour, and make the number orange with a `hand.raised.fill` glyph.
   - Medium: keep a small facepile (40pt) on the left, and on the right put up to three rows of name plus what they need, in `.subheadline` secondary.
   - Large: drop the giant facepile and use a header row ("3 need you", orange) over a 4–5 row list. Each row: avatar, name in `.headline`, status in `.subheadline` secondary, an orange trailing "Needs you" pill only on the agents that need you.
   - Only count an agent in the headline if its row says it needs you.

2. **53–56 – Tasks widgets change layout by size and waste space.**
   - Small, medium and extra large put the date trailing; large stacks it under the title, so rows are uneven heights (61pt with a date, about 44pt without).
   - Small shows two rows and truncates the first ("Review the ro…") while the bottom third is empty.
   - Medium shows two rows and "3 more" with room for a third.
   - Large shows all five and leaves 40% blank.
   - Extra large is a single 1500px-wide column, with dates about 1,000pt away from their titles.

   **Fix:**
   - Use one row template everywhere: 20pt checkbox, `.subheadline` title, `.caption` date under the title in red or secondary, flag trailing.
   - Small: three rows. Medium: three or four rows. Large: up to eight rows, or a second view section.
   - Extra large: two columns (Overdue | Today), or two task views side by side.
   - Use `.containerBackground(.fill.tertiary…)` only where you mean it. In light mode, the system white widget background looks more native than the flat #EEE grey.

3. **07, 13c, 26, 54–56 – Colour means two things.** Priority flags are orange and red, but orange is "needs you" and red is "failed" everywhere else (01, 02, 13). The Intelligence tab badge is red for a "needs you" count. **Fix:**
   - Take orange and red out of priority. Use Reminders-style `!`/`!!`/`!!!` in secondary, or flags in a single indigo with fill levels (outline = low, fill = high, `flag.badge.ellipsis` = urgent).
   - Reserve orange for needs you and red for failed or overdue.
   - The red system badge is acceptable on iOS, but the Live Activity and widgets should then lead with orange.

4. **01 – The Dashboard is the one screen that doesn't belong to the set.**
   - Its background is plain white while every other tab is grouped grey.
   - It has no navigation title, so the gear floats alone.
   - The greeting is a two-line 34pt bold full name.
   - "What's New 4" is a grey `.title3` header unlike any other section header.
   - The fourth row sits under the tab bar with nothing to show it scrolls.

   **Fix:**
   - Use the grouped background with the composer as an inset card.
   - Greet by first name only ("Good morning, Jackson"), one line, `.largeTitle` bold, with the date in `.subheadline` secondary.
   - Use the same section header style as Intelligence (`.headline` secondary, count in tertiary).
   - Put What's New in an inset grouped card like every other list.

5. **06, 13b, 13d – Custom headers don't clear the content.** In 06 the "Write Tests/…" tool row is sliced in half under a hairline. In 13b the earlier message text shows through behind the Atlas avatar. In 13d diff lines run straight through the session title. **Fix:** remove the hairline and apply the soft scroll-edge effect (`.scrollEdgeEffectStyle(.soft, for: .top)`) under the glass header, so text fades out before it reaches the title. The header on these screens should behave like the system nav bar does in 07 and 10.

6. **06, 13d – The permission card is the screen's main action but looks like a disabled form.**
   - The card is grey (systemGray6) inside a grey-tinted surround.
   - Deny is a mid-grey capsule with black text that reads as disabled.
   - The note field is a third grey.
   - On iPad the card is about 520pt wide while the transcript column and code blocks are about 740pt.

   **Fix:**
   - Make the card `secondarySystemGroupedBackground` (white) with a 1pt orange stroke and a faint orange tint only in the header row.
   - Allow stays as `.borderedProminent` indigo. Deny becomes `.bordered` (glass) with label-colour text. The ellipsis stays bordered.
   - Match the column width.

7. **13 – The "Working" section reads as disabled.** "Polish the iPad sidebar spacing" is in tertiary grey with a dotted empty circle, the same treatment as a cancelled item. **Fix:** use primary text, a small indigo `ProgressView` or rotating indigo ring instead of the dotted circle, and "Working · now" in indigo `.subheadline`. Running is the one live state on the screen, so it should look alive.

8. **13, 13b, 13c, 13d – Sidebar polish.**
   - The selected actor row turns the orange "Needs you" white-grey, so the one urgent signal disappears exactly when you open it.
   - Actor rows have no leading glyph, so their text starts at x=35 while agent names start at x=72.
   - "New Agent" is a label-colour row but "Teams" is an indigo link row, two styles for the same kind of action.
   - Pin glyphs on Atlas and Scout add noise, since pinned agents could just be their own section.

   **Fix:**
   - Keep the hand icon orange on a white chip in the selected state.
   - Give actor rows a 28pt status glyph (hand, spinner, check) aligned to the avatar column.
   - Style New Agent and Teams the same (label colour with an indigo symbol), or move them into the Agents header's ⋯ menu.
   - Replace the pins with a "Pinned" subsection.

9. **03, 07, 08, 10, 14, 44 – Title placement varies on every screen.**
   - Intelligence and Feeds use large titles.
   - Workspace uses a centred "Studio" principal menu with no large title.
   - Inbox (07) puts an inline title next to the back button, leading.
   - Journal and Documents use centred inline titles.
   - Extensions uses a large title, but Settings, its parent, is inline.

   **Fix:** root tabs and the Settings root get a large title (Workspace: large "Studio" with a chevron menu on the title). Pushed screens get a centred inline title. Inbox should match Journal.

10. **05 – The chat composer covers the content it should clear.** The table's last two rows ("2026-11-12 You", "2026-11-15 You") show through the glass composer and collide with the "Message Atlas" placeholder, and the reply's last line ("Send press kit…") sits below the composer. The table also mixes "Today/Tomorrow" with ISO dates. **Fix:**
    - Add bottom content margin equal to the composer height plus 12pt (`.safeAreaInset(edge: .bottom)` with the composer as its content), plus a soft bottom scroll edge.
    - Format dates in tables the way the rest of the app does ("Thu, Nov 12"), or tell the agent to.

11. **06, 34 – Code blocks are hard-clipped.** "-> Dura" and "model.query isn't" are cut at the card edge with no fade or scroll cue. **Fix:** put a horizontal `ScrollView` inside the block with a 16pt trailing gradient fade, or wrap with a hanging indent in the transcript (iPad already has the width).

12. **02 – The Intelligence layout is unbalanced.**
    - Two 120pt pinned avatars hug the left with the right half empty.
    - Scout's label is tertiary grey with no explanation.
    - Juniper's row is shorter than the others because it has no team.
    - "Teams" is an indigo link inside the Agents card.
    - The Actors section truncates the title and hides the most important item below the fold.

    **Fix:**
    - Show pinned agents as a horizontally scrolling row of 72pt avatars, with a status dot (green online, orange needs you) instead of greying the name.
    - Give team-less agents "No team" in tertiary, or a fixed row height.
    - Move Teams to the toolbar ⋯ menu.
    - Put Actors that need you first, above Agents, as orange-accented rows.

13. **07, 13c – Task rows have too many token styles.**
    - Calendar glyph plus date.
    - Monogram avatar plus name.
    - Ruler glyph in a grey capsule ("Tiny").
    - Plain grey capsule ("waiting").
    - Bare grey text ("Launch").

    That's five visual grammars in one `.footnote` line. iPhone puts tasks in an inset card while iPad uses a plain list.

    **Fix:**
    - Keep the date and assignee as plain secondary text.
    - Drop the size capsule's glyph.
    - Render tags as `#waiting` in tertiary rather than capsules.
    - Show the list name only in cross-list views.
    - On iPad, use aligned trailing columns (Due · Assignee · Size) like a table; the 13c detail pane has 200pt of unused width on the right.
    - Use the same list style on both devices.

14. **26 – Task sheet rows are inconsistent.**
    - The title sits in its own card with no label.
    - Notes is shown read-only with a separate "Edit Notes ›" row.
    - "Set Size" is an indigo button while every other value is a grey menu with an up-down chevron.
    - Priority "Medium" shows a grey flag that elsewhere means "low".

    **Fix:**
    - Make the title and notes one card with inline-editable `TextField(axis: .vertical)`, title in `.headline`.
    - Show Size as "None ⌃⌄" in secondary like its siblings.
    - Use the priority treatment from item 3.

15. **12 – The contact screen mixes edit mode into view mode.**
    - The action buttons are bare indigo glyphs with no platters; iOS Contacts uses tinted rounded-rect platters.
    - "Add Email…" and "Add Phone…" sit in the read view.
    - Email appears as both an action and a row.
    - The name is `.title2`, small under a 160pt monogram.

    **Fix:**
    - Put the four actions in equal-width `.bordered` glass platters (glyph over `.caption` label).
    - Move the "Add" rows behind Edit.
    - Set the name in `.title` bold.

16. **44 – Extension icons are five identical grey letter tiles**, so nothing can be told apart at a glance. The "v4" version labels are `.caption2` tertiary and barely legible. **Fix:** give each extension a tile hue (hash the id into the agent palette) or its real icon, and show the version in `.footnote` secondary, or move it to the detail screen.

17. **17 – Agent info doesn't feel like the agent's.**
    - "Context 48K" floats in its own card, with "tokens" stacked underneath in tiny tertiary.
    - The header is generic grey.
    - The Memories icon duplicates Settings › Memories exactly.

    **Fix:**
    - Tint the header background with a 12% wash of the agent's colour.
    - Make Context a row with a small `Gauge` (48K / limit) in the first list group.
    - Use "48K tokens" on one line in secondary.

18. **57–59 – The Live Activity's marks are ambiguous.**
    - Running uses `arrow.triangle.2.circlepath`, which means sync or retry, not working.
    - The compact ring shows "3" (the done count?) while the one item that needs you has no presence in the compact view.
    - Lock-screen type is about `.caption`.
    - The three-colour bar has no legend and duplicates the counts.
    - Green "done" overlaps with green "connected".

    **Fix:**
    - Show running as a spinning indigo `progress.indicator`-style ring or `ellipsis`.
    - Compact trailing: orange hand plus "1" whenever anything needs you, otherwise the running count.
    - Lock-screen rows in `.subheadline`.
    - Drop either the bar or the header counts.

19. **01 and tab bar – Tab iconography is inconsistent.** Dashboard's glyph (two stacked filled bars) doesn't say "home" or "dashboard". Feeds is an outline glyph among filled ones. **Fix:** use `square.grid.2x2` for Workspace (already filled) and `house.fill` or `rectangle.3.group.fill` for Dashboard, and use the same fill treatment for every tab.

20. **01, 03, 04, 07 – A gear floats in the top-left of every tab.** It takes the back-button slot, and its size varies slightly between tabs (01 against 03 and 04). **Fix:** follow the App Store and Music pattern: the user's avatar as a trailing toolbar button that opens Settings, at one fixed size via `ToolbarItem(placement: .topBarTrailing)`.

21. **13b, 13c – In the sidebar, "Scout" renders as a dark "S" followed by a lighter "cout".** This looks like a shimmer caught mid-frame, and in a static frame it reads as a glyph bug. The grey name also reads as offline with no explanation. **Fix:** show working with an indigo activity dot in the trailing slot rather than shimmering the name, and keep the name label-coloured.

22. **04 – The "All Feeds" glyph** (a jar or stack shape) is unclear. Feeds have no favicons, and "Ops Weekly" shows no count where the others do. **Fix:** use `tray.full` or `square.stack.3d.up` for All, favicons at 20pt in a rounded rect for each feed (falling back to the RSS glyph), and leave the count blank deliberately rather than inconsistently, or show a muted "0".

23. **13b – Answered choice cards are grey on grey.** Options A and C are tertiary text on systemGray5, and the selected B differs only by a pale indigo check. **Fix:** when answered, show only the chosen option, with an indigo `checkmark.circle.fill` and primary text. Collapse the others or set them in strikethrough tertiary.

24. **10, 08 – Small copy and casing slips.**
    - "yesterday" is lowercase while its neighbours are capitalised ("40 minutes ago", "4 days ago").
    - Journal's "Today / Morning" card has a subtitle whose meaning is unclear.

    **Fix:** use `Text(date, format: .relative(presentation: .named))` consistently with sentence case. Make Today's subtitle the entry's first line, or "No entry yet" in tertiary.

25. **01 vs 13 – The greeting copy differs between iPhone ("Good morning,") and iPad ("Let's get going,")** on the same date, and both use the full name. **Fix:** use one greeting rule on both, first name only.

## What works

- Settings and agent info use iOS Settings-style coloured squircle icons in inset grouped lists. They are instantly familiar and well executed.
- The chat header (agent avatar over a glass "Atlas ›" pill) and the indigo user bubbles against unbubbled agent replies give the chat an identity without fighting iOS.
- The article reader's New York serif, generous measure and inline code chips feel like a considered reading mode.
- What's New rows use colour and glyph semantics cleanly: orange hand for needs you, red X for failed, grey check for done, with matching coloured metadata.
- The iPad sidebar's structure (workspace switcher, pages, agents by team, actors) is a strong, native information architecture.

## To reach 9+

1. **Redesign the widgets around a single row template and an orange "needs you" lead.** Use ringed facepiles, no repeated content, layouts that fill each size, and two columns at extra large. They are currently the weakest surface and the first thing people see.
2. **Lock the colour semantics.** Take orange and red out of priority, lead with orange wherever something needs you (badge, compact Live Activity, widgets), make Working look alive in indigo, and never let selection wash out a status colour.
3. **Unify the chrome.**
   - Large titles on tabs, centred inline titles on pushed screens.
   - A trailing avatar for Settings instead of a top-left gear.
   - The soft scroll-edge effect under every custom header (chat and actor session).
   - Bottom insets so composers never cover content.
4. **Bring the Dashboard and Intelligence into the system.** Use the grouped background, a one-line first-name greeting, inset-card What's New with the shared section header style, a horizontal pinned-agent row with status dots, and Actors that need you first.
5. **Rationalise the task row and the permission card.**
   - Task rows: one metadata grammar (plain secondary text plus `#tags`), a table-like column layout on iPad, and the same list style on both devices.
   - Permission card: a white card with an orange stroke, a glass Deny button, and full column width.
