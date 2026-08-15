# AI Citadel Governance Hub — Terraform Deployment Guide

> **Scope:** This document covers the full deployment lifecycle for the Terraform
> port of the AI Hub Gateway Citadel accelerator: prerequisites, ordering,
> rollout strategies, every optional add-on, and the exact commands for each
> scenario.
>
> **Related files:**
> [scripts/deploy.sh](scripts/deploy.sh) / [scripts/deploy.ps1](scripts/deploy.ps1) ·
> [environments/dev.tfvars](environments/dev.tfvars) ·
> [environments/prod.tfvars](environments/prod.tfvars)

---

## 1. Mental model: how this differs from Bicep

The Bicep accelerator deploys its stack in **two tiers**:

1. **`main.bicep`** — core resource plane + APIM + APIC.
2. **Follow-on sub-deployments** (separate `az deployment sub create`
   invocations) for pieces that `main.bicep` cannot express inline:
   - `entra-id-setup/setup.ps1` — needs MS Graph (not ARM).
   - `foundry-integration/connection-apim.bicep` — needs the APIM subscription
     key as a **runtime input**.
   - `citadel-access-contracts/main.bicep` — per-use-case products that change
     often post-deploy.
   - `llm-backend-onboarding/` — adding/removing models.
   - `apim-gateway-upgrade/` — changing APIM SKU.

**Terraform has no such split.** The port folds every follow-on into the root
graph and resolves ordering through resource references + `depends_on`. As a
result:

- A single `terraform apply` can deploy the entire stack, including Entra ID,
  Foundry→APIM connection, and access contracts.
- All follow-ons are gated by **feature-flag variables** (`enable_*`) so you
  still choose what to roll out.
- If you prefer the Bicep workflow (stage core, validate, then enable
  add-ons), the `--phased` deploy-script mode gives you two sequential
  `plan`/`apply` passes against the same state.

---

## 2. Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| Terraform | ≥ 1.5.0 | Declared in [versions.tf](versions.tf) |
| Azure CLI (`az`) | ≥ 2.57 | Used for auth + RP registration + Logic App code publish (uses core `az functionapp` commands; no extensions needed) |
| `azurerm` provider | `~> 4.0` | Auto-installed by `terraform init` |
| `azapi` provider | `~> 2.0` | Used for APIM v2 backends, MCP, APIC |
| `azuread` provider | `~> 3.0` | Only installed/used when `enable_entra_id_setup = true` |
| `archive` / `null` providers | `~> 2.5` / `~> 3.2` | Used by the Logic App workflow-code publish step |
| Azure subscription | Owner or equivalent | Creates RBAC role assignments |
| Tenant permissions (Entra add-on only) | `Application.ReadWrite.All` | Required to create app registrations |

Sign in before anything else:

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 2.1 Script flavors: Bash & PowerShell

Every helper in [scripts/](scripts/) ships in **two interchangeable flavors** —
Bash (`*.sh`) and PowerShell 7+ (`*.ps1`). Both drive the same Terraform graph;
pick whichever suits your shell. This guide's examples use the Bash form, but
every `./scripts/*.sh` command has a `./scripts/*.ps1` equivalent. The only
difference is flag syntax: Bash uses `--kebab-case` flags, PowerShell uses
`-PascalCase` switches.

| Bash (`deploy.sh`) | PowerShell (`deploy.ps1`) |
|---|---|
| `dev` / `prod` (positional) | `dev` / `prod` (positional) |
| `--auto-approve` | `-AutoApprove` |
| `--phased` | `-Phased` |
| `--with-entra` | `-WithEntra` |
| `--with-foundry-conn` | `-WithFoundryConn` |
| `--with-access-contracts` | `-WithAccessContracts` |
| `--with-mcp-samples` | `-WithMcpSamples` |
| `--with-jwt` | `-WithJwt` |
| `--with-apic-onboarding` | `-WithApicOnboarding` |
| `--all-addons` | `-AllAddons` |
| `--skip-logic-app-code` | `-SkipLogicAppCode` |
| `--logic-app-code-only` | `-LogicAppCodeOnly` |
| `--help` | `-Help` |

**Example (identical result):**

```bash
./scripts/deploy.sh prod --all-addons --phased --auto-approve
```

```powershell
./scripts/deploy.ps1 prod -AllAddons -Phased -AutoApprove
```

