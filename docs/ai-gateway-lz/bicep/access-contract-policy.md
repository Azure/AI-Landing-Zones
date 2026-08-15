# AI Citadel Access Contracts Policy

This guide to expand on what policies are available out of the box for use with the AI Citadel Access Contracts Bicep package, and how to customize them for each use case being onboarded.

## Available Policies Snippets

The following policy snippets can be applied as needed for the product policy access as part of the `Citadel Access Contracts`:

### Asset-Type-Aware Policies (LLM + Tools + Agents in one product)

An access contract can grant a **single product** access to a mix of asset types — LLM inference APIs, published **Tools (MCP)**, and published **Agents (A2A)**. Because APIM does not expose the API *type* to policy at runtime, the product policy classifies each request with the **`set-asset-kind`** fragment and branches with a `<choose>`.

**Product prefix** follows the asset mix: `LLM` / `TOOL` / `AGENT` for a single type, or **`MULTI`** for two or more (e.g. `MULTI-HR-ChatAgent-DEV`). `TOOL` / `AGENT` / `MULTI` products default to [`policies/default-multi-product-policy.xml`](./policies/default-multi-product-policy.xml).

**Classification** — list the granted API **resource names** per type before including the fragment; anything unlisted defaults to `llm` (so LLM-only contracts are unaffected):

```xml
<inbound>
    <base />
    <!-- COMMON POLICIES (any asset type) go here, e.g. opt-in content safety -->

    <!-- Classify the request as llm | tool | agent -->
    <set-variable name="contractToolApis" value="weather-tool,ms-learn-tool" />
    <set-variable name="contractAgentApis" value="hr-chat-agent" />
    <include-fragment fragment-id="set-asset-kind" />

    <choose>
        <!-- LLM: model RBAC + token capacity (existing behavior) -->
        <when condition="@(context.Variables.GetValueOrDefault<string>("assetKind","llm") == "llm")">
            <include-fragment fragment-id="set-llm-requested-model" />
            <set-variable name="allowedModels" value="gpt-4o,gpt-4.1" />
            <include-fragment fragment-id="validate-model-access" />
            <llm-token-limit counter-key="@(context.Subscription.Id)" tokens-per-minute="10000" estimate-prompt-tokens="false" token-quota="1000000" token-quota-period="Monthly" />
        </when>
        <!-- TOOL (MCP): request-based rate limit + call quota -->
        <when condition="@(context.Variables.GetValueOrDefault<string>("assetKind","") == "tool")">
            <rate-limit-by-key calls="60" renewal-period="60" counter-key="@(context.Subscription.Id + ":tool")" />
            <quota-by-key calls="100000" renewal-period="2592000" counter-key="@(context.Subscription.Id + ":tool")" />
        </when>
        <!-- AGENT (A2A): request-based rate limit + call quota -->
        <when condition="@(context.Variables.GetValueOrDefault<string>("assetKind","") == "agent")">
            <rate-limit-by-key calls="30" renewal-period="60" counter-key="@(context.Subscription.Id + ":agent")" />
            <quota-by-key calls="50000" renewal-period="2592000" counter-key="@(context.Subscription.Id + ":agent")" />
        </when>
    </choose>
</inbound>
```

**Why request-based limits for Tools/Agents?** `llm-token-limit` counts LLM tokens, which don't exist for a tool call or an agent turn. Tools and Agents are throttled by **request count** instead: `rate-limit-by-key` (calls per period) + `quota-by-key` (long-term call quota). The `calls` / `renewal-period` values are baked per contract (like `llm-token-limit`'s TPM/quota).

