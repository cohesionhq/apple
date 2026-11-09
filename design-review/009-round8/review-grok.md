## Scores

| Category | Score | One-line reason |
| --- | --- | --- |
| Native | 7.3 | Liquid Glass tab bar, sheets, switches, and inset groups are real iOS; iPad panes and widget sizes are still phone layouts. |
| Typography | 6.6 | Titles and the article face read well; metadata collapses into one faint caption, and code and the chat table clip. |
| Hierarchy | 6.2 | Lists have clear titles, but the dashboard shouts the name, Workspace and Feeds are menus, and iPad tasks cannot be scanned. |
| Spacing & density | 6.5 | Phone cards share a rhythm; iPad and the larger widgets leave empty fields or stretch one row across the canvas. |
| Color & contrast | 6.4 | Orange, red, and indigo behave in the app, then “need you” goes gray on the widget and indigo tints every icon. |
| Iconography | 6.6 | SF Symbols are the family, but avatars, Settings tiles, extension letters, and widget illustrations are four containers. |
| Consistency & polish | 6.0 | The same task, greeting, and needs-you state are redesigned per surface, and several edges clip. |
| Overall | 6.4 | Credible native chrome, with a designed reader and permission card; not yet one product a designer would sign. |

## Problems

1. `13-ipad-split-view-light.png`, `13b-ipad-agent-chat-light.png`, `13d-ipad-actor-session-light.png`. The iPad detail pane is a phone column dropped on a wide canvas. Dashboard content sits in a narrow left stack with a dead right side; chat and the actor transcript are a centered phone measure. Give reading surfaces one centered column, about 680pt, with the composer and What’s New stretching to that width. Use the spare width on the dashboard for two columns: What’s New beside Working.

2. `01-iphone-dashboard-light.png`, `13-ipad-split-view-light.png`. The same screen opens with two products. iPhone says “Let’s get going, Jackson Zamorano” in a display size; iPad says “Good morning, Jackson Zamorano” at a large title. Use one greeting and one style: large title, date in `.subheadline` secondary on the next line, on both devices.

3. `01-iphone-dashboard-light.png`. The name is the loudest thing on the screen, so What’s New starts late and the fourth item (the count says 4) plus Working sit under the tab bar. Drop the display size to a large title so the first status row is the thing you see. Keep each status line in the status color at `.subheadline`, not a smaller tertiary line.

4. `07-iphone-tasks-light.png`, `13c-ipad-tasks-light.png`, `53-widget-tasks-small-light.png`, `54-widget-tasks-medium-light.png`, `55-widget-tasks-large-light.png`, `56-widget-tasks-extralarge-light.png`. A task is four different rows. iPhone is a title plus a second metadata line; iPad is one run-on of date, person, size, tags, and folder; the large widget stacks the date under the title; the extra-large widget throws the date to the far edge. Ship one row: title in `.body` emphasis, due date in a fixed trailing column (red when overdue), priority only as the flag, and people, size, and tags on a second line in `.subheadline` secondary. On iPad, align those into columns so dates scan.

5. `50-widget-agents-small-light.png`, `51-widget-agents-medium-light.png`, `52-widget-agents-large-light.png`. Small, medium, and large are the same overlapping avatars scaled up, and the sentence that matters is gray: “need you” / “Ada, Milo, and Juno need you.” The large widget then paints the row status “Needs you” in orange. Set every “Needs you” label in orange, matching the dashboard. Give each size its own layout: small is the number plus “Needs you”; medium is the three avatars with names; large is the rows, with the hero avatars smaller so the list fills the widget.

6. `53-widget-tasks-small-light.png`, `55-widget-tasks-large-light.png`, `56-widget-tasks-extralarge-light.png`. The small widget truncates “Review the ro…” while the next title fits, and “7 more” is faint. The extra-large widget is the large list stretched, with a wide empty gap between title and date. Let small titles wrap to two lines in `.subheadline`. Keep dates in a trailing column at large. Make extra-large two columns of the medium row. Set “7 more” and “1 more” in `.subheadline` secondary, not tertiary.

