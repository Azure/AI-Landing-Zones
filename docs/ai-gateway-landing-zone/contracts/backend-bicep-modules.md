---
render_macros: false
---

# LLM Backend Modules

This directory contains Bicep modules for dynamic LLM backend configuration in Azure API Management (APIM).

## Modules Overview

### 1. llm-backends.bicep
**Purpose**: Creates individual APIM backend resources for each LLM endpoint.

**Inputs**:

- `llmBackendConfig`: Array of backend configurations
- `managedIdentityClientId`: Client ID for authentication
- `configureCircuitBreaker`: Enable/disable circuit breaker

**Outputs**:

- `backendIds`: Array of created backend IDs
- `backendDetails`: Detailed backend information for pool creation

**Features**:

- Supports Azure OpenAI, AI Foundry, and external LLM providers
- Configures circuit breakers for resilience
- Sets up managed identity authentication
- Configures TLS validation

### 2. llm-backend-pools.bicep
**Purpose**: Creates backend pools for load balancing and failover.

**Logic**:

- Analyzes `backendDetails` to find models supported by multiple backends
- Creates pools only for multi-backend models
- Single-backend models route directly (no pool needed)

**Outputs**:

- `poolNames`: Array of created pool names
- `modelToPoolMap`: Maps model names to pool names
- `modelToBackendMap`: Maps single-backend models to backend IDs
- `policyFragmentConfig`: Configuration for policy generation

**Example**:
```
Backends: [A supports gpt-4, B supports gpt-4, C supports phi-4]
Result:
  - Creates "gpt-4-backend-pool" with backends A and B
  - No pool for phi-4 (only supported by C)
```

### 3. llm-policy-fragments.bicep
**Purpose**: Generates APIM policy fragments with dynamic backend configurations.

**Generated Fragments**:

1. **set-backend-pools**: Contains C# code defining all available backend pools
2. **set-backend-authorization**: Configures authentication based on backend type

**Features**:

- Injects backend pool definitions into policy fragment
- Supports multiple authentication schemes
- Handles URL rewriting for Azure OpenAI
- Works with AI Foundry OpenAI-compatible endpoints

### 4. inference-api.bicep
**Purpose**: Creates the Universal LLM API that uses the dynamic backends.

**Integration**:

- Consumes policy fragments from llm-policy-fragments
- Uses backends and pools from llm-backends and llm-backend-pools
- Provides unified OpenAI-compatible endpoint

## Usage

### Basic Example

```bicep
// 1. Create backends
module llmBackends './llm-backends.bicep' = {
  name: 'llm-backends'
  params: {
    apimServiceName: apimService.name
    managedIdentityClientId: managedIdentity.properties.clientId
    llmBackendConfig: [
      {
        backendId: 'ai-foundry-gpt4'
        backendType: 'ai-foundry'
        endpoint: 'https://my-project.eastus.inference.ml.azure.com'
        authType: 'managed-identity'
        supportedModels: ['gpt-4', 'gpt-4-turbo']
      }
    ]
  }
}

// 2. Create backend pools
module llmBackendPools './llm-backend-pools.bicep' = {
  name: 'llm-backend-pools'
  params: {
    apimServiceName: apimService.name
    backendDetails: llmBackends.outputs.backendDetails
  }
}

// 3. Generate policy fragments
module llmPolicyFragments './llm-policy-fragments.bicep' = {
  name: 'llm-policy-fragments'
  params: {
    apimServiceName: apimService.name
    policyFragmentConfig: llmBackendPools.outputs.policyFragmentConfig
    managedIdentityClientId: managedIdentity.properties.clientId
  }
}

// 4. Create API
module universalLlmApi './inference-api.bicep' = {
  name: 'universal-llm-api'
  params: {
    apiManagementName: apimService.name
    inferenceAPIName: 'universal-llm-api'
    inferenceAPIPath: 'llm'
    policyXml: loadTextContent('./policies/universal-llm-api-policy-v2.xml')
  }
  dependsOn: [
    llmBackends
    llmBackendPools
    llmPolicyFragments
  ]
}
```

## Backend Configuration Schema

```typescript
interface BackendConfig {
  backendId: string;           // Unique identifier
  backendType: 'ai-foundry' | 'azure-openai' | 'aws-bedrock' | 'aws-bedrock-mantle' | 'gemini' | 'gemini-openai' | 'anthropic' | 'external';
  endpoint: string;            // Base URL (e.g., https://xxx.inference.ml.azure.com)
  authType?: 'managed-identity' | 'aws-sigv4' | 'api-key-bearer' | 'api-key-header' | 'api-key-gemini' | 'api-key-anthropic' | 'none'; // omit to derive from backendType
  authConfig?: { namedValueKey: string; keyVaultSecretUri?: string; secretValue?: string }; // for api-key-* auth types
  authScheme?: 'managedIdentity' | 'apiKey' | 'token';  // LEGACY — superseded by authType
  supportedModels: string[];   // Model names (e.g., ['gpt-4', 'gpt-4-turbo'])
  priority?: number;           // 1-5, default 1 (lower = higher priority)
  weight?: number;             // 1-1000, default 100 (higher = more traffic)
}
```

## Request Flow

