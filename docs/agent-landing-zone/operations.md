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

An administrative panel is not required for native persistence.
Do not deploy a classic orchestrator or ingestion service to act as a second
workflow-state store. If an enabled UI feature requires a metadata store,
provision that dependency directly and grant access to its actual consumer.

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
Do not assume the ingestion dashboard is a consolidated native history or
feedback administration surface.

## Ingestion dashboard

The optional ingestion service manages source processing, not agent/workflow
execution. Review [Jobs & schedules](ingestion-jobs.md) before starting or
changing jobs: startup and scheduled runs can index and delete content.

With `DEPLOY_HOSTED_AGENT_ORCHESTRATION=false`, its ordinary ingestion admin
routes mount. In hosted mode, `DEPLOY_ADMINISTRATIVE_PANEL=true` is also
required to mount the hosted admin surface. A built frontend bundle is needed
for the dashboard UI. Hiding the panel does not disable document APIs or jobs.

Manual job runs and configuration mutations use the `Admin` gate when Entra
is configured. Administrative reads and file unblocking do not all share that
unconditional gate. Protect the whole service boundary deliberately, including
the tenant-free development configuration.
Hosted ingestion `/api/panel/*` instead requires a validated `Admin` bearer
with no tenant-free bypass. These gates are separate from UI user history.

The ingestion panel exposes its own feedback schema and an ingestion overview.
Its conversation-history endpoint returns `501`; it does not retrieve managed
native transcripts. Do not assume it shares the UI's metadata or feedback
schema. See the [ingestion API contracts](application-api.md#ingestion-administration).

### Operator overview and curation

Enable `PANEL_OPERATOR_SURFACES_ENABLED` only after validating the approved
operator role or group. Set an explicit `PANEL_OPERATOR_APP_ROLE` or
`PANEL_OPERATOR_GROUP_ID`. A UI user-history permission does not imply this
aggregate/operator access.

The ingestion operator routes also require the `DATA_INGEST_APP_APIKEY`
cursor-signing secret and panel deployment. They accept delegated user tokens,
not app-only tokens. Aggregate metrics suppress groups smaller than
`PANEL_OVERVIEW_MIN_CARDINALITY`, default `5`.
Blocked-file curation operates on Blob logs, not conversation messages.
The caller-bound signed cursor expires after `PANEL_CURSOR_TTL_SECONDS`,
default `600`. See [operator API contracts](application-api.md#operator-metrics-and-corpus-curation).

Configuration writes can partially succeed. A saved value is not undone by a
failed local refresh or later schedule-application error. Verify effective
settings before retrying.

## Configuration changes

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
  [restore a reviewed deployment](deploy-full-stack.md#roll-back-to-a-previous-release).
- Diagnose failures with [Troubleshooting](troubleshooting.md).
- For infrastructure changes, retain the provider, backend and approved
  resource-group mapping. Follow [Bicep maintenance](deploy-infra-only.md)
  or [Terraform maintenance](deploy-terraform-infra-only.md).

Native session/checkpoint state is not automatically portable across hosts or
incompatible graph publications. Retain the previous deployment's state for
rollback; do not delete, merge or convert it as part of application recovery.

<span id="upgrade-ingestion-selection-to-v430"></span>
<span id="change-ingestion-selection-safely"></span>

Changing [ingestion selection](ingestion.md) does not remove existing resources
or permissions. Environment destruction is a separate authorized operation.