**Common policies** — anything that should run for *every* asset type (e.g. opt-in [content safety](#content-safety-policy), custom alerting) goes **before** the `set-asset-kind` classification so it applies regardless of `assetKind`.

**Usage metrics** are emitted by the API-level baseline policies (`llm-usage` for LLM, `mcp-usage` / `a2a-usage` for published Tools/Agents), so the product policy focuses on access control and throttling only.

> ✅ **Backward compatible** — existing `LLM-` contracts keep the LLM product policy and never include `set-asset-kind`.

### Model Access Control Policy

The model access control policy restricts which LLM models a product can access. This is implemented using the `validate-model-access` policy fragment.

**Basic Usage:**

```xml
<inbound>
    <!-- Extract and validate model parameter from request -->
    <include-fragment fragment-id="set-llm-requested-model" />

    <!-- Setting allowed models variable (comma-separated list) -->
    <set-variable name="allowedModels" value="gpt-4o,deepseek-r1" />
    
    <!-- Validate model access based on allowedModels -->
    <include-fragment fragment-id="validate-model-access" />
</inbound>
```

**How It Works:**

1. The `set-llm-requested-model` fragment extracts the model from the request:
   - From request body `{"model": "gpt-4o", ...}` for Universal LLM API
   - From URL path `/deployments/{deployment-id}/...` for Azure OpenAI API
   - Returns `"non-llm-request"` for GET operations (like listing available models)

2. The `validate-model-access` fragment validates the requested model:
   - **Non-LLM requests** (GET operations): Usually reference meta data endpoints that discover allowed models
   - **Empty `allowedModels`**: All models are allowed
   - **Model not in list**: Returns 401 Unauthorized with structured JSON error

**Error Response Format:**

When access is denied, the policy returns a structured JSON error:

```json
{
    "error": {
        "message": "Access to model 'gpt-4' is not allowed for this product.",
        "type": "access_error",
        "code": "unauthorized_model_access",
        "allowed_models": "gpt-4o,deepseek-r1"
    }
}
```

**Configuration Options:**

| Variable | Description | Example |
|----------|-------------|---------|
| `allowedModels` | Comma-separated list of allowed model names (no white-space) | `"gpt-4o,deepseek-r1,Phi-4"` |

>**NOTE:** Non-LLM requests (such as GET operations for listing available models) are automatically allowed and do not require model validation. This ensures auxiliary endpoints function without needing a model parameter.

### Model Capacity Management Policy

The below policy snippet, enforces a token limit per subscription but for all models being access via this product.

```xml
<inbound>
    <!-- Capacity management - Subscription Level: allow only assigned tpm for each HR use case subscription -->
    <llm-token-limit counter-key="@(context.Subscription.Id)" 
        tokens-per-minute="300" 
        estimate-prompt-tokens="false" 
        tokens-consumed-header-name="consumed-tokens" 
        remaining-tokens-header-name="remaining-tokens" 
        token-quota="100000" 
        token-quota-period="Monthly" 
        retry-after-header-name="retry-after" />
</inbound>
```

To further control capacity management per model per subscription, you can extend the above policy snippet to include model specific token limits by leveraging the `requestedModel` variable set via the `set-llm-requested-model` fragment.

```xml
<!-- Inboud Section of the Product Policy -->
<!-- Extract and validate model parameter from request and save it to requestedModel -->
<include-fragment fragment-id="set-llm-requested-model" />

<!-- Capacity management - Subscription + Model Level: allow only assigned tpm for each model per subscription -->
<choose>
    <when condition="@((string)context.Variables["requestedModel"] == "gpt-4o")">
        <llm-token-limit 
            counter-key="@(context.Subscription.Id + "-" + context.Variables["requestedModel"])" 
            tokens-per-minute="10000" 
            estimate-prompt-tokens="false" 
            tokens-consumed-header-name="consumed-tokens" 
            remaining-tokens-header-name="remaining-tokens" 
            token-quota="100000"
            token-quota-period="Monthly"
            retry-after-header-name="retry-after" />
    </when>
    <when condition="@((string)context.Variables["requestedModel"] == "DeepSeek-R1")">
        <llm-token-limit 
            counter-key="@(context.Subscription.Id + "-" + context.Variables["requestedModel"])" 
            tokens-per-minute="2000" 
            estimate-prompt-tokens="false" 
            tokens-consumed-header-name="consumed-tokens" 
            remaining-tokens-header-name="remaining-tokens" 
            token-quota="10000"
            token-quota-period="Weekly"
            retry-after-header-name="retry-after" />
    </when>
    <otherwise>
        <!-- Default model token limit for other models -->
        <llm-token-limit 
            counter-key="@(context.Subscription.Id + "-default")" 
            tokens-per-minute="1000" 
            estimate-prompt-tokens="false" 
            tokens-consumed-header-name="consumed-tokens" 
            remaining-tokens-header-name="remaining-tokens" 
            token-quota="5000"
            token-quota-period="Monthly"
            retry-after-header-name="retry-after" />
    </otherwise>
</choose>
```

### LLM Usage Customization Policy

By default, AI Citadel Gateway is configured to collect the following data points for LLM usage tracking:
- Standard Dimensions (currently can't be modified):
  - Region
  - Service ID
  - Service Name
  - Service Type
- Citadel Added Dimensions:
    - Product Name
    - DeploymentName (based on requestedModel variable)
    - Backend ID
    - appId (looks for variable named appId, fall back to subscription ID and then to "Portal-Admin" if not found)
- Custom dimensions:
    - customDimension1 (by default looks for a variable named customDimension1)
    - customDimension2 (by default looks for a variable named customDimension2)

Standard setup is already included in the default policies, but you can customize it further by setting up the following variables in the product policy inbound section:

```xml
<!-- Map appId from x-app-id header with safe defaults -->
<set-variable name="appId" value="@{
    var requestedAppId = context.Request.Headers.GetValueOrDefault("x-app-id", null);
    if (!string.IsNullOrEmpty(requestedAppId))
    {
        return requestedAppId;
    }
    return context.Subscription?.Id ?? "Portal-Admin";
}" />

<!-- Map customDimension1 from x-enduser-id header -->
<set-variable name="customDimension1" value="@(
    context.Request.Headers.GetValueOrDefault("x-sub-agent-id", "general-agent")
)" />

<!-- Map customDimension2 from x-usecase-id header -->
<set-variable name="customDimension2" value="@(
    context.Request.Headers.GetValueOrDefault("x-enduser-id", "anonymous-enduser")
)" />

```

>NOTE: The above policy fragment assumes that the client application is passing `x-app-id`, `x-sub-agent-id` and `x-enduser-id` headers in the request. You can modify the header names as per your requirements or use different approach to set these variables.

### LLM Usage Custom Dimensions Policy

The two custom dimensions (`customDimension1` and `customDimension2`) are generic, free-form tracking fields that flow all the way through to Cosmos DB and become slicers / grouping columns in the [Power BI Dashboard](../../../guides/power-bi-dashboard.md#activating-custom-dimensions). Use them to attribute usage against any organization-specific context — for example **end-user ID**, **session ID**, **sub-agent ID**, **cost center**, **department**, or **channel**.

By default both dimensions resolve to `NA`. They only carry meaningful values once you set the matching context variables. You can configure them **per access contract** (recommended for use-case-specific context) or **globally** in the usage policy fragment (for context that is identical across all use cases).

#### Per Access Contract (use-case specific)

Set the `customDimension1` / `customDimension2` variables in the **inbound** section of the product policy. This is the recommended approach because each use case decides what business context matters and how to source it (headers, JWT claims, subscription attributes, etc.).

**Source from client headers:**

```xml
<inbound>
    <base />
    <!-- Track the calling end user (customDimension1) -->
    <set-variable name="customDimension1" value="@(
        context.Request.Headers.GetValueOrDefault("x-enduser-id", "anonymous-enduser")
    )" />

    <!-- Track the conversation/session (customDimension2) -->
    <set-variable name="customDimension2" value="@(
        context.Request.Headers.GetValueOrDefault("x-session-id", "NA-session")
    )" />
</inbound>
```

**Source from a validated JWT claim** (for example, attribute usage to the calling identity or a tenant claim after `security-handler` runs):

```xml
<inbound>
    <base />
    <set-variable name="jwtRequired" value="true" />

    <!-- Attribute usage to the department claim carried in the token -->
    <set-variable name="customDimension1" value="@{
        var jwt = context.Request.Headers.GetValueOrDefault("Authorization", "")?.Split(' ').LastOrDefault()?.AsJwt();
        return jwt?.Claims.GetValueOrDefault("department", "unknown-dept") ?? "unknown-dept";
    }" />
</inbound>
```

**Static value per use case** (useful to tag a fixed cost center to a contract):

```xml
<inbound>
    <base />
    <set-variable name="customDimension2" value="cost-center-4711" />
</inbound>
```

| Variable | Emitted as dimension | Typical source |
|----------|----------------------|----------------|
| `customDimension1` | `customDimension1` | End-user ID, sub-agent ID, department, channel |
| `customDimension2` | `customDimension2` | Session ID, cost center, tenant ID, request category |

#### Global default (all use cases)

If a dimension has the same meaning everywhere, embed the default directly in the `frag-set-llm-usage.xml` policy fragment instead of repeating it in every access contract. Set the variable before the `<llm-emit-token-metric>` block (or change the fallback in the `<dimension>` element). A per-product `set-variable` still overrides the global default for that specific access contract.

> **NOTE:** `llm-emit-token-metric` supports a limited number of custom dimensions, which is why exactly two generic dimensions are exposed. Be mindful of **cardinality** — assigning very high-cardinality values (such as raw user IDs on high-traffic products) increases metric storage and query cost. For high-cardinality tracking, prefer `appId` or aggregate the value (e.g., hash or bucket) before emitting it.

### Configuring Alerts Policy

The gateway ships a comprehensive, opt-in alerting fragment, `raise-alert-events`, that emits a single Application Insights custom metric (`AI Gateway Alert`, namespace `ai-gateway-alerts`) for a curated set of service-impacting events. It is **already wired into all three inference APIs** (Azure OpenAI, Universal LLM, Unified AI), so you do **not** need to include the fragment yourself — an access contract only sets **toggle variables** to tailor which categories it alerts on.

**Event categories and their toggles:**

| `alertType` | Trigger | Toggle variable | Default |
|-------------|---------|-----------------|---------|
| `throttling` | HTTP `429` (per-minute token rate / TPM exceeded) | `alertOnThrottling` | **On** |
| `quota-exceeded` | HTTP `403` (long-term `token-quota` exhausted, `AITokenQuotaExceeded`) | `alertOnQuotaExceeded` | **On** |
| `backend-failure` | HTTP `5xx` backend fault / connectivity error | `alertOnBackendFailure` | **On** |
| `auth-failure` | HTTP `401`/`403` — missing/invalid key, missing/invalid JWT, insufficient role, model-access denied | `alertOnAuthFailure` | Off |
| `content-safety` | `llm-content-safety` block | `alertOnContentSafety` | Off |
| `pii-failure` | PII anonymization failure (fail-closed `502`) | `alertOnPiiFailure` | Off |

A master switch, `alertsEnabled` (default `true`), suppresses **all** alerting for the contract when set to `false`.

> **Where to set the toggles:** set them in the **inbound** section (before or right after `<base/>`). Context variables persist across sections, so an inbound toggle is honored when `raise-alert-events` runs later in `outbound` / `on-error`, and also at the authorization rejection points that emit in explicit mode (`security-handler`, `validate-model-access`).

**Opt a mission-critical use case into additional categories:**

```xml
<inbound>
    <base />
    <!-- Throttling + backend-failure are already on platform-wide.
         Enable auth, content-safety, and PII alerting for this contract: -->
    <set-variable name="alertOnAuthFailure" value="true" />
    <set-variable name="alertOnContentSafety" value="true" />
    <set-variable name="alertOnPiiFailure" value="true" />
</inbound>
```

**Silence alerting for a noisy, non-critical use case:**

```xml
<inbound>
    <base />
    <!-- Disable just the throttling category for a bursty sandbox... -->
    <set-variable name="alertOnThrottling" value="false" />
    <!-- ...or suppress ALL alerting for this contract: -->
    <!-- <set-variable name="alertsEnabled" value="false" /> -->
</inbound>
```

Each event is emitted with the dimensions `alertType`, `statusCode`, `productName`, `deploymentName`, and `backendId` (the selected backend / pool), so a single Azure Monitor alert rule can be split/filtered per category, use case, model, or backend. `emit-metric` supports at most 5 custom dimensions.

> **NOTE:** Detailed guidance on the alerting model and creating Azure Monitor alert rules is in the [Throttling & Critical Event Alerting Guide](../../../guides/throttling-events-handling.md). The broader resiliency context (how alerting complements the circuit breaker and failover) is in the [Resiliency Guide — Alerting on Critical Events](../../../guides/resiliency-guide.md#5-alerting-on-critical-events).

> **NOTE:** The legacy `raise-throttling-events` fragment (metric `AI Throttling`, namespace `throttling-events`) is still deployed for backward compatibility but is superseded by `raise-alert-events`. Prefer the toggles above for new contracts.


### Response Headers Policy

The `set-response-headers` policy fragment injects `UAIG-*` response headers that expose internal gateway state for debugging and observability. These headers help trace request processing through the gateway, including authentication context, model routing, backend selection, and cache operations.

**By default, response headers are disabled.** To enable them for a specific product, set the `enableResponseHeaders` variable to `true` in the product policy inbound section.

**Basic Usage:**

```xml
<inbound>
    <base />
    <!-- Enable advanced response headers for debugging -->
    <set-variable name="enableResponseHeaders" value="@(true)" />
</inbound>
```

**Headers Returned (when enabled):**

| Header | Source Variable | Description |
|--------|----------------|-------------|
| `UAIG-Auth-Type` | `auth-type` | Authentication method (`api-key`, `jwt`, `api-key-jwt`, `none`) |
| `UAIG-User-Id` | `user-id` | Authenticated user identifier |
| `UAIG-Subscription` | `subscription-name` | APIM subscription name |
| `UAIG-Model-Id` | `requestedModel` | Requested LLM model name |
| `UAIG-API-Type` | `api-type` | Detected API type (e.g., `azure-openai`, `universal-llm`) |
| `UAIG-Processed-Path` | `routing-processed-path` | Processed request path used for routing |
| `UAIG-API-Version` | `selected-api-version` | Selected API version |
| `UAIG-Is-Streaming` | `is-streaming` | Whether the request is a streaming request |
| `UAIG-Backend` | `selected-backend` | Selected backend pool |
| `UAIG-Final-Path` | `finalPath` | Final backend path after rewriting |
| `UAIG-Cache-Operation` | `cache-operation` | Cache operation performed (hit/miss/skip) |
| `UAIG-Request-Id` | — | APIM request correlation ID |
| `UAIG-Gateway-Region` | — | Azure region of the APIM gateway |

**How It Works:**

1. The `set-response-headers` fragment is included in the outbound and on-error sections of all three API policies (Azure OpenAI, Universal LLM, Unified AI)
2. The fragment checks the `enableResponseHeaders` variable — if not set or `false`, no headers are injected
3. When enabled via a product policy, the fragment adds all `UAIG-*` headers to the response using values set by upstream fragments during request processing

**Configuration Options:**

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enableResponseHeaders` | bool | `false` | Set to `@(true)` to enable response header injection |

>**NOTE:** Response headers expose internal gateway state and should only be enabled for development/debugging products. Avoid enabling them in production access contracts to prevent leaking internal routing details to clients.

### Content Safety Policy

The [`llm-content-safety`](https://learn.microsoft.com/en-us/azure/api-management/llm-content-safety-policy) policy enforces content safety checks on large language model (LLM) requests (prompts) or responses (completions) by sending them to the Foundry AI Content Safety service. The policy can also enforce content safety checks on requests or responses for MCP tools or A2A Agent APIs managed in API Management.

You can configure the content safety policy to block or flag content based on your organization's requirements per use-case/access contract.

>NOTE: Content Safety has a context input limit of **10K** characters for both checking the content it self against harmful content and the prompt shield for detecting attacks. Currently APIM support natively chunking input requests over 10K chunks for content safety checks. Prompt Shield however are still limited by the 10K limit. If you have content larger than 10K in the request, it is better to disable `shield-prompt` while configuring the policy.

```xml
<inbound>
    <!-- Content Safety Policy -->
    <!-- Failure to pass content safety will result in 403 error -->
    <llm-content-safety backend-id="content-safety-backend" shield-prompt="true" window-size="1000" window-overlap-size="200" enforce-on-completions="false">
        <!-- 0 is most restrictive and can be set up-to 7 -->
        <categories output-type="EightSeverityLevels">
            <category name="Hate" threshold="3" />
            <category name="Violence" threshold="3" />
        </categories>
    </llm-content-safety>
    <!-- End of Content Safety Policy -->
</inbound>
```

### JWT Authentication Policy

JWT (JSON Web Token) authentication adds a second security layer on top of subscription API keys. When enabled for a product, clients must provide both an `api-key` header and an `Authorization: Bearer {token}` header.

JWT validation is handled by the unified `security-handler` policy fragment, which is included in **all three API endpoints** (Azure OpenAI API, Universal LLM API, and Unified AI API). The fragment validates the token's audience, issuer, signature, and expiry against either gateway-level APIM named values or per-product custom overrides.

> **Full JWT setup guide:** See [JWT Authentication Guide](../../../guides/entraid-auth-validation.md) for gateway-level configuration.
> **Client identity & permissions:** See [JWT Client Identity and Permissions Guide](../../../guides/jwt-client-identity-permissions.md) for configuring client applications to acquire tokens.

**Prerequisites:**
- APIM named values configured: `JWT-TenantId`, `JWT-AppRegistrationId`, `JWT-Issuer`, `JWT-OpenIdConfigUrl`
- For Microsoft Entra ID: Run the `bicep/infra/entra-id-setup` module to auto-provision app registration and named values
- For other identity providers: Manually configure the APIM named values or use per-product custom overrides

**APIM Named Values for JWT Configuration:**

| Named Value | Description | Example (Entra ID) | Example (Auth0) |
|-------------|-------------|---------------------|-----------------|
| `JWT-OpenIdConfigUrl` | OpenID Connect discovery endpoint | `https://login.microsoftonline.com/{tenant}/v2.0/.well-known/openid-configuration` | `https://{domain}/.well-known/openid-configuration` |
| `JWT-Issuer` | Expected token issuer | `https://login.microsoftonline.com/{tenant}/v2.0` | `https://{domain}/` |
| `JWT-AppRegistrationId` | Expected audience claim | `api://{client-id}` | `https://your-api-identifier` |

**Basic Usage - Enable JWT with Gateway Defaults:**

```xml
<inbound>
    <base />
    <!-- Enable JWT requirement for this product -->
    <set-variable name="jwtRequired" value="true" />
    
    <!-- Other policies (model access, capacity, etc.) -->
</inbound>
```

**Advanced Usage - Enable JWT with Custom Identity Provider:**

Access contracts can override the gateway's default JWT settings by setting custom variables. The `security-handler` checks for these overrides first, then falls back to the APIM named values if not set.

| Variable | Description | Falls back to Named Value |
|----------|-------------|---------------------------|
| `jwtAudience` | Custom audience claim to validate | `JWT-AppRegistrationId` |
| `jwtIssuer` | Custom token issuer to validate | `JWT-Issuer` |
| `jwtOpenIdConfigUrl` | Custom OpenID Connect discovery URL | `JWT-OpenIdConfigUrl` |

```xml
<inbound>
    <base />
    <!-- Enable JWT requirement -->
    <set-variable name="jwtRequired" value="true" />
    
    <!-- Override JWT settings for a different identity provider (e.g., Auth0, Okta, separate Entra tenant) -->
    <set-variable name="jwtAudience" value="https://my-custom-api-audience" />
    <set-variable name="jwtIssuer" value="https://my-idp.example.com/" />
    <set-variable name="jwtOpenIdConfigUrl" value="https://my-idp.example.com/.well-known/openid-configuration" />
    
    <!-- Other policies (model access, capacity, etc.) -->
</inbound>
```

You can override any combination of settings — unset variables fall back to the gateway defaults:

```xml
<inbound>
    <base />
    <set-variable name="jwtRequired" value="true" />
    
    <!-- Only override audience (issuer and OpenID config use gateway defaults) -->
    <set-variable name="jwtAudience" value="api://custom-audience-for-this-product" />
</inbound>
```

**How It Works:**

1. The `security-handler` fragment (included in the API-level policy via `<base />`) detects the authentication method:
   - `api-key` — only subscription key provided
   - `jwt` — only Bearer token provided
   - `api-key-jwt` — both provided
   - `none` — neither provided

2. API key is always validated first (APIM subscription validation)

3. If `jwtRequired` is `"true"` (set by product policy), JWT validation is enforced:
   - Token is validated against the OpenID Connect configuration endpoint
   - Audience, issuer, and signature are verified
   - User identity is extracted from the `azp` claim (client credentials flow)
   - Custom overrides (`jwtAudience`, `jwtIssuer`, `jwtOpenIdConfigUrl`) are used if set, otherwise APIM named values apply

4. If a Bearer token is provided but `jwtRequired` is not set, the token is still validated (opportunistic validation)

5. This behavior is **uniform across all three API endpoints** — the same `security-handler` fragment executes regardless of whether the request arrives via Azure OpenAI, Universal LLM, or Unified AI API

**Output Variables Set by Security Handler:**

| Variable | Description | Example Values |
|----------|-------------|----------------|
| `auth-type` | Authentication method detected | `"api-key"`, `"jwt"`, `"api-key-jwt"`, `"none"` |
| `subscription-name` | APIM subscription name | `"LLM-HR-ChatAgent-DEV-SUB-01"` |
| `user-id` | User identifier (from JWT or subscription) | `"app-client-id"` or `"subscription-name"` |

**Error Responses:**

| Scenario | HTTP Status | Error Code | Message |
|----------|-------------|------------|----------|
| No API key | 401 | `unauthorized` | Access denied. A valid API key is required. |
| JWT required but missing | 401 | `jwt_required` | JWT Bearer token is required for this product. |
| Invalid JWT token | 401 | — | Access denied due to invalid or expired JWT bearer token. |
| JWT config missing | 503 | `jwt_not_configured` | JWT authentication is not configured properly on the gateway. |

**Token Acquisition (Client Credentials Flow - Entra ID):**

```http
POST https://login.microsoftonline.com/{tenant-id}/oauth2/v2.0/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_id={entra-app-client-id}
&client_secret={entra-app-client-secret}
&scope={audience}/.default
```

**Combining JWT with Other Policies:**

JWT authentication works alongside all other access contract policies like model access control and capacity management.

> **NOTE:** The `jwtRequired` variable must be set within the product policy inbound section. The `security-handler` fragment reads this variable during API-level policy execution.

### App Role Authorization Policy

App role authorization adds fine-grained access control on top of JWT authentication. When enabled for a product, the `security-handler` fragment checks that the JWT token contains at least one of the required app roles in the `roles` claim. This is enforced **after** JWT validation, so the token must first pass audience, issuer, and signature checks.

The gateway's Entra ID app registration defines the following app roles (provisioned by `entra-id-setup/setup.ps1`):

| App Role | Value | Description |
|----------|-------|-------------|
| ReadWrite | `Task.ReadWrite` | Full read and write access to all gateway capabilities |
| Models.Read | `Models.Read` | Access to LLM model endpoints (chat completions, embeddings) |
| MCP.Read | `MCP.Read` | Access to MCP tool endpoints |
| Agent.Read | `Agent.Read` | Access to agent endpoints |

> **Full setup guides:**
> - [JWT Authentication Guide](../../../guides/entraid-auth-validation.md) — Gateway-level configuration
> - [JWT Client Identity and Permissions Guide](../../../guides/jwt-client-identity-permissions.md) — Assigning roles to client identities

**Basic Usage — Require a Single Role:**

```xml
<inbound>
    <base />
    <!-- Enable JWT requirement -->
    <set-variable name="jwtRequired" value="true" />

    <!-- Require the Models.Read app role -->
    <set-variable name="requiredRoles" value="Models.Read" />

    <!-- Other policies (model access, capacity, etc.) -->
</inbound>
```

**Multiple Roles (OR logic) — Any Matching Role Grants Access:**

```xml
<inbound>
    <base />
    <set-variable name="jwtRequired" value="true" />

    <!-- Client must have at least one of these roles -->
    <set-variable name="requiredRoles" value="Models.Read,Agent.Read" />
</inbound>
```

**How It Works:**

1. The `security-handler` fragment validates the JWT token (audience, issuer, signature, expiry)
2. After successful JWT validation, the fragment extracts the `roles` claim from the token
3. If `requiredRoles` is set by the product policy, the fragment checks if ANY of the required roles exist in the token's `roles` claim (case-insensitive OR match)
4. If no matching role is found, the request is rejected with HTTP 403 Forbidden

**Error Response Format:**

When a required role is missing, the policy returns:

```json
{
    "error": {
        "message": "Access denied. Required app role not found in token.",
        "code": "insufficient_role",
        "required_roles": "Models.Read",
        "token_roles": "Agent.Read"
    }
}
```

**Configuration Options:**

| Variable | Description | Example |
|----------|-------------|---------|
| `requiredRoles` | Comma-separated list of accepted app roles (OR logic) | `"Models.Read"` or `"Models.Read,Agent.Read"` |

> **NOTE:** The `requiredRoles` variable is opt-in. If not set or empty, no role check is performed — this ensures backward compatibility with existing access contracts that only use `jwtRequired`.

**Output Variables Set by Security Handler:**

| Variable | Description | Example Values |
|----------|-------------|----------------|
| `jwt-roles` | App roles extracted from the JWT token | `"Models.Read,Agent.Read"` or `""` |

**Recommended Policy Ordering:**

```xml
<inbound>
    <base />

    <!-- 1. JWT Authentication -->
    <set-variable name="jwtRequired" value="true" />

    <!-- 2. App Role Authorization -->
    <set-variable name="requiredRoles" value="Models.Read" />

    <!-- 3. Model extraction and access control -->
    <include-fragment fragment-id="set-llm-requested-model" />
    <set-variable name="allowedModels" value="gpt-4o,gpt-4o-mini" />
    <include-fragment fragment-id="validate-model-access" />

    <!-- 4. Capacity management -->
    <llm-token-limit counter-key="@(context.Subscription.Id)"
        tokens-per-minute="5000"
        estimate-prompt-tokens="false"
        token-quota="100000"
        token-quota-period="Monthly" />

    <!-- 5. Content safety, PII, etc. -->
</inbound>
```

### PII Handling Policy

AI Citadel Gateway supports PII processing using built-in policy fragments that leverage Azure AI Language Service for detection and anonymization. This allows you to protect sensitive data when sending requests to LLM backends \u2014 either by **anonymizing** PII before it reaches the backend, or by **rejecting (blocking)** any request that contains PII outright.

>**NOTE:** Azure AI Language Service enforces a **5,120-character-per-document** limit for PII detection (applies only to the inbound request content, not the generated response). The `pii-anonymization` fragment now handles larger payloads **automatically** by splitting the input into overlapping chunks, batching up to 5 chunks per Language Service request, and analyzing across multiple requests (up to ~125,000 characters total). Detection runs on the chunks only — the request body is never reassembled from redacted pieces — so the original request structure is fully preserved. Tune this behavior with the optional `piiMaxChunkSize` and `piiChunkOverlap` variables (see the configuration table below). For full details see the [PII Masking Guide](../../../guides/pii-masking-apim.md#handling-large-documents-chunking--batching).

#### Available PII Policy Fragments

| Fragment | Purpose | Description |
|----------|---------|-------------|
| `pii-anonymization` | Inbound | Detects and replaces PII with placeholders before sending to backend |
| `pii-deanonymization` | Outbound | Restores original PII values in the response |
| `pii-state-saving` | Outbound | Logs PII processing activity to Event Hub for auditing |

#### Configuration Variables

The following variables can be set in your product policy to configure PII processing:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `piiAnonymizationEnabled` | Yes | - | Set to `"true"` to enable PII detection/anonymization |
| `piiBlockingEnabled` | No | `"false"` | Set to `"true"` to reject (block) requests that contain PII instead of anonymizing them |
| `piiConfidenceThreshold` | No | `"0.8"` | Minimum confidence score (0.0-1.0) for PII detection |
| `piiEntityCategoryExclusions` | No | `""` | Comma-separated list of PII categories to exclude (e.g., `"PersonType"`) |
| `piiDetectionLanguage` | No | `"en"` | Language code for detection. Use `"auto"` for multilingual content |
| `piiRegexPatterns` | No | `""` | JSON array of custom regex patterns for additional PII detection |
| `piiMaxChunkSize` | No | `"5000"` | Max characters per chunk sent to the Language Service (clamped to the `500`–`5120` service range). Only applies when the input exceeds one chunk |
| `piiChunkOverlap` | No | `"250"` | Overlap characters between consecutive chunks to catch PII straddling a chunk boundary (clamped to `≤ piiMaxChunkSize / 2`) |
| `piiInputContent` | Yes | - | The content to be anonymized (typically the request body) |
| `piiStateSavingEnabled` | No | `"false"` | Set to `"true"` to enable Event Hub logging |

>**NOTE:** For a complete list of PII entity categories, see [Azure AI Language PII Entity Categories](https://learn.microsoft.com/en-us/azure/ai-services/language-service/personally-identifiable-information/concepts/entity-categories).

#### PII Anonymization/Deanonymization Setup

PII anonymization works in two phases:
1. **Inbound**: Detect and replace PII with placeholders (e.g., `<Person_0>`, `<Email_0>`)
2. **Outbound**: Restore original PII values in the LLM response

##### Inbound Configuration

```xml
<inbound>
    <!-- Enable PII Anonymization -->
    <set-variable name="piiAnonymizationEnabled" value="true" />
    
    <choose>
        <when condition="@(context.Variables.GetValueOrDefault<string>("piiAnonymizationEnabled") == "true")">
            
            <!-- Configure PII detection settings -->
            <set-variable name="piiConfidenceThreshold" value="0.8" />
            <set-variable name="piiEntityCategoryExclusions" value="PersonType" />
            <set-variable name="piiDetectionLanguage" value="en" />

            <!-- Optional: Configure custom regex patterns for additional PII detection -->
            <set-variable name="piiRegexPatterns" value="@{
                var patterns = new JArray {
                    new JObject {
                        ["pattern"] = @"\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b",
                        ["category"] = "CREDIT_CARD"
                    },
                    new JObject {
                        ["pattern"] = @"\b[A-Z]{2}\d{6}[A-Z]\b",
                        ["category"] = "PASSPORT_NUMBER"
                    }
                };
                return patterns.ToString();
            }" />
            
            <!-- Capture request body for PII processing -->
            <set-variable name="piiInputContent" value="@(context.Request.Body.As<string>(preserveContent: true))" />
            
            <!-- Apply PII anonymization -->
            <include-fragment fragment-id="pii-anonymization" />
            
            <!-- Replace request body with anonymized content -->
            <set-body>@(context.Variables.GetValueOrDefault<string>("piiAnonymizedContent"))</set-body>
        </when>
    </choose>
</inbound>
```

##### Outbound Configuration

```xml
<outbound>
    <!-- Store response body before processing -->
    <set-variable name="responseBodyContent" value="@(context.Response.Body.As<string>(preserveContent: true))" />
    
    <choose>
        <when condition="@(context.Variables.GetValueOrDefault<string>("piiAnonymizationEnabled") == "true" && 
                        context.Variables.ContainsKey("piiMappings"))">
            
            <!-- Set input for deanonymization -->
            <set-variable name="piiDeanonymizeContentInput" value="@(context.Variables.GetValueOrDefault<string>("responseBodyContent"))" />
            
            <!-- Apply PII deanonymization -->
            <include-fragment fragment-id="pii-deanonymization" />
            
            <!-- Optional: Enable PII processing audit logging to Event Hub -->
            <set-variable name="piiStateSavingEnabled" value="true" />
            <set-variable name="originalRequest" value="@(context.Variables.GetValueOrDefault<string>("piiInputContent"))" />
            <set-variable name="originalResponse" value="@(context.Variables.GetValueOrDefault<string>("responseBodyContent"))" />
            <include-fragment fragment-id="pii-state-saving" />
            
            <!-- Replace response with deanonymized content -->
            <set-body>@(context.Variables.GetValueOrDefault<string>("piiDeanonymizedContentOutput"))</set-body>
        </when>
        <otherwise>
            <!-- Pass through original response -->
            <set-body>@(context.Variables.GetValueOrDefault<string>("responseBodyContent"))</set-body>
        </otherwise>
    </choose>
</outbound>
```

#### PII Blocking (Request Rejection) Setup

Instead of anonymizing PII, some access contracts must **reject** any request that contains PII outright. This is useful for strict compliance scenarios where no PII — even in anonymized form — should reach the backend LLM.

Blocking reuses the `pii-anonymization` fragment purely for **detection**: the fragment populates the `piiMappings` variable with every PII entity it finds. If that collection contains any entries, the request is rejected with an HTTP `400 Bad Request` before it is forwarded to the backend.

> **NOTE:** Blocking does not require a dedicated detection fragment — it relies on the same `pii-anonymization` fragment used for masking. The difference is that the anonymized body is discarded and the request is short-circuited when PII is present.

##### Inbound Configuration

```xml
<inbound>
    <base />
    <!-- Enable PII Blocking -->
    <set-variable name="piiBlockingEnabled" value="true" />

    <choose>
        <when condition="@(context.Variables.GetValueOrDefault<string>("piiBlockingEnabled") == "true")">

            <!-- Configure PII detection settings -->
            <set-variable name="piiAnonymizationEnabled" value="true" />
            <set-variable name="piiConfidenceThreshold" value="0.75" />
            <set-variable name="piiEntityCategoryExclusions" value="PersonType" />
            <set-variable name="piiDetectionLanguage" value="en" />

            <!-- Optional: custom regex patterns for domain-specific PII -->
            <set-variable name="piiRegexPatterns" value="@{
                var patterns = new JArray {
                    new JObject {
                        ["pattern"] = @"\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b",
                        ["category"] = "CREDIT_CARD"
                    },
                    new JObject {
                        ["pattern"] = @"\b[A-Z]{2}\d{6}[A-Z]\b",
                        ["category"] = "PASSPORT_NUMBER"
                    },
                    new JObject {
                        ["pattern"] = @"\b784-\d{4}-\d{7}-\d{1}\b",
                        ["category"] = "EMIRATES_ID"
                    }
                };
                return patterns.ToString();
            }" />

            <!-- Capture request body for PII processing -->
            <set-variable name="piiInputContent" value="@(context.Request.Body.As<string>(preserveContent: true))" />

            <!-- Run detection via the anonymization fragment (populates piiMappings) -->
            <include-fragment fragment-id="pii-anonymization" />

            <!-- Reject the request when any PII entity was detected -->
            <choose>
                <when condition="@{
                    var mappings = context.Variables.GetValueOrDefault<string>("piiMappings", "[]");
                    return JArray.Parse(mappings).Count > 0;
                }">
                    <return-response>
                        <set-status code="400" reason="Bad Request" />
                        <set-header name="Content-Type" exists-action="override">
                            <value>application/json</value>
                        </set-header>
                        <set-body>@{
                            var mappings = JArray.Parse(context.Variables.GetValueOrDefault<string>("piiMappings", "[]"));
                            var categories = new HashSet<string>();
                            foreach (var mapping in mappings) {
                                var placeholder = mapping["placeholder"].ToString();
                                var category = placeholder.TrimStart('<').Split('_')[0];
                                categories.Add(category);
                            }
                            return new JObject(
                                new JProperty("error", new JObject(
                                    new JProperty("code", "PII_DETECTED"),
                                    new JProperty("message", "Request blocked: Personal Identifiable Information (PII) detected in the request."),
                                    new JProperty("detectedCategories", string.Join(", ", categories)),
                                    new JProperty("entityCount", mappings.Count)
                                ))
                            ).ToString();
                        }</set-body>
                    </return-response>
                </when>
            </choose>
        </when>
    </choose>
</inbound>
```

> **NOTE:** When blocking is enabled you should **not** add the outbound `pii-deanonymization` step — no anonymized content is ever forwarded to the backend, so there is nothing to restore.

**Error Response Format:**

When PII is detected, the request is rejected with an HTTP `400 Bad Request` and a structured JSON error listing the detected categories:

```json
{
    "error": {
        "code": "PII_DETECTED",
        "message": "Request blocked: Personal Identifiable Information (PII) detected in the request.",
        "detectedCategories": "Person, Email, PhoneNumber, InternationalBankingAccountNumber",
        "entityCount": 4
    }
}
```

**Blocking vs. Anonymization:**

| Behavior | Anonymization (`piiAnonymizationEnabled`) | Blocking (`piiBlockingEnabled`) |
|----------|-------------------------------------------|----------------------------------|
| PII detected in request | Replaced with placeholders and forwarded to backend | Request rejected with `400 Bad Request` |
| Backend receives request | Yes (anonymized) | No |
| Outbound deanonymization | Required to restore original values | Not applicable |
| Use case | Protect PII while still allowing processing | Strict compliance — no PII may reach the backend |

> **NOTE:** Use blocking when your compliance requirements prohibit any PII from being processed by backend services, even in anonymized form. A working reference implementation is available in the `compliance-piiblocking` access contract.

#### Custom Regex Patterns

Extend Azure AI Language Service NLP detection with custom regex patterns for domain-specific PII:

```xml
<set-variable name="piiRegexPatterns" value="@{
    var patterns = new JArray {
        new JObject {
            ["pattern"] = @"\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b",
            ["category"] = "CREDIT_CARD"
        },
        new JObject {
            ["pattern"] = @"\b[A-Z]{2}\d{6}[A-Z]\b",
            ["category"] = "PASSPORT_NUMBER"
        },
        new JObject {
            ["pattern"] = @"\b\d{3}[-]?\d{4}[-]?\d{7}[-]?\d{1}\b",
            ["category"] = "NATIONAL_ID"
        },
        new JObject {
            ["pattern"] = @"\b784-\d{4}-\d{7}-\d{1}\b",
            ["category"] = "EMIRATES_ID"
        }
    };
    return patterns.ToString();
}" />
```

>**TIP:** Regex patterns are processed before calling Azure AI Language Service, allowing you to catch domain-specific patterns that NLP might miss.

#### Event Hub Logging

When `piiStateSavingEnabled` is set to `"true"`, the `pii-state-saving` fragment logs detailed PII processing information to Event Hub for auditing and compliance purposes. The logged data includes:

- Operation metadata (timestamp, API name, product, subscription)
- Processing configuration (confidence threshold, exclusions)
- Entity counts and categories detected
- PII mappings (for detailed audit trails)
- Content length metrics

>**NOTE:** For detailed implementation information and advanced scenarios, see [PII Masking Guide](../../../guides/pii-masking-apim.md).

## Extending default policies

You can extend the out-of-the-box policies by leveraging APIM extensive policy expressions and capabilities.