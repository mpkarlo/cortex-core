<#
.SYNOPSIS
  Auto-snapshots Cortex instance changes with git, main-only.

.DESCRIPTION
  Git is used here purely as a rollback mechanism, not curated history: this
  script never prompts for a commit message, batches whatever changed since the
  last snapshot, validates, and commits in one call. It is meant to be run after
  every capture and after every Librarian triage/reorg pass so that any bad batch
  (especially an automated reorg) can be undone with 'git revert' or
  'git reset --hard' against a specific snapshot.

  Canonical Cortex content is only ever committed on the 'main' branch. This
  script refuses to commit from anywhere else. This is a policy this script can
  enforce for itself, but it cannot force the *host* (an IDE, an agent runtime,
  Copilot's session/worktree manager, etc.) to check the instance out on main in
  the first place - see "Avoiding stray branches" in AGENTS.md for the actual
  fix, which is choosing "branch" mode (not "worktree" mode) when opening a
  session against this instance.

.PARAMETER Reason
  Optional short free-text reason folded into the auto-generated commit message
  (e.g. "inbox capture", "librarian reorg"). Defaults to "snapshot".

.PARAMETER Push
  Pushes main to origin after committing.

.PARAMETER RootPath
  Instance root. Defaults to the parent of _meta.

.EXAMPLE
  .\_meta\scripts\snapshot.ps1 -Reason "librarian reorg"
#>

param(
  [string]$Reason = "snapshot",

  [switch]$Push,

  [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$branch = (git -C $RootPath branch --show-current).Trim()
if ($branch -ne "main") {
  throw "Main-only policy: refusing to snapshot from branch '$branch'. This instance must be opened in a mode that checks out 'main' directly (see 'Avoiding stray branches' in AGENTS.md), not a separate worktree/feature branch."
}

& (Join-Path $RootPath (Join-Path "_meta" (Join-Path "scripts" "validate.ps1"))) -RootPath $RootPath
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$status = git -C $RootPath status --porcelain
if ([string]::IsNullOrWhiteSpace($status)) {
  Write-Host "No changes to snapshot." -ForegroundColor Cyan
  exit 0
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
$message = "$Reason ($timestamp)"

git -C $RootPath add -A
git -C $RootPath commit -m $message | Out-Null
Write-Host "Snapshotted: $message" -ForegroundColor Green

if ($Push) {
  git -C $RootPath push origin main
}
