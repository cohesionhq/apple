# Round 5 scores

Baseline through round 5 on the core set in `../CORE.txt` (iPhone, iPad
landscape, and from round 3 the widgets and Live Activity). Grok's round-3
review returned late and is in `../004-round3/`; its round-4 review was still
running at commit time, and round 5 wasn't sent to Grok so as not to stack a
third run on a CLI that kept losing its connection.

### Opus

| Category | Base | R1 | R2 | R3 | R4 | R5 |
|---|---|---|---|---|---|---|
| Native | 6.6 | 7.0 | 7.2 | 7.3 | 7.6 | 7.6 |
| Typography | 6.4 | 6.7 | 7.0 | 7.0 | 7.4 | 7.3 |
| Hierarchy | 5.5 | 6.2 | 6.6 | 6.5 | 7.0 | 6.9 |
| Spacing & density | 6.0 | 6.5 | 6.5 | 6.4 | 7.2 | 7.0 |
| Color & contrast | 5.8 | 6.3 | 6.8 | 6.3 | 6.9 | 7.2 |
| Iconography | 5.6 | 5.9 | 6.5 | 6.8 | 6.8 | 7.0 |
| Consistency & polish | 5.0 | 5.7 | 5.9 | 6.0 | 6.6 | 6.8 |
| Overall | 5.8 | 6.3 | 6.5 | 6.6 | 7.1 | 7.1 |

### Composer

| Category | Base | R1 | R2 | R3 | R4 | R5 |
|---|---|---|---|---|---|---|
| Native | 6.4 | 6.4 | 6.4 | 7.1 | 6.4 | 7.4 |
| Typography | 6.7 | 6.7 | 7.1 | 6.9 | 7.3 | 7.0 |
| Hierarchy | 6.1 | 6.1 | 6.3 | 6.4 | 6.6 | 6.7 |
| Spacing & density | 5.9 | 6.5 | 5.9 | 6.4 | 6.7 | 6.9 |
| Color & contrast | 6.0 | 6.0 | 7.0 | 7.0 | 7.1 | 7.5 |
| Iconography | 6.3 | 7.0 | 7.3 | 6.9 | 7.6 | 7.1 |
| Consistency & polish | 5.6 | 5.9 | 6.1 | 6.0 | 6.3 | 6.8 |
| Overall | 6.2 | 6.3 | 6.5 | 6.6 | 6.8 | 7.0 |

### Grok

| Category | Base | R1 | R2 | R3 | R4 | R5 |
|---|---|---|---|---|---|---|
| Native | 6.4 | 6.4 | 6.3 | 6.7 | missing | missing |
| Typography | 5.8 | 6.1 | 6.0 | 6.2 | missing | missing |
| Hierarchy | 5.3 | 5.7 | 5.4 | 5.6 | missing | missing |
| Spacing & density | 5.2 | 5.4 | 5.5 | 5.9 | missing | missing |
| Color & contrast | 5.4 | 5.6 | 6.1 | 5.3 | missing | missing |
| Iconography | 6.5 | 6.0 | 6.4 | 6.2 | missing | missing |
| Consistency & polish | 4.7 | 4.9 | 4.6 | 5.0 | missing | missing |
| Overall | 5.5 | 5.5 | 5.5 | 5.7 | missing | missing |

## What changed in round 5, and why

Widgets only.

- **Agents widget, medium and large**, at the maintainer's request: avatar-led
  like the small one. The agents' avatars overlap, larger than the small's
  (56pt medium, 96pt large), each a link to its chat, with "+N" past the
  slots; under them the count beside who needs the user ("Ada, Milo, and
  Juno need you."). The large adds what each agent is doing, up to three
  rows. After the shots, the small's words under its count became "need
  you", reading on from the number as the larger sizes do.
- **The accent**: `Color.accentColor` drew the system's blue in a widget, so
  the widgets read `AccentColor` from the asset catalog by name
  (`Color.widgetAccent`).
- **Tasks widget**: a row without a flag keeps the flag's room, so the dates
  line up down the list.

Both reviewers placed the round-4 toolbar-tint complaint on package previews
tinting their toolbars; `INDEX.md` now says so.

## Open, and why

- Opus would drop the large widget's facepile for a list; kept, as the
  maintainer asked for the avatar-led look. Its other notes (a ring between
  discs, orange for the count) are open.
- Priority flags in orange and red (the web colours them), the Live
  Activity's green "done", the full name in the greeting (as the web does),
  Settings' coloured tiles (the iOS Settings idiom), and the Dashboard's
  plain background stay as they are.
- Title placement per screen, task metadata grammar, the permission card's
  greys and width, and the scroll edge under custom headers recur in every
  review.
