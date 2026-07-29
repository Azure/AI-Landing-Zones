# Bicep Features Not Implemented in Portal Deployment

This file tracks features that exist in the Bicep implementation (`Azure/bicep-ptn-aiml-landing-zone`) but are intentionally not implemented in the Portal deployment. Each entry explains why the feature doesn't map to the Portal and whether the gap is permanent or potentially resolvable.

---

## Exclusion Categories

| Category | Meaning |
|----------|---------|
| **Complexity** | Parameter surface too complex for a Portal form (arrays of objects, deeply nested structures) |
| **azd-specific** | Feature relies on azd CLI workflows inapplicable to Portal one-shot deployments |
| **CI/CD-only** | Feature designed for pipeline automation, not interactive deployments |
| **ARM limitation** | ARM template language cannot express the feature |
| **UX overhead** | Exposing would create unacceptable wizard complexity for minimal value |
| **Redundancy** | Portal handles the equivalent differently (see notes) |

---

## Feature Gap Registry

### 1. Container Apps List (`containerAppsList`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `containerAppsList` (array of objects) |
| **Category** | Complexity |
| **Identified** | v1.0.7 / 2025-06 |
| **Status** | Permanent |

**Description:** The Bicep implementation allows deploying multiple Container Apps via an array parameter where each entry defines a complete Container App configuration (name, image, env vars, scaling rules, workload profile, etc.).

**Why excluded:** The Portal UI cannot reasonably present an array-of-objects editor for Container App definitions. The form would need dynamic add/remove rows with nested fields for each app. Instead, the Portal deploys a single hardcoded orchestrator Container App (`ca-{baseName}-orchestrator`) as a placeholder.

**Portal equivalent:** Single Container App toggle (`deployToggles.containerApps`) with a fixed orchestrator definition.

---

### 2. Deployment Mode / Network Isolation Toggle (`deploymentMode`, `networkIsolation`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `deploymentMode` (`standalone` \| `ailz-integrated`), `networkIsolation` (bool) |
| **Category** | Redundancy |
| **Identified** | v1.0.7 / 2025-06 |
| **Status** | Permanent — different approach taken |

**Description:** Bicep offers two topology modes: `standalone` (full self-contained deployment) and `ailz-integrated` (spoke-only, peers into existing hub). The `networkIsolation` flag controls whether private networking is deployed.

**Why excluded:** The Portal uses `flagPlatformLandingZone` (bool) which provides equivalent functionality but with a different semantic model. When `true`, it suppresses Firewall/AppGW/APIM/Bastion/DNS and requires existing DNS zones — effectively equivalent to `ailz-integrated`. The Portal always deploys private networking (all resources have private endpoints); there is no "basic/public" mode.

**Portal equivalent:** `flagPlatformLandingZone` parameter and conditional visibility rules in `form.json`.

---

### 3. CAF Resource Naming Strategy (`resourceNamingMode`, `cafWorkloadName`, `cafEnvironmentName`, `cafRegionAbbreviation`)

| Field | Value |
|-------|-------|
| **Bicep Parameters** | `resourceNamingMode`, `cafWorkloadName`, `cafEnvironmentName`, `cafRegionAbbreviation`, `cafInstanceNumber` |
| **Category** | UX overhead |
| **Identified** | v1.0.7 / 2025-06 (enhanced v2.1.6, default changed v2.2.0) |
| **Status** | Permanent |

**Description:** Bicep supports two naming strategies: `caf` (Cloud Adoption Framework pattern: `type-workload-environment-region-instance`) and `legacy` (resource token-based). Multiple parameters control the CAF tokens. As of v2.2.0, CAF naming is the default mode.

**Why excluded:** The Portal uses a simplified `baseName` (2–12 chars) that seeds all resource names via a straightforward `{prefix}-{baseName}` pattern. Exposing 5+ naming parameters in the wizard would confuse users deploying via Portal (who typically want simplicity). The CAF naming is more appropriate for IaC-managed environments where naming conventions are organizationally mandated.

**Portal equivalent:** Single `baseName` parameter with deterministic naming in `template.json` variables section.

---

### 4. Individual Resource Name Overrides

