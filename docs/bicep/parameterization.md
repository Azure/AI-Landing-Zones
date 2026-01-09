# How to Parameterize the Bicep Template

You can customize the AI Landing Zones Bicep template by setting parameters in `bicep/infra/main.bicepparam`. Use this file to adapt the deployment to your environment and requirements.

Configuration snippet:

```bicep
using './main.bicep'

param location = 'eastus2'
param baseName = 'myailz'
param deployToggles = {
  acaEnvironmentNsg: true
  agentNsg: true
  apiManagement: true
  ...
  storageAccount: true
  virtualNetwork: true
  wafPolicy: true
}
param resourceIds = {}
param flagPlatformLandingZone = false
```

## Overview

The template supports multiple deployment patterns through parameter configuration:

**Platform Integration**

Use `flagPlatformLandingZone` when you want to integrate this workload landing zone into an existing “platform landing zone” that already owns shared networking/DNS. When `flagPlatformLandingZone=true`, this template assumes private DNS zones (and typically hub-level networking such as Firewall/Bastion subnets) are managed outside this deployment. The workload deployment still creates workload resources and private endpoints, but it will avoid creating/configuring private DNS zones in the current resource group and will instead rely on the DNS zone IDs you provide (see `privateDnsZonesDefinition.*ZoneId`).

**Resource Reuse**

Use `resourceIds` to switch a component from “create” to “reuse”. The common pattern in `bicep/infra/main.bicep` is:

- **Create new**: set `deployToggles.<service>=true` and leave `resourceIds.<service>ResourceId` empty.
- **Reuse existing**: set `resourceIds.<service>ResourceId` to an existing resource ID (and keep the corresponding toggle enabled when you want the landing zone to integrate with it).

This lets you mix-and-match (for example: reuse an existing VNet and Log Analytics workspace, but deploy new Key Vault + Storage).

**AI Foundry Options**

You can deploy AI Foundry in different “depths” by combining `deployToggles.aiFoundry` with `aiFoundryDefinition`:

- **Full setup (default behavior)**: `deployToggles.aiFoundry=true` and leave `aiFoundryDefinition` as-is. By default, the template deploys Foundry and (unless explicitly disabled) also deploys capability hosts and associated resources.

- **Project-only (no capability hosts, no associated resources)**: keep `deployToggles.aiFoundry=true` but set the two flags below. This deploys the AI Foundry account/project and model deployments, without creating capability hosts (agent service) or provisioning dependent resources.

  ```bicep
  param deployToggles = {
    // ...
    aiFoundry: true
  }

  param aiFoundryDefinition = {
    includeAssociatedResources: false
    aiFoundryConfiguration: {
      createCapabilityHosts: false
    }
  }
  ```

  If you disable associated resources, you will typically either (1) provide Foundry-specific backing services through `resourceIds.aiFoundry*` (Search/Storage/Cosmos/Key Vault), or (2) accept that those dependencies will not be created by this deployment.

- **Custom model deployments**: override `aiFoundryDefinition.aiModelDeployments`. The template maps deployments using `model.name`, `model.format`, `model.version`, and `sku.name` / `sku.capacity`.

  ```bicep
  param aiFoundryDefinition = {
    aiModelDeployments: [
      {
        name: 'my-gpt'
        model: {
          name: 'gpt-5-mini'
          format: 'OpenAI'
          version: '2025-08-07'
        }
        sku: {
          name: 'GlobalStandard'
          capacity: 10
        }
      }
    ]
  }
  ```

* **Enable/disable**: Set `deployToggles.aiFoundry` to control whether AI Foundry (and its internal dependencies) are deployed
* **Full setup**: AI Foundry with all dependencies (Search, Cosmos DB, Key Vault, and Storage)
* **Project only**: AI Foundry project only (no Agent Service or dependencies)
* **Custom models**: Configure specific AI model deployments

**Default Values**

Most parameters are optional. Defaults are defined in `bicep/infra/main.bicep` (and in some cases inside upstream AVM modules).

User-Defined Types (UDTs) in `bicep/infra/common/types.bicep` define the expected shape of parameters (types, allowed properties, validation).

For most "definition" objects (for example, `*Definition` parameters), the template follows a "defaults + overrides" pattern and merges your input on top of the defaults (often using a pattern like `union({ /* defaults */ }, userDefinition ?? {})`). This means you can provide only the properties you want to change.

Practical rule:

- If you omit an entire parameter from your `.bicepparam`, the template uses the default value.
- If you provide an object parameter, any property you set overrides the default for that property; any property you omit keeps the default.
- Some components are implemented via upstream AVM modules, which may apply additional defaults inside the module.

**Naming**

The template uses `resourceToken` (auto-generated if omitted) and `baseName` (defaults to a 12-char token derived from `resourceToken`) to generate deterministic names. Many component definition objects allow you to override the name explicitly; if you leave the name blank/empty, the template generates a valid name derived from `baseName`.

## Template Parameters

The parameters are organized into three categories:
- **Required Parameters**: Must be provided for the template to deploy successfully
- **Conditional Parameters**: Required only when certain features or components are enabled
- **Optional Parameters**: Have default values but can be customized as needed

Each parameter includes information about its type, requirements, default values (where applicable), and detailed descriptions of its purpose and usage.

## Parameters

### Required Parameters

### `deployToggles`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `deployToggles` | `object` | Required | Per-service deployment toggles. |

**Properties:**

- **`acaEnvironmentNsg`** (`bool`) - Required.
  Toggle to deploy NSG for Azure Container Apps environment subnet (true) or not (false).

- **`agentNsg`** (`bool`) - Required.
  Toggle to deploy NSG for agent (workload) subnet (true) or not (false).

- **`aiFoundry`** (`bool`) - Required.
  Toggle to deploy AI Foundry (true) or not (false).

- **`apiManagement`** (`bool`) - Required.
  Toggle to deploy API Management (true) or not (false).

- **`apiManagementNsg`** (`bool`) - Required.
  Toggle to deploy NSG for API Management subnet (true) or not (false).

- **`appConfig`** (`bool`) - Required.
  Toggle to deploy App Configuration (true) or not (false).

- **`appInsights`** (`bool`) - Required.
  Toggle to deploy Application Insights (true) or not (false).

- **`applicationGateway`** (`bool`) - Required.
  Toggle to deploy Application Gateway (true) or not (false).

- **`applicationGatewayNsg`** (`bool`) - Required.
  Toggle to deploy NSG for Application Gateway subnet (true) or not (false).

- **`applicationGatewayPublicIp`** (`bool`) - Required.
  Toggle to deploy a Public IP address for the Application Gateway (true) or not (false).

- **`bastionHost`** (`bool`) - Required.
  Toggle to deploy an Azure Bastion host (true) or not (false).

- **`bastionNsg`** (`bool`) - Required.
  Toggle to deploy NSG for Bastion host subnet (true) or not (false).

- **`buildVm`** (`bool`) - Required.
  Toggle to deploy Build VM (true) or not (false).

- **`containerApps`** (`bool`) - Required.
  Toggle to deploy Container Apps (true) or not (false).

- **`containerEnv`** (`bool`) - Required.
  Toggle to deploy Container Apps Environment (true) or not (false).

- **`containerRegistry`** (`bool`) - Required.
  Toggle to deploy Azure Container Registry (true) or not (false).

- **`cosmosDb`** (`bool`) - Required.
  Toggle to deploy Cosmos DB (true) or not (false).

- **`devopsBuildAgentsNsg`** (`bool`) - Required.
  Toggle to deploy NSG for DevOps build agents subnet (true) or not (false).

- **`firewall`** (`bool`) - Required.
  Toggle to deploy Azure Firewall (true) or not (false).

- **`groundingWithBingSearch`** (`bool`) - Required.
  Toggle to deploy Bing Grounding with Search (true) or not (false).

- **`jumpboxNsg`** (`bool`) - Required.
  Toggle to deploy NSG for jumpbox (bastion-accessed) subnet (true) or not (false).

- **`jumpVm`** (`bool`) - Required.
  Toggle to deploy Jump VM (true) or not (false).

- **`keyVault`** (`bool`) - Required.
  Toggle to deploy Key Vault (true) or not (false).

- **`logAnalytics`** (`bool`) - Required.
  Toggle to deploy Log Analytics (true) or not (false).

- **`peNsg`** (`bool`) - Required.
  Toggle to deploy NSG for private endpoints (PE) subnet (true) or not (false).

- **`searchService`** (`bool`) - Required.
  Toggle to deploy Azure AI Search (true) or not (false).

- **`storageAccount`** (`bool`) - Required.
  Toggle to deploy Storage Account (true) or not (false).

- **`virtualNetwork`** (`bool`) - Required.
  Toggle to deploy a new Virtual Network (true) or not (false).

- **`wafPolicy`** (`bool`) - Required.
  Toggle to deploy an Application Gateway WAF policy (true) or not (false).

### Conditional Parameters

### `appConfigurationDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `appConfigurationDefinition` | `object` | Conditional | App Configuration store settings. Required if deploy.appConfig is true and resourceIds.appConfigResourceId is empty. |

**Properties:**

- **`createMode`** (`string`) - Optional.
  Indicates whether the configuration store needs to be recovered.

- **`customerManagedKey`** (`object`) - Optional.
  Customer Managed Key definition.
  - **`autoRotationEnabled`** (`bool`) - Optional.
    Enable or disable auto-rotation (default true).

  - **`keyName`** (`string`) - Required.
    Key name used for encryption.

  - **`keyVaultResourceId`** (`string`) - Required.
    Resource ID of the Key Vault containing the key.

  - **`keyVersion`** (`string`) - Optional.
    Specific key version to use.

  - **`userAssignedIdentityResourceId`** (`string`) - Optional.
    User-assigned identity resource ID if system identity is not available.


- **`dataPlaneProxy`** (`object`) - Optional.
  Data plane proxy configuration for ARM.
  - **`authenticationMode`** (`string`) - Optional.
    Authentication mode for data plane proxy.

  - **`privateLinkDelegation`** (`string`) - Required.
    Whether private link delegation is enabled.


- **`diagnosticSettings`** (`array`) - Optional.
  Diagnostic settings for the service.
  - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional.
    Resource ID of the diagnostic event hub authorization rule.

  - **`eventHubName`** (`string`) - Optional.
    Name of the diagnostic Event Hub.

  - **`logAnalyticsDestinationType`** (`string`) - Optional.
    Destination type for Log Analytics. Allowed values: AzureDiagnostics, Dedicated.

  - **`logCategoriesAndGroups`** (`array`) - Optional.
    Log categories and groups to stream.
    - **`category`** (`string`) - Optional.
      Name of a diagnostic log category.

    - **`categoryGroup`** (`string`) - Optional.
      Name of a diagnostic log category group.

    - **`enabled`** (`bool`) - Optional.
      Enable or disable the category. Default true.

  - **`marketplacePartnerResourceId`** (`string`) - Optional.
    Marketplace partner resource ID.

  - **`metricCategories`** (`array`) - Optional.
    Metric categories to stream.
    - **`category`** (`string`) - Required.
      Diagnostic metric category name.

    - **`enabled`** (`bool`) - Optional.
      Enable or disable the metric category. Default true.

  - **`name`** (`string`) - Optional.
    Diagnostic setting name.

  - **`storageAccountResourceId`** (`string`) - Optional.
    Storage account resource ID for diagnostic logs.

  - **`workspaceResourceId`** (`string`) - Optional.
    Log Analytics workspace resource ID for diagnostic logs.
- **`disableLocalAuth`** (`bool`) - Optional.
  Disable all non-AAD authentication methods.

- **`enablePurgeProtection`** (`bool`) - Optional.
  Enable purge protection (default true, except Free SKU).

- **`enableTelemetry`** (`bool`) - Optional.
  Enable or disable usage telemetry for module.

- **`keyValues`** (`array`) - Optional.
  List of key/values to create (requires local auth).

- **`location`** (`string`) - Optional.
  Location for the resource (default resourceGroup().location).

- **`lock`** (`object`) - Optional.
  Lock settings.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`managedIdentities`** (`object`) - Optional.
  Managed identity configuration.
  - **`systemAssigned`** (`bool`) - Optional.
    Enable system-assigned managed identity.

  - **`userAssignedResourceIds`** (`array`) - Optional.
    User-assigned identity resource IDs.


- **`name`** (`string`) - Required.
  Name of the Azure App Configuration.

- **`privateEndpoints`** (`array`) - Optional.
  Private endpoint configuration.
  - **`applicationSecurityGroupResourceIds`** (`array`) - Optional.
    Application Security Group resource IDs.

  - **`customDnsConfigs`** (`array`) - Optional.
    Custom DNS configs.
    - **`fqdn`** (`string`) - Optional.
      FQDN that maps to the private IPs.

    - **`ipAddresses`** (`array`) - Required.
      Private IP addresses for the endpoint.

  - **`customNetworkInterfaceName`** (`string`) - Optional.
    Custom network interface name.

  - **`enableTelemetry`** (`bool`) - Optional.
    Enable or disable usage telemetry for the module.

  - **`ipConfigurations`** (`array`) - Optional.
    Explicit IP configurations for the Private Endpoint.
    - **`name`** (`string`) - Required.
      Name of this IP configuration.

    - **`properties`** (`object`) - Required.
      Object defining groupId, memberName, and privateIPAddress for the private endpoint IP configuration.
      - **`groupId`** (`string`) - Required.
        Group ID from the remote resource.

      - **`memberName`** (`string`) - Required.
        Member name from the remote resource.

      - **`privateIPAddress`** (`string`) - Required.
        Private IP address from the PE subnet.


  - **`isManualConnection`** (`bool`) - Optional.
    Use manual Private Link approval flow.

  - **`location`** (`string`) - Optional.
    Location to deploy the Private Endpoint to.

  - **`lock`** (`object`) - Optional.
    Lock settings for the Private Endpoint.
    - **`kind`** (`string`) - Optional.
      Lock type.

    - **`name`** (`string`) - Optional.
      Lock name.

    - **`notes`** (`string`) - Optional.
      Lock notes.


  - **`manualConnectionRequestMessage`** (`string`) - Optional.
    Manual connection request message.

  - **`name`** (`string`) - Optional.
    Name of the Private Endpoint resource.

  - **`privateDnsZoneGroup`** (`object`) - Optional.
    Private DNS Zone group configuration.
    - **`name`** (`string`) - Optional.
      Name of the Private DNS Zone group.

    - **`privateDnsZoneGroupConfigs`** (`array`) - Required.
      Configs for linking PDNS zones.
      - **`name`** (`string`) - Optional.
        Name of this DNS zone config.

      - **`privateDnsZoneResourceId`** (`string`) - Required.
        Private DNS Zone resource ID.


  - **`privateLinkServiceConnectionName`** (`string`) - Optional.
    Private Link service connection name.

  - **`resourceGroupResourceId`** (`string`) - Optional.
    Resource group resource ID to place the PE in.

  - **`roleAssignments`** (`array`) - Optional.
    Role assignments for the Private Endpoint.

  - **`service`** (`string`) - Optional.
    Target service group ID (as string).

  - **`subnetResourceId`** (`string`) - Required.
    Subnet resource ID for the private endpoint.

  - **`tags`** (`object`) - Optional.
    Tags to apply to the Private Endpoint.


- **`publicNetworkAccess`** (`string`) - Optional.
  Whether public network access is allowed.

- **`replicaLocations`** (`array`) - Optional.
  Replica locations.
  - **`name`** (`string`) - Optional.
    Replica name.

  - **`replicaLocation`** (`string`) - Required.
    Azure region name for the replica.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for App Configuration.

- **`sku`** (`string`) - Optional.
  Pricing tier of App Configuration.

- **`softDeleteRetentionInDays`** (`int`) - Optional.
  Retention period in days for soft delete (1–7). Default 1.

- **`tags`** (`object`) - Optional.
  Tags for the resource.

### `appGatewayDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `appGatewayDefinition` | `object` | Conditional | Application Gateway configuration. Required if deploy.applicationGateway is true and resourceIds.applicationGatewayResourceId is empty. |

**Properties:**

- **`authenticationCertificates`** (`array`) - Optional.
  Authentication certificates of the Application Gateway.

- **`autoscaleMaxCapacity`** (`int`) - Optional.
  Maximum autoscale capacity.

- **`autoscaleMinCapacity`** (`int`) - Optional.
  Minimum autoscale capacity.

- **`availabilityZones`** (`array`) - Optional.
  Availability zones used by the gateway.

- **`backendAddressPools`** (`array`) - Optional.
  Backend address pools of the Application Gateway.

- **`backendHttpSettingsCollection`** (`array`) - Optional.
  Backend HTTP settings.

- **`backendSettingsCollection`** (`array`) - Optional.
  Backend settings collection (see limits).

- **`capacity`** (`int`) - Optional.
  Static instance capacity. Default is 2.

- **`customErrorConfigurations`** (`array`) - Optional.
  Custom error configurations.

- **`diagnosticSettings`** (`array`) - Optional.
  Diagnostic settings for the Application Gateway.

- **`enableFips`** (`bool`) - Optional.
  Whether FIPS is enabled.

- **`enableHttp2`** (`bool`) - Optional.
  Whether HTTP/2 is enabled.

- **`enableRequestBuffering`** (`bool`) - Optional.
  Enable request buffering.

- **`enableResponseBuffering`** (`bool`) - Optional.
  Enable response buffering.

- **`enableTelemetry`** (`bool`) - Optional.
  Enable or disable telemetry (default true).

- **`firewallPolicyResourceId`** (`string`) - Conditional.
  Resource ID of the associated firewall policy. Required if SKU is WAF_v2.

- **`frontendIPConfigurations`** (`array`) - Optional.
  Frontend IP configurations.

- **`frontendPorts`** (`array`) - Optional.
  Frontend ports.

- **`gatewayIPConfigurations`** (`array`) - Optional.
  Gateway IP configurations (subnets).

- **`httpListeners`** (`array`) - Optional.
  HTTP listeners.

- **`listeners`** (`array`) - Optional.
  Listeners (see limits).

- **`loadDistributionPolicies`** (`array`) - Optional.
  Load distribution policies.

- **`location`** (`string`) - Optional.
  Location of the Application Gateway.

- **`lock`** (`object`) - Optional.
  Lock settings.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`managedIdentities`** (`object`) - Optional.
  Managed identities for the Application Gateway.
  - **`userAssignedResourceIds`** (`array`) - Optional.
    User-assigned managed identity resource IDs.


- **`name`** (`string`) - Required.
  Name of the Application Gateway.

- **`privateEndpoints`** (`array`) - Optional.
  Private endpoints configuration.

- **`privateLinkConfigurations`** (`array`) - Optional.
  Private link configurations.

- **`probes`** (`array`) - Optional.
  Probes for backend health monitoring.

- **`redirectConfigurations`** (`array`) - Optional.
  Redirect configurations.

- **`requestRoutingRules`** (`array`) - Optional.
  Request routing rules.

- **`rewriteRuleSets`** (`array`) - Optional.
  Rewrite rule sets.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Application Gateway.

- **`routingRules`** (`array`) - Optional.
  Routing rules.

- **`sku`** (`string`) - Optional.
  SKU of the Application Gateway. Default is WAF_v2.

- **`sslCertificates`** (`array`) - Optional.
  SSL certificates.

- **`sslPolicyCipherSuites`** (`array`) - Optional.
  SSL policy cipher suites.

- **`sslPolicyMinProtocolVersion`** (`string`) - Optional.
  Minimum SSL protocol version.

- **`sslPolicyName`** (`string`) - Optional.
  Predefined SSL policy name.

- **`sslPolicyType`** (`string`) - Optional.
  SSL policy type.

- **`sslProfiles`** (`array`) - Optional.
  SSL profiles.

- **`tags`** (`object`) - Optional.
  Resource tags.

- **`trustedClientCertificates`** (`array`) - Optional.
  Trusted client certificates.

- **`trustedRootCertificates`** (`array`) - Optional.
  Trusted root certificates.

- **`urlPathMaps`** (`array`) - Optional.
  URL path maps.

### `appGatewayPublicIp`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `appGatewayPublicIp` | `object` | Conditional | Conditional Public IP for Application Gateway. Requred when deploy applicationGatewayPublicIp is true and no existing ID is provided. |

**Properties:**

- **`ddosSettings`** (`object`) - Optional.
  DDoS protection settings for the Public IP Address.
  - **`ddosProtectionPlan`** (`object`) - Optional.
    Associated DDoS protection plan.
    - **`id`** (`string`) - Required.
      Resource ID of the DDoS protection plan.


  - **`protectionMode`** (`string`) - Required.
    DDoS protection mode. Allowed value: Enabled.


- **`diagnosticSettings`** (`array`) - Optional.
  Diagnostic settings for the Public IP Address.
  - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional.
    Resource ID of the diagnostic Event Hub authorization rule.

  - **`eventHubName`** (`string`) - Optional.
    Name of the diagnostic Event Hub.

  - **`logAnalyticsDestinationType`** (`string`) - Optional.
    Log Analytics destination type. Allowed values: AzureDiagnostics, Dedicated.

  - **`logCategoriesAndGroups`** (`array`) - Optional.
    Log categories and groups to collect. Set to [] to disable log collection.
    - **`category`** (`string`) - Optional.
      Name of a diagnostic log category.

    - **`categoryGroup`** (`string`) - Optional.
      Name of a diagnostic log category group. Use allLogs to collect all logs.

    - **`enabled`** (`bool`) - Optional.
      Enable or disable the log category. Default is true.

  - **`marketplacePartnerResourceId`** (`string`) - Optional.
    Marketplace partner resource ID.

  - **`metricCategories`** (`array`) - Optional.
    Metric categories to collect. Set to [] to disable metric collection.
    - **`category`** (`string`) - Required.
      Name of a diagnostic metric category. Use AllMetrics to collect all metrics.

    - **`enabled`** (`bool`) - Optional.
      Enable or disable the metric category. Default is true.

  - **`name`** (`string`) - Optional.
    Name of the diagnostic setting.

  - **`storageAccountResourceId`** (`string`) - Optional.
    Resource ID of the diagnostic storage account.

  - **`workspaceResourceId`** (`string`) - Optional.
    Resource ID of the diagnostic Log Analytics workspace.
