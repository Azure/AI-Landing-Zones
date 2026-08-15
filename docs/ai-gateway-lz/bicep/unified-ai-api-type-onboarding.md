# Onboarding New API Types to the Unified AI API

## Overview

The Unified AI API uses a modular, fragment-based architecture that supports adding new LLM provider API types without modifying the core routing logic. Each API type is defined by a set of configurations and policy rules that control:

- **Path detection**: How the gateway recognizes which API type a request targets
- **Model extraction**: How the requested model is identified from the request
- **Path construction**: How the backend URI is built for the target provider
- **Authentication**: How credentials are set for the backend provider

This guide walks through every step required to add a new API type, using **Amazon Bedrock** as a concrete example.

> **Another worked example: image models.** The `image` api-type (Azure OpenAI gpt-image, Black Forest Labs FLUX, Microsoft MAI) was added following exactly these steps — a new `image` api-type with `base-path: /v1/images`, new `azure-flux`/`azure-mai` backend types with their own `backend-path-templates`, a `{modelPath}` slug placeholder resolved in `path-builder`, and an `x-ai-model` header fallback for multipart edits in `request-processor`. See [LLM Access Guide — Image Models](./llm-access-guide.md#image-models) and [LLM Backend Onboarding — Image Models](../bicep/infra/llm-backend-onboarding/README.md#image-models).

## Architecture Context

The Unified AI API handles all request patterns through a single wildcard endpoint (`/unified-ai/*`). The routing flow is:

```
Client Request → Request Processor (detect API type + extract model)
              → Security Handler (authenticate client)
              → Backend Pool Selection (find target backend)
              → Backend Authorization (authenticate to backend)
              → Path Builder (construct backend URI)
              → Forward to Backend
```

Each step uses APIM policy fragments. Adding a new API type requires updates to specific fragments and configuration files.

## Two Access Modes per Provider

Most non-Azure providers can be onboarded under one or both of the following access modes. Pick the one(s) you need before editing fragments.

| Mode | Inbound API surface | Path examples | Backend `poolType` | URL rewrite responsibility |
|------|---------------------|----------------|--------------------|----------------------------|
| **OpenAI-compatible** | Universal LLM (`/models/*`) **and** Unified AI `inference` (`/unified-ai/v1/*`) | `/models/chat/completions`, `/unified-ai/v1/chat/completions` | `azure-openai`, `ai-foundry`, `aws-bedrock-mantle`, `gemini-openai` | `frag-set-backend-authorization` (Universal LLM) or `frag-path-builder` via `config-backend-path-templates` (Unified AI inference) |
| **Native (provider-specific)** | Unified AI prefixed paths only (`/unified-ai/{provider}/*`) | `/unified-ai/bedrock/model/{id}/converse`, `/unified-ai/gemini/v1beta/models/{id}:generateContent`, `/unified-ai/claude/v1/messages` | `aws-bedrock`, `gemini`, `anthropic` | `frag-path-builder` (per api-type `<when>` block) |

Two design rules that protect surface isolation:

1. **Universal LLM API restricts pool selection to OpenAI-compat pool types.** Its policy sets `compatiblePoolTypes="azure-openai,ai-foundry,aws-bedrock-mantle,gemini-openai"` before `set-target-backend-pool` runs. If the same model id is registered against both a native pool (e.g. `aws-bedrock`) and an OpenAI-compat pool (e.g. `aws-bedrock-mantle`), the gateway will only consider the OpenAI-compat pool — the native one has no `/chat/completions` rewrite branch and would let an unrewritten path reach the provider, returning errors like `com.amazon.coral.service#UnknownOperationException` from AWS Bedrock.
2. **Each Unified AI api-type declares its own `compatible-pool-types`.** Native api-types like `bedrock` declare `compatible-pool-types: 'aws-bedrock'`; the OpenAI-compat `inference` api-type declares `compatible-pool-types: 'ai-foundry,azure-openai,aws-bedrock-mantle,gemini-openai'`. This keeps surfaces from cross-routing without relying on suffix tricks.

When you add a new provider, decide whether you need:

- **Native only** (e.g. provider has no OpenAI-compat surface): add a Unified AI api-type with its own prefix and `compatible-pool-types` matching its native pool type.
- **OpenAI-compat only** (e.g. provider exposes only `/v1/chat/completions`): add the backend with a pool type already in Universal LLM's compatible list (`aws-bedrock-mantle`, `gemini-openai`, etc.). Add a `<when>` rewrite branch in `frag-set-backend-authorization` for Universal LLM, and a path template in `config-backend-path-templates` for the Unified AI `inference` api-type.
- **Both**: define two backends (one per pool type) and update both the api-type entry and the OpenAI-compat artifacts.

## Updating `set-llm-requested-model` for new providers

The `set-llm-requested-model` fragment is invoked from **all three** LLM API policies (Universal LLM, Azure OpenAI, Unified AI request-processor falls back to it implicitly via shared logic) **and** from Citadel access-contract product policies (`default-ai-product-policy.xml`) so that `validate-model-access` can enforce `allowedModels` regardless of which surface the call lands on.

Existing patterns it recognizes (in order):

1. `deployment-id` named path parameter (Azure OpenAI named operations)
2. `/deployments/{model}/...` segment (Azure OpenAI wildcards, `/openai/deployments/...`)
3. `/model/{modelId}/...` singular segment (AWS Bedrock Converse / Invoke; URL-decoded)
4. `/models/{modelId}:method` plural segment with `:` terminator (Gemini native; URL-decoded)
5. Request body `model` field (OpenAI-compat, Anthropic Messages, Bedrock OpenAI-compat)

If your new provider exposes the model in a different URL position (anything other than the patterns above) **or** in a body field other than `model`, you must extend `frag-set-llm-requested-model.xml` (both copies under `bicep/infra/modules/apim/policies/` and `bicep/infra/llm-backend-onboarding/modules/policies/`). Otherwise the access contract will return 400 `missing_model_parameter` for every native call, even when the request is valid for the provider.

## Prerequisites

Before starting, ensure you have:

- A working deployment of AI Citadel Governance Hub with the Unified AI API
- Understanding of the target provider's API format (endpoint URLs, auth mechanism, request/response format)
- Access to deploy Bicep templates to your APIM instance

## Step-by-Step Guide

### Step 1: Define the API Type in Metadata Configuration

The `metadata-config` fragment is the central configuration that defines all supported API types. Each API type needs three properties:

| Property | Description |
|----------|-------------|
| `base-path` | The URL path prefix that identifies this API type in incoming requests |
| `path-segment` | The path segment used for model extraction from the URL |
| `api-version` | Default API version sent to the backend |

**File**: `bicep/infra/llm-backend-onboarding/modules/policies/frag-metadata-config.xml`
(also mirrored in `bicep/infra/modules/apim/policies/frag-metadata-config.xml`)

#### How It Works

The `request-processor` fragment iterates over all entries in `api-types` and matches the incoming request path against each `base-path`. The first match determines the API type.

#### Adding Your API Type

Add a new entry to the `api-types` object in the metadata config. The key is your API type identifier (used throughout all fragments).

**Example — Adding Amazon Bedrock (native Converse / InvokeModel):**

```json
'bedrock-native': {
    'base-path': '/bedrock',
    'path-segment': '/bedrock',
    'api-version': 'bedrock-2024-04-15',
    'compatible-pool-types': 'aws-bedrock'
}
```

The `compatible-pool-types` CSV restricts which backend pools the request can land on — here, only pools whose `poolType == 'aws-bedrock'`. This prevents the gateway from accidentally routing a `/unified-ai/bedrock/...` call to an `aws-bedrock-mantle` (OpenAI-compat) pool that happens to advertise the same model name. Native and OpenAI-compat surfaces stay isolated without requiring suffix tricks on model ids.

#### Important Considerations

1. **Prefix matching with longest-match wins**: The `request-processor` uses **case-insensitive `StartsWith`** matching against the request path (after stripping the `/unified-ai` API prefix) and selects the **longest matching `base-path`**. This means declaration order in `api-types` does **not** affect routing — `/openai/v1/responses` will always win over `/openai/v1` or `/openai` for a request like `/openai/v1/responses/{id}`. Unrecognized prefixes (e.g. `/v2/openai/...`) are rejected with `403 PathNotAllowed`.

2. **The `base-path` must be unique**: No two API types should declare the same `base-path` value.

3. **Optional `backend` property**: If your API type should always route to a specific backend (bypassing model-based pool routing), add a `backend` property:
   ```json
   'my-api-type': {
       'base-path': '/my-path',
       'path-segment': '/my-path',
       'api-version': '2024-01-01',
       'backend': 'my-specific-backend-id'
   }
   ```
   This sets `apiTypeOverrideBackend` in the request processor, which tells `set-target-backend-pool` to skip pool matching.

4. **Both copies must be updated**: The metadata config exists in two locations:
   - `bicep/infra/llm-backend-onboarding/modules/policies/frag-metadata-config.xml` — Used when deploying via the LLM backend onboarding module
   - `bicep/infra/modules/apim/policies/frag-metadata-config.xml` — Used when deploying the full Citadel infrastructure

### Step 2: Add Path Construction Logic

The `path-builder` fragment reconstructs the backend URI based on the detected API type. You need to add a `<when>` condition for your new API type.

**File**: `bicep/infra/modules/apim/policies/frag-path-builder.xml`

#### How It Works

The path builder uses a `<choose>` block to select path construction logic based on the `api-type` variable (set by request-processor). It sets the `finalPath` variable, which is then used to rewrite the request URI.

#### Available Variables

| Variable | Source | Description |
|----------|--------|-------------|
| `api-type` | request-processor | The detected API type identifier |
| `api-base-path` | request-processor | The base path from metadata config |
| `requestedModel` | request-processor | The extracted model name |
| `response-id` | request-processor | Response ID (for responses API) |
| `selected-api-version` | request-processor | API version for the request |

#### Adding Your Path Logic

Add a new `<when>` block inside the `<choose>` element, before the default `<otherwise>` block.

**Example — Amazon Bedrock path (strip the `/bedrock` prefix and forward the rest):**

```xml
<!-- Amazon Bedrock native: /bedrock/model/{model}/converse → /model/{model}/converse -->
<when condition="@(context.Variables.GetValueOrDefault<string>("api-type", "").Equals("bedrock-native", StringComparison.OrdinalIgnoreCase))">
    <set-variable name="finalPath" value="@{
        var basePath = context.Variables.GetValueOrDefault<string>("api-base-path", "");
        var rawPath  = context.Request.OriginalUrl.Path;
        var idx      = rawPath.IndexOf(basePath, StringComparison.OrdinalIgnoreCase);
        return idx >= 0 ? rawPath.Substring(idx + basePath.Length) : rawPath;
    }" />
</when>
```

#### Path Pattern Reference

| Pattern | When to Use | Example |
|---------|-------------|---------|
| `{base-path}/chat/completions` | OpenAI-compatible APIs | Gemini, Inference |
| `{base-path}/deployments/{model}/chat/completions` | Deployment-based APIs | Azure OpenAI |
| `{base-path}` or `{base-path}/{id}` | Resource-based APIs | Responses API |
| `/bedrock/model/{model}/converse` (prefix-strip) | Provider-specific native paths | Amazon Bedrock, Gemini native |
| Fixed path with body-model rewrite | Provider-specific paths whose API has no model in URL | Anthropic Claude (`/claude/v1/messages`) |

> **Stateful APIs (Responses API)** — When your new api-type exposes server-side stateful resources keyed by an id (similar to OpenAI's Responses API `response_id`), pair it with the cross-API `responses-id-security` / `responses-id-cache-store` fragments described in [llm-access-guide.md](llm-access-guide.md#step-15-responses-api-id-security-responses-id-security--responses-id-cache-store). Those fragments are wired in once per API policy and cover Universal LLM, Azure OpenAI, and Unified AI surfaces, returning **403** on cross-subscription or cross-product access and **404** on unknown ids. Ownership mappings last 30 days, matching the default OpenAI Responses API retention period.

#### Additional Behaviors

Your path builder block can also:
- **Set query parameters**: Use `<set-query-parameter>` to inject API version or other params
- **Modify the request body**: Use `<set-body>` to add/transform fields (e.g., inject `model` field)
- **URL-encode model IDs**: Use `System.Uri.EscapeDataString()` for models with special characters (e.g., Bedrock's `us.anthropic.claude-3-5-haiku-20241022-v1:0`)

### Step 3: Add Backend Authentication

The `set-backend-authorization` fragment configures how APIM authenticates to each backend type. If your new API type uses a different authentication mechanism than the existing ones, you need to add a new `<when>` block.

**Files** (both must be updated):
- `bicep/infra/llm-backend-onboarding/modules/policies/frag-set-backend-authorization.xml`
- `bicep/infra/modules/apim/policies/frag-set-backend-authorization.xml`

#### Existing Auth Patterns

| Backend Type | Auth Mechanism | Implementation |
|--------------|----------------|----------------|
| `ai-foundry` | Azure Managed Identity | `<authentication-managed-identity>` with Cognitive Services scope |
| `azure-openai` | Azure Managed Identity | Same as ai-foundry + URL rewriting |
| `external` | Backend credentials | No auth header (credentials configured on backend resource) |
| `aws-bedrock` | AWS SigV4 | Custom policy computing HMAC-SHA256 signature |

#### Adding Your Auth Logic

Add a new `<when>` block that matches on `targetPoolType` (which comes from the `backendType` in your backend configuration).

**Example — AWS SigV4 for Amazon Bedrock:**

The AWS Signature Version 4 authentication requires:
1. Computing a SHA-256 hash of the request body
2. Constructing a canonical request string
3. Deriving a signing key from the secret key + date + region + service
4. Computing an HMAC-SHA256 signature
5. Setting the `Authorization`, `X-Amz-Date`, `X-Amz-Content-Sha256`, and `Host` headers

The full implementation uses APIM named values for credentials:
- `aws-access-key`: AWS IAM access key ID
- `aws-secret-key`: AWS IAM secret access key
- `aws-region`: AWS region (e.g., `us-east-1`)

See the [Microsoft Learn guide on Amazon Bedrock APIM integration](https://learn.microsoft.com/en-us/azure/api-management/amazon-bedrock-passthrough-llm-api) for the complete SigV4 policy implementation.

#### Named Values for Credentials

If your auth mechanism requires secrets (API keys, tokens), store them as APIM named values:

1. **Add parameters** to `llm-policy-fragments.bicep` for the credentials
2. **Create named value resources** conditionally (only when backends of your type exist)
3. **Reference in policy** using `{{named-value-name}}` syntax

**Example — Adding AWS named values in Bicep:**

```bicep
// In llm-policy-fragments.bicep

// Parameters
@secure()
param awsAccessKey string = ''
@secure()
param awsSecretKey string = ''
param awsRegion string = ''

// Check if any backend uses this type
var hasBedrockBackend = length(filter(llmBackendConfig, config => config.backendType == 'aws-bedrock')) > 0

// Always create named values (with safe defaults) so the policy fragment compiles
// even when no backends of this type are configured.
resource awsAccessKeyNamedValue 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  name: 'aws-access-key'
  parent: apimService
  properties: {
    displayName: 'aws-access-key'
    value: !empty(awsAccessKey) ? awsAccessKey : 'NOT_CONFIGURED'
    secret: true
  }
}
```

> **Important**: APIM resolves `{{named-value}}` references at policy save/compile time, not at runtime. If a named value doesn't exist in APIM, the policy fragment deployment will fail. Always create the named values — even with placeholder defaults — and add a runtime guard in the policy to return a clear error when the placeholder is detected. For example:
> ```xml
> <choose>
>     <when condition="@("{{aws-access-key}}" == "NOT_CONFIGURED")">
>         <return-response>
>             <set-status code="500" reason="Internal Server Error" />
>             <set-body>{"error": {"code": "AWSCredentialsNotConfigured", ...}}</set-body>
>         </return-response>
>     </when>
> </choose>
> ```

### Step 4: Configure the Backend in LLM Onboarding

Add your backend to the `llmBackendConfig` array in your `.bicepparam` file with a new `backendType` value.

**File**: Your deployment parameter file (e.g., `llm-backends-dev-local.bicepparam`)

#### Backend Configuration Properties

| Property | Value for Your API Type |
|----------|------------------------|
| `backendId` | Unique identifier (e.g., `bedrock-us-east-1`) |
| `backendType` | Your new type identifier (e.g., `aws-bedrock`) — must match the `targetPoolType` in auth fragment |
| `endpoint` | Base URL of the provider (e.g., `https://bedrock-runtime.us-east-1.amazonaws.com`) |
| `authType` | Authentication type (e.g., `aws-sigv4`, `managed-identity`, `api-key-bearer`). The legacy `authScheme` is still tolerated but superseded by `authType`. |
| `supportedModels` | Array of model definitions with metadata |

> **Stateful models:** add `sessionAwareModel: true` to any model object that must keep a client pinned to one backend across a session (e.g., the OpenAI Responses / Assistants APIs). When that model is served by a multi-backend pool, the pool gets session affinity so requests replaying the affinity cookie stick to the same backend. A single backend can mix session-aware and stateless models. Tune the cookie with `configureSessionAffinity` / `sessionAffinityDefaults` (default cookie `ai-gateway-affinity`) or a per-backend `sessionAffinity` override. See [LLM Backend Onboarding — Session Affinity Configuration](../bicep/infra/llm-backend-onboarding/README.md#session-affinity-configuration).

**Example — Amazon Bedrock backend:**

```bicep
param llmBackendConfig = [
  {
    backendId: 'bedrock-us-east-1'
    backendType: 'aws-bedrock'
    endpoint: 'https://bedrock-runtime.us-east-1.amazonaws.com'
    authType: 'aws-sigv4'
    supportedModels: [
      {
        "name": "us.anthropic.claude-3-5-haiku-20241022-v1:0"
        "sku": "OnDemand"
        "capacity": 1
        "modelFormat": "Anthropic"
        "modelVersion": "1"
        "retirementDate": "2099-12-30"
      }
      {
        "name": "us.anthropic.claude-3-5-sonnet-20241022-v2:0"
        "sku": "OnDemand"
        "capacity": 1
        "modelFormat": "Anthropic"
        "modelVersion": "2"
        "retirementDate": "2099-12-30"
      }
    ]
    priority: 1
    weight: 100
  }
]

// AWS credentials (required for aws-bedrock backends)
param awsAccessKey = '<your-aws-access-key-id>'
param awsSecretKey = '<your-aws-secret-access-key>'
param awsRegion = 'us-east-1'
```

#### Pass-Through Parameters

Ensure the new parameters flow through the module chain:

1. **`main.bicep`** — Add parameters and pass to `llmPolicyFragments` module
2. **`modules/llm-policy-fragments.bicep`** — Accept parameters and create named values
3. **`modules/llm-backends.bicep`** — No changes needed (backend creation is generic)
4. **`modules/llm-backend-pools.bicep`** — No changes needed (pool creation is generic)

### Step 5: Deploy and Test

#### Deploy

```bash
az deployment sub create \
  --name llm-backend-onboarding \
  --location <location> \
  --template-file main.bicep \
  --parameters llm-backends-dev-local.bicepparam
```

#### Verify Configuration

1. **Check APIM backends**: Verify the new backend resource was created in the Azure Portal under API Management → Backends
2. **Check named values**: Verify credential named values were created (e.g., `aws-access-key`, `aws-secret-key`, `aws-region`)
3. **Check policy fragments**: Verify `metadata-config` fragment includes your new API type and model mappings

#### Test the Endpoint

Send a request through the Unified AI API using your new API type's path pattern:

```bash
curl -X POST "https://<apim-gateway>/unified-ai/bedrock/model/us.anthropic.claude-3-5-haiku-20241022-v1:0/converse" \
  -H "Content-Type: application/json" \
  -H "api-key: <subscription-key>" \
  -d '{
    "messages": [
      {
        "role": "user",
        "content": [{"text": "Hello"}]
      }
    ],
    "inferenceConfig": {
      "maxTokens": 512,
      "temperature": 0.5
    }
  }'
```

#### Debug with Response Headers

Enable debug headers in your product policy to trace routing decisions:

```xml
<set-variable name="enableResponseHeaders" value="true" />
```

Then check the response headers:

| Header | Expected Value |
|--------|---------------|
| `UAIG-API-Type` | `bedrock-native` |
| `UAIG-Model-Id` | `us.anthropic.claude-3-5-haiku-20241022-v1:0` |
| `UAIG-Backend` | `bedrock-us-east-1` |
| `UAIG-Final-Path` | `/model/us.anthropic.claude-3-5-haiku-20241022-v1%3A0/converse` |

## Summary of Files to Modify

| File | Change | Required |
|------|--------|----------|
| `llm-backend-onboarding/modules/policies/frag-metadata-config.xml` | Add API type definition | Yes |
| `modules/apim/policies/frag-metadata-config.xml` | Add API type definition (mirror) | Yes |
| `modules/apim/policies/frag-path-builder.xml` | Add path construction logic | Yes |
| `llm-backend-onboarding/modules/policies/frag-set-llm-requested-model.xml` | Add new URL/body model-extraction pattern | If provider's model location is not covered by existing patterns |
| `modules/apim/policies/frag-set-llm-requested-model.xml` | Add new URL/body model-extraction pattern (mirror) | If provider's model location is not covered by existing patterns |
| `llm-backend-onboarding/modules/policies/frag-set-backend-authorization.xml` | Add auth logic for new backend type | If new auth needed |
| `modules/apim/policies/frag-set-backend-authorization.xml` | Add auth logic (mirror) | If new auth needed |
| `llm-backend-onboarding/modules/llm-policy-fragments.bicep` | Add credential parameters and named values | If new credentials needed |
| `llm-backend-onboarding/main.bicep` | Pass through new parameters | If new credentials needed |
| Your `.bicepparam` file | Add backend configuration | Yes |

## Checklist

- [ ] API type added to `frag-metadata-config.xml` (both copies)
- [ ] `base-path` is unique and doesn't conflict with existing API types
- [ ] `compatible-pool-types` set on the api-type to isolate native vs OpenAI-compat surfaces
- [ ] Path builder logic added to `frag-path-builder.xml` (or `config-backend-path-templates` entry for OpenAI-compat under `inference`)
- [ ] `set-llm-requested-model` extended (both copies) if provider's model location is not already covered
- [ ] Backend auth logic added to `frag-set-backend-authorization.xml` (both copies, if new auth type)
- [ ] Named values created for credentials (if applicable)
- [ ] Parameters passed through `main.bicep` → `llm-policy-fragments.bicep`
- [ ] Backend configured in `.bicepparam` with correct `backendType`
- [ ] Models listed in `supportedModels` with appropriate metadata
- [ ] Deployment tested with debug headers enabled
- [ ] Documentation updated (routing architecture guide, backend onboarding README)

## Example: Complete Bedrock Onboarding

For a complete working example of onboarding Amazon Bedrock as a new API type, see:

- **Backend Configuration**: [LLM Backend Onboarding README](../bicep/infra/llm-backend-onboarding/README.md#amazon-bedrock-backend) — Amazon Bedrock backend example
- **Routing Architecture**: [LLM Access Guide](llm-access-guide.md) — Bedrock request flow and path construction
- **APIM Integration**: [Microsoft Learn: Amazon Bedrock APIM Integration](https://learn.microsoft.com/en-us/azure/api-management/amazon-bedrock-passthrough-llm-api) — AWS SigV4 authentication policy details

## Related Guides

- [LLM Access Guide](llm-access-guide.md) - Complete routing flow documentation
- [LLM Backend Onboarding](../bicep/infra/llm-backend-onboarding/README.md) - Backend configuration reference
- [Parameters Usage Guide](parameters-usage-guide.md) - Parameter file configuration
