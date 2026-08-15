# APIM Gateway Upgrade (PREVIEW)

As the AI Governance Hub solution accelerator evolves, you may need to update the API Management gateway configuration to add new APIs, modify policies, or adjust logging settings. 

This deployment allows you to seamlessly apply updates to an existing APIM instance without needing to re-provision the entire service or associated infrastructure.

Notes:
- Update the configuration of an **existing** API Management instance without re-provisioning the APIM service or surrounding landing-zone infrastructure. 
- This deployment is designed to run **after** the main accelerator (`bicep/infra/main.bicep`) has provisioned the full environment.

> [!TIP]
> **Upgrading an APIM that the accelerator did NOT create?** Or one provisioned by an earlier
> version of the Citadel Governance Hub where some supporting services are missing? Use the companion
> **`supporting-services.bicep`** deployment in this folder to provision (or align an existing)
> ecosystem of dependent services — Logic App + Storage, Cosmos DB, Event Hub, primary AI Foundry,
> Key Vault, and managed identities — with a master on/off switch and per-service bring-your-own
> options. It never changes the network configuration of an existing APIM or existing supporting
> services. See **[gateway-ecosystem-upgrade-guide.md](./gateway-ecosystem-upgrade-guide.md)**, then
> run `main.bicep` (this guide) to apply the APIM configuration.

## What this deployment updates

| Category | Resources Updated |
|---|---|
| **Policy Fragments** | All static fragments (auth, usage, throttling, PII, AI Foundry, Unified AI) and dynamic LLM fragments (backend pools, authorization, target routing, model access, and the `backend-contract` routing contract) |
| **APIs** | Universal LLM API, Azure OpenAI API, Unified AI Wildcard API, OpenAI Realtime WebSocket API, and the Release Version API (`GET /version` + `GET /version/backend-contract`) — including OpenAPI specs, API-level policies, and operation-level policies |
| **LLM Backends** | Backend definitions, backend pools, and associated policy fragments for dynamic model routing |
| **Named Values** | UAMI client ID, PII service URL/key, Content Safety URL, JWT authentication values (TenantId, AppRegistrationId, Issuer, OpenIdConfigUrl) |
| **Logging / Diagnostics** | APIM-level Application Insights diagnostic configuration, per-API Azure Monitor diagnostic configuration, and optional creation of the `azuremonitor` logger + diagnostic settings to an existing Log Analytics workspace |
| **Redis Cache** | APIM cache entity backed by Azure Managed Redis (for semantic caching) |
| **Embeddings Backend** | APIM backend targeting AI Foundry embeddings endpoint (for semantic caching) |
| **Classic LLM Usage Container** *(reserved)* | A dedicated `llm-usage-container` (partition key `/productName`) provisioned in an **existing** Cosmos DB account — **reserved for classic AI Hub Gateway installs prior to the Citadel Governance Hub release** (disabled by default) |

>**NOTE**: It is very important depending on the gab between the newer gateway implementation and the existing one, try to make the initial run of this upgrade deployment with as many feature flags turned **on** as possible to ensure the APIM instance is fully updated, this will mean that backend routing configurations must be in place as well. Use this in non-production environment first to detect any potential issues before applying to production.

## What this deployment does NOT do

- Provision a new APIM service instance
- Create or modify the Application Insights logger (it must already exist); the Azure Monitor logger can optionally be created via `deployAzureMonitorLogger`
- Configure Event Hub loggers
- Publish to API Center
- Deploy sample MCP servers
- Modify networking, VNet, or private endpoint settings
- Create managed identities, Key Vaults, or other infrastructure
- Provision Azure Managed Redis (the Redis instance must already exist for cache updates)

> [!NOTE]
> Provisioning the dependent infrastructure (managed identities, Key Vault, Event Hub, Cosmos DB,
> Microsoft Foundry, Storage + Logic App) is handled by the separate **`supporting-services.bicep`**
> deployment — see **[gateway-ecosystem-upgrade-guide.md](./gateway-ecosystem-upgrade-guide.md)**.

## Prerequisites

