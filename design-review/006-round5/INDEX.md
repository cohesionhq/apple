# 006 — round 5

The core set (`../CORE.txt`) after round 5's changes, which are to the
widgets only: iPhone 18 Pro and iPad Pro 13-inch (landscape), iOS 27.2, light
mode. Only the widgets (50–56) were re-rendered; the rest are round 4's.

Note on toolbar tint: screens rendered from the screens package's own
previews (17, 26, 34, 44) tint toolbar glyphs with the accent, because a
package preview has to apply the app's accent with `.tint`. In the app, and
in the shots rendered through the app's shell (01–14, 13b–13d), toolbar
glyphs are the label colour. Don't count that difference as an
inconsistency in the app.

## Core set

Reviewers score the files in `../CORE.txt`: iPhone and iPad (landscape) in
light mode; dark mode and Dynamic Type are out of this pass's scope.

| File | Screen |
| --- | --- |
| 01-iphone-dashboard-light | Dashboard tab: greeting, composer, What's New |
| 02-iphone-intelligence-light | Intelligence tab: pinned agents grid, agents by team, actor sessions |
| 03-iphone-workspace-light | Workspace tab: pages, task lists, connectors |
| 04-iphone-feeds-light | Feeds tab |
| 05-iphone-agent-chat-light | Atlas's chat: a job run, Markdown reply, table, forwarded task |
| 06-iphone-actor-session-light | An actor session needing permission |
| 07-iphone-tasks-light | Inbox task list |
| 08-iphone-journal-light | Journal list |
| 10-iphone-documents-light | Documents list |
| 12-iphone-contact-light | A contact |
| 14-settings-light | Settings sheet |
| 17-agent-info-light | An agent's info sheet |
| 26-task-detail-light | A task's sheet |
| 34-article-light | The article reader |
| 44-extensions-light | Settings › Extensions |
| 13-ipad-split-view-light | iPad: sidebar beside the Dashboard |
| 13b-ipad-agent-chat-light | iPad: sidebar beside Atlas's chat |
| 13c-ipad-tasks-light | iPad: sidebar beside All tasks |
| 13d-ipad-actor-session-light | iPad: sidebar beside an actor session |
| 50-widget-agents-small-light | Agents widget, small: agents with unread messages |
| 51-widget-agents-medium-light | Agents widget, medium: the small's overlapping avatars, larger, with who needs you |
| 52-widget-agents-large-light | Agents widget, large: the avatars larger still, then what each agent is doing |
| 53-widget-tasks-small-light | Tasks widget, small: a task view (Today) |
| 54-widget-tasks-medium-light | Tasks widget, medium |
| 55-widget-tasks-large-light | Tasks widget, large |
| 56-widget-tasks-extralarge-light | Tasks widget, extra large (iPad only) |
| 57-live-activity-lockscreen-light | Live Activity on the Lock Screen: actor sessions at work |
| 58-live-activity-expanded-light | Live Activity, Dynamic Island expanded |
| 59-live-activity-compact-light | Live Activity, Dynamic Island compact |
