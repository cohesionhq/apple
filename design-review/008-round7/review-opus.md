## Scores

| Category | Score | One-line reason |
| --- | --- | --- |
| Native | 8.0 | Glass toolbars, a floating tab bar, inset-grouped lists, sheets and a sidebar are all standard. The weak spots are the hairline under the chat headers, content showing through the bars, and a mix of title styles. |
| Typography | 7.4 | A sound scale and a genuinely good serif reader. Let down by tiny tertiary captions in chat, mismatched mono sizes, a two-line greeting and the stacked "48K / tokens". |
| Hierarchy | 7.2 | The Dashboard composer and the permission card lead well. Widgets, the agent info sheet and the iPad task metadata are flat, or point the eye at the wrong thing. |
| Spacing & density | 7.2 | Phone lists have a good rhythm. Widgets waste half their area, iPad card widths vary inside one column, and the Live Activity's bar doesn't line up with its rows. |
| Color & contrast | 7.3 | The indigo accent is restrained, but orange and red also mean priority, the badge is red for "needs you", and selected sidebar rows erase the orange. |
| Iconography | 7.0 | Mostly one SF Symbols family. Problems: grey letter tiles for extensions, the bolt meaning two things, an odd "All Feeds" glyph, a ruler-like size glyph, sync arrows for "working", and filled and outline mixed in the tab bar. |
| Consistency & polish | 6.9 | Four title treatments, a different task list on iPhone and iPad, a different greeting per device, and a widget that contradicts itself. |
| Overall | 7.3 | Clearly designed and mostly native. Not yet finished enough that every screen reads as one system. |

## Problems

1. **52-widget-agents-large-light**: the header says "Ada, Milo, and Juno need you", but Ada's row says "Reading 12 of 40 sources", so the widget contradicts itself. The "Needs you" rows are also plain grey, with no orange. **Fix:** count only agents that are really waiting. Show working agents in a separate "Working" group. Render "Needs you" in orange with the `hand.raised.fill` mark the app uses everywhere else.
2. **13d-ipad-actor-session-light, 13-ipad-split-view-light**: the selected actor row in the sidebar turns indigo and its "Needs you" turns white. The most urgent state in the app loses its colour exactly when it's selected. **Fix:** keep a small orange hand badge (white disc, orange glyph) on selected rows, or use the tinted (not filled) sidebar selection style so the orange survives.
3. **01, 02, 04, 07, 08, 10, 12 (tab bar)**: the Intelligence badge is the system red "1", but what it counts is an orange "needs you" item. Red means failed everywhere else. **Fix:** tint the badge orange (`.badgeProminence` or a custom orange badge), or keep red only for failures.
4. **07-iphone-tasks-light, 13c-ipad-tasks-light, 26-task-detail-light, 54–56 (widgets)**: priority flags use orange (high) and red (urgent), the same colours as "needs you" and "failed". Medium and low are two near-identical greys. **Fix:** draw priority with weight and shape rather than the status colours: `flag.fill` in label colour for urgent and high (plus "!!"/"!" or a count), and `flag` outline in secondary for medium and low. Keep red only for overdue dates.
5. **Title styles across 02, 03, 07, 08, 10, 14, 44**: four treatments in one app.
   - Large title: Intelligence, Feeds, Extensions.
   - Centred inline: Journal, Documents, Settings.
   - Leading inline next to the back button: Inbox.
   - Centred menu: Workspace "Studio ⌄".

   The Settings sheet's root is inline but its child (Extensions) is large, the reverse of iOS Settings.

   **Fix:** tab roots get large titles; pushed screens get centred inline titles; the workspace switcher becomes a large-title menu on Workspace. Make Settings root large and Extensions inline.
6. **51-widget-agents-medium-light, 50-widget-agents-small-light**: the medium widget's avatars are the same size as the small's, which leaves the right 55% empty. One sentence of grey text is all it adds. Neither widget uses orange for its one message, "needs you". **Fix:**
   - Medium: avatar stack and an orange count on the left, then up to three rows on the right (name plus what each agent needs).
   - Small: make "3" orange, or put an orange hand above "need you".
7. **52-widget-agents-large-light**: the 150-pt avatar stack takes the top third and the bottom quarter is empty. **Fix:** cut the stack to the medium's size, align the headline to it, and give the space to up to five agent rows, separated by inset hairlines.
8. **05-iphone-agent-chat-light, 13b-ipad-agent-chat-light**: the floating composer sits over the table with too little blur, so "Record demo video 2026-11-12 You" reads through "Message Atlas". On iPad, the transcript reads through the header ("Raise the middle card less…" behind the "Atlas" pill). **Fix:**
   - Use the system scroll-edge effect (`.scrollEdgeEffectStyle(.soft)` top and bottom) instead of the hairline divider.
   - Add bottom content inset equal to the composer height.
