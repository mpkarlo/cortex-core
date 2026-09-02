# Cortex

A plaintext, Git-backed, AI-agent-driven personal knowledge base template. Cortex
provides durable long-term storage and reference for projects, tasks, people, decisions,
and reference material — designed to be read and maintained primarily through AI prompts
and agents, with a human-readable Markdown file as the ultimate source of truth.

This repository is the **template**, not an instance. It contains conventions, schemas,
scaffolding, and optional tools. Instances (e.g. `work-cortex`, `personal-cortex`) are
created by copying `template/` and are where actual content lives.

## Requirements

- Git
- PowerShell 7+ (`pwsh`) — cross-platform on Windows, Linux, and macOS. All scripts
  are dependency-free (no external modules, no package installs required) and are
  the single implementation for every platform; there is no separate Bash variant
  to keep in sync.

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
    scripts/        validate.ps1, new-note.ps1, backup.ps1, restore.ps1, sync.ps1
    ui/             reserved for a future local UI/visualization layer
  AGENTS.md          agent roles and write permissions
  .github/
    copilot-instructions.md

tools/
  webui/            optional, independent — local UI (empty until built)
  timeline/         optional, independent — timeline/visualization view
  importers/        optional, independent — data import scripts
  scripts/          small standalone utilities usable without any instance

tests/
  run-tests.ps1     dependency-free test suite covering init/new-note/validate/
                    backup/restore end-to-end; run with `pwsh ./tests/run-tests.ps1`
```

Each folder under `tools/` is independent: no tool depends on another tool. Every tool
consumes the same derived index contract (`_meta/index.json`, see
`_meta/schemas/index.schema.json`) rather than parsing Markdown directly, so tools can
be added, removed, or split into their own repository later without touching content
or other tools.

## Creating an instance (quick start)

These steps create a new Cortex instance from this template. Run them with `pwsh`
(PowerShell 7+); no dependencies beyond Git are required. Examples below use
Windows paths — substitute equivalent Linux/macOS paths as needed.

### 1. Clone this repository

```powershell
git clone https://github.com/<you>/cortex-core.git ~/Code/cortex-core
cd ~/Code/cortex-core
```

### 2. Choose where the instance will live

Default recommendation: a plain local path **outside** any cloud-synced folder
(OneDrive, iCloud Drive, Dropbox, etc.). Keeping the working Git repo off a
sync client avoids sync-induced file locks/conflicts during agent-driven bulk
edits. Off-machine backup coverage instead comes from periodic snapshots to a
cloud-synced destination — see step 6 and "Backups" below. Do not nest the
instance inside `cortex-core` itself.

```powershell
$target = "C:\Users\<you>\Cortex\work-cortex"
$backupDestination = "C:\Users\<you>\OneDrive - Microsoft\CortexBackups\work-cortex"
```

### 3. Run `init.ps1`

```powershell
.\init.ps1 -InstanceName "work-cortex" `
           -Owner "<Your Name>" `
           -Profile work `
           -Classification "Internal - personal work notes, no secrets, no unredacted PII" `
           -TargetPath $target `
           -BackupDestination $backupDestination `
           -Timezone "Eastern Standard Time"
