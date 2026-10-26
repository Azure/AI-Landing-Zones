<span id="configuration"></span>

# Deployment settings

Agent Landing Zone separates:

- **Deployment inputs**, supplied through the `azd` environment or root `main.parameters.json`. They select resources and the application, and control image builds.
- **Runtime settings**, read by applications from Azure App Configuration at startup. Bootstrap values, such as the store endpoint, must be available before remote reads begin.

The default Agent Application uses Foundry hosted orchestration with
`maf_lite`, no panel and native Foundry IQ Blob ingestion.
This page explains settings and defaults, not an execution sequence.
[How it works](how-it-works.md) introduces the concepts;
[deployment design](planning.md), [capacity](sizing.md) and
[cost planning](cost-planning.md) explain the planning decisions.

The [Deploy infra only](deploy-infra-only.md) and
[Deploy full stack](deploy-full-stack.md) runbooks describe input commands,
provisioning and validation. Read individual keys instead of dumping
environments that may contain secrets.

!!! note "Application-specific runtime settings"
    Runtime settings vary by application. Those described here belong to
    **Agent Application**, the supplied reference app; a custom app can have
    different requirements.

!!! note
    `main.parameters.json` is the checked-in input to composition. The `preprovision` hook generates `infra/main.parameters.json` from it and the selected environment. Do not edit the generated file. In a Git checkout, the hook attempts to hide local regeneration from `git status` with `skip-worktree`.

## Environment boundaries

DEV, TEST and PROD need separate azd environments and resource groups.
Separate subscriptions strengthen administrative and quota boundaries.
Permissions, identities and dedicated stores enforce the following boundaries.

| Boundary | Keep separate |
| --- | --- |
| Target and deployment access | Resource group/subscription, azd environment and environment-scoped deployment identity. DEV must not deploy to PROD. |
| Runtime access | Component identities, grants and Entra registrations, or explicitly separated callbacks and consent. |
| Configuration and secrets | App Configuration store/endpoint and Key Vault. The `agent-lz` label is shared by convention, not an environment separator. |
| Data | Sources, indexes, conversation/history stores and retention. Use approved test data instead of copying production documents. |
| Network and builds | DNS, routes, private endpoints and a connected runner. An ACR build pool does not connect the deployment host. |

Approved nonsecret inputs can be version-controlled. An `environments/`
folder is not loaded automatically; its settings need explicit application.
Local `.azure` contains private deployment state, which hooks copy to child
projects. Those workspaces need the same protection and cannot safely be
copied between DEV, TEST and PROD.

## Deployment parameters

### Resource naming

[Resource naming](resource-naming.md) explains defaults, overrides and name
stability. Names resolve before the first provision; later changes can create
new resources instead of updating existing ones.

### Resource group destinations

