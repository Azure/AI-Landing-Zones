# 📜 Citadel Access Contracts — Use-case onboarding (Terraform)

Standalone Terraform deployment that onboards an AI **use-case** to an existing AI Citadel Governance Hub APIM instance — creating per-service APIM products, subscriptions, inbound policies, and (optionally) Key Vault secrets and Azure AI Foundry connections.

## Overview

Automate the onboarding of AI use cases to your APIM-based AI Gateway with a streamlined, infrastructure-as-code approach using Terraform variable files (`terraform.tfvars`).

This module eliminates manual APIM configuration by providing:

- 📦 **Automated Product Creation**: Per-service APIM products with naming `<serviceCode>-<BU>-<UseCase>-<ENV>`
- 🔌 **API Integration**: Automatic API attachment to the product with custom or default policies
- 🔑 **Subscription Management**: Auto-generated subscription with secure API keys
- 🔐 **Flexible Secret Storage**: Optional Azure Key Vault integration or direct credential output
- 🤖 **Microsoft Foundry Integration**: Optional APIM connection creation for Foundry agents
- 🛡️ **JWT Authentication**: Optional layered API Key + JWT Bearer token authentication per product
- 📝 **Declarative Configuration**: Simple `terraform.tfvars` & `.xml` files for version control

> This module is a Terraform port of the Bicep [`citadel-access-contracts`](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/tree/citadel-v1/bicep/infra/citadel-access-contracts) module (`main.bicep` + `apimOnboardService.bicep` + `kvSecrets.bicep` + `foundryConnection.bicep`), packaged as an independently-applyable root module — the same pattern as `../llm-backend-onboarding`.

## What Gets Created

For each service `code` you onboard, this module creates:

| Resource | Naming Pattern | Description |
|----------|----------------|-------------|
| **APIM Product** | `<code>-<BU>-<UseCase>-<ENV>` | Product per service (e.g. `LLM-Finance-CustomerSupport-DEV`) with attached APIs and policies |
| **Product → API links** | — | Attaches the already-published APIs from `api_name_mapping[code]` to the product |
| **Product Policy** | — | Inbound policy applied to the product (per-service XML or the bundled default) |
| **APIM Subscription** | `<product>-SUB-01` | Subscription with primary/secondary API keys |
| **Key Vault Secrets** *(optional)* | `<secret_name>` | Endpoint URL + subscription key per service (`use_target_key_vault = true`) |
| **Foundry Connection** *(optional)* | `<prefix>-<code>` | One connection per service pointing at the APIM gateway (`use_target_foundry = true`) |

Naming examples:

- Product: `LLM-Finance-CustomerSupport-DEV`
- Subscription: `LLM-Finance-CustomerSupport-DEV-SUB-01`
- Foundry Connection: `Hub-Finance-CustomerSupport-DEV-LLM`

## Key Features

- ✨ **Simplified Inputs**: No need for full resource IDs — just API names
- 🔄 **Optional Key Vault**: Choose between Key Vault storage or direct output
- 🤖 **Optional Foundry Integration**: Create APIM connections for AI agents
- 📋 **Policy Templates**: Pre-built default policy for common LLM use cases
- 🎯 **Multi-Service Support**: Onboard multiple AI services in one apply
- 🔒 **Secure by Default**: Credentials stored in Key Vault or marked as sensitive outputs
- 📊 **Production Ready**: Designed for scale and aligned with DevOps practices

## Architecture Overview

### Deployment Flow

