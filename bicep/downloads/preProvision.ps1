$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$infraPath = 'infra'

function Get-GitModulesValue {
    param([string] $Key)

    $value = git config -f .gitmodules --get "submodule.$infraPath.$Key"
    if (-not $value) {
        throw "Missing submodule.$infraPath.$Key in .gitmodules."
    }

    return $value
}

$submoduleUrl = Get-GitModulesValue -Key 'url'
$submoduleTag = Get-GitModulesValue -Key 'branch'
$mainBicepPath = Join-Path $infraPath 'main.bicep'

if (-not (Test-Path $mainBicepPath) -and (Test-Path '.git')) {
    Write-Host 'Initializing infrastructure submodule...'
    git submodule update --init --recursive $infraPath
}

if (-not (Test-Path $mainBicepPath)) {
    Write-Host "Cloning AI Landing Zone into $infraPath..."
    if (Test-Path $infraPath) {
        Remove-Item -Recurse -Force $infraPath
    }

    git clone $submoduleUrl $infraPath
}

Write-Host "Pinning $infraPath to '$submoduleTag'..."
git -C $infraPath fetch --tags
git -C $infraPath checkout $submoduleTag

if (-not (Test-Path 'main.parameters.json')) {
    throw 'Missing root main.parameters.json.'
}

Write-Host 'Applying accelerator main.parameters.json to infra...'
Copy-Item 'main.parameters.json' (Join-Path $infraPath 'main.parameters.json') -Force

# Prefer typed Bicep bool parameters. For legacy nested object contracts only,
# invoke the compatibility helper here after adapting it.
# & (Join-Path $PSScriptRoot 'nested-boolean-rewrite.ps1') -InfraPath $infraPath

if (Test-Path 'manifest.json') {
    Copy-Item 'manifest.json' (Join-Path $infraPath 'manifest.json') -Force
}

# Add accelerator-specific validation here if needed.

if ($env:PREFLIGHT_SKIP -eq 'true') {
    Write-Host 'Skipping preflight checks because PREFLIGHT_SKIP=true.'
    exit 0
}

Write-Host 'Running AI Landing Zone preflight checks...'
& (Join-Path $infraPath 'scripts/Invoke-PreflightChecks.ps1')
