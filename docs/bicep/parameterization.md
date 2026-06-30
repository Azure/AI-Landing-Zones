# Parameterization

All parameters are defined in `main.parameters.json`. You can customize values by editing the file directly or by using `azd env set` for parameters that support environment variable substitution (indicated by `${VARIABLE_NAME}` syntax in the default value).

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
| `deploymentMode` | `standalone` | `DEPLOYMENT_MODE` | Topology preset: `standalone` (self-contained spoke) or `ailz-integrated` (peer to an existing hub VNet, reuse hub services) |
| `networkIsolation` | `false` | `NETWORK_ISOLATION` | Enable Zero Trust network isolation (private endpoints, VNet) |
| `allowedIpRanges` | `[]` | `ALLOWED_IP_RANGES` | IPv4 / CIDR allow-list applied to Storage, Key Vault, Cosmos DB, AI Search, ACR, AI Foundry, and Container Registry data planes when `networkIsolation=true` |
| `useZoneRedundancy` | `false` | — | Enable zone redundancy for supported services |
| `useCMK` | `false` | — | Enable customer-managed keys for encryption |
| `greenFieldDeployment` | `true` | — | Green-field deployment (creates all resources from scratch) |
| `publicIngress` | `{ enabled: false }` | — | Optional Application Gateway WAF v2 public endpoint for a private Container App. See [Public Ingress with Application Gateway](public-ingress.md). |

## Deploy toggles

Each toggle controls whether a specific service is provisioned. Set to `true` to deploy or `false` to skip.

| Parameter | Default | Description |
|---|---|---|
| `deployAiFoundry` | `true` | AI Foundry account and project |
| `deployAiFoundrySubnet` | `true` | Dedicated subnet for AI Foundry agents |
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

## Resource name overrides

By default, resource names are auto-generated from the `environmentName` prefix. Use these parameters to override specific resource names.

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

Use these to compose hub-and-spoke and Application Landing Zone (ALZ) topologies where the platform team owns shared services (Key Vault, Log Analytics, Application Insights, Private DNS zones, hub Bastion / NAT / firewall, etc.) and the spoke just consumes them.

### Workload data services

| Parameter | Env variable | Description |
|---|---|---|
| `aiSearchResourceId` | `AI_SEARCH_RESOURCE_ID` | Reuse an existing Azure AI Search service instead of creating one in the spoke. |
| `aiFoundryStorageAccountResourceId` | `AI_FOUNDRY_STORAGE_ACCOUNT_RESOURCE_ID` | Reuse an existing Storage account as the AI Foundry storage backing. |
| `aiFoundryCosmosDBAccountResourceId` | `AI_FOUNDRY_COSMOS_DB_ACCOUNT_RESOURCE_ID` | Reuse an existing Cosmos DB account as the AI Foundry Cosmos backing. |
| `keyVaultResourceId` | `KEY_VAULT_RESOURCE_ID` | Reuse an existing Key Vault for the workload (skips local vault creation). |

### Observability

| Parameter | Env variable | Description |
|---|---|---|
| `existingLogAnalyticsWorkspaceResourceId` | `EXISTING_LOG_ANALYTICS_WORKSPACE_RESOURCE_ID` | Reuse a central Log Analytics workspace. All diagnostic settings, AMPLS linkage, and the App Configuration entries point at this workspace. |
| `existingApplicationInsightsResourceId` | `EXISTING_APPLICATION_INSIGHTS_RESOURCE_ID` | Reuse an existing Application Insights component. Pair with `existingApplicationInsightsConnectionString` so downstream consumers (Container Apps Environment, App Configuration) receive a working connection string without needing access to the AppInsights resource. |
| `existingApplicationInsightsConnectionString` | `EXISTING_APPLICATION_INSIGHTS_CONNECTION_STRING` | Connection string for the reused AppInsights component (`az monitor app-insights component show -g <rg> -a <name> --query connectionString -o tsv`). Marked `@secure()`. |

### Networking

| Parameter | Env variable | Description |
|---|---|---|
| `existingVnetResourceId` | `EXISTING_VNET_RESOURCE_ID` | Existing VNet to deploy the workload subnets into. Used together with `useExistingVNet=true`. |
| `hubIntegrationHubVnetResourceId` | `HUB_INTEGRATION_HUB_VNET_RESOURCE_ID` | Resource ID of the hub VNet to peer with. When set and `hubIntegrationCreateHubPeering=true`, the deployment creates the spoke→hub peering automatically (the reverse hub→spoke direction is the operator's responsibility — see `tests/scripts/Add-HubSpokePeering.ps1`). |
| `hubIntegrationExistingRouteTableResourceId` | `HUB_INTEGRATION_EXISTING_ROUTE_TABLE_RESOURCE_ID` | Existing Route Table to attach to the spoke workload subnets. When set, the deployment skips local RT creation and assumes the RT is already configured with the correct default route. |

### Hub jumpbox / Bastion / NAT

When any of these is set, the matching `deploy*` flag defaults to `false`, so the spoke reuses the hub-managed component instead of deploying its own.

| Parameter | Env variable | Description |
|---|---|---|
| `existingBastionResourceId` | `EXISTING_BASTION_RESOURCE_ID` | Hub-managed Bastion host that has line-of-sight to the spoke jumpbox via peering. |
| `existingNatGatewayResourceId` | `EXISTING_NAT_GATEWAY_RESOURCE_ID` | Hub-managed NAT Gateway to associate with the spoke subnets for outbound egress. |
| `existingJumpboxResourceId` | `EXISTING_JUMPBOX_RESOURCE_ID` | Reference to a hub-managed jumpbox VM. Informational — surfaced to runbooks and post-provision scripts. |

### Private DNS zones

All 15 zones used by the landing zone can be brought from a central platform subscription independently. When any of these is set, the local zone is **not** created. Pre-link the zone to the spoke VNet (or rely on hub→spoke peering + hub-side link) — automatic spoke linking is not performed. When `policyManagedPrivateDns=true`, no zone creation or linking happens regardless of these overrides.

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

For `deploymentMode=ailz-integrated` or hybrid hub-and-spoke deployments. See the [Hub-and-Spoke topology](hub-and-spoke.md) runbook for the full picture.

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
| `deploySubnets` | `true` | `DEPLOY_SUBNETS` | Create the workload subnets (PE, jumpbox, agent, ACA, NAT, Bastion). Set to `false` to BYO subnets in an existing VNet. |
| `sideBySideDeploy` | `false` | `SIDE_BY_SIDE` | Allow a second AI LZ to be deployed side-by-side in the same existing VNet without disturbing the first one's subnets / NSGs. |

## Virtual Machine

| Parameter | Default | Description |
|---|---|---|
| `vmAdminPassword` | Auto-generated | Admin password for the Jumpbox VM |
| `vmSize` | `Standard_D8s_v5` | VM size for the Jumpbox |

## Tags

| Parameter | Default | Description |
|---|---|---|
| `deploymentTags` | `{}` | Custom tags applied to all deployed resources |

## Complex objects

### Model deployments

The `modelDeploymentList` parameter defines which AI models to deploy in the Foundry account.

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
        "name": "Standard",
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

See [Permissions](permissions.md) for the resulting role assignments with the default configuration.
