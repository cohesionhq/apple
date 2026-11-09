## Scores

| Category | Score | One-line reason |
|---|---|---|
| Native | 7.6 | Glass tab bar, toolbars and inset-grouped lists are right. The four tabs use four different title treatments, and a settings button floats alone top-left on every one. |
| Typography | 7.5 | Body sizes are sound and the serif article reader is lovely. Captions and footnotes on iPad chat, the Live Activity and task metadata fall to tertiary/caption2 and get hard to read. |
| Hierarchy | 6.9 | The Dashboard greeting outweighs the one "Needs you" item. The large Agents widget's headline contradicts its own rows. Answered and working states read as disabled. |
| Spacing & density | 7.1 | Lists have a good rhythm. Widgets leave half their area empty, pinned avatars are oversized, and the iPad sidebar is so loose that Actors falls off screen. |
| Color & contrast | 7.2 | Indigo and orange are mostly disciplined. Orange also means "high priority", red means overdue, urgent and failed, gray flags look disabled, and the selected sidebar row bleaches out orange. |
| Iconography | 7.3 | Mostly SF Symbols at one weight. Status marks mix filled and outline. The size and "All Feeds" glyphs are unclear, Extensions uses placeholder letter tiles, and widget emoji read as content. |
| Consistency & polish | 6.9 | Greeting copy differs between iPhone and iPad. Tasks is inset on iPhone but plain on iPad. Date formats are mixed, code blocks are hard-clipped, and content shows through chrome. |
| Overall | 7.2 | Clearly designed and coherent, but not yet finished: semantic colour, widget layouts and state treatments give it away. |

## Problems

1. **52-widget-agents-large**: the headline says "Ada, Milo, and Juno need you", but Ada's row says "Reading 12 of 40 sources". The "Needs you" status under Milo and Juno is gray, so the one colour that means "needs you" is missing from the widget about exactly that.
   - Make the headline count only agents that truly need you.
   - Render "Needs you" in orange with the `hand.raised.fill` glyph, the way 06 and 13 do.
   - Keep working agents in secondary text with their progress.

2. **50/51/52 Agents widgets, layout**:
   - The avatar strip is the whole design, and it scales up rather than using the space. Medium (51) leaves the right ~45% blank. In large (52), three ~145pt avatars take the top third, the list gets what remains, and the bottom stays empty.
   - Medium fix: the overlapping avatars at ~44pt on the left, and a 2–3 row list (name plus orange status) on the right.
   - Large fix: avatars at ~36pt in a header row beside the count, then 5–6 agent rows.
   - Colour the big count orange when it counts "need you".

3. **01/02/03/04 tab titles**: each tab has a different title treatment. Dashboard has a custom two-line greeting and no title, Intelligence and Feeds use large titles, and Workspace uses an inline emoji menu title. A lone glass gear also sits top-left on every tab, which is not where iOS puts settings.
   - Use large titles on all four tabs.
   - Make Workspace's switcher a `toolbarTitleMenu` on a large "Studio" title.
   - Move Settings to a trailing toolbar item (or a profile avatar) grouped with the tab's other actions.

4. **01-iphone-dashboard, 13-ipad-split-view: Dashboard hierarchy.** The greeting is two lines of ~34pt bold and uses ~25% of the iPhone screen. The only item that needs action ("Add backoff…", Needs you) has the same row weight as a Done item.
   - Shorten to "Good morning, Jackson" on one line, at .largeTitle or smaller.
   - Pull "Needs you" items into their own section above What's New, with the orange glyph and an inline Allow/Open action.
   - Demote Done and Failed items below it.

5. **01 vs 13: greeting copy.** iPhone says "Good morning, Jackson Zamorano" and iPad says "Let's get going, Jackson Zamorano". Use one time-of-day greeting on both, with the first name only.

6. **13d-ipad-actor-session, 13, 13b: sidebar selection.**
   - The selected row is a saturated indigo capsule with white text. On 13d this turns the orange "Needs you" glyph and label white, so the most important state disappears exactly when you're looking at it.
   - Use the system sidebar selection (a tinted, low-opacity fill with accent-coloured label) and keep status glyphs in their semantic colour when selected.

