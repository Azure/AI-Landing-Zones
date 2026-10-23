# Sizing and capacity

Plan capacity around the workload you expect to run, not only the number of
people who can sign in. Concurrent agent requests, model calls, tool latency and
document processing place different demands on the deployment.

Choose the [deployment shape](planning.md) first. Size each service below, then
use [Cost planning](cost-planning.md) to estimate the selected capacity.

!!! note "Defaults are not workload tiers"
    The starting points below describe platform v4.3.0, reviewed
    October 23, 2026. They are not benchmarked small/medium/large profiles or
    throughput guarantees. Use your composed parameters and actual deployed
    configuration, especially for existing environments and custom applications.

## Establish a workload baseline

Record these inputs before choosing resource capacity.

| Area | Questions to answer |
| --- | --- |
| Agent traffic | How many requests run concurrently at peak? How long do turns take, and how many model or tool calls does each strategy make? |
| Models | Which deployments are required? What are the expected input/output token volumes, token-rate limits and target response times? |
| Knowledge and ingestion | How many documents and vectors are stored? What are their sizes, formats, update rate and ingestion completion targets? Will ingestion run alongside peak interactive traffic? |
| Hosting | Which strategies must run, on which host? What CPU, memory, concurrency and scaling behavior does representative execution require? |
| Availability and operations | What recovery targets, environment separation, telemetry retention and private-network requirements must the deployment meet? |

Start with [Configuration](configuration.md) and [Agent hosting](hosted-agents.md)
to identify the applicable inputs and host constraints. Use the
[resource inventory](../bicep/deployed-resources.md) to identify enabled resources,
then confirm them against your platform's composed parameters: the foundation
inventory is not a promise that every Agent Landing Zone topology has the same
resource count.

## Models and quota

