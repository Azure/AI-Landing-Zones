# AI Landing Zone

### Parameters Documentation

This page provides detailed information about all the parameters available in the AI Landing Zone Bicep template. Parameters are configuration values that you can customize to adapt the deployment to your specific requirements and environment.

The parameters are organized into three categories:
- **Required Parameters**: Must be provided for the template to deploy successfully
- **Conditional Parameters**: Required only when certain features or components are enabled
- **Optional Parameters**: Have default values but can be customized as needed

Each parameter includes information about its type, requirements, default values (where applicable), and detailed descriptions of its purpose and usage.

## Table of Contents

- [AVM Modules](#avm-modules)
- [Resource Types](#resource-types)
- [Parameters](#parameters)
  - [Required Parameters](#required-parameters)
    - [deployToggles](#deploytoggles)
  - [Conditional Parameters](#conditional-parameters)
    - [appConfigurationDefinition](#appconfigurationdefinition)
    - [appGatewayDefinition](#appgatewaydefinition)
    - [appGatewayPublicIp](#appgatewaypublicip)
    - [appInsightsDefinition](#appinsightsdefinition)
    - [buildVmDefinition](#buildvmdefinition)
    - [containerAppEnvDefinition](#containerappenvdefinition)
    - [containerRegistryDefinition](#containerregistrydefinition)
    - [firewallDefinition](#firewalldefinition)
    - [firewallPolicyDefinition](#firewallpolicydefinition)
    - [firewallPublicIp](#firewallpublicip)
    - [groundingWithBingDefinition](#groundingwithbingdefinition)
    - [jumpVmDefinition](#jumpvmdefinition)
    - [logAnalyticsDefinition](#loganalyticsdefinition)
    - [storageAccountDefinition](#storageaccountdefinition)
    - [vNetDefinition](#vnetdefinition)
    - [wafPolicyDefinition](#wafpolicydefinition)
  - [Optional Parameters](#optional-parameters)
    - [acrPrivateDnsZoneDefinition](#acrprivatednszonedefinition)
    - [acrPrivateEndpointDefinition](#acrprivateendpointdefinition)
    - [aiFoundryDefinition](#aifoundrydefinition)
    - [aiSearchDefinition](#aisearchdefinition)
    - [aiServicesPrivateDnsZoneDefinition](#aiservicesprivatednszonedefinition)
    - [apimDefinition](#apimdefinition)
    - [apimPrivateDnsZoneDefinition](#apimprivatednszonedefinition)
    - [apimPrivateEndpointDefinition](#apimprivateendpointdefinition)
    - [appConfigPrivateDnsZoneDefinition](#appconfigprivatednszonedefinition)
    - [appConfigPrivateEndpointDefinition](#appconfigprivateendpointdefinition)
    - [appInsightsPrivateDnsZoneDefinition](#appinsightsprivatednszonedefinition)
    - [baseName](#basename)
    - [blobPrivateDnsZoneDefinition](#blobprivatednszonedefinition)
    - [buildVmMaintenanceDefinition](#buildvmmaintenancedefinition)
    - [cognitiveServicesPrivateDnsZoneDefinition](#cognitiveservicesprivatednszonedefinition)
    - [containerAppEnvPrivateEndpointDefinition](#containerappenvprivateendpointdefinition)
    - [containerAppsList](#containerappslist)
    - [containerAppsPrivateDnsZoneDefinition](#containerappsprivatednszonedefinition)
    - [cosmosDbDefinition](#cosmosdbdefinition)
    - [cosmosPrivateDnsZoneDefinition](#cosmosprivatednszonedefinition)
    - [cosmosPrivateEndpointDefinition](#cosmosprivateendpointdefinition)
    - [enableTelemetry](#enabletelemetry)
    - [existingVNetSubnetsDefinition](#existingvnetsubnetsdefinition)
    - [flagPlatformLandingZone](#flagplatformlandingzone)
    - [hubVnetPeeringDefinition](#hubvnetpeeringdefinition)
    - [jumpVmMaintenanceDefinition](#jumpvmmaintenancedefinition)
    - [keyVaultDefinition](#keyvaultdefinition)
    - [keyVaultPrivateDnsZoneDefinition](#keyvaultprivatednszonedefinition)
    - [keyVaultPrivateEndpointDefinition](#keyvaultprivateendpointdefinition)
    - [location](#location)
    - [nsgDefinitions](#nsgdefinitions)
    - [openAiPrivateDnsZoneDefinition](#openaiprivatednszonedefinition)
    - [privateDnsZonesDefinition](#privatednszonesdefinition)
    - [resourceIds](#resourceids)
    - [resourceToken](#resourcetoken)
    - [searchPrivateDnsZoneDefinition](#searchprivatednszonedefinition)
    - [searchPrivateEndpointDefinition](#searchprivateendpointdefinition)
    - [storageBlobPrivateEndpointDefinition](#storageblobprivateendpointdefinition)
    - [tags](#tags)
- [Outputs](#outputs)

## AVM Modules

| Module | Version |
| :-- | :-- |
| `avm/ptn/ai-ml/ai-foundry` | 0.4.0 |
| `avm/res/api-management/service` | 0.11.1 |
| `avm/res/app-configuration/configuration-store` | 0.9.2 |
| `avm/res/app/container-app` | 0.18.1 |
| `avm/res/app/managed-environment` | 0.11.3 |
| `avm/res/compute/virtual-machine` | 0.20.0 |
| `avm/res/container-registry/registry` | 0.9.3 |
| `avm/res/document-db/database-account` | 0.16.0 |
| `avm/res/insights/component` | 0.6.0 |
| `avm/res/key-vault/vault` | 0.13.3 |
| `avm/res/maintenance/maintenance-configuration` | 0.3.1 |
| `avm/res/network/application-gateway` | 0.7.2 |
| `avm/res/network/azure-firewall` | 0.8.0 |
| `avm/res/network/firewall-policy` | 0.3.1 |
| `avm/res/network/network-security-group` | 0.5.1 |
| `avm/res/network/private-dns-zone` | 0.8.0 |
| `avm/res/network/private-endpoint` | 0.11.0 |
| `avm/res/network/public-ip-address` | 0.9.0 |
| `avm/res/network/virtual-network` | 0.7.0 |
| `avm/res/operational-insights/workspace` | 0.12.0 |
| `avm/res/search/search-service` | 0.11.1 |
| `avm/res/storage/storage-account` | 0.27.0 |

## Resource Types

| Resource Type | API Version |
| :-- | :-- |
| `Microsoft.ApiManagement/service` | 2024-05-01 |
| `Microsoft.App/containerApps` | 2025-01-01 |
| `Microsoft.App/managedEnvironments` | 2024-10-02-preview |
| `Microsoft.App/managedEnvironments/storages` | 2024-10-02-preview |
| `Microsoft.AppConfiguration/configurationStores` | 2024-06-01 |
| `Microsoft.Authorization/locks` | 2020-05-01 |
| `Microsoft.Authorization/roleAssignments` | 2022-04-01 |
| `Microsoft.Automanage/configurationProfileAssignments` | 2022-05-04 |
| `Microsoft.Bing/accounts` | 2025-05-01-preview |
| `Microsoft.CognitiveServices/accounts/connections` | 2025-06-01 |
| `Microsoft.Compute/disks` | 2024-03-02 |
| `Microsoft.Compute/virtualMachines` | 2024-07-01 |
| `Microsoft.ContainerRegistry/registries` | 2023-06-01-preview |
| `Microsoft.DevTestLab/schedules` | 2018-09-15 |
| `Microsoft.DocumentDB/databaseAccounts` | 2024-11-15 |
| `Microsoft.GuestConfiguration/guestConfigurationAssignments` | 2024-04-05 |
| `Microsoft.Insights/components` | 2020-02-02 |
| `Microsoft.Insights/dataCollectionRuleAssociations` | 2023-03-11 |
| `Microsoft.Insights/diagnosticSettings` | 2021-05-01-preview |
| `Microsoft.KeyVault/vaults` | 2024-11-01 |
| `Microsoft.KeyVault/vaults/keys` | 2024-11-01 |
| `Microsoft.Maintenance/configurationAssignments` | 2023-04-01 |
| `Microsoft.Maintenance/maintenanceConfigurations` | 2023-04-01 |
| `Microsoft.ManagedIdentity/userAssignedIdentities` | 2024-11-30 |
| `Microsoft.Network/applicationGateways` | 2024-07-01 |
| `Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies` | 2024-01-01 |
| `Microsoft.Network/azureFirewalls` | 2024-05-01 |
| `Microsoft.Network/firewallPolicies` | 2024-05-01 |
| `Microsoft.Network/networkSecurityGroups` | 2023-11-01 |
| `Microsoft.Network/privateDnsZones` | 2020-06-01 |
| `Microsoft.Network/privateEndpoints` | 2024-05-01 |
| `Microsoft.Network/publicIPAddresses` | 2024-05-01 |
| `Microsoft.Network/virtualNetworks` | 2024-05-01 |
| `Microsoft.Network/virtualNetworks/subnets` | 2023-11-01 |
| `Microsoft.Network/virtualNetworks/virtualNetworkPeerings` | 2024-03-01 |
| `Microsoft.OperationalInsights/workspaces` | 2025-02-01 |
| `Microsoft.Resources/deployments` | 2022-09-01 |
| `Microsoft.Search/searchServices` | 2025-02-01-preview |
| `Microsoft.Security/pricings` | 2024-01-01 |
| `Microsoft.SecurityInsights/onboardingStates` | 2024-03-01 |
| `Microsoft.Storage/storageAccounts` | 2024-01-01 |

## Parameters

### Required Parameters

### `deployToggles`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `deployToggles` | `object` | Required | Per-service deployment toggles. |

**Properties:**

- **`acaEnvironmentNsg`** (`bool`) - Required
  - **Description:** Toggle to deploy NSG for Azure Container Apps environment subnet (true) or not (false).

- **`agentNsg`** (`bool`) - Required
  - **Description:** Toggle to deploy NSG for agent (workload) subnet (true) or not (false).

- **`aiFoundry`** (`bool`) - Required
  - **Description:** Toggle to deploy AI Foundry (true) or not (false).

- **`apiManagement`** (`bool`) - Required
  - **Description:** Toggle to deploy API Management (true) or not (false).

- **`apiManagementNsg`** (`bool`) - Required
  - **Description:** Toggle to deploy NSG for API Management subnet (true) or not (false).

- **`appConfig`** (`bool`) - Required
  - **Description:** Toggle to deploy App Configuration (true) or not (false).

- **`appInsights`** (`bool`) - Required
  - **Description:** Toggle to deploy Application Insights (true) or not (false).

- **`applicationGateway`** (`bool`) - Required
  - **Description:** Toggle to deploy Application Gateway (true) or not (false).

- **`applicationGatewayNsg`** (`bool`) - Required
  - **Description:** Toggle to deploy NSG for Application Gateway subnet (true) or not (false).

- **`applicationGatewayPublicIp`** (`bool`) - Required
  - **Description:** Toggle to deploy a Public IP address for the Application Gateway (true) or not (false).

- **`bastionHost`** (`bool`) - Required
  - **Description:** Toggle to deploy an Azure Bastion host (true) or not (false).

- **`bastionNsg`** (`bool`) - Required
  - **Description:** Toggle to deploy NSG for Bastion host subnet (true) or not (false).

- **`buildVm`** (`bool`) - Required
  - **Description:** Toggle to deploy Build VM (true) or not (false).

- **`containerApps`** (`bool`) - Required
  - **Description:** Toggle to deploy Container Apps (true) or not (false).

- **`containerEnv`** (`bool`) - Required
  - **Description:** Toggle to deploy Container Apps Environment (true) or not (false).

- **`containerRegistry`** (`bool`) - Required
  - **Description:** Toggle to deploy Azure Container Registry (true) or not (false).

- **`cosmosDb`** (`bool`) - Required
  - **Description:** Toggle to deploy Cosmos DB (true) or not (false).

- **`devopsBuildAgentsNsg`** (`bool`) - Required
  - **Description:** Toggle to deploy NSG for DevOps build agents subnet (true) or not (false).

- **`firewall`** (`bool`) - Required
  - **Description:** Toggle to deploy Azure Firewall (true) or not (false).

- **`groundingWithBingSearch`** (`bool`) - Required
  - **Description:** Toggle to deploy Bing Grounding with Search (true) or not (false).

- **`jumpboxNsg`** (`bool`) - Required
  - **Description:** Toggle to deploy NSG for jumpbox (bastion-accessed) subnet (true) or not (false).

- **`jumpVm`** (`bool`) - Required
  - **Description:** Toggle to deploy Jump VM (true) or not (false).

- **`keyVault`** (`bool`) - Required
  - **Description:** Toggle to deploy Key Vault (true) or not (false).

- **`logAnalytics`** (`bool`) - Required
  - **Description:** Toggle to deploy Log Analytics (true) or not (false).

- **`peNsg`** (`bool`) - Required
  - **Description:** Toggle to deploy NSG for private endpoints (PE) subnet (true) or not (false).

- **`searchService`** (`bool`) - Required
  - **Description:** Toggle to deploy Azure AI Search (true) or not (false).

- **`storageAccount`** (`bool`) - Required
  - **Description:** Toggle to deploy Storage Account (true) or not (false).

- **`virtualNetwork`** (`bool`) - Required
  - **Description:** Toggle to deploy a new Virtual Network (true) or not (false).

- **`wafPolicy`** (`bool`) - Required
  - **Description:** Toggle to deploy an Application Gateway WAF policy (true) or not (false).

### Conditional Parameters

### `appConfigurationDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `appConfigurationDefinition` | `object` | Conditional | App Configuration store settings. Required if deploy.appConfig is true and resourceIds.appConfigResourceId is empty. |

**Properties:**

- **`createMode`** (`string`) - Optional
  - **Description:** Indicates whether the configuration store needs to be recovered.

- **`customerManagedKey`** (`object`) - Optional
  - **Description:** Customer Managed Key definition.
  - **`autoRotationEnabled`** (`bool`) - Optional
    - **Description:** Enable or disable auto-rotation (default true).

  - **`keyName`** (`string`) - Required
    - **Description:** Key name used for encryption.

  - **`keyVaultResourceId`** (`string`) - Required
    - **Description:** Resource ID of the Key Vault containing the key.

  - **`keyVersion`** (`string`) - Optional
    - **Description:** Specific key version to use.

  - **`userAssignedIdentityResourceId`** (`string`) - Optional
    - **Description:** User-assigned identity resource ID if system identity is not available.


- **`dataPlaneProxy`** (`object`) - Optional
  - **Description:** Data plane proxy configuration for ARM.
  - **`authenticationMode`** (`string`) - Optional
    - **Description:** Authentication mode for data plane proxy.

  - **`privateLinkDelegation`** (`string`) - Required
    - **Description:** Whether private link delegation is enabled.


- **`diagnosticSettings`** (`array`) - Optional
  - **Description:** Diagnostic settings for the service.
  - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional
    - **Description:** Resource ID of the diagnostic event hub authorization rule.

  - **`eventHubName`** (`string`) - Optional
    - **Description:** Name of the diagnostic Event Hub.

  - **`logAnalyticsDestinationType`** (`string`) - Optional
    - **Description:** Destination type for Log Analytics. Allowed values: AzureDiagnostics, Dedicated.

  - **`logCategoriesAndGroups`** (`array`) - Optional
    - **Description:** Log categories and groups to stream.
    - **`category`** (`string`) - Optional
      - **Description:** Name of a diagnostic log category.

    - **`categoryGroup`** (`string`) - Optional
      - **Description:** Name of a diagnostic log category group.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Enable or disable the category. Default true.


  - **`logCategoriesAndGroups[*]`** (`object`) - Optional
    - **Description:** Array item for appConfigurationDefinition.diagnosticSettings[*].logCategoriesAndGroups

  - **`marketplacePartnerResourceId`** (`string`) - Optional
    - **Description:** Marketplace partner resource ID.

  - **`metricCategories`** (`array`) - Optional
    - **Description:** Metric categories to stream.
    - **`category`** (`string`) - Required
      - **Description:** Diagnostic metric category name.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Enable or disable the metric category. Default true.


  - **`metricCategories[*]`** (`object`) - Optional
    - **Description:** Array item for appConfigurationDefinition.diagnosticSettings[*].metricCategories

  - **`name`** (`string`) - Optional
    - **Description:** Diagnostic setting name.

  - **`storageAccountResourceId`** (`string`) - Optional
    - **Description:** Storage account resource ID for diagnostic logs.

  - **`workspaceResourceId`** (`string`) - Optional
    - **Description:** Log Analytics workspace resource ID for diagnostic logs.


- **`diagnosticSettings[*]`** (`object`) - Optional
  - **Description:** Array item for appConfigurationDefinition.diagnosticSettings
  - **`category`** (`string`) - Optional
    - **Description:** Name of a diagnostic log category.

  - **`categoryGroup`** (`string`) - Optional
    - **Description:** Name of a diagnostic log category group.

  - **`enabled`** (`bool`) - Optional
    - **Description:** Enable or disable the category. Default true.

  - **`category`** (`string`) - Required
    - **Description:** Diagnostic metric category name.

  - **`enabled`** (`bool`) - Optional
    - **Description:** Enable or disable the metric category. Default true.


- **`disableLocalAuth`** (`bool`) - Optional
  - **Description:** Disable all non-AAD authentication methods.

- **`enablePurgeProtection`** (`bool`) - Optional
  - **Description:** Enable purge protection (default true, except Free SKU).

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable or disable usage telemetry for module.

- **`keyValues`** (`array`) - Optional
  - **Description:** List of key/values to create (requires local auth).

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource (default resourceGroup().location).

- **`lock`** (`object`) - Optional
  - **Description:** Lock settings.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`managedIdentities`** (`object`) - Optional
  - **Description:** Managed identity configuration.
  - **`systemAssigned`** (`bool`) - Optional
    - **Description:** Enable system-assigned managed identity.

  - **`userAssignedResourceIds`** (`array`) - Optional
    - **Description:** User-assigned identity resource IDs.


- **`name`** (`string`) - Required
  - **Description:** Name of the Azure App Configuration.

- **`privateEndpoints`** (`array`) - Optional
  - **Description:** Private endpoint configuration.
  - **`applicationSecurityGroupResourceIds`** (`array`) - Optional
    - **Description:** Application Security Group resource IDs.

  - **`customDnsConfigs`** (`array`) - Optional
    - **Description:** Custom DNS configs.
    - **`fqdn`** (`string`) - Optional
      - **Description:** FQDN that maps to the private IPs.

    - **`ipAddresses`** (`array`) - Required
      - **Description:** Private IP addresses for the endpoint.


  - **`customDnsConfigs[*]`** (`object`) - Optional
    - **Description:** Array item for appConfigurationDefinition.privateEndpoints[*].customDnsConfigs

  - **`customNetworkInterfaceName`** (`string`) - Optional
    - **Description:** Custom network interface name.

  - **`enableTelemetry`** (`bool`) - Optional
    - **Description:** Enable or disable usage telemetry for the module.

  - **`ipConfigurations`** (`array`) - Optional
    - **Description:** Explicit IP configurations for the Private Endpoint.
    - **`name`** (`string`) - Required
      - **Description:** Name of this IP configuration.

    - **`properties`** (`object`) - Required
      - **Description:** Object defining groupId, memberName, and privateIPAddress for the private endpoint IP configuration.
      - **`groupId`** (`string`) - Required
        - **Description:** Group ID from the remote resource.

      - **`memberName`** (`string`) - Required
        - **Description:** Member name from the remote resource.

      - **`privateIPAddress`** (`string`) - Required
        - **Description:** Private IP address from the PE subnet.



  - **`ipConfigurations[*]`** (`object`) - Optional
    - **Description:** Array item for appConfigurationDefinition.privateEndpoints[*].ipConfigurations
    - **`groupId`** (`string`) - Required
      - **Description:** Group ID from the remote resource.

    - **`memberName`** (`string`) - Required
      - **Description:** Member name from the remote resource.

    - **`privateIPAddress`** (`string`) - Required
      - **Description:** Private IP address from the PE subnet.


  - **`isManualConnection`** (`bool`) - Optional
    - **Description:** Use manual Private Link approval flow.

  - **`location`** (`string`) - Optional
    - **Description:** Location to deploy the Private Endpoint to.

  - **`lock`** (`object`) - Optional
    - **Description:** Lock settings for the Private Endpoint.
    - **`kind`** (`string`) - Optional
      - **Description:** Lock type.

    - **`name`** (`string`) - Optional
      - **Description:** Lock name.

    - **`notes`** (`string`) - Optional
      - **Description:** Lock notes.


  - **`manualConnectionRequestMessage`** (`string`) - Optional
    - **Description:** Manual connection request message.

  - **`name`** (`string`) - Optional
    - **Description:** Name of the Private Endpoint resource.

  - **`privateDnsZoneGroup`** (`object`) - Optional
    - **Description:** Private DNS Zone group configuration.
    - **`name`** (`string`) - Optional
      - **Description:** Name of the Private DNS Zone group.

    - **`privateDnsZoneGroupConfigs`** (`array`) - Required
      - **Description:** Configs for linking PDNS zones.
      - **`name`** (`string`) - Optional
        - **Description:** Name of this DNS zone config.

      - **`privateDnsZoneResourceId`** (`string`) - Required
        - **Description:** Private DNS Zone resource ID.


    - **`privateDnsZoneGroupConfigs[*]`** (`object`) - Optional
      - **Description:** Array item for appConfigurationDefinition.privateEndpoints[*].privateDnsZoneGroup.privateDnsZoneGroupConfigs


  - **`privateLinkServiceConnectionName`** (`string`) - Optional
    - **Description:** Private Link service connection name.

  - **`resourceGroupResourceId`** (`string`) - Optional
    - **Description:** Resource group resource ID to place the PE in.

  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Role assignments for the Private Endpoint.

  - **`service`** (`string`) - Optional
    - **Description:** Target service group ID (as string).

  - **`subnetResourceId`** (`string`) - Required
    - **Description:** Subnet resource ID for the private endpoint.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags to apply to the Private Endpoint.


- **`privateEndpoints[*]`** (`object`) - Optional
  - **Description:** Array item for appConfigurationDefinition.privateEndpoints
  - **`fqdn`** (`string`) - Optional
    - **Description:** FQDN that maps to the private IPs.

  - **`ipAddresses`** (`array`) - Required
    - **Description:** Private IP addresses for the endpoint.

  - **`name`** (`string`) - Required
    - **Description:** Name of this IP configuration.

  - **`properties`** (`object`) - Required
    - **Description:** Object defining groupId, memberName, and privateIPAddress for the private endpoint IP configuration.
    - **`groupId`** (`string`) - Required
      - **Description:** Group ID from the remote resource.

    - **`memberName`** (`string`) - Required
      - **Description:** Member name from the remote resource.

    - **`privateIPAddress`** (`string`) - Required
      - **Description:** Private IP address from the PE subnet.


  - **`groupId`** (`string`) - Required
    - **Description:** Group ID from the remote resource.

  - **`memberName`** (`string`) - Required
    - **Description:** Member name from the remote resource.

  - **`privateIPAddress`** (`string`) - Required
    - **Description:** Private IP address from the PE subnet.

  - **`groupId`** (`string`) - Required
    - **Description:** Group ID from the remote resource.

  - **`memberName`** (`string`) - Required
    - **Description:** Member name from the remote resource.

  - **`privateIPAddress`** (`string`) - Required
    - **Description:** Private IP address from the PE subnet.

  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.

  - **`name`** (`string`) - Optional
    - **Description:** Name of the Private DNS Zone group.

  - **`privateDnsZoneGroupConfigs`** (`array`) - Required
    - **Description:** Configs for linking PDNS zones.
    - **`name`** (`string`) - Optional
      - **Description:** Name of this DNS zone config.

    - **`privateDnsZoneResourceId`** (`string`) - Required
      - **Description:** Private DNS Zone resource ID.


  - **`privateDnsZoneGroupConfigs[*]`** (`object`) - Optional
    - **Description:** Array item for appConfigurationDefinition.privateEndpoints[*].privateDnsZoneGroup.privateDnsZoneGroupConfigs

  - **`name`** (`string`) - Optional
    - **Description:** Name of this DNS zone config.

  - **`privateDnsZoneResourceId`** (`string`) - Required
    - **Description:** Private DNS Zone resource ID.


- **`publicNetworkAccess`** (`string`) - Optional
  - **Description:** Whether public network access is allowed.

- **`replicaLocations`** (`array`) - Optional
  - **Description:** Replica locations.
  - **`name`** (`string`) - Optional
    - **Description:** Replica name.

  - **`replicaLocation`** (`string`) - Required
    - **Description:** Azure region name for the replica.


- **`replicaLocations[*]`** (`object`) - Optional
  - **Description:** Array item for appConfigurationDefinition.replicaLocations

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for App Configuration.

- **`sku`** (`string`) - Optional
  - **Description:** Pricing tier of App Configuration.

- **`softDeleteRetentionInDays`** (`int`) - Optional
  - **Description:** Retention period in days for soft delete (1–7). Default 1.

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the resource.

### `appGatewayDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `appGatewayDefinition` | `object` | Conditional | Application Gateway configuration. Required if deploy.applicationGateway is true and resourceIds.applicationGatewayResourceId is empty. |

**Properties:**

- **`authenticationCertificates`** (`array`) - Optional
  - **Description:** Authentication certificates of the Application Gateway.

- **`autoscaleMaxCapacity`** (`int`) - Optional
  - **Description:** Maximum autoscale capacity.

- **`autoscaleMinCapacity`** (`int`) - Optional
  - **Description:** Minimum autoscale capacity.

- **`availabilityZones`** (`array`) - Optional
  - **Description:** Availability zones used by the gateway.

- **`backendAddressPools`** (`array`) - Optional
  - **Description:** Backend address pools of the Application Gateway.

- **`backendHttpSettingsCollection`** (`array`) - Optional
  - **Description:** Backend HTTP settings.

- **`backendSettingsCollection`** (`array`) - Optional
  - **Description:** Backend settings collection (see limits).

- **`capacity`** (`int`) - Optional
  - **Description:** Static instance capacity. Default is 2.

- **`customErrorConfigurations`** (`array`) - Optional
  - **Description:** Custom error configurations.

- **`diagnosticSettings`** (`array`) - Optional
  - **Description:** Diagnostic settings for the Application Gateway.

- **`enableFips`** (`bool`) - Optional
  - **Description:** Whether FIPS is enabled.

- **`enableHttp2`** (`bool`) - Optional
  - **Description:** Whether HTTP/2 is enabled.

- **`enableRequestBuffering`** (`bool`) - Optional
  - **Description:** Enable request buffering.

- **`enableResponseBuffering`** (`bool`) - Optional
  - **Description:** Enable response buffering.

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable or disable telemetry (default true).

- **`firewallPolicyResourceId`** (`string`) - Conditional
  - **Description:** Resource ID of the associated firewall policy. Required if SKU is WAF_v2.

- **`frontendIPConfigurations`** (`array`) - Optional
  - **Description:** Frontend IP configurations.

- **`frontendPorts`** (`array`) - Optional
  - **Description:** Frontend ports.

- **`gatewayIPConfigurations`** (`array`) - Optional
  - **Description:** Gateway IP configurations (subnets).

- **`httpListeners`** (`array`) - Optional
  - **Description:** HTTP listeners.

- **`listeners`** (`array`) - Optional
  - **Description:** Listeners (see limits).

- **`loadDistributionPolicies`** (`array`) - Optional
  - **Description:** Load distribution policies.

- **`location`** (`string`) - Optional
  - **Description:** Location of the Application Gateway.

- **`lock`** (`object`) - Optional
  - **Description:** Lock settings.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`managedIdentities`** (`object`) - Optional
  - **Description:** Managed identities for the Application Gateway.
  - **`userAssignedResourceIds`** (`array`) - Optional
    - **Description:** User-assigned managed identity resource IDs.


- **`name`** (`string`) - Required
  - **Description:** Name of the Application Gateway.

- **`privateEndpoints`** (`array`) - Optional
  - **Description:** Private endpoints configuration.

- **`privateLinkConfigurations`** (`array`) - Optional
  - **Description:** Private link configurations.

- **`probes`** (`array`) - Optional
  - **Description:** Probes for backend health monitoring.

- **`redirectConfigurations`** (`array`) - Optional
  - **Description:** Redirect configurations.

- **`requestRoutingRules`** (`array`) - Optional
  - **Description:** Request routing rules.

- **`rewriteRuleSets`** (`array`) - Optional
  - **Description:** Rewrite rule sets.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Application Gateway.

- **`routingRules`** (`array`) - Optional
  - **Description:** Routing rules.

- **`sku`** (`string`) - Optional
  - **Description:** SKU of the Application Gateway. Default is WAF_v2.

- **`sslCertificates`** (`array`) - Optional
  - **Description:** SSL certificates.

- **`sslPolicyCipherSuites`** (`array`) - Optional
  - **Description:** SSL policy cipher suites.

- **`sslPolicyMinProtocolVersion`** (`string`) - Optional
  - **Description:** Minimum SSL protocol version.

- **`sslPolicyName`** (`string`) - Optional
  - **Description:** Predefined SSL policy name.

- **`sslPolicyType`** (`string`) - Optional
  - **Description:** SSL policy type.

- **`sslProfiles`** (`array`) - Optional
  - **Description:** SSL profiles.

- **`tags`** (`object`) - Optional
  - **Description:** Resource tags.

- **`trustedClientCertificates`** (`array`) - Optional
  - **Description:** Trusted client certificates.

- **`trustedRootCertificates`** (`array`) - Optional
  - **Description:** Trusted root certificates.

- **`urlPathMaps`** (`array`) - Optional
  - **Description:** URL path maps.

### `appGatewayPublicIp`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `appGatewayPublicIp` | `object` | Conditional | Conditional Public IP for Application Gateway. Requred when deploy applicationGatewayPublicIp is true and no existing ID is provided. |

**Properties:**

- **`ddosSettings`** (`object`) - Optional
  - **Description:** DDoS protection settings for the Public IP Address.
  - **`ddosProtectionPlan`** (`object`) - Optional
    - **Description:** Associated DDoS protection plan.
    - **`id`** (`string`) - Required
      - **Description:** Resource ID of the DDoS protection plan.


  - **`protectionMode`** (`string`) - Required
    - **Description:** DDoS protection mode. Allowed value: Enabled.


- **`diagnosticSettings`** (`array`) - Optional
  - **Description:** Diagnostic settings for the Public IP Address.
  - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional
    - **Description:** Resource ID of the diagnostic Event Hub authorization rule.

  - **`eventHubName`** (`string`) - Optional
    - **Description:** Name of the diagnostic Event Hub.

  - **`logAnalyticsDestinationType`** (`string`) - Optional
    - **Description:** Log Analytics destination type. Allowed values: AzureDiagnostics, Dedicated.

  - **`logCategoriesAndGroups`** (`array`) - Optional
    - **Description:** Log categories and groups to collect. Set to [] to disable log collection.
    - **`category`** (`string`) - Optional
      - **Description:** Name of a diagnostic log category.

    - **`categoryGroup`** (`string`) - Optional
      - **Description:** Name of a diagnostic log category group. Use allLogs to collect all logs.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Enable or disable the log category. Default is true.


  - **`logCategoriesAndGroups[*]`** (`object`) - Optional
    - **Description:** Array item for appGatewayPublicIp.diagnosticSettings[*].logCategoriesAndGroups

  - **`marketplacePartnerResourceId`** (`string`) - Optional
    - **Description:** Marketplace partner resource ID.

  - **`metricCategories`** (`array`) - Optional
    - **Description:** Metric categories to collect. Set to [] to disable metric collection.
    - **`category`** (`string`) - Required
      - **Description:** Name of a diagnostic metric category. Use AllMetrics to collect all metrics.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Enable or disable the metric category. Default is true.


  - **`metricCategories[*]`** (`object`) - Optional
    - **Description:** Array item for appGatewayPublicIp.diagnosticSettings[*].metricCategories

  - **`name`** (`string`) - Optional
    - **Description:** Name of the diagnostic setting.

  - **`storageAccountResourceId`** (`string`) - Optional
    - **Description:** Resource ID of the diagnostic storage account.

  - **`workspaceResourceId`** (`string`) - Optional
    - **Description:** Resource ID of the diagnostic Log Analytics workspace.


- **`diagnosticSettings[*]`** (`object`) - Optional
  - **Description:** Array item for appGatewayPublicIp.diagnosticSettings
  - **`category`** (`string`) - Optional
    - **Description:** Name of a diagnostic log category.

  - **`categoryGroup`** (`string`) - Optional
    - **Description:** Name of a diagnostic log category group. Use allLogs to collect all logs.

  - **`enabled`** (`bool`) - Optional
    - **Description:** Enable or disable the log category. Default is true.

  - **`category`** (`string`) - Required
    - **Description:** Name of a diagnostic metric category. Use AllMetrics to collect all metrics.

  - **`enabled`** (`bool`) - Optional
    - **Description:** Enable or disable the metric category. Default is true.


- **`dnsSettings`** (`object`) - Optional
  - **Description:** DNS settings for the Public IP Address.
  - **`domainNameLabel`** (`string`) - Required
    - **Description:** Domain name label used to create an A DNS record in Azure DNS.

  - **`domainNameLabelScope`** (`string`) - Optional
    - **Description:** Domain name label scope. Allowed values: NoReuse, ResourceGroupReuse, SubscriptionReuse, TenantReuse.

  - **`fqdn`** (`string`) - Optional
    - **Description:** Fully qualified domain name (FQDN) associated with the Public IP.

  - **`reverseFqdn`** (`string`) - Optional
    - **Description:** Reverse FQDN used for PTR records.


- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable or disable usage telemetry for the module. Default is true.

- **`idleTimeoutInMinutes`** (`int`) - Optional
  - **Description:** Idle timeout in minutes for the Public IP Address. Default is 4.

- **`ipTags`** (`array`) - Optional
  - **Description:** IP tags associated with the Public IP Address.
  - **`ipTagType`** (`string`) - Required
    - **Description:** IP tag type.

  - **`tag`** (`string`) - Required
    - **Description:** IP tag value.


- **`ipTags[*]`** (`object`) - Optional
  - **Description:** Array item for appGatewayPublicIp.ipTags

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Public IP Address.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** Name of the Public IP Address.

- **`publicIPAddressVersion`** (`string`) - Optional
  - **Description:** IP address version. Default is IPv4. Allowed values: IPv4, IPv6.

- **`publicIPAllocationMethod`** (`string`) - Optional
  - **Description:** Public IP allocation method. Default is Static. Allowed values: Dynamic, Static.

- **`publicIpPrefixResourceId`** (`string`) - Optional
  - **Description:** Resource ID of the Public IP Prefix to allocate from.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments to apply to the Public IP Address.
  - **`condition`** (`string`) - Optional
    - **Description:** Condition for the role assignment.

  - **`conditionVersion`** (`string`) - Optional
    - **Description:** Condition version. Allowed value: 2.0.

  - **`delegatedManagedIdentityResourceId`** (`string`) - Optional
    - **Description:** Delegated managed identity resource ID.

  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Role assignment name (GUID). If omitted, a GUID is generated.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID of the identity being assigned.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type of the assigned identity. Allowed values: Device, ForeignGroup, Group, ServicePrincipal, User.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role to assign (display name, GUID, or full resource ID).


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for appGatewayPublicIp.roleAssignments

- **`skuName`** (`string`) - Optional
  - **Description:** SKU name for the Public IP Address. Default is Standard. Allowed values: Basic, Standard.

- **`skuTier`** (`string`) - Optional
  - **Description:** SKU tier for the Public IP Address. Default is Regional. Allowed values: Global, Regional.

- **`tags`** (`object`) - Optional
  - **Description:** Tags to apply to the Public IP Address resource.

- **`zones`** (`array`) - Optional
  - **Description:** Availability zones for the Public IP Address allocation. Allowed values: 1, 2, 3.

### `appInsightsDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `appInsightsDefinition` | `object` | Conditional | Application Insights configuration. Required if deploy.appInsights is true and resourceIds.appInsightsResourceId is empty; a Log Analytics workspace must exist or be deployed. |

### `buildVmDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `buildVmDefinition` | `object` | Conditional | Build VM configuration to support CI/CD workers (Linux). Required if deploy.buildVm is true. |

**Properties:**

- **`adminPassword`** (`securestring`) - Optional
  - **Description:** Admin password for the VM.

- **`adminUsername`** (`string`) - Optional
  - **Description:** Admin username to create (e.g., azureuser).

- **`availabilityZone`** (`int`) - Optional
  - **Description:** Availability zone.

- **`azdo`** (`object`) - Optional
  - **Description:** Azure DevOps settings (required when runner = azdo, Build VM only).
  - **`agentName`** (`string`) - Optional
    - **Description:** Agent name.

  - **`orgUrl`** (`string`) - Required
    - **Description:** Azure DevOps organization URL (e.g., https://dev.azure.com/contoso).

  - **`pool`** (`string`) - Required
    - **Description:** Agent pool name.

  - **`workFolder`** (`string`) - Optional
    - **Description:** Working folder.


- **`disablePasswordAuthentication`** (`bool`) - Optional
  - **Description:** Disable password authentication (Build VM only).

- **`enableAutomaticUpdates`** (`bool`) - Optional
  - **Description:** Enable automatic updates (Jump VM only).

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable telemetry via a Globally Unique Identifier (GUID).

- **`github`** (`object`) - Optional
  - **Description:** GitHub settings (required when runner = github, Build VM only).
  - **`agentName`** (`string`) - Optional
    - **Description:** Runner name.

  - **`labels`** (`string`) - Optional
    - **Description:** Runner labels (comma-separated).

  - **`owner`** (`string`) - Required
    - **Description:** GitHub owner (org or user).

  - **`repo`** (`string`) - Required
    - **Description:** Repository name.

  - **`workFolder`** (`string`) - Optional
    - **Description:** Working folder.


- **`imageReference`** (`object`) - Optional
  - **Description:** Marketplace image reference for the VM.
  - **`communityGalleryImageId`** (`string`) - Optional
    - **Description:** Community gallery image ID.

  - **`id`** (`string`) - Optional
    - **Description:** Resource ID.

  - **`offer`** (`string`) - Optional
    - **Description:** Offer name.

  - **`publisher`** (`string`) - Optional
    - **Description:** Publisher name.

  - **`sharedGalleryImageId`** (`string`) - Optional
    - **Description:** Shared gallery image ID.

  - **`sku`** (`string`) - Optional
    - **Description:** SKU name.

  - **`version`** (`string`) - Optional
    - **Description:** Image version (e.g., latest).


- **`location`** (`string`) - Optional
  - **Description:** Location for all resources.

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration.

- **`maintenanceConfigurationResourceId`** (`string`) - Optional
  - **Description:** Resource ID of the maintenance configuration (Jump VM only).

- **`managedIdentities`** (`object`) - Optional
  - **Description:** Managed identities.

- **`name`** (`string`) - Optional
  - **Description:** VM name.

- **`nicConfigurations`** (`array`) - Optional
  - **Description:** Network interface configurations.

- **`osDisk`** (`object`) - Optional
  - **Description:** OS disk configuration.

- **`osType`** (`string`) - Optional
  - **Description:** OS type for the VM.

- **`patchMode`** (`string`) - Optional
  - **Description:** Patch mode for the VM (Jump VM only).

- **`publicKeys`** (`array`) - Optional
  - **Description:** SSH public keys (Build VM only).

- **`requireGuestProvisionSignal`** (`bool`) - Optional
  - **Description:** Force password reset on first login.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments.

- **`runner`** (`string`) - Optional
  - **Description:** Which agent to install (Build VM only).

- **`sku`** (`string`) - Optional
  - **Description:** VM size SKU (e.g., Standard_B2s, Standard_D2s_v5).

- **`tags`** (`object`) - Optional
  - **Description:** Tags to apply to the VM resource.

### `containerAppEnvDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `containerAppEnvDefinition` | `object` | Conditional | Container Apps Environment configuration. Required if deploy.containerEnv is true and resourceIds.containerEnvResourceId is empty. |

**Properties:**

- **`appInsightsConnectionString`** (`securestring`) - Optional
  - **Description:** Application Insights connection string.

- **`appLogsConfiguration`** (`object`) - Optional
  - **Description:** App Logs configuration for the Managed Environment.
  - **`destination`** (`string`) - Optional
    - **Description:** Destination of the logs. Allowed values: azure-monitor, log-analytics, none.

  - **`logAnalyticsConfiguration`** (`object`) - Conditional
    - **Description:** Log Analytics configuration. Required if destination is log-analytics.
    - **`customerId`** (`string`) - Required
      - **Description:** Log Analytics Workspace ID.

    - **`sharedKey`** (`securestring`) - Required
      - **Description:** Shared key of the Log Analytics workspace.



- **`certificate`** (`object`) - Optional
  - **Description:** Managed Environment Certificate configuration.
  - **`certificateKeyVaultProperties`** (`object`) - Optional
    - **Description:** Key Vault reference for certificate.
    - **`identityResourceId`** (`string`) - Required
      - **Description:** Identity resource ID used to access Key Vault.

    - **`keyVaultUrl`** (`string`) - Required
      - **Description:** Key Vault URL referencing the certificate.


  - **`certificatePassword`** (`string`) - Optional
    - **Description:** Certificate password.

  - **`certificateType`** (`string`) - Optional
    - **Description:** Certificate type. Allowed values: ImagePullTrustedCA, ServerSSLCertificate.

  - **`certificateValue`** (`string`) - Optional
    - **Description:** Certificate value (PFX or PEM).

  - **`name`** (`string`) - Optional
    - **Description:** Certificate name.


- **`certificatePassword`** (`securestring`) - Optional
  - **Description:** Password of the certificate used by the custom domain.

- **`certificateValue`** (`securestring`) - Optional
  - **Description:** Certificate to use for the custom domain (PFX or PEM).

- **`daprAIConnectionString`** (`securestring`) - Optional
  - **Description:** Application Insights connection string for Dapr telemetry.

- **`daprAIInstrumentationKey`** (`securestring`) - Optional
  - **Description:** Azure Monitor instrumentation key for Dapr telemetry.

- **`dnsSuffix`** (`string`) - Optional
  - **Description:** DNS suffix for the environment domain.

- **`dockerBridgeCidr`** (`string`) - Conditional
  - **Description:** Docker bridge CIDR range for the environment. Must not overlap with other IP ranges. Required if zoneRedundant is set to true to be WAF compliant.

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable or disable telemetry for the module. Default is true.

- **`infrastructureResourceGroupName`** (`string`) - Conditional
  - **Description:** Infrastructure resource group name. Required if zoneRedundant is set to true to be WAF compliant.

- **`infrastructureSubnetResourceId`** (`string`) - Conditional
  - **Description:** Resource ID of the subnet for infrastructure components. Required if "internal" is true. Required if zoneRedundant is set to true to be WAF compliant.

- **`internal`** (`bool`) - Conditional
  - **Description:** Boolean indicating if only internal load balancer is used. Required if zoneRedundant is set to true to be WAF compliant.

- **`location`** (`string`) - Optional
  - **Description:** Location for all resources. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional
  - **Description:** Lock settings for the Managed Environment.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`managedIdentities`** (`object`) - Optional
  - **Description:** Managed identity configuration for the Managed Environment.
  - **`systemAssigned`** (`bool`) - Optional
    - **Description:** Enable system-assigned managed identity.

  - **`userAssignedResourceIds`** (`array`) - Optional
    - **Description:** User-assigned identity resource IDs. Required if user-assigned identity is used for encryption.


- **`name`** (`string`) - Required
  - **Description:** Name of the Container Apps Managed Environment.

- **`openTelemetryConfiguration`** (`object`) - Optional
  - **Description:** Open Telemetry configuration.

- **`peerTrafficEncryption`** (`bool`) - Optional
  - **Description:** Whether peer traffic encryption is enabled. Default is true.

- **`platformReservedCidr`** (`string`) - Conditional
  - **Description:** Reserved IP range in CIDR notation for infrastructure. Required if zoneRedundant is set to true to be WAF compliant.

- **`platformReservedDnsIP`** (`string`) - Conditional
  - **Description:** Reserved DNS IP within platformReservedCidr for internal DNS. Required if zoneRedundant is set to true to be WAF compliant.

- **`publicNetworkAccess`** (`string`) - Optional
  - **Description:** Whether to allow or block public network traffic. Allowed values: Disabled, Enabled.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments to create for the Managed Environment.

- **`storages`** (`array`) - Optional
  - **Description:** List of storages to mount on the environment.
  - **`accessMode`** (`string`) - Required
    - **Description:** Access mode for storage. Allowed values: ReadOnly, ReadWrite.

  - **`kind`** (`string`) - Required
    - **Description:** Type of storage. Allowed values: NFS, SMB.

  - **`shareName`** (`string`) - Required
    - **Description:** File share name.

  - **`storageAccountName`** (`string`) - Required
    - **Description:** Storage account name.


- **`storages[*]`** (`object`) - Optional
  - **Description:** Array item for containerAppEnvDefinition.storages

- **`tags`** (`object`) - Optional
  - **Description:** Tags to apply to the Managed Environment.

- **`workloadProfiles`** (`array`) - Conditional
  - **Description:** Workload profiles for the Managed Environment. Required if zoneRedundant is set to true to be WAF compliant.

- **`zoneRedundant`** (`bool`) - Optional
  - **Description:** Whether the Managed Environment is zone redundant. Default is true.

### `containerRegistryDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `containerRegistryDefinition` | `object` | Conditional | Container Registry configuration. Required if deploy.containerRegistry is true and resourceIds.containerRegistryResourceId is empty. |

**Properties:**

- **`acrAdminUserEnabled`** (`bool`) - Optional
  - **Description:** Enable admin user that has push/pull permission to the registry. Default is false.

- **`acrSku`** (`string`) - Optional
  - **Description:** Tier of your Azure Container Registry. Default is Premium.

- **`anonymousPullEnabled`** (`bool`) - Optional
  - **Description:** Enables registry-wide pull from unauthenticated clients (preview, Standard/Premium only). Default is false.

- **`azureADAuthenticationAsArmPolicyStatus`** (`string`) - Optional
  - **Description:** Indicates whether the policy for using ARM audience token is enabled. Default is enabled.

- **`cacheRules`** (`array`) - Optional
  - **Description:** Array of Cache Rules.
  - **`credentialSetResourceId`** (`string`) - Optional
    - **Description:** Resource ID of the credential store associated with the cache rule.

  - **`name`** (`string`) - Optional
    - **Description:** Name of the cache rule. Defaults to the source repository name if not set.

  - **`sourceRepository`** (`string`) - Required
    - **Description:** Source repository pulled from upstream.

  - **`targetRepository`** (`string`) - Optional
    - **Description:** Target repository specified in docker pull command.


- **`cacheRules[*]`** (`object`) - Optional
  - **Description:** Array item for containerRegistryDefinition.cacheRules

- **`credentialSets`** (`array`) - Optional
  - **Description:** Array of Credential Sets.
  - **`authCredentials`** (`array`) - Required
    - **Description:** List of authentication credentials (primary and optional secondary).
    - **`name`** (`string`) - Required
      - **Description:** Name of the credential.

    - **`passwordSecretIdentifier`** (`string`) - Required
      - **Description:** KeyVault Secret URI for the password.

    - **`usernameSecretIdentifier`** (`string`) - Required
      - **Description:** KeyVault Secret URI for the username.


  - **`authCredentials[*]`** (`object`) - Optional
    - **Description:** Array item for containerRegistryDefinition.credentialSets[*].authCredentials

  - **`loginServer`** (`string`) - Required
    - **Description:** Login server for which the credentials are stored.

  - **`managedIdentities`** (`object`) - Optional
    - **Description:** Managed identity definition for this credential set.
    - **`systemAssigned`** (`bool`) - Optional
      - **Description:** Enables system-assigned managed identity.


  - **`name`** (`string`) - Required
    - **Description:** Name of the credential set.


- **`credentialSets[*]`** (`object`) - Optional
  - **Description:** Array item for containerRegistryDefinition.credentialSets
  - **`name`** (`string`) - Required
    - **Description:** Name of the credential.

  - **`passwordSecretIdentifier`** (`string`) - Required
    - **Description:** KeyVault Secret URI for the password.

  - **`usernameSecretIdentifier`** (`string`) - Required
    - **Description:** KeyVault Secret URI for the username.

  - **`systemAssigned`** (`bool`) - Optional
    - **Description:** Enables system-assigned managed identity.


- **`customerManagedKey`** (`object`) - Optional
  - **Description:** Customer managed key definition.
  - **`autoRotationEnabled`** (`bool`) - Optional
    - **Description:** Enable or disable auto-rotation to the latest version. Default is true.

  - **`keyName`** (`string`) - Required
    - **Description:** Name of the key.

  - **`keyVaultResourceId`** (`string`) - Required
    - **Description:** Resource ID of the Key Vault.

  - **`keyVersion`** (`string`) - Optional
    - **Description:** Key version. Used if autoRotationEnabled=false.

  - **`userAssignedIdentityResourceId`** (`string`) - Optional
    - **Description:** User-assigned identity for fetching the key. Required if no system-assigned identity.


- **`dataEndpointEnabled`** (`bool`) - Conditional
  - **Description:** Enable a single data endpoint per region (Premium only). Default is false. Required if acrSku is Premium.

- **`diagnosticSettings`** (`array`) - Optional
  - **Description:** Diagnostic settings for the service.
  - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional
    - **Description:** Event Hub authorization rule resource ID.

  - **`eventHubName`** (`string`) - Optional
    - **Description:** Event Hub name for logs.

  - **`logAnalyticsDestinationType`** (`string`) - Optional
    - **Description:** Destination type for Log Analytics (AzureDiagnostics or Dedicated).

  - **`logCategoriesAndGroups`** (`array`) - Optional
    - **Description:** Log categories and groups.
    - **`category`** (`string`) - Optional
      - **Description:** Diagnostic log category.

    - **`categoryGroup`** (`string`) - Optional
      - **Description:** Diagnostic log category group.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Enable or disable this category. Default is true.


  - **`logCategoriesAndGroups[*]`** (`object`) - Optional
    - **Description:** Array item for containerRegistryDefinition.diagnosticSettings[*].logCategoriesAndGroups

  - **`marketplacePartnerResourceId`** (`string`) - Optional
    - **Description:** Marketplace partner resource ID.

  - **`metricCategories`** (`array`) - Optional
    - **Description:** Metric categories.
    - **`category`** (`string`) - Required
      - **Description:** Diagnostic metric category.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Enable or disable this metric. Default is true.


  - **`metricCategories[*]`** (`object`) - Optional
    - **Description:** Array item for containerRegistryDefinition.diagnosticSettings[*].metricCategories

  - **`name`** (`string`) - Optional
    - **Description:** Name of the diagnostic setting.

  - **`storageAccountResourceId`** (`string`) - Optional
    - **Description:** Storage account resource ID.

  - **`workspaceResourceId`** (`string`) - Optional
    - **Description:** Log Analytics workspace resource ID.


- **`diagnosticSettings[*]`** (`object`) - Optional
  - **Description:** Array item for containerRegistryDefinition.diagnosticSettings
  - **`category`** (`string`) - Optional
    - **Description:** Diagnostic log category.

  - **`categoryGroup`** (`string`) - Optional
    - **Description:** Diagnostic log category group.

  - **`enabled`** (`bool`) - Optional
    - **Description:** Enable or disable this category. Default is true.

  - **`category`** (`string`) - Required
    - **Description:** Diagnostic metric category.

  - **`enabled`** (`bool`) - Optional
    - **Description:** Enable or disable this metric. Default is true.


- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable or disable telemetry for the module. Default is true.

- **`exportPolicyStatus`** (`string`) - Optional
  - **Description:** Export policy status. Default is disabled.

- **`location`** (`string`) - Optional
  - **Description:** Location for all resources. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional
  - **Description:** Lock settings.
  - **`kind`** (`string`) - Optional
    - **Description:** Type of lock (CanNotDelete, None, ReadOnly).

  - **`name`** (`string`) - Optional
    - **Description:** Name of the lock.

  - **`notes`** (`string`) - Optional
    - **Description:** Notes for the lock.


- **`managedIdentities`** (`object`) - Optional
  - **Description:** Managed identity definition for the registry.
  - **`systemAssigned`** (`bool`) - Optional
    - **Description:** Enable system-assigned managed identity.

  - **`userAssignedResourceIds`** (`array`) - Optional
    - **Description:** User-assigned identity resource IDs. Required if user-assigned identity is used for encryption.


- **`name`** (`string`) - Required
  - **Description:** Name of your Azure Container Registry.

- **`networkRuleBypassOptions`** (`string`) - Optional
  - **Description:** Network rule bypass options. Default is AzureServices.

- **`networkRuleSetDefaultAction`** (`string`) - Optional
  - **Description:** Default action when no network rule matches. Default is Deny.

- **`networkRuleSetIpRules`** (`array`) - Conditional
  - **Description:** IP ACL rules (Premium only). Required if acrSku is Premium.

- **`privateEndpoints`** (`array`) - Conditional
  - **Description:** Private endpoint configuration (Premium only). Required if acrSku is Premium.

- **`publicNetworkAccess`** (`string`) - Conditional
  - **Description:** Public network access (Premium only). Disabled by default if private endpoints are set and no IP rules). Required if acrSku is Premium.

- **`quarantinePolicyStatus`** (`string`) - Conditional
  - **Description:** Quarantine policy status (Premium only). Default is disabled. Required if acrSku is Premium.

- **`replications`** (`array`) - Optional
  - **Description:** Replications to create.

- **`retentionPolicyDays`** (`int`) - Optional
  - **Description:** Number of days to retain untagged manifests. Default is 15.

- **`retentionPolicyStatus`** (`string`) - Optional
  - **Description:** Retention policy status. Default is enabled.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for this registry.

- **`scopeMaps`** (`array`) - Optional
  - **Description:** Scope maps configuration.

- **`softDeletePolicyDays`** (`int`) - Optional
  - **Description:** Number of days after which soft-deleted items are permanently deleted. Default is 7.

- **`softDeletePolicyStatus`** (`string`) - Optional
  - **Description:** Soft delete policy status. Default is disabled.

- **`tags`** (`object`) - Optional
  - **Description:** Resource tags.

- **`trustPolicyStatus`** (`string`) - Conditional
  - **Description:** Trust policy status (Premium only). Default is disabled. Required if acrSku is Premium.

- **`webhooks`** (`array`) - Optional
  - **Description:** Webhooks to create.

- **`zoneRedundancy`** (`string`) - Optional
  - **Description:** Zone redundancy setting. Default is Enabled. Conditional: requires acrSku=Premium.

### `firewallDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `firewallDefinition` | `object` | Conditional | Azure Firewall configuration. Required if deploy.firewall is true and resourceIds.firewallResourceId is empty. |

**Properties:**

- **`additionalPublicIpConfigurations`** (`array`) - Optional
  - **Description:** Additional Public IP configurations.

- **`applicationRuleCollections`** (`array`) - Optional
  - **Description:** Application rule collections used by Azure Firewall.
  - **`name`** (`string`) - Required
    - **Description:** Name of the application rule collection.

  - **`properties`** (`object`) - Required
    - **Description:** Properties of the application rule collection.
    - **`action`** (`object`) - Required
      - **Description:** Action of the rule collection.
      - **`type`** (`string`) - Required
        - **Description:** Action type. Allowed values: Allow, Deny.


    - **`priority`** (`int`) - Required
      - **Description:** Priority of the application rule collection (100-65000).

    - **`rules`** (`array`) - Required
      - **Description:** Application rules in the collection.
      - **`description`** (`string`) - Optional
        - **Description:** Description of the rule.

      - **`fqdnTags`** (`array`) - Optional
        - **Description:** List of FQDN tags for this rule.

      - **`name`** (`string`) - Required
        - **Description:** Name of the application rule.

      - **`protocols`** (`array`) - Required
        - **Description:** Protocols for the application rule.
        - **`port`** (`int`) - Optional
          - **Description:** Port number for the protocol (≤64000).

        - **`protocolType`** (`string`) - Required
          - **Description:** Protocol type. Allowed values: Http, Https, Mssql.


      - **`protocols[*]`** (`object`) - Optional
        - **Description:** Array item for firewallDefinition.applicationRuleCollections[*].properties.rules[*].protocols

      - **`sourceAddresses`** (`array`) - Optional
        - **Description:** List of source IP addresses for this rule.

      - **`sourceIpGroups`** (`array`) - Optional
        - **Description:** List of source IP groups for this rule.

      - **`targetFqdns`** (`array`) - Optional
        - **Description:** List of target FQDNs for this rule.


    - **`rules[*]`** (`object`) - Optional
      - **Description:** Array item for firewallDefinition.applicationRuleCollections[*].properties.rules
      - **`port`** (`int`) - Optional
        - **Description:** Port number for the protocol (≤64000).

      - **`protocolType`** (`string`) - Required
        - **Description:** Protocol type. Allowed values: Http, Https, Mssql.




- **`applicationRuleCollections[*]`** (`object`) - Optional
  - **Description:** Array item for firewallDefinition.applicationRuleCollections
  - **`action`** (`object`) - Required
    - **Description:** Action of the rule collection.
    - **`type`** (`string`) - Required
      - **Description:** Action type. Allowed values: Allow, Deny.


  - **`priority`** (`int`) - Required
    - **Description:** Priority of the application rule collection (100-65000).

  - **`rules`** (`array`) - Required
    - **Description:** Application rules in the collection.
    - **`description`** (`string`) - Optional
      - **Description:** Description of the rule.

    - **`fqdnTags`** (`array`) - Optional
      - **Description:** List of FQDN tags for this rule.

    - **`name`** (`string`) - Required
      - **Description:** Name of the application rule.

    - **`protocols`** (`array`) - Required
      - **Description:** Protocols for the application rule.
      - **`port`** (`int`) - Optional
        - **Description:** Port number for the protocol (≤64000).

      - **`protocolType`** (`string`) - Required
        - **Description:** Protocol type. Allowed values: Http, Https, Mssql.


    - **`protocols[*]`** (`object`) - Optional
      - **Description:** Array item for firewallDefinition.applicationRuleCollections[*].properties.rules[*].protocols

    - **`sourceAddresses`** (`array`) - Optional
      - **Description:** List of source IP addresses for this rule.

    - **`sourceIpGroups`** (`array`) - Optional
      - **Description:** List of source IP groups for this rule.

    - **`targetFqdns`** (`array`) - Optional
      - **Description:** List of target FQDNs for this rule.


  - **`rules[*]`** (`object`) - Optional
    - **Description:** Array item for firewallDefinition.applicationRuleCollections[*].properties.rules
    - **`port`** (`int`) - Optional
      - **Description:** Port number for the protocol (≤64000).

    - **`protocolType`** (`string`) - Required
      - **Description:** Protocol type. Allowed values: Http, Https, Mssql.


  - **`type`** (`string`) - Required
    - **Description:** Action type. Allowed values: Allow, Deny.

  - **`description`** (`string`) - Optional
    - **Description:** Description of the rule.

  - **`fqdnTags`** (`array`) - Optional
    - **Description:** List of FQDN tags for this rule.

  - **`name`** (`string`) - Required
    - **Description:** Name of the application rule.

  - **`protocols`** (`array`) - Required
    - **Description:** Protocols for the application rule.
    - **`port`** (`int`) - Optional
      - **Description:** Port number for the protocol (≤64000).

    - **`protocolType`** (`string`) - Required
      - **Description:** Protocol type. Allowed values: Http, Https, Mssql.


  - **`protocols[*]`** (`object`) - Optional
    - **Description:** Array item for firewallDefinition.applicationRuleCollections[*].properties.rules[*].protocols

  - **`sourceAddresses`** (`array`) - Optional
    - **Description:** List of source IP addresses for this rule.

  - **`sourceIpGroups`** (`array`) - Optional
    - **Description:** List of source IP groups for this rule.

  - **`targetFqdns`** (`array`) - Optional
    - **Description:** List of target FQDNs for this rule.

  - **`port`** (`int`) - Optional
    - **Description:** Port number for the protocol (≤64000).

  - **`protocolType`** (`string`) - Required
    - **Description:** Protocol type. Allowed values: Http, Https, Mssql.

  - **`port`** (`int`) - Optional
    - **Description:** Port number for the protocol (≤64000).

  - **`protocolType`** (`string`) - Required
    - **Description:** Protocol type. Allowed values: Http, Https, Mssql.


- **`autoscaleMaxCapacity`** (`int`) - Optional
  - **Description:** Maximum number of capacity units for the firewall.

- **`autoscaleMinCapacity`** (`int`) - Optional
  - **Description:** Minimum number of capacity units for the firewall.

- **`availabilityZones`** (`array`) - Optional
  - **Description:** Availability Zones for zone-redundant deployment.

- **`azureSkuTier`** (`string`) - Optional
  - **Description:** Tier of Azure Firewall. Allowed values: Basic, Premium, Standard.

- **`diagnosticSettings`** (`array`) - Optional
  - **Description:** Diagnostic settings for the firewall.
  - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional
    - **Description:** Event Hub authorization rule resource ID.

  - **`eventHubName`** (`string`) - Optional
    - **Description:** Event Hub name for diagnostic logs.

  - **`logAnalyticsDestinationType`** (`string`) - Optional
    - **Description:** Log Analytics destination type. Allowed values: AzureDiagnostics, Dedicated.

  - **`logCategoriesAndGroups`** (`array`) - Optional
    - **Description:** Log categories and groups.
    - **`category`** (`string`) - Optional
      - **Description:** Name of a diagnostic log category.

    - **`categoryGroup`** (`string`) - Optional
      - **Description:** Name of a diagnostic log category group.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Enable/disable category. Default is true.


  - **`logCategoriesAndGroups[*]`** (`object`) - Optional
    - **Description:** Array item for firewallDefinition.diagnosticSettings[*].logCategoriesAndGroups

  - **`marketplacePartnerResourceId`** (`string`) - Optional
    - **Description:** Marketplace partner resource ID for diagnostic logs.

  - **`metricCategories`** (`array`) - Optional
    - **Description:** Metric categories for diagnostics.
    - **`category`** (`string`) - Required
      - **Description:** Name of a diagnostic metric category.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Enable/disable metric category. Default is true.


  - **`metricCategories[*]`** (`object`) - Optional
    - **Description:** Array item for firewallDefinition.diagnosticSettings[*].metricCategories

  - **`name`** (`string`) - Optional
    - **Description:** Diagnostic setting name.

  - **`storageAccountResourceId`** (`string`) - Optional
    - **Description:** Diagnostic storage account resource ID.

  - **`workspaceResourceId`** (`string`) - Optional
    - **Description:** Log Analytics workspace resource ID.


- **`diagnosticSettings[*]`** (`object`) - Optional
  - **Description:** Array item for firewallDefinition.diagnosticSettings
  - **`category`** (`string`) - Optional
    - **Description:** Name of a diagnostic log category.

  - **`categoryGroup`** (`string`) - Optional
    - **Description:** Name of a diagnostic log category group.

  - **`enabled`** (`bool`) - Optional
    - **Description:** Enable/disable category. Default is true.

  - **`category`** (`string`) - Required
    - **Description:** Name of a diagnostic metric category.

  - **`enabled`** (`bool`) - Optional
    - **Description:** Enable/disable metric category. Default is true.


- **`enableForcedTunneling`** (`bool`) - Optional
  - **Description:** Enable or disable forced tunneling.

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable or disable usage telemetry. Default is true.

- **`firewallPolicyId`** (`string`) - Optional
  - **Description:** Resource ID of the Firewall Policy to attach.

- **`hubIPAddresses`** (`object`) - Conditional
  - **Description:** IP addresses associated with Azure Firewall. Required if virtualHubId is supplied.
  - **`privateIPAddress`** (`string`) - Optional
    - **Description:** Private IP Address associated with Azure Firewall.

  - **`publicIPs`** (`object`) - Optional
    - **Description:** Public IPs associated with Azure Firewall.
    - **`addresses`** (`array`) - Optional
      - **Description:** List of public IP addresses or IPs to retain.

    - **`count`** (`int`) - Optional
      - **Description:** Public IP address count.



- **`location`** (`string`) - Optional
  - **Description:** Location for all resources. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional
  - **Description:** Lock settings for the firewall.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`managementIPAddressObject`** (`object`) - Optional
  - **Description:** Properties of the Management Public IP to create and use.

- **`managementIPResourceID`** (`string`) - Optional
  - **Description:** Management Public IP resource ID for AzureFirewallManagementSubnet.

- **`name`** (`string`) - Required
  - **Description:** Name of the Azure Firewall.

- **`natRuleCollections`** (`array`) - Optional
  - **Description:** NAT rule collections used by Azure Firewall.
  - **`name`** (`string`) - Required
    - **Description:** Name of the NAT rule collection.

  - **`properties`** (`object`) - Required
    - **Description:** Properties of the NAT rule collection.
    - **`action`** (`object`) - Required
      - **Description:** Action of the NAT rule collection.
      - **`type`** (`string`) - Required
        - **Description:** Action type. Allowed values: Dnat, Snat.


    - **`priority`** (`int`) - Required
      - **Description:** Priority of the NAT rule collection (100–65000).

    - **`rules`** (`array`) - Required
      - **Description:** NAT rules in the collection.
      - **`description`** (`string`) - Optional
        - **Description:** Description of the NAT rule.

      - **`destinationAddresses`** (`array`) - Optional
        - **Description:** Destination addresses (IP ranges, prefixes, service tags).

      - **`destinationPorts`** (`array`) - Optional
        - **Description:** Destination ports.

      - **`name`** (`string`) - Required
        - **Description:** Name of the NAT rule.

      - **`protocols`** (`array`) - Required
        - **Description:** Protocols for the NAT rule. Allowed values: Any, ICMP, TCP, UDP.

      - **`sourceAddresses`** (`array`) - Optional
        - **Description:** Source addresses.

      - **`sourceIpGroups`** (`array`) - Optional
        - **Description:** Source IP groups.

      - **`translatedAddress`** (`string`) - Optional
        - **Description:** Translated address for the NAT rule.

      - **`translatedFqdn`** (`string`) - Optional
        - **Description:** Translated FQDN for the NAT rule.

      - **`translatedPort`** (`string`) - Optional
        - **Description:** Translated port for the NAT rule.


    - **`rules[*]`** (`object`) - Optional
      - **Description:** Array item for firewallDefinition.natRuleCollections[*].properties.rules



- **`natRuleCollections[*]`** (`object`) - Optional
  - **Description:** Array item for firewallDefinition.natRuleCollections
  - **`action`** (`object`) - Required
    - **Description:** Action of the NAT rule collection.
    - **`type`** (`string`) - Required
      - **Description:** Action type. Allowed values: Dnat, Snat.


  - **`priority`** (`int`) - Required
    - **Description:** Priority of the NAT rule collection (100–65000).

  - **`rules`** (`array`) - Required
    - **Description:** NAT rules in the collection.
    - **`description`** (`string`) - Optional
      - **Description:** Description of the NAT rule.

    - **`destinationAddresses`** (`array`) - Optional
      - **Description:** Destination addresses (IP ranges, prefixes, service tags).

    - **`destinationPorts`** (`array`) - Optional
      - **Description:** Destination ports.

    - **`name`** (`string`) - Required
      - **Description:** Name of the NAT rule.

    - **`protocols`** (`array`) - Required
      - **Description:** Protocols for the NAT rule. Allowed values: Any, ICMP, TCP, UDP.

    - **`sourceAddresses`** (`array`) - Optional
      - **Description:** Source addresses.

    - **`sourceIpGroups`** (`array`) - Optional
      - **Description:** Source IP groups.

    - **`translatedAddress`** (`string`) - Optional
      - **Description:** Translated address for the NAT rule.

    - **`translatedFqdn`** (`string`) - Optional
      - **Description:** Translated FQDN for the NAT rule.

    - **`translatedPort`** (`string`) - Optional
      - **Description:** Translated port for the NAT rule.


  - **`rules[*]`** (`object`) - Optional
    - **Description:** Array item for firewallDefinition.natRuleCollections[*].properties.rules

  - **`type`** (`string`) - Required
    - **Description:** Action type. Allowed values: Dnat, Snat.

  - **`description`** (`string`) - Optional
    - **Description:** Description of the NAT rule.

  - **`destinationAddresses`** (`array`) - Optional
    - **Description:** Destination addresses (IP ranges, prefixes, service tags).

  - **`destinationPorts`** (`array`) - Optional
    - **Description:** Destination ports.

  - **`name`** (`string`) - Required
    - **Description:** Name of the NAT rule.

  - **`protocols`** (`array`) - Required
    - **Description:** Protocols for the NAT rule. Allowed values: Any, ICMP, TCP, UDP.

  - **`sourceAddresses`** (`array`) - Optional
    - **Description:** Source addresses.

  - **`sourceIpGroups`** (`array`) - Optional
    - **Description:** Source IP groups.

  - **`translatedAddress`** (`string`) - Optional
    - **Description:** Translated address for the NAT rule.

  - **`translatedFqdn`** (`string`) - Optional
    - **Description:** Translated FQDN for the NAT rule.

  - **`translatedPort`** (`string`) - Optional
    - **Description:** Translated port for the NAT rule.


- **`networkRuleCollections`** (`array`) - Optional
  - **Description:** Network rule collections used by Azure Firewall.
  - **`name`** (`string`) - Required
    - **Description:** Name of the network rule collection.

  - **`properties`** (`object`) - Required
    - **Description:** Properties of the network rule collection.
    - **`action`** (`object`) - Required
      - **Description:** Action of the network rule collection.
      - **`type`** (`string`) - Required
        - **Description:** Action type. Allowed values: Allow, Deny.


    - **`priority`** (`int`) - Required
      - **Description:** Priority of the network rule collection (100–65000).

    - **`rules`** (`array`) - Required
      - **Description:** Network rules in the collection.
      - **`description`** (`string`) - Optional
        - **Description:** Description of the network rule.

      - **`destinationAddresses`** (`array`) - Optional
        - **Description:** Destination addresses.

      - **`destinationFqdns`** (`array`) - Optional
        - **Description:** Destination FQDNs.

      - **`destinationIpGroups`** (`array`) - Optional
        - **Description:** Destination IP groups.

      - **`destinationPorts`** (`array`) - Optional
        - **Description:** Destination ports.

      - **`name`** (`string`) - Required
        - **Description:** Name of the network rule.

      - **`protocols`** (`array`) - Required
        - **Description:** Protocols for the network rule. Allowed values: Any, ICMP, TCP, UDP.

      - **`sourceAddresses`** (`array`) - Optional
        - **Description:** Source addresses.

      - **`sourceIpGroups`** (`array`) - Optional
        - **Description:** Source IP groups.


    - **`rules[*]`** (`object`) - Optional
      - **Description:** Array item for firewallDefinition.networkRuleCollections[*].properties.rules



- **`networkRuleCollections[*]`** (`object`) - Optional
  - **Description:** Array item for firewallDefinition.networkRuleCollections
  - **`action`** (`object`) - Required
    - **Description:** Action of the network rule collection.
    - **`type`** (`string`) - Required
      - **Description:** Action type. Allowed values: Allow, Deny.


  - **`priority`** (`int`) - Required
    - **Description:** Priority of the network rule collection (100–65000).

  - **`rules`** (`array`) - Required
    - **Description:** Network rules in the collection.
    - **`description`** (`string`) - Optional
      - **Description:** Description of the network rule.

    - **`destinationAddresses`** (`array`) - Optional
      - **Description:** Destination addresses.

    - **`destinationFqdns`** (`array`) - Optional
      - **Description:** Destination FQDNs.

    - **`destinationIpGroups`** (`array`) - Optional
      - **Description:** Destination IP groups.

    - **`destinationPorts`** (`array`) - Optional
      - **Description:** Destination ports.

    - **`name`** (`string`) - Required
      - **Description:** Name of the network rule.

    - **`protocols`** (`array`) - Required
      - **Description:** Protocols for the network rule. Allowed values: Any, ICMP, TCP, UDP.

    - **`sourceAddresses`** (`array`) - Optional
      - **Description:** Source addresses.

    - **`sourceIpGroups`** (`array`) - Optional
      - **Description:** Source IP groups.


  - **`rules[*]`** (`object`) - Optional
    - **Description:** Array item for firewallDefinition.networkRuleCollections[*].properties.rules

  - **`type`** (`string`) - Required
    - **Description:** Action type. Allowed values: Allow, Deny.

  - **`description`** (`string`) - Optional
    - **Description:** Description of the network rule.

  - **`destinationAddresses`** (`array`) - Optional
    - **Description:** Destination addresses.

  - **`destinationFqdns`** (`array`) - Optional
    - **Description:** Destination FQDNs.

  - **`destinationIpGroups`** (`array`) - Optional
    - **Description:** Destination IP groups.

  - **`destinationPorts`** (`array`) - Optional
    - **Description:** Destination ports.

  - **`name`** (`string`) - Required
    - **Description:** Name of the network rule.

  - **`protocols`** (`array`) - Required
    - **Description:** Protocols for the network rule. Allowed values: Any, ICMP, TCP, UDP.

  - **`sourceAddresses`** (`array`) - Optional
    - **Description:** Source addresses.

  - **`sourceIpGroups`** (`array`) - Optional
    - **Description:** Source IP groups.


- **`publicIPAddressObject`** (`object`) - Optional
  - **Description:** Properties of the Public IP to create and use if no existing Public IP is provided.

- **`publicIPResourceID`** (`string`) - Optional
  - **Description:** Public IP resource ID for the AzureFirewallSubnet.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the firewall.

- **`tags`** (`object`) - Optional
  - **Description:** Tags to apply to the Azure Firewall resource.

- **`threatIntelMode`** (`string`) - Optional
  - **Description:** Operation mode for Threat Intel. Allowed values: Alert, Deny, Off.

- **`virtualHubResourceId`** (`string`) - Conditional
  - **Description:** The virtualHub resource ID to which the firewall belongs. Required if virtualNetworkId is empty.

- **`virtualNetworkResourceId`** (`string`) - Conditional
  - **Description:** Shared services Virtual Network resource ID containing AzureFirewallSubnet. Required if virtualHubId is empty.

### `firewallPolicyDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `firewallPolicyDefinition` | `object` | Conditional | Azure Firewall Policy configuration. Required if deploy.firewall is true and resourceIds.firewallPolicyResourceId is empty. |

**Properties:**

- **`allowSqlRedirect`** (`bool`) - Optional
  - **Description:** A flag to indicate if SQL Redirect traffic filtering is enabled. Requires no rule using ports 11000–11999.

- **`basePolicyResourceId`** (`string`) - Optional
  - **Description:** Resource ID of the base policy.

- **`certificateName`** (`string`) - Optional
  - **Description:** Name of the CA certificate.

- **`defaultWorkspaceResourceId`** (`string`) - Optional
  - **Description:** Default Log Analytics Resource ID for Firewall Policy Insights.

- **`enableProxy`** (`bool`) - Optional
  - **Description:** Enable DNS Proxy on Firewalls attached to the Firewall Policy.

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable or disable usage telemetry for the module. Default is true.

- **`fqdns`** (`array`) - Optional
  - **Description:** List of FQDNs for the ThreatIntel Allowlist.

- **`insightsIsEnabled`** (`bool`) - Optional
  - **Description:** Flag to indicate if insights are enabled on the policy.

- **`intrusionDetection`** (`object`) - Optional
  - **Description:** Intrusion detection configuration.
  - **`configuration`** (`object`) - Optional
    - **Description:** Intrusion detection configuration properties.
    - **`bypassTrafficSettings`** (`array`) - Optional
      - **Description:** List of bypass traffic rules.
      - **`description`** (`string`) - Optional
        - **Description:** Description of the bypass traffic rule.

      - **`destinationAddresses`** (`array`) - Optional
        - **Description:** Destination IP addresses or ranges.

      - **`destinationIpGroups`** (`array`) - Optional
        - **Description:** Destination IP groups.

      - **`destinationPorts`** (`array`) - Optional
        - **Description:** Destination ports or ranges.

      - **`name`** (`string`) - Required
        - **Description:** Name of the bypass traffic rule.

      - **`protocol`** (`string`) - Optional
        - **Description:** Protocol for the rule. Allowed values: ANY, ICMP, TCP, UDP.

      - **`sourceAddresses`** (`array`) - Optional
        - **Description:** Source IP addresses or ranges.

      - **`sourceIpGroups`** (`array`) - Optional
        - **Description:** Source IP groups.


    - **`bypassTrafficSettings[*]`** (`object`) - Optional
      - **Description:** Array item for firewallPolicyDefinition.intrusionDetection.configuration.bypassTrafficSettings

    - **`privateRanges`** (`array`) - Optional
      - **Description:** List of private IP ranges to consider as internal.

    - **`signatureOverrides`** (`array`) - Optional
      - **Description:** Signature override states.
      - **`id`** (`string`) - Required
        - **Description:** Signature ID.

      - **`mode`** (`string`) - Required
        - **Description:** Signature state. Allowed values: Alert, Deny, Off.


    - **`signatureOverrides[*]`** (`object`) - Optional
      - **Description:** Array item for firewallPolicyDefinition.intrusionDetection.configuration.signatureOverrides


  - **`mode`** (`string`) - Optional
    - **Description:** Intrusion detection mode. Allowed values: Alert, Deny, Off.

  - **`profile`** (`string`) - Optional
    - **Description:** IDPS profile name. Allowed values: Advanced, Basic, Extended, Standard.


- **`ipAddresses`** (`array`) - Optional
  - **Description:** List of IP addresses for the ThreatIntel Allowlist.

- **`keyVaultSecretId`** (`string`) - Optional
  - **Description:** Key Vault secret ID (base-64 encoded unencrypted PFX or Certificate object).

- **`location`** (`string`) - Optional
  - **Description:** Location for all resources. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional
  - **Description:** Lock settings for the Firewall Policy.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`managedIdentities`** (`object`) - Optional
  - **Description:** Managed identity definition for this resource.
  - **`userAssignedResourceIds`** (`array`) - Optional
    - **Description:** User-assigned identity resource IDs. Required if using a user-assigned identity for encryption.


- **`name`** (`string`) - Required
  - **Description:** Name of the Firewall Policy.

- **`retentionDays`** (`int`) - Optional
  - **Description:** Number of days to retain Firewall Policy insights. Default is 365.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments to create for the Firewall Policy.

- **`ruleCollectionGroups`** (`array`) - Optional
  - **Description:** Rule collection groups.

- **`servers`** (`array`) - Optional
  - **Description:** List of custom DNS servers.

- **`snat`** (`object`) - Optional
  - **Description:** SNAT private IP ranges configuration.
  - **`autoLearnPrivateRanges`** (`string`) - Required
    - **Description:** Mode for automatically learning private ranges. Allowed values: Disabled, Enabled.

  - **`privateRanges`** (`array`) - Optional
    - **Description:** List of private IP ranges not to be SNATed.


- **`tags`** (`object`) - Optional
  - **Description:** Tags to apply to the Firewall Policy.

- **`threatIntelMode`** (`string`) - Optional
  - **Description:** Threat Intelligence mode. Allowed values: Alert, Deny, Off.

- **`tier`** (`string`) - Optional
  - **Description:** Tier of the Firewall Policy. Allowed values: Basic, Premium, Standard.

- **`workspaces`** (`array`) - Optional
  - **Description:** List of workspaces for Firewall Policy Insights.

### `firewallPublicIp`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `firewallPublicIp` | `object` | Conditional | Conditional Public IP for Azure Firewall. Required when deploy firewall is true and no existing ID is provided. |

**Properties:**

- **`ddosSettings`** (`object`) - Optional
  - **Description:** DDoS protection settings for the Public IP Address.
  - **`ddosProtectionPlan`** (`object`) - Optional
    - **Description:** Associated DDoS protection plan.
    - **`id`** (`string`) - Required
      - **Description:** Resource ID of the DDoS protection plan.


  - **`protectionMode`** (`string`) - Required
    - **Description:** DDoS protection mode. Allowed value: Enabled.


- **`diagnosticSettings`** (`array`) - Optional
  - **Description:** Diagnostic settings for the Public IP Address.
  - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional
    - **Description:** Resource ID of the diagnostic Event Hub authorization rule.

  - **`eventHubName`** (`string`) - Optional
    - **Description:** Name of the diagnostic Event Hub.

  - **`logAnalyticsDestinationType`** (`string`) - Optional
    - **Description:** Log Analytics destination type. Allowed values: AzureDiagnostics, Dedicated.

  - **`logCategoriesAndGroups`** (`array`) - Optional
    - **Description:** Log categories and groups to collect. Set to [] to disable log collection.
    - **`category`** (`string`) - Optional
      - **Description:** Name of a diagnostic log category.

    - **`categoryGroup`** (`string`) - Optional
      - **Description:** Name of a diagnostic log category group. Use allLogs to collect all logs.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Enable or disable the log category. Default is true.


  - **`logCategoriesAndGroups[*]`** (`object`) - Optional
    - **Description:** Array item for firewallPublicIp.diagnosticSettings[*].logCategoriesAndGroups

  - **`marketplacePartnerResourceId`** (`string`) - Optional
    - **Description:** Marketplace partner resource ID.

  - **`metricCategories`** (`array`) - Optional
    - **Description:** Metric categories to collect. Set to [] to disable metric collection.
    - **`category`** (`string`) - Required
      - **Description:** Name of a diagnostic metric category. Use AllMetrics to collect all metrics.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Enable or disable the metric category. Default is true.


  - **`metricCategories[*]`** (`object`) - Optional
    - **Description:** Array item for firewallPublicIp.diagnosticSettings[*].metricCategories

  - **`name`** (`string`) - Optional
    - **Description:** Name of the diagnostic setting.

  - **`storageAccountResourceId`** (`string`) - Optional
    - **Description:** Resource ID of the diagnostic storage account.

  - **`workspaceResourceId`** (`string`) - Optional
    - **Description:** Resource ID of the diagnostic Log Analytics workspace.


- **`diagnosticSettings[*]`** (`object`) - Optional
  - **Description:** Array item for firewallPublicIp.diagnosticSettings
  - **`category`** (`string`) - Optional
    - **Description:** Name of a diagnostic log category.

  - **`categoryGroup`** (`string`) - Optional
    - **Description:** Name of a diagnostic log category group. Use allLogs to collect all logs.

  - **`enabled`** (`bool`) - Optional
    - **Description:** Enable or disable the log category. Default is true.

  - **`category`** (`string`) - Required
    - **Description:** Name of a diagnostic metric category. Use AllMetrics to collect all metrics.

  - **`enabled`** (`bool`) - Optional
    - **Description:** Enable or disable the metric category. Default is true.


- **`dnsSettings`** (`object`) - Optional
  - **Description:** DNS settings for the Public IP Address.
  - **`domainNameLabel`** (`string`) - Required
    - **Description:** Domain name label used to create an A DNS record in Azure DNS.

  - **`domainNameLabelScope`** (`string`) - Optional
    - **Description:** Domain name label scope. Allowed values: NoReuse, ResourceGroupReuse, SubscriptionReuse, TenantReuse.

  - **`fqdn`** (`string`) - Optional
    - **Description:** Fully qualified domain name (FQDN) associated with the Public IP.

  - **`reverseFqdn`** (`string`) - Optional
    - **Description:** Reverse FQDN used for PTR records.


- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable or disable usage telemetry for the module. Default is true.

- **`idleTimeoutInMinutes`** (`int`) - Optional
  - **Description:** Idle timeout in minutes for the Public IP Address. Default is 4.

- **`ipTags`** (`array`) - Optional
  - **Description:** IP tags associated with the Public IP Address.
  - **`ipTagType`** (`string`) - Required
    - **Description:** IP tag type.

  - **`tag`** (`string`) - Required
    - **Description:** IP tag value.


- **`ipTags[*]`** (`object`) - Optional
  - **Description:** Array item for firewallPublicIp.ipTags

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Public IP Address.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** Name of the Public IP Address.

- **`publicIPAddressVersion`** (`string`) - Optional
  - **Description:** IP address version. Default is IPv4. Allowed values: IPv4, IPv6.

- **`publicIPAllocationMethod`** (`string`) - Optional
  - **Description:** Public IP allocation method. Default is Static. Allowed values: Dynamic, Static.

- **`publicIpPrefixResourceId`** (`string`) - Optional
  - **Description:** Resource ID of the Public IP Prefix to allocate from.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments to apply to the Public IP Address.
  - **`condition`** (`string`) - Optional
    - **Description:** Condition for the role assignment.

  - **`conditionVersion`** (`string`) - Optional
    - **Description:** Condition version. Allowed value: 2.0.

  - **`delegatedManagedIdentityResourceId`** (`string`) - Optional
    - **Description:** Delegated managed identity resource ID.

  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Role assignment name (GUID). If omitted, a GUID is generated.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID of the identity being assigned.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type of the assigned identity. Allowed values: Device, ForeignGroup, Group, ServicePrincipal, User.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role to assign (display name, GUID, or full resource ID).


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for firewallPublicIp.roleAssignments

- **`skuName`** (`string`) - Optional
  - **Description:** SKU name for the Public IP Address. Default is Standard. Allowed values: Basic, Standard.

- **`skuTier`** (`string`) - Optional
  - **Description:** SKU tier for the Public IP Address. Default is Regional. Allowed values: Global, Regional.

- **`tags`** (`object`) - Optional
  - **Description:** Tags to apply to the Public IP Address resource.

- **`zones`** (`array`) - Optional
  - **Description:** Availability zones for the Public IP Address allocation. Allowed values: 1, 2, 3.

### `groundingWithBingDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `groundingWithBingDefinition` | `object` | Conditional | Grounding with Bing configuration. Required if deploy.groundingWithBingSearch is true and resourceIds.groundingServiceResourceId is empty. |

**Properties:**

- **`name`** (`string`) - Optional
  - **Description:** Bing Grounding resource name.

- **`sku`** (`string`) - Required
  - **Description:** Bing Grounding resource SKU.

- **`tags`** (`object`) - Required
  - **Description:** Tags to apply to the Bing Grounding resource.

### `jumpVmDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `jumpVmDefinition` | `object` | Conditional | Jump (bastion) VM configuration (Windows). Required if deploy.jumpVm is true. |

**Properties:**

- **`adminPassword`** (`securestring`) - Optional
  - **Description:** Admin password for the VM.

- **`adminUsername`** (`string`) - Optional
  - **Description:** Admin username to create (e.g., azureuser).

- **`availabilityZone`** (`int`) - Optional
  - **Description:** Availability zone.

- **`azdo`** (`object`) - Optional
  - **Description:** Azure DevOps settings (required when runner = azdo, Build VM only).
  - **`agentName`** (`string`) - Optional
    - **Description:** Agent name.

  - **`orgUrl`** (`string`) - Required
    - **Description:** Azure DevOps organization URL (e.g., https://dev.azure.com/contoso).

  - **`pool`** (`string`) - Required
    - **Description:** Agent pool name.

  - **`workFolder`** (`string`) - Optional
    - **Description:** Working folder.


- **`disablePasswordAuthentication`** (`bool`) - Optional
  - **Description:** Disable password authentication (Build VM only).

- **`enableAutomaticUpdates`** (`bool`) - Optional
  - **Description:** Enable automatic updates (Jump VM only).

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable telemetry via a Globally Unique Identifier (GUID).

- **`github`** (`object`) - Optional
  - **Description:** GitHub settings (required when runner = github, Build VM only).
  - **`agentName`** (`string`) - Optional
    - **Description:** Runner name.

  - **`labels`** (`string`) - Optional
    - **Description:** Runner labels (comma-separated).

  - **`owner`** (`string`) - Required
    - **Description:** GitHub owner (org or user).

  - **`repo`** (`string`) - Required
    - **Description:** Repository name.

  - **`workFolder`** (`string`) - Optional
    - **Description:** Working folder.


- **`imageReference`** (`object`) - Optional
  - **Description:** Marketplace image reference for the VM.
  - **`communityGalleryImageId`** (`string`) - Optional
    - **Description:** Community gallery image ID.

  - **`id`** (`string`) - Optional
    - **Description:** Resource ID.

  - **`offer`** (`string`) - Optional
    - **Description:** Offer name.

  - **`publisher`** (`string`) - Optional
    - **Description:** Publisher name.

  - **`sharedGalleryImageId`** (`string`) - Optional
    - **Description:** Shared gallery image ID.

  - **`sku`** (`string`) - Optional
    - **Description:** SKU name.

  - **`version`** (`string`) - Optional
    - **Description:** Image version (e.g., latest).


- **`location`** (`string`) - Optional
  - **Description:** Location for all resources.

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration.

- **`maintenanceConfigurationResourceId`** (`string`) - Optional
  - **Description:** Resource ID of the maintenance configuration (Jump VM only).

- **`managedIdentities`** (`object`) - Optional
  - **Description:** Managed identities.

- **`name`** (`string`) - Optional
  - **Description:** VM name.

- **`nicConfigurations`** (`array`) - Optional
  - **Description:** Network interface configurations.

- **`osDisk`** (`object`) - Optional
  - **Description:** OS disk configuration.

- **`osType`** (`string`) - Optional
  - **Description:** OS type for the VM.

- **`patchMode`** (`string`) - Optional
  - **Description:** Patch mode for the VM (Jump VM only).

- **`publicKeys`** (`array`) - Optional
  - **Description:** SSH public keys (Build VM only).

- **`requireGuestProvisionSignal`** (`bool`) - Optional
  - **Description:** Force password reset on first login.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments.

- **`runner`** (`string`) - Optional
  - **Description:** Which agent to install (Build VM only).

- **`sku`** (`string`) - Optional
  - **Description:** VM size SKU (e.g., Standard_B2s, Standard_D2s_v5).

- **`tags`** (`object`) - Optional
  - **Description:** Tags to apply to the VM resource.

### `logAnalyticsDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `logAnalyticsDefinition` | `object` | Conditional | Log Analytics Workspace configuration. Required if deploy.logAnalytics is true and resourceIds.logAnalyticsWorkspaceResourceId is empty. |

**Properties:**

- **`dailyQuotaGb`** (`int`) - Optional
  - **Description:** Daily ingestion quota in GB. Default is -1.

- **`dataExports`** (`array`) - Optional
  - **Description:** Data export instances for the workspace.
  - **`destination`** (`object`) - Optional
    - **Description:** Destination configuration for the export.
    - **`metaData`** (`object`) - Optional
      - **Description:** Destination metadata.
      - **`eventHubName`** (`string`) - Optional
        - **Description:** Event Hub name (not applicable when destination is Storage Account).


    - **`resourceId`** (`string`) - Required
      - **Description:** Destination resource ID.


  - **`enable`** (`bool`) - Optional
    - **Description:** Enable or disable the data export.

  - **`name`** (`string`) - Required
    - **Description:** Name of the data export.

  - **`tableNames`** (`array`) - Required
    - **Description:** Table names to export.


- **`dataExports[*]`** (`object`) - Optional
  - **Description:** Array item for logAnalyticsDefinition.dataExports
  - **`metaData`** (`object`) - Optional
    - **Description:** Destination metadata.
    - **`eventHubName`** (`string`) - Optional
      - **Description:** Event Hub name (not applicable when destination is Storage Account).


  - **`resourceId`** (`string`) - Required
    - **Description:** Destination resource ID.

  - **`eventHubName`** (`string`) - Optional
    - **Description:** Event Hub name (not applicable when destination is Storage Account).


- **`dataRetention`** (`int`) - Optional
  - **Description:** Number of days data will be retained. Default 365 (0–730).

- **`dataSources`** (`array`) - Optional
  - **Description:** Data sources for the workspace.
  - **`counterName`** (`string`) - Optional
    - **Description:** Counter name for WindowsPerformanceCounter.

  - **`eventLogName`** (`string`) - Optional
    - **Description:** Event log name for WindowsEvent.

  - **`eventTypes`** (`array`) - Optional
    - **Description:** Event types for WindowsEvent.

  - **`instanceName`** (`string`) - Optional
    - **Description:** Instance name for WindowsPerformanceCounter or LinuxPerformanceObject.

  - **`intervalSeconds`** (`int`) - Optional
    - **Description:** Interval in seconds for collection.

  - **`kind`** (`string`) - Required
    - **Description:** Kind of data source.

  - **`linkedResourceId`** (`string`) - Optional
    - **Description:** Resource ID linked to the workspace.

  - **`name`** (`string`) - Required
    - **Description:** Name of the data source.

  - **`objectName`** (`string`) - Optional
    - **Description:** Object name for WindowsPerformanceCounter or LinuxPerformanceObject.

  - **`performanceCounters`** (`array`) - Optional
    - **Description:** Performance counters for LinuxPerformanceObject.

  - **`state`** (`string`) - Optional
    - **Description:** State (for IISLogs, LinuxSyslogCollection, or LinuxPerformanceCollection).

  - **`syslogName`** (`string`) - Optional
    - **Description:** System log name for LinuxSyslog.

  - **`syslogSeverities`** (`array`) - Optional
    - **Description:** Severities for LinuxSyslog.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the data source.


- **`dataSources[*]`** (`object`) - Optional
  - **Description:** Array item for logAnalyticsDefinition.dataSources

- **`diagnosticSettings`** (`array`) - Optional
  - **Description:** Diagnostic settings for the workspace.
  - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional
    - **Description:** Event Hub authorization rule resource ID.

  - **`eventHubName`** (`string`) - Optional
    - **Description:** Diagnostic Event Hub name.

  - **`logAnalyticsDestinationType`** (`string`) - Optional
    - **Description:** Destination type for Log Analytics. Allowed: AzureDiagnostics, Dedicated.

  - **`logCategoriesAndGroups`** (`array`) - Optional
    - **Description:** Log categories and groups to stream.
    - **`category`** (`string`) - Optional
      - **Description:** Log category name.

    - **`categoryGroup`** (`string`) - Optional
      - **Description:** Log category group name.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Enable or disable the category. Default true.


  - **`logCategoriesAndGroups[*]`** (`object`) - Optional
    - **Description:** Array item for logAnalyticsDefinition.diagnosticSettings[*].logCategoriesAndGroups

  - **`marketplacePartnerResourceId`** (`string`) - Optional
    - **Description:** Marketplace partner resource ID.

  - **`metricCategories`** (`array`) - Optional
    - **Description:** Metric categories to stream.
    - **`category`** (`string`) - Required
      - **Description:** Diagnostic metric category name.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Enable or disable the metric category. Default true.


  - **`metricCategories[*]`** (`object`) - Optional
    - **Description:** Array item for logAnalyticsDefinition.diagnosticSettings[*].metricCategories

  - **`name`** (`string`) - Optional
    - **Description:** Diagnostic setting name.

  - **`storageAccountResourceId`** (`string`) - Optional
    - **Description:** Storage account resource ID for diagnostic logs.

  - **`useThisWorkspace`** (`bool`) - Optional
    - **Description:** Use this workspace as diagnostic target (ignores workspaceResourceId).

  - **`workspaceResourceId`** (`string`) - Optional
    - **Description:** Log Analytics workspace resource ID for diagnostics.


- **`diagnosticSettings[*]`** (`object`) - Optional
  - **Description:** Array item for logAnalyticsDefinition.diagnosticSettings
  - **`category`** (`string`) - Optional
    - **Description:** Log category name.

  - **`categoryGroup`** (`string`) - Optional
    - **Description:** Log category group name.

  - **`enabled`** (`bool`) - Optional
    - **Description:** Enable or disable the category. Default true.

  - **`category`** (`string`) - Required
    - **Description:** Diagnostic metric category name.

  - **`enabled`** (`bool`) - Optional
    - **Description:** Enable or disable the metric category. Default true.


- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable or disable telemetry. Default true.

- **`features`** (`object`) - Optional
  - **Description:** Features for the workspace.
  - **`disableLocalAuth`** (`bool`) - Optional
    - **Description:** Disable non-EntraID auth. Default true.

  - **`enableDataExport`** (`bool`) - Optional
    - **Description:** Enable data export.

  - **`enableLogAccessUsingOnlyResourcePermissions`** (`bool`) - Optional
    - **Description:** Enable log access using only resource permissions. Default false.

  - **`immediatePurgeDataOn30Days`** (`bool`) - Optional
    - **Description:** Remove data after 30 days.


- **`forceCmkForQuery`** (`bool`) - Optional
  - **Description:** Enforce customer-managed storage for queries.

- **`gallerySolutions`** (`array`) - Optional
  - **Description:** Gallery solutions for the workspace.
  - **`name`** (`string`) - Required
    - **Description:** Solution name. Must follow Microsoft or 3rd party naming convention.

  - **`plan`** (`object`) - Required
    - **Description:** Plan for the gallery solution.
    - **`name`** (`string`) - Optional
      - **Description:** Solution name (defaults to gallerySolutions.name).

    - **`product`** (`string`) - Required
      - **Description:** Product name (e.g., OMSGallery/AntiMalware).

    - **`publisher`** (`string`) - Optional
      - **Description:** Publisher name (default: Microsoft for Microsoft solutions).



- **`gallerySolutions[*]`** (`object`) - Optional
  - **Description:** Array item for logAnalyticsDefinition.gallerySolutions
  - **`name`** (`string`) - Optional
    - **Description:** Solution name (defaults to gallerySolutions.name).

  - **`product`** (`string`) - Required
    - **Description:** Product name (e.g., OMSGallery/AntiMalware).

  - **`publisher`** (`string`) - Optional
    - **Description:** Publisher name (default: Microsoft for Microsoft solutions).


- **`linkedServices`** (`array`) - Optional
  - **Description:** Linked services for the workspace.
  - **`name`** (`string`) - Required
    - **Description:** Name of the linked service.

  - **`resourceId`** (`string`) - Optional
    - **Description:** Resource ID of the linked service (read access).

  - **`writeAccessResourceId`** (`string`) - Optional
    - **Description:** Resource ID for write access.


- **`linkedServices[*]`** (`object`) - Optional
  - **Description:** Array item for logAnalyticsDefinition.linkedServices

- **`linkedStorageAccounts`** (`array`) - Conditional
  - **Description:** List of Storage Accounts to be linked. Required if forceCmkForQuery is true and savedSearches is not empty.
  - **`name`** (`string`) - Required
    - **Description:** Name of the storage link.

  - **`storageAccountIds`** (`array`) - Required
    - **Description:** Linked storage accounts resource IDs.


- **`linkedStorageAccounts[*]`** (`object`) - Optional
  - **Description:** Array item for logAnalyticsDefinition.linkedStorageAccounts

- **`location`** (`string`) - Optional
  - **Description:** Location of the workspace. Default: resourceGroup().location.

- **`lock`** (`object`) - Optional
  - **Description:** Lock settings.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`managedIdentities`** (`object`) - Optional
  - **Description:** Managed identity definition (system-assigned or user-assigned).
  - **`systemAssigned`** (`bool`) - Optional
    - **Description:** Enable system-assigned identity.

  - **`userAssignedResourceIds`** (`array`) - Optional
    - **Description:** User-assigned identity resource IDs.


- **`name`** (`string`) - Required
  - **Description:** Name of the Log Analytics workspace.

- **`onboardWorkspaceToSentinel`** (`bool`) - Optional
  - **Description:** Onboard workspace to Sentinel. Requires SecurityInsights solution.

- **`publicNetworkAccessForIngestion`** (`string`) - Optional
  - **Description:** Network access for ingestion. Allowed: Disabled, Enabled.

- **`publicNetworkAccessForQuery`** (`string`) - Optional
  - **Description:** Network access for query. Allowed: Disabled, Enabled.

- **`replication`** (`object`) - Optional
  - **Description:** Replication settings.
  - **`enabled`** (`bool`) - Optional
    - **Description:** Enable replication.

  - **`location`** (`string`) - Conditional
    - **Description:** Replication location. Required if replication is enabled.


- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the workspace.
  - **`condition`** (`string`) - Optional
    - **Description:** Condition for the role assignment.

  - **`conditionVersion`** (`string`) - Optional
    - **Description:** Condition version. Allowed: 2.0.

  - **`delegatedManagedIdentityResourceId`** (`string`) - Optional
    - **Description:** Delegated managed identity resource ID.

  - **`description`** (`string`) - Optional
    - **Description:** Role assignment description.

  - **`name`** (`string`) - Optional
    - **Description:** Role assignment GUID name.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type. Allowed: Device, ForeignGroup, Group, ServicePrincipal, User.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID, name, or GUID.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for logAnalyticsDefinition.roleAssignments

- **`savedSearches`** (`array`) - Optional
  - **Description:** Saved KQL searches.
  - **`category`** (`string`) - Required
    - **Description:** Saved search category.

  - **`displayName`** (`string`) - Required
    - **Description:** Display name for the saved search.

  - **`etag`** (`string`) - Optional
    - **Description:** ETag for concurrency control.

  - **`functionAlias`** (`string`) - Optional
    - **Description:** Function alias if used as a function.

  - **`functionParameters`** (`string`) - Optional
    - **Description:** Function parameters if query is used as a function.

  - **`name`** (`string`) - Required
    - **Description:** Name of the saved search.

  - **`query`** (`string`) - Required
    - **Description:** Query expression.

  - **`tags`** (`array`) - Optional
    - **Description:** Tags for the saved search.

  - **`version`** (`int`) - Optional
    - **Description:** Version of the query language. Default is 2.


- **`savedSearches[*]`** (`object`) - Optional
  - **Description:** Array item for logAnalyticsDefinition.savedSearches

- **`skuCapacityReservationLevel`** (`int`) - Optional
  - **Description:** Capacity reservation level in GB (100–5000 in increments of 100).

- **`skuName`** (`string`) - Optional
  - **Description:** SKU name. Allowed: CapacityReservation, Free, LACluster, PerGB2018, PerNode, Premium, Standalone, Standard.

- **`storageInsightsConfigs`** (`array`) - Optional
  - **Description:** Storage insights configs for linked storage accounts.
  - **`containers`** (`array`) - Optional
    - **Description:** Blob container names to read.

  - **`storageAccountResourceId`** (`string`) - Required
    - **Description:** Storage account resource ID.

  - **`tables`** (`array`) - Optional
    - **Description:** Tables to read.


- **`storageInsightsConfigs[*]`** (`object`) - Optional
  - **Description:** Array item for logAnalyticsDefinition.storageInsightsConfigs

- **`tables`** (`array`) - Optional
  - **Description:** Custom LAW tables to be deployed.
  - **`name`** (`string`) - Required
    - **Description:** Table name.

  - **`plan`** (`string`) - Optional
    - **Description:** Table plan.

  - **`restoredLogs`** (`object`) - Optional
    - **Description:** Restored logs configuration.
    - **`endRestoreTime`** (`string`) - Optional
      - **Description:** End restore time (UTC).

    - **`sourceTable`** (`string`) - Optional
      - **Description:** Source table for restored logs.

    - **`startRestoreTime`** (`string`) - Optional
      - **Description:** Start restore time (UTC).


  - **`retentionInDays`** (`int`) - Optional
    - **Description:** Table retention in days.

  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Role assignments for the table.

  - **`schema`** (`object`) - Optional
    - **Description:** Table schema.
    - **`columns`** (`array`) - Required
      - **Description:** List of table columns.
      - **`dataTypeHint`** (`string`) - Optional
        - **Description:** Logical data type hint. Allowed: armPath, guid, ip, uri.

      - **`description`** (`string`) - Optional
        - **Description:** Column description.

      - **`displayName`** (`string`) - Optional
        - **Description:** Column display name.

      - **`name`** (`string`) - Required
        - **Description:** Column name.

      - **`type`** (`string`) - Required
        - **Description:** Column type. Allowed: boolean, dateTime, dynamic, guid, int, long, real, string.


    - **`columns[*]`** (`object`) - Optional
      - **Description:** Array item for logAnalyticsDefinition.tables[*].schema.columns

    - **`description`** (`string`) - Optional
      - **Description:** Table description.

    - **`displayName`** (`string`) - Optional
      - **Description:** Table display name.

    - **`name`** (`string`) - Required
      - **Description:** Table name.


  - **`searchResults`** (`object`) - Optional
    - **Description:** Search results for the table.
    - **`description`** (`string`) - Optional
      - **Description:** Description of the search job.

    - **`endSearchTime`** (`string`) - Optional
      - **Description:** End time for the search (UTC).

    - **`limit`** (`int`) - Optional
      - **Description:** Row limit for the search job.

    - **`query`** (`string`) - Required
      - **Description:** Query for the search job.

    - **`startSearchTime`** (`string`) - Optional
      - **Description:** Start time for the search (UTC).


  - **`totalRetentionInDays`** (`int`) - Optional
    - **Description:** Total retention in days for the table.


- **`tables[*]`** (`object`) - Optional
  - **Description:** Array item for logAnalyticsDefinition.tables
  - **`endRestoreTime`** (`string`) - Optional
    - **Description:** End restore time (UTC).

  - **`sourceTable`** (`string`) - Optional
    - **Description:** Source table for restored logs.

  - **`startRestoreTime`** (`string`) - Optional
    - **Description:** Start restore time (UTC).

  - **`columns`** (`array`) - Required
    - **Description:** List of table columns.
    - **`dataTypeHint`** (`string`) - Optional
      - **Description:** Logical data type hint. Allowed: armPath, guid, ip, uri.

    - **`description`** (`string`) - Optional
      - **Description:** Column description.

    - **`displayName`** (`string`) - Optional
      - **Description:** Column display name.

    - **`name`** (`string`) - Required
      - **Description:** Column name.

    - **`type`** (`string`) - Required
      - **Description:** Column type. Allowed: boolean, dateTime, dynamic, guid, int, long, real, string.


  - **`columns[*]`** (`object`) - Optional
    - **Description:** Array item for logAnalyticsDefinition.tables[*].schema.columns

  - **`description`** (`string`) - Optional
    - **Description:** Table description.

  - **`displayName`** (`string`) - Optional
    - **Description:** Table display name.

  - **`name`** (`string`) - Required
    - **Description:** Table name.

  - **`dataTypeHint`** (`string`) - Optional
    - **Description:** Logical data type hint. Allowed: armPath, guid, ip, uri.

  - **`description`** (`string`) - Optional
    - **Description:** Column description.

  - **`displayName`** (`string`) - Optional
    - **Description:** Column display name.

  - **`name`** (`string`) - Required
    - **Description:** Column name.

  - **`type`** (`string`) - Required
    - **Description:** Column type. Allowed: boolean, dateTime, dynamic, guid, int, long, real, string.

  - **`description`** (`string`) - Optional
    - **Description:** Description of the search job.

  - **`endSearchTime`** (`string`) - Optional
    - **Description:** End time for the search (UTC).

  - **`limit`** (`int`) - Optional
    - **Description:** Row limit for the search job.

  - **`query`** (`string`) - Required
    - **Description:** Query for the search job.

  - **`startSearchTime`** (`string`) - Optional
    - **Description:** Start time for the search (UTC).


- **`tags`** (`object`) - Optional
  - **Description:** Tags for the workspace.

### `storageAccountDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `storageAccountDefinition` | `object` | Conditional | Storage Account configuration. Required if deploy.storageAccount is true and resourceIds.storageAccountResourceId is empty. |

**Properties:**

- **`accessTier`** (`string`) - Conditional
  - **Description:** The access tier for billing. Required if kind is set to BlobStorage. Allowed values: Cold, Cool, Hot, Premium.

- **`allowBlobPublicAccess`** (`bool`) - Optional
  - **Description:** Indicates whether public access is enabled for all blobs or containers. Recommended to be set to false.

- **`allowCrossTenantReplication`** (`bool`) - Optional
  - **Description:** Allow or disallow cross AAD tenant object replication.

- **`allowedCopyScope`** (`string`) - Optional
  - **Description:** Restrict copy scope. Allowed values: AAD, PrivateLink.

- **`allowSharedKeyAccess`** (`bool`) - Optional
  - **Description:** Indicates whether Shared Key authorization is allowed. Default is true.

- **`azureFilesIdentityBasedAuthentication`** (`object`) - Optional
  - **Description:** Provides the identity-based authentication settings for Azure Files.

- **`blobServices`** (`object`) - Optional
  - **Description:** Blob service and containers configuration.

- **`customDomainName`** (`string`) - Optional
  - **Description:** Sets the custom domain name (CNAME source) for the storage account.

- **`customDomainUseSubDomainName`** (`bool`) - Optional
  - **Description:** Indicates whether indirect CName validation is enabled (updates only).

- **`customerManagedKey`** (`object`) - Optional
  - **Description:** Customer managed key definition.
  - **`autoRotationEnabled`** (`bool`) - Optional
    - **Description:** Enable or disable key auto-rotation. Default is true.

  - **`keyName`** (`string`) - Required
    - **Description:** The name of the customer managed key.

  - **`keyVaultResourceId`** (`string`) - Required
    - **Description:** The Key Vault resource ID where the key is stored.

  - **`keyVersion`** (`string`) - Optional
    - **Description:** The version of the customer managed key to reference.

  - **`userAssignedIdentityResourceId`** (`string`) - Optional
    - **Description:** User-assigned identity resource ID to fetch the key (if no system-assigned identity is available).


- **`defaultToOAuthAuthentication`** (`bool`) - Optional
  - **Description:** When true, OAuth is the default authentication method.

- **`diagnosticSettings`** (`array`) - Optional
  - **Description:** Diagnostic settings for the service.

- **`dnsEndpointType`** (`string`) - Optional
  - **Description:** Endpoint type. Allowed values: AzureDnsZone, Standard.

- **`enableHierarchicalNamespace`** (`bool`) - Conditional
  - **Description:** Enables Hierarchical Namespace for the storage account. Required if enableSftp or enableNfsV3 is true.

- **`enableNfsV3`** (`bool`) - Optional
  - **Description:** Enables NFS 3.0 support. Requires hierarchical namespace enabled.

- **`enableSftp`** (`bool`) - Optional
  - **Description:** Enables Secure File Transfer Protocol (SFTP). Requires hierarchical namespace enabled.

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/disable telemetry for the module.

- **`fileServices`** (`object`) - Optional
  - **Description:** File service and share configuration.

- **`isLocalUserEnabled`** (`bool`) - Optional
  - **Description:** Enables local users feature for SFTP authentication.

- **`keyType`** (`string`) - Optional
  - **Description:** Key type for Queue & Table services. Allowed values: Account, Service.

- **`kind`** (`string`) - Optional
  - **Description:** Storage account type. Allowed values: BlobStorage, BlockBlobStorage, FileStorage, Storage, StorageV2.

- **`largeFileSharesState`** (`string`) - Optional
  - **Description:** Large file shares state. Allowed values: Disabled, Enabled.

- **`localUsers`** (`array`) - Optional
  - **Description:** Local users for SFTP authentication.

- **`location`** (`string`) - Optional
  - **Description:** Resource location.

- **`lock`** (`object`) - Optional
  - **Description:** Lock settings for the resource.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`managedIdentities`** (`object`) - Optional
  - **Description:** Managed identity configuration.
  - **`systemAssigned`** (`bool`) - Optional
    - **Description:** Enables system-assigned identity.

  - **`userAssignedResourceIds`** (`array`) - Optional
    - **Description:** List of user-assigned identity resource IDs.


- **`managementPolicyRules`** (`array`) - Optional
  - **Description:** Storage account management policy rules.

- **`minimumTlsVersion`** (`string`) - Optional
  - **Description:** Minimum TLS version for requests. Allowed value: TLS1_2.

- **`name`** (`string`) - Required
  - **Description:** Name of the Storage Account. Must be lower-case.

- **`networkAcls`** (`object`) - Optional
  - **Description:** Network ACL rules and settings.

- **`privateEndpoints`** (`array`) - Optional
  - **Description:** Private endpoint configurations.

- **`publicNetworkAccess`** (`string`) - Optional
  - **Description:** Whether public network access is allowed. Allowed values: Disabled, Enabled.

- **`queueServices`** (`object`) - Optional
  - **Description:** Queue service configuration.

- **`requireInfrastructureEncryption`** (`bool`) - Optional
  - **Description:** Indicates whether infrastructure encryption with PMK is applied.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the storage account.

- **`sasExpirationAction`** (`string`) - Optional
  - **Description:** SAS expiration action. Allowed values: Block, Log.

- **`sasExpirationPeriod`** (`string`) - Optional
  - **Description:** SAS expiration period in DD.HH:MM:SS format.

- **`secretsExportConfiguration`** (`object`) - Optional
  - **Description:** Configuration for exporting secrets to Key Vault.

- **`skuName`** (`string`) - Optional
  - **Description:** SKU name for the storage account. Allowed values: Premium_LRS, Premium_ZRS, PremiumV2_LRS, PremiumV2_ZRS, Standard_GRS, Standard_GZRS, Standard_LRS, Standard_RAGRS, Standard_RAGZRS, Standard_ZRS, StandardV2_GRS, StandardV2_GZRS, StandardV2_LRS, StandardV2_ZRS.

- **`supportsHttpsTrafficOnly`** (`bool`) - Optional
  - **Description:** When true, allows only HTTPS traffic to the storage service.

- **`tableServices`** (`object`) - Optional
  - **Description:** Table service and tables configuration.

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the resource.

### `vNetDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `vNetDefinition` | `object` | Conditional | Virtual Network configuration. Required if deploy.virtualNetwork is true and resourceIds.virtualNetworkResourceId is empty. |

**Properties:**

- **`addressPrefixes`** (`array`) - Required
  - **Description:** An array of one or more IP address prefixes OR the resource ID of the IPAM pool to be used for the Virtual Network. Required if using IPAM pool resource ID, you must also set ipamPoolNumberOfIpAddresses.

- **`ddosProtectionPlanResourceId`** (`string`) - Optional
  - **Description:** Resource ID of the DDoS protection plan to assign the VNet to. If blank, DDoS protection is not configured.

- **`diagnosticSettings`** (`array`) - Optional
  - **Description:** The diagnostic settings of the Virtual Network.
  - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional
    - **Description:** Resource ID of the diagnostic event hub authorization rule for the Event Hubs namespace.

  - **`eventHubName`** (`string`) - Optional
    - **Description:** Name of the diagnostic event hub within the namespace to which logs are streamed.

  - **`logAnalyticsDestinationType`** (`string`) - Optional
    - **Description:** Destination type for export to Log Analytics. Allowed values: AzureDiagnostics, Dedicated.

  - **`logCategoriesAndGroups`** (`array`) - Optional
    - **Description:** Logs to be streamed. Set to [] to disable log collection.
    - **`category`** (`string`) - Optional
      - **Description:** Name of a diagnostic log category for the resource type.

    - **`categoryGroup`** (`string`) - Optional
      - **Description:** Name of a diagnostic log category group for the resource type.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Enable or disable the category explicitly. Default is true.


  - **`logCategoriesAndGroups[*]`** (`object`) - Optional
    - **Description:** Array item for vNetDefinition.diagnosticSettings[*].logCategoriesAndGroups

  - **`marketplacePartnerResourceId`** (`string`) - Optional
    - **Description:** Marketplace resource ID to which diagnostic logs should be sent.

  - **`metricCategories`** (`array`) - Optional
    - **Description:** Metrics to be streamed. Set to [] to disable metric collection.
    - **`category`** (`string`) - Required
      - **Description:** Name of a diagnostic metric category for the resource type.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Enable or disable the metric category explicitly. Default is true.


  - **`metricCategories[*]`** (`object`) - Optional
    - **Description:** Array item for vNetDefinition.diagnosticSettings[*].metricCategories

  - **`name`** (`string`) - Optional
    - **Description:** Name of the diagnostic setting.

  - **`storageAccountResourceId`** (`string`) - Optional
    - **Description:** Resource ID of the diagnostic storage account.

  - **`workspaceResourceId`** (`string`) - Optional
    - **Description:** Resource ID of the diagnostic Log Analytics workspace.


- **`diagnosticSettings[*]`** (`object`) - Optional
  - **Description:** Array item for vNetDefinition.diagnosticSettings
  - **`category`** (`string`) - Optional
    - **Description:** Name of a diagnostic log category for the resource type.

  - **`categoryGroup`** (`string`) - Optional
    - **Description:** Name of a diagnostic log category group for the resource type.

  - **`enabled`** (`bool`) - Optional
    - **Description:** Enable or disable the category explicitly. Default is true.

  - **`category`** (`string`) - Required
    - **Description:** Name of a diagnostic metric category for the resource type.

  - **`enabled`** (`bool`) - Optional
    - **Description:** Enable or disable the metric category explicitly. Default is true.


- **`dnsServers`** (`array`) - Optional
  - **Description:** DNS servers associated with the Virtual Network.

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable or disable usage telemetry for the module. Default is true.

- **`enableVmProtection`** (`bool`) - Optional
  - **Description:** Indicates if VM protection is enabled for all subnets in the Virtual Network.

- **`flowTimeoutInMinutes`** (`int`) - Optional
  - **Description:** Flow timeout in minutes for intra-VM flows (range 4–30). Default 0 sets the property to null.

- **`ipamPoolNumberOfIpAddresses`** (`string`) - Optional
  - **Description:** Number of IP addresses allocated from the IPAM pool. Required if addressPrefixes is defined with a resource ID of an IPAM pool.

- **`location`** (`string`) - Optional
  - **Description:** Location for all resources. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional
  - **Description:** Lock settings for the Virtual Network.
  - **`kind`** (`string`) - Optional
    - **Description:** Type of lock. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional
    - **Description:** Name of the lock.

  - **`notes`** (`string`) - Optional
    - **Description:** Notes for the lock.


- **`name`** (`string`) - Required
  - **Description:** The name of the Virtual Network (vNet).

- **`peerings`** (`array`) - Optional
  - **Description:** Virtual Network peering configurations.
  - **`allowForwardedTraffic`** (`bool`) - Optional
    - **Description:** Allow forwarded traffic from VMs in local VNet. Default is true.

  - **`allowGatewayTransit`** (`bool`) - Optional
    - **Description:** Allow gateway transit from remote VNet. Default is false.

  - **`allowVirtualNetworkAccess`** (`bool`) - Optional
    - **Description:** Allow VMs in local VNet to access VMs in remote VNet. Default is true.

  - **`doNotVerifyRemoteGateways`** (`bool`) - Optional
    - **Description:** Do not verify remote gateway provisioning state. Default is true.

  - **`name`** (`string`) - Optional
    - **Description:** Name of the VNet peering resource. Default: peer-localVnetName-remoteVnetName.

  - **`remotePeeringAllowForwardedTraffic`** (`bool`) - Optional
    - **Description:** Allow forwarded traffic from remote peering. Default is true.

  - **`remotePeeringAllowGatewayTransit`** (`bool`) - Optional
    - **Description:** Allow gateway transit from remote peering. Default is false.

  - **`remotePeeringAllowVirtualNetworkAccess`** (`bool`) - Optional
    - **Description:** Allow virtual network access from remote peering. Default is true.

  - **`remotePeeringDoNotVerifyRemoteGateways`** (`bool`) - Optional
    - **Description:** Do not verify provisioning state of remote peering gateway. Default is true.

  - **`remotePeeringEnabled`** (`bool`) - Optional
    - **Description:** Deploy outbound and inbound peering.

  - **`remotePeeringName`** (`string`) - Optional
    - **Description:** Name of the remote peering resource. Default: peer-remoteVnetName-localVnetName.

  - **`remotePeeringUseRemoteGateways`** (`bool`) - Optional
    - **Description:** Use remote gateways for transit if allowed. Default is false.

  - **`remoteVirtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the remote Virtual Network to peer with.

  - **`useRemoteGateways`** (`bool`) - Optional
    - **Description:** Use remote gateways on this Virtual Network for transit. Default is false.


- **`peerings[*]`** (`object`) - Optional
  - **Description:** Array item for vNetDefinition.peerings

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments to create on the Virtual Network.
  - **`condition`** (`string`) - Optional
    - **Description:** Condition applied to the role assignment.

  - **`conditionVersion`** (`string`) - Optional
    - **Description:** Condition version. Allowed value: 2.0.

  - **`delegatedManagedIdentityResourceId`** (`string`) - Optional
    - **Description:** Resource ID of delegated managed identity.

  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name of the role assignment. If not provided, a GUID will be generated.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID of the user/group/identity to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type. Allowed values: Device, ForeignGroup, Group, ServicePrincipal, User.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role to assign. Accepts role name, role GUID, or fully qualified role definition ID.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for vNetDefinition.roleAssignments

- **`subnets`** (`array`) - Optional
  - **Description:** Array of subnets to deploy in the Virtual Network.
  - **`addressPrefix`** (`string`) - Conditional
    - **Description:** Address prefix for the subnet. Required if addressPrefixes is empty.

  - **`addressPrefixes`** (`array`) - Conditional
    - **Description:** List of address prefixes for the subnet. Required if addressPrefix is empty.

  - **`applicationGatewayIPConfigurations`** (`array`) - Optional
    - **Description:** Application Gateway IP configurations for the subnet.

  - **`defaultOutboundAccess`** (`bool`) - Optional
    - **Description:** Disable default outbound connectivity for all VMs in subnet. Only allowed at creation time.

  - **`delegation`** (`string`) - Optional
    - **Description:** Delegation to enable on the subnet.

  - **`ipamPoolPrefixAllocations`** (`array`) - Conditional
    - **Description:** Address space for subnet from IPAM Pool. Required if both addressPrefix and addressPrefixes are empty and VNet uses IPAM Pool.

  - **`name`** (`string`) - Required
    - **Description:** Name of the subnet.

  - **`natGatewayResourceId`** (`string`) - Optional
    - **Description:** NAT Gateway resource ID for the subnet.

  - **`networkSecurityGroupResourceId`** (`string`) - Optional
    - **Description:** NSG resource ID for the subnet.

  - **`privateEndpointNetworkPolicies`** (`string`) - Optional
    - **Description:** Policy for private endpoint network. Allowed values: Disabled, Enabled, NetworkSecurityGroupEnabled, RouteTableEnabled.

  - **`privateLinkServiceNetworkPolicies`** (`string`) - Optional
    - **Description:** Policy for private link service network. Allowed values: Disabled, Enabled.

  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Role assignments to create on the subnet.
    - **`condition`** (`string`) - Optional
      - **Description:** Condition applied to the role assignment.

    - **`conditionVersion`** (`string`) - Optional
      - **Description:** Condition version. Allowed value: 2.0.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional
      - **Description:** Resource ID of delegated managed identity.

    - **`description`** (`string`) - Optional
      - **Description:** Description of the role assignment.

    - **`name`** (`string`) - Optional
      - **Description:** Name of the role assignment. If not provided, a GUID will be generated.

    - **`principalId`** (`string`) - Required
      - **Description:** Principal ID of the user/group/identity to assign the role to.

    - **`principalType`** (`string`) - Optional
      - **Description:** Principal type. Allowed values: Device, ForeignGroup, Group, ServicePrincipal, User.

    - **`roleDefinitionIdOrName`** (`string`) - Required
      - **Description:** Role to assign. Accepts role name, role GUID, or fully qualified role definition ID.


  - **`roleAssignments[*]`** (`object`) - Optional
    - **Description:** Array item for vNetDefinition.subnets[*].roleAssignments

  - **`routeTableResourceId`** (`string`) - Optional
    - **Description:** Route table resource ID for the subnet.

  - **`serviceEndpointPolicies`** (`array`) - Optional
    - **Description:** Service endpoint policies for the subnet.

  - **`serviceEndpoints`** (`array`) - Optional
    - **Description:** Service endpoints enabled on the subnet.

  - **`sharingScope`** (`string`) - Optional
    - **Description:** Sharing scope for the subnet. Allowed values: DelegatedServices, Tenant.


- **`subnets[*]`** (`object`) - Optional
  - **Description:** Array item for vNetDefinition.subnets
  - **`condition`** (`string`) - Optional
    - **Description:** Condition applied to the role assignment.

  - **`conditionVersion`** (`string`) - Optional
    - **Description:** Condition version. Allowed value: 2.0.

  - **`delegatedManagedIdentityResourceId`** (`string`) - Optional
    - **Description:** Resource ID of delegated managed identity.

  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name of the role assignment. If not provided, a GUID will be generated.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID of the user/group/identity to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type. Allowed values: Device, ForeignGroup, Group, ServicePrincipal, User.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role to assign. Accepts role name, role GUID, or fully qualified role definition ID.


- **`tags`** (`object`) - Optional
  - **Description:** Tags to apply to the Virtual Network.

- **`virtualNetworkBgpCommunity`** (`string`) - Optional
  - **Description:** The BGP community associated with the Virtual Network.

- **`vnetEncryption`** (`bool`) - Optional
  - **Description:** Indicates if encryption is enabled for the Virtual Network. Requires the EnableVNetEncryption feature and a supported region.

- **`vnetEncryptionEnforcement`** (`string`) - Optional
  - **Description:** Enforcement policy for unencrypted VMs in an encrypted VNet. Allowed values: AllowUnencrypted, DropUnencrypted.

### `wafPolicyDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `wafPolicyDefinition` | `object` | Conditional | Web Application Firewall (WAF) policy configuration. Required if deploy.wafPolicy is true and you are deploying Application Gateway via this template. |

**Properties:**

- **`customRules`** (`array`) - Optional
  - **Description:** Custom rules inside the policy.

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable or disable usage telemetry for the module. Default is true.

- **`location`** (`string`) - Optional
  - **Description:** Location for all resources. Default is resourceGroup().location.

- **`managedRules`** (`object`) - Required
  - **Description:** Managed rules configuration (rule sets and exclusions).
  - **`exclusions`** (`array`) - Optional
    - **Description:** Exclusions for specific rules or variables.
    - **`excludedRuleSet`** (`object`) - Optional
      - **Description:** Specific managed rule set exclusion details.
      - **`ruleGroup`** (`array`) - Optional
        - **Description:** Rule groups to exclude.

      - **`ruleSetType`** (`string`) - Required
        - **Description:** Rule set type (e.g., OWASP).

      - **`ruleSetVersion`** (`string`) - Required
        - **Description:** Rule set version (e.g., 3.2).


    - **`matchVariable`** (`string`) - Required
      - **Description:** Match variable to exclude (e.g., RequestHeaderNames).

    - **`selector`** (`string`) - Required
      - **Description:** Selector value for the match variable.

    - **`selectorMatchOperator`** (`string`) - Required
      - **Description:** Selector match operator (e.g., Equals, Contains).


  - **`exclusions[*]`** (`object`) - Optional
    - **Description:** Array item for wafPolicyDefinition.managedRules.exclusions
    - **`ruleGroup`** (`array`) - Optional
      - **Description:** Rule groups to exclude.

    - **`ruleSetType`** (`string`) - Required
      - **Description:** Rule set type (e.g., OWASP).

    - **`ruleSetVersion`** (`string`) - Required
      - **Description:** Rule set version (e.g., 3.2).


  - **`managedRuleSets`** (`array`) - Required
    - **Description:** Managed rule sets to apply.
    - **`ruleGroupOverrides`** (`array`) - Optional
      - **Description:** Overrides for specific rule groups.
      - **`rule`** (`array`) - Required
        - **Description:** Rule overrides within the group.
        - **`action`** (`string`) - Required
          - **Description:** Action to take (e.g., Allow, Block, Log).

        - **`enabled`** (`bool`) - Required
          - **Description:** Whether the rule is enabled.

        - **`id`** (`string`) - Required
          - **Description:** Rule ID.


      - **`rule[*]`** (`object`) - Optional
        - **Description:** Array item for wafPolicyDefinition.managedRules.managedRuleSets[*].ruleGroupOverrides[*].rule

      - **`ruleGroupName`** (`string`) - Required
        - **Description:** Name of the rule group.


    - **`ruleGroupOverrides[*]`** (`object`) - Optional
      - **Description:** Array item for wafPolicyDefinition.managedRules.managedRuleSets[*].ruleGroupOverrides
      - **`action`** (`string`) - Required
        - **Description:** Action to take (e.g., Allow, Block, Log).

      - **`enabled`** (`bool`) - Required
        - **Description:** Whether the rule is enabled.

      - **`id`** (`string`) - Required
        - **Description:** Rule ID.


    - **`ruleSetType`** (`string`) - Required
      - **Description:** Rule set type (e.g., OWASP).

    - **`ruleSetVersion`** (`string`) - Required
      - **Description:** Rule set version.


  - **`managedRuleSets[*]`** (`object`) - Optional
    - **Description:** Array item for wafPolicyDefinition.managedRules.managedRuleSets
    - **`rule`** (`array`) - Required
      - **Description:** Rule overrides within the group.
      - **`action`** (`string`) - Required
        - **Description:** Action to take (e.g., Allow, Block, Log).

      - **`enabled`** (`bool`) - Required
        - **Description:** Whether the rule is enabled.

      - **`id`** (`string`) - Required
        - **Description:** Rule ID.


    - **`rule[*]`** (`object`) - Optional
      - **Description:** Array item for wafPolicyDefinition.managedRules.managedRuleSets[*].ruleGroupOverrides[*].rule

    - **`ruleGroupName`** (`string`) - Required
      - **Description:** Name of the rule group.

    - **`action`** (`string`) - Required
      - **Description:** Action to take (e.g., Allow, Block, Log).

    - **`enabled`** (`bool`) - Required
      - **Description:** Whether the rule is enabled.

    - **`id`** (`string`) - Required
      - **Description:** Rule ID.

    - **`action`** (`string`) - Required
      - **Description:** Action to take (e.g., Allow, Block, Log).

    - **`enabled`** (`bool`) - Required
      - **Description:** Whether the rule is enabled.

    - **`id`** (`string`) - Required
      - **Description:** Rule ID.



- **`name`** (`string`) - Required
  - **Description:** Name of the Application Gateway WAF policy.

- **`policySettings`** (`object`) - Optional
  - **Description:** Policy settings (state, mode, size limits).
  - **`fileUploadLimitInMb`** (`int`) - Required
    - **Description:** File upload size limit (MB).

  - **`maxRequestBodySizeInKb`** (`int`) - Required
    - **Description:** Maximum request body size (KB).

  - **`mode`** (`string`) - Required
    - **Description:** WAF mode (Prevention or Detection).

  - **`requestBodyCheck`** (`bool`) - Required
    - **Description:** Enable request body inspection.

  - **`state`** (`string`) - Required
    - **Description:** WAF policy state.


- **`tags`** (`object`) - Optional
  - **Description:** Resource tags.

### Optional Parameters

### `acrPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `acrPrivateDnsZoneDefinition` | `object` | Optional | Container Registry Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for acrPrivateDnsZoneDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for acrPrivateDnsZoneDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for acrPrivateDnsZoneDefinition.virtualNetworkLinks

### `acrPrivateEndpointDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `acrPrivateEndpointDefinition` | `object` | Optional | Azure Container Registry Private Endpoint configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for acrPrivateEndpointDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for acrPrivateEndpointDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for acrPrivateEndpointDefinition.virtualNetworkLinks

### `aiFoundryDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `aiFoundryDefinition` | `object` | Optional | AI Foundry project configuration (account/project, networking, associated resources, and deployments). |

**Properties:**

- **`aiFoundryConfiguration`** (`object`) - Optional
  - **Description:** Custom configuration for the AI Foundry account.
  - **`accountName`** (`string`) - Optional
    - **Description:** The name of the AI Foundry account.

  - **`allowProjectManagement`** (`bool`) - Optional
    - **Description:** Whether to allow project management in the account. Defaults to true.

  - **`createCapabilityHosts`** (`bool`) - Optional
    - **Description:** Whether to create capability hosts for the AI Agent Service. Requires includeAssociatedResources = true. Defaults to true.

  - **`disableLocalAuth`** (`bool`) - Optional
    - **Description:** Disables local authentication methods so that the account requires Microsoft Entra ID identities exclusively for authentication. Defaults to false for backward compatibility.

  - **`location`** (`string`) - Optional
    - **Description:** Location of the AI Foundry account. Defaults to resource group location.

  - **`networking`** (`object`) - Optional
    - **Description:** Networking configuration for the AI Foundry account and project.
    - **`agentServiceSubnetResourceId`** (`string`) - Optional
      - **Description:** Subnet Resource ID for Azure AI Services. Required if you want to deploy AI Agent Service.

    - **`aiServicesPrivateDnsZoneResourceId`** (`string`) - Required
      - **Description:** Private DNS Zone Resource ID for Azure AI Services.

    - **`cognitiveServicesPrivateDnsZoneResourceId`** (`string`) - Required
      - **Description:** Private DNS Zone Resource ID for Cognitive Services.

    - **`openAiPrivateDnsZoneResourceId`** (`string`) - Required
      - **Description:** Private DNS Zone Resource ID for OpenAI.


  - **`project`** (`object`) - Optional
    - **Description:** Default AI Foundry project.
    - **`description`** (`string`) - Optional
      - **Description:** Project description.

    - **`displayName`** (`string`) - Optional
      - **Description:** Friendly/display name of the project.

    - **`name`** (`string`) - Optional
      - **Description:** Name of the project.


  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Role assignments to apply to the AI Foundry account.

  - **`sku`** (`string`) - Optional
    - **Description:** SKU of the AI Foundry / Cognitive Services account. Defaults to S0.


- **`aiModelDeployments`** (`array`) - Optional
  - **Description:** Specifies the OpenAI deployments to create.
  - **`model`** (`object`) - Required
    - **Description:** Deployment model configuration.
    - **`format`** (`string`) - Required
      - **Description:** Format of the deployment model.

    - **`name`** (`string`) - Required
      - **Description:** Name of the deployment model.

    - **`version`** (`string`) - Required
      - **Description:** Version of the deployment model.


  - **`name`** (`string`) - Optional
    - **Description:** Name of the deployment.

  - **`raiPolicyName`** (`string`) - Optional
    - **Description:** Responsible AI policy name.

  - **`sku`** (`object`) - Optional
    - **Description:** SKU configuration for the deployment.
    - **`capacity`** (`int`) - Optional
      - **Description:** SKU capacity.

    - **`family`** (`string`) - Optional
      - **Description:** SKU family.

    - **`name`** (`string`) - Required
      - **Description:** SKU name.

    - **`size`** (`string`) - Optional
      - **Description:** SKU size.

    - **`tier`** (`string`) - Optional
      - **Description:** SKU tier.


  - **`versionUpgradeOption`** (`string`) - Optional
    - **Description:** Version upgrade option.


- **`aiModelDeployments[*]`** (`object`) - Optional
  - **Description:** Array item for aiFoundryDefinition.aiModelDeployments
  - **`format`** (`string`) - Required
    - **Description:** Format of the deployment model.

  - **`name`** (`string`) - Required
    - **Description:** Name of the deployment model.

  - **`version`** (`string`) - Required
    - **Description:** Version of the deployment model.

  - **`capacity`** (`int`) - Optional
    - **Description:** SKU capacity.

  - **`family`** (`string`) - Optional
    - **Description:** SKU family.

  - **`name`** (`string`) - Required
    - **Description:** SKU name.

  - **`size`** (`string`) - Optional
    - **Description:** SKU size.

  - **`tier`** (`string`) - Optional
    - **Description:** SKU tier.


- **`aiSearchConfiguration`** (`object`) - Optional
  - **Description:** Custom configuration for AI Search.
  - **`existingResourceId`** (`string`) - Optional
    - **Description:** Existing AI Search resource ID. If provided, other properties are ignored.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the AI Search resource.

  - **`privateDnsZoneResourceId`** (`string`) - Optional
    - **Description:** Private DNS Zone Resource ID for AI Search. Required if private endpoints are used.

  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Role assignments for the AI Search resource.


- **`baseName`** (`string`) - Optional
  - **Description:** A friendly application/environment name to serve as the base when using the default naming for all resources in this deployment.

- **`baseUniqueName`** (`string`) - Optional
  - **Description:** A unique text value for the application/environment. Used to ensure resource names are unique for global resources. Defaults to a 5-character substring of the unique string generated from the subscription ID, resource group name, and base name.

- **`cosmosDbConfiguration`** (`object`) - Optional
  - **Description:** Custom configuration for Cosmos DB.
  - **`existingResourceId`** (`string`) - Optional
    - **Description:** Existing Cosmos DB resource ID. If provided, other properties are ignored.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the Cosmos DB resource.

  - **`privateDnsZoneResourceId`** (`string`) - Optional
    - **Description:** Private DNS Zone Resource ID for Cosmos DB. Required if private endpoints are used.

  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Role assignments for the Cosmos DB resource.


- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module. Default is true.

- **`includeAssociatedResources`** (`bool`) - Optional
  - **Description:** Whether to include associated resources (Key Vault, AI Search, Storage Account, Cosmos DB). Defaults to true.

- **`keyVaultConfiguration`** (`object`) - Optional
  - **Description:** Custom configuration for Key Vault.
  - **`existingResourceId`** (`string`) - Optional
    - **Description:** Existing Key Vault resource ID. If provided, other properties are ignored.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the Key Vault.

  - **`privateDnsZoneResourceId`** (`string`) - Optional
    - **Description:** Private DNS Zone Resource ID for Key Vault. Required if private endpoints are used.

  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Role assignments for the Key Vault resource.


- **`location`** (`string`) - Optional
  - **Description:** Location for all resources. Defaults to the resource group location.

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the AI resources.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`privateEndpointSubnetResourceId`** (`string`) - Optional
  - **Description:** The Resource ID of the subnet to establish Private Endpoint(s). If provided, private endpoints will be created for the AI Foundry account and associated resources. Each resource will also require supplied private DNS zone resource ID(s).

- **`storageAccountConfiguration`** (`object`) - Optional
  - **Description:** Custom configuration for Storage Account.
  - **`blobPrivateDnsZoneResourceId`** (`string`) - Optional
    - **Description:** Private DNS Zone Resource ID for blob endpoint. Required if private endpoints are used.

  - **`existingResourceId`** (`string`) - Optional
    - **Description:** Existing Storage Account resource ID. If provided, other properties are ignored.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the Storage Account.

  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Role assignments for the Storage Account.


- **`tags`** (`object`) - Optional
  - **Description:** Specifies the resource tags for all the resources.

### `aiSearchDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `aiSearchDefinition` | `object` | Optional | AI Search settings. |

**Properties:**

- **`authOptions`** (`object`) - Optional
  - **Description:** Defines the options for how the data plane API of a Search service authenticates requests. Must remain {} if disableLocalAuth=true.
  - **`aadOrApiKey`** (`object`) - Optional
    - **Description:** Indicates that either API key or an access token from Microsoft Entra ID can be used for authentication.
    - **`aadAuthFailureMode`** (`string`) - Optional
      - **Description:** Response sent when authentication fails. Allowed values: http401WithBearerChallenge, http403.


  - **`apiKeyOnly`** (`object`) - Optional
    - **Description:** Indicates that only the API key can be used for authentication.


- **`cmkEnforcement`** (`string`) - Optional
  - **Description:** Policy that determines how resources within the search service are encrypted with Customer Managed Keys. Default is Unspecified. Allowed values: Disabled, Enabled, Unspecified.

- **`diagnosticSettings`** (`array`) - Optional
  - **Description:** Diagnostic settings for the search service.
  - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional
    - **Description:** Resource ID of the diagnostic Event Hub authorization rule.

  - **`eventHubName`** (`string`) - Optional
    - **Description:** Name of the diagnostic Event Hub. Without this, one Event Hub per category will be created.

  - **`logAnalyticsDestinationType`** (`string`) - Optional
    - **Description:** Destination type for Log Analytics. Allowed values: AzureDiagnostics, Dedicated.

  - **`logCategoriesAndGroups`** (`array`) - Optional
    - **Description:** Log categories and groups to collect. Use [] to disable.
    - **`category`** (`string`) - Optional
      - **Description:** Diagnostic log category.

    - **`categoryGroup`** (`string`) - Optional
      - **Description:** Diagnostic log category group. Use allLogs to collect all logs.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Enable or disable this log category. Default is true.


  - **`logCategoriesAndGroups[*]`** (`object`) - Optional
    - **Description:** Array item for aiSearchDefinition.diagnosticSettings[*].logCategoriesAndGroups

  - **`marketplacePartnerResourceId`** (`string`) - Optional
    - **Description:** Marketplace partner resource ID to send logs to.

  - **`metricCategories`** (`array`) - Optional
    - **Description:** Metric categories to collect.
    - **`category`** (`string`) - Required
      - **Description:** Diagnostic metric category. Example: AllMetrics.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Enable or disable this metric category. Default is true.


  - **`metricCategories[*]`** (`object`) - Optional
    - **Description:** Array item for aiSearchDefinition.diagnosticSettings[*].metricCategories

  - **`name`** (`string`) - Optional
    - **Description:** Name of the diagnostic setting.

  - **`storageAccountResourceId`** (`string`) - Optional
    - **Description:** Storage account resource ID for diagnostic logs.

  - **`workspaceResourceId`** (`string`) - Optional
    - **Description:** Log Analytics workspace resource ID for diagnostic logs.


- **`diagnosticSettings[*]`** (`object`) - Optional
  - **Description:** Array item for aiSearchDefinition.diagnosticSettings
  - **`category`** (`string`) - Optional
    - **Description:** Diagnostic log category.

  - **`categoryGroup`** (`string`) - Optional
    - **Description:** Diagnostic log category group. Use allLogs to collect all logs.

  - **`enabled`** (`bool`) - Optional
    - **Description:** Enable or disable this log category. Default is true.

  - **`category`** (`string`) - Required
    - **Description:** Diagnostic metric category. Example: AllMetrics.

  - **`enabled`** (`bool`) - Optional
    - **Description:** Enable or disable this metric category. Default is true.


- **`disableLocalAuth`** (`bool`) - Optional
  - **Description:** Disable local authentication via API keys. Cannot be true if authOptions are defined. Default is true.

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/disable usage telemetry for the module. Default is true.

- **`hostingMode`** (`string`) - Optional
  - **Description:** Hosting mode, only for standard3 SKU. Allowed values: default, highDensity. Default is default.

- **`location`** (`string`) - Optional
  - **Description:** Location for all resources. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional
  - **Description:** Lock settings for the search service.
  - **`kind`** (`string`) - Optional
    - **Description:** Type of lock. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional
    - **Description:** Name of the lock.

  - **`notes`** (`string`) - Optional
    - **Description:** Notes for the lock.


- **`managedIdentities`** (`object`) - Optional
  - **Description:** Managed identity definition for the search service.
  - **`systemAssigned`** (`bool`) - Optional
    - **Description:** Enables system-assigned managed identity.

  - **`userAssignedResourceIds`** (`array`) - Optional
    - **Description:** User-assigned identity resource IDs. Required if user-assigned identity is used for encryption.


- **`name`** (`string`) - Required
  - **Description:** The name of the Azure Cognitive Search service to create or update. Must only contain lowercase letters, digits or dashes, cannot use dash as the first two or last one characters, cannot contain consecutive dashes, must be between 2 and 60 characters in length, and must be globally unique. Immutable after creation.

- **`networkRuleSet`** (`object`) - Optional
  - **Description:** Network rules for the search service.
  - **`bypass`** (`string`) - Optional
    - **Description:** Bypass setting. Allowed values: AzurePortal, AzureServices, None.

  - **`ipRules`** (`array`) - Optional
    - **Description:** IP restriction rules applied when publicNetworkAccess=Enabled.
    - **`value`** (`string`) - Required
      - **Description:** IPv4 address (e.g., 123.1.2.3) or range in CIDR format (e.g., 123.1.2.3/24) to allow.


  - **`ipRules[*]`** (`object`) - Optional
    - **Description:** Array item for aiSearchDefinition.networkRuleSet.ipRules


- **`partitionCount`** (`int`) - Optional
  - **Description:** Number of partitions in the search service. Valid values: 1,2,3,4,6,12 (or 1–3 for standard3 highDensity). Default is 1.

- **`privateEndpoints`** (`array`) - Optional
  - **Description:** Configuration details for private endpoints.

- **`publicNetworkAccess`** (`string`) - Optional
  - **Description:** Public network access. Default is Enabled. Allowed values: Enabled, Disabled.

- **`replicaCount`** (`int`) - Optional
  - **Description:** Number of replicas in the search service. Must be 1–12 for Standard SKUs or 1–3 for Basic. Default is 3.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the search service.

- **`secretsExportConfiguration`** (`object`) - Optional
  - **Description:** Key Vault reference and secret settings for exporting admin keys.
  - **`keyVaultResourceId`** (`string`) - Required
    - **Description:** Key Vault resource ID where the API Admin keys will be stored.

  - **`primaryAdminKeyName`** (`string`) - Optional
    - **Description:** Secret name for the primary admin key.

  - **`secondaryAdminKeyName`** (`string`) - Optional
    - **Description:** Secret name for the secondary admin key.


- **`semanticSearch`** (`string`) - Optional
  - **Description:** Semantic search configuration. Allowed values: disabled, free, standard.

- **`sharedPrivateLinkResources`** (`array`) - Optional
  - **Description:** Shared Private Link Resources to create. Default is [].

- **`sku`** (`string`) - Optional
  - **Description:** SKU of the search service. Determines price tier and limits. Default is standard. Allowed values: basic, free, standard, standard2, standard3, storage_optimized_l1, storage_optimized_l2.

- **`tags`** (`object`) - Optional
  - **Description:** Tags for categorizing the search service.

### `aiServicesPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `aiServicesPrivateDnsZoneDefinition` | `object` | Optional | AI Services Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for aiServicesPrivateDnsZoneDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for aiServicesPrivateDnsZoneDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for aiServicesPrivateDnsZoneDefinition.virtualNetworkLinks

### `apimDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `apimDefinition` | `object` | Optional | API Management configuration. |

**Properties:**

- **`additionalLocations`** (`array`) - Optional
  - **Description:** Additional locations for the API Management service.

- **`apiDiagnostics`** (`array`) - Optional
  - **Description:** API diagnostics for APIs.

- **`apis`** (`array`) - Optional
  - **Description:** APIs to create in the API Management service.

- **`apiVersionSets`** (`array`) - Optional
  - **Description:** API version sets to configure.

- **`authorizationServers`** (`array`) - Optional
  - **Description:** Authorization servers to configure.

- **`availabilityZones`** (`array`) - Optional
  - **Description:** Availability Zones for HA deployment.

- **`backends`** (`array`) - Optional
  - **Description:** Backends to configure.

- **`caches`** (`array`) - Optional
  - **Description:** Caches to configure.

- **`certificates`** (`array`) - Optional
  - **Description:** Certificates to configure for API Management. Maximum of 10 certificates.

- **`customProperties`** (`object`) - Optional
  - **Description:** Custom properties to configure.

- **`diagnosticSettings`** (`array`) - Optional
  - **Description:** Diagnostic settings for the API Management service.

- **`disableGateway`** (`bool`) - Optional
  - **Description:** Disable gateway in a region (for multi-region setup).

- **`enableClientCertificate`** (`bool`) - Optional
  - **Description:** Enable client certificate for requests (Consumption SKU only).

- **`enableDeveloperPortal`** (`bool`) - Optional
  - **Description:** Enable developer portal for the service.

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/disable usage telemetry for module. Default is true.

- **`hostnameConfigurations`** (`array`) - Optional
  - **Description:** Hostname configurations for the API Management service.

- **`identityProviders`** (`array`) - Optional
  - **Description:** Identity providers to configure.

- **`location`** (`string`) - Optional
  - **Description:** Location for the API Management service. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional
  - **Description:** Lock settings for the API Management service.
  - **`kind`** (`string`) - Optional
    - **Description:** Type of lock. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional
    - **Description:** Name of the lock.

  - **`notes`** (`string`) - Optional
    - **Description:** Notes for the lock.


- **`loggers`** (`array`) - Optional
  - **Description:** Loggers to configure.

- **`managedIdentities`** (`object`) - Optional
  - **Description:** Managed identity settings for the API Management service.
  - **`systemAssigned`** (`bool`) - Optional
    - **Description:** Enables system-assigned managed identity.

  - **`userAssignedResourceIds`** (`array`) - Optional
    - **Description:** User-assigned identity resource IDs.


- **`minApiVersion`** (`string`) - Optional
  - **Description:** Minimum ARM API version to use for control-plane operations.

- **`name`** (`string`) - Required
  - **Description:** Name of the API Management service.

- **`namedValues`** (`array`) - Optional
  - **Description:** Named values to configure.

- **`newGuidValue`** (`string`) - Optional
  - **Description:** Helper for generating new GUID values.

- **`notificationSenderEmail`** (`string`) - Optional
  - **Description:** Notification sender email address.

- **`policies`** (`array`) - Optional
  - **Description:** Policies to configure.

- **`portalsettings`** (`array`) - Optional
  - **Description:** Portal settings for the developer portal.

- **`products`** (`array`) - Optional
  - **Description:** Products to configure.

- **`publicIpAddressResourceId`** (`string`) - Optional
  - **Description:** Public IP address resource ID for API Management.

- **`publisherEmail`** (`string`) - Required
  - **Description:** Publisher email address.

- **`publisherName`** (`string`) - Required
  - **Description:** Publisher display name.

- **`restore`** (`bool`) - Optional
  - **Description:** Restore configuration for undeleting API Management services.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the API Management service.

- **`sku`** (`string`) - Optional
  - **Description:** SKU of the API Management service. Allowed values: Basic, BasicV2, Consumption, Developer, Premium, Standard, StandardV2.

- **`skuCapacity`** (`int`) - Conditional
  - **Description:** SKU capacity. Required if SKU is not Consumption.

- **`subnetResourceId`** (`string`) - Optional
  - **Description:** Subnet resource ID for VNet integration.

- **`subscriptions`** (`array`) - Optional
  - **Description:** Subscriptions to configure.

- **`tags`** (`object`) - Optional
  - **Description:** Tags to apply to the API Management service.

- **`virtualNetworkType`** (`string`) - Optional
  - **Description:** Virtual network type. Allowed values: None, External, Internal.

### `apimPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `apimPrivateDnsZoneDefinition` | `object` | Optional | API Management Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for apimPrivateDnsZoneDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for apimPrivateDnsZoneDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for apimPrivateDnsZoneDefinition.virtualNetworkLinks

### `apimPrivateEndpointDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `apimPrivateEndpointDefinition` | `object` | Optional | API Management Private Endpoint configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for apimPrivateEndpointDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for apimPrivateEndpointDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for apimPrivateEndpointDefinition.virtualNetworkLinks

### `appConfigPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `appConfigPrivateDnsZoneDefinition` | `object` | Optional | App Configuration Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for appConfigPrivateDnsZoneDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for appConfigPrivateDnsZoneDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for appConfigPrivateDnsZoneDefinition.virtualNetworkLinks

### `appConfigPrivateEndpointDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `appConfigPrivateEndpointDefinition` | `object` | Optional | App Configuration Private Endpoint configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for appConfigPrivateEndpointDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for appConfigPrivateEndpointDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for appConfigPrivateEndpointDefinition.virtualNetworkLinks

### `appInsightsPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `appInsightsPrivateDnsZoneDefinition` | `object` | Optional | Application Insights Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for appInsightsPrivateDnsZoneDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for appInsightsPrivateDnsZoneDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for appInsightsPrivateDnsZoneDefinition.virtualNetworkLinks

### `baseName`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `baseName` | `string` | Optional | Base name to seed resource names; defaults to a 12-char token. |

### `blobPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `blobPrivateDnsZoneDefinition` | `object` | Optional | Blob Storage Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for blobPrivateDnsZoneDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for blobPrivateDnsZoneDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for blobPrivateDnsZoneDefinition.virtualNetworkLinks

### `buildVmMaintenanceDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `buildVmMaintenanceDefinition` | `object` | Optional | Build VM Maintenance Definition. Used when deploy.buildVm is true. |

**Properties:**

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable or disable usage telemetry for the module. Default is true.

- **`extensionProperties`** (`object`) - Optional
  - **Description:** Extension properties of the Maintenance Configuration.

- **`installPatches`** (`object`) - Optional
  - **Description:** Configuration settings for VM guest patching with Azure Update Manager.

- **`location`** (`string`) - Optional
  - **Description:** Resource location. Defaults to the resource group location.

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Maintenance Configuration.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`maintenanceScope`** (`string`) - Optional
  - **Description:** Maintenance scope of the configuration. Default is Host.

- **`maintenanceWindow`** (`object`) - Optional
  - **Description:** Definition of the Maintenance Window.

- **`name`** (`string`) - Required
  - **Description:** Name of the Maintenance Configuration.

- **`namespace`** (`string`) - Optional
  - **Description:** Namespace of the resource.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments to apply to the Maintenance Configuration.
  - **`condition`** (`string`) - Optional
    - **Description:** Condition for the role assignment.

  - **`conditionVersion`** (`string`) - Optional
    - **Description:** Condition version.

  - **`delegatedManagedIdentityResourceId`** (`string`) - Optional
    - **Description:** Delegated managed identity resource ID.

  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Role assignment name (GUID). If omitted, a GUID is generated.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID of the identity being assigned.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type of the assigned identity.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role to assign (display name, GUID, or full resource ID).


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for buildVmMaintenanceDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags to apply to the Maintenance Configuration resource.

- **`visibility`** (`string`) - Optional
  - **Description:** Visibility of the configuration. Default is Custom.

### `cognitiveServicesPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `cognitiveServicesPrivateDnsZoneDefinition` | `object` | Optional | Cognitive Services Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for cognitiveServicesPrivateDnsZoneDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for cognitiveServicesPrivateDnsZoneDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for cognitiveServicesPrivateDnsZoneDefinition.virtualNetworkLinks

### `containerAppEnvPrivateEndpointDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `containerAppEnvPrivateEndpointDefinition` | `object` | Optional | Container Apps Environment Private Endpoint configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for containerAppEnvPrivateEndpointDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for containerAppEnvPrivateEndpointDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for containerAppEnvPrivateEndpointDefinition.virtualNetworkLinks

### `containerAppsList`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `containerAppsList` | `array` | Optional | List of Container Apps to create. |

### `containerAppsPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `containerAppsPrivateDnsZoneDefinition` | `object` | Optional | Container Apps Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for containerAppsPrivateDnsZoneDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for containerAppsPrivateDnsZoneDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for containerAppsPrivateDnsZoneDefinition.virtualNetworkLinks

### `cosmosDbDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `cosmosDbDefinition` | `object` | Optional | Cosmos DB settings. |

**Properties:**

- **`automaticFailover`** (`bool`) - Optional
  - **Description:** Enable automatic failover for regions. Defaults to true.

- **`backupIntervalInMinutes`** (`int`) - Optional
  - **Description:** Interval in minutes between two backups (periodic only). Defaults to 240. Range: 60–1440.

- **`backupPolicyContinuousTier`** (`string`) - Optional
  - **Description:** Retention period for continuous mode backup. Default is Continuous30Days. Allowed values: Continuous30Days, Continuous7Days.

- **`backupPolicyType`** (`string`) - Optional
  - **Description:** Backup mode. Periodic must be used if multiple write locations are enabled. Default is Continuous. Allowed values: Continuous, Periodic.

- **`backupRetentionIntervalInHours`** (`int`) - Optional
  - **Description:** Time (hours) each backup is retained (periodic only). Default is 8. Range: 2–720.

- **`backupStorageRedundancy`** (`string`) - Optional
  - **Description:** Type of backup residency (periodic only). Default is Local. Allowed values: Geo, Local, Zone.

- **`capabilitiesToAdd`** (`array`) - Optional
  - **Description:** List of Cosmos DB specific capabilities to enable.

- **`databaseAccountOfferType`** (`string`) - Optional
  - **Description:** The offer type for the account. Default is Standard. Allowed value: Standard.

- **`dataPlaneRoleAssignments`** (`array`) - Optional
  - **Description:** Cosmos DB for NoSQL native role-based access control assignments.
  - **`name`** (`string`) - Optional
    - **Description:** Unique name of the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** The Microsoft Entra principal ID granted access by this assignment.

  - **`roleDefinitionId`** (`string`) - Required
    - **Description:** The unique identifier of the NoSQL native role definition.


- **`dataPlaneRoleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for cosmosDbDefinition.dataPlaneRoleAssignments

- **`dataPlaneRoleDefinitions`** (`array`) - Optional
  - **Description:** Cosmos DB for NoSQL native role-based access control definitions.
  - **`assignableScopes`** (`array`) - Optional
    - **Description:** Assignable scopes for the definition.

  - **`assignments`** (`array`) - Optional
    - **Description:** Assignments associated with this role definition.
    - **`name`** (`string`) - Optional
      - **Description:** Unique identifier name for the role assignment.

    - **`principalId`** (`string`) - Required
      - **Description:** The Microsoft Entra principal ID granted access by this role assignment.


  - **`assignments[*]`** (`object`) - Optional
    - **Description:** Array item for cosmosDbDefinition.dataPlaneRoleDefinitions[*].assignments

  - **`dataActions`** (`array`) - Optional
    - **Description:** Array of allowed data actions.

  - **`name`** (`string`) - Optional
    - **Description:** Unique identifier for the role definition.

  - **`roleName`** (`string`) - Required
    - **Description:** A user-friendly unique name for the role definition.


- **`dataPlaneRoleDefinitions[*]`** (`object`) - Optional
  - **Description:** Array item for cosmosDbDefinition.dataPlaneRoleDefinitions
  - **`name`** (`string`) - Optional
    - **Description:** Unique identifier name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** The Microsoft Entra principal ID granted access by this role assignment.


- **`defaultConsistencyLevel`** (`string`) - Optional
  - **Description:** Default consistency level. Default is Session. Allowed values: BoundedStaleness, ConsistentPrefix, Eventual, Session, Strong.

- **`diagnosticSettings`** (`array`) - Optional
  - **Description:** Diagnostic settings for the Cosmos DB account.

- **`disableKeyBasedMetadataWriteAccess`** (`bool`) - Optional
  - **Description:** Disable write operations on metadata resources via account keys. Default is true.

- **`disableLocalAuthentication`** (`bool`) - Optional
  - **Description:** Opt-out of local authentication, enforcing Microsoft Entra-only auth. Default is true.

- **`enableAnalyticalStorage`** (`bool`) - Optional
  - **Description:** Enable analytical storage. Default is false.

- **`enableFreeTier`** (`bool`) - Optional
  - **Description:** Enable Free Tier. Default is false.

- **`enableMultipleWriteLocations`** (`bool`) - Optional
  - **Description:** Enable multiple write locations. Requires periodic backup. Default is false.

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry. Default is true.

- **`failoverLocations`** (`array`) - Optional
  - **Description:** Failover locations configuration.
  - **`failoverPriority`** (`int`) - Required
    - **Description:** Failover priority. 0 = write region.

  - **`isZoneRedundant`** (`bool`) - Optional
    - **Description:** Zone redundancy flag for region. Default is true.

  - **`locationName`** (`string`) - Required
    - **Description:** Region name.


- **`failoverLocations[*]`** (`object`) - Optional
  - **Description:** Array item for cosmosDbDefinition.failoverLocations

- **`gremlinDatabases`** (`array`) - Optional
  - **Description:** Gremlin database configurations.

- **`location`** (`string`) - Optional
  - **Description:** Location for the account. Defaults to resourceGroup().location.

- **`lock`** (`object`) - Optional
  - **Description:** Lock settings for the Cosmos DB account.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`managedIdentities`** (`object`) - Optional
  - **Description:** Managed identity configuration.
  - **`systemAssigned`** (`bool`) - Optional
    - **Description:** Enables system-assigned identity.

  - **`userAssignedResourceIds`** (`array`) - Optional
    - **Description:** User-assigned identity resource IDs.


- **`maxIntervalInSeconds`** (`int`) - Optional
  - **Description:** Maximum lag time in seconds (BoundedStaleness). Defaults to 300.

- **`maxStalenessPrefix`** (`int`) - Optional
  - **Description:** Maximum stale requests (BoundedStaleness). Defaults to 100000.

- **`minimumTlsVersion`** (`string`) - Optional
  - **Description:** Minimum allowed TLS version. Default is Tls12.

- **`mongodbDatabases`** (`array`) - Optional
  - **Description:** MongoDB database configurations.

- **`name`** (`string`) - Required
  - **Description:** The name of the account.

- **`networkRestrictions`** (`object`) - Optional
  - **Description:** Network restrictions for the Cosmos DB account.

- **`privateEndpoints`** (`array`) - Optional
  - **Description:** Private endpoint configurations for secure connectivity.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Control plane Azure role assignments for Cosmos DB.

- **`serverVersion`** (`string`) - Optional
  - **Description:** MongoDB server version (if using MongoDB API). Default is 4.2.

- **`sqlDatabases`** (`array`) - Optional
  - **Description:** SQL (NoSQL) database configurations.

- **`tables`** (`array`) - Optional
  - **Description:** Table API database configurations.

- **`tags`** (`object`) - Optional
  - **Description:** Tags to apply to the Cosmos DB account.

- **`totalThroughputLimit`** (`int`) - Optional
  - **Description:** Total throughput limit in RU/s. Default is unlimited (-1).

- **`zoneRedundant`** (`bool`) - Optional
  - **Description:** Zone redundancy for single-region accounts. Default is true.

### `cosmosPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `cosmosPrivateDnsZoneDefinition` | `object` | Optional | Cosmos DB Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for cosmosPrivateDnsZoneDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for cosmosPrivateDnsZoneDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for cosmosPrivateDnsZoneDefinition.virtualNetworkLinks

### `cosmosPrivateEndpointDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `cosmosPrivateEndpointDefinition` | `object` | Optional | Cosmos DB Private Endpoint configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for cosmosPrivateEndpointDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for cosmosPrivateEndpointDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for cosmosPrivateEndpointDefinition.virtualNetworkLinks

### `enableTelemetry`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `enableTelemetry` | `bool` | Optional | Enable/Disable usage telemetry for module. |

### `existingVNetSubnetsDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `existingVNetSubnetsDefinition` | `object` | Optional | Configuration for adding subnets to an existing VNet. Use this when you want to deploy subnets to an existing VNet instead of creating a new one. |

**Properties:**

- **`existingVNetName`** (`string`) - Required
  - **Description:** Name or Resource ID of the existing Virtual Network. For cross-subscription/resource group scenarios, use the full Resource ID format: /subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Network/virtualNetworks/{vnet-name}

- **`subnets`** (`array`) - Optional
  - **Description:** Array of custom subnets to add to the existing VNet. If not provided and useDefaultSubnets is true, uses default AI Landing Zone subnets.
  - **`addressPrefix`** (`string`) - Conditional
    - **Description:** Address prefix for the subnet. Required if addressPrefixes is empty.

  - **`addressPrefixes`** (`array`) - Conditional
    - **Description:** List of address prefixes for the subnet. Required if addressPrefix is empty.

  - **`applicationGatewayIPConfigurations`** (`array`) - Optional
    - **Description:** Application Gateway IP configurations for the subnet.

  - **`defaultOutboundAccess`** (`bool`) - Optional
    - **Description:** Disable default outbound connectivity for all VMs in subnet.

  - **`delegation`** (`string`) - Optional
    - **Description:** Delegation to enable on the subnet.

  - **`name`** (`string`) - Required
    - **Description:** Name of the subnet.

  - **`natGatewayResourceId`** (`string`) - Optional
    - **Description:** NAT Gateway resource ID for the subnet.

  - **`networkSecurityGroupResourceId`** (`string`) - Optional
    - **Description:** NSG resource ID for the subnet.

  - **`privateEndpointNetworkPolicies`** (`string`) - Optional
    - **Description:** Policy for private endpoint network.

  - **`privateLinkServiceNetworkPolicies`** (`string`) - Optional
    - **Description:** Policy for private link service network.

  - **`routeTableResourceId`** (`string`) - Optional
    - **Description:** Route table resource ID for the subnet.

  - **`serviceEndpointPolicies`** (`array`) - Optional
    - **Description:** Service endpoint policies for the subnet.

  - **`serviceEndpoints`** (`array`) - Optional
    - **Description:** Service endpoints enabled on the subnet.

  - **`sharingScope`** (`string`) - Optional
    - **Description:** Sharing scope for the subnet.


- **`subnets[*]`** (`object`) - Optional
  - **Description:** Array item for existingVNetSubnetsDefinition.subnets

- **`useDefaultSubnets`** (`bool`) - Optional
  - **Description:** Use default AI Landing Zone subnets with 192.168.x.x addressing. Default: true.

### `flagPlatformLandingZone`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `flagPlatformLandingZone` | `bool` | Optional | Enable platform landing zone integration. When true, private DNS zones and private endpoints are managed by the platform landing zone. |

### `hubVnetPeeringDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `hubVnetPeeringDefinition` | `object` | Optional | Hub VNet peering configuration. Configure this to establish hub-spoke peering topology. |

### `jumpVmMaintenanceDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `jumpVmMaintenanceDefinition` | `object` | Optional | Jump VM Maintenance Definition. Used when deploy.jumpVm is true. |

**Properties:**

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable or disable usage telemetry for the module. Default is true.

- **`extensionProperties`** (`object`) - Optional
  - **Description:** Extension properties of the Maintenance Configuration.

- **`installPatches`** (`object`) - Optional
  - **Description:** Configuration settings for VM guest patching with Azure Update Manager.

- **`location`** (`string`) - Optional
  - **Description:** Resource location. Defaults to the resource group location.

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Maintenance Configuration.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`maintenanceScope`** (`string`) - Optional
  - **Description:** Maintenance scope of the configuration. Default is Host.

- **`maintenanceWindow`** (`object`) - Optional
  - **Description:** Definition of the Maintenance Window.

- **`name`** (`string`) - Required
  - **Description:** Name of the Maintenance Configuration.

- **`namespace`** (`string`) - Optional
  - **Description:** Namespace of the resource.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments to apply to the Maintenance Configuration.
  - **`condition`** (`string`) - Optional
    - **Description:** Condition for the role assignment.

  - **`conditionVersion`** (`string`) - Optional
    - **Description:** Condition version.

  - **`delegatedManagedIdentityResourceId`** (`string`) - Optional
    - **Description:** Delegated managed identity resource ID.

  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Role assignment name (GUID). If omitted, a GUID is generated.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID of the identity being assigned.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type of the assigned identity.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role to assign (display name, GUID, or full resource ID).


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for jumpVmMaintenanceDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags to apply to the Maintenance Configuration resource.

- **`visibility`** (`string`) - Optional
  - **Description:** Visibility of the configuration. Default is Custom.

### `keyVaultDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `keyVaultDefinition` | `object` | Optional | Key Vault settings. |

**Properties:**

- **`accessPolicies`** (`array`) - Optional
  - **Description:** All access policies to create.
  - **`applicationId`** (`string`) - Optional
    - **Description:** Application ID of the client making request on behalf of a principal.

  - **`objectId`** (`string`) - Required
    - **Description:** The object ID of a user, service principal or security group in the tenant for the vault.

  - **`permissions`** (`object`) - Required
    - **Description:** Permissions the identity has for keys, secrets and certificates.
    - **`certificates`** (`array`) - Optional
      - **Description:** Permissions to certificates.

    - **`keys`** (`array`) - Optional
      - **Description:** Permissions to keys.

    - **`secrets`** (`array`) - Optional
      - **Description:** Permissions to secrets.

    - **`storage`** (`array`) - Optional
      - **Description:** Permissions to storage accounts.


  - **`tenantId`** (`string`) - Optional
    - **Description:** The tenant ID that is used for authenticating requests to the key vault.


- **`accessPolicies[*]`** (`object`) - Optional
  - **Description:** Array item for keyVaultDefinition.accessPolicies
  - **`certificates`** (`array`) - Optional
    - **Description:** Permissions to certificates.

  - **`keys`** (`array`) - Optional
    - **Description:** Permissions to keys.

  - **`secrets`** (`array`) - Optional
    - **Description:** Permissions to secrets.

  - **`storage`** (`array`) - Optional
    - **Description:** Permissions to storage accounts.


- **`createMode`** (`string`) - Optional
  - **Description:** The vault's create mode to indicate whether the vault needs to be recovered or not.

- **`diagnosticSettings`** (`array`) - Optional
  - **Description:** The diagnostic settings of the service.

- **`enablePurgeProtection`** (`bool`) - Optional
  - **Description:** Provide true to enable Key Vault purge protection feature.

- **`enableRbacAuthorization`** (`bool`) - Optional
  - **Description:** Controls how data actions are authorized. When true, RBAC is used for authorization.

- **`enableSoftDelete`** (`bool`) - Optional
  - **Description:** Switch to enable/disable Key Vault soft delete feature.

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for module.

- **`enableVaultForDeployment`** (`bool`) - Optional
  - **Description:** Specifies if the vault is enabled for deployment by script or compute.

- **`enableVaultForDiskEncryption`** (`bool`) - Optional
  - **Description:** Specifies if the platform has access to the vault for disk encryption scenarios.

- **`enableVaultForTemplateDeployment`** (`bool`) - Optional
  - **Description:** Specifies if the vault is enabled for a template deployment.

- **`keys`** (`array`) - Optional
  - **Description:** All keys to create.

- **`location`** (`string`) - Optional
  - **Description:** Location for all resources.

- **`lock`** (`object`) - Optional
  - **Description:** The lock settings of the service.
  - **`kind`** (`string`) - Optional
    - **Description:** Specify the type of lock.

  - **`name`** (`string`) - Optional
    - **Description:** Specify the name of the lock.

  - **`notes`** (`string`) - Optional
    - **Description:** Specify the notes of the lock.


- **`name`** (`string`) - Required
  - **Description:** Name of the Key Vault. Must be globally unique.

- **`networkAcls`** (`object`) - Optional
  - **Description:** Rules governing the accessibility of the resource from specific networks.

- **`privateEndpoints`** (`array`) - Optional
  - **Description:** Configuration details for private endpoints.
  - **`applicationSecurityGroupResourceIds`** (`array`) - Optional
    - **Description:** Application security groups in which the Private Endpoint IP configuration is included.

  - **`customDnsConfigs`** (`array`) - Optional
    - **Description:** Custom DNS configurations.
    - **`fqdn`** (`string`) - Optional
      - **Description:** FQDN that resolves to private endpoint IP address.

    - **`ipAddresses`** (`array`) - Required
      - **Description:** A list of private IP addresses of the private endpoint.


  - **`customDnsConfigs[*]`** (`object`) - Optional
    - **Description:** Array item for keyVaultDefinition.privateEndpoints[*].customDnsConfigs

  - **`customNetworkInterfaceName`** (`string`) - Optional
    - **Description:** The custom name of the network interface attached to the Private Endpoint.

  - **`enableTelemetry`** (`bool`) - Optional
    - **Description:** Enable/Disable usage telemetry for module.

  - **`ipConfigurations`** (`array`) - Optional
    - **Description:** A list of IP configurations of the Private Endpoint.
    - **`name`** (`string`) - Required
      - **Description:** The name of the resource that is unique within a resource group.

    - **`properties`** (`object`) - Required
      - **Description:** Properties of private endpoint IP configurations.
      - **`groupId`** (`string`) - Required
        - **Description:** The ID of a group obtained from the remote resource to connect to.

      - **`memberName`** (`string`) - Required
        - **Description:** The member name of a group obtained from the remote resource.

      - **`privateIPAddress`** (`string`) - Required
        - **Description:** A private IP address obtained from the private endpoint's subnet.



  - **`ipConfigurations[*]`** (`object`) - Optional
    - **Description:** Array item for keyVaultDefinition.privateEndpoints[*].ipConfigurations
    - **`groupId`** (`string`) - Required
      - **Description:** The ID of a group obtained from the remote resource to connect to.

    - **`memberName`** (`string`) - Required
      - **Description:** The member name of a group obtained from the remote resource.

    - **`privateIPAddress`** (`string`) - Required
      - **Description:** A private IP address obtained from the private endpoint's subnet.


  - **`isManualConnection`** (`bool`) - Optional
    - **Description:** If Manual Private Link Connection is required.

  - **`location`** (`string`) - Optional
    - **Description:** The location to deploy the Private Endpoint to.

  - **`lock`** (`object`) - Optional
    - **Description:** Lock settings for the Private Endpoint.
    - **`kind`** (`string`) - Optional
      - **Description:** Specify the type of lock.

    - **`name`** (`string`) - Optional
      - **Description:** Specify the name of the lock.

    - **`notes`** (`string`) - Optional
      - **Description:** Specify the notes of the lock.


  - **`manualConnectionRequestMessage`** (`string`) - Optional
    - **Description:** A message passed with the manual connection request.

  - **`name`** (`string`) - Optional
    - **Description:** The name of the Private Endpoint.

  - **`privateDnsZoneGroup`** (`object`) - Optional
    - **Description:** The private DNS zone group to configure for the Private Endpoint.
    - **`name`** (`string`) - Optional
      - **Description:** The name of the Private DNS Zone Group.

    - **`privateDnsZoneGroupConfigs`** (`array`) - Required
      - **Description:** The private DNS Zone Groups to associate the Private Endpoint.
      - **`name`** (`string`) - Optional
        - **Description:** The name of the private DNS Zone Group config.

      - **`privateDnsZoneResourceId`** (`string`) - Required
        - **Description:** The resource ID of the private DNS zone.


    - **`privateDnsZoneGroupConfigs[*]`** (`object`) - Optional
      - **Description:** Array item for keyVaultDefinition.privateEndpoints[*].privateDnsZoneGroup.privateDnsZoneGroupConfigs


  - **`privateLinkServiceConnectionName`** (`string`) - Optional
    - **Description:** The name of the private link connection to create.

  - **`resourceGroupResourceId`** (`string`) - Optional
    - **Description:** The resource ID of the Resource Group the Private Endpoint will be created in.

  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Array of role assignments to create for the Private Endpoint.

  - **`service`** (`string`) - Optional
    - **Description:** The subresource to deploy the Private Endpoint for (e.g., vault).

  - **`subnetResourceId`** (`string`) - Required
    - **Description:** Resource ID of the subnet where the endpoint needs to be created.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the Private Endpoint.


- **`privateEndpoints[*]`** (`object`) - Optional
  - **Description:** Array item for keyVaultDefinition.privateEndpoints
  - **`fqdn`** (`string`) - Optional
    - **Description:** FQDN that resolves to private endpoint IP address.

  - **`ipAddresses`** (`array`) - Required
    - **Description:** A list of private IP addresses of the private endpoint.

  - **`name`** (`string`) - Required
    - **Description:** The name of the resource that is unique within a resource group.

  - **`properties`** (`object`) - Required
    - **Description:** Properties of private endpoint IP configurations.
    - **`groupId`** (`string`) - Required
      - **Description:** The ID of a group obtained from the remote resource to connect to.

    - **`memberName`** (`string`) - Required
      - **Description:** The member name of a group obtained from the remote resource.

    - **`privateIPAddress`** (`string`) - Required
      - **Description:** A private IP address obtained from the private endpoint's subnet.


  - **`groupId`** (`string`) - Required
    - **Description:** The ID of a group obtained from the remote resource to connect to.

  - **`memberName`** (`string`) - Required
    - **Description:** The member name of a group obtained from the remote resource.

  - **`privateIPAddress`** (`string`) - Required
    - **Description:** A private IP address obtained from the private endpoint's subnet.

  - **`groupId`** (`string`) - Required
    - **Description:** The ID of a group obtained from the remote resource to connect to.

  - **`memberName`** (`string`) - Required
    - **Description:** The member name of a group obtained from the remote resource.

  - **`privateIPAddress`** (`string`) - Required
    - **Description:** A private IP address obtained from the private endpoint's subnet.

  - **`kind`** (`string`) - Optional
    - **Description:** Specify the type of lock.

  - **`name`** (`string`) - Optional
    - **Description:** Specify the name of the lock.

  - **`notes`** (`string`) - Optional
    - **Description:** Specify the notes of the lock.

  - **`name`** (`string`) - Optional
    - **Description:** The name of the Private DNS Zone Group.

  - **`privateDnsZoneGroupConfigs`** (`array`) - Required
    - **Description:** The private DNS Zone Groups to associate the Private Endpoint.
    - **`name`** (`string`) - Optional
      - **Description:** The name of the private DNS Zone Group config.

    - **`privateDnsZoneResourceId`** (`string`) - Required
      - **Description:** The resource ID of the private DNS zone.


  - **`privateDnsZoneGroupConfigs[*]`** (`object`) - Optional
    - **Description:** Array item for keyVaultDefinition.privateEndpoints[*].privateDnsZoneGroup.privateDnsZoneGroupConfigs

  - **`name`** (`string`) - Optional
    - **Description:** The name of the private DNS Zone Group config.

  - **`privateDnsZoneResourceId`** (`string`) - Required
    - **Description:** The resource ID of the private DNS zone.


- **`publicNetworkAccess`** (`string`) - Optional
  - **Description:** Whether or not public network access is allowed for this resource.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Array of role assignments to create at the vault level.

- **`secrets`** (`array`) - Optional
  - **Description:** All secrets to create.
  - **`attributes`** (`object`) - Optional
    - **Description:** Contains attributes of the secret.
    - **`enabled`** (`bool`) - Optional
      - **Description:** Defines whether the secret is enabled or disabled.

    - **`exp`** (`int`) - Optional
      - **Description:** Expiration time of the secret, in epoch seconds.

    - **`nbf`** (`int`) - Optional
      - **Description:** Not-before time of the secret, in epoch seconds.


  - **`contentType`** (`string`) - Optional
    - **Description:** The content type of the secret.

  - **`name`** (`string`) - Required
    - **Description:** The name of the secret.

  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Array of role assignments to create for the secret.

  - **`tags`** (`object`) - Optional
    - **Description:** Resource tags for the secret.

  - **`value`** (`securestring`) - Required
    - **Description:** The value of the secret.


- **`secrets[*]`** (`object`) - Optional
  - **Description:** Array item for keyVaultDefinition.secrets
  - **`enabled`** (`bool`) - Optional
    - **Description:** Defines whether the secret is enabled or disabled.

  - **`exp`** (`int`) - Optional
    - **Description:** Expiration time of the secret, in epoch seconds.

  - **`nbf`** (`int`) - Optional
    - **Description:** Not-before time of the secret, in epoch seconds.


- **`sku`** (`string`) - Optional
  - **Description:** Specifies the SKU for the vault.

- **`softDeleteRetentionInDays`** (`int`) - Optional
  - **Description:** Soft delete retention days (between 7 and 90).

- **`tags`** (`object`) - Optional
  - **Description:** Resource tags for the vault.

### `keyVaultPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `keyVaultPrivateDnsZoneDefinition` | `object` | Optional | Key Vault Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for keyVaultPrivateDnsZoneDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for keyVaultPrivateDnsZoneDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for keyVaultPrivateDnsZoneDefinition.virtualNetworkLinks

### `keyVaultPrivateEndpointDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `keyVaultPrivateEndpointDefinition` | `object` | Optional | Key Vault Private Endpoint configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for keyVaultPrivateEndpointDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for keyVaultPrivateEndpointDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for keyVaultPrivateEndpointDefinition.virtualNetworkLinks

### `location`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `location` | `string` | Optional | Azure region for AI LZ resources. Defaults to the resource group location. |

### `nsgDefinitions`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `nsgDefinitions` | `object` | Optional | NSG definitions per subnet role; each entry deploys an NSG for that subnet when a non-empty NSG definition is provided. |

**Properties:**

- **`acaEnvironment`** (`object`) - Optional
  - **Description:** NSG definition applied to the Azure Container Apps environment (infrastructure) subnet.
  - **`diagnosticSettings`** (`array`) - Optional
    - **Description:** Diagnostic settings to send NSG logs/metrics to Log Analytics, Event Hub, or Storage.
    - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional
      - **Description:** Destination Event Hub authorization rule resource ID.

    - **`eventHubName`** (`string`) - Optional
      - **Description:** Destination Event Hub name when sending to Event Hub.

    - **`logAnalyticsDestinationType`** (`string`) - Optional
      - **Description:** Destination type for Log Analytics (AzureDiagnostics or Dedicated).

    - **`logCategoriesAndGroups`** (`array`) - Optional
      - **Description:** List of categories and/or category groups to enable.
      - **`category`** (`string`) - Optional
        - **Description:** Single diagnostic log category to enable.

      - **`categoryGroup`** (`string`) - Optional
        - **Description:** Category group (e.g., AllMetrics) to enable.

      - **`enabled`** (`bool`) - Optional
        - **Description:** Whether this category/category group is enabled.


    - **`logCategoriesAndGroups[*]`** (`object`) - Optional
      - **Description:** Array item for nsgDefinitions.acaEnvironment.diagnosticSettings[*].logCategoriesAndGroups

    - **`marketplacePartnerResourceId`** (`string`) - Optional
      - **Description:** Marketplace partner destination resource ID (if applicable).

    - **`name`** (`string`) - Optional
      - **Description:** Name of the diagnostic settings resource.

    - **`storageAccountResourceId`** (`string`) - Optional
      - **Description:** Destination Storage Account resource ID.

    - **`workspaceResourceId`** (`string`) - Optional
      - **Description:** Destination Log Analytics workspace resource ID.


  - **`diagnosticSettings[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.acaEnvironment.diagnosticSettings
    - **`category`** (`string`) - Optional
      - **Description:** Single diagnostic log category to enable.

    - **`categoryGroup`** (`string`) - Optional
      - **Description:** Category group (e.g., AllMetrics) to enable.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Whether this category/category group is enabled.


  - **`enableTelemetry`** (`bool`) - Optional
    - **Description:** Enable or disable usage telemetry for this module. Default: true.

  - **`flushConnection`** (`bool`) - Optional
    - **Description:** When true, flows created from NSG connections are re-evaluated when rules are updated. Default: false.

  - **`location`** (`string`) - Optional
    - **Description:** Azure region for the NSG. Defaults to the resource group location.

  - **`lock`** (`object`) - Optional
    - **Description:** Management lock configuration for the NSG.
    - **`kind`** (`string`) - Optional
      - **Description:** Lock type (None, CanNotDelete, or ReadOnly).

    - **`name`** (`string`) - Optional
      - **Description:** Name of the management lock.

    - **`notes`** (`string`) - Optional
      - **Description:** Notes describing the reason for the lock.


  - **`name`** (`string`) - Optional
    - **Description:** Name of the Network Security Group.

  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Role assignments to apply on the NSG.
    - **`condition`** (`string`) - Optional
      - **Description:** Advanced condition expression for the assignment.

    - **`conditionVersion`** (`string`) - Optional
      - **Description:** Condition version. Use 2.0 when condition is provided.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional
      - **Description:** Delegated managed identity resource ID (for cross-tenant scenarios).

    - **`description`** (`string`) - Optional
      - **Description:** Description for the role assignment.

    - **`name`** (`string`) - Optional
      - **Description:** Stable GUID name of the role assignment (omit to auto-generate).

    - **`principalId`** (`string`) - Required
      - **Description:** Principal (object) ID for the assignment.

    - **`principalType`** (`string`) - Optional
      - **Description:** Principal type for the assignment.

    - **`roleDefinitionIdOrName`** (`string`) - Required
      - **Description:** Role to assign (name, GUID, or fully qualified role definition ID).


  - **`roleAssignments[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.acaEnvironment.roleAssignments

  - **`securityRules`** (`array`) - Optional
    - **Description:** Security rules to apply to the NSG. If omitted, only default rules are present.
    - **`name`** (`string`) - Required
      - **Description:** Name of the security rule.

    - **`properties`** (`object`) - Required
      - **Description:** Properties that define the behavior of the security rule.
      - **`access`** (`string`) - Required
        - **Description:** Whether matching traffic is allowed or denied.

      - **`description`** (`string`) - Optional
        - **Description:** Free-form description for the rule.

      - **`destinationAddressPrefix`** (`string`) - Optional
        - **Description:** Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

      - **`destinationAddressPrefixes`** (`array`) - Optional
        - **Description:** Multiple destination address prefixes.

      - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional
        - **Description:** Destination Application Security Group (ASG) resource IDs.

      - **`destinationPortRange`** (`string`) - Optional
        - **Description:** Single destination port or port range (e.g., 443, 1000-2000).

      - **`destinationPortRanges`** (`array`) - Optional
        - **Description:** Multiple destination ports or port ranges.

      - **`direction`** (`string`) - Required
        - **Description:** Direction of the rule (Inbound or Outbound).

      - **`priority`** (`int`) - Required
        - **Description:** Priority of the rule (100–4096). Must be unique per rule in the NSG.

      - **`protocol`** (`string`) - Required
        - **Description:** Network protocol to match.

      - **`sourceAddressPrefix`** (`string`) - Optional
        - **Description:** Single source address prefix (e.g., Internet, 10.0.0.0/24).

      - **`sourceAddressPrefixes`** (`array`) - Optional
        - **Description:** Multiple source address prefixes.

      - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional
        - **Description:** Source Application Security Group (ASG) resource IDs.

      - **`sourcePortRange`** (`string`) - Optional
        - **Description:** Single source port or port range.

      - **`sourcePortRanges`** (`array`) - Optional
        - **Description:** Multiple source ports or port ranges.



  - **`securityRules[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.acaEnvironment.securityRules
    - **`access`** (`string`) - Required
      - **Description:** Whether matching traffic is allowed or denied.

    - **`description`** (`string`) - Optional
      - **Description:** Free-form description for the rule.

    - **`destinationAddressPrefix`** (`string`) - Optional
      - **Description:** Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

    - **`destinationAddressPrefixes`** (`array`) - Optional
      - **Description:** Multiple destination address prefixes.

    - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional
      - **Description:** Destination Application Security Group (ASG) resource IDs.

    - **`destinationPortRange`** (`string`) - Optional
      - **Description:** Single destination port or port range (e.g., 443, 1000-2000).

    - **`destinationPortRanges`** (`array`) - Optional
      - **Description:** Multiple destination ports or port ranges.

    - **`direction`** (`string`) - Required
      - **Description:** Direction of the rule (Inbound or Outbound).

    - **`priority`** (`int`) - Required
      - **Description:** Priority of the rule (100–4096). Must be unique per rule in the NSG.

    - **`protocol`** (`string`) - Required
      - **Description:** Network protocol to match.

    - **`sourceAddressPrefix`** (`string`) - Optional
      - **Description:** Single source address prefix (e.g., Internet, 10.0.0.0/24).

    - **`sourceAddressPrefixes`** (`array`) - Optional
      - **Description:** Multiple source address prefixes.

    - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional
      - **Description:** Source Application Security Group (ASG) resource IDs.

    - **`sourcePortRange`** (`string`) - Optional
      - **Description:** Single source port or port range.

    - **`sourcePortRanges`** (`array`) - Optional
      - **Description:** Multiple source ports or port ranges.


  - **`tags`** (`object`) - Optional
    - **Description:** Tags to apply to the NSG.


- **`agent`** (`object`) - Optional
  - **Description:** NSG definition applied to the agent (workload) subnet.
  - **`diagnosticSettings`** (`array`) - Optional
    - **Description:** Diagnostic settings to send NSG logs/metrics to Log Analytics, Event Hub, or Storage.
    - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional
      - **Description:** Destination Event Hub authorization rule resource ID.

    - **`eventHubName`** (`string`) - Optional
      - **Description:** Destination Event Hub name when sending to Event Hub.

    - **`logAnalyticsDestinationType`** (`string`) - Optional
      - **Description:** Destination type for Log Analytics (AzureDiagnostics or Dedicated).

    - **`logCategoriesAndGroups`** (`array`) - Optional
      - **Description:** List of categories and/or category groups to enable.
      - **`category`** (`string`) - Optional
        - **Description:** Single diagnostic log category to enable.

      - **`categoryGroup`** (`string`) - Optional
        - **Description:** Category group (e.g., AllMetrics) to enable.

      - **`enabled`** (`bool`) - Optional
        - **Description:** Whether this category/category group is enabled.


    - **`logCategoriesAndGroups[*]`** (`object`) - Optional
      - **Description:** Array item for nsgDefinitions.agent.diagnosticSettings[*].logCategoriesAndGroups

    - **`marketplacePartnerResourceId`** (`string`) - Optional
      - **Description:** Marketplace partner destination resource ID (if applicable).

    - **`name`** (`string`) - Optional
      - **Description:** Name of the diagnostic settings resource.

    - **`storageAccountResourceId`** (`string`) - Optional
      - **Description:** Destination Storage Account resource ID.

    - **`workspaceResourceId`** (`string`) - Optional
      - **Description:** Destination Log Analytics workspace resource ID.


  - **`diagnosticSettings[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.agent.diagnosticSettings
    - **`category`** (`string`) - Optional
      - **Description:** Single diagnostic log category to enable.

    - **`categoryGroup`** (`string`) - Optional
      - **Description:** Category group (e.g., AllMetrics) to enable.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Whether this category/category group is enabled.


  - **`enableTelemetry`** (`bool`) - Optional
    - **Description:** Enable or disable usage telemetry for this module. Default: true.

  - **`flushConnection`** (`bool`) - Optional
    - **Description:** When true, flows created from NSG connections are re-evaluated when rules are updated. Default: false.

  - **`location`** (`string`) - Optional
    - **Description:** Azure region for the NSG. Defaults to the resource group location.

  - **`lock`** (`object`) - Optional
    - **Description:** Management lock configuration for the NSG.
    - **`kind`** (`string`) - Optional
      - **Description:** Lock type (None, CanNotDelete, or ReadOnly).

    - **`name`** (`string`) - Optional
      - **Description:** Name of the management lock.

    - **`notes`** (`string`) - Optional
      - **Description:** Notes describing the reason for the lock.


  - **`name`** (`string`) - Optional
    - **Description:** Name of the Network Security Group.

  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Role assignments to apply on the NSG.
    - **`condition`** (`string`) - Optional
      - **Description:** Advanced condition expression for the assignment.

    - **`conditionVersion`** (`string`) - Optional
      - **Description:** Condition version. Use 2.0 when condition is provided.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional
      - **Description:** Delegated managed identity resource ID (for cross-tenant scenarios).

    - **`description`** (`string`) - Optional
      - **Description:** Description for the role assignment.

    - **`name`** (`string`) - Optional
      - **Description:** Stable GUID name of the role assignment (omit to auto-generate).

    - **`principalId`** (`string`) - Required
      - **Description:** Principal (object) ID for the assignment.

    - **`principalType`** (`string`) - Optional
      - **Description:** Principal type for the assignment.

    - **`roleDefinitionIdOrName`** (`string`) - Required
      - **Description:** Role to assign (name, GUID, or fully qualified role definition ID).


  - **`roleAssignments[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.agent.roleAssignments

  - **`securityRules`** (`array`) - Optional
    - **Description:** Security rules to apply to the NSG. If omitted, only default rules are present.
    - **`name`** (`string`) - Required
      - **Description:** Name of the security rule.

    - **`properties`** (`object`) - Required
      - **Description:** Properties that define the behavior of the security rule.
      - **`access`** (`string`) - Required
        - **Description:** Whether matching traffic is allowed or denied.

      - **`description`** (`string`) - Optional
        - **Description:** Free-form description for the rule.

      - **`destinationAddressPrefix`** (`string`) - Optional
        - **Description:** Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

      - **`destinationAddressPrefixes`** (`array`) - Optional
        - **Description:** Multiple destination address prefixes.

      - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional
        - **Description:** Destination Application Security Group (ASG) resource IDs.

      - **`destinationPortRange`** (`string`) - Optional
        - **Description:** Single destination port or port range (e.g., 443, 1000-2000).

      - **`destinationPortRanges`** (`array`) - Optional
        - **Description:** Multiple destination ports or port ranges.

      - **`direction`** (`string`) - Required
        - **Description:** Direction of the rule (Inbound or Outbound).

      - **`priority`** (`int`) - Required
        - **Description:** Priority of the rule (100–4096). Must be unique per rule in the NSG.

      - **`protocol`** (`string`) - Required
        - **Description:** Network protocol to match.

      - **`sourceAddressPrefix`** (`string`) - Optional
        - **Description:** Single source address prefix (e.g., Internet, 10.0.0.0/24).

      - **`sourceAddressPrefixes`** (`array`) - Optional
        - **Description:** Multiple source address prefixes.

      - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional
        - **Description:** Source Application Security Group (ASG) resource IDs.

      - **`sourcePortRange`** (`string`) - Optional
        - **Description:** Single source port or port range.

      - **`sourcePortRanges`** (`array`) - Optional
        - **Description:** Multiple source ports or port ranges.



  - **`securityRules[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.agent.securityRules
    - **`access`** (`string`) - Required
      - **Description:** Whether matching traffic is allowed or denied.

    - **`description`** (`string`) - Optional
      - **Description:** Free-form description for the rule.

    - **`destinationAddressPrefix`** (`string`) - Optional
      - **Description:** Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

    - **`destinationAddressPrefixes`** (`array`) - Optional
      - **Description:** Multiple destination address prefixes.

    - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional
      - **Description:** Destination Application Security Group (ASG) resource IDs.

    - **`destinationPortRange`** (`string`) - Optional
      - **Description:** Single destination port or port range (e.g., 443, 1000-2000).

    - **`destinationPortRanges`** (`array`) - Optional
      - **Description:** Multiple destination ports or port ranges.

    - **`direction`** (`string`) - Required
      - **Description:** Direction of the rule (Inbound or Outbound).

    - **`priority`** (`int`) - Required
      - **Description:** Priority of the rule (100–4096). Must be unique per rule in the NSG.

    - **`protocol`** (`string`) - Required
      - **Description:** Network protocol to match.

    - **`sourceAddressPrefix`** (`string`) - Optional
      - **Description:** Single source address prefix (e.g., Internet, 10.0.0.0/24).

    - **`sourceAddressPrefixes`** (`array`) - Optional
      - **Description:** Multiple source address prefixes.

    - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional
      - **Description:** Source Application Security Group (ASG) resource IDs.

    - **`sourcePortRange`** (`string`) - Optional
      - **Description:** Single source port or port range.

    - **`sourcePortRanges`** (`array`) - Optional
      - **Description:** Multiple source ports or port ranges.


  - **`tags`** (`object`) - Optional
    - **Description:** Tags to apply to the NSG.


- **`apiManagement`** (`object`) - Optional
  - **Description:** NSG definition applied to the API Management subnet.
  - **`diagnosticSettings`** (`array`) - Optional
    - **Description:** Diagnostic settings to send NSG logs/metrics to Log Analytics, Event Hub, or Storage.
    - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional
      - **Description:** Destination Event Hub authorization rule resource ID.

    - **`eventHubName`** (`string`) - Optional
      - **Description:** Destination Event Hub name when sending to Event Hub.

    - **`logAnalyticsDestinationType`** (`string`) - Optional
      - **Description:** Destination type for Log Analytics (AzureDiagnostics or Dedicated).

    - **`logCategoriesAndGroups`** (`array`) - Optional
      - **Description:** List of categories and/or category groups to enable.
      - **`category`** (`string`) - Optional
        - **Description:** Single diagnostic log category to enable.

      - **`categoryGroup`** (`string`) - Optional
        - **Description:** Category group (e.g., AllMetrics) to enable.

      - **`enabled`** (`bool`) - Optional
        - **Description:** Whether this category/category group is enabled.


    - **`logCategoriesAndGroups[*]`** (`object`) - Optional
      - **Description:** Array item for nsgDefinitions.apiManagement.diagnosticSettings[*].logCategoriesAndGroups

    - **`marketplacePartnerResourceId`** (`string`) - Optional
      - **Description:** Marketplace partner destination resource ID (if applicable).

    - **`name`** (`string`) - Optional
      - **Description:** Name of the diagnostic settings resource.

    - **`storageAccountResourceId`** (`string`) - Optional
      - **Description:** Destination Storage Account resource ID.

    - **`workspaceResourceId`** (`string`) - Optional
      - **Description:** Destination Log Analytics workspace resource ID.


  - **`diagnosticSettings[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.apiManagement.diagnosticSettings
    - **`category`** (`string`) - Optional
      - **Description:** Single diagnostic log category to enable.

    - **`categoryGroup`** (`string`) - Optional
      - **Description:** Category group (e.g., AllMetrics) to enable.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Whether this category/category group is enabled.


  - **`enableTelemetry`** (`bool`) - Optional
    - **Description:** Enable or disable usage telemetry for this module. Default: true.

  - **`flushConnection`** (`bool`) - Optional
    - **Description:** When true, flows created from NSG connections are re-evaluated when rules are updated. Default: false.

  - **`location`** (`string`) - Optional
    - **Description:** Azure region for the NSG. Defaults to the resource group location.

  - **`lock`** (`object`) - Optional
    - **Description:** Management lock configuration for the NSG.
    - **`kind`** (`string`) - Optional
      - **Description:** Lock type (None, CanNotDelete, or ReadOnly).

    - **`name`** (`string`) - Optional
      - **Description:** Name of the management lock.

    - **`notes`** (`string`) - Optional
      - **Description:** Notes describing the reason for the lock.


  - **`name`** (`string`) - Optional
    - **Description:** Name of the Network Security Group.

  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Role assignments to apply on the NSG.
    - **`condition`** (`string`) - Optional
      - **Description:** Advanced condition expression for the assignment.

    - **`conditionVersion`** (`string`) - Optional
      - **Description:** Condition version. Use 2.0 when condition is provided.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional
      - **Description:** Delegated managed identity resource ID (for cross-tenant scenarios).

    - **`description`** (`string`) - Optional
      - **Description:** Description for the role assignment.

    - **`name`** (`string`) - Optional
      - **Description:** Stable GUID name of the role assignment (omit to auto-generate).

    - **`principalId`** (`string`) - Required
      - **Description:** Principal (object) ID for the assignment.

    - **`principalType`** (`string`) - Optional
      - **Description:** Principal type for the assignment.

    - **`roleDefinitionIdOrName`** (`string`) - Required
      - **Description:** Role to assign (name, GUID, or fully qualified role definition ID).


  - **`roleAssignments[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.apiManagement.roleAssignments

  - **`securityRules`** (`array`) - Optional
    - **Description:** Security rules to apply to the NSG. If omitted, only default rules are present.
    - **`name`** (`string`) - Required
      - **Description:** Name of the security rule.

    - **`properties`** (`object`) - Required
      - **Description:** Properties that define the behavior of the security rule.
      - **`access`** (`string`) - Required
        - **Description:** Whether matching traffic is allowed or denied.

      - **`description`** (`string`) - Optional
        - **Description:** Free-form description for the rule.

      - **`destinationAddressPrefix`** (`string`) - Optional
        - **Description:** Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

      - **`destinationAddressPrefixes`** (`array`) - Optional
        - **Description:** Multiple destination address prefixes.

      - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional
        - **Description:** Destination Application Security Group (ASG) resource IDs.

      - **`destinationPortRange`** (`string`) - Optional
        - **Description:** Single destination port or port range (e.g., 443, 1000-2000).

      - **`destinationPortRanges`** (`array`) - Optional
        - **Description:** Multiple destination ports or port ranges.

      - **`direction`** (`string`) - Required
        - **Description:** Direction of the rule (Inbound or Outbound).

      - **`priority`** (`int`) - Required
        - **Description:** Priority of the rule (100–4096). Must be unique per rule in the NSG.

      - **`protocol`** (`string`) - Required
        - **Description:** Network protocol to match.

      - **`sourceAddressPrefix`** (`string`) - Optional
        - **Description:** Single source address prefix (e.g., Internet, 10.0.0.0/24).

      - **`sourceAddressPrefixes`** (`array`) - Optional
        - **Description:** Multiple source address prefixes.

      - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional
        - **Description:** Source Application Security Group (ASG) resource IDs.

      - **`sourcePortRange`** (`string`) - Optional
        - **Description:** Single source port or port range.

      - **`sourcePortRanges`** (`array`) - Optional
        - **Description:** Multiple source ports or port ranges.



  - **`securityRules[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.apiManagement.securityRules
    - **`access`** (`string`) - Required
      - **Description:** Whether matching traffic is allowed or denied.

    - **`description`** (`string`) - Optional
      - **Description:** Free-form description for the rule.

    - **`destinationAddressPrefix`** (`string`) - Optional
      - **Description:** Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

    - **`destinationAddressPrefixes`** (`array`) - Optional
      - **Description:** Multiple destination address prefixes.

    - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional
      - **Description:** Destination Application Security Group (ASG) resource IDs.

    - **`destinationPortRange`** (`string`) - Optional
      - **Description:** Single destination port or port range (e.g., 443, 1000-2000).

    - **`destinationPortRanges`** (`array`) - Optional
      - **Description:** Multiple destination ports or port ranges.

    - **`direction`** (`string`) - Required
      - **Description:** Direction of the rule (Inbound or Outbound).

    - **`priority`** (`int`) - Required
      - **Description:** Priority of the rule (100–4096). Must be unique per rule in the NSG.

    - **`protocol`** (`string`) - Required
      - **Description:** Network protocol to match.

    - **`sourceAddressPrefix`** (`string`) - Optional
      - **Description:** Single source address prefix (e.g., Internet, 10.0.0.0/24).

    - **`sourceAddressPrefixes`** (`array`) - Optional
      - **Description:** Multiple source address prefixes.

    - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional
      - **Description:** Source Application Security Group (ASG) resource IDs.

    - **`sourcePortRange`** (`string`) - Optional
      - **Description:** Single source port or port range.

    - **`sourcePortRanges`** (`array`) - Optional
      - **Description:** Multiple source ports or port ranges.


  - **`tags`** (`object`) - Optional
    - **Description:** Tags to apply to the NSG.


- **`applicationGateway`** (`object`) - Optional
  - **Description:** NSG definition applied to the Application Gateway subnet.
  - **`diagnosticSettings`** (`array`) - Optional
    - **Description:** Diagnostic settings to send NSG logs/metrics to Log Analytics, Event Hub, or Storage.
    - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional
      - **Description:** Destination Event Hub authorization rule resource ID.

    - **`eventHubName`** (`string`) - Optional
      - **Description:** Destination Event Hub name when sending to Event Hub.

    - **`logAnalyticsDestinationType`** (`string`) - Optional
      - **Description:** Destination type for Log Analytics (AzureDiagnostics or Dedicated).

    - **`logCategoriesAndGroups`** (`array`) - Optional
      - **Description:** List of categories and/or category groups to enable.
      - **`category`** (`string`) - Optional
        - **Description:** Single diagnostic log category to enable.

      - **`categoryGroup`** (`string`) - Optional
        - **Description:** Category group (e.g., AllMetrics) to enable.

      - **`enabled`** (`bool`) - Optional
        - **Description:** Whether this category/category group is enabled.


    - **`logCategoriesAndGroups[*]`** (`object`) - Optional
      - **Description:** Array item for nsgDefinitions.applicationGateway.diagnosticSettings[*].logCategoriesAndGroups

    - **`marketplacePartnerResourceId`** (`string`) - Optional
      - **Description:** Marketplace partner destination resource ID (if applicable).

    - **`name`** (`string`) - Optional
      - **Description:** Name of the diagnostic settings resource.

    - **`storageAccountResourceId`** (`string`) - Optional
      - **Description:** Destination Storage Account resource ID.

    - **`workspaceResourceId`** (`string`) - Optional
      - **Description:** Destination Log Analytics workspace resource ID.


  - **`diagnosticSettings[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.applicationGateway.diagnosticSettings
    - **`category`** (`string`) - Optional
      - **Description:** Single diagnostic log category to enable.

    - **`categoryGroup`** (`string`) - Optional
      - **Description:** Category group (e.g., AllMetrics) to enable.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Whether this category/category group is enabled.


  - **`enableTelemetry`** (`bool`) - Optional
    - **Description:** Enable or disable usage telemetry for this module. Default: true.

  - **`flushConnection`** (`bool`) - Optional
    - **Description:** When true, flows created from NSG connections are re-evaluated when rules are updated. Default: false.

  - **`location`** (`string`) - Optional
    - **Description:** Azure region for the NSG. Defaults to the resource group location.

  - **`lock`** (`object`) - Optional
    - **Description:** Management lock configuration for the NSG.
    - **`kind`** (`string`) - Optional
      - **Description:** Lock type (None, CanNotDelete, or ReadOnly).

    - **`name`** (`string`) - Optional
      - **Description:** Name of the management lock.

    - **`notes`** (`string`) - Optional
      - **Description:** Notes describing the reason for the lock.


  - **`name`** (`string`) - Optional
    - **Description:** Name of the Network Security Group.

  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Role assignments to apply on the NSG.
    - **`condition`** (`string`) - Optional
      - **Description:** Advanced condition expression for the assignment.

    - **`conditionVersion`** (`string`) - Optional
      - **Description:** Condition version. Use 2.0 when condition is provided.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional
      - **Description:** Delegated managed identity resource ID (for cross-tenant scenarios).

    - **`description`** (`string`) - Optional
      - **Description:** Description for the role assignment.

    - **`name`** (`string`) - Optional
      - **Description:** Stable GUID name of the role assignment (omit to auto-generate).

    - **`principalId`** (`string`) - Required
      - **Description:** Principal (object) ID for the assignment.

    - **`principalType`** (`string`) - Optional
      - **Description:** Principal type for the assignment.

    - **`roleDefinitionIdOrName`** (`string`) - Required
      - **Description:** Role to assign (name, GUID, or fully qualified role definition ID).


  - **`roleAssignments[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.applicationGateway.roleAssignments

  - **`securityRules`** (`array`) - Optional
    - **Description:** Security rules to apply to the NSG. If omitted, only default rules are present.
    - **`name`** (`string`) - Required
      - **Description:** Name of the security rule.

    - **`properties`** (`object`) - Required
      - **Description:** Properties that define the behavior of the security rule.
      - **`access`** (`string`) - Required
        - **Description:** Whether matching traffic is allowed or denied.

      - **`description`** (`string`) - Optional
        - **Description:** Free-form description for the rule.

      - **`destinationAddressPrefix`** (`string`) - Optional
        - **Description:** Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

      - **`destinationAddressPrefixes`** (`array`) - Optional
        - **Description:** Multiple destination address prefixes.

      - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional
        - **Description:** Destination Application Security Group (ASG) resource IDs.

      - **`destinationPortRange`** (`string`) - Optional
        - **Description:** Single destination port or port range (e.g., 443, 1000-2000).

      - **`destinationPortRanges`** (`array`) - Optional
        - **Description:** Multiple destination ports or port ranges.

      - **`direction`** (`string`) - Required
        - **Description:** Direction of the rule (Inbound or Outbound).

      - **`priority`** (`int`) - Required
        - **Description:** Priority of the rule (100–4096). Must be unique per rule in the NSG.

      - **`protocol`** (`string`) - Required
        - **Description:** Network protocol to match.

      - **`sourceAddressPrefix`** (`string`) - Optional
        - **Description:** Single source address prefix (e.g., Internet, 10.0.0.0/24).

      - **`sourceAddressPrefixes`** (`array`) - Optional
        - **Description:** Multiple source address prefixes.

      - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional
        - **Description:** Source Application Security Group (ASG) resource IDs.

      - **`sourcePortRange`** (`string`) - Optional
        - **Description:** Single source port or port range.

      - **`sourcePortRanges`** (`array`) - Optional
        - **Description:** Multiple source ports or port ranges.



  - **`securityRules[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.applicationGateway.securityRules
    - **`access`** (`string`) - Required
      - **Description:** Whether matching traffic is allowed or denied.

    - **`description`** (`string`) - Optional
      - **Description:** Free-form description for the rule.

    - **`destinationAddressPrefix`** (`string`) - Optional
      - **Description:** Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

    - **`destinationAddressPrefixes`** (`array`) - Optional
      - **Description:** Multiple destination address prefixes.

    - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional
      - **Description:** Destination Application Security Group (ASG) resource IDs.

    - **`destinationPortRange`** (`string`) - Optional
      - **Description:** Single destination port or port range (e.g., 443, 1000-2000).

    - **`destinationPortRanges`** (`array`) - Optional
      - **Description:** Multiple destination ports or port ranges.

    - **`direction`** (`string`) - Required
      - **Description:** Direction of the rule (Inbound or Outbound).

    - **`priority`** (`int`) - Required
      - **Description:** Priority of the rule (100–4096). Must be unique per rule in the NSG.

    - **`protocol`** (`string`) - Required
      - **Description:** Network protocol to match.

    - **`sourceAddressPrefix`** (`string`) - Optional
      - **Description:** Single source address prefix (e.g., Internet, 10.0.0.0/24).

    - **`sourceAddressPrefixes`** (`array`) - Optional
      - **Description:** Multiple source address prefixes.

    - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional
      - **Description:** Source Application Security Group (ASG) resource IDs.

    - **`sourcePortRange`** (`string`) - Optional
      - **Description:** Single source port or port range.

    - **`sourcePortRanges`** (`array`) - Optional
      - **Description:** Multiple source ports or port ranges.


  - **`tags`** (`object`) - Optional
    - **Description:** Tags to apply to the NSG.


- **`bastion`** (`object`) - Optional
  - **Description:** NSG definition applied to the Bastion subnet.
  - **`diagnosticSettings`** (`array`) - Optional
    - **Description:** Diagnostic settings to send NSG logs/metrics to Log Analytics, Event Hub, or Storage.
    - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional
      - **Description:** Destination Event Hub authorization rule resource ID.

    - **`eventHubName`** (`string`) - Optional
      - **Description:** Destination Event Hub name when sending to Event Hub.

    - **`logAnalyticsDestinationType`** (`string`) - Optional
      - **Description:** Destination type for Log Analytics (AzureDiagnostics or Dedicated).

    - **`logCategoriesAndGroups`** (`array`) - Optional
      - **Description:** List of categories and/or category groups to enable.
      - **`category`** (`string`) - Optional
        - **Description:** Single diagnostic log category to enable.

      - **`categoryGroup`** (`string`) - Optional
        - **Description:** Category group (e.g., AllMetrics) to enable.

      - **`enabled`** (`bool`) - Optional
        - **Description:** Whether this category/category group is enabled.


    - **`logCategoriesAndGroups[*]`** (`object`) - Optional
      - **Description:** Array item for nsgDefinitions.bastion.diagnosticSettings[*].logCategoriesAndGroups

    - **`marketplacePartnerResourceId`** (`string`) - Optional
      - **Description:** Marketplace partner destination resource ID (if applicable).

    - **`name`** (`string`) - Optional
      - **Description:** Name of the diagnostic settings resource.

    - **`storageAccountResourceId`** (`string`) - Optional
      - **Description:** Destination Storage Account resource ID.

    - **`workspaceResourceId`** (`string`) - Optional
      - **Description:** Destination Log Analytics workspace resource ID.


  - **`diagnosticSettings[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.bastion.diagnosticSettings
    - **`category`** (`string`) - Optional
      - **Description:** Single diagnostic log category to enable.

    - **`categoryGroup`** (`string`) - Optional
      - **Description:** Category group (e.g., AllMetrics) to enable.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Whether this category/category group is enabled.


  - **`enableTelemetry`** (`bool`) - Optional
    - **Description:** Enable or disable usage telemetry for this module. Default: true.

  - **`flushConnection`** (`bool`) - Optional
    - **Description:** When true, flows created from NSG connections are re-evaluated when rules are updated. Default: false.

  - **`location`** (`string`) - Optional
    - **Description:** Azure region for the NSG. Defaults to the resource group location.

  - **`lock`** (`object`) - Optional
    - **Description:** Management lock configuration for the NSG.
    - **`kind`** (`string`) - Optional
      - **Description:** Lock type (None, CanNotDelete, or ReadOnly).

    - **`name`** (`string`) - Optional
      - **Description:** Name of the management lock.

    - **`notes`** (`string`) - Optional
      - **Description:** Notes describing the reason for the lock.


  - **`name`** (`string`) - Optional
    - **Description:** Name of the Network Security Group.

  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Role assignments to apply on the NSG.
    - **`condition`** (`string`) - Optional
      - **Description:** Advanced condition expression for the assignment.

    - **`conditionVersion`** (`string`) - Optional
      - **Description:** Condition version. Use 2.0 when condition is provided.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional
      - **Description:** Delegated managed identity resource ID (for cross-tenant scenarios).

    - **`description`** (`string`) - Optional
      - **Description:** Description for the role assignment.

    - **`name`** (`string`) - Optional
      - **Description:** Stable GUID name of the role assignment (omit to auto-generate).

    - **`principalId`** (`string`) - Required
      - **Description:** Principal (object) ID for the assignment.

    - **`principalType`** (`string`) - Optional
      - **Description:** Principal type for the assignment.

    - **`roleDefinitionIdOrName`** (`string`) - Required
      - **Description:** Role to assign (name, GUID, or fully qualified role definition ID).


  - **`roleAssignments[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.bastion.roleAssignments

  - **`securityRules`** (`array`) - Optional
    - **Description:** Security rules to apply to the NSG. If omitted, only default rules are present.
    - **`name`** (`string`) - Required
      - **Description:** Name of the security rule.

    - **`properties`** (`object`) - Required
      - **Description:** Properties that define the behavior of the security rule.
      - **`access`** (`string`) - Required
        - **Description:** Whether matching traffic is allowed or denied.

      - **`description`** (`string`) - Optional
        - **Description:** Free-form description for the rule.

      - **`destinationAddressPrefix`** (`string`) - Optional
        - **Description:** Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

      - **`destinationAddressPrefixes`** (`array`) - Optional
        - **Description:** Multiple destination address prefixes.

      - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional
        - **Description:** Destination Application Security Group (ASG) resource IDs.

      - **`destinationPortRange`** (`string`) - Optional
        - **Description:** Single destination port or port range (e.g., 443, 1000-2000).

      - **`destinationPortRanges`** (`array`) - Optional
        - **Description:** Multiple destination ports or port ranges.

      - **`direction`** (`string`) - Required
        - **Description:** Direction of the rule (Inbound or Outbound).

      - **`priority`** (`int`) - Required
        - **Description:** Priority of the rule (100–4096). Must be unique per rule in the NSG.

      - **`protocol`** (`string`) - Required
        - **Description:** Network protocol to match.

      - **`sourceAddressPrefix`** (`string`) - Optional
        - **Description:** Single source address prefix (e.g., Internet, 10.0.0.0/24).

      - **`sourceAddressPrefixes`** (`array`) - Optional
        - **Description:** Multiple source address prefixes.

      - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional
        - **Description:** Source Application Security Group (ASG) resource IDs.

      - **`sourcePortRange`** (`string`) - Optional
        - **Description:** Single source port or port range.

      - **`sourcePortRanges`** (`array`) - Optional
        - **Description:** Multiple source ports or port ranges.



  - **`securityRules[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.bastion.securityRules
    - **`access`** (`string`) - Required
      - **Description:** Whether matching traffic is allowed or denied.

    - **`description`** (`string`) - Optional
      - **Description:** Free-form description for the rule.

    - **`destinationAddressPrefix`** (`string`) - Optional
      - **Description:** Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

    - **`destinationAddressPrefixes`** (`array`) - Optional
      - **Description:** Multiple destination address prefixes.

    - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional
      - **Description:** Destination Application Security Group (ASG) resource IDs.

    - **`destinationPortRange`** (`string`) - Optional
      - **Description:** Single destination port or port range (e.g., 443, 1000-2000).

    - **`destinationPortRanges`** (`array`) - Optional
      - **Description:** Multiple destination ports or port ranges.

    - **`direction`** (`string`) - Required
      - **Description:** Direction of the rule (Inbound or Outbound).

    - **`priority`** (`int`) - Required
      - **Description:** Priority of the rule (100–4096). Must be unique per rule in the NSG.

    - **`protocol`** (`string`) - Required
      - **Description:** Network protocol to match.

    - **`sourceAddressPrefix`** (`string`) - Optional
      - **Description:** Single source address prefix (e.g., Internet, 10.0.0.0/24).

    - **`sourceAddressPrefixes`** (`array`) - Optional
      - **Description:** Multiple source address prefixes.

    - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional
      - **Description:** Source Application Security Group (ASG) resource IDs.

    - **`sourcePortRange`** (`string`) - Optional
      - **Description:** Single source port or port range.

    - **`sourcePortRanges`** (`array`) - Optional
      - **Description:** Multiple source ports or port ranges.


  - **`tags`** (`object`) - Optional
    - **Description:** Tags to apply to the NSG.


- **`devopsBuildAgents`** (`object`) - Optional
  - **Description:** NSG definition applied to the DevOps build agents subnet.
  - **`diagnosticSettings`** (`array`) - Optional
    - **Description:** Diagnostic settings to send NSG logs/metrics to Log Analytics, Event Hub, or Storage.
    - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional
      - **Description:** Destination Event Hub authorization rule resource ID.

    - **`eventHubName`** (`string`) - Optional
      - **Description:** Destination Event Hub name when sending to Event Hub.

    - **`logAnalyticsDestinationType`** (`string`) - Optional
      - **Description:** Destination type for Log Analytics (AzureDiagnostics or Dedicated).

    - **`logCategoriesAndGroups`** (`array`) - Optional
      - **Description:** List of categories and/or category groups to enable.
      - **`category`** (`string`) - Optional
        - **Description:** Single diagnostic log category to enable.

      - **`categoryGroup`** (`string`) - Optional
        - **Description:** Category group (e.g., AllMetrics) to enable.

      - **`enabled`** (`bool`) - Optional
        - **Description:** Whether this category/category group is enabled.


    - **`logCategoriesAndGroups[*]`** (`object`) - Optional
      - **Description:** Array item for nsgDefinitions.devopsBuildAgents.diagnosticSettings[*].logCategoriesAndGroups

    - **`marketplacePartnerResourceId`** (`string`) - Optional
      - **Description:** Marketplace partner destination resource ID (if applicable).

    - **`name`** (`string`) - Optional
      - **Description:** Name of the diagnostic settings resource.

    - **`storageAccountResourceId`** (`string`) - Optional
      - **Description:** Destination Storage Account resource ID.

    - **`workspaceResourceId`** (`string`) - Optional
      - **Description:** Destination Log Analytics workspace resource ID.


  - **`diagnosticSettings[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.devopsBuildAgents.diagnosticSettings
    - **`category`** (`string`) - Optional
      - **Description:** Single diagnostic log category to enable.

    - **`categoryGroup`** (`string`) - Optional
      - **Description:** Category group (e.g., AllMetrics) to enable.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Whether this category/category group is enabled.


  - **`enableTelemetry`** (`bool`) - Optional
    - **Description:** Enable or disable usage telemetry for this module. Default: true.

  - **`flushConnection`** (`bool`) - Optional
    - **Description:** When true, flows created from NSG connections are re-evaluated when rules are updated. Default: false.

  - **`location`** (`string`) - Optional
    - **Description:** Azure region for the NSG. Defaults to the resource group location.

  - **`lock`** (`object`) - Optional
    - **Description:** Management lock configuration for the NSG.
    - **`kind`** (`string`) - Optional
      - **Description:** Lock type (None, CanNotDelete, or ReadOnly).

    - **`name`** (`string`) - Optional
      - **Description:** Name of the management lock.

    - **`notes`** (`string`) - Optional
      - **Description:** Notes describing the reason for the lock.


  - **`name`** (`string`) - Optional
    - **Description:** Name of the Network Security Group.

  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Role assignments to apply on the NSG.
    - **`condition`** (`string`) - Optional
      - **Description:** Advanced condition expression for the assignment.

    - **`conditionVersion`** (`string`) - Optional
      - **Description:** Condition version. Use 2.0 when condition is provided.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional
      - **Description:** Delegated managed identity resource ID (for cross-tenant scenarios).

    - **`description`** (`string`) - Optional
      - **Description:** Description for the role assignment.

    - **`name`** (`string`) - Optional
      - **Description:** Stable GUID name of the role assignment (omit to auto-generate).

    - **`principalId`** (`string`) - Required
      - **Description:** Principal (object) ID for the assignment.

    - **`principalType`** (`string`) - Optional
      - **Description:** Principal type for the assignment.

    - **`roleDefinitionIdOrName`** (`string`) - Required
      - **Description:** Role to assign (name, GUID, or fully qualified role definition ID).


  - **`roleAssignments[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.devopsBuildAgents.roleAssignments

  - **`securityRules`** (`array`) - Optional
    - **Description:** Security rules to apply to the NSG. If omitted, only default rules are present.
    - **`name`** (`string`) - Required
      - **Description:** Name of the security rule.

    - **`properties`** (`object`) - Required
      - **Description:** Properties that define the behavior of the security rule.
      - **`access`** (`string`) - Required
        - **Description:** Whether matching traffic is allowed or denied.

      - **`description`** (`string`) - Optional
        - **Description:** Free-form description for the rule.

      - **`destinationAddressPrefix`** (`string`) - Optional
        - **Description:** Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

      - **`destinationAddressPrefixes`** (`array`) - Optional
        - **Description:** Multiple destination address prefixes.

      - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional
        - **Description:** Destination Application Security Group (ASG) resource IDs.

      - **`destinationPortRange`** (`string`) - Optional
        - **Description:** Single destination port or port range (e.g., 443, 1000-2000).

      - **`destinationPortRanges`** (`array`) - Optional
        - **Description:** Multiple destination ports or port ranges.

      - **`direction`** (`string`) - Required
        - **Description:** Direction of the rule (Inbound or Outbound).

      - **`priority`** (`int`) - Required
        - **Description:** Priority of the rule (100–4096). Must be unique per rule in the NSG.

      - **`protocol`** (`string`) - Required
        - **Description:** Network protocol to match.

      - **`sourceAddressPrefix`** (`string`) - Optional
        - **Description:** Single source address prefix (e.g., Internet, 10.0.0.0/24).

      - **`sourceAddressPrefixes`** (`array`) - Optional
        - **Description:** Multiple source address prefixes.

      - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional
        - **Description:** Source Application Security Group (ASG) resource IDs.

      - **`sourcePortRange`** (`string`) - Optional
        - **Description:** Single source port or port range.

      - **`sourcePortRanges`** (`array`) - Optional
        - **Description:** Multiple source ports or port ranges.



  - **`securityRules[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.devopsBuildAgents.securityRules
    - **`access`** (`string`) - Required
      - **Description:** Whether matching traffic is allowed or denied.

    - **`description`** (`string`) - Optional
      - **Description:** Free-form description for the rule.

    - **`destinationAddressPrefix`** (`string`) - Optional
      - **Description:** Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

    - **`destinationAddressPrefixes`** (`array`) - Optional
      - **Description:** Multiple destination address prefixes.

    - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional
      - **Description:** Destination Application Security Group (ASG) resource IDs.

    - **`destinationPortRange`** (`string`) - Optional
      - **Description:** Single destination port or port range (e.g., 443, 1000-2000).

    - **`destinationPortRanges`** (`array`) - Optional
      - **Description:** Multiple destination ports or port ranges.

    - **`direction`** (`string`) - Required
      - **Description:** Direction of the rule (Inbound or Outbound).

    - **`priority`** (`int`) - Required
      - **Description:** Priority of the rule (100–4096). Must be unique per rule in the NSG.

    - **`protocol`** (`string`) - Required
      - **Description:** Network protocol to match.

    - **`sourceAddressPrefix`** (`string`) - Optional
      - **Description:** Single source address prefix (e.g., Internet, 10.0.0.0/24).

    - **`sourceAddressPrefixes`** (`array`) - Optional
      - **Description:** Multiple source address prefixes.

    - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional
      - **Description:** Source Application Security Group (ASG) resource IDs.

    - **`sourcePortRange`** (`string`) - Optional
      - **Description:** Single source port or port range.

    - **`sourcePortRanges`** (`array`) - Optional
      - **Description:** Multiple source ports or port ranges.


  - **`tags`** (`object`) - Optional
    - **Description:** Tags to apply to the NSG.


- **`jumpbox`** (`object`) - Optional
  - **Description:** NSG definition applied to the jumpbox (bastion-accessed) subnet.
  - **`diagnosticSettings`** (`array`) - Optional
    - **Description:** Diagnostic settings to send NSG logs/metrics to Log Analytics, Event Hub, or Storage.
    - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional
      - **Description:** Destination Event Hub authorization rule resource ID.

    - **`eventHubName`** (`string`) - Optional
      - **Description:** Destination Event Hub name when sending to Event Hub.

    - **`logAnalyticsDestinationType`** (`string`) - Optional
      - **Description:** Destination type for Log Analytics (AzureDiagnostics or Dedicated).

    - **`logCategoriesAndGroups`** (`array`) - Optional
      - **Description:** List of categories and/or category groups to enable.
      - **`category`** (`string`) - Optional
        - **Description:** Single diagnostic log category to enable.

      - **`categoryGroup`** (`string`) - Optional
        - **Description:** Category group (e.g., AllMetrics) to enable.

      - **`enabled`** (`bool`) - Optional
        - **Description:** Whether this category/category group is enabled.


    - **`logCategoriesAndGroups[*]`** (`object`) - Optional
      - **Description:** Array item for nsgDefinitions.jumpbox.diagnosticSettings[*].logCategoriesAndGroups

    - **`marketplacePartnerResourceId`** (`string`) - Optional
      - **Description:** Marketplace partner destination resource ID (if applicable).

    - **`name`** (`string`) - Optional
      - **Description:** Name of the diagnostic settings resource.

    - **`storageAccountResourceId`** (`string`) - Optional
      - **Description:** Destination Storage Account resource ID.

    - **`workspaceResourceId`** (`string`) - Optional
      - **Description:** Destination Log Analytics workspace resource ID.


  - **`diagnosticSettings[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.jumpbox.diagnosticSettings
    - **`category`** (`string`) - Optional
      - **Description:** Single diagnostic log category to enable.

    - **`categoryGroup`** (`string`) - Optional
      - **Description:** Category group (e.g., AllMetrics) to enable.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Whether this category/category group is enabled.


  - **`enableTelemetry`** (`bool`) - Optional
    - **Description:** Enable or disable usage telemetry for this module. Default: true.

  - **`flushConnection`** (`bool`) - Optional
    - **Description:** When true, flows created from NSG connections are re-evaluated when rules are updated. Default: false.

  - **`location`** (`string`) - Optional
    - **Description:** Azure region for the NSG. Defaults to the resource group location.

  - **`lock`** (`object`) - Optional
    - **Description:** Management lock configuration for the NSG.
    - **`kind`** (`string`) - Optional
      - **Description:** Lock type (None, CanNotDelete, or ReadOnly).

    - **`name`** (`string`) - Optional
      - **Description:** Name of the management lock.

    - **`notes`** (`string`) - Optional
      - **Description:** Notes describing the reason for the lock.


  - **`name`** (`string`) - Optional
    - **Description:** Name of the Network Security Group.

  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Role assignments to apply on the NSG.
    - **`condition`** (`string`) - Optional
      - **Description:** Advanced condition expression for the assignment.

    - **`conditionVersion`** (`string`) - Optional
      - **Description:** Condition version. Use 2.0 when condition is provided.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional
      - **Description:** Delegated managed identity resource ID (for cross-tenant scenarios).

    - **`description`** (`string`) - Optional
      - **Description:** Description for the role assignment.

    - **`name`** (`string`) - Optional
      - **Description:** Stable GUID name of the role assignment (omit to auto-generate).

    - **`principalId`** (`string`) - Required
      - **Description:** Principal (object) ID for the assignment.

    - **`principalType`** (`string`) - Optional
      - **Description:** Principal type for the assignment.

    - **`roleDefinitionIdOrName`** (`string`) - Required
      - **Description:** Role to assign (name, GUID, or fully qualified role definition ID).


  - **`roleAssignments[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.jumpbox.roleAssignments

  - **`securityRules`** (`array`) - Optional
    - **Description:** Security rules to apply to the NSG. If omitted, only default rules are present.
    - **`name`** (`string`) - Required
      - **Description:** Name of the security rule.

    - **`properties`** (`object`) - Required
      - **Description:** Properties that define the behavior of the security rule.
      - **`access`** (`string`) - Required
        - **Description:** Whether matching traffic is allowed or denied.

      - **`description`** (`string`) - Optional
        - **Description:** Free-form description for the rule.

      - **`destinationAddressPrefix`** (`string`) - Optional
        - **Description:** Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

      - **`destinationAddressPrefixes`** (`array`) - Optional
        - **Description:** Multiple destination address prefixes.

      - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional
        - **Description:** Destination Application Security Group (ASG) resource IDs.

      - **`destinationPortRange`** (`string`) - Optional
        - **Description:** Single destination port or port range (e.g., 443, 1000-2000).

      - **`destinationPortRanges`** (`array`) - Optional
        - **Description:** Multiple destination ports or port ranges.

      - **`direction`** (`string`) - Required
        - **Description:** Direction of the rule (Inbound or Outbound).

      - **`priority`** (`int`) - Required
        - **Description:** Priority of the rule (100–4096). Must be unique per rule in the NSG.

      - **`protocol`** (`string`) - Required
        - **Description:** Network protocol to match.

      - **`sourceAddressPrefix`** (`string`) - Optional
        - **Description:** Single source address prefix (e.g., Internet, 10.0.0.0/24).

      - **`sourceAddressPrefixes`** (`array`) - Optional
        - **Description:** Multiple source address prefixes.

      - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional
        - **Description:** Source Application Security Group (ASG) resource IDs.

      - **`sourcePortRange`** (`string`) - Optional
        - **Description:** Single source port or port range.

      - **`sourcePortRanges`** (`array`) - Optional
        - **Description:** Multiple source ports or port ranges.



  - **`securityRules[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.jumpbox.securityRules
    - **`access`** (`string`) - Required
      - **Description:** Whether matching traffic is allowed or denied.

    - **`description`** (`string`) - Optional
      - **Description:** Free-form description for the rule.

    - **`destinationAddressPrefix`** (`string`) - Optional
      - **Description:** Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

    - **`destinationAddressPrefixes`** (`array`) - Optional
      - **Description:** Multiple destination address prefixes.

    - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional
      - **Description:** Destination Application Security Group (ASG) resource IDs.

    - **`destinationPortRange`** (`string`) - Optional
      - **Description:** Single destination port or port range (e.g., 443, 1000-2000).

    - **`destinationPortRanges`** (`array`) - Optional
      - **Description:** Multiple destination ports or port ranges.

    - **`direction`** (`string`) - Required
      - **Description:** Direction of the rule (Inbound or Outbound).

    - **`priority`** (`int`) - Required
      - **Description:** Priority of the rule (100–4096). Must be unique per rule in the NSG.

    - **`protocol`** (`string`) - Required
      - **Description:** Network protocol to match.

    - **`sourceAddressPrefix`** (`string`) - Optional
      - **Description:** Single source address prefix (e.g., Internet, 10.0.0.0/24).

    - **`sourceAddressPrefixes`** (`array`) - Optional
      - **Description:** Multiple source address prefixes.

    - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional
      - **Description:** Source Application Security Group (ASG) resource IDs.

    - **`sourcePortRange`** (`string`) - Optional
      - **Description:** Single source port or port range.

    - **`sourcePortRanges`** (`array`) - Optional
      - **Description:** Multiple source ports or port ranges.


  - **`tags`** (`object`) - Optional
    - **Description:** Tags to apply to the NSG.


- **`pe`** (`object`) - Optional
  - **Description:** NSG definition applied to the private endpoints (PE) subnet.
  - **`diagnosticSettings`** (`array`) - Optional
    - **Description:** Diagnostic settings to send NSG logs/metrics to Log Analytics, Event Hub, or Storage.
    - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional
      - **Description:** Destination Event Hub authorization rule resource ID.

    - **`eventHubName`** (`string`) - Optional
      - **Description:** Destination Event Hub name when sending to Event Hub.

    - **`logAnalyticsDestinationType`** (`string`) - Optional
      - **Description:** Destination type for Log Analytics (AzureDiagnostics or Dedicated).

    - **`logCategoriesAndGroups`** (`array`) - Optional
      - **Description:** List of categories and/or category groups to enable.
      - **`category`** (`string`) - Optional
        - **Description:** Single diagnostic log category to enable.

      - **`categoryGroup`** (`string`) - Optional
        - **Description:** Category group (e.g., AllMetrics) to enable.

      - **`enabled`** (`bool`) - Optional
        - **Description:** Whether this category/category group is enabled.


    - **`logCategoriesAndGroups[*]`** (`object`) - Optional
      - **Description:** Array item for nsgDefinitions.pe.diagnosticSettings[*].logCategoriesAndGroups

    - **`marketplacePartnerResourceId`** (`string`) - Optional
      - **Description:** Marketplace partner destination resource ID (if applicable).

    - **`name`** (`string`) - Optional
      - **Description:** Name of the diagnostic settings resource.

    - **`storageAccountResourceId`** (`string`) - Optional
      - **Description:** Destination Storage Account resource ID.

    - **`workspaceResourceId`** (`string`) - Optional
      - **Description:** Destination Log Analytics workspace resource ID.


  - **`diagnosticSettings[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.pe.diagnosticSettings
    - **`category`** (`string`) - Optional
      - **Description:** Single diagnostic log category to enable.

    - **`categoryGroup`** (`string`) - Optional
      - **Description:** Category group (e.g., AllMetrics) to enable.

    - **`enabled`** (`bool`) - Optional
      - **Description:** Whether this category/category group is enabled.


  - **`enableTelemetry`** (`bool`) - Optional
    - **Description:** Enable or disable usage telemetry for this module. Default: true.

  - **`flushConnection`** (`bool`) - Optional
    - **Description:** When true, flows created from NSG connections are re-evaluated when rules are updated. Default: false.

  - **`location`** (`string`) - Optional
    - **Description:** Azure region for the NSG. Defaults to the resource group location.

  - **`lock`** (`object`) - Optional
    - **Description:** Management lock configuration for the NSG.
    - **`kind`** (`string`) - Optional
      - **Description:** Lock type (None, CanNotDelete, or ReadOnly).

    - **`name`** (`string`) - Optional
      - **Description:** Name of the management lock.

    - **`notes`** (`string`) - Optional
      - **Description:** Notes describing the reason for the lock.


  - **`name`** (`string`) - Optional
    - **Description:** Name of the Network Security Group.

  - **`roleAssignments`** (`array`) - Optional
    - **Description:** Role assignments to apply on the NSG.
    - **`condition`** (`string`) - Optional
      - **Description:** Advanced condition expression for the assignment.

    - **`conditionVersion`** (`string`) - Optional
      - **Description:** Condition version. Use 2.0 when condition is provided.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional
      - **Description:** Delegated managed identity resource ID (for cross-tenant scenarios).

    - **`description`** (`string`) - Optional
      - **Description:** Description for the role assignment.

    - **`name`** (`string`) - Optional
      - **Description:** Stable GUID name of the role assignment (omit to auto-generate).

    - **`principalId`** (`string`) - Required
      - **Description:** Principal (object) ID for the assignment.

    - **`principalType`** (`string`) - Optional
      - **Description:** Principal type for the assignment.

    - **`roleDefinitionIdOrName`** (`string`) - Required
      - **Description:** Role to assign (name, GUID, or fully qualified role definition ID).


  - **`roleAssignments[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.pe.roleAssignments

  - **`securityRules`** (`array`) - Optional
    - **Description:** Security rules to apply to the NSG. If omitted, only default rules are present.
    - **`name`** (`string`) - Required
      - **Description:** Name of the security rule.

    - **`properties`** (`object`) - Required
      - **Description:** Properties that define the behavior of the security rule.
      - **`access`** (`string`) - Required
        - **Description:** Whether matching traffic is allowed or denied.

      - **`description`** (`string`) - Optional
        - **Description:** Free-form description for the rule.

      - **`destinationAddressPrefix`** (`string`) - Optional
        - **Description:** Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

      - **`destinationAddressPrefixes`** (`array`) - Optional
        - **Description:** Multiple destination address prefixes.

      - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional
        - **Description:** Destination Application Security Group (ASG) resource IDs.

      - **`destinationPortRange`** (`string`) - Optional
        - **Description:** Single destination port or port range (e.g., 443, 1000-2000).

      - **`destinationPortRanges`** (`array`) - Optional
        - **Description:** Multiple destination ports or port ranges.

      - **`direction`** (`string`) - Required
        - **Description:** Direction of the rule (Inbound or Outbound).

      - **`priority`** (`int`) - Required
        - **Description:** Priority of the rule (100–4096). Must be unique per rule in the NSG.

      - **`protocol`** (`string`) - Required
        - **Description:** Network protocol to match.

      - **`sourceAddressPrefix`** (`string`) - Optional
        - **Description:** Single source address prefix (e.g., Internet, 10.0.0.0/24).

      - **`sourceAddressPrefixes`** (`array`) - Optional
        - **Description:** Multiple source address prefixes.

      - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional
        - **Description:** Source Application Security Group (ASG) resource IDs.

      - **`sourcePortRange`** (`string`) - Optional
        - **Description:** Single source port or port range.

      - **`sourcePortRanges`** (`array`) - Optional
        - **Description:** Multiple source ports or port ranges.



  - **`securityRules[*]`** (`object`) - Optional
    - **Description:** Array item for nsgDefinitions.pe.securityRules
    - **`access`** (`string`) - Required
      - **Description:** Whether matching traffic is allowed or denied.

    - **`description`** (`string`) - Optional
      - **Description:** Free-form description for the rule.

    - **`destinationAddressPrefix`** (`string`) - Optional
      - **Description:** Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

    - **`destinationAddressPrefixes`** (`array`) - Optional
      - **Description:** Multiple destination address prefixes.

    - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional
      - **Description:** Destination Application Security Group (ASG) resource IDs.

    - **`destinationPortRange`** (`string`) - Optional
      - **Description:** Single destination port or port range (e.g., 443, 1000-2000).

    - **`destinationPortRanges`** (`array`) - Optional
      - **Description:** Multiple destination ports or port ranges.

    - **`direction`** (`string`) - Required
      - **Description:** Direction of the rule (Inbound or Outbound).

    - **`priority`** (`int`) - Required
      - **Description:** Priority of the rule (100–4096). Must be unique per rule in the NSG.

    - **`protocol`** (`string`) - Required
      - **Description:** Network protocol to match.

    - **`sourceAddressPrefix`** (`string`) - Optional
      - **Description:** Single source address prefix (e.g., Internet, 10.0.0.0/24).

    - **`sourceAddressPrefixes`** (`array`) - Optional
      - **Description:** Multiple source address prefixes.

    - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional
      - **Description:** Source Application Security Group (ASG) resource IDs.

    - **`sourcePortRange`** (`string`) - Optional
      - **Description:** Single source port or port range.

    - **`sourcePortRanges`** (`array`) - Optional
      - **Description:** Multiple source ports or port ranges.


  - **`tags`** (`object`) - Optional
    - **Description:** Tags to apply to the NSG.


### `openAiPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `openAiPrivateDnsZoneDefinition` | `object` | Optional | OpenAI Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for openAiPrivateDnsZoneDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for openAiPrivateDnsZoneDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for openAiPrivateDnsZoneDefinition.virtualNetworkLinks

### `privateDnsZonesDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `privateDnsZonesDefinition` | `object` | Optional | Private DNS Zone configuration for private endpoints. Used when not in platform landing zone mode. |

**Properties:**

- **`acrZoneId`** (`string`) - Optional
  - **Description:** Existing Private DNS Zone resource ID for Azure Container Registry.

- **`aiServicesZoneId`** (`string`) - Optional
  - **Description:** Existing Private DNS Zone resource ID for AI Services.

- **`allowInternetResolutionFallback`** (`bool`) - Optional
  - **Description:** Allow fallback to internet DNS resolution when Private DNS is unavailable.

- **`apimZoneId`** (`string`) - Optional
  - **Description:** Existing Private DNS Zone resource ID for Azure API Management.

- **`appConfigZoneId`** (`string`) - Optional
  - **Description:** Existing Private DNS Zone resource ID for App Configuration.

- **`appInsightsZoneId`** (`string`) - Optional
  - **Description:** Existing Private DNS Zone resource ID for Application Insights.

- **`blobZoneId`** (`string`) - Optional
  - **Description:** Existing Private DNS Zone resource ID for Blob Storage.

- **`cognitiveservicesZoneId`** (`string`) - Optional
  - **Description:** Existing Private DNS Zone resource ID for Cognitive Services.

- **`containerAppsZoneId`** (`string`) - Optional
  - **Description:** Existing Private DNS Zone resource ID for Container Apps.

- **`cosmosSqlZoneId`** (`string`) - Optional
  - **Description:** Existing Private DNS Zone resource ID for Cosmos DB (SQL API).

- **`createNetworkLinks`** (`bool`) - Optional
  - **Description:** Create VNet link to associate Spoke with the zones (can be empty).

- **`keyVaultZoneId`** (`string`) - Optional
  - **Description:** Existing Private DNS Zone resource ID for Key Vault.

- **`openaiZoneId`** (`string`) - Optional
  - **Description:** Existing Private DNS Zone resource ID for Azure OpenAI.

- **`searchZoneId`** (`string`) - Optional
  - **Description:** Existing Private DNS Zone resource ID for Azure Cognitive Search.

- **`tags`** (`object`) - Optional
  - **Description:** Tags to apply to the Private DNS Zones.

### `resourceIds`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `resourceIds` | `object` | Optional | Existing resource IDs to reuse (can be empty). |

**Properties:**

- **`acaEnvironmentNsgResourceId`** (`string`) - Optional
  - **Description:** Existing NSG resource ID to reuse for the Azure Container Apps environment subnet.

- **`agentNsgResourceId`** (`string`) - Optional
  - **Description:** Existing NSG resource ID to reuse for the agent (workload) subnet.

- **`apiManagementNsgResourceId`** (`string`) - Optional
  - **Description:** Existing NSG resource ID to reuse for the API Management subnet.

- **`apimServiceResourceId`** (`string`) - Optional
  - **Description:** Existing API Management service resource ID to reuse.

- **`appConfigResourceId`** (`string`) - Optional
  - **Description:** Existing App Configuration store resource ID to reuse.

- **`appGatewayPublicIpResourceId`** (`string`) - Optional
  - **Description:** Existing Public IP resource ID to reuse for the Application Gateway.

- **`appInsightsResourceId`** (`string`) - Optional
  - **Description:** Existing Application Insights resource ID to reuse.

- **`applicationGatewayNsgResourceId`** (`string`) - Optional
  - **Description:** Existing NSG resource ID to reuse for the Application Gateway subnet.

- **`applicationGatewayResourceId`** (`string`) - Optional
  - **Description:** Existing Application Gateway resource ID to reuse.

- **`bastionHostResourceId`** (`string`) - Optional
  - **Description:** Existing Azure Bastion resource ID to reuse; leave empty to skip.

- **`bastionNsgResourceId`** (`string`) - Optional
  - **Description:** Existing NSG resource ID to reuse for the Bastion host subnet.

- **`containerEnvResourceId`** (`string`) - Optional
  - **Description:** Existing Container Apps Environment resource ID to reuse.

- **`containerRegistryResourceId`** (`string`) - Optional
  - **Description:** Existing Azure Container Registry resource ID to reuse.

- **`dbAccountResourceId`** (`string`) - Optional
  - **Description:** Existing Cosmos DB account resource ID to reuse.

- **`devopsBuildAgentsNsgResourceId`** (`string`) - Optional
  - **Description:** Existing NSG resource ID to reuse for the DevOps build agents subnet.

- **`firewallPolicyResourceId`** (`string`) - Optional
  - **Description:** Existing Azure Firewall Policy resource ID to reuse.

- **`firewallPublicIpResourceId`** (`string`) - Optional
  - **Description:** Existing Public IP resource ID to reuse for the Azure Firewall.

- **`firewallResourceId`** (`string`) - Optional
  - **Description:** Existing Azure Firewall resource ID to reuse.

- **`groundingServiceResourceId`** (`string`) - Optional
  - **Description:** Existing Grounding service resource ID to reuse.

- **`jumpboxNsgResourceId`** (`string`) - Optional
  - **Description:** Existing NSG resource ID to reuse for the jumpbox (bastion-accessed) subnet.

- **`keyVaultResourceId`** (`string`) - Optional
  - **Description:** Existing Key Vault resource ID to reuse.

- **`logAnalyticsWorkspaceResourceId`** (`string`) - Optional
  - **Description:** Existing Log Analytics Workspace resource ID to reuse.

- **`peNsgResourceId`** (`string`) - Optional
  - **Description:** Existing NSG resource ID to reuse for the private endpoints (PE) subnet.

- **`searchServiceResourceId`** (`string`) - Optional
  - **Description:** Existing Azure AI Search service resource ID to reuse.

- **`storageAccountResourceId`** (`string`) - Optional
  - **Description:** Existing Storage Account resource ID to reuse.

- **`virtualNetworkResourceId`** (`string`) - Optional
  - **Description:** Existing VNet resource ID to reuse; leave empty to create a new VNet.

### `resourceToken`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `resourceToken` | `string` | Optional | Deterministic token for resource names; auto-generated if not provided. |

### `searchPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `searchPrivateDnsZoneDefinition` | `object` | Optional | Azure AI Search Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for searchPrivateDnsZoneDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for searchPrivateDnsZoneDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for searchPrivateDnsZoneDefinition.virtualNetworkLinks

### `searchPrivateEndpointDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `searchPrivateEndpointDefinition` | `object` | Optional | Azure AI Search Private Endpoint configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for searchPrivateEndpointDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for searchPrivateEndpointDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for searchPrivateEndpointDefinition.virtualNetworkLinks

### `storageBlobPrivateEndpointDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `storageBlobPrivateEndpointDefinition` | `object` | Optional | Storage Account Private Endpoint configuration. |

**Properties:**

- **`a`** (`array`) - Optional
  - **Description:** A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required
    - **Description:** List of IPv4 addresses.

  - **`name`** (`string`) - Required
    - **Description:** Name of the A record.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the A record.

  - **`ttl`** (`int`) - Optional
    - **Description:** Time-to-live for the record.


- **`a[*]`** (`object`) - Optional
  - **Description:** Array item for storageBlobPrivateEndpointDefinition.a

- **`enableTelemetry`** (`bool`) - Optional
  - **Description:** Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional
  - **Description:** Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional
  - **Description:** Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional
    - **Description:** Lock type.

  - **`name`** (`string`) - Optional
    - **Description:** Lock name.

  - **`notes`** (`string`) - Optional
    - **Description:** Lock notes.


- **`name`** (`string`) - Required
  - **Description:** The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional
  - **Description:** Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional
    - **Description:** Description of the role assignment.

  - **`name`** (`string`) - Optional
    - **Description:** Name for the role assignment.

  - **`principalId`** (`string`) - Required
    - **Description:** Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional
    - **Description:** Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required
    - **Description:** Role definition ID or name.


- **`roleAssignments[*]`** (`object`) - Optional
  - **Description:** Array item for storageBlobPrivateEndpointDefinition.roleAssignments

- **`tags`** (`object`) - Optional
  - **Description:** Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional
  - **Description:** Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required
    - **Description:** The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional
    - **Description:** Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional
    - **Description:** Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required
    - **Description:** Resource ID of the virtual network to link.


- **`virtualNetworkLinks[*]`** (`object`) - Optional
  - **Description:** Array item for storageBlobPrivateEndpointDefinition.virtualNetworkLinks

### `tags`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `tags` | `object` | Optional | Tags to apply to all resources. |

## Outputs

| Output Name | Type | Description |
| :-- | :-- | :-- |
| `acaEnvironmentNsgResourceId` | string | Azure Container Apps Environment subnet Network Security Group resource ID (newly created or existing). |
| `acrPrivateDnsZoneResourceId` | string | Container Registry Private DNS Zone resource ID (newly created or existing). |
| `agentNsgResourceId` | string | Agent subnet Network Security Group resource ID (newly created or existing). |
| `aiFoundryAiServicesName` | string | AI Foundry AI Services name. |
| `aiFoundryCosmosAccountName` | string | AI Foundry Cosmos DB account name. |
| `aiFoundryKeyVaultName` | string | AI Foundry Key Vault name. |
| `aiFoundryProjectName` | string | AI Foundry project name. |
| `aiFoundryResourceGroupName` | string | AI Foundry resource group name. |
| `aiFoundrySearchServiceName` | string | AI Foundry AI Search service name. |
| `aiFoundryStorageAccountName` | string | AI Foundry Storage Account name. |
| `aiSearchName` | string | AI Search name. |
| `aiSearchResourceId` | string | AI Search resource ID. |
| `aiServicesPrivateDnsZoneResourceId` | string | AI Services Private DNS Zone resource ID (newly created or existing). |
| `apiManagementNsgResourceId` | string | API Management subnet Network Security Group resource ID (newly created or existing). |
| `apimPrivateDnsZoneResourceId` | string | API Management Private DNS Zone resource ID (newly created or existing). |
| `apimServiceName` | string | API Management service name. |
| `apimServiceResourceId` | string | API Management service resource ID. |
| `appConfigPrivateDnsZoneResourceId` | string | App Configuration Private DNS Zone resource ID (newly created or existing). |
| `appConfigResourceId` | string | App Configuration Store resource ID. |
| `appGatewayPublicIpResourceId` | string | Application Gateway Public IP resource ID (newly created or existing). |
| `appInsightsPrivateDnsZoneResourceId` | string | Application Insights Private DNS Zone resource ID (newly created or existing). |
| `appInsightsResourceId` | string | Application Insights resource ID. |
| `applicationGatewayName` | string | Application Gateway name. |
| `applicationGatewayNsgResourceId` | string | Application Gateway subnet Network Security Group resource ID (newly created or existing). |
| `applicationGatewayResourceId` | string | Application Gateway resource ID (newly created or existing). |
| `bingConnectionId` | string | Bing Search connection ID (if deployed). |
| `bingResourceGroupName` | string | Bing Search resource group name (if deployed). |
| `bingSearchResourceId` | string | Bing Search service resource ID (if deployed). |
| `blobPrivateDnsZoneResourceId` | string | Blob Storage Private DNS Zone resource ID (newly created or existing). |
| `buildVmName` | string | Build VM name (if deployed). |
| `buildVmResourceId` | string | Build VM resource ID (if deployed). |
| `cognitiveServicesPrivateDnsZoneResourceId` | string | Cognitive Services Private DNS Zone resource ID (newly created or existing). |
| `containerAppsCount` | int | Container Apps deployment count. |
| `containerAppsPrivateDnsZoneResourceId` | string | Container Apps Private DNS Zone resource ID (newly created or existing). |
| `containerEnvResourceId` | string | Container App Environment resource ID. |
| `containerRegistryResourceId` | string | Container Registry resource ID. |
| `cosmosDbName` | string | Cosmos DB name. |
| `cosmosDbResourceId` | string | Cosmos DB resource ID. |
| `cosmosSqlPrivateDnsZoneResourceId` | string | Cosmos DB (SQL API) Private DNS Zone resource ID (newly created or existing). |
| `devopsBuildAgentsNsgResourceId` | string | DevOps Build Agents subnet Network Security Group resource ID (newly created or existing). |
| `firewallName` | string | Azure Firewall name. |
| `firewallPolicyName` | string | Azure Firewall Policy name (if deployed). |
| `firewallPolicyResourceId` | string | Azure Firewall Policy resource ID (if deployed). |
| `firewallPrivateIp` | string | Azure Firewall private IP address (if deployed). |
| `firewallPublicIpResourceId` | string | Firewall Public IP resource ID (newly created or existing). |
| `firewallResourceId` | string | Azure Firewall resource ID (newly created or existing). |
| `hubToSpokePeeringResourceId` | string | Hub to Spoke peering resource ID (if hub peering is enabled). |
| `jumpboxNsgResourceId` | string | Jumpbox subnet Network Security Group resource ID (newly created or existing). |
| `jumpVmName` | string | Jump VM name (if deployed). |
| `jumpVmResourceId` | string | Jump VM resource ID (if deployed). |
| `keyVaultName` | string | Key Vault name. |
| `keyVaultPrivateDnsZoneResourceId` | string | Key Vault Private DNS Zone resource ID (newly created or existing). |
| `keyVaultResourceId` | string | Key Vault resource ID. |
| `logAnalyticsWorkspaceResourceId` | string | Log Analytics workspace resource ID. |
| `openAiPrivateDnsZoneResourceId` | string | OpenAI Private DNS Zone resource ID (newly created or existing). |
| `peNsgResourceId` | string | Private Endpoints subnet Network Security Group resource ID (newly created or existing). |
| `searchPrivateDnsZoneResourceId` | string | Azure AI Search Private DNS Zone resource ID (newly created or existing). |
| `storageAccountResourceId` | string | Storage Account resource ID. |
| `virtualNetworkResourceId` | string | Virtual Network resource ID (newly created or existing). |
| `wafPolicyName` | string | WAF Policy name (if deployed). |
| `wafPolicyResourceId` | string | WAF Policy resource ID (if deployed). |