7. **13b-ipad-agent-chat, 13d: content shows through the top chrome.** On 13b, the floating avatar and "Atlas >" pill sit over half-legible scrolled text ("Raise the middle card less…") with a hairline under it. On 13d, the diff code shows through the session title.
   - Apply a soft scroll-edge effect under the header so content fades out before it reaches the title, and drop the hairline.
   - Alternatively, put a 28pt avatar and name inline in the principal toolbar slot.

8. **13b, answered question card.** The answered card reads as disabled:
   - Option text is gray on a gray card.
   - The A/B/C letters are nearly invisible.
   - The chosen option has only a pale lavender check.

   Collapse the answered card to the chosen option at .body primary with an indigo `checkmark.circle.fill`, and the other options hidden behind a "Show options" disclosure. The two footnote lines ("Noted: …", "Context rebuilt…") are caption2 tertiary: use .footnote secondary.

9. **05-iphone-agent-chat: table and composer.** The Markdown table runs under the glass composer, so "Record demo video 2026-11-12 You" shows through the field and makes it noisy. The table is full-width with columns crammed together, and it mixes "Today"/"Tomorrow" with ISO dates.
   - Add a bottom scroll-edge effect behind the composer.
   - Set tables at .subheadline, and make them scroll horizontally with a trailing fade when wide.

10. **06-iphone-actor-session, 34-article: code blocks.** They hard-clip at the right edge mid-identifier ("-> Dura", "isn't "), which looks broken rather than scrollable. Make them scroll horizontally with a trailing gradient fade and a little extra inset, or soft-wrap them with a hanging indent.

11. **07, 13c, 26, 54–56: priority flags.**
    - Flags come in four tints: red, orange, dark gray and light gray. The gray ones read as "disabled" or "no priority", and orange collides with "needs you".
    - Show a flag only for high and urgent priority, and remove medium and low flags from rows entirely.
    - Don't use orange for priority: red for urgent; for high, use an outline flag in secondary or `exclamationmark` marks like Reminders.

12. **13c-ipad-tasks, 07-iphone-tasks: the task metadata line** packs too much in:
    - Up to six caption-sized tokens.
    - ~14pt initials avatars ("JZ" and "MC" are illegible).
    - A size glyph that reads as a battery or ruler.
    - Folder names ("Launch", "Product", "Inbox") in plain gray that look like more tags.

    Drop the assignee when it's "You", use a `folder` glyph before the folder name, show size as a short text label without the icon, and set avatars at ≥16pt.

13. **07 vs 13c: list style and toolbar placement.**
    - Tasks are an inset-grouped card on iPhone but a plain list with separators on iPad. Use one style; inset-grouped matches the rest of the app.
    - On iPad, the +/filter/… pill hugs the window edge, far from the centred ~700pt content column. The "All ⌄" title is centred over the content, so the chrome feels detached from what it acts on.

14. **26-task-detail.**
    - "Set Size" is indigo while every other value is gray: show "None" in secondary with the up-down chevrons.
    - "Edit Notes" is a separate row under the notes. Make the notes field editable inline.
    - "Tags" shows a chevron and no value: show the tags or "None".
    - The confirm checkmark is a gray glass circle that looks disabled. Use the prominent glass style tinted with the accent.

15. **12-iphone-contact.**
    - Message/Call/FaceTime/Email are bare glyph-and-label pairs with no platters. iOS Contacts uses glass tiles for these: put each in a ~64×52 glass rounded rectangle.
    - "Add Email…" and "Add Phone…" sit in the read-only view, making the screen look like an edit form. Move them into Edit.

16. **44-extensions-light.**
    - Identical gray letter tiles (G, L, D, I, C) look like placeholders next to Settings' colourful symbol tiles. Use each extension's icon, or a tile coloured from its name with an SF Symbol.
    - Every description truncates at one line: allow 2 lines.
    - "v4" in tertiary right after the name competes with it. Move the version into the subtitle line or the detail screen.

17. **02-iphone-intelligence.**
    - Pinned avatars are ~120pt while list avatars are ~48pt: there is no middle size, and two pinned agents leave a big gap. Use ~72pt.
    - Scout's offline state shows only as a gray name under a fully saturated avatar. Desaturate or dim the avatar too, or add a small status dot.
    - "Teams" is styled as an indigo link row inside the Agents list. Give it its own section or a toolbar item.
    - Juniper's row has no subtitle, so the list's rhythm breaks.

