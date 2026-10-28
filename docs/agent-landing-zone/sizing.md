# Sizing and capacity

!!! note
    An update to align this guidance with the current architecture is planned.
    Confirm sizing and cost assumptions against your deployment configuration.

Capacity depends on the workload, not only the number of people who can sign
in. Concurrent agent requests, model calls, tool latency and
document processing place different demands on the deployment.

The default is a Foundry hosted orchestrator using `maf_lite`, no panel and
native Foundry IQ Blob ingestion. This reference explains its capacity
constraints and optional components. [Deployment choices](planning.md)
covers resource selection; [Cost planning](cost-planning.md) covers spending.
Execution steps belong to the [Deploy infra only](deploy-infra-only.md)
and [Deploy full stack](deploy-full-stack.md) runbooks.

!!! note "Validate defaults against your workload"
    Defaults are starting points, not benchmarked capacity profiles or throughput
    guarantees. Composed parameters and the deployed configuration determine the
    actual capacity, including for custom applications.

<span id="establish-a-workload-baseline"></span>

## Workload baseline

Capacity estimates need the following workload assumptions.

A **token** is a piece of text processed by a model. An **embedding** represents
content as a numeric vector for similarity search. Host capacity is measured
in CPU (processor capacity) and memory; `Gi` denotes gibibytes of memory.
A service's **SKU** identifies its tier or capacity option, not measured usage.

| Area | Questions to answer |
| --- | --- |
| Agent traffic | How many requests run concurrently at peak? How long do turns take, and how many model or tool calls does each strategy make? |
| Models | Which deployments are required? What are the expected input/output token volumes, token-rate limits and target response times? |
| Knowledge and ingestion | How many documents and vectors (numeric content representations used for similarity search) are stored? What are their sizes, formats, update rate and ingestion completion targets? Will ingestion run alongside peak interactive traffic? |
| Hosting | Which strategies must run, on which host? What CPU, memory, concurrency and scaling behavior does representative execution require? |
| Availability and operations | What recovery targets, environment separation, telemetry retention and private-network requirements must the deployment meet? |

[Deployment settings](configuration.md) and [Agent hosting](hosted-agents.md)
describe inputs and host constraints. The
[resource inventory](../bicep/deployed-resources.md) describes resource families;
the generated `infra/main.parameters.json` identifies the selected resources.
Their count varies with topology and reuse.

## Models and quota

