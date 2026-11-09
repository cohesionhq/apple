## Scores

| Category | Score | One-line reason |
| --- | --- | --- |
| Native | 7.8 | Inset-grouped lists, the floating glass tab bar, glass toolbar groups and Settings-style tiles all look right. Scroll-edge handling under custom headers and composers is not finished. |
| Typography | 7.4 | The base scale is sound and the serif reader is a highlight. The two-line 34pt greeting, tertiary-gray captions and tiny metadata glyphs drag it down. |
| Hierarchy | 7.0 | Rows read well, but several screens have no clear lead (Dashboard, Feeds, the medium/large widgets), and "working" items look disabled. |
| Spacing & density | 7.1 | List rhythm is consistent. Widgets leave a third to half of their area empty, and there are large dead zones above heroes and below short lists. |
| Color & contrast | 7.3 | Indigo stays restrained, but orange is spread across "needs you", priority flags, agent discs and the Profile tile, and gray-on-gray options read as disabled. |
| Iconography | 7.0 | SF Symbols throughout, but four flag shades, a cue icon that changes meaning between screens, mixed filled and outline status marks, and placeholder monogram tiles. |
| Consistency & polish | 6.8 | Title alignment, greeting copy, value affordances in the task form and sidebar action colours all change from screen to screen. Text collides under headers on iPad. |
| Overall | 7.2 | Clearly designed and mostly native, but the unfinished edges and loose semantics would stop a professional from calling it fully designed. |

## Problems

1. **13b-ipad-agent-chat, 13d-ipad-actor-session, 05-iphone-agent-chat, 06-iphone-actor-session**: Scrolled content shows straight through the custom header and composer and collides with them.
   - In 13b, "Raise the middle card less" sits on the "Atlas >" pill.
   - In 13d, diff lines run behind "Add backoff to the change socket's reconnect".
   - In 05, the table rows "Record demo video / 2026-11-12" print under "Message Atlas".
   - In 06, the "Write Tests/…" tool row is cut in half by the header hairline.
   - There is a stray blue glass blob at the top-right of 13b.
   - Fix: host the header and the composer in `safeAreaBar` (top and bottom) so the system scroll-edge effect blurs and fades the content under them. Use `.scrollEdgeEffectStyle(.hard, for: .top)` on iPad, where the header has no glass container, and add a bottom content margin equal to the composer's height. Find and remove the stray glass view in the top-right corner.

2. **52-widget-agents-large**: The large widget contradicts itself. The summary says "Ada, Milo, and Juno need you", but Ada's row says "Reading 12 of 40 sources".
   - Fix: build the sentence only from agents whose state is needs-you ("Milo and Juno need you"), and sort those rows first.
   - Also, the three ~145pt avatars take the top third of the widget as decoration. Cut them to 44pt overlapping discs inline with the count, and give the space to two more agent rows.

3. **51-widget-agents-medium, 53-widget-tasks-small, 54-widget-tasks-medium, 56-widget-tasks-extralarge**: The widgets waste space.
   - The medium Agents widget leaves the right ~55% empty.
   - The small and medium Tasks widgets show 2 rows and leave the bottom third blank.
   - The extra-large widget is one 1,400px-wide column with dates stranded far from their titles.
   - Fix: Agents medium should put the avatars and count in a left column and 3 status rows on the right. Tasks small and medium should use `.subheadline` rows with 18pt checkboxes to fit 3 to 4 rows. Tasks XL should split into two columns ("Overdue" / "Today") or add the assignee and list columns.

4. **01-iphone-dashboard, 13-ipad-split-view**: The greeting differs by device: "Let's get going, Jackson Zamorano" on iPhone and "Good morning, Jackson Zamorano" on iPad.
   - On iPhone it wraps to two lines at a size bigger than `.largeTitle`, so the full name pushes the composer down.
   - Fix: use one time-of-day greeting on both devices, with the first name only ("Good morning, Jackson"). Use `.largeTitle.bold()` on a single line, with the date in `.subheadline` secondary directly under it.

