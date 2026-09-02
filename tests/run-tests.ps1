<#
.SYNOPSIS
  Dependency-free test suite for cortex-core scripts (init, new-note, capture,
  librarian triage, snapshot, validate, backup, restore, sync). No Pester or
  other test framework required - runs under plain PowerShell 7+ (pwsh) on
  Windows, Linux, or macOS.

.DESCRIPTION
  Creates disposable instances and backup destinations under the system temp
  directory, exercises each script, asserts expected outcomes, and cleans up
  afterwards (even on failure). Exits with a non-zero code if any assertion fails,
  so it can be used as a CI gate.

.EXAMPLE
  pwsh ./tests/run-tests.ps1
#>

param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$failures = @()
$passCount = 0

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if ($Condition) {
    $script:passCount++
  } else {
    $script:failures += $Message
    Write-Host "FAIL: $Message" -ForegroundColor Red
  }
}

function New-TempDir {
  param([string]$Prefix)
  $path = Join-Path ([System.IO.Path]::GetTempPath()) "$Prefix-$(New-Guid)"
  New-Item -ItemType Directory -Force -Path $path | Out-Null
  return $path
}

$workDir = New-TempDir -Prefix "cortex-core-tests"
$instancePath = Join-Path $workDir "instance"
$backupPath = Join-Path $workDir "backups"
$restorePathBundle = Join-Path $workDir "restored-bundle"
$restorePathZip = Join-Path $workDir "restored-zip"

Write-Host "Test workspace: $workDir" -ForegroundColor Cyan

