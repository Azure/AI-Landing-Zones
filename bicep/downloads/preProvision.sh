#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

INFRA_PATH="infra"
SUBMODULE_URL="$(git config -f .gitmodules --get "submodule.${INFRA_PATH}.url" || true)"
SUBMODULE_TAG="$(git config -f .gitmodules --get "submodule.${INFRA_PATH}.branch" || true)"
NESTED_BOOLEAN_REWRITES='[]'
# Example for legacy object parameters:
# NESTED_BOOLEAN_REWRITES='[
#   {
#     "parameter": "publicIngress",
#     "propertyPath": ["enabled"],
#     "environmentVariable": "PUBLIC_INGRESS_ENABLED",
#     "default": false
#   }
# ]'

normalize_nested_booleans() {
  if [ "$NESTED_BOOLEAN_REWRITES" = "[]" ]; then
    return 0
  fi

  if ! command -v pwsh >/dev/null 2>&1; then
    echo "PowerShell (pwsh) is required to normalize nested boolean parameters."
    exit 1
  fi

  export NESTED_BOOLEAN_REWRITES
  pwsh -NoProfile -ExecutionPolicy Bypass -Command '
    param([string] $ParametersPath)

    $rules = $env:NESTED_BOOLEAN_REWRITES | ConvertFrom-Json
    if ($null -eq $rules -or $rules.Count -eq 0) {
      return
    }

    $parameters = Get-Content $ParametersPath -Raw | ConvertFrom-Json

    foreach ($rule in @($rules)) {
      $parameterName = $rule.parameter
      $propertyPath = @($rule.propertyPath)
      $environmentVariable = $rule.environmentVariable
      $defaultValue = [bool] $rule.default

      if (-not ($parameters.parameters.PSObject.Properties.Name -contains $parameterName)) {
        throw "Cannot normalize nested boolean: parameter $parameterName does not exist in $ParametersPath."
      }

      $target = $parameters.parameters.$parameterName.value
      if ($propertyPath.Count -gt 1) {
        foreach ($segment in $propertyPath[0..($propertyPath.Count - 2)]) {
          if (-not ($target.PSObject.Properties.Name -contains $segment)) {
            throw "Cannot normalize nested boolean: property $segment does not exist under parameter $parameterName."
          }
          $target = $target.$segment
        }
      }

      $leafProperty = $propertyPath[-1]
      if (-not ($target.PSObject.Properties.Name -contains $leafProperty)) {
        throw "Cannot normalize nested boolean: property $leafProperty does not exist under parameter $parameterName."
      }

      $rawValue = [Environment]::GetEnvironmentVariable($environmentVariable)
      $target.$leafProperty = if ([string]::IsNullOrWhiteSpace($rawValue)) {
        $defaultValue
      } else {
        [bool]::Parse($rawValue)
      }
    }

    $parameters | ConvertTo-Json -Depth 100 | Set-Content $ParametersPath
  ' "$INFRA_PATH/main.parameters.json"
}

if [ -z "$SUBMODULE_URL" ] || [ -z "$SUBMODULE_TAG" ]; then
  echo "Missing infra submodule url or branch in .gitmodules."
  exit 1
fi

if [ ! -f "$INFRA_PATH/main.bicep" ] && [ -d ".git" ]; then
  echo "Initializing infrastructure submodule..."
  git submodule update --init --recursive "$INFRA_PATH"
fi

if [ ! -f "$INFRA_PATH/main.bicep" ]; then
  echo "Cloning AI Landing Zone into $INFRA_PATH..."
  rm -rf "$INFRA_PATH"
  git clone "$SUBMODULE_URL" "$INFRA_PATH"
fi

echo "Pinning $INFRA_PATH to '$SUBMODULE_TAG'..."
git -C "$INFRA_PATH" fetch --tags
git -C "$INFRA_PATH" checkout "$SUBMODULE_TAG"

if [ ! -f "main.parameters.json" ]; then
  echo "Missing root main.parameters.json."
  exit 1
fi

echo "Applying accelerator main.parameters.json to infra..."
cp "main.parameters.json" "$INFRA_PATH/main.parameters.json"
normalize_nested_booleans

if [ -f "manifest.json" ]; then
  cp "manifest.json" "$INFRA_PATH/manifest.json"
fi

# Add accelerator-specific validation here if needed.

if [ "${PREFLIGHT_SKIP:-false}" = "true" ]; then
  echo "Skipping preflight checks because PREFLIGHT_SKIP=true."
  exit 0
fi

if ! command -v pwsh >/dev/null 2>&1; then
  echo "PowerShell (pwsh) is required to run AI Landing Zone preflight checks."
  exit 1
fi

echo "Running AI Landing Zone preflight checks..."
pwsh -NoProfile -ExecutionPolicy Bypass -File "$INFRA_PATH/scripts/Invoke-PreflightChecks.ps1"
