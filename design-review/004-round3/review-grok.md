Connection lost, reconnecting to https://agentn.global.api5.cursor.sh (attempt 1)...
Retry attempt 1...
## Scores

| Category | Score | One-line reason |
| --- | --- | --- |
| Native | 6.7 | The glass tab bar, sheet chrome, and grouped lists are iOS 27; the iPad sidebar, floating headers, and content under bars are not. |
| Typography | 6.2 | Article text and large titles read well; metadata is caption-sized, and code, tables, and titles are clipped. |
| Hierarchy | 5.6 | Greetings, giant avatars, and equal-weight chips outrank the work that needs you. |
| Spacing & density | 5.9 | Inset lists share a rhythm; bottoms collide with bars, and large widgets plus several screens are mostly empty. |
| Color & contrast | 5.3 | In light mode, orange, red, and green mean status on the dashboard, then flags, icons, and overdue dates. |
| Iconography | 6.2 | SF Symbols hold one weight, then letter tiles, emoji, flags, and calendar avatars compete with them. |
| Consistency & polish | 5.0 | The same row, date, title, and “needs you” treatment changes by screen, and several edges are cut off. |
| Overall | 5.7 | The reader, permission card, and tab bar look designed; the product as a whole is still an unfinished pass. |

## Problems

1. **01, 02, 03, 05, 12.** The last row sits under the glass. On the dashboard, “New message · 25m ago” and Quill’s avatar show through the tab bar; Intelligence’s next actor and Workspace’s “Cancelled” do the same; Atlas’s table and “Want me to draft…” run under “Message Atlas”; Maya’s Notes card slides under the tab bar. Give the scroll view a bottom inset equal to the tab bar or composer, plus 8pt, so the last separator clears the glass.

2. **13, 13b, 13c, 13d.** The iPad sidebar is a second, flatter app: a long stack of pages, every agent, and actors, with a saturated indigo capsule that is taller than the rows around it. On All tasks, no sidebar row is selected, so the detail title “All” is the only “you are here.” Use a system sidebar selection (rounded rect, subtle fill, label color unchanged). Keep the destination highlighted. Collapse agents to pinned plus a count, and keep Actors as its own short section.

3. **01, 07, 13c, 14, 17, 54, 55, 57.** Orange, red, and green do not keep a meaning. Dashboard and the Live Activity use orange for “Needs you” and red for “Failed.” The iPad task list uses red for overdue dates and red/orange/gray flags for priority. The tasks widgets color Nov 3, Nov 4, and Nov 5 orange even though the dashboard date is November 9, so those dates are overdue. Settings uses orange for Profile, red for Notifications, and green for Live Activities. Reserve orange for “needs you,” red for failed or overdue, and green for connected or done. Draw priority as the word “High” or “Medium” in `.subheadline` secondary, with a single neutral flag. Paint Settings symbols indigo or gray, in one tile style.

4. **01 vs 13.** The same Monday opens as a two-line display headline, “Let’s get going, / Jackson Zamorano,” on iPhone and as “Fresh start, Jackson Zamorano” on iPad. The iPhone headline pushes What’s New down until the fourth item is under the tab bar. The composer, the real primary action, is a faint field under the billboard. Use one string. Set it in `.largeTitle`, name on the same line, date in `.subheadline` secondary. Put the composer directly under the date, then What’s New.

5. **06, 34.** Code is cut off mid-glyph. The iPhone session clips `Duration` to “Dura” and `attempt` to “atte” at the card edge. The article clips the comment in the bottom code block and lets the block run into the home indicator. Put code in a horizontal scroller inside the card, 16pt from the card edge, with a trailing fade. Keep 24pt below the block, above the home indicator.

6. **05.** The transcript’s table is the thing you cannot read: three cramped columns, the third row sliced by the composer, and machine dates `2026-11-12` beside prose that says “Today” and “Tomorrow.” On iPhone, render each task as a stacked row: title `.body`, due and owner `.subheadline` secondary, due formatted “Nov 12”. Inset the transcript above the composer.