try {
  # --- init.ps1 -------------------------------------------------------------
  & (Join-Path $repoRoot "init.ps1") `
    -InstanceName "test-instance" `
    -Owner "Test Owner" `
    -Profile work `
    -Classification "Test classification" `
    -TargetPath $instancePath `
    -BackupDestination $backupPath `
    -Timezone "UTC" | Out-Null

  Assert-True (Test-Path $instancePath) "init.ps1 creates the target path"
  Assert-True (Test-Path (Join-Path $instancePath ".git")) "init.ps1 initializes a Git repo"
  Assert-True (Test-Path (Join-Path $instancePath (Join-Path "_meta" "config.json"))) "init.ps1 writes _meta/config.json"
  Assert-True (-not (Test-Path (Join-Path $instancePath (Join-Path "_meta" "config.json.template")))) "init.ps1 removes config.json.template"

  $config = Get-Content (Join-Path $instancePath (Join-Path "_meta" "config.json")) -Raw | ConvertFrom-Json
  Assert-True ($config.instanceName -eq "test-instance") "config.json has stamped instanceName"
  Assert-True ($config.owner -eq "Test Owner") "config.json has stamped owner"
  Assert-True ($config.backupDestination -eq $backupPath) "config.json records backupDestination"

  $agentsContent = Get-Content (Join-Path $instancePath "AGENTS.md") -Raw
  Assert-True ($agentsContent -notmatch '\{\{INSTANCE_NAME\}\}') "AGENTS.md has no unstamped tokens"
  Assert-True ($agentsContent -match 'test-instance') "AGENTS.md contains the stamped instance name"

  # --- validate.ps1 (clean instance) -----------------------------------------
  & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "validate.ps1"))) -RootPath $instancePath
  Assert-True ($LASTEXITCODE -eq 0) "validate.ps1 passes on a freshly initialized instance"

  # --- new-note.ps1 -----------------------------------------------------------
  & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "new-note.ps1"))) `
    -Type project -Title "Test Project" -RootPath $instancePath | Out-Null

  $notePath = Join-Path $instancePath (Join-Path "10-projects" "project-test-project.md")
  Assert-True (Test-Path $notePath) "new-note.ps1 creates the expected file for a project note"

  $noteContent = Get-Content $notePath -Raw
  Assert-True ($noteContent -match 'id: project-test-project') "new-note.ps1 stamps the correct id"
  Assert-True ($noteContent -match '# Test Project') "new-note.ps1 stamps the title into the heading"

  & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "new-note.ps1"))) `
    -Type meeting -Title "Weekly Sync" -RootPath $instancePath | Out-Null
  $meetingFiles = Get-ChildItem (Join-Path $instancePath "50-meetings") -Filter "meeting-*.md"
  Assert-True ($meetingFiles.Count -eq 1 -and $meetingFiles[0].Name -match '^meeting-\d{8}-weekly-sync\.md$') "new-note.ps1 uses dated filename convention for meetings"

  & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "new-note.ps1"))) `
    -Type area -Title "Engineering Practice" -RootPath $instancePath | Out-Null
  Assert-True (Test-Path (Join-Path $instancePath (Join-Path "20-areas" "area-engineering-practice.md"))) "new-note.ps1 creates area notes"

  # --- capture.ps1 (zero-decision inbox drop) ----------------------------------
  $capturedPath = & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "capture.ps1"))) `
    -Source "Copilot chat" `
    -Content "Captured `$5 note from another repository chat." `
    -RootPath $instancePath -PassThru
  Assert-True (Test-Path $capturedPath) "capture.ps1 creates an inbox file"
  Assert-True ($capturedPath -match [regex]::Escape((Join-Path "00-inbox" ""))) "capture.ps1 files into 00-inbox by default"
  $capturedContent = Get-Content $capturedPath -Raw
  Assert-True ($capturedContent -match 'status: unfiled') "capture.ps1 stamps status: unfiled"
  Assert-True ($capturedContent -match 'source: "Copilot chat"') "capture.ps1 records the source"
  Assert-True ($capturedContent -match 'Captured \$5 note') "capture.ps1 preserves literal dollar signs in captured text"
  Assert-True ($capturedContent -notmatch 'type:') "capture.ps1 makes no type decision at capture time"

  # --- librarian-list-inbox.ps1 -------------------------------------------------
  $inboxJson = & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "librarian-list-inbox.ps1"))) -RootPath $instancePath | Out-String
  $inboxEntries = $inboxJson | ConvertFrom-Json
  Assert-True ($inboxEntries.Count -eq 1) "librarian-list-inbox.ps1 lists the unfiled capture"
  Assert-True ($inboxEntries[0].source -eq "Copilot chat") "librarian-list-inbox.ps1 surfaces the source"

  # --- librarian-archive-inbox-entry.ps1 ----------------------------------------
  & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "librarian-archive-inbox-entry.ps1"))) `
    -Path $capturedPath -FiledTo "project-test-project" -RootPath $instancePath | Out-Null
  Assert-True (-not (Test-Path $capturedPath)) "librarian-archive-inbox-entry.ps1 removes the entry from 00-inbox"
  $archivedPath = Join-Path $instancePath (Join-Path "90-archive" (Join-Path "inbox" (Split-Path $capturedPath -Leaf)))
  Assert-True (Test-Path $archivedPath) "librarian-archive-inbox-entry.ps1 moves the entry to 90-archive/inbox"
  $archivedContent = Get-Content $archivedPath -Raw
  Assert-True ($archivedContent -match 'status: filed') "librarian-archive-inbox-entry.ps1 marks the entry as filed"
  Assert-True ($archivedContent -match 'filedTo: \["project-test-project"\]') "librarian-archive-inbox-entry.ps1 records where the entry was filed"

  $inboxJsonAfter = & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "librarian-list-inbox.ps1"))) -RootPath $instancePath | Out-String
  $inboxEntriesAfter = $inboxJsonAfter | ConvertFrom-Json
  Assert-True ($null -eq $inboxEntriesAfter -or @($inboxEntriesAfter).Count -eq 0) "librarian-list-inbox.ps1 no longer lists an archived entry"

  # --- validate.ps1 (populated instance) --------------------------------------
  & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "validate.ps1"))) -RootPath $instancePath
  Assert-True ($LASTEXITCODE -eq 0) "validate.ps1 passes after adding valid notes"

  # --- validate.ps1 catches structural errors ---------------------------------
  Add-Content -Path $notePath -Value "`n[broken link](../does-not-exist.md)"
  & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "validate.ps1"))) -RootPath $instancePath 2>$null
  Assert-True ($LASTEXITCODE -ne 0) "validate.ps1 fails when a broken link is introduced"

  Set-Content -Path $notePath -Value ($noteContent) -NoNewline
  & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "validate.ps1"))) -RootPath $instancePath
  Assert-True ($LASTEXITCODE -eq 0) "validate.ps1 passes again after reverting the broken link"

  & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "snapshot.ps1"))) `
    -Reason "test notes" -RootPath $instancePath | Out-Null
  $latestCommit = (git -C $instancePath log -1 --pretty=%s).Trim()
  Assert-True ($latestCommit -match '^test notes \(') "snapshot.ps1 commits note changes on main with an auto-generated message"

  git -C $instancePath switch -c test-branch -q
  $mainOnlyRefused = $false
  try {
    & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "snapshot.ps1"))) `
      -Reason "Should fail" -RootPath $instancePath 2>$null
  } catch {
    $mainOnlyRefused = $true
  }
  Assert-True $mainOnlyRefused "snapshot.ps1 refuses to save from non-main branches"
  git -C $instancePath switch main -q

  # --- backup.ps1 --------------------------------------------------------------
  & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "backup.ps1"))) -RootPath $instancePath
  $latestDir = Join-Path $backupPath "latest"
  $historyDir = Join-Path $backupPath "history"
  Assert-True (Test-Path $latestDir) "backup.ps1 creates the 'latest' directory"
  Assert-True ((Get-ChildItem $latestDir -Filter "*.bundle").Count -eq 1) "backup.ps1 writes a .bundle to latest/"
  Assert-True ((Get-ChildItem $latestDir -Filter "*.zip").Count -eq 1) "backup.ps1 writes a .zip to latest/"
  Assert-True (Test-Path (Join-Path $latestDir "manifest.json")) "backup.ps1 writes manifest.json"
  Assert-True ((Get-ChildItem $historyDir -Filter "*.bundle").Count -eq 1) "backup.ps1 writes a timestamped copy to history/"

  $manifest = Get-Content (Join-Path $latestDir "manifest.json") -Raw | ConvertFrom-Json
  Assert-True ($manifest.name -eq "instance") "backup.ps1 manifest records the instance name"
  Assert-True (-not [string]::IsNullOrWhiteSpace($manifest.commitSha)) "backup.ps1 manifest records a commit SHA"

  # --- backup.ps1 falls back to config.json backupDestination ------------------
  Remove-Item $backupPath -Recurse -Force
  & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "backup.ps1"))) -RootPath $instancePath
  Assert-True (Test-Path (Join-Path $backupPath (Join-Path "latest" "manifest.json"))) "backup.ps1 falls back to config.json's backupDestination when -DestinationPath is omitted"

  # --- restore.ps1 (from bundle) -------------------------------------------------
  & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "restore.ps1"))) `
    -SourcePath $backupPath -TargetPath $restorePathBundle -FromBundle
  Assert-True (Test-Path (Join-Path $restorePathBundle ".git")) "restore.ps1 -FromBundle restores a Git repo"
  Assert-True (Test-Path (Join-Path $restorePathBundle (Join-Path "10-projects" "project-test-project.md"))) "restore.ps1 -FromBundle restores note content"

  # --- restore.ps1 (from zip) -----------------------------------------------------
  & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "restore.ps1"))) `
    -SourcePath $backupPath -TargetPath $restorePathZip -FromZip
  Assert-True (Test-Path (Join-Path $restorePathZip (Join-Path "10-projects" "project-test-project.md"))) "restore.ps1 -FromZip restores note content"

  # --- restore.ps1 refuses to overwrite non-empty target without -Force -----------
  $refused = $false
  try {
    & (Join-Path $instancePath (Join-Path "_meta" (Join-Path "scripts" "restore.ps1"))) `
      -SourcePath $backupPath -TargetPath $restorePathZip -FromZip
  } catch {
    $refused = $true
  }
  Assert-True $refused "restore.ps1 refuses to restore into a non-empty target without -Force"

} finally {
  Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
if ($failures.Count -eq 0) {
  Write-Host "All $passCount assertions passed." -ForegroundColor Green
  exit 0
} else {
  Write-Host "$($failures.Count) assertion(s) failed out of $($passCount + $failures.Count):" -ForegroundColor Red
  $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
  exit 1
}
