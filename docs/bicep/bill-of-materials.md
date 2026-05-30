# Bill of Materials

This page answers two questions operators ask before approving a deployment:

1. **What does the AI Landing Zone actually deploy?** — broken down by *always-on baseline*, *default-on but customizable*, and *opt-in add-on*.
2. **What will it cost?** — an order-of-magnitude monthly estimate for three common scenarios, with the variable (token / call / data) components called out separately.

!!! warning "Cost estimates are illustrative, not a quote"
    All cost figures on this page are **estimates in USD**, based on **East US 2 PAYG retail pricing as of 2026-05-29**, with empty data and zero traffic except where noted. Your actual bill will vary with region, currency, EA / MCA discounts, reserved capacity, autoscale behavior, data volumes, model token consumption, and Application Gateway capacity units. **Always validate with the [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/)** before committing to a deployment.

---

## What gets deployed

The landing zone is composed of four layers. Every box below maps to a real `deploy*` flag in `main.parameters.json`, so any of them can be toggled independently — the layers are just a presentation aid.

| Layer | Purpose | Always present? |
|---|---|---|
| **Runtime apps** | The Container Apps that run your workload (frontend, orchestrator, ingestion, MCP, …) | Yes (driven by `containerAppsList`) |
| **AI Foundry & data path** | AI Foundry account/project, model deployments, AI Search, Cosmos DB, Storage | Yes by default, each individually toggleable |
| **Common platform** | App Configuration, Container Registry, Container Apps Environment, Key Vault, Log Analytics, App Insights, managed identity / RBAC | Yes by default, each individually toggleable |
| **Zero Trust networking** | VNet/subnets, NSGs, private endpoints, private DNS, Azure Firewall, Jumpbox VM, Bastion, NAT Gateway | Opt-in via `networkIsolation=true` |
| **Scenario add-ons** | Application Gateway WAF v2, Bing Grounding, Azure Speech, agentic retrieval, MCP | Opt-in per flag |

### Legend used in the tables below

| Marker | Meaning |
|---|---|
| ✅ **Default-on** | Provisioned automatically; turn off with the corresponding `deploy*=false` flag |
| 🔧 **BYO-capable** | Default-on, but can be replaced with an existing resource via an `existing*ResourceId` parameter (cross-subscription IDs accepted) |
| 🟧 **Opt-in** | Off by default; set the corresponding flag to `true` to provision |
| 🔒 **ZT-only** | Only provisioned when `networkIsolation=true` |
| 🚪 **Public-ingress-only** | Only provisioned when `publicIngress.enabled=true` |

---

## Resource inventory

### Runtime apps

| Resource | Marker | Flag / parameter | Notes |
|---|---|---|---|
| Frontend Container App | ✅ | `containerAppsList[]` | Public-facing UI / API |
| Orchestrator Container App | ✅ | `containerAppsList[]` | Workflow / agent orchestrator |
| Ingestion Container App | ✅ | `containerAppsList[]` | Document and data ingestion |
| MCP server Container App | ✅ | `deployMcp` | Model Context Protocol endpoint |

### AI Foundry & data path

| Resource | Marker | Flag / parameter | Notes |
|---|---|---|---|
| AI Foundry account | ✅ | `deployAiFoundry` | Cognitive Services account (`kind=AIServices`) |
| AI Foundry project | ✅ | `deployAiFoundry` | Project hosting model deployments |
| Model deployments | ✅ | `modelDeploymentList` | Defaults: `gpt-5-nano` (GlobalStandard, capacity 40) + `text-embedding-3-large` (Standard, capacity 10) |
| Foundry Storage | 🔧 | `aiFoundryStorageAccountResourceId` | BYO Storage account for Foundry artifacts |
| Foundry AI Search | 🔧 | `aiSearchResourceId` | BYO Search service used by Foundry |
| Foundry Cosmos DB | 🔧 | `aiFoundryCosmosDBAccountResourceId` | BYO Cosmos account used by Foundry |
| Workload AI Search | 🔧 | `deploySearchService` | Standard SKU, 1 replica, 1 partition |
| Workload Storage | 🔧 | `deployStorageAccount` | Standard_LRS, Hot tier |
| Workload Cosmos DB | 🔧 | `deployCosmosDb` | NoSQL, serverless or provisioned-autoscale |
| Solution Key Vault | 🔧 | `deployKeyVault` / `keyVaultResourceId` | Standard tier |

### Common platform services

| Resource | Marker | Flag / parameter | Notes |
|---|---|---|---|
| App Configuration | ✅ | `deployAppConfig` | Standard tier |
| Container Apps Environment | ✅ | `deployContainerEnv` | Consumption + `D4` workload profile, `minimumCount=0` |
| Container Apps | ✅ | `deployContainerApps` | Apps from `containerAppsList` |
| Container Registry | ✅ | `deployContainerRegistry` | Premium tier (required for private endpoints) |
| Managed identity & RBAC | ✅ | `useUAI` | System-assigned by default; UAI when `useUAI=true` |
| Log Analytics workspace | 🔧 | `deployLogAnalytics` / `existingLogAnalyticsWorkspaceResourceId` | Pay-as-you-go ingestion |
| Application Insights | 🔧 | `deployAppInsights` / `existingApplicationInsightsResourceId` | Workspace-based |