7. `06-iphone-actor-session-light.png`, `05-iphone-agent-chat-light.png`. The Swift sample runs off the right edge of the code card, and the chat table runs under the composer so Due, Owner, and the last rows are cut off. Put code and tables in a rounded inset that scrolls horizontally, monospaced `.footnote`, and add a bottom content inset equal to the composer height so the last row clears it.

8. `13-ipad-split-view-light.png`, `13b-ipad-agent-chat-light.png`. The sidebar item that needs you is clipped by the bottom edge (“Add backoff to the change sock…”). That is the row the orange status exists for. Inset the sidebar above the home indicator and keep that row fully on screen, with “Needs you” in orange `.caption` under the title, the same treatment as What’s New.

9. `03-iphone-workspace-light.png`, `04-iphone-feeds-light.png`. Both tabs are directories of chevrons. Workspace lists Today, Journal, Documents, Contacts, then folders, then views, and never shows a task. Feeds shows source names and counts, then a blank half screen. Open Workspace on the Inbox (or Today) and move the other pages into the toolbar menu. On Feeds, show the latest articles (title `.headline`, source and time `.subheadline` secondary) and keep the source list behind the title menu.

10. `02-iphone-intelligence-light.png`, `03-iphone-workspace-light.png`, `04-iphone-feeds-light.png`, `10-iphone-documents-light.png`. Indigo is the accent, the selected tab, your chat bubble, the Allow button, and also every row icon, so it stops meaning “primary.” Paint navigation symbols in the label color, as the toolbars already do. Reserve indigo for the selected tab, primary buttons, and your own bubbles.

11. `02-iphone-intelligence-light.png`, `57-live-activity-lockscreen-light.png`, `58-live-activity-expanded-light.png`. Green is Scout’s avatar and also the Live Activity “done” segment. A green agent and a green success read as the same signal. Keep agent color inside the disc. Use green only for done or connected, as on the activity’s check.

12. `06-iphone-actor-session-light.png`, `13d-ipad-actor-session-light.png`, `01-iphone-dashboard-light.png`. The stop control is a red square, the same red as “Failed” and Unpair. Use a label-color stop glyph in a circular bordered button. Keep red for failed, overdue, and destructive actions.

13. `26-task-detail-light.png`. The sheet is a settings form. The title sits in a card, notes follow, and Due Date is a switch at the bottom of Status, Assignee, Priority, Size, Folder, and Tags. “Set Size” is an indigo text button while the other fields are menus, and the circled check in the toolbar does not say whether it completes or dismisses. Make the task title the sheet title. Put due date and priority on one row directly under it. Show Size as “None” with the same menu as Folder. Replace the check with a “Done” button to close, and a separate Complete control if completing is the action.

14. `12-iphone-contact-light.png`. Maya Chen’s avatar is a gray “MC” disc beside a product full of saturated agent discs, and Add Email and Add Phone stay visible under values that already exist. Company is only inside Notes, which slides under the tab bar. Use a color disc at the same size as an agent avatar, put “The Ledger Daily” in `.subheadline` secondary under the name, and move Add Email and Add Phone into edit mode. Inset the notes card above the tab bar.

15. `17-agent-info-light.png`. “48K” and “tokens” break onto two lines in the Context row, so the value looks like a wrapping bug. One trailing value, “48K tokens”, in `.subheadline` secondary, vertically centered with “Context”.

16. `44-extensions-light.png`. GitHub, Linear, Done Stamp, iOS Companion, and Cohesion Registry are the same gray letter tile, so none of them is identifiable and there is no on or off state. Use the Settings row tile (rounded rect, one color per extension, symbol or letter inside) at the same size as `14-settings-light.png`. Put the version in `.caption` secondary on the title line, the description in `.subheadline` secondary, and a status (“On”) in `.subheadline` secondary before the chevron.

17. `08-iphone-journal-light.png`, `10-iphone-documents-light.png`. Journal has no add button and lifts Today into its own card above “November 2026.” Documents has search and +, and “Design Review — Nov 8” also says “Yesterday.” Use one sectioned list. Add a trailing + on Journal. Show only the relative date in `.subheadline` secondary; drop the repeated date from the title line.

