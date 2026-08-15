# 🚀 LLM Backend Onboarding (Terraform)

Standalone Terraform deployment for onboarding LLM backends to an existing AI Citadel Governance Hub APIM instance.

## Overview

Automate the onboarding of LLM backends to your APIM-based AI Gateway with a streamlined, infrastructure-as-code approach using Terraform variable files (`terraform.tfvars`).

This module enables dynamic LLM backend routing without modifying APIM policies:

- 📦 **Automatic Backend Creation**: Create APIM backends from configuration
- ⚖️ **Load Balancing**: Distribute requests across multiple backends for the same model
- 🔄 **Automatic Failover**: Route to healthy backends when others are unavailable
- 🔌 **Multi-Provider Support**: Microsoft Foundry, Azure OpenAI, Amazon Bedrock, and external LLM providers
- 📝 **Declarative Configuration**: Simple `terraform.tfvars` files for version control

> This module is a Terraform port of the Bicep [`llm-backend-onboarding`](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/tree/citadel-v1/bicep/infra/llm-backend-onboarding) module from the AI Hub Gateway Solution Accelerator.

## What Gets Created

| Resource | Description |
|----------|-------------|
| **APIM Backends** | Individual backend resources for each LLM endpoint (native managed-identity credentials for Azure OpenAI / AI Foundry) |
| **Backend Pools** | Load-balanced pools for models with multiple backends |
| **Policy Fragments** | Dynamic routing logic for model-based routing, model aliases, and Responses API isolation |
| **Get Available Models Fragment** | Returns available model deployments with capabilities (similar to Azure Cognitive Services API) |
| **Metadata Config Fragment** | Centralized model routing config for the Unified AI API — always deployed with backend onboarding to stay in sync |
| **Resolve Model Alias Fragment** | Resolves client-facing alias names (e.g. `adv-gpt` as an alias for `gpt-5.2` and `gpt-4.1`) to actual underlying models — shared across Azure OpenAI, Universal LLM, and Unified AI APIs |
| **Named Values** | AWS Bedrock credentials (`aws-access-key`/`aws-secret-key`/`aws-region`) and dynamic per-backend API-key named values (Key Vault reference or explicit value) |

## Prerequisites

- Existing deployment of AI Citadel Governance Hub with:
  - User-assigned managed identity configured
  - APIs for Universal LLM API and Azure OpenAI API
- LLM backends deployed and accessible:
  - Microsoft Foundry with model deployments
  - Azure OpenAI resources with model deployments
  - Amazon Bedrock with foundation model access
  - APIM can reach the target backends from a network perspective
- Verify APIM's user-assigned managed identity has the required roles:
  - `Cognitive Services OpenAI User` for Azure OpenAI
  - `Cognitive Services User` for Microsoft Foundry
- For Amazon Bedrock:
  - AWS IAM user with Bedrock access and access keys generated
  - Provide `aws_access_key`, `aws_secret_key`, and `aws_region` variables when deploying — these are stored as secret APIM named values (`aws-access-key`, `aws-secret-key`, `aws-region`)
  - If these variables are not provided, the named values are created with a `NOT_CONFIGURED` placeholder and the gateway returns a `500 AWSCredentialsNotConfigured` error at runtime when a Bedrock backend is invoked
- Terraform >= 1.5 and Azure CLI installed
- Authenticated to Azure (`az login`)

## Quick Start

### 1. Copy and Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 2. Configure Your Backends

Edit `terraform.tfvars`:

```hcl
subscription_id            = "00000000-0000-0000-0000-000000000000" # Your subscription ID
resource_group_name        = "rg-citadel-governance-hub"            # APIM resource group
apim_name                  = "apim-citadel-governance-hub"          # APIM instance name
managed_identity_client_id = "00000000-0000-0000-0000-000000000000" # APIM managed identity client ID

llm_backend_config = [
  {
    backend_id   = "aif-citadel-primary"
    backend_type = "ai-foundry"
    endpoint     = "https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/"
    auth_scheme  = "managedIdentity"
    supported_models = [
      { name = "gpt-4o-mini", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "2024-07-18", retirementDate = "2026-09-30" },
      { name = "gpt-4o", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "2024-11-20", retirementDate = "2026-09-30" },
      { name = "gpt-4.1", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "2025-04-14", retirementDate = "2026-10-14", apiVersion = "2025-04-01-preview", timeout = 180 },
      { name = "DeepSeek-R1", sku = "GlobalStandard", capacity = 1, modelFormat = "DeepSeek", modelVersion = "1", retirementDate = "2099-12-30", inferenceApiVersion = "2024-05-01-preview" },
      { name = "Phi-4", sku = "GlobalStandard", capacity = 1, modelFormat = "Microsoft", modelVersion = "3", retirementDate = "2099-12-30", inferenceApiVersion = "2024-05-01-preview" },
      { name = "text-embedding-3-large", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "1", retirementDate = "2027-04-14" }
    ]
    priority = 1
    weight   = 100
  }
]
```

