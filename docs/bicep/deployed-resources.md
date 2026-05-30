# Deployed Resources & Cost Estimates

This page answers the two questions operators always ask before approving an AI Landing Zone deployment:

1. **What does this template actually deploy?** — every resource, broken down by *always-on baseline*, *default-on (toggleable)*, *BYO-capable*, and *opt-in add-on*.
2. **What will it cost?** — an order-of-magnitude monthly estimate for three common scenarios, with the variable (token / call / data) drivers called out separately.

!!! warning "Cost figures are estimates, not a quote"
    All numbers here are **USD/month**, **East US 2 PAYG retail pricing**, **as of 2026-05-29**, with empty data and a quiet workload (~1 user). Your bill will vary with region, currency, EA/MCA discounts, reserved capacity, autoscale behavior, data volumes, model token consumption, AI Search index size, and Application Gateway capacity units. **Always validate with the [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/)** before committing.

---

## The "Standard Agent Setup" gotcha — read this first

By default the landing zone deploys **AI Foundry with the Standard Agent Setup** (`deployAiFoundry=true` + `deployAfProject=true` + `deployAAfAgentSvc=true`). The Agent Service requires its own data plane, so when this combination is on the template provisions a **second**, dedicated set of supporting resources just for Foundry:

| Resource family | Default count when Agent Service is enabled | Why |
|---|---|---|
| Azure AI Search | **2** — one for Foundry agents, one for the workload | Agent Service stores agent state, thread embeddings, and tool indices in its own Search service so workload index churn never affects agents |
| Storage account | **2** — one for Foundry artifacts, one for workload blobs | Agent files, run outputs, and Foundry connections live in the Foundry-owned account |
| Cosmos DB account | **2** — one for Foundry agent threads/state, one for workload documents | Foundry-owned account holds thread/run/message documents |
| Key Vault | **2** — one for workload secrets, one for the jumpbox VM (ZT only) | `deployVmKeyVault=true` is on by default |

!!! tip "How to opt out of the duplicate Foundry data plane"
    - **Bring your own** — set `aiSearchResourceId`, `aiFoundryStorageAccountResourceId`, and `aiFoundryCosmosDBAccountResourceId` to existing resource IDs of a **dedicated Foundry-only trio** that belongs exclusively to this Foundry instance. Don't share the Agent Service data plane with the workload or with other Foundry instances — only use BYO to reattach a trio already provisioned out-of-band for this same Foundry.
    - **Disable the Agent Service** — set `deployAAfAgentSvc=false` (and optionally `deployAfProject=false`). The Foundry account stays, but the second Search / Storage / Cosmos are not created. Use this when you only need model deployments and don't use Foundry agents.
    - **Foundry AI Search defaults to `1 partition × 1 replica`** (lowered from 3 replicas in v2.0.5; see [CHANGELOG](https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/main/CHANGELOG.md)) — scale it back up to 3 replicas in-place if you need Azure AI Search's read/write SLA.

---

## What gets deployed

The deployment is composed in five layers. Every box below maps to a real `deploy*` flag in `main.parameters.json`, so any of them can be toggled independently — the layers are purely a presentation aid.

| Layer | Purpose | Always present? |
|---|---|---|
| **Runtime apps** | The Container Apps that run your workload (orchestrator and any you add) | Yes (driven by `containerAppsList`) |
| **AI Foundry & agent data plane** | Foundry account/project, model deployments, Foundry-owned Search/Storage/Cosmos when Agent Service is on | Yes by default; the agent data plane appears only when `deployAAfAgentSvc=true` |
| **Workload data path** | Workload-owned AI Search, Storage, Cosmos, Key Vault | Yes by default, each individually toggleable / BYO-capable |
| **Common platform** | App Configuration, Container Registry, Container Apps Environment, managed identity / RBAC, Log Analytics, App Insights | Yes by default, each individually toggleable |
| **Zero Trust networking** | VNet/subnets, NSGs, private endpoints, private DNS, Azure Firewall, Jumpbox VM, VM Key Vault, Bastion, NAT Gateway | Opt-in via `networkIsolation=true` |
| **Scenario add-ons** | Application Gateway WAF v2, Azure Speech, ACR build-agent pool | Mostly opt-in (a couple are default-on) |

### Legend used below