The same mapping applies to the other helpers:
[bootstrap-state](scripts/bootstrap-state.ps1),
[validate](scripts/validate.ps1), [destroy](scripts/destroy.ps1), and
[import-existing](scripts/import-existing.ps1) all expose `.ps1` equivalents
with positional `dev`/`prod` arguments.

---

## 3. Execution ordering (what runs and when)

Terraform builds a DAG from every explicit reference + `depends_on` clause.
The effective order for a full deployment is:

```text
0. Random suffix + Resource Group
1. networking         ── VNet, 3 subnets, NSGs, route table, DNS zones
2. eventhub           ── namespace + ai-usage/pii-usage hubs + consumer groups
   cosmosdb           ── account + usage-db + 4 containers
   monitoring         ── LAW + 3 App Insights + 3 dashboards + AMPLS
   ai_services        ── Foundry account + project + APIC scaffold
                       (all run in parallel — no cross-dependencies)
3. security           ── Key Vault + Foundry KV RBAC
4. redis              ── Azure Managed Redis + PE + APIM caches link
5. entra_id           ── (optional) azuread_application + SP + KV secret
6. apim               ── APIM service + identity + loggers + diagnostics
   ├─ backends        ── per-model LLM backends + pools + content safety
   │                    + AI search + embeddings
   ├─ fragments       ── 21 static + 3 dynamic policy fragments
   ├─ extra-apis      ── Unified AI, AI Search, DocIntel×2, Inference,
   │                    Realtime, Weather, Weather MCP, MS Learn MCP
   ├─ named-values    ── JWT-*, piiServiceKey + 4 operation policies
   ├─ apic-onboarding ── (optional) register each API in APIC
   └─ foundry-sub     ── (optional) dedicated APIM subscription for Foundry
7. logic_app          ── Logic App Standard + 4 storage PEs + MI RBAC
   └─ publish_workflows
                      ── zip + `az functionapp deployment source config-zip`
                         of logicapp-src/usage-ingestion-logicapp (4 workflows +
                         host.json + connections.json). On by default;
                         gated by `enable_logic_app_code_deploy`.
8. foundry.connection_apim
                      ── (optional) Foundry project → APIM connection
9. access_contracts   ── (optional) per-use-case APIM products + policies
```

Anything upstream is mandatory; anything marked `(optional)` is gated by a
feature flag.

---

## 4. Feature flags (what's optional)

Every add-on defaults to **off** unless listed otherwise. You can set them in
`environments/<env>.tfvars`, via `-var=…=true` on the command line, or via
the `--with-*` shortcuts in [scripts/deploy.sh](scripts/deploy.sh).

| Variable | Default | Shortcut flag | Effect |
|---|---|---|---|
| `enable_entra_id_setup` | `false` | `--with-entra` | Creates Entra ID app registration, service principal, client secret → KV; auto-populates APIM JWT-* named values. |
| `enable_foundry_apim_connection` | `false` | `--with-foundry-conn` | Creates Foundry project → APIM connection (ApiKey) + dedicated APIM subscription. |
| `enable_access_contracts` | `false` | `--with-access-contracts` | Reads the `access_contracts` map and creates per-use-case APIM products, policies, subscriptions, and optional KV secrets + Foundry connections. |
| `is_mcp_sample_deployed` | `false` | `--with-mcp-samples` | Enables Weather API + Weather MCP + MS Learn MCP APIs. |
| `enable_jwt_auth` | `false` | `--with-jwt` | Populates JWT-* named values from `jwt_tenant_id` / `jwt_app_registration_id`. Auto-overridden by `enable_entra_id_setup`. |
| `enable_api_center_onboarding` | `false` | `--with-apic-onboarding` | Registers each APIM API in API Center with version + definition + deployment records. |
| `enable_unified_ai_api` | depends on tfvars | — | Wildcard unified AI API. |
| `enable_azure_ai_search` | depends on tfvars | — | AI Search Index API + backends from `ai_search_instances`. |
| `enable_document_intelligence` | depends on tfvars | — | Legacy `/formrecognizer` + current `/documentintelligence` APIs. |
| `enable_ai_model_inference` | depends on tfvars | — | Model Inference API. |
| `enable_openai_realtime` | depends on tfvars | — | WebSocket Realtime API. |
| `enable_embeddings_backend` | `false` | — | Dedicated embeddings backend for semantic cache. |
| `enable_pii_anonymization` | `false` | — | PII redaction policy + `piiServiceKey` named value (secret). |
| `enable_api_center` | `true` | — | Provisions the API Center service (workspace, environments, metadata schemas). |
| `eventhub_disaster_recovery_config` | empty | — | Optional EH DR namespace pairing. |
| `configure_circuit_breaker` | `false` | — | Adds circuit-breaker rules to LLM backends. |
| `enable_logic_app_code_deploy` | `true` | `--skip-logic-app-code` (inverse) | Zips and publishes `logicapp-src/usage-ingestion-logicapp` to the Logic App Standard site after infra is ready. See §7.8. |

