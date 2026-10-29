# Cost planning

!!! note
    An update to align this guidance with the current architecture is planned.
    Confirm sizing and cost assumptions against your deployment configuration.

Cost depends on the **Agent Landing Zone configuration that runs**:
[topology and resource reuse](planning.md), [capacity](sizing.md) and usage.
The default has a Foundry hosted orchestrator, frontend, no panel and native
Foundry IQ Blob ingestion, without Agent App Ingestion.

This page explains cost drivers, not deployment steps. The
[Deploy infra only](deploy-infra-only.md) and
[Deploy full stack](deploy-full-stack.md) runbooks cover execution.

Use the [Sizing & cost planner](sizing-cost-planner.md) to compare editable
workload and price assumptions with an isolated standalone `hosted-no-panel`
reference. It is a planning estimate, not an Azure quote; workload examples are
not deployment defaults or measured capacity. Review the dated price sources,
included billing units and any sourced amounts for contract-priced options.
Its catalog combines Azure Retail Prices API records with exact official
pricing-page rows. Automated daily refresh retains the last validated catalog
if collection, parsing or validation fails; check the displayed snapshot date.

The planner shows one monthly total. When you change a resource, its cost
difference is already included in that total, not charged on top. The named
changes include linked dependencies, such as API Management's private endpoint.
**Largest monthly costs** ranks the main contributors and identifies allocation
and throughput hypotheses, including idle build-pool hours.
Open a resource to preview the cost of adding an optional unit. Capability and
resource details expand on demand. Save, comparison and export tools are under
**Save, compare & export**.

!!! note "Pricing sources and dates"
    The shared
    [resource inventory and estimates](../bicep/deployed-resources.md) uses
    **May 29, 2026, East US 2, US dollars, pay-as-you-go** example prices. Its scenarios are not
    Agent Application defaults or a full-stack quote. The
    [shared cost guide](../architecture/cost-guide.md) explains its calculator
    example's date and limitations. An estimate needs current regional rates,
    currency and your organization's agreement.

<span id="build-the-estimate"></span>

## Estimate inputs

| Input | What it contributes |
| --- | --- |
| Resolved resources | Platform Git commit or release tag, selected application, `DEPLOYMENT_TOPOLOGY`, ingestion selection, network mode and reused resources. Composed parameters and the deployment preview show planned resources; the deployed inventory also reveals retained allocations. |
| Allocated capacity | Search services, registry tier, App Configuration, workload-profile nodes, private endpoints, firewall, Bastion and ingress can incur idle-period charges. |
| Measured usage | Turns, model/tool calls, tokens, embeddings, indexing, compute, requests, data, logs and transfer. Initial corpus ingestion and reindexing are separate from steady-state traffic. |
| Shared services | Hub, DNS, gateway and monitoring costs allocated with their owners. Reuse avoids some new allocations, not all usage charges. |

The [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)
supports a dated estimate with explicit assumptions and exclusions.
Actual spend after deployment provides the comparison baseline.

<span id="check-the-agent-specific-cost-drivers"></span>

## Agent-specific cost drivers

| Decision | Include in the estimate |
| --- | --- |
| Application hosting | Foundry hosted compute, plus the frontend and other selected components separately. The root's `main` D4 profile has a zero-node minimum, but selected Container Apps with minimum replicas can keep a node allocated and billed while idle. |
| Foundry Agent Service | Separate Search, Storage and Cosmos DB backing resources where created. `hosted-no-panel` omits Agent Application Cosmos DB, not these Foundry backing resources. Reused dedicated backing resources still have costs. |
| Retrieval and ingestion | Agent Application Search replicas/partitions plus any separately billed retrieval features, model calls and embeddings. Omitting Agent App Ingestion does not remove native ingestion or indexing charges. With the component selected, include its compute and processing dependencies. |
| Private networking | Count the actual private endpoints, DNS, firewall/NAT, peering/data transfer and connected runner. Include Bastion, VM and disks only where selected or retained. Hub reuse changes allocation and ownership, not the connectivity requirements. |
| Builds and images | Registry capacity/storage, ACR Tasks or private agent-pool allocation and build activity. Check the pool's provisioned allocation, not only elapsed build duration. Include image retention and promotion copies. |
| UI ingress or AI Gateway | Add Application Gateway/WAF only if enabled. A separately operated AI Gateway has its own tier, capacity, policy and usage charges; it is not included automatically in an Agent deployment. |
| Observability and protection | Workspace ingestion/retention, configured tests, backup and redundancy. Avoid double-counting Application Insights ingestion billed through its Log Analytics workspace. |