```text
  📥 INPUTS                         🚀 DEPLOYMENT                        📤 OUTPUTS
┌────────────────┐          ┌──────────────────────────┐
│ terraform.tfvars│         │ terraform apply          │
│ Policy XML files│ ───────▶│   │                      │
└────────────────┘          │   ▼                      │
                            │ Create Products ─────────┼────────────▶ Products Created
                            │   │                      │
                            │   ▼                      │
                            │ Attach APIs to Products  │
                            │   │                      │
                            │   ▼                      │
                            │ Apply Policies           │
                            │   │                      │
                            │   ▼                      │
                            │ Create Subscriptions ────┼────────────▶ Subscription Keys
                            │   │                      │
                            │   ├──▶ Use Key Vault?    │
                            │   │     ├─ Yes ──▶ Store ┼────────────▶ KV Secret Names
                            │   │     │   Secrets in KV│
                            │   │     └─ No  ──▶ Output┼────────────▶ Direct Credentials
                            │   │         Credentials  │
                            │   │                      │
                            │   └──▶ Use Foundry?      │
                            │         └─ Yes ──▶ Create┼────────────▶ Foundry Connections
                            │             Connections  │
                            └──────────────────────────┘
```

### Runtime Request Flow

Suggested flow for client applications (i.e. agents) interacting with the onboarded services via the access contract:

```text
 AI Agent/App      Entra ID        Key Vault       Foundry        AI Gateway      AI Services
      │                │               │              │                │               │
      │  ── Credential acquisition (choose one) ──────────────────────────────────     │
      │                │               │              │                │               │
      │ [Key Vault]    │  Get endpoint + API key      │                │               │
      │ ──────────────────────────────▶               │                │               │
      │ ◀──────────────────────────────  secrets      │                │               │
      │                │               │              │                │               │
      │ [Foundry]      │  Use APIM connection (credentials stored)     │               │
      │ ─────────────────────────────────────────────▶                 │               │
      │                │               │              │                │               │
      │ [Direct]       Use credentials from terraform output           │               │
      │                │               │              │                │               │
      │  ── (optional) JWT authentication ────────────────────────────────────────     │
      │  Request JWT token (client credentials)       │                │               │
      │ ───────────────▶               │              │                │               │
      │ ◀───────────────  Bearer token │              │                │               │
      │                │               │              │                │               │
      │  HTTPS request: api-key + optional Bearer token                │               │
      │ ──────────────────────────────────────────────────────────────▶                │
      │                │      Validate subscription key (always required)              │
      │                │      Apply product policy (check jwtRequired)  │              │
      │                │      [if jwtRequired] Validate JWT via security-handler       │
      │                │               │              │   Forward to backend service   │
      │                │               │              │                │ ─────────────▶│
      │                │               │              │                │ ◀─────────────│
      │                │               │              │     Logs & metrics             │
      │ ◀──────────────────────────────────────────────────────────────                │
      │                  Response with usage headers  │                │               │
```

## Prerequisites

### Azure Resources

| Resource | Requirement | How to Verify |
|----------|-------------|---------------|
| **Citadel-compliant APIM instance** | With published APIs matching your `api_name_mapping` | `az apim api list -g <rg> -n <apim-name>` |
| **Azure Key Vault** | Accessible with secret-set permissions (if using KV) | `az keyvault show -n <kv-name>` |
| **Microsoft Foundry** | Account and project must exist (if using Foundry) | `az cognitiveservices account show -n <account-name> -g <rg>` |

### Permissions Required

The deploying principal needs:

| Scope | Role | Purpose |
|-------|------|---------|
| APIM resource group | `API Management Service Contributor` | Create products, subscriptions, and policies |
| Target Key Vault *(if used)* | `Key Vault Secrets Officer` | Write secrets |
| Foundry resource group *(if used)* | `Contributor` | Create connections |
| Subscription | `Reader` | Reference existing resources |

### Tooling

- Terraform >= 1.5 and Azure CLI installed
- Authenticated to Azure (`az login`)

## Quick Start

### 1. Configure variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

A minimal configuration looks like:

