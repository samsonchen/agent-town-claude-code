<#
.SYNOPSIS
  Submits the Microsoft Store package built by release.ps1 -Store to Partner Center.

.DESCRIPTION
  Uses the Microsoft Store Developer CLI (msstore; winget install --id 9P53PC5S0PHJ --source msstore).
  This script holds no credentials and never asks for them: msstore keeps its own, set once by the
  user with "msstore reconfigure" in their own terminal (docs/windows/store.md, "Submitting with the
  script").

  The steps: check that msstore is configured, print the product's current submission status, then
  "msstore publish" the package app\windows\build\store\agent-town-<version>.msix (the version from
  project.godot). msstore replaces a pending draft submission with a new one copied from the last
  published submission, uploads the package and, without -Draft, commits it to certification.
  Listing text, screenshots, pricing and certification notes carry over from the last published
  submission.

  -Status only prints the current submission's status. -DeletePending deletes the pending submission
  first (msstore asks to confirm); use it when publish refuses because of a pending submission.

.EXAMPLE
    .\app\windows\scripts\store-submit.ps1 -Status          # what Partner Center has now
    .\app\windows\scripts\store-submit.ps1 -Draft           # upload, leave the submission as a draft
    .\app\windows\scripts\store-submit.ps1                  # upload and submit to certification
    .\app\windows\scripts\store-submit.ps1 -DeletePending   # delete the pending submission, then submit
#>
param(
  [switch]$Status,         # only print the current submission's status
  [switch]$Draft,          # upload but keep the submission as a draft (msstore --noCommit)
  [switch]$DeletePending,  # delete the pending submission first (msstore asks to confirm)
  [string]$Package         # the .msix to submit; default build\store\agent-town-<version>.msix
)

$ErrorActionPreference = 'Stop'
function Fail([string]$msg) { Write-Host "error: $msg" -ForegroundColor Red; exit 1 }
function Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

# The Store ID of "Agent-Town for Claude Code" (docs/windows/store.md). Not a secret.
$storeId = '9N0G35LW0LNK'

$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path   # app\windows

# -- msstore -----------------------------------------------------------------------------------
$msstore = Get-Command msstore -ErrorAction SilentlyContinue | Select-Object -First 1
# msstore writes its progress to stderr, which PowerShell 5.1 can turn into errors under 'Stop'.
function Invoke-MSStore { $ErrorActionPreference = 'Continue'; & $msstore.Source @args }
if (-not $msstore) {
  Fail 'msstore not found: winget install --id 9P53PC5S0PHJ --source msstore (then open a new terminal)'
}
& { $ErrorActionPreference = 'Continue'; Invoke-MSStore info *> $null }
if ($LASTEXITCODE -ne 0) {
  Write-Host 'msstore is not configured. In your own terminal (never in a script or a chat), run:' -ForegroundColor Yellow
  Write-Host '  msstore reconfigure --tenantId <tenant> --sellerId <seller> --clientId <client> --clientSecret <secret>'
  Write-Host 'See docs/windows/store.md, "Submitting with the script".'
  exit 1
}

Step "Current submission of $storeId"
Invoke-MSStore submission status $storeId
if ($LASTEXITCODE -ne 0) { Write-Host '(msstore could not read the submission status)' -ForegroundColor Yellow }
if ($Status) { exit 0 }

# -- Package -----------------------------------------------------------------------------------
$m = Select-String -Path (Join-Path $project 'project.godot') -Pattern '^config/version="([0-9]+(\.[0-9]+)+)"' | Select-Object -First 1
if (-not $m) { Fail 'no config/version in project.godot' }
$version = $m.Matches[0].Groups[1].Value
if (-not $Package) { $Package = Join-Path $project "build\store\agent-town-$version.msix" }
if (-not (Test-Path $Package)) { Fail "no package at ${Package}: build it with .\app\windows\scripts\release.ps1 -Store" }
$Package = (Resolve-Path $Package).Path
Write-Host "Package: $Package (project.godot says $version)"

# -- Pending submission ------------------------------------------------------------------------
if ($DeletePending) {
  Step 'Deleting the pending submission'
  Invoke-MSStore submission delete $storeId
  if ($LASTEXITCODE -ne 0) { Fail 'msstore could not delete the pending submission' }
}

# -- Publish -----------------------------------------------------------------------------------
$publishArgs = @('publish', (Split-Path $Package), '--inputFile', $Package, '--appId', $storeId)
if ($Draft) { $publishArgs += '--noCommit' }
Step ($(if ($Draft) { 'Uploading as a draft submission' } else { 'Uploading and submitting to certification' }))
Invoke-MSStore @publishArgs
if ($LASTEXITCODE -ne 0) {
  Fail 'msstore publish failed. If a pending submission is in the way, run again with -DeletePending.'
}

Step 'Done'
Invoke-MSStore submission status $storeId
if ($Draft) {
  Write-Host "`nThe submission is a draft. Submit it in Partner Center, or run this script again without -Draft."
} else {
  Write-Host "`nSubmitted. Certification usually takes from a few hours to a few days; -Status shows where it is."
}
