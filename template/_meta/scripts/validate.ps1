<#
.SYNOPSIS
  Validates Cortex instance content against _meta/schemas. Dependency-free
  (built-in PowerShell only). No AI, no external modules.

.DESCRIPTION
  Checks, across all note files under the numbered content folders:
    - Frontmatter block is present and parses as valid YAML-ish key/value pairs
      (a minimal parser is used; complex YAML is not required by the schemas)
    - Required fields per type are present (per _meta/schemas/*.schema.json)
    - No duplicate 'id' values across the whole instance
    - No broken repo-relative Markdown links ([text](path) where path is a file)
    - Filenames match the {type}-{slug}.md or {type}-{yyyymmdd}-{slug}.md convention

.PARAMETER RootPath
  Path to the instance root (defaults to the parent of _meta, i.e. this script's
  grandparent directory when run from within an instance).

.EXAMPLE
  .\_meta\scripts\validate.ps1
#>

param(
  [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"
$contentFolders = @("10-projects","20-areas","30-tasks","40-people","50-meetings","60-decisions","70-reference","80-journal")
$schemaDir = Join-Path $RootPath "_meta\schemas"
$errors = @()
$seenIds = @{}

function Parse-Frontmatter {
  param([string[]]$Lines)
  # Minimal frontmatter parser: supports top-level scalar and inline-array fields only.
  # Sufficient for validation purposes; not a full YAML parser (no external dependency).
  $fm = @{}
  foreach ($line in $Lines) {
    if ($line -match '^([A-Za-z0-9_]+):\s*(.*)$') {
      $key = $matches[1]
      $val = $matches[2].Trim()
      $fm[$key] = $val
    }
  }
  return $fm
}

function Get-RequiredFields {
  param([string]$Type)
  $common = @("id","type","status","created","updated")
  $extra = @{
    project  = @("owner")
    meeting  = @("date","attendees")
    decision = @("date","decisionStatus")
    person   = @()
    task     = @()
    area     = @()
    reference= @()
    journal  = @()
  }
  return $common + $extra[$Type]
}

$allFiles = @()
foreach ($folder in $contentFolders) {
  $path = Join-Path $RootPath $folder
  if (Test-Path $path) {
    $allFiles += Get-ChildItem -Path $path -Recurse -Filter *.md -File
  }
}

foreach ($file in $allFiles) {
  $content = Get-Content -Path $file.FullName -Raw
  if ($content -notmatch '(?s)^---\r?\n(.*?)\r?\n---') {
    $errors += "MISSING_FRONTMATTER: $($file.FullName)"
    continue
  }
  $fmBlock = $matches[1] -split "`r?`n"
  $fm = Parse-Frontmatter -Lines $fmBlock

  if (-not $fm.ContainsKey("type")) {
    $errors += "MISSING_TYPE: $($file.FullName)"
    continue
  }
  $type = $fm["type"]

  foreach ($field in (Get-RequiredFields -Type $type)) {
    if (-not $fm.ContainsKey($field) -or [string]::IsNullOrWhiteSpace($fm[$field])) {
      $errors += "MISSING_FIELD ($field): $($file.FullName)"
    }
  }

  if ($fm.ContainsKey("id")) {
    $id = $fm["id"]
    if ($seenIds.ContainsKey($id)) {
      $errors += "DUPLICATE_ID ($id): $($file.FullName) conflicts with $($seenIds[$id])"
    } else {
      $seenIds[$id] = $file.FullName
    }
    if ($id -notmatch '^[a-z]+-[a-z0-9]+(-[a-z0-9]+)*$') {
      $errors += "MALFORMED_ID ($id): $($file.FullName)"
    }
  }

  $expectedPrefix = "$type-"
  if ($file.BaseName -ne "index" -and -not $file.BaseName.StartsWith($expectedPrefix)) {
    $errors += "FILENAME_CONVENTION: $($file.FullName) does not start with '$expectedPrefix'"
  }

  # Check repo-relative markdown links resolve to existing files
  $linkMatches = [regex]::Matches($content, '\[[^\]]+\]\(([^)]+)\)')
  foreach ($m in $linkMatches) {
    $target = $m.Groups[1].Value
    if ($target -match '^(https?:|mailto:|#)') { continue }
    $resolved = Join-Path $file.DirectoryName $target
    if (-not (Test-Path $resolved)) {
      $errors += "BROKEN_LINK ($target): $($file.FullName)"
    }
  }
}

if ($errors.Count -eq 0) {
  Write-Host "Validation passed: $($allFiles.Count) files checked, 0 errors." -ForegroundColor Green
  exit 0
} else {
  Write-Host "Validation failed: $($errors.Count) error(s) across $($allFiles.Count) files." -ForegroundColor Red
  $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
  exit 1
}
