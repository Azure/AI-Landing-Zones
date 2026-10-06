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
| `AZURE_SEARCH_LOCATION` | Empty | Region for Azure AI Search. Leave empty to use the deployment region. |
| `AZURE_SPEECH_LOCATION` | Empty | Region for Azure AI Speech. Leave empty to use the deployment region. |
| `AZURE_PE_LOCATION` | Empty | Region for private endpoints. Leave empty to use the deployment region. |
| `AZURE_PE_RESOURCE_GROUP_NAME` | Empty | Resource group for private endpoints. Leave empty to use the deployment resource group. |
| `EXISTING_APPLICATION_INSIGHTS_CONNECTION_STRING` | None | Sends telemetry to an Application Insights resource you already have. |

Parameters that start with `EXISTING_` reuse a resource instead of creating one. They are listed in [Network and security](#network-and-security).

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

## Network and security

These parameters matter mostly when `NETWORK_ISOLATION=true`. Read [Network isolation](network-isolation.md) first.

| Variable | Default | Description |
| --- | --- | --- |
| `DEPLOY_AZURE_FIREWALL` | `true` | Deploys Azure Firewall for egress control. |
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

Other hosted defaults: CPU `2`, memory `4Gi`, Responses protocol `2.0.0`, Invocations protocol `1.0.0`, capability key ID `v1`, capability TTL `900` seconds, and history limits of `100` messages and `32000` characters.

`PREPARE_HOSTED_AGENT`, `HOSTED_AGENT_PREPARED` and `DEPLOY_HOSTED_AGENT` are managed by the deployment scripts. Do not set them by hand.

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

To change a runtime setting:

1. Update the key in App Configuration with the label `agent-lz`.
2. Restart the active revision of the affected Container App so it reads the new value.

Settings declared by a custom application definition are validated but not published. Publish them yourself.