---

## 5. First deployment: step by step

### 5.1 Configure your environment

The `environments/*.tfvars` files are git-ignored — only the `.example`
templates are committed. Copy the template for your target environment and fill
in the values:

```bash
cp environments/dev.tfvars.example environments/dev.tfvars
# (prod) cp environments/prod.tfvars.example environments/prod.tfvars
```

Then edit [environments/dev.tfvars](environments/dev.tfvars):

```hcl
subscription_id        = "YOUR-SUBSCRIPTION-ID"   # auto-rewritten by deploy.sh
location               = "swedencentral"
environment_name       = "citadel-dev"
resource_group_name    = "rg-citadel-dev"

# Feature flags (start conservative, enable more over time)
enable_azure_ai_search       = false
enable_document_intelligence = false
enable_unified_ai_api        = true
enable_api_center            = true
enable_api_center_onboarding = false
enable_jwt_auth              = false
```

### 5.2 Bootstrap (first time only)

```bash
# Verify Azure login
az account show

# Register required resource providers (deploy.sh does this too)
./scripts/bootstrap-state.sh     # (optional) set up remote state
```

### 5.3 Core-only deployment

```bash
./scripts/deploy.sh dev
```

This is equivalent to `main.bicep` with everything but APIC onboarding
disabled. Adds ~35 resources. Expect 25–35 minutes for the first run
(APIM + Redis dominate).

### 5.4 Verify

```bash
./scripts/validate.sh dev
terraform output
```

### 5.5 LLM backend routing (auto-derived, single apply)

As of this revision, the §5.3 core apply produces a **fully-routed gateway
in one shot**. `llm_backend_config` is auto-derived in
[main.tf](main.tf) from `enable_ai_foundry` + `ai_foundry_instances` +
`ai_foundry_models`, with endpoints sourced from
`module.foundry.foundry_endpoints` (late-bound — known after apply, which
Terraform handles transparently because `for_each` keys are deterministic
`foundry-${location}-${index}` strings).

**What you get automatically:**

- One APIM backend (`azapi_resource.llm_backend`) per Foundry instance,
  priority `1` for index `0`, priority `2` for subsequent instances.
- Models grouped into pools by `ai_service_index` — every model you list
  under `ai_foundry_models` targeting instance `i` is attached to that
  instance's backend.
- The three dynamic policy fragments (`set-backend-pools`,
  `get-available-models`, `metadata-config`) are populated with real
  routing tables.
- Named values for the backend IDs / pool IDs are created automatically
  (they're gated on `length(llm_backend_config) > 0` internally — the
  auto-derived list lights them up).

**When to override (optional).** Populate either of these variables in your
tfvars:

- `llm_backend_config` — **full override.** Non-empty value replaces the
  auto-derived list entirely. Use when you need non-Foundry backends
  exclusively (external Azure OpenAI, third-party LLM gateway, on-prem
  model server).
- `extra_llm_backends` — **append.** Added on top of the auto-derived
  Foundry list. Use to mix Foundry (auto) with external backends in the
  same gateway. Same object shape as `llm_backend_config`.

```hcl
# Example: keep Foundry auto-derive + add an external Azure OpenAI backend
llm_backend_config = []  # or omit entirely — default is []
extra_llm_backends = [
  {
    backend_id   = "external-aoai-0"
    backend_type = "azure-openai"
    endpoint     = "https://my-aoai-resource.openai.azure.com/"
    auth_scheme  = "apiKey"
    priority     = 2
    weight       = 100
    supported_models = [
      { name = "gpt-4.1", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "2025-04-14" },
    ]
  },
]
```

**Discover the auto-derived endpoints** (for verification / external
scripts):

```bash
terraform output -json ai_foundry_endpoints | jq -r '.[]'
```

