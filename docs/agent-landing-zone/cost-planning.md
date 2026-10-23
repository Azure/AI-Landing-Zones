# Cost planning

Estimate the **Agent Landing Zone configuration you will run**, not the
independent foundation's example total. Choose [topology and resource reuse](planning.md)
and establish [capacity assumptions](sizing.md) first.

!!! note "Pricing evidence and date"
    Reviewed against platform v4.3.0 on **October 23, 2026**. This page does not
    quote or reprice Azure services. The shared
    [resource inventory and estimates](../bicep/deployed-resources.md) uses
    **May 29, 2026, East US 2 USD PAYG** example prices. Its scenarios are not
    Agent Application defaults or a full-stack quote. The
    [shared cost guide](../architecture/cost-guide.md) explains the older
    calculator example's date and limitations. Recalculate using current
    regional rates, currency and your organization's agreement.

## Build the estimate

1. **Count the resolved footprint.** Record the platform revision, application
   definition, `DEPLOYMENT_TOPOLOGY`, ingestion selection, network mode and
   existing-resource IDs. Compare composed parameters and the deployment
   preview, including retained migration resources.
2. **Price allocated capacity.** Include selected Search services, registry
   tier, App Configuration, workload-profile nodes, private endpoints,
   firewall, Bastion, ingress and other allocation-based services. Idle is
   not necessarily free.
3. **Add measured usage.** Estimate turns, model/tool calls, input/output tokens,
   embeddings, indexing, compute, requests, stored data, logs and network
   transfer. Include initial corpus ingestion and reindexing separately
   from steady-state traffic.
4. **Account for shared services.** Agree the workload's share of hub, DNS,
   gateway and monitoring charges with their owners. Reuse avoids some new
   allocations, not all usage charges.
5. **Approve a dated estimate.** Use the
   [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/),
   record assumptions and exclusions, then compare actual spend after deployment.

## Check the Agent-specific cost drivers

| Decision | Include in the estimate |
| --- | --- |
| Hosted or classic orchestrator | Foundry hosted compute where selected, or the classic Container App. Include the frontend and other selected components separately. The root's `main` D4 profile has a zero-node minimum, but selected apps with minimum replicas can keep a node allocated. Do not assume Consumption scale-to-zero. |
| Foundry Agent Service | Separate Search, Storage and Cosmos DB backing resources where created. `hosted-no-panel` omits Agent Application Cosmos DB, not these Foundry backing resources. Reused dedicated backing resources still have costs. |
| Retrieval and ingestion | Agent Application Search replicas/partitions plus any separately billed retrieval features, model calls and embeddings. Omitting Agent App Ingestion does not remove native ingestion or indexing charges. With the component selected, include its compute and processing dependencies. |
| Private networking | Count the actual private endpoints, DNS, firewall/NAT, peering/data transfer and connected runner. Include Bastion, VM and disks only where selected or retained. Hub reuse changes allocation and ownership, not the connectivity requirements. |
| Builds and images | Registry capacity/storage, ACR Tasks or private agent-pool allocation and build activity. Check the pool's provisioned allocation, not only elapsed build duration. Include image retention and promotion copies. |
| UI ingress or AI Gateway | Add Application Gateway/WAF only if enabled. A separately operated AI Gateway has its own tier, capacity, policy and usage charges; it is not included automatically in an Agent deployment. |
| Observability and protection | Workspace ingestion/retention, configured tests, backup and redundancy. Avoid double-counting Application Insights ingestion billed through its Log Analytics workspace. |

Model deployment `sku.capacity` is a quota allocation input, **not** a price
or a guaranteed task rate. Model, deployment type, region, actual tokens and
any provisioned-capacity purchase determine the relevant billing assumptions.
Check current service pricing rather than converting that number into a
monthly token bill.

## Control spend without weakening the design

- Set budgets and alerts in
  [Azure Cost Management](https://learn.microsoft.com/azure/cost-management-billing/costs/overview-cost-management).
  Budgets notify; they do not automatically stop resources or cap spend.
- Compare the estimate with service-level usage after the initial ingestion
  and after representative interactive traffic. Investigate idle allocations,
  unexpected retained resources, retry loops and excessive log volume.
- Tune model choice, Search capacity, replica minimums and retention using
  measured quality, latency, availability and compliance requirements.
  Revalidate [sizing](sizing.md) after each change.
- Reuse shared infrastructure only with approved ownership, routing and
  permissions. Do not enable public access, remove authorization or bypass
  private-link readiness to meet a cost target.
- Retire old components only after dependency, backup and grant review.
  Changing a selection flag is not a cleanup procedure; use the
  [deployment lifecycle guidance](deploy-full-stack.md).

Keep one estimate per environment with its owner, date, region/currency,
selected/reused resources, expected monthly usage and contingency. Revisit it
after a topology, model, corpus or traffic change. The
[shared cost guide](../architecture/cost-guide.md) provides additional pricing
references without repeating the generic catalog here.
