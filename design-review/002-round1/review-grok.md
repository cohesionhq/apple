## Scores

| Category | Score | One-line reason |
| --- | --- | --- |
| Native | 6.4 | Liquid Glass tab bar and toolbar clusters are right; nav bars, the actor chrome, and the iPad sidebar break the platform patterns around them. |
| Typography | 6.1 | The greeting and the article sit on a real scale; metadata, counts, code, and extension subtitles are too small or cut off. |
| Hierarchy | 5.7 | What’s New and Allow have a focal point; Workspace, tasks, and chat let chips, bubbles, and equal rows outrank the thing the screen is for. |
| Spacing & density | 5.4 | In-card rhythm is even; iPad detail is a phone column in a void, and floating bars cover the last row on several phone screens. |
| Color & contrast | 5.6 | The ground is calm and indigo reads as the accent; orange, red, green, and indigo each mean several different things, and the task list adds a second rainbow. |
| Iconography | 6.0 | One SF Symbol family, used at a consistent optical size; folders repeat, sidebar icons are all indigo, and several avatars fall back to a letter. |
| Consistency & polish | 4.9 | The same destination changes container, title, and selection between phone and pad; content clips the bar, Settings is cut off, and Size reads as a broken control. |
| Overall | 5.5 | A designer set the glass, the accent, and the article; the iPad, the actor session, and the color rules are not finished enough to ship. |

## Problems

1. **`13b-ipad-agent-chat-light.png`, `13d-ipad-actor-session-light.png`, `06-iphone-actor-session-light.png`.** The transcript scrolls through the navigation area. On the iPad chat, Atlas’s disc and name sit on top of the previous answer. On both actor screens, the inline title sits on the diff with no material behind it, so the first lines show through. Put a real inline bar behind that chrome (material background, bottom separator only while content is under it) and inset the scroll view so the first line clears the bar by 8pt.

2. **`01-iphone-dashboard-light.png`, `02-iphone-intelligence-light.png`, `03-iphone-workspace-light.png`, `05-iphone-agent-chat-light.png`, `12-iphone-contact-light.png`.** Floating chrome covers the last content. The dashboard row “Polish the iPad sidebar spacing” is under the tab bar, the chat table and “Want me to draft…” sit under the composer, and the contact notes run into the tab bar. Pad the scroll content by the bar height plus 16pt, and let the glass blur only that strip.

3. **`13-ipad-split-view-light.png`, `13b-ipad-agent-chat-light.png`, `13c-ipad-tasks-light.png`, `13d-ipad-actor-session-light.png`.** The sidebar is not finished. Settings is clipped by the bottom edge. Selection is a short indigo pill wrapped around the word Dashboard, and on chat, tasks, and the actor session no row is selected, so location lives only in a small centered title. Pin Settings above the home indicator. Use a full-width rounded selection, the shape Mail uses, and highlight the row that owns the detail on every one of these screens.

4. **`13-ipad-split-view-light.png`, `01-iphone-dashboard-light.png`.** The iPad dashboard is a narrow phone column centered in an empty canvas, with a redundant centered title “Dashboard”, and it greets with “Let’s get going” while the phone says “Fresh start”. Use one greeting string. Drop the centered “Dashboard” title. Split What’s New and Working into two columns inside one max-width container (about 900pt), sharing the composer’s horizontal inset, with the heading leading-aligned to that container.

5. **`06-iphone-actor-session-light.png`, `05-iphone-agent-chat-light.png`, `13d-ipad-actor-session-light.png`, `13b-ipad-agent-chat-light.png`.** The two transcripts do not share chrome. Chat hides the tab bar. The actor session keeps the tab bar, a follow-up field, and a red stop control, so the permission card is a long scroll away from the thumb. Hide the tab bar on both. On the actor screen, dock Allow, Allow for this session, and Deny in a bottom bar that stays put while the transcript scrolls. Show the follow-up field after the session is allowed to continue.

6. **`06-iphone-actor-session-light.png`, `13d-ipad-actor-session-light.png`.** “Allow for this session” uses the same gray fill as “Deny”, and “Deny and stop” is red text on that gray, so the second allow reads as a refusal. Keep a single filled indigo button for Allow. Draw Allow for this session as indigo text on a 15% indigo fill. Draw Deny as a plain secondary-label button. Draw Deny and stop as red text with no fill. Make “Add a note” a white field with a hairline and a `.subheadline` secondary placeholder, so it is clearly a field.

7. **`06-iphone-actor-session-light.png`, `13d-ipad-actor-session-light.png`.** Code is clipped at the card edge (`Dura`, `atte`) with no cue that it scrolls. Give the block horizontal scrolling, 16pt internal padding, 12pt monospaced text, and a `.caption` secondary language label above the first line. Keep the inline tokens (`.active`, `retryLimit`) in monospaced body on a secondary fill, dark enough to match the surrounding paragraph.