```hcl
apim = {
  subscription_id     = "YOUR-SUBSCRIPTION-ID"
  resource_group_name = "YOUR-APIM-RESOURCE-GROUP"
  name                = "YOUR-APIM-NAME"
}

use_case = {
  business_unit = "Finance"
  use_case_name = "CustomerSupport"
  environment   = "DEV" # DEV, TEST, PROD
}

# Verify these API names exist in your APIM
api_name_mapping = {
  LLM = ["azure-openai-api", "universal-llm-api"]
  DOC = ["document-intelligence-api", "document-intelligence-api-legacy"]
}

services = [
  {
    code                 = "LLM"
    endpoint_secret_name = "OPENAI_ENDPOINT"
    api_key_secret_name  = "OPENAI_API_KEY"
    policy_xml           = "" # "" = default policy, or file("policies/my-policy.xml")
  }
]

use_target_key_vault = true # false to return credentials as outputs

key_vault = {
  subscription_id     = "YOUR-SUBSCRIPTION-ID"
  resource_group_name = "YOUR-KV-RESOURCE-GROUP"
  name                = "YOUR-KV-NAME"
}
```

### 2. Deploy

```bash
./scripts/deploy.sh
```

```powershell
./scripts/deploy.ps1
```

Or manually:

```bash
terraform init
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### 3. Test

```bash
# When use_target_key_vault = false, keys come from terraform output:
./scripts/test.sh

# When keys are stored in Key Vault, pass one explicitly:
./scripts/test.sh --api-key "<subscription-key>"
```

```powershell
# When use_target_key_vault = false, keys come from terraform output:
./scripts/test.ps1

# When keys are stored in Key Vault, pass one explicitly:
./scripts/test.ps1 -ApiKey "<subscription-key>"
```

You can also use the [`citadel-access-contracts-tests`](../validation/citadel-access-contracts-tests.ipynb) notebook to validate end-to-end connectivity of the newly created access contract.

## Configuration

### Naming convention

All resources are named from `use_case`:

```
<code>-<business_unit>-<use_case_name>-<environment>
```

For `use_case = { business_unit = "Finance", use_case_name = "CustomerSupport", environment = "DEV" }`
and a `LLM` service, you get product `LLM-Finance-CustomerSupport-DEV` and subscription `LLM-Finance-CustomerSupport-DEV-SUB-01`.

### Service code mapping

Map service codes (a short acronym that represents the category of services) to their API names in APIM:

```hcl
api_name_mapping = {
  LLM   = ["azure-openai-api", "universal-llm-api"]
  OAIRT = ["openai-realtime-ws-api"]
  DOC   = ["document-intelligence-api", "document-intelligence-api-legacy"]
  SRCH  = ["azure-ai-search-index-api"]
  # ... add more services
}
```

> **Note**: Each API name must already exist in your APIM instance. The apply will fail if an API name is not found.

#### Adding custom APIs

You can onboard any number of additional APIs to support custom services — add the new API names to the mapping accordingly.

#### Multi-service bundles

Mappings are typically focused on a specific category of services (e.g. LLM, Document Intelligence). You can create mappings that mix different service types under one bundle if needed — this requires the product policy to be aware of that mix so it applies the correct limits per service type (e.g. token-per-minute limits for LLM and request-per-minute limits for Document Intelligence).

### Top-level variables

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `apim` | object | Yes | `{ subscription_id, resource_group_name, name }` of the target APIM. The provider is pinned to this subscription. |
| `use_case` | object | Yes | `{ business_unit, use_case_name, environment }` — drives naming. |
| `api_name_mapping` | map(list(string)) | Yes | Service code → list of **existing** APIM API names. |
| `services` | list(object) | Yes | Services to onboard (see below). |
| `product_terms` | string | No | Terms of service shown to subscribers. |
| `use_target_key_vault` | bool | No | Write endpoint + key secrets to Key Vault (default `true`). |
| `key_vault` | object | If KV | `{ subscription_id, resource_group_name, name }`. May be in another subscription/RG. |
| `use_target_foundry` | bool | No | Create a Foundry connection per service (default `false`). |
| `foundry` | object | If Foundry | `{ subscription_id, resource_group_name, account_name, project_name }`. |
| `foundry_config` | object | No | Advanced Foundry connection options (see below). |

### Service object properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `code` | string | Yes | Service code; must be a key in `api_name_mapping` (e.g. `LLM`, `DOC`, `SRCH`). |
| `endpoint_secret_name` | string | Yes | Key Vault secret name for the gateway endpoint URL. Underscores are lower-cased to hyphens. |
| `api_key_secret_name` | string | Yes | Key Vault secret name for the subscription key. Underscores are lower-cased to hyphens. |
| `policy_xml` | string | No | Inbound product policy XML. Empty (`""`) applies `policies/default-ai-product-policy.xml`. Use `file("policies/your-policy.xml")` for a custom one. |

### Foundry connection config (`foundry_config`)

| Property | Default | Description |
|----------|---------|-------------|
| `connection_name_prefix` | `""` | Empty → `Hub-<business_unit>-<use_case_name>-<environment>`. Connection name = `<prefix>-<code>`. |
| `connection_category` | `ApiManagement` | `ApiManagement` or `ModelGateway`. |
| `deployment_in_path` | `"false"` | `"true"` = model in URL path; `"false"` = model in request body. |
| `is_shared_to_all` | `false` | Share the connection with all project users. |
| `inference_api_version` | `""` | API version for inference calls. Empty = APIM defaults. |
| `deployment_api_version` | `""` | API version for deployment discovery. Empty = APIM defaults. |
| `static_models` | `[]` | Static model list (skips dynamic discovery). |
| `list_models_endpoint` | `""` | Custom list-models endpoint. Empty = APIM defaults. |
| `get_model_endpoint` | `""` | Custom get-model endpoint. Empty = APIM defaults. |
| `deployment_provider` | `""` | `""`, `AzureOpenAI`, or `OpenAI` (used with custom discovery). |
| `custom_headers` | `{}` | Extra request headers (always emitted; `{}` when empty). |
| `auth_config` | `{}` | Custom auth configuration object. |

## Secret Management Options

The module supports three (non-exclusive) ways to deliver credentials to consuming applications.

### Option 1: Azure Key Vault (Recommended)

Set `use_target_key_vault = true` and provide a `key_vault` block. Endpoint URLs and subscription keys are written as Key Vault secrets:

```hcl
use_target_key_vault = true

