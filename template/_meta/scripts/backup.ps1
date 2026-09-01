<#
.SYNOPSIS
  Optional periodic safety-net backup for a Cortex instance. Not required for
  normal operation if the instance already lives in a synced location (e.g.
  OneDrive) — this is an extra layer for before risky bulk-agent operations or
  as a monthly snapshot.

.DESCRIPTION
  Writes, to -DestinationPath:
    - {name}.bundle   full Git history, restorable with `git clone` on the bundle
    - {name}.zip       flat snapshot of the working tree (human-readable fallback)
    - manifest.json    timestamp, commit SHA, file count, template version

  Keeps a rolling "latest" copy plus a timestamped copy under "history/".

.PARAMETER RootPath
  Instance root (a Git repository). Defaults to the parent of _meta.

.PARAMETER DestinationPath
  Where to write backups, e.g. an instance-specific folder in OneDrive.

.EXAMPLE
  .\_meta\scripts\backup.ps1 -DestinationPath "C:\Users\me\OneDrive\CortexBackups\work-cortex"
#>

param(
  [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [Parameter(Mandatory=$true)]
  [string]$DestinationPath
)

$ErrorActionPreference = "Stop"

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

  $fileCount = (Get-ChildItem -Path $RootPath -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.git\\' }).Count
  $templateVersion = $null
  $configPath = Join-Path $RootPath "_meta\config.json"
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
