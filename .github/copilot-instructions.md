# Copilot Instructions — AI Landing Zones Portal Deployment

## Repository Purpose

This repository maintains the **Azure Portal deployment** (ARM JSON + UI form) for the [Azure AI Landing Zones](https://github.com/Azure/AI-Landing-Zones) project. The Portal deployment is a derivative of the **source Bicep implementation** hosted in the `main` branch at `https://aka.ms/ailz/bicep`. This branch (`portalbicepalignment`) exists to keep the Portal deployment aligned with upstream Bicep changes.

The Portal deployment consists of:

- **`portal/template.json`** — The main ARM deployment template (orchestrator). Defines all parameters, variables, deployment conditions, and linked template invocations.
- **`portal/form.json`** — The Azure Portal UI form definition (`uiFormDefinition`). Provides the 7-step wizard experience for end users.
- **`portal/wrappers/`** — Linked ARM templates invoked by `template.json`. Two categories:
  - **`avm.*.json`** — Compiled from Azure Verified Module (AVM) Bicep sources. These are generated artifacts.
  - **`res.*.json`** — Custom resource templates for glue logic (managed identity, role assignments, AI Foundry connections, app config population, bastion host, Bing search, etc.). These are hand-authored ARM JSON.

## Source of Truth

The **Bicep implementation** in the main branch is the canonical source of truth for architecture, resource configuration, parameter design, and deployment logic. This Portal deployment must faithfully represent the same architecture using ARM JSON linked templates and a Portal UI form.

Key upstream references:

- Bicep repo: `https://aka.ms/ailz/bicep` (main branch of this same repository)
- AVM module registry: `br/public:avm/res/*` and `br/public:avm/ptn/*`
- The `releaseTag` variable in `template.json` tracks the current version alignment

## Context Directory

The `context/` directory contains reference files that guide decision-making when evaluating Bicep changes for Portal impact. These files are **not synced to the remote repository** (excluded via `.gitignore`) and are maintained locally for agent consumption.

When context files are present, agents should read them before making modification decisions. Context files may include:

- Bicep module source snapshots for diff comparison
- Mapping tables between Bicep parameters and ARM/form parameters
- Change logs from upstream Bicep updates
- Decision records for why certain Bicep features were adapted or omitted in the Portal version

## Architecture & Conventions

### Naming

All deployed resources follow a `{prefix}-{baseName}` pattern where `baseName` is a 2–12 character user input (lowercase alphanumeric). Naming conventions are defined in the `variables` section of `template.json`. Examples:

| Resource | Pattern |
|----------|---------|
| Virtual Network | `vnet-{baseName}` |
| Key Vault | `kv-{baseName}` |
| Storage Account | `st{baseName}` |
| Build VM | `vm-{baseName}-bld` (truncated to 15 chars) |
| Container App | `ca-{baseName}-orchestrator` |

### Deployment Toggles

Resources are conditionally deployed via the `deployToggles` parameter object. Each toggle maps to a `deploy*` variable that combines the toggle with a check for an existing resource ID (brownfield support):

```
deployX = toggle.x AND empty(resourceIds.xResourceId)
```

### Platform Landing Zone Mode

The `flagPlatformLandingZone` parameter is the most impactful architectural toggle. When `true`:

- Firewall, Application Gateway, APIM, Bastion, and WAF are suppressed
- Private DNS Zones are not created; the user must provide existing zone IDs
- The form dynamically hides/shows fields based on this flag

### Linked Template Pattern

Every resource deployment in `template.json` follows this pattern:

```json
{
  "condition": "[variables('deployX')]",
  "type": "Microsoft.Resources/deployments",
  "apiVersion": "2025-04-01",
  "name": "m-{short-name}",
  "properties": {
    "mode": "Incremental",
    "templateLink": {
      "uri": "[variables('{x}TemplateUri')]",
      "contentVersion": "1.0.0.0"
    },
    "parameters": { ... }
  },
  "dependsOn": [ ... ]
}
```

The `baseTemplateUri` variable points to this branch for raw content serving. Wrapper filenames must match the URI references in `template.json`.

### AVM Wrapper Generation

Wrappers prefixed with `avm.` are generated from Bicep AVM modules. The generation process:

1. A Bicep file is authored that wraps the AVM module with a simplified parameter surface
2. The Bicep file is compiled to ARM JSON via `bicep build`
3. The resulting JSON is placed in `portal/wrappers/`

The `_generator` metadata block in each AVM wrapper records the Bicep compiler version and template hash, which can be used for drift detection.

### Custom Wrappers

Wrappers prefixed with `res.` are hand-authored ARM JSON for operations that don't have direct AVM module equivalents: managed identity creation, RBAC role assignments, Cosmos DB data-plane role assignments, AI Foundry connections, app configuration population, bastion host, NAT gateway, private link scope, Bing search, and VM custom script extensions.

## Agent Responsibilities

### Automated Daily Sync Workflow

This repository uses an automated agent workflow to keep the Portal deployment aligned with the upstream Bicep source (`Azure/bicep-ptn-aiml-landing-zone`). The workflow runs daily and operates **without human interaction** unless a Portal UI/appearance decision is required.

#### Workflow Steps

1. **Check for upstream changes** — Compare the current `releaseTag` in `template.json` against the latest releases/commits on the Bicep source repo. Check for:
   - New tagged releases
   - Commits to `main` since the last synced tag
   - Changes to `main.bicep`, `modules/`, `constants/`, or parameter schemas

2. **Fetch and diff** — Download the updated Bicep source and produce a structured diff against the last-synced version stored in `context/`. Focus on:
   - Parameter additions, removals, or type changes
   - New or removed module references
   - Changed default values or allowed value constraints
   - New or removed resources
   - Modified RBAC role assignments or networking rules

3. **Triage each change** — For every detected change, classify it into one of:

   | Classification | Action | Human Input Required? |
   |---------------|--------|----------------------|
   | **Infrastructure/logic change** | Apply to template.json and/or wrappers | No |
   | **New parameter (backend only)** | Add to template.json with safe default | No |
   | **New parameter (user-facing)** | Add to form.json + template.json | **Yes — pause for UI guidance** |
   | **UI layout/ordering change** | Modify form.json wizard steps | **Yes — pause for UI guidance** |
   | **Bicep-only feature** | Skip; log to `bicep-only-no-portal.md` | No |
   | **AVM module version bump** | Recompile affected wrapper(s) | No |
   | **Breaking parameter rename** | Update form→template→wrapper chain | No (if mapping is mechanical) |
   | **New visibility/dependency rule** | Update form.json visibility expressions | **Yes — if UX impact is ambiguous** |

4. **Execute changes** — Apply all non-UI changes automatically. For each modified file, validate the quality checklist (see below).

5. **Pause for UI decisions** — When a change requires Portal UI/appearance decisions (new wizard fields, reorganization of tabs, new visibility rules that affect user flow), the agent must:
   - Stop processing further changes in that batch
   - Document the pending decision in `context/pending-ui-decisions.md`
   - Clearly describe what the Bicep change introduces and what Portal UI options exist
   - Wait for human guidance before proceeding

6. **Log skipped features** — When a Bicep feature cannot map to a Portal deployment for functional reasons (e.g., complex array parameters, azd-specific workflows, multi-environment pipelines), add an entry to `bicep-only-no-portal.md` explaining:
   - What the feature is
   - Why it doesn't translate to Portal
   - The Bicep parameter(s) or module(s) involved
   - The version/date it was identified

7. **Update tracking** — After applying changes:
   - Update `releaseTag` in `template.json` if syncing to a new release
   - Update `PORTAL_BICEP_ALIGNMENT_ANALYSIS.md` with current alignment status
   - Commit context snapshots to `context/` for future diffing

8. **Validate supported regions** — Verify the `allowedValues` region list in `form.json` remains accurate:
   - Query Azure for `text-embedding-3-large` model availability with Standard SKU across all recommended regions (this is the most restrictive constraint)
   - Verify the intersection with Container Apps (`Microsoft.App/managedEnvironments`), AI Search (`Microsoft.Search/searchServices`), Cognitive Services (`Microsoft.CognitiveServices/accounts`), Cosmos DB (`Microsoft.DocumentDB/databaseAccounts`), and Container Registry (`Microsoft.ContainerRegistry/registries`)
   - Compare the resulting region set against the current `allowedValues` in `form.json` → `resourceScope.location`
   - If regions have been added or removed, update the `allowedValues` array in `form.json`
   - Log any region changes to `PORTAL_BICEP_ALIGNMENT_ANALYSIS.md`
   - This step requires no human input — region changes are data-driven and automatic

#### Decision Authority

The agent has **full authority** to make changes autonomously when:
- The change is purely structural (adding a parameter, updating a condition, fixing a dependency)
- The change maps 1:1 from Bicep to ARM JSON with no ambiguity
- The change is a security fix or bug fix
- The change updates an AVM wrapper to a newer compiled version
- The change adds/removes a resource that already has an established form.json toggle pattern

The agent **must pause and request human guidance** when:
- A new wizard step/tab would need to be added to form.json
- Existing wizard fields would need to be reordered or renamed in a user-visible way
- A new `Microsoft.Common.*` UI control type would need to be selected
- The visibility logic creates a UX flow that could confuse users
- A feature could be exposed via multiple valid UI patterns (dropdown vs toggle vs text input)
- Removing a user-facing option that currently exists in the form

#### Feature Gap Tracking (`bicep-only-no-portal.md`)

The file `bicep-only-no-portal.md` serves as the canonical record of features that exist in the Bicep implementation but are intentionally **not** implemented in the Portal deployment. Each entry must include:
- A clear description of the feature
- The reason it cannot or should not be in the Portal (categorized)
- The relevant Bicep parameter(s) or module path(s)
- The date/version when the gap was identified
- Whether the gap is permanent or potentially resolvable in the future

Valid exclusion categories:
- **Complexity** — Parameter surface too complex for a Portal form (e.g., arrays of objects)
- **azd-specific** — Feature relies on azd CLI workflows inapplicable to Portal deployments
- **CI/CD-only** — Feature designed for pipeline automation, not interactive deployments
- **ARM limitation** — ARM template language cannot express the feature
- **UX overhead** — Exposing would create unacceptable wizard complexity for minimal value
- **Redundancy** — Portal handles the equivalent differently (document the Portal approach)

### Monitoring for Bicep Changes

Agents operating in this repository should:

1. **Detect upstream changes** — Compare the source Bicep modules (main branch) against the current Portal wrapper versions. Use the `_generator.templateHash` in AVM wrappers and the `releaseTag` variable in `template.json` as drift indicators.

2. **Evaluate impact** — Not all Bicep changes require Portal updates. Assess each change against:
   - Does it add, remove, or rename a resource?
   - Does it change parameters that surface in the Portal form?
   - Does it modify deployment conditions or dependencies?
   - Does it update AVM module versions (new features, breaking changes)?
   - Does it change security posture, RBAC assignments, or networking topology?

3. **Classify the change** — Categorize as one of:
   - **No action** — Internal refactoring, comment changes, or features not exposed in Portal
   - **Wrapper update** — Recompile affected `avm.*.json` wrapper(s) from updated Bicep
   - **Template update** — Modify `template.json` (new parameters, variables, conditions, resources, or dependency changes)
   - **Form update** — Modify `form.json` (new wizard fields, visibility rules, validation, or option values)
   - **Full sync** — Coordinated changes across template, form, and wrappers
   - **Bicep-only** — Log to `bicep-only-no-portal.md` and skip

### Applying Updates

When changes are needed:

1. **Read context files first** — Check `context/` for any guidance, mapping tables, or decision records before modifying files.

2. **Preserve Portal-specific adaptations** — The Portal deployment has intentional differences from Bicep:
   - ARM JSON uses `[expression]` syntax instead of Bicep interpolation
   - The form.json uses `Microsoft.Common.*` and `Microsoft.Solutions.*` UI elements
   - Linked template parameters are wrapped in `{ "value": ... }` objects
   - Conditions use ARM `condition` properties, not Bicep `if` syntax
   - The `createObject()` function is used to build inline parameter objects

3. **Maintain deployment integrity** — After any change:
   - Verify all `dependsOn` references are valid
   - Confirm condition variables align between `template.json` and `form.json` visibility rules
   - Ensure linked template URIs match actual wrapper filenames
   - Validate parameter flow from form → template → wrapper

4. **Update documentation** — When significant changes are made, update:
   - `PortalDeploymentGuide.md` if user-facing options change
   - `PORTAL_BICEP_ALIGNMENT_ANALYSIS.md` with the alignment status
   - The `releaseTag` variable in `template.json` if versioning advances
   - `bicep-only-no-portal.md` if a feature is skipped

### What NOT to Change

- Do not modify `README.md` — it is shared with the main branch
- Do not modify `CODE_OF_CONDUCT.md`, `LICENSE`, `SECURITY.md`, or `SUPPORT.md`
- Do not push changes to `main` branch files (Bicep source, Terraform, docs site)
- Do not alter the `.gitignore` rules for `context/` and `.github/` exclusions
- Do not remove brownfield support (`resourceIds` parameter, existing resource ID checks)

## File Relationships

```
form.json (Portal UI)
    │
    ├── Collects user input → maps to template.json parameters
    │
template.json (Orchestrator)
    │
    ├── Parameters: deployToggles, baseName, flagPlatformLandingZone, etc.
    ├── Variables: deploy* conditions, naming, template URIs
    ├── Resources: Microsoft.Resources/deployments (linked templates)
    │
    └── wrappers/ (Linked Templates)
        ├── avm.*.json — AVM module wrappers (Bicep-compiled)
        └── res.*.json — Custom glue logic (hand-authored ARM)
```

## Current Resource Inventory

### AVM-Based Wrappers
| Wrapper | AVM Module | Purpose |
|---------|-----------|---------|
| `avm.ptn.ai-ml.ai-foundry.json` | `avm/ptn/ai-ml/ai-foundry` | AI Foundry hub + project + model deployments |
| `avm.res.api-management.service.json` | `avm/res/api-management/service` | API Management (AI Gateway) |
| `avm.res.app-configuration.configuration-store.json` | `avm/res/app-configuration/configuration-store` | App Configuration |
| `avm.res.app.container-app.json` | `avm/res/app/container-app` | Container App (orchestrator) |
| `avm.res.app.managed-environment.json` | `avm/res/app/managed-environment` | Container Apps Environment |
| `avm.res.compute.build-vm.json` | `avm/res/compute/virtual-machine` | Build VM (Linux) |
| `avm.res.compute.jump-vm.json` | `avm/res/compute/virtual-machine` | Jump VM (Windows) |
| `avm.res.compute.virtual-machine.json` | `avm/res/compute/virtual-machine` | Generic VM wrapper |
| `avm.res.container-registry.registry.json` | `avm/res/container-registry/registry` | Container Registry |
| `avm.res.document-db.database-account.json` | `avm/res/document-db/database-account` | Cosmos DB |
| `avm.res.insights.component.json` | `avm/res/insights/component` | Application Insights |
| `avm.res.key-vault.vault.json` | `avm/res/key-vault/vault` | Key Vault |
| `avm.res.maintenance.maintenance-configuration.json` | `avm/res/maintenance/maintenance-configuration` | VM Maintenance Config |
| `avm.res.network.application-gateway.json` | `avm/res/network/application-gateway` | Application Gateway |
| `avm.res.network.azure-firewall.json` | `avm/res/network/azure-firewall` | Azure Firewall |
| `avm.res.network.firewall-policy.json` | `avm/res/network/firewall-policy` | Firewall Policy |
| `avm.res.network.network-security-group.json` | `avm/res/network/network-security-group` | NSG |
| `avm.res.network.private-dns-zone.json` | `avm/res/network/private-dns-zone` | Private DNS Zone |
| `avm.res.network.private-endpoint.json` | `avm/res/network/private-endpoint` | Private Endpoint |
| `avm.res.network.public-ip-address.json` | `avm/res/network/public-ip-address` | Public IP |
| `avm.res.network.virtual-network.json` | `avm/res/network/virtual-network` | Virtual Network |
| `avm.res.network.waf-policy.json` | `avm/res/network/waf-policy` | WAF Policy |
| `avm.res.operational-insights.workspace.json` | `avm/res/operational-insights/workspace` | Log Analytics Workspace |
| `avm.res.search.search-service.json` | `avm/res/search/search-service` | AI Search |
| `avm.res.storage.storage-account.json` | `avm/res/storage/storage-account` | Storage Account |

### Custom Wrappers
| Wrapper | Purpose |
|---------|---------|
| `res.ai-foundry.json` | AI Foundry hub/project deployment |
| `res.ai-foundry-connection-insights.json` | Connect App Insights to AI Foundry |
| `res.ai-foundry-connection-search.json` | Connect AI Search to AI Foundry |
| `res.ai-foundry-connection-storage.json` | Connect Storage to AI Foundry |
| `res.app-configuration-populate.json` | Populate App Config with service endpoints |
| `res.bastion-host.json` | Azure Bastion Host |
| `res.bing-search.json` | Bing Search for grounding |
| `res.cosmos-role-assignment.json` | Cosmos DB data-plane RBAC |
| `res.managed-identity.json` | User-Assigned Managed Identity |
| `res.nat-gateway.json` | NAT Gateway |
| `res.private-link-scope.json` | Azure Monitor Private Link Scope |
| `res.role-assignment.json` | Resource-scoped RBAC role assignments |
| `res.vm-custom-script-extension.json` | Build VM software installation |

## Translation Patterns: Bicep → ARM JSON

When converting Bicep changes to ARM JSON for this repo, follow these patterns:

| Bicep | ARM JSON Equivalent |
|-------|-------------------|
| `param foo string` | `"parameters": { "foo": { "type": "string" } }` |
| `var bar = '...'` | `"variables": { "bar": "..." }` |
| `resource x '...' = if (cond) { }` | `{ "condition": "[variables('cond')]", ... }` |
| `module m './path.bicep' = { }` | `Microsoft.Resources/deployments` with `templateLink` |
| `'${baseName}-suffix'` | `"[concat(parameters('baseName'), '-suffix')]"` |
| `existing` keyword | Separate `resourceIds` parameter with fallback logic |
| `@description('...')` | `"metadata": { "description": "..." }` |
| `output x string = ...` | `"outputs": { "x": { "type": "string", "value": "..." } }` |
| `dependsOn: [otherModule]` | `"dependsOn": ["deploymentName"]` |

## Security Guidelines

- Never hardcode secrets, keys, or connection strings in any template
- Maintain `secureString` type for all password parameters
- Preserve RBAC least-privilege assignments (do not broaden role scopes)
- Keep private endpoint and private DNS zone configurations intact
- Do not remove NSG rules or weaken network isolation
- Defender for AI and Key Vault toggles must remain opt-in (default: disabled)

## Quality Checklist

Before considering any change complete:

- [ ] All `dependsOn` references resolve to valid deployment names
- [ ] All `templateLink.uri` values match files in `portal/wrappers/`
- [ ] All condition variables have matching entries in the `variables` section
- [ ] Form visibility rules in `form.json` align with deployment conditions in `template.json`
- [ ] Parameter names flow consistently: form.json output → template.json parameter → wrapper parameter
- [ ] No broken ARM expression syntax (`[concat(...)]`, `[if(...)]`, `[coalesce(...)]`)
- [ ] `releaseTag` and `baseTemplateUri` reflect the correct branch and version
- [ ] `PortalDeploymentGuide.md` reflects any user-facing changes