7. **02.** Intelligence leads with two oversized avatars (a compass and a letter “S”) and parks the session that needs you under the tab bar. “Teams” is a blue link inside the agent card, so it reads as another agent. Put a “Needs you” section first, one row, orange hand, title `.body`, status `.subheadline` in orange. Shrink pins to a 44pt horizontal row, one avatar recipe (symbol centered on the agent color). Move Teams out of the card and set its label in `.body` primary.

8. **07 vs 13c.** Inbox and All tasks are different components. iPhone is a short inset card; iPad is a full-width hairline list whose second line is a run of equal gray chips (date, person, size, tag, tag, list). The eye cannot find the date or the person. Use one row: 22pt circle, title `.body`, one `.subheadline` secondary line with the date (red when overdue) and the assignee. Keep a single tag at most. Group iPad rows into Overdue, Today, and Later with `.subheadline` secondary headers.

9. **50, 51, 52, 53, 56.** Widget sizes and words drift. The small agents widget says “Need you” in gray and stacks a calendar “17” with two avatars, so it reads as a date widget; medium and large correctly say “Needs you,” still in gray, while Ada is only “Reading…”. Large agents repeats the three medium rows and leaves the lower half blank. Extra-large tasks leaves the lower half blank and drops flags in the gutter between columns. Small tasks truncates “Review the ro…”. Always use “Needs you” in orange, `.subheadline` semibold. Small agents: avatar stack of agents only, orange caption only when someone needs you. Large: fill the card with more rows. Extra-large: two columns, flag 8pt after the title, rows continued until the card is full. Small tasks: one full title and “4 more” in `.footnote` secondary.

10. **57, 58, 59.** The Live Activity’s summary disagrees with itself. The header order is hand, then working, then done; the bar is green, then indigo, then orange. Times read “0:43” and “5:16” with no unit. Compact shows a rainbow ring and “3,” which does not say “someone needs you.” Order the bar to match the header, or replace it with one bar in the most urgent color. Label times “44s” and “5m” in `.caption` secondary, with “elapsed” omitted once the unit is short. Compact trailing: an orange hand and “1” when a session needs you; otherwise one indigo count of sessions still running.

11. **13b, 13d.** The iPad chat and session headers float on the scroll view. Atlas’s earlier lines (“look disabled.”, a faded sentence) show above and through the avatar. The session title sits on top of a faded tool card. Pin a material bar to the top, inset the scroll content below it, and put the avatar and `.headline` title inside the bar.

12. **13d.** Selecting the actor paints the row indigo and leaves “Needs you” orange on that indigo, so the status color fails and the urgent row is the one at the bottom edge. Keep selection as a light tinted rounded rect, primary label color unchanged, “Needs you” in orange `.caption` semibold. Repeat that status at the top of the sidebar when any actor needs you.

13. **06, 13d.** The session name is the title and it does not fit. iPhone shows “Add backoff to the change …”; the subtitle “apple” has no label. The permission card below is the real focus and is the strongest component in the app, sitting under a title you cannot read. Use a two-line leading title, `.headline`, full name wrapping, and `.subheadline` secondary with a folder symbol plus the project name.

14. **02, 04, 07, 08, 10, 14, 17, 26, 44.** Titles and dismiss controls change every screen. Feeds, Intelligence, and Extensions use a leading large title. Journal, Documents, and Inbox use a centered bold title. Workspace has only “🎨 Studio.” Settings and agent info dismiss with an indigo check; the task sheet uses a gray check and an X, on screens that are not confirming an edit. Use a leading `.largeTitle` on every list. Navigation sheets get “Done” in `.body` indigo, trailing. Edit sheets get “Cancel” and “Done” as text. A gray check appears only while disabled, at reduced opacity.

15. **26.** The task sheet emphasizes the empty field. “Set Size” is indigo; Status, Assignee, and Priority are quiet gray. The note is shown and then repeated as “Edit Notes.” The nav title is the generic “Task.” The Due Date row shows a switch and no date. Put the task name in the nav title. Make the note itself the edit control and remove the extra row. Set empty values in `.body` secondary (“Add size”), same color as the filled values. When a due date exists, show it as the trailing `.body` value on that row.

