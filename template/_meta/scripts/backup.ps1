<#
.SYNOPSIS
  Optional periodic safety-net backup for a Cortex instance. Cross-platform via
  PowerShell 7+ (pwsh) on Windows, Linux, or macOS - no external modules required.

.DESCRIPTION
  The recommended default layout keeps the active instance as a plain local Git
  repository (not inside a cloud-synced folder) and relies on this script to push
  periodic snapshots to a cloud-synced backup destination (OneDrive, iCloud Drive,
  Dropbox, rclone-mounted storage, etc. - any folder that is itself synced/backed
  up externally). This keeps Git operations fast and conflict-free while still
  getting off-machine backup coverage.

  Writes, to -DestinationPath:
    - {name}.bundle   full Git history, restorable with `git clone` on the bundle
    - {name}.zip       flat snapshot of the working tree (human-readable fallback)
    - manifest.json    timestamp, commit SHA, file count, template version

  Keeps a rolling "latest" copy plus a timestamped copy under "history/". Use
  restore.ps1 to recover from either.

.PARAMETER RootPath
  Instance root (a Git repository). Defaults to the parent of _meta.

.PARAMETER DestinationPath
  Where to write backups, e.g. a cloud-synced folder. Defaults to
  `_meta/config.json` -> `backupDestination` if not supplied.

.EXAMPLE
  .\_meta\scripts\backup.ps1
  Uses the destination recorded in _meta/config.json.

.EXAMPLE
  .\_meta\scripts\backup.ps1 -DestinationPath "C:\Users\me\OneDrive\CortexBackups\work-cortex"
#>

param(
  [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$DestinationPath
)

$ErrorActionPreference = "Stop"

$configPath = Join-Path $RootPath "_meta/config.json"
if (-not $DestinationPath) {
  if (Test-Path $configPath) {
    $DestinationPath = (Get-Content $configPath -Raw | ConvertFrom-Json).backupDestination
  }
  if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
    throw "No -DestinationPath given and _meta/config.json has no 'backupDestination' set. Provide -DestinationPath or set backupDestination in config.json."
  }
}

$name = Split-Path -Leaf $RootPath
$latestDir = Join-Path $DestinationPath "latest"
$historyDir = Join-Path $DestinationPath "history"
New-Item -ItemType Directory -Force -Path $latestDir, $historyDir | Out-Null

$timestamp = Get-Date -Format "yyyy-MM-ddTHH-mm-ssZ"
Push-Location $RootPath
try {
  $sha = (git rev-parse HEAD).Trim()
  $bundlePath = Join-Path $latestDir "$name.bundle"
  git bundle create $bundlePath --all | Out-Null

  $zipPath = Join-Path $latestDir "$name.zip"
  if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
  Compress-Archive -Path (Join-Path $RootPath "*") -DestinationPath $zipPath -Force

  $gitSegment = [regex]::Escape([IO.Path]::DirectorySeparatorChar) + '\.git' + [regex]::Escape([IO.Path]::DirectorySeparatorChar)
  $fileCount = (Get-ChildItem -Path $RootPath -Recurse -File | Where-Object { $_.FullName -notmatch $gitSegment }).Count
  $templateVersion = $null
  if (Test-Path $configPath) {
    $templateVersion = (Get-Content $configPath -Raw | ConvertFrom-Json).templateVersion
  }

  $manifest = @{
    name            = $name
    timestamp       = $timestamp
    commitSha       = $sha
    fileCount       = $fileCount
    templateVersion = $templateVersion
  }
  $manifestPath = Join-Path $latestDir "manifest.json"
  $manifest | ConvertTo-Json | Set-Content -Path $manifestPath

  Copy-Item $bundlePath (Join-Path $historyDir "${timestamp}_$name.bundle")
  Copy-Item $zipPath (Join-Path $historyDir "${timestamp}_$name.zip")
  Copy-Item $manifestPath (Join-Path $historyDir "${timestamp}_manifest.json")

  Write-Host "Backup complete: $latestDir (+ timestamped copy in $historyDir)" -ForegroundColor Green
} finally {
  Pop-Location
}
