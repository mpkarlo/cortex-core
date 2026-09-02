# Changelog — cortex-core

All notable changes to the template scaffolding (schemas, note templates, scripts,
agent instructions) are recorded here. Instance content is never recorded here.

## [Unreleased]

### Added
- Zero-decision `capture.ps1`: writes raw captures straight into `00-inbox/`
  with only a timestamp and source label — no type, tags, or title required
  at capture time.
- `librarian-list-inbox.ps1` and `librarian-archive-inbox-entry.ps1` supporting
  a new periodic **Librarian** agent role that files, tags, links, and archives
  inbox entries on a schedule (not on user request).
- `snapshot.ps1` (replaces `save-notes.ps1`): main-only, auto-generated commit
  messages — routine notes and Librarian reorg passes are never hand-authored
  commits or feature branches.
- Area and journal note templates and schemas, matching the documented folder
  structure.
- `AGENTS.md` "Git policy: snapshots, not curated history" and "Avoiding stray
  branches" guidance, reflecting that Git is now a rollback/snapshot mechanism
  rather than curated history, and that content edits should be rare compared
  to reorganization.

### Changed
- `AGENTS.md` and `.github/copilot-instructions.md` rewritten around a
  capture-vs-organize split: Curator now files on-demand/explicit-instruction
  content only; the new Librarian role owns periodic, non-chat-triggered
  reorganization.

### Removed
- `save-notes.ps1` (replaced by `snapshot.ps1`).

## [0.1.0] - 2026-09-01

### Added
- Initial folder structure: `00-inbox` through `90-archive`, `assets/`, `_meta/`.
- Frontmatter schemas for project, person, meeting, decision, task, reference,
  and the shared derived-index contract (`index.schema.json`).
- Note templates for project, person, meeting, decision, task, reference.
- `_meta/scripts/validate.ps1` — dependency-free structural validator.
- `_meta/scripts/new-note.ps1` — scaffolds a new note from a template.
- `_meta/scripts/backup.ps1` — optional bundle+zip safety-net backup.
- `_meta/scripts/sync.ps1` — pull/push `_meta/` scaffolding between an instance
  and this template repository.
- `init.ps1` — bootstraps a new instance from `template/`.
- `AGENTS.md` and `.github/copilot-instructions.md` defining the Reader /
  Curator / Specialist / Validator agent model.
- `tools/` scaffolding (`webui/`, `timeline/`, `importers/`, `scripts/`) as
  independent, optional, pluggable folders — none built yet.
