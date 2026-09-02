<#
.SYNOPSIS
  Marks a 00-inbox/ entry as filed and moves it into 90-archive/inbox/.

.DESCRIPTION
  Called by the Librarian after a raw capture has been triaged into a proper
  note elsewhere in the instance. Keeps the original raw capture (source text,
  exact wording, timestamp) for audit/recovery purposes instead of deleting it,
  but takes it out of the active inbox so repeated triage passes don't re-process
  it. Optionally records which note(s) the entry was filed into.

.PARAMETER Path
  Full or instance-relative path to the 00-inbox/inbox-*.md file to archive.

.PARAMETER FiledTo
  Optional list of note IDs this entry was filed into, recorded in frontmatter
  for traceability (e.g. -FiledTo project-arbiter,task-20260901-followup).

.PARAMETER RootPath
  Instance root. Defaults to the parent of _meta.

.EXAMPLE
  .\_meta\scripts\librarian-archive-inbox-entry.ps1 -Path 00-inbox\inbox-20260901-120000.md `
    -FiledTo project-arbiter
#>

param(
  [Parameter(Mandatory=$true)]
  [string]$Path,

  [string[]]$FiledTo = @(),

  [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$sourcePath = $Path
if (-not [System.IO.Path]::IsPathRooted($sourcePath)) {
  $sourcePath = Join-Path $RootPath $Path
}
if (-not (Test-Path $sourcePath)) {
  throw "No inbox entry found at $sourcePath"
}

$archiveFolder = Join-Path $RootPath (Join-Path "90-archive" "inbox")
New-Item -ItemType Directory -Force -Path $archiveFolder | Out-Null

$content = Get-Content -Path $sourcePath -Raw
$filedToInline = "[]"
if ($FiledTo.Count -gt 0) {
  $filedToInline = "[" + (($FiledTo | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join ", ") + "]"
}

if ($content -match '(?s)^(---\r?\n.*?)(status:\s*\S+)(.*?\r?\n---)') {
  $content = $content -replace 'status:\s*\S+', "status: filed`nfiledTo: $filedToInline"
} else {
  $content = $content -replace '(?s)^(---\r?\n)', "`${1}status: filed`nfiledTo: $filedToInline`n"
}

$targetPath = Join-Path $archiveFolder (Split-Path $sourcePath -Leaf)
Set-Content -Path $targetPath -Value $content -NoNewline
Remove-Item -Path $sourcePath

Write-Host "Archived inbox entry to $targetPath" -ForegroundColor Green