| Marker | Meaning |
|---|---|
| ✅ **Default-on** | Provisioned automatically; turn off with the corresponding `deploy*=false` flag |
| 🔧 **BYO-capable** | Default-on, but can be replaced with an existing resource via an `existing*ResourceId` parameter (cross-subscription accepted) |
| 🟧 **Opt-in** | Off by default; set the flag to `true` to provision |
| 🔒 **ZT-only** | Only provisioned when `networkIsolation=true` |
| 🚪 **Public-ingress-only** | Only provisioned when `publicIngress.enabled=true` |

---

## Resource inventory

### Runtime apps

| Resource | Marker | Flag / parameter | Default config |
|---|---|---|---|
| Orchestrator Container App | ✅ | `containerAppsList[]` | 1 vCPU / 2 GiB, `min_replicas=1`, profile `main` (D4) |
| Additional Container Apps | 🟧 | Append entries to `containerAppsList` | One entry per app; see [Parameterization](parameterization.md) |

!!! note "Why this matters for cost"
    The default orchestrator has `min_replicas=1` and `profile_name="main"`, which pins **one D4 workload-profile node always running** (≈$290/month). If you do not need the D4 profile, remove it from `workloadProfiles` and let apps run on Consumption (which scales to zero). See the cost-reduction tips below.

### AI Foundry & agent data plane

| Resource | Marker | Flag / parameter | Default config |
|---|---|---|---|
| AI Foundry account (Cognitive Services `kind=AIServices`) | ✅ | `deployAiFoundry` | S0; billed only per token |
| AI Foundry project | ✅ | `deployAfProject` | Created inside the account |
| Model deployment: chat | ✅ | `modelDeploymentList[0]` | `gpt-5-nano`, GlobalStandard, capacity 40 |
| Model deployment: embeddings | ✅ | `modelDeploymentList[1]` | `text-embedding-3-large`, Standard, capacity 10 |
| Grounding with Bing | ✅ | `deployGroundingWithBing` | Bing Search resource, S1; **billed per query** |
| Foundry-dedicated AI Search | ✅ 🔧 | `deployAAfAgentSvc` / `aiSearchResourceId` | Standard SKU, **1 partition × 1 replica** (scale up for AI Search read/write SLA) |
| Foundry-dedicated Storage | ✅ 🔧 | `deployAAfAgentSvc` / `aiFoundryStorageAccountResourceId` | Standard_LRS, Hot |
| Foundry-dedicated Cosmos DB | ✅ 🔧 | `deployAAfAgentSvc` / `aiFoundryCosmosDBAccountResourceId` | NoSQL, autoscale |

### Workload data path

| Resource | Marker | Flag / parameter | Default config |
|---|---|---|---|
| Workload AI Search | ✅ 🔧 | `deploySearchService` / `aiSearchResourceId` | Standard SKU, **1 partition × 1 replica** |
| Workload Storage | ✅ 🔧 | `deployStorageAccount` | Standard_LRS, Hot |
| Workload Cosmos DB | ✅ 🔧 | `deployCosmosDb` | NoSQL, **serverless** (`EnableServerless`) |
| Workload Key Vault | ✅ 🔧 | `deployKeyVault` / `keyVaultResourceId` | Standard tier |
| Azure Speech | 🟧 | `deploySpeechService` | S0 (off by default) |

### Common platform services

| Resource | Marker | Flag / parameter | Default config |
|---|---|---|---|
| App Configuration | ✅ | `deployAppConfig` | Standard tier |
| Container Registry | ✅ | `deployContainerRegistry` | **Premium** (required for private endpoints) |
| Container Apps Environment | ✅ | `deployContainerEnv` | `Consumption` + `D4` workload profile (`minimumCount=0`, but pinned by `min_replicas=1` on the orchestrator) |
| Managed identity & RBAC | ✅ | `useUAI` | System-assigned by default; UAI when `useUAI=true` |
| Log Analytics workspace | ✅ 🔧 | `deployLogAnalytics` / `existingLogAnalyticsWorkspaceResourceId` | PAYG ingestion |
| Application Insights | ✅ 🔧 | `deployAppInsights` / `existingApplicationInsightsResourceId` | Workspace-based |
| ACR build-agent pool | ✅ | `deployAcrTaskAgentPool` | For ACR Tasks (S1 agent pool) |

