# Parameterization

This reference describes native parameters of the Bicep foundation maintained
in Agent Landing Zone's `infra/bicep/`. The platform's root `main.parameters.json`
supplies reviewed values and `${VARIABLE_NAME}` substitutions. Use `azd env set`
only for substitutions actually present in that file; native arrays and objects
need reviewed file changes.

Agent Landing Zone composes its own root parameter file and regenerates
`infra/bicep/main.parameters.json`. Its definition and topology can override foundation
choices. See [Agent configuration](../agent-landing-zone/configuration.md) rather
than assuming every foundation deploy toggle is an Agent environment variable.
Execute changes through the [infrastructure](../agent-landing-zone/deploy-infra-only.md)
or [full-stack](../agent-landing-zone/deploy-full-stack.md) runbook.

```bash
# Example: set a parameter via azd
azd env set NETWORK_ISOLATION true
```

!!! tip
    Parameters set via `azd env set` are stored locally in the azd environment and override the defaults in `main.parameters.json` at provisioning time. This only works for parameters whose default value uses the `${...}` syntax.

## Environment and location

| Parameter | Default | Env variable | Description |
|---|---|---|---|
| `environmentName` | — | `AZURE_ENV_NAME` | Name prefix for all resources (set automatically by `azd init`) |
| `location` | — | `AZURE_LOCATION` | Primary Azure region for the deployment |
| `aiFoundryLocation` | — | `AZURE_AI_FOUNDRY_LOCATION` | Region for AI Foundry resources (if different from primary) |
| `cosmosLocation` | — | `AZURE_COSMOS_LOCATION` | Region for Cosmos DB account |

## Identity and access

| Parameter | Default | Env variable | Description |
|---|---|---|---|
| `principalId` | — | `AZURE_PRINCIPAL_ID` | Object ID of the deploying user or service principal |
| `useUAI` | — | `USE_UAI` | Use user-assigned managed identity instead of system-assigned |
| `useCAppAPIKey` | — | `USE_CAPP_API_KEY` | Enable API key authentication for Container Apps |

## Feature toggles

| Parameter | Default | Env variable | Description |
|---|---|---|---|
| `deploymentMode` | `standalone` | `DEPLOYMENT_MODE` | Design intent: `standalone` or `ailz-integrated`; explicit network, routing, DNS and reuse inputs still determine behavior |
| `networkIsolation` | `false` | `NETWORK_ISOLATION` | Set `true` explicitly for the recommended private production setup (private endpoints and VNet). The `false` default selects public service endpoints, for approved evaluations without sensitive data. |
| `allowedIpRanges` | `[]` | — (native array) | Approved IPv4/CIDR public-access exceptions on supported service data planes; review separately from private endpoints |
| `useZoneRedundancy` | `false` | — | Enable zone redundancy for supported services |
| `useCMK` | `false` | — | Enable encryption keys that you manage |
| `greenFieldDeployment` | `true` | `GREEN_FIELD_DEPLOYMENT` | Green-field deployment; review resource-specific conditions and reuse inputs |
| `publicIngress` | `{ enabled: false }` | — | Optional Application Gateway WAF v2 public endpoint for a private Container App. See [Public Ingress with Application Gateway](public-ingress.md). |

## Solution Storage controls

These three inputs apply **only to the solution Storage account** controlled by `deployStorageAccount`, not auxiliary AI Foundry Storage, VM storage, or other services. The Storage AVM dependency remains `br/public:avm/res/storage/storage-account:0.26.2`.

| Parameter | Bicep type | Default | Description |
|---|---|---|---|
| `storageAccountNetworkAclsBypass` | String-literal union | `'AzureServices'` | Value passed to the solution account's `networkAcls.bypass`. Only the exact strings listed below are accepted. |
| `storageAccountResourceAccessRules` | Array of sealed objects with required `resourceId: string` and `tenantId: string` fields | `[]` | Complete desired list of resource-instance network rules passed to `networkAcls.resourceAccessRules`. Additional object properties are not accepted. |
| `storageAccountAllowSharedKeyAccess` | `bool` | `true` | Value passed to `allowSharedKeyAccess`. Disabling Shared Key authorization is an explicit, compatibility-sensitive opt-in. |

The bypass union accepts exactly these eight values, with the spelling, comma-space separators, and ordering shown:

