<span id="operations"></span>

# Administration

The application has separate administrative surfaces for conversations,
configuration and document processing. Deploy and authorize only the ones
your operators need. An administrative role does not grant access to every
source document.

## Choose the administrative surface

| Surface | Purpose | Prerequisite |
| --- | --- | --- |
| Classic orchestrator dashboard | Inspect classic conversations and change allowlisted settings. | `ENABLE_DASHBOARD=true`, built dashboard assets and configured Entra access. |
| Ingestion dashboard | Inspect files, jobs, schedules and allowlisted ingestion settings. | Selected ingestion service and its administrative surface. |
| Hosted user panel | Owner-scoped conversation and feedback APIs in the UI service. | Panel deployment, active continuity and user-history gates. |
| Operator overview and curation | Aggregate metrics and blocked-file curation. | Panel deployment and separately validated operator authorization. |

The default `hosted-no-panel` topology does not deploy the hosted administrative
panel or its application Cosmos resources. Selecting a panel topology does
not automatically enable history, feedback or operator access.

## Classic orchestrator dashboard

Set `ENABLE_DASHBOARD=true` and deploy the built dashboard assets to serve
`/dashboard/`. Use one Entra app registration for both the dashboard SPA and API.
Its client ID is the backend token audience.

1. Add the **Single-page application** platform with the redirect
   `https://<orchestrator-host>/dashboard/`, including its trailing slash.
   Add local redirects only for development.
2. Expose the delegated API scope `api://<client-id>/access_as_user` and
   complete the required consent.
3. Define an enabled **Users/Groups** app role with exact value `Admin` and
   assign approved operators through the enterprise application.
4. Publish `OAUTH_AZURE_AD_TENANT_ID` and `OAUTH_AZURE_AD_CLIENT_ID`.
   `OAUTH_AZURE_AD_API_SCOPE` can override the requested scope on that API.
5. Restart the backend and sign in again after role changes.

Use the dashboard API's access token, not a Graph token. An invalid bearer
returns `401`, and a valid token without `Admin` returns `403`.
A configured tenant without a client ID is a configuration error.
The SPA needs no client secret. Backend OBO secrets remain server-side.

!!! warning "Configure identity before exposing a dashboard"
    The classic dashboard's development gate is open when the tenant is absent.
    The dashboard can write allowlisted settings, it is not read-only.
    Do not expose this development configuration as a production endpoint.

Your tenant's **Assignment required** policy can reject an unassigned user
before the API is reached. Preserve the approved production policy rather
than weakening it just to observe an API denial.

## Ingestion dashboard

The ingestion dashboard manages document processing, not conversational agents.
Review [Jobs & schedules](ingestion-jobs.md) before starting or changing a job.
Startup and cron runs can write or delete indexed content.

With `DEPLOY_HOSTED_AGENT_ORCHESTRATION=false`, the classic ingestion admin
routes mount. In hosted mode, `DEPLOY_ADMINISTRATIVE_PANEL=true` is also
required to mount the hosted admin surface. A built frontend bundle is needed
for its dashboard UI.

Classic manual job runs and configuration mutations use the `Admin` gate when
Entra is configured. Administrative reads and file unblocking do not share
that unconditional gate. Protect the whole service boundary deliberately,
including the tenant-free development configuration.
Hosted `/api/panel/*` instead requires a validated `Admin` bearer with no
tenant-free bypass.

The ingestion panel exposes its own feedback schema and an ingestion overview.
Its conversation-history endpoint returns `501`, it does not retrieve managed
Foundry transcripts. Do not assume it shares the UI panel's feedback schema.

## Hosted conversation and feedback panel

User-facing UI routes require `DEPLOY_ADMINISTRATIVE_PANEL`, active hosted
continuity and `PANEL_HISTORY_ENABLED`. Configure the token audience through
`PANEL_CONVERSATIONS_TOKEN_AUDIENCE`, the tenant through
`PANEL_CONVERSATIONS_TENANT_ID` or the OAuth tenant, and the required Cosmos
metadata access.

`PANEL_CONVERSATION_ENUMERATION_MODE=owner_index` is the default.
Delegated enumeration requires separate evidence through
`PANEL_HISTORY_OWNER_BINDING_VALIDATED`. These gates do not grant Azure
permissions. Missing active gates return `503`.

The default owner-index and feedback containers are
`panel-conversation-owner-index` and `panel-feedback`. Cosmos holds metadata,
not the managed transcript. Follow [Conversations & files](conversations.md)
and [User feedback](user-feedback.md) for their setup and limitations.

## Operator overview and curation

Enable `PANEL_OPERATOR_SURFACES_ENABLED` only after validating the approved
operator role or group. Set an explicit `PANEL_OPERATOR_APP_ROLE` or
`PANEL_OPERATOR_GROUP_ID`. These are separate from user-history access.

The ingestion operator routes additionally require the
`DATA_INGEST_APP_APIKEY` cursor-signing secret and panel deployment.
They accept delegated user tokens, not app-only tokens. Aggregate metrics
suppress groups smaller than `PANEL_OVERVIEW_MIN_CARDINALITY`, default `5`.
Blocked-file curation operates on Blob logs, not conversation messages.
Its caller-bound signed cursor expires after `PANEL_CURSOR_TTL_SECONDS`,
default `600`.

Configuration writes can partially succeed. A saved value is not undone by a
failed local refresh or later schedule-application error. Verify effective
settings before retrying. Use [Application settings](application-settings.md)
and the [API reference](application-api.md) for the corresponding boundaries.

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

<span id="upgrade-ingestion-selection-to-v430"></span>
<span id="change-ingestion-selection-safely"></span>

Changing [ingestion selection](ingestion.md) does not remove existing resources
or permissions. Environment destruction is a separate authorized operation,
not an application rollback.