### Zero Trust networking (only when `networkIsolation=true`)

| Resource | Marker | Flag / parameter | Default config |
|---|---|---|---|
| VNet + subnets | 🔒 🔧 | `useExistingVNet` / `deploySubnets` | Workload, PE, jumpbox, agent, ACA, NAT, Bastion subnets |
| NSGs | 🔒 | `deployNsgs` | One per subnet, locked-down rules |
| Private endpoints | 🔒 | (auto, per service) | **~13–15 PEs** — one per PE-capable resource (2× Search, 2× Storage, 2× Cosmos, KV, AppConfig, ACR, Foundry, etc.) |
| Private DNS zones (×15) | 🔒 🔧 | `existingPrivateDnsZone*ResourceId` (one parameter per zone) | All 15 zones BYO-capable individually |
| Azure Firewall | 🔒 🟧 | `deployAzureFirewall` (default `true` when ZT) | **Standard SKU**; can be turned off when reusing a hub firewall |
| Public IP (firewall) | 🔒 | (auto) | Standard, Static |
| Jumpbox VM | 🔒 🔧 | `deployJumpbox` (defaults to `networkIsolation`) / `existingJumpboxResourceId` | `Standard_D2s_v3`, Windows Server 2022 Datacenter Azure Edition, 128 GB P10 disk |
| VM Key Vault | 🔒 | `deployVmKeyVault` | Standard tier, for jumpbox secrets |
| Azure Bastion | 🔒 🔧 | `deployBastion` / `existingBastionResourceId` | **Standard** SKU |
| NAT Gateway | 🔒 🔧 | `deployNatGateway` / `existingNatGatewayResourceId` | For outbound egress when no spoke firewall |
| Public IP (NAT) | 🔒 | (auto) | Standard, Static |
| Hub peering | 🔒 | `hubIntegrationHubVnetResourceId` | Spoke→hub only; reverse peering stays operator-owned |

### Public ingress add-on (`publicIngress.enabled=true`)

| Resource | Marker | Flag / parameter | Default config |
|---|---|---|---|
| Application Gateway WAF v2 | 🚪 | `publicIngress.enabled` | WAF v2, minimum capacity (autoscales with traffic) |
| Public IP (App Gateway) | 🚪 | (auto) | Standard, Static |
| WAF policy | 🚪 | (auto) | OWASP CRS managed rule set |

See [Public Ingress](public-ingress.md) for the full topology.

---

## Estimated monthly cost — by scenario

The three scenarios correspond to the most common shapes operators ask about. Each shows:

- **Fixed monthly cost** — what you pay even with zero traffic and empty data (the resource exists and is billed by allocation).
- **Variable driver** — what makes the line grow over the fixed floor.

!!! tip "Quick mental model"
    Most of the *fixed* cost comes from a small number of allocation-based resources: the two AI Search services, Application Gateway (if any), Azure Firewall (if any), Bastion, ACR Premium, App Configuration, and any pinned D4 workload-profile node. Everything else is essentially zero at idle but scales fast with use.

### Scenario 1 — Basic deployment (public, no network isolation)

```text
networkIsolation        = false
deployAzureFirewall     = false   (auto-suppressed when NI is off)
deployJumpbox / Bastion / NatGateway = false (defaults to NI; no VNet)
publicIngress.enabled   = false
deployAAfAgentSvc       = true    (default — Standard Agent Setup)
deployAcrTaskAgentPool  = true    (default)
deployGroundingWithBing = true    (default)
```

Best for: sandbox, demo, dev/test, evaluation of the orchestrator path over a public endpoint.

