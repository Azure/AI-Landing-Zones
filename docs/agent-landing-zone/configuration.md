# Configuration

Agent Landing Zone has two kinds of configuration:

- **Deployment parameters** are `azd` environment variables. They are read when you run `azd provision` or `azd up` and decide which Azure resources are created and how.
- **Runtime settings** are Azure App Configuration keys. The applications read them at startup.

Set a deployment parameter with `azd env set <NAME> <value>` before you run `azd up`. Run `azd env get-values` to see the current values of the selected environment.

!!! note
    `infra/main.parameters.json` maps `azd` environment variables to Bicep parameters. It ships with the repository and is rewritten by the `preprovision` hook. You do not need to edit it, and local changes to it are hidden from `git status` automatically.

## Deployment parameters

### Values set by azd or by you

| Variable | Description |
| --- | --- |
| `AZURE_ENV_NAME` | Environment name. Set by `azd env new`. Used to derive resource names. |
| `AZURE_LOCATION` | Primary Azure region. `azd` asks for it on the first `azd up`. |
| `AZURE_PRINCIPAL_ID` | Object ID of the identity that receives data-plane roles for testing. Set by `azd` from your signed-in account. |

### Inputs without a default

These values have no default in `main.parameters.json`. When they are not set, Bicep uses the default defined in the template.

| Variable | Description |
| --- | --- |
| `NETWORK_ISOLATION` | `true` deploys private endpoints, a private virtual network, a jumpbox and Bastion. See [Network isolation](network-isolation.md). |
| `AZURE_AI_FOUNDRY_LOCATION` | Region for the Microsoft Foundry account, when it must differ from `AZURE_LOCATION`. |
| `AZURE_COSMOS_LOCATION` | Region for Azure Cosmos DB, when it must differ from `AZURE_LOCATION`. |
| `USE_UAI` | `true` uses user-assigned managed identities instead of system-assigned identities. |
| `ENABLE_AGENTIC_RETRIEVAL` | Enables agentic retrieval in Azure AI Search. |
| `USE_EXISTING_VNET` | `true` deploys into a virtual network you already have. |
| `EXISTING_VNET_RESOURCE_ID` | Resource ID of that virtual network. |
| `DEPLOY_SUBNETS` | Whether to create subnets in the existing virtual network. |
| `SIDE_BY_SIDE` | Deploys next to an existing landing zone in the same virtual network. |

### General

| Variable | Default | Description |
| --- | --- | --- |
| `AZURE_PRINCIPAL_TYPE` | `User` | Type of `AZURE_PRINCIPAL_ID`. Use `ServicePrincipal` in pipelines. |
| `DEPLOYMENT_MODE` | `standalone` | `standalone` creates everything. `ailz-integrated` attaches to an existing AI Landing Zone. |
| `RESOURCE_NAMING_MODE` | `caf` | `caf` uses Cloud Adoption Framework prefixes. `legacy` keeps the naming of older environments. |
| `USE_CAPP_API_KEY` | `false` | Protects the Container Apps with an API key in addition to Entra ID. |
| `APP_RUNTIME_CONFIGURATION_MODE` | `appConfig` | Applications read runtime settings from App Configuration. |
| `ENABLE_COSMOS_ANALYTICAL_STORAGE` | `false` | Enables the Cosmos DB analytical store. |
| `AZURE_SEARCH_LOCATION` | Empty | Region for both the general Azure AI Search service and the Search service created for Foundry Agent Service. Leave empty to use `AZURE_LOCATION`. |
| `AZURE_SPEECH_LOCATION` | Empty | Region for Azure AI Speech. Leave empty to use the deployment region. |
| `AZURE_PE_LOCATION` | Empty | Region for private endpoints. Leave empty to use the deployment region. |
| `AZURE_PE_RESOURCE_GROUP_NAME` | Empty | Resource group for private endpoints. Leave empty to use the deployment resource group. |
| `EXISTING_APPLICATION_INSIGHTS_CONNECTION_STRING` | None | Sends telemetry to an Application Insights resource you already have. |

