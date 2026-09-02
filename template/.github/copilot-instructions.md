# Copilot instructions — Cortex instance `{{INSTANCE_NAME}}`

This repository is a Cortex instance: a plaintext Markdown knowledge base for
`{{OWNER}}`, profile `{{PROFILE}}`. Read `AGENTS.md` before making any changes —
it defines roles, the capture/organize split, and the git-as-snapshot policy in
full detail. This file is a short operational summary.

## Before writing anything

1. Determine your role for this task: Reader, Curator, Librarian, or Archivist
   (see `AGENTS.md`). If unclear, act as a Reader and ask.
2. Check the current branch. Canonical writes only happen on `main`. If you're
   on any other branch (e.g. a worktree session created its own branch), stop
   and tell the user to reopen this instance in a mode that checks out `main`
   directly — do not write notes to a separate branch and do not merge/rebase
   automatically. See "Avoiding stray branches" in `AGENTS.md`.
3. Never invent new frontmatter fields — check `_meta/schemas/` first.
4. Use existing note IDs and links; do not duplicate an entity that already has
   a note (search `40-people/`, `10-projects/`, etc. first).

## When the user gives you something to capture

This is the default, and it should require zero organizational decisions from
the user:

1. Run `_meta/scripts/capture.ps1 -Content "..." -Source "..."`. Do not ask the
   user for a type, folder, or tags first — that decision is deferred to the
   Librarian's periodic pass, not made at capture time.
2. Exception: if the user gives explicit filing instructions ("file this under
   project X", "tag this as Y"), act as Curator immediately and use
   `_meta/scripts/new-note.ps1` instead of the inbox.
3. If the user supplied long freeform text, a transcript, or a separate source
   document they want preserved as-is, keep it as given rather than folding it
   into a summary (see "Primary intake path" in `AGENTS.md`).
4. Run `_meta/scripts/snapshot.ps1` before considering the task done. It
   auto-generates its own commit message — do not ask the user for one.

## When acting as Librarian (periodic triage, not user-requested)

Only relevant when explicitly invoked as Librarian — by a scheduled workflow,
a session automation, or a user asking for a "cleanup"/"reorg" pass. Follow the
full process in `AGENTS.md` under "Librarian": list unfiled inbox entries with
`_meta/scripts/librarian-list-inbox.ps1`, file each one with `new-note.ps1` (or
merge into an existing note), archive the raw entry with
`_meta/scripts/librarian-archive-inbox-entry.ps1`, validate, then snapshot with
`-Reason "librarian reorg"`.

## When the user asks to back up or restore

Act as the Archivist. Use `_meta/scripts/backup.ps1` to snapshot, or
`_meta/scripts/restore.ps1` to recover a prior snapshot. Always confirm with
the user before restoring, since it can overwrite uncommitted changes.

## When answering questions

- Cite the note's `id` and relative path, e.g. `project-arbiter
  (10-projects/project-arbiter/index.md)`.
- If information is not found, say so explicitly rather than inferring it.
- Prefer the derived index (`_meta/index.json`) for fast lookups if present and
  up to date; fall back to direct search otherwise.

## Scope

This instance's content is classified per `_meta/config.json`. Do not copy its
content into the `cortex-core` repository, into another instance, or into any
external system not already approved for this classification.
