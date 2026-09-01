# Copilot instructions — Cortex instance `{{INSTANCE_NAME}}`

This repository is a Cortex instance: a plaintext Markdown knowledge base for
`{{OWNER}}`, profile `{{PROFILE}}`. Read `AGENTS.md` before making any changes — it
defines which role you are acting as and what you may write.

## Before writing anything

1. Determine your role for this task: Reader, Curator, or Specialist (see
   `AGENTS.md`). If unclear, act as a Reader and ask.
2. If acting as Curator, run `_meta/scripts/validate.ps1` before and after your
   changes.
3. Never invent new frontmatter fields — check `_meta/schemas/` first.
4. Never write outside `00-inbox/` unless you are the Curator.
5. Use existing note IDs and links; do not duplicate an entity that already has a
   note (search `40-people/`, `10-projects/`, etc. first).

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