5. **07-iphone-tasks, 13c-ipad-tasks, 26-task-detail, 55/56 widgets**: Priority is encoded as four flag treatments (light gray, dark gray, orange, red) plus no flag. The two grays are indistinguishable at a glance, and the orange flag competes with orange "needs you".
   - Fix: show no mark for low or medium priority. Use Reminders-style `exclamationmark` glyphs in red for urgent and in the label colour for high, or keep flags for high and urgent only, both red, with urgent filled and high outlined.
   - Keep orange exclusively for "needs you".

6. **05-iphone-agent-chat vs 17-agent-info**: The same icon means different things on different screens.
   - In chat, a cue firing is shown with an indigo `bolt`.
   - In Agent Info, Cues is an alarm clock and Runs is the bolt.
   - Fix: give Cues one symbol (`alarm` or `bolt.badge.clock`) everywhere, including the chat's cue row, and give Runs `play.circle` or `list.bullet.rectangle`.
   - Put the mapping in one place so chat and info can't drift.

7. **26-task-detail**: The value column has four affordances:
   - gray text with `chevron.up.down` (Status, Assignee, Priority, Folder)
   - accent-coloured "Set Size" with no chevron
   - gray "None" with a push chevron (Tags)
   - an "Edit Notes >" row under the notes text

   The ✓ confirm button is also a gray glass disc that looks disabled. Fix:
   - Show Size as "None" with `chevron.up.down` like its siblings.
   - Make Notes an inline multi-line `TextField(axis: .vertical)` and drop the "Edit Notes" row.
   - Make ✓ `.glassProminent` in indigo when there are changes.

