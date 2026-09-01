# AGENTS.md — Cortex Instance `{{INSTANCE_NAME}}`

This file defines how AI agents are permitted to read and write this repository.
It applies to every agent, tool, or automation acting on this instance, regardless
of which host or product is invoking them.

## Roles

### Reader
- May search, summarize, correlate, and answer questions using any file in the
  repository.
- Must **never** create, edit, move, rename, or delete files.
- May propose changes as text/diffs for the user or the Curator to apply.

### Curator (the only default writer)
- The single role permitted to write to the canonical folders
  (`00-inbox` through `90-archive`, `assets/`).
- Responsible for: normalizing frontmatter, assigning stable IDs, filing notes into
  the correct folder, maintaining links between notes, and keeping `_meta/index.json`
  (if present) in sync.
- Must run `_meta/scripts/validate.ps1` after any batch of writes and must not leave
  the repository in a state that fails validation.
- Must write in small, atomic commits with descriptive messages so a bad batch can be
  reverted with `git revert` without affecting unrelated notes.

### Specialist
- Produces draft content (e.g. a generated meeting summary, a proposed project
  breakdown) and places it in `00-inbox/` for the Curator to triage and file.
- Must not write directly outside `00-inbox/`.

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
