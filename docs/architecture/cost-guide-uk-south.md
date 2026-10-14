# UK South — Monthly Run Cost

This page gives the **monthly run cost of the AI Landing Zone deployed to Azure UK South**, using live UK South PAYG retail pricing in **GBP (£)**.

It mirrors the resource inventory in [Deployed Resources & Cost Estimates](../bicep/deployed-resources.md); read that page for *what* gets deployed and *why*. This page answers only *what it costs in UK South*.

!!! warning "Cost figures are estimates, not a quote"
    All numbers are **GBP/month**, **UK South PAYG retail pricing**, pulled live from the [Azure Retail Prices API](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices) on **2026-07-27**, with **empty data and a quiet workload (~1 user)**. Your bill will vary with EA/MCA/CSP discounts, reserved capacity / savings plans, Azure Hybrid Benefit, autoscale behaviour, data volumes, model token consumption, AI Search index size, and Application Gateway capacity units. Always validate with the [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/) before committing.

---

## Headline monthly run cost (UK South)

| Scenario | Fixed £/month | Best for |
|---|---:|---|
| **1. Basic** (public, no network isolation) | **~£753** | Sandbox, demo, dev/test, public evaluation |
| **2. Zero Trust** (private, internal users) | **~£1,850** | Production for internal users (VPN / ExpressRoute / Bastion) |
| **3. Zero Trust + App Gateway** (external users) | **~£2,102** | Production for external users behind WAF v2 |

Each figure is the **fixed floor** — what you pay with zero traffic and empty data. Variable model-token, Bing-query, data-ingestion and per-GB-processed costs sit on top and depend entirely on your workload.

!!! tip "Two levers drop the Basic floor to ~£280/month"
    - `deployAAfAgentSvc=false` — turn off the Standard Agent Setup if you don't use Foundry agents → **−£186 (Foundry AI Search) −~£20 (Foundry Cosmos)**.
    - Drop the `D4` workload profile (Consumption-only) and remove `min_replicas=1` from the orchestrator → **−£293**.

---

## UK South unit prices used

Live UK South retail prices (GBP), PAYG, as of **2026-07-27**. Monthly figures assume **730 hours/month** and **30.42 days/month**.

| Resource (default config) | UK South unit price | Fixed £/month |
|---|---|---:|
| Azure Firewall Standard — deployment | £0.947006 / hr | £691.31 |
| Azure Firewall Standard — data processed | £0.012122 / GB | variable |
| Azure Bastion Standard — gateway | £0.219705 / hr | £160.38 |
| Azure Bastion Standard — data out | £0.053032 / GB | variable |
| AI Search Standard S1 (1 partition × 1 replica) | £0.254555 / hr | £185.83 **each** |
| Container Apps — Dedicated vCPU | £0.061259 / vCPU-hr | £178.88 (D4) |
| Container Apps — Dedicated memory | £0.005029 / GiB-hr | £58.74 (D4) |
| Container Apps — Dedicated plan management | £0.075760 / hr | £55.30 |
| Container Registry Premium — registry unit | £1.262624 / day | £38.41 |
| App Configuration Standard — instance | £0.909125 / day | £27.66 |
| Jumpbox VM `Standard_D2s_v3` (Windows) | £0.157582 / hr | £115.03 |
| Managed disk — P10 (128 GB Premium SSD) | £18.067351 / month | £18.07 |
| Public IP — Standard Static IPv4 | £0.003788 / hr | £2.77 **each** |
| Private DNS zone (first 25 zones) | £0.378802 / zone / month | £5.68 (×15) |
| Private endpoint¹ | ~£0.0074 / hr | ~£5.40 **each** |
| NAT Gateway¹ | ~£0.0356 / hr | ~£26 |
| Cosmos DB — autoscale (Foundry) | £0.009091 / 100 RU/s-hr | ~£7–27 |
| Cosmos DB — serverless (workload) | £0.225009 / 1M RU | £0 idle |
| Storage — Hot LRS data stored | £0.013964 / GB / month | £0 idle |
| Key Vault — operations | £0.022728 / 10K ops | £0 idle |
| Log Analytics — Analytics Logs ingestion | £2.181901 / GB | £0 idle |
| AI Foundry account + project + models | per-token | £0 fixed |
| Grounding with Bing (S1) — search | £10.606462 / 1K queries | £0 idle |
| Application Gateway WAF v2 — fixed | £0.340922 / hr | £248.87 |
| Application Gateway WAF v2 — capacity unit | £0.010910 / CU-hr | variable |

¹ Private endpoint and NAT Gateway meters are not exposed by the Retail Prices API for UK South; values are Azure's published UK South list prices for those services.

---

## Scenario 1 — Basic (public, no network isolation)

```text
networkIsolation        = false
deployAzureFirewall     = false   (auto-suppressed when NI is off)
deployJumpbox/Bastion/NatGateway = false
publicIngress.enabled   = false
deployAAfAgentSvc       = true    (default — Standard Agent Setup)
deployAcrTaskAgentPool  = true    (default)
deployGroundingWithBing = true    (default)
```