| Resource | Fixed monthly | Variable driver |
|---|---:|---|
| AI Foundry account + project | $0 | Per-token model usage |
| Model: `gpt-5-nano` (GlobalStandard, cap 40) | $0 | ~$0.05 / 1M input tokens, ~$0.40 / 1M output tokens — pay-as-you-go |
| Model: `text-embedding-3-large` (Standard, cap 10) | $0 | ~$0.13 / 1M tokens |
| Grounding with Bing (S1) | $0 | ~$3 per 1,000 transactions |
| **Foundry AI Search** (Standard, 1p × 1r) | **~$245** | Index storage; queries scale with QPS. Scale to 3r for read/write SLA (~$735/mo) |
| Foundry Storage (Standard_LRS, Hot) | ~$1 | ~$0.018 / GB + ~$0.005 / 10K ops |
| Foundry Cosmos DB (autoscale) | ~$24 | Min 400 RU/s autoscale floor + storage |
| Workload AI Search (Standard, 1p × 1r) | **~$245** | Index storage; queries scale with QPS |
| Workload Storage (Standard_LRS, Hot) | ~$1 | ~$0.018 / GB + ~$0.005 / 10K ops |
| Workload Cosmos DB (serverless) | $0 | ~$0.25 / 1M RU + ~$0.25 / GB-month |
| Workload Key Vault (Standard) | $0 | ~$0.03 / 10K operations |
| Container Apps Environment — D4 workload-profile node (pinned by orchestrator `min_replicas=1`) | **~$290** | Additional D4 instances when scaled up |
| Container Apps Environment — Consumption profile | $0 | vCPU-s + GiB-s per request |
| Container Registry (**Premium**) | **~$50** | Storage above 500 GB + geo-replication if enabled |
| ACR build-agent pool (S1, on-demand) | $0 | ~$0.50 / build-hour |
| App Configuration (Standard) | **~$36** | Per-request above the included quota |
| Log Analytics workspace | $0 | ~$2.30 / GB ingested |
| Application Insights | $0 | (Bundled into Log Analytics billing) |
| **Subtotal — Basic** | **~$892 / month** | + token / data / request usage |

### Scenario 2 — Zero Trust (private, internal users only)

```text
networkIsolation        = true
deployAzureFirewall     = true     (default when NI; share hub FW to skip)
deployJumpbox           = true     (default = NI)
deployBastion           = true     (default = NI && deployJumpbox)
deployNatGateway        = true     (default = NI && deployJumpbox)
deployVmKeyVault        = true     (default)
publicIngress.enabled   = false
```

Best for: production internal workloads — users reach the app over ExpressRoute / VPN / Bastion; no public ingress.

Adds, **on top of Scenario 1**:

| Resource | Fixed monthly | Variable driver |
|---|---:|---|
| VNet + subnets + NSGs + Private DNS zones (×15) | ~$8 | $0.50 / DNS zone / mo |
| Private endpoints (~13–15) | **~$105** | ~$7.30 each + ~$0.01 / GB processed |
| **Azure Firewall (Standard)** | **~$912** | + ~$0.016 / GB processed |
| Public IP (firewall) | ~$4 | — |
| **Azure Bastion (Standard)** | **~$140** | + ~$0.09 / GB outbound |
| Jumpbox VM (`Standard_D2s_v3` + 128 GB P10) | **~$87** (~$70 VM + ~$17 disk) | — |
| VM Key Vault (Standard) | $0 | ~$0.03 / 10K operations |
| NAT Gateway | **~$32** | + ~$0.045 / GB processed |
| Public IP (NAT) | ~$4 | — |
| **Zero Trust additions subtotal** | **~$1,292 / month** | + per-GB processing |
| **Subtotal — ZTA (Basic + ZT)** | **~$2,184 / month** | + token / data / request usage |

!!! note "Where Zero Trust cost actually goes"
    Roughly **70 % of the ZT-only surcharge is Azure Firewall (~$912)**. If your platform team already operates a hub Firewall, set `deployAzureFirewall=false` and configure `hubIntegrationEgressNextHopIp=<hub-firewall-private-IP>`. The spoke then reuses the hub's firewall and the ZT delta drops to **~$380/month**. See [Hub-and-Spoke Topology](hub-and-spoke.md).

### Scenario 3 — Zero Trust + Application Gateway (external users)

```text
(everything from Scenario 2, plus)
publicIngress.enabled   = true   # exposes a private Container App via App Gateway WAF v2
```

Best for: production workloads that need to serve **external users over the public internet** while keeping the workload itself private (the frontend Container App is reachable only through the gateway).

Adds, **on top of Scenario 2**:

| Resource | Fixed monthly | Variable driver |
|---|---:|---|
| **Application Gateway WAF v2** (1 instance, minimum) | **~$250** | + ~$0.0072 / capacity-unit-hour; scales with throughput, TLS, and WAF rules |
| Public IP (App Gateway) | ~$4 | — |
| WAF policy | $0 | — |
| **App Gateway additions subtotal** | **~$254 / month** | + capacity-unit consumption |
| **Subtotal — ZTA + App Gateway (Basic + ZT + AppGW)** | **~$2,438 / month** | + token / data / request usage |