### Zero Trust networking (only when `networkIsolation=true`)

| Resource | Marker | Flag / parameter | Notes |
|---|---|---|---|
| VNet + subnets | 🔒 | `useExistingVNet` / `deploySubnets` | Workload, PE, jumpbox, agent, ACA, NAT, Bastion |
| Private endpoints | 🔒 | (auto, per service) | One per private-endpoint-capable resource |
| Private DNS zones (×15) | 🔒 🔧 | `existingPrivateDnsZone*ResourceId` | All 15 BYO-capable individually |
| NSGs | 🔒 | `deployNsgs` | Per-subnet rules |
| Azure Firewall | 🔒 | `deployAzureFirewall` (default `true` when ZT) | Standard SKU |
| Jumpbox VM | 🔒 🔧 | `deployJumpbox` / `existingJumpboxResourceId` | Default `Standard_D2s_v3`, Windows 2022 |
| Azure Bastion | 🔒 🔧 | `deployBastion` / `existingBastionResourceId` | Standard SKU |
| NAT Gateway | 🔒 🔧 | `deployNatGateway` / `existingNatGatewayResourceId` | For outbound egress when no firewall |
| Private ACR build pool | 🟧 🔒 | `deployAcrTaskAgentPool` | For ACR Tasks inside the VNet |
| Hub peering | 🔒 | `hubIntegrationHubVnetResourceId` | Spoke→hub; reverse peering is operator-owned |

### Scenario add-ons

| Resource | Marker | Flag / parameter | Notes |
|---|---|---|---|
| Application Gateway WAF v2 | 🚪 | `publicIngress.enabled` | Public ingress for a private Container App. See [Public Ingress](public-ingress.md). |
| Bing Grounding | 🟧 | `deployGroundingWithBing` | Bing Search resource for grounding |
| Azure Speech | 🟧 | (via app config / Foundry) | S0 tier |
| Agentic retrieval | 🟧 | (via Foundry project) | No extra resource; uses AI Search + Foundry |

---

## Estimated monthly cost — by scenario

The three scenarios below correspond to the most common deployment shapes operators ask about. **All figures are USD/month, East US 2 retail PAYG, as of 2026-05-29.** Each scenario shows:

- **Fixed-floor cost** — what you pay even with zero traffic and empty data (the resource exists and is billed by allocation, not usage).
- **Variable cost drivers** — line items billed per token / per call / per GB ingested. The number you see is a **minimum** assuming a quiet workload (~1 user, light traffic); these scale up with actual usage and can dominate the bill at scale.

!!! tip "How to read these tables"
    The **Fixed monthly** column is the floor you commit to by deploying the resource. The **Variable driver** column tells you what makes it grow. Always re-run the [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/) with your own region and traffic assumptions.

### Scenario 1 — Basic deployment (public, no network isolation)

```
networkIsolation = false
deployAzureFirewall = false  (suppressed when NI is off)
deployJumpbox / deployBastion / deployNatGateway = false (no VNet)
publicIngress.enabled = false
```

Best for: sandboxes, demos, dev/test, evaluation of the GPT-RAG runtime path on a public endpoint.

| Resource | Fixed monthly | Variable driver |
|---|---:|---|
| AI Foundry account + project | $0 | Per-token model usage |
| Model: gpt-5-nano (GlobalStandard, cap 40) | $0 | ~$0.05 / 1M input tokens, ~$0.40 / 1M output tokens — billed per token, no reservation |
| Model: text-embedding-3-large (Standard, cap 10) | $0 | ~$0.13 / 1M tokens |
| AI Search (Standard S1, 1×1) | **~$245** | Storage / queries scale with index size |
| Cosmos DB (NoSQL, serverless) | $0 | ~$0.25 / 1M RU + $0.25 / GB-month |
| Storage account (Standard_LRS, Hot) | ~$1 | ~$0.018 / GB + ~$0.005 / 10K ops |
| Container Apps Environment (Consumption only) | $0 | vCPU-s + GiB-s per request |
| Container Apps (3–4 apps) | $0–$30 | vCPU-s + GiB-s; scales to zero when idle |
| Container Registry (Premium) | **~$50** | Storage above 500 GB + geo-replication if enabled |
| App Configuration (Standard) | **~$36** | Per-request above the included quota |
| Key Vault (Standard) | $0 | ~$0.03 / 10K operations |
| Log Analytics workspace | $0 | ~$2.30 / GB ingested |
| Application Insights | $0 | (Bundled into Log Analytics billing) |
| **Subtotal — Basic** | **~$332 / month** | + token / data / request usage |

### Scenario 2 — Zero Trust (private, internal users only)

```
networkIsolation = true
deployAzureFirewall = true
deployJumpbox = true
deployBastion = true
deployNatGateway = true     (or omit if firewall covers egress)
publicIngress.enabled = false
```

Best for: production internal workloads — users reach the app over ExpressRoute / VPN / Bastion; no public ingress.

Adds, on top of Scenario 1:

| Resource | Fixed monthly | Variable driver |
|---|---:|---|
| VNet + subnets + NSGs + Private DNS zones | $0 | — |
| Private endpoints (~10) | **~$73** | ~$7.30 each (≈10) + ~$0.01 / GB processed |
| Azure Firewall (Standard) | **~$912** | + ~$0.016 / GB processed |
| Public IP (firewall) | ~$4 | — |
| Azure Bastion (Standard) | **~$140** | + ~$0.09 / GB outbound |
| Jumpbox VM (`Standard_D2s_v3` + 128 GB Premium SSD P10) | **~$87** (~$70 VM + ~$17 disk) | — |
| NAT Gateway | **~$32** | + ~$0.045 / GB processed |
| Public IP (NAT) | ~$4 | — |
| **Zero Trust additions subtotal** | **~$1,252 / month** | + per-GB processing |
| **Subtotal — ZTA (Basic + ZT)** | **~$1,584 / month** | + token / data / request usage |

!!! note "Where Zero Trust cost actually goes"
    Roughly **75% of the ZT-only surcharge is Azure Firewall**. If your platform team already operates a hub Firewall, set `deployAzureFirewall=false` and `hubIntegrationEgressNextHopIp=<hub-firewall-private-IP>` — the spoke then reuses the hub's firewall and the ZT-only delta drops to ~$340/month. The [Hub-and-Spoke Topology](hub-and-spoke.md) runbook covers this pattern.

### Scenario 3 — Zero Trust + Application Gateway (external users)

```
networkIsolation = true
deployAzureFirewall = true
deployJumpbox / deployBastion / deployNatGateway = true
publicIngress.enabled = true   # exposes a private Container App via App Gateway WAF v2
```

Best for: production workloads that need to serve **external users over the public internet** while keeping the workload itself private (frontend Container App is reachable only through the gateway).

Adds, on top of Scenario 2:

| Resource | Fixed monthly | Variable driver |
|---|---:|---|
| Application Gateway WAF v2 (1 instance, minimum) | **~$250** | + ~$0.0072 / capacity-unit-hour; scales with throughput, TLS, and WAF rule count |
| Public IP (App Gateway) | ~$4 | — |
| WAF policy | $0 | — |
| **App Gateway additions subtotal** | **~$254 / month** | + capacity-unit consumption |
| **Subtotal — ZTA + App Gateway (Basic + ZT + AppGW)** | **~$1,838 / month** | + token / data / request usage |

See [Public Ingress with Application Gateway](public-ingress.md) for the topology and parameters.

---

## Cost comparison at a glance

| Scenario | Fixed monthly floor | Best for |
|---|---:|---|
| **1. Basic** | **~$332** | Sandbox, demo, dev/test, public evaluation |
| **2. Zero Trust (internal)** | **~$1,584** | Production for internal users (VPN / ExpressRoute / Bastion) |
| **3. Zero Trust + App Gateway** | **~$1,838** | Production for external users with WAF-protected public ingress |

Variable model / data / processing cost applies to all three and depends entirely on traffic volume.

!!! info "What you can do to reduce the floor"
    - **Share the hub firewall** in a hub-and-spoke topology (`deployAzureFirewall=false` + `hubIntegrationEgressNextHopIp`) — saves ~$900/month.
    - **BYO observability** (`existingLogAnalyticsWorkspaceResourceId`, `existingApplicationInsightsResourceId`) — avoids duplicating workspaces across spokes.
    - **BYO Private DNS zones** — every one of the 15 zones is BYO-capable, ideal for ALZ-integrated topologies.
    - **Stop the Jumpbox when idle** — `Standard_D2s_v3` compute charges stop when deallocated; only the OS disk continues to bill.
    - **Use the Consumption-only workload profile** for the Container Apps Environment if you don't need the dedicated `D4` profile (delete it from `workloadProfiles`).

---

## Methodology and caveats

- **Pricing snapshot**: Azure retail PAYG, **East US 2**, **2026-05-29**.
- **Currency**: USD; convert at your contract rate.
- **Discounts not applied**: EA, MCA, CSP, reservations, savings plans, Azure Hybrid Benefit, dev/test rates — all of these can materially lower the floor.
- **Empty-data assumption**: storage / Log Analytics / Cosmos data charges are shown as $0 fixed because the resource itself is free at zero bytes; they grow linearly with data.
- **Quiet workload**: variable token / call / processing line items are listed without a number because they depend on your traffic — model the load you actually expect in the Pricing Calculator.
- **Region matters**: AI Search, Azure Firewall, and Application Gateway can vary by ±20% across regions.
- **Page is a snapshot, not a contract**: when in doubt, [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/) is the source of truth.

## See also

- [Overview](overview.md) — high-level architecture and topology
- [Parameterization](parameterization.md) — full reference for every flag mentioned here
- [Regional Considerations](regional-considerations.md) — capacity caveats per region (AI Search, Cosmos, ACA)
- [Hub-and-Spoke Topology](hub-and-spoke.md) — how to share hub Firewall / Bastion / DNS to lower the ZT floor
- [Public Ingress (App Gateway)](public-ingress.md) — Scenario 3 details