- **`dnsSettings`** (`object`) - Optional.
  DNS settings for the Public IP Address.
  - **`domainNameLabel`** (`string`) - Required.
    Domain name label used to create an A DNS record in Azure DNS.

  - **`domainNameLabelScope`** (`string`) - Optional.
    Domain name label scope. Allowed values: NoReuse, ResourceGroupReuse, SubscriptionReuse, TenantReuse.

  - **`fqdn`** (`string`) - Optional.
    Fully qualified domain name (FQDN) associated with the Public IP.

  - **`reverseFqdn`** (`string`) - Optional.
    Reverse FQDN used for PTR records.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable or disable usage telemetry for the module. Default is true.

- **`idleTimeoutInMinutes`** (`int`) - Optional.
  Idle timeout in minutes for the Public IP Address. Default is 4.

- **`ipTags`** (`array`) - Optional.
  IP tags associated with the Public IP Address.
  - **`ipTagType`** (`string`) - Required.
    IP tag type.

  - **`tag`** (`string`) - Required.
    IP tag value.

- **`location`** (`string`) - Optional.
  Location for the resource. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional.
  Lock configuration for the Public IP Address.
  - **`kind`** (`string`) - Optional.
    Lock type. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  Name of the Public IP Address.

- **`publicIPAddressVersion`** (`string`) - Optional.
  IP address version. Default is IPv4. Allowed values: IPv4, IPv6.

- **`publicIPAllocationMethod`** (`string`) - Optional.
  Public IP allocation method. Default is Static. Allowed values: Dynamic, Static.

- **`publicIpPrefixResourceId`** (`string`) - Optional.
  Resource ID of the Public IP Prefix to allocate from.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments to apply to the Public IP Address.
  - **`condition`** (`string`) - Optional.
    Condition for the role assignment.

  - **`conditionVersion`** (`string`) - Optional.
    Condition version. Allowed value: 2.0.

  - **`delegatedManagedIdentityResourceId`** (`string`) - Optional.
    Delegated managed identity resource ID.

  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Role assignment name (GUID). If omitted, a GUID is generated.

  - **`principalId`** (`string`) - Required.
    Principal ID of the identity being assigned.

  - **`principalType`** (`string`) - Optional.
    Principal type of the assigned identity. Allowed values: Device, ForeignGroup, Group, ServicePrincipal, User.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role to assign (display name, GUID, or full resource ID).


- **`skuName`** (`string`) - Optional.
  SKU name for the Public IP Address. Default is Standard. Allowed values: Basic, Standard.

- **`skuTier`** (`string`) - Optional.
  SKU tier for the Public IP Address. Default is Regional. Allowed values: Global, Regional.

- **`tags`** (`object`) - Optional.
  Tags to apply to the Public IP Address resource.

- **`zones`** (`array`) - Optional.
  Availability zones for the Public IP Address allocation. Allowed values: 1, 2, 3.

### `appInsightsDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `appInsightsDefinition` | `object` | Conditional | Application Insights configuration. Required if deploy.appInsights is true and resourceIds.appInsightsResourceId is empty; a Log Analytics workspace must exist or be deployed. |

### `buildVmDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `buildVmDefinition` | `object` | Conditional | Build VM configuration to support CI/CD workers (Linux). Required if deploy.buildVm is true. |

**Properties:**

- **`adminPassword`** (`securestring`) - Optional.
  Admin password for the VM.

- **`adminUsername`** (`string`) - Optional.
  Admin username to create (e.g., azureuser).

- **`availabilityZone`** (`int`) - Optional.
  Availability zone.

- **`azdo`** (`object`) - Optional.
  Azure DevOps settings (required when runner = azdo, Build VM only).
  - **`agentName`** (`string`) - Optional.
    Agent name.

  - **`orgUrl`** (`string`) - Required.
    Azure DevOps organization URL (e.g., https://dev.azure.com/contoso).

  - **`pool`** (`string`) - Required.
    Agent pool name.

  - **`workFolder`** (`string`) - Optional.
    Working folder.


- **`disablePasswordAuthentication`** (`bool`) - Optional.
  Disable password authentication (Build VM only).

- **`enableAutomaticUpdates`** (`bool`) - Optional.
  Enable automatic updates (Jump VM only).

- **`enableTelemetry`** (`bool`) - Optional.
  Enable telemetry via a Globally Unique Identifier (GUID).

- **`github`** (`object`) - Optional.
  GitHub settings (required when runner = github, Build VM only).
  - **`agentName`** (`string`) - Optional.
    Runner name.

  - **`labels`** (`string`) - Optional.
    Runner labels (comma-separated).

  - **`owner`** (`string`) - Required.
    GitHub owner (org or user).

  - **`repo`** (`string`) - Required.
    Repository name.

  - **`workFolder`** (`string`) - Optional.
    Working folder.


- **`imageReference`** (`object`) - Optional.
  Marketplace image reference for the VM.
  - **`communityGalleryImageId`** (`string`) - Optional.
    Community gallery image ID.

  - **`id`** (`string`) - Optional.
    Resource ID.

  - **`offer`** (`string`) - Optional.
    Offer name.

  - **`publisher`** (`string`) - Optional.
    Publisher name.

  - **`sharedGalleryImageId`** (`string`) - Optional.
    Shared gallery image ID.

  - **`sku`** (`string`) - Optional.
    SKU name.

  - **`version`** (`string`) - Optional.
    Image version (e.g., latest).


- **`location`** (`string`) - Optional.
  Location for all resources.

- **`lock`** (`object`) - Optional.
  Lock configuration.

- **`maintenanceConfigurationResourceId`** (`string`) - Optional.
  Resource ID of the maintenance configuration (Jump VM only).

- **`managedIdentities`** (`object`) - Optional.
  Managed identities.

- **`name`** (`string`) - Optional.
  VM name.

- **`nicConfigurations`** (`array`) - Optional.
  Network interface configurations.

- **`osDisk`** (`object`) - Optional.
  OS disk configuration.

- **`osType`** (`string`) - Optional.
  OS type for the VM.

- **`patchMode`** (`string`) - Optional.
  Patch mode for the VM (Jump VM only).

- **`publicKeys`** (`array`) - Optional.
  SSH public keys (Build VM only).

- **`requireGuestProvisionSignal`** (`bool`) - Optional.
  Force password reset on first login.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments.

- **`runner`** (`string`) - Optional.
  Which agent to install (Build VM only).

- **`sku`** (`string`) - Optional.
  VM size SKU (e.g., Standard_B2s, Standard_D2s_v5).

- **`tags`** (`object`) - Optional.
  Tags to apply to the VM resource.

### `containerAppEnvDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `containerAppEnvDefinition` | `object` | Conditional | Container Apps Environment configuration. Required if deploy.containerEnv is true and resourceIds.containerEnvResourceId is empty. |

**Properties:**

- **`appInsightsConnectionString`** (`securestring`) - Optional.
  Application Insights connection string.

- **`appLogsConfiguration`** (`object`) - Optional.
  App Logs configuration for the Managed Environment.
  - **`destination`** (`string`) - Optional.
    Destination of the logs. Allowed values: azure-monitor, log-analytics, none.

  - **`logAnalyticsConfiguration`** (`object`) - Conditional.
    Log Analytics configuration. Required if destination is log-analytics.
    - **`customerId`** (`string`) - Required.
      Log Analytics Workspace ID.

    - **`sharedKey`** (`securestring`) - Required.
      Shared key of the Log Analytics workspace.



- **`certificate`** (`object`) - Optional.
  Managed Environment Certificate configuration.
  - **`certificateKeyVaultProperties`** (`object`) - Optional.
    Key Vault reference for certificate.
    - **`identityResourceId`** (`string`) - Required.
      Identity resource ID used to access Key Vault.

    - **`keyVaultUrl`** (`string`) - Required.
      Key Vault URL referencing the certificate.


  - **`certificatePassword`** (`string`) - Optional.
    Certificate password.

  - **`certificateType`** (`string`) - Optional.
    Certificate type. Allowed values: ImagePullTrustedCA, ServerSSLCertificate.

  - **`certificateValue`** (`string`) - Optional.
    Certificate value (PFX or PEM).

  - **`name`** (`string`) - Optional.
    Certificate name.


- **`certificatePassword`** (`securestring`) - Optional.
  Password of the certificate used by the custom domain.

- **`certificateValue`** (`securestring`) - Optional.
  Certificate to use for the custom domain (PFX or PEM).

- **`daprAIConnectionString`** (`securestring`) - Optional.
  Application Insights connection string for Dapr telemetry.

- **`daprAIInstrumentationKey`** (`securestring`) - Optional.
  Azure Monitor instrumentation key for Dapr telemetry.

- **`dnsSuffix`** (`string`) - Optional.
  DNS suffix for the environment domain.

- **`dockerBridgeCidr`** (`string`) - Conditional.
  Docker bridge CIDR range for the environment. Must not overlap with other IP ranges. Required if zoneRedundant is set to true to be WAF compliant.

- **`enableTelemetry`** (`bool`) - Optional.
  Enable or disable telemetry for the module. Default is true.

- **`infrastructureResourceGroupName`** (`string`) - Conditional.
  Infrastructure resource group name. Required if zoneRedundant is set to true to be WAF compliant.

- **`infrastructureSubnetResourceId`** (`string`) - Conditional.
  Resource ID of the subnet for infrastructure components. Required if "internal" is true. Required if zoneRedundant is set to true to be WAF compliant.

- **`internal`** (`bool`) - Conditional.
  Boolean indicating if only internal load balancer is used. Required if zoneRedundant is set to true to be WAF compliant.

- **`location`** (`string`) - Optional.
  Location for all resources. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional.
  Lock settings for the Managed Environment.
  - **`kind`** (`string`) - Optional.
    Lock type. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`managedIdentities`** (`object`) - Optional.
  Managed identity configuration for the Managed Environment.
  - **`systemAssigned`** (`bool`) - Optional.
    Enable system-assigned managed identity.

  - **`userAssignedResourceIds`** (`array`) - Optional.
    User-assigned identity resource IDs. Required if user-assigned identity is used for encryption.


- **`name`** (`string`) - Required.
  Name of the Container Apps Managed Environment.

- **`openTelemetryConfiguration`** (`object`) - Optional.
  Open Telemetry configuration.

- **`peerTrafficEncryption`** (`bool`) - Optional.
  Whether peer traffic encryption is enabled. Default is true.

- **`platformReservedCidr`** (`string`) - Conditional.
  Reserved IP range in CIDR notation for infrastructure. Required if zoneRedundant is set to true to be WAF compliant.

- **`platformReservedDnsIP`** (`string`) - Conditional.
  Reserved DNS IP within platformReservedCidr for internal DNS. Required if zoneRedundant is set to true to be WAF compliant.

- **`publicNetworkAccess`** (`string`) - Optional.
  Whether to allow or block public network traffic. Allowed values: Disabled, Enabled.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments to create for the Managed Environment.

- **`storages`** (`array`) - Optional.
  List of storages to mount on the environment.
  - **`accessMode`** (`string`) - Required.
    Access mode for storage. Allowed values: ReadOnly, ReadWrite.

  - **`kind`** (`string`) - Required.
    Type of storage. Allowed values: NFS, SMB.

  - **`shareName`** (`string`) - Required.
    File share name.

  - **`storageAccountName`** (`string`) - Required.
    Storage account name.


- **`tags`** (`object`) - Optional.
  Tags to apply to the Managed Environment.

- **`workloadProfiles`** (`array`) - Conditional.
  Workload profiles for the Managed Environment. Required if zoneRedundant is set to true to be WAF compliant.

- **`zoneRedundant`** (`bool`) - Optional.
  Whether the Managed Environment is zone redundant. Default is true.

### `containerRegistryDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `containerRegistryDefinition` | `object` | Conditional | Container Registry configuration. Required if deploy.containerRegistry is true and resourceIds.containerRegistryResourceId is empty. |

**Properties:**

- **`acrAdminUserEnabled`** (`bool`) - Optional.
  Enable admin user that has push/pull permission to the registry. Default is false.

- **`acrSku`** (`string`) - Optional.
  Tier of your Azure Container Registry. Default is Premium.

- **`anonymousPullEnabled`** (`bool`) - Optional.
  Enables registry-wide pull from unauthenticated clients (preview, Standard/Premium only). Default is false.

- **`azureADAuthenticationAsArmPolicyStatus`** (`string`) - Optional.
  Indicates whether the policy for using ARM audience token is enabled. Default is enabled.

- **`cacheRules`** (`array`) - Optional.
  Array of Cache Rules.
  - **`credentialSetResourceId`** (`string`) - Optional.
    Resource ID of the credential store associated with the cache rule.

  - **`name`** (`string`) - Optional.
    Name of the cache rule. Defaults to the source repository name if not set.

  - **`sourceRepository`** (`string`) - Required.
    Source repository pulled from upstream.

  - **`targetRepository`** (`string`) - Optional.
    Target repository specified in docker pull command.

- **`credentialSets`** (`array`) - Optional.
  Array of Credential Sets.
  - **`authCredentials`** (`array`) - Required.
    List of authentication credentials (primary and optional secondary).
    - **`name`** (`string`) - Required.
      Name of the credential.

    - **`passwordSecretIdentifier`** (`string`) - Required.
      KeyVault Secret URI for the password.

    - **`usernameSecretIdentifier`** (`string`) - Required.
      KeyVault Secret URI for the username.

  - **`loginServer`** (`string`) - Required.
    Login server for which the credentials are stored.

  - **`managedIdentities`** (`object`) - Optional.
    Managed identity definition for this credential set.
    - **`systemAssigned`** (`bool`) - Optional.
      Enables system-assigned managed identity.


  - **`name`** (`string`) - Required.
    Name of the credential set.
- **`customerManagedKey`** (`object`) - Optional.
  Customer managed key definition.
  - **`autoRotationEnabled`** (`bool`) - Optional.
    Enable or disable auto-rotation to the latest version. Default is true.

  - **`keyName`** (`string`) - Required.
    Name of the key.

  - **`keyVaultResourceId`** (`string`) - Required.
    Resource ID of the Key Vault.

  - **`keyVersion`** (`string`) - Optional.
    Key version. Used if autoRotationEnabled=false.

  - **`userAssignedIdentityResourceId`** (`string`) - Optional.
    User-assigned identity for fetching the key. Required if no system-assigned identity.


- **`dataEndpointEnabled`** (`bool`) - Conditional.
  Enable a single data endpoint per region (Premium only). Default is false. Required if acrSku is Premium.

- **`diagnosticSettings`** (`array`) - Optional.
  Diagnostic settings for the service.
  - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional.
    Event Hub authorization rule resource ID.

  - **`eventHubName`** (`string`) - Optional.
    Event Hub name for logs.

  - **`logAnalyticsDestinationType`** (`string`) - Optional.
    Destination type for Log Analytics (AzureDiagnostics or Dedicated).

  - **`logCategoriesAndGroups`** (`array`) - Optional.
    Log categories and groups.
    - **`category`** (`string`) - Optional.
      Diagnostic log category.

    - **`categoryGroup`** (`string`) - Optional.
      Diagnostic log category group.

    - **`enabled`** (`bool`) - Optional.
      Enable or disable this category. Default is true.

  - **`marketplacePartnerResourceId`** (`string`) - Optional.
    Marketplace partner resource ID.

  - **`metricCategories`** (`array`) - Optional.
    Metric categories.
    - **`category`** (`string`) - Required.
      Diagnostic metric category.

    - **`enabled`** (`bool`) - Optional.
      Enable or disable this metric. Default is true.

  - **`name`** (`string`) - Optional.
    Name of the diagnostic setting.

  - **`storageAccountResourceId`** (`string`) - Optional.
    Storage account resource ID.

  - **`workspaceResourceId`** (`string`) - Optional.
    Log Analytics workspace resource ID.
- **`enableTelemetry`** (`bool`) - Optional.
  Enable or disable telemetry for the module. Default is true.

- **`exportPolicyStatus`** (`string`) - Optional.
  Export policy status. Default is disabled.

- **`location`** (`string`) - Optional.
  Location for all resources. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional.
  Lock settings.
  - **`kind`** (`string`) - Optional.
    Type of lock (CanNotDelete, None, ReadOnly).

  - **`name`** (`string`) - Optional.
    Name of the lock.

  - **`notes`** (`string`) - Optional.
    Notes for the lock.


- **`managedIdentities`** (`object`) - Optional.
  Managed identity definition for the registry.
  - **`systemAssigned`** (`bool`) - Optional.
    Enable system-assigned managed identity.

  - **`userAssignedResourceIds`** (`array`) - Optional.
    User-assigned identity resource IDs. Required if user-assigned identity is used for encryption.


- **`name`** (`string`) - Required.
  Name of your Azure Container Registry.

- **`networkRuleBypassOptions`** (`string`) - Optional.
  Network rule bypass options. Default is AzureServices.

- **`networkRuleSetDefaultAction`** (`string`) - Optional.
  Default action when no network rule matches. Default is Deny.

- **`networkRuleSetIpRules`** (`array`) - Conditional.
  IP ACL rules (Premium only). Required if acrSku is Premium.

- **`privateEndpoints`** (`array`) - Conditional.
  Private endpoint configuration (Premium only). Required if acrSku is Premium.

- **`publicNetworkAccess`** (`string`) - Conditional.
  Public network access (Premium only). Disabled by default if private endpoints are set and no IP rules). Required if acrSku is Premium.

- **`quarantinePolicyStatus`** (`string`) - Conditional.
  Quarantine policy status (Premium only). Default is disabled. Required if acrSku is Premium.

- **`replications`** (`array`) - Optional.
  Replications to create.

- **`retentionPolicyDays`** (`int`) - Optional.
  Number of days to retain untagged manifests. Default is 15.

- **`retentionPolicyStatus`** (`string`) - Optional.
  Retention policy status. Default is enabled.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for this registry.

- **`scopeMaps`** (`array`) - Optional.
  Scope maps configuration.

- **`softDeletePolicyDays`** (`int`) - Optional.
  Number of days after which soft-deleted items are permanently deleted. Default is 7.

- **`softDeletePolicyStatus`** (`string`) - Optional.
  Soft delete policy status. Default is disabled.

- **`tags`** (`object`) - Optional.
  Resource tags.

- **`trustPolicyStatus`** (`string`) - Conditional.
  Trust policy status (Premium only). Default is disabled. Required if acrSku is Premium.

- **`webhooks`** (`array`) - Optional.
  Webhooks to create.

- **`zoneRedundancy`** (`string`) - Optional.
  Zone redundancy setting. Default is Enabled. Conditional: requires acrSku=Premium.

### `firewallDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `firewallDefinition` | `object` | Conditional | Azure Firewall configuration. Required if deploy.firewall is true and resourceIds.firewallResourceId is empty. |

**Properties:**

- **`additionalPublicIpConfigurations`** (`array`) - Optional.
  Additional Public IP configurations.

- **`applicationRuleCollections`** (`array`) - Optional.
  Application rule collections used by Azure Firewall.
  - **`name`** (`string`) - Required.
    Name of the application rule collection.

  - **`properties`** (`object`) - Required.
    Properties of the application rule collection.
    - **`action`** (`object`) - Required.
      Action of the rule collection.
      - **`type`** (`string`) - Required.
        Action type. Allowed values: Allow, Deny.


    - **`priority`** (`int`) - Required.
      Priority of the application rule collection (100-65000).

    - **`rules`** (`array`) - Required.
      Application rules in the collection.
      - **`description`** (`string`) - Optional.
        Description of the rule.

      - **`fqdnTags`** (`array`) - Optional.
        List of FQDN tags for this rule.

      - **`name`** (`string`) - Required.
        Name of the application rule.

      - **`protocols`** (`array`) - Required.
        Protocols for the application rule.
        - **`port`** (`int`) - Optional.
          Port number for the protocol (≤64000).

        - **`protocolType`** (`string`) - Required.
          Protocol type. Allowed values: Http, Https, Mssql.


      - **`sourceAddresses`** (`array`) - Optional.
        List of source IP addresses for this rule.

      - **`sourceIpGroups`** (`array`) - Optional.
        List of source IP groups for this rule.

      - **`targetFqdns`** (`array`) - Optional.
        List of target FQDNs for this rule.


- **`autoscaleMaxCapacity`** (`int`) - Optional.
  Maximum number of capacity units for the firewall.

- **`autoscaleMinCapacity`** (`int`) - Optional.
  Minimum number of capacity units for the firewall.

- **`availabilityZones`** (`array`) - Optional.
  Availability Zones for zone-redundant deployment.

- **`azureSkuTier`** (`string`) - Optional.
  Tier of Azure Firewall. Allowed values: Basic, Premium, Standard.

