<#
.SYNOPSIS
  Bootstraps a new Cortex instance from this template.

.PARAMETER InstanceName
  e.g. "work-cortex" or "personal-cortex". Used for {{INSTANCE_NAME}} tokens and
  as the default Git repo folder name.

.PARAMETER Owner
  Your name, used for {{OWNER}} tokens and _meta/config.json.

.PARAMETER Profile
  "work" or "personal". Used for {{PROFILE}} tokens.

.PARAMETER Classification
  Free-text classification note, e.g. "Internal - personal work notes, no
  secrets, no customer PII beyond redacted references."

.PARAMETER TargetPath
  Where to create the instance. Recommended: a plain local path outside any
  cloud-synced folder (see -BackupDestination for how backups are handled instead).

.PARAMETER BackupDestination
  Optional. A cloud-synced folder (or other externally-backed-up location) that
  _meta/scripts/backup.ps1 will write snapshots to by default. Recorded in
  _meta/config.json -> backupDestination. Can be left blank and supplied later,
  or overridden per-invocation with backup.ps1 -DestinationPath.

.PARAMETER Timezone
  IANA or Windows timezone label used for {{TIMEZONE}} tokens.

.PARAMETER Remote
  Optional Git remote URL to set as 'origin' after init.

.EXAMPLE
  .\init.ps1 -InstanceName "work-cortex" -Owner "Karlo" -Profile work `
             -Classification "Internal - personal work notes" `
             -TargetPath "C:\Users\karlom\Cortex\work-cortex" `
             -BackupDestination "C:\Users\karlom\OneDrive - Microsoft\CortexBackups\work-cortex" `
             -Timezone "Eastern Standard Time"
#>

param(
  [Parameter(Mandatory=$true)] [string]$InstanceName,
  [Parameter(Mandatory=$true)] [string]$Owner,
  [Parameter(Mandatory=$true)] [ValidateSet("work","personal")] [string]$Profile,
  [string]$Classification = "Unclassified - set this before adding real content",
  [Parameter(Mandatory=$true)] [string]$TargetPath,
  [string]$BackupDestination = "",
  [string]$Timezone = "UTC",
  [string]$Remote
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot
$templateSource = Join-Path $repoRoot "template"

if (Test-Path $TargetPath) {
  throw "TargetPath already exists: $TargetPath. Choose a new location or remove it first."
}

Write-Host "Creating instance '$InstanceName' at $TargetPath ..." -ForegroundColor Cyan
Copy-Item -Path $templateSource -Destination $TargetPath -Recurse

$today = Get-Date -Format "yyyy-MM-dd"
$changelogPath = Join-Path $repoRoot "CHANGELOG.md"
$templateVersion = "0.1.0"
if (Test-Path $changelogPath) {
  $firstVersionLine = (Get-Content $changelogPath | Where-Object { $_ -match '^\#\# \[' } | Select-Object -First 1)
  if ($firstVersionLine -match '\[(.+?)\]') { $templateVersion = $matches[1] }
}

$tokenMap = @{
  "{{INSTANCE_NAME}}"      = $InstanceName
  "{{OWNER}}"              = $Owner
  "{{PROFILE}}"            = $Profile
  "{{CLASSIFICATION}}"     = $Classification
  "{{CREATED_DATE}}"       = $today
  "{{TEMPLATE_VERSION}}"   = $templateVersion
  "{{TIMEZONE}}"           = $Timezone
  "{{BACKUP_DESTINATION}}" = $BackupDestination
}

$filesToStamp = @(
  "README.md",
  "AGENTS.md",
  (Join-Path ".github" "copilot-instructions.md"),
  (Join-Path ".github" "github-app.yml")
) | ForEach-Object { Join-Path $TargetPath $_ } | Where-Object { Test-Path $_ }

foreach ($f in $filesToStamp) {
  $content = Get-Content -Path $f -Raw
  foreach ($token in $tokenMap.Keys) {
    $content = $content -replace [regex]::Escape($token), $tokenMap[$token]
  }
  Set-Content -Path $f -Value $content -NoNewline
}

$configTemplatePath = Join-Path $TargetPath (Join-Path "_meta" "config.json.template")
$configPath = Join-Path $TargetPath (Join-Path "_meta" "config.json")
$configContent = Get-Content -Path $configTemplatePath -Raw
foreach ($token in $tokenMap.Keys) {
  $jsonSafeValue = $tokenMap[$token] -replace '\\', '\\'
  $configContent = $configContent -replace [regex]::Escape($token), $jsonSafeValue
}
Set-Content -Path $configPath -Value $configContent -NoNewline
Remove-Item $configTemplatePath

# README.md doesn't ship a per-instance stub; write a minimal one pointing at AGENTS.md.
$instanceReadme = @"
# $InstanceName

A Cortex instance for $Owner ($Profile). See AGENTS.md for agent roles and
write rules, and .github/copilot-instructions.md for how AI tools should use
this repository. Generated from cortex-core v$templateVersion on $today.
"@
Set-Content -Path (Join-Path $TargetPath "README.md") -Value $instanceReadme

Push-Location $TargetPath
try {
  git init -b main | Out-Null
  if ($Remote) {
    git remote add origin $Remote
  }
  git add -A
  git commit -m "Initialize $InstanceName from cortex-core v$templateVersion" | Out-Null
  Write-Host "Instance created and committed at $TargetPath" -ForegroundColor Green
  if ($Remote) {
    Write-Host "Remote 'origin' set to $Remote - push when ready: git push -u origin main" -ForegroundColor Cyan
  }
  if ([string]::IsNullOrWhiteSpace($BackupDestination)) {
    Write-Host "No -BackupDestination set. Set _meta/config.json -> backupDestination later, or pass -DestinationPath explicitly to backup.ps1." -ForegroundColor Yellow
  } else {
    Write-Host "Backups will default to: $BackupDestination (run _meta/scripts/backup.ps1 to snapshot)" -ForegroundColor Cyan
  }
} finally {
  Pop-Location
}