### 3. Deploy

```bash
./scripts/deploy.sh
```

```powershell
./scripts/deploy.ps1
```

Or manually:

```bash
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### 4. Test

```bash
./scripts/test.sh --api-key "your-apim-subscription-key"
```

```powershell
./scripts/test.ps1 -ApiKey "your-apim-subscription-key"
```

## Configuration Reference

### Backend Configuration Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `backend_id` | string | Yes | Unique identifier for the APIM backend resource (usually the name of the backend resource) |
| `backend_type` | string | Yes | `ai-foundry`, `azure-openai`, `aws-bedrock`, or `external` |
| `endpoint` | string | Yes | Base URL of the LLM service |
| `auth_scheme` | string | Yes | `managedIdentity`, `apiKey`, or `token` (legacy; sets native MI credentials when `managedIdentity`) |
| `auth_type` | string | No | `managed-identity`, `aws-sigv4`, `api-key-bearer`, `api-key-header`, or `none`. Overrides `auth_scheme` for policy-fragment routing |
| `auth_config` | object | No | API-key credential source: `{ named_value_key, key_vault_secret_uri?, secret_value? }` (see below) |
| `supported_models` | list | Yes | Array of model objects (see Model Object Properties below) |
| `priority` | number | No | 1-5, default 1 (lower = higher priority) |
| `weight` | number | No | 1-1000, default 100 (load balancing weight) |

#### `auth_config` Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `named_value_key` | string | No | APIM named value that holds the credential |
| `key_vault_secret_uri` | string | No | Key Vault secret reference (recommended for production) |
| `secret_value` | string | No | Explicit value (testing only — do **not** use in production) |

### Model Object Properties

Each model in the `supported_models` array has these properties:

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | string | Yes | Model name (e.g., `gpt-4o`, `DeepSeek-R1`, `Phi-4`) |
| `sku` | string | No | SKU name for the deployment (default: `Standard`). Used in `get-available-models` response |
| `capacity` | number | No | Capacity/TPM quota (default: 100). Used in `get-available-models` response |
| `modelFormat` | string | No | Model format identifier, e.g., `OpenAI`, `DeepSeek`, `Microsoft` (default: `OpenAI`). Used in `get-available-models` response |
| `modelVersion` | string | No | Version of the model (default: `1`). Used in `get-available-models` response |
| `retirementDate` | string (date) | No | Optional retirement date for the model (YYYY-MM-DD). Used in `get-available-models` response |
| `apiVersion` | string | No | API version for OpenAI-type requests (default: `2024-02-15-preview`). Used by Unified AI API for backend routing |
| `timeout` | number | No | Request timeout in seconds (default: `120`). Used by Unified AI API for per-model timeout configuration |
| `inferenceApiVersion` | string | No | API version for inference-type requests (e.g., `2024-05-01-preview`). Used by Unified AI API for non-OpenAI models |

### Backend Types

#### AI Foundry (`ai-foundry`)

- Uses Azure AI Foundry project endpoints
- Endpoint format: `https://<resource>.cognitiveservices.azure.com/`
- Authentication: Managed identity with Cognitive Services scope
- No URL rewriting required

#### Azure OpenAI (`azure-openai`)

- Uses Azure OpenAI Service endpoints
- Endpoint format: `https://<resource>.openai.azure.com/`
- Authentication: Managed identity with Cognitive Services scope
- Automatic URL rewriting to include `/deployments/{model}/`

#### External (`external`)

- Uses external LLM provider endpoints
- Authentication: API key or backend credentials
- No URL rewriting

#### Amazon Bedrock (`aws-bedrock`)