Model deployment `sku.capacity` allocates quota. To estimate model charges,
use the deployment type, region, expected tokens and any provisioned-capacity
commitment with the current service prices.

### Planner price and budget assumptions

These calculations explain the planner's initial reference using captured
public rates. Consult its dated catalog for refreshed prices. Budget hypotheses
are not deployed service settings.

| Item | Initial price or budget calculation |
| --- | --- |
| `gpt-5-nano`, Global | $0.05 input / $0.40 output per million tokens, captured from the exact official model-pricing row. This is a published-page price, not a Retail API meter. |
| Dedicated ACR Tasks S1 pool | $0.0001/vCPU-second produces $525.60 at 730 allocated hours. Allocated capacity is billed even without active builds. The rate comes from the official published pricing row. |
| Foundry backing Cosmos DB | A fresh provisioned account is budgeted as five manual 1,000-RU/s offers (5,000 RU/s total), 10 GB of transactional data plus indexes, a separate 10 GB of `Continuous30Days` backup and one non-zone-redundant region: $296.50/month at the captured rates. The Foundry runtime owns the actual offers; these quantities are explicit budget hypotheses. |

Published-page prices carry their source and capture date rather than
Retail meter IDs. Operator-entered rates remain separately identified.

The planner's Cosmos backup choice is a billing hypothesis, not a claim that
the providers deploy the same policy: pinned Bicep AVM inherits
`Continuous30Days`, while Terraform omits the backup policy and receives the
API's periodic default. Verify the deployed policy and runtime-owned offers
before approving a budget; changing the planner does not change either.

### Standalone firewall selection

Isolated standalone deployments default to Basic. Include its fixed allocation,
data-processing rate, additional management public IP, logs and network
transfer in the estimate; a lower hourly price alone is not the full cost.
Compare current regional rates and measured volume with Standard. Select
Standard explicitly when its DNS or capacity capabilities are required.

The planner retains Basic as its initial East US 2 reference. No VNet Basic
rate was found for Sweden Central in the Retail API or official Basic pricing
row, so the planner offers Standard/Premium there and uses Standard as that
region's reference. A secured-vHub rate is not a substitute for standalone VNet
pricing. Deploying the Sweden Central reference needs a reviewed IaC change;
the planner does not change the shipped Basic default or prove regional
service availability.

Basic needs separate data and management subnets; the management subnet must be
/26 or larger. External hub egress uses the hub's firewall and does not create
a local firewall or management IP. GatewaySubnet is reserved only on request
and does not provision a paid gateway. See the
[networking resource matrix](network-isolation.md#firewall-sku-and-management-networking).

<span id="control-spend-without-weakening-the-design"></span>

## Spend controls and security

[Azure Cost Management](https://learn.microsoft.com/azure/cost-management-billing/costs/overview-cost-management)
budgets and alerts notify; they do not automatically stop resources or cap spend.
Service-level usage after ingestion and representative traffic can reveal idle
allocations, retained resources, retry loops and excessive logs.

Model choice, Search capacity, replica minimums and retention can be tuned
against measured quality, latency, availability and compliance needs.
Each change affects [sizing](sizing.md) as well as cost.

Shared infrastructure needs approved ownership, routing and permissions.
Public access, removed authorization and bypassed private-link readiness are
not cost controls. Selection flags affect future deployments; existing
resources and grants require separate dependency, backup and access review
before cleanup, as covered by the
[Deploy full stack](deploy-full-stack.md) runbook.

An environment estimate records its owner, date, region/currency,
selected/reused resources, expected monthly usage and contingency.
Topology, model, corpus or traffic changes can invalidate it. The
[shared cost guide](../architecture/cost-guide.md) provides additional pricing
references without repeating the generic catalog here.
