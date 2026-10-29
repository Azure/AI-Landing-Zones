# Cost guide

Estimate the **deployment you intend to run**, not an all-services-enabled
template. Begin with the [resource inventory and scenario estimates](../bicep/deployed-resources.md),
then build a regional estimate in the
[Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/).
Use the [Sizing & cost planner](../agent-landing-zone/sizing-cost-planner.md) to identify the capacity
assumptions you need to test.

!!! warning "Estimate dates and pricing evidence"
    The earlier version of this guide contained East US USD estimates dated
    **November 5, 2025**, linked to this
    [saved calculator example](https://azure.com/e/e92e102172054654a13cdc1cada6cecc).
    That example is not a current default deployment or a quote. The separate
    resource inventory identifies its own pricing date and assumptions.
    This guide's October 18, 2026 editorial review did **not** reprice Azure
    services. Recalculate for your region, agreement, currency and selected
    resources before approving spend.

## Build an estimate in five steps

1. **Select the implementation and topology.** Record whether you are estimating
   a foundation alone or the application too. For Agent Landing Zone, use its
   `manifest.json`, deployment definition and resolved configuration, not the
   standalone foundation's example defaults.
2. **Count the actual resources.** Include separate Agent Service backing
   resources where created. Account for existing resources without counting
   their full shared cost twice.
3. **Separate allocation from usage.** Estimate always-running capacity,
   variable consumption and one-time migration or indexing work separately.
4. **Price the region and tier.** Use current calculator rates and your
   organization's applicable pricing. Record a date and shareable estimate.
5. **Validate after deployment.** Compare the estimate with Cost Management,
   usage and performance. Revisit it after traffic, model, data or topology
   changes.

## What to include

The categories below are a costing checklist, **not** a statement that every
resource is deployed by default. Check the selected template and effective
parameters.

| Category | Include when selected or required | Main cost drivers |
| --- | --- | --- |
| Models and Foundry | Account/project, selected model deployments and agent/tool services | Input/output tokens, model and deployment type, provisioned capacity, separately metered tools |
| Search and ingestion | Workload Search, Agent Service Search where created, native ingestion or the optional ingestion application | Service count, SKU, replicas/partitions, semantic or agentic retrieval, indexing/enrichment and embedding usage |
| Application hosting | Selected Container Apps, Foundry hosted-agent compute, build services and Container Registry | Active compute, minimum replicas, allocated workload-profile nodes, registry tier/storage and build-agent pool allocation |
| Data | Workload and Agent Service Storage/Cosmos DB as applicable | Account count, throughput mode, requests, stored data, redundancy, backup and restore |
| Configuration and secrets | App Configuration and Key Vault | Tier, requests and secret/key operations |
| Observability | Log Analytics, Application Insights and configured tests | Ingested data, retention, queries and test execution; avoid double-counting workspace-based ingestion |
| Private networking | Private endpoints/DNS, firewall, NAT, peering, Bastion and connected-runner VMs where deployed | Allocated hours, processed data, endpoint count, DNS queries, VM disks and data transfer |
| Ingress and optional tools | Application Gateway/WAF, API Management, Speech, Grounding with Bing or other selected services | Tier and capacity, allocated hours, requests, tokens and data transfer |

### Avoid common counting mistakes

- **Agent backing resources are separate.** Standard Agent Service setup can
  create its own Search, Storage and Cosmos DB resources in addition to workload
  resources. Count what is actually created or reused.
- **Application Cosmos DB depends on topology.** Omitting the application's
  database does not imply that Agent Service has no backing database.
- **Ingestion is a separate choice.** Omitting the optional ingestion app does
  not remove Search, source-processing, embedding or indexing charges.
- **Private networking is not a fixed package.** Endpoint count and services
  depend on isolation, selected resources and existing platform integration.
  Count firewall, Bastion, NAT, VMs and disks only where present.
- **Optional does not mean free.** Add API Management, public ingress and tools
  only when selected, with their own pricing assumptions.

## Record your sizing assumptions

Use measured or explicitly estimated inputs rather than a single unexplained
monthly total:

| Input | What to record |
| --- | --- |
| User and agent traffic | Active users, turns per day, concurrency, peak rate and retries/tool calls per task |
| Model usage | Input/output tokens per task, context size, model choice and embedding volume |
| Retrieval and ingestion | Document count/size, update frequency, query volume and index growth |
| Compute | Hosting mode, instance size, minimum/maximum capacity and expected active hours |
| Data protection | Retention, backups, replication and recovery requirements |
| Network and monitoring | Outbound/cross-region data, private endpoint count, log volume and retention |

Search's allocated capacity is only part of its cost: inspect separately billed
features and usage. For Cosmos DB, distinguish provisioned or autoscale capacity
from serverless request consumption. A stopped VM can still incur disk and
network charges.

## Optimize without changing the security contract

Start with idle or oversized capacity, unnecessary duplicate resources and
excessive telemetry. Validate each proposed saving against service limits and
workload acceptance tests.

- Schedule supported development VMs, while preserving the connected-runner
  access needed for private deployments.
- Tune Container Apps minimum replicas and workload-profile allocation using
  measured startup and latency requirements. Consumption hosting is a design
  choice, not a drop-in instruction to replace the deployed application.
- Choose Search capacity and replica counts according to index size, throughput
  and availability requirements, not price alone.
- Evaluate commitments only after measuring sustained utilization.
- Set intentional log retention and avoid unnecessary content capture without
  losing operational or compliance evidence.
- Reuse shared networking only when ownership, routing and access requirements
  are satisfied. Do not disable firewall, authentication or private access to
  meet an arbitrary savings percentage.

Removing a component is not routine cost cleanup. Back up data, review
dependencies and explicitly authorize retirement. For Agent Landing Zone, follow
the [full-stack lifecycle guidance](../agent-landing-zone/deploy-full-stack.md)
rather than deleting individual resources behind the deployment's state.

## Monitor actual spend

Use [Azure Cost Management](https://learn.microsoft.com/azure/cost-management-billing/costs/overview-cost-management)
to group spend by resource and environment, set budgets/alerts and investigate
unexpected usage. Budgets are notifications, not an automatic cap on spending.
Review both platform-shared and workload-specific charges with their owners.

Useful pricing references:

- [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)
- [Azure OpenAI pricing](https://azure.microsoft.com/pricing/details/cognitive-services/openai-service/)
- [Azure AI Search pricing](https://azure.microsoft.com/pricing/details/search/)
- [Container Apps pricing](https://azure.microsoft.com/pricing/details/container-apps/)
- [Azure Monitor pricing](https://azure.microsoft.com/pricing/details/monitor/)
