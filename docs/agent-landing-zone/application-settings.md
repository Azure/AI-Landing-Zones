# Application settings

Application settings control the UI, native agent/workflow and optional
ingestion and MCP services. Azure App Configuration remains an intentional dependency.
Components read the `agent-lz` label; a label is not an environment-isolation
boundary. Keep stores, identities and secrets separate between environments.

This dependency belongs to the bundled applications, not platform resource
discovery. Deployment tooling uses verified provider `DEPLOYMENT_METADATA`.
Custom applications can select `containerEnv` or `none` with their own runtime
contract. See [runtime configuration mode](configuration.md#runtime-configuration-mode).
The default `appConfig` behavior and `agent-lz` ownership rules below are unchanged.

[Deployment settings](configuration.md) covers resource selection, provisioning
ownership and generated outputs. Read individual nonsecret keys rather than
dumping a store or environment.

## Choose where to configure it

Start in the project directory created by
[the deployment guide](deploy-full-stack.md). Keep the same azd environment
and infrastructure provider throughout configuration, provision and deploy.

| What you are changing | Where to edit it | When |
| --- | --- | --- |
| Host, application mode, history, feedback or private attachments | The selected azd environment, using the supported `azd env set` inputs | Before `azd provision`, then deploy |
| An agent capability or another declared application setting | `parameters.additionalAppConfigurationSettings.value` in the project-root `main.parameters.json` | Before provision, after declaring the capability's resource dependencies |
| An operator-managed value in an existing deployment | Azure App Configuration, key label `agent-lz` | After provision, followed by the setting's documented refresh or restart |
| Generated endpoints, metadata account/database names or identity allowlists | Their provisioning inputs and lifecycle | Provision/deploy publishes the resolved values |
| A component's process/bootstrap environment | Its application deployment definition or documented deployment input | Before publishing or restarting that component |

These are different configuration surfaces. An arbitrary `azd env set`
does not create an App Configuration key. Conversely, editing a key in the
Azure portal does not provision its resources or grant its consumer access.

## Enable a product feature

History, feedback and private attachments have supported azd deployment inputs.
Their defaults are `false`. The lifecycle uses these choices to select
application Cosmos DB, create the owner-partitioned metadata container and
grant the frontend access before publishing the settings under `agent-lz`.

For example, to enable feedback:

1. In the initialized project directory, select the intended environment with
   `azd env select <environment-name>`. Use the environment created during
   initialization, or the existing deployment you are updating.
2. Set the feature **before provisioning**:

   ```bash
   azd env set ENABLE_USER_FEEDBACK true
   ```

3. Run `azd provision` to create or reuse the metadata resources and apply
   the frontend's scoped permissions.
4. Complete any sign-in handoff in the
   [deployment guide](deploy-full-stack.md), then run `azd deploy`.
5. Sign in, obtain a response and follow the
   [feedback checks](user-feedback.md). Verify that another user's identity
   cannot act on your response.

Use the same sequence with `ENABLE_CHAT_HISTORY` for saved-history discovery
or `ENABLE_PRIVATE_ATTACHMENTS` for private conversational files.
Read [Conversations & files](conversations.md) before enabling either.
Workflow mode or `both` also selects UI metadata without enabling those features.

The lifecycle publishes `DATABASE_ACCOUNT_NAME`, `DATABASE_NAME` and
`NATIVE_UI_METADATA_CONTAINER` for the selected resources.
Keep the default container `native-ui-metadata` and partition key
`/principal_id` unless your deployment deliberately declares a different
compatible container. Do not copy resource names from another environment.

For an existing deployment, enabling one of these features still requires
provision and deploy. Disabling it does not delete retained metadata.
Apply the installation's retention policy separately.

## Configure an agent capability

For [Inline visuals](inline-visuals.md), use the
per-agent `AGENT_PRESENTATION_SETTINGS` example through the same declaration
path below. It is off by default and needs no new presentation resources.

Agent capabilities such as Foundry IQ have application keys and separate
resource prerequisites. Complete the selected capability's guide before
enabling its key. For example, [Foundry IQ](foundry-iq.md) explains the
knowledge source, Search connection and access checks needed for retrieval.

In the project-root `main.parameters.json`, append the capability's entry to
`parameters.additionalAppConfigurationSettings.value`. Preserve existing
entries, including the host and application mode:

```json
"additionalAppConfigurationSettings": {
  "value": [
    { "name": "ORCHESTRATION_HOST", "value": "${ORCHESTRATION_HOST=hosted}", "label": "agent-lz" },
    { "name": "APPLICATION_MODE", "value": "${APPLICATION_MODE=conversational}", "label": "agent-lz" },
    { "name": "FOUNDRY_IQ_ENABLED", "value": "true", "label": "agent-lz" }
  ]
}
```

Values in this list are strings. Include the `agent-lz` label.
This is a fragment of the existing parameters object, not a replacement
for the complete parameter file. Bicep and Terraform use the same
application-setting declaration.

Run the selected provider's `azd provision` and `azd deploy` sequence after
the prerequisites are ready. Verify a real allowed-source query and a
denied-source query, not just a successful key write.
Use the feature-specific guide for all additional required settings.

## Change a setting

1. Select the intended environment and check
   [configuration ownership](configuration.md#configuration-ownership-and-declarations).
   Change provisioning-managed values through their declared inputs.
2. Identify whether the setting is functional or structural using the table
   below. An accepted key write does not prove a running process loaded it.
3. Update an operator-managed key under `agent-lz`. Keep credentials as Key
   Vault references, never literal strings.
4. For a supported dynamic parameter, allow the official provider's
   refresh/cache cycle and check a new interaction. For a structural change,
   publish/redeploy the affected application with compatible configuration.
5. Verify the effective nonsecret value, a successful operation and its
   failure/denied-user behavior.

Use the [runtime-setting procedure](deploy-full-stack.md#change-a-runtime-setting)
and [secret rotation](deploy-full-stack.md#rotate-a-secret) for operational
steps. Not every component or setting shares the runtime's refresh behavior.

### Edit an existing nonsecret key

After provision, retrieve the intended store endpoint with
`azd env get-value APP_CONFIG_ENDPOINT`. In the Azure portal, open that
**App Configuration** resource, select **Configuration explorer**, find the
key with label **agent-lz** and edit its value.
Your operator identity needs App Configuration Data Owner to write keys.

For a CLI update, the equivalent operation is:

```bash
az appconfig kv set --endpoint <app-config-endpoint> --auth-mode login --key LOG_LEVEL --label agent-lz --value INFO --yes
```

Replace the endpoint with your deployment's value.
This example changes the logging level, which is read at process startup:
redeploy the affected application before checking its effective level.
Only settings explicitly documented as dynamic use a refresh cycle instead.

Record a provisioning-managed change in its declared input too, so the next
provision does not overwrite your intended value.
Keep secrets in Key Vault and use the owning component's secret-reference
procedure rather than this nonsecret-key example.

## Configuration access

Supply `APP_CONFIG_ENDPOINT` as a process bootstrap input. Managed identity
is preferred in Azure; local Azure credentials still require the appropriate
data-plane permissions and network connectivity.

Load only keys needed by the selected component, host, application mode and
capabilities. Use official provider caching and refresh, not a bespoke
configuration polling/state engine. Do not eagerly resolve unrelated Key Vault
references or require optional source credentials to start a different feature.

App Configuration Data Reader is not Key Vault secret access. Grant secret
permissions only to actual consumers at the required scope.
A missing required setting or authorization context must be reported, not
converted into an insecure fallback or a successful empty result.

If startup cannot read required configuration, check the selected endpoint,
managed identity, network path and data-plane permissions. Restore access
before admitting users. The application reports configuration failures instead
of starting with an unconfigured fallback.

## Functional parameters and deployment choices

| Kind | How it takes effect |
| --- | --- |
| Supported functional parameter | Refresh through the official provider; applies to new work after refresh |
| Workflow functional snapshot | Captured for that run; retained across pending human input and resume |
| Current user/source/tool authorization | Rechecked at each interaction; never frozen by a functional snapshot |
| Host or application mode | Deployment composition; not a per-message or UI strategy switch |
| Workflow graph/executor identifiers, native registration names | Reviewed application definition and compatible publication |
| Identity, persistence backend, endpoints or process bootstrap | Matching resources, permissions and deployment/restart |
| User delegation (`HOSTED_AGENT_AUTH_MODE`) | Structural deployment choice, persisted in App Configuration, requiring coordinated component/connection updates and new sessions when changed |
| MCP toolset selection | Startup-only; provision declared dependencies and restart/redeploy, no hot reload |

Do not assume arbitrary configuration changes can safely mutate an in-flight
workflow. A run uses the functional values captured when it started, while a
revoked user permission must still prevent a later interaction.

### Overrides and effective values

Use the exact bootstrap/configuration contract of the selected component.
A process variable, sample `.env` file or key under another label is not an
implied universal override. Remove stale conflicting declarations rather than
relying on accidental label ordering.

Verify the selected App Configuration endpoint, label, relevant nonsecret
settings and publication/revision. Do not log resolved secrets to prove access.
An unavailable required store is a readiness failure, not an offline mode.

## Find the settings for your task

| Task | Guide |
| --- | --- |
| Select application mode and host | [Native execution selection](configuration.md#native-execution-selection) |
| Configure agent instructions and capabilities | [Agents & prompts](agent-strategies.md), [Tools & MCP](agent-tools.md) |
| Operate a human-reviewed process | [Workflows & human input](workflows.md) |
| Set up login, consent and document access | [Sign-in & access](application-auth.md) |
| Configure saved history and understand private-input limits | [Conversations & files](conversations.md) |
| Enable owner-scoped feedback | [User feedback](user-feedback.md) |
| Connect a knowledge source | [Foundry IQ](foundry-iq.md), [SharePoint](sharepoint.md) |
| Schedule custom ingestion | [Jobs & schedules](ingestion-jobs.md) |
| Configure trace export and inspect agent execution | [Native tracing](application-monitoring.md#native-tracing) |
| Configure administration and audit | [Administration](operations.md), [Monitoring & audit](application-monitoring.md) |

## Native application contract

| Setting | Default or requirement |
| --- | --- |
| `APPLICATION_MODE` | `conversational`; also accepts `workflow` and `both` |
| `ORCHESTRATION_HOST` | `hosted`; also accepts `container_apps` |
| `HOSTED_AGENT_AUTH_MODE` | `user_delegated` by default, or `service_identity` for authenticated service access subject to each source's authorization |
| `HOSTED_AGENT_BASE_URL` | Actual conversational Hosted publication endpoint |
| `HOSTED_WORKFLOW_BASE_URL` | Actual separate workflow Hosted publication endpoint |
| `DURABLE_TASK_SCHEDULER_CONNECTION_STRING` | Native managed-identity binding using the actual scheduler output and configured task hub |
| `SEARCH_RETRIEVAL_ENABLED` | `false`; native Search tool capability |
| `FOUNDRY_IQ_ENABLED` | `false`; native Foundry IQ capability |
| `TOOLBOX_ENDPOINT` | Platform-derived project Toolbox endpoint under `agent-lz`, required for native Hosted Foundry IQ, structural rather than a user-configurable auth mode |
| `MCP_ENABLED` | `false`; native MCP connection/registration, derived by the integrated server lifecycle; does not select server toolsets |
| `MULTIMODAL_ENABLED` | `false`; native multimodal tool capability, separate from ingestion `MULTIMODAL` and private attachments |
| `ENABLE_CHAT_HISTORY` | `false`; explicitly selects saved-history discovery |
| `ENABLE_USER_FEEDBACK` | `false`; explicitly selects user feedback |
| `DATABASE_ACCOUNT_NAME` | Selected application Cosmos account for UI metadata |
| `DATABASE_NAME` | Selected application Cosmos database for UI metadata |
| `NATIVE_UI_METADATA_CONTAINER` | `native-ui-metadata`, with partition key `/principal_id` |
| `NATIVE_TOOL_SECRET_NAMES` | `[]`; platform scoped-grant declaration of secret **names**, not values; not consumed by the native runtime |
| `ENABLE_PRIVATE_ATTACHMENTS` | `false`; conversational inline attachments, independent of corporate ingestion; no workflow attachments |

The host, mode and three product feature flags above are selected through
their supported azd inputs. Agent capability keys use
`additionalAppConfigurationSettings`.
The lifecycle publishes both kinds under `agent-lz`.
Use the [product-feature](#enable-a-product-feature) or
[agent-capability](#configure-an-agent-capability) procedure, as appropriate.

User delegation uses one existing selector, not independent login, OBO and
retrieval switches. Both modes require login. The platform derives the retrieval
contract from the selected mode. It does not impose a Blob-only source allowlist.
Operations requiring user delegation fail explicitly when OBO is unavailable.
See [Choose user delegation](application-auth.md#choose-user-delegation)
for caller grants, source authorization and coordinated changes.

Workflow mode or `both` selects UI metadata even when both history and feedback
flags are `false`. Enabled history, feedback or attachments also selects that
dependency.

The UI reads `DATABASE_ACCOUNT_NAME`, `DATABASE_NAME` and
`NATIVE_UI_METADATA_CONTAINER`; only the frontend receives the metadata grant.
Existing foundation outputs `COSMOS_DB_ENDPOINT` and
`COSMOS_DB_ACCOUNT_RESOURCE_ID` remain conditional. There is no separate
native Cosmos endpoint key. `/principal_id` is the authenticated `tid:oid`.
Metadata contains owner mappings, references, feedback and descriptors, not
file bytes, transcripts, tokens or native checkpoints.

Conversational mode with all product flags off uses bounded volatile owner
maps that are lost on UI restart. Native persistence does not restore them.

Private attachments allow at most three UTF-8 TXT/Markdown, PDF, PNG or JPEG
files, each at most 64 KiB, using validated inline Base64 native inputs.
The serialized inline turn budget is 256 KiB across the Hosted/DTS envelopes,
including text, escaping and encoding overhead.
Transport is implemented; model PDF/image understanding remains unverified.
See [Conversations & files](conversations.md#private-attachments).

Native Hosted and DTS execution do not require application Cosmos.
Selecting `nl2sql` on Agent App MCP Server requires application Cosmos for
separate source and vector-metadata containers. An empty Agent App MCP server
does not require that catalog or NL2SQL model/secret access.

The MCP identity receives declared catalog/model access and SQL-owner-approved
read access only for NL2SQL. The orchestrator receives MCP invocation access only.
Generic application Cosmos and custom Cosmos capabilities remain independent
of MCP selection. See [Application Cosmos DB](configuration.md#application-cosmos-db).

For Hosted `both`, the shared configuration can describe the composition,
but each publication must receive an explicit single-mode process input.
Conversation uses `conversational`; the process publication uses `workflow`.
Do not let the shared composition value start a single Hosted process in
`both` mode. See [Agent hosting](hosted-agents.md).

When private attachments are enabled in Hosted `both`, keep the shared/UI and
conversational publication flag enabled. Only the workflow publication
receives `ENABLE_PRIVATE_ATTACHMENTS=false`; it does not support attachments.

## Telemetry settings

Native Agent Framework instrumentation is enabled by default.
The selected host configures its exporter at startup. Basic tracing does not
require an audit flag or message-content capture.
Follow [Native tracing](application-monitoring.md#native-tracing) for setup
and the Foundry viewing procedure.

| Setting | Default or requirement | Scope |
| --- | --- | --- |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Generated from the selected Application Insights resource; required for export there | Provisioning-managed App Configuration key under `agent-lz`; read at process startup |
| `LOG_LEVEL` | `INFO` | Application logging level; not a tracing enable switch |
| `AZURE_MONITOR_DISABLE_LOGGING` | `true` | Container Apps worker's general application-log export; tracing remains enabled |
| `AUDIT_EVENTS_ENABLED` | `false` for the orchestrator | Supported orchestrator audit hooks; ingestion has a separate emission contract |
| `HOSTED_AGENT_CAPTURE_MESSAGE_CONTENT` | `false` | azd deployment input mapped to `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` on Hosted publications; not an App Configuration feature key |

Export-destination and process telemetry changes require a restart or
redeployment. Changing Hosted content capture requires a new Hosted version.
Do not treat runtime functional refresh as a telemetry reconfiguration path.

General logs, audit events and captured message content have separate
privacy and retention implications. Enabling one does not prove complete
coverage of another.
See [Monitoring & audit](application-monitoring.md) for the actual host and
component boundaries.

## Agent App MCP contract

Select the component with `DEPLOY_AGENT_APP_MCP=true` in the azd environment
before provisioning; the default is `false`.
This is a deployment selector, not another native runtime feature key.
Select tools explicitly before provision/deploy:

```bash
azd env set DEPLOY_AGENT_APP_MCP true
azd env set MCP_TOOLSETS '["nl2sql"]'
```

`MCP_TOOLSETS` is a JSON array, default `[]`. Empty means zero tools and no
NL2SQL client/dependency initialization, not unauthenticated access.
The only supported nonempty value is `["nl2sql"]`. Unknown names, duplicates
and invalid values fail closed. In the reference application, a nonempty
selection requires `DEPLOY_AGENT_APP_MCP=true`.

Custom applications may explicitly supply `MCP_TOOLSETS` with their own
compute, dependency and permission declarations. This is application/runtime configuration under
`agent-lz`, not a new tool-specific Bicep or Terraform parameter.

The platform publishes the following values under `agent-lz` from the selected
resources, models and identities. Do not copy endpoints between components,
manually edit generated client authorization, or supply Cosmos keys.

After MCP and the actual native consumers deploy, the lifecycle grants
`MCP.Invoke`, publishes the allowlist and `MCP_ENABLED`, and verifies the
effective authenticated connection. An accepted key write alone does not prove
that the MCP process loaded new authorization settings.

Server authentication and toolset settings are **startup-only**, not dynamically refreshed.
The platform automatically restarts every active MCP revision after allowlist
publication and before consumer activation. Use the normal `azd deploy`
lifecycle; a manual operator restart is not part of that procedure.

| Setting | Value or requirement | Ownership |
| --- | --- | --- |
| `MCP_TOOLSETS` | `[]`; explicitly select `["nl2sql"]` to register the two supplied SQL tools | Reviewed application configuration, published under `agent-lz`; restart/redeploy required |
| `MCP_AUTH_TENANT_ID` | Entra tenant GUID | Generated identity configuration |
| `MCP_AUTH_AUDIENCE` | Dedicated MCP API application client ID; JWT v2 audience | Generated identity configuration |
| `MCP_AUTH_RESOURCE_SCOPE` | `api://<MCP API client ID>/.default` | Generated client token scope |
| `MCP_ALLOWED_CLIENT_IDS` | JSON array of permitted application client IDs | Lifecycle resolves actual callers, including both Hosted publications when selected |
| `MCP_COSMOS_ENDPOINT` | Application Cosmos endpoint; NL2SQL only | Conditional provisioning output |
| `MCP_COSMOS_DATABASE` | Application Cosmos database; NL2SQL only | Conditional provisioning output |
| `MCP_SOURCES_CONTAINER` | `mcp-sources`; NL2SQL only | Provisioned source catalog |
| `MCP_METADATA_CONTAINER` | `mcp-nl2sql-metadata`; NL2SQL only | Provisioned vector-metadata catalog |
| `MCP_EMBEDDING_DIMENSIONS` | `3072` by default; NL2SQL model, import and vector policy must match | Reviewed model selection, resolved before provision |
| `MCP_METADATA_TOP_K` | `8` by default; NL2SQL only | Bounded metadata retrieval |
| `MCP_QUERY_TIMEOUT_SECONDS` | `75` by default, accepted range `1..75`; NL2SQL only | Complete server-query deadline |
| `MCP_CLIENT_TIMEOUT` | `90` by default, positive; must exceed the whole-query deadline when NL2SQL is selected | Consuming orchestrator |
| `AI_FOUNDRY_OPENAI_ENDPOINT` | Selected model endpoint for NL2SQL | Conditional provisioning output |
| `CHAT_DEPLOYMENT_NAME` | Selected NL2SQL generation deployment | Reviewed model selection |
| `EMBEDDING_DEPLOYMENT_NAME` | Selected NL2SQL embedding deployment | Reviewed model selection |
| `KEY_VAULT_ENDPOINT` | Selected vault endpoint when a SQL-password source needs it | Conditional output and secret-scoped grant |
| `MCP_SQL_SECRET_NAMES` | `[]` by default; optional JSON array of SQL password-secret **names**, never values | Operator declaration for scoped MCP vault grants |

Declare password-secret names through the reviewed deployment inputs before
provisioning their scoped grants. This is a grant declaration, not a tool
enable switch or a replacement for a source's `password_secret_name`.
Adding a secret consumer later requires matching provision/deploy steps.

With `MCP_TOOLSETS=[]`, the server does not validate NL2SQL settings or open
its Cosmos, model, SQL or Key Vault clients. Deselecting NL2SQL stops
registration/initialization after restart/redeployment; retained catalog data
and previously granted roles are not automatically deleted or revoked.

`APP_CONFIG_ENDPOINT` is the process bootstrap environment variable.
`AZURE_CLIENT_ID` is optional when selecting an assigned managed identity;
neither belongs in tool arguments. The endpoint uses HTTPS `/mcp` in Azure.
Identity, endpoint, timeout or model/policy changes require the owning lifecycle
and compatible processes; do not assume UI or native functional refresh changes
the server or reindexes metadata.

The server validates signature, the tenant's v2 issuer
(`https://login.microsoftonline.com/<tenant>/v2.0`), audience and token validity,
plus allowed `azp` and the `MCP.Invoke` application role.
There is no API-key fallback or raw user-context authorization.

The deployment helper configures the API registration/service principal,
`MCP.Invoke` role and client assignments automatically. It requires the
deployer's appropriate Entra directory permissions; Azure Contributor or ARM
RBAC administration alone is insufficient. There is no broad ARM-token
authentication fallback.

Registration reuse uses the exact application object ID recorded in App
Configuration, not an application name or subscription RBAC inference.

SQL's 30-second execution timeout, 1,000-row limit and 256-KiB result ceiling
are separate from the complete query deadline.
See [Agent App MCP Server](agent-app-mcp.md) for the lifecycle and
[NL2SQL](nl2sql.md#results-and-execution-limits) for results.

<span id="orchestrator-tls-compatibility"></span>

## Transport and secret changes

Keep certificate and hostname verification enabled. A private endpoint needs
working DNS, network access and a trusted certificate chain; changing an
application parameter does not repair connectivity.

Secret rotation and transport/bootstrap changes have their own reload rules.
Do not infer that functional parameter refresh also rotates every cached
credential. Follow the selected component's verified deployment contract and
[TLS diagnosis](troubleshooting.md#hosted-configuration-tls-handshake-stalls)
without disabling TLS verification.