8. **07-iphone-tasks vs 08-iphone-journal, 10-iphone-documents; 03-iphone-workspace vs 02, 04**: Title treatment changes from screen to screen.
   - Inbox has a left-aligned inline title beside the back button, while Journal and Documents centre theirs.
   - Workspace has no large title (just the "Studio ⌄" principal), while Intelligence and Feeds have large titles.
   - Fix: use a large title on every root tab (Workspace's large title becomes the "Studio ⌄" switcher, as in Files and Mail account pickers) and a centred inline title on pushed screens, including Inbox.

9. **01-iphone-dashboard, 13-ipad-split-view**: The composer accessories don't match each other.
   - The "Atlas ⌃⌄" picker and "Quick Journal…" are two capsule styles with different heights and weights.
   - "Quick Journal…" ends in an ellipsis, though it isn't a menu that asks for more input.
   - The photo and send glyphs in the composer are tertiary gray and nearly invisible, and the composer's drop shadow is heavier than anything else in the app.
   - Fix: make both accessories `.buttonStyle(.glass)` with `.controlSize(.small)`, and label the second "Journal". Make the photo glyph secondary, and make send an indigo filled circle that is enabled once text exists. Replace the shadow with a hairline stroke or glass.

10. **13-ipad-split-view (Working section)**: "Polish the iPad sidebar spacing" is drawn in tertiary gray with a dashed circle, so the one live thing on the dashboard reads as disabled.
    - Fix: use a primary-colour title and an indigo `ProgressView` or a `progress.indicator` symbol with `.symbolEffect(.variableColor)`.
    - Set "Working · now" in secondary.

11. **01, 13 (What's New)**: The status marks mix fills: filled orange hand, filled red ✕, outline gray ✓, dashed circle, and an agent avatar.
    - Fix: use one family, `*.circle.fill`, tinted by meaning:
      - `hand.raised.circle.fill` orange
      - `xmark.circle.fill` red
      - `checkmark.circle.fill` secondary gray
    - Keep avatars only for message rows, at the same 28pt diameter.

12. **44-extensions**: Every extension is an identical gray monogram tile ("G", "L", "D", "I", "C"), which reads like placeholder art. The version ("v4") floats at the top-right, away from the chevron, and is visually tied to the description.
    - Fix: use the extension's icon if the protocol provides one. If not, tint each monogram tile from a stable hash in the agent palette, so the tiles look intentional rather than empty.
    - Move the version into the subtitle ("v4 · Imports issues…") or show it as a trailing secondary value aligned to the chevron's centre.

13. **02-iphone-intelligence**: The layout has several loose ends.
    - Only two pinned avatars, left-aligned, float in a wide band.
    - Scout's label is tertiary with no explanation (offline?).
    - The Actors rows have no leading mark, so their text starts at the section inset while the agent names above start after a 30pt avatar.
    - "Teams" is a link row inside the Agents list.
    - Juniper's row is shorter because it has no team.
    - Fix:
      - Lay the pins out as a 4-column grid (empty slots stay empty), and explain Scout's dimming with a status dot or an "Offline" caption.
      - Give actor rows a 28pt status glyph or terminal icon so all rows share one text inset.
      - Move Teams into the `…` menu or its own section.
      - Give team-less agents a secondary caption (e.g. "No team").

14. **13-ipad-split-view, 13d-ipad-actor-session (sidebar)**:
    - "New Agent" is in the label colour while "Teams" is in indigo, though both are actions.
    - The selected actor row turns "Needs you" and its hand into washed-out white or gray, so the most urgent state disappears exactly when it's selected.
    - Fix: give both action rows the same treatment (secondary label with an indigo glyph). For a selected row, keep the orange hand on a white disc, or put a small orange dot on the trailing edge.

15. **13b-ipad-agent-chat (question card)**: The unselected options "Wednesday 10:00–12:00" and "Friday 9:30–11:30" are tertiary gray on a gray fill, so they look disabled rather than choosable. The letters A, B, C are lighter still.
    - Fix: use primary text on `secondarySystemFill` and set the letter in indigo `.subheadline.weight(.semibold)`.
    - Mark the chosen row with an indigo tint fill and a check. Dim the others only after the answer is sent.

16. **06-iphone-actor-session, 13d-ipad-actor-session (permission card)**:
    - "in /Users/jackson/Developer/apple" is monospaced tertiary at a small size, with low contrast.
    - On iPad the card is about half the column width while the code block above spans the full column, so the column edges are ragged.
    - On iPhone, the footer's activity spinner sits in a glass circle like a button.
    - Fix: set the path in `.footnote` secondary, and make the card full column width like the code blocks. Show the spinner without glass (or inline in the field's leading edge) so only real buttons have glass.

17. **06-iphone-actor-session, 34-article**: Code blocks are clipped at the trailing edge ("-> Dura", "isn't") with no sign that they scroll.
    - Fix: add a trailing fade mask (or `.scrollIndicators(.visible)` with a horizontal indicator).
    - Inside the 34 reader, consider wrapping with a hanging indent, since horizontal scroll inside vertical reading is hostile.

18. **10-iphone-documents**:
    - Every row repeats the same indigo doc glyph, which adds noise without information.
    - "40 minutes ago" and "5 hours ago" are long and crowd titles ("Design Review — Nov 8 / Yesterday" nearly touch).
    - Fix: drop the glyph, or use it only to tell types apart. Use abbreviated relative dates ("40m", "5h", "Yesterday"), or put them in a secondary subtitle under the title.

19. **12-iphone-contact**:
    - The Message, Call, FaceTime and Email actions are bare indigo glyphs, where iOS Contacts puts them in uniform rounded tiles.
    - "Email" appears as both an action and a row.
    - The separator under "Add Email…" is inset differently from the ones above it.
    - About 90pt of empty space sits above the avatar.
    - Fix: put the actions in `.glass` rounded-rect tiles of equal width, align all separators to the text inset, and pull the avatar up under the toolbar.

20. **04-iphone-feeds**:
    - The "All Feeds" glyph (a stacked cylinder) reads as storage, not feeds.
    - Ops Weekly shows no count.
    - Two-thirds of the screen is empty.
    - Fix: use `tray.full` or `dot.radiowaves.up.forward` for All Feeds, and show "0" or nothing consistently.
    - Put a "Latest" section of the 5 newest unread articles (title, source, age) under the feed list, so the tab has something to read.

21. **57-live-activity-lockscreen, 58-live-activity-expanded**:
    - The summary is ordered needs-you, running, done, but the segmented bar runs done (green), running (indigo), needs-you (orange): the reverse.
    - "0:39" and "5:12" don't say they're elapsed time.
    - The bar's leading edge in 58 is inset further than the row icons.
    - Fix: order the bar to match the summary, or drop it, since the counts already say it. Use `Text(timerInterval:)` with a leading `clock` glyph or an "elapsed" accessibility label, and align the bar to the icon column.

22. **05-iphone-agent-chat, 13b**: The stacked header (a 56pt avatar over an "Atlas >" glass pill, then a hairline) costs about 140pt of the iPhone screen.
    - Fix: use a 32pt avatar beside the name in a single tappable principal item. Keep the iMessage-style stacked form only at rest, collapsing it on scroll.

23. **50-widget-agents-small vs 52**: The meaning word changes colour between widget sizes. The small and medium widgets set "need you" in gray, while the large widget's rows and the Live Activity set "Needs you" in orange.
    - Fix: make "need you" orange in the small and medium widgets, and leave the count in the label colour.

24. **14-settings, 02, 50–52**: Orange is also used for non-semantic things: the Profile tile, Ledger's and Juno's discs, and the high-priority flag. That waters down "orange = needs you".
    - Fix: give the Profile tile gray or blue as iOS does.
    - Exclude pure orange from the agent palette, or render needs-you with its hand glyph everywhere so the colour isn't carrying the meaning alone.

25. **01-iphone-dashboard (tab bar)**: The Dashboard tab glyph (two stacked bars) is ambiguous and doesn't read as "home".
    - Fix: use `house` or `rectangle.grid.1x2`, at the same weight as the `square.grid.2x2` Workspace glyph.

26. **34-article**: The list bullets are tiny light-gray dots that sit low against the serif cap height.
    - Fix: use a body-sized label-colour bullet, baseline-aligned, with a 1em hanging indent.

27. **08-iphone-journal**:
    - The top card "Today / Morning" is ambiguous: is "Morning" a prompt, a template, or the first line of an entry?
    - There is no compose action in the toolbar.
    - Fix: label it "Today" with the entry's first line (or "Start today's entry" in indigo if it's empty), and add a `square.and.pencil` toolbar button.

## What works

- The Settings (14) and Agent Info (17) sheets are textbook iOS: tiles, inset-grouped lists and a destructive row on its own. Keep this as the reference for every list-and-detail screen.
- The article reader (34) uses New York serif, a comfortable line length, a clear byline and source line, and readable inline code. It feels designed, not defaulted.
- The permission card (06, 13d) is the single most important interaction and it reads right: an orange outline and hand, the command in mono, an optional note, and an indigo Allow beside a glass Deny.
- The iPad chat (13b, 13d) uses a ~740px reading column with right-aligned indigo user bubbles and unbubbled agent replies. That's the right model for a pro tool.
- The Live Activity and compact island (57–59) are compact, legible, colour-coded and on-brand, and the ring in 59 is a nice personality touch.

## To reach 9+

1. **Fix every scroll-edge collision**: put the chat and actor headers and the composers in `safeAreaBar` with the system scroll-edge effect, add bottom content margins, and fade the trailing edge of clipped code blocks. This alone lifts Native and Polish.
2. **Lock the semantic palette and icon map**:
   - Orange only for needs-you, red only for failed or overdue, green only for connected or done.
   - Priority without orange or gray-shade flags.
   - One status-symbol family (`*.circle.fill`).
   - One symbol per concept (Cue, Run) shared across chat, info and widgets.
3. **Rebuild the widgets for density and truth**: shrink the decorative avatars, fill the medium and large Agents widgets with status rows that match the headline, fit 3 to 4 tasks in the small and medium widgets, and give the XL widget two columns.
4. **Normalise the screen chrome**:
   - A large title on every root tab, including Workspace's switcher.
   - A centred inline title on every pushed screen.
   - One greeting with the first name only.
   - One capsule style for composer accessories.
   - One value affordance per control type in the task form.
5. **Give the sparse screens a lead**:
   - Dashboard on iPad gets a second column (Today's tasks or pinned agents) instead of a dead right half.
   - Feeds gets a "Latest" section.
   - Extensions gets real or tinted icons.
   - Intelligence gets a deliberate pinned grid and aligned actor rows.
