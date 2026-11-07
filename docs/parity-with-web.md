# Parity with the web UI

The web UI is the full surface; the apps match it on what makes sense
on mobile, as its mobile twin rather than a copy. The maintainers keep
the status list, one row per web feature (Yes, Partial, No, n/a); this
page says how to compare.

## Where the web's features are

In cohesionhq/cohesion (`../cohesion/web/` in a checkout beside this one):

| Look in | For |
| --- | --- |
| `src/routes/` | Every page. Workspace pages are under `w/[ws]/` (dashboard, today, tasks, journal, documents, articles, research, resources); the rest are top level (agents, actors, activities, threads, extensions, connectors, settings). |
| `src/lib/shell/routes.ts` | The route builders, one per page and deep link. |
| `src/lib/features/<area>/` | What each page does: dialogs, menus, forms. |
| `src/lib/features/settings/sections.ts` | The settings sections. |
| `src/lib/shell/Palette.svelte`, `shortcuts.svelte.ts`, `ShortcutsDialog.svelte` | The command palette and keyboard shortcuts. |
| `README.md` | Layout, styling and copy rules. |

The app's side is `Cohesion/Views/RootView.swift` (what's reachable) and
`CohesionScreens/<Area>/`. The daemon's commands
(`../cohesion/cohesion-core/src/protocol/*_requests.rs`) against
`CohesionCore`'s `Connection/Commands.swift` show what the app can't reach yet.

## Comparing one feature

1. Find the web page and its feature folder; list what a user can see and
   do there (lists, actions in menus, dialogs, settings).
2. Find the same in the app. Grep `Commands.swift` for the commands the
   web calls.
3. Decide the status: **Yes** when everything that makes sense on mobile
   is there, **Partial** when some is, **No** when none, **n/a** when the
   feature is deliberately web only.
4. Wording and placement may differ (iOS conventions, `docs/design.md`);
   what the user can do should not.

## When you change a surface

- Building or changing a feature here: report which rows change and to
  what (`finish-task`, **Product direction**). The maintainers update the
  list.
- Noticing the web has something the app doesn't: report it; don't build
  it unasked. A "No" row needs a decision with the maintainers, per screen.
- The app's native-only features (pushes, Live Activities, widgets, the
  share extension) have no web row.
