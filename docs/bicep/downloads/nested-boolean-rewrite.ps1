param(
    [string] $InfraPath = (Join-Path $PSScriptRoot '..\infra')
)

# Optional helper for scripts/preProvision.ps1 or scripts/preProvision.sh.
# Call this after main.parameters.json has been copied into infra/.
# Replace publicIngress.value.enabled and PUBLIC_INGRESS_ENABLED with the field and environment variable used by your accelerator.

$parametersPath = Join-Path $InfraPath 'main.parameters.json'
$parameters = Get-Content $parametersPath -Raw | ConvertFrom-Json

if ($parameters.parameters.PSObject.Properties.Name -contains 'publicIngress') {
    $enabled = if ([string]::IsNullOrWhiteSpace($env:PUBLIC_INGRESS_ENABLED)) {
        $false
    } else {
        [bool]::Parse($env:PUBLIC_INGRESS_ENABLED)
    }

    $parameters.parameters.publicIngress.value.enabled = $enabled
    $parameters | ConvertTo-Json -Depth 100 | Set-Content $parametersPath
}
