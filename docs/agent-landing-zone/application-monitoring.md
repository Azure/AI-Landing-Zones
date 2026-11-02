# Monitoring & audit

Use Application Insights and Azure Monitor to follow requests, diagnose
failures and inspect ingestion results. Audit events add structured evidence
about application operations. They do not replace user authorization, data
retention policies or service backups.

## Native tracing

Microsoft Foundry and Microsoft Agent Framework provide native
OpenTelemetry-based tracing. The reference orchestrator uses that integration
to record agent execution, model calls and tool operations.

**Foundry Hosted:** the official hosting SDK configures OpenTelemetry and export
using the Application Insights connection string.
View execution in the Foundry project under **Agents > Traces**, with
Application Insights for deeper investigation.

**Container Apps with Durable Task Scheduler:** the native worker configures
Azure Monitor export, and Agent Framework instrumentation is enabled by default.
Investigate the worker and its dependencies in Application Insights.
This host is separate from Foundry Hosted publications.

### Set up trace export

The standard full-stack deployment provisions or reuses Application Insights,
connects it to Foundry and publishes `APPLICATIONINSIGHTS_CONNECTION_STRING`
in App Configuration under `agent-lz`. The orchestrator reads it at startup.
There is no separate application feature flag to enable basic tracing.

When reusing infrastructure, verify that the Foundry project is connected to
the intended Application Insights resource and that the connection string
points to that same resource. Use the declared
[deployment inputs](configuration.md), not a manually copied connection to a
different environment.