| Resource | Fixed £/month | Variable driver |
|---|---:|---|
| AI Foundry account + project | £0 | Per-token model usage |
| Model: `gpt-5-nano` (GlobalStandard, cap 40) | £0 | Pay-as-you-go tokens |
| Model: `text-embedding-3-large` (Standard, cap 10) | £0 | Pay-as-you-go tokens |
| Grounding with Bing (S1) | £0 | £10.61 / 1K queries |
| **Foundry AI Search** (Standard S1, 1p × 1r) | **£185.83** | Index storage; scale to 3r (~£557/mo) for read/write SLA |
| Foundry Storage (Standard_LRS, Hot) | ~£1 | Data + operations |
| Foundry Cosmos DB (autoscale) | ~£20 | Autoscale floor + storage |
| **Workload AI Search** (Standard S1, 1p × 1r) | **£185.83** | Index storage; queries scale with QPS |
| Workload Storage (Standard_LRS, Hot) | ~£1 | Data + operations |
| Workload Cosmos DB (serverless) | £0 | £0.225 / 1M RU + storage |
| Workload Key Vault (Standard) | £0 | £0.023 / 10K operations |
| **Container Apps — pinned D4 workload-profile node** | **£292.92** | Extra D4 instances when scaled up |
| Container Apps Environment — Consumption profile | £0 | vCPU-s + GiB-s per request |
| **Container Registry (Premium)** | **£38.41** | Storage above 500 GB + geo-replication |
| ACR build-agent pool (on-demand) | £0 | Per build-hour |
| **App Configuration (Standard)** | **£27.66** | Per-request above quota |
| Log Analytics workspace | £0 | £2.18 / GB ingested |
| Application Insights | £0 | Bundled into Log Analytics |
| **Subtotal — Basic** | **~£753 / month** | + token / data / request usage |

---

## Scenario 2 — Zero Trust (private, internal users only)

```text
networkIsolation = true    # Firewall, Jumpbox, Bastion, NAT Gateway all default-on
publicIngress.enabled = false
```

Adds, **on top of Scenario 1**:

| Resource | Fixed £/month | Variable driver |
|---|---:|---|
| VNet + subnets + NSGs + Private DNS zones (×15) | ~£6 | £0.379 / zone / mo |
| Private endpoints (~14) | ~£76 | ~£5.40 each + per-GB processed |
| **Azure Firewall (Standard)** | **£691.31** | + £0.012 / GB processed |
| Public IP (firewall) | £2.77 | — |
| **Azure Bastion (Standard)** | **£160.38** | + £0.053 / GB outbound |
| Jumpbox VM (`D2s_v3`) + 128 GB P10 disk | £133.10 | — |
| VM Key Vault (Standard) | £0 | £0.023 / 10K operations |
| NAT Gateway | ~£26 | + per-GB processed |
| Public IP (NAT) | £2.77 | — |
| **Zero Trust additions subtotal** | **~£1,097 / month** | + per-GB processing |
| **Subtotal — Zero Trust (Basic + ZT)** | **~£1,850 / month** | + token / data / request usage |

!!! note "Where the Zero Trust cost goes"
    Roughly **63 % of the ZT surcharge is Azure Firewall (£691)**. If your platform team already runs a hub Firewall, set `deployAzureFirewall=false` and point `hubIntegrationEgressNextHopIp` at it — the ZT delta drops from ~£1,097 to **~£406/month**.

---

## Scenario 3 — Zero Trust + Application Gateway (external users)

```text
(everything from Scenario 2, plus)
publicIngress.enabled = true
```

Adds, **on top of Scenario 2**:

| Resource | Fixed £/month | Variable driver |
|---|---:|---|
| **Application Gateway WAF v2** (1 instance, minimum) | **~£249** | + £0.011 / capacity-unit-hour |
| Public IP (App Gateway) | £2.77 | — |
| WAF policy | £0 | — |
| **App Gateway additions subtotal** | **~£252 / month** | + capacity-unit consumption |
| **Subtotal — ZT + App Gateway** | **~£2,102 / month** | + token / data / request usage |

---

## Methodology and caveats

- **Pricing source**: [Azure Retail Prices API](https://prices.azure.com/api/retail/prices), `armRegionName eq 'uksouth'`, `currencyCode=GBP`, PAYG retail, pulled **2026-07-27**.
- **Currency**: GBP list prices set directly by Azure for UK South (not USD-converted).
- **Discounts not applied**: EA, MCA, CSP, reservations, savings plans, Azure Hybrid Benefit, dev/test rates — any of these lowers the floor.
- **Empty-data assumption**: Storage, Log Analytics, and serverless Cosmos data charges are ~£0 fixed because the resource is free at zero bytes; they grow linearly with data.
- **Quiet-workload assumption**: model-token, Bing-query and per-GB line items are listed as £0 fixed because they depend entirely on traffic — model your expected load in the Pricing Calculator.
- **Container Apps** D4 baseline assumes 1 node stays active because the default `orchestrator` app pins `min_replicas=1` on `profile_name: "main"`. Consumption-only deployments drop this to £0.
- **Foundry Cosmos** floor reflects the autoscale band commonly used by the AVM Foundry module (~100–400 RU/s at idle); the exact number depends on the CapabilityHost configuration.
- **Private endpoint & NAT Gateway** figures use Azure's published UK South list prices because those meters are not returned by the Retail Prices API.
- **Snapshot, not a contract**: when in doubt, the [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/) is the source of truth.

## See also

- [Deployed Resources & Cost Estimates](../bicep/deployed-resources.md) — full resource inventory (East US 2 reference figures)
- [Cost Guide](cost-guide.md) — pricing-calculator walkthrough
- [Regional Considerations](../bicep/regional-considerations.md) — capacity caveats per region