key_vault = {
  subscription_id     = "YOUR-SUBSCRIPTION-ID"
  resource_group_name = "YOUR-KV-RESOURCE-GROUP"
  name                = "YOUR-KV-NAME"
}

services = [
  {
    code                 = "LLM"
    endpoint_secret_name = "OPENAI_ENDPOINT" # → openai-endpoint in Key Vault
    api_key_secret_name  = "OPENAI_API_KEY"  # → openai-api-key in Key Vault
    policy_xml           = ""
  }
]
```

> **Naming**: `endpoint_secret_name` / `api_key_secret_name` are normalized for Key Vault — underscores become hyphens and the value is lower-cased (`OPENAI_API_KEY` → `openai-api-key`).

Consuming the secret from Python:

```python
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from openai import AzureOpenAI

kv = SecretClient(vault_url="https://YOUR-KV-NAME.vault.azure.net", credential=DefaultAzureCredential())
endpoint = kv.get_secret("openai-endpoint").value
api_key  = kv.get_secret("openai-api-key").value

client = AzureOpenAI(azure_endpoint=endpoint, api_key=api_key, api_version="2024-10-21")
```

### Option 2: Direct Output (CI/CD)

Set `use_target_key_vault = false` to skip Key Vault. Credentials are returned in the (sensitive) `endpoints` output for use in pipelines:

```hcl
use_target_key_vault = false
```

```bash
# Retrieve the sensitive endpoints output as JSON
terraform output -json endpoints
```

> **Security note**: The `endpoints` output contains live subscription keys. It is marked `sensitive`; store it securely (environment variables, CI/CD secrets) and prefer Key Vault for production.

### Option 3: Microsoft Foundry Connections

Set `use_target_foundry = true` to create one APIM connection per service inside a Foundry project, so agents can call the gateway without managing keys directly:

```hcl
use_target_foundry = true

