<#
.SYNOPSIS
  Fails if a change would introduce real instance data into the cortex-core
  template. Dependency-free (built-in PowerShell only). No AI required.

.DESCRIPTION
  This repository ships `template/` as pristine scaffolding — content folders
  (00-inbox through 90-archive, assets/) must never contain anything but a
  .gitkeep placeholder, and _meta/ must never contain a stamped config.json
  (only config.json.template). This guards against a contributor accidentally
  committing real notes, an instantiated config, or other personal/work data
  into the template that every future instance is copied from.

  Checks performed against `template/`:
    - Content folders (00-inbox, 10-projects, 20-areas, 30-tasks, 40-people,
      50-meetings, 60-decisions, 70-reference, 80-journal, 90-archive) and
      assets/ must contain only .gitkeep (recursively) — no other files.
    - _meta/config.json must not exist (only config.json.template is allowed;
      config.json is instance-only and produced by init.ps1).
    - No file anywhere under template/ may contain a frontmatter block
      (--- ... ---) with a non-token `id:`, `owner:`, or similar real-looking
      value — i.e. no file should look like a filled-in note. Files containing
      unresolved {{TOKEN}} placeholders are expected and pass.

.PARAMETER RootPath
  Path to the repository root (defaults to the parent of this script's
  grandparent directory, i.e. the repo root when run from tools/scripts).

.EXAMPLE
  pwsh ./tools/scripts/check-template-purity.ps1
#>

param(
  [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"
$templateRoot = Join-Path $RootPath "template"
$errors = @()

if (-not (Test-Path $templateRoot)) {
  throw "template/ not found under $RootPath"
}

$contentFolders = @(
  "00-inbox","10-projects","20-areas","30-tasks","40-people",
  "50-meetings","60-decisions","70-reference","80-journal","90-archive",
  "assets"
)

foreach ($folder in $contentFolders) {
  $path = Join-Path $templateRoot $folder
  if (-not (Test-Path $path)) { continue }
  $files = Get-ChildItem -Path $path -Recurse -File
  foreach ($file in $files) {
    if ($file.Name -ne ".gitkeep") {
      $rel = $file.FullName.Substring($RootPath.Length).TrimStart('\','/')
      $errors += "NON_TEMPLATE_FILE: $rel (only .gitkeep is allowed in template content folders)"
    }
  }
}

$stampedConfig = Join-Path $templateRoot (Join-Path "_meta" "config.json")
if (Test-Path $stampedConfig) {
  $errors += "STAMPED_CONFIG: template/_meta/config.json must not exist — only config.json.template belongs in the template."
}

# Scan every text file under template/ for a filled-in frontmatter block,
# i.e. a `---` fenced header with real-looking scalar values and no
# unresolved {{TOKEN}} placeholders left for init.ps1 to stamp.
$candidateFiles = Get-ChildItem -Path $templateRoot -Recurse -File | Where-Object {
  $_.Extension -in @(".md", ".json")
}

foreach ($file in $candidateFiles) {
  $content = Get-Content -Path $file.FullName -Raw
  if ([string]::IsNullOrEmpty($content)) { continue }

  if ($content -match '(?s)^---\r?\n(.*?)\r?\n---') {
    $fmBlock = $matches[1]
    $hasId = $fmBlock -match '(?m)^id:\s*(\S.*)$'
    if ($hasId) {
      $idValue = $matches[1].Trim()
      $isPlaceholder = ($idValue -like '*{{*}}*') -or ($idValue -like '*<*>*')
      if ($idValue -and -not $isPlaceholder) {
        $rel = $file.FullName.Substring($RootPath.Length).TrimStart('\','/')
        $errors += "FILLED_FRONTMATTER ($idValue): $rel looks like a real note, not a blank template."
      }
    }
  }
}

if ($errors.Count -eq 0) {
  Write-Host "Template purity check passed: template/ contains no real instance data." -ForegroundColor Green
  exit 0
} else {
  Write-Host "Template purity check failed: $($errors.Count) issue(s) found." -ForegroundColor Red
  $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
  Write-Host ""
  Write-Host "template/ must stay pristine scaffolding — real notes and instance data belong only in a generated instance (see init.ps1), never in this repository." -ForegroundColor Yellow
  exit 1
}
