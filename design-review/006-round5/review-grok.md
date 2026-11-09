## Scores

| Category | Score | One-line reason |
| --- | --- | --- |
| Native | 7.5 | Glass tab bar, split view, sheets, and system controls are in the right places; root screens still slide under the tab bar and the sidebar clips its last row. |
| Typography | 6.5 | Titles, body, and the article scale read as SF; code, the chat table, widget titles, and task metadata do not stay legible. |
| Hierarchy | 6.6 | Settings, the article, and the permission card lead the eye; Dashboard, Intelligence, and the widgets bury “needs you.” |
| Spacing & density | 6.4 | Grouped lists share a rhythm; the extra-large widget, the medium widget, and the iPad task header are mostly empty. |
| Color & contrast | 6.7 | Indigo, orange, red, and gray hold their meaning in the app; the agents widget, agent hues, and the Live Activity bar break it. |
| Iconography | 6.8 | SF Symbols are one weight; destination rows, extensions, “working,” and widget avatars are four different icon systems. |
| Consistency & polish | 6.1 | The same state changes color, wording, glyph, and layout by surface, and several edges are cut off. |
| Overall | 6.5 | A designer built the shell; a professional would not yet believe every screen was finished. |

## Problems

1. `50-widget-agents-small-light.png`, `51-widget-agents-medium-light.png`, `52-widget-agents-large-light.png`. “Needs you” is the product’s orange, and it is orange on the dashboard, the actor row, and the Live Activity. In the agents widget the same words are secondary gray, identical to “Reading 12 of 40 sources.” Use orange for that status line at every size, and red when a run has failed.

2. `13-ipad-split-view-light.png`, `13b-ipad-agent-chat-light.png`, `13c-ipad-tasks-light.png`, `13d-ipad-actor-session-light.png`. The actor that needs you is the last sidebar row, and the device corner cuts through both the title and the orange status. On `13d` the indigo selection pill is clipped with it. Inset the sidebar above the home indicator and the corner radius so the last row, and its selection shape, are complete.

3. `01-iphone-dashboard-light.png`, `02-iphone-intelligence-light.png`, `03-iphone-workspace-light.png`, `12-iphone-contact-light.png`. Floating-tab content does not rest above the bar. A purple avatar pokes out under the dashboard tab bar, Intelligence and Workspace draw the next row through the bar and into the home-indicator band, and the contact notes run under the bar. Add a bottom inset equal to the tab bar plus the home indicator so the last row sits fully above the glass.

4. `53-widget-tasks-small-light.png`, `54-widget-tasks-medium-light.png`, `55-widget-tasks-large-light.png`, `56-widget-tasks-extralarge-light.png`. The task widget is a different layout at each size, and the larger sizes do not earn the space. Small clips the title to “Review the ro…”. Medium shows two rows and a blank lower half. Large stacks a red date under the title and parks the flag on the right. Extra large goes back to a trailing date, then leaves most of the widget empty, with the flag a long gap away from the title. Use one row: circle, title (two lines on small), overdue date in red subheadline, flag trailing. On extra large, two columns of that row. Show another row whenever the height fits, including medium.

5. `05-iphone-agent-chat-light.png`. The task table is drawn underneath the composer, so “Record demo video,” the due dates, and the owners are cut in half, and the follow-up question sits below the field. Inset the transcript by the composer’s height. Keep the table inside the column width and let it scroll horizontally on its own, with a header in semibold and cells in subheadline.

6. `06-iphone-actor-session-light.png`. The Swift the user is reading before they allow a command is clipped mid-token (`Dura`, `atte`), with no wrap and no scroll cue. The iPad transcript in `13d-ipad-actor-session-light.png` shows the full line. Wrap the code block to the column, or put a horizontal scroll inside the block, and keep every glyph inside the padding.

7. `01-iphone-dashboard-light.png`, `02-iphone-intelligence-light.png`, `13-ipad-split-view-light.png`. The urgent state is the third layer down. Dashboard spends the top on a two-line display name and an empty composer; “Needs you” is one more cell. Intelligence spends it on two oversized avatars, and the orange actor row is the one the tab bar cuts. Put a single needs-you row first (orange hand tile, title, relative time), and make the greeting one line at the large-title size.

8. `03-iphone-workspace-light.png`, `13-ipad-split-view-light.png`, `14-settings-light.png`, `17-agent-info-light.png`. Page rows are bare indigo symbols, so Today, Journal, a folder, and Admin scan as the same row. Settings and the agent sheet use white symbols on colored tiles, which is why those screens scan. Use that tile for every destination row in the workspace list and the sidebar, one color per destination.

9. `57-live-activity-lockscreen-light.png`, `58-live-activity-expanded-light.png`, `59-live-activity-compact-light.png`. The compact island shows a green “3” while a session needs you, so the glanceable state is the opposite of the urgent one. The leading mark is the Feeds antenna. The progress bar is green, then indigo, then orange, and those segments do not match Budget review, Q3 research, and Inbox digest. If anything needs you, the compact trailing side is an orange hand. Use the Intelligence sparkles for the mark. Drop the bar, or draw one segment per session in that session’s status color.

10. `01-iphone-dashboard-light.png`, `06-iphone-actor-session-light.png`, `13-ipad-split-view-light.png`, `57-live-activity-lockscreen-light.png`. “Working” is three symbols: a dotted circle on the dashboard, a spinner in the actor field, and circular arrows on the Live Activity. Pick the dotted circle and use it for every in-progress session, including the Live Activity rows.

