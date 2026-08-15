# 🏷️ Release Version Management Guide

This guide explains the versioning model of the Citadel Governance Hub accelerator, what each
version track in [`release.json`](../release.json) means, how versions are surfaced at runtime, and
how to plan and implement migrations when a version changes.

> [!IMPORTANT]
> **The primary accelerator deployment (`bicep/infra/main.bicep`) is for the _initial_
> implementation only.** Once the hub is established, the **[APIM Gateway Upgrade](../bicep/infra/apim-gateway-upgrade/README.md)**
> submodule is the standard, supported way to adopt new accelerator releases — it applies the new
> version in place (policies, APIs, backends, fragments, named values, and the `/version` manifest)
> **without re-provisioning** the APIM service or the surrounding landing-zone infrastructure.
> Re-running the full `main.bicep` for version upgrades is not the intended path and risks
> unnecessary churn on already-provisioned resources.

---

## Overview

The accelerator ships a single source-of-truth version manifest at the repository root:
[`release.json`](../release.json). Rather than a single monolithic version, the accelerator uses
**independent, component-scoped version tracks** so that a change in one subsystem (for example the
routing policy logic) does not force a full re-versioning of unrelated subsystems (for example usage
ingestion).

```jsonc
{
    "master-version": "1.0.2",
    "routing-version": "1.0.0",
    "backend-contract-version": "1.1.0",
    "access-contract-version": "1.2.0",
    "publish-contract-version": "1.0.0-preview",
    "gateway-upgrade-version": "1.0.0-preview",
    "usage-ingestion-version": "1.1.0"
}
```