**Rules to keep in mind (apply to both auto-derived and overridden
configs):**

- `backend_type` is one of `ai-foundry`, `azure-openai`, or `external`.
- `auth_scheme = "managedIdentity"` works out of the box for Foundry — the
  APIM UAMI already has `Cognitive Services OpenAI User` on every Foundry
  account deployed by the stack. Use `apiKey` for external backends.
- Multiple backends advertising the same `supported_models[*].name` at the
  same `priority` form a load-balanced pool with automatic failover. Use
  different `priority` values for active/standby routing.

---

## 6. Add-on deployments

### 6.1 Single-apply mode (Terraform-native)

Deploy everything in one pass:

```bash
./scripts/deploy.sh dev --with-entra --with-foundry-conn --with-access-contracts --with-mcp-samples --with-apic-onboarding
```

Or the shorthand:

```bash
./scripts/deploy.sh dev --all-addons
```

Terraform computes the full graph and creates dependencies correctly in one
`apply`. This is the **recommended path** for most environments — it's
faster, atomic, and gives you a single state snapshot.

### 6.2 Phased mode (Bicep-style follow-ons)

When you want to deploy core first, validate, then layer add-ons on top:

```bash
./scripts/deploy.sh prod --all-addons --phased
```

The script performs:

| Phase | What runs | What's forced off |
|---|---|---|
| Phase 1 — `core` | networking, monitoring, data, APIM service + backends + fragments + APIs | `enable_entra_id_setup=false`, `enable_foundry_apim_connection=false`, `enable_access_contracts=false`, `is_mcp_sample_deployed=false`, `enable_jwt_auth=false`, `enable_api_center_onboarding=false` |
| Phase 2 — `add-ons` | Re-applies with the selected `--with-*` flags enabled; only the add-on resources change | nothing forced — uses your flag selection |

This mirrors the Bicep "deploy + follow-on" workflow without splitting the
state. If you pass `--phased` without any `--with-*` flags, phase 2 is a
no-op (plan reports "no changes").

### 6.3 Single add-on later

After a successful core deployment, enable just one add-on:

```bash
./scripts/deploy.sh dev --with-entra
```

Terraform plan shows exactly the new resources (≈6 for Entra, ≈2–5 for
Foundry connection, N×6 for access contracts). You can keep re-running with
different flags without touching anything else.

---

## 7. Add-on reference

### 7.1 Entra ID (`--with-entra`)

**Bicep parity:** `entra-id-setup/setup.ps1` (uses MS Graph, runs outside
`main.bicep` in Bicep).

**What gets created** ([modules/entra-id/](modules/entra-id/)):

- `azuread_application` — display name `ai-citadel-gateway-<env>`, OAuth2
  `access_as_user` scope, 4 app roles (`Task.ReadWrite`, `Models.Read`,
  `MCP.Read`, `Agent.Read`) with the same canonical GUIDs as the PowerShell
  script (idempotent re-runs), + MS Graph `User.Read`.
- `azuread_application_identifier_uri` — `api://<client_id>` (split to avoid
  self-reference).
- `azuread_service_principal`.
- `azuread_application_password` — rotated every
  `entra_client_secret_rotation_days` (default 730 = 2 years).
- `azurerm_key_vault_secret` — writes the secret to KV as
  `ENTRA-APP-CLIENT-SECRET`.

**Side effect:** When enabled, `local.effective_{enable_jwt_auth,
jwt_tenant_id, jwt_app_registration_id}` override the bare `jwt_*` variables
on the APIM module, so the `JWT-TenantId` and `JWT-AppRegistrationId` named
values auto-populate from the live app registration + tenant.

**Variables:**

| Variable | Default |
|---|---|
| `enable_entra_id_setup` | `false` |
| `entra_app_display_name_prefix` | `"ai-citadel-gateway"` |
| `entra_client_secret_name` | `"ENTRA-APP-CLIENT-SECRET"` |
| `entra_client_secret_rotation_days` | `730` |

**Example:**

```bash
./scripts/deploy.sh dev --with-entra
```

### 7.2 Foundry → APIM connection (`--with-foundry-conn`)

**Bicep parity:** `foundry-integration/connection-apim.bicep`.

**What gets created:**

- `modules/apim/foundry-subscription.tf` — dedicated APIM subscription that
  exposes a primary key as an output.
