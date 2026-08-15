# 🚀 Governance Hub Backend Contract

## Overview

Automate the onboarding of LLM backends to your APIM-based AI Gateway with a streamlined, infrastructure-as-code approach using **Bicep parameter files** (`.bicepparam`).

This package enables dynamic LLM backend routing without modifying APIM policies:

- 📦 **Automatic Backend Creation**: Create APIM backends from configuration
- ⚖️ **Load Balancing**: Distribute requests across multiple backends for the same model
- 🔄 **Automatic Failover**: Route to healthy backends when others are unavailable
- 🔌 **Multi-Provider Support**: Microsoft Foundry, Azure OpenAI, Amazon Bedrock, and external LLM providers
- 📝 **Declarative Configuration**: Simple `.bicepparam` files for version control

## What Gets Created

| Resource | Description |
|----------|-------------|
| **APIM Backends** | Individual backend resources for each LLM endpoint |
| **Backend Pools** | Load-balanced pools for models with multiple backends |
| **Policy Fragments** | Dynamic routing logic for model-based routing |
| **Get Available Models Fragment** | Returns available model deployments with capabilities (similar to Azure Cognitive Services API) |
| **Metadata Config Fragment** | Centralized model routing config for the Unified AI API — always deployed with backend onboarding to stay in sync |
| **Resolve Model Alias Fragment** | Resolves client-facing alias names (e.g. `adv-gpt` as an alias for gpt-5.2 and gpt-4.1) to actual underlying models — shared across Azure OpenAI, Universal LLM, and Unified AI APIs |
| **Backend Contract Fragment** | `backend-contract` fragment returning the active routing contract as JSON: APIM target, full `llmBackendConfig` (per-model metadata), circuit breaker + session affinity configuration, model aliases, and derived pools. Regenerated on every onboarding run so the Release Version API `GET /version/backend-contract` operation always reflects the live contract |

