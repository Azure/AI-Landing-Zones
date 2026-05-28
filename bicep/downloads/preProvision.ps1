$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$infraPath = 'infra'

$nestedBooleanRewrites = @(
    # Example for legacy object parameters:
    # @{
    #     Parameter = 'publicIngress'
    #     PropertyPath = @('enabled')
    #     EnvironmentVariable = 'PUBLIC_INGRESS_ENABLED'
    #     Default = $false
    # }
)

function Get-GitModulesValue {
    param([string] $Key)

    $value = git config -f .gitmodules --get "submodule.$infraPath.$Key"
    if (-not $value) {
        throw "Missing submodule.$infraPath.$Key in .gitmodules."
    }

    return $value
}

function Set-NestedBooleanParameters {
    param(
        [string] $ParametersPath,
        [object[]] $Rules
    )

    if (-not $Rules -or $Rules.Count -eq 0) {
        return
    }

    $parameters = Get-Content $ParametersPath -Raw | ConvertFrom-Json

    foreach ($rule in $Rules) {
        $parameterName = $rule['Parameter']
        $propertyPath = @($rule['PropertyPath'])
        $environmentVariable = $rule['EnvironmentVariable']
        $defaultValue = [bool] $rule['Default']

        if (-not ($parameters.parameters.PSObject.Properties.Name -contains $parameterName)) {
            throw "Cannot normalize nested boolean: parameter '$parameterName' does not exist in $ParametersPath."
        }

        $target = $parameters.parameters.$parameterName.value
        if ($propertyPath.Count -gt 1) {
            foreach ($segment in $propertyPath[0..($propertyPath.Count - 2)]) {
                if (-not ($target.PSObject.Properties.Name -contains $segment)) {
                    throw "Cannot normalize nested boolean: property '$segment' does not exist under parameter '$parameterName'."
                }
                $target = $target.$segment
            }
        }

        $leafProperty = $propertyPath[-1]
        if (-not ($target.PSObject.Properties.Name -contains $leafProperty)) {
            throw "Cannot normalize nested boolean: property '$leafProperty' does not exist under parameter '$parameterName'."
        }

        $rawValue = [Environment]::GetEnvironmentVariable($environmentVariable)
        $target.$leafProperty = if ([string]::IsNullOrWhiteSpace($rawValue)) {
            $defaultValue
        } else {
            [bool]::Parse($rawValue)
        }
    }

    $parameters | ConvertTo-Json -Depth 100 | Set-Content $ParametersPath
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
$parametersPath = Join-Path $infraPath 'main.parameters.json'
Copy-Item 'main.parameters.json' $parametersPath -Force
Set-NestedBooleanParameters -ParametersPath $parametersPath -Rules $nestedBooleanRewrites

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