foundry = {
  subscription_id     = "YOUR-SUBSCRIPTION-ID"
  resource_group_name = "YOUR-FOUNDRY-RESOURCE-GROUP"
  account_name        = "YOUR-FOUNDRY-ACCOUNT"
  project_name        = "YOUR-FOUNDRY-PROJECT"
}

foundry_config = {
  connection_name_prefix = ""              # "" → Hub-<BU>-<UseCase>-<ENV>
  connection_category    = "ApiManagement" # or "ModelGateway"
  deployment_in_path     = "false"
  is_shared_to_all       = false
}
```

#### Combined targets

The options are not mutually exclusive — you can write to Key Vault **and** create Foundry connections in the same apply:

```hcl
use_target_key_vault = true
key_vault            = { /* ... */ }

use_target_foundry   = true
foundry              = { /* ... */ }
foundry_config       = { /* ... */ }
```

## Creating Custom Policies

### Using the default policy

Leave `policy_xml = ""` to apply the bundled `policies/default-ai-product-policy.xml`. The default policy provides:

- 🎯 **Model restrictions** — allowed models: `gpt-4o`, `deepseek-r1`, `gpt-4.1`, `gpt-5.4-mini`
- ⏱️ **Token limits** — `1000` tokens/minute and a `100,000` token monthly quota per subscription
- 📊 **Advanced response headers** — usage headers enabled for observability

### Creating a custom policy

Add your XML under `policies/` and reference it from the service with `file(...)`:

```hcl
services = [
  {
    code                 = "LLM"
    endpoint_secret_name = "OPENAI_ENDPOINT"
    api_key_secret_name  = "OPENAI_API_KEY"
    policy_xml           = file("policies/finance-llm-policy.xml")
  }
]
```

A minimal product policy:

```xml
<policies>
    <inbound>
        <base />
        <include-fragment fragment-id="set-llm-requested-model" />
        <set-variable name="allowedModels" value="gpt-4o,gpt-4.1" />
        <llm-token-limit counter-key="@(context.Subscription.Id)"
                         tokens-per-minute="2000"
                         estimate-prompt-tokens="false"
                         token-quota="200000"
                         token-quota-period="Monthly" />
        <set-variable name="enableResponseHeaders" value="@(true)" />
    </inbound>
    <backend><base /></backend>
    <outbound><base /></outbound>
    <on-error><base /></on-error>
</policies>
```

> Policy fragments such as `set-llm-requested-model` are provisioned by the Governance Hub / `llm-backend-onboarding` deployments and must exist in the target APIM instance.

## Advanced Scenarios

### Multiple services in one use case

Onboard several AI services for a single use case in a single apply:

```hcl
use_case = {
  business_unit = "Finance"
  use_case_name = "DocProcessing"
  environment   = "PROD"
}

api_name_mapping = {
  LLM  = ["azure-openai-api", "universal-llm-api"]
  DOC  = ["document-intelligence-api"]
  SRCH = ["azure-ai-search-index-api"]
}