- **`diagnosticSettings`** (`array`) - Optional.
  Diagnostic settings for the firewall.
  - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional.
    Event Hub authorization rule resource ID.

  - **`eventHubName`** (`string`) - Optional.
    Event Hub name for diagnostic logs.

  - **`logAnalyticsDestinationType`** (`string`) - Optional.
    Log Analytics destination type. Allowed values: AzureDiagnostics, Dedicated.

  - **`logCategoriesAndGroups`** (`array`) - Optional.
    Log categories and groups.
    - **`category`** (`string`) - Optional.
      Name of a diagnostic log category.

    - **`categoryGroup`** (`string`) - Optional.
      Name of a diagnostic log category group.

    - **`enabled`** (`bool`) - Optional.
      Enable/disable category. Default is true.

  - **`marketplacePartnerResourceId`** (`string`) - Optional.
    Marketplace partner resource ID for diagnostic logs.

  - **`metricCategories`** (`array`) - Optional.
    Metric categories for diagnostics.
    - **`category`** (`string`) - Required.
      Name of a diagnostic metric category.

    - **`enabled`** (`bool`) - Optional.
      Enable/disable metric category. Default is true.

  - **`name`** (`string`) - Optional.
    Diagnostic setting name.

  - **`storageAccountResourceId`** (`string`) - Optional.
    Diagnostic storage account resource ID.

  - **`workspaceResourceId`** (`string`) - Optional.
    Log Analytics workspace resource ID.
- **`enableForcedTunneling`** (`bool`) - Optional.
  Enable or disable forced tunneling.

- **`enableTelemetry`** (`bool`) - Optional.
  Enable or disable usage telemetry. Default is true.

- **`firewallPolicyId`** (`string`) - Optional.
  Resource ID of the Firewall Policy to attach.

- **`hubIPAddresses`** (`object`) - Conditional.
  IP addresses associated with Azure Firewall. Required if virtualHubId is supplied.
  - **`privateIPAddress`** (`string`) - Optional.
    Private IP Address associated with Azure Firewall.

  - **`publicIPs`** (`object`) - Optional.
    Public IPs associated with Azure Firewall.
    - **`addresses`** (`array`) - Optional.
      List of public IP addresses or IPs to retain.

    - **`count`** (`int`) - Optional.
      Public IP address count.



- **`location`** (`string`) - Optional.
  Location for all resources. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional.
  Lock settings for the firewall.
  - **`kind`** (`string`) - Optional.
    Lock type. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`managementIPAddressObject`** (`object`) - Optional.
  Properties of the Management Public IP to create and use.

- **`managementIPResourceID`** (`string`) - Optional.
  Management Public IP resource ID for AzureFirewallManagementSubnet.

- **`name`** (`string`) - Required.
  Name of the Azure Firewall.

- **`natRuleCollections`** (`array`) - Optional.
  NAT rule collections used by Azure Firewall.
  - **`name`** (`string`) - Required.
    Name of the NAT rule collection.

  - **`properties`** (`object`) - Required.
    Properties of the NAT rule collection.
    - **`action`** (`object`) - Required.
      Action of the NAT rule collection.
      - **`type`** (`string`) - Required.
        Action type. Allowed values: Dnat, Snat.


    - **`priority`** (`int`) - Required.
      Priority of the NAT rule collection (100–65000).

    - **`rules`** (`array`) - Required.
      NAT rules in the collection.
      - **`description`** (`string`) - Optional.
        Description of the NAT rule.

      - **`destinationAddresses`** (`array`) - Optional.
        Destination addresses (IP ranges, prefixes, service tags).

      - **`destinationPorts`** (`array`) - Optional.
        Destination ports.

      - **`name`** (`string`) - Required.
        Name of the NAT rule.

      - **`protocols`** (`array`) - Required.
        Protocols for the NAT rule. Allowed values: Any, ICMP, TCP, UDP.

      - **`sourceAddresses`** (`array`) - Optional.
        Source addresses.

      - **`sourceIpGroups`** (`array`) - Optional.
        Source IP groups.

      - **`translatedAddress`** (`string`) - Optional.
        Translated address for the NAT rule.

      - **`translatedFqdn`** (`string`) - Optional.
        Translated FQDN for the NAT rule.

      - **`translatedPort`** (`string`) - Optional.
        Translated port for the NAT rule.


- **`networkRuleCollections`** (`array`) - Optional.
  Network rule collections used by Azure Firewall.
  - **`name`** (`string`) - Required.
    Name of the network rule collection.

  - **`properties`** (`object`) - Required.
    Properties of the network rule collection.
    - **`action`** (`object`) - Required.
      Action of the network rule collection.
      - **`type`** (`string`) - Required.
        Action type. Allowed values: Allow, Deny.


    - **`priority`** (`int`) - Required.
      Priority of the network rule collection (100–65000).

    - **`rules`** (`array`) - Required.
      Network rules in the collection.
      - **`description`** (`string`) - Optional.
        Description of the network rule.

      - **`destinationAddresses`** (`array`) - Optional.
        Destination addresses.

      - **`destinationFqdns`** (`array`) - Optional.
        Destination FQDNs.

      - **`destinationIpGroups`** (`array`) - Optional.
        Destination IP groups.

      - **`destinationPorts`** (`array`) - Optional.
        Destination ports.

      - **`name`** (`string`) - Required.
        Name of the network rule.

      - **`protocols`** (`array`) - Required.
        Protocols for the network rule. Allowed values: Any, ICMP, TCP, UDP.

      - **`sourceAddresses`** (`array`) - Optional.
        Source addresses.

      - **`sourceIpGroups`** (`array`) - Optional.
        Source IP groups.


- **`publicIPAddressObject`** (`object`) - Optional.
  Properties of the Public IP to create and use if no existing Public IP is provided.

- **`publicIPResourceID`** (`string`) - Optional.
  Public IP resource ID for the AzureFirewallSubnet.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the firewall.

- **`tags`** (`object`) - Optional.
  Tags to apply to the Azure Firewall resource.

- **`threatIntelMode`** (`string`) - Optional.
  Operation mode for Threat Intel. Allowed values: Alert, Deny, Off.

- **`virtualHubResourceId`** (`string`) - Conditional.
  The virtualHub resource ID to which the firewall belongs. Required if virtualNetworkId is empty.

- **`virtualNetworkResourceId`** (`string`) - Conditional.
  Shared services Virtual Network resource ID containing AzureFirewallSubnet. Required if virtualHubId is empty.

### `firewallPolicyDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `firewallPolicyDefinition` | `object` | Conditional | Azure Firewall Policy configuration. Required if deploy.firewall is true and resourceIds.firewallPolicyResourceId is empty. |

**Properties:**

- **`allowSqlRedirect`** (`bool`) - Optional.
  A flag to indicate if SQL Redirect traffic filtering is enabled. Requires no rule using ports 11000–11999.

- **`basePolicyResourceId`** (`string`) - Optional.
  Resource ID of the base policy.

- **`certificateName`** (`string`) - Optional.
  Name of the CA certificate.

- **`defaultWorkspaceResourceId`** (`string`) - Optional.
  Default Log Analytics Resource ID for Firewall Policy Insights.

- **`enableProxy`** (`bool`) - Optional.
  Enable DNS Proxy on Firewalls attached to the Firewall Policy.

- **`enableTelemetry`** (`bool`) - Optional.
  Enable or disable usage telemetry for the module. Default is true.

- **`fqdns`** (`array`) - Optional.
  List of FQDNs for the ThreatIntel Allowlist.

- **`insightsIsEnabled`** (`bool`) - Optional.
  Flag to indicate if insights are enabled on the policy.

- **`intrusionDetection`** (`object`) - Optional.
  Intrusion detection configuration.
  - **`configuration`** (`object`) - Optional.
    Intrusion detection configuration properties.
    - **`bypassTrafficSettings`** (`array`) - Optional.
      List of bypass traffic rules.

      - **`description`** (`string`) - Optional.
        Description of the bypass traffic rule.
      - **`destinationAddresses`** (`array`) - Optional.
        Destination IP addresses or ranges.
      - **`destinationIpGroups`** (`array`) - Optional.
        Destination IP groups.
      - **`destinationPorts`** (`array`) - Optional.
        Destination ports or ranges.
      - **`name`** (`string`) - Required.
        Name of the bypass traffic rule.
      - **`protocol`** (`string`) - Optional.
        Protocol for the rule. Allowed values: ANY, ICMP, TCP, UDP.
      - **`sourceAddresses`** (`array`) - Optional.
        Source IP addresses or ranges.
      - **`sourceIpGroups`** (`array`) - Optional.
        Source IP groups.
    - **`privateRanges`** (`array`) - Optional.
      List of private IP ranges to consider as internal.

    - **`signatureOverrides`** (`array`) - Optional.
      Signature override states.

      - **`id`** (`string`) - Required.
        Signature ID.
      - **`mode`** (`string`) - Required.
        Signature state. Allowed values: Alert, Deny, Off.
  - **`mode`** (`string`) - Optional.
    Intrusion detection mode. Allowed values: Alert, Deny, Off.
  - **`profile`** (`string`) - Optional.
    IDPS profile name. Allowed values: Advanced, Basic, Extended, Standard.
- **`ipAddresses`** (`array`) - Optional.
  List of IP addresses for the ThreatIntel Allowlist.

- **`keyVaultSecretId`** (`string`) - Optional.
  Key Vault secret ID (base-64 encoded unencrypted PFX or Certificate object).

- **`location`** (`string`) - Optional.
  Location for all resources. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional.
  Lock settings for the Firewall Policy.
  - **`kind`** (`string`) - Optional.
    Lock type. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`managedIdentities`** (`object`) - Optional.
  Managed identity definition for this resource.
  - **`userAssignedResourceIds`** (`array`) - Optional.
    User-assigned identity resource IDs. Required if using a user-assigned identity for encryption.


- **`name`** (`string`) - Required.
  Name of the Firewall Policy.

- **`retentionDays`** (`int`) - Optional.
  Number of days to retain Firewall Policy insights. Default is 365.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments to create for the Firewall Policy.

- **`ruleCollectionGroups`** (`array`) - Optional.
  Rule collection groups.

- **`servers`** (`array`) - Optional.
  List of custom DNS servers.

- **`snat`** (`object`) - Optional.
  SNAT private IP ranges configuration.
  - **`autoLearnPrivateRanges`** (`string`) - Required.
    Mode for automatically learning private ranges. Allowed values: Disabled, Enabled.

  - **`privateRanges`** (`array`) - Optional.
    List of private IP ranges not to be SNATed.


- **`tags`** (`object`) - Optional.
  Tags to apply to the Firewall Policy.

- **`threatIntelMode`** (`string`) - Optional.
  Threat Intelligence mode. Allowed values: Alert, Deny, Off.

- **`tier`** (`string`) - Optional.
  Tier of the Firewall Policy. Allowed values: Basic, Premium, Standard.

- **`workspaces`** (`array`) - Optional.
  List of workspaces for Firewall Policy Insights.

### `firewallPublicIp`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `firewallPublicIp` | `object` | Conditional | Conditional Public IP for Azure Firewall. Required when deploy firewall is true and no existing ID is provided. |

**Properties:**

- **`ddosSettings`** (`object`) - Optional.
  DDoS protection settings for the Public IP Address.
  - **`ddosProtectionPlan`** (`object`) - Optional.
    Associated DDoS protection plan.
    - **`id`** (`string`) - Required.
      Resource ID of the DDoS protection plan.


  - **`protectionMode`** (`string`) - Required.
    DDoS protection mode. Allowed value: Enabled.


- **`diagnosticSettings`** (`array`) - Optional.
  Diagnostic settings for the Public IP Address.
  - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional.
    Resource ID of the diagnostic Event Hub authorization rule.

  - **`eventHubName`** (`string`) - Optional.
    Name of the diagnostic Event Hub.

  - **`logAnalyticsDestinationType`** (`string`) - Optional.
    Log Analytics destination type. Allowed values: AzureDiagnostics, Dedicated.

  - **`logCategoriesAndGroups`** (`array`) - Optional.
    Log categories and groups to collect. Set to [] to disable log collection.
    - **`category`** (`string`) - Optional.
      Name of a diagnostic log category.

    - **`categoryGroup`** (`string`) - Optional.
      Name of a diagnostic log category group. Use allLogs to collect all logs.

    - **`enabled`** (`bool`) - Optional.
      Enable or disable the log category. Default is true.

  - **`marketplacePartnerResourceId`** (`string`) - Optional.
    Marketplace partner resource ID.

  - **`metricCategories`** (`array`) - Optional.
    Metric categories to collect. Set to [] to disable metric collection.
    - **`category`** (`string`) - Required.
      Name of a diagnostic metric category. Use AllMetrics to collect all metrics.

    - **`enabled`** (`bool`) - Optional.
      Enable or disable the metric category. Default is true.

  - **`name`** (`string`) - Optional.
    Name of the diagnostic setting.

  - **`storageAccountResourceId`** (`string`) - Optional.
    Resource ID of the diagnostic storage account.

  - **`workspaceResourceId`** (`string`) - Optional.
    Resource ID of the diagnostic Log Analytics workspace.
- **`dnsSettings`** (`object`) - Optional.
  DNS settings for the Public IP Address.
  - **`domainNameLabel`** (`string`) - Required.
    Domain name label used to create an A DNS record in Azure DNS.

  - **`domainNameLabelScope`** (`string`) - Optional.
    Domain name label scope. Allowed values: NoReuse, ResourceGroupReuse, SubscriptionReuse, TenantReuse.

  - **`fqdn`** (`string`) - Optional.
    Fully qualified domain name (FQDN) associated with the Public IP.

  - **`reverseFqdn`** (`string`) - Optional.
    Reverse FQDN used for PTR records.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable or disable usage telemetry for the module. Default is true.

- **`idleTimeoutInMinutes`** (`int`) - Optional.
  Idle timeout in minutes for the Public IP Address. Default is 4.

- **`ipTags`** (`array`) - Optional.
  IP tags associated with the Public IP Address.
  - **`ipTagType`** (`string`) - Required.
    IP tag type.

  - **`tag`** (`string`) - Required.
    IP tag value.


- **`location`** (`string`) - Optional.
  Location for the resource. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional.
  Lock configuration for the Public IP Address.
  - **`kind`** (`string`) - Optional.
    Lock type. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  Name of the Public IP Address.

- **`publicIPAddressVersion`** (`string`) - Optional.
  IP address version. Default is IPv4. Allowed values: IPv4, IPv6.

- **`publicIPAllocationMethod`** (`string`) - Optional.
  Public IP allocation method. Default is Static. Allowed values: Dynamic, Static.

- **`publicIpPrefixResourceId`** (`string`) - Optional.
  Resource ID of the Public IP Prefix to allocate from.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments to apply to the Public IP Address.
  - **`condition`** (`string`) - Optional.
    Condition for the role assignment.

  - **`conditionVersion`** (`string`) - Optional.
    Condition version. Allowed value: 2.0.

  - **`delegatedManagedIdentityResourceId`** (`string`) - Optional.
    Delegated managed identity resource ID.

  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Role assignment name (GUID). If omitted, a GUID is generated.

  - **`principalId`** (`string`) - Required.
    Principal ID of the identity being assigned.

  - **`principalType`** (`string`) - Optional.
    Principal type of the assigned identity. Allowed values: Device, ForeignGroup, Group, ServicePrincipal, User.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role to assign (display name, GUID, or full resource ID).


- **`skuName`** (`string`) - Optional.
  SKU name for the Public IP Address. Default is Standard. Allowed values: Basic, Standard.

- **`skuTier`** (`string`) - Optional.
  SKU tier for the Public IP Address. Default is Regional. Allowed values: Global, Regional.

- **`tags`** (`object`) - Optional.
  Tags to apply to the Public IP Address resource.

- **`zones`** (`array`) - Optional.
  Availability zones for the Public IP Address allocation. Allowed values: 1, 2, 3.

### `groundingWithBingDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `groundingWithBingDefinition` | `object` | Conditional | Grounding with Bing configuration. Required if deploy.groundingWithBingSearch is true and resourceIds.groundingServiceResourceId is empty. |

**Properties:**

- **`name`** (`string`) - Optional.
  Bing Grounding resource name.

- **`sku`** (`string`) - Required.
  Bing Grounding resource SKU.

- **`tags`** (`object`) - Required.
  Tags to apply to the Bing Grounding resource.

### `jumpVmDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `jumpVmDefinition` | `object` | Conditional | Jump (bastion) VM configuration (Windows). Required if deploy.jumpVm is true. |

**Properties:**

- **`adminPassword`** (`securestring`) - Optional.
  Admin password for the VM.

- **`adminUsername`** (`string`) - Optional.
  Admin username to create (e.g., azureuser).

- **`availabilityZone`** (`int`) - Optional.
  Availability zone.

