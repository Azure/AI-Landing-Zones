<span id="configuration"></span>

# Deployment settings

Agent Landing Zone separates:

- **Deployment inputs**, supplied through the `azd` environment and root `main.parameters.json`. They select resources and the application, and control image builds.
- **Runtime settings**, read by applications from Azure App Configuration at startup. Bootstrap values, such as the store endpoint, must be available before remote reads begin.

The default Agent Application uses Foundry hosted orchestration with
`maf_lite`, no panel and native Foundry IQ Blob ingestion.
This page explains settings and defaults, not an execution sequence.
[How it works](how-it-works.md) introduces the concepts;
[deployment design](planning.md), [capacity](sizing.md) and
[cost planning](cost-planning.md) explain the planning decisions.

The infrastructure-only runbooks for [Bicep](deploy-infra-only.md) and
[Terraform](deploy-terraform-infra-only.md), and the full-stack runbooks for
[Bicep](deploy-full-stack.md) and [Terraform](deploy-terraform-full-stack.md),
describe input commands, provisioning and validation.
Read individual keys instead of dumping
environments that may contain secrets.

!!! note "Application-specific runtime settings"
    Runtime settings vary by application. Those described here belong to
    **Agent Application**, the supplied reference app; a custom app can have
    different requirements.

!!! note "Edit the root inputs"
    Both providers use documented environment inputs and root
    `main.parameters.json`. Structured values use `parameters.<name>.value`.
    Preprovision resolves the shared topology and generates typed inputs.

    Bicep consumes `infra/main.parameters.json`. Terraform consumes the ignored
    `infra/terraform/main.tfvars.json`; its `infra/main.parameters.json` is a
    shared preflight diagnostic artifact. Do not edit either generated file or
    generated `.azure/` inputs.

## Terraform backend settings

Use an existing Azure Storage account and container outside every workload
resource group. Backend settings are separate from workload parameters:

| Variable | Required value or default |
| --- | --- |
| `TF_STATE_RESOURCE_GROUP` | Backend storage account's resource group |
| `TF_STATE_STORAGE_ACCOUNT` | Existing storage account name |
| `TF_STATE_CONTAINER` | Existing state container name |
| `TF_STATE_SUBSCRIPTION_ID` | Defaults to `AZURE_SUBSCRIPTION_ID` |
| `ARM_ENVIRONMENT` | Canonical `public`, `usgovernment` or `china`; qualified from CLI metadata or explicitly selected for process credentials |

The state key is `agent-landing-zone/${AZURE_ENV_NAME}.tfstate`.
AzureAD Blob authentication requires account **Reader** for metadata and
container **Storage Blob Data Contributor**. The workload does not bootstrap
the backend or include it in `azd down`.

