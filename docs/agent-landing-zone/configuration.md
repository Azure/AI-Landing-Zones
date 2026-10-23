# Configuration

Agent Landing Zone has two kinds of configuration:

- **Deployment inputs** are `azd` environment variables read by Bicep or the lifecycle hooks. They control resource provisioning, application selection and image builds.
- **Runtime settings** are Azure App Configuration keys read by applications at startup. Some bootstrap values must be container environment variables because they are needed before remote configuration can load.

Set deployment inputs with `azd env set <NAME> <value>` before provisioning.
Inspect only the keys you need with `azd env get-value <NAME>`; a complete
environment dump can contain secrets.

Use this page to look up settings and defaults. Follow
[Deploy infrastructure only](deploy-infra-only.md) or
[Deploy the full stack](deploy-full-stack.md) for the ordered workflow.
Choose the [deployment shape](planning.md), [capacity](sizing.md) and
[cost assumptions](cost-planning.md) before setting inputs.

!!! note
    `main.parameters.json` is the checked-in input to composition. The `preprovision` hook generates `infra/main.parameters.json` from it and the selected environment. Do not edit the generated file. In a Git checkout, the hook attempts to hide local regeneration from `git status` with `skip-worktree`.

## Environment boundaries

Use separate azd environments and resource groups for DEV, TEST and PROD.
Separate subscriptions provide a stronger administrative and quota boundary.
Enforce separation through deployment permissions, service identities and
dedicated configuration and data stores, as summarized below.

| Boundary | Keep separate |
| --- | --- |
| Target and deployment access | Resource group/subscription, azd environment and environment-scoped deployment identity. DEV must not deploy to PROD. |
| Runtime access | Component identities, grants and Entra registrations, or explicitly separated callbacks and consent. |
| Configuration and secrets | App Configuration store/endpoint and Key Vault. The `agent-lz` label is shared by convention, not an environment separator. |
| Data | Sources, indexes, conversation/history stores and retention. Use approved test data instead of copying production documents. |
| Network and builds | DNS, routes, private endpoints and a connected runner. An ACR build pool does not connect the deployment host. |

Keep nonsecret, approved inputs in version control. If you organize them in an
`environments/` folder, apply those settings explicitly; the platform does not
load that folder automatically. Local `.azure` contains private deployment
state. Hooks copy it to child projects; protect those workspaces too. Never
copy DEV state into TEST or PROD.

## Deployment parameters

### Resource naming

For generated names, naming overrides and preserving existing resource names,
see [Resource naming](resource-naming.md). Choose naming inputs before the
first provision; changing them later can create replacement resources.

### Values set by azd or by you

| Variable | Description |
| --- | --- |
| `AZURE_ENV_NAME` | Environment name. Set by `azd env new`. Used to derive resource names. |
| `AZURE_LOCATION` | Primary Azure region. `azd` asks for it on the first `azd up`. |
| `AZURE_PRINCIPAL_ID` | Object ID of the deployment identity that receives roles for service setup and access. Set by `azd` from your signed-in account. |

### Inputs that use Bicep defaults

These mappings have no inline default in `main.parameters.json`.
When unset, they use the template defaults shown below.

| Variable | Template default | Description |
| --- | --- | --- |
| `NETWORK_ISOLATION` | `false` | Enables private networking. Jumpbox, Bastion and firewall deployment also depend on their component flags. See [Network isolation](network-isolation.md). |
| `AZURE_AI_FOUNDRY_LOCATION` | Deployment region | Region for the Microsoft Foundry account. |
| `AZURE_COSMOS_LOCATION` | Deployment region | Region for Agent Application Cosmos DB. |
| `USE_UAI` | `false` | Uses user-assigned managed identities instead of system-assigned identities. |
| `ENABLE_AGENTIC_RETRIEVAL` | `false` | Enables the template's agentic retrieval resource configuration. This is separate from the Agent Application setting `RETRIEVAL_BACKEND`. |
| `USE_EXISTING_VNET` | `false` | Deploys into a virtual network you already have when network isolation is enabled. |
| `EXISTING_VNET_RESOURCE_ID` | Empty | Resource ID required when reusing a virtual network. |
| `DEPLOY_SUBNETS` | `true` | Creates the required subnets in the selected virtual network. |
| `SIDE_BY_SIDE` | `true` | Uses the deployment resource group for private endpoints and DNS zones rather than placing them in the existing VNet's resource group. |