8. **`13c-ipad-tasks-light.png`, `07-iphone-tasks-light.png`.** The task title loses to the second line. Date, initials, a colored size chip (Tiny, Small, Large, Huge), tags, and the list name all sit at caption size, and a separate flag adds another hue. Set the title in `.body`. Set one `.subheadline` secondary line to the due date and the assignee. Keep priority as the flag only: secondary label, orange, or red. Move size and tags onto the task sheet.

9. **`01-iphone-dashboard-light.png`, `02-iphone-intelligence-light.png`, `03-iphone-workspace-light.png`, `13-ipad-split-view-light.png`, `13c-ipad-tasks-light.png`, `14-settings-light.png`, `17-agent-info-light.png`.** Color has too many jobs. Indigo is the selected tab, the link, the primary button, every Workspace and sidebar icon, the user bubble, and the value “Incomplete”. Orange is “needs you”, a flag, the Profile tile, and Ledger. Green is Scout, the connection dot, Live Activities, and the Small chip. Restrict indigo to selection, filled primary buttons, and text links. Draw navigation icons in label color, and use indigo only on the selected icon. Keep each agent’s color inside the avatar disc. Reserve orange for needs you, red for failed and destructive, and green for connected or succeeded.

10. **`01-iphone-dashboard-light.png`.** The composer, the Atlas chip, and Quick Journal are three equal actions, and the field is white on a near-white ground, so the greeting wins. Make the composer the only primary control: a white card, 44pt minimum, placeholder in `.body` secondary, send and attach at 22pt inside the field. Put the Atlas menu on the field’s leading edge. Place Quick Journal underneath as a leading `.subheadline` tinted text button.

11. **`05-iphone-agent-chat-light.png`, `13b-ipad-agent-chat-light.png`.** The indigo user bubble is the loudest object on the screen, so the answer looks like leftover body copy. Keep assistant text in `.body` on the background, with a max line length of about 68 characters (cap the iPad column near 640pt). Keep the user bubble at roughly 75% of that column. Render tool rows (“Checking this week’s tasks”, “2 steps”, “Cue … fired”) in one `.subheadline` secondary style. Replace the sun emoji with Atlas’s avatar, shown once above the first assistant paragraph.

12. **`05-iphone-agent-chat-light.png`.** The Task / Due / Owner table is a desktop fragment at phone width, already sliding under the composer. On iPhone, turn each row into a two-line inset row: title in `.body`, “Today · You” in `.subheadline` secondary. On iPad, keep the table, with `.caption` secondary headers, `.subheadline` cells, and a 44pt row height.

13. **`01-iphone-dashboard-light.png`, `02-iphone-intelligence-light.png`, `03-iphone-workspace-light.png`, `07-iphone-tasks-light.png`, `13c-ipad-tasks-light.png`, `13-ipad-split-view-light.png`.** List containers change by screen. What’s New is a full-bleed hairline list. Intelligence, Workspace, Feeds, and the iPhone inbox are white inset cards. iPad tasks go back to full-bleed. Use inset grouped cards for short menus (Workspace, Feeds, Settings, Agent info). Use full-bleed rows for anything you scan (tasks, What’s New, documents, journal). Use that same choice on phone and iPad.

14. **`01-iphone-dashboard-light.png`, `02-iphone-intelligence-light.png`, `03-iphone-workspace-light.png`, `04-iphone-feeds-light.png`, `07-iphone-tasks-light.png`, `13-ipad-split-view-light.png`, `13c-ipad-tasks-light.png`.** Titles follow no rule. Dashboard has a greeting and no nav title. Intelligence and Feeds have large titles. Workspace replaces the title with the small “Studio” menu. Pushed lists use a small centered title. iPad centers “Dashboard” and “All” in a wide pane. Give every phone root a large title, including “Workspace”, and move Studio to a toolbar menu. Use an inline title on pushed screens. On iPad, leading-align the detail title to the content column.

15. **`13-ipad-split-view-light.png`.** Two sidebar rows are both named “Issues”, with a gray G and a gray L, inside a column where pages, tasks, connectors, and feeds all have the same weight. Feeds stay expanded, which is what pushes Settings off the bottom. Label them “GitHub Issues” and “Linear Issues”. Use a monogram on a white disc with a hairline, at 28pt, so it is not gray on gray. Keep section headers in `.footnote` secondary with 20pt of space above, and leave Feeds collapsed until the disclosure is opened.

16. **`26-task-detail-light.png`.** The sheet is titled “Task”, the name sits in a second rounded field, and Size reads “None Set Size” as two adjacent buttons. The trailing check is a disabled gray circle, so save and dismiss are unclear. Title the sheet with the task name and drop the extra name field. Make Size one menu row, the value “None” in the same indigo `.body` treatment as Status and Folder. Show the indigo check only when there is something to save. Keep the glass X as dismiss.