Native azd disables state locking. Shared and production environments require
one authorized writer with queued, non-canceling execution per actual state
identity. This is an access/execution control, not backend locking. See the
[single-writer policy](deploy-terraform-infra-only.md#state-protection).
Follow [backend preparation](deploy-terraform-infra-only.md#step-3-prepare-remote-state-outside-the-workload)
for setup commands.

### Azure cloud

The adapter generates the `azureCloud` context and passes the canonical
`ARM_ENVIRONMENT` into the backend:

| Cloud | Storage DNS suffix |
| --- | --- |
| `public` | `core.windows.net` |
| `usgovernment` | `core.usgovcloudapi.net` |
| `china` | `core.chinacloudapi.cn` |

CLI authentication must match the selected subscription and active CLI cloud.
Process credentials require an explicit cloud; any azd-store and process
values must agree. Preprovision persists the qualified cloud before native
backend initialization. The hooks do not change global cloud or authentication
settings.

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

This **Agent azd** interface is shared by the product's Bicep and integrated
Terraform paths using the compatible components pinned by the platform
manifest. For direct shared-module use or portal deployment, follow those
implementations' input references.

New environments use three resource groups by default: Foundry/grounding,
application and workload networking. Existing environments keep their mapping.
All workload destinations must be in `AZURE_SUBSCRIPTION_ID`. Equal names are
valid: one, two or three distinct groups can express the same three logical
destinations. These inputs do not enable services, change network isolation or
create a platform hub; existing BYO VNet, DNS and hub settings still apply.

| Variable | Default | Purpose |
| --- | --- | --- |
| `AZURE_RESOURCE_GROUP` | `rg-<environment-name>` | Foundry and grounding destination, and the native azd root deployment group. An explicitly supplied name is preserved. |
| `AZURE_APP_RESOURCE_GROUP` | `<AZURE_RESOURCE_GROUP>-app` | Application destination: Container Apps, registry, App Configuration, Key Vault, application Cosmos DB and monitoring. |
| `AZURE_NETWORK_RESOURCE_GROUP` | `<AZURE_RESOURCE_GROUP>-network` | Destination for workload-owned network resources. Existing network/private-endpoint overrides retain their own contract. |
| `CREATE_RESOURCE_GROUPS` | `true` for new environments | Strict boolean (`true` or `false`): allows creating missing additional destination groups. Set `false` to require pre-created additional groups. Does not disable azd's normal root-group creation. |

The hook saves these defaults in the selected azd environment before provision.
For long custom root names, generated names include a stable hash and suffix
within Azure's 90-character limit. These are first-run defaults, not automatic
changes to existing environments.

Set destinations **before first provision**. For three pre-created groups:

```bash
azd env set AZURE_RESOURCE_GROUP rg-ai
azd env set AZURE_APP_RESOURCE_GROUP rg-app
azd env set AZURE_NETWORK_RESOURCE_GROUP rg-net
azd env set CREATE_RESOURCE_GROUPS false
```

For two groups, set `AZURE_NETWORK_RESOURCE_GROUP` to `rg-ai` to keep networking
with Foundry, or `rg-app` to keep it with the application.
For one group, explicitly select the same name for all destinations:

```bash
azd env set AZURE_RESOURCE_GROUP rg-workload
azd env set AZURE_APP_RESOURCE_GROUP rg-workload
azd env set AZURE_NETWORK_RESOURCE_GROUP rg-workload
```

With `false`, a missing additional destination fails before services are
provisioned. With `true`, existing groups are reused without
changing their tags or location; only missing additional groups are created.

The additional destinations are application and network; azd manages creation
of the Foundry/root group through its normal lifecycle.
New additional groups do not receive the `azd-env-name` tag.

Run the normal product-root lifecycle: each `azd provision` coordinates the
selected provider across the configured destinations. Bicep uses its
resource-group-scoped root and scoped modules; Terraform uses its repository-owned
composition. Do not replace the lifecycle with three manual deployments.
Hosted image preparation remains part of application deployment.

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

Resource-group Contributor and scoped RBAC administration do not grant Entra
directory reads; for platform-output client-ID discovery, restricted automation
can instead supply `AGENTLZ_COMPONENT_IDENTITIES` as a nonsecret JSON map of
Container App component names to pre-resolved managed-identity client IDs,
without granting broad directory rights.

The workflow records the mapping with the environment and uses the deploying
identity's permissions. Preserve that mapping for provisioning, deployment
and recovery.

After partial failure, repair the cause and
retry with the same destinations. Do not delete groups as automatic rollback.
Review every destination and shared dependency before any
[environment removal](deploy-full-stack.md#remove-an-environment).

For **Bicep**, the `predown` guard blocks split-group `azd down`; arrange
owner-reviewed, separately authorized cleanup.
For **Terraform**, the guard verifies the original common group binding,
`terraform-resource-groups.json` and `terraform-backend.json`, then permits
native state-scoped destroy across recorded owned/BYO groups. It rejects
missing records or retargeted groups/backend settings. See
[Terraform removal](deploy-terraform-infra-only.md#remove-the-foundation).

### Values set by azd or by you

A **principal** is a user or service identity. Its **object ID** identifies
that identity in the Entra directory; it is not an application's client ID.

| Variable | Description |
| --- | --- |
| `AZURE_ENV_NAME` | Environment name. Set by `azd env new`. Used to derive resource names. |
| `AZURE_LOCATION` | Primary Azure region. Set it before provision so the first-run hook can create the additional resource groups. |
| `AZURE_PRINCIPAL_ID` | Deployment identity's object ID for service setup and access. azd resolves it for Bicep; Terraform preprovision detects a missing value for ordinary CLI, service-principal and managed-identity authentication. |

For certificate, OIDC or custom managed-identity authentication, explicitly
set `AZURE_PRINCIPAL_ID` and `AZURE_PRINCIPAL_TYPE` to identify the caller.
These inputs are not credentials; use the caller's object ID, not its client
ID. See [Terraform authentication](deploy-terraform-infra-only.md#step-2-authenticate-and-select-the-target).

### Inputs that use Bicep defaults

These mappings have no inline default in `main.parameters.json`.
When unset, they use the template defaults shown below.

| Variable | Template default | Description |
| --- | --- | --- |
| `NETWORK_ISOLATION` | `false` | Set `true` explicitly for the recommended private production setup. `false` selects public service endpoints; use it only for approved evaluations without sensitive data. Jumpbox, Bastion and firewall also depend on their component flags. See [Network isolation](network-isolation.md). |
| `AZURE_AI_FOUNDRY_LOCATION` | Deployment region | Region for the Microsoft Foundry account. |
| `AZURE_COSMOS_LOCATION` | Deployment region | Region for Agent Application Cosmos DB. |
| `USE_UAI` | `false` | Uses user-assigned managed identities instead of system-assigned identities. |
| `ENABLE_AGENTIC_RETRIEVAL` | `false` | Enables the template's agentic retrieval resource configuration. This is separate from the Agent Application setting `RETRIEVAL_BACKEND`. |
| `USE_EXISTING_VNET` | `false` | Deploys into a virtual network you already have when network isolation is enabled. |
| `EXISTING_VNET_RESOURCE_ID` | Empty | Resource ID required when reusing a virtual network. |
| `SIDE_BY_SIDE` | `true` | Selects side-by-side placement for private endpoints and DNS zones rather than placing them in the existing VNet's resource group. See the private endpoint group precedence below. |

### General

| Variable | Default | Description |
| --- | --- | --- |
| `AZURE_PRINCIPAL_TYPE` | `User`; inferred during Terraform caller detection | Type of `AZURE_PRINCIPAL_ID`: `User` or `ServicePrincipal`. Explicit service identities use `ServicePrincipal`. |
| `DEPLOYMENT_MODE` | `standalone` | Declares deployment intent for tags and preflight. `ailz-integrated` does not automatically attach a hub or override component flags. Supply the hub, routing, resource reuse and DNS inputs explicitly. |
| `POLICY_MANAGED_PRIVATE_DNS` | `false` | Delegates private DNS zone groups/records to Azure Policy. Use instead of BYO private DNS zone IDs; agree policy coverage, VNet links and readiness with the DNS owner. |
| `RESOURCE_NAMING_MODE` | `caf` | Uses Cloud Adoption Framework prefixes and naming tokens. See [Resource naming](resource-naming.md). |
| `USE_CAPP_API_KEY` | `false` | Hosted composition keeps this API-key mechanism disabled. It does not configure Entra ID sign-in. |
| `APP_RUNTIME_CONFIGURATION_MODE` | `appConfig` | The Agent Application reads runtime settings from App Configuration. |
| `ENABLE_COSMOS_ANALYTICAL_STORAGE` | `false` | Enables the Agent Application Cosmos DB analytical store. |
| `AZURE_SEARCH_LOCATION` | Empty | Region for both the Agent Application Search service and the separate Foundry Agent Service Search service. Leave empty to use `AZURE_LOCATION`. |
| `AZURE_SPEECH_LOCATION` | Empty | Region for Azure AI Speech. Leave empty to use the deployment region. |
| `AZURE_PE_LOCATION` | Empty | Region for private endpoints. Leave empty to use the deployment region. |
| `AZURE_PE_RESOURCE_GROUP_NAME` | Empty | Explicit private endpoint group override takes precedence. When empty, `USE_EXISTING_VNET=true` with `SIDE_BY_SIDE=false` uses the existing VNet's group; otherwise uses the resolved network group (`AZURE_NETWORK_RESOURCE_GROUP`). New Foundry-root environments initialize a separate network group; existing single-group environments retain their mapping. |
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
| `RETRIEVAL_AUTH_MODE` | `native_search` | Automatically published runtime authorization contract for the integrated native Search path. The UI obtains the delegated Search token; the hosted connector forwards it separately from workload transport authentication. |
| `FOUNDRY_IQ_PATTERN` | `azureBlob` | Native Blob source processing and knowledge-base setup. |
| `FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND` | `azureBlob` | Blob connector for the knowledge source. |
| `FOUNDRY_IQ_API_VERSION` | `2026-05-01-preview` | Azure AI Search API version used for Foundry IQ objects. |
| `FOUNDRY_IQ_IS_ADLS_GEN2` | `false` | Identifies Azure Data Lake Storage (ADLS) Gen2: Blob storage with a hierarchical directory namespace. `true` when the source account uses that namespace. |
| `KNOWLEDGE_BASE_NAME` | `knowledge-base` | Knowledge base name. |
| `KNOWLEDGE_BASE_CONNECTION_NAME` | `knowledge-base-connection` | Foundry project connection to the knowledge base. |
| `FOUNDRY_IQ_KNOWLEDGE_SOURCE_NAME` | `knowledge-base-blob-ks` | Knowledge source name. |
| `FOUNDRY_IQ_SEARCH_INDEX_NAME` | `agent-lz-index` | Search index name. |

Other retrieval defaults: billing plan `free`, semantic configuration `default`, security field `metadata_security_id`, storage container `documents`, content extraction mode `standard`, ingestion permission options `["rbacScope"]`, and the filter add-on disabled.

Native authorization uses the index's `userIds`, `groupIds` and `rbacScope`
annotations, not the legacy security-field/add-on setting. Provisioning enables
native permission filtering on new and compatible existing application indexes
without deleting their documents or custom schema. Incompatible field
annotations stop the update; do not disable permission checks to force it through.

### Additional native source identities

Work IQ, Fabric and indexed SharePoint require the implemented
`2026-08-01-preview` source contract. Configure the matching source flag,
knowledge-source name and bindings; incomplete enabled sources fail before
resource changes instead of disappearing from a mixed knowledge base.
Fabric sources also select the configured planning model and `low` reasoning.

These optional identity inputs are nonsecret UUIDs. Explicit deployment
environment values are published under `agent-lz`; omission invents no identity
and an explicit empty value clears that setting.

| Setting | Meaning |
| --- | --- |
| `WORK_IQ_APPLICATION_ID` | Work IQ app's application/client ID. |
| `WORK_IQ_FEDERATED_CREDENTIAL_ID` | Object ID of the credential that trusts the Search principal, not the principal ID. |
| `WORK_IQ_TENANT_ID` | App tenant ID for cross-tenant Work IQ configuration. |
| `SHAREPOINT_INDEXED_APPLICATION_ID` | SharePoint ingestion app's application/client ID. |
| `SHAREPOINT_INDEXED_FEDERATED_CREDENTIAL_APPLICATION_ID` | Application/client ID of the federated Search managed identity, not a credential object ID. |

These settings do not register Entra apps, grant tenant consent or remove source
licensing/billing requirements. See [Work IQ](work-iq.md) and
[SharePoint](sharepoint.md) for administrator setup.

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

Malformed JSON, a single value instead of a JSON list, the text `null`,
invalid list entries and unsupported permission names fail with actionable
diagnostics.
Invalid input fails closed rather than silently removing protection.
An actual null and the text `null` are different inputs.

For active native Blob ingestion, `[]` is appropriate only when policy permits
the source's documents to be shared without that ingestion permission metadata.
It does not grant document access by
itself or change other sources, application authentication, Entra ID/OBO,
retrieval authorization, RBAC or private network restrictions.

It is not a
workaround for an authentication or private-link failure. Its use requires
audience review and allow/deny tests with real user identities before activation.

Restoring `["rbacScope"]` requires source reconfiguration and verification
of source/index permission metadata, including already-ingested documents.
Allowed and denied users both need validation before access resumes. The
[Deploy full stack](deploy-full-stack.md) runbook covers reconfiguration.
See also
[Private native Blob ingestion](network-isolation.md#private-native-blob-ingestion).

### Protected download configuration

Native hosted downloads reuse the configured storage account/containers and
`SEARCH_SERVICE_QUERY_ENDPOINT`, `SEARCH_RAG_INDEX_NAME` and
`SEARCH_API_VERSION`; there is no separate permission-bypass switch.
The bundled UI includes `retrieval-reader` for native Search transport during
upload authorization. Its workload role does not grant the caller access.

Shared document downloads additionally require delegated Azure Storage
`user_impersonation` consent on the UI app and the user's source RBAC/ACLs.
See [protected citation downloads](application-auth.md#protected-citation-downloads).
Do not change Blob ingestion permission options to fix a download denial.

## Network and security

These parameters apply mainly when `NETWORK_ISOLATION=true`.
[Network isolation](network-isolation.md) explains connectivity and DNS requirements.

Additional runtime destinations belong in the application's
[`components[].egress`](build-your-own-app.md#runtime-egress-declarations),
not a blanket network exception or App Configuration key.
[Review the component plan](network-isolation.md#component-runtime-egress)
before provisioning; external firewall policies remain report-only.

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

### Subnet creation and addressing

Choose [subnet ownership](network-isolation.md#choose-subnet-ownership) first.
The global `DEPLOY_SUBNETS` switch and all twelve individual switches default
to `true` through inline environment mappings in root `main.parameters.json`.
Effective creation is `networkIsolation && deploySubnets && individualFlag`.

| Native root parameter | Environment input | Subnet purpose |
| --- | --- | --- |
| `deploySubnets` | `DEPLOY_SUBNETS` | Global creation switch for new and existing VNets |
| `deployAgentSubnet` | `DEPLOY_AGENT_SUBNET` | Foundry Agent Service |
| `deployAcaEnvironmentSubnet` | `DEPLOY_ACA_ENVIRONMENT_SUBNET` | Container Apps environment |
| `deployPeSubnet` | `DEPLOY_PE_SUBNET` | Foundry/grounding private endpoints |
| `deployAzureBastionSubnet` | `DEPLOY_AZURE_BASTION_SUBNET` | Bastion |
| `deployAzureFirewallSubnet` | `DEPLOY_AZURE_FIREWALL_SUBNET` | Firewall |
| `deployGatewaySubnet` | `DEPLOY_GATEWAY_SUBNET` | VPN/ExpressRoute reservation |
| `deployAppGatewaySubnet` | `DEPLOY_APP_GATEWAY_SUBNET` | Application Gateway |
| `deployJumpboxSubnet` | `DEPLOY_JUMPBOX_SUBNET` | Jumpbox |
| `deployDevopsBuildAgentsSubnet` | `DEPLOY_DEVOPS_BUILD_AGENTS_SUBNET` | Build agents |
| `deployApplicationPeSubnet` | `DEPLOY_APPLICATION_PE_SUBNET` | Application private endpoints |
| `deployPowerPlatformSubnet` | `DEPLOY_POWER_PLATFORM_SUBNET` | Power Platform |
| `deployAiGatewaySubnet` | `DEPLOY_AI_GATEWAY_SUBNET` | AI Gateway |

A `false` creation flag means do not create/manage that subnet; it does **not**
disable its consumer. Every enabled consumer must have an existing, valid
subnet in the selected VNet, or be explicitly disabled. No consumer is silently
disabled or redirected to another subnet.

For a fresh deployment without Power Platform integration, omit its optional
reservation with `azd env set DEPLOY_POWER_PLATFORM_SUBNET false`.
In contrast, disabling application PE subnet creation still requires an
existing [application PE subnet](#application-private-endpoint-subnet)
when application private endpoints are enabled.

An isolated new VNet is still created when subnet creation is disabled, but
configuration fails if an enabled workload requires a subnet that is absent.
For an existing VNet, only selected subnets are created/updated, through
serialized child deployments; its entire subnet collection is not replaced.
Managed BYO subnet writes require `deployNsgs=true`; opting out of a subnet's
creation does not remove its existing NSG association. Creation flags are not
deletion commands or a guarantee of preserving every previously submitted
subnet in a deployment-owned VNet; Azure can reject removal of occupied subnets.

`deployAiFoundrySubnet` controls the Foundry Agent Service subnet association,
not subnet creation. Use `deployAgentSubnet` for creation ownership.

#### Network selection examples

For a new isolated environment, set `azd env set NETWORK_ISOLATION true`,
then apply the matching selection.

For a **new VNet**, keep the default names and address plan unless your network
owner requires different ranges:

```bash
azd env set USE_EXISTING_VNET false
azd env set DEPLOY_SUBNETS true
```

For an **existing VNet with template-managed subnets**, replace the placeholder
with its full ARM resource ID and match the subnet inputs to the approved plan:

```bash
azd env set USE_EXISTING_VNET true
azd env set EXISTING_VNET_RESOURCE_ID <existing-vnet-resource-id>
azd env set DEPLOY_SUBNETS true
```

For **externally managed subnets**, use the same existing-VNet inputs but set
`azd env set DEPLOY_SUBNETS false`. Confirm all required subnets already exist
with the configured names, prefixes, delegations and NSG requirements.
Then continue with the selected deployment runbook; these inputs do not
configure peering, DNS forwarding or runner connectivity.

#### Names and address ranges

All twelve name and prefix parameters can be overridden in root
`main.parameters.json` or through the environment bindings below. Explicit
operator values are preserved through composition; the allocation table lists
defaults, not mandatory ranges. Reserved service names must retain their
required spellings.

| Native name parameter | Name environment input | Native prefix parameter | Prefix environment input |
| --- | --- | --- | --- |
| `agentSubnetName` | `AZURE_AGENT_SUBNET_NAME` | `agentSubnetPrefix` | `AZURE_AGENT_SUBNET_PREFIX` |
| `acaEnvironmentSubnetName` | `AZURE_ACA_ENVIRONMENT_SUBNET_NAME` | `acaEnvironmentSubnetPrefix` | `AZURE_ACA_ENVIRONMENT_SUBNET_PREFIX` |
| `peSubnetName` | `AZURE_PE_SUBNET_NAME` | `peSubnetPrefix` | `AZURE_PE_SUBNET_PREFIX` |
| `azureBastionSubnetName` | `AZURE_BASTION_SUBNET_NAME` | `azureBastionSubnetPrefix` | `AZURE_BASTION_SUBNET_PREFIX` |
| `azureFirewallSubnetName` | `AZURE_FIREWALL_SUBNET_NAME` | `azureFirewallSubnetPrefix` | `AZURE_FIREWALL_SUBNET_PREFIX` |
| `gatewaySubnetName` | `AZURE_GATEWAY_SUBNET_NAME` | `gatewaySubnetPrefix` | `AZURE_GATEWAY_SUBNET_PREFIX` |
| `azureAppGatewaySubnetName` | `AZURE_APP_GATEWAY_SUBNET_NAME` | `azureAppGatewaySubnetPrefix` | `AZURE_APP_GATEWAY_SUBNET_PREFIX` |
| `jumpboxSubnetName` | `AZURE_JUMPBOX_SUBNET_NAME` | `jumpboxSubnetPrefix` | `AZURE_JUMPBOX_SUBNET_PREFIX` |
| `devopsBuildAgentsSubnetName` | `AZURE_DEVOPS_BUILD_AGENTS_SUBNET_NAME` | `devopsBuildAgentsSubnetPrefix` | `AZURE_DEVOPS_BUILD_AGENTS_SUBNET_PREFIX` |
| `applicationPeSubnetName` | `AZURE_APPLICATION_PE_SUBNET_NAME` | `applicationPeSubnetPrefix` | `AZURE_APPLICATION_PE_SUBNET_PREFIX` |
| `powerPlatformSubnetName` | `AZURE_POWER_PLATFORM_SUBNET_NAME` | `powerPlatformSubnetPrefix` | `AZURE_POWER_PLATFORM_SUBNET_PREFIX` |
| `aiGatewaySubnetName` | `AZURE_AI_GATEWAY_SUBNET_NAME` | `aiGatewaySubnetPrefix` | `AZURE_AI_GATEWAY_SUBNET_PREFIX` |

Set `vnetAddressPrefixes.value` as an explicit array in root
`main.parameters.json` (default `["192.168.0.0/21"]`); there is no
`VNET_ADDRESS_PREFIXES` environment mapping. For example, merge this complete
address plan into the root file's `parameters` object before first provision,
if `10.20.0.0/21` is approved and does not overlap connected networks:

```json
{
  "vnetAddressPrefixes": {"value": ["10.20.0.0/21"]},
  "agentSubnetPrefix": {"value": "10.20.0.0/24"},
  "acaEnvironmentSubnetPrefix": {"value": "10.20.1.0/24"},
  "peSubnetPrefix": {"value": "10.20.2.0/26"},
  "azureBastionSubnetPrefix": {"value": "10.20.2.64/26"},
  "azureFirewallSubnetPrefix": {"value": "10.20.2.128/26"},
  "gatewaySubnetPrefix": {"value": "10.20.2.192/26"},
  "azureAppGatewaySubnetPrefix": {"value": "10.20.3.0/27"},
  "jumpboxSubnetPrefix": {"value": "10.20.3.64/27"},
  "devopsBuildAgentsSubnetPrefix": {"value": "10.20.3.96/27"},
  "applicationPeSubnetPrefix": {"value": "10.20.3.128/26"},
  "powerPlatformSubnetPrefix": {"value": "10.20.4.0/24"},
  "aiGatewaySubnetPrefix": {"value": "10.20.5.0/24"}
}
```

A subnet override does not resize the VNet; a reused VNet's actual address
space is authoritative. Names must be unique and required names/prefixes
cannot be empty. CIDRs must be aligned IPv4 ranges, contained in the VNet and
nonoverlapping with other requested or existing subnets. The same managed
subnet's current range is not counted twice. Invalid ranges fail rather than
being replaced with defaults. Reserved names and service-specific size,
delegation and NSG requirements still apply.

<span id="optional-application-private-endpoint-subnet"></span>

### Application private endpoint subnet

Application private endpoints use their own configured subnet, independently
of resource group count.

| Variable | Native root parameter | Default | Purpose |
| --- | --- | --- | --- |
| `AZURE_APPLICATION_PE_SUBNET_NAME` | `applicationPeSubnetName` | `application-pe-subnet` | Dedicated application private endpoint subnet name. |
| `AZURE_APPLICATION_PE_SUBNET_PREFIX` | `applicationPeSubnetPrefix` | `192.168.3.128/26` | Aligned IPv4 CIDR for the application private endpoint subnet. |

Enabled application Cosmos DB, Key Vault, App Configuration, Container Apps,
ACR and Azure Monitor Private Link
Scope private endpoints use the application subnet. Foundry/grounding private
endpoints use `peSubnetName`/`peSubnetPrefix`, defaulting to `pe-subnet` at
`192.168.2.0/26`.

Customize the name and prefix before first provision, using your approved
address plan:

```bash
azd env set AZURE_APPLICATION_PE_SUBNET_NAME snet-app-pe
azd env set AZURE_APPLICATION_PE_SUBNET_PREFIX <approved-ipv4-subnet-cidr>
```

The application subnet needs a distinct name and an aligned IPv4 CIDR of `/29`
or shorter. Empty required names/prefixes fail explicitly; there is no shared
Foundry PE fallback. With `DEPLOY_APPLICATION_PE_SUBNET=false` or
`DEPLOY_SUBNETS=false`, application endpoints still select this configured
subnet. It must already exist and satisfy the enabled consumers' requirements.

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

### Configuration ownership and declarations

Terraform manages foundation connections, model metadata and input-driven
settings. Shared postprovision queries existing key names, not values, and
seeds **only missing defaults**, preserving existing values, content types
and Key Vault-reference metadata.

`config.deployment.appconfig` updates runtime-owned keys according to the
product's single ownership inventory. Its intent comes from the declared
parameter document and selected azd environment. Declare additional entries
through root `parameters.additionalAppConfigurationSettings.value`, using
`name` and string `value`, plus optional `label` and `contentType`.
Declared labels, content types and literal values are preserved.

Keep the exact reviewed declaration, including required private inputs, on
every runner. A missing required declaration fails; outputs and Terraform state
are not substitutes. The publisher's optional `--input <path>` selects that
exact parameter document. Do not create per-key azd variables to transport it.

Routing, identity and other authority-controlled conflicts are rejected.
Unsupported runtime Key Vault-reference overrides fail explicitly; use the
existing governance or continuity owner for those references.

### Effective settings

The Agent Application components do not read exclusively from `agent-lz`. Their startup
loaders also select other component labels, and later matching selections
can overwrite earlier values.

Agent App UI and Agent App Ingestion endpoint loaders
end with `label_filter=None`, which leaves the label filter unset and can
read other labels.

The orchestrator uses the explicit null label `"\0"` for its last
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

Change foundation-owned settings in their declared inputs and runtime-owned
settings through their publisher; a missing-only default seed does not make
every key operator-owned. Custom application
definitions validate settings but do not publish them; the application
must publish its own runtime settings.

The [Deploy full stack](deploy-full-stack.md#change-a-runtime-setting)
runbook provides commands, including [secret rotation](deploy-full-stack.md#rotate-a-secret) for
versioned versus unversioned Key Vault references. Changing deployment selection,
RBAC or infrastructure requires the matching full workflow, not just a key edit.
