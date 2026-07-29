# Portal ↔ Bicep Alignment Analysis

**Date:** 2026-07-28  
**Upstream Bicep version:** v2.3.0 (2026-07-02)  
**Portal releaseTag (before):** v1.0.7  
**Portal releaseTag (after):** v2.0.12  

---

## Phase 1 — Automatic Fixes Applied

### 1. `releaseTag` updated: `v1.0.7` → `v2.0.12`

**File:** `portal/template.json` (line 438)  
**Impact:** VM Custom Script Extension now fetches `install.ps1` from v2.0.12, which includes:
- Watchdog/timeout fixes (v2.0.9)
- `AZD_SKIP_FIRST_RUN=true` optimization (v2.0.12)
- Manifest reference alignment (v2.0.10)

### 2. Cosmos DB RBAC Scope Narrowed to Database Level

**File:** `portal/template.json` — two role assignments updated  
**Deployments fixed:**
- `vmCosmosRoleAssignment-JumpVm` (line ~3353)
- `vmCosmosRoleAssignment-BuildVm` (line ~3525)

**Before:** `[resourceId('Microsoft.DocumentDB/databaseAccounts', ...)]` (account-level)  
**After:** `[concat(resourceId('Microsoft.DocumentDB/databaseAccounts', ...), '/dbs/', variables('cosmosDbDatabaseName'))]` (database-level)  
**Rationale:** Aligns with Bicep v2.0.4 least-privilege fix. Container App assignment was already correct.

---

## Phase 1 — Items Confirmed Not Applicable

| # | Item | Reason |
|---|------|--------|
| 1 | Subnet delegation casing | Portal already uses correct `Microsoft.App/environments` |
| 3 | PE emission empty-string guard | Portal uses separate PE linked templates, not the same conditional pattern |
| 7 | Firewall empty FQDNs | Portal deploys firewall policy without rule collection groups |
| 8 | Container App → Firewall dependency | No UDR/forced-tunnel on ACA subnet; firewall not in egress path |
| 11 | Duplicate App Config NETWORK_ISOLATION key | Portal has only one occurrence |

---

## Phase 1 — Requires AVM Wrapper Recompilation

These fixes are embedded in the compiled `avm.ptn.ai-ml.ai-foundry.json` and cannot be patched manually:

| Fix | Bicep Version | Description |
|-----|---------------|-------------|
| PE name collision | v2.0.2 | Private endpoints sharing a subnet get duplicate names |
| Search replica count | v2.0.6 | Foundry-bundled AI Search replicas lowered from 3 to 1 |

**Action required:** Recompile from upstream `bicep-ptn-aiml-landing-zone/modules/ai-foundry/main.bicep` at v2.3.0+:
```bash
az bicep build --file modules/ai-foundry/main.bicep --outfile portal/wrappers/avm.ptn.ai-ml.ai-foundry.json
```

---

## Phase 2 — UI Decisions (Resolved)

| ID | Item | Decision | Status |
|----|------|----------|--------|
| A | AI Foundry project name parameterization | ✅ Added TextBox to AI Services step | **Implemented** |
| B | App runtime configuration mode (`none`) | Keep as-is — existing `deployContainerAppEnv` toggle covers this | **Skipped** |
| C | Capacity Host wait timeout exposure | Keep as-is — not a template parameter, CI/deployment concern only | **Skipped** |
| D | DNS Zone Link Suffix for multi-spoke | Keep as-is — Portal naming is already unique per deployment | **Skipped** |
| E | Additional ACR Task Build FQDNs | Keep as-is — Portal doesn't deploy ACR Task agent pool; post-deploy config | **Skipped** |
| F | Standalone AI Search removal (Foundry bundles its own) | ✅ Removed duplicate module, wrapper files, and all references | **Implemented** |
| G | Container App workload profile selection | ✅ Added DropDown to AI Services step (D4–E16 options) | **Implemented** |

### Phase 2 Implementation Details

**Item A — AI Foundry Project Name:**
- `form.json`: Added `aiFoundryProjectName` TextBox (first element in AI Services step)
- `template.json`: Added `aiFoundryProjectName` parameter; replaced hardcoded `"aifoundry-default-project"` with parameterized value
- Wrapper appends unique suffix automatically via `res.ai-foundry.json`

**Item F — Standalone AI Search Removal:**
- Removed ~303 lines from `template.json` (deployment, PE, DNS zone, conditions, variables)
- Removed 35 lines from `form.json` (toggle + output)
- Deleted `portal/wrappers/avm.res.search.search-service.json` (2,840 lines)
- Deleted `portal/wrappers/res.ai-foundry-connection-search.json` (63 lines)

**Item G — Container App Workload Profile:**
- `form.json`: Added `containerAppWorkloadProfile` DropDown (last element in AI Services step)
- `template.json`: Added `containerAppWorkloadProfile` parameter with `allowedValues`; replaced hardcoded `"D4"` with parameterized value

---

## Bicep-Only Gaps Logged

9 new entries added to `bicep-only-no-portal.md` (entries #28–#36). Total tracked gaps: **36** (24 permanent, 12 potentially resolvable).

---

## Next Steps

1. Recompile AVM wrappers from upstream v2.3.0 source (fixes PE name collision + search replica count)
2. Re-enable maintenance toggles after upstream fix (see `context/upstream-bug-maintenance-config.md`)
3. Full deployment validation in test subscription
4. Get `daily-sync.yml` merged to `main` branch for cron activation