18. **13-ipad-split-view: the "Working 1" row.** It is all tertiary text with a dotted circle, so the one live item looks disabled. Use a primary title, a secondary "Working · now" line, and an animated indigo progress indicator.

19. **13 sidebar density.** Sidebar rows are ~56pt, and team subtitles under every agent push the Actors section (the one with "Needs you") to the bottom edge of a 13-inch iPad.
    - Use standard sidebar row height and drop the team subtitles; teams are already a section concept.
    - Or float actors that need you above Agents.

20. **57/58/59 Live Activity.**
    - The compact trailing ring shows "3", which is the done count. It should lead with what needs you: an orange hand and "1".
    - The tri-colour bar has no stated meaning. Remove it or label it.
    - Lock Screen rows are ~13pt, and the header counts with their tiny glyphs are smaller still. Use .subheadline for rows and .footnote semibold for counts.

21. **54/55/56 Tasks widgets.**
    - Medium shows only 2 rows and leaves the bottom third empty: fit 3.
    - Large puts the date under the title while medium and XL put it at the trailing edge. Pick one; trailing works at every size.
    - XL has a ~900pt gap between title and date. Use two columns, or add notes and folder text there.

22. **01 Dashboard status glyphs** mix three styles in one list: a filled orange hand, an outline gray check and a filled red x. Use filled circle symbols for every status (`checkmark.circle.fill` in secondary for Done).

23. **04-iphone-feeds.** The "All Feeds" glyph reads as a jar or trash can. Use `tray.full` or `newspaper`. The Ops Weekly row has no count, so its chevron column looks misaligned; show "0" in tertiary, or reserve the width.

24. **17-agent-info.** "Context" sits alone in a card, with "48K" over a tiny tertiary "tokens" caption. Put "48K tokens" on one line in .body secondary inside the Identity/Memories list, or show a small usage gauge.

25. **10-iphone-documents.** The lowercase "yesterday" sits beside sentence-case section headers and "Today". Use "Yesterday". Rows also have no leading document glyph, unlike every other Workspace list.

26. **06 actor composer.** A lone indigo spinner in a glass circle left of "Follow up…" is ambiguous: is it a button? Show progress as a status line above the composer ("Waiting for you · 2m") and keep only Stop as a control.

## What works

- The orange "Needs you" language (hand glyph, orange-bordered permission card, orange status text) is clear and distinctive wherever it isn't overridden.
- The article reader (34) has a serif display title, a comfortable measure and well-styled inline code. It's the most "designed" screen in the app.
- The permission card (06/13d) is a strong pattern: the command in mono, the working directory, the reason, an optional note, and a single prominent Allow.
- Settings and agent info (14, 17) use colourful symbol tiles and read as native, trustworthy iOS.
- The chat (05/13b) has unbubbled agent prose, indigo user bubbles, and quiet tool-step lines with durations. It's a good balance for a pro tool.

## To reach 9+

1. **Fix semantic colour everywhere.** Orange only for "needs you": remove orange and gray priority flags, and keep status colour when a row is selected. Red only for failed, overdue and destructive actions. Make every "needs you" count and status orange, in widgets and the Live Activity's compact view too.
2. **Rebuild the Agents widgets around content, not avatars.** Use small avatar clusters plus lists of who needs you, fill each size, and make sure the headline matches the rows.
3. **Unify the tab shell.** Large titles on all tabs, Settings moved to the trailing toolbar, Workspace's switcher as a title menu, and one greeting with first name only. Promote "Needs you" to the top of the Dashboard.
4. **Give every state a finished treatment.** Answered questions, working rows, offline agents and disabled-looking confirm buttons all need proper styles. Add scroll-edge effects under headers and composers, and fix code-block clipping.
5. **Tighten the iPad.** Use the system sidebar selection and density so Actors stays visible. Use the same inset-grouped task list as iPhone. Anchor toolbar actions to the content column, and trim task metadata to legible tokens with real folder and size marks.