11. `13c-ipad-tasks-light.png`, `07-iphone-tasks-light.png`. A task row is a title plus a run of identical gray capsules (date, person, size, tag, folder), so only an overdue red date and a flag survive a scan. Medium priority is a gray flag on a white row. Keep the date as subheadline (red when overdue), the assignee as the avatar, size as one capsule, and the folder as secondary text. Draw the medium flag in secondary, not quaternary.

12. `44-extensions-light.png`. Five extensions share one gray letter tile, the subtitle is ellipsized (“fro…”, “y…”, “publis…”) while the rest of the screen is empty, and nothing shows connected, inactive, or failed. Wrap the subtitle to two lines. Use a colored symbol tile, and put the status in the trailing detail: green connected, orange inactive, red failed.

13. `50-widget-agents-small-light.png`, `51-widget-agents-medium-light.png`, `52-widget-agents-large-light.png`, `01-iphone-dashboard-light.png`. One state, three strings: “Need you,” “need you,” and “Needs you.” Times are a fourth inconsistency across the set: “2m ago,” “40 minutes ago,” “yesterday,” “Nov 15,” “Nov 3,” “0:43.” Use “Needs you” everywhere, and one formatter: “2m ago” / “1h ago” within the day, “Yesterday,” then “Nov 9.”

14. `02-iphone-intelligence-light.png`. Pinned agents are two large discs, left aligned, with a blank region where the rest of a row should be. They read as a layout that expected four and got two. Size the discs for a four-across row and center a short row, with the name in secondary under the disc and the unread dot after the name.

15. `52-widget-agents-large-light.png`, `02-iphone-intelligence-light.png`. In the app an avatar is a symbol or an initial, centered in a flat disc. The widget puts a full-color telescope and a full-color calendar into the disc; the calendar’s own orange sits on an orange fill and reads as “needs you,” which is Juno’s agent color. Draw widget avatars with the same disc rule, and scale an emoji to about half the disc.

16. `02-iphone-intelligence-light.png`, `13-ipad-split-view-light.png`. Juniper’s disc is the same red as failure, and Scout’s is the same green as connected. Status then has to fight the avatar. Keep red and green for failed and connected; shift agent colors off those two hues, or mute the disc and put status only in the label.

17. `13c-ipad-tasks-light.png`. On a 13-inch landscape detail, the screen title is a small centered “All” with a chevron, and the add and filter buttons sit in a nearly empty bar. Use a leading large title, the view menu on that title, and the actions trailing, the way Intelligence treats its title.

18. `10-iphone-documents-light.png`. “yesterday” is lowercase next to “4 days ago” and “2 weeks ago,” and a plan and a note have no kind mark, so the row is only two gray-balanced strings. Use “Yesterday,” a leading document symbol in secondary, the title in body, and the date in subheadline secondary.

19. `26-task-detail-light.png`. The sheet’s confirm control is a gray filled circle with a white check, beside a light close button, so the commit action looks disabled. Fill the check with the accent when the sheet can be confirmed.

20. `04-iphone-feeds-light.png`, `02-iphone-intelligence-light.png`. Feeds lists unread counts of 5, 2, 1, and 2 and the tab is unbadged. Intelligence shows a red badge of 1 for a single unread dot. Badge a tab for needs-you only, and keep ordinary unread as the trailing count already on the row.

21. `01-iphone-dashboard-light.png`, `13-ipad-split-view-light.png`. “What’s New 4” reads as one title. The count is the same gray and the same baseline as the section header. Set the count in subheadline, tertiary, with a clear gap, or in a secondary capsule.

22. `06-iphone-actor-session-light.png`. The session name truncates to “Add backoff to the change …” and the project name “apple” is a tiny centered subtitle. Use a two-line inline title for the session, and set the project in subheadline secondary.

23. `12-iphone-contact-light.png`. Message, Call, FaceTime, and Email are four equal indigo actions, which is the Phone contacts screen with a workspace note underneath. Keep one primary action (Email) as the labeled button, and move Call and FaceTime into the overflow.

24. `13-ipad-split-view-light.png`, `01-iphone-dashboard-light.png`. “You are here” is a solid indigo bar with white type in the sidebar, and a neutral pill with an indigo glyph in the tab bar. Use the neutral pill in the sidebar too, and keep indigo on the symbol and the label.

## What works

- The glass tab bar and the circular toolbar buttons are the right iOS 27 chrome, used in the same places on every iPhone tab.
- What’s New already has a real status language: orange hand for needs you, gray check for done, red for failed, and the permission card on `06-iphone-actor-session-light.png` and `13d-ipad-actor-session-light.png` is the clearest object in the app.
- The article on `34-article-light.png` has a proper title, byline, measure, headings, and inline code.
- Settings is a finished grouped list: colored tiles, a separated red Unpair, and the same tiles on the agent sheet.
- On iPad the conversation column stays a readable measure, and the choice card and the permission card sit in that measure instead of stretching across the pane.

## To reach 9+

1. Make orange, red, green, and the working glyph mean one thing on every surface, including both widgets and all three Live Activity states, and put “Needs you” in that orange with one shared time formatter.
2. Fix the edges that are actually cut: sidebar bottom inset, tab-bar inset, composer inset over the chat table, and code that wraps instead of clipping.
3. Use one symbol tile for every destination, and one avatar disc for agents in lists and widgets, so Workspace, Settings, extensions, and the home screen widgets look like the same app.
4. Rebuild the task row once and reuse it: iPhone list, iPad list, and every widget size. Larger widgets add columns and rows; they do not stretch a two-line layout into empty gray.
5. Lead Dashboard and Intelligence with the session that needs the user, and demote the greeting to a single large-title line so the home screen is about the work.