See [Public Ingress with Application Gateway](public-ingress.md) for the topology and parameters.

---

## Cost comparison at a glance

| Scenario | Fixed monthly floor | Best for |
|---|---:|---|
| **1. Basic** | **~$892** | Sandbox, demo, dev/test, public evaluation |
| **2. Zero Trust (internal)** | **~$2,184** | Production for internal users (VPN / ExpressRoute / Bastion) |
| **3. Zero Trust + App Gateway** | **~$2,438** | Production for external users with WAF-protected public ingress |

Variable model / data / processing cost applies to all three and depends entirely on traffic.

!!! info "Concrete levers to lower the floor"
    | Lever | Savings (approx.) | Trade-off |
    |---|---:|---|
    | `deployAAfAgentSvc=false` — turn off Standard Agent Setup if you don't use Foundry agents | **~$270/mo** (drops Foundry Search + Cosmos) | No Agent Service; you keep models, projects, and your own workload Search |
    | `aiSearchResourceId=<existing>` — reattach Foundry to a **dedicated Search service it already exclusively owns** (e.g. one provisioned out-of-band for this same Foundry instance) | **~$245/mo** | Only valid when the Search service is exclusively dedicated to this Foundry account; **do not share it with the workload or with other Foundry instances** |
    | Drop the `D4` workload profile (use Consumption-only) and remove `min_replicas=1` from orchestrator | **~$290/mo** | Cold-start latency on first request |
    | `deployAzureFirewall=false` + `hubIntegrationEgressNextHopIp=…` (share hub FW) | **~$912/mo** (ZT scenarios only) | Requires a hub firewall already operated by the platform team |
    | BYO Log Analytics / App Insights (`existingLogAnalyticsWorkspaceResourceId`, `existingApplicationInsightsResourceId`) | Avoids duplicate workspaces | Workspace governed centrally |
    | BYO Private DNS zones (any of the 15 `existingPrivateDnsZone*ResourceId` params) | $0.50/zone/mo + admin time | Zones owned by the platform team |
    | `deployGroundingWithBing=false` if you don't use Bing-grounded answers | $0 fixed; saves variable Bing query cost | No Bing grounding |
    | Deallocate the Jumpbox VM when idle | ~$70/mo (compute only; disk continues) | Manual stop/start |

    Stacking the first two levers in Scenario 1 takes the **Basic floor from ~$892 to ~$332/month**.

---

## Methodology and caveats

- **Pricing snapshot**: Azure retail PAYG, **East US 2**, **2026-05-29**.
- **Currency**: USD; convert at your contract rate.
- **Discounts not applied**: EA, MCA, CSP, reservations, savings plans, Azure Hybrid Benefit, dev/test rates — all of these can materially lower the floor.
- **Empty-data assumption**: Storage, Log Analytics, and Cosmos data charges are shown as ~$0 fixed because the resource itself is free at zero bytes; they grow linearly with data.
- **Quiet workload assumption**: variable token / call / processing line items are listed without a number because they depend entirely on your traffic — model the load you actually expect in the Pricing Calculator.
- **Foundry Cosmos** floor reflects the minimum autoscale band (400 RU/s) commonly used by the AVM Foundry module; the exact number depends on the Foundry CapabilityHost configuration.
- **Container Apps**: the D4 workload-profile baseline assumes 1 node remains active because the default `orchestrator` app pins `min_replicas=1` on `profile_name: "main"`. With Consumption-only deployments the baseline drops to $0.
- **Region matters**: AI Search, Azure Firewall, and Application Gateway can vary by ±20 % across regions.
- **Page is a snapshot, not a contract**: when in doubt, the [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/) is the source of truth.

## See also

- [Overview](overview.md) — high-level architecture and topology
- [Parameterization](parameterization.md) — full reference for every flag mentioned here
- [Regional Considerations](regional-considerations.md) — capacity caveats per region (AI Search, Cosmos, ACA)
- [Hub-and-Spoke Topology](hub-and-spoke.md) — how to share hub Firewall / Bastion / DNS to lower the ZT floor
- [Public Ingress (App Gateway)](public-ingress.md) — Scenario 3 details
