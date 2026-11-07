---
name: finish-task
description: Wrap up work in this repo. Check the dirty checkout, commit only your own files on master, update the docs your change made wrong, and write the final report in the standard format. Use whenever a task in this repo is implemented and verified, when asked to commit or push, or when the checkout has uncommitted changes that aren't yours.
---

# Finish a task

Run the `verify-change` skill first. A task whose build fails isn't done:
fix it, or leave it uncommitted and say why in the report.

## 1. Read the checkout

```sh
git status --short
git diff --stat
```

The main checkout may hold someone else's uncommitted work, or another
agent's. **Never stash, revert, reset, checkout or commit a path you
didn't change.** If one of your files also has someone else's edits in it,
don't commit that file: leave it, and say so under caveats in the report.

Work on `master` in this checkout. Don't create a branch or worktree unless
the task needs isolation.

## 2. Update what your change made wrong

Keeping the docs true is part of the task (`CLAUDE.md`, "Keep the docs
true"). Fix these in the same commit when the change makes them inaccurate:

- `ARCHITECTURE.md`: targets, flows, file locations.
- `CLAUDE.md`: principles and conventions.
- `docs/design.md`, `docs/platform-integrations.md`,
  `docs/parity-with-web.md`: the rules and the wiring they describe.
- `.claude/skills/*`: commands, the known-warnings list, the add-feature
  checklist.

Then check the change against the product direction
(`docs/product-direction.md`):

- Which parity rows (`docs/parity-with-web.md`) change, and to what
  (Yes, Partial, No, n/a)?
- Does it add, remove or change something the apps offer, or contradict a
  rule in `docs/product-direction.md`?
- Did you find a doc that disagrees with the code and leave it?

Each yes goes in the report under **Product direction** or **Caveats**.
The maintainers update the product direction from your report.

## 3. Commit

List your paths explicitly. `--only` commits exactly those paths and leaves
anything else that is staged alone:

```sh
git add <new files>          # new files must be added first
git commit --only <path> <path> -F - <<'EOF'
feat: the agent chat shows when the agent last replied

What changed and why, wrapped at about 72 columns. Write it for
someone reading the log, not as a list of edits.
EOF
```

- **Subject**: `feat:` / `fix:` / `docs:` / `chore:`, with no scope, then a
  lowercase sentence about what the user sees (see `git log --oneline`).
- **Body**: a short why, then any trailer the session asks for.
- Use one commit per task; split only parts that stand on their own.
- Never `git add -A` or `git add .`, and never amend or force-push.

## 4. Push

Push only when asked. If a push is rejected because the remote moved,
`git pull --rebase` is safe only when `git status` shows no uncommitted
changes. With a dirty tree, don't rebase: report that the commit is local
and unpushed.

Never deploy: no archive, TestFlight, App Store Connect, or a change to
signing or provisioning.

## 5. Report

Keep it brief. Use these headings and leave out any that are empty:

```markdown
**What changed**: one to three sentences, user-visible first.
**Commits**: `abc1234` feat: …
**Checks**: Cohesion scheme build ✅, no new warnings. Not covered: …
**Choices made without asking**: each design or copy call, and the alternative.
**Product direction**: parity rows that change (row → new status), anything else the Goal, Area, Surface or Parity documents should now say.
**Caveats**: anything left undone, files skipped because they were dirty, a daemon change needed (cohesionhq/cohesion), docs that disagree with the code.
**Check manually**: what to look at on a device, and where (screen, iPhone or iPad, light or dark).
```

Choices and manual checks are the parts read first. Be specific:
"Clients › a revoked client: the Revoke button is now red" is useful; "check
the UI" is not.
