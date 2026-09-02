<#
.SYNOPSIS
  Restores a Cortex instance from a backup created by backup.ps1. Cross-platform
  via PowerShell 7+ (pwsh). Read-only against the backup destination - never
  deletes or overwrites existing backup artifacts.

.DESCRIPTION
  Two restore modes:
    -FromBundle   Clones the .bundle (full Git history) into -TargetPath. Use this
                  to recover the instance somewhere new, or after the working
                  copy was lost entirely.
    -FromZip      Expands the .zip snapshot into -TargetPath. Use this if you only
                  need the files back and don't need Git history (e.g. the bundle
                  is unavailable or corrupted).

  By default, uses the most recent backup under -SourcePath/latest. Pass
  -Timestamp to restore a specific historical snapshot from -SourcePath/history
  instead.

  This script will refuse to overwrite a non-empty -TargetPath unless -Force is
  passed, since restoring can discard newer uncommitted changes.

.PARAMETER SourcePath
  The backup destination previously used with backup.ps1 (contains latest/ and
  history/).

.PARAMETER TargetPath
  Where to restore the instance to.

.PARAMETER Timestamp
  Optional. Restore a specific historical snapshot (matches the {timestamp}_ prefix
  used in -SourcePath/history) instead of the latest backup.

.PARAMETER FromBundle
  Restore from the .bundle (full history). Mutually exclusive with -FromZip.

.PARAMETER FromZip
  Restore from the .zip (files only, no history). Mutually exclusive with -FromBundle.

.PARAMETER Force
  Allow restoring into a non-empty -TargetPath.

.EXAMPLE
  .\restore.ps1 -SourcePath "D:\CortexBackups\work-cortex" -TargetPath "C:\Cortex\work-cortex" -FromBundle

.EXAMPLE
  .\restore.ps1 -SourcePath "D:\CortexBackups\work-cortex" -TargetPath "C:\Cortex\work-cortex-recovered" -FromZip -Timestamp "2026-09-01T12-00-00Z"
#>

param(
  [Parameter(Mandatory=$true)] [string]$SourcePath,
  [Parameter(Mandatory=$true)] [string]$TargetPath,
  [string]$Timestamp,
  [switch]$FromBundle,
  [switch]$FromZip,
  [switch]$Force
)

$ErrorActionPreference = "Stop"

if ($FromBundle -and $FromZip) { throw "Specify only one of -FromBundle or -FromZip." }
if (-not $FromBundle -and -not $FromZip) { throw "Specify -FromBundle or -FromZip." }

if ((Test-Path $TargetPath) -and (Get-ChildItem $TargetPath -Force | Measure-Object).Count -gt 0 -and -not $Force) {
  throw "TargetPath '$TargetPath' is non-empty. Pass -Force to restore into it anyway (existing contents may be overwritten)."
}

$latestDir = Join-Path $SourcePath "latest"
$historyDir = Join-Path $SourcePath "history"

function Find-BackupFile {
  param([string]$Extension)
  if ($Timestamp) {
    $matches = Get-ChildItem -Path $historyDir -Filter "${Timestamp}_*$Extension" -File -ErrorAction SilentlyContinue
    if (-not $matches) { throw "No backup found in history for timestamp '$Timestamp' with extension '$Extension'." }
    return $matches[0].FullName
  }
  $matches = Get-ChildItem -Path $latestDir -Filter "*$Extension" -File -ErrorAction SilentlyContinue
  if (-not $matches) { throw "No backup found in '$latestDir' with extension '$Extension'." }
  return $matches[0].FullName
}

if ($FromBundle) {
  $bundlePath = Find-BackupFile -Extension ".bundle"
  Write-Host "Restoring from bundle: $bundlePath" -ForegroundColor Cyan
  if (Test-Path $TargetPath) {
    git clone $bundlePath $TargetPath --branch main 2>&1 | Out-Null
  } else {
    New-Item -ItemType Directory -Force -Path $TargetPath | Out-Null
    git clone $bundlePath $TargetPath --branch main
  }
  Write-Host "Restored (with full history) to $TargetPath" -ForegroundColor Green
}

if ($FromZip) {
  $zipPath = Find-BackupFile -Extension ".zip"
  Write-Host "Restoring from zip: $zipPath" -ForegroundColor Cyan
  New-Item -ItemType Directory -Force -Path $TargetPath | Out-Null
  Expand-Archive -Path $zipPath -DestinationPath $TargetPath -Force
  Write-Host "Restored (files only, no Git history) to $TargetPath" -ForegroundColor Green
  Write-Host "Note: this snapshot has no Git history. Run 'git init' if you want to start tracking history again." -ForegroundColor Yellow
}
