# AGENTS.md — Cortex Instance `{{INSTANCE_NAME}}`

This file defines how AI agents are permitted to read and write this repository.
It applies to every agent, tool, or automation acting on this instance, regardless
of which host or product is invoking them.

## Primary intake path

The expected way to create a note is an **AI prompt**, not a script invoked directly
by the user. A user describes what happened or what they want captured; the Curator
(or a Specialist handing off to the Curator) decides the type, assigns an ID, fills
the frontmatter, and files it. `_meta/scripts/new-note.ps1` exists as the deterministic
mechanism agents use to do this consistently, and as a scriptable/testable entry point
— it is not the expected everyday interface for a human. A user should rarely need to
run it by hand; doing so directly is fine (e.g. for scripting or testing) but is the
exception, not the default workflow.

When a user has their own freeform text, or wants to preserve a separate source
document (e.g. pasted meeting transcript, a long clipboard of notes, an external
document) rather than have it rewritten into the note body, that material is saved
as a **separate reference file** next to the note it supports, and the note links to
it — the note itself stays a normalized, structured summary. Convention:

```text
50-meetings/
  meeting-20260901-weekly-sync.md
  meeting-20260901-weekly-sync.attachments/
    raw-transcript.md
```

The main note links to it with a relative Markdown link
(`[raw transcript](meeting-20260901-weekly-sync.attachments/raw-transcript.md)`).
Agents must not silently absorb long freeform user text into frontmatter or rewrite
it beyond what's needed for the note's summary — preserve the original as given.

## Roles

### Reader
- May search, summarize, correlate, and answer questions using any file in the
  repository.
- Must **never** create, edit, move, rename, or delete files.
- May propose changes as text/diffs for the user or the Curator to apply.

### Curator (the only default writer)
- The single role permitted to write to the canonical folders
  (`00-inbox` through `90-archive`, `assets/`).
- The primary way the Curator creates a note is by acting on an AI prompt from the
  user (see "Primary intake path" above), using `_meta/scripts/new-note.ps1` (or
  equivalent) to keep IDs, filenames, and frontmatter consistent.
- Responsible for: normalizing frontmatter, assigning stable IDs, filing notes into
  the correct folder, maintaining links between notes, saving user-supplied freeform
  text as a linked reference file rather than absorbing it into the note body, and
  keeping `_meta/index.json` (if present) in sync.
- Must run `_meta/scripts/validate.ps1` after any batch of writes and must not leave
  the repository in a state that fails validation.
- Must write in small, atomic commits with descriptive messages so a bad batch can be
  reverted with `git revert` without affecting unrelated notes.

### Specialist
- Produces draft content (e.g. a generated meeting summary, a proposed project
  breakdown) and places it in `00-inbox/` for the Curator to triage and file.
- Must not write directly outside `00-inbox/`.

### Archivist (backup / restore)
- Invoked explicitly by the user, not run automatically in the background.
- Responsible for running `_meta/scripts/backup.ps1` (periodic or pre-risky-operation
  snapshot to the configured backup destination) and
  `_meta/scripts/restore.ps1` (recovering a prior snapshot on request).
- Must confirm with the user before restoring over the current working tree, since
  this can discard uncommitted or unbacked-up changes.
- Never deletes existing backups; `restore.ps1` is read-only against the backup
  destination.

### Validator (deterministic, non-AI)
- `_meta/scripts/validate.ps1`. Checks: required frontmatter fields present per
  `_meta/schemas/`, no duplicate `id` values, no broken internal Markdown links, and
  filenames match the `{type}-{slug}` convention.
- Should be run before and after any agent-driven batch operation.

## Human approval required for

- Deleting any file outside `00-inbox/`.
- Restructuring folders or renaming more than a few files at once.
- Adding content that may contain secrets, credentials, or data outside the
  classification allowed for this instance (see `_meta/config.json` →
  `classification`).
- Any write initiated by a Specialist that the Curator has not yet triaged.

## Conventions agents must follow

- **IDs**: `{type}-{slug}` for durable entities (e.g. `project-arbiter`,
  `person-jane-smith`), `{type}-{yyyymmdd}-{slug}` for dated entities
  (e.g. `decision-20260901-storage`, `task-20260901-review-design`).
- **Frontmatter**: every note in `10-projects` through `80-journal` must include the
  fields defined in the matching `_meta/schemas/*.schema.json` file. Do not invent
  new top-level frontmatter fields without adding them to the schema first.
- **Links**: use repository-relative Markdown links
  (`[project-arbiter](../10-projects/project-arbiter/index.md)`), not absolute paths.
- **Media**: small durable media goes in `assets/`, referenced by relative link. Large
  or sensitive files are linked out to the sanctioned SharePoint/OneDrive library
  recorded in `_meta/config.json` → `mediaLibraryUrl` — do not link to ad hoc
  locations.
- **Stability**: do not rename or move a note's path once it has been referenced
  elsewhere unless updating all inbound links in the same commit.

## Classification

See `_meta/config.json` for this instance's `profile` (`work` / `personal`) and
`classification`. Agents must not copy content from this instance into another
instance, into the template repository, or into any external tool/service that is
not explicitly permitted for this classification.
