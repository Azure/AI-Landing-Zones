# Publish Contract Guide

The **Publish Contract** is the mechanism the Citadel Governance Hub uses to onboard and publish centrally protected AI assets — **Tools (MCP)** and **Agents (A2A)** — through the AI Hub Gateway (Azure API Management). It complements the two existing contracts:

| Contract | Answers | Artifact |
| --- | --- | --- |
| **Backend Contract** | *Where* do LLM requests route to? | `bicep/infra/llm-backend-onboarding/` |
| **Access Contract** | *Who* may access an AI asset and under what limits? | `bicep/infra/citadel-access-contracts/` |
| **Publish Contract** (this) | *What* AI assets (tools/agents) are published and protected? | `bicep/infra/citadel-publish-contracts/` |

> **Publishing vs. access.** The Publish Contract establishes the asset: endpoints, per-asset backends, baseline policies, usage tracking, and optional API Center registration. **Granting access** is the job of the [Access Contract](../citadel-access-contracts/), which now governs published Tools/Agents alongside LLMs — a single product can grant a mix of asset types (prefix `MULTI-`) and applies **conditional per-asset-type** policies (model RBAC + token limits for LLM; request-based rate limits for Tools/Agents). Publishing itself does **not** create APIM Products/Subscriptions.

---

## 1. Concepts

A **published asset** is a governed entry point on the primary gateway. Publishing an asset creates:

1. An APIM API of the appropriate type (`mcp` or `a2a`).
2. For remote MCP / A2A: a dedicated APIM **backend** with a circuit breaker and credential injection.
3. A **baseline policy** that layers the gateway's shared governance fragments (authentication, usage metrics, alerting) onto the asset.
4. Optionally, an **Azure API Center** registration for discoverability.

Assets are declared as entries in the `publishAssets` array of a `.bicepparam` file — one file can publish many assets.

### Asset types

| `assetType` | Description | APIM type | Gateway endpoint | Backend |
| --- | --- | --- | --- | --- |
| `mcp-from-api` | Wrap selected operations of an **existing onboarded REST API** as MCP tools | `mcp` (`mcpTools[]`) | `{gateway}/mcp/{path}/mcp` | Reuses the source API's backend |
| `mcp-existing` | Publish an **existing/remote MCP server** (e.g. `https://learn.microsoft.com/api/mcp`) | `mcp` (`backendId` + `mcpPropperties`) | `{gateway}/mcp/{path}` | Dedicated `<name>-backend` |
| `a2a` | Publish a native **A2A agent** endpoint + agent card (e.g. a Foundry-hosted agent) | `a2a` (`a2aProperties` + `jsonRpcProperties`) | `{gateway}/agent/{path}` (card at `/.well-known/agent.json`) | Policy MI auth to backend (no backend object, see §4); optional subscription-key on the client |

