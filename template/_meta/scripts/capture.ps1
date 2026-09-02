<#
.SYNOPSIS
  Drops freeform content into 00-inbox/ with zero organizational decisions.

.DESCRIPTION
  This is the only capture entry point a user (or an agent acting on their behalf)
  should need for routine input: chat wrap-ups, personal notes, forwarded mail,
  pasted documents, anything. It never asks for a type, folder, or tags - it just
  timestamps the content and records where it came from. Deciding what the content
  *is* (project note, task, journal entry, etc.) is deferred entirely to the
  Librarian's periodic triage pass (see AGENTS.md); it is not a design goal of
  this script.

.PARAMETER Content
  The freeform text to preserve, verbatim.

.PARAMETER Source
  Optional short label for where this came from, e.g. "Copilot chat", "email",
  "manual entry", a repo name, a URL. Defaults to "manual".

.PARAMETER RootPath
  Instance root. Defaults to the parent of _meta.

.PARAMETER PassThru
  Writes the created file path to the pipeline instead of only printing a status
  line.

.EXAMPLE
  .\_meta\scripts\capture.ps1 -Content "Remember to revisit the auth design."

.EXAMPLE
  .\_meta\scripts\capture.ps1 -Source "Copilot chat: cortex-core repo cleanup" `
    -Content "Summary of what we changed and why..."
#>

param(
  [Parameter(Mandatory=$true)]
  [string]$Content,

  [string]$Source = "manual",

  [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,

  [switch]$PassThru
)

$ErrorActionPreference = "Stop"

$inboxFolder = Join-Path $RootPath "00-inbox"
New-Item -ItemType Directory -Force -Path $inboxFolder | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$targetPath = Join-Path $inboxFolder "inbox-$timestamp.md"

$suffix = 2
while (Test-Path $targetPath) {
  $targetPath = Join-Path $inboxFolder "inbox-$timestamp-$suffix.md"
  $suffix++
}

$capturedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
$sourceEscaped = $Source -replace '"', '\"'

$note = @"
---
captured: $capturedAt
source: "$sourceEscaped"
status: unfiled
---

$($Content.Trim())
"@

Set-Content -Path $targetPath -Value $note -NoNewline
if ($PassThru) {
  Write-Output $targetPath
} else {
  Write-Host "Captured to inbox: $targetPath" -ForegroundColor Green
}