- **`azdo`** (`object`) - Optional.
  Azure DevOps settings (required when runner = azdo, Build VM only).
  - **`agentName`** (`string`) - Optional.
    Agent name.

  - **`orgUrl`** (`string`) - Required.
    Azure DevOps organization URL (e.g., https://dev.azure.com/contoso).

  - **`pool`** (`string`) - Required.
    Agent pool name.

  - **`workFolder`** (`string`) - Optional.
    Working folder.


- **`disablePasswordAuthentication`** (`bool`) - Optional.
  Disable password authentication (Build VM only).

- **`enableAutomaticUpdates`** (`bool`) - Optional.
  Enable automatic updates (Jump VM only).

- **`enableTelemetry`** (`bool`) - Optional.
  Enable telemetry via a Globally Unique Identifier (GUID).

- **`github`** (`object`) - Optional.
  GitHub settings (required when runner = github, Build VM only).
  - **`agentName`** (`string`) - Optional.
    Runner name.

  - **`labels`** (`string`) - Optional.
    Runner labels (comma-separated).

  - **`owner`** (`string`) - Required.
    GitHub owner (org or user).

  - **`repo`** (`string`) - Required.
    Repository name.

  - **`workFolder`** (`string`) - Optional.
    Working folder.


- **`imageReference`** (`object`) - Optional.
  Marketplace image reference for the VM.
  - **`communityGalleryImageId`** (`string`) - Optional.
    Community gallery image ID.

  - **`id`** (`string`) - Optional.
    Resource ID.

  - **`offer`** (`string`) - Optional.
    Offer name.

  - **`publisher`** (`string`) - Optional.
    Publisher name.

  - **`sharedGalleryImageId`** (`string`) - Optional.
    Shared gallery image ID.

  - **`sku`** (`string`) - Optional.
    SKU name.

  - **`version`** (`string`) - Optional.
    Image version (e.g., latest).


- **`location`** (`string`) - Optional.
  Location for all resources.

- **`lock`** (`object`) - Optional.
  Lock configuration.

- **`maintenanceConfigurationResourceId`** (`string`) - Optional.
  Resource ID of the maintenance configuration (Jump VM only).

- **`managedIdentities`** (`object`) - Optional.
  Managed identities.

- **`name`** (`string`) - Optional.
  VM name.

- **`nicConfigurations`** (`array`) - Optional.
  Network interface configurations.

- **`osDisk`** (`object`) - Optional.
  OS disk configuration.

- **`osType`** (`string`) - Optional.
  OS type for the VM.

- **`patchMode`** (`string`) - Optional.
  Patch mode for the VM (Jump VM only).

- **`publicKeys`** (`array`) - Optional.
  SSH public keys (Build VM only).

- **`requireGuestProvisionSignal`** (`bool`) - Optional.
  Force password reset on first login.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments.

- **`runner`** (`string`) - Optional.
  Which agent to install (Build VM only).

- **`sku`** (`string`) - Optional.
  VM size SKU (e.g., Standard_B2s, Standard_D2s_v5).

- **`tags`** (`object`) - Optional.
  Tags to apply to the VM resource.

### `logAnalyticsDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `logAnalyticsDefinition` | `object` | Conditional | Log Analytics Workspace configuration. Required if deploy.logAnalytics is true and resourceIds.logAnalyticsWorkspaceResourceId is empty. |

**Properties:**

- **`dailyQuotaGb`** (`int`) - Optional.
  Daily ingestion quota in GB. Default is -1.

- **`dataExports`** (`array`) - Optional.
  Data export instances for the workspace.
  - **`destination`** (`object`) - Optional.
    Destination configuration for the export.
    - **`metaData`** (`object`) - Optional.
      Destination metadata.
      - **`eventHubName`** (`string`) - Optional.
        Event Hub name (not applicable when destination is Storage Account).


    - **`resourceId`** (`string`) - Required.
      Destination resource ID.


  - **`enable`** (`bool`) - Optional.
    Enable or disable the data export.

  - **`name`** (`string`) - Required.
    Name of the data export.

  - **`tableNames`** (`array`) - Required.
    Table names to export.


- **`dataRetention`** (`int`) - Optional.
  Number of days data will be retained. Default 365 (0–730).

- **`dataSources`** (`array`) - Optional.
  Data sources for the workspace.
  - **`counterName`** (`string`) - Optional.
    Counter name for WindowsPerformanceCounter.

  - **`eventLogName`** (`string`) - Optional.
    Event log name for WindowsEvent.

  - **`eventTypes`** (`array`) - Optional.
    Event types for WindowsEvent.

  - **`instanceName`** (`string`) - Optional.
    Instance name for WindowsPerformanceCounter or LinuxPerformanceObject.

  - **`intervalSeconds`** (`int`) - Optional.
    Interval in seconds for collection.

  - **`kind`** (`string`) - Required.
    Kind of data source.

  - **`linkedResourceId`** (`string`) - Optional.
    Resource ID linked to the workspace.

  - **`name`** (`string`) - Required.
    Name of the data source.

  - **`objectName`** (`string`) - Optional.
    Object name for WindowsPerformanceCounter or LinuxPerformanceObject.

  - **`performanceCounters`** (`array`) - Optional.
    Performance counters for LinuxPerformanceObject.

  - **`state`** (`string`) - Optional.
    State (for IISLogs, LinuxSyslogCollection, or LinuxPerformanceCollection).

  - **`syslogName`** (`string`) - Optional.
    System log name for LinuxSyslog.

  - **`syslogSeverities`** (`array`) - Optional.
    Severities for LinuxSyslog.

  - **`tags`** (`object`) - Optional.
    Tags for the data source.
- **`diagnosticSettings`** (`array`) - Optional.
  Diagnostic settings for the workspace.
  - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional.
    Event Hub authorization rule resource ID.

  - **`eventHubName`** (`string`) - Optional.
    Diagnostic Event Hub name.

  - **`logAnalyticsDestinationType`** (`string`) - Optional.
    Destination type for Log Analytics. Allowed: AzureDiagnostics, Dedicated.

  - **`logCategoriesAndGroups`** (`array`) - Optional.
    Log categories and groups to stream.
    - **`category`** (`string`) - Optional.
      Log category name.

    - **`categoryGroup`** (`string`) - Optional.
      Log category group name.

    - **`enabled`** (`bool`) - Optional.
      Enable or disable the category. Default true.

  - **`marketplacePartnerResourceId`** (`string`) - Optional.
    Marketplace partner resource ID.

  - **`metricCategories`** (`array`) - Optional.
    Metric categories to stream.
    - **`category`** (`string`) - Required.
      Diagnostic metric category name.

    - **`enabled`** (`bool`) - Optional.
      Enable or disable the metric category. Default true.

  - **`name`** (`string`) - Optional.
    Diagnostic setting name.

  - **`storageAccountResourceId`** (`string`) - Optional.
    Storage account resource ID for diagnostic logs.

  - **`useThisWorkspace`** (`bool`) - Optional.
    Use this workspace as diagnostic target (ignores workspaceResourceId).

  - **`workspaceResourceId`** (`string`) - Optional.
    Log Analytics workspace resource ID for diagnostics.
- **`enableTelemetry`** (`bool`) - Optional.
  Enable or disable telemetry. Default true.

- **`features`** (`object`) - Optional.
  Features for the workspace.
  - **`disableLocalAuth`** (`bool`) - Optional.
    Disable non-EntraID auth. Default true.

  - **`enableDataExport`** (`bool`) - Optional.
    Enable data export.

  - **`enableLogAccessUsingOnlyResourcePermissions`** (`bool`) - Optional.
    Enable log access using only resource permissions. Default false.

  - **`immediatePurgeDataOn30Days`** (`bool`) - Optional.
    Remove data after 30 days.


- **`forceCmkForQuery`** (`bool`) - Optional.
  Enforce customer-managed storage for queries.

- **`gallerySolutions`** (`array`) - Optional.
  Gallery solutions for the workspace.
  - **`name`** (`string`) - Required.
    Solution name. Must follow Microsoft or 3rd party naming convention.

  - **`plan`** (`object`) - Required.
    Plan for the gallery solution.
    - **`name`** (`string`) - Optional.
      Solution name (defaults to gallerySolutions.name).

    - **`product`** (`string`) - Required.
      Product name (e.g., OMSGallery/AntiMalware).

    - **`publisher`** (`string`) - Optional.
      Publisher name (default: Microsoft for Microsoft solutions).
- **`linkedServices`** (`array`) - Optional.
  Linked services for the workspace.
  - **`name`** (`string`) - Required.
    Name of the linked service.

  - **`resourceId`** (`string`) - Optional.
    Resource ID of the linked service (read access).

  - **`writeAccessResourceId`** (`string`) - Optional.
    Resource ID for write access.

- **`linkedStorageAccounts`** (`array`) - Conditional.
  List of Storage Accounts to be linked. Required if forceCmkForQuery is true and savedSearches is not empty.
  - **`name`** (`string`) - Required.
    Name of the storage link.

  - **`storageAccountIds`** (`array`) - Required.
    Linked storage accounts resource IDs.

- **`location`** (`string`) - Optional.
  Location of the workspace. Default: resourceGroup().location.

- **`lock`** (`object`) - Optional.
  Lock settings.
  - **`kind`** (`string`) - Optional.
    Lock type. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`managedIdentities`** (`object`) - Optional.
  Managed identity definition (system-assigned or user-assigned).
  - **`systemAssigned`** (`bool`) - Optional.
    Enable system-assigned identity.

  - **`userAssignedResourceIds`** (`array`) - Optional.
    User-assigned identity resource IDs.


- **`name`** (`string`) - Required.
  Name of the Log Analytics workspace.

- **`onboardWorkspaceToSentinel`** (`bool`) - Optional.
  Onboard workspace to Sentinel. Requires SecurityInsights solution.

- **`publicNetworkAccessForIngestion`** (`string`) - Optional.
  Network access for ingestion. Allowed: Disabled, Enabled.

- **`publicNetworkAccessForQuery`** (`string`) - Optional.
  Network access for query. Allowed: Disabled, Enabled.

- **`replication`** (`object`) - Optional.
  Replication settings.
  - **`enabled`** (`bool`) - Optional.
    Enable replication.

  - **`location`** (`string`) - Conditional.
    Replication location. Required if replication is enabled.


- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the workspace.
  - **`condition`** (`string`) - Optional.
    Condition for the role assignment.

  - **`conditionVersion`** (`string`) - Optional.
    Condition version. Allowed: 2.0.

  - **`delegatedManagedIdentityResourceId`** (`string`) - Optional.
    Delegated managed identity resource ID.

  - **`description`** (`string`) - Optional.
    Role assignment description.

  - **`name`** (`string`) - Optional.
    Role assignment GUID name.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign.

  - **`principalType`** (`string`) - Optional.
    Principal type. Allowed: Device, ForeignGroup, Group, ServicePrincipal, User.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID, name, or GUID.


- **`savedSearches`** (`array`) - Optional.
  Saved KQL searches.
  - **`category`** (`string`) - Required.
    Saved search category.

  - **`displayName`** (`string`) - Required.
    Display name for the saved search.

  - **`etag`** (`string`) - Optional.
    ETag for concurrency control.

  - **`functionAlias`** (`string`) - Optional.
    Function alias if used as a function.

  - **`functionParameters`** (`string`) - Optional.
    Function parameters if query is used as a function.

  - **`name`** (`string`) - Required.
    Name of the saved search.

  - **`query`** (`string`) - Required.
    Query expression.

  - **`tags`** (`array`) - Optional.
    Tags for the saved search.

  - **`version`** (`int`) - Optional.
    Version of the query language. Default is 2.


- **`skuCapacityReservationLevel`** (`int`) - Optional.
  Capacity reservation level in GB (100–5000 in increments of 100).

- **`skuName`** (`string`) - Optional.
  SKU name. Allowed: CapacityReservation, Free, LACluster, PerGB2018, PerNode, Premium, Standalone, Standard.

- **`storageInsightsConfigs`** (`array`) - Optional.
  Storage insights configs for linked storage accounts.
  - **`containers`** (`array`) - Optional.
    Blob container names to read.

  - **`storageAccountResourceId`** (`string`) - Required.
    Storage account resource ID.

  - **`tables`** (`array`) - Optional.
    Tables to read.


- **`tables`** (`array`) - Optional.
  Custom LAW tables to be deployed.
  - **`name`** (`string`) - Required.
    Table name.

  - **`plan`** (`string`) - Optional.
    Table plan.

  - **`restoredLogs`** (`object`) - Optional.
    Restored logs configuration.
    - **`endRestoreTime`** (`string`) - Optional.
      End restore time (UTC).

    - **`sourceTable`** (`string`) - Optional.
      Source table for restored logs.

    - **`startRestoreTime`** (`string`) - Optional.
      Start restore time (UTC).


  - **`retentionInDays`** (`int`) - Optional.
    Table retention in days.

  - **`roleAssignments`** (`array`) - Optional.
    Role assignments for the table.

  - **`schema`** (`object`) - Optional.
    Table schema.
    - **`columns`** (`array`) - Required.
      List of table columns.
      - **`dataTypeHint`** (`string`) - Optional.
        Logical data type hint. Allowed: armPath, guid, ip, uri.

      - **`description`** (`string`) - Optional.
        Column description.

      - **`displayName`** (`string`) - Optional.
        Column display name.

      - **`name`** (`string`) - Required.
        Column name.

      - **`type`** (`string`) - Required.
        Column type. Allowed: boolean, dateTime, dynamic, guid, int, long, real, string.

    - **`description`** (`string`) - Optional.
      Table description.

    - **`displayName`** (`string`) - Optional.
      Table display name.

    - **`name`** (`string`) - Required.
      Table name.


  - **`searchResults`** (`object`) - Optional.
    Search results for the table.
    - **`description`** (`string`) - Optional.
      Description of the search job.

    - **`endSearchTime`** (`string`) - Optional.
      End time for the search (UTC).

    - **`limit`** (`int`) - Optional.
      Row limit for the search job.

    - **`query`** (`string`) - Required.
      Query for the search job.

    - **`startSearchTime`** (`string`) - Optional.
      Start time for the search (UTC).


  - **`totalRetentionInDays`** (`int`) - Optional.
    Total retention in days for the table.
- **`tags`** (`object`) - Optional.
  Tags for the workspace.

### `storageAccountDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `storageAccountDefinition` | `object` | Conditional | Storage Account configuration. Required if deploy.storageAccount is true and resourceIds.storageAccountResourceId is empty. |

**Properties:**

- **`accessTier`** (`string`) - Conditional.
  The access tier for billing. Required if kind is set to BlobStorage. Allowed values: Cold, Cool, Hot, Premium.

- **`allowBlobPublicAccess`** (`bool`) - Optional.
  Indicates whether public access is enabled for all blobs or containers. Recommended to be set to false.

- **`allowCrossTenantReplication`** (`bool`) - Optional.
  Allow or disallow cross AAD tenant object replication.

- **`allowedCopyScope`** (`string`) - Optional.
  Restrict copy scope. Allowed values: AAD, PrivateLink.

- **`allowSharedKeyAccess`** (`bool`) - Optional.
  Indicates whether Shared Key authorization is allowed. Default is true.

- **`azureFilesIdentityBasedAuthentication`** (`object`) - Optional.
  Provides the identity-based authentication settings for Azure Files.

- **`blobServices`** (`object`) - Optional.
  Blob service and containers configuration.

- **`customDomainName`** (`string`) - Optional.
  Sets the custom domain name (CNAME source) for the storage account.

- **`customDomainUseSubDomainName`** (`bool`) - Optional.
  Indicates whether indirect CName validation is enabled (updates only).

- **`customerManagedKey`** (`object`) - Optional.
  Customer managed key definition.
  - **`autoRotationEnabled`** (`bool`) - Optional.
    Enable or disable key auto-rotation. Default is true.

  - **`keyName`** (`string`) - Required.
    The name of the customer managed key.

  - **`keyVaultResourceId`** (`string`) - Required.
    The Key Vault resource ID where the key is stored.

  - **`keyVersion`** (`string`) - Optional.
    The version of the customer managed key to reference.

  - **`userAssignedIdentityResourceId`** (`string`) - Optional.
    User-assigned identity resource ID to fetch the key (if no system-assigned identity is available).


- **`defaultToOAuthAuthentication`** (`bool`) - Optional.
  When true, OAuth is the default authentication method.

- **`diagnosticSettings`** (`array`) - Optional.
  Diagnostic settings for the service.

- **`dnsEndpointType`** (`string`) - Optional.
  Endpoint type. Allowed values: AzureDnsZone, Standard.

- **`enableHierarchicalNamespace`** (`bool`) - Conditional.
  Enables Hierarchical Namespace for the storage account. Required if enableSftp or enableNfsV3 is true.

- **`enableNfsV3`** (`bool`) - Optional.
  Enables NFS 3.0 support. Requires hierarchical namespace enabled.

- **`enableSftp`** (`bool`) - Optional.
  Enables Secure File Transfer Protocol (SFTP). Requires hierarchical namespace enabled.

- **`enableTelemetry`** (`bool`) - Optional.
  Enable/disable telemetry for the module.

- **`fileServices`** (`object`) - Optional.
  File service and share configuration.

- **`isLocalUserEnabled`** (`bool`) - Optional.
  Enables local users feature for SFTP authentication.

- **`keyType`** (`string`) - Optional.
  Key type for Queue & Table services. Allowed values: Account, Service.

- **`kind`** (`string`) - Optional.
  Storage account type. Allowed values: BlobStorage, BlockBlobStorage, FileStorage, Storage, StorageV2.

- **`largeFileSharesState`** (`string`) - Optional.
  Large file shares state. Allowed values: Disabled, Enabled.

- **`localUsers`** (`array`) - Optional.
  Local users for SFTP authentication.

- **`location`** (`string`) - Optional.
  Resource location.

- **`lock`** (`object`) - Optional.
  Lock settings for the resource.
  - **`kind`** (`string`) - Optional.
    Lock type. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`managedIdentities`** (`object`) - Optional.
  Managed identity configuration.
  - **`systemAssigned`** (`bool`) - Optional.
    Enables system-assigned identity.

  - **`userAssignedResourceIds`** (`array`) - Optional.
    List of user-assigned identity resource IDs.


- **`managementPolicyRules`** (`array`) - Optional.
  Storage account management policy rules.

- **`minimumTlsVersion`** (`string`) - Optional.
  Minimum TLS version for requests. Allowed value: TLS1_2.

- **`name`** (`string`) - Required.
  Name of the Storage Account. Must be lower-case.

- **`networkAcls`** (`object`) - Optional.
  Network ACL rules and settings.

- **`privateEndpoints`** (`array`) - Optional.
  Private endpoint configurations.

- **`publicNetworkAccess`** (`string`) - Optional.
  Whether public network access is allowed. Allowed values: Disabled, Enabled.

- **`queueServices`** (`object`) - Optional.
  Queue service configuration.

- **`requireInfrastructureEncryption`** (`bool`) - Optional.
  Indicates whether infrastructure encryption with PMK is applied.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the storage account.

- **`sasExpirationAction`** (`string`) - Optional.
  SAS expiration action. Allowed values: Block, Log.

- **`sasExpirationPeriod`** (`string`) - Optional.
  SAS expiration period in DD.HH:MM:SS format.

- **`secretsExportConfiguration`** (`object`) - Optional.
  Configuration for exporting secrets to Key Vault.

- **`skuName`** (`string`) - Optional.
  SKU name for the storage account. Allowed values: Premium_LRS, Premium_ZRS, PremiumV2_LRS, PremiumV2_ZRS, Standard_GRS, Standard_GZRS, Standard_LRS, Standard_RAGRS, Standard_RAGZRS, Standard_ZRS, StandardV2_GRS, StandardV2_GZRS, StandardV2_LRS, StandardV2_ZRS.

- **`supportsHttpsTrafficOnly`** (`bool`) - Optional.
  When true, allows only HTTPS traffic to the storage service.

- **`tableServices`** (`object`) - Optional.
  Table service and tables configuration.

- **`tags`** (`object`) - Optional.
  Tags for the resource.

### `vNetDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `vNetDefinition` | `object` | Conditional | Virtual Network configuration. Required if deploy.virtualNetwork is true and resourceIds.virtualNetworkResourceId is empty. |

**Properties:**

- **`addressPrefixes`** (`array`) - Required.
  An array of one or more IP address prefixes OR the resource ID of the IPAM pool to be used for the Virtual Network. Required if using IPAM pool resource ID, you must also set ipamPoolNumberOfIpAddresses.

- **`ddosProtectionPlanResourceId`** (`string`) - Optional.
  Resource ID of the DDoS protection plan to assign the VNet to. If blank, DDoS protection is not configured.

- **`diagnosticSettings`** (`array`) - Optional.
  The diagnostic settings of the Virtual Network.
  - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional.
    Resource ID of the diagnostic event hub authorization rule for the Event Hubs namespace.

  - **`eventHubName`** (`string`) - Optional.
    Name of the diagnostic event hub within the namespace to which logs are streamed.

  - **`logAnalyticsDestinationType`** (`string`) - Optional.
    Destination type for export to Log Analytics. Allowed values: AzureDiagnostics, Dedicated.

  - **`logCategoriesAndGroups`** (`array`) - Optional.
    Logs to be streamed. Set to [] to disable log collection.
    - **`category`** (`string`) - Optional.
      Name of a diagnostic log category for the resource type.

    - **`categoryGroup`** (`string`) - Optional.
      Name of a diagnostic log category group for the resource type.

    - **`enabled`** (`bool`) - Optional.
      Enable or disable the category explicitly. Default is true.


  - **`marketplacePartnerResourceId`** (`string`) - Optional.
    Marketplace resource ID to which diagnostic logs should be sent.

  - **`metricCategories`** (`array`) - Optional.
    Metrics to be streamed. Set to [] to disable metric collection.
    - **`category`** (`string`) - Required.
      Name of a diagnostic metric category for the resource type.

    - **`enabled`** (`bool`) - Optional.
      Enable or disable the metric category explicitly. Default is true.

  - **`name`** (`string`) - Optional.
    Name of the diagnostic setting.

  - **`storageAccountResourceId`** (`string`) - Optional.
    Resource ID of the diagnostic storage account.

  - **`workspaceResourceId`** (`string`) - Optional.
    Resource ID of the diagnostic Log Analytics workspace.
- **`dnsServers`** (`array`) - Optional.
  DNS servers associated with the Virtual Network.

- **`enableTelemetry`** (`bool`) - Optional.
  Enable or disable usage telemetry for the module. Default is true.

- **`enableVmProtection`** (`bool`) - Optional.
  Indicates if VM protection is enabled for all subnets in the Virtual Network.

- **`flowTimeoutInMinutes`** (`int`) - Optional.
  Flow timeout in minutes for intra-VM flows (range 4–30). Default 0 sets the property to null.

- **`ipamPoolNumberOfIpAddresses`** (`string`) - Optional.
  Number of IP addresses allocated from the IPAM pool. Required if addressPrefixes is defined with a resource ID of an IPAM pool.

- **`location`** (`string`) - Optional.
  Location for all resources. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional.
  Lock settings for the Virtual Network.
  - **`kind`** (`string`) - Optional.
    Type of lock. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional.
    Name of the lock.

  - **`notes`** (`string`) - Optional.
    Notes for the lock.


- **`name`** (`string`) - Required.
  The name of the Virtual Network (vNet).

- **`peerings`** (`array`) - Optional.
  Virtual Network peering configurations.
  - **`allowForwardedTraffic`** (`bool`) - Optional.
    Allow forwarded traffic from VMs in local VNet. Default is true.

  - **`allowGatewayTransit`** (`bool`) - Optional.
    Allow gateway transit from remote VNet. Default is false.

  - **`allowVirtualNetworkAccess`** (`bool`) - Optional.
    Allow VMs in local VNet to access VMs in remote VNet. Default is true.

  - **`doNotVerifyRemoteGateways`** (`bool`) - Optional.
    Do not verify remote gateway provisioning state. Default is true.

  - **`name`** (`string`) - Optional.
    Name of the VNet peering resource. Default: peer-localVnetName-remoteVnetName.

  - **`remotePeeringAllowForwardedTraffic`** (`bool`) - Optional.
    Allow forwarded traffic from remote peering. Default is true.

  - **`remotePeeringAllowGatewayTransit`** (`bool`) - Optional.
    Allow gateway transit from remote peering. Default is false.

  - **`remotePeeringAllowVirtualNetworkAccess`** (`bool`) - Optional.
    Allow virtual network access from remote peering. Default is true.

  - **`remotePeeringDoNotVerifyRemoteGateways`** (`bool`) - Optional.
    Do not verify provisioning state of remote peering gateway. Default is true.

  - **`remotePeeringEnabled`** (`bool`) - Optional.
    Deploy outbound and inbound peering.

  - **`remotePeeringName`** (`string`) - Optional.
    Name of the remote peering resource. Default: peer-remoteVnetName-localVnetName.

  - **`remotePeeringUseRemoteGateways`** (`bool`) - Optional.
    Use remote gateways for transit if allowed. Default is false.

  - **`remoteVirtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the remote Virtual Network to peer with.

  - **`useRemoteGateways`** (`bool`) - Optional.
    Use remote gateways on this Virtual Network for transit. Default is false.


- **`roleAssignments`** (`array`) - Optional.
  Role assignments to create on the Virtual Network.
  - **`condition`** (`string`) - Optional.
    Condition applied to the role assignment.

  - **`conditionVersion`** (`string`) - Optional.
    Condition version. Allowed value: 2.0.

  - **`delegatedManagedIdentityResourceId`** (`string`) - Optional.
    Resource ID of delegated managed identity.

  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name of the role assignment. If not provided, a GUID will be generated.

  - **`principalId`** (`string`) - Required.
    Principal ID of the user/group/identity to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type. Allowed values: Device, ForeignGroup, Group, ServicePrincipal, User.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role to assign. Accepts role name, role GUID, or fully qualified role definition ID.


- **`subnets`** (`array`) - Optional.
  Array of subnets to deploy in the Virtual Network.
  - **`addressPrefix`** (`string`) - Conditional.
    Address prefix for the subnet. Required if addressPrefixes is empty.

  - **`addressPrefixes`** (`array`) - Conditional.
    List of address prefixes for the subnet. Required if addressPrefix is empty.

  - **`applicationGatewayIPConfigurations`** (`array`) - Optional.
    Application Gateway IP configurations for the subnet.

  - **`defaultOutboundAccess`** (`bool`) - Optional.
    Disable default outbound connectivity for all VMs in subnet. Only allowed at creation time.

  - **`delegation`** (`string`) - Optional.
    Delegation to enable on the subnet.

  - **`ipamPoolPrefixAllocations`** (`array`) - Conditional.
    Address space for subnet from IPAM Pool. Required if both addressPrefix and addressPrefixes are empty and VNet uses IPAM Pool.

  - **`name`** (`string`) - Required.
    Name of the subnet.

  - **`natGatewayResourceId`** (`string`) - Optional.
    NAT Gateway resource ID for the subnet.

  - **`networkSecurityGroupResourceId`** (`string`) - Optional.
    NSG resource ID for the subnet.

  - **`privateEndpointNetworkPolicies`** (`string`) - Optional.
    Policy for private endpoint network. Allowed values: Disabled, Enabled, NetworkSecurityGroupEnabled, RouteTableEnabled.

  - **`privateLinkServiceNetworkPolicies`** (`string`) - Optional.
    Policy for private link service network. Allowed values: Disabled, Enabled.

  - **`roleAssignments`** (`array`) - Optional.
    Role assignments to create on the subnet.
    - **`condition`** (`string`) - Optional.
      Condition applied to the role assignment.

    - **`conditionVersion`** (`string`) - Optional.
      Condition version. Allowed value: 2.0.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional.
      Resource ID of delegated managed identity.

    - **`description`** (`string`) - Optional.
      Description of the role assignment.

    - **`name`** (`string`) - Optional.
      Name of the role assignment. If not provided, a GUID will be generated.

    - **`principalId`** (`string`) - Required.
      Principal ID of the user/group/identity to assign the role to.

    - **`principalType`** (`string`) - Optional.
      Principal type. Allowed values: Device, ForeignGroup, Group, ServicePrincipal, User.

    - **`roleDefinitionIdOrName`** (`string`) - Required.
      Role to assign. Accepts role name, role GUID, or fully qualified role definition ID.


  - **`routeTableResourceId`** (`string`) - Optional.
    Route table resource ID for the subnet.

  - **`serviceEndpointPolicies`** (`array`) - Optional.
    Service endpoint policies for the subnet.

  - **`serviceEndpoints`** (`array`) - Optional.
    Service endpoints enabled on the subnet.

  - **`sharingScope`** (`string`) - Optional.
    Sharing scope for the subnet. Allowed values: DelegatedServices, Tenant.


- **`tags`** (`object`) - Optional.
  Tags to apply to the Virtual Network.

- **`virtualNetworkBgpCommunity`** (`string`) - Optional.
  The BGP community associated with the Virtual Network.

- **`vnetEncryption`** (`bool`) - Optional.
  Indicates if encryption is enabled for the Virtual Network. Requires the EnableVNetEncryption feature and a supported region.

- **`vnetEncryptionEnforcement`** (`string`) - Optional.
  Enforcement policy for unencrypted VMs in an encrypted VNet. Allowed values: AllowUnencrypted, DropUnencrypted.

### `wafPolicyDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `wafPolicyDefinition` | `object` | Conditional | Web Application Firewall (WAF) policy configuration. Required if deploy.wafPolicy is true and you are deploying Application Gateway via this template. |

**Properties:**

- **`customRules`** (`array`) - Optional.
  Custom rules inside the policy.

- **`enableTelemetry`** (`bool`) - Optional.
  Enable or disable usage telemetry for the module. Default is true.

- **`location`** (`string`) - Optional.
  Location for all resources. Default is resourceGroup().location.

- **`managedRules`** (`object`) - Required.
  Managed rules configuration (rule sets and exclusions).
  - **`exclusions`** (`array`) - Optional.
    Exclusions for specific rules or variables.
    - **`excludedRuleSet`** (`object`) - Optional.
      Specific managed rule set exclusion details.
      - **`ruleGroup`** (`array`) - Optional.
        Rule groups to exclude.

      - **`ruleSetType`** (`string`) - Required.
        Rule set type (e.g., OWASP).

      - **`ruleSetVersion`** (`string`) - Required.
        Rule set version (e.g., 3.2).


    - **`matchVariable`** (`string`) - Required.
      Match variable to exclude (e.g., RequestHeaderNames).

    - **`selector`** (`string`) - Required.
      Selector value for the match variable.

    - **`selectorMatchOperator`** (`string`) - Required.
      Selector match operator (e.g., Equals, Contains).


  - **`managedRuleSets`** (`array`) - Required.
    Managed rule sets to apply.
    - **`ruleGroupOverrides`** (`array`) - Optional.
      Overrides for specific rule groups.
      - **`rule`** (`array`) - Required.
        Rule overrides within the group.
        - **`action`** (`string`) - Required.
          Action to take (e.g., Allow, Block, Log).

        - **`enabled`** (`bool`) - Required.
          Whether the rule is enabled.

        - **`id`** (`string`) - Required.
          Rule ID.


      - **`ruleGroupName`** (`string`) - Required.
        Name of the rule group.


    - **`ruleSetType`** (`string`) - Required.
      Rule set type (e.g., OWASP).

    - **`ruleSetVersion`** (`string`) - Required.
      Rule set version.


- **`name`** (`string`) - Required.
  Name of the Application Gateway WAF policy.

- **`policySettings`** (`object`) - Optional.
  Policy settings (state, mode, size limits).
  - **`fileUploadLimitInMb`** (`int`) - Required.
    File upload size limit (MB).

  - **`maxRequestBodySizeInKb`** (`int`) - Required.
    Maximum request body size (KB).

  - **`mode`** (`string`) - Required.
    WAF mode (Prevention or Detection).

  - **`requestBodyCheck`** (`bool`) - Required.
    Enable request body inspection.

  - **`state`** (`string`) - Required.
    WAF policy state.


- **`tags`** (`object`) - Optional.
  Resource tags.

### Optional Parameters

### `acrPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `acrPrivateDnsZoneDefinition` | `object` | Optional | Container Registry Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`aiFoundryConfiguration`** (`object`) - Optional.
  Custom configuration for the AI Foundry account.
  - **`accountName`** (`string`) - Optional.
    The name of the AI Foundry account.

  - **`allowProjectManagement`** (`bool`) - Optional.
    Whether to allow project management in the account. Defaults to true.

  - **`createCapabilityHosts`** (`bool`) - Optional.
    Whether to create capability hosts for the AI Agent Service. Requires includeAssociatedResources = true. Defaults to true.

  - **`disableLocalAuth`** (`bool`) - Optional.
    Disables local authentication methods so that the account requires Microsoft Entra ID identities exclusively for authentication. Defaults to false for backward compatibility.

  - **`location`** (`string`) - Optional.
    Location of the AI Foundry account. Defaults to resource group location.

  - **`networking`** (`object`) - Optional.
    Networking configuration for the AI Foundry account and project.
    - **`agentServiceSubnetResourceId`** (`string`) - Optional.
      Subnet Resource ID for Azure AI Services. Required if you want to deploy AI Agent Service.

    - **`aiServicesPrivateDnsZoneResourceId`** (`string`) - Required.
      Private DNS Zone Resource ID for Azure AI Services.

    - **`cognitiveServicesPrivateDnsZoneResourceId`** (`string`) - Required.
      Private DNS Zone Resource ID for Cognitive Services.

    - **`openAiPrivateDnsZoneResourceId`** (`string`) - Required.
      Private DNS Zone Resource ID for OpenAI.


  - **`project`** (`object`) - Optional.
    Default AI Foundry project.
    - **`description`** (`string`) - Optional.
      Project description.

    - **`displayName`** (`string`) - Optional.
      Friendly/display name of the project.

    - **`name`** (`string`) - Optional.
      Name of the project.


  - **`roleAssignments`** (`array`) - Optional.
    Role assignments to apply to the AI Foundry account.

  - **`sku`** (`string`) - Optional.
    SKU of the AI Foundry / Cognitive Services account. Defaults to S0.


- **`aiModelDeployments`** (`array`) - Optional.
  Specifies the OpenAI deployments to create.
  - **`model`** (`object`) - Required.
    Deployment model configuration.
    - **`format`** (`string`) - Required.
      Format of the deployment model.

    - **`name`** (`string`) - Required.
      Name of the deployment model.

    - **`version`** (`string`) - Required.
      Version of the deployment model.


  - **`name`** (`string`) - Optional.
    Name of the deployment.

  - **`raiPolicyName`** (`string`) - Optional.
    Responsible AI policy name.

  - **`sku`** (`object`) - Optional.
    SKU configuration for the deployment.
    - **`capacity`** (`int`) - Optional.
      SKU capacity.

    - **`family`** (`string`) - Optional.
      SKU family.

    - **`name`** (`string`) - Required.
      SKU name.

    - **`size`** (`string`) - Optional.
      SKU size.

    - **`tier`** (`string`) - Optional.
      SKU tier.


  - **`versionUpgradeOption`** (`string`) - Optional.
    Version upgrade option.


- **`aiSearchConfiguration`** (`object`) - Optional.
  Custom configuration for AI Search.
  - **`existingResourceId`** (`string`) - Optional.
    Existing AI Search resource ID. If provided, other properties are ignored.

  - **`name`** (`string`) - Optional.
    Name for the AI Search resource.

  - **`privateDnsZoneResourceId`** (`string`) - Optional.
    Private DNS Zone Resource ID for AI Search. Required if private endpoints are used.

  - **`roleAssignments`** (`array`) - Optional.
    Role assignments for the AI Search resource.


- **`baseName`** (`string`) - Optional.
  A friendly application/environment name to serve as the base when using the default naming for all resources in this deployment.

- **`baseUniqueName`** (`string`) - Optional.
  A unique text value for the application/environment. Used to ensure resource names are unique for global resources. Defaults to a 5-character substring of the unique string generated from the subscription ID, resource group name, and base name.

- **`cosmosDbConfiguration`** (`object`) - Optional.
  Custom configuration for Cosmos DB.
  - **`existingResourceId`** (`string`) - Optional.
    Existing Cosmos DB resource ID. If provided, other properties are ignored.

  - **`name`** (`string`) - Optional.
    Name for the Cosmos DB resource.

  - **`privateDnsZoneResourceId`** (`string`) - Optional.
    Private DNS Zone Resource ID for Cosmos DB. Required if private endpoints are used.

  - **`roleAssignments`** (`array`) - Optional.
    Role assignments for the Cosmos DB resource.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module. Default is true.

- **`includeAssociatedResources`** (`bool`) - Optional.
  Whether to include associated resources (Key Vault, AI Search, Storage Account, Cosmos DB). Defaults to true.

- **`keyVaultConfiguration`** (`object`) - Optional.
  Custom configuration for Key Vault.
  - **`existingResourceId`** (`string`) - Optional.
    Existing Key Vault resource ID. If provided, other properties are ignored.

  - **`name`** (`string`) - Optional.
    Name for the Key Vault.

  - **`privateDnsZoneResourceId`** (`string`) - Optional.
    Private DNS Zone Resource ID for Key Vault. Required if private endpoints are used.

  - **`roleAssignments`** (`array`) - Optional.
    Role assignments for the Key Vault resource.


- **`location`** (`string`) - Optional.
  Location for all resources. Defaults to the resource group location.

- **`lock`** (`object`) - Optional.
  Lock configuration for the AI resources.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`privateEndpointSubnetResourceId`** (`string`) - Optional.
  The Resource ID of the subnet to establish Private Endpoint(s). If provided, private endpoints will be created for the AI Foundry account and associated resources. Each resource will also require supplied private DNS zone resource ID(s).

- **`storageAccountConfiguration`** (`object`) - Optional.
  Custom configuration for Storage Account.
  - **`blobPrivateDnsZoneResourceId`** (`string`) - Optional.
    Private DNS Zone Resource ID for blob endpoint. Required if private endpoints are used.

  - **`existingResourceId`** (`string`) - Optional.
    Existing Storage Account resource ID. If provided, other properties are ignored.

  - **`name`** (`string`) - Optional.
    Name for the Storage Account.

  - **`roleAssignments`** (`array`) - Optional.
    Role assignments for the Storage Account.


- **`tags`** (`object`) - Optional.
  Specifies the resource tags for all the resources.

### `aiSearchDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `aiSearchDefinition` | `object` | Optional | AI Search settings. |

**Properties:**

- **`authOptions`** (`object`) - Optional.
  Defines the options for how the data plane API of a Search service authenticates requests. Must remain {} if disableLocalAuth=true.
  - **`aadOrApiKey`** (`object`) - Optional.
    Indicates that either API key or an access token from Microsoft Entra ID can be used for authentication.
    - **`aadAuthFailureMode`** (`string`) - Optional.
      Response sent when authentication fails. Allowed values: http401WithBearerChallenge, http403.


  - **`apiKeyOnly`** (`object`) - Optional.
    Indicates that only the API key can be used for authentication.


- **`cmkEnforcement`** (`string`) - Optional.
  Policy that determines how resources within the search service are encrypted with Customer Managed Keys. Default is Unspecified. Allowed values: Disabled, Enabled, Unspecified.

- **`diagnosticSettings`** (`array`) - Optional.
  Diagnostic settings for the search service.
  - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional.
    Resource ID of the diagnostic Event Hub authorization rule.

  - **`eventHubName`** (`string`) - Optional.
    Name of the diagnostic Event Hub. Without this, one Event Hub per category will be created.

  - **`logAnalyticsDestinationType`** (`string`) - Optional.
    Destination type for Log Analytics. Allowed values: AzureDiagnostics, Dedicated.

  - **`logCategoriesAndGroups`** (`array`) - Optional.
    Log categories and groups to collect. Use [] to disable.
    - **`category`** (`string`) - Optional.
      Diagnostic log category.

    - **`categoryGroup`** (`string`) - Optional.
      Diagnostic log category group. Use allLogs to collect all logs.

    - **`enabled`** (`bool`) - Optional.
      Enable or disable this log category. Default is true.

  - **`marketplacePartnerResourceId`** (`string`) - Optional.
    Marketplace partner resource ID to send logs to.

  - **`metricCategories`** (`array`) - Optional.
    Metric categories to collect.
    - **`category`** (`string`) - Required.
      Diagnostic metric category. Example: AllMetrics.

    - **`enabled`** (`bool`) - Optional.
      Enable or disable this metric category. Default is true.

  - **`name`** (`string`) - Optional.
    Name of the diagnostic setting.

  - **`storageAccountResourceId`** (`string`) - Optional.
    Storage account resource ID for diagnostic logs.

  - **`workspaceResourceId`** (`string`) - Optional.
    Log Analytics workspace resource ID for diagnostic logs.
- **`disableLocalAuth`** (`bool`) - Optional.
  Disable local authentication via API keys. Cannot be true if authOptions are defined. Default is true.

- **`enableTelemetry`** (`bool`) - Optional.
  Enable/disable usage telemetry for the module. Default is true.

- **`hostingMode`** (`string`) - Optional.
  Hosting mode, only for standard3 SKU. Allowed values: default, highDensity. Default is default.

- **`location`** (`string`) - Optional.
  Location for all resources. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional.
  Lock settings for the search service.
  - **`kind`** (`string`) - Optional.
    Type of lock. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional.
    Name of the lock.

  - **`notes`** (`string`) - Optional.
    Notes for the lock.


- **`managedIdentities`** (`object`) - Optional.
  Managed identity definition for the search service.
  - **`systemAssigned`** (`bool`) - Optional.
    Enables system-assigned managed identity.

  - **`userAssignedResourceIds`** (`array`) - Optional.
    User-assigned identity resource IDs. Required if user-assigned identity is used for encryption.


- **`name`** (`string`) - Required.
  The name of the Azure Cognitive Search service to create or update. Must only contain lowercase letters, digits or dashes, cannot use dash as the first two or last one characters, cannot contain consecutive dashes, must be between 2 and 60 characters in length, and must be globally unique. Immutable after creation.

- **`networkRuleSet`** (`object`) - Optional.
  Network rules for the search service.
  - **`bypass`** (`string`) - Optional.
    Bypass setting. Allowed values: AzurePortal, AzureServices, None.

  - **`ipRules`** (`array`) - Optional.
    IP restriction rules applied when publicNetworkAccess=Enabled.
    - **`value`** (`string`) - Required.
      IPv4 address (e.g., 123.1.2.3) or range in CIDR format (e.g., 123.1.2.3/24) to allow.


- **`partitionCount`** (`int`) - Optional.
  Number of partitions in the search service. Valid values: 1,2,3,4,6,12 (or 1–3 for standard3 highDensity). Default is 1.

- **`privateEndpoints`** (`array`) - Optional.
  Configuration details for private endpoints.

- **`publicNetworkAccess`** (`string`) - Optional.
  Public network access. Default is Enabled. Allowed values: Enabled, Disabled.

- **`replicaCount`** (`int`) - Optional.
  Number of replicas in the search service. Must be 1–12 for Standard SKUs or 1–3 for Basic. Default is 3.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the search service.

- **`secretsExportConfiguration`** (`object`) - Optional.
  Key Vault reference and secret settings for exporting admin keys.
  - **`keyVaultResourceId`** (`string`) - Required.
    Key Vault resource ID where the API Admin keys will be stored.

  - **`primaryAdminKeyName`** (`string`) - Optional.
    Secret name for the primary admin key.

  - **`secondaryAdminKeyName`** (`string`) - Optional.
    Secret name for the secondary admin key.


- **`semanticSearch`** (`string`) - Optional.
  Semantic search configuration. Allowed values: disabled, free, standard.

- **`sharedPrivateLinkResources`** (`array`) - Optional.
  Shared Private Link Resources to create. Default is [].

- **`sku`** (`string`) - Optional.
  SKU of the search service. Determines price tier and limits. Default is standard. Allowed values: basic, free, standard, standard2, standard3, storage_optimized_l1, storage_optimized_l2.

- **`tags`** (`object`) - Optional.
  Tags for categorizing the search service.

### `aiServicesPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `aiServicesPrivateDnsZoneDefinition` | `object` | Optional | AI Services Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.

- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`additionalLocations`** (`array`) - Optional.
  Additional locations for the API Management service.

- **`apiDiagnostics`** (`array`) - Optional.
  API diagnostics for APIs.

- **`apis`** (`array`) - Optional.
  APIs to create in the API Management service.

- **`apiVersionSets`** (`array`) - Optional.
  API version sets to configure.

- **`authorizationServers`** (`array`) - Optional.
  Authorization servers to configure.

- **`availabilityZones`** (`array`) - Optional.
  Availability Zones for HA deployment.

- **`backends`** (`array`) - Optional.
  Backends to configure.

- **`caches`** (`array`) - Optional.
  Caches to configure.

- **`certificates`** (`array`) - Optional.
  Certificates to configure for API Management. Maximum of 10 certificates.

- **`customProperties`** (`object`) - Optional.
  Custom properties to configure.

- **`diagnosticSettings`** (`array`) - Optional.
  Diagnostic settings for the API Management service.

- **`disableGateway`** (`bool`) - Optional.
  Disable gateway in a region (for multi-region setup).

- **`enableClientCertificate`** (`bool`) - Optional.
  Enable client certificate for requests (Consumption SKU only).

- **`enableDeveloperPortal`** (`bool`) - Optional.
  Enable developer portal for the service.

- **`enableTelemetry`** (`bool`) - Optional.
  Enable/disable usage telemetry for module. Default is true.

- **`hostnameConfigurations`** (`array`) - Optional.
  Hostname configurations for the API Management service.

- **`identityProviders`** (`array`) - Optional.
  Identity providers to configure.

- **`location`** (`string`) - Optional.
  Location for the API Management service. Default is resourceGroup().location.

- **`lock`** (`object`) - Optional.
  Lock settings for the API Management service.
  - **`kind`** (`string`) - Optional.
    Type of lock. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional.
    Name of the lock.

  - **`notes`** (`string`) - Optional.
    Notes for the lock.


- **`loggers`** (`array`) - Optional.
  Loggers to configure.

- **`managedIdentities`** (`object`) - Optional.
  Managed identity settings for the API Management service.
  - **`systemAssigned`** (`bool`) - Optional.
    Enables system-assigned managed identity.

  - **`userAssignedResourceIds`** (`array`) - Optional.
    User-assigned identity resource IDs.


- **`minApiVersion`** (`string`) - Optional.
  Minimum ARM API version to use for control-plane operations.

- **`name`** (`string`) - Required.
  Name of the API Management service.

- **`namedValues`** (`array`) - Optional.
  Named values to configure.

- **`newGuidValue`** (`string`) - Optional.
  Helper for generating new GUID values.

- **`notificationSenderEmail`** (`string`) - Optional.
  Notification sender email address.

- **`policies`** (`array`) - Optional.
  Policies to configure.

- **`portalsettings`** (`array`) - Optional.
  Portal settings for the developer portal.

- **`products`** (`array`) - Optional.
  Products to configure.

- **`publicIpAddressResourceId`** (`string`) - Optional.
  Public IP address resource ID for API Management.

- **`publisherEmail`** (`string`) - Required.
  Publisher email address.

- **`publisherName`** (`string`) - Required.
  Publisher display name.

- **`restore`** (`bool`) - Optional.
  Restore configuration for undeleting API Management services.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the API Management service.

- **`sku`** (`string`) - Optional.
  SKU of the API Management service. Allowed values: Basic, BasicV2, Consumption, Developer, Premium, Standard, StandardV2.

- **`skuCapacity`** (`int`) - Conditional.
  SKU capacity. Required if SKU is not Consumption.

- **`subnetResourceId`** (`string`) - Optional.
  Subnet resource ID for VNet integration.

- **`subscriptions`** (`array`) - Optional.
  Subscriptions to configure.

- **`tags`** (`object`) - Optional.
  Tags to apply to the API Management service.

- **`virtualNetworkType`** (`string`) - Optional.
  Virtual network type. Allowed values: None, External, Internal.

### `apimPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `apimPrivateDnsZoneDefinition` | `object` | Optional | API Management Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable or disable usage telemetry for the module. Default is true.

- **`extensionProperties`** (`object`) - Optional.
  Extension properties of the Maintenance Configuration.

- **`installPatches`** (`object`) - Optional.
  Configuration settings for VM guest patching with Azure Update Manager.

- **`location`** (`string`) - Optional.
  Resource location. Defaults to the resource group location.

- **`lock`** (`object`) - Optional.
  Lock configuration for the Maintenance Configuration.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`maintenanceScope`** (`string`) - Optional.
  Maintenance scope of the configuration. Default is Host.

- **`maintenanceWindow`** (`object`) - Optional.
  Definition of the Maintenance Window.

- **`name`** (`string`) - Required.
  Name of the Maintenance Configuration.

- **`namespace`** (`string`) - Optional.
  Namespace of the resource.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments to apply to the Maintenance Configuration.
  - **`condition`** (`string`) - Optional.
    Condition for the role assignment.

  - **`conditionVersion`** (`string`) - Optional.
    Condition version.

  - **`delegatedManagedIdentityResourceId`** (`string`) - Optional.
    Delegated managed identity resource ID.

  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Role assignment name (GUID). If omitted, a GUID is generated.

  - **`principalId`** (`string`) - Required.
    Principal ID of the identity being assigned.

  - **`principalType`** (`string`) - Optional.
    Principal type of the assigned identity.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role to assign (display name, GUID, or full resource ID).


- **`tags`** (`object`) - Optional.
  Tags to apply to the Maintenance Configuration resource.

- **`visibility`** (`string`) - Optional.
  Visibility of the configuration. Default is Custom.

### `cognitiveServicesPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `cognitiveServicesPrivateDnsZoneDefinition` | `object` | Optional | Cognitive Services Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`automaticFailover`** (`bool`) - Optional.
  Enable automatic failover for regions. Defaults to true.

- **`backupIntervalInMinutes`** (`int`) - Optional.
  Interval in minutes between two backups (periodic only). Defaults to 240. Range: 60–1440.

- **`backupPolicyContinuousTier`** (`string`) - Optional.
  Retention period for continuous mode backup. Default is Continuous30Days. Allowed values: Continuous30Days, Continuous7Days.

- **`backupPolicyType`** (`string`) - Optional.
  Backup mode. Periodic must be used if multiple write locations are enabled. Default is Continuous. Allowed values: Continuous, Periodic.

- **`backupRetentionIntervalInHours`** (`int`) - Optional.
  Time (hours) each backup is retained (periodic only). Default is 8. Range: 2–720.

- **`backupStorageRedundancy`** (`string`) - Optional.
  Type of backup residency (periodic only). Default is Local. Allowed values: Geo, Local, Zone.

- **`capabilitiesToAdd`** (`array`) - Optional.
  List of Cosmos DB specific capabilities to enable.

- **`databaseAccountOfferType`** (`string`) - Optional.
  The offer type for the account. Default is Standard. Allowed value: Standard.

- **`dataPlaneRoleAssignments`** (`array`) - Optional.
  Cosmos DB for NoSQL native role-based access control assignments.
  - **`name`** (`string`) - Optional.
    Unique name of the role assignment.

  - **`principalId`** (`string`) - Required.
    The Microsoft Entra principal ID granted access by this assignment.

  - **`roleDefinitionId`** (`string`) - Required.
    The unique identifier of the NoSQL native role definition.


- **`dataPlaneRoleDefinitions`** (`array`) - Optional.
  Cosmos DB for NoSQL native role-based access control definitions.
  - **`assignableScopes`** (`array`) - Optional.
    Assignable scopes for the definition.

  - **`assignments`** (`array`) - Optional.
    Assignments associated with this role definition.
    - **`name`** (`string`) - Optional.
      Unique identifier name for the role assignment.

    - **`principalId`** (`string`) - Required.
      The Microsoft Entra principal ID granted access by this role assignment.


  - **`dataActions`** (`array`) - Optional.
    Array of allowed data actions.

  - **`name`** (`string`) - Optional.
    Unique identifier for the role definition.

  - **`roleName`** (`string`) - Required.
    A user-friendly unique name for the role definition.


- **`defaultConsistencyLevel`** (`string`) - Optional.
  Default consistency level. Default is Session. Allowed values: BoundedStaleness, ConsistentPrefix, Eventual, Session, Strong.

- **`diagnosticSettings`** (`array`) - Optional.
  Diagnostic settings for the Cosmos DB account.

- **`disableKeyBasedMetadataWriteAccess`** (`bool`) - Optional.
  Disable write operations on metadata resources via account keys. Default is true.

- **`disableLocalAuthentication`** (`bool`) - Optional.
  Opt-out of local authentication, enforcing Microsoft Entra-only auth. Default is true.

- **`enableAnalyticalStorage`** (`bool`) - Optional.
  Enable analytical storage. Default is false.

- **`enableFreeTier`** (`bool`) - Optional.
  Enable Free Tier. Default is false.

- **`enableMultipleWriteLocations`** (`bool`) - Optional.
  Enable multiple write locations. Requires periodic backup. Default is false.

- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry. Default is true.

- **`failoverLocations`** (`array`) - Optional.
  Failover locations configuration.
  - **`failoverPriority`** (`int`) - Required.
    Failover priority. 0 = write region.

  - **`isZoneRedundant`** (`bool`) - Optional.
    Zone redundancy flag for region. Default is true.

  - **`locationName`** (`string`) - Required.
    Region name.


- **`gremlinDatabases`** (`array`) - Optional.
  Gremlin database configurations.

- **`location`** (`string`) - Optional.
  Location for the account. Defaults to resourceGroup().location.

- **`lock`** (`object`) - Optional.
  Lock settings for the Cosmos DB account.
  - **`kind`** (`string`) - Optional.
    Lock type. Allowed values: CanNotDelete, None, ReadOnly.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`managedIdentities`** (`object`) - Optional.
  Managed identity configuration.
  - **`systemAssigned`** (`bool`) - Optional.
    Enables system-assigned identity.

  - **`userAssignedResourceIds`** (`array`) - Optional.
    User-assigned identity resource IDs.


- **`maxIntervalInSeconds`** (`int`) - Optional.
  Maximum lag time in seconds (BoundedStaleness). Defaults to 300.

- **`maxStalenessPrefix`** (`int`) - Optional.
  Maximum stale requests (BoundedStaleness). Defaults to 100000.

- **`minimumTlsVersion`** (`string`) - Optional.
  Minimum allowed TLS version. Default is Tls12.

- **`mongodbDatabases`** (`array`) - Optional.
  MongoDB database configurations.

- **`name`** (`string`) - Required.
  The name of the account.

- **`networkRestrictions`** (`object`) - Optional.
  Network restrictions for the Cosmos DB account.

- **`privateEndpoints`** (`array`) - Optional.
  Private endpoint configurations for secure connectivity.

- **`roleAssignments`** (`array`) - Optional.
  Control plane Azure role assignments for Cosmos DB.

- **`serverVersion`** (`string`) - Optional.
  MongoDB server version (if using MongoDB API). Default is 4.2.

- **`sqlDatabases`** (`array`) - Optional.
  SQL (NoSQL) database configurations.

- **`tables`** (`array`) - Optional.
  Table API database configurations.

- **`tags`** (`object`) - Optional.
  Tags to apply to the Cosmos DB account.

- **`totalThroughputLimit`** (`int`) - Optional.
  Total throughput limit in RU/s. Default is unlimited (-1).

- **`zoneRedundant`** (`bool`) - Optional.
  Zone redundancy for single-region accounts. Default is true.

### `cosmosPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `cosmosPrivateDnsZoneDefinition` | `object` | Optional | Cosmos DB Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`existingVNetName`** (`string`) - Required.
  Name or Resource ID of the existing Virtual Network. For cross-subscription/resource group scenarios, use the full Resource ID format: /subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Network/virtualNetworks/{vnet-name}

- **`subnets`** (`array`) - Optional.
  Array of custom subnets to add to the existing VNet. If not provided and useDefaultSubnets is true, uses default AI Landing Zone subnets.
  - **`addressPrefix`** (`string`) - Conditional.
    Address prefix for the subnet. Required if addressPrefixes is empty.

  - **`addressPrefixes`** (`array`) - Conditional.
    List of address prefixes for the subnet. Required if addressPrefix is empty.

  - **`applicationGatewayIPConfigurations`** (`array`) - Optional.
    Application Gateway IP configurations for the subnet.

  - **`defaultOutboundAccess`** (`bool`) - Optional.
    Disable default outbound connectivity for all VMs in subnet.

  - **`delegation`** (`string`) - Optional.
    Delegation to enable on the subnet.

  - **`name`** (`string`) - Required.
    Name of the subnet.

  - **`natGatewayResourceId`** (`string`) - Optional.
    NAT Gateway resource ID for the subnet.

  - **`networkSecurityGroupResourceId`** (`string`) - Optional.
    NSG resource ID for the subnet.

  - **`privateEndpointNetworkPolicies`** (`string`) - Optional.
    Policy for private endpoint network.

  - **`privateLinkServiceNetworkPolicies`** (`string`) - Optional.
    Policy for private link service network.

  - **`routeTableResourceId`** (`string`) - Optional.
    Route table resource ID for the subnet.

  - **`serviceEndpointPolicies`** (`array`) - Optional.
    Service endpoint policies for the subnet.

  - **`serviceEndpoints`** (`array`) - Optional.
    Service endpoints enabled on the subnet.

  - **`sharingScope`** (`string`) - Optional.
    Sharing scope for the subnet.


- **`useDefaultSubnets`** (`bool`) - Optional.
  Use default AI Landing Zone subnets with 192.168.x.x addressing. Default: true.

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

- **`enableTelemetry`** (`bool`) - Optional.
  Enable or disable usage telemetry for the module. Default is true.

- **`extensionProperties`** (`object`) - Optional.
  Extension properties of the Maintenance Configuration.

- **`installPatches`** (`object`) - Optional.
  Configuration settings for VM guest patching with Azure Update Manager.

- **`location`** (`string`) - Optional.
  Resource location. Defaults to the resource group location.

- **`lock`** (`object`) - Optional.
  Lock configuration for the Maintenance Configuration.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`maintenanceScope`** (`string`) - Optional.
  Maintenance scope of the configuration. Default is Host.

- **`maintenanceWindow`** (`object`) - Optional.
  Definition of the Maintenance Window.

- **`name`** (`string`) - Required.
  Name of the Maintenance Configuration.

- **`namespace`** (`string`) - Optional.
  Namespace of the resource.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments to apply to the Maintenance Configuration.
  - **`condition`** (`string`) - Optional.
    Condition for the role assignment.

  - **`conditionVersion`** (`string`) - Optional.
    Condition version.

  - **`delegatedManagedIdentityResourceId`** (`string`) - Optional.
    Delegated managed identity resource ID.

  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Role assignment name (GUID). If omitted, a GUID is generated.

  - **`principalId`** (`string`) - Required.
    Principal ID of the identity being assigned.

  - **`principalType`** (`string`) - Optional.
    Principal type of the assigned identity.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role to assign (display name, GUID, or full resource ID).


- **`tags`** (`object`) - Optional.
  Tags to apply to the Maintenance Configuration resource.

- **`visibility`** (`string`) - Optional.
  Visibility of the configuration. Default is Custom.

### `keyVaultDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `keyVaultDefinition` | `object` | Optional | Key Vault settings. |

**Properties:**

- **`accessPolicies`** (`array`) - Optional.
  All access policies to create.
  - **`applicationId`** (`string`) - Optional.
    Application ID of the client making request on behalf of a principal.

  - **`objectId`** (`string`) - Required.
    The object ID of a user, service principal or security group in the tenant for the vault.

  - **`permissions`** (`object`) - Required.
    Permissions the identity has for keys, secrets and certificates.
    - **`certificates`** (`array`) - Optional.
      Permissions to certificates.

    - **`keys`** (`array`) - Optional.
      Permissions to keys.

    - **`secrets`** (`array`) - Optional.
      Permissions to secrets.

    - **`storage`** (`array`) - Optional.
      Permissions to storage accounts.


  - **`tenantId`** (`string`) - Optional.
    The tenant ID that is used for authenticating requests to the key vault.


- **`createMode`** (`string`) - Optional.
  The vault's create mode to indicate whether the vault needs to be recovered or not.

- **`diagnosticSettings`** (`array`) - Optional.
  The diagnostic settings of the service.

- **`enablePurgeProtection`** (`bool`) - Optional.
  Provide true to enable Key Vault purge protection feature.

- **`enableRbacAuthorization`** (`bool`) - Optional.
  Controls how data actions are authorized. When true, RBAC is used for authorization.

- **`enableSoftDelete`** (`bool`) - Optional.
  Switch to enable/disable Key Vault soft delete feature.

- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for module.

- **`enableVaultForDeployment`** (`bool`) - Optional.
  Specifies if the vault is enabled for deployment by script or compute.

- **`enableVaultForDiskEncryption`** (`bool`) - Optional.
  Specifies if the platform has access to the vault for disk encryption scenarios.

- **`enableVaultForTemplateDeployment`** (`bool`) - Optional.
  Specifies if the vault is enabled for a template deployment.

- **`keys`** (`array`) - Optional.
  All keys to create.

- **`location`** (`string`) - Optional.
  Location for all resources.

- **`lock`** (`object`) - Optional.
  The lock settings of the service.
  - **`kind`** (`string`) - Optional.
    Specify the type of lock.

  - **`name`** (`string`) - Optional.
    Specify the name of the lock.

  - **`notes`** (`string`) - Optional.
    Specify the notes of the lock.


- **`name`** (`string`) - Required.
  Name of the Key Vault. Must be globally unique.

- **`networkAcls`** (`object`) - Optional.
  Rules governing the accessibility of the resource from specific networks.

- **`privateEndpoints`** (`array`) - Optional.
  Configuration details for private endpoints.
  - **`applicationSecurityGroupResourceIds`** (`array`) - Optional.
    Application security groups in which the Private Endpoint IP configuration is included.

  - **`customDnsConfigs`** (`array`) - Optional.
    Custom DNS configurations.
    - **`fqdn`** (`string`) - Optional.
      FQDN that resolves to private endpoint IP address.

    - **`ipAddresses`** (`array`) - Required.
      A list of private IP addresses of the private endpoint.


  - **`customNetworkInterfaceName`** (`string`) - Optional.
    The custom name of the network interface attached to the Private Endpoint.

  - **`enableTelemetry`** (`bool`) - Optional.
    Enable/Disable usage telemetry for module.

  - **`ipConfigurations`** (`array`) - Optional.
    A list of IP configurations of the Private Endpoint.
    - **`name`** (`string`) - Required.
      The name of the resource that is unique within a resource group.

    - **`properties`** (`object`) - Required.
      Properties of private endpoint IP configurations.
      - **`groupId`** (`string`) - Required.
        The ID of a group obtained from the remote resource to connect to.

      - **`memberName`** (`string`) - Required.
        The member name of a group obtained from the remote resource.

      - **`privateIPAddress`** (`string`) - Required.
        A private IP address obtained from the private endpoint's subnet.



  - **`isManualConnection`** (`bool`) - Optional.
    If Manual Private Link Connection is required.

  - **`location`** (`string`) - Optional.
    The location to deploy the Private Endpoint to.

  - **`lock`** (`object`) - Optional.
    Lock settings for the Private Endpoint.
    - **`kind`** (`string`) - Optional.
      Specify the type of lock.

    - **`name`** (`string`) - Optional.
      Specify the name of the lock.

    - **`notes`** (`string`) - Optional.
      Specify the notes of the lock.


  - **`manualConnectionRequestMessage`** (`string`) - Optional.
    A message passed with the manual connection request.

  - **`name`** (`string`) - Optional.
    The name of the Private Endpoint.

  - **`privateDnsZoneGroup`** (`object`) - Optional.
    The private DNS zone group to configure for the Private Endpoint.
    - **`name`** (`string`) - Optional.
      The name of the Private DNS Zone Group.

    - **`privateDnsZoneGroupConfigs`** (`array`) - Required.
      The private DNS Zone Groups to associate the Private Endpoint.
      - **`name`** (`string`) - Optional.
        The name of the private DNS Zone Group config.

      - **`privateDnsZoneResourceId`** (`string`) - Required.
        The resource ID of the private DNS zone.


  - **`privateLinkServiceConnectionName`** (`string`) - Optional.
    The name of the private link connection to create.

  - **`resourceGroupResourceId`** (`string`) - Optional.
    The resource ID of the Resource Group the Private Endpoint will be created in.

  - **`roleAssignments`** (`array`) - Optional.
    Array of role assignments to create for the Private Endpoint.

  - **`service`** (`string`) - Optional.
    The subresource to deploy the Private Endpoint for (e.g., vault).

  - **`subnetResourceId`** (`string`) - Required.
    Resource ID of the subnet where the endpoint needs to be created.

  - **`tags`** (`object`) - Optional.
    Tags for the Private Endpoint.


- **`publicNetworkAccess`** (`string`) - Optional.
  Whether or not public network access is allowed for this resource.

- **`roleAssignments`** (`array`) - Optional.
  Array of role assignments to create at the vault level.

- **`secrets`** (`array`) - Optional.
  All secrets to create.
  - **`attributes`** (`object`) - Optional.
    Contains attributes of the secret.
    - **`enabled`** (`bool`) - Optional.
      Defines whether the secret is enabled or disabled.

    - **`exp`** (`int`) - Optional.
      Expiration time of the secret, in epoch seconds.

    - **`nbf`** (`int`) - Optional.
      Not-before time of the secret, in epoch seconds.


  - **`contentType`** (`string`) - Optional.
    The content type of the secret.

  - **`name`** (`string`) - Required.
    The name of the secret.

  - **`roleAssignments`** (`array`) - Optional.
    Array of role assignments to create for the secret.

  - **`tags`** (`object`) - Optional.
    Resource tags for the secret.

  - **`value`** (`securestring`) - Required.
    The value of the secret.


- **`sku`** (`string`) - Optional.
  Specifies the SKU for the vault.

- **`softDeleteRetentionInDays`** (`int`) - Optional.
  Soft delete retention days (between 7 and 90).

- **`tags`** (`object`) - Optional.
  Resource tags for the vault.

### `keyVaultPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `keyVaultPrivateDnsZoneDefinition` | `object` | Optional | Key Vault Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`acaEnvironment`** (`object`) - Optional.
  NSG definition applied to the Azure Container Apps environment (infrastructure) subnet.
  - **`diagnosticSettings`** (`array`) - Optional.
    Diagnostic settings to send NSG logs/metrics to Log Analytics, Event Hub, or Storage.
    - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional.
      Destination Event Hub authorization rule resource ID.

    - **`eventHubName`** (`string`) - Optional.
      Destination Event Hub name when sending to Event Hub.

    - **`logAnalyticsDestinationType`** (`string`) - Optional.
      Destination type for Log Analytics (AzureDiagnostics or Dedicated).

    - **`logCategoriesAndGroups`** (`array`) - Optional.
      List of categories and/or category groups to enable.
      - **`category`** (`string`) - Optional.
        Single diagnostic log category to enable.

      - **`categoryGroup`** (`string`) - Optional.
        Category group (e.g., AllMetrics) to enable.

      - **`enabled`** (`bool`) - Optional.
        Whether this category/category group is enabled.


    - **`marketplacePartnerResourceId`** (`string`) - Optional.
      Marketplace partner destination resource ID (if applicable).

    - **`name`** (`string`) - Optional.
      Name of the diagnostic settings resource.

    - **`storageAccountResourceId`** (`string`) - Optional.
      Destination Storage Account resource ID.

    - **`workspaceResourceId`** (`string`) - Optional.
      Destination Log Analytics workspace resource ID.


  - **`enableTelemetry`** (`bool`) - Optional.
    Enable or disable usage telemetry for this module. Default: true.

  - **`flushConnection`** (`bool`) - Optional.
    When true, flows created from NSG connections are re-evaluated when rules are updated. Default: false.

  - **`location`** (`string`) - Optional.
    Azure region for the NSG. Defaults to the resource group location.

  - **`lock`** (`object`) - Optional.
    Management lock configuration for the NSG.
    - **`kind`** (`string`) - Optional.
      Lock type (None, CanNotDelete, or ReadOnly).

    - **`name`** (`string`) - Optional.
      Name of the management lock.

    - **`notes`** (`string`) - Optional.
      Notes describing the reason for the lock.


  - **`name`** (`string`) - Optional.
    Name of the Network Security Group.

  - **`roleAssignments`** (`array`) - Optional.
    Role assignments to apply on the NSG.
    - **`condition`** (`string`) - Optional.
      Advanced condition expression for the assignment.

    - **`conditionVersion`** (`string`) - Optional.
      Condition version. Use 2.0 when condition is provided.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional.
      Delegated managed identity resource ID (for cross-tenant scenarios).

    - **`description`** (`string`) - Optional.
      Description for the role assignment.

    - **`name`** (`string`) - Optional.
      Stable GUID name of the role assignment (omit to auto-generate).

    - **`principalId`** (`string`) - Required.
      Principal (object) ID for the assignment.

    - **`principalType`** (`string`) - Optional.
      Principal type for the assignment.

    - **`roleDefinitionIdOrName`** (`string`) - Required.
      Role to assign (name, GUID, or fully qualified role definition ID).


  - **`securityRules`** (`array`) - Optional.
    Security rules to apply to the NSG. If omitted, only default rules are present.
    - **`name`** (`string`) - Required.
      Name of the security rule.

    - **`properties`** (`object`) - Required.
      Properties that define the behavior of the security rule.
      - **`access`** (`string`) - Required.
        Whether matching traffic is allowed or denied.

      - **`description`** (`string`) - Optional.
        Free-form description for the rule.

      - **`destinationAddressPrefix`** (`string`) - Optional.
        Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

      - **`destinationAddressPrefixes`** (`array`) - Optional.
        Multiple destination address prefixes.

      - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional.
        Destination Application Security Group (ASG) resource IDs.

      - **`destinationPortRange`** (`string`) - Optional.
        Single destination port or port range (e.g., 443, 1000-2000).

      - **`destinationPortRanges`** (`array`) - Optional.
        Multiple destination ports or port ranges.

      - **`direction`** (`string`) - Required.
        Direction of the rule (Inbound or Outbound).

      - **`priority`** (`int`) - Required.
        Priority of the rule (100–4096). Must be unique per rule in the NSG.

      - **`protocol`** (`string`) - Required.
        Network protocol to match.

      - **`sourceAddressPrefix`** (`string`) - Optional.
        Single source address prefix (e.g., Internet, 10.0.0.0/24).

      - **`sourceAddressPrefixes`** (`array`) - Optional.
        Multiple source address prefixes.

      - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional.
        Source Application Security Group (ASG) resource IDs.

      - **`sourcePortRange`** (`string`) - Optional.
        Single source port or port range.

      - **`sourcePortRanges`** (`array`) - Optional.
        Multiple source ports or port ranges.



  - **`tags`** (`object`) - Optional.
    Tags to apply to the NSG.


- **`agent`** (`object`) - Optional.
  NSG definition applied to the agent (workload) subnet.
  - **`diagnosticSettings`** (`array`) - Optional.
    Diagnostic settings to send NSG logs/metrics to Log Analytics, Event Hub, or Storage.
    - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional.
      Destination Event Hub authorization rule resource ID.

    - **`eventHubName`** (`string`) - Optional.
      Destination Event Hub name when sending to Event Hub.

    - **`logAnalyticsDestinationType`** (`string`) - Optional.
      Destination type for Log Analytics (AzureDiagnostics or Dedicated).

    - **`logCategoriesAndGroups`** (`array`) - Optional.
      List of categories and/or category groups to enable.
      - **`category`** (`string`) - Optional.
        Single diagnostic log category to enable.

      - **`categoryGroup`** (`string`) - Optional.
        Category group (e.g., AllMetrics) to enable.

      - **`enabled`** (`bool`) - Optional.
        Whether this category/category group is enabled.


    - **`marketplacePartnerResourceId`** (`string`) - Optional.
      Marketplace partner destination resource ID (if applicable).

    - **`name`** (`string`) - Optional.
      Name of the diagnostic settings resource.

    - **`storageAccountResourceId`** (`string`) - Optional.
      Destination Storage Account resource ID.

    - **`workspaceResourceId`** (`string`) - Optional.
      Destination Log Analytics workspace resource ID.


  - **`enableTelemetry`** (`bool`) - Optional.
    Enable or disable usage telemetry for this module. Default: true.

  - **`flushConnection`** (`bool`) - Optional.
    When true, flows created from NSG connections are re-evaluated when rules are updated. Default: false.

  - **`location`** (`string`) - Optional.
    Azure region for the NSG. Defaults to the resource group location.

  - **`lock`** (`object`) - Optional.
    Management lock configuration for the NSG.
    - **`kind`** (`string`) - Optional.
      Lock type (None, CanNotDelete, or ReadOnly).

    - **`name`** (`string`) - Optional.
      Name of the management lock.

    - **`notes`** (`string`) - Optional.
      Notes describing the reason for the lock.


  - **`name`** (`string`) - Optional.
    Name of the Network Security Group.

  - **`roleAssignments`** (`array`) - Optional.
    Role assignments to apply on the NSG.
    - **`condition`** (`string`) - Optional.
      Advanced condition expression for the assignment.

    - **`conditionVersion`** (`string`) - Optional.
      Condition version. Use 2.0 when condition is provided.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional.
      Delegated managed identity resource ID (for cross-tenant scenarios).

    - **`description`** (`string`) - Optional.
      Description for the role assignment.

    - **`name`** (`string`) - Optional.
      Stable GUID name of the role assignment (omit to auto-generate).

    - **`principalId`** (`string`) - Required.
      Principal (object) ID for the assignment.

    - **`principalType`** (`string`) - Optional.
      Principal type for the assignment.

    - **`roleDefinitionIdOrName`** (`string`) - Required.
      Role to assign (name, GUID, or fully qualified role definition ID).


  - **`securityRules`** (`array`) - Optional.
    Security rules to apply to the NSG. If omitted, only default rules are present.
    - **`name`** (`string`) - Required.
      Name of the security rule.

    - **`properties`** (`object`) - Required.
      Properties that define the behavior of the security rule.
      - **`access`** (`string`) - Required.
        Whether matching traffic is allowed or denied.

      - **`description`** (`string`) - Optional.
        Free-form description for the rule.

      - **`destinationAddressPrefix`** (`string`) - Optional.
        Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

      - **`destinationAddressPrefixes`** (`array`) - Optional.
        Multiple destination address prefixes.

      - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional.
        Destination Application Security Group (ASG) resource IDs.

      - **`destinationPortRange`** (`string`) - Optional.
        Single destination port or port range (e.g., 443, 1000-2000).

      - **`destinationPortRanges`** (`array`) - Optional.
        Multiple destination ports or port ranges.

      - **`direction`** (`string`) - Required.
        Direction of the rule (Inbound or Outbound).

      - **`priority`** (`int`) - Required.
        Priority of the rule (100–4096). Must be unique per rule in the NSG.

      - **`protocol`** (`string`) - Required.
        Network protocol to match.

      - **`sourceAddressPrefix`** (`string`) - Optional.
        Single source address prefix (e.g., Internet, 10.0.0.0/24).

      - **`sourceAddressPrefixes`** (`array`) - Optional.
        Multiple source address prefixes.

      - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional.
        Source Application Security Group (ASG) resource IDs.

      - **`sourcePortRange`** (`string`) - Optional.
        Single source port or port range.

      - **`sourcePortRanges`** (`array`) - Optional.
        Multiple source ports or port ranges.



  - **`tags`** (`object`) - Optional.
    Tags to apply to the NSG.


- **`apiManagement`** (`object`) - Optional.
  NSG definition applied to the API Management subnet.
  - **`diagnosticSettings`** (`array`) - Optional.
    Diagnostic settings to send NSG logs/metrics to Log Analytics, Event Hub, or Storage.
    - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional.
      Destination Event Hub authorization rule resource ID.

    - **`eventHubName`** (`string`) - Optional.
      Destination Event Hub name when sending to Event Hub.

    - **`logAnalyticsDestinationType`** (`string`) - Optional.
      Destination type for Log Analytics (AzureDiagnostics or Dedicated).

    - **`logCategoriesAndGroups`** (`array`) - Optional.
      List of categories and/or category groups to enable.
      - **`category`** (`string`) - Optional.
        Single diagnostic log category to enable.

      - **`categoryGroup`** (`string`) - Optional.
        Category group (e.g., AllMetrics) to enable.

      - **`enabled`** (`bool`) - Optional.
        Whether this category/category group is enabled.


    - **`marketplacePartnerResourceId`** (`string`) - Optional.
      Marketplace partner destination resource ID (if applicable).

    - **`name`** (`string`) - Optional.
      Name of the diagnostic settings resource.

    - **`storageAccountResourceId`** (`string`) - Optional.
      Destination Storage Account resource ID.

    - **`workspaceResourceId`** (`string`) - Optional.
      Destination Log Analytics workspace resource ID.


  - **`enableTelemetry`** (`bool`) - Optional.
    Enable or disable usage telemetry for this module. Default: true.

  - **`flushConnection`** (`bool`) - Optional.
    When true, flows created from NSG connections are re-evaluated when rules are updated. Default: false.

  - **`location`** (`string`) - Optional.
    Azure region for the NSG. Defaults to the resource group location.

  - **`lock`** (`object`) - Optional.
    Management lock configuration for the NSG.
    - **`kind`** (`string`) - Optional.
      Lock type (None, CanNotDelete, or ReadOnly).

    - **`name`** (`string`) - Optional.
      Name of the management lock.

    - **`notes`** (`string`) - Optional.
      Notes describing the reason for the lock.


  - **`name`** (`string`) - Optional.
    Name of the Network Security Group.

  - **`roleAssignments`** (`array`) - Optional.
    Role assignments to apply on the NSG.
    - **`condition`** (`string`) - Optional.
      Advanced condition expression for the assignment.

    - **`conditionVersion`** (`string`) - Optional.
      Condition version. Use 2.0 when condition is provided.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional.
      Delegated managed identity resource ID (for cross-tenant scenarios).

    - **`description`** (`string`) - Optional.
      Description for the role assignment.

    - **`name`** (`string`) - Optional.
      Stable GUID name of the role assignment (omit to auto-generate).

    - **`principalId`** (`string`) - Required.
      Principal (object) ID for the assignment.

    - **`principalType`** (`string`) - Optional.
      Principal type for the assignment.

    - **`roleDefinitionIdOrName`** (`string`) - Required.
      Role to assign (name, GUID, or fully qualified role definition ID).


  - **`securityRules`** (`array`) - Optional.
    Security rules to apply to the NSG. If omitted, only default rules are present.
    - **`name`** (`string`) - Required.
      Name of the security rule.

    - **`properties`** (`object`) - Required.
      Properties that define the behavior of the security rule.
      - **`access`** (`string`) - Required.
        Whether matching traffic is allowed or denied.

      - **`description`** (`string`) - Optional.
        Free-form description for the rule.

      - **`destinationAddressPrefix`** (`string`) - Optional.
        Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

      - **`destinationAddressPrefixes`** (`array`) - Optional.
        Multiple destination address prefixes.

      - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional.
        Destination Application Security Group (ASG) resource IDs.

      - **`destinationPortRange`** (`string`) - Optional.
        Single destination port or port range (e.g., 443, 1000-2000).

      - **`destinationPortRanges`** (`array`) - Optional.
        Multiple destination ports or port ranges.

      - **`direction`** (`string`) - Required.
        Direction of the rule (Inbound or Outbound).

      - **`priority`** (`int`) - Required.
        Priority of the rule (100–4096). Must be unique per rule in the NSG.

      - **`protocol`** (`string`) - Required.
        Network protocol to match.

      - **`sourceAddressPrefix`** (`string`) - Optional.
        Single source address prefix (e.g., Internet, 10.0.0.0/24).

      - **`sourceAddressPrefixes`** (`array`) - Optional.
        Multiple source address prefixes.

      - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional.
        Source Application Security Group (ASG) resource IDs.

      - **`sourcePortRange`** (`string`) - Optional.
        Single source port or port range.

      - **`sourcePortRanges`** (`array`) - Optional.
        Multiple source ports or port ranges.



  - **`tags`** (`object`) - Optional.
    Tags to apply to the NSG.


- **`applicationGateway`** (`object`) - Optional.
  NSG definition applied to the Application Gateway subnet.
  - **`diagnosticSettings`** (`array`) - Optional.
    Diagnostic settings to send NSG logs/metrics to Log Analytics, Event Hub, or Storage.
    - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional.
      Destination Event Hub authorization rule resource ID.

    - **`eventHubName`** (`string`) - Optional.
      Destination Event Hub name when sending to Event Hub.

    - **`logAnalyticsDestinationType`** (`string`) - Optional.
      Destination type for Log Analytics (AzureDiagnostics or Dedicated).

    - **`logCategoriesAndGroups`** (`array`) - Optional.
      List of categories and/or category groups to enable.
      - **`category`** (`string`) - Optional.
        Single diagnostic log category to enable.

      - **`categoryGroup`** (`string`) - Optional.
        Category group (e.g., AllMetrics) to enable.

      - **`enabled`** (`bool`) - Optional.
        Whether this category/category group is enabled.


    - **`marketplacePartnerResourceId`** (`string`) - Optional.
      Marketplace partner destination resource ID (if applicable).

    - **`name`** (`string`) - Optional.
      Name of the diagnostic settings resource.

    - **`storageAccountResourceId`** (`string`) - Optional.
      Destination Storage Account resource ID.

    - **`workspaceResourceId`** (`string`) - Optional.
      Destination Log Analytics workspace resource ID.


  - **`enableTelemetry`** (`bool`) - Optional.
    Enable or disable usage telemetry for this module. Default: true.

  - **`flushConnection`** (`bool`) - Optional.
    When true, flows created from NSG connections are re-evaluated when rules are updated. Default: false.

  - **`location`** (`string`) - Optional.
    Azure region for the NSG. Defaults to the resource group location.

  - **`lock`** (`object`) - Optional.
    Management lock configuration for the NSG.
    - **`kind`** (`string`) - Optional.
      Lock type (None, CanNotDelete, or ReadOnly).

    - **`name`** (`string`) - Optional.
      Name of the management lock.

    - **`notes`** (`string`) - Optional.
      Notes describing the reason for the lock.


  - **`name`** (`string`) - Optional.
    Name of the Network Security Group.

  - **`roleAssignments`** (`array`) - Optional.
    Role assignments to apply on the NSG.
    - **`condition`** (`string`) - Optional.
      Advanced condition expression for the assignment.

    - **`conditionVersion`** (`string`) - Optional.
      Condition version. Use 2.0 when condition is provided.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional.
      Delegated managed identity resource ID (for cross-tenant scenarios).

    - **`description`** (`string`) - Optional.
      Description for the role assignment.

    - **`name`** (`string`) - Optional.
      Stable GUID name of the role assignment (omit to auto-generate).

    - **`principalId`** (`string`) - Required.
      Principal (object) ID for the assignment.

    - **`principalType`** (`string`) - Optional.
      Principal type for the assignment.

    - **`roleDefinitionIdOrName`** (`string`) - Required.
      Role to assign (name, GUID, or fully qualified role definition ID).


  - **`securityRules`** (`array`) - Optional.
    Security rules to apply to the NSG. If omitted, only default rules are present.
    - **`name`** (`string`) - Required.
      Name of the security rule.

    - **`properties`** (`object`) - Required.
      Properties that define the behavior of the security rule.
      - **`access`** (`string`) - Required.
        Whether matching traffic is allowed or denied.

      - **`description`** (`string`) - Optional.
        Free-form description for the rule.

      - **`destinationAddressPrefix`** (`string`) - Optional.
        Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

      - **`destinationAddressPrefixes`** (`array`) - Optional.
        Multiple destination address prefixes.

      - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional.
        Destination Application Security Group (ASG) resource IDs.

      - **`destinationPortRange`** (`string`) - Optional.
        Single destination port or port range (e.g., 443, 1000-2000).

      - **`destinationPortRanges`** (`array`) - Optional.
        Multiple destination ports or port ranges.

      - **`direction`** (`string`) - Required.
        Direction of the rule (Inbound or Outbound).

      - **`priority`** (`int`) - Required.
        Priority of the rule (100–4096). Must be unique per rule in the NSG.

      - **`protocol`** (`string`) - Required.
        Network protocol to match.

      - **`sourceAddressPrefix`** (`string`) - Optional.
        Single source address prefix (e.g., Internet, 10.0.0.0/24).

      - **`sourceAddressPrefixes`** (`array`) - Optional.
        Multiple source address prefixes.

      - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional.
        Source Application Security Group (ASG) resource IDs.

      - **`sourcePortRange`** (`string`) - Optional.
        Single source port or port range.

      - **`sourcePortRanges`** (`array`) - Optional.
        Multiple source ports or port ranges.



  - **`tags`** (`object`) - Optional.
    Tags to apply to the NSG.


- **`bastion`** (`object`) - Optional.
  NSG definition applied to the Bastion subnet.
  - **`diagnosticSettings`** (`array`) - Optional.
    Diagnostic settings to send NSG logs/metrics to Log Analytics, Event Hub, or Storage.
    - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional.
      Destination Event Hub authorization rule resource ID.

    - **`eventHubName`** (`string`) - Optional.
      Destination Event Hub name when sending to Event Hub.

    - **`logAnalyticsDestinationType`** (`string`) - Optional.
      Destination type for Log Analytics (AzureDiagnostics or Dedicated).

    - **`logCategoriesAndGroups`** (`array`) - Optional.
      List of categories and/or category groups to enable.
      - **`category`** (`string`) - Optional.
        Single diagnostic log category to enable.

      - **`categoryGroup`** (`string`) - Optional.
        Category group (e.g., AllMetrics) to enable.

      - **`enabled`** (`bool`) - Optional.
        Whether this category/category group is enabled.


    - **`marketplacePartnerResourceId`** (`string`) - Optional.
      Marketplace partner destination resource ID (if applicable).

    - **`name`** (`string`) - Optional.
      Name of the diagnostic settings resource.

    - **`storageAccountResourceId`** (`string`) - Optional.
      Destination Storage Account resource ID.

    - **`workspaceResourceId`** (`string`) - Optional.
      Destination Log Analytics workspace resource ID.


  - **`enableTelemetry`** (`bool`) - Optional.
    Enable or disable usage telemetry for this module. Default: true.

  - **`flushConnection`** (`bool`) - Optional.
    When true, flows created from NSG connections are re-evaluated when rules are updated. Default: false.

  - **`location`** (`string`) - Optional.
    Azure region for the NSG. Defaults to the resource group location.

  - **`lock`** (`object`) - Optional.
    Management lock configuration for the NSG.
    - **`kind`** (`string`) - Optional.
      Lock type (None, CanNotDelete, or ReadOnly).

    - **`name`** (`string`) - Optional.
      Name of the management lock.

    - **`notes`** (`string`) - Optional.
      Notes describing the reason for the lock.


  - **`name`** (`string`) - Optional.
    Name of the Network Security Group.

  - **`roleAssignments`** (`array`) - Optional.
    Role assignments to apply on the NSG.
    - **`condition`** (`string`) - Optional.
      Advanced condition expression for the assignment.

    - **`conditionVersion`** (`string`) - Optional.
      Condition version. Use 2.0 when condition is provided.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional.
      Delegated managed identity resource ID (for cross-tenant scenarios).

    - **`description`** (`string`) - Optional.
      Description for the role assignment.

    - **`name`** (`string`) - Optional.
      Stable GUID name of the role assignment (omit to auto-generate).

    - **`principalId`** (`string`) - Required.
      Principal (object) ID for the assignment.

    - **`principalType`** (`string`) - Optional.
      Principal type for the assignment.

    - **`roleDefinitionIdOrName`** (`string`) - Required.
      Role to assign (name, GUID, or fully qualified role definition ID).


  - **`securityRules`** (`array`) - Optional.
    Security rules to apply to the NSG. If omitted, only default rules are present.
    - **`name`** (`string`) - Required.
      Name of the security rule.

    - **`properties`** (`object`) - Required.
      Properties that define the behavior of the security rule.
      - **`access`** (`string`) - Required.
        Whether matching traffic is allowed or denied.

      - **`description`** (`string`) - Optional.
        Free-form description for the rule.

      - **`destinationAddressPrefix`** (`string`) - Optional.
        Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

      - **`destinationAddressPrefixes`** (`array`) - Optional.
        Multiple destination address prefixes.

      - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional.
        Destination Application Security Group (ASG) resource IDs.

      - **`destinationPortRange`** (`string`) - Optional.
        Single destination port or port range (e.g., 443, 1000-2000).

      - **`destinationPortRanges`** (`array`) - Optional.
        Multiple destination ports or port ranges.

      - **`direction`** (`string`) - Required.
        Direction of the rule (Inbound or Outbound).

      - **`priority`** (`int`) - Required.
        Priority of the rule (100–4096). Must be unique per rule in the NSG.

      - **`protocol`** (`string`) - Required.
        Network protocol to match.

      - **`sourceAddressPrefix`** (`string`) - Optional.
        Single source address prefix (e.g., Internet, 10.0.0.0/24).

      - **`sourceAddressPrefixes`** (`array`) - Optional.
        Multiple source address prefixes.

      - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional.
        Source Application Security Group (ASG) resource IDs.

      - **`sourcePortRange`** (`string`) - Optional.
        Single source port or port range.

      - **`sourcePortRanges`** (`array`) - Optional.
        Multiple source ports or port ranges.



  - **`tags`** (`object`) - Optional.
    Tags to apply to the NSG.


- **`devopsBuildAgents`** (`object`) - Optional.
  NSG definition applied to the DevOps build agents subnet.
  - **`diagnosticSettings`** (`array`) - Optional.
    Diagnostic settings to send NSG logs/metrics to Log Analytics, Event Hub, or Storage.
    - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional.
      Destination Event Hub authorization rule resource ID.

    - **`eventHubName`** (`string`) - Optional.
      Destination Event Hub name when sending to Event Hub.

    - **`logAnalyticsDestinationType`** (`string`) - Optional.
      Destination type for Log Analytics (AzureDiagnostics or Dedicated).

    - **`logCategoriesAndGroups`** (`array`) - Optional.
      List of categories and/or category groups to enable.
      - **`category`** (`string`) - Optional.
        Single diagnostic log category to enable.

      - **`categoryGroup`** (`string`) - Optional.
        Category group (e.g., AllMetrics) to enable.

      - **`enabled`** (`bool`) - Optional.
        Whether this category/category group is enabled.


    - **`marketplacePartnerResourceId`** (`string`) - Optional.
      Marketplace partner destination resource ID (if applicable).

    - **`name`** (`string`) - Optional.
      Name of the diagnostic settings resource.

    - **`storageAccountResourceId`** (`string`) - Optional.
      Destination Storage Account resource ID.

    - **`workspaceResourceId`** (`string`) - Optional.
      Destination Log Analytics workspace resource ID.


  - **`enableTelemetry`** (`bool`) - Optional.
    Enable or disable usage telemetry for this module. Default: true.

  - **`flushConnection`** (`bool`) - Optional.
    When true, flows created from NSG connections are re-evaluated when rules are updated. Default: false.

  - **`location`** (`string`) - Optional.
    Azure region for the NSG. Defaults to the resource group location.

  - **`lock`** (`object`) - Optional.
    Management lock configuration for the NSG.
    - **`kind`** (`string`) - Optional.
      Lock type (None, CanNotDelete, or ReadOnly).

    - **`name`** (`string`) - Optional.
      Name of the management lock.

    - **`notes`** (`string`) - Optional.
      Notes describing the reason for the lock.


  - **`name`** (`string`) - Optional.
    Name of the Network Security Group.

  - **`roleAssignments`** (`array`) - Optional.
    Role assignments to apply on the NSG.
    - **`condition`** (`string`) - Optional.
      Advanced condition expression for the assignment.

    - **`conditionVersion`** (`string`) - Optional.
      Condition version. Use 2.0 when condition is provided.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional.
      Delegated managed identity resource ID (for cross-tenant scenarios).

    - **`description`** (`string`) - Optional.
      Description for the role assignment.

    - **`name`** (`string`) - Optional.
      Stable GUID name of the role assignment (omit to auto-generate).

    - **`principalId`** (`string`) - Required.
      Principal (object) ID for the assignment.

    - **`principalType`** (`string`) - Optional.
      Principal type for the assignment.

    - **`roleDefinitionIdOrName`** (`string`) - Required.
      Role to assign (name, GUID, or fully qualified role definition ID).


  - **`securityRules`** (`array`) - Optional.
    Security rules to apply to the NSG. If omitted, only default rules are present.
    - **`name`** (`string`) - Required.
      Name of the security rule.

    - **`properties`** (`object`) - Required.
      Properties that define the behavior of the security rule.
      - **`access`** (`string`) - Required.
        Whether matching traffic is allowed or denied.

      - **`description`** (`string`) - Optional.
        Free-form description for the rule.

      - **`destinationAddressPrefix`** (`string`) - Optional.
        Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

      - **`destinationAddressPrefixes`** (`array`) - Optional.
        Multiple destination address prefixes.

      - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional.
        Destination Application Security Group (ASG) resource IDs.

      - **`destinationPortRange`** (`string`) - Optional.
        Single destination port or port range (e.g., 443, 1000-2000).

      - **`destinationPortRanges`** (`array`) - Optional.
        Multiple destination ports or port ranges.

      - **`direction`** (`string`) - Required.
        Direction of the rule (Inbound or Outbound).

      - **`priority`** (`int`) - Required.
        Priority of the rule (100–4096). Must be unique per rule in the NSG.

      - **`protocol`** (`string`) - Required.
        Network protocol to match.

      - **`sourceAddressPrefix`** (`string`) - Optional.
        Single source address prefix (e.g., Internet, 10.0.0.0/24).

      - **`sourceAddressPrefixes`** (`array`) - Optional.
        Multiple source address prefixes.

      - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional.
        Source Application Security Group (ASG) resource IDs.

      - **`sourcePortRange`** (`string`) - Optional.
        Single source port or port range.

      - **`sourcePortRanges`** (`array`) - Optional.
        Multiple source ports or port ranges.



  - **`tags`** (`object`) - Optional.
    Tags to apply to the NSG.


- **`jumpbox`** (`object`) - Optional.
  NSG definition applied to the jumpbox (bastion-accessed) subnet.
  - **`diagnosticSettings`** (`array`) - Optional.
    Diagnostic settings to send NSG logs/metrics to Log Analytics, Event Hub, or Storage.
    - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional.
      Destination Event Hub authorization rule resource ID.

    - **`eventHubName`** (`string`) - Optional.
      Destination Event Hub name when sending to Event Hub.

    - **`logAnalyticsDestinationType`** (`string`) - Optional.
      Destination type for Log Analytics (AzureDiagnostics or Dedicated).

    - **`logCategoriesAndGroups`** (`array`) - Optional.
      List of categories and/or category groups to enable.
      - **`category`** (`string`) - Optional.
        Single diagnostic log category to enable.

      - **`categoryGroup`** (`string`) - Optional.
        Category group (e.g., AllMetrics) to enable.

      - **`enabled`** (`bool`) - Optional.
        Whether this category/category group is enabled.


    - **`marketplacePartnerResourceId`** (`string`) - Optional.
      Marketplace partner destination resource ID (if applicable).

    - **`name`** (`string`) - Optional.
      Name of the diagnostic settings resource.

    - **`storageAccountResourceId`** (`string`) - Optional.
      Destination Storage Account resource ID.

    - **`workspaceResourceId`** (`string`) - Optional.
      Destination Log Analytics workspace resource ID.


  - **`enableTelemetry`** (`bool`) - Optional.
    Enable or disable usage telemetry for this module. Default: true.

  - **`flushConnection`** (`bool`) - Optional.
    When true, flows created from NSG connections are re-evaluated when rules are updated. Default: false.

  - **`location`** (`string`) - Optional.
    Azure region for the NSG. Defaults to the resource group location.

  - **`lock`** (`object`) - Optional.
    Management lock configuration for the NSG.
    - **`kind`** (`string`) - Optional.
      Lock type (None, CanNotDelete, or ReadOnly).

    - **`name`** (`string`) - Optional.
      Name of the management lock.

    - **`notes`** (`string`) - Optional.
      Notes describing the reason for the lock.


  - **`name`** (`string`) - Optional.
    Name of the Network Security Group.

  - **`roleAssignments`** (`array`) - Optional.
    Role assignments to apply on the NSG.
    - **`condition`** (`string`) - Optional.
      Advanced condition expression for the assignment.

    - **`conditionVersion`** (`string`) - Optional.
      Condition version. Use 2.0 when condition is provided.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional.
      Delegated managed identity resource ID (for cross-tenant scenarios).

    - **`description`** (`string`) - Optional.
      Description for the role assignment.

    - **`name`** (`string`) - Optional.
      Stable GUID name of the role assignment (omit to auto-generate).

    - **`principalId`** (`string`) - Required.
      Principal (object) ID for the assignment.

    - **`principalType`** (`string`) - Optional.
      Principal type for the assignment.

    - **`roleDefinitionIdOrName`** (`string`) - Required.
      Role to assign (name, GUID, or fully qualified role definition ID).


  - **`securityRules`** (`array`) - Optional.
    Security rules to apply to the NSG. If omitted, only default rules are present.
    - **`name`** (`string`) - Required.
      Name of the security rule.

    - **`properties`** (`object`) - Required.
      Properties that define the behavior of the security rule.
      - **`access`** (`string`) - Required.
        Whether matching traffic is allowed or denied.

      - **`description`** (`string`) - Optional.
        Free-form description for the rule.

      - **`destinationAddressPrefix`** (`string`) - Optional.
        Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

      - **`destinationAddressPrefixes`** (`array`) - Optional.
        Multiple destination address prefixes.

      - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional.
        Destination Application Security Group (ASG) resource IDs.

      - **`destinationPortRange`** (`string`) - Optional.
        Single destination port or port range (e.g., 443, 1000-2000).

      - **`destinationPortRanges`** (`array`) - Optional.
        Multiple destination ports or port ranges.

      - **`direction`** (`string`) - Required.
        Direction of the rule (Inbound or Outbound).

      - **`priority`** (`int`) - Required.
        Priority of the rule (100–4096). Must be unique per rule in the NSG.

      - **`protocol`** (`string`) - Required.
        Network protocol to match.

      - **`sourceAddressPrefix`** (`string`) - Optional.
        Single source address prefix (e.g., Internet, 10.0.0.0/24).

      - **`sourceAddressPrefixes`** (`array`) - Optional.
        Multiple source address prefixes.

      - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional.
        Source Application Security Group (ASG) resource IDs.

      - **`sourcePortRange`** (`string`) - Optional.
        Single source port or port range.

      - **`sourcePortRanges`** (`array`) - Optional.
        Multiple source ports or port ranges.



  - **`tags`** (`object`) - Optional.
    Tags to apply to the NSG.


- **`pe`** (`object`) - Optional.
  NSG definition applied to the private endpoints (PE) subnet.
  - **`diagnosticSettings`** (`array`) - Optional.
    Diagnostic settings to send NSG logs/metrics to Log Analytics, Event Hub, or Storage.
    - **`eventHubAuthorizationRuleResourceId`** (`string`) - Optional.
      Destination Event Hub authorization rule resource ID.

    - **`eventHubName`** (`string`) - Optional.
      Destination Event Hub name when sending to Event Hub.

    - **`logAnalyticsDestinationType`** (`string`) - Optional.
      Destination type for Log Analytics (AzureDiagnostics or Dedicated).

    - **`logCategoriesAndGroups`** (`array`) - Optional.
      List of categories and/or category groups to enable.
      - **`category`** (`string`) - Optional.
        Single diagnostic log category to enable.

      - **`categoryGroup`** (`string`) - Optional.
        Category group (e.g., AllMetrics) to enable.

      - **`enabled`** (`bool`) - Optional.
        Whether this category/category group is enabled.


    - **`marketplacePartnerResourceId`** (`string`) - Optional.
      Marketplace partner destination resource ID (if applicable).

    - **`name`** (`string`) - Optional.
      Name of the diagnostic settings resource.

    - **`storageAccountResourceId`** (`string`) - Optional.
      Destination Storage Account resource ID.

    - **`workspaceResourceId`** (`string`) - Optional.
      Destination Log Analytics workspace resource ID.


  - **`enableTelemetry`** (`bool`) - Optional.
    Enable or disable usage telemetry for this module. Default: true.

  - **`flushConnection`** (`bool`) - Optional.
    When true, flows created from NSG connections are re-evaluated when rules are updated. Default: false.

  - **`location`** (`string`) - Optional.
    Azure region for the NSG. Defaults to the resource group location.

  - **`lock`** (`object`) - Optional.
    Management lock configuration for the NSG.
    - **`kind`** (`string`) - Optional.
      Lock type (None, CanNotDelete, or ReadOnly).

    - **`name`** (`string`) - Optional.
      Name of the management lock.

    - **`notes`** (`string`) - Optional.
      Notes describing the reason for the lock.


  - **`name`** (`string`) - Optional.
    Name of the Network Security Group.

  - **`roleAssignments`** (`array`) - Optional.
    Role assignments to apply on the NSG.
    - **`condition`** (`string`) - Optional.
      Advanced condition expression for the assignment.

    - **`conditionVersion`** (`string`) - Optional.
      Condition version. Use 2.0 when condition is provided.

    - **`delegatedManagedIdentityResourceId`** (`string`) - Optional.
      Delegated managed identity resource ID (for cross-tenant scenarios).

    - **`description`** (`string`) - Optional.
      Description for the role assignment.

    - **`name`** (`string`) - Optional.
      Stable GUID name of the role assignment (omit to auto-generate).

    - **`principalId`** (`string`) - Required.
      Principal (object) ID for the assignment.

    - **`principalType`** (`string`) - Optional.
      Principal type for the assignment.

    - **`roleDefinitionIdOrName`** (`string`) - Required.
      Role to assign (name, GUID, or fully qualified role definition ID).


  - **`securityRules`** (`array`) - Optional.
    Security rules to apply to the NSG. If omitted, only default rules are present.
    - **`name`** (`string`) - Required.
      Name of the security rule.

    - **`properties`** (`object`) - Required.
      Properties that define the behavior of the security rule.
      - **`access`** (`string`) - Required.
        Whether matching traffic is allowed or denied.

      - **`description`** (`string`) - Optional.
        Free-form description for the rule.

      - **`destinationAddressPrefix`** (`string`) - Optional.
        Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).

      - **`destinationAddressPrefixes`** (`array`) - Optional.
        Multiple destination address prefixes.

      - **`destinationApplicationSecurityGroupResourceIds`** (`array`) - Optional.
        Destination Application Security Group (ASG) resource IDs.

      - **`destinationPortRange`** (`string`) - Optional.
        Single destination port or port range (e.g., 443, 1000-2000).

      - **`destinationPortRanges`** (`array`) - Optional.
        Multiple destination ports or port ranges.

      - **`direction`** (`string`) - Required.
        Direction of the rule (Inbound or Outbound).

      - **`priority`** (`int`) - Required.
        Priority of the rule (100–4096). Must be unique per rule in the NSG.

      - **`protocol`** (`string`) - Required.
        Network protocol to match.

      - **`sourceAddressPrefix`** (`string`) - Optional.
        Single source address prefix (e.g., Internet, 10.0.0.0/24).

      - **`sourceAddressPrefixes`** (`array`) - Optional.
        Multiple source address prefixes.

      - **`sourceApplicationSecurityGroupResourceIds`** (`array`) - Optional.
        Source Application Security Group (ASG) resource IDs.

      - **`sourcePortRange`** (`string`) - Optional.
        Single source port or port range.

      - **`sourcePortRanges`** (`array`) - Optional.
        Multiple source ports or port ranges.



  - **`tags`** (`object`) - Optional.
    Tags to apply to the NSG.


