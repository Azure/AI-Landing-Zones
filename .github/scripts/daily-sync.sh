#!/usr/bin/env bash
set -euo pipefail

HAVE_JQ=0
if command -v jq >/dev/null 2>&1; then
  HAVE_JQ=1
fi

# Extract a top-level field from JSON read from stdin.
json_stdin_field() {
  local field="$1"
  if [[ "$HAVE_JQ" -eq 1 ]]; then
    jq -r --arg f "$field" '.[$f] // empty'
  else
    python -c "import json,sys; field=sys.argv[1]; data=json.load(sys.stdin); value=data.get(field, ''); print('' if value is None else value)" "$field"
  fi
}

get_current_tag() {
  if [[ "$HAVE_JQ" -eq 1 ]]; then
    jq -r '.variables.releaseTag // empty' "$PORTAL_TEMPLATE"
  else
    python - "$PORTAL_TEMPLATE" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding='utf-8') as f:
    data = json.load(f)
print(((data.get('variables') or {}).get('releaseTag')) or '')
PY
  fi
}

get_portal_params() {
  if [[ "$HAVE_JQ" -eq 1 ]]; then
    jq -r '.parameters | keys[]' "$PORTAL_TEMPLATE" | sort
  else
    python - "$PORTAL_TEMPLATE" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding='utf-8') as f:
    data = json.load(f)
for k in sorted((data.get('parameters') or {}).keys()):
    print(k)
PY
  fi
}