- `modules/foundry/connection-apim.tf` —
  `Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview`
  per (foundry project × selected API) with Custom Keys auth, plus metadata
  (`deploymentInPath`, `inferenceAPIVersion`, `deploymentAPIVersion`,
  `modelDiscovery`, `models`, `customHeaders`).

**Why it was a follow-on in Bicep:** Bicep couldn't wire the APIM subscription
key into the Foundry connection at plan time. Terraform uses the output of
the subscription resource directly.

**Example:**

```bash
./scripts/deploy.sh dev --with-foundry-conn
```

### 7.3 Access contracts (`--with-access-contracts`)

**Bicep parity:** `citadel-access-contracts/main.bicep` + its 3 sub-modules.

**What gets created** ([modules/access-contracts/](modules/access-contracts/)):

Per entry in `var.access_contracts`:

- `azurerm_api_management_product` + display name, description, terms.
- `azurerm_api_management_product_api` (per allowed API).
- `azurerm_api_management_product_policy` — with allow-list of permitted
  deployments rendered from the contract's `models` list; can also enforce
  JWT.
- `azurerm_api_management_subscription`.
- (optional) `azurerm_key_vault_secret` for the primary key.
- (optional) Foundry project connection created against this product.

**Example:**

```hcl
# environments/dev.tfvars
access_contracts = [
  {
    name          = "marketing-team"
    display_name  = "Marketing team"
    apis          = ["universal-llm-api", "unified-ai-api"]
    models        = ["gpt-4o", "gpt-4o-mini"]
    jwt_required  = true
    write_kv_key  = true
    foundry_project = "marketing-proj"
  },
  # …
]
```

```bash
./scripts/deploy.sh dev --with-access-contracts
```

### 7.4 MCP samples (`--with-mcp-samples`)

**Bicep parity:** `mcp-from-api.bicep` + `mcp-existing.bicep`.

Enables two APIM MCP resources:

- **Weather API + Weather MCP** — demo API converted into an MCP server.
- **MS Learn MCP** — external MCP endpoint registered via
  `azapi_resource.ms_learn_mcp_backend` + `azapi_resource.ms_learn_mcp`.

**Example:**

```bash
./scripts/deploy.sh dev --with-mcp-samples
```

### 7.5 API Center onboarding (`--with-apic-onboarding`)

**Bicep parity:** `apim/api-center-onboarding.bicep`.

Registers each enabled APIM API in API Center with:

- `Microsoft.ApiCenter/services/workspaces/apis@2024-03-01`
- `…/versions`
- `…/definitions` (with the OpenAPI spec or import link)
- `…/deployments` (pointing at the running APIM gateway URL +
  `api-dev` / `mcp-dev` / `api-prod` / `mcp-prod` environment)

The APIC service itself is created unconditionally when `enable_api_center =
true` (default); this flag only controls the per-API record creation.

**Example:**

```bash
./scripts/deploy.sh dev --with-apic-onboarding
```

### 7.6 JWT auth without Entra (`--with-jwt`)

Use this when you already have an app registration and just want APIM to
enforce JWT against its tenant/app-reg IDs.

```bash
./scripts/deploy.sh dev \
  --with-jwt \
  -- -var=jwt_tenant_id=<tid> -var=jwt_app_registration_id=<aid>
```

(Or set them in `dev.tfvars`.)

> ⚠️ The `--` isn't parsed by the script; pass extra Terraform vars via
> `TF_VAR_*` environment variables or tfvars instead:
> ```bash
> export TF_VAR_jwt_tenant_id=<tid>
> export TF_VAR_jwt_app_registration_id=<aid>
> ./scripts/deploy.sh dev --with-jwt
> ```

### 7.7 Enabling `--with-entra` implies JWT

`enable_entra_id_setup = true` derives `effective_enable_jwt_auth = true`
automatically, populating all four JWT-* named values from the live app
registration. You don't need to pass `--with-jwt` alongside `--with-entra`.

### 7.8 Logic App workflow code (off by default)

**Bicep parity:** `azd deploy usageProcessingLogicApp` in the upstream
accelerator's `azure.yaml`.

**What gets created** ([modules/logic-app/code-deploy.tf](modules/logic-app/code-deploy.tf)):