### General

| Variable | Default | Description |
| --- | --- | --- |
| `AZURE_PRINCIPAL_TYPE` | `User` | Type of `AZURE_PRINCIPAL_ID`. Use `ServicePrincipal` in pipelines. |
| `DEPLOYMENT_MODE` | `standalone` | Declares deployment intent for tags and preflight. `ailz-integrated` does not automatically attach a hub or override component flags. Supply the hub, routing, resource reuse and DNS inputs explicitly. |
| `POLICY_MANAGED_PRIVATE_DNS` | `false` | Delegates private DNS zone groups/records to Azure Policy. Use instead of BYO private DNS zone IDs; agree policy coverage, VNet links and readiness with the DNS owner. |
| `RESOURCE_NAMING_MODE` | `caf` | `caf` uses Cloud Adoption Framework prefixes. `legacy` keeps the naming of older environments. |
| `USE_CAPP_API_KEY` | `false` | Enables the optional classic Container App API-key mechanism. It does not configure Entra ID sign-in. Hosted composition disables this key mechanism. |
| `APP_RUNTIME_CONFIGURATION_MODE` | `appConfig` | The Agent Application reads runtime settings from App Configuration. |
| `ENABLE_COSMOS_ANALYTICAL_STORAGE` | `false` | Enables the Agent Application Cosmos DB analytical store. |
| `AZURE_SEARCH_LOCATION` | Empty | Region for both the Agent Application Search service and the separate Foundry Agent Service Search service. Leave empty to use `AZURE_LOCATION`. |
| `AZURE_SPEECH_LOCATION` | Empty | Region for Azure AI Speech. Leave empty to use the deployment region. |
| `AZURE_PE_LOCATION` | Empty | Region for private endpoints. Leave empty to use the deployment region. |
| `AZURE_PE_RESOURCE_GROUP_NAME` | Empty | Resource group for private endpoints. Defaults to the deployment resource group, or the existing VNet's resource group when `USE_EXISTING_VNET=true` and `SIDE_BY_SIDE=false`. |
| `EXISTING_APPLICATION_INSIGHTS_CONNECTION_STRING` | None | Sends telemetry to an Application Insights resource you already have. |

