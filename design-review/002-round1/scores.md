# Round 1 scores

Baseline (`001-baseline`) against round 1 (`002-round1`), on the core set in
`../CORE.txt`: iPhone and iPad (landscape), light mode. Each reviewer scored
the same prompt (`../REVIEW-PROMPT.md`); their reviews are beside these
images. Grok's round-1 review is **missing**: Cursor's CLI ran on Grok
(`grok-4.7-high`) and returned nothing, so it was recorded as missing rather
than waited on. Its baseline is the only Grok score.

| Category | Opus base | Opus R1 | Composer base | Composer R1 | Grok base | Grok R1 |
|---|---|---|---|---|---|---|
| Native | 6.6 | 7.0 (+0.4) | 6.4 | 6.4 (+0.0) | 6.4 | missing |
| Typography | 6.4 | 6.7 (+0.3) | 6.7 | 6.7 (+0.0) | 5.8 | missing |
| Hierarchy | 5.5 | 6.2 (+0.7) | 6.1 | 6.1 (+0.0) | 5.3 | missing |
| Spacing & density | 6.0 | 6.5 (+0.5) | 5.9 | 6.5 (+0.6) | 5.2 | missing |
| Color & contrast | 5.8 | 6.3 (+0.5) | 6.0 | 6.0 (+0.0) | 5.4 | missing |
| Iconography | 5.6 | 5.9 (+0.3) | 6.3 | 7.0 (+0.7) | 6.5 | missing |
| Consistency & polish | 5.0 | 5.7 (+0.7) | 5.6 | 5.9 (+0.3) | 4.7 | missing |
| Overall | 5.8 | 6.3 (+0.5) | 6.2 | 6.3 (+0.1) | 5.5 | missing |

## What changed in round 1, and why

- **Status colour has one meaning.** An actor session that needs the user has
  its status words amber wherever it's listed, not only on the Dashboard
  (reviewers saw orange in one place and grey in another).
- **Dashboard.** The greeting is leading-aligned at a large title's size with
  the day under it, as the web's Dashboard has it, instead of a centred 40pt
  heading over a dead gap. What's New and a new **Working** section are rows of
  one kind (a session's status icon in the slot an agent's avatar takes,
  "Needs you · 5m"), each heading carrying its count; the working sessions'
  capsule chips, which read as a garbled pill over the tab bar, are gone.
- **Intelligence** is titled large, as Feeds is, and its pinned agents are a
  four-across grid of smaller discs rather than two dominating ones.
- **Settings button** uses `gearshape`, the standard mark.
- **Journal** previews read as plain words (no `##` showing) and the entries
  are grouped under month headings, with "Yesterday" or "Saturday 7" as titles
  rather than a full date with the year on every row.
- **Chat.** Markdown task items (`- [x]`) draw as a ticked or empty circle
  instead of literal brackets; the conversation column is 680pt, a reading
  measure, rather than 760; the header's avatar sits above its name pill
  rather than over it; a fork's collapsed steps are a row on a faint fill, its
  bolt in the agent's colour, rather than near-invisible tertiary text.
- **Actor session.** A permission's decisions are an equal two-column grid,
  the allows over the denials, rather than four ragged pills; its cards share
  an agent card's grey and corners rather than a hairline stroke.
- **Contacts** without a photo show their initials white on grey, as the
  system's Contacts does, in the list and on their page; method labels are
  grey, not the button's tint.
- **Agent info** opens with the agent's avatar, name and role.
- **Extensions** rows are labels, so separators line up with the text; the
  version reads "v4"; an extension or connector without an icon gets a grey
  tile with a white initial, not a faint letter on grey.
- **Workspace tab** splits the task lists from the views of them (All, Done,
  Cancelled, saved views); All is `tray.2`, saved views a bookmark.

## Left for round 2 (what the reviewers still score low)

- iPad sidebar: agents and actor sessions sit below Feeds and Connectors, off
  screen, so every reviewer read them as missing; two connector rows both say
  "Issues".
- Conversation chrome: text runs under the header; the tab bar shows in actor
  sessions (in previews at least); the permission card has no clear first
  choice; a session's "Allowed for this session" reads as a user bubble.
- Colour meaning on task priority flags (indigo, orange, red) and size chips
  (a rainbow), which the web uses on purpose — a product call.
- Four icon languages side by side (Settings tiles, indigo outlines, letter
  tiles, emoji); mismatched status glyph shapes in What's New.
- Smaller: code blocks clip with no cue; the task sheet's title has no weight;
  the Feeds tab is mostly empty.
