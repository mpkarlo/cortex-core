# Cortex

A plaintext, Git-backed, AI-agent-driven personal knowledge base template. Cortex
provides durable long-term storage and reference for projects, tasks, people, decisions,
and reference material — designed to be read and maintained primarily through AI prompts
and agents, with a human-readable Markdown file as the ultimate source of truth.

This repository is the **template**, not an instance. It contains conventions, schemas,
scaffolding, and optional tools. Instances (e.g. `work-cortex`, `personal-cortex`) are
created by copying `template/` and are where actual content lives.

## Principles

1. **The Markdown files are the system.** No tool, script, index, or agent should be
   load-bearing. If everything else disappeared, the repo must still be fully usable
   in a plain text editor.
2. **Stable IDs, shallow paths.** Notes are identified by a stable `id`, not by their
   path. Paths should rarely change once created.
3. **Canonical vs. derived.** Frontmatter + Markdown content is canonical and committed.
   Indexes, embeddings, and caches are derived, rebuildable, and gitignored.
4. **One writer.** A single curator agent role normalizes and files content. Other
   agents propose; the curator commits. See `AGENTS.md`.
5. **Deterministic validation.** A dependency-free script checks schema compliance,
   duplicate IDs, and broken links — no AI required to catch structural errors.

## Structure

```
template/
  00-inbox/        unsorted capture, triaged by the curator agent
  10-projects/      active and past work/personal projects
  20-areas/         ongoing areas of responsibility (not time-bound)
  30-tasks/         standalone tasks not tied to a project
  40-people/        people notes (contacts, context, history)
  50-meetings/      meeting notes
  60-decisions/     decision records
  70-reference/     durable reference material
  80-journal/       dated journal / log entries
  90-archive/       retired content, kept for history
  assets/           small durable media committed to the repo
  _meta/
    templates/      note templates for each type
    schemas/        frontmatter field definitions (JSON)
    scripts/        validate.ps1, new-note.ps1, backup.ps1
    ui/             reserved for a future local UI/visualization layer
  AGENTS.md          agent roles and write permissions
  .github/
    copilot-instructions.md

tools/
  webui/            optional, independent — local UI (empty until built)
  timeline/         optional, independent — timeline/visualization view
  importers/        optional, independent — data import scripts
  scripts/          small standalone utilities usable without any instance
```

Each folder under `tools/` is independent: no tool depends on another tool. Every tool
consumes the same derived index contract (`_meta/index.json`, see
`_meta/schemas/index.schema.json`) rather than parsing Markdown directly, so tools can
be added, removed, or split into their own repository later without touching content
or other tools.

## Creating an instance

```powershell
git clone https://github.com/<you>/cortex-template.git
.\cortex-template\init.ps1 -InstanceName "work-cortex" `
                            -Owner "Karlo" `
                            -Profile work `
                            -TargetPath "C:\Users\karlom\OneDrive - Microsoft\Cortex\work-cortex" `
                            -Remote "" 
```

`init.ps1` copies `template/` to `-TargetPath`, stamps `{{OWNER}}` / `{{INSTANCE_NAME}}` /
`{{PROFILE}}` / `{{CREATED_DATE}}` tokens into `README.md`, `AGENTS.md`, and
`.github/copilot-instructions.md`, writes `_meta/config.json`, runs `git init`, and makes
the first commit. See `init.ps1 -?` for all parameters.

## Keeping an instance up to date with the template

Each instance can track this repository as an upstream remote and selectively pull
`_meta/` improvements without ever pulling instance content into the template, and
without the template ever containing instance content. See `_meta/scripts/sync.ps1`
inside a generated instance, and "Template evolution" below.

## Template evolution (fork/pull model)

- This repository (`cortex-template`) only ever contains scaffolding: folder
  structure, schemas, note templates, scripts, and agent instructions. It never
  contains real notes.
- An instance pulls improvements from this repo with `sync.ps1 -Pull`, which updates
  only `_meta/` (schemas, templates, scripts, instructions) — it never touches
  `00-inbox/` through `90-archive/`.
- When an instance produces an improvement worth generalizing (a better meeting
  template, a validator fix), that specific file is deliberately copied or PR'd back
  into this repository with `sync.ps1 -Push` (or manually) — a conscious "contribute
  upstream" step, not an automatic one, so instance-specific content never leaks into
  the shared template.
- `CHANGELOG.md` and each instance's `_meta/config.json` (`templateVersion`) track
  which template revision an instance is running and what it may be missing.

## Backups

Instances are expected to live inside a synced storage location (e.g. OneDrive) as a
normal local Git repository — no separate backup step is required by default.
`_meta/scripts/backup.ps1` is provided as an optional, periodic safety net (e.g.
monthly, or before a risky bulk-agent operation): it writes a `git bundle` (full
history) and a `.zip` (flat restore fallback) plus a `manifest.json` to a backup
destination.
