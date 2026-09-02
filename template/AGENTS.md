# AGENTS.md — Cortex Instance `{{INSTANCE_NAME}}`

This file defines how AI agents are permitted to read and write this repository.
It applies to every agent, tool, or automation acting on this instance, regardless
of which host or product is invoking them.

## Design intent

This instance exists so that capturing something costs nothing to think about,
and organizing things is a separate, periodic, agent-driven activity - not
something a human does at write time. Two consequences follow:

- **Capture is a dumb, fast, zero-decision write.** The user (or an agent
  wrapping up a chat/task on their behalf) never chooses a folder, type, or
  tag. Everything lands in `00-inbox/` via `_meta/scripts/capture.ps1`.
- **Organization is a separate, periodic pass**, not something that has to
  happen inline with capture. See "Librarian" below. Content changes (editing
  what a note says) should be rare; re-filing, re-tagging, merging, and
  restructuring should be the common kind of write this instance sees.

## Primary intake path

1. Any freeform input - a prompt, a chat wrap-up, a forwarded email, a pasted
   document, a personal note - is captured with
   `_meta/scripts/capture.ps1 -Content "..." -Source "..."`. This is the only
   entry point a user should need day to day, from a GitHub Copilot chat, not a
   shell. It timestamps the content and records where it came from; nothing
   else.