### `openAiPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `openAiPrivateDnsZoneDefinition` | `object` | Optional | OpenAI Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`acrZoneId`** (`string`) - Optional.
  Existing Private DNS Zone resource ID for Azure Container Registry.

- **`aiServicesZoneId`** (`string`) - Optional.
  Existing Private DNS Zone resource ID for AI Services.

- **`allowInternetResolutionFallback`** (`bool`) - Optional.
  Allow fallback to internet DNS resolution when Private DNS is unavailable.

- **`apimZoneId`** (`string`) - Optional.
  Existing Private DNS Zone resource ID for Azure API Management.

- **`appConfigZoneId`** (`string`) - Optional.
  Existing Private DNS Zone resource ID for App Configuration.

- **`appInsightsZoneId`** (`string`) - Optional.
  Existing Private DNS Zone resource ID for Application Insights.

- **`blobZoneId`** (`string`) - Optional.
  Existing Private DNS Zone resource ID for Blob Storage.

- **`cognitiveservicesZoneId`** (`string`) - Optional.
  Existing Private DNS Zone resource ID for Cognitive Services.

- **`containerAppsZoneId`** (`string`) - Optional.
  Existing Private DNS Zone resource ID for Container Apps.

- **`cosmosSqlZoneId`** (`string`) - Optional.
  Existing Private DNS Zone resource ID for Cosmos DB (SQL API).

