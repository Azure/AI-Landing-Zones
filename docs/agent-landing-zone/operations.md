<span id="operations"></span>

# Administration

Native execution, UI product metadata and optional document processing have
separate operational owners. Deploy and authorize only the surfaces needed
by the installation. An operator role is not blanket permission to read
every user's transcript, private attachment or source document.

## Choose the operational surface

| Area | Responsibility |
| --- | --- |
| Foundry Hosted | Native application publications, session/workflow state and host telemetry |
| Container Apps and Durable Task Scheduler | Durable worker lifecycle, scheduler connectivity and native run state |
| UI/BFF | Owner mappings, history discovery, feedback and enabled product administration |
| Optional ingestion service | Files, indexing/purge jobs, schedules and allowlisted processing settings |
| App Configuration and Key Vault | Declared settings, supported refresh, scoped access and secret rotation |

Native persistence belongs to the selected execution host.
Do not deploy an extra execution or ingestion service to act as a second
workflow-state store. If an enabled UI feature requires a metadata store,
provision that dependency directly and grant access to its actual consumer.

## How to inspect an application

1. Select the installation's azd environment in its project directory with
   `azd env select <environment-name>`. Confirm its subscription, resource
   group and selected execution host before opening an administrative tool.
2. For **Foundry Hosted**, open that Foundry project and its **Agents**
   view. Select the conversational or workflow publication that handled the
   request. Use [native traces](application-monitoring.md#view-traces-in-foundry)
   to correlate a real invocation.
3. For **Container Apps**, open the worker's Container App in the Azure portal.
   Check its active revision and logs, then the deployment's Durable Task
   Scheduler and task hub for native execution state.
4. For a user's conversation or pending decision, use the authenticated
   application UI. Reopen the owner-bound session and inspect current progress
   before submitting an action.
5. Record the deployment revision, request/run identifier, time and safe
   failure status. Follow [Troubleshooting](troubleshooting.md) for the failing
   boundary rather than retrying a state-changing operation blindly.

Azure resource administration and application-user access are separate
permissions. Use the user's approved application path when acting on their
session. Use the service's administrative access for resource health and
diagnostics.

### Inspect Operate and Traces in isolated networks

Human operators inspecting **Operate** and **Traces** in the Foundry portal for
an isolated deployment need both private DNS resolution and Azure Monitor read
RBAC:

- **Private DNS and firewall path:** resolve AMPLS zones (`privatelink.monitor.azure.com`, `privatelink.oms.opinsights.azure.com`, `privatelink.ods.opinsights.azure.com`, `privatelink.agentsvc.azure-automation.net` and `privatelink.blob.core.windows.net`) over VPN or ExpressRoute with Private DNS Resolver, and allow outbound HTTPS (`443`) to Azure Monitor ingestion and query endpoints. See the [BYO hub Private DNS checklist](network-isolation.md#byo-hub-private-dns-checklist).
- **Operator Azure Monitor RBAC:** assign `Log Analytics Reader` on Application Insights and the linked Log Analytics workspace, plus `Privileged Monitoring Data Reader` when `AppGenAIContent` is `Protected`.

### Run scheduled trace evaluations on hosted agents

Use **scheduled trace evaluations** (`azure_ai_traces`) for hosted agents
instead of `responseCompleted` continuous evaluation rules, which are not
supported for hosted agents. Check per-item agent version
(`gen_ai.agent.version` or `FOUNDRY_AGENT_VERSION`) and non-empty output across
rolling trace lookback windows so older versions or empty warm-up spans do not
skew evaluation scores.

Opt in before `azd provision` only to the least-privilege evaluation roles
required by the Foundry project managed identity:

- **`GRANT_PROJECT_TRACE_EVALUATION_READER=true`** (`grantProjectTraceEvaluationReader`): grants the Foundry project managed identity `Reader` on Application Insights and `Log Analytics Data Reader` on the linked Log Analytics workspace.
- **`GRANT_PROJECT_PROTECTED_TRACE_CONTENT_READER=true`** (`grantProjectProtectedTraceContentReader`): strictly opt-in grant assigning `Privileged Monitoring Data Reader` conditioned with Azure ABAC v2.0 restricting workspace table reads to `AppGenAIContent` when `Protected`.

When model calls traverse an AI Gateway, allowlist each hosted agent's
dedicated runtime identity (created on first `azd deploy` publication) at the
gateway rather than only the Foundry project identity.

## Conversations, workflows and feedback

Use the selected host's official client and service operations to inspect
native execution. Product-facing reads and actions must pass through the
authenticated BFF owner checks; arbitrary run/session IDs are not permission.

Pending human input belongs to the native workflow. An operator UI must not
silently convert a pending request into an approval or manufacture a new run
after a browser disconnect.
See [Workflows & human input](workflows.md).

Metadata and native state have distinct lifecycle operations. Define retention,
deletion and partial-failure handling for both, including attachments,
feedback, audit data and backups.
[Conversations & files](conversations.md) and
[User feedback](user-feedback.md) explain the product boundaries.
Use the ingestion dashboard for corpus processing and jobs.
Use the application UI for owner-scoped conversations, workflow actions
and response feedback.

## Ingestion dashboard

The optional ingestion service manages source processing, not agent/workflow
execution. Review [Jobs & schedules](ingestion-jobs.md) before starting or
changing jobs: startup and scheduled runs can index and delete content.

The ingestion component includes administrative API and dashboard contracts
for explicitly managed component deployments. The native platform keeps the
aggregate operator surface disabled. Choosing an orchestration host does
not activate that dashboard.

For a component deployment that includes administration, build its frontend
before backend startup using the
[local dashboard procedure](local-development.md#operator-dashboard-frontend).
The static bundle is needed for the dashboard, not for API routes.
Check the mounted routes and authorization independently of UI visibility.

Manual job runs and configuration mutations use the `Admin` gate when Entra
is configured. Administrative reads and file unblocking do not all share that
unconditional gate. Protect the whole service boundary deliberately, including
the tenant-free development configuration.
The ingestion component's `/api/panel/*` requires a validated `Admin` bearer.
These administrative gates are separate from UI user-history access.

The ingestion panel exposes ingestion-specific records and an ingestion
overview. Its conversation-history endpoint returns `501`.
Use the [ingestion API contracts](application-api.md#ingestion-administration)
to select the supported administration operations.

### Operator overview and curation

Before exposing operator routes, a component-managed integration requires the
selected administrative surface and `PANEL_OPERATOR_SURFACES_ENABLED`.
The integration also requires an explicit `PANEL_OPERATOR_APP_ROLE` or
`PANEL_OPERATOR_GROUP_ID`.
The `DATA_INGEST_APP_APIKEY` cursor-signing secret must be securely resolved.
These are component contracts, not an activation recipe for the reference
platform: its configuration ownership fixes operator surfaces to `false`.

Use the [application integration procedure](build-your-own-app.md) to review
a separately owned composition, configuration and authorization boundary.
Do not override the reference platform's protected value in the portal.
Operator routes enforce their bearer/Admin policy without a tenant-free
development bypass and accept delegated operator tokens, not app-only tokens.
A UI history permission does not grant aggregate access.

Aggregate metrics suppress groups smaller than
`PANEL_OVERVIEW_MIN_CARDINALITY`, default `5`.
Blocked-file curation operates on Blob logs, not conversation messages.
The caller-bound signed cursor expires after `PANEL_CURSOR_TTL_SECONDS`,
default `600`. See [operator API contracts](application-api.md#operator-metrics-and-corpus-curation).

Configuration writes can partially succeed. A saved value is not undone by a
failed local refresh or later schedule-application error. Verify effective
settings before retrying.

## Configuration changes

### How to apply an operational change

1. Find the setting in [Application settings](application-settings.md).
   Identify its owner, edit location and refresh or restart requirement.
2. For history, feedback or private attachments, use the
   [product-feature procedure](application-settings.md#enable-a-product-feature)
   before provision. The lifecycle applies their metadata resources and grants.
3. For an existing operator-managed key, edit the intended App Configuration
   resource with label `agent-lz` using the
   [portal or CLI procedure](application-settings.md#edit-an-existing-nonsecret-key).
4. Apply the required refresh, provision or redeployment. Check a new
   operation and its denied-access case before treating the change as effective.
5. Record the input change with the installation's configuration so later
   provisioning reproduces it. Use [secret rotation](deploy-full-stack.md#rotate-a-secret)
   for credentials rather than placing them in ordinary key values.

Use the [ownership inventory](configuration.md#configuration-ownership-and-declarations)
and [Application settings](application-settings.md) before editing a key.
Supported functional parameters refresh through the official provider.
Running workflows retain their functional snapshots; current authorization
is rechecked separately.

Structural changes to host, graph, identity, persistence, registration names
or process bootstrap require compatible deployment. An accepted write is
not proof that every affected process loaded it.

<span id="lifecycle-guidance-has-moved"></span>

## Maintenance and recovery

- [Monitor requests and audit events](application-monitoring.md).
- [Redeploy applications](deploy-full-stack.md#redeploy-applications-only),
  [rotate secrets](deploy-full-stack.md#rotate-a-secret) or
  [review recovery safeguards](deploy-full-stack.md#rollback).
- Diagnose failures with [Troubleshooting](troubleshooting.md).
- For infrastructure changes, retain the provider, backend and approved
  resource-group mapping. Follow [Bicep maintenance](deploy-infra-only.md)
  or [Terraform maintenance](deploy-terraform-infra-only.md).

Retries and redeployments must not delete existing user data or resources.

<span id="change-ingestion-selection-safely"></span>

Changing [ingestion selection](ingestion.md) does not remove existing resources
or permissions. Environment destruction is a separate authorized operation.