- Uses Amazon Bedrock runtime endpoints
- Endpoint format: `https://bedrock-runtime.<aws-region>.amazonaws.com`
- Authentication: AWS Signature Version 4 (SigV4) using IAM access keys stored as APIM named values
- Path construction: `/model/{model-id}/converse`
- Requires additional variables: `aws_access_key`, `aws_secret_key`, `aws_region`
- See [Microsoft Learn: Import Amazon Bedrock API](https://learn.microsoft.com/en-us/azure/api-management/amazon-bedrock-passthrough-llm-api) for detailed APIM integration guidance

## Example Configurations

### Single AI Foundry Backend

```hcl
llm_backend_config = [
  {
    backend_id   = "aif-citadel-primary"
    backend_type = "ai-foundry"
    endpoint     = "https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/"
    auth_scheme  = "managedIdentity"
    supported_models = [
      { name = "gpt-4o-mini", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "2024-07-18", retirementDate = "2026-09-30" },
      { name = "gpt-4o", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "2024-11-20", retirementDate = "2026-09-30" },
      { name = "gpt-4.1", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "2025-04-14", retirementDate = "2026-10-14", apiVersion = "2025-04-01-preview", timeout = 180 },
      { name = "DeepSeek-R1", sku = "GlobalStandard", capacity = 1, modelFormat = "DeepSeek", modelVersion = "1", retirementDate = "2099-12-30", inferenceApiVersion = "2024-05-01-preview" },
      { name = "Phi-4", sku = "GlobalStandard", capacity = 1, modelFormat = "Microsoft", modelVersion = "3", retirementDate = "2099-12-30", inferenceApiVersion = "2024-05-01-preview" },
      { name = "text-embedding-3-large", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "1", retirementDate = "2027-04-14" }
    ]
    priority = 1
    weight   = 100
  }
]
```

### Load Balancing Across Regions

As `DeepSeek-R1` is available in 2 different backends, the onboarding will automatically create a backend pool for `DeepSeek-R1` and distribute traffic based on the specified priority/weights.

```hcl
llm_backend_config = [
  {
    backend_id   = "aif-citadel-primary"
    backend_type = "ai-foundry"
    endpoint     = "https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/"
    auth_scheme  = "managedIdentity"
    supported_models = [
      { name = "gpt-4o-mini", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "2024-07-18", retirementDate = "2026-09-30" },
      { name = "gpt-4o", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "2024-11-20", retirementDate = "2026-09-30" },
      { name = "DeepSeek-R1", sku = "GlobalStandard", capacity = 1, modelFormat = "DeepSeek", modelVersion = "1", retirementDate = "2099-12-30", inferenceApiVersion = "2024-05-01-preview" },
      { name = "text-embedding-3-large", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "1", retirementDate = "2027-04-14" }
    ]
    priority = 1
    weight   = 100
  },
  {
    backend_id   = "aif-citadel-secondary"
    backend_type = "ai-foundry"
    endpoint     = "https://aif-RESOURCE_TOKEN-1.cognitiveservices.azure.com/"
    auth_scheme  = "managedIdentity"
    supported_models = [
      { name = "gpt-5", sku = "GlobalStandard", capacity = 50, modelFormat = "OpenAI", modelVersion = "1", retirementDate = "2027-02-05" },
      { name = "DeepSeek-R1", sku = "GlobalStandard", capacity = 1, modelFormat = "DeepSeek", modelVersion = "1", retirementDate = "2099-12-30", inferenceApiVersion = "2024-05-01-preview" }
    ]
    priority = 2
    weight   = 50
  }
]
```

In this example, `DeepSeek-R1` will get a `DeepSeek-R1-backend-pool` with both backends.

### Mixed Providers

This mixes Azure OpenAI and Microsoft Foundry backends. Common models across providers are automatically load balanced (like `DeepSeek-R1` and `text-embedding-3-large` below), while unique models are routed to their specific backend.

```hcl
llm_backend_config = [
  {
    backend_id   = "aif-citadel-primary"
    backend_type = "ai-foundry"
    endpoint     = "https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/"
    auth_scheme  = "managedIdentity"
    supported_models = [
      { name = "gpt-4o-mini", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "2024-07-18", retirementDate = "2026-09-30" },
      { name = "gpt-4o", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "2024-11-20", retirementDate = "2026-09-30" },
      { name = "DeepSeek-R1", sku = "GlobalStandard", capacity = 1, modelFormat = "DeepSeek", modelVersion = "1", retirementDate = "2099-12-30", inferenceApiVersion = "2024-05-01-preview" },
      { name = "text-embedding-3-large", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "1", retirementDate = "2027-04-14" }
    ]
    priority = 1
    weight   = 100
  },
  {
    backend_id   = "aoai-eastus-gpt4"
    backend_type = "azure-openai"
    endpoint     = "https://YOUR-AOAI-RESOURCE.openai.azure.com/"
    auth_scheme  = "managedIdentity"
    supported_models = [
      { name = "gpt-5", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "2025-08-07", retirementDate = "2027-02-05" },
      { name = "DeepSeek-R1", sku = "GlobalStandard", capacity = 1, modelFormat = "DeepSeek", modelVersion = "1", retirementDate = "2099-12-30", inferenceApiVersion = "2024-05-01-preview" },
      { name = "text-embedding-3-large", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "1", retirementDate = "2027-04-14" }
    ]
    priority = 1
    weight   = 100
  }
]
```

### Amazon Bedrock Backend

This example adds an Amazon Bedrock backend alongside Azure backends. The `aws-bedrock` backend type uses AWS SigV4 authentication via IAM access keys stored as APIM named values.

```hcl
llm_backend_config = [
  {
    backend_id   = "aif-citadel-primary"
    backend_type = "ai-foundry"
    endpoint     = "https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/"
    auth_scheme  = "managedIdentity"
    supported_models = [
      { name = "gpt-4o", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "2024-11-20", retirementDate = "2026-09-30" }
    ]
    priority = 1
    weight   = 100
  },
  {
    backend_id   = "bedrock-us-east-1"
    backend_type = "aws-bedrock"
    endpoint     = "https://bedrock-runtime.us-east-1.amazonaws.com"
    auth_scheme  = "token"
    auth_type    = "aws-sigv4"
    supported_models = [
      { name = "us.anthropic.claude-3-5-haiku-20241022-v1:0", sku = "OnDemand", capacity = 1, modelFormat = "Anthropic", modelVersion = "1", retirementDate = "2099-12-30" },
      { name = "us.anthropic.claude-3-5-sonnet-20241022-v2:0", sku = "OnDemand", capacity = 1, modelFormat = "Anthropic", modelVersion = "2", retirementDate = "2099-12-30" },
      { name = "us.amazon.nova-pro-v1:0", sku = "OnDemand", capacity = 1, modelFormat = "Amazon", modelVersion = "1", retirementDate = "2099-12-30" }
    ]
    priority = 1
    weight   = 100
  }
]

# AWS credentials for Bedrock authentication
aws_access_key = "<your-aws-access-key-id>"
aws_secret_key = "<your-aws-secret-access-key>"
aws_region     = "us-east-1"
```

> **Important**: Store AWS access keys securely. Consider using Azure Key Vault references for the APIM named values in production. See [Create IAM user access keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/access-key-self-managed.html#Using_CreateAccessKey) for generating AWS access keys.

## Request Flow

```
1. Client → APIM Gateway
   POST /models/chat/completions
   Body: { "model": "gpt-4o", "messages": [...] }

2. Extract Model
   → requestedModel = "gpt-4o"

3. Find Backend Pool
   → matches "gpt-4o-backend-pool" (load balanced)
   or direct backend if single provider

4. Authenticate
   → Get managed identity token
   → Set Authorization header

5. Route to Backend
   → Forward to healthy backend in pool

6. Return Response
   → Client receives response with usage headers
```

## Model Aliases

Model aliases let you expose a single client-facing model name (for example `multi-cloud-openai`) that the gateway resolves at runtime to one of several underlying real models. Clients keep using the alias even when the underlying line-up changes — the gateway abstracts away the migration **and** transparently load-balances / fails over across the underlying members.

### ⚠️ Phase scope: same-API-spec routing only

This phase of the accelerator does **not** translate between API protocols. Every alias must therefore front backends that share the **same wire-level API spec** — same path, same request/response shape, same auth contract. Inbound requests are routed unchanged to the picked member's underlying pool; only the JSON body's `model` field is rewritten to the resolved real model name.

| Allowed (same spec) | Not allowed (different specs) |
|---|---|
| Foundry + Bedrock-Mantle + Gemini-OpenAI under one alias served via OpenAI `/v1/chat/completions` ✅ | Anthropic Messages + Bedrock Converse under one alias ❌ — different request shapes |
| Multiple Anthropic backends (regions, tenants) under one alias served via `/claude/v1/messages` ✅ | Foundry OpenAI-compat + Anthropic Messages under one alias ❌ — different paths and bodies |
| Multiple Foundry models (gpt-5 + Mistral + Phi-4) under one weighted alias ✅ | Gemini `generateContent` + OpenAI `/v1/chat/completions` under one alias ❌ |

A future phase will add **protocol-passthrough backend types** (e.g. `aws-bedrock-anthropic-passthrough` exposing Bedrock-hosted Claude under the Anthropic Messages spec, and `foundry-anthropic-passthrough` for Foundry-hosted Claude). When those land, an alias spanning Anthropic + Bedrock + Foundry over a single `/v1/messages` surface becomes possible without any caller-side change. The alias data model already supports this — only the per-protocol passthrough backend types are pending.

### Aliases are virtual backend pools

Every entry in `model_aliases` becomes a **virtual pool entry inside the same `backendPools` JArray that real model pools live in**. APIM cannot natively put pools inside pools, so the gateway materialises this with a deploy-time-resolved JObject that carries each member's underlying poolName / poolType / authType. Alias resolution and member fallback then ride on the same `set-target-backend-pool` + retry pipeline that real models use. You get:

- **Same-spec load balancing and fallback** — the alias resolves to a member that's compatible with the inbound API surface (filtered by `compatiblePoolTypes`); on 429/5xx the retry block walks the remaining members in resolution order. When the alias spans multiple clouds for a single shared spec (e.g. OpenAI-compat across Foundry + Bedrock-Mantle + Gemini-OpenAI), this is **transparent cross-cloud fallback**.
- **Routing strategies** — `priority` (deterministic order with implicit fallback) or `weighted` (probabilistic distribution) configured per alias.
- **Backend path templates preserved** — once a member is picked, the request takes the same code paths a direct call to that real model would have taken (URL rewrite, auth, body forwarding).
- **Consistent across the LLM API surfaces** — Azure OpenAI API, Universal LLM API, and Unified AI API all resolve aliases the same way using the shared `set-target-backend-pool` fragment.
- **Compatible-pool-types filtering** — when the inbound API surface restricts pool types (e.g. Universal LLM = OpenAI-compat-only, `/claude/` = anthropic-only), alias members with no compatible underlying pool are skipped automatically. An alias with no member compatible with the surface returns a clear `alias_no_compatible_member` 400.
- **Direct-model routing untouched** — aliases are opt-in. Configurations that never declare `model_aliases` see exactly the same direct-pool behaviour as before.

### Configuration

Add a `model_aliases` list to your `terraform.tfvars` file alongside `llm_backend_config`. Pick the scenarios that match your backend mix:

```hcl
model_aliases = [
  # Scenario A — Foundry weighted load-balance (single cloud, OpenAI-compat).
  # All members must be in `ai-foundry` pools. Use weights to drive the
  # random-by-weight pick on each call.
  {
    name     = "foundry-weighted-mix"
    models   = ["gpt-5", "mistral-large", "Phi-4"]
    strategy = "weighted"
    weights  = [50, 30, 20]
  },
  # Scenario B — Cross-cloud OpenAI-compat (multi-cloud, same /v1/chat/completions spec).
  # Members must be OpenAI-compat-capable: ai-foundry, aws-bedrock-mantle, gemini-openai.
  # Priority strategy gives a primary + transparent cross-cloud fallback.
  {
    name = "multi-cloud-openai"
    models = [
      "gpt-4.1",              # ai-foundry
      "openai.gpt-oss-120b",  # aws-bedrock-mantle
      "gemini-2.5-flash-lite" # gemini-openai
    ]
    strategy = "priority"
  },
  # Scenario C — Native Anthropic Messages alias (/v1/messages spec).
  # Today the only backend type that natively serves /v1/messages is `anthropic`,
  # so alias members are limited to direct Anthropic API keys.
  {
    name     = "multi-cloud-claude"
    models   = ["claude-sonnet-4-6", "claude-haiku-4-5"]
    strategy = "priority"
  }
]
```

### Alias Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | string | Yes | Client-facing alias name. Must **not** collide with any real model name in `llm_backend_config`. |
| `models` | list(string) | Yes | Ordered list of underlying real models the alias may resolve to. Each must exist as a `name` in some backend's `supported_models`. May span any mix of providers. |
| `strategy` | string | No | `priority` (default) — first compatible member wins, the rest form the fallback list; `weighted` — random selection by weights, the rest form the fallback list (round-walk after the picked one). |
| `weights` | list(number) | No | Required when `strategy` is `weighted`. Same length as `models`. Higher weight = more traffic. Used at deploy time to render the alias virtual pool entry; runtime selection is random-weighted. |

Aliases surface in the `/deployments` discovery response and are honored by `validate-model-access` RBAC.

### Resolution flow

```
1. Client calls e.g. POST /unified-ai/v1/chat/completions with "model": "multi-cloud-openai".

2. validate-model-access: RBAC check on the alias name (allowedModels in the
   product policy controls alias access — admins do NOT need to enumerate the
   underlying real models).

3. set-backend-pools: Loads the gateway's backendPools JArray. The alias appears
   as a virtual pool entry with isAlias=true, aliasName="multi-cloud-openai",
   members=[ {model, weight, pools[]}, ... ]. Each member's pools[] carries
   the resolved poolName / poolType / authType for every underlying pool that
   hosts the member model.

4. set-target-backend-pool: Detects the alias. Filters members by the inbound
   API surface's compatiblePoolTypes (so e.g. /v1/chat/completions only
   considers OpenAI-compat-capable pool types). Picks one member based on
   strategy. Sets:
     - is-alias = true
     - original-model-alias = "multi-cloud-openai"
     - requestedModel = picked member's real model name
     - targetBackendPool = picked member's poolName
     - targetPoolType / targetAuthType / targetAuthConfigNamedValue
     - alias-fallback-members = JArray of remaining members in walk order.

5. resolve-model-alias: Slim post-resolution body rewrite. Replaces the JSON
   body's model field with requestedModel so backends see the real name.
   No-op when is-alias=false.

6. set-backend-authorization + path-builder: Operate on the resolved real model
   exactly like a direct request would.

7. Backend retry block: If the request returns 429 or 5xx (pre-stream), the
   API policy walks alias-fallback-members one entry at a time, swapping
   targetBackendPool / requestedModel / authType in place. Cross-cloud fallback
   (Foundry → Bedrock-Mantle → Gemini-OpenAI) is transparent to the client.
   Once streaming has started, fallback is no longer possible.
```

### What changes for direct-model requests?

Nothing. When `requestedModel` does not match any alias entry, `set-target-backend-pool` falls through to its existing model→pool match logic. Direct routing is unchanged.

### Access Control

`validate-model-access` runs **before** `set-target-backend-pool`, so the access contract's `allowedModels` list controls access to the **alias name**, not the underlying members. Granting `allowedModels = "multi-cloud-openai"` lets the client invoke the alias without having to also list `gpt-4.1` / `openai.gpt-oss-120b` / `gemini-2.5-flash-lite` separately. The alias becomes the contract-level abstraction.

### Discovery (`GET /deployments`)

Aliases also appear in the model discovery responses (`get-available-models` fragment, used by `GET /deployments` and `GET /deployments/{deployment-id}` on the Universal LLM, Azure OpenAI, and Unified AI APIs) **as first-class entries alongside real models**. This means clients (including Microsoft Foundry's deployment picker) can discover and use an alias without the backend implementation leaking out.

Each alias entry returned by discovery looks like:

```json
{
  "id": "alias",
  "type": "alias",
  "name": "multi-cloud-openai",
  "sku": { "name": "Standard", "capacity": 100 },
  "properties": {
    "model": { "format": "Alias", "name": "multi-cloud-openai", "version": "1" },
    "capabilities": {
      "chatCompletion": "true",
      "description": "Alias for: gpt-4.1, openai.gpt-oss-120b, gemini-2.5-flash-lite (strategy: priority)"
    },
    "provisioningState": "Succeeded"
  }
}
```

The `description` field under `capabilities` exposes which underlying models the alias maps to and which strategy is in use (with the configured weights when `strategy = "weighted"`). The discovery filter (`allowedModels` from the access contract) matches by `name`, so RBAC works for aliases identically to real models.

### Errors

| Code | When |
|------|------|
| `alias_no_compatible_member` (400) | The alias was matched but every member's underlying pool is incompatible with the inbound API surface (filtered out by `compatiblePoolTypes`). The error body includes the alias name, requested CSV of compatible pool types, and total member count. |
| `unauthorized_model_access` (403) | The alias name is not in the access contract's `allowedModels` list. |

## Get Available Models API

The `get-available-models` policy fragment enables an API endpoint that returns all available model deployments with their capabilities, similar to the Azure Cognitive Services deployment list API.

This policy fragment is designed to support Microsoft Foundry integration with Citadel Governance Hub, allowing clients to query available models dynamically from the Foundry portal experience.

> **NOTE**: This policy fragment is included in the `/deployments` get operation of the Universal LLM API by default. Currently this Microsoft Foundry feature is in `preview` and may change in future releases.

### Usage

Include the policy fragment in any API operation to return available models:

```xml
<inbound>
    <include-fragment fragment-id="get-available-models" />
</inbound>
```

### Response Format

```json
{
    "value": [
        {
            "id": "aif-citadel-primary",
            "type": "ai-foundry",
            "name": "gpt-4o",
            "sku": { "name": "GlobalStandard", "capacity": 100 },
            "properties": {
                "model": { "format": "OpenAI", "name": "gpt-4o", "version": "2024-11-20" },
                "capabilities": { "chatCompletion": "true" },
                "provisioningState": "Succeeded"
            }
        },
        {
            "id": "aif-citadel-primary",
            "type": "ai-foundry",
            "name": "gpt-4o-mini",
            "sku": { "name": "GlobalStandard", "capacity": 100 },
            "properties": {
                "model": { "format": "OpenAI", "name": "gpt-4o-mini", "version": "2024-11-20" },
                "capabilities": { "chatCompletion": "true" },
                "provisioningState": "Succeeded"
            }
        }
    ]
}
```

The response is dynamically generated based on the `llm_backend_config` variable, using the optional metadata fields (`sku`, `capacity`, `modelFormat`, `modelVersion`).

## Load Balancing

Models that appear in **multiple backends** automatically get a backend pool for load balancing and failover. For example, given two backends that both expose `DeepSeek-R1`, the onboarding creates a `DeepSeek-R1-backend-pool` containing both backends and distributes traffic based on the configured `priority`/`weight`. See [Load Balancing Across Regions](#load-balancing-across-regions) for a full example.

## Monitoring

### Key Metrics

Connecting Application Insights to APIM provides insights into backend performance:

| Metric | Description |
|--------|-------------|
| Application Map | Visual representation of dependency performance |
| Performance | For both operations and dependencies |
| Failures | Failures by backend |
| Latency | Response time per backend |

### Application Insights Query

```kusto
// this query calculates LLM backend duration percentiles and count by target
let start=ago(24h);
let end=now();
let timeGrain=5m;

let dataset=dependencies
// additional filters can be applied here
| where timestamp > start and timestamp < end
| where client_Type != "Browser"
;
// calculate duration percentiles and count for all dependencies (overall)
dataset
| summarize avg_duration=sum(itemCount * duration)/sum(itemCount), percentiles(duration, 50, 95, 99), count_=sum(itemCount)
| project operation_Name="Overall", avg_duration, percentile_duration_50, percentile_duration_95, percentile_duration_99, count_
| union(dataset
// change 'target' on the below line to segment by a different property
| summarize avg_duration=sum(itemCount * duration)/sum(itemCount), percentiles(duration, 50, 95, 99), count_=sum(itemCount) by target
| sort by avg_duration desc, count_ desc
)
```

## Troubleshooting

### "Model not supported" Error

1. Check the model name in the `supported_models` array (case-insensitive)
2. Verify the backend pool was created in APIM
3. Review policy fragment deployment

### "403 Forbidden" Error

1. Check the `allowedBackendPools` policy variable
2. Verify RBAC configuration
3. Review product/subscription access

### "401 Unauthorized" Error

1. Verify APIM's managed identity has the required roles:
   - `Cognitive Services OpenAI User` for Azure OpenAI
   - `Cognitive Services User` for AI Foundry
2. For Amazon Bedrock: Verify AWS IAM access keys are valid and stored as named values (`aws-access-key`, `aws-secret-key`, `aws-region`)
3. `Unauthorized model access` indicates the used access contract product is restricted for the model
4. Check the named value `uami-client-id` is set correctly to APIM's managed identity client ID

### "500 AWSCredentialsNotConfigured" Error

This error means an `aws-bedrock` backend was matched but the AWS credentials named values are still set to the `NOT_CONFIGURED` placeholder. To fix:

1. Re-apply with the `aws_access_key`, `aws_secret_key`, and `aws_region` variables set to valid values, **or**
2. Manually update the APIM named values `aws-access-key`, `aws-secret-key`, and `aws-region` in the Azure Portal

## Scripts

> Each script ships in two interchangeable flavours — Bash (`.sh`) and PowerShell (`.ps1`) — with identical functionality. Use whichever suits your shell.

| Script | Purpose |
|--------|---------|
| `scripts/deploy.sh` / `scripts/deploy.ps1` | Initialize, plan, and apply Terraform |
| `scripts/import-existing.sh` / `scripts/import-existing.ps1` | Import pre-existing APIM resources into Terraform state |
| `scripts/test.sh` / `scripts/test.ps1` | Test deployed backends via the APIM gateway |

### Deploy Script Options

Bash (`deploy.sh`):

```
--auto-approve    Skip interactive confirmation
--plan-only       Show plan without applying
--destroy         Remove all onboarded backends
--var-file FILE   Custom .tfvars file (default: terraform.tfvars)
```

PowerShell (`deploy.ps1`):

```
-AutoApprove      Skip interactive confirmation
-PlanOnly         Show plan without applying
-Destroy          Remove all onboarded backends
-VarFile FILE     Custom .tfvars file (default: terraform.tfvars)
```

### Test Script Options

Bash (`test.sh`):

```
--api-key KEY       APIM subscription key (required)
--gateway-url URL   Override auto-detected gateway URL
--model MODEL       Specific model to test
--all-models        Test all configured models
--verbose           Show full response bodies
```

PowerShell (`test.ps1`):

```
-ApiKey KEY         APIM subscription key (required)
-GatewayUrl URL     Override auto-detected gateway URL
-Model MODEL        Specific model to test
-AllModels          Test all configured models
-Verbose            Show full response bodies
```

## Outputs

| Output | Description |
|--------|-------------|
| `apim_name` | Name of the APIM service |
| `apim_gateway_url` | Gateway URL for the APIM service |
| `backend_ids` | Array of created backend IDs |
| `pool_names` | Array of created backend pool names |
| `model_to_pool_map` | Mapping of models to their backend pool names (models with 2+ backends) |
| `model_to_backend_map` | Mapping of models to direct backend IDs (models with a single backend) |
| `supported_models` | All supported models across all backends |
| `policy_fragments` | Names of the deployed policy fragments |

## File Structure

```
llm-backend-onboarding/
├── main.tf                    # Backends, pools, policy fragments
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── versions.tf                # Terraform & provider versions
├── providers.tf               # Provider configuration
├── terraform.tfvars.example   # Example configuration
├── policies/                  # Policy fragment XML templates + OpenAPI specs
│   ├── frag-set-backend-pools.xml          # dynamic (backend pools code-gen)
│   ├── frag-get-available-models.xml       # dynamic (model + alias discovery)
│   ├── frag-metadata-config.xml            # dynamic (model mapping + aliases)
│   ├── frag-resolve-model-alias.xml        # dynamic (inline alias map)
│   ├── frag-set-backend-authorization.xml
│   ├── frag-set-target-backend-pool.xml
│   ├── frag-set-llm-requested-model.xml
│   ├── frag-set-llm-usage.xml
│   ├── frag-validate-model-access.xml
│   ├── frag-responses-id-security.xml
│   ├── frag-responses-id-cache-store.xml
│   ├── universal-llm-api-policy.xml
│   ├── universal-llm-openapi.json
│   └── models-inference-openapi.json
├── scripts/
│   ├── deploy.sh              # Deployment automation (Bash)
│   ├── deploy.ps1             # Deployment automation (PowerShell)
│   ├── import-existing.sh     # Import existing APIM resources (Bash)
│   ├── import-existing.ps1    # Import existing APIM resources (PowerShell)
│   ├── test.sh                # Backend testing (Bash)
│   └── test.ps1               # Backend testing (PowerShell)
└── README.md
```

## Relationship to Main Deployment

This module is **independent** from the main Citadel Terraform deployment (`../main.tf`). Use it when:

- You need to onboard new LLM backends without a full infrastructure redeploy
- Different teams manage infrastructure vs. model routing
- You want to iterate quickly on backend configuration

The main deployment's `modules/apim` manages the same resources as part of the full stack. If you use both, ensure your `llm_backend_config` in the main deployment's tfvars is kept in sync.

## Related Guides

- [Citadel Access Contracts](../citadel-access-contracts/README.md) — Configure use case access to the governance hub
- [Bicep source module](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/tree/citadel-v1/bicep/infra/llm-backend-onboarding) — The original Bicep implementation this module is ported from