- **`createNetworkLinks`** (`bool`) - Optional.
  Create VNet link to associate Spoke with the zones (can be empty).

- **`keyVaultZoneId`** (`string`) - Optional.
  Existing Private DNS Zone resource ID for Key Vault.

- **`openaiZoneId`** (`string`) - Optional.
  Existing Private DNS Zone resource ID for Azure OpenAI.

- **`searchZoneId`** (`string`) - Optional.
  Existing Private DNS Zone resource ID for Azure Cognitive Search.

- **`tags`** (`object`) - Optional.
  Tags to apply to the Private DNS Zones.

### `resourceIds`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `resourceIds` | `object` | Optional | Existing resource IDs to reuse (can be empty). |

**Note:** AI Foundry dependency resources (AI Search, Storage, Cosmos DB) are treated as separate resources from the GenAI App backing services.
To have AI Foundry reuse existing dependency resources, provide the `aiFoundry*` resource IDs below.
Otherwise, leave them empty and the AI Foundry component will create its own dependencies when `aiFoundryDefinition.includeAssociatedResources = true`.

**Properties:**

- **`acaEnvironmentNsgResourceId`** (`string`) - Optional.
  Existing NSG resource ID to reuse for the Azure Container Apps environment subnet.

- **`agentNsgResourceId`** (`string`) - Optional.
  Existing NSG resource ID to reuse for the agent (workload) subnet.