```
1. Client Request → APIM Gateway
   POST /llm/openai/chat/completions
   Body: { "model": "gpt-4", "messages": [...] }

2. Policy: Extract Model
   → requestedModel = "gpt-4"

3. Policy Fragment: set-backend-pools
   → Loads available backend pools
   → backendPools = [{ poolName: "gpt-4-backend-pool", supportedModels: ["gpt-4"] }]

4. Policy Fragment: set-target-backend-pool
   → Matches "gpt-4" to "gpt-4-backend-pool"
   → targetBackendPool = "gpt-4-backend-pool"

5. Policy Fragment: set-backend-authorization
   → Gets authentication for backend type
   → Sets Authorization header with managed identity token
   → Rewrites URL if needed (Azure OpenAI)

6. Backend Pool Routing
   → Selects backend based on priority and weight
   → Routes to healthy backend

7. Response → Client
```

## Load Balancing Behavior

### Priority-Based Routing
- Backends with **lower priority** are preferred
- Priority range: 1-5 (1 = highest priority)

### Weight-Based Distribution
- Within the same priority, traffic is distributed by weight
- Weight range: 1-1000
- Higher weight = more traffic

### Example:
```json
[
  { "backendId": "primary", "priority": 1, "weight": 100 },
  { "backendId": "secondary", "priority": 1, "weight": 50 },
  { "backendId": "tertiary", "priority": 2, "weight": 100 }
]
```

Behavior:

- Primary receives ~67% of traffic (100 / 150)
- Secondary receives ~33% of traffic (50 / 150)
- Tertiary only receives traffic if both primary and secondary fail

## Authentication Types

### Managed Identity (Recommended)
```json
{
  "authType": "managed-identity"
}
```

APIM uses its user-assigned managed identity to authenticate:

- Azure OpenAI: `Cognitive Services OpenAI User` role
- AI Foundry: `Cognitive Services User` role

### API Key
```json
{
  "authType": "api-key-bearer",
  "authConfig": { "namedValueKey": "my-provider-key", "keyVaultSecretUri": "https://kv.vault.azure.net/secrets/my-provider-key" }
}
```

The API key is configured natively on the APIM backend resource via `credentials.header`, resolved from the named value (or Key Vault reference) at deploy time.

> **Legacy:** the older `authScheme` field (`managedIdentity` | `apiKey` | `token`) is still tolerated for backward compatibility but is superseded by `authType`. New configurations should use `authType`.

## Backend Types

### ai-foundry
- Azure AI Foundry inference endpoints
- OpenAI-compatible API paths
- Managed identity authentication
- No URL rewriting needed

### azure-openai
- Azure OpenAI Service endpoints
- Requires URL rewriting to add `/deployments/{model}/` path
- Managed identity authentication
- Model name must match deployment name

### external
- External LLM providers (OpenAI, Anthropic, etc.)
- Custom authentication via backend credentials
- No URL rewriting

## Circuit Breaker Configuration

Protects backends from cascading failures:

```bicep
circuitBreaker: {
  rules: [
    {
      failureCondition: {
        count: 3                    // Fail after 3 errors
        interval: 'PT5M'            // Within 5 minutes
        statusCodeRanges: [
          { min: 429, max: 429 }    // Rate limiting
          { min: 500, max: 503 }    // Server errors
        ]
      }
      tripDuration: 'PT1M'          // Circuit open for 1 minute
      acceptRetryAfter: true        // Respect Retry-After header
    }
  ]
}
```

## Error Handling

### Model Not Found
Returns `400 Bad Request` if model is not mapped to any backend:
```json
{
  "error": {
    "message": "Model 'unknown-model' is not supported",
    "type": "invalid_request_error",
    "code": "model_not_supported"
  }
}
```

### No Allowed Backend Pool
Returns `403 Forbidden` if RBAC prevents access:
```json
{
  "error": {
    "message": "Access denied to backend pool for model 'gpt-4'",
    "type": "insufficient_permissions",
    "code": "forbidden_backend_pool"
  }
}
```

## Testing

### Verify Backend Creation
```bash
az apim backend list \
  --resource-group <rg> \
  --service-name <apim> \
  --query "[].{name:name, url:properties.url}"
```

### Verify Backend Pool
```bash
az apim backend show \
  --resource-group <rg> \
  --service-name <apim> \
  --backend-id gpt-4-backend-pool \
  --query "{name:name, type:properties.type, services:properties.pool.services}"
```

### Test Request
```bash
curl -X POST "https://<apim>.azure-api.net/llm/openai/chat/completions" \
  -H "Content-Type: application/json" \
  -H "api-key: <subscription-key>" \
  -d '{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Troubleshooting

### Backend Not Routing
1. Check backend exists: `az apim backend show ...`
2. Verify policy fragment: `az apim policy-fragment show ...`
3. Check API policy includes fragment: `az apim api policy show ...`

### Authentication Failing
1. Verify managed identity has required roles
2. Check `uami-client-id` named value is set
3. Ensure backend endpoint is correct

### Pool Not Created
Pools are only created for models supported by **multiple backends**. If only one backend supports a model, requests route directly to that backend (no pool needed).

## Best Practices

1. **Naming Convention**: Use descriptive backend IDs (provider-region-model)
2. **Priority Strategy**: Reserve priority 1 for production backends
3. **Weight Distribution**: Start with equal weights, adjust based on capacity
4. **Circuit Breakers**: Always enable for production deployments
5. **Monitoring**: Track backend health in APIM analytics
6. **Documentation**: Keep model-to-backend mapping documented

## See Also

- [Dynamic LLM Backend Configuration Guide](backend-contracts-bicep.md)
- [APIM Backend Pools Documentation](https://learn.microsoft.com/azure/api-management/backends)
- [AI Foundry Inference](https://learn.microsoft.com/azure/ai-foundry/how-to/inference)
