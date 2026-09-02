<#
.SYNOPSIS
  Lists unfiled 00-inbox/ entries for the Librarian triage pass.

.DESCRIPTION
  Deterministic helper: returns raw capture entries that still have
  status: unfiled in their frontmatter, oldest first. Does not decide how to
  file them - that reasoning belongs to the agent acting as Librarian (see
  AGENTS.md). Intended to be called at the start of a triage pass, whether
  that pass runs on a schedule, on a new-capture trigger, or on user request.

.PARAMETER RootPath
  Instance root. Defaults to the parent of _meta.

.EXAMPLE
  .\_meta\scripts\librarian-list-inbox.ps1
#>

param(
  [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$inboxFolder = Join-Path $RootPath "00-inbox"
if (-not (Test-Path $inboxFolder)) {
  Write-Output @()
  return
}

$entries = @()
Get-ChildItem -Path $inboxFolder -Filter "inbox-*.md" -File | Sort-Object Name | ForEach-Object {
  $content = Get-Content -Path $_.FullName -Raw
  if ($content -match '(?s)^---\r?\n(.*?)\r?\n---\r?\n(.*)$') {
    $fm = $matches[1]
    $body = $matches[2].Trim()
    $status = "unfiled"
    if ($fm -match 'status:\s*(\S+)') { $status = $matches[1] }
    if ($status -eq "unfiled") {
      $source = ""
      if ($fm -match 'source:\s*"?([^"\r\n]*)"?') { $source = $matches[1] }
      $captured = ""
      if ($fm -match 'captured:\s*(\S+)') { $captured = $matches[1] }
      $entries += [PSCustomObject]@{
        path     = $_.FullName
        captured = $captured
        source   = $source
        body     = $body
      }
    }
  }
}

ConvertTo-Json -InputObject $entries -Depth 3