9. **06-iphone-actor-session-light, 13d-ipad-actor-session-light**: the top tool row ("Write Tests/CohesionCoreTests/BackoffTests.swift ✓ 2s") is cut in half by the header hairline. The iPad diff shows through behind the title. **Fix:** same as item 8, remove the hairline and rely on the scroll-edge effect so content blurs under the title.
10. **06-iphone-actor-session-light, 34-article-light, 05-iphone-agent-chat-light**: code blocks clip hard at the right edge ("-> Dura", "isn't"), with no fade or scroll cue. On 05 the table's last column ("Owner") touches the screen edge. **Fix:** a horizontal ScrollView with a trailing gradient fade inside the block, and the same 16-pt inset on tables as on body text.
11. **17-agent-info-light, 05-iphone-agent-chat-light**: the bolt means "Cue fired" in chat (indigo bolt) but "Runs" in the agent sheet, where Cues is an alarm clock. **Fix:** one symbol per concept. Use the alarm (or `bolt.badge.clock`) for the cue row in chat, and keep the bolt for runs.
12. **44-extensions-light**: every extension is a grey gradient squircle with a letter. They look like disabled placeholders, and GitHub and Linear have well-known marks. **Fix:** use the extension's own icon when it ships one; otherwise use a symbol per kind (`arrow.down.doc` for importers, `bell.badge` for push) on a coloured squircle, matching Settings' tiles. Move "v4" into the subtitle ("v4 · Imports issues…") so the top-right corner isn't a stray caption.
13. **13c-ipad-tasks-light vs 07-iphone-tasks-light**: on iPhone the list is inset-grouped cards; on iPad it's plain rows. On iPad the toolbar sits at the far right edge, detached from the 700-pt centred column. The folder name ("Launch", "Product") is plain grey and looks like another tag. **Fix:**
   - Use the same list style on both.
   - On iPad, either drop the max-width or add a column (Due / Assignee / Size) so the width earns its place.
   - Give folders a `folder` glyph, and tags an indigo-tinted `#`.
14. **07, 13c (task metadata)**: the size glyph (a flat ruler-like rectangle beside "Tiny") reads as a battery or a placeholder. The calendar glyph is a dotted grid at caption size. Every metadata item is the same grey. **Fix:**
   - Use a clearer size mark: S/M/L/XL text in a small rounded badge, or `gauge.with.dots.needle`.
   - Use `calendar` at `.caption` with `.imageScale(.small)`.
   - Keep the assignee avatar but drop "You" when the assignee is the user.
