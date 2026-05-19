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
| `deploymentMode` | `standalone` | `DEPLOYMENT_MODE` | Topology preset (**v2+**): `standalone` (self-contained spoke) or `ailz-integrated` (peer to an existing hub VNet, reuse hub services) |
| `networkIsolation` | `false` | `NETWORK_ISOLATION` | Enable Zero Trust network isolation (private endpoints, VNet) |
| `allowedIpRanges` | `[]` | `ALLOWED_IP_RANGES` | IPv4 / CIDR allow-list (**v2+**) applied to Storage, Key Vault, Cosmos DB, AI Search, ACR, AI Foundry, and Container Registry data planes when `networkIsolation=true` |
| `useZoneRedundancy` | `false` | — | Enable zone redundancy for supported services |
| `useCMK` | `false` | — | Enable customer-managed keys for encryption |
| `greenFieldDeployment` | `true` | — | Green-field deployment (creates all resources from scratch) |

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
| `deployJumpbox` | `null` (inherits from preset) | Jumpbox VM (**v2+** — replaces the v1.x `deployVM` flag) |
| `deployBastion` | `null` (inherits from preset) | Azure Bastion host (**v2+** — independent of jumpbox) |
| `deployNatGateway` | `null` (inherits from preset) | NAT Gateway for outbound traffic (**v2+** — independent of jumpbox) |
| `deploySoftware` | `true` | Pre-install development tools on the Jumpbox VM |

!!! note "Changed in v2"
    The v1.x umbrella flag `deployVM` is **removed**. Use the three independent flags `deployJumpbox` / `deployBastion` / `deployNatGateway` instead. See the [Migration to v2](migration-v2.md) guide.

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

## Existing resource IDs

Use these parameters to reuse existing resources instead of creating new ones.

| Parameter | Default | Description |
|---|---|---|
| `aiSearchResourceId` | `null` | Resource ID of an existing AI Search service |
| `aiFoundryStorageAccountResourceId` | `null` | Resource ID of an existing Storage account for AI Foundry |
| `aiFoundryCosmosDBAccountResourceId` | `null` | Resource ID of an existing Cosmos DB account for AI Foundry |

### v2 — Bring-your-own platform services

These parameters were added in v2 to support the [hub-and-spoke topology](hub-and-spoke.md). Set any value to a resource ID to **reuse** that platform resource (cross-RG and cross-subscription supported); leave empty to let the template create it.

| Parameter | Env variable | Description |
|---|---|---|
| `existingPlatformServices.logAnalyticsWorkspaceResourceId` | `EXISTING_LOG_ANALYTICS_WORKSPACE_ID` | Reuse a Log Analytics workspace from the hub for diagnostics + App Insights linkage |
| `existingPlatformServices.applicationInsightsResourceId` | `EXISTING_APPLICATION_INSIGHTS_ID` | Reuse an existing Application Insights instance |
| `existingPlatformServices.keyVaultResourceId` | `EXISTING_KEY_VAULT_ID` | Reuse a hub-managed Key Vault for shared secrets |
| `existingBastionResourceId` | `EXISTING_BASTION_RESOURCE_ID` | Hub Bastion host that already has line-of-sight to the spoke jumpbox via peering |
| `existingNatGatewayResourceId` | `EXISTING_NAT_GATEWAY_RESOURCE_ID` | Hub-owned NAT Gateway to associate with spoke subnets |
| `existingJumpboxResourceId` | `EXISTING_JUMPBOX_RESOURCE_ID` | Reference to a hub-managed jumpbox VM (informational; used by docs and post-provisioning scripts) |
| `existingPrivateDnsZones.*` | per-zone | 15 per-namespace overrides (blob, file, queue, table, vault, search, openai, cosmos-documents, redis, container apps, ACR, AMPLS, etc.). See the [source migration guide](https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/main/docs/v2-migration.md#3-4-private-dns-zones) for the complete list and behavior |

## Hub integration (v2)

For `deploymentMode=ailz-integrated` or hybrid hub-and-spoke deployments.

| Parameter | Env variable | Description |
|---|---|---|
| `hubIntegration.hubVnetResourceId` | `HUB_VNET_RESOURCE_ID` | Resource ID of the hub VNet to peer with. When set, the template creates a spoke→hub peering automatically. |
| `hubIntegration.createHubPeering` | `CREATE_HUB_PEERING` | Whether the template should create the spoke→hub peering (default `true` when `hubVnetResourceId` is set) |
| `hubIntegration.egressNextHopIp` | `EGRESS_NEXT_HOP_IP` | Private IP of the hub Azure Firewall / NVA. When set, the spoke UDR for `0.0.0.0/0` points here instead of a local firewall. |
| `hubIntegration.existingRouteTableResourceId` | `EXISTING_ROUTE_TABLE_RESOURCE_ID` | BYO route table for the spoke workload subnets. Bypasses the auto-generated UDR. |
| `hubIntegration.peeringAllowGatewayTransit` | — | Allow gateway transit on the spoke side of the peering |
| `hubIntegration.peeringUseRemoteGateways` | — | Use remote gateways from the hub |

## DNS zone link suffix (v2)

| Parameter | Default | Env variable | Description |
|---|---|---|---|
| `dnsZoneLinkSuffix` | `''` | `DNS_ZONE_LINK_SUFFIX` | Suffix appended to VNet-link names when reusing shared Private DNS zones across multiple spokes, so links don't collide on name |
| `linkExistingPrivateDnsZonesToSpoke` | `true` | — | When reusing BYO DNS zones, also create a link from each zone to the spoke VNet (needed when peering doesn't propagate DNS) |

## Networking

| Parameter | Default | Env variable | Description |
|---|---|---|---|
| `useExistingVNet` | `false` | `USE_EXISTING_VNET` | Use an existing VNet instead of creating a new one |
| `deploySubnets` | — | `DEPLOY_SUBNETS` | Create subnets in the existing VNet |
| `sideBySideDeploy` | — | `SIDE_BY_SIDE` | Enable side-by-side deployment in the same VNet |
| `existingVnetResourceId` | — | `EXISTING_VNET_RESOURCE_ID` | Resource ID of the existing VNet to use |

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

| Field | Description |
|---|---|
| `name` | Container App name (auto-generated from `service_name` if `null`) |
| `external` | Whether the app is externally accessible |
| `target_port` | Port the container listens on |
| `service_name` | Logical service name |
| `profile_name` | Workload profile to use (must match a `workloadProfiles` entry) |
| `min_replicas` / `max_replicas` | Replica scaling bounds |
| `canonical_name` | Environment variable name exported to App Configuration |
| `roles` | List of RBAC roles assigned to the container app's managed identity |

See [Permissions](permissions.md) for the resulting role assignments with the default configuration.
