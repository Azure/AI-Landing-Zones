# Portal ↔ Bicep Priority Gap Report (v2.5.1)

**Date:** 2026-08-13  
**Portal template releaseTag:** `v2.0.12`  
**Upstream compared:** `Azure/bicep-ptn-aiml-landing-zone` `v2.5.1`  
**Drift summary:** 184 upstream parameters not present in `portal/template.json`; 23 portal-only parameters.

---

## Scope and Method

This report prioritizes parameter gaps by likely deployment impact and PR relevance:

1. **P0 (Critical):** topology/DNS/networking choices that can change deployment behavior or break integrated mode.
2. **P1 (High):** AI Foundry and agent capabilities that significantly alter delivered functionality.
3. **P2 (Medium):** security/runtime controls that are useful but not required for baseline parity.
4. **P3 (Low/Defer):** advanced naming/override and expert-only parameters that can remain Bicep-only.

---

## P0 — Critical Gaps (address first)

These are the highest-value parity gaps for this branch because they directly affect Portal mode selection and private networking outcomes.

| Parameter | Why it matters | Recommended Portal action |
|---|---|---|
| `deploymentMode` | Canonical upstream mode switch (`standalone` vs integrated) | Map to existing `flagPlatformLandingZone` semantics in template logic (backend mapping) |
| `networkIsolation` | Upstream network posture switch | Keep private-by-default behavior; document explicit mapping/skip in `bicep-only-no-portal.md` |
| `useExistingVNet` | Governs existing-vNet flow | Alias to existing `existingVnetId`/`existingVnetName` path |
| `existingVnetResourceId` | Required in upstream for existing-vNet scenarios | Backend-only alias from existing portal parameter(s) |
| `deploySubnets` | Controls subnet creation path in existing-vNet mode | Map to existing `existingSubnets` UX behavior |
| `policyManagedPrivateDns` | DNS ownership model (platform-managed DNS) | Add backend support and conditional handling with `flagPlatformLandingZone` |
| `existingPrivateDnsZoneOpenAiResourceId` | Integrated-mode DNS correctness for OpenAI | Add to DNS mapping layer; likely no direct UI if `existingDNSZones` object is retained |
| `existingPrivateDnsZoneCogSvcsResourceId` | Same as above for Cognitive Services | Same as above |
| `existingPrivateDnsZoneAiServicesResourceId` | Same as above for AI Services | Same as above |
| `existingPrivateDnsZoneSearchResourceId` | Same as above for AI Search | Same as above |
| `existingPrivateDnsZoneBlobResourceId` | Same as above for Storage Blob | Same as above |
| `existingPrivateDnsZoneKeyVaultResourceId` | Same as above for Key Vault | Same as above |

**P0 implementation pattern for this PR track:**
- Prefer **backend aliases/mappings** before adding new form fields.
- Keep existing Portal UX stable and map legacy field model to upstream field model in `template.json`.
- Log any intentional non-equivalence to `bicep-only-no-portal.md`.

---

## P1 — High Priority Functional Gaps

These materially change what the environment can do once deployed.

| Parameter | Why it matters | Recommended action |
|---|---|---|
| `deployAfProject` | Controls explicit Foundry project provisioning behavior | Add backend support; decide if user-facing toggle is needed |
| `aiFoundryProjectDisplayName` | Improves project identity/UX beyond simple name | Add optional field or backend default derived from existing project name |
| `aiFoundryProjectDescription` | Project metadata parity | Backend default acceptable if UI complexity should stay low |
| `modelDeploymentList` | Enables explicit model deployment matrix | Keep Bicep-only unless a simplified Portal preset model selector is introduced |
| `deployAAfAgentSvc` | Enables Agent Service-specific resources | Likely keep Bicep-only for now; document clearly |
| `deployHostedAgent` | Hosted-agent path support | Evaluate as optional advanced toggle |
| `retrievalBackend` | RAG retrieval mode behavior | Consider exposing only if paired with a simplified UX |
| `knowledgeBaseName` | Knowledge resource naming/selection | Backend default or advanced section |
| `knowledgeBaseConnectionName` | Connection object naming | Backend default |
| `containerAppsList` | Multi-app topology support | Keep Bicep-only (already consistent with current exclusions) |

---

## P2 — Medium Priority Security/Runtime Gaps

| Parameter | Why it matters | Recommended action |
|---|---|---|
| `allowedIpRanges` | Network hardening input | Candidate advanced field under security/networking |
| `publicIngress` | Exposure model for app endpoints | Candidate advanced toggle |
| `useUAI` | Identity mode control | Backend support if managed identity strategy is expanding |
| `principalId` / `principalType` | RBAC assignment targets | Backend-only unless Portal introduces BYO principal UX |
| `useZoneRedundancy` | Availability/cost tradeoff control | Candidate advanced toggle with region guard |
| `enablePrivateLogAnalytics` | Monitoring isolation behavior | Add only if monitoring UX already expanded |

---

## P3 — Low Priority / Defer Candidates

These are important in IaC-heavy workflows but usually too granular for the current Portal UX model.

- `resourceNamingMode`, `cafWorkloadName`, `cafEnvironmentName`, `cafRegionName`, `cafInstance`, `resourceToken`
- Bulk explicit naming overrides (`*Name` parameters)
- Extensive BYO-resource IDs (`existing*ResourceId`) beyond current integrated-mode coverage
- Specialized Foundry IQ tuning (`foundryIq*` parameters)
- VM image micro-controls (`vmImage*`) where Portal currently favors curated defaults

Recommendation: keep these as Bicep-first unless product direction changes to an advanced/expert Portal mode.

---

## Quick-Win Backlog (Suggested Order)

1. **Topology/DNS mapping pass** in `portal/template.json` for P0 parameters using existing UI inputs.
2. **Integrated-mode DNS matrix hardening** (OpenAI/CogSvcs/AIServices/Search/Blob/KeyVault).
3. **Foundry project metadata parity** (`aiFoundryProjectDisplayName`, `aiFoundryProjectDescription`) with safe defaults.
4. **Security advanced toggles** shortlist (`allowedIpRanges`, `publicIngress`, `useZoneRedundancy`) if UX budget allows.
5. Update `PORTAL_BICEP_ALIGNMENT_ANALYSIS.md` with what was implemented vs deferred.

---

## Notes

- The 23 Portal-only parameters largely reflect intentional Portal simplifications (`baseName`, grouped toggles, etc.) and are not necessarily defects.
- This report is intentionally focused: it prioritizes **impactful parity work** over one-to-one exposure of all upstream knobs.