| Field | Value |
|-------|-------|
| **Bicep Parameters** | `aiFoundryAccountName`, `aiFoundryProjectName`, `keyVaultName`, `searchServiceName`, `logAnalyticsWorkspaceName`, `containerEnvName`, `containerRegistryName`, `dbAccountName`, `dbDatabaseName`, `solutionStorageAccountName`, `appConfigName`, `bingSearchName`, `appInsightsName`, `frontEndContainerAppName`, `dataIngestContainerAppName`, + more |
| **Category** | UX overhead |
| **Identified** | v1.0.7 / 2025-06 |
| **Status** | Permanent |

**Description:** Bicep allows overriding every individual resource name with explicit parameters.

**Why excluded:** Would require 15+ additional text fields in the wizard with complex validation (global uniqueness, character restrictions per resource type). The Portal's `baseName` approach handles naming automatically. Users needing custom names should use the Bicep/Terraform deployment.

**Portal equivalent:** Deterministic naming from `baseName` variable in `template.json`.

---

### 5. AI Foundry Agent Service Data Plane (`deployAAfAgentSvc`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `deployAAfAgentSvc` |
| **Category** | Complexity |
| **Identified** | v2.0.x / 2025-07 |
| **Status** | Potentially resolvable — monitor for Portal feasibility |