18. `02-iphone-intelligence-light.png`. The pinned discs (Atlas, Scout) show no status, while Quill’s unread is a blue dot lower down, and Teams is the last row inside the Agents card. Ring a pin in orange when that agent needs you. Move Teams out of the agent group into its own row, the same pattern as New Agent on iPad.

19. `57-live-activity-lockscreen-light.png`, `58-live-activity-expanded-light.png`, `59-live-activity-compact-light.png`. The legend reads hand, then running, then done, and the bar reads green, then indigo, then orange, so the bar cannot be read from the legend. Order the segments orange, indigo, green to match the counts, or drop the bar and keep the counts. On the expanded island, set the timers in a secondary label that holds on black, not a dim gray. The compact ring’s “1” is the right reduction; keep it as the needs-you count in orange.

20. `13b-ipad-agent-chat-light.png`, `06-iphone-actor-session-light.png`. The poll is a flat gray slab (A / B / C, a small check on B). The permission prompt is an orange-stroked card with real buttons. Draw choices as button rows in the same rounded card, selected row filled with a quiet indigo tint and a trailing check. One card language for “the agent is waiting on you.”

21. `50-widget-agents-small-light.png`, `02-iphone-intelligence-light.png`, `14-settings-light.png`, `44-extensions-light.png`. Avatars do not match. In the app, agents are flat symbol or letter discs; Settings uses colorful rounded-rect tiles; extensions use gray letter squares; the widget uses a telescope illustration and a calendar graphic. Use the in-app disc, unchanged, on the widget. Two containers only: a circle for agents and people, a rounded rect for settings and extensions, symbols at one weight.

22. `34-article-light.png`, `05-iphone-agent-chat-light.png`. The reader is the best type on the phone, then inline code highlights (`@Observable`, `@Published`, `objectWillChange`) break the sentence into gray pills, and the list marker is a middot. Style a whole code token as monospaced with one quiet background. Use the same hanging indent and marker as the numbered list in chat. Keep the headline at the article’s current large size; it is the scale the dashboard should learn from, not exceed.

23. `05-iphone-agent-chat-light.png`. Your bubble is indigo, and links inside Atlas’s reply are a second blue, so the accent splits. Tint inline links indigo, the same accent as the bubble and Allow.

24. `06-iphone-actor-session-light.png`. The screen’s title truncates to “Add backoff to the change …” while the subtitle is only “apple.” Allow the inline title two lines at `.headline`, with the repo name in `.caption` secondary, so the session you opened is named.

## What works

- The tab bar is actual Liquid Glass: one selected pill, a badge on Intelligence, and labels that match the four sections.
- What’s New and the actor permission card use orange for “needs you,” red for failed, and a single indigo Allow. That is the status system to extend, not restyle.
- Settings is a finished iOS screen: color tiles, grouped rows, On/Off in secondary, Unpair isolated and red.
- The article has a real reading scale: headline, byline, subheads, and a code block that is clearly not body text.
- The iPhone Inbox row is the right density for this product: title, one metadata line, flag at the trailing edge. The medium tasks widget is the same idea and should be the widget template.

## To reach 9+

1. Design the iPad pane on purpose. One centered reading column for the dashboard, chat, and actor session; a real column-aligned task table on All tasks; sidebar rows fully above the home indicator.
2. One task row everywhere. iPhone Inbox, iPad All tasks, and all four task widget sizes share title, trailing due date, flag, and a second metadata line.
3. Rebuild the agents widget per size, and paint every “Needs you” orange, with the same avatar discs as the app.
4. Make the three home tabs show work. Dashboard greeting at large-title size so What’s New leads; Workspace opens on the list; Feeds shows articles.
5. Lock color and icons. Indigo is selection, primary buttons, and your bubbles. Orange is needs you. Red is failed, overdue, and destructive. Green is done. Circles for agents and people, rounded rects for settings and extensions, one symbol weight.