- **`apiManagementNsgResourceId`** (`string`) - Optional.
  Existing NSG resource ID to reuse for the API Management subnet.

- **`apimServiceResourceId`** (`string`) - Optional.
  Existing API Management service resource ID to reuse.

- **`appConfigResourceId`** (`string`) - Optional.
  Existing App Configuration store resource ID to reuse.

- **`appGatewayPublicIpResourceId`** (`string`) - Optional.
  Existing Public IP resource ID to reuse for the Application Gateway.

- **`appInsightsResourceId`** (`string`) - Optional.
  Existing Application Insights resource ID to reuse.

- **`applicationGatewayNsgResourceId`** (`string`) - Optional.
  Existing NSG resource ID to reuse for the Application Gateway subnet.

- **`applicationGatewayResourceId`** (`string`) - Optional.
  Existing Application Gateway resource ID to reuse.

- **`bastionHostResourceId`** (`string`) - Optional.
  Existing Azure Bastion resource ID to reuse; leave empty to skip.

- **`bastionNsgResourceId`** (`string`) - Optional.
  Existing NSG resource ID to reuse for the Bastion host subnet.

- **`containerEnvResourceId`** (`string`) - Optional.
  Existing Container Apps Environment resource ID to reuse.

- **`containerRegistryResourceId`** (`string`) - Optional.
  Existing Azure Container Registry resource ID to reuse.

