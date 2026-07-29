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

## Phase 2 — Deferred (UI Decisions Required)

| ID | Item | Decision Needed |
|----|------|-----------------|
| A | AI Foundry project name parameterization | Add form field or keep hardcoded default? |
| B | App runtime configuration mode (`none`) | Add mode selector dropdown? |
| C | Capacity Host wait timeout exposure | Surface in Advanced settings? |
| D | DNS Zone Link Suffix for multi-spoke | Add to networking step? |
| E | Additional ACR Task Build FQDNs | Add repeating text field? |
| F | Standalone AI Search removal (Foundry bundles its own) | Remove duplicate module? |
| G | Container App workload profile selection | Add profile picker dropdown? |

---

## Bicep-Only Gaps Logged

9 new entries added to `bicep-only-no-portal.md` (entries #28–#36). Total tracked gaps: **36** (24 permanent, 12 potentially resolvable).

---

## Next Steps

1. Recompile AVM wrappers from upstream v2.3.0 source
2. Resolve Phase 2 UI decisions with stakeholders
3. Full deployment validation in test subscription
