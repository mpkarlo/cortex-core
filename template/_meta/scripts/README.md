# Scripts

Dependency-free PowerShell 7+ (`pwsh`) scripts. No external modules required.

| Script | Used by | Purpose |
| --- | --- | --- |
| `capture.ps1` | Anyone, any time | Zero-decision capture into `00-inbox/`. Only `-Content` and `-Source`. |
| `new-note.ps1` | Curator, Librarian | Scaffolds a typed note (`-Type project\|area\|person\|meeting\|decision\|task\|reference\|journal`) from its template. |
| `librarian-list-inbox.ps1` | Librarian | Lists unfiled `00-inbox/` entries as JSON. |
| `librarian-archive-inbox-entry.ps1` | Librarian | Archives a filed inbox entry into `90-archive/inbox/` with `filedTo` provenance. |
| `validate.ps1` | Curator, Librarian, Validator | Dependency-free structural check: schema compliance, duplicate IDs, broken links. |
| `snapshot.ps1` | Anyone finishing a batch | Main-only, auto-generated-message commit. Replaces hand-authored commit messages for routine notes. |
| `backup.ps1` / `restore.ps1` | Archivist (on request only) | Bundle+zip safety-net snapshot to the configured backup destination, and recovery from it. |
| `sync.ps1` | Instance maintainer | Pull/push `_meta/` scaffolding between an instance and the `cortex-core` template. |

## Setting up the scheduled Librarian pass

The Librarian (see `AGENTS.md`) is meant to run on its own - on a schedule or
on a trigger - never because a user asked for it in a chat. In this app, wire
that up once per instance with a scheduled workflow:

1. Open (or create) a project session for this instance.
2. Use `save_workflow` to create a workflow against that project:
   - `interval`: `daily` (adjust to taste - `hourly`/`weekly` also work; a new
     capture doesn't need a dedicated trigger since the Librarian catches up
     on its next scheduled run).
   - `mode`: `autopilot` (no human approval needed for a routine reorg pass).
   - `prompt`: use the prompt below verbatim.

### The prompt

```
Act as the Librarian for this Cortex instance, per AGENTS.md:

1. Run `_meta/scripts/librarian-list-inbox.ps1` to list unfiled `00-inbox/` entries.
2. For each entry, decide the right type, folder, tags, and links, then file it
   with `_meta/scripts/new-note.ps1` (creating a new note) or by merging into an
   existing note that already covers the topic.
3. Archive each filed entry with
   `_meta/scripts/librarian-archive-inbox-entry.ps1 -Path <entry> -FiledTo <note-id(s)>`.
4. While scanning, also look for other maintenance: stale `status: active` items
   that should be `done`/`archived`, duplicate or near-duplicate notes to merge,
   orphaned tags, broken links. Fix what you can; never delete content outright -
   fold or archive it instead.
5. Run `_meta/scripts/validate.ps1` and fix anything it flags.
6. Run `_meta/scripts/snapshot.ps1 -Reason "librarian reorg"` to commit the whole
   pass as one atomic, revertible checkpoint.

Do not ask for per-item approval - this is a routine, expected pass. Stop and
report back only if you hit something outside your role (e.g. you'd need to
delete a file outright, or the repo is not on `main`).
```

If this app doesn't have workflow scheduling available, a `save_session_automation`
on a long-lived session with the same prompt and an `interval` works as a
substitute; outside this app, any scheduler that can invoke an agent CLI against
this path with the same prompt (cron, Task Scheduler, etc.) is equivalent.