The root `main.parameters.json` selects a `chat` deployment of `gpt-5-nano`
and a `text-embedding` deployment of `text-embedding-3-large`, each with
`sku.capacity=100`. The token and request limits represented by this value
depend on the model and deployment type. Limits and regional availability are
listed in the
[model quota reference](https://learn.microsoft.com/azure/ai-services/openai/quotas-limits).
`modelDeploymentList` in the root `main.parameters.json` controls that capacity.

Relevant demand includes input/output tokens per turn, model/tool calls,
retries and peak turns per minute. Ingestion adds extracted tokens and
embedding batches. Long contexts and multiple calls can exhaust quota even
with few users. Application replicas do not increase model quota.

## Search capacity

Both newly created Search services start at Standard, **one partition and one
replica**. The Agent Application Search service and the separate Foundry Agent
Service Search service both count when both creation paths are enabled. They use
`AZURE_SEARCH_LOCATION`, falling back to `AZURE_LOCATION`; quota must cover
the complete enabled service count in that region.

- **Partitions:** index/vector storage, document count and growth determine demand.
  A representative corpus reveals how splitting documents into passages expands the index;
  source-file size alone is not the index footprint.
- **Replicas:** peak retrieval plus concurrent indexing affects latency and
  throttling. The current
  [Search reliability and SLA requirements](https://learn.microsoft.com/azure/search/search-reliability)
  describe production availability requirements. The one-replica default is not
  a high-availability design.
- **Change path:** the shipped `infra/main.bicep` declares SKU, partition and
  replica counts as literals for both services. There is no root
  `SEARCH_REPLICA_COUNT` or equivalent scaling input. Persistent sizing needs a
  reviewed infrastructure change; provisioning can reset portal-only changes.
  `aiSearchResourceId` does not reuse workload Search; it reuses Foundry's backing service.

Current [Search service limits](https://learn.microsoft.com/azure/search/search-limits-quotas-capacity)
depend on tier, region and service creation date. Private native Blob
ingestion also requires approved, ready shared private links; extra Search
capacity does not bypass that gate.

## Application hosting

| Host/resource | Starting point | Sizing considerations |
| --- | --- | --- |
| Foundry hosted orchestrator (default) | The Agent Application's `hosted-agent/azure.yaml` declares `2` CPU and `4Gi` memory. | Memory peaks, streaming latency and concurrent turns determine demand. `HOSTED_AGENT_CONTAINER_CPU` / `HOSTED_AGENT_CONTAINER_MEMORY` affect provisioning but do not override the child's literal deployment fields. Resizing needs a compatible child definition, provisioned deployment metadata and a new agent version. Container Apps scaling does not control this host. |
| Frontend Container App | Root entry uses `profile_name=main`, `min_replicas=1`, `max_replicas=1`. With no explicit size, infrastructure placeholders use `0.5` CPU / `1.0Gi`. | Active revisions, CPU, memory, concurrent streams and startup latency show runtime demand. `containerAppsList` settings and child deployment behavior both matter; placeholder sizing is not a performance guarantee. |
| Agent App Ingestion (optional, omitted by default) | Root entry specifies `1.0` CPU / `3.0Gi` and one minimum/maximum replica on `main`. | Large files and expensive formats affect peak memory, backlog and embedding/Search throttling. Additional replicas require verified duplicate handling and concurrent writes to shared sources and indexes. |
| Container Apps workload profiles | `Consumption` plus `main` D4 with `minimumCount=0`, `maximumCount=1`. | Aggregate CPU/memory placement and per-app limits both matter. Raising app replicas alone does not raise the profile's node ceiling. Minimum app replicas can keep a node allocated despite the zero-node profile minimum. |

The root arrays/objects above belong in reviewed `main.parameters.json`;
`infra/main.parameters.json` is generated. Deployed capacity can differ from
placeholders after application deployment. [Agent hosting](hosted-agents.md)
describes strategy eligibility, immutable images and history limitations.
Conversation continuity limits are not compute-sizing controls.

## Data, builds and observability

| Resource | What to measure and decide |
| --- | --- |
| Agent Application Cosmos DB | `hosted-no-panel` does not deploy this account. Foundry Agent Service's backing Cosmos DB is separate and still needs its own capacity and retention review. |
| Blob storage | Original files, extracted images, enabled attachments, updates, retention, transaction rate and ingestion completion time all contribute. Omitting Agent App Ingestion does not omit native source processing. |
| Registry and private build pool | Image sizes, build duration and parallel build demand affect capacity. Isolated hosted preparation requires the private ACR Tasks pool and permitted package feeds; more runtime compute does not speed it up or connect the runner. Pool capacity depends on SKU and region. |
| App Configuration and Key Vault | Startup/restart bursts and service request limits matter. Secrets remain Key Vault references, not plain configuration values. |
| Log Analytics and Application Insights | Ingestion volume, investigation needs and compliance determine retention/sampling. Message-content capture is a privacy decision, not a required sizing test. |

<span id="validate-the-initial-capacity"></span>

## Capacity validation

Useful acceptance targets include response time, error rate, ingestion delay
and peak concurrency. Representative nonproduction tests cover configured
tools, document sizes, native ingestion, authentication and document allow/deny
behavior within regional service limits.

Service metrics and application traces distinguish model throttling, Search
limits, tool latency and runtime CPU/memory pressure. Comparable tests before
and after a capacity change show whether it addressed the actual bottleneck.

Scaling the application host does not increase model quota or Search capacity.
Ingestion and interactive requests share those independent service limits.

<span id="turn-the-result-into-a-cost-plan"></span>

## Capacity and cost

The Agent-specific [Cost planning](cost-planning.md) reference covers region,
enabled resources, measured usage and availability requirements. Shared
infrastructure estimates are pricing examples, not workload capacity profiles.
A recorded configuration, workload baseline and test evidence allow later
capacity changes to be evaluated consistently.
