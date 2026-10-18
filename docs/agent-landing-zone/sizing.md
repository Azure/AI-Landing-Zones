# Sizing and capacity

Plan capacity around the workload you expect to run, not only the number of
people who can sign in. Concurrent agent requests, model calls, tool latency and
document processing place different demands on the deployment.

!!! info "Detailed guidance is planned"
    A benchmark-backed sizing guide with validated workload profiles is planned.
    This page provides planning questions, not tested small/medium/large tiers
    or a throughput guarantee.

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

Use [Cost planning](../architecture/cost-guide.md) and
[Deployed resources and cost estimates](../bicep/deployed-resources.md) as starting
points. Recalculate for your region, enabled resources, measured usage and
availability requirements. The example estimates are not a quote or a validated
production sizing profile.

Record the selected configuration with the workload assumptions and test
evidence so that a later capacity change can be evaluated against the same
baseline. Then follow [Deploy infrastructure only](deploy-infra-only.md) or
[Deploy the full stack](deploy-full-stack.md).
