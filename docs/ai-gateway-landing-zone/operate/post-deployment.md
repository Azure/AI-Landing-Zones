---
render_macros: false
---

# Post-Deployment Guide

Once the AI Citadel Governance Hub landing zone is provisioned (see the [Full Deployment Guide](../deploy/bicep-full-deployment.md)), the gateway is running but **not yet serving governed traffic**. This guide covers the **day-2 activities** that turn a fresh landing zone into a production-ready governance hub, and how to **upgrade an existing gateway** to newer accelerator releases without re-provisioning.

> **Key principle:** the primary deployment (`bicep/infra/main.bicep`) is for the **initial implementation only**. All configuration below is applied through **independent submodules** and, for version upgrades, through the **[APIM Gateway Upgrade](gateway-upgrade.md)** submodule — never by re-running `main.bicep`. See [Release Version Management](release-version-management.md).

---

## Contents

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

- [ ] **1. Backends onboarded** — LLM backends, pools, routing, and circuit breakers configured → [Backend Contract](../contracts/backend-contracts-bicep.md)
- [ ] **2. Use cases onboarded** — APIM products, subscriptions/keys, and per-use-case policies → [Access Contract](../contracts/access-contracts-bicep.md)
- [ ] **3. Authentication enabled** *(optional)* — Entra ID JWT layered on top of API keys → [Entra ID Setup](../security/entra-id-setup.md)
- [ ] **4. Usage reporting activated** *(recommended)* — Power BI dashboard connected to Cosmos DB → [Power BI Dashboard](../observability/power-bi-dashboard.md)
- [ ] **5. Multi-region linked** *(if global)* — Cosmos DB multi-write across regions → [Cosmos Global Sync](cosmos-multi-region-sync.md)
- [ ] **6. Gateway upgraded** *(as releases ship)* — new policies/APIs/backends applied in place → [APIM Gateway Upgrade](gateway-upgrade.md)
- [ ] **Logic App private connectivity verified** *(when enabled)* - website/SCM DNS, workflow publishing, public access restrictions, and ingestion health checked using the [private connectivity checklist](#logic-app-private-connectivity-checks).

> All submodules use versioned Bicep parameter files (`.bicepparam`) and are DevOps/CI-CD friendly. Keep customized copies under source control, separate from the accelerator's default files.

---

## 1. Onboard LLM Backends (Backend Contract)

**What:** Register the actual LLM endpoints (Microsoft Foundry, Azure OpenAI, Amazon Bedrock, and other providers) the gateway routes to, and define load-balanced **pools**, **failover**, and **circuit breakers** — all as declarative configuration, without editing APIM policies.

**Why first:** an access contract can only grant use cases access to **models/pools that already exist**. Onboard backends before use cases.

**How:**

1. Edit the backend configuration `.bicepparam` (`llmBackendConfig`) — see the [Backend Contract README](../contracts/backend-contracts-bicep.md).
2. Ensure APIM's user-assigned managed identity has the required roles on each backend:
   - `Cognitive Services OpenAI User` for Azure OpenAI
   - `Cognitive Services User` for Microsoft Foundry
3. Deploy the `llm-backend-onboarding` submodule.

This also refreshes the **`backend-contract`** policy fragment, so the runtime endpoint `GET /version/backend-contract` immediately reflects the live routing configuration (see [Backend Contract Endpoint](release-version-management.md#backend-contract-endpoint)).

> **Resiliency is configured here.** Circuit breaker, session affinity, and failover defaults are applied during onboarding. For tuning guidance (per-backend overrides, alias fallback, session-aware models), see the [Resiliency Guide](../resiliency/resiliency.md).

📘 Module: [`bicep/infra/llm-backend-onboarding`](../contracts/backend-contracts-bicep.md) · Concepts: [LLM Access Guide](../apis/llm-access.md)

---

## 2. Onboard Use Cases (Access Contract)

**What:** Create a governed **APIM product** per use case (`<serviceCode>-<BU>-<UseCase>-<ENV>`) with an auto-generated **subscription key**, attached APIs, and per-use-case policies (allowed models/pools, JWT requirement, PII, throttling, usage dimensions). Optionally stores the endpoint/key in **Key Vault** and creates a **Microsoft Foundry connection** for agents.

**How:**

1. Define the use case(s) in an access contract `.bicepparam` and (optionally) a policy `.xml` — see the [Access Contract README](../contracts/access-contracts-bicep.md).
2. Set access controls per product (e.g., `allowedModels`, `allowedBackendPools`, `jwtAuth.enabled`).
3. Deploy the `citadel-access-contracts` submodule; distribute the generated API key (or Key Vault reference) to the consuming team.

> **Business continuity option.** A single access contract can be **mirrored across additional gateways, Key Vaults, and Foundry instances** while **reusing the same subscription `api-key`** — ideal behind a global load balancer. See [Access Contract resiliency](../contracts/access-contracts-resiliency.md) and the [BC/DR Guide](../resiliency/business-continuity-dr.md).

📘 Module: [`bicep/infra/citadel-access-contracts`](../contracts/access-contracts-bicep.md)

---

## 3. Enable Entra ID Authentication

**What:** Layer **Microsoft Entra ID (JWT)** authentication on top of the always-required API key. When enabled, APIM validates a JWT Bearer token before routing to backends.

**How (standalone — no redeployment of the landing zone):**

```bash
cd bicep/infra/entra-id-setup
pwsh ./setup.ps1
```

The script creates the Entra ID app registration + service principal, stores a client secret in Key Vault (`ENTRA-APP-CLIENT-SECRET`), and **directly configures the APIM JWT named values** (`JWT-TenantId`, `JWT-AppRegistrationId`, `JWT-Issuer`, `JWT-OpenIdConfigUrl`). APIM is JWT-ready immediately afterward.

**Prerequisites:** run as the Azure CLI user who will execute JWT validation, with
application-management and app-role-assignment permissions (for example Cloud
Application Administrator), `Key Vault Secrets Officer` on the hub Key Vault, and
`API Management Service Contributor` on APIM. Application Developer alone does
not cover the validation assignments. Key Vault public network access may need
to be temporarily enabled to run the script.

Setup also prepares the application, current-user and missing-model-role test
identities. The [JWT notebook](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-jwt-authentication-tests.ipynb)
then loads the selected azd environment and acquires/decodes all three tokens
without manual fields. Conditional access or expired sessions still require a
valid user sign-in; the notebook reports that requirement explicitly.

JWT is then **enforced per use case** by setting `jwtAuth.enabled: true` in the relevant access contract (Step 2).

📘 Module: [`bicep/infra/entra-id-setup`](../security/entra-id-setup.md) · Concepts: [Entra ID Authentication](../security/entra-id-authentication.md) · [JWT Client Identity & Permissions](../security/jwt-client-identity.md)

---

## 4. Activate Power BI Usage Reporting

**What:** Turn the LLM usage telemetry streamed to Cosmos DB by the usage-ingestion pipeline into cost-attribution, chargeback, and FinOps dashboards.

**How:**

1. Install **Power BI Desktop** and ensure your machine can reach Cosmos DB (allow your public IP on the Cosmos DB firewall).
2. Seed the **`model-pricing`** container using the sample [model-pricing-generated-extended.json](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/src/usage-reports/model-pricing-generated-extended.json), then review/adjust prices for the models you actually use.
3. Open the `Citadel-Governance-Hub-Usage-Dashboard-V1.1-Incremental.pbix` template and point it at your Cosmos DB account.
4. *(Optional)* Configure `customDimension1` / `customDimension2` per access contract to enrich reports — see [Activating custom dimensions](../observability/power-bi-dashboard.md#activating-custom-dimensions).

📘 Guide: [Power BI Dashboard](../observability/power-bi-dashboard.md)

---

## 5. Go Multi-Region (Cosmos DB Multi-Write)

**Only for global / multi-region deployments.** If you deployed the hub in more than one region (BC/DR Option 1 — multiple full deployments), link each region's Cosmos DB account into a single **multi-write, globally distributed** topology so usage written in any region is globally readable for chargeback and reporting.

**How:**

1. Deploy an independent Governance Hub per region (repeat the [Full Deployment Guide](../deploy/bicep-full-deployment.md)).
2. Configure the secondary-region Logic Apps to use distinct `Export-Config` ids so regions don't overwrite each other's usage exports (see prerequisites in the module README).
3. Deploy [`citadel-cosmos-global-multi-master-sync`](cosmos-multi-region-sync.md) to align all linked accounts to the same write-region set.

This pairs with the [Access Contract resiliency feature](../contracts/access-contracts-resiliency.md) (same key across gateways) and per-region backend routing.

📘 Module: [`bicep/infra/citadel-cosmos-global-multi-master-sync`](cosmos-multi-region-sync.md) · Guide: [BC/DR Guide](../resiliency/business-continuity-dr.md)

---

## 6. Upgrade the Gateway to a Newer Release

As the accelerator evolves, adopt new releases on an **already-provisioned** gateway using the **APIM Gateway Upgrade** submodule — it applies new policies, APIs, backends, fragments, named values, and the `/version` manifest **in place**, without re-provisioning APIM or the surrounding landing zone.

**Plan the upgrade using version tracks.** The accelerator uses independent, component-scoped versions in [`release.json`](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/release.json) (`master-version`, `routing-version`, `backend-contract-version`, `access-contract-version`, `publish-contract-version`, `gateway-upgrade-version`, `usage-ingestion-version`). Compare **each** track against what you run today and read the [Release Version Management Guide](release-version-management.md) migration notes for any `MAJOR` bump or Preview track change.

**Confirm what is deployed at runtime** (no source inspection needed):

```bash
curl https://<your-apim-gateway-host>/version
curl https://<your-apim-gateway-host>/version/backend-contract
```

**How:**

1. Sync your local `original` branch with upstream and merge into your environment branch (via Pull Request).
2. Review the [APIM Gateway Upgrade README](gateway-upgrade.md) — feature flags let you scope what is updated. Run against **non-production first**.
3. If your gateway predates some supporting services (or the APIM was not created by this accelerator), first run the companion `supporting-services.bicep` — see [Gateway ecosystem upgrade guide](gateway-ecosystem-upgrade.md).
4. Deploy the upgrade, then re-run [Backend Contract onboarding](#1-onboard-llm-backends-backend-contract) if routing fragments changed, and re-check `/version`.

> ⚠️ The `gateway-upgrade-version` track is currently `-preview` — pin to an exact version in production and validate before upgrading.

> ⚠️ The `publish-contract-version` track is also `-preview` — review and validate MCP/A2A contract changes before re-deploying published assets.

📘 Module: [`bicep/infra/apim-gateway-upgrade`](gateway-upgrade.md) · Guide: [Release Version Management](release-version-management.md)

---

## 7. Validation

### Logic App private connectivity checks

When `logicAppUsePrivateEndpoint = true`, complete these checks after provisioning and workflow publishing. The flags default to `false` / `true` for endpoint creation / public access; see the [parameter reference](../deploy/bicep-parameter-files.md#logic-app-private-access) and [publishing prerequisites](../deploy/bicep-full-deployment.md#private-only-logic-app-publishing).

- [ ] The Logic App private endpoint connection is **Approved**, targets the `sites` subresource, and uses the private-endpoint subnet rather than the delegated outbound integration subnet.
- [ ] From the publishing runner and administration network, both `<app>.azurewebsites.net` and `<app>.scm.azurewebsites.net` resolve to the endpoint's private IP and are reachable over HTTPS. Confirm the `privatelink.azurewebsites.net` zone group and both records, plus any required links or forwarding.
- [ ] Authenticated workflow publishing succeeds through private SCM, and the expected workflows are present and enabled. Infrastructure deployment success alone is not sufficient.
- [ ] For private-only mode, the site's `publicNetworkAccess` is `Disabled`. From a client without private connectivity, confirm website and SCM access are blocked by the public-network restriction; an authentication error or missing-route response alone is not proof. Skip this rejection check when public access is intentionally enabled for staged verification.
- [ ] Expected Event Hub and scheduled ingestion workflows run successfully, fresh usage records reach Cosmos DB, and Event Hub backlog is not accumulating unexpectedly.
- [ ] Storage access and monitoring connections remain healthy, logs continue to arrive, and there are no new dependency connectivity errors. Confirm other services' access settings and outbound integration remain unchanged.

**Existing-app maintenance:** Do not rerun the main or resource-group accelerator templates to convert an existing hub. Plan a separately approved, narrowly scoped networking change; the gateway-upgrade supporting-services templates do not expose these flags. Changes can restart the app or delay ingestion, so validate recovery rather than assuming zero disruption. In an incremental ARM deployment, setting `logicAppUsePrivateEndpoint = false` does not delete an existing endpoint; removal requires a separate reviewed operation. Any temporary restoration of public access requires owner and policy approval.

### Governance validation

Use the validation notebooks under the [`/validation`](../validation/notebooks-bicep.md) folder to verify each step:

| Notebook | Validates |
|----------|-----------|
| [llm-backend-onboarding-runner.ipynb](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/llm-backend-onboarding-runner.ipynb) | Backend onboarding, routing, and connectivity |
| [citadel-access-contracts-tests.ipynb](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-access-contracts-tests.ipynb) | Access contract behavior and model access |
| [citadel-jwt-authentication-tests.ipynb](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-jwt-authentication-tests.ipynb) | Entra ID / JWT enforcement per use case |
| [citadel-pii-processing-tests.ipynb](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-pii-processing-tests.ipynb) | PII detection / masking policies |

---

## 8. Related Guides

- [Full Deployment Guide](../deploy/bicep-full-deployment.md) — provision the landing zone (prerequisite for this guide)
- [Citadel Sizing Guide](../plan/sizing-guide.md) — T-shirt sizing and SKU selection
- [Resiliency Guide](../resiliency/resiliency.md) — circuit breaking, session affinity, failover, error handling
- [Business Continuity & DR Guide](../resiliency/business-continuity-dr.md) — multi-region topologies and recovery objectives
- [Release Version Management](release-version-management.md) — version tracks and migration planning
- [LLM Access Guide](../apis/llm-access.md) · [PII Masking](../security/pii-masking.md) · [Throttling Events Handling](../observability/throttling-events.md)

---

**Your AI Citadel Governance Hub is now serving governed AI traffic. Iterate on backends, use cases, and releases using the submodules above — never by re-provisioning the landing zone.** 🎉