The investigating operator needs access to the Foundry project and its
telemetry. The Foundry tracing quickstart lists Foundry User and
Log Analytics Reader, with Privileged Monitoring Data Reader when protected
tables require it.
See the [official tracing prerequisites](https://learn.microsoft.com/azure/foundry/observability/quickstarts/quickstart-tracing-hosted-agent).

Changing the export destination requires restarting or redeploying the
affected process. It is not a per-message functional refresh.
Generate a real request after deployment before looking for its trace.

### View traces in Foundry

1. Open the deployed Foundry project, then **Agents > Traces**.
2. Select the Hosted agent and a time range that includes your request.
3. Find the request by trace ID, response ID or time.
4. Open the trace to inspect the hosting operation and its nested Agent
   Framework spans, including the model and tools that actually ran.

Foundry emits service-side invocation telemetry automatically.
The application instrumentation supplies the agent/model/tool detail.
A service invocation trace alone does not establish that every application
span was exported.

If traces are missing, check the selected project, connected Application
Insights resource, startup configuration, ingestion delay, operator access
and exporter errors. A custom process override
`ENABLE_INSTRUMENTATION=false` disables Agent Framework instrumentation.
For Container Apps, start in Application Insights rather than expecting a
Hosted-agent entry in Foundry.

### Traces, logs and content are separate

Basic traces do not require prompt or response-content capture.
Keep that capture off unless its privacy and retention requirements have been
approved. Timing, outcome and correlation remain useful without transcripts.

In the Container Apps worker, `AZURE_MONITOR_DISABLE_LOGGING=true` suppresses
general application-log export, not tracing.
`AUDIT_EVENTS_ENABLED` controls the orchestrator's supported audit hooks,
not the creation of basic agent traces. The Hosted SDK owns its own telemetry
setup, so do not apply the worker's logging switch as a universal control.

See [telemetry settings](application-settings.md#telemetry-settings),
[content capture](#content-capture-and-privacy) and
[Agent Framework observability](https://learn.microsoft.com/agent-framework/agents/observability)
for the separate controls.

## Check an application request

1. Record the deployed application revision and the time of the request.
2. Follow its correlation information through the UI, orchestrator and the
   selected retrieval, MCP or ingestion path.
3. Check both the HTTP outcome and the operation result. An ingestion envelope
   can return HTTP success while individual records failed.
4. For denied access, inspect safe status and correlation fields. Do not
   enable token or document-content logging to investigate a permission problem.

Process health probes confirm that a process is running. They do not establish
successful indexing, correct source access or production readiness.
Use [Troubleshooting](troubleshooting.md) for boundary-specific diagnosis.

## Native runtime audit scope

The orchestrator provides audit hooks for in-process tool operations.
Use those events alongside native host traces and the remote service's
own evidence. An orchestrator tool event describes that local operation,
not every step performed inside a remote service.

### How to enable orchestrator tool audit

1. Complete [trace export setup](#set-up-trace-export) and verify a normal
   application request before enabling additional event export.
2. Choose a secret name for the audit HMAC key in the installation's Key Vault.
   Add that **name**, not its value, to the azd environment's JSON array
   `NATIVE_TOOL_SECRET_NAMES` before provision. Preserve existing declared names.
   Run `azd provision` for the selected installation.
3. Once the vault is available, store exactly 32 random bytes encoded as
   Base64, Base64URL or hexadecimal under the selected secret name.
   Open the vault's **Secrets** page in Azure Portal and use the installation's
   approved secret-generation procedure. The operator needs secret-write
   permission; the runtime needs only its secret-scoped read grant.
4. In App Configuration **Configuration explorer**, under label `agent-lz`,
   create `AUDIT_HMAC_KEY` as a **Key Vault reference** to that secret.
   Set `AUDIT_HMAC_KEY_ID` to your nonsecret key identifier.
   Keep `AUDIT_SENSITIVE_CONTENT_ENABLED=false`.
5. Set the nonsecret key `AUDIT_EVENTS_ENABLED` to string `true` under the
   same label. Record these declarations in the installation's approved
   configuration. Follow [Application settings](application-settings.md#edit-an-existing-nonsecret-key)
   for the operator's permissions and edit location.
6. Run `azd deploy`. The lifecycle grants the declared secret to the selected
   orchestrator identity, including the identity created by a Hosted
   publication. Invoke an enabled in-process tool and inspect the resulting
   events in Application Insights. Check exporter errors and verify that no
   credentials or message content were captured.

For the Container Apps worker, the audit-only logging mode exports audit
events while `AZURE_MONITOR_DISABLE_LOGGING=true` keeps general log export
off. The Hosted SDK configures its own export.
Keep the selected host's telemetry configuration with that host.

Audit delivery is best-effort, not an immutable ledger or a compliance
certification. Disabling emission does not delete exported events.
Correlate native UI actions, provider outcomes and in-process tool events
without claiming complete remote-call coverage.

## MCP query correlation

Authenticated discovery with `MCP_TOOLSETS=[]` returns zero tools by design,
not a catalog failure. Verify denied callers for empty servers too.
SQL query evidence below applies only when `nl2sql` is selected.

SQL generation, catalog retrieval and execution occur in the separate
Agent App MCP Server, not as local orchestrator SQL helpers. Correlate the
application request with the returned `query_id`, `source_id` and
`metadata_version`, then inspect safe status/limit information at the server.
Do not infer a complete server audit stream from an orchestrator tool event.

Tokens, generated SQL, returned rows and internal reasoning are not logged
by default. A successful zero-row query is distinct from an authorization,
validation, dependency or limit failure. `/healthz` establishes liveness, not
authenticated discovery or SQL readiness.
See [NL2SQL evidence](nl2sql.md#check-before-admitting-users) and
[MCP troubleshooting](troubleshooting.md#agent-app-mcp-failures).

## Ingestion audit and provenance

Ingestion emits audit events through its existing OpenTelemetry pipeline
without an `AUDIT_EVENTS_ENABLED` opt-in. Export depends on telemetry setup.
The event names are:

- `ingestion.run.started`
- `ingestion.run.completed`
- `ingestion.run.failed`
- `ingestion.run.cancelled`
- `ingestion.document.indexed`
- `ingestion.document.rejected`
- `ingestion.document.deleted`

They are exported under the `agentlz.audit.` prefix. Run wrappers attempt
one start event and one terminal event. Document events carry run correlation.
A completed run means its wrapper did not observe a failure, not that every
possible source document was processed. Check confirmed Search write/delete
results as well as [job status](ingestion-jobs.md).

`INGESTION_PROVENANCE_ENABLED` defaults to `false`. Enable it to add optional
provenance to indexed/deleted events.
`INGESTION_REQUIRE_GOVERNANCE_METADATA=true` also requires provenance or startup
fails. It reports classification and right-to-use only when explicitly supplied,
it does not reject indexing merely because they are absent.

Without strict metadata reporting, defaults are
`INGESTION_DEFAULT_CLASSIFICATION=unclassified` and
`INGESTION_DEFAULT_RIGHT_TO_USE=not_asserted`.
Source/version digests and checksums can reveal equality or existence even
without raw content. Review their retention and readership accordingly.
The `delete_after` provenance field is metadata, not an automatic purge schedule.

## Content capture and privacy

Keep prompt, completion and sensitive audit-content capture off unless its
purpose, access controls and retention have been approved.
For hosted orchestration, the deployment input
`HOSTED_AGENT_CAPTURE_MESSAGE_CONTENT` supplies
`OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` and defaults to `false`.
A change requires a new hosted version. Leave it off when enabling or
investigating basic traces.

After privacy approval, change `HOSTED_AGENT_CAPTURE_MESSAGE_CONTENT` in the
selected azd environment **before** `azd deploy`. The deployment maps it into
the Hosted process environment. Keep it `false` for ordinary diagnostics.
Set the approved retention and telemetry-reader permissions before collecting
any content.

An audit-content allowlist does not establish that every native path has
capture wired, nor guarantee that user-authored content is safe to export.
UI metadata deliberately contains no transcripts, tokens or attachment bytes;
native input and telemetry retention remain separate concerns.
Never log tokens, client credentials or authentication claims.

## Event schemas and investigation

The component repositories retain the executable audit schemas and digests:
[orchestrator contracts](https://github.com/Azure/agent-app-orchestrator/tree/main/contracts)
and [ingestion contracts](https://github.com/Azure/agent-app-ingestion/tree/main/contracts).
Use the schema corresponding to your deployed component.

Application Insights custom properties are strings. When correlating root
events, treat `parent_event_id=evt_00000000000000000000000000000000` as
no parent. Select the schema matching the component that emitted the event.

Reverting an image does not restore deleted documents, undo configuration
writes or remove telemetry. Follow separately approved data restoration,
reingestion and [configuration recovery](deploy-full-stack.md#rollback).
For a workload evaluation and release workflow, see [AgentOps](agentops.md).
