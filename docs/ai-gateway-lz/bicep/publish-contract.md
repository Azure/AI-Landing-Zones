# Citadel Publish Contract

Onboard and publish **centrally protected AI assets** — Tools (MCP) and Agents (A2A) — through the AI Hub Gateway, using the same declarative, bicepparam-driven approach as the Access Contract and Backend Contract.

> **Phase 1 scope:** publishing the asset endpoints, backends, baseline policies, usage tracking, and optional API Center registration. This does **not** create APIM Products/Subscriptions — governed access (who may call a published asset) is **Access Contract** scope, handled in phase 2.

📖 Full documentation: [publish-contract-guide.md](./publish-contract-guide.md)

## Asset types

| `assetType`     | Result | Gateway endpoint | Backend |
| --------------- | ------ | ---------------- | ------- |
| `mcp-from-api`  | Converts an existing onboarded REST API into an MCP tool server (`mcpTools` wrap operations) | `{gateway}/{path}/mcp` | Reuses the source API's backend |
| `mcp-existing`  | Publishes a remote/native MCP server through the gateway | `{gateway}/{path}` | Dedicated backend (`<name>-backend`) |
| `a2a`           | Publishes a native APIM A2A agent endpoint + agent card (e.g. a Foundry-hosted agent) | `{gateway}/{path}` (card at `/.well-known/agent.json`) | Policy managed-identity auth (no backend object) |

> **MCP endpoint suffix:** APIM appends `/mcp` to the path **only** for API→MCP tools (`mcp-from-api`). Native/remote MCP servers (`mcp-existing`) are served at `{gateway}/{path}` with **no** appended `/mcp`.

> ⚠️ **`mcp-from-api` source API must NOT require its own subscription key.** The MCP server forwards `tools/call` to `sourceApiName` internally, so if that source API was onboarded with `subscriptionRequired: true` the internal call fails with `401 — missing subscription key` (while `initialize`/`tools/list` still succeed). Onboard the source API with `subscriptionRequired: false` and let the published MCP server's own subscription/Access Contract gate govern access. See [publish-contract-guide.md](./publish-contract-guide.md#per-asset-fields).

> 🔐 **Keep the source API protected (opt-in).** Set `forwardSubscriptionKeyToSource: true` on an `mcp-from-api` asset to forward the caller's subscription key into a custom header (`sourceSubscriptionKeyHeaderName`, default `x-mcp-sub-key`) that survives the internal hop — so the **same contract key** reaches both the MCP tool and a **subscription-protected** source API (no anonymous direct access). Requires the source API onboarded with `subscriptionRequired: true` reading that custom header, and the source API added to the Access Contract's `apiNameMapping`. See [publish-contract-guide.md](./publish-contract-guide.md#per-asset-fields).

## Layout

```
bicep/infra/citadel-publish-contracts/
├── main.bicep                     # Orchestrator (subscription scope)
├── main.bicepparam                # Sample: 3 assets (API->MCP, native MCP, A2A)
├── publish-contract-guide.md      # Primary guide
├── README.md                      # This file
├── modules/
│   ├── publishBackend.bicep        # Per-asset backend + circuit breaker + auth
│   ├── publishMcpFromApi.bicep     # API -> MCP tool server
│   ├── publishMcpExisting.bicep    # Remote/native MCP server
│   ├── publishA2aAgent.bicep       # Native A2A agent endpoint
│   ├── publishApiCenter.bicep      # Optional API Center registration
│   └── publishPolicyFragments.bicep# Ensures mcp-usage / a2a-usage fragments exist
└── policies/
    ├── baseline-mcp-policy.xml     # Default MCP policy (auth + usage; no response-body reads)
    └── baseline-a2a-policy.xml     # Default A2A policy (auth + usage)

contracts/                          # per-contract definitions (git-ignored; see below)
└── <contract-name>/<env>/main.bicepparam   # using '../../../main.bicep'
```

### Folder structure & source control

Like the [Access Contract](../citadel-access-contracts/README.md), each publish contract lives under `contracts/<contract-name>/<env>/main.bicepparam` (the `using` points three levels up to `main.bicep`). The `contracts/` tree is **git-ignored** in this accelerator (generated params carry environment-specific ids); teams source-control their own contracts in their repo following this layout. The validation notebook writes its generated contract to `contracts/sample-assets/dev/`.

## Deploy

```powershell
az deployment sub create `
  --name publish-sample-assets-dev `
  --location <region> `
  --template-file bicep/infra/citadel-publish-contracts/main.bicep `
  --parameters bicep/infra/citadel-publish-contracts/contracts/<contract-name>/<env>/main.bicepparam
```

> The root [main.bicepparam](./main.bicepparam) is a reference sample (`using 'main.bicep'`); real contracts live under `contracts/<contract-name>/<env>/` (`using '../../../main.bicep'`).

## Resiliency

Each `mcp-existing` asset gets a native APIM **circuit breaker** on its backend (defaults: 3 failures / PT5M → open PT1M, honoring `Retry-After`). Override per asset via `backend.circuitBreaker`, or disable globally with `configureCircuitBreaker=false`. This mirrors the Backend Contract's resiliency model. (`a2a` assets authenticate in policy against a full URL and have no backend object; add a retry policy for agent resilience.)

## Usage tracking

The baseline policies emit inbound request-count metrics to the `mcp-usage` / `a2a-usage` App Insights namespaces (tool/agent name via the `deploymentName` dimension). Two scheduled Logic App workflows (`mcp-usage-ingestion`, `agent-usage-ingestion`) aggregate these into the `mcp-usage-container` / `agent-usage-container` Cosmos collections — mirroring the LLM usage pipeline, with **no Event Hub** dependency.

> MCP responses stream (SSE); MCP policies must **not** read the response body. Usage, auth, and any PII/content-safety you layer on run **inbound only**.

## API Center (optional)

Set `publishToApiCenter: true` on an asset and supply the `apiCenter` coordinates to register it (kind `mcp`/`a2a`) into Azure API Center. Off by default.