- **`dbAccountResourceId`** (`string`) - Optional.
  Existing Cosmos DB account resource ID to reuse.

- **`devopsBuildAgentsNsgResourceId`** (`string`) - Optional.
  Existing NSG resource ID to reuse for the DevOps build agents subnet.

- **`firewallPolicyResourceId`** (`string`) - Optional.
  Existing Azure Firewall Policy resource ID to reuse.

- **`firewallPublicIpResourceId`** (`string`) - Optional.
  Existing Public IP resource ID to reuse for the Azure Firewall.

- **`firewallResourceId`** (`string`) - Optional.
  Existing Azure Firewall resource ID to reuse.

- **`groundingServiceResourceId`** (`string`) - Optional.
  Existing Grounding service resource ID to reuse.

- **`jumpboxNsgResourceId`** (`string`) - Optional.
  Existing NSG resource ID to reuse for the jumpbox (bastion-accessed) subnet.

- **`keyVaultResourceId`** (`string`) - Optional.
  Existing Key Vault resource ID to reuse.

- **`logAnalyticsWorkspaceResourceId`** (`string`) - Optional.
  Existing Log Analytics Workspace resource ID to reuse.

- **`peNsgResourceId`** (`string`) - Optional.
  Existing NSG resource ID to reuse for the private endpoints (PE) subnet.

- **`aiFoundrySearchServiceResourceId`** (`string`) - Optional.
  Existing Azure AI Search service resource ID to reuse for AI Foundry dependencies.

- **`aiFoundryStorageAccountResourceId`** (`string`) - Optional.
  Existing Storage Account resource ID to reuse for AI Foundry dependencies.

- **`aiFoundryCosmosDBAccountResourceId`** (`string`) - Optional.
  Existing Cosmos DB account resource ID to reuse for AI Foundry dependencies.

- **`aiFoundryKeyVaultResourceId`** (`string`) - Optional.
  Existing Key Vault resource ID to reuse for AI Foundry dependencies. If empty and `aiFoundryDefinition.includeAssociatedResources=true`, the AI Foundry component creates its own Key Vault named `kv-<aiAccountName>` (truncated to meet Key Vault naming limits).

- **`searchServiceResourceId`** (`string`) - Optional.
  Existing Azure AI Search service resource ID to reuse.

- **`storageAccountResourceId`** (`string`) - Optional.
  Existing Storage Account resource ID to reuse.

- **`virtualNetworkResourceId`** (`string`) - Optional.
  Existing VNet resource ID to reuse; leave empty to create a new VNet.

### `resourceToken`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `resourceToken` | `string` | Optional | Deterministic token for resource names; auto-generated if not provided. |

### `searchPrivateDnsZoneDefinition`

| Parameter | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `searchPrivateDnsZoneDefinition` | `object` | Optional | Azure AI Search Private DNS Zone configuration. |

**Properties:**

- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


- **`a`** (`array`) - Optional.
  A list of DNS zone records to create.
  - **`ipv4Addresses`** (`array`) - Required.
    List of IPv4 addresses.

  - **`name`** (`string`) - Required.
    Name of the A record.

  - **`tags`** (`object`) - Optional.
    Tags for the A record.

  - **`ttl`** (`int`) - Optional.
    Time-to-live for the record.


- **`enableTelemetry`** (`bool`) - Optional.
  Enable/Disable usage telemetry for the module.

- **`location`** (`string`) - Optional.
  Location for the resource. Defaults to "global".

- **`lock`** (`object`) - Optional.
  Lock configuration for the Private DNS Zone.
  - **`kind`** (`string`) - Optional.
    Lock type.

  - **`name`** (`string`) - Optional.
    Lock name.

  - **`notes`** (`string`) - Optional.
    Lock notes.


- **`name`** (`string`) - Required.
  The name of the Private DNS Zone.

- **`roleAssignments`** (`array`) - Optional.
  Role assignments for the Private DNS Zone.
  - **`description`** (`string`) - Optional.
    Description of the role assignment.

  - **`name`** (`string`) - Optional.
    Name for the role assignment.

  - **`principalId`** (`string`) - Required.
    Principal ID to assign the role to.

  - **`principalType`** (`string`) - Optional.
    Principal type.

  - **`roleDefinitionIdOrName`** (`string`) - Required.
    Role definition ID or name.


- **`tags`** (`object`) - Optional.
  Tags for the Private DNS Zone.

- **`virtualNetworkLinks`** (`array`) - Optional.
  Virtual network links to create for the Private DNS Zone.
  - **`name`** (`string`) - Required.
    The name of the virtual network link.

  - **`registrationEnabled`** (`bool`) - Optional.
    Whether to enable auto-registration of virtual machine records in the zone.

  - **`tags`** (`object`) - Optional.
    Tags for the virtual network link.

  - **`virtualNetworkResourceId`** (`string`) - Required.
    Resource ID of the virtual network to link.


