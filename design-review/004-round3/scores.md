# Round 3 scores

Baseline through round 3 on the core set in `../CORE.txt`, each reviewer on
the same prompt (`../REVIEW-PROMPT.md`). From this round the core set also
holds the widgets at every size and the Live Activity (50–59), which the
earlier rounds didn't score; round 3's numbers judge the app *and* its
widgets, so they aren't strictly comparable with round 2's. Grok's round-3
review hadn't returned at commit time; it's added with round 4 if it does.

### Opus

| Category | Base | R1 | R2 | R3 |
|---|---|---|---|---|
| Native | 6.6 | 7.0 | 7.2 | 7.3 |
| Typography | 6.4 | 6.7 | 7.0 | 7.0 |
| Hierarchy | 5.5 | 6.2 | 6.6 | 6.5 |
| Spacing & density | 6.0 | 6.5 | 6.5 | 6.4 |
| Color & contrast | 5.8 | 6.3 | 6.8 | 6.3 |
| Iconography | 5.6 | 5.9 | 6.5 | 6.8 |
| Consistency & polish | 5.0 | 5.7 | 5.9 | 6.0 |
| Overall | 5.8 | 6.3 | 6.5 | 6.6 |

### Composer

| Category | Base | R1 | R2 | R3 |
|---|---|---|---|---|
| Native | 6.4 | 6.4 | 6.4 | 7.1 |
| Typography | 6.7 | 6.7 | 7.1 | 6.9 |
| Hierarchy | 6.1 | 6.1 | 6.3 | 6.4 |
| Spacing & density | 5.9 | 6.5 | 5.9 | 6.4 |
| Color & contrast | 6.0 | 6.0 | 7.0 | 7.0 |
| Iconography | 6.3 | 7.0 | 7.3 | 6.9 |
| Consistency & polish | 5.6 | 5.9 | 6.1 | 6.0 |
| Overall | 6.2 | 6.3 | 6.5 | 6.6 |

### Grok

| Category | Base | R1 | R2 | R3 |
|---|---|---|---|---|
| Native | 6.4 | 6.4 | 6.3 | missing |
| Typography | 5.8 | 6.1 | 6.0 | missing |
| Hierarchy | 5.3 | 5.7 | 5.4 | missing |
| Spacing & density | 5.2 | 5.4 | 5.5 | missing |
| Color & contrast | 5.4 | 5.6 | 6.1 | missing |
| Iconography | 6.5 | 6.0 | 6.4 | missing |
| Consistency & polish | 4.7 | 4.9 | 4.6 | missing |
| Overall | 5.5 | 5.5 | 5.5 | missing |

## What changed in round 3, and why

- **iPad sidebar**: Settings moves from a bottom bar that floated over the
  last rows (every reviewer saw it cover "Needs you") into the sidebar's bar,
  beside the overflow menu.
- **Tab bar on the iPhone actor session**: the screen hid it only when pushed
  after the tab bar controller existed; one shown at launch (a restored
  screen, a link, the preview) kept it. It now hides in `viewIsAppearing` too.
- **Transcript chrome**: chat and session get a hard top scroll edge, so
  text doesn't read through the header; the chat's pill is the agent's name
  alone (the role, always cut off, is on the info sheet).
- **Permission card**: an amber edge while it waits; its directory line at
  `.footnote`; a decision without a note is a centred line with a shield,
  not the user's indigo bubble.
- **Status colour**: a failed session's icon is filled and its words red, as
  needs-you is filled and amber.
- **Dashboard**: a bar with Settings, as every tab's first screen has; What's
  New titles wrap to two lines.
- **Small text**: transcript captions (sender, cue, actor's place) move from
  caption to footnote; inline code is set at the code block's size, smaller
  than the body rather than larger.
- **iPad width**: a task list keeps to the 680pt column, centred, as the
  Dashboard and chats do (`centeredColumn()`).
- **Task sheet**: the name in `.title3` semibold; menu values in secondary
  rather than the accent; Size is one "Set Size" control.
- **Widgets**: an Extra Large Tasks preview; the Agents previews lead with
  their fullest entry.

## Left for round 4

- Widgets: large and XL half empty; "Needs you" grey; overdue orange; the
  small Agents count counts every unread agent; Today's sun system blue.
- Selected sidebar row: orange words on the solid indigo pill.
- Working drawn three ways; Live Activity done in green.
- Permission card still grey-on-grey; title conventions; "add" placement;
  relative-time formats; task metadata styles.