All version tracks follow [Semantic Versioning](https://semver.org/) (`MAJOR.MINOR.PATCH`), with an
optional pre-release suffix (for example `-preview`):

- **MAJOR** — breaking change. Requires a planned migration (contract change, path change, or
  behavioral change that existing consumers/configurations depend on).
- **MINOR** — backward-compatible feature addition. Safe to adopt without consumer changes.
- **PATCH** — backward-compatible fix. Safe to adopt without consumer changes.
- **`-preview`** — the track is functional but the surface may still change before it is declared
  stable. Pin to an exact version in production and validate before upgrading.

---

## Version Tracks

| Track | Scope | What changes it | Owned by |
|-------|-------|-----------------|----------|
| **`master-version`** | The overall accelerator release. Acts as the umbrella "product" version that consumers cite when reporting the deployed release. Bumped whenever any component track has a notable change. | Any coordinated release. | Whole repo |
| **`routing-version`** | The LLM request routing logic — backend pool selection, model-to-backend resolution, load balancing, failover, alias fallback, and the dynamic routing policy fragments. | Changes to `llm-policy-fragments.*`, `llm-backend-pools.bicep`, routing/target policies. | `bicep/infra/modules/apim` |
| **`backend-contract-version`** | The shape of the **backend configuration contract** (`llmBackendConfig`) consumed during onboarding — backend types, auth types, model object properties, circuit breaker defaults. | Changes to the `llmBackendConfig` schema or `llm-backend-onboarding` parameter surface. | `bicep/infra/llm-backend-onboarding` |
| **`access-contract-version`** | The shape of the **Citadel Access Contract** — product policies, JWT/subscription access patterns, per-use-case product definitions, and the access-contract parameter surface. | Changes to `citadel-access-contracts` schema, product policy templates, or access-pattern behavior. | `bicep/infra/citadel-access-contracts` |
| **`publish-contract-version`** | The shape of the **Citadel Publish Contract** for publishing Tools (MCP) and Agents (A2A), including Foundry-hosted A2A agents. Currently `-preview`. | Changes to publish asset schemas, baseline policies, backend/auth options, usage tracking, or API Center integration. | `bicep/infra/citadel-publish-contracts` |
| **`gateway-upgrade-version`** | The in-place **APIM Gateway Upgrade** tooling used to update an existing gateway without re-provisioning. Currently `-preview`. | Changes to `bicep/infra/apim-gateway-upgrade`. | `bicep/infra/apim-gateway-upgrade` |
| **`usage-ingestion-version`** | The **usage ingestion pipeline** — Logic App workflows and the usage-ingestion Function that process usage/log streams into the reporting store. | Changes to `src/usage-ingestion-logicapp`, the usage-ingestion function, or the ingestion data contract. | `src/usage-ingestion-*` |

> [!TIP]
> The tracks are intentionally decoupled. When evaluating an upgrade, compare **each** track against
> what you currently run — a `usage-ingestion-version` bump has no bearing on your routing config,
> and vice versa.

---

## Runtime Version Endpoint

The deployed version manifest is exposed at runtime through the **Release Version API** in API
Management, so operators and consumers can confirm exactly which release a gateway is running
**without** inspecting the deployment source.

- **API:** `Release Version API` (`release-version-api`)
- **Path:** `GET /version`
- **Auth:** anonymous by default (no subscription key required) — a health/version-style endpoint
- **Response:** the verbatim contents of `release.json` as `application/json`

```bash
curl https://<your-apim-gateway-host>/version
```

The endpoint is served entirely from an APIM **mock (`return-response`)** policy — the release
manifest is embedded into the operation policy at deploy time, so there is no backend dependency and
no latency cost.

### Backend Contract Endpoint

The same API exposes a second GET operation that returns the **active LLM backend routing contract**
currently deployed on the gateway — a detailed projection of the effective onboarding
configuration, alongside the `backend-contract-version`.

- **Path:** `GET /version/backend-contract`
- **Auth:** anonymous by default (inherits the API setting)
- **Response:** `application/json` describing the live configuration

```bash
curl https://<your-apim-gateway-host>/version/backend-contract
```

The contract includes:

| Section | Contents |
|---------|----------|
| `masterVersion`, `backendContractVersion` | Versions from `release.json` |
| `apim` | APIM target coordinates (`subscriptionId`, `resourceGroupName`, `name`) |
| `circuitBreaker` | `enabled` flag + the full `defaults` (failure count/interval, trip duration, status ranges, error reasons) |
| `sessionAffinity` | `enabled` flag + the full `defaults` (cookie name, source) |
| `modelAliases` | The configured model alias definitions (name, models, strategy, weights) |
| `backends` | The **full** `llmBackendConfig` array, including every model's metadata (sku, capacity, version, api versions, timeouts, retirement dates, session-aware flags) |
| `pools` | The derived backend pools (pool name, type, and the models each serves) |

```jsonc
{
  "masterVersion": "1.0.0",
  "backendContractVersion": "1.0.0",
  "apim": { "subscriptionId": "…", "resourceGroupName": "rg-citadel-governance-hub", "name": "apim-citadel" },
  "circuitBreaker": {
    "enabled": true,
    "defaults": { "failureCount": 3, "failureInterval": "PT5M", "tripDuration": "PT1M", "acceptRetryAfter": true, "errorReasons": ["Server errors"], "statusCodeRanges": [ { "min": 429, "max": 429 }, { "min": 500, "max": 503 } ] }
  },
  "sessionAffinity": { "enabled": true, "defaults": { "cookieName": "ai-gateway-affinity", "source": "Cookie" } },
  "modelAliases": [ { "name": "gpt-advanced", "models": ["gpt-5", "gpt-4.1"], "strategy": "priority" } ],
  "backends": [
    {
      "backendId": "aif-citadel-primary",
      "backendType": "ai-foundry",
      "endpoint": "https://aif-…-0.cognitiveservices.azure.com/",
      "authType": "managed-identity",
      "supportedModels": [ { "name": "gpt-4o", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-11-20", "retirementDate": "2026-09-30" } ],
      "priority": 1, "weight": 100
    }
  ],
  "pools": [ { "poolName": "gpt-4o-pool", "poolType": "ai-foundry", "supportedModels": ["gpt-4o"] } ]
}
```

> [!IMPORTANT]
> Any inline `authConfig.secretValue` is **redacted** (`***redacted***`) before it is embedded in the
> contract. Key Vault secret URIs and named-value keys are preserved (they are references, not
> secrets). Endpoints are included so operators can see routing targets.

Unlike `GET /version` (a static mock), this operation returns the response through a **dynamically
generated policy fragment** named `backend-contract`. The fragment's JSON body is built at deploy
time from the effective onboarding configuration (`string()`-serialized Bicep object), so it always
reflects what the gateway is configured to route to.

> [!NOTE]
> The `backend-contract` fragment is (re)generated and updated by **both** the primary deployment
> **and** the LLM Backend Onboarding submodule. The onboarding submodule supplies the richest detail
> (circuit breaker, session affinity, and model aliases are onboarding features); the primary
> deployment reports session affinity and aliases as inactive until an onboarding run configures
> them. Because the operation references the fragment by id, onboarding refreshes the response
> **without** touching the Release Version API definition.

### How it gets created / updated

| Deployment | Behavior |
|------------|----------|
| **Primary accelerator** (`bicep/infra/main.bicep` → `apim.bicep`) | Creates the Release Version API (both operations) with the content of `release.json` and generates the `backend-contract` fragment from the deployed backend config. |
| **LLM Backend Onboarding** (`bicep/infra/llm-backend-onboarding/main.bicep`) | Regenerates the `backend-contract` fragment from the onboarded `llmBackendConfig`, refreshing the `GET /version/backend-contract` response. |
| **APIM Gateway Upgrade** (`bicep/infra/apim-gateway-upgrade/main.bicep`) | Creates **or** updates the Release Version API (toggle `updateReleaseVersionApi`, default `true`) and, when `updateLLMPolicyFragments` is on, refreshes the `backend-contract` fragment. |

The Release Version API is created by the shared module `bicep/infra/modules/apim/version-api.bicep`
(reads `release.json` via `loadTextContent`). The `backend-contract` fragment is produced by
`llm-policy-fragments.bicep` (present in both the primary `modules/apim` path and the LLM onboarding
`modules` path). Bump the manifest and/or change your backend config, redeploy (or run the gateway
upgrade / onboarding), and the endpoints reflect the new values.

---

## Bumping a Version

1. **Identify the affected track(s).** Only bump tracks whose component actually changed.
2. **Choose the SemVer increment** (MAJOR / MINOR / PATCH) based on the impact rules above.
3. **Bump `master-version`** whenever any track changes in a release that consumers should cite.
4. **Update [`release.json`](../release.json)** with the new values.
5. **Publish the new release.** For an **existing** hub, run the **[APIM Gateway Upgrade](../bicep/infra/apim-gateway-upgrade/README.md)**
   with the relevant feature toggles enabled — this is the standard upgrade path and updates the
   `/version` manifest in place. Only the very **first** implementation uses the primary
   `main.bicep` deployment.
6. **Validate** with `curl https://<gateway-host>/version`.

---

## Migration Strategy

### The upgrade model: initial deployment vs. release upgrades

The accelerator has two distinct lifecycle phases:

| Phase | Tooling | When |
|-------|---------|------|
| **Initial implementation** | Primary deployment — `bicep/infra/main.bicep` (`azd provision`) | Once, to stand up the hub and its landing-zone infrastructure. |
| **Release upgrades** | **[APIM Gateway Upgrade](../bicep/infra/apim-gateway-upgrade/README.md)** — `bicep/infra/apim-gateway-upgrade/main.bicep` | Every subsequent move to a new accelerator release. |

After the hub is live, **all version upgrades flow through the APIM Gateway Upgrade submodule.** It
targets an existing APIM instance and applies the new release's policies, APIs, backends, policy
fragments, named values, diagnostics, and the `/version` manifest **without re-provisioning** the
APIM service or surrounding infrastructure. Its feature toggles (e.g. `updateLLMPolicyFragments`,
`updateLLMBackends`, `updateUnifiedAiApi`, `updateReleaseVersionApi`) let you scope the upgrade to
exactly the tracks that changed.

How you migrate then depends on **which track** changed and **whether the increment is MAJOR**.

### Non-breaking (MINOR / PATCH) on any track

Adopt directly by running the **APIM Gateway Upgrade** with the relevant feature toggles enabled. No
consumer changes are required.

### `routing-version` (MAJOR)

Routing changes affect how requests reach backends (pool composition, model resolution, failover).

- Roll out to a **non-production** gateway first and run the routing/backends validation notebooks.
- Prefer the **APIM Gateway Upgrade** to update policy fragments and backend pools in place
  (`updateLLMPolicyFragments`, `updateLLMBackendPools`, `updateLLMBackends`).
- Verify load balancing, failover, and alias fallback behavior before promoting to production.

### `backend-contract-version` (MAJOR)

The `llmBackendConfig` schema changed (for example a renamed/removed property or a new required
field).

- Update your backend parameter file(s) to the new contract **before** deploying — a stale config
  against a new contract can fail validation or route incorrectly.
- Consult [LLM Backend Onboarding](../bicep/infra/llm-backend-onboarding/README.md) for the current
  schema, then re-run onboarding.

### `access-contract-version` (MAJOR)

The Citadel Access Contract product/policy surface changed.

- Review each Access Contract parameter file against the new schema.
- Re-deploy the access contracts; validate JWT and subscription access patterns per use case with
  the access-contract validation notebooks.
- See [AI Citadel Access Contracts](../bicep/infra/citadel-access-contracts/README.md).

### `publish-contract-version` (`-preview` / MAJOR)

The Publish Contract surface for MCP and A2A assets is available in Preview and may evolve.

- Pin to the exact Preview version you validated and deploy to a non-production gateway first.
- Review each Publish Contract parameter file when the schema, baseline policies, backend/auth options,
  or usage tracking changes; re-deploy affected published assets.
- Validate MCP handshakes and A2A agent-card/JSON-RPC flows before promotion.
- See the [Citadel Publish Contract Guide](../bicep/infra/citadel-publish-contracts/publish-contract-guide.md).

### `gateway-upgrade-version` (`-preview`)

The in-place upgrade tooling is evolving.

- Pin to the exact version you validated. Read the
  [APIM Gateway Upgrade Guide](../bicep/infra/apim-gateway-upgrade/README.md) release notes before
  adopting a newer upgrade tool.
- For the first run against an existing/legacy gateway, enable as many feature toggles as possible
  in a **non-production** environment to detect drift early (see the upgrade guide).

### `usage-ingestion-version` (MAJOR)

The ingestion workflows or data contract changed (for example a new field in the usage record or a
changed store schema).

- Update the Logic App / Function first, then confirm downstream reporting (Cosmos/Power BI) still
  reads correctly.
- Because ingestion is decoupled from the gateway data plane, this migration can typically be
  performed independently and without gateway downtime.

### General guidance

- **Migrate one MAJOR track at a time** where possible, to isolate risk and simplify rollback.
- **Always validate in non-production first**, then promote.
- **Record the deployed `master-version`** (e.g. from the `/version` endpoint) in your change log so
  you can correlate incidents with the exact release.

---

## Related Guides

- [APIM Gateway Upgrade Guide](../bicep/infra/apim-gateway-upgrade/README.md)
- [LLM Backend Onboarding](../bicep/infra/llm-backend-onboarding/README.md)
- [AI Citadel Access Contracts](../bicep/infra/citadel-access-contracts/README.md)
- [Resiliency Guide](./resiliency-guide.md)