> **Asset-type path prefix (default on):** with `useAssetTypePathPrefix = true` (default) every **Tool** is served under an `mcp/` segment and every **Agent** under an `agent/` segment — e.g. `path: 'weather-tool-mcp'` → `{gateway}/mcp/weather-tool-mcp/...`, `path: 'hr-chat-agent'` → `{gateway}/agent/hr-chat-agent`. This namespaces tools and agents on the gateway. Override per asset with `pathPrefix` (a custom segment, or `''` to opt one asset out), or set the global toggle to `false` to keep legacy un-prefixed paths. See [§7 Path prefixing & backward compatibility](#7-path-prefixing--backward-compatibility).

> **MCP endpoint suffix (important):** APIM appends `/mcp` to the path **only** for API→MCP tools (`mcp-from-api`) — e.g. `path: 'weather-tool-mcp'` → `{gateway}/mcp/weather-tool-mcp/mcp` (note the `mcp/` prefix *and* the `/mcp` suffix). For a native/remote MCP server (`mcp-existing`) APIM does **not** append `/mcp` — the endpoint is `{gateway}/mcp/{path}` exactly (e.g. `{gateway}/mcp/ms-learn-tool-mcp`). Point MCP clients at these URLs accordingly. (With the prefix disabled these become `{gateway}/{path}/mcp` and `{gateway}/{path}`.)

---

## 2. Parameter schema

Global parameters (see [main.bicepparam](./main.bicepparam)):

| Parameter | Purpose |
| --- | --- |
| `apim` | `{ subscriptionId, resourceGroupName, name }` of the target gateway |
| `managedIdentityClientId` | UAMI client id for managed-identity backends (empty = system-assigned) |
| `configureCircuitBreaker` | Master toggle for backend circuit breakers (default `true`) |
| `circuitBreakerDefaults` | Default breaker settings, shallow-merged with per-asset overrides |
| `ensureUsageFragments` | Create the `mcp-usage` / `a2a-usage` fragments if missing (default `true`) |
| `useAssetTypePathPrefix` | Prefix each asset's gateway path with its type segment — `mcp/` for Tools, `agent/` for Agents (default `true`). `false` = legacy un-prefixed paths. Per-asset override via `pathPrefix`. |
| `apiCenter` | `{ subscriptionId, resourceGroupName, serviceName, workspaceName }` — required only if any asset opts into API Center |
| `publishAssets` | The array of assets to publish |

### Per-asset fields

Common: `assetType`, `name`, `displayName`, `description`, `path`, `metadata`, `policyXml?`, `publishToApiCenter?`, `apiCenter?`.

> **`pathPrefix` (optional):** overrides the automatic asset-type prefix for a single asset. Set a custom segment (e.g. `'tools'`) to group differently, or `''` to publish this one asset at the bare `path` even when `useAssetTypePathPrefix` is on. Omit it to use the default (`mcp` for Tools, `agent` for Agents).

**`metadata`** (informational governance context surfaced to operators / API Center):

```bicep
metadata: {
  version: '1.0.0'
  owner: 'Platform Engineering'
  contactEmail: 'ai-platform@contoso.com'
  compliance: [ 'GDPR' ]        // regulatory/compliance tags
  classification: 'confidential' // public | internal | confidential
}
```

**`mcp-from-api`**: `sourceApiName`, `operationNames`, `subscriptionRequired` (default `true`), `subscriptionKeyHeaderName` (`api-key` default, or `Ocp-Apim-Subscription-Key`), `forwardSubscriptionKeyToSource` (default `false`), `sourceSubscriptionKeyHeaderName` (default `x-mcp-sub-key`).

> ⚠️ **Source API must NOT require its own subscription key.** An `mcp-from-api` server forwards `tools/call` to the source API (`sourceApiName`) **internally**. If that source API is onboarded with `subscriptionRequired: true`, the internal hop has no subscription key and APIM rejects it with `401 — Access denied due to missing subscription key`. The failure is subtle: `initialize` and `tools/list` still succeed (they only read tool metadata and never touch the backend), so only actual tool invocations break. Onboard the source API with **`subscriptionRequired: false`** (the sample `weather-api` uses `subscriptionRequired: false` + the `api-key` header) and let the published MCP server's own `subscriptionRequired`/Access Contract gate govern who may call it. The `subscriptionRequired` field here controls the **published MCP server's** gate, which is independent of the source API's setting.

> 🔐 **Keep the source API protected (opt-in key forwarding).** If you don't want the source API reachable anonymously, set `forwardSubscriptionKeyToSource: true`. The published MCP policy then injects the caller's subscription key (`context.Subscription.Key`) into a **custom header** — `sourceSubscriptionKeyHeaderName` (default `x-mcp-sub-key`) — that survives the internal hop, so the **same contract key** reaches both the MCP tool and the raw API. This works because APIM strips the *standard* subscription headers (`api-key` **and** `Ocp-Apim-Subscription-Key`) before the tool→backend hop, but leaves a non-standard header intact. Two prerequisites (outside this module):
> 1. **Source API** onboarded with `subscriptionRequired: true` reading its key from the **same** custom header (e.g. `weather-api` → `subscriptionKeyParameterNames.header = x-mcp-sub-key`).
> 2. **Access Contract** grants the source API too — add it to `apiNameMapping` (e.g. `MULTI: [ 'weather-tool', 'weather-api', … ]`) so the one subscription key authorizes both APIs.
>
> Result: direct calls to the source API without a key return `401`, the same key works directly *and* via the tool, and no second credential is needed. Leave `forwardSubscriptionKeyToSource: false` (default) to keep the simpler anonymous-source model. Ignored when a custom `policyXml` is supplied on the asset.

**`mcp-existing`**: `transportType` (default `streamable`), `subscriptionRequired` (default `true`), `subscriptionKeyHeaderName` (`api-key` default, or `Ocp-Apim-Subscription-Key`), `backend { url, authType, authConfig?, circuitBreaker? }`.

**`a2a`**: `agentId`, `agentCardPath` (default `/.well-known/agent.json`), `agentCardBackendUrl`, `jsonRpcPath` (default `/`), `subscriptionRequired` (default `false`), `subscriptionKeyHeaderName` (`api-key` default, or `Ocp-Apim-Subscription-Key`), `backend { url, authType, authConfig? }`.

> **A2A client auth:** set `subscriptionRequired: true` to require an APIM subscription (API) key on the caller. The key is read from the header named by `subscriptionKeyHeaderName` — use `api-key` to match the LLM/MCP convention, or `Ocp-Apim-Subscription-Key` for the APIM-native header (query-string key name is `api-key` / `subscription-key` respectively). Leave `subscriptionRequired: false` for an anonymous endpoint. The gateway still authenticates to the backend (Foundry) agent with its managed identity regardless.

### Backend auth (`backend.authType`)

| `authType` | Use | `authConfig` |
| --- | --- | --- |
| `none` | Public remote MCP | — |
| `managed-identity` | Foundry A2A, Azure-hosted backends | `{ resource }` (e.g. `https://ai.azure.com`) |
| `api-key-header` | Remote server keyed by a header | `{ headerName?, namedValueKey, keyVaultSecretUri? | secretValue? }` |
| `api-key-bearer` | Bearer-token server | `{ namedValueKey, keyVaultSecretUri? | secretValue? }` (store the full `Bearer ...` value) |

API keys are stored as APIM **named values** — prefer `keyVaultSecretUri` (rotatable, auditable) over inline `secretValue`.

### Folder structure & source control

Organize publish contracts by **name** and **environment** — the same layout used by the [Access Contract](../citadel-access-contracts/README.md) — so each contract is a self-contained, reviewable unit:

```
citadel-publish-contracts/
├── main.bicep                          # the module (do not edit per-contract)
├── main.bicepparam                     # reference sample (using 'main.bicep')
└── contracts/                          # per-contract publish definitions (git-ignored by default)
    └── <contract-name>/
        └── <env>/
            └── main.bicepparam         # using '../../../main.bicep'
```

- **`contracts/<contract-name>/<env>/main.bicepparam`** — one folder per environment. The `using` points **three levels up** to the module (`using '../../../main.bicep'`).
- The `contracts/` tree is **git-ignored** in this accelerator (like `citadel-access-contracts/contracts`) because generated params carry environment-specific ids; teams source-control their own contracts in their repo/branch following this layout.
- The validation notebook writes its generated publish contract to `contracts/sample-assets/dev/main.bicepparam` and the paired access contract to `citadel-access-contracts/contracts/<biz>-<usecase>/<env>/`.

Deploy a contract from its folder:

```bash
az deployment sub create \
  --name publish-<contract-name>-<env> \
  --location <region> \
  --template-file bicep/infra/citadel-publish-contracts/main.bicep \
  --parameters bicep/infra/citadel-publish-contracts/contracts/<contract-name>/<env>/main.bicepparam
```

---

## 3. Resiliency

**Remote MCP** assets create a dedicated APIM backend with a native **circuit breaker**, reusing the Backend Contract model:

```bicep
backend: {
  url: 'https://remote-mcp.contoso.com/mcp'
  authType: 'none'
  circuitBreaker: {          // optional per-asset override
    failureCount: 5
    failureInterval: 'PT1M'
    tripDuration: 'PT30S'
    acceptRetryAfter: true
  }
}
```

Defaults (from `circuitBreakerDefaults`): trip after **3** failures within **PT5M**, stay open **PT1M**, honor upstream `Retry-After`, on status `429` and `500–503`. Set `configureCircuitBreaker=false` to disable globally, or `backend.circuitBreaker.enabled=false` per asset. See the [resiliency guide](../../../guides/resiliency-guide.md) for the wider gateway resiliency model.

> **A2A assets** authenticate to the backend in policy against a full URL (see §4), so they do **not** create an APIM backend object and have no native circuit breaker. Add resilience for agents with a retry policy (custom `policyXml`) if needed.

---

## 4. Policies & reuse of LLM capabilities

Each asset gets a **baseline policy** ([baseline-mcp-policy.xml](./policies/baseline-mcp-policy.xml) / [baseline-a2a-policy.xml](./policies/baseline-a2a-policy.xml)) that composes the gateway's shared fragments:

- **MCP** — `security-handler` (API key + optional per-product JWT), `mcp-usage` (metric), `raise-alert-events` (opt-in alerting).
- **A2A** — `authentication-managed-identity` (backend/Foundry auth, injected with the asset's MI client id), `a2a-usage` (metric), `raise-alert-events`. **No `security-handler`** — see the A2A auth model below.

The MCP fragments are the **same** ones used by the LLM APIs, so existing governance composes with published tools. To layer more controls on a specific asset (e.g. inbound PII anonymization or content safety), supply a custom `policyXml` on that asset rather than editing the baseline.

### A2A authentication model (important)

APIM's A2A preview **does not validate product/subscription keys** — sending an `api-key` header to an A2A endpoint re-triggers a broken subscription gate and returns `401`. Therefore, in **phase 1**:

- The A2A endpoint is **anonymous at the gateway** (`subscriptionRequired: false`); client-side auth (subscription/JWT) is added by the **phase-2 Access Contract**.
- The gateway authenticates to the **agent backend** (Foundry) using a **managed identity** — attached in the policy via `<authentication-managed-identity resource="https://ai.azure.com" client-id="…"/>`, injected from `managedIdentityClientId`. The MI must hold **Foundry Agent Consumer** (or **Azure AI User**) on the Foundry project.
- Because auth is done in policy against a **full backend URL**, A2A assets do **not** create an APIM backend object (and thus have no native circuit breaker — see §3). MCP assets are unaffected.

### ⚠️ MCP streaming constraint

MCP servers use a streaming (SSE) transport. **Policies must not read `context.Response.Body`** for MCP assets — doing so buffers the response and breaks the transport. Consequently:

- Request-side controls (auth, usage, inbound PII/content-safety) **work** for MCP.
- Response-side controls (PII **de**-anonymization, response content-safety) are **not supported** for MCP.

A2A v1.0 is JSON-RPC (non-streaming), so response-side inspection is generally safe there — but the baseline keeps it opt-in for simplicity.

---

## 5. Usage tracking

Usage is emitted as **App Insights custom metrics** (no Event Hub, no `log-to-eventhub`), mirroring the LLM metric approach:

| Metric | Namespace | `deploymentName` dim | `customDimension1` | `customDimension2` |
| --- | --- | --- | --- | --- |
| `McpRequests` | `mcp-usage` | tool / MCP name | `mcp` | operation |
| `A2ARequests` | `a2a-usage` | agent name | `a2a` | operation |

Two scheduled **Logic App** workflows aggregate these metrics into Cosmos DB, cloned from the LLM usage workflow:

| Workflow | Reads metric | Writes container | Export-config id |
| --- | --- | --- | --- |
| `src/usage-ingestion-logicapp/mcp-usage-ingestion` | `McpRequests` | `mcp-usage-container` | `003` |
| `src/usage-ingestion-logicapp/agent-usage-ingestion` | `A2ARequests` | `agent-usage-container` | `004` |

Each run queries `customMetrics` over a rolling window (`sum(valueSum)` = request count), upserts one document per `(tool/agent, product, backend, hour)` bin, and advances `lastExportDate` in the `streaming-export-config` container. The Logic App's existing `azuremonitorlogs` connection and managed-identity RBAC (Azure Monitor Logs Reader + Cosmos SQL Contributor) are reused unchanged. The two new containers are added to the Cosmos module.

---

## 6. API Center registration (optional)

Set `publishToApiCenter: true` and provide the global `apiCenter` coordinates plus a per-asset `apiCenter` block:

```bicep
publishToApiCenter: true
apiCenter: {
  environmentName: 'mcp-dev'          // mcp-dev | mcp-prod | api-dev | ...
  lifecycleStage: 'development'
  versionName: '1-0-0'
  customProperties: { Visibility: true, Vendor: 'Internal', Type: 'AI Gateway' }
}
```

The asset is registered (kind `mcp` or `a2a`) via the shared `api-center-onboarding` module. Off by default.

---

## 7. Path prefixing & backward compatibility

By default (`useAssetTypePathPrefix = true`) the module prepends an **asset-type segment** to every published asset's gateway path, so the gateway namespaces assets by type:

| Asset type | `path` | Endpoint (prefix on) | Endpoint (prefix off) |
| --- | --- | --- | --- |
| `mcp-from-api` | `weather-tool-mcp` | `{gateway}/mcp/weather-tool-mcp/mcp` | `{gateway}/weather-tool-mcp/mcp` |
| `mcp-existing` | `ms-learn-tool-mcp` | `{gateway}/mcp/ms-learn-tool-mcp` | `{gateway}/ms-learn-tool-mcp` |
| `a2a` | `hr-chat-agent` | `{gateway}/agent/hr-chat-agent` | `{gateway}/hr-chat-agent` |

**Controls**

- **Global toggle** — `useAssetTypePathPrefix` (default `true`). Set `false` to restore the legacy behavior where `path` is used verbatim.
- **Per-asset override** — `pathPrefix` on any asset: a custom segment (e.g. `'tools'` → `{gateway}/tools/{path}`) or `''` to opt that single asset out even when the toggle is on.
- The **`/mcp` suffix** on `mcp-from-api` is unchanged — it is APIM behavior, independent of this prefix — so an API→MCP tool ends up with **both** (`{gateway}/mcp/{path}/mcp`). Choose `path` names accordingly (e.g. drop a trailing `-mcp` if the double reads awkwardly).

### ⚠️ Backward-compatibility considerations

Enabling the prefix **changes the public URL** of every published asset. When adopting it on an existing gateway:

1. **Clients must repoint.** Existing MCP/A2A clients calling `{gateway}/{path}` (or `{gateway}/{path}/mcp`) break — update them to the `mcp/` / `agent/` URLs (or keep `useAssetTypePathPrefix = false` until they migrate).
2. **Access Contracts auto-heal on redeploy, but stored secrets go stale.** The [Access Contract](../citadel-access-contracts/README.md) resolves each granted API's path **live** from APIM at deploy time, so re-running an access contract picks up the new path automatically. However, Key Vault **endpoint secrets** and Foundry connections written by an earlier run still hold the old URL until the access contract is redeployed — re-run it after flipping the prefix.
3. **API Center runtime URIs change.** Re-registration updates each asset's `apiPath` (`mcp/{path}[/mcp]` or `agent/{path}`); consumers reading the runtime URI from API Center get the new value.
4. **Escape hatch.** For a phased rollout, keep `useAssetTypePathPrefix = false` globally and prefix assets one at a time with a per-asset `pathPrefix`, or vice-versa (`true` globally with `pathPrefix: ''` on assets that must stay on legacy paths).

---

## 8. Publishing a Foundry agent as A2A

Foundry-hosted agents can be exposed as A2A endpoints. Before publishing:

1. **Enable incoming A2A** on the agent (a prompt agent, or a hosted agent that implements the responses protocol) via a `PATCH` to `…/agents/{agent}?api-version=v1` setting the `agent_card` and `protocol_configuration { responses: {}, a2a: {} }`. See [Enable incoming A2A on a Foundry agent](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/enable-agent-to-agent-endpoint) and the sample [a2a-foundry-sample-agent.ps1](../../../local/contracts/a2a-foundry-sample-agent.ps1).
2. **Grant the gateway's managed identity** access on the Foundry project. Incoming A2A requires Microsoft Entra auth (key-based auth is not supported), so the identity APIM uses to call the agent needs a data-plane role on the project (`Azure AI User`, or the least-privilege `Foundry Agent Consumer`). Prefer APIM's **user-assigned** managed identity and pass its **`clientId`** as the global `managedIdentityClientId` parameter — the A2A backend then embeds managed-identity auth (audience `https://ai.azure.com`) using that specific identity. The validation notebook automates both the grant and the `clientId` wiring (step 3️⃣.1).

Then configure the asset:

```bicep
{
  assetType: 'a2a'
  name: 'hr-chat-agent'
  displayName: 'HR Chat Agent (A2A)'
  path: 'hr-chat-agent'
  agentId: 'HR-ChatAgent'
  subscriptionRequired: true        // require an APIM subscription key on the caller
  subscriptionKeyHeaderName: 'api-key'  // or 'Ocp-Apim-Subscription-Key'
  agentCardPath: '/.well-known/agent.json'
  agentCardBackendUrl: 'https://{account}.services.ai.azure.com/api/projects/{project}/agents/{agent}/endpoint/protocols/a2a/agentCard/v1.0'
  jsonRpcPath: '/'
  backend: {
    url: 'https://{account}.services.ai.azure.com/api/projects/{project}/agents/{agent}/endpoint/protocols/a2a'
    authType: 'managed-identity'
    authConfig: { resource: 'https://ai.azure.com' }
  }
}
```

APIM re-exposes the Foundry agent card (served at the custom `agentCard/v1.0` path) at the standard `/.well-known/agent.json` path, and proxies JSON-RPC calls to the Foundry A2A base path. The gateway authenticates to Foundry with the **user-assigned managed identity** whose `clientId` you pass as `managedIdentityClientId` (that identity needs **Foundry Agent Consumer** on the project).

**Agent card transport rewrite.** A2A SDK / Microsoft Agent Framework clients read the agent card's transport **interface URLs** to decide where to send requests. Foundry's card advertises the Foundry endpoint, which would make clients bypass the gateway and call Foundry directly. So `publishA2aAgent.bicep` adds an **outbound policy** that rewrites the backend (Foundry) transport URLs in the card to the **gateway** A2A URL (`{gateway}/{path}`). The rewrite is guarded to JSON responses (the card), so it never buffers a streaming body. The inbound policy also forces `Accept-Encoding: identity` on the backend request, because `find-and-replace` cannot rewrite a gzip-compressed card body (a compressed card returns empty and clients fail to resolve it). Result: clients that resolve the card — including `agent_framework.a2a.A2AAgent` — route **through the gateway** (presenting their subscription key when `subscriptionRequired: true`), keeping the traffic governed, regardless of the client's compression settings.

> **Foundry A2A notes:** v1.0 is **JSON-RPC only**, **text-only**, **no streaming**, and in **preview**; Foundry serves **v0.3 by default** (send `A2A-Version: 1.0` to select v1.0, and note the message object needs a `kind` field). Client access is **subscription-key based**: publish with `subscriptionRequired: true` and callers present a valid APIM subscription key in the header named by `subscriptionKeyHeaderName` (`api-key` or `Ocp-Apim-Subscription-Key`); publish with `subscriptionRequired: false` for an anonymous endpoint. Richer client auth (JWT, product scoping) is added by the phase-2 Access Contract.

---

## 9. Validation

`validation/citadel-publish-contract-tests.ipynb` deploys and validates all three asset types end-to-end (MCP handshake, agent-card fetch, JSON-RPC call, policy application, usage metrics, and circuit-breaker resiliency). See that notebook for a runnable scenario.

---

## 10. Related

- [Access Contract](../citadel-access-contracts/README.md)
- [Backend Contract](../llm-backend-onboarding/README.md)
- [Resiliency guide](../../../guides/resiliency-guide.md)
- [Platform observability guide](../../../guides/platform-observability-guide.md)