# Copilot instructions — Cortex instance `{{INSTANCE_NAME}}`

This repository is a Cortex instance: a plaintext Markdown knowledge base for
`{{OWNER}}`, profile `{{PROFILE}}`. Read `AGENTS.md` before making any changes — it
defines which role you are acting as and what you may write.

## Before writing anything

1. Determine your role for this task: Reader, Curator, Specialist, or Archivist (see
   `AGENTS.md`). If unclear, act as a Reader and ask.
2. If acting as Curator, run `_meta/scripts/validate.ps1` before and after your
   changes.
3. Never invent new frontmatter fields — check `_meta/schemas/` first.
4. Never write outside `00-inbox/` unless you are the Curator.
5. Use existing note IDs and links; do not duplicate an entity that already has a
   note (search `40-people/`, `10-projects/`, etc. first).

## When the user gives you information to capture

This is the primary way notes get created — the user describes something in a
prompt, not by running a script themselves. As the Curator:

1. Decide the note type and derive a title from what the user said.
2. Use `_meta/scripts/new-note.ps1` (or replicate its ID/filename/frontmatter
   conventions exactly) rather than freehanding a new file.
3. Summarize the user's input into the note body in the template's structure.
4. If the user supplied long freeform text, a transcript, or a separate source
   document they want preserved as-is, do **not** fold it verbatim into the note.
   Save it as a sibling file under `{note-filename-without-ext}.attachments/` and
   link to it from the note (see "Primary intake path" in `AGENTS.md`).
5. Run `_meta/scripts/validate.ps1` before considering the task done.

## When the user asks to back up or restore

Act as the Archivist. Use `_meta/scripts/backup.ps1` to snapshot, or
`_meta/scripts/restore.ps1` to recover a prior snapshot. Always confirm with the
user before restoring, since it can overwrite uncommitted changes.

## When answering questions

- Cite the note's `id` and relative path, e.g. `project-arbiter
  (10-projects/project-arbiter/index.md)`.
- If information is not found, say so explicitly rather than inferring it.
- Prefer the derived index (`_meta/index.json`) for fast lookups if present and
  up to date; fall back to direct search otherwise.

## When filing new content

- Assign an ID per the convention in `AGENTS.md`.
- Use the matching template in `_meta/templates/`.
- Place drafts in `00-inbox/` first if you are a Specialist agent; only the Curator
  files directly into the numbered folders.

## Scope

This instance's content is classified per `_meta/config.json`. Do not copy its
content into the `cortex-core` repository, into another instance, or into any
external system not already approved for this classification.