1. The APIM service referenced by `apimServiceName` must already exist in the target resource group.
2. The user-assigned managed identity referenced by `managedIdentityName` must already exist in the same resource group.
3. APIM loggers:
   - `appinsights-logger` (Application Insights) must be pre-provisioned.
   - `azuremonitor` (Azure Monitor) must be pre-provisioned **OR** set `deployAzureMonitorLogger = true` to create it during the upgrade — see [Surfacing the Azure Monitor logger](#surfacing-the-azure-monitor-logger-for-legacy-installs).
4. Azure CLI authenticated with permissions to deploy to the target resource group.

### Notes for classic provisioned older installation:

If your APIM instance already exposes `/openai` and `/models` API paths, the new APIs would collide with the legacy ones. Resolve this with one of the two options below. **Both are safe against the shared policy fragments**: API policies strip the frontend prefix dynamically via `context.Api.Path`, and the `/openai`/`/models` values inside `frag-metadata-config.xml` are *backend* target paths — so neither a renamed legacy path nor a new prefix changes fragment behavior or backend routing.

- **Option 1 — Rename the legacy APIs, deploy new at `/openai` and `/models`.** Change the existing APIs to e.g. `/openai-classic` and `/models-classic`, then run this upgrade with the default empty prefixes (WARNING: temporary disruption to existing consumers until they re-point).
- **Option 2 — Deploy new APIs under a prefix.** Keep the legacy APIs untouched and set `universalLLMApiPathPrefix` / `azureOpenAIApiPathPrefix` (e.g. `v2`) so the new APIs land at `/v2/openai` and `/v2/models`. No disruption; consumers migrate at their own pace.

| | Option 1 — rename legacy | Option 2 — prefix new |
|---|---|---|
| Bicep change required | No (operational rename only) | Yes (`*ApiPathPrefix` params, shipped) |
| Final new-API paths | `/openai`, `/models` | `/v2/openai`, `/v2/models` |
| Consumer disruption | Temporary (legacy URL changes) | None |
| Client URL changes | Eventually back to `/openai`, `/models` | New clients use prefixed paths |
| Cleanup | Decommission `*-classic` later | Optionally drop prefix later |
| Best for | Cutover migrations | Side-by-side rollout / canary |

> [!NOTE]
> Path prefixes are policy-fragment safe — no fragment edits are needed for either option.

## Usage

### Surfacing the Azure Monitor logger (for legacy installs)

Older deployments may not have the `azuremonitor` logger. Enable it during the upgrade:

```bicep
param deployAzureMonitorLogger = true
// Reference the EXISTING workspace already used by the legacy APIM — none is provisioned
param logAnalyticsWorkspaceResourceId = '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.OperationalInsights/workspaces/<law-name>'
```

This creates the `azuremonitor` logger and attaches APIM diagnostic settings routing `allLogs` and `AllMetrics` to the existing workspace. Leave `logAnalyticsWorkspaceResourceId` empty to create only the logger. When `deployAzureMonitorLogger = false`, the deployment assumes the logger already exists. No Log Analytics workspace is created.

### Classic AI Hub Gateway: LLM usage container (reserved)

> [!IMPORTANT]
> This configuration is **reserved exclusively for classic AI Hub Gateway installs provisioned
> before the Citadel Governance Hub release**. It is **disabled by default** and should remain off
> for Citadel Governance Hub deployments, which provision the `llm-usage-container` as part of their
> own supporting-services pipeline.

When enabled, this adds a single `llm-usage-container` (partition key `/productName`) to an
**existing** Cosmos DB account that you reference by its account name. The account is expected to
reside in the **same resource group as the APIM instance**. It is additive and idempotent — it only
creates the container under the specified database and **never** changes the account's network
configuration (public access, IP/VNet rules, private endpoints) or any other database/container.

```bicep
// Off by default — only turn on for classic AI Hub Gateway installs.
param enableClassicLlmUsageContainer = true
// EXISTING Cosmos DB account name (same resource group as APIM)
param classicCosmosDbAccountName = 'cosmos-myaihub'
// EXISTING database in which to create the container (default: ai-usage-db)
param classicCosmosDbDatabaseName = 'ai-usage-db'
// Throughput (RU/s) for the new container (default: 400)
param classicLlmUsageContainerThroughput = 400
```

| Setting | Default | Description |
|---|---|---|
| `enableClassicLlmUsageContainer` | `false` | Master on/off switch (off = nothing is provisioned) |
| `classicCosmosDbAccountName` | `''` | Name of the existing Cosmos DB account in the same RG as APIM (required when enabled) |
| `classicCosmosDbDatabaseName` | `ai-usage-db` | Existing database that will hold the container |
| `classicLlmUsageContainerThroughput` | `400` | Provisioned RU/s for the `llm-usage-container` |

### 1. Configure Parameters

Edit `main.bicepparam` to match your environment:

```bicep
param apimServiceName = 'my-apim-instance'
param managedIdentityName = 'my-apim-identity'
```

### 2. Toggle Feature Flags

Enable or disable individual configuration sections by setting the feature flag parameters to `true` or `false`:

```bicep
// Only update policies and logging, skip API definitions
param updatePolicyFragments = true
param updateUniversalLLMApi = false
param updateAzureOpenAIApi = false
param updateUnifiedAiApi = false
param updateAppInsightsDiagnostics = true
param updateNamedValues = false
param updateJwtNamedValues = false```

### 3. Configure LLM Backends

Provide the LLM backend configuration array that matches your current environment:

```bicep
param llmBackendConfig = [
  {
    backendId: 'azure-openai-swedencentral'
    backendType: 'azure-openai'
    endpoint: 'https://my-openai.openai.azure.com'
    authType: 'managed-identity'
    supportedModels: [
      { name: 'gpt-4o', sku: 'GlobalStandard', capacity: 100, modelFormat: 'OpenAI', modelVersion: '2024-08-06' }
    ]
    priority: 1
    weight: 100
  }
]
```

### 4. Deploy

Run the deployment scoped to the resource group containing the APIM instance:

```bash
az deployment group create --name gateway-upgrade --resource-group <your-resource-group> --template-file main.bicep --parameters main.bicepparam
```

## When to use this

| Scenario | Use this deployment? |
|---|---|
| Updated API policies (routing logic, rate limiting, auth) | **Yes** |
| Changed LLM backend configuration (new models, endpoints) | **Yes** |
| Updated policy fragments (usage tracking, PII, throttling) | **Yes** |
| Tuning Application Insights or Azure Monitor log capture | **Yes** |
| Updating named values (PII URL, Content Safety URL) | **Yes** |
| Adding a new LLM backend or model to existing pools | **Yes** |
| Updating JWT authentication configuration | **Yes** |
| Updating Unified AI Wildcard API | **Yes** |
| Adding the azuremonitor logger to a legacy install (existing LAW) | **Yes** |
| Deploying new APIs under a prefix to avoid /openai & /models conflicts | **Yes** |
| Updating Redis cache or embeddings backend config | **Yes** |
| Initial environment provisioning | No — use `bicep/infra/main.bicep` |
| Changing APIM SKU, networking, or VNet configuration | No — use `bicep/infra/main.bicep` |
| Adding Event Hub loggers | No — use `bicep/infra/main.bicep` |
| Publishing to API Center | No — use `bicep/infra/main.bicep` |

## Parameter Reference

### Core Parameters

| Parameter | Required | Description |
|---|---|---|
| `apimServiceName` | Yes | Name of the existing APIM instance |
| `managedIdentityName` | Yes | Name of the existing user-assigned managed identity |

### Feature Flags

| Parameter | Default | Description |
|---|---|---|
| `updatePolicyFragments` | `true` | Update static policy fragments |
| `updateUniversalLLMApi` | `true` | Update Universal LLM API spec and policy |
| `updateAzureOpenAIApi` | `true` | Update Azure OpenAI API spec and policy |
| `updateUnifiedAiApi` | `true` | Update Unified AI Wildcard API, product, and policy |
| `updateOpenAIRealtimeApi` | `false` | Update OpenAI Realtime WebSocket API |
| `updateAppInsightsDiagnostics` | `true` | Update APIM-level App Insights diagnostics |
| `updateNamedValues` | `true` | Update APIM named values |
| `updateJwtNamedValues` | `true` | Update JWT authentication named values |
| `updateLLMBackends` | `true` | Update LLM backend definitions |
| `updateLLMBackendPools` | `true` | Update LLM backend pools |
| `updateLLMPolicyFragments` | `true` | Update dynamic LLM policy fragments |
| `updateRedisCache` | `false` | Update APIM Redis cache entity |
| `updateEmbeddingsBackend` | `false` | Update APIM embeddings backend |
| `deployAzureMonitorLogger` | `false` | Create the `azuremonitor` logger and (optional) diagnostic settings to an existing LAW |

### Feature-Specific Parameters

| Parameter | Default | Description |
|---|---|---|
| `enablePIIAnonymization` | `true` | Enable PII anonymization policy fragments |
| `enableAIModelInference` | `true` | Enable AI model inference fragments |
| `enableUnifiedAiApi` | `true` | Enable the Unified AI Wildcard API |
| `enableJwtAuth` | `false` | Enable JWT authentication named values and security-handler fragment |
| `jwtTenantId` | `''` | JWT Tenant ID (required when `enableJwtAuth` is true) |
| `jwtAppRegistrationId` | `''` | JWT App Registration Client ID (required when `enableJwtAuth` is true) |
| `enableRedisCache` | `false` | Enable APIM Redis cache entity (requires `redisCacheConnectionString`) |
| `enableEmbeddingsBackend` | `false` | Enable APIM embeddings backend (requires `embeddingsBackendUrl`) |
| `azureOpenAIApiPathPrefix` | `''` | Prefix for the Azure OpenAI API (`''`→`/openai`, `v2`→`/v2/openai`) for legacy coexistence |
| `universalLLMApiPathPrefix` | `''` | Prefix for the Universal LLM API (`''`→`/models`, `v2`→`/v2/models`) for legacy coexistence |
| `logAnalyticsWorkspaceResourceId` | `''` | Resource ID of an existing LAW for APIM diagnostics (only when `deployAzureMonitorLogger` is true) |

### Logging Settings

| Parameter | Description |
|---|---|
| `azureMonitorLogSettings` | Frontend/backend headers & body bytes, LLM log settings for Azure Monitor |
| `appInsightsLogSettings` | Headers to capture and body bytes for Application Insights |

## File structure

```
apim-gateway-upgrade/
├── main.bicep                          # APIM configuration upgrade (resource group scope)
├── main.bicepparam                     # Parameter file — configure before deploying
├── supporting-services.bicep           # Gateway ecosystem provisioning / alignment (create-or-BYO)
├── supporting-services.bicepparam      # Supporting-services parameter file
├── services/                           # Upgrade-scoped wrapper modules (create-or-BYO, optional PE)
├── README.md                           # This guide
└── gateway-ecosystem-upgrade-guide.md  # Guide for supporting-services.bicep
```

All API specs, policy XML files, and sub-modules are referenced from `../modules/apim/` — no duplication of policy or spec files.