Supported `EXISTING_*` inputs select reuse, subject to each resource's conditions.
They are listed in [Network and security](#network-and-security).
Foundry backing-service reuse uses native parameter names instead; see
[Select, reuse or omit resources](planning.md#select-reuse-or-omit-resources).
Supply the supported resource ID to attach an existing service; naming and
deployment flags control resource creation.

<span id="ingestion-application-selection"></span>

### Agent App Ingestion selection

| Variable | Fresh-environment default | Description |
| --- | --- | --- |
| `DEPLOY_INGESTION_CONTAINER_APP` | `false` | Selects the optional Agent App Ingestion component of the Agent Application, independently of `DEPLOYMENT_TOPOLOGY`. |

The boolean is persisted by pre-provision and published under label `agent-lz`.
Existing environments retain their selection; they do not silently adopt the
fresh default. Custom definitions retain their declared intent and additive
foundation composition.

| Selection | Effect |
| --- | --- |
| `false` | Omits Agent App Ingestion from subsequent Agent Application composition/deployment and reconciliation. The UI disables attachment controls and upload paths, not text chat, authentication or retrieval. |
| `true` | Selects the app and retains the UI's existing upload eligibility checks. It does not grant every caller permission to upload. |

Opt-out supports native Foundry IQ `azureBlob`, or an explicitly bound,
independently populated `SEARCH_RAG_INDEX_NAME` for `ai_search` / Foundry IQ
`searchIndex`. It does not select a strategy, configure SharePoint, rewrite
source bindings, populate an index or remove authorization.
`FOUNDRY_IQ_CONVERSATION_UPLOAD_ENABLED=true` requires the app.

See [Ingestion and conversation uploads](ingestion.md) for source choices,
SharePoint distinctions, custom-definition behavior and
[older-UI migration and safe retirement](ingestion.md#upgrade-and-retirement-safety).
Disabling the component does not delete existing resources or revoke old grants.

### Search region and quota

`AZURE_SEARCH_LOCATION` resolves the effective Bicep `searchServiceLocation`.
An unset or empty value falls back to `AZURE_LOCATION`. Both newly created
Search services use this effective region. Provider availability and Search
quota checks must use that same region, not the primary region when an override
is set.

Search quota must cover the complete enabled service count: one Agent Application service
when `deploySearchService` (`DEPLOY_SEARCH_SERVICE`) is enabled, plus one Foundry
Search service when `deployAiFoundry` and `deployAAfAgentSvc`
(`DEPLOY_AAF_AGENT_SVC`) are enabled and `aiSearchResourceId` is not supplied.
When both creation paths are enabled, the check requires quota for two services.
Reusing a Foundry Search resource does not request a new service for that path.
Do not bypass preflight to work around a region mismatch or insufficient quota.
See [Search preflight region and quota](troubleshooting.md#search-preflight-region-and-quota).

### Retrieval

| Variable | Default | Description |
| --- | --- | --- |
| `RETRIEVAL_BACKEND` | `foundry_iq` | Retrieval implementation used by the Agent Application orchestrator. |
| `FOUNDRY_IQ_PATTERN` | `azureBlob` | Foundry IQ pattern. |
| `FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND` | `azureBlob` | Kind of knowledge source. |
| `FOUNDRY_IQ_API_VERSION` | `2026-05-01-preview` | Azure AI Search API version used for Foundry IQ objects. |
| `FOUNDRY_IQ_IS_ADLS_GEN2` | `false` | `true` when the source storage account has a hierarchical namespace. |
| `KNOWLEDGE_BASE_NAME` | `knowledge-base` | Knowledge base name. |
| `KNOWLEDGE_BASE_CONNECTION_NAME` | `knowledge-base-connection` | Foundry project connection to the knowledge base. |
| `FOUNDRY_IQ_KNOWLEDGE_SOURCE_NAME` | `knowledge-base-blob-ks` | Knowledge source name. |
| `FOUNDRY_IQ_SEARCH_INDEX_NAME` | `agent-lz-index` | Search index name. |

Other retrieval defaults: billing plan `free`, semantic configuration `default`, security field `metadata_security_id`, storage container `documents`, content extraction mode `standard`, ingestion permission options `["rbacScope"]`, and the filter add-on disabled.

For network-isolated native Blob configuration, infrastructure publishes
`SEARCH_SHARED_PRIVATE_LINKS` as a JSON array under label `agent-lz`. This is
post-provision metadata, not an operator switch or a runtime retrieval setting.
Each entry records the template-owned `name`, `groupId` and
`privateLinkResourceId`. Configuration uses these values to verify the Search
links and their target Storage and Foundry resources before creating a native
knowledge source. Pending links require administrator approval.
Keep this deployment-generated metadata unchanged and follow
[Private native Blob ingestion](network-isolation.md#private-native-blob-ingestion).

The exact ARM resource IDs can include Azure-valid resource-group names with
parentheses, Unicode letters and decimal digits. Resource-group validation
does not relax the expected resource type or allow extra path segments,
query strings, URL hosts or encoded path separators.

### Explicit shared-source permission options

`FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS` controls the configured source's
ingestion permission metadata. Omission or an actual null value retains the protected default
`["rbacScope"]`. An explicit JSON empty array, `[]`, is an opt-in for a
deliberately shared source **when native Blob ingestion is active**. It is
not treated as a missing value.

For active native Blob ingestion, the shared-source empty list is accepted
with `RETRIEVAL_BACKEND=foundry_iq`, `FOUNDRY_IQ_PATTERN=azureBlob` (or the
historical `managed` compatibility alias), `azureBlob` knowledge source kind
and a recognized non-ADLS source. Active ADLS Gen2, mismatched source
configuration and ambiguous ADLS configuration fail closed. Nonempty Blob
permission lists accept only `rbacScope` and `sensitivityLabels`.

The infrastructure also publishes `[]` as **unused metadata** for inactive
native Blob ingestion: `ai_search` with any pattern, or `foundry_iq` with
the `searchIndex` pattern. Those empty lists remain accepted because no
native Blob knowledge source is rendered. They are not shared-source opt-ins
and do not change the independently populated index's authorization.

Malformed JSON, scalar values, textual `null`, non-string or blank list
entries, and unsupported permission names fail with actionable diagnostics.
Invalid input fails closed rather than silently falling back or removing
protection. An actual null value and the text `null` are not interchangeable.

For active native Blob ingestion, use `[]` only when policy permits the
source's documents to be shared without that ingestion permission metadata.
It does not grant document access by
itself or change other sources, application authentication, Entra ID/OBO,
retrieval authorization, RBAC or private network restrictions. Do not use it
to work around an authentication or private-link failure. Review the source's
intended audience and verify allow/deny behavior before enabling it.

To restore protected ingestion, set `["rbacScope"]` and rerun the source
configuration. Before allowing access, verify the source/index permission
metadata and test document access for allowed and denied users, including
already-ingested documents. See
[Private native Blob ingestion](network-isolation.md#private-native-blob-ingestion).

## Network and security

These parameters matter mostly when `NETWORK_ISOLATION=true`. Read [Network isolation](network-isolation.md) first.

| Variable | Default | Description |
| --- | --- | --- |
| `DEPLOY_AZURE_FIREWALL` | `true` | Deploys Azure Firewall for egress control. |
| `ENABLE_FIREWALL_DNS_PROXY` | `false` | Enables the deployed firewall's DNS proxy only when both Azure Firewall deployment and network isolation are enabled. Does not modify VNet or VPN DNS settings. |
| `DEPLOY_ACR_TASK_AGENT_POOL` | `true` | Deploys an Azure Container Registry agent pool inside the virtual network so images can be built without a local Docker host. The pool is created only when `NETWORK_ISOLATION=true`. |
| `DEPLOY_JUMPBOX` | Same as `NETWORK_ISOLATION` | Deploys a Windows jumpbox virtual machine. |
| `DEPLOY_BASTION` | Enabled with network isolation and jumpbox deployment | Deploys Azure Bastion unless an existing Bastion is selected. |
| `BASTION_SKU_NAME` | `Standard` | Bastion SKU. |
| `DEPLOY_NAT_GATEWAY` | Enabled with network isolation and jumpbox deployment | Deploys a NAT gateway unless an existing gateway is selected. |
| `ENABLE_ACS_MEDIA_EGRESS` | `false` | Opens firewall egress for Azure Communication Services media. |
| `DEPLOY_GROUNDING_WITH_BING` | `false` | Deploys Grounding with Bing Search. |
| `DEPLOY_KEY_VAULT` | `true` | Deploys the Agent Application Key Vault. |
| `DEPLOY_VM_KEY_VAULT` | `false` | Deploys a separate Key Vault for the jumpbox. |
| `DEPLOY_LOG_ANALYTICS` | `true` | Deploys a Log Analytics workspace unless an existing workspace is selected. |
| `ENABLE_PRIVATE_LOG_ANALYTICS` | `true` | Configures Azure Monitor Private Link when network isolation is enabled and a central workspace is not being reused. |
| `ALLOW_MIXED_OBSERVABILITY_WORKSPACES` | `false` | Allows Application Insights and Log Analytics from different sources. |
| `DEPLOY_SEARCH_SERVICE` | `true` | Deploys the Agent Application Search service. |
| `DEPLOY_SPEECH_SERVICE` | `false` | Deploys Azure AI Speech (SKU `S0`). |
| `DEPLOY_STORAGE_ACCOUNT` | `true` | Deploys the document storage account. |

Bastion tunneling is disabled by default.

### Hub integration

Use these parameters to connect the spoke virtual network to an existing hub. See [Integrate with an existing hub](network-isolation.md#integrate-with-an-existing-hub).

| Variable | Default | Description |
| --- | --- | --- |
| `HUB_INTEGRATION_HUB_VNET_RESOURCE_ID` | None | Resource ID of the hub virtual network. |
| `HUB_INTEGRATION_CREATE_HUB_PEERING` | `true` | Creates spoke-to-hub peering for a newly created spoke VNet. The hub owner supplies reverse peering. With an existing VNet, both directions are externally managed. |
| `HUB_INTEGRATION_PEERING_ALLOW_GATEWAY_TRANSIT` | `false` | Allows gateway transit on the peering. |
| `HUB_INTEGRATION_PEERING_USE_REMOTE_GATEWAYS` | `false` | Uses the hub gateways from the spoke. |
| `HUB_INTEGRATION_EGRESS_NEXT_HOP_IP` | None | Private IP of the hub firewall used as the default route. |
| `HUB_INTEGRATION_EXISTING_ROUTE_TABLE_RESOURCE_ID` | None | Route table to attach instead of creating one. |

### Existing resources

Set any of these to reuse a resource instead of creating it:

- `EXISTING_VNET_RESOURCE_ID`
- `EXISTING_JUMPBOX_RESOURCE_ID`
- `EXISTING_BASTION_RESOURCE_ID`
- `EXISTING_NAT_GATEWAY_RESOURCE_ID`
- `EXISTING_LOG_ANALYTICS_WORKSPACE_RESOURCE_ID`
- `EXISTING_APPLICATION_INSIGHTS_RESOURCE_ID`

To use private DNS zones that already exist (for example, in a hub subscription), set `EXISTING_PRIVATE_DNS_ZONE_<ZONE>_RESOURCE_ID`, where `<ZONE>` is one of:

`COGSVCS`, `OPENAI`, `AISERVICES`, `SEARCH`, `COSMOS`, `BLOB`, `KEYVAULT`, `APPCONFIG`, `CONTAINERAPPS`, `ACR`, `AZUREMONITOR`, `OMSOPSINSIGHTS`, `ODSOPSINSIGHTS`, `AZUREAUTOMATION`, `APPINSIGHTS`.

Their owner must provide the required VNet links or resolver forwarding
separately from network peering. With `POLICY_MANAGED_PRIVATE_DNS=true`,
Azure Policy manages DNS records instead of the template. Agree those policy
assignments and links with the DNS owner before deploying.

## Hosted agent

These parameters apply when the orchestrator runs as a Foundry hosted agent. See [Hosted agents](hosted-agents.md).

| Variable | Default | Description |
| --- | --- | --- |
| `DEPLOYMENT_TOPOLOGY` | `hosted-no-panel` | Agent Application topology. See [Topologies](hosted-agents.md#topologies). |
| `DEPLOY_AAF_AGENT_SVC` | `true` | Enables the Foundry Agent Service capability host. |
| `HOSTED_AGENT_NAME` | `agent-app-orchestrator` | Name of the hosted agent in the Foundry project. |
| `HOSTED_AGENT_IMAGE` | `agent-app-orchestrator` | Repository name of the agent image in Container Registry. |
| `HOSTED_CONVERSATION_OWNER_BINDING` | `delegated` | How conversation ownership is bound to the caller. |
| `HOSTED_CONTINUITY_ENABLED` | `false` | Managed activation state for continuity endpoints. Hosted topology alone does not enable them. See [Hosted agents](hosted-agents.md). |
| `HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS` | `60` | Idle timeout for streamed responses. |
| `PRESERVE_CLASSIC_RUNTIME` | `false` | Keeps the classic orchestrator Container App while an existing environment moves to hosted. |
| `APP_CONFIG_TLS_COMPATIBILITY` | `false` | Opt-in bootstrap transport for App Configuration and Agent Application Key Vault endpoints. Requires the coordinated runtime correction and `KEY_VAULT_URI`. See [Configuration TLS compatibility](hosted-agents.md#configuration-tls-compatibility). |

Hosted provisioning inputs `HOSTED_AGENT_CONTAINER_CPU` and
`HOSTED_AGENT_CONTAINER_MEMORY` default to `2` and `4Gi`. The Agent Application's
child `hosted-agent/azure.yaml` also declares CPU and memory as **literal
fields**; changing those environment variables alone does not resize the
deployed agent. Keep any reviewed child-definition change compatible with
the provisioned handoff and deploy a new version. See [Sizing](sizing.md#application-hosting).

Other hosted defaults: Responses protocol `2.0.0`,
Invocations protocol `1.0.0`, capability key ID `v1` and capability TTL
`900` seconds. The platform configures continuity history with `100` items
and `32000` estimated tokens. These are not character limits or a limit
on ordinary session chat. See [Hosted agents](hosted-agents.md) for the
continuity activation and history limitations.

For the UI's owner-binding gates, capability signing requirements and
conversation-store settings, see
[UI continuity configuration](https://github.com/Azure/agent-app-ui/blob/main/docs/python-development.md#optional-continuity).
These are runtime settings, not additional infrastructure parameters.

`PREPARE_HOSTED_AGENT`, `HOSTED_AGENT_PREPARED` and `DEPLOY_HOSTED_AGENT` are managed by the deployment scripts. Do not set them by hand.

`APP_CONFIG_TLS_COMPATIBILITY` is a container environment variable, not an App
Configuration key: it is read before remote configuration can load. Only `true`
and `false` are accepted. The foundation's additive `KEY_VAULT_URI` output
provides the deployed vault URI without hardcoding a cloud DNS suffix and is
empty when the vault is not deployed. Use the complete manifest-pinned
Agent Application and infrastructure combination so the loader and hosted definition
agree on these inputs.

## Deployment controls

These variables control hook execution and application selection. Selecting
a different application can change which resources are provisioned.

| Variable | Description |
| --- | --- |
| `BUILD_MODE` | `local` uses Docker on the deployment host. `acr-task` uses Azure Container Registry. Unset values select a mode as described below. |
| `RUN_FROM_JUMPBOX` | `false` defers post-provision configuration in an isolated deployment. It is not a connectivity bypass. See [Post-provision can be deferred](network-isolation.md#post-provision-can-be-deferred). |
| `AZURE_SKIP_NETWORK_ISOLATION_WARNING` | `true` also defers post-provision configuration in an isolated deployment. |
| `PREFLIGHT_SKIP` | `true` skips regional and infrastructure preflight checks, not application-definition or topology validation. |
| `AGENTLZ_REGIONAL_PREFLIGHT_SKIP` | `true` skips only the regional quota and availability check. |
| `AGENTLZ_APP_DEFINITION` | Path to a custom application definition. See [Custom applications](build-your-own-app.md). |

Preflight skip flags are diagnostic controls, not a supported fix for quota,
region, permission or network failures. Resolve the reported cause before
deploying.

When `BUILD_MODE` is unset, component scripts first apply recognized legacy
`USE_DOCKER` values. Otherwise, network isolation or a configured task pool
selects ACR Tasks. Without either, usable Docker selects a local build,
and unavailable Docker selects ACR Tasks. Explicit `local` fails if Docker
is unusable rather than falling back silently.

Hosted orchestrator image preparation always uses ACR Tasks.
`BUILD_MODE=local` does not change that preparation path or the isolated
custom source-build path. See
[Hosted agents](hosted-agents.md) and
[Custom applications](build-your-own-app.md#source-pinning).

## Runtime settings

Post-provision publishes runtime settings to Azure App Configuration with
the label `agent-lz`. Use that label for platform-owned settings.

The Agent Application components do not read exclusively from `agent-lz`. Their startup
loaders also select service or legacy labels, and later matching selections
can overwrite earlier values. Agent App UI and Agent App Ingestion endpoint loaders
end with `label_filter=None`, which leaves the label filter unset and can
read other labels. The orchestrator uses the explicit null label `"\0"` for its last
selection, which reads unlabelled keys rather than all labels. Unlabelled
values can still override `agent-lz` values.

Before changing a setting, check for conflicting legacy, service and unlabelled
values, since a later selection can replace an earlier value for the same key.
Use separate stores and identities for environment isolation.
The component repositories document their version-specific selectors.

To change a runtime setting:

1. Update the key in App Configuration with the label `agent-lz`.
2. Restart the affected Container App revision or deploy a new hosted version
   so it reloads startup configuration. Running hosted versions are immutable.

Deployment-owned keys can be overwritten by the next provision or
post-provision run. Change their deployment inputs as well when the new
value must persist. Settings declared by a custom application definition are
validated but not published. Publish them yourself.

Use the [runtime-setting runbook](deploy-full-stack.md#change-a-runtime-setting)
for commands and [secret rotation](deploy-full-stack.md#rotate-a-secret) for
versioned versus unversioned Key Vault references. Changing deployment selection,
RBAC or infrastructure requires the matching full workflow, not just a key edit.
