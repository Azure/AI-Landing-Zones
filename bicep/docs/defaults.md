# AI/ML Landing Zone — Parameter Defaults  

---

## Table of Contents

- [Global & Shared](#global--shared)
- [Security](#security)
- [Network Security Groups](#network-security-groups)
- [Virtual Network](#virtual-network)
- [Private DNS Zones](#private-dns-zones)
- [Public IPs](#public-ips)
- [Private Endpoints](#private-endpoints)
- [Observability](#observability)
- [Container Platform](#container-platform)
- [Storage](#storage)
- [Databases & Config](#databases--config)
- [API Management](#api-management)
- [AI Foundry](#ai-foundry)
- [Gateways & Firewall](#gateways--firewall)
- [Virtual Machines](#virtual-machines)

---

## Global & Shared

Global configuration parameters that affect the overall deployment behavior and resource organization.

| parameter | default | description |
|-----------|---------|-------------|
| flagPlatformLandingZone | false | Flag to indicate if deploying in platform landing zone mode (uses existing shared resources) |
| resourceIds | {} | Existing resource IDs to reuse (can be empty for new deployments) |
| enableTelemetry | true | Enable/Disable usage telemetry collection for Microsoft to improve the template |
| tags | {} | Common tags to apply to all resources in the deployment |

---

## Security

Security-related deployment options.

| parameter | default | description |
|-----------|---------|-------------|
| enableDefenderForAI | false | Enables Microsoft Defender for AI by configuring Defender for Cloud pricing at **subscription scope** (`Microsoft.Security/pricings`). Requires subscription-level permissions; keep `false` by default to avoid deployment failures in restricted environments. |

---

## Network Security Groups

Network Security Groups (NSGs) provide network-level security by controlling traffic flow to and from subnets and network interfaces.

### Default NSG Names

| parameter | default | description |
|-----------|---------|-------------|
| agentNsg.name | nsg-agent-${baseName} | NSG for Container Apps agent subnet |
| privateEndpointsNsg.name | nsg-pe-${baseName} | NSG for private endpoints subnet |
| appGatewayNsg.name | nsg-appgw-${baseName} | NSG for Application Gateway subnet |
| apimNsg.name | nsg-apim-${baseName} | NSG for API Management subnet |
| acaEnvNsg.name | nsg-aca-env-${baseName} | NSG for Container Apps environment subnet |
| jumpboxNsg.name | nsg-jumpbox-${baseName} | NSG for jumpbox/bastion host subnet |
| devopsAgentsNsg.name | nsg-devops-agents-${baseName} | NSG for DevOps build agents subnet |
| bastionNsg.name | nsg-bastion-${baseName} | NSG for Azure Bastion subnet |

### App Gateway NSG Default Rules

Pre-configured security rules required for Application Gateway functionality.

| parameter | default | description |
|-----------|---------|-------------|
| securityRules[0].name | Allow-GatewayManager-Inbound | Required rule for Azure Gateway Manager |
| securityRules[0].properties.protocol | Tcp | TCP protocol for management traffic |
| securityRules[0].properties.sourceAddressPrefix | GatewayManager | Azure service tag for Gateway Manager |
| securityRules[0].properties.destinationPortRange | 65200-65535 | Port range for management traffic |
| securityRules[0].properties.access | Allow | Allow inbound management traffic |
| securityRules[1].name | Allow-Internet-HTTP-Inbound | Allow HTTP traffic from internet |
| securityRules[1].properties.protocol | Tcp | TCP protocol for HTTP |
| securityRules[1].properties.sourceAddressPrefix | Internet | Allow traffic from internet |
| securityRules[1].properties.destinationPortRange | 80 | HTTP port |
| securityRules[1].properties.access | Allow | Allow inbound HTTP traffic |
| securityRules[2].name | Allow-Internet-HTTPS-Inbound | Allow HTTPS traffic from internet |
| securityRules[2].properties.protocol | Tcp | TCP protocol for HTTPS |
| securityRules[2].properties.sourceAddressPrefix | Internet | Allow traffic from internet |
| securityRules[2].properties.destinationPortRange | 443 | HTTPS port |
| securityRules[2].properties.access | Allow | Allow inbound HTTPS traffic |

---

## Virtual Network

Virtual network configuration defining the network topology and subnets for the AI/ML landing zone.

### Network Configuration

| parameter | default | description |
|-----------|---------|-------------|
| vNetDefinition.name | vnet-${baseName} | Name of the virtual network |
| vNetDefinition.addressPrefixes | ['192.168.0.0/22'] | CIDR address space for the virtual network (1024 IP addresses) |

### Subnet Configuration

| parameter | default | description |
|-----------|---------|-------------|
| vNetDefinition.subnets[0].name | agent-subnet | Container Apps environment subnet for AI agents |
| vNetDefinition.subnets[0].properties.addressPrefix | 192.168.0.0/27 | CIDR range for agent subnet (32 IPs) |
| vNetDefinition.subnets[0].properties.delegations[0].serviceName | Microsoft.App/environments | Delegation to Container Apps service |
| vNetDefinition.subnets[0].properties.serviceEndpoints | ['Microsoft.CognitiveServices'] | Service endpoints for Cognitive Services |
| vNetDefinition.subnets[1].name | pe-subnet | Private endpoints subnet for secure service connections |
| vNetDefinition.subnets[1].properties.addressPrefix | 192.168.0.32/27 | CIDR range for private endpoints subnet (32 IPs) |
| vNetDefinition.subnets[1].properties.serviceEndpoints | ['Microsoft.AzureCosmosDB'] | Service endpoints for Cosmos DB |
| vNetDefinition.subnets[1].properties.privateEndpointNetworkPolicies | Disabled | Allow private endpoints in this subnet |
| vNetDefinition.subnets[2].name | AzureBastionSubnet | Azure Bastion subnet (required name) |
| vNetDefinition.subnets[2].properties.addressPrefix | 192.168.0.64/26 | CIDR range for Bastion subnet (64 IPs minimum) |
| vNetDefinition.subnets[3].name | AzureFirewallSubnet | Azure Firewall subnet (required name) |
| vNetDefinition.subnets[3].properties.addressPrefix | 192.168.0.128/26 | CIDR range for Firewall subnet (64 IPs minimum) |
| vNetDefinition.subnets[4].name | appgw-subnet | Application Gateway subnet |
| vNetDefinition.subnets[4].properties.addressPrefix | 192.168.0.192/27 | CIDR range for Application Gateway subnet (32 IPs) |
| vNetDefinition.subnets[5].name | apim-subnet | API Management subnet |
| vNetDefinition.subnets[5].properties.addressPrefix | 192.168.0.224/27 | CIDR range for API Management subnet (32 IPs) |
| vNetDefinition.subnets[6].name | jumpbox-subnet | Jump box/bastion host subnet |
| vNetDefinition.subnets[6].properties.addressPrefix | 192.168.1.0/28 | CIDR range for jumpbox subnet (16 IPs) |
| vNetDefinition.subnets[7].name | aca-env-subnet | Container Apps environment subnet for workloads |
| vNetDefinition.subnets[7].properties.addressPrefix | 192.168.2.0/23 | CIDR range for Container Apps subnet (512 IPs) |
| vNetDefinition.subnets[7].properties.delegations[0].serviceName | Microsoft.App/environments | Delegation to Container Apps service |
| vNetDefinition.subnets[7].properties.serviceEndpoints | ['Microsoft.AzureCosmosDB'] | Service endpoints for Cosmos DB |
| vNetDefinition.subnets[8].name | devops-agents-subnet | DevOps build agents subnet |
| vNetDefinition.subnets[8].properties.addressPrefix | 192.168.1.32/27 | CIDR range for DevOps agents subnet (32 IPs) |

---

## Private DNS Zones

Private DNS Zones enable secure, private resolution of Azure service endpoints within the virtual network, preventing traffic from traversing the public internet.

### General Configuration

| parameter | default | description |
|-----------|---------|-------------|
| privateDnsZonesDefinition.allowInternetResolutionFallback | false | Allow fallback to internet DNS resolution when Private DNS is unavailable |
| privateDnsZonesDefinition.createNetworkLinks | true | Create VNet link to associate Spoke with the zones (can be empty) |

### Service-Specific DNS Zones

| parameter | default | description |
|-----------|---------|-------------|
| apimPrivateDnsZoneDefinition.name | privatelink.azure-api.net | Private DNS zone name for API Management service endpoints |
| apimPrivateDnsZoneDefinition.location | global | Location for the API Management Private DNS Zone (global for multi-region) |
| cognitiveServicesPrivateDnsZoneDefinition.name | privatelink.cognitiveservices.azure.com | Private DNS zone name for Cognitive Services endpoints |
| cognitiveServicesPrivateDnsZoneDefinition.location | global | Location for the Cognitive Services Private DNS Zone (global for multi-region) |
| openAiPrivateDnsZoneDefinition.name | privatelink.openai.azure.com | Private DNS zone name for Azure OpenAI service endpoints |
| openAiPrivateDnsZoneDefinition.location | global | Location for the OpenAI Private DNS Zone (global for multi-region) |
| aiServicesPrivateDnsZoneDefinition.name | privatelink.services.ai.azure.com | Private DNS zone name for AI Services endpoints |
| aiServicesPrivateDnsZoneDefinition.location | global | Location for the AI Services Private DNS Zone (global for multi-region) |
| searchPrivateDnsZoneDefinition.name | privatelink.search.windows.net | Private DNS zone name for Azure Cognitive Search endpoints |
| searchPrivateDnsZoneDefinition.location | global | Location for the Search Private DNS Zone (global for multi-region) |
| cosmosPrivateDnsZoneDefinition.name | privatelink.documents.azure.com | Private DNS zone name for Cosmos DB SQL API endpoints |
| cosmosPrivateDnsZoneDefinition.location | global | Location for the Cosmos DB Private DNS Zone (global for multi-region) |
| blobPrivateDnsZoneDefinition.name | privatelink.blob.${environment().suffixes.storage} | Private DNS zone name for Blob Storage endpoints |
| blobPrivateDnsZoneDefinition.location | global | Location for the Blob Storage Private DNS Zone (global for multi-region) |
| keyVaultPrivateDnsZoneDefinition.name | privatelink.vaultcore.azure.net | Private DNS zone name for Key Vault endpoints |
| keyVaultPrivateDnsZoneDefinition.location | global | Location for the Key Vault Private DNS Zone (global for multi-region) |
| appConfigPrivateDnsZoneDefinition.name | privatelink.azconfig.io | Private DNS zone name for App Configuration endpoints |
| appConfigPrivateDnsZoneDefinition.location | global | Location for the App Configuration Private DNS Zone (global for multi-region) |
| containerAppsPrivateDnsZoneDefinition.name | privatelink.${location}.azurecontainerapps.io | Private DNS zone name for Container Apps endpoints (region-specific) |
| containerAppsPrivateDnsZoneDefinition.location | global | Location for the Container Apps Private DNS Zone (global for multi-region) |
| acrPrivateDnsZoneDefinition.name | privatelink.azurecr.io | Private DNS zone name for Azure Container Registry endpoints |
| acrPrivateDnsZoneDefinition.location | global | Location for the ACR Private DNS Zone (global for multi-region) |
| appInsightsPrivateDnsZoneDefinition.name | privatelink.applicationinsights.azure.com | Private DNS zone name for Application Insights endpoints |
| appInsightsPrivateDnsZoneDefinition.location | global | Location for the Application Insights Private DNS Zone (global for multi-region) |

---

## Public IPs

Public IP addresses for internet-facing services like Application Gateway and Azure Firewall.

### Application Gateway Public IP

| parameter | default | description |
|-----------|---------|-------------|
| appGatewayPublicIp.name | pip-agw-${baseName} | Name of the Application Gateway public IP address |
| appGatewayPublicIp.skuName | Standard | Public IP SKU for Application Gateway (Standard required for zone redundancy) |
| appGatewayPublicIp.skuTier | Regional | Regional tier for consistent performance within the region |
| appGatewayPublicIp.publicIPAllocationMethod | Static | Static IP allocation for consistent endpoint addressing |
| appGatewayPublicIp.publicIPAddressVersion | IPv4 | IP version (IPv4 supported by Application Gateway) |
| appGatewayPublicIp.zones | [1,2,3] | Availability zones for high availability (all three zones) |

### Azure Firewall Public IP

| parameter | default | description |
|-----------|---------|-------------|
| firewallPublicIp.name | pip-fw-${baseName} | Name of the Azure Firewall public IP address |
| firewallPublicIp.skuName | Standard | Public IP SKU for Azure Firewall (Standard required for zone redundancy) |
| firewallPublicIp.skuTier | Regional | Regional tier for consistent performance within the region |
| firewallPublicIp.publicIPAllocationMethod | Static | Static IP allocation for consistent firewall endpoint |
| firewallPublicIp.publicIPAddressVersion | IPv4 | IP version (IPv4 supported by Azure Firewall) |
| firewallPublicIp.zones | [1,2,3] | Availability zones for high availability (all three zones) |

---

## Private Endpoints

Private endpoints provide secure, private connectivity to Azure PaaS services from within the virtual network, eliminating exposure to the public internet.

### App Configuration Private Endpoint

| parameter | default | description |
|-----------|---------|-------------|
| appConfigPrivateEndpointDefinition.name | pe-appcs-${baseName} | Name of the App Configuration private endpoint |
| appConfigPrivateEndpointDefinition.groupIds | ['configurationStores'] | Service connection group for App Configuration stores |

### API Management Private Endpoint

> Note: By default this template deploys API Management in **Internal VNet** mode (see the **API Management** section below).
> Private Endpoints for API Management are **not supported** when `virtualNetworkType` is `Internal`.
> Therefore, this template only deploys the APIM Private Endpoint when you explicitly configure `apimDefinition.virtualNetworkType = 'None'`
> (and the APIM SKU supports Private Endpoints: `StandardV2`, `Premium`, or `PremiumV2`).

| parameter | default | description |
|-----------|---------|-------------|
| apimPrivateEndpointDefinition.name | pe-apim-${baseName} | Name of the API Management private endpoint |
| apimPrivateEndpointDefinition.groupIds | ['Gateway'] | Service connection group for API Management gateway |

### Container Apps Environment Private Endpoint

| parameter | default | description |
|-----------|---------|-------------|
| containerAppEnvPrivateEndpointDefinition.name | pe-cae-${baseName} | Name of the Container Apps Environment private endpoint |
| containerAppEnvPrivateEndpointDefinition.groupIds | ['managedEnvironments'] | Service connection group for Container Apps environments |

### Azure Container Registry Private Endpoint

| parameter | default | description |
|-----------|---------|-------------|
| acrPrivateEndpointDefinition.name | pe-acr-${baseName} | Name of the Azure Container Registry private endpoint |
| acrPrivateEndpointDefinition.groupIds | ['registry'] | Service connection group for container registry |

### Storage Account (Blob) Private Endpoint

| parameter | default | description |
|-----------|---------|-------------|
| storageBlobPrivateEndpointDefinition.name | pe-st-${baseName} | Name of the Storage Account Blob private endpoint |
| storageBlobPrivateEndpointDefinition.groupIds | ['blob'] | Service connection group for blob storage |

### Cosmos DB (SQL) Private Endpoint

| parameter | default | description |
|-----------|---------|-------------|
| cosmosPrivateEndpointDefinition.name | pe-cos-${baseName} | Name of the Cosmos DB private endpoint |
| cosmosPrivateEndpointDefinition.groupIds | ['Sql'] | Service connection group for Cosmos DB SQL API |

### Azure AI Search Private Endpoint

| parameter | default | description |
|-----------|---------|-------------|
| searchPrivateEndpointDefinition.name | pe-srch-${baseName} | Name of the Azure AI Search private endpoint |
| searchPrivateEndpointDefinition.groupIds | ['searchService'] | Service connection group for search service |

### Key Vault Private Endpoint

| parameter | default | description |
|-----------|---------|-------------|
| keyVaultPrivateEndpointDefinition.name | pe-kv-${baseName} | Name of the Key Vault private endpoint |
| keyVaultPrivateEndpointDefinition.groupIds | ['vault'] | Service connection group for Key Vault |

---

## Observability

Monitoring and logging services for comprehensive visibility into AI/ML workloads and infrastructure health.

### Log Analytics Workspace

| parameter | default | description |
|-----------|---------|-------------|
| logAnalyticsDefinition.name | log-${baseName} | Name of the Log Analytics workspace for centralized logging |
| logAnalyticsDefinition.dataRetention | 30 | Data retention period in days for log data |

### Application Insights

| parameter | default | description |
|-----------|---------|-------------|
| appInsightsDefinition.name | appi-${baseName} | Name of the Application Insights component for application telemetry |
| appInsightsDefinition.disableIpMasking | true | Disable IP masking to capture full client IP addresses for debugging |

---

## Container Platform

Container orchestration and registry services for deploying and managing containerized AI/ML workloads.

### Container Apps Environment

| parameter | default | description |
|-----------|---------|-------------|
| containerAppEnvDefinition.name | cae-${baseName} | Name of the Container Apps environment |
| containerAppEnvDefinition.workloadProfiles[0].workloadProfileType | D4 | Default workload profile type (4 vCPU, 16GB RAM) |
| containerAppEnvDefinition.workloadProfiles[0].name | default | Name of the default workload profile |
| containerAppEnvDefinition.workloadProfiles[0].minimumCount | 1 | Minimum number of instances for scaling |
| containerAppEnvDefinition.workloadProfiles[0].maximumCount | 3 | Maximum number of instances for scaling |
| containerAppEnvDefinition.internal | false | Environment visibility (false = external load balancer) |
| containerAppEnvDefinition.publicNetworkAccess | Disabled | Disable public network access for security |
| containerAppEnvDefinition.zoneRedundant | true | Enable zone redundancy for high availability |

### Container Registry

| parameter | default | description |
|-----------|---------|-------------|
| containerRegistryDefinition.name | cr${baseName} | Name of the Azure Container Registry |
| containerRegistryDefinition.publicNetworkAccess | Disabled | Disable public network access for security |
| containerRegistryDefinition.acrSku | Premium | Premium SKU for private endpoints and geo-replication support |

### Container Apps

| parameter | default | description |
|-----------|---------|-------------|
| containerAppsList | [] | List of container apps to deploy (empty by default) |

---

## Storage

Secure storage services for AI/ML datasets, models, and application data with private network access.

| parameter | default | description |
|-----------|---------|-------------|
| storageAccountDefinition.name | st${baseName} | Name of the storage account for AI/ML data and artifacts |
| storageAccountDefinition.kind | StorageV2 | General-purpose v2 storage account with full feature support |
| storageAccountDefinition.skuName | Standard_LRS | Locally redundant storage for cost-effective data storage |
| storageAccountDefinition.publicNetworkAccess | Disabled | Disable public network access, require private endpoints |

---

## Databases & Config

Database and configuration services for AI/ML applications including vector search, document storage, secrets management, and application configuration.

| parameter | default | description |
|-----------|---------|-------------|
| appConfigurationDefinition.name | appcs-${baseName} | Name of the App Configuration service for centralized application settings |
| cosmosDbDefinition.name | cosmos-${baseName} | Name of the Cosmos DB account for document and vector storage |
| keyVaultDefinition.name | kv-${baseName} | Name of the Key Vault for secure secrets and certificate management |
| aiSearchDefinition.name | search-${baseName} | Name of the Azure AI Search service for vector and semantic search |

---

## API Management

API gateway service for managing, securing, and monitoring AI/ML service endpoints and APIs.

| parameter | default | description |
|-----------|---------|-------------|
| apimDefinition.name | apim-${baseName} | Name of the API Management service instance |
| apimDefinition.publisherEmail | admin@contoso.com | Publisher contact email (change to your organization email) |
| apimDefinition.publisherName | Contoso | Publisher organization name (change to your organization) |
| apimDefinition.sku | PremiumV2 | Default tier for APIM deployed in Internal VNet mode |
| apimDefinition.skuCapacity | 3 | Number of gateway units for traffic handling capacity |
| apimDefinition.virtualNetworkType | Internal | Virtual network integration type (Internal = private IP in the APIM subnet) |
| apimDefinition.minApiVersion | 2022-08-01 | Minimum API version accepted for requests |

---

## AI Foundry

AI Foundry provides a comprehensive platform for AI/ML development, deployment, and management with pre-configured models and projects.

### AI Foundry Configuration

| parameter | default | description |
|-----------|---------|-------------|
| aiFoundryDefinition.aiFoundryConfiguration.accountName | ai${baseName} | Name of the AI Foundry account (Azure AI Services multi-service account) |
| aiFoundryDefinition.aiFoundryConfiguration.disableLocalAuth | false | Whether to disable local authentication (enable for Azure AD only) |
| aiFoundryDefinition.includeAssociatedResources | true | Whether the Foundry component creates the associated dependency resources (Search/Storage/Cosmos) and their PE/DNS |
| aiFoundryDefinition.aiFoundryConfiguration.createCapabilityHosts | true | Whether the Foundry component creates Capability Hosts (Agent Service). Requires includeAssociatedResources = true |
| aiFoundryDefinition.aiFoundryConfiguration.project.name | aifoundry-default-project | Internal name of the default AI Foundry project |
| aiFoundryDefinition.aiFoundryConfiguration.project.displayName | Default AI Foundry Project. | Display name shown in the AI Foundry portal |
| aiFoundryDefinition.aiFoundryConfiguration.project.description | This is the default project for AI Foundry. | Description of the project's purpose and scope |

### Default Model Deployments

Pre-configured AI model deployments for immediate use in AI applications.

#### GPT-4o Model Deployment

| parameter | default | description |
|-----------|---------|-------------|
| aiFoundryDefinition.aiModelDeployments[0].model.format | OpenAI | Model format compatibility (OpenAI API format) |
| aiFoundryDefinition.aiModelDeployments[0].model.name | gpt-4o | GPT-4 Omni model for advanced text generation and reasoning |
| aiFoundryDefinition.aiModelDeployments[0].model.version | 2024-11-20 | Specific model version for consistency and stability |
| aiFoundryDefinition.aiModelDeployments[0].name | gpt-4o | Deployment name for referencing in applications |
| aiFoundryDefinition.aiModelDeployments[0].sku.name | GlobalStandard | Global deployment for high availability and performance |
| aiFoundryDefinition.aiModelDeployments[0].sku.capacity | 10 | Token per minute (TPM) capacity in thousands |

#### Text Embedding Model Deployment

| parameter | default | description |
|-----------|---------|-------------|
| aiFoundryDefinition.aiModelDeployments[1].model.format | OpenAI | Model format compatibility (OpenAI API format) |
| aiFoundryDefinition.aiModelDeployments[1].model.name | text-embedding-3-large | Large text embedding model for vector representations |
| aiFoundryDefinition.aiModelDeployments[1].model.version | 1 | Model version for consistent embedding dimensions |
| aiFoundryDefinition.aiModelDeployments[1].name | text-embedding-3-large | Deployment name for embedding operations |
| aiFoundryDefinition.aiModelDeployments[1].sku.name | Standard | Standard deployment tier for cost-effective embeddings |
| aiFoundryDefinition.aiModelDeployments[1].sku.capacity | 1 | Token per minute (TPM) capacity in thousands |

---

## Gateways & Firewall

### WAF Policy Defaults

| parameter | default |
|-----------|---------|
| wafPolicyDefinition.name | afwp-${baseName} |
| wafPolicyDefinition.managedRules.managedRuleSets[0].ruleSetType | OWASP |
| wafPolicyDefinition.managedRules.managedRuleSets[0].ruleSetVersion | 3.2 |
| wafPolicyDefinition.managedRules.managedRuleSets[0].ruleGroupOverrides | [] |
| wafPolicyDefinition.managedRules.exclusions | [] |

### App Gateway Defaults

| parameter | default |
|-----------|---------|
| appGatewayDefinition.name | agw-${baseName} |
| appGatewayDefinition.sku | WAF_v2 |
| appGatewayDefinition.frontendIPConfigurations[0].properties.privateIPAllocationMethod | Static |
| appGatewayDefinition.frontendIPConfigurations[0].properties.privateIPAddress | 192.168.0.200 |
| appGatewayDefinition.frontendPorts[0].properties.port | 80 |
| appGatewayDefinition.backendAddressPools[0].name | defaultBackendPool |
| appGatewayDefinition.backendHttpSettingsCollection[0].properties.cookieBasedAffinity | Disabled |
| appGatewayDefinition.backendHttpSettingsCollection[0].properties.port | 80 |
| appGatewayDefinition.backendHttpSettingsCollection[0].properties.protocol | Http |
| appGatewayDefinition.backendHttpSettingsCollection[0].properties.requestTimeout | 20 |
| appGatewayDefinition.httpListeners[0].name | httpListener |
| appGatewayDefinition.requestRoutingRules[0].name | httpRoutingRule |
| appGatewayDefinition.requestRoutingRules[0].properties.priority | 100 |
| appGatewayDefinition.requestRoutingRules[0].properties.ruleType | Basic |

### Firewall Defaults

| parameter | default |
|-----------|---------|
| firewallPolicyDefinition.name | afwp-${baseName} |
| firewallDefinition.name | afw-${baseName} |
| firewallDefinition.availabilityZones | [1,2,3] |
| firewallDefinition.azureSkuTier | Standard |

---

## Virtual Machines

### Build VM Defaults

| parameter | default |
|-----------|---------|
| buildVmDefinition.name | vm-${substring(baseName,0,6)}-bld |
| buildVmDefinition.sku | Standard_F4s_v2 |
| buildVmDefinition.adminUsername | builduser |
| buildVmDefinition.osType | Linux |
| buildVmDefinition.imageReference.publisher | Canonical |
| buildVmDefinition.imageReference.offer | 0001-com-ubuntu-server-jammy |
| buildVmDefinition.imageReference.sku | 22_04-lts |
| buildVmDefinition.imageReference.version | latest |
| buildVmDefinition.runner | github |
| buildVmDefinition.github.owner | your-org |
| buildVmDefinition.github.repo | your-repo |
| buildVmDefinition.nicConfigurations[0].nicSuffix | -nic |
| buildVmDefinition.nicConfigurations[0].ipConfigurations[0].name | ipconfig01 |
| buildVmDefinition.osDisk.caching | ReadWrite |
| buildVmDefinition.osDisk.createOption | FromImage |
| buildVmDefinition.osDisk.deleteOption | Delete |
| buildVmDefinition.osDisk.managedDisk.storageAccountType | Standard_LRS |
| buildVmDefinition.disablePasswordAuthentication | false |
| buildVmDefinition.availabilityZone | 1 |
| buildVmMaintenanceDefinition.name | mc-${baseName}-build |

### Jump VM Defaults

| parameter | default |
|-----------|---------|
| jumpVmDefinition.name | vm-${substring(baseName,0,6)}-jmp |
| jumpVmDefinition.sku | Standard_D4as_v5 |
| jumpVmDefinition.adminUsername | azureuser |
| jumpVmDefinition.osType | Windows |
| jumpVmDefinition.imageReference.publisher | MicrosoftWindowsServer |
| jumpVmDefinition.imageReference.offer | WindowsServer |
| jumpVmDefinition.imageReference.sku | 2022-datacenter-azure-edition |
| jumpVmDefinition.imageReference.version | latest |
| jumpVmDefinition.nicConfigurations[0].nicSuffix | -nic |
| jumpVmDefinition.nicConfigurations[0].ipConfigurations[0].name | ipconfig01 |
| jumpVmDefinition.osDisk.caching | ReadWrite |
| jumpVmDefinition.osDisk.createOption | FromImage |
| jumpVmDefinition.osDisk.deleteOption | Delete |
| jumpVmDefinition.osDisk.managedDisk.storageAccountType | Standard_LRS |
| jumpVmDefinition.availabilityZone | 1 |
| jumpVmMaintenanceDefinition.name | mc-${baseName}-jump |
