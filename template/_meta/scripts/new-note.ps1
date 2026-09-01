<#
.SYNOPSIS
  Creates a new note from a _meta/templates/*.md template with tokens filled in.

.PARAMETER Type
  One of: project, person, meeting, decision, task, reference

.PARAMETER Title
  Human-readable title, used to derive the slug and filled into the heading.

.PARAMETER RootPath
  Instance root. Defaults to the parent of _meta.

.EXAMPLE
  .\_meta\scripts\new-note.ps1 -Type project -Title "Arbiter Rollout"
  Creates 10-projects\project-arbiter-rollout.md

.EXAMPLE
  .\_meta\scripts\new-note.ps1 -Type meeting -Title "Weekly sync"
  Creates 50-meetings\meeting-20260901-weekly-sync.md
#>

param(
  [Parameter(Mandatory=$true)]
  [ValidateSet("project","person","meeting","decision","task","reference")]
  [string]$Type,

  [Parameter(Mandatory=$true)]
  [string]$Title,

  [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$folderMap = @{
  project   = "10-projects"
  person    = "40-people"
  meeting   = "50-meetings"
  decision  = "60-decisions"
  task      = "30-tasks"
  reference = "70-reference"
}
$datedTypes = @("meeting","decision","task")

function ConvertTo-Slug {
  param([string]$Text)
  $s = $Text.ToLower()
  $s = $s -replace "[^a-z0-9\s-]", ""
  $s = $s -replace "\s+", "-"
  $s = $s.Trim("-")
  return $s
}

$slug = ConvertTo-Slug -Text $Title
$today = Get-Date -Format "yyyy-MM-dd"
$dateSlug = Get-Date -Format "yyyyMMdd"

$templatePath = Join-Path $RootPath (Join-Path "_meta" (Join-Path "templates" "$Type.md"))
if (-not (Test-Path $templatePath)) {
  throw "No template found for type '$Type' at $templatePath"
}

if ($datedTypes -contains $Type) {
  $fileName = "$Type-$dateSlug-$slug.md"
} else {
  $fileName = "$Type-$slug.md"
}

$targetFolder = Join-Path $RootPath $folderMap[$Type]
$targetPath = Join-Path $targetFolder $fileName

if (Test-Path $targetPath) {
  throw "A note already exists at $targetPath — choose a different title or edit it directly."
}

$content = Get-Content -Path $templatePath -Raw
$content = $content -replace "\{\{SLUG\}\}", $slug
$content = $content -replace "\{\{DATESLUG\}\}", $dateSlug
$content = $content -replace "\{\{DATE\}\}", $today
$content = $content -replace "\{\{TITLE\}\}", $Title
$content = $content -replace "\{\{OWNER\}\}", (
  (Get-Content (Join-Path $RootPath (Join-Path "_meta" "config.json")) -Raw | ConvertFrom-Json).owner
)

New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null
Set-Content -Path $targetPath -Value $content -NoNewline
Write-Host "Created $targetPath" -ForegroundColor Green
