# Design review prompt

The same prompt goes to every reviewer each round (a fresh Opus subagent,
Cursor's `agent` on Composer, and on Grok), with `<folder>` replaced by the
round's folder.

---

You are a senior iOS product designer reviewing Cohesion, a native SwiftUI
iPhone and iPad app (iOS 27, Liquid Glass) for a professional tool: a
workspace where AI agents and coding "actor sessions" work alongside the
user's tasks, journal, documents, contacts and feeds. The goal is an app that
feels fully native, with a few personality traits so it isn't just an iOS list
app, sharing the refined feel of the product's reworked web UI without copying
it. The brand accent is indigo; each agent has its own color; orange means
"needs you", red failed, green connected.

Review ONLY the core set of PNG screenshots in `<folder>`: the files named in
`design-review/CORE.txt` (add `.png`); `INDEX.md` in the folder says what each
shows. Don't take new screenshots and don't read the source code. Open and
look at every one of those images. They are iPhone and iPad (landscape) in
light mode; dark mode and Dynamic Type are out of scope for this pass.

The maintainers are open to major shifts, not just polish: if a screen's
layout, navigation or visual language should change substantially to feel
like a refined, designed iOS app, say so concretely.

Score each category from 1.0 to 10.0 (one decimal):

- **Native**: Liquid Glass usage, standard iOS design patterns.
- **Typography**: the type scale, weights, line length, and that every size
  is legible.
- **Hierarchy**: the eye lands on what matters; one main action per screen;
  titles, sections and metadata are distinct.
- **Spacing & density**: a consistent rhythm and grid, alignment, and density
  right for a professional tool.
- **Color & contrast**: a restrained palette, colour that means the same thing
  everywhere, legible contrast in both themes.
- **Iconography**: one icon family and weight, marks legible at their size,
  meaning clear.
- **Consistency & polish**: the same thing looks and behaves the same
  everywhere; edges, states and alignment are finished.
- **Overall**: would a professional believe a designer made it?

Reply in Markdown with exactly these sections:

1. `## Scores`: a table, one row per category, columns Category | Score |
   One-line reason.
2. `## Problems`: a numbered list, most important first, at least 15 items
   if you can find them. Each item: the screenshot file name(s), what is
   wrong, and the concrete fix (e.g. "use .subheadline secondary for the
   date, not .caption2 tertiary").
3. `## What works`: up to 5 bullets to keep.
4. `## To reach 9+`: the 5 changes that would raise the lowest scores most.

Be specific and critical; a 9 means you'd ship it as an Apple Design Award
finalist would. Don't inflate scores.
