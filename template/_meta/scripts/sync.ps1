<#
.SYNOPSIS
  Syncs _meta/ scaffolding between a Cortex instance and the cortex-template
  upstream repository. Content folders (00-inbox..90-archive, assets/) are never
  touched by this script in either direction.

.PARAMETER Pull
  Pull the latest _meta/ scaffolding (schemas, templates, scripts, AGENTS.md,
  .github/copilot-instructions.md) from the template remote into this instance.
  Existing instance content in _meta/config.json is preserved; only the shared
  scaffolding files are updated.

.PARAMETER Push
  Copy a specific improved file from this instance back into a local clone of
  the template repo, so you can review and commit it upstream deliberately.
  Requires -File and -TemplateRepoPath.

.PARAMETER TemplateRemoteUrl
  URL of the cortex-template repository. Only needed the first time (adds a
  'template' remote) or if it has changed.

.PARAMETER TemplateRepoPath
  Local path to a clone of cortex-template, used for -Push.

.PARAMETER File
  Repo-relative path of the single file to push upstream, e.g.
  "_meta/templates/meeting.md".

.EXAMPLE
  .\_meta\scripts\sync.ps1 -Pull -TemplateRemoteUrl "https://github.com/you/cortex-template.git"

.EXAMPLE
  .\_meta\scripts\sync.ps1 -Push -File "_meta/scripts/validate.ps1" -TemplateRepoPath "C:\Code\cortex-template"
#>

param(
  [switch]$Pull,
  [switch]$Push,
  [string]$TemplateRemoteUrl,
  [string]$TemplateRepoPath,
  [string]$File,
  [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

if (-not $Pull -and -not $Push) {
  throw "Specify -Pull or -Push."
}

if ($Pull) {
  Push-Location $RootPath
  try {
    $hasRemote = (git remote) -contains "template"
    if (-not $hasRemote) {
      if (-not $TemplateRemoteUrl) { throw "First pull requires -TemplateRemoteUrl to add the 'template' remote." }
      git remote add template $TemplateRemoteUrl
    }
    git fetch template

    # Pull only the template/_meta -> ./_meta mapping via a scoped checkout,
    # avoiding git subtree dependency issues by checking out specific paths.
    $paths = @("template/_meta", "template/AGENTS.md", "template/.github")
    foreach ($p in $paths) {
      git checkout template/main -- $p
    }
    if (Test-Path (Join-Path $RootPath "template")) {
      # The checkout above recreates the 'template/' prefix; flatten it into root.
      Copy-Item -Path (Join-Path $RootPath "template\*") -Destination $RootPath -Recurse -Force
      Remove-Item -Path (Join-Path $RootPath "template") -Recurse -Force
    }
    Write-Host "Pulled latest _meta/, AGENTS.md, .github/ from template remote. Review 'git status' and commit." -ForegroundColor Green
  } finally {
    Pop-Location
  }
}

if ($Push) {
  if (-not $File -or -not $TemplateRepoPath) {
    throw "-Push requires both -File and -TemplateRepoPath."
  }
  $source = Join-Path $RootPath $File
  if (-not (Test-Path $source)) { throw "File not found in instance: $source" }

  $destRelative = $File -replace '^_meta', 'template/_meta' -replace '^AGENTS\.md$', 'template/AGENTS.md' -replace '^\.github', 'template/.github'
  $destination = Join-Path $TemplateRepoPath $destRelative
  New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
  Copy-Item -Path $source -Destination $destination -Force
  Write-Host "Copied $File into template repo at $destination. Review, commit, and push from the template repo." -ForegroundColor Green
}