16. **44, 12.** Extensions and the contact are unfinished identity. Every extension is the same gray letter tile, version jammed on the name (“GitHub v4”), subtitle cut mid-word (“fro…”, “publis…”). Maya is a muddy gray “MC” while agents are saturated color, and Add Email / Add Phone sit inside an already complete card. Give extension subtitles two lines at `.subheadline` secondary, and move the version to that line in `.caption` secondary. Tint each monogram a distinct color. On the contact, use a colored disc and `.title2` semibold initials. Move add-field rows into editing.

17. **03, 04.** Workspace and Feeds are the same indigo list, so color never helps you scan. Launch, Product, and Admin are identical folders. Ops Weekly has no count while the other feeds show one. Keep indigo symbols for navigation. Add a trailing count in `.body` semibold when it is non-zero, and omit it when it is zero, including Ops Weekly. Give a task list with overdue work an orange count, using the same “needs you” orange as the dashboard.

18. **08, 10, 05, 13c.** Dates are a different dialect on every screen: “2m ago,” “Nov 15,” “yesterday,” “Nov 9, 2026,” “2026-11-12.” “waiting” is lowercase next to “Tiny.” “Design Review — Nov 8” repeats “yesterday.” Journal’s Today card sits outside “November 2026.” Documents have no symbols; every neighboring list has one. Use “Yesterday” capitalized, “40 minutes ago” within a day, and “Nov 8” after that. Put Today inside the month group as the first row. Add a document symbol in secondary color, aligned with the Journal and Workspace symbols.

19. **13b.** A resolved choice still looks like an open form. Wednesday, Thursday, and Friday stay as full rows in a gray card, with only a small check on Thursday, under a message that already says “Done: Record demo video…”. Collapse a resolved choice to one line, “Thursday 15:00–17:00,” checkmark, `.subheadline` secondary. Reserve the full A/B/C card for a choice that is still open, with the accent on the selected row.

20. **05, 06, 13b.** Primary indigo drifts. User bubbles and Allow are a brighter violet; tab labels, links, and list symbols are a quieter indigo. “Context rebuilt…” uses a sparkle, the same idea as the Intelligence tab, for a cache note. Pick one accent and use it for Allow, send, links, and bubbles (white label on accent). Mark system notes with `info.circle` in `.footnote` secondary.

## What works

- The actor permission card (06, 13d): orange stroke, command in its own inset, one filled Allow, a quiet Deny, and a separate stop control. That is the right “needs you” pattern; the rest of the app should take its color and emphasis from here.
- The glass tab bar and the toolbar capsules (01–04, 07, 34): selection pill, badge, back disc, and plus/ellipsis groups already feel like iOS 27.
- The article (34): title, byline, indigo link, body measure, real headings, and inline code highlights. This is the type system to copy.
- Dashboard status rows (01, 13): hand, check, x, and dashed circle, each with a single colored status line under the title. The pattern is clear whenever the row is actually on screen.
- Lock Screen and expanded Live Activity (57, 58): one orange “Needs you” row, quiet running rows, and a header count. The structure is right; the compact island and the bar need to match it.

## To reach 9+

1. **Write one status-color rule and apply it on every surface.** Orange is only “needs you,” red is only failed or overdue, green is only connected or done. Flags, Settings tiles, widget dates, sidebar selection, and agent identity stop borrowing those three. This is the fastest lift for Color and Consistency, the two lowest scores.
2. **Finish the edges.** Bottom-inset every scrolling screen so nothing sits under the tab bar or the composer. Let code scroll inside its card. Put a material behind iPad headers. A design award ship has no clipped glyphs and no type under glass.
3. **Rebuild information architecture around the urgent work.** Dashboard and Intelligence open on what needs you, with the greeting reduced to one `.largeTitle` line and the same words on iPhone and iPad. The iPad sidebar becomes a system sidebar with a persistent selection, pins collapsed, and “Needs you” above the fold.
4. **One type ramp and one list row.** Leading large titles, `.body` titles, `.subheadline` secondary metadata, one date formatter, one task row on iPhone, iPad, and widgets. Tags and list names leave the row and stay on the sheet. Hierarchy and Typography move together once the second line stops being a chip dump.
5. **Design each extra surface for its size.** Large and extra-large widgets fill their cards; the compact island shows an orange “1” when someone needs you; the Live Activity bar matches its legend. The in-app permission card already shows the standard. Widgets and the island should look like the same product.