17. **`14-settings-light.png`, `17-agent-info-light.png`, `26-task-detail-light.png`.** The filled indigo check means Done on Settings and Agent info, and Save on the task sheet. A check promises a commit. Use a glass X to close Settings and Agent info. Reserve the filled indigo check for sheets that save edits.

18. **`44-extensions-light.png`, `02-iphone-intelligence-light.png`, `08-iphone-journal-light.png`, `10-iphone-documents-light.png`, `03-iphone-workspace-light.png`.** The same nouns do not share a mark, and several subtitles are cut off in a half-empty screen. Journal and Documents rows are text and a chevron, while Workspace and the sidebar give those destinations indigo symbols. Extensions are five identical gray initials, with subtitles ellipsized at one line (“fro…”, “publis…”). Agents mix a symbol (Atlas’s compass, Quill’s nib) with a letter (Scout’s S, Relay’s R). Use a symbol on the agent’s color, and an initial only when there is no symbol. In menus, use a 20pt symbol in secondary label, then the title. Let extension subtitles wrap to two lines at `.subheadline` secondary, and set the version in `.caption` secondary beside the name.

19. **`01-iphone-dashboard-light.png`, `13-ipad-split-view-light.png`.** “What’s New 4” puts the count in the same size and color as the header, and the state line (“Needs you · 2m ago”, “Failed · 1h ago”) is caption-sized color, the smallest text carrying the most important fact. Set the header in `.headline`, the count in `.subheadline` secondary with a 6pt gap, and the state line in `.subheadline`: orange, red, or secondary.

20. **`02-iphone-intelligence-light.png`.** Teams is a blue icon and a blue label inside the agent card, while every agent row is a color disc plus a black name. It reads as a link that escaped the list. Draw it as a normal last row: secondary-label symbol, primary label, chevron, and a count in `.subheadline` secondary when there is one.

21. **`12-iphone-contact-light.png`.** The layout matches Contacts, then undermines it. The gray “MC” disc looks unfinished beside the colored agent discs, and “Add Email…” / “Add Phone…” appear under values that already exist, in the same indigo as the tappable address. Use a neutral filled disc with a white `.title2` initial. Move add actions into the trailing menu. Keep the address and phone in indigo `.body`, with `.caption` secondary labels.

22. **`04-iphone-feeds-light.png`, `03-iphone-workspace-light.png`, `17-agent-info-light.png`.** These screens are menus of equal rows and then a large empty region, so nothing is the main act. Give Workspace and Feeds their counts in `.subheadline` secondary, the way All Feeds already does. On Agent info, make the 48K context stat a real summary (value in `.title2`, unit in `.caption` secondary under it) and leave the five destinations as the quiet list beneath.

## What works

- The Liquid Glass tab bar and the separated circular toolbar buttons (gear, add, more, back, share) are the right iOS 27 chrome. Keep that cluster pattern.
- What’s New already has a readable state language: orange hand for needs you, red circled x for failed, gray check for done. Extend that trio anywhere a run can be in those states.
- The article reader (`34-article-light.png`) has a real title, a quiet byline, a comfortable measure, and headings that are obviously headings. That is the type standard for chat and the actor transcript.
- The contact screen’s structure — disc, four actions, grouped fields, notes — is properly native and should stay the template for people.
- Agent color living in the disc (Atlas’s blue compass, Quill’s purple nib) is the personality. Keep the color inside the disc.

## To reach 9+

1. **Finish the chrome, then give iPad a real canvas.** Material navigation bars that content cannot scroll through, scroll insets that clear the tab bar and the composer, a sidebar with a full-width selection and Settings pinned, and a dashboard that uses two columns instead of a floating phone column. This is the single largest lift for spacing, consistency, and native.

2. **One navigation and one list language.** Large titles on every phone root, Studio always in the toolbar, inline titles on pushes, leading-aligned iPad titles, inset cards only for short menus, full-bleed rows for data you scan, and the same choice on both devices. Chat and the actor session either both hide the tab bar or both keep it.

3. **A color contract with four meanings.** Indigo for selection, filled primary buttons, and links. Label color for navigation icons. Agent color only inside the disc. Orange, red, and green only for needs you, failed or destructive, and connected or succeeded. Size, tags, and settings tiles stop borrowing those hues.

4. **Make the primary object win on tasks and in chat.** Task title in `.body`, one `.subheadline` secondary line for due date and assignee, flag for priority, size and tags on the sheet. In chat, assistant prose at a capped measure, one quiet style for tool rows, and the user bubble no wider than about three quarters of the column. Phone tables become rows.

5. **Treat the actor session as a decision screen.** Sticky action bar, one filled Allow, a tinted session-allow, text-only denies, code that scrolls sideways at 12pt with padding, and a navigation bar that actually covers the transcript. The permission card is the product’s “needs you” moment, and it is the screen that most needs to look finished.
