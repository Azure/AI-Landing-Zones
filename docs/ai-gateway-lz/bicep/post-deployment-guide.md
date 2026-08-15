# 🛠️ Post-Deployment Guide

Once the AI Citadel Governance Hub landing zone is provisioned (see the [Full Deployment Guide](./full-deployment-guide.md)), the gateway is running but **not yet serving governed traffic**. This guide covers the **day-2 activities** that turn a fresh landing zone into a production-ready governance hub, and how to **upgrade an existing gateway** to newer accelerator releases without re-provisioning.

> **Key principle:** the primary deployment (`bicep/infra/main.bicep`) is for the **initial implementation only**. All configuration below is applied through **independent submodules** and, for version upgrades, through the **[APIM Gateway Upgrade](../bicep/infra/apim-gateway-upgrade/README.md)** submodule — never by re-running `main.bicep`. See [Release Version Management](./release-version-management.md).

---

## 📖 Contents

1. [Onboard LLM Backends (Backend Contract)](#1-onboard-llm-backends-backend-contract)
2. [Onboard Use Cases (Access Contract)](#2-onboard-use-cases-access-contract)
3. [Enable Entra ID Authentication](#3-enable-entra-id-authentication)
4. [Activate Power BI Usage Reporting](#4-activate-power-bi-usage-reporting)
5. [Go Multi-Region (Cosmos DB Multi-Write)](#5-go-multi-region-cosmos-db-multi-write)
6. [Upgrade the Gateway to a Newer Release](#6-upgrade-the-gateway-to-a-newer-release)
7. [Validation](#7-validation)
8. [Related Guides](#8-related-guides)

---

## Post-Deployment Checklist

Work top-to-bottom. Steps 1–2 are **required** to serve traffic; the rest are enabled as needed.

- [ ] **1. Backends onboarded** — LLM backends, pools, routing, and circuit breakers configured → [Backend Contract](../bicep/infra/llm-backend-onboarding/README.md)
- [ ] **2. Use cases onboarded** — APIM products, subscriptions/keys, and per-use-case policies → [Access Contract](../bicep/infra/citadel-access-contracts/README.md)
- [ ] **3. Authentication enabled** *(optional)* — Entra ID JWT layered on top of API keys → [Entra ID Setup](../bicep/infra/entra-id-setup/README.md)
- [ ] **4. Usage reporting activated** *(recommended)* — Power BI dashboard connected to Cosmos DB → [Power BI Dashboard](./power-bi-dashboard.md)
- [ ] **5. Multi-region linked** *(if global)* — Cosmos DB multi-write across regions → [Cosmos Global Sync](../bicep/infra/citadel-cosmos-global-multi-master-sync/README.md)
- [ ] **6. Gateway upgraded** *(as releases ship)* — new policies/APIs/backends applied in place → [APIM Gateway Upgrade](../bicep/infra/apim-gateway-upgrade/README.md)

> All submodules use versioned Bicep parameter files (`.bicepparam`) and are DevOps/CI-CD friendly. Keep customized copies under source control, separate from the accelerator's default files.

---

## 1. Onboard LLM Backends (Backend Contract)

**What:** Register the actual LLM endpoints (Microsoft Foundry, Azure OpenAI, Amazon Bedrock, and other providers) the gateway routes to, and define load-balanced **pools**, **failover**, and **circuit breakers** — all as declarative configuration, without editing APIM policies.

**Why first:** an access contract can only grant use cases access to **models/pools that already exist**. Onboard backends before use cases.

**How:**

1. Edit the backend configuration `.bicepparam` (`llmBackendConfig`) — see the [Backend Contract README](../bicep/infra/llm-backend-onboarding/README.md).
2. Ensure APIM's user-assigned managed identity has the required roles on each backend:
   - `Cognitive Services OpenAI User` for Azure OpenAI
   - `Cognitive Services User` for Microsoft Foundry
3. Deploy the `llm-backend-onboarding` submodule.

This also refreshes the **`backend-contract`** policy fragment, so the runtime endpoint `GET /version/backend-contract` immediately reflects the live routing configuration (see [Backend Contract Endpoint](./release-version-management.md#backend-contract-endpoint)).

> **Resiliency is configured here.** Circuit breaker, session affinity, and failover defaults are applied during onboarding. For tuning guidance (per-backend overrides, alias fallback, session-aware models), see the [Resiliency Guide](./resiliency-guide.md).

📘 Module: [`bicep/infra/llm-backend-onboarding`](../bicep/infra/llm-backend-onboarding/README.md) · Concepts: [LLM Access Guide](./llm-access-guide.md)

---

## 2. Onboard Use Cases (Access Contract)

**What:** Create a governed **APIM product** per use case (`<serviceCode>-<BU>-<UseCase>-<ENV>`) with an auto-generated **subscription key**, attached APIs, and per-use-case policies (allowed models/pools, JWT requirement, PII, throttling, usage dimensions). Optionally stores the endpoint/key in **Key Vault** and creates a **Microsoft Foundry connection** for agents.

**How:**

1. Define the use case(s) in an access contract `.bicepparam` and (optionally) a policy `.xml` — see the [Access Contract README](../bicep/infra/citadel-access-contracts/README.md).
2. Set access controls per product (e.g., `allowedModels`, `allowedBackendPools`, `jwtAuth.enabled`).
3. Deploy the `citadel-access-contracts` submodule; distribute the generated API key (or Key Vault reference) to the consuming team.

> **Business continuity option.** A single access contract can be **mirrored across additional gateways, Key Vaults, and Foundry instances** while **reusing the same subscription `api-key`** — ideal behind a global load balancer. See [Access Contract resiliency](../bicep/infra/citadel-access-contracts/access-contract-resiliency-guide.md) and the [BC/DR Guide](./business-continuity-dr-guide.md).

📘 Module: [`bicep/infra/citadel-access-contracts`](../bicep/infra/citadel-access-contracts/README.md)

---

## 3. Enable Entra ID Authentication

**What:** Layer **Microsoft Entra ID (JWT)** authentication on top of the always-required API key. When enabled, APIM validates a JWT Bearer token before routing to backends.

**How (standalone — no redeployment of the landing zone):**

```bash
cd bicep/infra/entra-id-setup
pwsh ./setup.ps1
```

The script creates the Entra ID app registration + service principal, stores a client secret in Key Vault (`ENTRA-APP-CLIENT-SECRET`), and **directly configures the APIM JWT named values** (`JWT-TenantId`, `JWT-AppRegistrationId`, `JWT-Issuer`, `JWT-OpenIdConfigUrl`). APIM is JWT-ready immediately afterward.

**Prerequisites:** deployer needs `Application.ReadWrite.All` (or Application Developer role), `Key Vault Secrets Officer` on the hub Key Vault, and `API Management Service Contributor` on APIM. Key Vault public network access may need to be temporarily enabled to run the script.

JWT is then **enforced per use case** by setting `jwtAuth.enabled: true` in the relevant access contract (Step 2).

📘 Module: [`bicep/infra/entra-id-setup`](../bicep/infra/entra-id-setup/README.md) · Concepts: [Entra ID Authentication](./entraid-auth-validation.md) · [JWT Client Identity & Permissions](./jwt-client-identity-permissions.md)

---

## 4. Activate Power BI Usage Reporting

**What:** Turn the LLM usage telemetry streamed to Cosmos DB by the usage-ingestion pipeline into cost-attribution, chargeback, and FinOps dashboards.

**How:**

1. Install **Power BI Desktop** and ensure your machine can reach Cosmos DB (allow your public IP on the Cosmos DB firewall).
2. Seed the **`model-pricing`** container using the sample [model-pricing-generated-extended.json](../src/usage-reports/model-pricing-generated-extended.json), then review/adjust prices for the models you actually use.
3. Open the `Citadel-Governance-Hub-Usage-Dashboard-V1.1-Incremental.pbix` template and point it at your Cosmos DB account.
4. *(Optional)* Configure `customDimension1` / `customDimension2` per access contract to enrich reports — see [Activating custom dimensions](./power-bi-dashboard.md#activating-custom-dimensions).

📘 Guide: [Power BI Dashboard](./power-bi-dashboard.md)

---

## 5. Go Multi-Region (Cosmos DB Multi-Write)

**Only for global / multi-region deployments.** If you deployed the hub in more than one region (BC/DR Option 1 — multiple full deployments), link each region's Cosmos DB account into a single **multi-write, globally distributed** topology so usage written in any region is globally readable for chargeback and reporting.

**How:**

1. Deploy an independent Governance Hub per region (repeat the [Full Deployment Guide](./full-deployment-guide.md)).
2. Configure the secondary-region Logic Apps to use distinct `Export-Config` ids so regions don't overwrite each other's usage exports (see prerequisites in the module README).
3. Deploy [`citadel-cosmos-global-multi-master-sync`](../bicep/infra/citadel-cosmos-global-multi-master-sync/README.md) to align all linked accounts to the same write-region set.

This pairs with the [Access Contract resiliency feature](../bicep/infra/citadel-access-contracts/access-contract-resiliency-guide.md) (same key across gateways) and per-region backend routing.

📘 Module: [`bicep/infra/citadel-cosmos-global-multi-master-sync`](../bicep/infra/citadel-cosmos-global-multi-master-sync/README.md) · Guide: [BC/DR Guide](./business-continuity-dr-guide.md)

---

## 6. Upgrade the Gateway to a Newer Release

As the accelerator evolves, adopt new releases on an **already-provisioned** gateway using the **APIM Gateway Upgrade** submodule — it applies new policies, APIs, backends, fragments, named values, and the `/version` manifest **in place**, without re-provisioning APIM or the surrounding landing zone.

**Plan the upgrade using version tracks.** The accelerator uses independent, component-scoped versions in [`release.json`](../release.json) (`master-version`, `routing-version`, `backend-contract-version`, `access-contract-version`, `publish-contract-version`, `gateway-upgrade-version`, `usage-ingestion-version`). Compare **each** track against what you run today and read the [Release Version Management Guide](./release-version-management.md) migration notes for any `MAJOR` bump or Preview track change.

**Confirm what is deployed at runtime** (no source inspection needed):

```bash
curl https://<your-apim-gateway-host>/version
curl https://<your-apim-gateway-host>/version/backend-contract
```

**How:**

1. Sync your local `original` branch with upstream and merge into your environment branch (via Pull Request).
2. Review the [APIM Gateway Upgrade README](../bicep/infra/apim-gateway-upgrade/README.md) — feature flags let you scope what is updated. Run against **non-production first**.
3. If your gateway predates some supporting services (or the APIM was not created by this accelerator), first run the companion `supporting-services.bicep` — see [gateway-ecosystem-upgrade-guide.md](../bicep/infra/apim-gateway-upgrade/gateway-ecosystem-upgrade-guide.md).
4. Deploy the upgrade, then re-run [Backend Contract onboarding](#1-onboard-llm-backends-backend-contract) if routing fragments changed, and re-check `/version`.

> ⚠️ The `gateway-upgrade-version` track is currently `-preview` — pin to an exact version in production and validate before upgrading.

> ⚠️ The `publish-contract-version` track is also `-preview` — review and validate MCP/A2A contract changes before re-deploying published assets.

📘 Module: [`bicep/infra/apim-gateway-upgrade`](../bicep/infra/apim-gateway-upgrade/README.md) · Guide: [Release Version Management](./release-version-management.md)

---

## 7. Validation

Use the validation notebooks under the [`/validation`](../validation/) folder to verify each step:

| Notebook | Validates |
|----------|-----------|
| [llm-backend-onboarding-runner.ipynb](../validation/llm-backend-onboarding-runner.ipynb) | Backend onboarding, routing, and connectivity |
| [citadel-access-contracts-tests.ipynb](../validation/citadel-access-contracts-tests.ipynb) | Access contract behavior and model access |
| [citadel-jwt-authentication-tests.ipynb](../validation/citadel-jwt-authentication-tests.ipynb) | Entra ID / JWT enforcement per use case |
| [citadel-pii-processing-tests.ipynb](../validation/citadel-pii-processing-tests.ipynb) | PII detection / masking policies |

---

## 8. Related Guides

- [Full Deployment Guide](./full-deployment-guide.md) — provision the landing zone (prerequisite for this guide)
- [Citadel Sizing Guide](./citadel-sizing-guide.md) — T-shirt sizing and SKU selection
- [Resiliency Guide](./resiliency-guide.md) — circuit breaking, session affinity, failover, error handling
- [Business Continuity & DR Guide](./business-continuity-dr-guide.md) — multi-region topologies and recovery objectives
- [Release Version Management](./release-version-management.md) — version tracks and migration planning
- [LLM Access Guide](./llm-access-guide.md) · [PII Masking](./pii-masking-apim.md) · [Throttling Events Handling](./throttling-events-handling.md)

---

**Your AI Citadel Governance Hub is now serving governed AI traffic. Iterate on backends, use cases, and releases using the submodules above — never by re-provisioning the landing zone.** 🎉