The root `main.parameters.json` selects a `chat` deployment of `gpt-5-nano`
and a `text-embedding` deployment of `text-embedding-3-large`, each with
`sku.capacity=100`. This is a deployment capacity input, **not** 100 requests
per second or a model-independent token rate. Confirm quota units, deployment
type and regional availability for each model using the
[model quota reference](https://learn.microsoft.com/azure/ai-services/openai/quotas-limits).
Change the reviewed root `modelDeploymentList`, not an invented environment
variable.

Estimate input/output tokens per turn, calls per strategy, retries and peak
turns per minute. For ingestion, measure extracted tokens and embedding batch
volume as well. Long contexts and multiple tool/model calls can exhaust quota
even with few users. Observe throttling and token/request usage before adding
application replicas; replicas do not increase model quota.

## Search capacity

Both newly created Search services start at Standard, **one partition and one
replica**. Count the Agent Application Search service and the separate Foundry Agent
Service Search service when both creation paths are enabled. They use
`AZURE_SEARCH_LOCATION`, falling back to `AZURE_LOCATION`; quota must cover
the complete enabled service count in that region.

- **Partitions:** measure index/vector storage, document count and growth.
  Use a representative corpus to measure chunk expansion and index size;
  source-file size alone is not the index footprint.
- **Replicas:** measure query latency/throttling under peak retrieval plus
  concurrent indexing. Check the current
  [Search reliability and SLA requirements](https://learn.microsoft.com/azure/search/search-reliability)
  before approving production availability. The one-replica default is not
  a high-availability design.
- **Change path:** the shipped `infra/main.bicep` declares SKU, partition and
  replica counts as literals for both services. There is no root
  `SEARCH_REPLICA_COUNT` or equivalent scaling input. Maintain a reviewed
  infrastructure change for persistent sizing; portal-only changes can be
  reset by provisioning. `aiSearchResourceId` reuses Foundry backing Search,
  not Agent Application Search.

Check current [Search service limits](https://learn.microsoft.com/azure/search/search-limits-quotas-capacity)
for the selected tier, region and service creation date. Private native Blob
ingestion also requires approved, ready shared private links; extra Search
capacity does not bypass that gate.

## Application hosting

| Host/resource | Shipped starting point | Practical sizing action |
| --- | --- | --- |
| Foundry hosted orchestrator | The Agent Application's `hosted-agent/azure.yaml` declares `2` CPU and `4Gi` memory. | Measure memory peaks, streaming latency and concurrent turns on the supported strategy. `HOSTED_AGENT_CONTAINER_CPU` / `HOSTED_AGENT_CONTAINER_MEMORY` affect provisioning, but do not override the child's literal deployment fields. Coordinate a compatible definition/handoff change and deploy a new agent version. Container Apps scale settings do not control this host. |
| Frontend and classic orchestrator Container Apps | Root entries use `profile_name=main`, `min_replicas=1`, `max_replicas=1`. With no explicit resource size, foundation placeholders use `0.5` CPU / `1.0Gi`. Hosted topology normally omits the classic orchestrator. | Inspect active revisions after application deployment. Measure CPU, memory, concurrent streams and startup latency. Review `containerAppsList` resource/replica settings and the child deployment behavior together; a placeholder size is not a runtime performance guarantee. |
| Agent App Ingestion (optional) | Root entry specifies `1.0` CPU / `3.0Gi` and one minimum/maximum replica on `main`. | Test large files and expensive formats, peak memory, processing backlog and embedding/Search throttling. Increasing replicas is not proof of safe parallel ingestion; validate duplicate handling and shared source/index writes. |
| Container Apps workload profiles | `Consumption` plus `main` D4 with `minimumCount=0`, `maximumCount=1`. | Check aggregate CPU/memory placement as well as per-app limits. Raising app replicas alone does not raise the profile's node ceiling. Minimum app replicas can keep a node allocated despite the zero-node profile minimum. |

The root arrays/objects above belong in reviewed `main.parameters.json`;
`infra/main.parameters.json` is generated. Check the deployed configuration
after each provision/deploy. For hosted strategy eligibility, immutable image
handoff and history limitations, use [Agent hosting](hosted-agents.md).
Conversation continuity limits are not compute-sizing controls.

## Data, builds and observability

| Resource | What to measure and decide |
| --- | --- |
| Agent Application Cosmos DB | `hosted-no-panel` omits it; `hosted-panel` and `classic` select it. The workload account is serverless, with `dbDatabaseThroughput` left null. Measure consumed RUs, throttling, partition-key distribution, item growth and retention. Setting a provisioned RU/s value alone does not convert the account's throughput mode. Foundry backing Cosmos DB is separate. |
| Blob storage | Measure original files, extracted images, conversation attachments where enabled, updates and retention. Check transaction rate and ingestion completion time, not only stored GB. Omitting Agent App Ingestion does not omit native source processing. |
| Registry and private build pool | Measure image sizes, build duration and parallel build demand. Isolated hosted preparation requires the private ACR Tasks pool; increasing runtime compute does not speed it up or connect the deployment runner. Confirm pool SKU/region capacity and allowed package feeds. |
| App Configuration and Key Vault | Include startup/restart bursts across components and service request limits. Keep secrets as Key Vault references; do not copy them into configuration to reduce lookups. |
| Log Analytics and Application Insights | Measure ingestion volume and set retention/sampling according to investigation and compliance needs. Message-content capture is a privacy decision, not a required sizing test. |

## Validate the initial capacity

1. **Choose explicit targets.** Record acceptable response time, error rate,
   ingestion delay and peak concurrency for representative requests.
2. **Check service limits and quota.** Confirm regional availability and capacity
   for every enabled service. Template defaults and a passing preflight check
   are not workload sizing evidence.
3. **Measure representative behavior.** In a nonproduction environment, exercise
   the selected strategy, configured tools, document sizes and ingestion path.
   Include authentication and document allow/deny checks.
4. **Observe the bottleneck.** Use service metrics and application traces to
   distinguish model throttling, Search limits, tool latency and runtime
   CPU/memory pressure before changing capacity.
5. **Recheck cost and repeat.** Change the constrained resource, repeat the same
   tests and record the chosen settings and results.

Scaling the application host does not increase model quota or Search capacity.
Treat those as separate limits, and account for shared demand when ingestion
and interactive requests use the same services.

## Turn the result into a cost plan

Use the Agent-specific [Cost planning](cost-planning.md) checklist. Recalculate
for your region, enabled resources, measured usage and availability requirements.
Shared foundation example estimates are not a quote or a validated production
sizing profile.

Record the selected configuration with the workload assumptions and test
evidence so that a later capacity change can be evaluated against the same
baseline. Then follow [Deploy infrastructure only](deploy-infra-only.md) or
[Deploy the full stack](deploy-full-stack.md).
