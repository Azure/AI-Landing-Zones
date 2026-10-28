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

!!! note "Pricing sources and dates"
    This page does not quote or reprice Azure services. The shared
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