!!! note "Available from v4.4.0"
    The optional resource group destinations below support new Agent Landing
    Zone **Bicep/azd** deployments from
    [v4.4.0](https://github.com/Azure/agent-landing-zone/releases/tag/v4.4.0).
    Use a reviewed compatible source revision. Terraform, portal and the
    independent Bicep foundation are not claimed to support this Agent
    platform contract.

Without overrides, deployment keeps the existing single-resource-group path.
All workload destinations must be in `AZURE_SUBSCRIPTION_ID`. Equal names are
valid: one, two or three distinct groups can express the same three logical
destinations. These inputs do not enable services, change network isolation or
create a platform hub; existing BYO VNet, DNS and hub settings still apply.

| Variable | Default | Purpose |
| --- | --- | --- |
| `AZURE_RESOURCE_GROUP` | Selected or initialized by azd | Application destination and azd root deployment group. |
| `AZURE_FOUNDRY_RESOURCE_GROUP` | `AZURE_RESOURCE_GROUP` | Optional Foundry and grounding destination. |
| `AZURE_NETWORK_RESOURCE_GROUP` | `AZURE_RESOURCE_GROUP` | Optional destination for workload-owned network resources. Existing network/private-endpoint overrides retain their own contract. |
| `CREATE_RESOURCE_GROUPS` | `false` | Strict boolean (`true` or `false`): allows creating only explicitly named, missing additional destination groups. Does not disable azd's normal root-group creation. |

Set destinations **before first provision**. For three pre-created groups:

```bash
azd env set AZURE_RESOURCE_GROUP rg-app
azd env set AZURE_FOUNDRY_RESOURCE_GROUP rg-ai
azd env set AZURE_NETWORK_RESOURCE_GROUP rg-net
azd env set CREATE_RESOURCE_GROUPS false
```

For two groups, set `AZURE_NETWORK_RESOURCE_GROUP` to `rg-app` instead.
For the unchanged single-group path, omit both optional destination inputs.
With `false`, a missing additional destination fails before services are
provisioned. With an approved `true`, existing groups are reused without
changing their tags or location; only missing additional groups are created.
New additional groups do not receive the `azd-env-name` tag.
Run the normal root lifecycle: each `azd provision` coordinates the
resource-group-scoped root and its scoped modules. Do not replace it with
three manual deployments. Hosted image preparation still uses its normal
multi-step lifecycle.

#### Resource group permissions

- **Existing groups:** Contributor on each target covers resource management
  and `Microsoft.Resources/deployments/*`, not RBAC grants or data access.
  Splitting existing groups does not itself require subscription Owner or
  subscription-scope deployment permission.
- **Creating missing groups:** `CREATE_RESOURCE_GROUPS=true` additionally needs
  `Microsoft.Resources/subscriptions/resourceGroups/write` at subscription
  scope. A scoped custom role can grant that action; subscription Contributor
  is broader, not a universal prerequisite.
- **RBAC:** the deploying identity needs
  `Microsoft.Authorization/roleAssignments/write` at each assignment scope,
  for example through Role Based Access Control Administrator, subject to its
  conditions. Creating a group does not automatically grant this access.
- **Service configuration:** keep the required Foundry, Search, App
  Configuration, Key Vault and other service-specific data-plane roles.
  Management-plane Contributor does not replace them. External network/DNS
  resources require their owners' scoped permissions.

The workflow does not elevate its own permissions. Record the approved mapping
with the environment; changing a provisioned environment's mapping is not a
supported resource migration. After partial failure, repair the cause and
retry with the same destinations. Do not delete groups as automatic rollback.
Review every destination and shared dependency before any
[environment removal](deploy-full-stack.md#remove-an-environment).
For split-group deployments, a `predown` safety hook blocks `azd down`; cleanup
requires manual inventory, owner review and separately authorized removal.
No automatic deletion or bypass option is provided. The single-group teardown path is unchanged.

### Values set by azd or by you

A **principal** is a user or service identity. Its **object ID** identifies
that identity in the Entra directory; it is not an application's client ID.

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
| `SIDE_BY_SIDE` | `true` | Selects side-by-side placement for private endpoints and DNS zones rather than placing them in the existing VNet's resource group. See the private endpoint group precedence below. |

### General

| Variable | Default | Description |
| --- | --- | --- |
| `AZURE_PRINCIPAL_TYPE` | `User` | Type of `AZURE_PRINCIPAL_ID`. Use `ServicePrincipal` in pipelines. |
| `DEPLOYMENT_MODE` | `standalone` | Declares deployment intent for tags and preflight. `ailz-integrated` does not automatically attach a hub or override component flags. Supply the hub, routing, resource reuse and DNS inputs explicitly. |
| `POLICY_MANAGED_PRIVATE_DNS` | `false` | Delegates private DNS zone groups/records to Azure Policy. Use instead of BYO private DNS zone IDs; agree policy coverage, VNet links and readiness with the DNS owner. |
| `RESOURCE_NAMING_MODE` | `caf` | Uses Cloud Adoption Framework prefixes and naming tokens. See [Resource naming](resource-naming.md). |
| `USE_CAPP_API_KEY` | `false` | Hosted composition keeps this API-key mechanism disabled. It does not configure Entra ID sign-in. |
| `APP_RUNTIME_CONFIGURATION_MODE` | `appConfig` | The Agent Application reads runtime settings from App Configuration. |
| `ENABLE_COSMOS_ANALYTICAL_STORAGE` | `false` | Enables the Agent Application Cosmos DB analytical store. |
| `AZURE_SEARCH_LOCATION` | Empty | Region for both the Agent Application Search service and the separate Foundry Agent Service Search service. Leave empty to use `AZURE_LOCATION`. |
| `AZURE_SPEECH_LOCATION` | Empty | Region for Azure AI Speech. Leave empty to use the deployment region. |
| `AZURE_PE_LOCATION` | Empty | Region for private endpoints. Leave empty to use the deployment region. |
| `AZURE_PE_RESOURCE_GROUP_NAME` | Empty | Explicit private endpoint group override takes precedence. When empty, `USE_EXISTING_VNET=true` with `SIDE_BY_SIDE=false` uses the existing VNet's group; otherwise uses the resolved network group (`AZURE_NETWORK_RESOURCE_GROUP`, falling back to `AZURE_RESOURCE_GROUP`). Optional multi-group placement is available from v4.4.0; the single-group default is unchanged. |
| `EXISTING_APPLICATION_INSIGHTS_CONNECTION_STRING` | None | Sends telemetry to an Application Insights resource you already have. |

Supported `EXISTING_*` inputs select reuse, subject to each resource's conditions.
They are listed in [Network and security](#network-and-security).
Foundry backing-service reuse uses native parameter names instead; see
[Resource selection and reuse](planning.md#select-reuse-or-omit-resources).
A supported resource ID selects reuse; naming and deployment flags control
resource creation.

<span id="ingestion-application-selection"></span>

### Agent App Ingestion selection

| Variable | Fresh-environment default | Description |
| --- | --- | --- |
| `DEPLOY_INGESTION_CONTAINER_APP` | `false` | Selects the optional Agent App Ingestion component of the Agent Application, independently of `DEPLOYMENT_TOPOLOGY`. |

The boolean is persisted by pre-provision and published under label `agent-lz`.
Existing environments retain their selection rather than silently adopting the
fresh default. Custom definitions retain their declared components and additive
infrastructure composition.

| Selection | Effect |
| --- | --- |
| `false` | Omits Agent App Ingestion from subsequent Agent Application composition/deployment and reconciliation. The UI disables attachment controls and upload paths, not text chat, authentication or retrieval. |
| `true` | Selects the app and retains the UI's existing upload eligibility checks. It does not grant every caller permission to upload. |

Omission supports native Foundry IQ `azureBlob`, or an explicitly configured,
independently populated `SEARCH_RAG_INDEX_NAME` for `ai_search` / Foundry IQ
`searchIndex`. It does not select a strategy, configure SharePoint, rewrite
source configuration, populate an index or remove authorization.
`FOUNDRY_IQ_CONVERSATION_UPLOAD_ENABLED=true` requires the app.

See [Ingestion](ingestion.md) for native ingestion, conversation uploads and
custom processing. Disabling the component does not delete existing resources
or revoke their grants.

### Search region and quota

`AZURE_SEARCH_LOCATION` resolves the effective Bicep `searchServiceLocation`.
An unset or empty value falls back to `AZURE_LOCATION`. Both newly created
Search services use this effective region. Provider availability and Search
quota checks use that same region, not the primary region when an override
is set.

Search quota must cover the complete enabled service count: one Agent Application service
when `deploySearchService` (`DEPLOY_SEARCH_SERVICE`) is enabled, plus one Foundry
Search service when `deployAiFoundry` and `deployAAfAgentSvc`
(`DEPLOY_AAF_AGENT_SVC`) are enabled and `aiSearchResourceId` is not supplied.
When both creation paths are enabled, the check requires quota for two services.
Reusing a Foundry Search resource does not request a new service for that path.
Bypassing preflight does not resolve region mismatches or insufficient quota.
See [Search preflight region and quota](troubleshooting.md#search-preflight-region-and-quota).

### Retrieval

A **knowledge source** describes retrievable data; a **knowledge base**
combines sources for retrieval. The pattern identifies the setup arrangement,
such as native Blob processing or an independently populated Search index.
The source kind identifies the data connector. Both default to `azureBlob`.

Foundry IQ manages the default Blob knowledge source and knowledge base.
Native source processing does not require Agent App Ingestion. The application
uses the knowledge base for retrieval; source permissions and application
authorization still apply.

| Variable | Default | Description |
| --- | --- | --- |
| `RETRIEVAL_BACKEND` | `foundry_iq` | Retrieval implementation used by the Agent Application orchestrator. |
| `FOUNDRY_IQ_PATTERN` | `azureBlob` | Native Blob source processing and knowledge-base setup. |
| `FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND` | `azureBlob` | Blob connector for the knowledge source. |
| `FOUNDRY_IQ_API_VERSION` | `2026-05-01-preview` | Azure AI Search API version used for Foundry IQ objects. |
| `FOUNDRY_IQ_IS_ADLS_GEN2` | `false` | Identifies Azure Data Lake Storage (ADLS) Gen2: Blob storage with a hierarchical directory namespace. `true` when the source account uses that namespace. |
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
This deployment-generated metadata is not an operator override. See
[Private native Blob ingestion](network-isolation.md#private-native-blob-ingestion).

### Explicit shared-source permission options

Ingestion permission metadata records access information alongside indexed
content. `rbacScope` records Azure RBAC scopes; `sensitivityLabels` records
information-protection labels. Retrieval must still enforce the applicable
permissions for the caller.

`FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS` controls the configured source's
ingestion permission metadata. Omission or an actual null value retains the protected default
`["rbacScope"]`. An explicit JSON empty array, `[]`, is an opt-in for a
deliberately shared source **when native Blob ingestion is active**.
An empty array is distinct from an omitted setting.

For active native Blob ingestion, the shared-source empty list is accepted
with `RETRIEVAL_BACKEND=foundry_iq`, `FOUNDRY_IQ_PATTERN=azureBlob`,
`azureBlob` knowledge source kind
and a recognized non-ADLS source. Active ADLS Gen2, mismatched source
configuration and ambiguous ADLS configuration fail closed. Nonempty Blob
permission lists accept only `rbacScope` and `sensitivityLabels`.

The infrastructure also publishes `[]` as **unused metadata** for inactive
native Blob ingestion: `ai_search` with any pattern, or `foundry_iq` with
the `searchIndex` pattern. Those empty lists remain accepted because no
native Blob knowledge source is rendered. They are not shared-source opt-ins
and do not change the independently populated index's authorization.

Malformed JSON, scalar values, textual `null`, invalid list entries and
unsupported permission names fail with actionable diagnostics.
Invalid input fails closed rather than silently removing protection.
An actual null and the text `null` are different inputs.

For active native Blob ingestion, `[]` is appropriate only when policy permits
the source's documents to be shared without that ingestion permission metadata.
It does not grant document access by
itself or change other sources, application authentication, Entra ID/OBO,
retrieval authorization, RBAC or private network restrictions. It is not a
workaround for an authentication or private-link failure. Its use requires
audience review and allow/deny tests with real user identities before activation.

Restoring `["rbacScope"]` requires source reconfiguration and verification
of source/index permission metadata, including already-ingested documents.
Allowed and denied users both need validation before access resumes. The
[Deploy full stack](deploy-full-stack.md) runbook covers reconfiguration.
See also
[Private native Blob ingestion](network-isolation.md#private-native-blob-ingestion).

## Network and security

These parameters apply mainly when `NETWORK_ISOLATION=true`.
[Network isolation](network-isolation.md) explains connectivity and DNS requirements.

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

### Optional application private endpoint subnet

**Available from v4.4.0:** new Agent Bicep/azd deployments can separate
application private endpoints from Foundry/grounding private endpoints.
This choice is independent of resource group count and does not enable network
isolation or additional services.

| Variable | Native root parameter | Default | Purpose |
| --- | --- | --- | --- |
| `AZURE_APPLICATION_PE_SUBNET_NAME` | `applicationPeSubnetName` | Empty string | Name of the optional application private endpoint subnet; supply with its prefix. |
| `AZURE_APPLICATION_PE_SUBNET_PREFIX` | `applicationPeSubnetPrefix` | Empty string | Aligned IPv4 CIDR for that subnet; supply with its name. |

Leave both empty to keep the existing shared private endpoint subnet, even with
three resource groups. When both are set, enabled application Cosmos DB, Key
Vault, App Configuration, Container Apps, ACR and Azure Monitor Private Link
Scope private endpoints use the application subnet. Foundry/grounding endpoints
remain on the subnet selected by existing native `peSubnetName` and
`peSubnetPrefix` parameters.

Set the pair before first provision, using your approved address plan:

```bash
azd env set AZURE_APPLICATION_PE_SUBNET_NAME snet-app-pe
azd env set AZURE_APPLICATION_PE_SUBNET_PREFIX <approved-ipv4-subnet-cidr>
```

Bootstrap validates the pair, subnet name and IPv4 CIDR before optional group
creation. Bicep additionally checks a network-aligned prefix length of `/29`
or shorter, containment in the VNet, non-overlap with base subnet prefixes,
a distinct subnet name and compatibility with BYO VNet settings. Review subnet
ownership and existing-subnet compatibility with the network owner; these
settings do not bypass the existing `DEPLOY_SUBNETS` contract.

### Hub integration

These parameters describe spoke integration with an existing hub.
[Hub integration](network-isolation.md#integrate-with-an-existing-hub) explains the network design.

| Variable | Default | Description |
| --- | --- | --- |
| `HUB_INTEGRATION_HUB_VNET_RESOURCE_ID` | None | Resource ID of the hub virtual network. |
| `HUB_INTEGRATION_CREATE_HUB_PEERING` | `true` | Creates spoke-to-hub peering for a newly created spoke VNet. The hub owner supplies reverse peering. With an existing VNet, both directions are externally managed. |
| `HUB_INTEGRATION_PEERING_ALLOW_GATEWAY_TRANSIT` | `false` | Allows gateway transit on the peering. |
| `HUB_INTEGRATION_PEERING_USE_REMOTE_GATEWAYS` | `false` | Uses the hub gateways from the spoke. |
| `HUB_INTEGRATION_EGRESS_NEXT_HOP_IP` | None | Private IP of the hub firewall used as the default route. |
| `HUB_INTEGRATION_EXISTING_ROUTE_TABLE_RESOURCE_ID` | None | Route table to attach instead of creating one. |

### Existing resources

Supported resource-ID inputs select reuse instead of creation:

- `EXISTING_VNET_RESOURCE_ID`
- `EXISTING_JUMPBOX_RESOURCE_ID`
- `EXISTING_BASTION_RESOURCE_ID`
- `EXISTING_NAT_GATEWAY_RESOURCE_ID`
- `EXISTING_LOG_ANALYTICS_WORKSPACE_RESOURCE_ID`
- `EXISTING_APPLICATION_INSIGHTS_RESOURCE_ID`

Existing private DNS zones, such as hub-owned zones, use
`EXISTING_PRIVATE_DNS_ZONE_<ZONE>_RESOURCE_ID`, where `<ZONE>` is one of:

`COGSVCS`, `OPENAI`, `AISERVICES`, `SEARCH`, `COSMOS`, `BLOB`, `KEYVAULT`, `APPCONFIG`, `CONTAINERAPPS`, `ACR`, `AZUREMONITOR`, `OMSOPSINSIGHTS`, `ODSOPSINSIGHTS`, `AZUREAUTOMATION`, `APPINSIGHTS`.

Their owner must provide the required VNet links or resolver forwarding
separately from network peering. With `POLICY_MANAGED_PRIVATE_DNS=true`,
Azure Policy manages DNS records instead of the template. Policy coverage
and links need agreement with the DNS owner. Policy-managed DNS and explicit
existing-zone IDs are mutually exclusive DNS arrangements.

## Hosted agent

The orchestrator runs as a Foundry hosted agent by default. The
`hosted-no-panel` topology omits the panel and Agent Application Cosmos DB,
not Foundry's separate backing services. See [Agent hosting](hosted-agents.md)
for supported capabilities and conversation-history limitations.

Ordinary chat uses history supplied by the UI on each turn. Hosted orchestration
does not itself provide durable cross-session history. **Continuity**, the UI's
optional ability to resume a saved conversation, is a separate, gated capability,
not enabled by hosted topology alone.

| Variable | Default | Description |
| --- | --- | --- |
| `DEPLOYMENT_TOPOLOGY` | `hosted-no-panel` | Agent Application topology. See [Topologies](hosted-agents.md#topologies). |
| `DEPLOY_AAF_AGENT_SVC` | `true` | Enables the Foundry Agent Service capability host. |
| `HOSTED_AGENT_NAME` | `agent-app-orchestrator` | Name of the hosted agent in the Foundry project. |
| `HOSTED_AGENT_IMAGE` | `agent-app-orchestrator` | Repository name of the agent image in Container Registry. |
| `HOSTED_CONVERSATION_OWNER_BINDING` | `delegated` | Associates continuity conversations with the authenticated user. Its identity and validation gates are described in [Agent hosting](hosted-agents.md). |
| `HOSTED_CONTINUITY_ENABLED` | `false` | Managed activation state for continuity endpoints. Hosted topology alone does not enable them. See [Hosted agents](hosted-agents.md). |
| `HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS` | `60` | Idle timeout for server-sent event (SSE) response streams. |
| `APP_CONFIG_TLS_COMPATIBILITY` | `false` | Opt-in bootstrap transport for App Configuration and Agent Application Key Vault endpoints. Requires `KEY_VAULT_URI` and a compatible runtime and hosted definition. Certificate verification remains enabled. See [Configuration TLS compatibility](hosted-agents.md#configuration-tls-compatibility). |

Hosted provisioning inputs `HOSTED_AGENT_CONTAINER_CPU` and
`HOSTED_AGENT_CONTAINER_MEMORY` default to `2` and `4Gi`. The Agent Application's
child `hosted-agent/azure.yaml` also declares CPU and memory as **literal
fields**; changing those environment variables alone does not resize the
deployed agent. Resizing requires a reviewed child-definition change compatible
with the provisioned deployment metadata, followed by a new version. See
[host capacity requirements](sizing.md#application-hosting).

The child definition also fixes the deployed agent name, startup command and
protocol versions. Their provisioning inputs alone do not override those
deployment fields.

Other hosted defaults: Responses protocol `2.0.0`,
Invocations protocol `1.0.0`, capability key ID `v1` and capability TTL
`900` seconds. The platform configures continuity history with `100` items
and `32000` estimated tokens. These are not character limits or a limit
on ordinary session chat. See [Hosted agents](hosted-agents.md) for the
continuity activation and history limitations.

[UI continuity configuration](https://github.com/Azure/agent-app-ui/blob/main/docs/python-development.md#optional-continuity)
explains user-ownership checks, signed access capabilities and conversation
storage. These belong to the application runtime, not infrastructure inputs.

`PREPARE_HOSTED_AGENT`, `HOSTED_AGENT_PREPARED` and `DEPLOY_HOSTED_AGENT` are
script-managed state, not operator inputs.

`APP_CONFIG_TLS_COMPATIBILITY` is a container environment variable, not an App
Configuration key: it is read before remote configuration can load. Only `true`
and `false` are accepted. The infrastructure's `KEY_VAULT_URI` output
provides the deployed vault URI without hardcoding a cloud DNS suffix and is
empty when the vault is not deployed. The manifest-pinned Agent Application
and infrastructure combination keeps the loader and hosted definition compatible.

## Deployment controls

Hook execution and application selection use the variables below.
The selected application also affects the resource footprint.

| Variable | Description |
| --- | --- |
| `BUILD_MODE` | `local` uses Docker on the deployment host. `acr-task` uses Azure Container Registry. Unset values select a mode as described below. |
| `RUN_FROM_JUMPBOX` | `false` defers post-provision configuration in an isolated deployment. It is not a connectivity bypass. See [Post-provision can be deferred](network-isolation.md#post-provision-can-be-deferred). |
| `AZURE_SKIP_NETWORK_ISOLATION_WARNING` | `true` defers isolated post-provision configuration unless `RUN_FROM_JUMPBOX` explicitly requests a connectivity check. |
| `PREFLIGHT_SKIP` | `true` skips regional and infrastructure preflight checks, not application-definition or topology validation. |
| `AGENTLZ_REGIONAL_PREFLIGHT_SKIP` | `true` skips only the regional quota and availability check. |
| `AGENTLZ_APP_DEFINITION` | Path to a custom application definition. See [Custom applications](build-your-own-app.md). |

Preflight skip flags are diagnostic controls, not a supported fix for quota,
region, permission or network failures.

An explicit `BUILD_MODE` takes precedence. When it is unset, component scripts
first apply recognized `USE_DOCKER` values: `true`, `1` or `yes` select local;
`false`, `0` or `no` select ACR Tasks. Without either override, network
isolation or a configured task pool selects ACR Tasks. Otherwise, usable Docker
selects local and unavailable Docker selects ACR Tasks. Explicit `local`
fails if Docker is unusable rather than falling back silently.

Hosted orchestrator image preparation always uses ACR Tasks.
`BUILD_MODE=local` does not change that preparation path or the isolated
custom source-build path. See
[Hosted agents](hosted-agents.md) and
[Custom applications](build-your-own-app.md#source-pinning).

## Runtime settings

Post-provision publishes runtime settings to Azure App Configuration with
the label `agent-lz`. That is the label for platform-owned settings.

The Agent Application components do not read exclusively from `agent-lz`. Their startup
loaders also select other component labels, and later matching selections
can overwrite earlier values. Agent App UI and Agent App Ingestion endpoint loaders
end with `label_filter=None`, which leaves the label filter unset and can
read other labels. The orchestrator uses the explicit null label `"\0"` for its last
selection, which reads unlabelled keys rather than all labels. Unlabelled
values can still override `agent-lz` values.

Conflicting component-labelled or unlabelled values can therefore replace a
value written under `agent-lz`. Environment isolation needs separate stores
and identities, not just different labels.

Process variables can also override remote values in the orchestrator and
optional ingestion component when `allow_environment_variables` is enabled.
Their parsing differs: the orchestrator recognizes `1`, `true` and `yes`,
whereas ingestion treats any nonempty string, including `false`, as enabled.
This parsing difference is a risk, not a recommended way to override settings.

An unavailable store does not make every component stop: some loaders disable
remote reads or use configured fallback paths. Runtime validation therefore
needs to confirm the effective settings and authorization behavior, not only
that the process started.

Settings are loaded at startup. A changed key requires the affected Container
App to restart, or a new hosted version to be deployed, before the new startup
configuration is loaded. Running hosted versions are immutable.

Provisioning or post-provision can overwrite deployment-owned keys, so
persistent changes need matching deployment inputs. Custom application
definitions validate settings but do not publish them; the application
must publish its own runtime settings.

The [Deploy full stack](deploy-full-stack.md#change-a-runtime-setting)
runbook provides commands, including [secret rotation](deploy-full-stack.md#rotate-a-secret) for
versioned versus unversioned Key Vault references. Changing deployment selection,
RBAC or infrastructure requires the matching full workflow, not just a key edit.