**Description:** When enabled, the Bicep deployment provisions dedicated Foundry-owned Search, Storage, and Cosmos DB resources for the Agent Service data plane (separate from the workload's own instances of these services).

**Why excluded:** Enabling this creates a parallel set of resources with their own private endpoints, DNS zones, and role assignments. The Portal would need additional form sections and the orchestration complexity would double. The feature is also relatively new and evolving rapidly.

**Portal equivalent:** None currently. Users needing Agent Service should deploy via Bicep.

---

### 6. ACR Build-Agent Pool (`deployAcrTaskAgentPool`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `deployAcrTaskAgentPool` |
| **Category** | UX overhead |
| **Identified** | v2.0.x / 2025-07 |
| **Status** | Permanent |

**Description:** Deploys an S1 agent pool for ACR Tasks, enabling container image builds within the private network.

**Why excluded:** Niche feature primarily useful for CI/CD workflows where images are built inside the ACR rather than on a build VM. The Portal deployment already provides a Build VM for this purpose. Adding a toggle for ACR agent pools adds form complexity for a minority use case.

**Portal equivalent:** Build VM with Docker pre-installed serves the container image build function.

---

### 7. Side-by-Side Deployment (`sideBySideDeploy`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `sideBySideDeploy` |
| **Category** | ARM limitation / Complexity |
| **Identified** | v2.0.x / 2025-07 |
| **Status** | Permanent |

**Description:** Allows a second AI Landing Zone to be deployed side-by-side in the same existing VNet without disturbing the first deployment's subnets or NSGs.

**Why excluded:** This is an advanced scenario requiring careful subnet address planning and naming collision avoidance. The Portal form cannot validate against existing resources at design time. Additionally, the Portal deploys with fixed subnet naming that would conflict.

**Portal equivalent:** None. Users needing multi-instance should use Bicep with explicit addressing.

---

### 8. Workload Profiles Configuration (`workloadProfiles`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `workloadProfiles` (array of objects) |
| **Category** | Complexity |
| **Identified** | v1.0.7 / 2025-06 |
| **Status** | Potentially resolvable — could add simplified profile selection |

**Description:** Bicep allows defining multiple Container Apps Environment workload profiles (D4, D8, GPU, etc.) as an array.

**Why excluded:** Array-of-objects parameter requiring users to understand ACA workload profile concepts, SKU names, and scaling properties. The Portal deploys with a default `main` profile (D4).

**Portal equivalent:** Fixed D4 workload profile in the Container Apps Environment wrapper.

---

### 9. Model Deployment List Customization (`modelDeploymentList`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `modelDeploymentList` (array of objects) |
| **Category** | Complexity |
| **Identified** | v1.0.7 / 2025-06 |
| **Status** | Potentially resolvable — could offer model picker in future |

**Description:** Bicep allows specifying an arbitrary list of AI model deployments with name, model, version, SKU, and capacity for each.

**Why excluded:** Each model deployment requires knowing the model name, format, version, SKU name, and capacity — all of which vary by region and change frequently. The Portal hardcodes two standard models (`gpt-5-mini` GlobalStandard/10, `text-embedding-3-large` Standard/1) that work in most regions.

**Portal equivalent:** Fixed `varAiFoundryModelDeployments` variable in `template.json`.

---

### 10. Separate AI Foundry Region (`aiFoundryLocation`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `aiFoundryLocation` |
| **Category** | UX overhead |
| **Identified** | v2.0.x / 2025-07 |
| **Status** | Potentially resolvable |

**Description:** Allows deploying AI Foundry resources in a different region than the primary deployment (useful when model quota is unavailable in the primary region).

**Why excluded:** Adds cross-region complexity with implications for private endpoint routing, DNS resolution, and latency. The Portal UI would need an additional region picker with explanatory text. Users needing cross-region can use Bicep.

**Portal equivalent:** All resources deploy to the resource group's region.

---

### 11. Separate Cosmos DB Region (`cosmosLocation`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `cosmosLocation` |
| **Category** | UX overhead |
| **Identified** | v2.0.x / 2025-07 |
| **Status** | Potentially resolvable |

**Description:** Allows deploying Cosmos DB in a different region (useful when serverless Cosmos isn't available in the primary region).

**Why excluded:** Same reasoning as AI Foundry separate region — cross-region networking complexity and marginal Portal user value.

**Portal equivalent:** Cosmos DB deploys to the resource group's region.

---

### 12. Principal ID / Deploying User Identity (`principalId`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `principalId` |
| **Category** | azd-specific |
| **Identified** | v1.0.7 / 2025-06 |
| **Status** | Permanent |

**Description:** The deploying user's Object ID, used to grant the deployer direct RBAC access to deployed resources.

**Why excluded:** In Portal deployments, the deploying user already has access via the Azure Portal session. The `principalId` is an azd convention for granting the CLI user access to resources they just provisioned.

**Portal equivalent:** Not needed — Portal users access resources through the Portal itself.

---

### 13. User-Assigned vs System-Assigned Identity Choice (`useUAI`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `useUAI` |
| **Category** | Redundancy |
| **Identified** | v1.0.7 / 2025-06 |
| **Status** | Permanent |

**Description:** Bicep allows choosing between user-assigned and system-assigned managed identity.

**Why excluded:** The Portal deployment always creates a User-Assigned Managed Identity (via `res.managed-identity.json`) and assigns it to Container Apps. This is the recommended approach for multi-resource architectures. Offering a system-assigned option would complicate role assignment ordering.

**Portal equivalent:** Always deploys User-Assigned Managed Identity.

---

### 14. Container App API Key Authentication (`useCAppAPIKey`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `useCAppAPIKey` |
| **Category** | UX overhead |
| **Identified** | v2.0.x / 2025-07 |
| **Status** | Potentially resolvable |

**Description:** Enables API key authentication for Container Apps instead of/alongside managed identity.

**Why excluded:** Niche configuration option. The Portal deployment uses managed identity for inter-service auth by default, which is more secure and simpler for the wizard flow.

**Portal equivalent:** Managed identity auth is the default and only option.

---

### 15. Policy-Managed Private DNS (`policyManagedPrivateDns`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `policyManagedPrivateDns` |
| **Category** | Complexity |
| **Identified** | v2.0.x / 2025-07 |
| **Status** | Potentially resolvable |

**Description:** When `true`, no DNS zones are created or linked regardless of other settings — assumes Azure Policy handles all private DNS zone management.

**Why excluded:** This is an enterprise pattern where a central Azure Policy assigns private DNS zones to private endpoints. The Portal deployment either creates zones (standalone) or expects the user to provide existing zone IDs (platform landing zone mode). Policy-managed DNS is a third model that would need its own explanation and visibility rules.

**Portal equivalent:** Platform Landing Zone mode with existing DNS zone selection covers the primary enterprise scenario.

---

### 16. Hub Integration Parameters (`hubIntegrationHubVnetResourceId`, `hubIntegrationCreateHubPeering`, `hubIntegrationExistingRouteTableResourceId`)

| Field | Value |
|-------|-------|
| **Bicep Parameters** | `hubIntegrationHubVnetResourceId`, `hubIntegrationCreateHubPeering`, `hubIntegrationExistingRouteTableResourceId` |
| **Category** | Redundancy |
| **Identified** | v2.0.x / 2025-07 |
| **Status** | Permanent — covered by Portal's VNet peering feature |

**Description:** Bicep's `ailz-integrated` mode has dedicated hub integration parameters for connecting to a hub VNet, auto-creating peering, and attaching route tables.

**Why excluded:** The Portal provides VNet peering via `deployPeering` / `peerVnetName` / `peerVnetId` parameters which cover the primary use case. Route table association and auto-peering creation from the hub side are not supported (hub-side changes require hub owner action regardless).

**Portal equivalent:** VNet peering section in the Network Configuration wizard step.

---

### 17. Separate VM Key Vault (`deployVmKeyVault`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `deployVmKeyVault` |
| **Category** | UX overhead |
| **Identified** | v2.0.x / 2025-07 |
| **Status** | Permanent |

**Description:** Creates a dedicated Key Vault for VM secrets separate from the workload Key Vault.

**Why excluded:** The Portal deploys a single Key Vault that serves both purposes. Splitting Key Vaults adds wizard complexity (two Key Vault toggles, two private endpoints, two DNS zones) for a security-hardening pattern that most Portal users don't need.

**Portal equivalent:** Single Key Vault deployment.

---

### 18. Subnet Deployment Toggle (`deploySubnets`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `deploySubnets` |
| **Category** | Redundancy |
| **Identified** | v2.0.x / 2025-07 |
| **Status** | Permanent |

**Description:** When using an existing VNet, controls whether new subnets are created in it.

**Why excluded:** The Portal handles this via the "Deploy VNet" toggle combined with an existing VNet selector and explicit subnet mapping dropdowns. When `deployVNet = No` and `deploySubnets = No` equivalent, the user maps existing subnets in the form.

**Portal equivalent:** Existing VNet subnet mapping section in form.json.

---

### 19. Additional Private DNS Zones (15 total in Bicep vs ~11 in Portal)

| Field | Value |
|-------|-------|
| **Bicep Parameters** | `existingPrivateDnsZoneOdsOpsInsightsResourceId`, `existingPrivateDnsZoneOmsOpsInsightsResourceId`, `existingPrivateDnsZoneAzureAutomationResourceId`, `existingPrivateDnsZoneAzureMonitorResourceId` |
| **Category** | UX overhead |
| **Identified** | v2.0.x / 2025-07 |
| **Status** | Potentially resolvable — add as needed |

**Description:** Bicep supports 15 private DNS zones including ODS/OMS OpInsights, Azure Automation, and Azure Monitor zones for comprehensive AMPLS coverage.

**Why excluded:** The Portal supports ~11 zones covering the primary services. The additional ODS/OMS/Automation zones are only needed for full Azure Monitor Private Link Scope coverage, which the Portal's Private Link Scope wrapper handles internally without explicit zone selection.

**Portal equivalent:** Private Link Scope wrapper manages monitor-related zones internally.

---

### 20. Green Field Deployment Flag (`greenFieldDeployment`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `greenFieldDeployment` |
| **Category** | Redundancy |
| **Identified** | v2.0.x / 2025-07 |
| **Status** | Permanent |

**Description:** Master flag that when `true` creates everything from scratch.

**Why excluded:** The Portal handles this implicitly through the `resourceIds` parameter. If all resource IDs are empty (default), it's a green-field deployment. If any are populated, it's brownfield. No need for an explicit flag.

**Portal equivalent:** Empty vs populated `resourceIds` parameter.

---

### 21. azd Environment Name / Variable Substitution (`environmentName`, `${AZURE_ENV_NAME}`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `environmentName` |
| **Category** | azd-specific |
| **Identified** | v1.0.7 / 2025-06 |
| **Status** | Permanent |

**Description:** The azd environment name used as a seed for resource naming and for multi-environment (dev/test/prod) support.

**Why excluded:** Portal deployments don't use azd environments. The Portal's `baseName` parameter serves the same naming seed purpose. Multi-environment support is not applicable to one-shot Portal deployments.

**Portal equivalent:** `baseName` parameter.

---

### 22. App Config Label (`appConfigLabel`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `appConfigLabel` |
| **Category** | azd-specific |
| **Identified** | v2.0.x / 2025-07 |
| **Status** | Potentially resolvable |

**Description:** Labels App Configuration entries with an accelerator-specific label for multi-tenant App Config usage.

**Why excluded:** The Portal deployment populates App Config with a fixed set of keys without labels. Labeling is an accelerator pattern for distinguishing multiple workloads sharing one App Config store — not applicable to standalone Portal deployments.

**Portal equivalent:** App Config populated without labels via `res.app-configuration-populate.json`.

---

### 23. CI/CD Pipeline Support (Azure DevOps / GitHub Actions)

| Field | Value |
|-------|-------|
| **Bicep Feature** | `pipelines/azuredevops/`, `pipelines/github/`, CI/CD variable templates |
| **Category** | CI/CD-only |
| **Identified** | v1.0.7 / 2025-06 |
| **Status** | Permanent |

**Description:** Bicep repo includes full CI/CD pipeline definitions for Azure DevOps and GitHub Actions with multi-environment (Dev/Test/Prod) promotion, validation stages, and retry logic.

**Why excluded:** Portal deployments are interactive one-shot operations. CI/CD automation is fundamentally incompatible with the Portal wizard model.

**Portal equivalent:** None — Portal is the manual alternative to CI/CD.

---

### 24. Preflight Checks (`scripts/Invoke-PreflightChecks.ps1`)

| Field | Value |
|-------|-------|
| **Bicep Feature** | `scripts/Invoke-PreflightChecks.ps1`, quota validation, region checks |
| **Category** | azd-specific |
| **Identified** | v1.0.7 / 2025-06 |
| **Status** | Permanent |

**Description:** PowerShell-based pre-deployment validation that checks quotas, region availability, and parameter consistency before deploying.

**Why excluded:** The Azure Portal has its own built-in deployment validation (ARM preflight checks). Custom preflight scripts cannot run within the Portal deployment flow.

**Portal equivalent:** ARM template validation built into the Portal deployment experience.

---

### 25. Accelerator/Submodule Pattern

| Field | Value |
|-------|-------|
| **Bicep Feature** | `.gitmodules`, `azure.yaml`, `preprovision` hooks, `manifest.json` |
| **Category** | azd-specific |
| **Identified** | v2.0.x / 2025-07 |
| **Status** | Permanent |

**Description:** Bicep supports a submodule pattern where accelerator repos consume the AI Landing Zone as a git submodule, pinned to a tag, with overlay parameters.

**Why excluded:** This is an azd development workflow pattern for composing accelerators on top of the base infrastructure. The Portal deployment is self-contained and doesn't support composition or submodule patterns.

**Portal equivalent:** None — the Portal deployment is the complete self-contained implementation.

---

### 26. Public Ingress as Object Parameter (`publicIngress: { enabled: true }`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `publicIngress` (object with `enabled` boolean) |
| **Category** | Redundancy |
| **Identified** | v1.0.7 / 2025-06 |
| **Status** | Permanent — different approach taken |

**Description:** Bicep uses an object parameter `publicIngress` with an `enabled` property to control Application Gateway deployment.

**Why excluded:** The Portal flattens this into separate toggle parameters (`deployToggles.applicationGateway`, `deployToggles.applicationGatewayPublicIp`, `deployToggles.wafPolicy`) with individual visibility rules tied to `flagPlatformLandingZone`. This gives the form finer-grained control over UI presentation.

**Portal equivalent:** Individual deploy toggles for App Gateway, Public IP, and WAF Policy.

---

### 27. VM Password Auto-Generation

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `vmAdminPassword` (auto-generated when empty) |
| **Category** | ARM limitation |
| **Identified** | v1.0.7 / 2025-06 |
| **Status** | Permanent |

**Description:** Bicep auto-generates a secure VM password when the parameter is left empty and stores it in Key Vault.

**Why excluded:** ARM linked templates cannot generate random values at deployment time in the same way Bicep's `uniqueString()` + Key Vault pattern works. The Portal requires the user to input a password that meets Azure complexity requirements.

**Portal equivalent:** Required `vmPassword` secureString parameter with complexity validation in `form.json`.

---

### 28. Additional App Configuration Settings (Passthrough Array)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `additionalAppConfigurationSettings` (array of objects) |
| **Category** | Complexity |
| **Identified** | v2.3.0 / 2026-07-02 |
| **Status** | Permanent |

**Description:** Allows arbitrary key-value pairs to be injected into the App Configuration store at deployment time via a freeform array parameter.

**Why excluded:** The Portal cannot expose a dynamic arbitrary key-value editor in the ARM deployment form. App Configuration population is handled by the `res.app-configuration-populate.json` wrapper with a curated list of keys.

**Portal equivalent:** Fixed set of keys populated by `appConfigPopulate` deployment in template.json.

---

### 29. App Runtime Configuration Mode (`containerEnv` / `none`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `appRuntimeConfigurationMode` (string enum) |
| **Category** | Complexity |
| **Identified** | v2.0.17 / 2026-06-19 |
| **Status** | Potentially resolvable |

**Description:** Controls whether the landing zone deploys a Container Apps environment for the app runtime or skips it entirely (`none` mode for BYO compute scenarios).

**Why excluded:** The Portal always deploys the Container Apps environment when `deployToggles.containerApps` is true. The `none` mode is an advanced scenario for users who bring their own compute. Adding a mode selector adds UI complexity for an edge case.

**Portal equivalent:** `deployToggles.containerApps` toggle (binary on/off, no `none` mode).

---

### 30. Foundry IQ Knowledge Base Runtime Configuration

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `foundryIqKnowledgeBaseName`, `foundryIqKnowledgeBaseSourceName`, `foundryIqModelDeployment`, `foundryIqEmbeddingModelDeployment`, `foundryIqIndexName`, `foundryIqSearchSemanticConfig`, `foundryIqUseVectors` |
| **Category** | azd-specific |
| **Identified** | v2.1.0 / 2026-06-25 |
| **Status** | Permanent |

**Description:** Seven parameters that configure the Foundry IQ (AI Foundry Knowledge Base) runtime settings, including knowledge base names, embedding models, index names, and vector search configuration.

**Why excluded:** These are runtime application configuration values that only apply when running the AI Landing Zone reference application via `azd`. The Portal deployment focuses on infrastructure provisioning; runtime app configuration is handled post-deployment.

**Portal equivalent:** None — infrastructure-only deployment; application runtime is configured separately.

---

### 31. Additional ACR Task Build FQDNs

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `additionalAcrTaskBuildFqdns` (array) |
| **Category** | Complexity |
| **Identified** | v2.0.5 / 2026-05-26 |
| **Status** | Potentially resolvable |

**Description:** Allows specifying additional FQDNs that should be allowed through the firewall for ACR task builds (e.g., custom package registries, private feeds).

**Why excluded:** Dynamic FQDN arrays require a complex repeating-section UI control. The Portal firewall policy is deployed without rule collection groups; ACR tasks use the default network path.

**Portal equivalent:** None — users can add firewall rules post-deployment if custom FQDNs are needed.

---

### 32. DNS Zone Link Suffix for Multi-Spoke Shared Zones

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `dnsZoneLinkSuffix` (string) |
| **Category** | UX overhead |
| **Identified** | v2.0.0 / 2026-05-18 |
| **Status** | Potentially resolvable |

**Description:** Appends a suffix to private DNS zone virtual network link names, enabling multiple spokes to link to the same shared DNS zone without naming collisions.

**Why excluded:** Multi-spoke topologies require understanding of the hub-spoke naming convention. Adding a suffix field adds cognitive load for the majority of users deploying a single landing zone.

**Portal equivalent:** Links use the VNet name as the link name (e.g., `{vnetName}-{service}-link`), which is unique per deployment.

---

### 33. Cosmos Analytical Storage Preflight Warning

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `enableCosmosAnalyticalStorage` (bool, with preflight validation) |
| **Category** | CI/CD-only |
| **Identified** | v2.0.16 / 2026-06-17 |
| **Status** | Permanent |

**Description:** Bicep includes a preflight assertion that warns when analytical storage is enabled but the selected Cosmos DB region doesn't support it, preventing deployment failures.

**Why excluded:** ARM templates do not support the Bicep `assert` construct for preflight validation. The Portal validates region compatibility through Azure API calls during form submission, not through template-level assertions.

**Portal equivalent:** Portal form validation via ARM API capabilities check (implicit).

---

### 34. Allow Mixed Observability Workspaces Advisory Flag

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `allowMixedObservabilityWorkspaces` (bool) |
| **Category** | azd-specific |
| **Identified** | v2.0.0 / 2026-05-18 |
| **Status** | Permanent |

**Description:** Advisory flag that suppresses warnings when the AI Foundry workspace and Container Apps environment use different Log Analytics workspaces.

**Why excluded:** This is a Bicep-time advisory mechanism that emits a deployment warning. ARM templates have no equivalent warning/advisory system. The Portal always deploys a single Log Analytics workspace shared by all resources.

**Portal equivalent:** Single shared workspace architecture eliminates the mixed-workspace scenario.

---

### 35. Foundry IQ Parameters Deprecated (Passthrough Replacement)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `foundryIq*` parameters (7 params, replaced by `additionalAppConfigurationSettings` passthrough) |
| **Category** | azd-specific |
| **Identified** | v2.3.0 / 2026-07-02 |
| **Status** | Permanent |

**Description:** The seven `foundryIq*` parameters from v2.1.0 were deprecated and replaced by the generic `additionalAppConfigurationSettings` passthrough array, allowing arbitrary runtime config without dedicated parameters.

**Why excluded:** Both the original parameters (entry #30) and their replacement mechanism (entry #28) are excluded. This entry tracks the deprecation transition specifically.

**Portal equivalent:** None — same as entries #28 and #30.

---

### 36. AVM Wrapper Recompilation Required (PE Naming + Search Replicas)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | Internal to `avm.ptn.ai-ml.ai-foundry` compiled module |
| **Category** | Tooling limitation |
| **Identified** | v2.0.2 (PE fix), v2.0.6 (replica fix) / 2026-05-22 |
| **Status** | Potentially resolvable |

**Description:** Two fixes in the compiled AI Foundry AVM pattern module: (1) private endpoint name collision when multiple PEs share a subnet (v2.0.2), and (2) AI Search replica count lowered from 3 to 1 for cost optimization (v2.0.6). These are baked into the compiled `avm.ptn.ai-ml.ai-foundry.json` wrapper.

**Why excluded:** Cannot manually patch compiled ARM JSON from Bicep. Requires recompilation of the AVM pattern module (`az bicep build`) from the latest upstream source.

**Portal equivalent:** Recompile `avm.ptn.ai-ml.ai-foundry.json` from upstream `bicep-ptn-aiml-landing-zone/modules/ai-foundry/main.bicep` at tag v2.3.0 or later.

---

## Summary Statistics

| Status | Count |
|--------|-------|
| Permanent exclusions | 24 |
| Potentially resolvable | 12 |
| Blocked by upstream bug | 1 |
| **Total tracked gaps** | **37** |

---

### 37. VM Maintenance Configuration (`jumpVmMaintenanceDefinition`, `buildVmMaintenanceDefinition`)

| Field | Value |
|-------|-------|
| **Bicep Parameter** | `jumpVmMaintenanceDefinition`, `buildVmMaintenanceDefinition` (object) |
| **Category** | ARM limitation (upstream bug) |
| **Identified** | v2.3.0 / 2026-07 |
| **Status** | Blocked — awaiting upstream fix |
| **Notes** | The compiled AVM wrapper `avm.res.maintenance.maintenance-configuration.json` does not forward `maintenanceScope` (or any scheduling properties) from the outer parameter to its inner nested deployment. The inner template defaults `maintenanceScope` to `"Host"`, which requires isolated/dedicated-host VM SKUs. Non-isolated SKUs (e.g. `Standard_D4as_v5`) fail with error `UnsupportedResourceOperation: Non-Isolated VMs are currently not permitted to opt in to Maintenance`. Both Portal toggles (Jump VM and Build VM) have been hidden and hardcoded to pass `{}` (disabled). Re-enablement steps documented in `context/upstream-bug-maintenance-config.md`. See: https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/TBD |

---

*Last updated: 2026-07-28 — aligned with Bicep v2.3.0 / Portal v2.0.12 (releaseTag)*
