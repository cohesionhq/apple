# Round 6 scores

Baseline through round 6 on the core set in `../CORE.txt` (iPhone, iPad
landscape, the widgets and the Live Activity). Grok's round-5 and round-6
reviews were running at commit time and are added when they return.

### Opus

| Category | Base | R1 | R2 | R3 | R4 | R5 | R6 |
|---|---|---|---|---|---|---|---|
| Native | 6.6 | 7.0 | 7.2 | 7.3 | 7.6 | 7.6 | 7.6 |
| Typography | 6.4 | 6.7 | 7.0 | 7.0 | 7.4 | 7.3 | 7.5 |
| Hierarchy | 5.5 | 6.2 | 6.6 | 6.5 | 7.0 | 6.9 | 6.9 |
| Spacing & density | 6.0 | 6.5 | 6.5 | 6.4 | 7.2 | 7.0 | 7.1 |
| Color & contrast | 5.8 | 6.3 | 6.8 | 6.3 | 6.9 | 7.2 | 7.2 |
| Iconography | 5.6 | 5.9 | 6.5 | 6.8 | 6.8 | 7.0 | 7.3 |
| Consistency & polish | 5.0 | 5.7 | 5.9 | 6.0 | 6.6 | 6.8 | 6.9 |
| Overall | 5.8 | 6.3 | 6.5 | 6.6 | 7.1 | 7.1 | 7.2 |

### Composer

| Category | Base | R1 | R2 | R3 | R4 | R5 | R6 |
|---|---|---|---|---|---|---|---|
| Native | 6.4 | 6.4 | 6.4 | 7.1 | 6.4 | 7.4 | 7.3 |
| Typography | 6.7 | 6.7 | 7.1 | 6.9 | 7.3 | 7.0 | 7.1 |
| Hierarchy | 6.1 | 6.1 | 6.3 | 6.4 | 6.6 | 6.7 | 6.7 |
| Spacing & density | 5.9 | 6.5 | 5.9 | 6.4 | 6.7 | 6.9 | 6.4 |
| Color & contrast | 6.0 | 6.0 | 7.0 | 7.0 | 7.1 | 7.5 | 7.2 |
| Iconography | 6.3 | 7.0 | 7.3 | 6.9 | 7.6 | 7.1 | 6.6 |
| Consistency & polish | 5.6 | 5.9 | 6.1 | 6.0 | 6.3 | 6.8 | 6.5 |
| Overall | 6.2 | 6.3 | 6.5 | 6.6 | 6.8 | 7.0 | 6.8 |

### Grok

| Category | Base | R1 | R2 | R3 | R4 | R5 | R6 |
|---|---|---|---|---|---|---|---|
| Native | 6.4 | 6.4 | 6.3 | 6.7 | 6.3 | missing | missing |
| Typography | 5.8 | 6.1 | 6.0 | 6.2 | 5.8 | missing | missing |
| Hierarchy | 5.3 | 5.7 | 5.4 | 5.6 | 5.9 | missing | missing |
| Spacing & density | 5.2 | 5.4 | 5.5 | 5.9 | 5.4 | missing | missing |
| Color & contrast | 5.4 | 5.6 | 6.1 | 5.3 | 5.7 | missing | missing |
| Iconography | 6.5 | 6.0 | 6.4 | 6.2 | 6.4 | missing | missing |
| Consistency & polish | 4.7 | 4.9 | 4.6 | 5.0 | 5.0 | missing | missing |
| Overall | 5.5 | 5.5 | 5.5 | 5.7 | 5.6 | missing | missing |

## What changed in round 6, and why

- **Task rows**: the line under a title is plain grey words, no capsules:
  the due day (red once past), the assignee, the size after a ruler, tags as
  `#tag`, the list. Every reviewer counted five styles in that one line.
- **Permission card**: while it waits it's the page's background, edged in
  amber, rather than grey with grey wells and a grey Deny, which read as
  disabled; Deny and the menu are glass.
- **Widgets**: the system's background rather than a flat grey; each
  overlapping avatar has a ring of the background so the discs read apart;
  the Tasks previews hold nine tasks, as a real view does, rather than five.

Tried and reverted: Inbox's title sits at the leading edge where Journal's
is centred; dropping its empty "Edited" subtitle didn't move it, so the
three toolbar buttons beside it are the likelier cause, and it's left.

## Open

- Priority flags in orange and red (the web colours them).
- Settings at the top left of every tab; title styles per tab.
- The selected sidebar row's status colour: round 3's reviewers couldn't read
  amber on indigo, round 6's want it back.
- The greeting's full name, as the web has it.
