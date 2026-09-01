# Changelog — cortex-template

All notable changes to the template scaffolding (schemas, note templates, scripts,
agent instructions) are recorded here. Instance content is never recorded here.

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
