# Round 4 scores

Baseline through round 4 on the core set in `../CORE.txt` (iPhone, iPad
landscape, and from round 3 the widgets and Live Activity), each reviewer on
the same prompt (`../REVIEW-PROMPT.md`). Grok's round-3 and round-4 reviews
were still running (the CLI lost its connection and retried) at commit time;
they're added later if they return.

### Opus

| Category | Base | R1 | R2 | R3 | R4 |
|---|---|---|---|---|---|
| Native | 6.6 | 7.0 | 7.2 | 7.3 | 7.6 |
| Typography | 6.4 | 6.7 | 7.0 | 7.0 | 7.4 |
| Hierarchy | 5.5 | 6.2 | 6.6 | 6.5 | 7.0 |
| Spacing & density | 6.0 | 6.5 | 6.5 | 6.4 | 7.2 |
| Color & contrast | 5.8 | 6.3 | 6.8 | 6.3 | 6.9 |
| Iconography | 5.6 | 5.9 | 6.5 | 6.8 | 6.8 |
| Consistency & polish | 5.0 | 5.7 | 5.9 | 6.0 | 6.6 |
| Overall | 5.8 | 6.3 | 6.5 | 6.6 | 7.1 |

### Composer

| Category | Base | R1 | R2 | R3 | R4 |
|---|---|---|---|---|---|
| Native | 6.4 | 6.4 | 6.4 | 7.1 | 6.4 |
| Typography | 6.7 | 6.7 | 7.1 | 6.9 | 7.3 |
| Hierarchy | 6.1 | 6.1 | 6.3 | 6.4 | 6.6 |
| Spacing & density | 5.9 | 6.5 | 5.9 | 6.4 | 6.7 |
| Color & contrast | 6.0 | 6.0 | 7.0 | 7.0 | 7.1 |
| Iconography | 6.3 | 7.0 | 7.3 | 6.9 | 7.6 |
| Consistency & polish | 5.6 | 5.9 | 6.1 | 6.0 | 6.3 |
| Overall | 6.2 | 6.3 | 6.5 | 6.6 | 6.8 |

### Grok

| Category | Base | R1 | R2 | R3 | R4 |
|---|---|---|---|---|---|
| Native | 6.4 | 6.4 | 6.3 | missing | missing |
| Typography | 5.8 | 6.1 | 6.0 | missing | missing |
| Hierarchy | 5.3 | 5.7 | 5.4 | missing | missing |
| Spacing & density | 5.2 | 5.4 | 5.5 | missing | missing |
| Color & contrast | 5.4 | 5.6 | 6.1 | missing | missing |
| Iconography | 6.5 | 6.0 | 6.4 | missing | missing |
| Consistency & polish | 4.7 | 4.9 | 4.6 | missing | missing |
| Overall | 5.5 | 5.5 | 5.5 | missing | missing |

## What changed in round 4, and why

- **Widgets** (every reviewer scored them low in round 3): the Tasks
  widget's overdue dates are red, as the app's are, rather than orange, which
  means "needs you"; Extra Large is one list with its dates and flags in a
  column at the end, rather than two columns that didn't line up. The Agents
  widget's medium and large sizes have a heading with the count, as the Tasks
  widget does, and a large one's rows are roomier.
- **Selected sidebar row**: a session's status icon and words take the row's
  colour on the accent's fill, rather than amber or red on indigo.
- **Sheets with nothing to save** (Settings, an agent's info) close with
  `xmark`, rather than a checkmark that reads as saving (`docs/design.md`).
- **Dashboard**: the gap between the composer and What's New is smaller.

## Left for round 5

- Widgets in system blue rather than the indigo accent; the trailing date
  column ragged where a row has no flag; large sizes still half empty.
- Permission card on iPad narrower than the column; three greys inside it.
- Toolbar tint differing by screen; title placement by screen.
- Settings-style coloured tiles spending orange, red and green on decoration.
- Priority flags on the status palette (left open: the web colours them).
