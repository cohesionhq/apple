# Round 2 scores

Baseline, round 1 and round 2 on the core set in `../CORE.txt` (iPhone and
iPad landscape, light mode), each reviewer on the same prompt
(`../REVIEW-PROMPT.md`). Grok's round-1 review arrived after round 1 was
committed and is now in `../002-round1/review-grok.md`. Grok's round-2 review
returned after round 2 was committed and is added with round 3.

### Opus

| Category | Base | R1 | R2 |
|---|---|---|---|
| Native | 6.6 | 7.0 | 7.2 |
| Typography | 6.4 | 6.7 | 7.0 |
| Hierarchy | 5.5 | 6.2 | 6.6 |
| Spacing & density | 6.0 | 6.5 | 6.5 |
| Color & contrast | 5.8 | 6.3 | 6.8 |
| Iconography | 5.6 | 5.9 | 6.5 |
| Consistency & polish | 5.0 | 5.7 | 5.9 |
| Overall | 5.8 | 6.3 | 6.5 |

### Composer

| Category | Base | R1 | R2 |
|---|---|---|---|
| Native | 6.4 | 6.4 | 6.4 |
| Typography | 6.7 | 6.7 | 7.1 |
| Hierarchy | 6.1 | 6.1 | 6.3 |
| Spacing & density | 5.9 | 6.5 | 5.9 |
| Color & contrast | 6.0 | 6.0 | 7.0 |
| Iconography | 6.3 | 7.0 | 7.3 |
| Consistency & polish | 5.6 | 5.9 | 6.1 |
| Overall | 6.2 | 6.3 | 6.5 |

### Grok

| Category | Base | R1 | R2 |
|---|---|---|---|
| Native | 6.4 | 6.4 | 6.3 |
| Typography | 5.8 | 6.1 | 6.0 |
| Hierarchy | 5.3 | 5.7 | 5.4 |
| Spacing & density | 5.2 | 5.4 | 5.5 |
| Color & contrast | 5.4 | 5.6 | 6.1 |
| Iconography | 6.5 | 6.0 | 6.4 |
| Consistency & polish | 4.7 | 4.9 | 4.6 |
| Overall | 5.5 | 5.5 | 5.5 |

## What changed in round 2, and why

- **iPad sidebar order.** Agents and actor sessions come right after the task
  lists; connectors and Feeds move to the bottom, so no reviewer reads the
  agents as missing. A connector's row names its connector ("GitHub Issues",
  "Linear Issues") rather than two rows both saying "Issues".
- **Permission card.** One first choice: Allow is prominent, Deny bordered,
  and the rest (including Abort) sit in a `…` menu. The card's title carries
  the needs-you glyph in orange while it's open.
- **Actor session chrome.** The transcript gets a soft scroll-edge effect at
  top and bottom so text doesn't run under the header; the iPad title no
  longer truncates.
- **Colour meaning in tasks.** Priority flags leave the status palette (low
  tertiary, medium secondary); size chips are grey, not coloured; a due date
  says Today / Tomorrow / Yesterday and turns red only when overdue.
- **Icons.** Actor statuses use one family (`hand.raised.circle.fill`,
  `checkmark.circle`, `checkmark.circle.fill`); Agents in Settings is
  `sparkles`, Cues teal.
- **Dashboard** drops its empty navigation title on iPhone.

## Left for round 3 (what the reviewers still score low)

- iPad sidebar's floating Settings pill covers the last rows.
- Tab bar still shows on the iPhone actor session; chat and session headers
  float over content; "Allowed for this session" draws as a user bubble.
- Permission card still reads grey and disabled; Deny's fill.
- Title convention differs per screen (large, inline centred, inline leading,
  none).
- Small tertiary text in transcripts and cards; inline code bigger than body.
- iPad tasks span the whole width; Feeds and Inbox look sparse.
- Task sheet and contact values in indigo read as links.