get_form_regions() {
  if [[ "$HAVE_JQ" -eq 1 ]]; then
    jq -r '
      (((.view.properties.steps // .steps) // [])[0].elements[0]) as $scope
      | (($scope.location.allowedValues // $scope.resourceScope.location.allowedValues) // [])[]
    ' "$PORTAL_FORM" 2>/dev/null | sort
  else
    python - "$PORTAL_FORM" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding='utf-8') as f:
    data = json.load(f)

steps = (((data.get('view') or {}).get('properties') or {}).get('steps')) or data.get('steps') or []
regions = []
if steps and isinstance(steps, list):
    elements = (steps[0] or {}).get('elements') or []
    if elements:
        scope = elements[0] or {}
        location = (scope.get('location') or ((scope.get('resourceScope') or {}).get('location')) or {})
        regions = location.get('allowedValues') or []

for r in sorted(regions):
    print(r)
PY
  fi
}

# =============================================================================
# Daily Portal-Bicep Sync Check
#
# Compares the upstream Bicep repo's latest release against the portal
# template's releaseTag. When a new release is detected, downloads the
# upstream main.bicep, diffs parameters, and creates GitHub Issues for
# changes that require human UI decisions.
#
# Environment variables (set by the workflow):
#   UPSTREAM_API      — GitHub API URL for the upstream repo
#   PORTAL_TEMPLATE   — path to portal/template.json
#   PORTAL_FORM       — path to portal/form.json
#   SYNC_LABEL        — label for sync issues
#   UI_LABEL          — label for UI-decision issues
#   GH_TOKEN          — GitHub token (provided by actions/checkout)
# =============================================================================

UPSTREAM_API="${UPSTREAM_API:-https://api.github.com/repos/Azure/bicep-ptn-aiml-landing-zone}"
PORTAL_TEMPLATE="${PORTAL_TEMPLATE:-portal/template.json}"
PORTAL_FORM="${PORTAL_FORM:-portal/form.json}"
SYNC_LABEL="${SYNC_LABEL:-portal-sync}"
UI_LABEL="${UI_LABEL:-ui-decision}"

# Static region list — update manually when Azure adds new region support
# for all required services (AI Services, AI Search, Container Apps,
# Cosmos DB, Container Registry, App Configuration, Key Vault, and zonal Compute).
SUPPORTED_REGIONS=(
  australiaeast
  eastus
  francecentral
  germanywestcentral
  japaneast
  koreacentral
  norwayeast
  polandcentral
  southafricanorth
  southeastasia
  spaincentral
  swedencentral
  switzerlandnorth
  uaenorth
  uksouth
)

# -----------------------------------------------------------------------------
# Region validation function (defined early so it can be called on early exit)
# -----------------------------------------------------------------------------
validate_regions() {
  echo ""
  echo "--- Region Validation ---"

  FORM_REGIONS=$(get_form_regions | tr -d '\r')

  STATIC_REGIONS=$(printf '%s\n' "${SUPPORTED_REGIONS[@]}" | sort | tr -d '\r')

  REGION_DIFF=$(diff <(echo "$FORM_REGIONS") <(echo "$STATIC_REGIONS") || true)

  if [[ -n "$REGION_DIFF" ]]; then
    echo "⚠️  Region list mismatch between form.json and static list in daily-sync.sh"
    echo "$REGION_DIFF"
    echo "::warning::Region list in form.json does not match the static supported regions list. Update one or the other."
  else
    echo "✅ Region list in form.json matches static list (${#SUPPORTED_REGIONS[@]} regions)"
  fi
}

# -----------------------------------------------------------------------------
# Step 1: Get current portal releaseTag
# -----------------------------------------------------------------------------
CURRENT_TAG=$(get_current_tag)
if [[ -z "$CURRENT_TAG" ]]; then
  echo "::error::Could not read releaseTag from $PORTAL_TEMPLATE"
  exit 1
fi
echo "Current portal releaseTag: $CURRENT_TAG"

# -----------------------------------------------------------------------------
# Step 2: Get latest upstream release
# -----------------------------------------------------------------------------
LATEST_RELEASE=$(curl -sf "${UPSTREAM_API}/releases/latest" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28")

LATEST_TAG=$(echo "$LATEST_RELEASE" | json_stdin_field 'tag_name')
LATEST_DATE=$(echo "$LATEST_RELEASE" | json_stdin_field 'published_at')
LATEST_URL=$(echo "$LATEST_RELEASE" | json_stdin_field 'html_url')

if [[ -z "$LATEST_TAG" ]]; then
  echo "::error::Could not fetch latest release from upstream"
  exit 1
fi
echo "Latest upstream release: $LATEST_TAG (published: $LATEST_DATE)"

# -----------------------------------------------------------------------------
# Step 3: Compare versions
# -----------------------------------------------------------------------------
if [[ "$CURRENT_TAG" == "$LATEST_TAG" ]]; then
  echo "✅ Portal is up to date with upstream ($CURRENT_TAG)"
  # Still run region validation even when in sync
  validate_regions
  exit 0
fi

echo "⚠️  Version drift detected: portal=$CURRENT_TAG upstream=$LATEST_TAG"

# -----------------------------------------------------------------------------
# Step 4: Download upstream main.bicep for parameter comparison
# -----------------------------------------------------------------------------
UPSTREAM_RAW="https://raw.githubusercontent.com/Azure/bicep-ptn-aiml-landing-zone/refs/tags/${LATEST_TAG}"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

curl -sf "${UPSTREAM_RAW}/main.bicep" -o "${TMPDIR}/main.bicep" || {
  echo "::warning::Could not download main.bicep from ${LATEST_TAG}"
}

# -----------------------------------------------------------------------------
# Step 5: Extract upstream parameters (grep-based extraction from Bicep)
# -----------------------------------------------------------------------------
UPSTREAM_PARAMS=""
if [[ -f "${TMPDIR}/main.bicep" ]]; then
  UPSTREAM_PARAMS=$(grep -E '^param ' "${TMPDIR}/main.bicep" | \
    sed 's/param \([a-zA-Z0-9_]*\).*/\1/' | sort)
fi

# Extract portal template parameters
PORTAL_PARAMS=$(get_portal_params)

# -----------------------------------------------------------------------------
# Step 6: Compute diffs
# -----------------------------------------------------------------------------
NEW_PARAMS=""
REMOVED_PARAMS=""

if [[ -n "$UPSTREAM_PARAMS" ]]; then
  NEW_PARAMS=$(comm -23 <(echo "$UPSTREAM_PARAMS") <(echo "$PORTAL_PARAMS") || true)
  REMOVED_PARAMS=$(comm -13 <(echo "$UPSTREAM_PARAMS") <(echo "$PORTAL_PARAMS") || true)
fi

# -----------------------------------------------------------------------------
# Step 7: Dedup helper — check for existing open issues
# -----------------------------------------------------------------------------
dedup_check() {
  local search_term="$1"
  local count
  count=$(gh issue list --label "$SYNC_LABEL" --state open \
    --search "$search_term" --json number --jq 'length')
  [[ "$count" -gt 0 ]]
}

# -----------------------------------------------------------------------------
# Step 8: Create version drift issue if none exists
# -----------------------------------------------------------------------------
DRIFT_TITLE="[Portal Sync] New upstream release ${LATEST_TAG} (current: ${CURRENT_TAG})"

if ! dedup_check "New upstream release ${LATEST_TAG}"; then
  # Build the parameter diff section
  PARAM_SECTION=""
  if [[ -n "$NEW_PARAMS" ]]; then
    PARAM_SECTION+=$'\n### New Upstream Parameters\n'
    PARAM_SECTION+=$'\nThese parameters exist in the upstream Bicep but not in the portal template:\n\n'
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      PARAM_SECTION+="- \`${p}\`"$'\n'
    done <<< "$NEW_PARAMS"
  fi

  if [[ -n "$REMOVED_PARAMS" ]]; then
    PARAM_SECTION+=$'\n### Parameters Only in Portal\n'
    PARAM_SECTION+=$'\nThese parameters exist in the portal template but not upstream (may be portal-specific or renamed):\n\n'
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      PARAM_SECTION+="- \`${p}\`"$'\n'
    done <<< "$REMOVED_PARAMS"
  fi

  if [[ -z "$NEW_PARAMS" && -z "$REMOVED_PARAMS" ]]; then
    PARAM_SECTION=$'\n### Parameter Diff\n\nNo new or removed parameters detected (parameter names unchanged). Review the release notes for value/type changes.\n'
  fi

  BODY=$(cat <<ISSUE_BODY
## Upstream Release Detected

| Field | Value |
|-------|-------|
| **Upstream Release** | [${LATEST_TAG}](${LATEST_URL}) |
| **Published** | ${LATEST_DATE} |
| **Current Portal Tag** | ${CURRENT_TAG} |
| **Upstream Repo** | [Azure/bicep-ptn-aiml-landing-zone](https://github.com/Azure/bicep-ptn-aiml-landing-zone) |

${PARAM_SECTION}

## Triage Checklist

For each change in the release, classify and act:

- [ ] Review [release notes](${LATEST_URL}) for breaking changes
- [ ] Identify new parameters that need Portal UI controls (creates sub-issues)
- [ ] Identify infrastructure/logic changes (auto-resolvable)
- [ ] Identify features to skip (add to \`bicep-only-no-portal.md\`)
- [ ] Check if AVM wrappers need recompilation
- [ ] Update \`releaseTag\` in \`template.json\` to \`${LATEST_TAG}\`

## 🤖 Agent Instructions

When this issue is triaged, implement the following:

**Scope:** Full sync from \`${CURRENT_TAG}\` → \`${LATEST_TAG}\`
**Files to review:** \`portal/template.json\`, \`portal/form.json\`, \`portal/wrappers/\`
**Upstream diff:** \`https://github.com/Azure/bicep-ptn-aiml-landing-zone/compare/${CURRENT_TAG}...${LATEST_TAG}\`

### Steps
1. Download and diff \`main.bicep\` between \`${CURRENT_TAG}\` and \`${LATEST_TAG}\`
2. For each new parameter, determine if it is backend-only or user-facing
3. Apply backend-only changes directly to \`template.json\`
4. For user-facing parameters, check for sub-issues labeled \`${UI_LABEL}\` with decisions
5. Recompile any AVM wrappers whose source modules were updated
6. Update \`releaseTag\` to \`${LATEST_TAG}\`
7. Run the quality checklist from \`.github/copilot-instructions.md\`
8. Update \`PORTAL_BICEP_ALIGNMENT_ANALYSIS.md\`

### Acceptance Criteria
- [ ] All auto-resolvable changes applied
- [ ] UI-decision sub-issues created for user-facing parameters
- [ ] \`releaseTag\` updated
- [ ] No broken \`dependsOn\` references
- [ ] All linked template URIs valid
ISSUE_BODY
  )

  gh issue create \
    --title "$DRIFT_TITLE" \
    --body "$BODY" \
    --label "${SYNC_LABEL}" \
    --label "${UI_LABEL}"

  echo "📋 Created version drift issue: $DRIFT_TITLE"
else
  echo "ℹ️  Version drift issue already exists for ${LATEST_TAG}"
fi

# -----------------------------------------------------------------------------
# Step 9: Create individual issues for new upstream parameters
# -----------------------------------------------------------------------------
if [[ -n "$NEW_PARAMS" ]]; then
  while IFS= read -r PARAM; do
    [[ -z "$PARAM" ]] && continue

    PARAM_TITLE="[Portal Sync] New parameter: ${PARAM} (${LATEST_TAG})"

    if dedup_check "New parameter: ${PARAM}"; then
      echo "ℹ️  Issue already exists for parameter: ${PARAM}"
      continue
    fi

    PARAM_BODY=$(cat <<PARAM_ISSUE
## New Upstream Parameter

| Field | Value |
|-------|-------|
| **Parameter** | \`${PARAM}\` |
| **Source Release** | [${LATEST_TAG}](${LATEST_URL}) |
| **Current Portal Tag** | ${CURRENT_TAG} |

## Decision Required

This parameter was added in the upstream Bicep source but does not yet exist in the portal deployment. Please decide:

1. **Is this user-facing?** Should it appear in the Portal wizard?
2. **Which wizard step?** (Basics, AI Configuration, DevOps, Networking, Security, Monitoring, Advanced)
3. **What UI control?** (OptionsGroup Yes/No, DropDown, TextBox, etc.)
4. **Visibility rules?** Always visible, or gated by a toggle?
5. **Should it be skipped?** Add to \`bicep-only-no-portal.md\` instead?

## 🤖 Agent Instructions

When the user comments their decision on this issue, implement the following:

**Files to modify:** \`portal/form.json\`, \`portal/template.json\`
**Upstream source:** \`Azure/bicep-ptn-aiml-landing-zone\` ${LATEST_TAG}
**Parameter name:** \`${PARAM}\`

### If user-facing (add to form):
1. Add a \`Microsoft.Common.*\` UI control to the specified wizard step in \`form.json\`
2. Add the parameter to \`template.json\` with the correct type and default
3. Wire the form output to the template parameter
4. Add visibility condition if specified
5. Test in Portal Sandbox: https://portal.azure.com/#view/Microsoft_Azure_CreateUIDef/SandboxBlade

### If backend-only (no form change):
1. Add the parameter to \`template.json\` with a safe default value
2. No changes to \`form.json\`

### If skipped:
1. Add entry to \`bicep-only-no-portal.md\` with category and justification
2. Close this issue

### Acceptance Criteria
- [ ] Parameter integrated or documented as skipped
- [ ] Form validates in Portal Sandbox (if form change)
- [ ] No broken parameter references
PARAM_ISSUE
    )

    gh issue create \
      --title "$PARAM_TITLE" \
      --body "$PARAM_BODY" \
      --label "${SYNC_LABEL}" \
      --label "${UI_LABEL}"

    echo "📋 Created parameter issue: ${PARAM}"
  done <<< "$NEW_PARAMS"
fi

# -----------------------------------------------------------------------------
# Step 10: Validate static region list against form.json
# -----------------------------------------------------------------------------
validate_regions

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "=== Daily Sync Check Complete ==="
echo "Portal:   ${CURRENT_TAG}"
echo "Upstream: ${LATEST_TAG}"
echo "Status:   $([ "$CURRENT_TAG" == "$LATEST_TAG" ] && echo 'IN SYNC' || echo 'DRIFT DETECTED')"