- `data.archive_file.workflow_code` — zips the Logic App Standard project
  folder (`host.json`, `connections.json`, and the 4 `workflow.json` files
  under `ai-usage-ingestion/`, `ai-usage-streaming-ingestion/`,
  `llm-usage-ingestion/`, `pii-usage-ingestion/`). Excludes
  `workflow-designtime/`, `.funcignore`, and `local.settings.json`.
- `null_resource.publish_workflows` — runs
  `az functionapp deployment source config-zip` (Logic App Standard is built
  on the Functions runtime, so the Functions zip-deploy command is the
  supported path). Ships in core Azure CLI — no extension install required.

**Runtime prerequisites:**

- `az` CLI ≥ 2.57. No extra extensions needed.
- A signed-in principal with **Logic App Contributor** (or higher) on the RG
  — the same identity that runs `terraform apply`.
- Network reachability to `management.azure.com` and the Logic App's SCM
  endpoint (`<sitename>.scm.azurewebsites.net`). The zip is uploaded through
  Kudu, so if the Logic App itself is behind a private endpoint the
  deployer must run from inside the VNet. For public-network sites
  (`apim_v2_public_network_access = true`) SCM is reachable from anywhere.

**Trigger behaviour:**

| Change | Effect on next apply |
|---|---|
| Edit any file under `logicapp-src/usage-ingestion-logicapp/` | `code_sha256` trigger changes → re-publish. |
| Logic App site is recreated | `logic_app_id` trigger changes → re-publish. |
| Infrastructure-only edits elsewhere | `null_resource` is untouched (no re-publish). |

**Variables:**

| Variable | Default |
|---|---|
| `enable_logic_app_code_deploy` | `true` |
| `logic_app_code_source_path` | `logicapp-src/usage-ingestion-logicapp` (set in `environments/dev.tfvars`; blank disables the publish) |

**Examples:**

```bash
# Default — publish as part of the normal apply
./scripts/deploy.sh dev

# Iterate on IaC without re-publishing the workflows
./scripts/deploy.sh dev --skip-logic-app-code

# Iterate on workflow JSON only — skips full plan/apply and retargets
# `module.logic_app.null_resource.publish_workflows[0]`
./scripts/deploy.sh dev --logic-app-code-only

# Point at a fork or a locally-modified project tree
export TF_VAR_logic_app_code_source_path=/path/to/my/workflows
./scripts/deploy.sh dev --logic-app-code-only
```

**Rollback:** there is no native slot history on Logic App Standard. To roll
back, check out an earlier commit of `logicapp-src/usage-ingestion-logicapp/`
and run `./scripts/deploy.sh <env> --logic-app-code-only`.

---

## 8. Full rollout scenarios

### 8.1 Developer sandbox (one-shot, everything)

```bash
./scripts/deploy.sh dev --all-addons --auto-approve
```

Approx. 40 resources beyond core. Good for local demos.

### 8.2 Production (staged, reviewed)

```bash
# Phase 1: core only — validate gateway endpoints, logs, dashboards
./scripts/deploy.sh prod

# Smoke-test APIM gateway
./scripts/validate.sh prod

# Phase 2: identity
./scripts/deploy.sh prod --with-entra

# Verify Entra secret landed in KV, then enable JWT
./scripts/deploy.sh prod --with-entra --with-apic-onboarding

# Phase 3: downstream consumers
./scripts/deploy.sh prod --with-entra --with-apic-onboarding \
  --with-foundry-conn --with-access-contracts
```

Each run is idempotent; re-running with the same flags is a no-op.

### 8.3 Bicep-style single-command phased

```bash
./scripts/deploy.sh prod --all-addons --phased
```

The script executes:

1. `terraform plan -var=enable_entra_id_setup=false … -out=plan-core` → apply
2. `terraform plan -var=enable_entra_id_setup=true  … -out=plan-addons` → apply

Same end state as `--all-addons` without `--phased`, but with an
intermediate checkpoint.

### 8.4 Disabling an add-on

Run without the flag. Terraform plans a destroy of just that module:

```bash
# Was: ./scripts/deploy.sh dev --with-access-contracts
./scripts/deploy.sh dev            # plan shows destroy of access-contracts
```

Destroys are limited to the feature-flagged resources; core stays.

---

## 9. Interactions with existing tooling

### 9.1 LLM backend onboarding

The Bicep accelerator ships a separate `llm-backend-onboarding/` sub-deployment.
Terraform handles this inline — edit `llm_backend_config` in your tfvars and
re-run `./scripts/deploy.sh <env>`. Changes are diff'd; only the affected
backends + pools + the 3 dynamic policy fragments get re-applied.