Parameters that start with `EXISTING_` reuse a resource instead of creating one. They are listed in [Network and security](#network-and-security).

### Ingestion application selection

| Variable | Fresh-environment default | Description |
| --- | --- | --- |
| `DEPLOY_INGESTION_CONTAINER_APP` | `false` | Selects the optional Agent App Ingestion Container App in the bundled application, independently of `DEPLOYMENT_TOPOLOGY`. |

With the component disabled, it is excluded from provisioning parameters,
checkout, build, deployment, endpoint reconciliation, identity discovery,
role assignment and panel RBAC. UI chat, authentication and retrieval remain
available with the UI v3.3.0 upload gate described below; attachment
eligibility is a separate capability. This
switch does **not** select a retrieval backend, configure a new source, rebind
an index, or remove document authorization.

Use native ingestion only for supported, configured Foundry IQ sources, such
as the default `azureBlob` source. Native ingestion and Agent App Ingestion
are not feature-equivalent. Unsupported combinations must fail explicitly;
disabling the app is not a way to make an unconfigured source ingest documents.
An ingestion-free `ai_search` or Foundry IQ `searchIndex` deployment must
explicitly bind `SEARCH_RAG_INDEX_NAME` to an index populated by an independent
pipeline. For Foundry IQ, also set `FOUNDRY_IQ_PATTERN=searchIndex` and
`FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND=searchIndex`. The named index must satisfy the
existing Search schema/upgrade guards; the switch does not populate it.
`FOUNDRY_IQ_CONVERSATION_UPLOAD_ENABLED=true` requires the ingestion app.

**Versioned upgrade requirement.** Ingestion-free operation requires the
Agent Landing Zone **v4.3.0** combination with **agent-app-ui v3.3.0**.
Upgrade the complete manifest-pinned combination, not only the configuration
key or one application. Follow
[the migration steps](operations.md#upgrade-ingestion-selection-to-v430).

UI v3.2.2 sends chat attachments to Agent App Ingestion in both classic and
hosted modes, regardless of the new flag. Keep
`DEPLOY_INGESTION_CONTAINER_APP=true` on that older combination, including
fresh deployments. An empty endpoint is not an opt-out: the UI derives a
`dataingest` URL or falls back to Dapr. Its `.chainlit/config.toml` upload
setting is overwritten at startup to `not allow_anonymous`, and Entra
Copilot settings force uploads on even if that TOML setting is false.
Do not change authentication policy to hide attachment controls.

The UI v3.3.0 contract consumes `DEPLOY_INGESTION_CONTAINER_APP` under label
`agent-lz`. A missing key preserves legacy behavior. Explicit `false` hides
attachment controls and rejects server uploads and client preflight before
ingestion URL/Dapr resolution; text chat, authentication and retrieval
remain available. Explicit `true` retains the existing authentication and
conversation eligibility checks, rather than granting uploads unconditionally.
Native Blob source ingestion does not implement conversation uploads.

Existing environments retain their prior component selection rather than
silently adopting the fresh default. Custom application definitions retain
their explicit component intent. Before opting out in an existing environment,
check source/index bindings and any application-managed ingestion dependencies.
See [Change ingestion selection safely](operations.md#change-ingestion-selection-safely).

Selection accepts only `true` or `false`. Pre-provision persists the resolved
boolean into the azd environment, and provisioning/post-provision publish the
same value under App Configuration label `agent-lz`. A populated existing
environment without any prior selection retains ingestion (`true`); an empty
azd-created resource group is fresh (`false`). When the local setting is
missing, existing persisted selection is read rather than guessed. A failed
state lookup requires an explicit selection or restored access. Custom
definitions retain the existing additive bundled composition, including its
ingestion app, even if this bundled-only switch is `false`. For these custom
definitions, the published effective ingestion capability is `true`,
consistent with the selected components rather than the raw bundled-only flag.

### Search region and quota

`AZURE_SEARCH_LOCATION` resolves the effective Bicep `searchServiceLocation`;
an unset or empty value falls back to `AZURE_LOCATION`. Both newly created
Search services use this effective region. Provider availability and Search
quota checks must use that same region, not the primary region when an override
is set.

Search quota must cover the complete enabled service count: one general service
when `deploySearchService` (`DEPLOY_SEARCH_SERVICE`) is enabled, plus one Foundry
Search service when `deployAiFoundry` and `deployAAfAgentSvc`
(`DEPLOY_AAF_AGENT_SVC`) are enabled and `aiSearchResourceId` is not supplied.
When both creation paths are enabled, the check requires quota for two services;
reusing a Foundry Search resource does not request a new service for that path.
Do not bypass preflight to work around a region mismatch or insufficient quota.
See [Search preflight region and quota](troubleshooting.md#search-preflight-region-and-quota).

### Retrieval

| Variable | Default | Description |
| --- | --- | --- |
| `RETRIEVAL_BACKEND` | `foundry_iq` | Retrieval implementation used by the orchestrator. |
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
`privateLinkResourceId`. Configuration cross-checks these against
`SEARCH_SERVICE_RESOURCE_ID`, `STORAGE_ACCOUNT_RESOURCE_ID` and
`AI_FOUNDRY_ACCOUNT_RESOURCE_ID`. This manifest identifies the exact source
GETs for readiness; it is not an automatic target approval allowlist.
Pending links require administrator approval. Do not substitute unrelated
resources or edit the manifest to bypass the gate. See
[Private native Blob ingestion](network-isolation.md#private-native-blob-ingestion).

The exact ARM resource IDs can include Azure-valid resource-group names with
parentheses, Unicode letters and decimal digits. Resource-group validation
does not relax the expected resource type or allow extra path segments,
query strings, URL hosts or encoded path separators.

### Explicit shared-source permission options

`FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS` controls the configured source's
ingestion permission metadata; it is an existing setting, not a new runtime
key. Omission or an actual null value retains the protected default
`["rbacScope"]`. An explicit JSON empty array, `[]`, is an opt-in for a
deliberately shared source **when native Blob ingestion is active**; it is
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
configuration. Verify the resulting source/index permission metadata and
document authorization; do not assume changing a setting alone has repaired
already-ingested documents. See
[Private ingestion and shared-source recovery](operations.md#private-ingestion-and-shared-source-recovery).

## Network and security

These parameters matter mostly when `NETWORK_ISOLATION=true`. Read [Network isolation](network-isolation.md) first.

| Variable | Default | Description |
| --- | --- | --- |
| `DEPLOY_AZURE_FIREWALL` | `true` | Deploys Azure Firewall for egress control. |
| `ENABLE_FIREWALL_DNS_PROXY` | `false` | Enables the deployed firewall's DNS proxy only when both Azure Firewall deployment and network isolation are enabled. Does not modify VNet or VPN DNS settings. |
| `DEPLOY_ACR_TASK_AGENT_POOL` | `true` | Deploys an Azure Container Registry agent pool inside the virtual network so images can be built without a local Docker host. The pool is created only when `NETWORK_ISOLATION=true`. |
| `DEPLOY_JUMPBOX` | Same as `NETWORK_ISOLATION` | Deploys a Windows jumpbox virtual machine. |
| `DEPLOY_BASTION` | Same as `NETWORK_ISOLATION` | Deploys Azure Bastion. |
| `BASTION_SKU_NAME` | `Standard` | Bastion SKU. |
| `DEPLOY_NAT_GATEWAY` | Same as `NETWORK_ISOLATION` | Deploys a NAT gateway. |
| `ENABLE_ACS_MEDIA_EGRESS` | `false` | Opens firewall egress for Azure Communication Services media. |
| `DEPLOY_GROUNDING_WITH_BING` | `false` | Deploys Grounding with Bing Search. |
| `DEPLOY_KEY_VAULT` | `true` | Deploys the application Key Vault. |
| `DEPLOY_VM_KEY_VAULT` | `false` | Deploys a separate Key Vault for the jumpbox. |
| `DEPLOY_LOG_ANALYTICS` | `true` | Deploys a Log Analytics workspace. Private access is enabled by default. |
| `ALLOW_MIXED_OBSERVABILITY_WORKSPACES` | `false` | Allows Application Insights and Log Analytics from different sources. |
| `DEPLOY_SEARCH_SERVICE` | `true` | Deploys Azure AI Search. |
| `DEPLOY_SPEECH_SERVICE` | `false` | Deploys Azure AI Speech (SKU `S0`). |
| `DEPLOY_STORAGE_ACCOUNT` | `true` | Deploys the document storage account. |

Bastion tunneling is disabled by default.

### Hub integration

Use these parameters to connect the spoke virtual network to an existing hub. See [Integrate with an existing hub](network-isolation.md#integrate-with-an-existing-hub).

| Variable | Default | Description |
| --- | --- | --- |
| `HUB_INTEGRATION_HUB_VNET_RESOURCE_ID` | None | Resource ID of the hub virtual network. |
| `HUB_INTEGRATION_CREATE_HUB_PEERING` | `true` | Creates the peering from the hub side. |
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

## Hosted agent

These parameters apply when the orchestrator runs as a Foundry hosted agent. See [Hosted agents](hosted-agents.md).

| Variable | Default | Description |
| --- | --- | --- |
| `DEPLOYMENT_TOPOLOGY` | `hosted-no-panel` | Application topology. See [Topologies](hosted-agents.md#topologies). |
| `DEPLOY_AAF_AGENT_SVC` | `true` | Enables the Foundry Agent Service capability host. |
| `HOSTED_AGENT_NAME` | `agent-app-orchestrator` | Name of the hosted agent in the Foundry project. |
| `HOSTED_AGENT_IMAGE` | `agent-app-orchestrator` | Repository name of the agent image in Container Registry. |
| `HOSTED_CONVERSATION_OWNER_BINDING` | `delegated` | How conversation ownership is bound to the caller. |
| `HOSTED_CONTINUITY_ENABLED` | `false` | Enables the conversation continuity endpoints. Requires a hosted topology with `CHAT_BACKEND=hosted_agent`. |
| `HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS` | `60` | Idle timeout for streamed responses. |
| `PRESERVE_CLASSIC_RUNTIME` | `false` | Keeps the classic orchestrator Container App while an existing environment moves to hosted. |
| `APP_CONFIG_TLS_COMPATIBILITY` | `false` | Opt-in bootstrap transport for the App Configuration and application Key Vault endpoints; requires the coordinated runtime correction and `KEY_VAULT_URI`. See [Configuration TLS compatibility](hosted-agents.md#configuration-tls-compatibility). |

Other hosted defaults: CPU `2`, memory `4Gi`, Responses protocol `2.0.0`, Invocations protocol `1.0.0`, capability key ID `v1`, capability TTL `900` seconds, and history limits of `100` messages and `32000` characters.

`PREPARE_HOSTED_AGENT`, `HOSTED_AGENT_PREPARED` and `DEPLOY_HOSTED_AGENT` are managed by the deployment scripts. Do not set them by hand.

`APP_CONFIG_TLS_COMPATIBILITY` is a container environment variable, not an App
Configuration key: it is read before remote configuration can load. Only `true`
and `false` are accepted. The foundation's additive `KEY_VAULT_URI` output
provides the deployed vault URI without hardcoding a cloud DNS suffix and is
empty when the vault is not deployed. These coordinated corrections are included
in Agent Landing Zone **v4.2.3**, which pins **agent-app-ui v3.2.2** and
**agent-app-orchestrator v5.2.1**.

## Deployment controls

These variables change how the hooks behave. They do not change the deployed resources.

| Variable | Description |
| --- | --- |
| `BUILD_MODE` | `local` builds images with Docker on the current host. When unset, images are built with Azure Container Registry tasks. |
| `RUN_FROM_JUMPBOX` | `false` defers post-provision configuration in an isolated deployment. It is not a connectivity bypass. See [Post-provision can be deferred](network-isolation.md#post-provision-can-be-deferred). |
| `AZURE_SKIP_NETWORK_ISOLATION_WARNING` | `true` also defers post-provision configuration in an isolated deployment. |
| `PREFLIGHT_SKIP` | `true` skips all preflight checks. |
| `AGENTLZ_REGIONAL_PREFLIGHT_SKIP` | `true` skips only the regional quota and availability check. |
| `AGENTLZ_APP_DEFINITION` | Path to a custom application definition. See [Custom applications](build-your-own-app.md). |

## Runtime settings

Post-provision publishes runtime settings to Azure App Configuration with the label `agent-lz`. The applications read only that label.

The corrected orchestrator's unlabelled selector uses the SDK's explicit null
label (`"\0"`), not `None` (which means all labels). Existing service-label
precedence is preserved; unrelated UI-labelled Key Vault references must not
be pulled into the orchestrator's bootstrap.

To change a runtime setting:

1. Update the key in App Configuration with the label `agent-lz`.
2. Restart the active revision of the affected Container App so it reads the new value.

Settings declared by a custom application definition are validated but not published. Publish them yourself.