- `'None'`
- `'AzureServices'`
- `'Logging'`
- `'Metrics'`
- `'AzureServices, Logging'`
- `'AzureServices, Metrics'`
- `'AzureServices, Logging, Metrics'`
- `'Logging, Metrics'`

Do not combine `None` with another value or use a differently ordered or unspaced string.

### Native parameter values and defaults

These inputs use native JSON values in `main.parameters.json`: a string, an array of objects, and a boolean. They do **not** introduce environment-variable substitutions, environment-variable names, or JSON-string aliases. In particular, do not quote booleans or serialize the rules array into a string.

!!! note "Top-level null selects defaults"
    Bicep `0.42.1` treats an explicit top-level `null` for these defaulted parameters as omission/default selection: `AzureServices`, `[]`, and `true`, respectively. This is [compiler behavior](https://github.com/Azure/bicep/blob/v0.42.1/src/Bicep.Core/Semantics/SemanticModel.cs), not a new runtime fallback or a change to product defaults. For the stricter profile, explicitly set bypass to `None` and Shared Key access to `false`, not `null`; use `[]` when no resource-instance exceptions are desired.

This top-level behavior does not permit malformed nested rule fields. Each rule still requires non-empty string `resourceId` and `tenantId` fields; missing fields, nested `null`, wrong types, empty strings, and extra properties are invalid. Wrong bypass enum values and other wrong parameter types remain invalid.

Omitting all three inputs from a compatible parameter file uses the defaults. The equivalent explicit defaults are shown below as a fragment of the file's `parameters` object, not as a complete deployment parameter file:

```json
{
  "storageAccountNetworkAclsBypass": {
    "value": "AzureServices"
  },
  "storageAccountResourceAccessRules": {
    "value": []
  },
  "storageAccountAllowSharedKeyAccess": {
    "value": true
  }
}
```

Keep customizations in the platform's reviewed, version-controlled root
`main.parameters.json`. The platform hooks compose
`infra/bicep/main.parameters.json`; do not patch that generated copy or change the
pinned AVM to apply these settings. See
[foundation customization](accelerator-pattern.md) and the
[deployment and migration guidance](how-to-deploy.md#solution-storage-profile).

### Network rules are desired state, not discovered exceptions

`storageAccountResourceAccessRules` declares the **entire desired rules list**. A redeployment removes resource-instance rules not included in it, including undesired or manually added exceptions. An empty array, including the omitted-input default, does not preserve rules that exist on the live account. There is no live-state merge or automatic discovery of Defender scanner exceptions.

Each entry must use the exact, approved, existing Azure resource's full ARM resource ID and its tenant ID. Do not use wildcards, tenant/subscription/resource-group-wide scopes, or a synthesized scanner ID. Resource instances must belong to the **same Microsoft Entra tenant** as the Storage account, although their subscriptions can differ.

A sealed object validates the input shape, not the resource's existence, supported type, tenant eligibility, or permissions; those remain Azure-side checks.

A [resource-instance network rule](https://learn.microsoft.com/azure/storage/common/storage-network-security-resource-instances) provides network eligibility, **not data permissions**. The resource's managed identity still needs the appropriate data-plane authorization, managed separately.

These inputs do not change the existing `networkIsolation`, public network access (PNA), `allowedIpRanges`, `defaultAction`, or private-endpoint behavior. Bypass `None` alone does not make an account private. Conversely, PNA `Disabled` does **not** make trusted-service or resource-instance exceptions irrelevant: previously configured exceptions can remain effective. Review them explicitly using the [Storage firewall limitations](https://learn.microsoft.com/azure/storage/common/storage-network-security-limitations) and [network access rules](https://learn.microsoft.com/azure/storage/common/storage-network-security).

An approved existing Defender scanner can be included explicitly in the rules list when needed. These inputs do not enable a Defender plan or create a scanner, its managed identity, or role assignments. Defender's own configuration is a separate prerequisite; see [resources deployed by malware scanning](https://learn.microsoft.com/azure/defender-for-cloud/introduction-malware-scanning#resources-deployed-by-malware-scanning).

### Shared Key compatibility boundary

Before opting into `storageAccountAllowSharedKeyAccess=false`, inventory and migrate all account-key clients, key-based connection strings, service SAS and account SAS consumers, and Azure Files clients and tools. Validate each required protocol and workflow before rollout.

Microsoft Entra authorization and **Blob user delegation SAS** are distinct from key-signed service/account SAS; disabling Shared Key does not disable the former, but they still require suitable network access and data permissions. See [prevent Shared Key authorization](https://learn.microsoft.com/azure/storage/common/shared-key-authorization-prevent).

This is a data-plane authorization control, not a promise of a key-free management-plane deployment. AVM `0.26.2` retains secure outputs that use `listKeys`; setting this input to `false` does not remove those outputs or their management-plane requirements.

## Deploy toggles

Each toggle controls whether a specific service is provisioned. Set to `true` to deploy or `false` to skip.

| Parameter | Default | Description |
|---|---|---|
| `deployAiFoundry` | `true` | AI Foundry account and project |
| `deployAiFoundrySubnet` | `true` | Foundry Agent Service subnet association; `deployAgentSubnet` independently controls subnet creation |
| `deployAppConfig` | `true` | Azure App Configuration store |
| `deployAppInsights` | `true` | Application Insights instance |
| `deployCosmosDb` | `true` | Azure Cosmos DB account and database |
| `deployContainerApps` | `true` | Container Apps (based on `containerAppsList`) |
| `deployContainerRegistry` | `true` | Azure Container Registry |
| `deployContainerEnv` | `true` | Container Apps Environment |
| `deployNsgs` | `true` | Network Security Groups |
| `deployMcp` | `true` | MCP (Model Context Protocol) server |
| `deployGroundingWithBing` | `false` | Bing Grounding service |
| `deployKeyVault` | `true` | Azure Key Vault |
| `deployVmKeyVault` | — | Separate Key Vault for VM secrets (`DEPLOY_VM_KEY_VAULT`) |
| `deployLogAnalytics` | `true` | Log Analytics workspace |
| `deploySearchService` | `true` | Azure AI Search service |
| `deployStorageAccount` | `true` | Azure Storage account |
| `deployJumpbox` | `null` (inherits from preset) | Jumpbox VM |
| `deployBastion` | `null` (inherits from preset) | Azure Bastion host |
| `deployNatGateway` | `null` (inherits from preset) | NAT Gateway for outbound traffic |
| `deploySoftware` | `true` | Pre-install development tools on the Jumpbox VM |

!!! note "Jumpbox, Bastion, and NAT Gateway"
    These components are controlled independently with `deployJumpbox`, `deployBastion`, and `deployNatGateway`, so each topology can choose only the pieces it needs.

## Resource naming

By default, generated resource names follow the Cloud Adoption Framework (CAF) pattern `type-workload-environment-region-instance`, for example `kv-a1b2c3-dev-eus2-001`. You do not have to set anything: every CAF token has a safe default, so a plain `azd provision` produces valid, readable names.

| Parameter | Env variable | Default | Description |
|---|---|---|---|
| `resourceNamingMode` | `RESOURCE_NAMING_MODE` | `caf` | Naming strategy: `caf` (default) or `legacy` (older `resourceToken`-based names). |
| `cafWorkloadName` | `CAF_WORKLOAD_NAME` | short deterministic hash | Workload token. When empty, derived from subscription, environment, and location. Override with a meaningful name such as `contosoai`. |
| `cafEnvironmentName` | `CAF_ENVIRONMENT_NAME` | azd environment name | Environment token, for example `dev` or `prod`. |
| `cafRegionName` | `CAF_REGION_NAME` | mapped from `AZURE_LOCATION` | Region token. `eastus2` becomes `eus2`. |
| `cafInstance` | `CAF_INSTANCE` | `001` | Instance token. Increment only for a second parallel copy of the same workload in the same environment and region. |

Names are length-bounded automatically so they stay within Azure limits (storage 24, Key Vault 24, Container Apps environment 32, and so on). Because the tokens are deterministic, redeploying the same environment produces the same names, so naming stays idempotent.

!!! tip "Override a single token"
    ```bash
    azd env set CAF_WORKLOAD_NAME contosoai
    ```

!!! warning "Upgrading an existing deployment"
    CAF is now the default. To keep the older `resourceToken`-based names and avoid renaming existing resources, pin the legacy mode before provisioning:
    ```bash
    azd env set RESOURCE_NAMING_MODE legacy
    ```

## Resource name overrides

By default, resource names are generated using the [CAF naming pattern](#resource-naming) described above. These parameters override individual resource names in either naming mode.

| Parameter | Default | Description |
|---|---|---|
| `aiFoundryAccountName` | `null` | AI Foundry account name |
| `aiFoundryProjectName` | `null` | AI Foundry project name |
| `aiFoundryProjectDisplayName` | `null` | AI Foundry project display name |
| `aiFoundryProjectDescription` | `null` | AI Foundry project description |
| `aiFoundryStorageAccountName` | `null` | Storage account for AI Foundry |
| `aiFoundrySearchServiceName` | `null` | Search service for AI Foundry |
| `aiFoundryCosmosDbName` | `null` | Cosmos DB account for AI Foundry |
| `bingSearchName` | `null` | Bing Search resource name |
| `appConfigName` | `null` | App Configuration store name |
| `appInsightsName` | `null` | Application Insights name |
| `containerEnvName` | `null` | Container Apps Environment name |
| `containerRegistryName` | `null` | Container Registry name |
| `conversationContainerName` | `null` | Cosmos DB container for conversations |
| `dataIngestContainerAppName` | `null` | Data ingestion Container App name |
| `datasourcesContainerName` | `null` | Cosmos DB container for datasources |
| `dbAccountName` | `null` | Cosmos DB account name |
| `dbDatabaseName` | `null` | Cosmos DB database name |
| `frontEndContainerAppName` | `null` | Front-end Container App name |
| `keyVaultName` | `null` | Key Vault name |
| `logAnalyticsWorkspaceName` | `null` | Log Analytics workspace name |
| `searchServiceName` | `null` | AI Search service name |
| `solutionStorageAccountName` | `null` | Solution Storage account name |

## Existing resource IDs (BYO)

All of the parameters below are optional. Leave them empty to let the template create the resource; set any of them to a resource ID to **reuse** an existing resource instead. Cross-resource-group and cross-subscription IDs are supported throughout.

Use these for hub-and-spoke and workload landing zone designs where a platform
team owns shared services. Resource reuse needs explicit scoped permissions
and connectivity; a resource ID alone does not supply them.

### Workload data services

| Parameter | Env variable | Description |
|---|---|---|
| `aiSearchResourceId` | — (native string) | Reattach a dedicated Foundry backing Search service; this is not the workload Search reuse input. |
| `aiFoundryStorageAccountResourceId` | — (native string) | Reuse dedicated Foundry backing Storage. |
| `aiFoundryCosmosDBAccountResourceId` | — (native string) | Reuse dedicated Foundry backing Cosmos DB. |
| `keyVaultResourceId` | — (native string; add to reviewed root file if needed) | Existing workload Key Vault ID. Review its deployment and access conditions. |

### Observability

#### Log Analytics workspace

- **Parameter:** `existingLogAnalyticsWorkspaceResourceId`
- **Environment variable:** `EXISTING_LOG_ANALYTICS_WORKSPACE_RESOURCE_ID`

Reuse a central Log Analytics workspace. All diagnostic settings, AMPLS
linkage, and the App Configuration entries point at this workspace.

#### Application Insights component

- **Parameter:** `existingApplicationInsightsResourceId`
- **Environment variable:** `EXISTING_APPLICATION_INSIGHTS_RESOURCE_ID`

Reuse an existing Application Insights component. Pair with
`existingApplicationInsightsConnectionString` so downstream consumers
(Container Apps Environment, App Configuration) receive a working connection
string without needing access to the AppInsights resource.

#### Application Insights connection string

- **Parameter:** `existingApplicationInsightsConnectionString`
- **Environment variable:** `EXISTING_APPLICATION_INSIGHTS_CONNECTION_STRING`

Connection string for the reused AppInsights component. Retrieve it with:

```bash
az monitor app-insights component show -g <rg> -a <name> --query connectionString -o tsv
```

This parameter is marked `@secure()`.

### Networking

| Parameter | Env variable | Description |
|---|---|---|
| `existingVnetResourceId` | `EXISTING_VNET_RESOURCE_ID` | Existing VNet to deploy the workload subnets into. Used together with `useExistingVNet=true`. |
| `hubIntegrationHubVnetResourceId` | `HUB_INTEGRATION_HUB_VNET_RESOURCE_ID` | Resource ID of the hub VNet to peer with. When set and `hubIntegrationCreateHubPeering=true`, the deployment creates the spoke→hub peering automatically (the reverse hub→spoke direction requires the hub owner's authorization and action — see [peering and bootstrap ordering](hub-and-spoke.md#peering-and-bootstrap-ordering)). |
| `hubIntegrationExistingRouteTableResourceId` | `HUB_INTEGRATION_EXISTING_ROUTE_TABLE_RESOURCE_ID` | Existing Route Table to attach to the spoke workload subnets. When set, the deployment skips local RT creation and assumes the RT is already configured with the correct default route. |

### Hub jumpbox / Bastion / NAT

An existing ID influences the matching nullable `deploy*` default; an explicit
deploy flag wins. Review the effective flags together rather than assuming the
ID alone suppresses every local resource.

| Parameter | Env variable | Description |
|---|---|---|
| `existingBastionResourceId` | `EXISTING_BASTION_RESOURCE_ID` | Hub-managed Bastion host that has line-of-sight to the spoke jumpbox via peering. |
| `existingNatGatewayResourceId` | `EXISTING_NAT_GATEWAY_RESOURCE_ID` | Hub-managed NAT Gateway to associate with the spoke subnets for outbound egress. |
| `existingJumpboxResourceId` | `EXISTING_JUMPBOX_RESOURCE_ID` | Reference to a hub-managed jumpbox VM. Informational — surfaced to runbooks and post-provision scripts. |

### Private DNS zones

Each applicable zone can be brought from a central platform subscription.
An existing zone ID suppresses its local creation and automatic spoke link.
Every client VNet needs a zone link or explicit DNS forwarding path to a linked
network; **peering alone does not propagate DNS zone links**.
With `policyManagedPrivateDns=true`, use the Policy-owned DNS model instead of
BYO overrides and agree who creates zone groups, records and links.

| Parameter | Zone |
|---|---|
| `existingPrivateDnsZoneCogSvcsResourceId` | `privatelink.cognitiveservices.azure.com` (Cognitive Services / Foundry) |
| `existingPrivateDnsZoneOpenAiResourceId` | `privatelink.openai.azure.com` |
| `existingPrivateDnsZoneAiServicesResourceId` | `privatelink.services.ai.azure.com` |
| `existingPrivateDnsZoneSearchResourceId` | `privatelink.search.windows.net` |
| `existingPrivateDnsZoneCosmosResourceId` | `privatelink.documents.azure.com` |
| `existingPrivateDnsZoneBlobResourceId` | `privatelink.blob.<storage suffix>` |
| `existingPrivateDnsZoneKeyVaultResourceId` | `privatelink.vaultcore.azure.net` |
| `existingPrivateDnsZoneAppConfigResourceId` | `privatelink.azconfig.io` |
| `existingPrivateDnsZoneContainerAppsResourceId` | `privatelink.<region>.azurecontainerapps.io` (region-specific) |
| `existingPrivateDnsZoneAcrResourceId` | `privatelink.azurecr.io` |
| `existingPrivateDnsZoneAzureMonitorResourceId` | `privatelink.monitor.azure.com` |
| `existingPrivateDnsZoneOmsOpsInsightsResourceId` | `privatelink.oms.opinsights.azure.com` |
| `existingPrivateDnsZoneOdsOpsInsightsResourceId` | `privatelink.ods.opinsights.azure.com` |
| `existingPrivateDnsZoneAzureAutomationResourceId` | `privatelink.agentsvc.azure.automation.net` |
| `existingPrivateDnsZoneAppInsightsResourceId` | `privatelink.applicationinsights.io` (consumed only when AMPLS is created locally) |

## Hub integration

For `deploymentMode=ailz-integrated` or hybrid hub-and-spoke designs. See the
[hub-and-spoke reference](hub-and-spoke.md) for ownership, DNS and peering.

| Parameter | Default | Description |
|---|---|---|
| `hubIntegrationCreateHubPeering` | `true` | When `true` and `hubIntegrationHubVnetResourceId` is set, the deployment creates the spoke→hub peering inline. Set to `false` to defer peering creation to the platform team. |
| `hubIntegrationEgressNextHopIp` | `null` | Private IP of the hub Azure Firewall / NVA. When set, the spoke UDR for `0.0.0.0/0` points here. Effective only when `deployAzureFirewall=false` and `networkIsolation=true`. |
| `hubIntegrationPeeringAllowGatewayTransit` | `false` | `allowGatewayTransit` flag on the spoke→hub peering. Set to `true` only when the spoke owns a VPN / ExpressRoute gateway. |
| `hubIntegrationPeeringUseRemoteGateways` | `false` | `useRemoteGateways` flag on the spoke→hub peering. Set to `true` to route on-premises traffic through a hub-owned gateway. |

The BYO IDs that drive this section (`hubIntegrationHubVnetResourceId`, `hubIntegrationExistingRouteTableResourceId`) are listed in the [Networking BYO table above](#networking).

## DNS zone link suffix

| Parameter | Default | Env variable | Description |
|---|---|---|---|
| `dnsZoneLinkSuffix` | `''` | `DNS_ZONE_LINK_SUFFIX` | Suffix appended to VNet-link names when multiple spokes share the same hub Private DNS zones, so the per-spoke link names don't collide. Typical values: `spoke01`, `spoke02`, … |

## Networking

| Parameter | Default | Env variable | Description |
|---|---|---|---|
| `useExistingVNet` | `false` | `USE_EXISTING_VNET` | Use an existing VNet instead of creating a new one. Pair with `existingVnetResourceId`. |
| `deploySubnets` | `true` | `DEPLOY_SUBNETS` | Global creation switch for all twelve subnets, in both new and existing VNets. Effective creation also requires `networkIsolation` and the individual subnet flag. |
| `vnetAddressPrefixes` | `["192.168.0.0/21"]` | — (explicit root array) | Address space for a new VNet. A reused VNet's actual address space is authoritative and is not resized. |
| `sideBySideDeploy` | `false` | `SIDE_BY_SIDE` | Allow a second AI LZ to be deployed side-by-side in the same existing VNet without disturbing the first one's subnets / NSGs. |

See [subnet creation and addressing](../agent-landing-zone/configuration.md#subnet-creation-and-addressing)
for all twelve creation flags (each defaults to `true`), root name/prefix
parameters and their exact environment bindings. A false creation flag does
not disable a consumer: its valid subnet must already exist in the selected
VNet, or the consumer must be explicitly disabled. Application private endpoints
use their configured subnet without falling back to the Foundry PE subnet.
The [default allocation table](../agent-landing-zone/network-isolation.md#isolation-and-provisioning)
lists names, CIDRs and delegations.

## Virtual Machine

| Parameter | Default | Description |
|---|---|---|
| `vmAdminPassword` | Auto-generated | Admin password for the Jumpbox VM |
| `vmSize` | Root substitution defaults to `Standard_D2s_v3` | VM size for the jumpbox; set `AZURE_VM_SIZE` after checking regional capacity |

## Tags

| Parameter | Default | Description |
|---|---|---|
| `deploymentTags` | `{}` | Custom tags applied to all deployed resources |

## Complex objects

### Model deployments

The `modelDeploymentList` parameter defines which AI models to deploy in the Foundry account.

| Purpose | Model | Version | Default deployment type (`sku.name`) | Declared capacity | Empty-list foundation fallback capacity |
|---|---|---|---|---|---|
| embedding | text-embedding-3-large | 1 | GlobalStandard | 100 | 10 |

Both Bicep and Terraform use `GlobalStandard` for this embedding model. The
foundation fallback applies when `modelDeploymentList` is empty; it does not
replace the declared capacity of 100. Deployment names, API versions and vector
dimensions are unchanged.

[Azure's Global Standard availability table](https://learn.microsoft.com/azure/foundry/foundry-models/concepts/models-sold-directly-by-azure-region-availability#global-standard)
lists support for this model/version. Global deployment processing may occur
outside the resource region. If regional processing is required, explicitly set
the embedding entry's `sku.name` to `Standard` and verify regional model
availability and quota.

The example below uses custom capacity 40 for both models, not the declared
embedding default or the empty-list fallback.

```json
"modelDeploymentList": {
  "value": [
    {
      "name": "chat",
      "model": {
        "format": "OpenAI",
        "name": "gpt-5-nano",
        "version": "2025-08-07"
      },
      "sku": {
        "name": "GlobalStandard",
        "capacity": 40
      },
      "canonical_name": "CHAT_DEPLOYMENT_NAME",
      "apiVersion": "2025-12-01-preview"
    },
    {
      "name": "text-embedding",
      "model": {
        "format": "OpenAI",
        "name": "text-embedding-3-large",
        "version": "1"
      },
      "sku": {
        "name": "GlobalStandard",
        "capacity": 40
      },
      "canonical_name": "EMBEDDING_DEPLOYMENT_NAME",
      "apiVersion": "2025-12-01-preview"
    }
  ]
}
```

| Field | Description |
|---|---|
| `name` | Deployment name used in API calls |
| `model.format` | Model provider format (e.g., `OpenAI`) |
| `model.name` | Model identifier |
| `model.version` | Model version string |
| `sku.name` | SKU tier (`GlobalStandard`, `Standard`, etc.) |
| `sku.capacity` | Throughput capacity in thousands of tokens per minute |
| `canonical_name` | Environment variable name exported to App Configuration |
| `apiVersion` | Azure API version for the model deployment |

### Workload profiles

The `workloadProfiles` parameter defines the Container Apps Environment workload profiles.

```json
"workloadProfiles": {
  "value": [
    {
      "name": "Consumption",
      "workloadProfileType": "Consumption"
    },
    {
      "workloadProfileType": "D4",
      "name": "main",
      "minimumCount": 0,
      "maximumCount": 1
    }
  ]
}
```

| Field | Description |
|---|---|
| `name` | Profile name referenced by container apps |
| `workloadProfileType` | Profile type (`Consumption`, `D4`, `D8`, etc.) |
| `minimumCount` | Minimum number of instances (dedicated profiles only) |
| `maximumCount` | Maximum number of instances (dedicated profiles only) |

### Storage account containers

The `storageAccountContainersList` parameter defines blob containers to create in the solution storage account.

```json
"storageAccountContainersList": {
  "value": [
    {
      "name": "documents",
      "canonical_name": "DOCUMENTS_STORAGE_CONTAINER"
    }
  ]
}
```

### Database containers

The `databaseContainersList` parameter defines containers to create in the Cosmos DB database.

```json
"databaseContainersList": {
  "value": [
    {
      "name": "conversations",
      "canonical_name": "CONVERSATIONS_DATABASE_CONTAINER"
    }
  ]
}
```

### Container apps

The `containerAppsList` parameter defines the container apps to deploy and their RBAC roles.

```json
"containerAppsList": {
  "value": [
    {
      "name": null,
      "external": true,
      "target_port": 8080,
      "service_name": "orchestrator",
      "profile_name": "main",
      "min_replicas": 1,
      "max_replicas": 1,
      "canonical_name": "ORCHESTRATOR_APP",
      "dapr": {
        "enabled": true,
        "appId": "orchestrator",
        "appPort": 8080
      },
      "roles": [
        "AppConfigurationDataReader",
        "CognitiveServicesUser",
        "CognitiveServicesOpenAIUser",
        "AcrPull",
        "CosmosDBBuiltInDataContributor",
        "SearchIndexDataReader",
        "StorageBlobDataReader",
        "KeyVaultSecretsUser"
      ]
    }
  ]
}
```

| Field | Default | Description |
|---|---|---|
| `name` | Auto-generated from `service_name` when `null` or empty | Container App resource name |
| `external` | Required | Whether the app is externally accessible |
| `target_port` | `8080` | Port the container listens on |
| `service_name` | Required | Logical service name |
| `profile_name` | Required | Workload profile to use (must match a `workloadProfiles` entry) |
| `min_replicas` / `max_replicas` | Required | Replica scaling bounds |
| `canonical_name` | Required | Environment variable name exported to App Configuration |
| `dapr.enabled` | `false` | Enables Dapr for apps that need service invocation or other Dapr features |
| `dapr.appId` | `service_name` | Dapr app ID used for service invocation when Dapr is enabled |
| `dapr.appPort` | `target_port`, then `8080` | Dapr app port when Dapr is enabled |
| `dapr.appProtocol` | `http` | Dapr app protocol when Dapr is enabled |
| `dapr.enableApiLogging` | `false` | Enables Dapr API logging when Dapr is enabled |
| `roles` | Required | List of RBAC roles assigned to the container app's managed identity |

See [Permissions](permissions.md) for the default Agent layout's frontend and
hosted-runtime grants. Custom Container App role lists and other deployment
selections produce different assignments.