### 9.2 APIM SKU upgrade

The Bicep `apim-gateway-upgrade/` sub-deployment isn't needed. Change
`apim_sku_name` + `apim_sku_capacity` in your tfvars and re-run — Terraform
applies the SKU change in place on the existing APIM resource.

### 9.3 Auto-import on drift

If a resource exists in Azure but not in the Terraform state (e.g. from a
previous partial run), `deploy.sh` detects `already exists` errors, offers to
run [scripts/import-existing.sh](scripts/import-existing.sh), and retries the
apply automatically.

### 9.4 Validation notebooks (`validation/` + `shared/`)

The Jupyter test suite ported from the upstream accelerator lives in
[validation/](validation/) with its Python helpers in [shared/](shared/). The
suite is four notebooks that exercise a **live** deployment: LLM backend
onboarding, the Universal LLM API across every model, access contracts, and
model-alias routing.

Each notebook is configured **manually**: open the first (config) cell and
replace the `"REPLACE"` sentinel values — plus any inline config blocks such as
`llm_backends_config` / `model_aliases` — with values that match your
deployment, then run the cell. Any value left as `"REPLACE"` is flagged with a
warning so you can see what still needs filling in.

If you deployed with this repo's Terraform flow, pull the values you need
straight from state and paste them into the config cell:

```bash
terraform output -raw resource_group_name
terraform output -raw location
terraform output -json llm_backend_config
terraform output -raw key_vault_name
```

[shared/utils.py](shared/utils.py) also provides a Terraform-output bridge:
`azd_env_get()` resolves a requested key from `terraform output -json`, with an
internal alias map translating each azd-style variable name into the matching
Terraform output:

| Notebook variable / azd name | Terraform output |
|---|---|
| `AZURE_RESOURCE_GROUP`, `GOVERNANCE_HUB_RESOURCE_GROUP` | `resource_group_name` |
| `AZURE_LOCATION`, `LOCATION` | `location` |
| `AZURE_SUBSCRIPTION_ID` | `subscription_id` |
| `KEY_VAULT_NAME` | `key_vault_name` |
| `AI_FOUNDRY_SERVICES` | `ai_foundry_services` |
| `LLM_BACKEND_CONFIG`, `LLM_BACKENDS_CONFIG` | `llm_backend_config` |
| `APIM_NAME` | `apim_name` |
| `APIM_GATEWAY_URL` | `apim_gateway_url` |

The `location`, `subscription_id`, `key_vault_name`, `ai_foundry_services`, and
`llm_backend_config` outputs were added to [outputs.tf](outputs.tf) for this
purpose; they only appear in state after a `terraform apply`. The bridge
resolves the Terraform root as the parent of `shared/` (the repo root);
override with the `CITADEL_TF_DIR` environment variable to point at another
state directory (e.g. `llm-backend-onboarding/`). `apimtools.py` is
deployment-tool-agnostic — it uses `az` + the Azure SDK with the resource group
/ APIM name passed as parameters.

```bash
pip install -r shared/requirements.txt
# then open any notebook in validation/ and run the first (config) cell
```

See [validation/README.md](validation/README.md) for the full per-notebook
variable map.

---

## 10. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `terraform init` downloads `azuread` even with `enable_entra_id_setup = false` | Provider is declared globally | Expected; the provider is harmless until a resource is created. |
| `A resource with the ID "…applications/…" already exists` | Azure AD app with same display name exists from a prior run | `terraform import module.entra_id[0].azuread_application.gateway /applications/<object-id>` |
| `Unauthorized: The client does not have authorization to perform action 'Microsoft.KeyVault/vaults/secrets/write'` | Current user lacks KV Secrets Officer role | Use the printed `az role assignment create` command from the Key Vault module outputs. |
| APIM deployment stuck ~30 min | First-time APIM provisioning is slow | Normal; don't cancel. Use `az apim list -g <rg>` to check `provisioningState`. |
| `enable_jwt_auth=true` but JWT fails at runtime | `jwt_tenant_id`/`jwt_app_registration_id` placeholders | Enable Entra add-on (`--with-entra`) or set the variables explicitly. |
| Foundry connection fails with "missing subscription key" | APIM subscription hasn't finished provisioning | Re-run `./scripts/deploy.sh <env> --with-foundry-conn`. |
| `az: command not found` during `publish_workflows` | Deployer doesn't have Azure CLI installed | Install `az` CLI or run with `--skip-logic-app-code` and publish manually. |
| Workflow publish fails with `AuthorizationFailed` | Signed-in principal lacks **Website Contributor** / **Logic App Contributor** on the RG | Grant the role or run the zip-deploy as a different principal. |
| Workflow publish hangs / `403 Ip Forbidden` on SCM | Logic App is behind a private endpoint and the deployer isn't on the VNet | Run `--logic-app-code-only` from a jumpbox inside the VNet, or temporarily flip `apim_v2_public_network_access = true`. |
| Logic App runs trigger but workflows are empty | Code-publish skipped or first apply crashed before the null_resource | Run `./scripts/deploy.sh <env> --logic-app-code-only`. |