2. If the user gives explicit filing instructions ("file this under project
   Arbiter", "tag this as urgent") act as **Curator** immediately and file it
   directly with `_meta/scripts/new-note.ps1` instead of dropping it in the
   inbox. Explicit instructions always take priority over the default
   inbox-first path.
3. Otherwise, leave it in `00-inbox/` for the **Librarian** pass to triage
   later. Do not block the user's capture on deciding organization.
4. When a user has their own freeform text, or wants to preserve a separate
   source document (e.g. pasted meeting transcript, a long clipboard of notes,
   an external document) rather than have it rewritten into a note body, that
   material is saved as a **separate reference file** next to the note it
   supports (once filed), and the note links to it. Convention:

   ```text
   50-meetings/
     meeting-20260901-weekly-sync.md
     meeting-20260901-weekly-sync.attachments/
       raw-transcript.md
   ```

   Agents must not silently absorb long freeform user text into frontmatter or
   rewrite it beyond what's needed for a note's summary - preserve the
   original as given.

## Roles

### Reader
- May search, summarize, correlate, and answer questions using any file in the
  repository.
- Must **never** create, edit, move, rename, or delete files.
- May propose changes as text/diffs for the user or the Curator/Librarian to
  apply.

### Curator (on-demand filing)
- Files content into the canonical folders (`10-projects` through
  `90-archive`, `assets/`) **when invoked explicitly** - either by direct user
  instruction, or as the mechanism the Librarian uses during its periodic pass.
- Curator is not the default path for routine capture anymore; see "Primary
  intake path" above. It exists for: (a) explicit user filing instructions,
  and (b) the Librarian's own filing actions.
- Uses `_meta/scripts/new-note.ps1` (or equivalent) to keep IDs, filenames, and
  frontmatter consistent.
- Must run `_meta/scripts/validate.ps1` after any batch of writes.

### Librarian (periodic, not user-triggered)
- The role responsible for turning `00-inbox/` entries and existing loosely
  organized notes into a well-structured instance: assigning types, IDs, tags,
  and folders; merging duplicate or related entries; fixing broken links;
  archiving stale content.
- **Runs on a schedule or on a triggering event (new capture, interval, etc.),
  not because the user asked for it in the moment.** In this app, that means a
  scheduled workflow (see "Scheduling the Librarian" below) or a session
  automation, not a chat-driven one-off.
- Process for each pass:
  1. List unfiled entries: `_meta/scripts/librarian-list-inbox.ps1`.
  2. For each entry, decide the right type/folder/tags/links (this reasoning
     step is the actual point of having an AI do this instead of a script),
     then file it as the Curator would (`new-note.ps1`, or append/merge into
     an existing note if one already covers the topic).
  3. Mark the original entry as filed and move it out of the active inbox:
     `_meta/scripts/librarian-archive-inbox-entry.ps1 -Path <entry> -FiledTo <note-id(s)>`.
  4. While already scanning the instance, look for other maintenance: stale
     `status: active` items that should be `done`/`archived`, duplicate or
     near-duplicate notes to merge, orphaned tags, broken links.
  5. Run `_meta/scripts/validate.ps1`.
  6. Run `_meta/scripts/snapshot.ps1 -Reason "librarian reorg"` to commit the
     whole pass as one atomic, revertible checkpoint.
- Must not delete a note's content outright when merging - fold the older
  note's content into the surviving note (or archive it under `90-archive/`)
  so nothing is silently lost.
- A single bad Librarian pass should always be recoverable with
  `git revert <commit>` against the snapshot it produced.

### Specialist
- Produces draft content (e.g. a generated meeting summary, a proposed project
  breakdown) and places it in `00-inbox/` for the Librarian to triage, same as
  ordinary capture.
- Must not write directly outside `00-inbox/`.

### Archivist (backup / restore)
- Invoked explicitly by the user, not run automatically in the background.
- Responsible for running `_meta/scripts/backup.ps1` (periodic or
  pre-risky-operation snapshot to the configured backup destination) and
  `_meta/scripts/restore.ps1` (recovering a prior snapshot on request).
- Must confirm with the user before restoring over the current working tree,
  since this can discard uncommitted or unbacked-up changes.
- Never deletes existing backups; `restore.ps1` is read-only against the
  backup destination.

### Validator (deterministic, non-AI)
- `_meta/scripts/validate.ps1`. Checks: required frontmatter fields present
  per `_meta/schemas/`, no duplicate `id` values, no broken internal Markdown
  links, and filenames match the `{type}-{slug}` convention.
- Should be run before and after any Curator or Librarian batch operation.

## Human approval required for

- Deleting any file outright (as opposed to moving it to `90-archive/`).
- Restructuring folders or renaming more than a few files at once, *outside*
  of a normal Librarian pass (a Librarian pass doing this routinely is
  expected and does not need per-run approval - that is its job).
- Adding content that may contain secrets, credentials, or data outside the
  classification allowed for this instance (see `_meta/config.json` →
  `classification`).
- Any write initiated by a Specialist that has not yet gone through the
  Librarian.

## Git policy: snapshots, not curated history

Git in this instance is a rollback mechanism, not a curated commit log. Content
edits should be rare; re-filing/reorganization by the Librarian should be the
common kind of write. Given that:

- Every capture and every Librarian pass ends with
  `_meta/scripts/snapshot.ps1`, which auto-generates its own commit message
  (batched, not one commit per file) - no one should have to think about
  commit messages for routine notes.
- Canonical content is committed to `main` only. There are no feature
  branches or pull requests for routine capture or Librarian passes.
  `snapshot.ps1` refuses to commit from any branch other than `main`.
- The main reason to keep any git history at all is so a bad Librarian pass
  (a bulk reorg that mis-files or merges things wrong) can be undone with
  `git revert` or by restoring an earlier snapshot, not to review a diff-based
  history the way a code repository would.

### Avoiding stray branches

`snapshot.ps1`'s main-only check can only refuse to commit from the wrong
place - it cannot make a host check the instance out on `main` in the first
place. If you open this instance as a **worktree** session (the default for
many agent hosts, including this app), the host creates a new branch and
leaves your primary `main` checkout untouched, so notes silently accumulate on
a throwaway branch instead of `main`.

**When opening a session against this instance, use a mode that operates
directly on the existing `main` checkout** (in this app: choose "branch" mode,
not "worktree" mode, when creating the session; or simply work in the
already-checked-out folder rather than spawning a new one). If an agent
detects it is on a non-`main` branch, it should stop and tell the user to
reopen the instance that way instead of trying to work around it (e.g. do not
merge/rebase automatically).

### Scheduling the Librarian

The Librarian pass should be automated, not something the user has to
remember to ask for. In this app, set up a scheduled workflow
(`save_workflow` with an `interval`, e.g. daily) targeting this instance's
project, with a prompt instructing the agent to act as Librarian per the
process above. See `_meta/scripts/README.md` for the exact prompt to use when
configuring this the first time in a new or existing instance.

## Conventions agents must follow

- **IDs**: `{type}-{slug}` for durable entities (e.g. `project-arbiter`,
  `area-team-operations`, `person-jane-smith`), `{type}-{yyyymmdd}-{slug}` for
  dated entities (e.g. `decision-20260901-storage`,
  `task-20260901-review-design`, `journal-20260901-chat-wrap-up`).
- **Frontmatter**: every note in `10-projects` through `80-journal` must
  include the fields defined in the matching `_meta/schemas/*.schema.json`
  file. Do not invent new top-level frontmatter fields without adding them to
  the schema first. `00-inbox/` and `90-archive/inbox/` entries use a
  lighter-weight `captured`/`source`/`status` frontmatter instead - they are
  raw captures, not notes, until the Librarian files them.
- **Links**: use repository-relative Markdown links
  (`[project-arbiter](../10-projects/project-arbiter/index.md)`), not absolute
  paths.
- **Media**: small durable media goes in `assets/`, referenced by relative
  link. Large or sensitive files are linked out to the sanctioned
  SharePoint/OneDrive library recorded in `_meta/config.json` →
  `mediaLibraryUrl` - do not link to ad hoc locations.
- **Stability**: do not rename or move a note's path once it has been
  referenced elsewhere unless updating all inbound links in the same commit.

## Classification

See `_meta/config.json` for this instance's `profile` (`work` / `personal`)
and `classification`. Agents must not copy content from this instance into
another instance, into the template repository, or into any external
system/tool not explicitly permitted for this classification.
