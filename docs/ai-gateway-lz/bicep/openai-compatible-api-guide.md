# OpenAI-Compatible API Guide

## Overview

The Unified AI API includes an **OpenAI-compatible path** (`/unified-ai/v1/*`) that allows clients to use standard OpenAI SDKs and tools without modification. Requests are transparently routed to the correct backend (Azure AI Foundry, Azure OpenAI, AWS Bedrock Mantle, Google Gemini, etc.) based on the model specified in the request.

This path supports the standard OpenAI operations:
- `POST /v1/chat/completions` — Chat completions
- `POST /v1/embeddings` — Text embeddings
- `POST /v1/responses` — Responses API
- `POST /v1/images/generations` — Image generation
- `GET /v1/models` — List available models

> **Responses API security**: The gateway enforces per-subscription and per-product ownership of `response_id` values. A `GET`/`DELETE` on `/v1/responses/{id}` (or a chained `POST` carrying `previous_response_id`) issued by a *different* subscription or product than the one that originally created the response is rejected with **HTTP 403** (`response_id_forbidden`). Productless subscriptions use `NA` as their product identity. Ownership mappings last **30 days**, matching the default OpenAI Responses API retention period; unknown or expired ids return **HTTP 404** (`response_id_not_found`). See [llm-access-guide.md](llm-access-guide.md#step-15-responses-api-id-security-responses-id-security--responses-id-cache-store) for the cache contract and routing details.

## Getting Started

### Using the OpenAI Python SDK

```python
from openai import OpenAI

client = OpenAI(
    api_key="<apim-subscription-key>",
    base_url="https://<apim-gateway>/unified-ai/v1",
)

response = client.chat.completions.create(
    model="gpt-4o",  # Any model configured in the gateway
    messages=[{"role": "user", "content": "Hello!"}],
)
print(response.choices[0].message.content)
```

### Using curl

```bash
curl -X POST "https://<apim-gateway>/unified-ai/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "api-key: <subscription-key>" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## How It Works

The `openai-compat` API type uses **backend-path-templates** to dynamically construct the correct backend URL based on the backend type. This means the same client request (`/v1/chat/completions`) can route to completely different backend paths depending on where the model is hosted:

| Backend Type | Client Path | Backend Path |
|---|---|---|
| `ai-foundry` | `/v1/chat/completions` | `/openai/v1/chat/completions` (model in body) |
| `azure-openai` | `/v1/chat/completions` | `/openai/v1/chat/completions` (model in body) |
| `aws-bedrock-mantle` | `/v1/chat/completions` | `/v1/chat/completions` |
| `gemini-openai` | `/v1/chat/completions` | `/v1beta/openai/chat/completions` |
| `aws-bedrock` | `/v1/chat/completions` | `/model/{model}/converse` |

## Model Aliases

Model aliases let you group multiple models under a single client-facing name. This enables:
- **Model upgrades**: Change the underlying model without client changes
- **Cross-model fallback**: Automatically retry with a different model on failure
- **A/B testing**: Distribute traffic across models with weighted routing

### Configuration

Model aliases are defined in the `modelAliases` parameter during deployment:

```bicep
param modelAliases = [
  {
    name: 'gpt-advanced'
    models: ['gpt-5', 'gpt-4.1', 'gpt-4o']
    strategy: 'priority'  // Use models in order; first available wins
  }
  {
    name: 'embeddings-balanced'
    models: ['text-embedding-3-large', 'text-embedding-ada-002']
    strategy: 'weighted'
    weights: [80, 20]  // 80% traffic to first, 20% to second
  }
]
```

### Using Aliases

Clients use the alias name as the model:

```python
response = client.chat.completions.create(
    model="gpt-advanced",  # Alias name — resolves to actual model
    messages=[{"role": "user", "content": "Hello!"}],
)
```

### Strategies

| Strategy | Behavior |
|---|---|
| `priority` | Uses models in order. First model in the list is tried first. If it fails (429/5xx), falls back to the next model in the list. |
| `weighted` | Distributes traffic across models based on weights. Useful for A/B testing or gradual model migration. |

### Cross-Model Fallback

When using aliases, the gateway automatically implements cross-model fallback:
1. Request is sent to the primary model (first in list for `priority`, or selected by weight)
2. If the backend returns 429 (throttled) or 5xx (server error), the gateway retries with the next model in the alias
3. Each model in the alias may route to a different backend with different authentication

> **Note**: Cross-model fallback only works for non-streaming requests or pre-stream errors. Once streaming has started, the response is committed and fallback is not possible.

## Debug Headers

When `enableResponseHeaders` is set to `true` in the product policy, the following headers are included in responses:

| Header | Description |
|---|---|
| `UAIG-API-Type` | `openai-compat` for requests through `/v1/*` |
| `UAIG-Model-Id` | The resolved model name (after alias resolution) |
| `UAIG-Alias` | The original alias name (only when an alias was used) |
| `UAIG-Resolved-Model` | The actual model after alias resolution |
| `UAIG-Backend` | The backend that served the request |
| `UAIG-Final-Path` | The constructed backend path |
| `UAIG-Auth-Type-Backend` | The authentication type used for the backend |

## Authentication Types

The gateway supports multiple authentication types per backend, independent of the backend type:

| Auth Type | Mechanism | Use Case |
|---|---|---|
| `managed-identity` | APIM Managed Identity → Cognitive Services token | Azure AI Foundry, Azure OpenAI |
| `aws-sigv4` | AWS Signature V4 | Amazon Bedrock (Converse API) |
| `api-key-bearer` | `Authorization: Bearer {key}` | Bedrock Mantle, Gemini, external providers |
| `api-key-header` | `api-key: {value}` header | Alternative API key injection |
| `none` | No auth headers | Backend credentials on APIM backend resource |

Two backends of the same type can use different auth types. For example, you can have one AI Foundry backend using managed identity and another using an API key.

## Related Guides

- [LLM Access Guide](llm-access-guide.md) — Unified LLM access patterns and complete routing flow documentation
- [Onboarding New API Types](unified-ai-api-type-onboarding.md) — Adding new backend types
- [LLM Backend Onboarding](../bicep/infra/llm-backend-onboarding/README.md) — Backend configuration reference