15. **01-iphone-dashboard-light vs 13-ipad-split-view-light**: the same moment reads "Good morning, Jackson Zamorano" on iPhone and "Let's get going, Jackson Zamorano" on iPad. On iPhone the greeting wraps to two 34-pt lines and pushes What's New below the fold. **Fix:** one greeting rule on both devices, using the first name only ("Good morning, Jackson") so it fits on one line at .largeTitle.
16. **01-iphone-dashboard-light, 13-ipad-split-view-light**: in "Needs you · 2m ago" and "Failed · 1h ago" the timestamp is coloured too. **Fix:** colour only the status word, and put "· 2m ago" in secondary. The "Done" row's grey outline check should be a green `checkmark.circle.fill` (or the secondary grey filled), so completed reads as a state rather than a disabled control.
17. **13-ipad-split-view-light**: the Working row ("Polish the iPad sidebar spacing") has a dotted empty circle and tertiary-grey title, so it looks disabled rather than alive. **Fix:** use an indigo `ProgressView` (or the Live Activity's working symbol) and label-colour text, with "Working · now" in secondary.
18. **13b-ipad-agent-chat-light**: once answered, the poll card turns every option grey on grey, including the chosen one. Captions like "Noted: Demo recording…" and "Context rebuilt because…" are caption2 tertiary, below comfortable legibility. **Fix:**
    - Keep the chosen option in label colour with an indigo check, and dim only the others.
    - Set the system notes in `.footnote` secondary.
19. **17-agent-info-light**: "Context 48K / tokens" stacks a value over a tiny tertiary unit, and the sheet has no primary action. **Fix:**
    - Show "48K of 200K tokens" in one line, with a thin capacity gauge.
    - Add a prominent "Message" button (or Pin/Unpin) under the description, as Contacts does.
20. **26-task-detail-light**: "Set Size" is indigo while every other value is grey with up/down chevrons. Tags has a chevron but no value. The JZ avatar touches "You". The confirm button is a grey-filled check that reads as disabled. Notes appear read-only, with a separate "Edit Notes" row. **Fix:**
    - Show "None" in secondary with the same chevrons for Size, and show the tag count for Tags.
    - Add 6 pt between avatar and name.
    - Use `.glassProminent` indigo for the check when there are changes.
    - Make the notes text itself the editor.
21. **57-live-activity-lockscreen-light, 58-live-activity-expanded-light**: the working symbol, `arrow.triangle.2.circlepath`, reads as "sync/refresh". On 58 the progress bar starts about 10 pt right of the icon column, and the logo sits outside both. **Fix:** use the app's working indicator (a small indigo spinner, or `ellipsis` with a variable-colour animation), and align bar, icons and logo to one leading edge.
22. **04-iphone-feeds-light**: "All Feeds" uses a jar or trash-can-like stack glyph. The tab root is just five rows over a blank screen. **Fix:**
    - Use `tray.full` (consistent with "All" in Workspace) or `square.stack`.
    - Consider a major shift: make the Feeds tab a unified, newest-first article timeline (title, source, excerpt, unread dot), and move the feed list into a filter menu. A tab should have content.
23. **55 vs 54 vs 56 (Tasks widgets)**: the large widget puts the date under the title; medium and extra large put it trailing. On large this gives uneven row heights. The extra large spends 1,400 px on one column with dates 1,000 px away from their titles. **Fix:**
    - Trailing dates on every size.
    - On extra large, two columns (Overdue | Today), or add the folder and assignee.
24. **12-iphone-contact-light**: the name is .title2 under a 160-pt avatar, which reads small. The quick actions are bare tinted glyphs, where iOS 26/27 Contacts uses glass capsule buttons. "Add Email…" and "Add Phone…" sit in the same card as real data. **Fix:**
    - Set the name in .largeTitle bold.
    - Put the four actions in equal-width `.glass` buttons.
    - Move the add rows into their own section, or into an Edit mode.
25. **02-iphone-intelligence-light, 13 sidebar**: Scout's pinned avatar is fully saturated green while its label is greyed. Offline is shown only by grey text, and a green disc also suggests "connected". In the sidebar, "New Agent" is a label-colour row while "Teams" is indigo. **Fix:** desaturate (or reduce opacity on) offline avatars and add an "Offline" subtitle. Style New Agent and Teams the same.

## What works

- The permission card (06, 13d): orange outline, hand mark, a question as the headline, the command in mono, then one prominent Allow. It's the clearest "needs you" moment in the app; keep it as the pattern for every approval.
- The article reader (34): the serif display and body, a generous measure and a quiet byline give the app real personality without leaving iOS.
- The Dashboard composer with the agent picker (01, 13): one obvious primary action, and it feels like the product's own surface rather than a generic list.
- The chat's mixed content (05, 13b): unbubbled assistant prose, indigo user bubbles, tool steps as quiet grey rows and Markdown tables and checklists read like a refined native transcript.
- Settings and the agent sheet (14, 17) use iOS-style coloured squircles and inset-grouped cards, which feel instantly at home.

## To reach 9+

1. **Lock down the colour semantics.** Orange only for "needs you", red only for failed and overdue, green only for connected and done. Move task priority off orange and red, make the tab badge orange, keep orange visible on selected sidebar rows, and make every "needs you" in widgets orange.
2. **One title and chrome system.** Large titles on tab roots, centred inline titles on pushed screens, and the system scroll-edge effect instead of hairlines everywhere. No content should collide with headers, composers or the tab bar (05, 06, 12, 13b, 13d).
3. **Rebuild the Agents widgets around content, not avatars.** Correct counts, orange status, agents listed with what they need on medium and large, and avatars sized as a supporting element. Give the Tasks widget sizes one row layout and a two-column extra large.
4. **An icon audit.** One symbol per concept (cue vs run, working vs sync, All vs All Feeds), real or symbolic extension icons instead of grey letters, a legible size mark, and filled tab icons throughout (Feeds is outline).
5. **Make iPad layouts earn their width.** On iPad: tasks in a list or table style that uses the width (or matches iPhone's cards), a Dashboard that puts What's New beside Working and Today, card widths consistent within the chat column, and toolbars attached to the content column.
