#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

INFRA_PATH="infra"
SUBMODULE_URL="$(git config -f .gitmodules --get "submodule.${INFRA_PATH}.url" || true)"
SUBMODULE_TAG="$(git config -f .gitmodules --get "submodule.${INFRA_PATH}.branch" || true)"

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

# Prefer typed Bicep bool parameters. For legacy nested object contracts only,
# invoke the compatibility helper here after adapting it.
# pwsh -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/nested-boolean-rewrite.ps1" -InfraPath "$INFRA_PATH"

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