---

## 11. Tearing down

```bash
./scripts/destroy.sh dev
```

This performs `terraform destroy` with the dev tfvars. Some resources may
linger in Azure for purge-protection reasons:

- **Key Vault** — soft-deleted; purged on destroy when
  `purge_soft_delete_on_destroy = true` (see [providers.tf](providers.tf)).
- **APIM** — soft-deleted; same purge behaviour.
- **Cognitive Services** — soft-deleted; same purge behaviour.

For a hard reset set the var to `true` in your tfvars and re-run destroy.

---

## 12. Reference: command cheatsheet

```bash
# Help
./scripts/deploy.sh --help

# Core only
./scripts/deploy.sh dev
./scripts/deploy.sh prod --auto-approve

# Individual add-ons
./scripts/deploy.sh dev --with-entra
./scripts/deploy.sh dev --with-foundry-conn
./scripts/deploy.sh dev --with-access-contracts
./scripts/deploy.sh dev --with-mcp-samples
./scripts/deploy.sh dev --with-apic-onboarding
./scripts/deploy.sh dev --with-jwt

# Combinations
./scripts/deploy.sh dev --with-entra --with-foundry-conn
./scripts/deploy.sh prod --all-addons

# Phased rollout
./scripts/deploy.sh prod --phased
./scripts/deploy.sh prod --all-addons --phased
./scripts/deploy.sh prod --with-entra --with-foundry-conn --phased

# Logic App workflow code
./scripts/deploy.sh dev --skip-logic-app-code     # infra only
./scripts/deploy.sh dev --logic-app-code-only     # republish workflows only

# Validation + teardown
./scripts/validate.sh dev
./scripts/destroy.sh dev

# Notebook test suite (against a live deployment)
pip install -r shared/requirements.txt   # then run validation/*.ipynb
```

### PowerShell equivalents

Every command above has a PowerShell twin (see §2.1 for the full flag map):

```powershell
# Help
./scripts/deploy.ps1 -Help

# Core only
./scripts/deploy.ps1 dev
./scripts/deploy.ps1 prod -AutoApprove

# Individual add-ons
./scripts/deploy.ps1 dev -WithEntra
./scripts/deploy.ps1 dev -WithFoundryConn
./scripts/deploy.ps1 dev -WithAccessContracts
./scripts/deploy.ps1 dev -WithMcpSamples
./scripts/deploy.ps1 dev -WithApicOnboarding
./scripts/deploy.ps1 dev -WithJwt

# Combinations
./scripts/deploy.ps1 dev -WithEntra -WithFoundryConn
./scripts/deploy.ps1 prod -AllAddons

# Phased rollout
./scripts/deploy.ps1 prod -Phased
./scripts/deploy.ps1 prod -AllAddons -Phased
./scripts/deploy.ps1 prod -WithEntra -WithFoundryConn -Phased

# Logic App workflow code
./scripts/deploy.ps1 dev -SkipLogicAppCode     # infra only
./scripts/deploy.ps1 dev -LogicAppCodeOnly     # republish workflows only

# Validation + teardown
./scripts/validate.ps1 dev
./scripts/destroy.ps1 dev
```

---

## 13. See also

- [README.md](README.md) — project overview.
- [VARIABLES.md](VARIABLES.md) — detailed reference for every variable, including the feature flags.
- [validation/README.md](validation/README.md) — notebook test suite + per-notebook variable map.
- [full-deployment-guide.md (upstream Bicep)](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/citadel-v1/guides/full-deployment-guide.md)
  — the original Bicep deployment guide, for comparison.