> [!NOTE]
> **Backend Contract endpoint.** The primary accelerator deployment creates a **Release Version API**
> with a `GET /version/backend-contract` operation. That operation returns its response through the
> dynamically generated `backend-contract` policy fragment. Running this onboarding submodule
> **refreshes that fragment** from your full `llmBackendConfig` (plus circuit breaker, session
> affinity, and model alias settings), so the endpoint immediately reflects newly onboarded
> backends/models — no change to the API definition is required. Inline `authConfig.secretValue`
> entries are redacted (Key Vault references and named-value keys are preserved). See the
> [Release Version Management Guide](../../../guides/release-version-management.md#backend-contract-endpoint).

## Prerequisites

- Existing deployment of AI Citadel Governance Hub with:
  - User-assigned managed identity configured
  - APIs for Universal LLM API and Azure OpenAI API
- LLM backends deployed and accessible:
  - Microsoft Foundry with model deployments
  - Azure OpenAI resources with model deployments
  - Amazon Bedrock with foundation model access
  - APIM can reach the target backends from network perspective
- Verify APIM's user assigned managed identity has required roles:
   - `Cognitive Services OpenAI User` for Azure OpenAI
   - `Cognitive Services User` for Microsoft Foundry
- For Amazon Bedrock:
   - AWS IAM user with Bedrock access and access keys generated
   - Provide `awsAccessKey`, `awsSecretKey`, and `awsRegion` parameters when deploying — these are stored as secret APIM named values (`aws-access-key`, `aws-secret-key`, `aws-region`)
   - If these parameters are not provided, the named values are created with a `NOT_CONFIGURED` placeholder and the gateway returns a `500 AWSCredentialsNotConfigured` error at runtime when a Bedrock backend is invoked

## Quick Start

### 1. Copy the Parameter Template

```bash
cp main.bicepparam llm-backends-dev-local.bicepparam
```

### 2. Configure Your Backends

Edit `llm-backends-dev-local.bicepparam`:

```bicep
using 'main.bicep'

param apim = {
  subscriptionId: '00000000-0000-0000-0000-000000000000' // Replace with your subscription ID
  resourceGroupName: 'rg-citadel-governance-hub'         // Replace with your APIM resource group
  name: 'apim-citadel-governance-hub'                    // Replace with your APIM name
}

param apimManagedIdentity = {
  subscriptionId: '00000000-0000-0000-0000-000000000000' // Replace with your subscription ID
  resourceGroupName: 'rg-citadel-governance-hub'         // Replace with your identity resource group
  name: 'id-apim-citadel'                                // Replace with your managed identity name
}

param llmBackendConfig = [
  {
    backendId: 'aif-citadel-primary'
    backendType: 'ai-foundry'
    endpoint: 'https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/'
    authType: 'managed-identity'
    supportedModels: [
      { "name": "gpt-4o-mini", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-07-18", "retirementDate": "2026-09-30" },
      { "name": "gpt-4o", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-11-20", "retirementDate": "2026-09-30" },
      { "name": "gpt-4.1", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2025-04-14", "retirementDate": "2026-10-14", "apiVersion": "2025-04-01-preview", "timeout": 180 },
      { "name": "DeepSeek-R1", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "DeepSeek", "modelVersion": "1", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "Phi-4", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "Microsoft", "modelVersion": "3", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "text-embedding-3-large", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "1", "retirementDate": "2027-04-14" }
    ]
    priority: 1
    weight: 100
  }
]
```

### 3. Deploy

```bash
az deployment sub create --name llm-backend-onboarding --location swedencentral --template-file main.bicep --parameters llm-backends-generated-local.bicepparam
```

## Configuration Reference

### Backend Configuration Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `backendId` | string | Yes | Unique identifier for the backend (usually the name of the backend resource) |
| `backendType` | string | Yes | `ai-foundry`, `azure-openai`, `aws-bedrock`, `aws-bedrock-mantle`, `gemini`, `gemini-openai`, `anthropic`, `azure-flux`, `azure-mai`, or `external` |
| `endpoint` | string | Yes | Base URL of the LLM service |
| `authType` | string | No | `managed-identity`, `aws-sigv4`, `api-key-bearer`, `api-key-header`, `api-key-gemini`, `api-key-anthropic`, or `none`. When omitted, derived from `backendType` (ai-foundry/azure-openai → `managed-identity`) |
| `authConfig` | object | No | `{ namedValueKey, keyVaultSecretUri?, secretValue? }` — required for `api-key-*` auth types |
| `authScheme` | string | No | **Legacy** — `managedIdentity`, `apiKey`, or `token`. Superseded by `authType`; still tolerated for backward compatibility |
| `supportedModels` | array | Yes | Array of model objects (see Model Object Properties below) |
| `priority` | number | No | 1-5, default 1 (lower = higher priority) |
| `weight` | number | No | 1-1000, default 100 (load balancing weight) |
| `circuitBreaker` | object | No | Per-backend circuit breaker override (shallow-merged over `circuitBreakerDefaults`). Supports `failureCount`, `failureInterval`, `tripDuration`, `acceptRetryAfter`, `errorReasons`, `statusCodeRanges`, and `enabled`. See [Circuit Breaker Configuration](#circuit-breaker-configuration) |
| `sessionAffinity` | object | No | Per-backend session affinity override (shallow-merged over `sessionAffinityDefaults`). Supports `cookieName` and `source`. Applies to the session-aware model pools this backend joins. See [Session Affinity Configuration](#session-affinity-configuration) |

### Model Object Properties

Each model in the `supportedModels` array has these properties:

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | string | Yes | Model name (e.g., `gpt-4o`, `DeepSeek-R1`, `Phi-4`) |
| `sku` | string | No | SKU name for the deployment (default: `Standard`). Used in `get-available-models` response |
| `capacity` | number | No | Capacity/TPM quota (default: 100). Used in `get-available-models` response |
| `modelFormat` | string | No | Model format identifier, e.g., `OpenAI`, `DeepSeek`, `Microsoft` (default: `OpenAI`). Used in `get-available-models` response |
| `modelVersion` | string | No | Version of the model (default: `1`). Used in `get-available-models` response |
| `retirementDate` | string (date) | No | Optional retirement date for the model. Used in `get-available-models` response |
| `apiVersion` | string | No | API version for OpenAI-type requests (default: `2024-02-15-preview`). Used by Unified AI API for backend routing |
| `timeout` | number | No | Request timeout in seconds (default: `120`). Used by Unified AI API for per-model timeout configuration |
| `inferenceApiVersion` | string | No | API version for inference-type requests (e.g., `2024-05-01-preview`). Used by Unified AI API for non-OpenAI models |
| `sessionAwareModel` | bool | No | Default `false`. Marks a **stateful** model (e.g., OpenAI Responses / Assistants). When such a model is served by a multi-backend pool, the pool is given session affinity so follow-up requests replaying the affinity cookie stick to the same backend. See [Session Affinity Configuration](#session-affinity-configuration) |
| `modelPath` | string | No | Provider-specific model slug used in the backend URL path. **Required for `azure-flux`** models, where the BFL slug differs from the model name (e.g. model `FLUX.2-pro` -> `modelPath` `flux-2-pro`, `FLUX.1-Kontext-pro` -> `flux-kontext-pro`). When omitted, the gateway falls back to the model name. Set once at onboarding; see [Image Models](#image-models). |

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
- Requires additional parameters: `awsAccessKey`, `awsSecretKey`, `awsRegion`
- See [Microsoft Learn: Import Amazon Bedrock API](https://learn.microsoft.com/en-us/azure/api-management/amazon-bedrock-passthrough-llm-api) for detailed APIM integration guidance

#### Azure FLUX (`azure-flux`)
- Black Forest Labs FLUX image models hosted on a Microsoft Foundry resource (native BFL surface)
- Endpoint format: `https://<resource>.services.ai.azure.com/` (or `https://<resource>.api.cognitive.microsoft.com/`)
- Authentication: Managed identity with Cognitive Services scope (same as `ai-foundry`)
- Path construction: `/providers/blackforestlabs/v1/{modelPath}?api-version=preview` — **each model must set `modelPath`** (the BFL slug, e.g. `flux-2-pro`)
- Image generation/edit only; reached via the unified `/v1/images/generations` and `/v1/images/edits` surfaces. See [Image Models](#image-models).

#### Azure MAI (`azure-mai`)
- Microsoft MAI image models hosted on a Microsoft Foundry resource (native MAI surface)
- Endpoint format: `https://<resource>.services.ai.azure.com/`
- Authentication: Managed identity with Cognitive Services scope (override to `api-key-header` if using a key)
- Path construction: `/mai/v1/images/generations` and `/mai/v1/images/edits` (model travels in the request body)
- Image generation/edit only; reached via the unified `/v1/images/generations` and `/v1/images/edits` surfaces. See [Image Models](#image-models).

## Example Configurations

### Single AI Foundry Backend

```bicep
param llmBackendConfig = [
  {
    backendId: 'aif-citadel-primary'
    backendType: 'ai-foundry'
    endpoint: 'https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/'
    authType: 'managed-identity'
    supportedModels: [
      { "name": "gpt-4o-mini", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-07-18", "retirementDate": "2026-09-30" },
      { "name": "gpt-4o", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-11-20", "retirementDate": "2026-09-30" },
      { "name": "gpt-4.1", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2025-04-14", "retirementDate": "2026-10-14", "apiVersion": "2025-04-01-preview", "timeout": 180 },
      { "name": "DeepSeek-R1", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "DeepSeek", "modelVersion": "1", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "Phi-4", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "Microsoft", "modelVersion": "3", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "text-embedding-3-large", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "1", "retirementDate": "2027-04-14" }
    ]
    priority: 1
    weight: 100
  }
]
```

### Load Balancing Across Regions

As `DeepSeek-R1` is available in 2 different backends, the onboarding script will automatically create a backend pool for `DeepSeek-R1` and distribute traffic based on the specified priority/weights.

```bicep
param llmBackendConfig = [
  {
    backendId: 'aif-citadel-primary'
    backendType: 'ai-foundry'
    endpoint: 'https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/'
    authType: 'managed-identity'
    supportedModels: [
      { "name": "gpt-4o-mini", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-07-18", "retirementDate": "2026-09-30" },
      { "name": "gpt-4o", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-11-20", "retirementDate": "2026-09-30" },
      { "name": "gpt-4.1", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2025-04-14", "retirementDate": "2026-10-14", "apiVersion": "2025-04-01-preview", "timeout": 180 },
      { "name": "DeepSeek-R1", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "DeepSeek", "modelVersion": "1", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "Phi-4", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "Microsoft", "modelVersion": "3", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "text-embedding-3-large", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "1", "retirementDate": "2027-04-14" }
    ]
    priority: 1
    weight: 100
  }
  {
    backendId: 'aif-citadel-secondary'
    backendType: 'ai-foundry'
    endpoint: 'https://aif-RESOURCE_TOKEN-1.cognitiveservices.azure.com/'
    authType: 'managed-identity'
    supportedModels: [
      { "name": "gpt-5", "sku": "GlobalStandard", "capacity": 50, "modelFormat": "OpenAI", "modelVersion": "1", "retirementDate": "2027-02-05" },
      { "name": "DeepSeek-R1", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "DeepSeek", "modelVersion": "1", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" }
    ]
    priority: 2
    weight: 50
  }
]
```

### Mixed Providers

This is mixing Azure OpenAI and Microsoft Foundry backends. Common models across providers will be automatically load balanced (like `DeepSeek-R1` and `text-embedding-3-large` in the below example), while unique models will be routed to their specific backend.

```bicep
param llmBackendConfig = [
  {
    backendId: 'aif-citadel-primary'
    backendType: 'ai-foundry'
    endpoint: 'https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/'
    authType: 'managed-identity'
    supportedModels: [
      { "name": "gpt-4o-mini", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-07-18", "retirementDate": "2026-09-30" },
      { "name": "gpt-4o", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-11-20", "retirementDate": "2026-09-30" },
      { "name": "gpt-4.1", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2025-04-14", "retirementDate": "2026-10-14", "apiVersion": "2025-04-01-preview", "timeout": 180 },
      { "name": "DeepSeek-R1", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "DeepSeek", "modelVersion": "1", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "Phi-4", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "Microsoft", "modelVersion": "3", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "text-embedding-3-large", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "1", "retirementDate": "2027-04-14" }
    ]
    priority: 1
    weight: 100
  }
  {
    backendId: 'aoai-eastus-gpt4'
    backendType: 'azure-openai'
    endpoint: 'https://YOUR-AOAI-RESOURCE.openai.azure.com/'
    authType: 'managed-identity'
    supportedModels: [
      { "name": "gpt-5", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2025-08-07", "retirementDate": "2027-02-05" },
      { "name": "DeepSeek-R1", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "DeepSeek", "modelVersion": "1", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "text-embedding-3-large", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "1", "retirementDate": "2027-04-14" }
    ]
    priority: 1
    weight: 100
  }
]
```

### Amazon Bedrock Backend

This example adds an Amazon Bedrock backend alongside Azure backends. The `aws-bedrock` backend type uses AWS SigV4 authentication via IAM access keys stored as APIM named values.

```bicep
param llmBackendConfig = [
  {
    backendId: 'aif-citadel-primary'
    backendType: 'ai-foundry'
    endpoint: 'https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/'
    authType: 'managed-identity'
    supportedModels: [
      { "name": "gpt-4o", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-11-20", "retirementDate": "2026-09-30" }
    ]
    priority: 1
    weight: 100
  }
  {
    backendId: 'bedrock-us-east-1'
    backendType: 'aws-bedrock'
    endpoint: 'https://bedrock-runtime.us-east-1.amazonaws.com'
    authType: 'aws-sigv4'
    supportedModels: [
      { "name": "us.anthropic.claude-3-5-haiku-20241022-v1:0", "sku": "OnDemand", "capacity": 1, "modelFormat": "Anthropic", "modelVersion": "1", "retirementDate": "2099-12-30" }
      { "name": "us.anthropic.claude-3-5-sonnet-20241022-v2:0", "sku": "OnDemand", "capacity": 1, "modelFormat": "Anthropic", "modelVersion": "2", "retirementDate": "2099-12-30" }
      { "name": "us.amazon.nova-pro-v1:0", "sku": "OnDemand", "capacity": 1, "modelFormat": "Amazon", "modelVersion": "1", "retirementDate": "2099-12-30" }
    ]
    priority: 1
    weight: 100
  }
]

// AWS credentials for Bedrock authentication
param awsAccessKey = '<your-aws-access-key-id>'
param awsSecretKey = '<your-aws-secret-access-key>'
param awsRegion = 'us-east-1'
```

> **Important**: Store AWS access keys securely. Consider using Azure Key Vault references for the APIM named values in production. See [Create IAM user access keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/access-key-self-managed.html#Using_CreateAccessKey) for generating AWS access keys.

## Circuit Breaker Configuration

Each APIM backend can be protected by a [circuit breaker](https://learn.microsoft.com/azure/api-management/backends#circuit-breaker) that temporarily stops routing to a backend once it starts failing, and automatically probes it back into rotation after a cool-off. Circuit breaking is controlled at two levels:

1. **`configureCircuitBreaker`** (bool, default `true`) — the master toggle. When `false`, no backend gets a circuit breaker.
2. **`circuitBreakerDefaults`** (object) — the default rule applied to **every** backend when the master toggle is on.
3. **Per-backend `circuitBreaker`** (object, optional) — added to an individual `llmBackendConfig` entry to override a subset of the defaults for that one backend, or to disable it entirely.

### Settings

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `failureCount` | number | `3` | Number of failures within `failureInterval` that trips the breaker |
| `failureInterval` | string (ISO 8601) | `PT5M` | Rolling window used to count failures |
| `tripDuration` | string (ISO 8601) | `PT1M` | How long the breaker stays open once tripped |
| `acceptRetryAfter` | bool | `true` | Honor an upstream `Retry-After` header when tripping |
| `errorReasons` | string[] | `['Server errors']` | Failure reasons that count toward the breaker |
| `statusCodeRanges` | object[] | `429` and `500-503` | HTTP status ranges (`{ min, max }`) counted as failures |
| `enabled` | bool | `true` | Per-backend only — set `false` to disable the breaker for that backend even when the master toggle is on |

> The built-in defaults match the previously hard-coded rule, so existing deployments behave identically when no new parameters are supplied.

### Global defaults

Tune the rule applied to all backends by supplying `circuitBreakerDefaults` in your `.bicepparam` file:

```bicep
param configureCircuitBreaker = true

param circuitBreakerDefaults = {
  failureCount: 5
  failureInterval: 'PT1M'
  tripDuration: 'PT30S'
  acceptRetryAfter: true
  errorReasons: [ 'Server errors' ]
  statusCodeRanges: [
    { min: 429, max: 429 }
    { min: 500, max: 503 }
  ]
}
```

### Per-backend override

Add a `circuitBreaker` object to any backend entry. Only the keys you set change; the rest fall back to `circuitBreakerDefaults`:

```bicep
param llmBackendConfig = [
  {
    backendId: 'aif-citadel-primary'
    backendType: 'ai-foundry'
    endpoint: 'https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/'
    authType: 'managed-identity'
    supportedModels: [ /* ... */ ]
    priority: 1
    weight: 100
    // Trip faster than the global default for this backend only
    circuitBreaker: {
      failureCount: 5
      failureInterval: 'PT1M'
      tripDuration: 'PT30S'
    }
  }
  {
    backendId: 'aif-citadel-secondary'
    backendType: 'ai-foundry'
    endpoint: 'https://aif-RESOURCE_TOKEN-1.cognitiveservices.azure.com/'
    authType: 'managed-identity'
    supportedModels: [ /* ... */ ]
    priority: 2
    weight: 50
    // Disable the circuit breaker for this backend only
    circuitBreaker: { enabled: false }
  }
]
```

> **Backward compatible.** `circuitBreakerDefaults` and per-backend `circuitBreaker` are both optional. With neither supplied, every backend gets the same rule as before (`failureCount: 3`, `PT5M` window, `PT1M` trip, on `429` + `500-503`).

## Session Affinity Configuration

When the same model is served by **multiple backends**, the onboarding creates an APIM [backend pool](https://learn.microsoft.com/azure/api-management/backends#load-balanced-pool) that load-balances requests across them by priority/weight. For **stateless** models this is ideal. For **stateful** models — where follow-up calls must land on the same backend that holds the conversation/thread state (e.g., the OpenAI **Responses API** and **Assistants API**) — pure load balancing breaks the session.

**Session affinity** (session-aware load balancing) solves this: APIM sets a session cookie on the first response and, when the client replays that cookie on subsequent requests, routes them back to the **same backend** in the pool.

Session affinity is controlled at two levels, and enablement is **per-model**:

1. **`sessionAwareModel`** (bool on each model object, default `false`) — the opt-in. Only pools whose model is flagged session-aware receive affinity. A single backend can freely mix stateful (`sessionAwareModel: true`, e.g. `gpt-4.1` used with the Responses API) and stateless (default, e.g. `Phi-4`) models — only the flagged models' pools become sticky.
2. **`configureSessionAffinity`** (bool, default `true`) — a global kill-switch. Leaving it `true` is safe because no pool gets affinity unless a model is flagged. Set it `false` to force affinity off everywhere.
3. **`sessionAffinityDefaults`** (object) — the cookie settings applied to every session-aware pool.
4. **Per-backend `sessionAffinity`** (object, optional) — added to an `llmBackendConfig` entry to override the cookie settings for the session-aware pools that backend joins.

### Settings

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `cookieName` | string | `ai-gateway-affinity` | Name of the affinity cookie APIM sets/reads. The non-generic default avoids clashing with other cookies used by the client or backend |
| `source` | string | `Cookie` | Where APIM reads the session id from. Only `Cookie` is supported today |

> **Backward compatible.** `sessionAwareModel` defaults to `false`, so existing configs produce identical pools with **no** session affinity. Affinity only appears once you flag a model.

### How it resolves

- A pool becomes session-aware if **any** member backend flags that model `sessionAwareModel: true` (the flag is ORed across the pool).
- The pool's cookie config is `sessionAffinityDefaults` shallow-merged with the **first** pool member that supplies a per-backend `sessionAffinity` override (else just the defaults).
- Single-backend (non-pooled) models are unaffected — affinity is only meaningful when there are 2+ backends to choose between.

### Global defaults

```bicep
param configureSessionAffinity = true

param sessionAffinityDefaults = {
  cookieName: 'ai-gateway-affinity'
  source: 'Cookie'
}
```

### Flag a stateful model

Add `sessionAwareModel: true` to the model on every backend that serves it (flagging one member is enough, but flagging all keeps intent explicit):

```bicep
param llmBackendConfig = [
  {
    backendId: 'aif-citadel-primary'
    backendType: 'ai-foundry'
    endpoint: 'https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/'
    authType: 'managed-identity'
    supportedModels: [
      // Stateful — used with the OpenAI Responses API; its pool becomes sticky
      { name: 'gpt-4.1', modelFormat: 'OpenAI', modelVersion: '2025-04-14', sessionAwareModel: true }
      // Stateless — stays pure load-balanced
      { name: 'Phi-4', modelFormat: 'Microsoft', modelVersion: '3' }
    ]
    priority: 1
    weight: 100
    // Optional per-backend cookie override for this backend's session-aware pools
    // sessionAffinity: { cookieName: 'ai-gateway-affinity', source: 'Cookie' }
  }
  {
    backendId: 'aif-citadel-secondary'
    backendType: 'ai-foundry'
    endpoint: 'https://aif-RESOURCE_TOKEN-1.cognitiveservices.azure.com/'
    authType: 'managed-identity'
    supportedModels: [
      { name: 'gpt-4.1', modelFormat: 'OpenAI', modelVersion: '2025-04-14', sessionAwareModel: true }
    ]
    priority: 2
    weight: 50
  }
]
```

### Client requirement (cookie jar)

Affinity only works if the **client replays the cookie**. APIM returns the affinity cookie in a `Set-Cookie` header; the client must persist it and send it on every follow-up request in the same session:

- Use a **single, shared HTTP client with a cookie container** (cookie jar) for all requests belonging to one logical session/conversation.
- Most SDKs and browsers do this automatically when you reuse the same client instance; raw HTTP callers must capture `Set-Cookie` and echo it back on subsequent calls.
- Different sessions should use separate cookie jars so they can be balanced independently.

> **Notes / limits.** Affinity is best-effort across gateway units (APIM's distributed nature). It only applies to pooled (multi-backend) session-aware models. If a stuck backend trips its circuit breaker, traffic still fails over to another pool member.

## Image Models

The Unified AI API routes image-generation and image-edit models (Azure OpenAI **gpt-image**, Black Forest Labs **FLUX**, Microsoft **MAI**) through a single OpenAI-style images surface. All three providers return OpenAI-shaped responses (`data[].b64_json`), so clients use one consistent contract regardless of provider.

### Client surface

| Endpoint | Model location | Use for |
|----------|----------------|---------|
| `POST /unified-ai/v1/images/generations` | `model` in JSON body | Generation (gpt-image, FLUX, MAI) |
| `POST /unified-ai/openai/deployments/{model}/images/generations` | `{model}` in URL | Generation (Azure OpenAI SDK style) |
| `POST /unified-ai/openai/deployments/{model}/images/edits` | `{model}` in URL | Edits (multipart) — **recommended** |
| `POST /unified-ai/v1/images/edits` | `x-ai-model` **header** | Edits (multipart) when not using the deployments path |

> **Image edits are multipart/form-data.** The model can't be read from a multipart form field, so on `POST /unified-ai/v1/images/edits` you must pass the model in the `x-ai-model` request header. Prefer the `/openai/deployments/{model}/images/edits` form, which carries the model in the URL. A missing model returns `400 missing_model_parameter` with guidance.

### Provider routing

| Provider | `backendType` | Backend path built by the gateway | Auth |
|----------|---------------|-----------------------------------|------|
| Azure OpenAI / Foundry gpt-image | `ai-foundry` / `azure-openai` | `/openai/v1/images/generations` \| `/openai/v1/images/edits` | Managed identity |
| Black Forest Labs FLUX | `azure-flux` | `/providers/blackforestlabs/v1/{modelPath}?api-version=preview` | Managed identity |
| Microsoft MAI | `azure-mai` | `/mai/v1/images/generations` \| `/mai/v1/images/edits` | Managed identity |

### FLUX `modelPath` (one-time onboarding step)

FLUX's URL slug isn't derivable from the model name, so **every `azure-flux` model must set `modelPath`** to the BFL slug. This is a one-time onboarding value; once set, the gateway routes correctly:

| Model name | `modelPath` |
|------------|-------------|
| `FLUX.2-pro` | `flux-2-pro` |
| `FLUX.2-flex` | `flux-2-flex` |
| `FLUX.1-Kontext-pro` | `flux-kontext-pro` |
| `FLUX-1.1-pro` | `flux-pro-1.1` |

### Example configuration

```bicep
param llmBackendConfig = [
  // gpt-image rides the existing Foundry/Azure OpenAI backend (no new backend needed)
  {
    backendId: 'aif-citadel-primary'
    backendType: 'ai-foundry'
    endpoint: 'https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/'
    authType: 'managed-identity'
    supportedModels: [
      { "name": "gpt-image-1.5", "sku": "GlobalStandard", "capacity": 10, "modelFormat": "OpenAI", "modelVersion": "1", "retirementDate": "2099-12-30" }
    ]
    priority: 1
    weight: 100
  }
  // FLUX — native BFL surface; each model sets its modelPath slug
  {
    backendId: 'aif-citadel-flux'
    backendType: 'azure-flux'
    endpoint: 'https://aif-RESOURCE_TOKEN-0.services.ai.azure.com/'
    authType: 'managed-identity'
    supportedModels: [
      { "name": "FLUX.2-pro", "modelPath": "flux-2-pro", "modelFormat": "BlackForestLabs", "modelVersion": "1", "retirementDate": "2099-12-30" }
      { "name": "FLUX.1-Kontext-pro", "modelPath": "flux-kontext-pro", "modelFormat": "BlackForestLabs", "modelVersion": "1", "retirementDate": "2099-12-30" }
    ]
    priority: 1
    weight: 100
  }
  // MAI — native MAI surface; model travels in the request body
  {
    backendId: 'aif-citadel-mai'
    backendType: 'azure-mai'
    endpoint: 'https://aif-RESOURCE_TOKEN-0.services.ai.azure.com/'
    authType: 'managed-identity'
    supportedModels: [
      { "name": "MAI-Image-2.5-Flash", "modelFormat": "MAI", "modelVersion": "1", "retirementDate": "2099-12-30" }
    ]
    priority: 1
    weight: 100
  }
]
```

> **Backward compatible.** Image routing is isolated behind a new `image` api-type (`/v1/images`) plus the new `azure-flux`/`azure-mai` pool types. Existing chat, embeddings, responses, and native Bedrock/Gemini/Anthropic surfaces are unaffected. Token-usage metrics are unchanged (image responses simply emit zero token usage).

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

As of the alias-as-virtual-pool refactor, every entry in `modelAliases` becomes a **virtual pool entry inside the same `backendPools` JArray that real model pools live in**. APIM cannot natively put pools inside pools, so the gateway materialises this with a deploy-time-resolved JObject that carries each member's underlying poolName / poolType / authType. Alias resolution and member fallback then ride on the same `set-target-backend-pool` + retry pipeline that real models use. You get:

- **Same-spec load balancing and fallback** — the alias resolves to a member that's compatible with the inbound API surface (filtered by `compatiblePoolTypes`); on 429/5xx the retry block walks the remaining members in resolution order. When the alias spans multiple clouds for a single shared spec (e.g. OpenAI-compat across Foundry + Bedrock-Mantle + Gemini-OpenAI), this is **transparent cross-cloud fallback**.
- **Routing strategies** — `priority` (deterministic order with implicit fallback) or `weighted` (probabilistic distribution) configured per alias.
- **Backend path templates preserved** — once a member is picked, the request takes the same code paths a direct call to that real model would have taken (URL rewrite, auth, body forwarding).
- **Consistent across the LLM API surfaces** — Azure OpenAI API, Universal LLM API, and Unified AI API all resolve aliases the same way using the shared `set-target-backend-pool` fragment.
- **Compatible-pool-types filtering** — when the inbound API surface restricts pool types (e.g. Universal LLM = OpenAI-compat-only, `/claude/` = anthropic-only), alias members with no compatible underlying pool are skipped automatically. An alias with no member compatible with the surface returns a clear `alias_no_compatible_member` 400.
- **Direct-model routing untouched** — aliases are opt-in. Customers who never declare `modelAliases` see exactly the same direct-pool behaviour as before.

### Reference scenarios (from the extended-providers validation notebook)

The extended-providers validation notebook (`validation/llm-backend-onboarding-extended-providers-runner.ipynb`) builds three opt-in alias scenarios from the configured backends. Each one only materialises when its underlying members exist:

| Scenario | Alias | API spec | Members today | Use case |
|---|---|---|---|---|
| **A. Foundry weighted** | `foundry-weighted-mix` | OpenAI `/v1/chat/completions` (single cloud) | Up to 3 Microsoft Foundry models, weighted (e.g. 50/30/20) | A/B testing a new model, blended traffic across the Foundry catalog |
| **B. Cross-cloud OpenAI-compat** | `multi-cloud-openai` | OpenAI `/v1/chat/completions` (multi-cloud) | First model from each of: Foundry, Bedrock-Mantle, Gemini-OpenAI | Multi-cloud failover for OpenAI-compat workloads |
| **C. Native Anthropic Messages** | `multi-cloud-claude` | Anthropic `/v1/messages` | Anthropic API-key members today; Bedrock-Anthropic + Foundry-Anthropic passthroughs are planned | Single Anthropic abstraction across regions / tenants today, multi-cloud once passthroughs ship |

### Configuration

Add a `modelAliases` array to your `.bicepparam` file alongside `llmBackendConfig`. Pick the scenarios that match your backend mix:

```bicep
param modelAliases = [
  // Scenario A — Foundry weighted load-balance (single cloud, OpenAI-compat).
  // All members must be in `ai-foundry` pools. Use weights to drive the
  // random-by-weight pick on each call.
  {
    name: 'foundry-weighted-mix'
    models: [ 'gpt-5', 'mistral-large', 'Phi-4' ]
    strategy: 'weighted'
    weights: [ 50, 30, 20 ]
  }
  // Scenario B — Cross-cloud OpenAI-compat (multi-cloud, same /v1/chat/completions spec).
  // Members must be OpenAI-compat-capable: ai-foundry, aws-bedrock-mantle, gemini-openai.
  // Priority strategy gives a primary + transparent cross-cloud fallback.
  {
    name: 'multi-cloud-openai'
    models: [
      'gpt-4.1'                  // ai-foundry
      'openai.gpt-oss-120b'      // aws-bedrock-mantle
      'gemini-2.5-flash-lite'    // gemini-openai
    ]
    strategy: 'priority'
  }
  // Scenario C — Native Anthropic Messages alias (/v1/messages spec).
  // Today the only backend type that natively serves /v1/messages is `anthropic`,
  // so alias members are limited to direct Anthropic API keys. Once the planned
  // `aws-bedrock-anthropic-passthrough` and `foundry-anthropic-passthrough`
  // backend types ship, add their Claude model names here and the same alias
  // will fan across clouds with no caller-side change.
  {
    name: 'multi-cloud-claude'
    models: [ 'claude-sonnet-4-6', 'claude-haiku-4-5' ]
    strategy: 'priority'
  }
]
```

### Alias Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | string | Yes | Client-facing alias name. Must NOT collide with any real model name in `llmBackendConfig`. |
| `models` | string[] | Yes | Ordered list of underlying real models the alias may resolve to. Each must exist as a `name` in some backend's `supportedModels`. May span any mix of providers. |
| `strategy` | string | No | `priority` (default) — first compatible member wins, the rest form the fallback list; `weighted` — random selection by weights, the rest form the fallback list (round-walk after the picked one). |
| `weights` | int[] | No | Required when `strategy` is `weighted`. Same length as `models`. Higher weight = more traffic. Used at deploy time to render the alias virtual pool entry; runtime selection is random-weighted. |

### Resolution flow

```
1. Client calls e.g. POST /unified-ai/v1/chat/completions with `"model": "multi-cloud-openai"`.

2. validate-model-access: RBAC check on the alias name (`allowedModels` in the
   product policy controls alias access — admins do NOT need to enumerate the
   underlying real models).

3. set-backend-pools: Loads the gateway's `backendPools` JArray. The alias appears
   as a virtual pool entry with `isAlias=true`, `aliasName="multi-cloud-openai"`,
   `members=[ {model, weight, pools[]}, ... ]`. Each member's `pools[]` carries
   the resolved poolName / poolType / authType for every underlying pool that
   hosts the member model.

4. set-target-backend-pool: Detects the alias. Filters members by the inbound
   API surface's `compatiblePoolTypes` (so e.g. /v1/chat/completions only
   considers OpenAI-compat-capable pool types). Picks one member based on
   `strategy`. Sets:
     - is-alias = true
     - original-model-alias = "multi-cloud-openai"
     - requestedModel = picked member's real model name
     - targetBackendPool = picked member's poolName
     - targetPoolType / targetAuthType / targetAuthConfigNamedValue
     - alias-fallback-members = JArray of remaining members in walk order,
       each pre-resolved to its compatible poolName / poolType / authType /
       authConfigNamedValue.
   Same-spec discipline: every member here is OpenAI-compat-capable, so the
   downstream stages can forward the request unchanged regardless of which
   member won the pick.

5. resolve-model-alias: Slim post-resolution body rewrite. Replaces the JSON
   body's `model` field with `requestedModel` so backends see the real name.
   No-op when `is-alias=false`.

6. set-backend-authorization + path-builder: Operate on the resolved real model
   exactly like a direct request would.

7. Backend retry block: If the request returns 429 or 5xx (pre-stream), the
   API policy walks `alias-fallback-members` one entry at a time, swapping
   targetBackendPool / requestedModel / authType in place and re-invoking
   resolve-model-alias + set-backend-authorization (+ path-builder for Unified
   AI). Cross-cloud fallback (Foundry → Bedrock-Mantle → Gemini-OpenAI) is
   transparent to the client. Once streaming has started, fallback is no
   longer possible.
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

The `description` field under `capabilities` exposes which underlying models the alias maps to and which strategy is in use (with the configured weights when `strategy: weighted`). The discovery filter (`allowedModels` from the access contract) matches by `name`, so RBAC works for aliases identically to real models.

### Source of Truth

Aliases are emitted in two places by the same Bicep parameter (`modelAliases`):

| Fragment | Used By | Source |
|----------|---------|--------|
| `set-backend-pools` (virtual pool entries inside the `backendPools` JArray) | All 3 APIs (alias resolution + retry fallback) | Generated `aliasPoolsCode` block |
| `get-available-models` | All 3 APIs (`GET /deployments`) | Inline `JObject` entry per alias with description |
| `metadata-config` (`model-aliases` JSON section) | Unified AI API (informational / cached config) | `modelAliasesCode` JSON block |

All three are regenerated on every onboarding deployment, so the views stay in sync. The runtime resolution exclusively reads from the `set-backend-pools` virtual entries — `metadata-config` keeps a parallel copy for tooling that introspects the cached config.

### Errors

| Code | When |
|------|------|
| `alias_no_compatible_member` (400) | The alias was matched but every member's underlying pool is incompatible with the inbound API surface (filtered out by `compatiblePoolTypes`). The error body includes the alias name, requested CSV of compatible pool types, and total member count. |
| `unauthorized_model_access` (403) | The alias name is not in the access contract's `allowedModels` list. |

## Get Available Models API

The `get-available-models` policy fragment enables an API endpoint that returns all available model deployments with their capabilities, similar to the Azure Cognitive Services deployment list API.

This policy fragment is designed to support Microsoft Foundry integration with Citadel Governance Hub, allowing clients to query available models dynamically from Foundry portal experience.

>NOTE: This policy fragment is included in the `/deployments` get operation of the Universal LLM API by default. Currently this Microsoft Foundry feature is in `preview` and may change in future releases.

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

The response is dynamically generated based on the `llmBackendConfig` parameter, using the optional metadata fields (`sku`, `capacity`, `modelFormat`, `modelVersion`).

## Monitoring

### Key Metrics

Connected Application Insights to APIM provides insights into backend performance:

| Metric | Description |
|--------|-------------|
| Application Map | Visual representation of dependencies performance |
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

1. Check model name in `supportedModels` array (case-insensitive)
2. Verify backend pool was created in APIM
3. Review policy fragment deployment

### "403 Forbidden" Error

1. Check `allowedBackendPools` policy variable
2. Verify RBAC configuration
3. Review product/subscription access

### "401 Unauthorized" Error

1. Verify APIM's managed identity has required roles:
   - `Cognitive Services OpenAI User` for Azure OpenAI
   - `Cognitive Services User` for AI Foundry
2. For Amazon Bedrock: Verify AWS IAM access keys are valid and stored as named values (`aws-access-key`, `aws-secret-key`, `aws-region`)
3. `Unauthorized model access` indicates used access contract product is restricted for the model
4. Check named value `uami-client-id` is set correctly to APIM's managed identity client ID

### "500 AWSCredentialsNotConfigured" Error

This error means an `aws-bedrock` backend was matched but the AWS credentials named values are still set to the `NOT_CONFIGURED` placeholder. To fix:

1. Redeploy with the `awsAccessKey`, `awsSecretKey`, and `awsRegion` parameters set to valid values, **or**
2. Manually update the APIM named values `aws-access-key`, `aws-secret-key`, and `aws-region` in the Azure Portal

## Files

```
llm-backend-onboarding/
├── main.bicep                    # Main deployment template
├── main.bicepparam               # Parameter file template
├── README.md                     # This file
└── modules/
    ├── llm-backends.bicep        # Creates APIM backend resources
    ├── llm-backend-pools.bicep   # Creates load-balanced pools
    ├── llm-policy-fragments.bicep # Generates routing policy fragments
    ├── universal-llm-api.bicep   # Creates Universal LLM API
    └── policies/
        ├── frag-set-backend-pools.xml
        ├── frag-set-backend-authorization.xml
        ├── frag-set-target-backend-pool.xml
        ├── frag-set-llm-requested-model.xml
        ├── frag-set-llm-usage.xml
        ├── frag-get-available-models.xml
        ├── frag-metadata-config.xml          # Unified AI API metadata (always deployed)
        ├── frag-resolve-model-alias.xml      # Shared alias resolution (Azure OpenAI / Universal LLM / Unified AI)
        ├── universal-llm-api-policy.xml
        ├── universal-llm-openapi.json
        └── models-inference-openapi.json
```

## Related Guides

- [Citadel Access Contracts](../citadel-access-contracts/README.md) - Configure use case access to governance hub
- [LLM Access Guide](../../../guides/llm-access-guide.md) - Unified LLM access patterns and detailed routing architecture
- [Resiliency Guide](../../../guides/resiliency-guide.md) - Circuit breaker, session affinity, automated failover, and error handling — what to configure and when
- [Full Deployment Guide](../../../guides/full-deployment-guide.md) - Complete Citadel deployment guide