services = [
  {
    code                 = "LLM"
    endpoint_secret_name = "OPENAI_ENDPOINT"
    api_key_secret_name  = "OPENAI_API_KEY"
    policy_xml           = ""
  },
  {
    code                 = "DOC"
    endpoint_secret_name = "DOCINTELL_ENDPOINT"
    api_key_secret_name  = "DOCINTELL_API_KEY"
    policy_xml           = file("policies/doc-intel-policy.xml")
  },
  {
    code                 = "SRCH"
    endpoint_secret_name = "SEARCH_ENDPOINT"
    api_key_secret_name  = "SEARCH_API_KEY"
    policy_xml           = ""
  }
]
```

This produces three products (`LLM-Finance-DocProcessing-PROD`, `DOC-Finance-DocProcessing-PROD`, `SRCH-Finance-DocProcessing-PROD`), each with its own subscription, policy, and — depending on the secret options — Key Vault secrets and/or Foundry connections.

## JWT Authentication for Access Contracts

By default, products are protected with the APIM **subscription key** (`api-key` header). You can add a second layer of **JWT Bearer token** validation so that callers must present *both* a valid subscription key and a valid Microsoft Entra ID token.

### How it works

The Citadel policy fragments support a `jwtRequired` flag. When a product policy sets this flag to `true`, the security handler validates the incoming `Authorization: Bearer <token>` against your configured Microsoft Entra ID application before the request is forwarded to the backend.

| Layer | Mechanism | Always Required? |
|-------|-----------|------------------|
| Subscription | APIM `api-key` header | ✅ Yes |
| Identity | Microsoft Entra ID JWT Bearer token | Only when `jwtRequired = true` |

### Enabling JWT via a custom product policy

Because this Terraform module applies the product policy XML you provide, enabling JWT is done by setting `jwtRequired` in your `policy_xml`:

```xml
<policies>
    <inbound>
        <base />
        <!-- Require a valid JWT in addition to the subscription key -->
        <set-variable name="jwtRequired" value="@(true)" />
        <include-fragment fragment-id="set-llm-requested-model" />
        <set-variable name="allowedModels" value="gpt-4o,gpt-4.1" />
        <set-variable name="enableResponseHeaders" value="@(true)" />
    </inbound>
    <backend><base /></backend>
    <outbound><base /></outbound>
    <on-error><base /></on-error>
</policies>
```

Reference it from the service:

```hcl
services = [
  {
    code                 = "LLM"
    endpoint_secret_name = "OPENAI_ENDPOINT"
    api_key_secret_name  = "OPENAI_API_KEY"
    policy_xml           = file("policies/jwt-llm-policy.xml")
  }
]
```

> The JWT validation fragments and the Microsoft Entra ID application configuration are provisioned by the Governance Hub deployment. This module only opts a product into JWT enforcement via the `jwtRequired` flag in its policy.

### Acquiring a JWT token

Clients obtain a token from Microsoft Entra ID using the client-credentials flow, then send it alongside the subscription key:

```bash
TOKEN=$(az account get-access-token --resource "<api-app-id-uri>" --query accessToken -o tsv)

curl -X POST "https://YOUR-APIM.azure-api.net/openai/deployments/gpt-4o/chat/completions?api-version=2024-10-21" \
  -H "api-key: <subscription-key>" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello"}]}'
