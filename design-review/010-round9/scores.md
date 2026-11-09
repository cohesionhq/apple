# Round 9 scores

Baseline through round 9 on the core set in `../CORE.txt` (iPhone, iPad
landscape, the widgets and the Live Activity). Grok's round-8 review came
back late and is beside it; its round-9 review was running at commit time.

### Opus

| Category | Base | R1 | R2 | R3 | R4 | R5 | R6 | R7 | R8 | R9 |
|---|---|---|---|---|---|---|---|---|---|---|
| Native | 6.6 | 7.0 | 7.2 | 7.3 | 7.6 | 7.6 | 7.6 | 8.0 | 7.6 | 7.8 |
| Typography | 6.4 | 6.7 | 7.0 | 7.0 | 7.4 | 7.3 | 7.5 | 7.4 | 7.3 | 7.4 |
| Hierarchy | 5.5 | 6.2 | 6.6 | 6.5 | 7.0 | 6.9 | 6.9 | 7.2 | 7.0 | 7.0 |
| Spacing & density | 6.0 | 6.5 | 6.5 | 6.4 | 7.2 | 7.0 | 7.1 | 7.2 | 7.0 | 7.1 |
| Color & contrast | 5.8 | 6.3 | 6.8 | 6.3 | 6.9 | 7.2 | 7.2 | 7.3 | 6.8 | 7.3 |
| Iconography | 5.6 | 5.9 | 6.5 | 6.8 | 6.8 | 7.0 | 7.3 | 7.0 | 6.9 | 7.0 |
| Consistency & polish | 5.0 | 5.7 | 5.9 | 6.0 | 6.6 | 6.8 | 6.9 | 6.9 | 6.7 | 6.8 |
| Overall | 5.8 | 6.3 | 6.5 | 6.6 | 7.1 | 7.1 | 7.2 | 7.3 | 7.1 | 7.2 |

### Composer

| Category | Base | R1 | R2 | R3 | R4 | R5 | R6 | R7 | R8 | R9 |
|---|---|---|---|---|---|---|---|---|---|---|
| Native | 6.4 | 6.4 | 6.4 | 7.1 | 6.4 | 7.4 | 7.3 | 7.0 | 7.3 | 6.7 |
| Typography | 6.7 | 6.7 | 7.1 | 6.9 | 7.3 | 7.0 | 7.1 | 7.3 | 7.4 | 7.0 |
| Hierarchy | 6.1 | 6.1 | 6.3 | 6.4 | 6.6 | 6.7 | 6.7 | 6.5 | 6.9 | 6.4 |
| Spacing & density | 5.9 | 6.5 | 5.9 | 6.4 | 6.7 | 6.9 | 6.4 | 6.2 | 7.1 | 6.2 |
| Color & contrast | 6.0 | 6.0 | 7.0 | 7.0 | 7.1 | 7.5 | 7.2 | 7.5 | 7.6 | 7.1 |
| Iconography | 6.3 | 7.0 | 7.3 | 6.9 | 7.6 | 7.1 | 6.6 | 6.8 | 7.0 | 6.6 |
| Consistency & polish | 5.6 | 5.9 | 6.1 | 6.0 | 6.3 | 6.8 | 6.5 | 6.4 | 6.6 | 6.1 |
| Overall | 6.2 | 6.3 | 6.5 | 6.6 | 6.8 | 7.0 | 6.8 | 6.9 | 7.2 | 6.5 |

### Grok

| Category | Base | R1 | R2 | R3 | R4 | R5 | R6 | R7 | R8 | R9 |
|---|---|---|---|---|---|---|---|---|---|---|
| Native | 6.4 | 6.4 | 6.3 | 6.7 | 6.3 | 7.5 | 7.0 | 7.3 | 7.3 | missing |
| Typography | 5.8 | 6.1 | 6.0 | 6.2 | 5.8 | 6.5 | 6.4 | 6.2 | 6.6 | missing |
| Hierarchy | 5.3 | 5.7 | 5.4 | 5.6 | 5.9 | 6.6 | 6.1 | 6.0 | 6.2 | missing |
| Spacing & density | 5.2 | 5.4 | 5.5 | 5.9 | 5.4 | 6.4 | 5.9 | 5.8 | 6.5 | missing |
| Color & contrast | 5.4 | 5.6 | 6.1 | 5.3 | 5.7 | 6.7 | 5.6 | 6.4 | 6.4 | missing |
| Iconography | 6.5 | 6.0 | 6.4 | 6.2 | 6.4 | 6.8 | 6.3 | 7.0 | 6.6 | missing |
| Consistency & polish | 4.7 | 4.9 | 4.6 | 5.0 | 5.0 | 6.1 | 5.5 | 5.7 | 6.0 | missing |
| Overall | 5.5 | 5.5 | 5.5 | 5.7 | 5.6 | 6.5 | 6.0 | 6.3 | 6.4 | missing |

## What changed in round 9, and why

- **Composers**: the chat's composer and the actor session's foot are
  `safeAreaBar`s rather than insets, so the transcript blurs out under their
  glass (the scroll edge effect) rather than reading through it, which every
  reviewer flagged in every round.
- **Agent info**: the context is "48K tokens" on one line, as a row's value
  is, rather than the count over a small "tokens" (the web's way).
- **Task sheet**: Tags says "None" when empty, as the rows around it do.

After this round's shots, at the maintainer's request (its own commit): the
permission card's Allow is prominent glass, matching the glass Deny and
menu; it no longer shows where a command runs; and its note appears only
once Deny is tapped.

## Open

- The agent chat's last reply showed below the composer in the iPhone shot,
  which may be the preview catching a scroll; to check on a device.