```

- `-Profile` is `work` or `personal`.
- `-BackupDestination` is optional but recommended — it's recorded in
  `_meta/config.json` so `backup.ps1` and the Archivist agent role have a default
  target without needing it passed every time. You can set or change it later by
  editing `_meta/config.json` directly.
- Omit `-Remote` for now — add it later once you've created a remote for the
  instance itself (see step 6). The instance does not need to share a remote
  with `cortex-core`.

This copies `template/` to `$target`, stamps `{{OWNER}}`, `{{INSTANCE_NAME}}`,
`{{PROFILE}}`, `{{CLASSIFICATION}}`, `{{CREATED_DATE}}`, `{{TIMEZONE}}`, and
`{{BACKUP_DESTINATION}}` tokens into `README.md`, `AGENTS.md`, and
`.github/copilot-instructions.md`, writes `_meta/config.json`, runs
`git init -b main`, and makes the first commit. See `.\init.ps1 -?` for the full
parameter list.

### 4. Verify the instance

```powershell
cd $target
.\_meta\scripts\validate.ps1
```

This should report `0 errors` on a freshly created instance. Run it again any time
after an agent (or you) make bulk edits.

### 5. Create your first note — via an AI prompt

The primary way to add content is by prompting an AI agent (e.g. "capture this as
a project note about X"), not by running a script yourself. Point an agent at the
instance and describe what you want captured; the agent assumes the Curator role
described in `AGENTS.md` and calls `_meta/scripts/new-note.ps1` on your behalf,
filing it under the right folder with frontmatter already filled in. If you
supply your own freeform text or a reference document, the agent saves it as a
linked attachment alongside the note rather than folding it into the note body —
see "Primary intake path" in `AGENTS.md`.

Running `new-note.ps1` directly still works and is useful for scripting or
testing, but is not the expected day-to-day interface:

```powershell
.\_meta\scripts\new-note.ps1 -Type project -Title "My First Project"
```

This creates `10-projects\project-my-first-project.md` from the project template.
See `.github/copilot-instructions.md` for how Copilot-style tools should behave in
this repository, and `AGENTS.md` for the full set of agent roles (Reader /
Curator / Specialist / Archivist / Validator).

### 6. Set up backups

Instances live outside cloud sync by default (step 2), so periodic backup to
cloud storage is how you get off-machine coverage. Either run it yourself or ask
an agent to invoke the Archivist role ("back this up", "restore last week's
backup"):

```powershell
.\_meta\scripts\backup.ps1
```

Uses `-BackupDestination` from step 3 (or pass `-DestinationPath` explicitly).
Writes a `.bundle` (full Git history), a `.zip` (flat fallback), and a
`manifest.json` to that destination. See "Backups" below and
`_meta/scripts/restore.ps1` for recovery.

### 7. (Optional) Add a remote for the instance

The instance is its own Git repository, independent of `cortex-core`. A remote is
optional, but becomes necessary if you need the instance to **sync across
multiple machines** (e.g. a work laptop and a home desktop) — the backup
destination alone is a one-way snapshot, not a two-way sync mechanism.

**Option A — hosted remote (GitHub/GitLab/Azure DevOps, private repo).**
Simplest if you're comfortable putting the instance on a hosted git service:

```powershell
git remote add origin <instance-remote-url>
git push -u origin main
```

**Option B — bare repo on cloud-synced storage (no hosted service needed).**
Works well if you'd rather not host personal/work notes on a third-party service
at all: create a *bare* Git repository inside a cloud-synced folder (OneDrive,
iCloud Drive, Dropbox, etc.). The cloud-sync client mirrors the bare repo's files
between machines exactly like any other file; each machine then treats it as a
normal `origin` and syncs with ordinary `git push`/`git pull`. A dedicated
`GitRemotes/` folder (not mixed in with note content or backups) keeps this
reusable for other repos too, not just Cortex instances.

```powershell
# One-time setup (on the first machine):
git init --bare "C:\Users\<you>\OneDrive\GitRemotes\<instance-name>.git"
cd $target
git remote add origin "C:\Users\<you>\OneDrive\GitRemotes\<instance-name>.git"
git push -u origin main
```

```powershell
# On each additional machine, once OneDrive has synced the bare repo there:
git clone "C:\Users\<you>\OneDrive\GitRemotes\<instance-name>.git" "C:\Users\<you>\Cortex\<instance-name>"
cd "C:\Users\<you>\Cortex\<instance-name>"
# git pull / git push as usual from here on
```

Caveat: because sync relies on the cloud-sync client mirroring files, avoid
pushing from two machines at the same moment — resolve any conflicting sync
copies the cloud provider creates the same way you would for any other
file-synced Git repo. This is unrelated to `-BackupDestination`/`backup.ps1`,
which remains a separate, periodic safety-net snapshot even when a sync remote
is in use.

### 8. Repeat for a second instance

Run `init.ps1` again with a different `-InstanceName`, `-Profile`, `-TargetPath`,
and `-BackupDestination` (e.g. `personal-cortex`). Each instance is independent;
only `_meta/` scaffolding is ever shared between them, via `sync.ps1` — see
"Keeping an instance up to date with the template" below.

## Keeping an instance up to date with the template

Each instance can track this repository as an upstream remote and selectively pull
`_meta/` improvements without ever pulling instance content into the template, and
without the template ever containing instance content. See `_meta/scripts/sync.ps1`
inside a generated instance, and "Template evolution" below.

## Template evolution (fork/pull model)

- This repository (`cortex-core`) only ever contains scaffolding: folder
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

Instances live outside cloud-synced storage by default (see "Creating an
instance" step 2), as a plain local Git repository — this keeps day-to-day and
agent-driven bulk edits fast and free of sync-client locking/conflicts.
Off-machine coverage instead comes from periodic snapshots pushed to a
cloud-synced destination (OneDrive, iCloud Drive, Dropbox, etc.):

- `_meta/scripts/backup.ps1` writes a `git bundle` (full history), a `.zip` (flat
  restore fallback), and a `manifest.json` to `-DestinationPath` (or the
  `backupDestination` recorded in `_meta/config.json` by `init.ps1`).
- `_meta/scripts/restore.ps1` restores from either artifact: `-FromBundle`
  (clones the bundle, preserving full Git history) or `-FromZip` (expands the
  files only). Use `-Timestamp` to recover a specific historical snapshot
  instead of the latest one.
- The **Archivist** agent role (see `AGENTS.md`) can run backup/restore on your
  behalf when explicitly invoked ("back this up", "restore last Tuesday's
  snapshot") — it never runs automatically, and always confirms with you before
  a restore, since restoring can discard newer uncommitted changes.

Run `backup.ps1` periodically (e.g. daily/weekly, or before a risky bulk-agent
operation) — there's no automatic scheduling built in; a scheduled task/cron job
is a reasonable way to automate it if you want.

## Testing

```powershell
pwsh ./tests/run-tests.ps1
```

Runs a dependency-free end-to-end check of `init.ps1`, `new-note.ps1`,
`validate.ps1`, `backup.ps1`, and `restore.ps1` against disposable, temp-directory
instances (cleaned up automatically). Run this after changing any script in
`_meta/scripts/` or `init.ps1` before committing.

`tools/scripts/check-template-purity.ps1` guards against `template/` ever
accumulating real instance data (filled-in notes, a stamped `_meta/config.json`,
etc.) — it runs automatically in CI (`.github/workflows/template-purity.yml`)
on every pull request and push to `main`.

## License

Licensed under the [GNU General Public License v3.0](LICENSE). You are free to use,
study, modify, and redistribute this template and its generated instances, provided
derivative works remain under the same license.