```

You can validate JWT-enabled access contracts using the [`citadel-jwt-authentication-tests`](../gitignore/citadel-jwt-authentication-tests.ipynb) notebook.

## Outputs

| Output | Description |
|--------|-------------|
| `apim_gateway_url` | Base URL of the APIM gateway. |
| `use_key_vault` | Whether secrets were written to Key Vault. |
| `products` | Map of service code → `{ product_id, display_name }`. |
| `subscriptions` | Per-service subscription metadata (Key Vault secret names when KV is used). |
| `endpoints` | **(sensitive)** Per-service `{ endpoint, api_key }`. Only populated when `use_target_key_vault = false`. |
| `use_foundry` | Whether Foundry connections were created. |
| `foundry_connections` | Map of service code → created Foundry connection metadata. |

> **Security note:** When `use_target_key_vault = false`, the `endpoints` output contains live subscription keys. It is marked `sensitive`; handle it securely (environment variables, CI/CD secrets) and prefer Key Vault for production.

### When using Key Vault (`use_target_key_vault = true`)

`subscriptions` returns the Key Vault secret references rather than raw keys, and `endpoints` is empty:

```bash
terraform output subscriptions
# {
#   "LLM" = {
#     "name"                           = "LLM-Finance-CustomerSupport-DEV-SUB-01"
#     "product_id"                     = "LLM-Finance-CustomerSupport-DEV"
#     "key_vault_endpoint_secret_name" = "openai-endpoint"
#     "key_vault_api_key_secret_name"  = "openai-api-key"
#   }
# }
```

### When NOT using Key Vault (`use_target_key_vault = false`)

The raw endpoint + key are exposed in the sensitive `endpoints` output:

```bash
terraform output -json endpoints
# {
#   "LLM": {
#     "product_id":        "LLM-Finance-CustomerSupport-DEV",
#     "subscription_name": "LLM-Finance-CustomerSupport-DEV-SUB-01",
#     "endpoint":          "https://YOUR-APIM.azure-api.net/openai",
#     "api_key":           "<subscription-key>"
#   }
# }
```

## Cross-subscription resources

The Terraform provider is pinned to `apim.subscription_id`. Key Vault and Foundry are referenced by **fully-qualified resource IDs** built from their `subscription_id` objects, so they may live in different subscriptions/resource groups — as long as the authenticated principal has access there.

## Scripts

> Each script ships in two interchangeable flavours — Bash (`.sh`) and PowerShell (`.ps1`) — with identical functionality. Use whichever suits your shell.

| Script | Purpose |
|--------|---------|
| `scripts/deploy.sh` / `scripts/deploy.ps1` | Init, import existing resources, plan, and apply. |
| `scripts/import-existing.sh` / `scripts/import-existing.ps1` | Import pre-existing APIM products/policies/subscriptions/API-links into state (idempotent re-runs). Called automatically by the deploy script. |
| `scripts/test.sh` / `scripts/test.ps1` | Smoke-test the onboarded services through the APIM gateway. |

### Deploy script options

Bash (`deploy.sh`):

```
--auto-approve    Skip interactive confirmation
--plan-only       Show plan without applying
--destroy         Remove the onboarded use-case resources
--var-file FILE   Custom .tfvars file (default: terraform.tfvars)
```

PowerShell (`deploy.ps1`):

```
-AutoApprove      Skip interactive confirmation
-PlanOnly         Show plan without applying
-Destroy          Remove the onboarded use-case resources
-VarFile FILE     Custom .tfvars file (default: terraform.tfvars)
```

### Test script options

Bash (`test.sh`):

```
--api-key KEY       APIM subscription key (required when keys are in Key Vault)
--gateway-url URL   Override the auto-detected gateway URL
--path PATH         Probe a specific API path
--verbose           Show response bodies
```

PowerShell (`test.ps1`):

```
-ApiKey KEY         APIM subscription key (required when keys are in Key Vault)
-GatewayUrl URL     Override the auto-detected gateway URL
-Path PATH          Probe a specific API path
-Verbose            Show response bodies
```

## File structure

```
citadel-access-contracts/
├── main.tf                    # Products, product-APIs, policies, subscriptions, KV secrets, Foundry connection
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── versions.tf                # Terraform & provider versions
├── providers.tf               # Provider configuration (pinned to apim.subscription_id)
├── terraform.tfvars.example   # Example configuration
├── policies/
│   └── default-ai-product-policy.xml   # Default inbound product policy
├── scripts/
│   ├── deploy.sh
│   ├── deploy.ps1
│   ├── import-existing.sh
│   ├── import-existing.ps1
│   ├── test.sh
│   └── test.ps1
└── README.md
```

## Relationship to the main deployment

This module is **independent** from the main Citadel Terraform deployment (`../main.tf`) and from the reusable `../modules/access-contracts` module. Use it to onboard new use-cases against an already-deployed Governance Hub without a full infrastructure redeploy — for example when a platform team owns the hub and product teams onboard their own use-cases.

The reusable `../modules/access-contracts` module performs the same role inside the full stack; this standalone root resolves the APIM gateway URL, API paths, Key Vault ID, and Foundry project ID from the structured inputs and applies the resources directly.

## Support

- Review the parent [AI Citadel Governance Hub README](../README.md) and the [Deployment Guide](../DEPLOYMENT_GUIDE.md) for hub-level context.
- See the companion [`llm-backend-onboarding`](../llm-backend-onboarding/README.md) module for onboarding LLM backends to the gateway.
- Validate onboarded contracts with the notebooks under [`../validation`](../validation/).
- For the original Bicep implementation this module is ported from, see the [ai-hub-gateway-solution-accelerator](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/tree/citadel-v1/bicep/infra/citadel-access-contracts) (citadel-v1 branch).