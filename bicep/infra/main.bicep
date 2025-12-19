metadata name = 'AI/ML Landing Zone'
metadata description = 'Deploys a secure AI/ML landing zone (resource groups, networking, AI services, private endpoints, and guardrails) using AVM resource modules.'

///////////////////////////////////////////////////////////////////////////////////////////////////
// main.bicep
//
// Purpose: Landing Zone for AI/ML workloads, network-isolated by default.
//
// -----------------------------------------------------------------------------------------------
// About this template
//
// - Strong typing: All parameter shapes are defined as User-Defined Types (UDTs) in `common/types.bicep`
//   (e.g., `types.vNetDefinitionType`, `types.privateDnsZonesDefinitionType`, etc.).
//
// - AVM alignment: This template orchestrates multiple Azure Verified Modules (AVM) via local wrappers.
//   Parameters are intentionally aligned to the upstream AVM schema. When a setting is not provided here,
//   we pass `null` (or omit) so the AVM module's own default is used.
//
// - Pre-provisioning workflow: Before deployment execution, a pre-provisioning script automatically
//   replaces wrapper module paths (`./wrappers/avm.res.*`) with their corresponding template
//   specifications. This approach is required because the template is too large to compile as a
//   single monolithic file, so it leverages pre-compiled template specs for deployment.
//
// - Opinionated defaults: Because this is a landing-zone template, some safe defaults are overridden here
//   (e.g., secure network configurations, proper subnet sizing, zone redundancy settings).
//
// - Create vs. reuse: Each service follows a uniform pattern—`resourceIds.*` (reuse) + `deploy.*` (create).
//   The computed flags `varDeploy*` determine whether a resource is created or referenced.
//
// - Section mapping: The numbered index below mirrors the actual module layout, making it easy to jump
//   between the guide and the actual module blocks.
//
// - How to use: See the provided examples for end-to-end parameter files showing different deployment
//   configurations (create-new vs. reuse-existing, etc.).
//
// - Component details: For detailed information about each deployed component, their configuration,
//   and integration patterns, see `docs/components.md`.
// -----------------------------------------------------------------------------------------------

// How to read this file:
//   1  GLOBAL PARAMETERS AND VARIABLES
//       1.1 Imports
//       1.2 General Configuration (location, tags, naming token, global flags)
//       1.3 Deployment Toggles
//       1.4 Reuse Existing Services (resourceIds)
//       1.5 Global Configuration Flags
//       1.6 Telemetry
//   2  SECURITY - NETWORK SECURITY GROUPS
//       2.1 Agent Subnet NSG
//       2.2 Private Endpoints Subnet NSG
//       2.3 Application Gateway Subnet NSG
//       2.4 API Management Subnet NSG
//       2.5 Azure Container Apps Environment Subnet NSG
//       2.6 Jumpbox Subnet NSG
//       2.7 DevOps Build Agents Subnet NSG
//       2.8 Azure Bastion Subnet NSG
//   3  NETWORKING - VIRTUAL NETWORK
//       3.1 Virtual Network and Subnets
//       3.2 Existing VNet Subnet Configuration (if applicable)
//       3.3 VNet Resource ID Resolution
//   4  NETWORKING - PRIVATE DNS ZONES
//       4.1 Platform Landing Zone Integration Logic
//       4.2 DNS Zone Configuration Variables
//       4.3 API Management Private DNS Zone
//       4.4 Cognitive Services Private DNS Zone
//       4.5 OpenAI Private DNS Zone
//       4.6 AI Services Private DNS Zone
//       4.7 Azure AI Search Private DNS Zone
//       4.8 Cosmos DB (SQL API) Private DNS Zone
//       4.9 Blob Storage Private DNS Zone
//       4.10 Key Vault Private DNS Zone
//       4.11 App Configuration Private DNS Zone
//       4.12 Container Apps Private DNS Zone
//       4.13 Container Registry Private DNS Zone
//       4.14 Application Insights Private DNS Zone
//   5  NETWORKING - PUBLIC IP ADDRESSES
//       5.1 Application Gateway Public IP
//       5.2 Azure Firewall Public IP
//   6  NETWORKING - VNET PEERING
//       6.1 Hub VNet Peering Configuration
//       6.2 Spoke VNet with Peering
//       6.3 Hub-to-Spoke Reverse Peering
//   7  NETWORKING - PRIVATE ENDPOINTS
//       7.1 App Configuration Private Endpoint
//       7.2 API Management Private Endpoint
//       7.3 Container Apps Environment Private Endpoint
//       7.4 Azure Container Registry Private Endpoint
//       7.5 Storage Account (Blob) Private Endpoint
//       7.6 Cosmos DB (SQL) Private Endpoint
//       7.7 Azure AI Search Private Endpoint
//       7.8 Key Vault Private Endpoint
//   8  OBSERVABILITY
//       8.1 Log Analytics Workspace
//       8.2 Application Insights
//   9  CONTAINER PLATFORM
//       9.1 Container Apps Environment
//       9.2 Container Registry
//   10 STORAGE
//       10.1 Storage Account
//   11 APPLICATION CONFIGURATION
//       11.1 App Configuration Store
//   12 COSMOS DB
//       12.1 Cosmos DB Database Account
//   13 KEY VAULT
//       13.1 Key Vault
//   14 AI SEARCH
//       14.1 AI Search Service
//   15 API MANAGEMENT
//       15.1 API Management Service
//   16 AI FOUNDRY
//       16.1 AI Foundry Configuration
//   17 BING GROUNDING
//       17.1 Bing Grounding Configuration
//   18 GATEWAYS AND FIREWALL
//       18.1 Web Application Firewall (WAF) Policy
//       18.2 Application Gateway
//       18.3 Azure Firewall Policy
//       18.4 Azure Firewall
//   19 VIRTUAL MACHINES
//       19.1 Build VM (Linux)
//       19.2 Jump VM (Windows)
//   20 OUTPUTS
//       20.1 Network Security Group Outputs
//       20.2 Virtual Network Outputs
//       20.3 Private DNS Zone Outputs
//       20.4 Public IP Outputs
//       20.5 VNet Peering Outputs
//       20.6 Observability Outputs
//       20.7 Container Platform Outputs
//       20.8 Storage Outputs
//       20.9 Application Configuration Outputs
//       20.10 Cosmos DB Outputs
//       20.11 Key Vault Outputs
//       20.12 AI Search Outputs
//       20.13 API Management Outputs
//       20.14 AI Foundry Outputs
//       20.15 Bing Grounding Outputs
//       20.16 Gateways and Firewall Outputs
///////////////////////////////////////////////////////////////////////////////////////////////////

targetScope = 'resourceGroup'

import {
  deployTogglesType
  resourceIdsType
  vNetDefinitionType
  existingVNetSubnetsDefinitionType
  publicIpDefinitionType
  nsgPerSubnetDefinitionsType
  hubVnetPeeringDefinitionType
  privateDnsZonesDefinitionType
  logAnalyticsDefinitionType
  appInsightsDefinitionType
  containerAppEnvDefinitionType
  containerAppDefinitionType
  appConfigurationDefinitionType
  containerRegistryDefinitionType
  storageAccountDefinitionType
  genAIAppCosmosDbDefinitionType
  keyVaultDefinitionType
  kSAISearchDefinitionType
  apimDefinitionType
  aiFoundryDefinitionType
  kSGroundingWithBingDefinitionType
  wafPolicyDefinitionsType
  appGatewayDefinitionType
  firewallPolicyDefinitionType
  firewallDefinitionType
  vmDefinitionType
  vmMaintenanceDefinitionType
  privateDnsZoneDefinitionType
} from './common/types.bicep'

@description('Required. Per-service deployment toggles.')
param deployToggles deployTogglesType

@description('Optional. Enable platform landing zone integration. When true, private DNS zones and private endpoints are managed by the platform landing zone.')
param flagPlatformLandingZone bool = false

@description('Optional. Existing resource IDs to reuse (can be empty).')
param resourceIds resourceIdsType = {}

@description('Optional. Azure region for AI LZ resources. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Optional.  Deterministic token for resource names; auto-generated if not provided.')
param resourceToken string = toLower(uniqueString(subscription().id, resourceGroup().name, location))

@description('Optional.  Base name to seed resource names; defaults to a 12-char token.')
param baseName string = substring(resourceToken, 0, 12)

@description('Optional. Enable/Disable usage telemetry for module.')
param enableTelemetry bool = true

@description('Optional. Tags to apply to all resources.')
param tags object = {}

@description('Optional. Private DNS Zone configuration for private endpoints. Used when not in platform landing zone mode.')
param privateDnsZonesDefinition privateDnsZonesDefinitionType = {
  allowInternetResolutionFallback: false
  createNetworkLinks: true
  cognitiveservicesZoneId: ''
  apimZoneId: ''
  openaiZoneId: ''
  aiServicesZoneId: ''
  searchZoneId: ''
  cosmosSqlZoneId: ''
  blobZoneId: ''
  keyVaultZoneId: ''
  appConfigZoneId: ''
  containerAppsZoneId: ''
  acrZoneId: ''
  appInsightsZoneId: ''
  tags: {}
}

// -----------------------
// Telemetry
// -----------------------
#disable-next-line no-deployments-resources
resource avmTelemetry 'Microsoft.Resources/deployments@2024-03-01' = if (enableTelemetry) {
  name: '46d3xbcp.ptn.aiml-lz.${substring(uniqueString(deployment().name, location), 0, 4)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
      outputs: {
        telemetry: {
          type: 'String'
          value: 'For more information, see https://aka.ms/avm/TelemetryInfo'
        }
      }
    }
  }
}

// -----------------------
// 1.7 Unique Naming for Deployments
// -----------------------
// Generate unique suffixes to prevent deployment name conflicts
var varUniqueSuffix = substring(uniqueString(deployment().name, location, resourceGroup().id), 0, 8)


// -----------------------
// 1.8 SECURITY - MICROSOFT DEFENDER FOR AI
// -----------------------

@description('Optional. Enable Microsoft Defender for AI (part of Defender for Cloud).')
param enableDefenderForAI bool = true

// Deploy Microsoft Defender for AI at subscription level via module
module defenderModule './components/defender/main.bicep' = if (enableDefenderForAI) {
  name: 'defender-${varUniqueSuffix}'
  scope: subscription()
  params: {
    enableDefenderForAI: enableDefenderForAI
    enableDefenderForKeyVault: deployKeyVault
  }
}
 
// -----------------------
// 2 SECURITY - NETWORK SECURITY GROUPS
// -----------------------

@description('Optional. NSG definitions per subnet role; each entry deploys an NSG for that subnet when a non-empty NSG definition is provided.')
param nsgDefinitions nsgPerSubnetDefinitionsType?

var varDeployAgentNsg = deployToggles.agentNsg && empty(resourceIds.?agentNsgResourceId)

// 2.1 Agent Subnet NSG
module agentNsgWrapper 'wrappers/avm.res.network.network-security-group.bicep' = if (varDeployAgentNsg) {
  name: 'm-nsg-agent'
  params: {
    nsg: union(
      {
        name: 'nsg-agent-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
      },
      nsgDefinitions!.?agent ?? {}
    )
  }
}

var agentNsgResourceId = resourceIds.?agentNsgResourceId ?? (varDeployAgentNsg
  ? agentNsgWrapper!.outputs.resourceId
  : null)

var varDeployPeNsg = deployToggles.peNsg && empty(resourceIds.?peNsgResourceId)

// 2.2 Private Endpoints Subnet NSG
module peNsgWrapper 'wrappers/avm.res.network.network-security-group.bicep' = if (varDeployPeNsg) {
  name: 'm-nsg-pe'
  params: {
    nsg: union(
      {
        name: 'nsg-pe-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
      },
      nsgDefinitions!.?pe ?? {}
    )
  }
}

var peNsgResourceId = resourceIds.?peNsgResourceId ?? (varDeployPeNsg ? peNsgWrapper!.outputs.resourceId : null)

var varDeployApplicationGatewayNsg = deployToggles.applicationGatewayNsg && empty(resourceIds.?applicationGatewayNsgResourceId)

// 2.3 Application Gateway Subnet NSG
module applicationGatewayNsgWrapper 'wrappers/avm.res.network.network-security-group.bicep' = if (varDeployApplicationGatewayNsg) {
  name: 'm-nsg-appgw'
  params: {
    nsg: union(
      {
        name: 'nsg-appgw-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
        // Required security rules for Application Gateway v2
        securityRules: [
          {
            name: 'Allow-GatewayManager-Inbound'
            properties: {
              access: 'Allow'
              direction: 'Inbound'
              priority: 100
              protocol: 'Tcp'
              description: 'Allow Azure Application Gateway management traffic on ports 65200-65535'
              sourceAddressPrefix: 'GatewayManager'
              sourcePortRange: '*'
              destinationAddressPrefix: '*'
              destinationPortRange: '65200-65535'
            }
          }
          {
            name: 'Allow-Internet-HTTP-Inbound'
            properties: {
              access: 'Allow'
              direction: 'Inbound'
              priority: 110
              protocol: 'Tcp'
              description: 'Allow HTTP traffic from Internet'
              sourceAddressPrefix: 'Internet'
              sourcePortRange: '*'
              destinationAddressPrefix: '*'
              destinationPortRange: '80'
            }
          }
          {
            name: 'Allow-Internet-HTTPS-Inbound'
            properties: {
              access: 'Allow'
              direction: 'Inbound'
              priority: 120
              protocol: 'Tcp'
              description: 'Allow HTTPS traffic from Internet'
              sourceAddressPrefix: 'Internet'
              sourcePortRange: '*'
              destinationAddressPrefix: '*'
              destinationPortRange: '443'
            }
          }
        ]
      },
      nsgDefinitions!.?applicationGateway ?? {}
    )
  }
}

var applicationGatewayNsgResourceId = resourceIds.?applicationGatewayNsgResourceId ?? (varDeployApplicationGatewayNsg
  ? applicationGatewayNsgWrapper!.outputs.resourceId
  : '')

var varDeployApiManagementNsg = deployToggles.apiManagementNsg && empty(resourceIds.?apiManagementNsgResourceId)

// 2.4 API Management Subnet NSG
module apiManagementNsgWrapper 'wrappers/avm.res.network.network-security-group.bicep' = if (varDeployApiManagementNsg) {
  name: 'm-nsg-apim'
  params: {
    nsg: union(
      {
        name: 'nsg-apim-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
        // Required security rules for API Management Internal VNet mode
        securityRules: [
          // ========== INBOUND RULES ==========
          {
            name: 'Allow-APIM-Management-Inbound'
            properties: {
              access: 'Allow'
              direction: 'Inbound'
              priority: 100
              protocol: 'Tcp'
              description: 'Azure API Management control plane traffic'
              sourceAddressPrefix: 'ApiManagement'
              sourcePortRange: '*'
              destinationAddressPrefix: 'VirtualNetwork'
              destinationPortRange: '3443'
            }
          }
          {
            name: 'Allow-AzureLoadBalancer-Inbound'
            properties: {
              access: 'Allow'
              direction: 'Inbound'
              priority: 110
              protocol: 'Tcp'
              description: 'Azure Infrastructure Load Balancer health probes'
              sourceAddressPrefix: 'AzureLoadBalancer'
              sourcePortRange: '*'
              destinationAddressPrefix: 'VirtualNetwork'
              destinationPortRange: '6390'
            }
          }
          {
            name: 'Allow-VNet-to-APIM-Inbound'
            properties: {
              access: 'Allow'
              direction: 'Inbound'
              priority: 120
              protocol: 'Tcp'
              description: 'Internal VNet clients to APIM gateway'
              sourceAddressPrefix: 'VirtualNetwork'
              sourcePortRange: '*'
              destinationAddressPrefix: 'VirtualNetwork'
              destinationPortRange: '443'
            }
          }
          // ========== OUTBOUND RULES ==========
          {
            name: 'Allow-APIM-to-Storage-Outbound'
            properties: {
              access: 'Allow'
              direction: 'Outbound'
              priority: 100
              protocol: 'Tcp'
              description: 'APIM to Azure Storage for dependencies'
              sourceAddressPrefix: 'VirtualNetwork'
              sourcePortRange: '*'
              destinationAddressPrefix: 'Storage'
              destinationPortRange: '443'
            }
          }
          {
            name: 'Allow-APIM-to-SQL-Outbound'
            properties: {
              access: 'Allow'
              direction: 'Outbound'
              priority: 110
              protocol: 'Tcp'
              description: 'APIM to Azure SQL for dependencies'
              sourceAddressPrefix: 'VirtualNetwork'
              sourcePortRange: '*'
              destinationAddressPrefix: 'Sql'
              destinationPortRange: '1443'
            }
          }
          {
            name: 'Allow-APIM-to-KeyVault-Outbound'
            properties: {
              access: 'Allow'
              direction: 'Outbound'
              priority: 120
              protocol: 'Tcp'
              description: 'APIM to Key Vault for certificates and secrets'
              sourceAddressPrefix: 'VirtualNetwork'
              sourcePortRange: '*'
              destinationAddressPrefix: 'AzureKeyVault'
              destinationPortRange: '443'
            }
          }
          {
            name: 'Allow-APIM-to-EventHub-Outbound'
            properties: {
              access: 'Allow'
              direction: 'Outbound'
              priority: 130
              protocol: 'Tcp'
              description: 'APIM to Event Hub for logging'
              sourceAddressPrefix: 'VirtualNetwork'
              sourcePortRange: '*'
              destinationAddressPrefix: 'EventHub'
              destinationPortRanges: ['5671', '5672', '443']
            }
          }
          {
            name: 'Allow-APIM-to-InternalBackends-Outbound'
            properties: {
              access: 'Allow'
              direction: 'Outbound'
              priority: 140
              protocol: 'Tcp'
              description: 'APIM to internal backends (OpenAI, AI Services, etc)'
              sourceAddressPrefix: 'VirtualNetwork'
              sourcePortRange: '*'
              destinationAddressPrefix: 'VirtualNetwork'
              destinationPortRange: '443'
            }
          }
          {
            name: 'Allow-APIM-to-AzureMonitor-Outbound'
            properties: {
              access: 'Allow'
              direction: 'Outbound'
              priority: 150
              protocol: 'Tcp'
              description: 'APIM to Azure Monitor for telemetry'
              sourceAddressPrefix: 'VirtualNetwork'
              sourcePortRange: '*'
              destinationAddressPrefix: 'AzureMonitor'
              destinationPortRanges: ['1886', '443']
            }
          }
        ]
      },
      nsgDefinitions!.?apiManagement ?? {}
    )
  }
}

var apiManagementNsgResourceId = resourceIds.?apiManagementNsgResourceId ?? (varDeployApiManagementNsg
  ? apiManagementNsgWrapper!.outputs.resourceId
  : '')

var varDeployAcaEnvironmentNsg = deployToggles.acaEnvironmentNsg && empty(resourceIds.?acaEnvironmentNsgResourceId)

// 2.5 Azure Container Apps Environment Subnet NSG
module acaEnvironmentNsgWrapper 'wrappers/avm.res.network.network-security-group.bicep' = if (varDeployAcaEnvironmentNsg) {
  name: 'm-nsg-aca-env'
  params: {
    nsg: union(
      {
        name: 'nsg-aca-env-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
      },
      nsgDefinitions!.?acaEnvironment ?? {}
    )
  }
}

var acaEnvironmentNsgResourceId = resourceIds.?acaEnvironmentNsgResourceId ?? (varDeployAcaEnvironmentNsg
  ? acaEnvironmentNsgWrapper!.outputs.resourceId
  : '')

var varDeployJumpboxNsg = deployToggles.jumpboxNsg && empty(resourceIds.?jumpboxNsgResourceId)

// 2.6 Jumpbox Subnet NSG
module jumpboxNsgWrapper 'wrappers/avm.res.network.network-security-group.bicep' = if (varDeployJumpboxNsg) {
  name: 'm-nsg-jumpbox'
  params: {
    nsg: union(
      {
        name: 'nsg-jumpbox-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
      },
      nsgDefinitions!.?jumpbox ?? {}
    )
  }
}

var jumpboxNsgResourceId = resourceIds.?jumpboxNsgResourceId ?? (varDeployJumpboxNsg
  ? jumpboxNsgWrapper!.outputs.resourceId
  : '')

var varDeployDevopsBuildAgentsNsg = deployToggles.devopsBuildAgentsNsg && empty(resourceIds.?devopsBuildAgentsNsgResourceId)

// 2.7 DevOps Build Agents Subnet NSG
module devopsBuildAgentsNsgWrapper 'wrappers/avm.res.network.network-security-group.bicep' = if (varDeployDevopsBuildAgentsNsg) {
  name: 'm-nsg-devops-agents'
  params: {
    nsg: union(
      {
        name: 'nsg-devops-agents-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
      },
      nsgDefinitions!.?devopsBuildAgents ?? {}
    )
  }
}

var devopsBuildAgentsNsgResourceId = resourceIds.?devopsBuildAgentsNsgResourceId ?? (varDeployDevopsBuildAgentsNsg
  ? devopsBuildAgentsNsgWrapper!.outputs.resourceId
  : '')

// 2.8 Azure Bastion Subnet NSG

var varDeployBastionNsg = deployToggles.bastionNsg && empty(resourceIds.?bastionNsgResourceId)

module bastionNsgWrapper 'wrappers/avm.res.network.network-security-group.bicep' = if (varDeployBastionNsg) {
  name: 'm-nsg-bastion'
  params: {
    nsg: union(
      {
        name: 'nsg-bastion-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
        // Required security rules for Azure Bastion
        securityRules: [
          {
            name: 'Allow-GatewayManager-Inbound'
            properties: {
              access: 'Allow'
              direction: 'Inbound'
              priority: 100
              protocol: 'Tcp'
              description: 'Allow Azure Bastion control plane traffic'
              sourceAddressPrefix: 'GatewayManager'
              sourcePortRange: '*'
              destinationAddressPrefix: '*'
              destinationPortRange: '443'
            }
          }
          {
            name: 'Allow-Internet-HTTPS-Inbound'
            properties: {
              access: 'Allow'
              direction: 'Inbound'
              priority: 110
              protocol: 'Tcp'
              description: 'Allow HTTPS traffic from Internet for user sessions'
              sourceAddressPrefix: 'Internet'
              sourcePortRange: '*'
              destinationAddressPrefix: '*'
              destinationPortRange: '443'
            }
          }
          {
            name: 'Allow-Internet-HTTPS-Alt-Inbound'
            properties: {
              access: 'Allow'
              direction: 'Inbound'
              priority: 120
              protocol: 'Tcp'
              description: 'Allow alternate HTTPS traffic from Internet'
              sourceAddressPrefix: 'Internet'
              sourcePortRange: '*'
              destinationAddressPrefix: '*'
              destinationPortRange: '4443'
            }
          }
          {
            name: 'Allow-BastionHost-Communication-Inbound'
            properties: {
              access: 'Allow'
              direction: 'Inbound'
              priority: 130
              protocol: 'Tcp'
              description: 'Allow Bastion host-to-host communication'
              sourceAddressPrefix: 'VirtualNetwork'
              sourcePortRange: '*'
              destinationAddressPrefix: 'VirtualNetwork'
              destinationPortRanges: ['8080', '5701']
            }
          }
          {
            name: 'Allow-SSH-RDP-Outbound'
            properties: {
              access: 'Allow'
              direction: 'Outbound'
              priority: 100
              protocol: '*'
              description: 'Allow SSH and RDP to target VMs'
              sourceAddressPrefix: '*'
              sourcePortRange: '*'
              destinationAddressPrefix: 'VirtualNetwork'
              destinationPortRanges: ['22', '3389']
            }
          }
          {
            name: 'Allow-AzureCloud-Outbound'
            properties: {
              access: 'Allow'
              direction: 'Outbound'
              priority: 110
              protocol: 'Tcp'
              description: 'Allow Azure Cloud communication'
              sourceAddressPrefix: '*'
              sourcePortRange: '*'
              destinationAddressPrefix: 'AzureCloud'
              destinationPortRange: '443'
            }
          }
          {
            name: 'Allow-BastionHost-Communication-Outbound'
            properties: {
              access: 'Allow'
              direction: 'Outbound'
              priority: 120
              protocol: 'Tcp'
              description: 'Allow Bastion host-to-host communication'
              sourceAddressPrefix: 'VirtualNetwork'
              sourcePortRange: '*'
              destinationAddressPrefix: 'VirtualNetwork'
              destinationPortRanges: ['8080', '5701']
            }
          }
          {
            name: 'Allow-GetSessionInformation-Outbound'
            properties: {
              access: 'Allow'
              direction: 'Outbound'
              priority: 130
              protocol: '*'
              description: 'Allow session and certificate validation'
              sourceAddressPrefix: '*'
              sourcePortRange: '*'
              destinationAddressPrefix: 'Internet'
              destinationPortRange: '80'
            }
          }
        ]
      },
      nsgDefinitions!.?bastion ?? {}
    )
  }
}

var bastionNsgResourceId = resourceIds.?bastionNsgResourceId ?? (varDeployBastionNsg
  ? bastionNsgWrapper!.outputs.resourceId
  : '')

// -----------------------
// 3 NETWORKING - VIRTUAL NETWORK
// -----------------------

@description('Conditional. Virtual Network configuration. Required if deploy.virtualNetwork is true and resourceIds.virtualNetworkResourceId is empty.')
param vNetDefinition vNetDefinitionType?

@description('Optional. Configuration for adding subnets to an existing VNet. Use this when you want to deploy subnets to an existing VNet instead of creating a new one.')
param existingVNetSubnetsDefinition existingVNetSubnetsDefinitionType?

var varDeployVnet = deployToggles.virtualNetwork && empty(resourceIds.?virtualNetworkResourceId)
var varDeploySubnetsToExistingVnet = existingVNetSubnetsDefinition != null

// Parse existing VNet Resource ID for cross-subscription/resource group support
var varExistingVNetIdSegments = varDeploySubnetsToExistingVnet
  ? split(existingVNetSubnetsDefinition!.existingVNetName, '/')
  : array([])
var varIsExistingVNetResourceId = varDeploySubnetsToExistingVnet && length(varExistingVNetIdSegments) > 1
var varExistingVNetSubscriptionId = varDeploySubnetsToExistingVnet && varIsExistingVNetResourceId && length(varExistingVNetIdSegments) >= 3
  ? varExistingVNetIdSegments[2]
  : ''
var varExistingVNetResourceGroupName = varDeploySubnetsToExistingVnet && varIsExistingVNetResourceId && length(varExistingVNetIdSegments) >= 5
  ? varExistingVNetIdSegments[4]
  : ''
var varIsCrossScope = varIsExistingVNetResourceId && !empty(varExistingVNetSubscriptionId) && !empty(varExistingVNetResourceGroupName)

// 3.1 Virtual Network and Subnets
module vNetworkWrapper 'wrappers/avm.res.network.virtual-network.bicep' = if (varDeployVnet) {
  name: 'm-vnet'
  params: {
    vnet: union(
      {
        name: 'vnet-${baseName}'
        addressPrefixes: ['192.168.0.0/22']
        location: location
        enableTelemetry: enableTelemetry
        subnets: [
          {
            enabled: true
            name: 'agent-subnet'
            addressPrefix: '192.168.0.0/27'
            delegation: 'Microsoft.App/environments'
            serviceEndpoints: ['Microsoft.CognitiveServices']
            networkSecurityGroupResourceId: agentNsgResourceId
            // Min: /27 (32 IPs) will work for small setups
            // Recommended: /24 (256 IPs) per Microsoft guidance for delegated Agent subnets
          }
          {
            enabled: true
            name: 'pe-subnet'
            addressPrefix: '192.168.0.32/27'
            serviceEndpoints: ['Microsoft.AzureCosmosDB']
            privateEndpointNetworkPolicies: 'Disabled'
            networkSecurityGroupResourceId: peNsgResourceId
            // Min: /28 (16 IPs) can work for a couple of Private Endpoints
            // Recommended: /27 or larger if you expect many PEs (each uses 1 IP)
          }
          {
            enabled: true
            name: 'AzureBastionSubnet'
            addressPrefix: '192.168.0.64/26'
            networkSecurityGroupResourceId: bastionNsgResourceId
            // Min (required by Azure): /26 (64 IPs)
            // Recommended: /26 (mandatory, cannot be smaller)
          }
          {
            enabled: true
            name: 'AzureFirewallSubnet'
            addressPrefix: '192.168.0.128/26'
            // Min (required by Azure): /26 (64 IPs)
            // Recommended: /26 or /25 if you want future scale
          }
          {
            enabled: true
            name: 'appgw-subnet'
            addressPrefix: '192.168.0.192/27'
            networkSecurityGroupResourceId: applicationGatewayNsgResourceId
            // Min: /29 (8 IPs) if very small, but not practical
            // Recommended: /27 (32 IPs) or larger for production App Gateway
          }
          {
            enabled: true
            name: 'apim-subnet'
            addressPrefix: '192.168.0.224/27'
            networkSecurityGroupResourceId: apiManagementNsgResourceId
            // Min: /28 (16 IPs) for dev/test SKUs
            // Recommended: /27 or larger for production multi-zone APIM
          }
          {
            enabled: true
            name: 'jumpbox-subnet'
            addressPrefix: '192.168.1.0/28'
            networkSecurityGroupResourceId: jumpboxNsgResourceId
            // Min: /29 (8 IPs) for 1–2 VMs
            // Recommended: /28 (16 IPs) to host a couple of VMs comfortably
          }
          {
            enabled: true
            name: 'aca-env-subnet'
            addressPrefix: '192.168.2.0/23' // ACA requires /23 minimum
            delegation: 'Microsoft.App/environments'
            serviceEndpoints: ['Microsoft.AzureCosmosDB']
            networkSecurityGroupResourceId: acaEnvironmentNsgResourceId
            // Min (required by Azure): /23 (512 IPs)
            // Recommended: /23 or /22 if expecting many apps & scale-out
          }
          {
            enabled: true
            name: 'devops-agents-subnet'
            addressPrefix: '192.168.1.32/27'
            networkSecurityGroupResourceId: devopsBuildAgentsNsgResourceId
            // Min: /28 (16 IPs) if you run few agents
            // Recommended: /27 (32 IPs) to allow scaling
          }
        ]
      },
      vNetDefinition ?? {}
    )
  }
}

var varApimSubnetId = empty(resourceIds.?virtualNetworkResourceId!)
  ? '${virtualNetworkResourceId}/subnets/apim-subnet'
  : '${resourceIds.virtualNetworkResourceId!}/subnets/apim-subnet'

// Note: We need two module declarations because Bicep requires compile-time scope resolution.
// The scope parameter cannot be conditionally determined at runtime, so we use two modules
// with different scopes but the same template to handle both same-scope and cross-scope scenarios.

// 3.2 Existing VNet Subnet Configuration (if applicable)
module existingVNetSubnets './helpers/setup-subnets-for-vnet/main.bicep' = if (varDeploySubnetsToExistingVnet && !varIsCrossScope) {
  name: 'm-existing-vnet-subnets'
  params: {
    existingVNetSubnetsDefinition: existingVNetSubnetsDefinition!
    nsgResourceIds: {
      agentNsgResourceId: agentNsgResourceId!
      peNsgResourceId: peNsgResourceId!
      applicationGatewayNsgResourceId: applicationGatewayNsgResourceId!
      apiManagementNsgResourceId: apiManagementNsgResourceId!
      jumpboxNsgResourceId: jumpboxNsgResourceId!
      acaEnvironmentNsgResourceId: acaEnvironmentNsgResourceId!
      devopsBuildAgentsNsgResourceId: devopsBuildAgentsNsgResourceId!
      bastionNsgResourceId: bastionNsgResourceId!
    }
  }
}

// Deploy subnets to existing VNet (cross-scope)
module existingVNetSubnetsCrossScope './helpers/setup-subnets-for-vnet/main.bicep' = if (varDeploySubnetsToExistingVnet && varIsCrossScope) {
  name: 'm-existing-vnet-subnets-cross-scope'
  scope: resourceGroup(varExistingVNetSubscriptionId, varExistingVNetResourceGroupName)
  params: {
    existingVNetSubnetsDefinition: existingVNetSubnetsDefinition!
    nsgResourceIds: {
      agentNsgResourceId: agentNsgResourceId!
      peNsgResourceId: peNsgResourceId!
      applicationGatewayNsgResourceId: applicationGatewayNsgResourceId!
      apiManagementNsgResourceId: apiManagementNsgResourceId!
      jumpboxNsgResourceId: jumpboxNsgResourceId!
      acaEnvironmentNsgResourceId: acaEnvironmentNsgResourceId!
      devopsBuildAgentsNsgResourceId: devopsBuildAgentsNsgResourceId!
    }
  }
}

var existingVNetResourceId = varDeploySubnetsToExistingVnet
  ? (varIsCrossScope
      ? existingVNetSubnetsCrossScope!.outputs.virtualNetworkResourceId
      : existingVNetSubnets!.outputs.virtualNetworkResourceId)
  : ''

// 3.3 VNet Resource ID Resolution
var virtualNetworkResourceId = resourceIds.?virtualNetworkResourceId ?? (varDeployHubPeering && varDeployVnet
  ? spokeVNetWithPeering!.outputs.resourceId
  : (varDeployVnet ? vNetworkWrapper!.outputs.resourceId : existingVNetResourceId))

// -----------------------
// 4 NETWORKING - PRIVATE DNS ZONES
// -----------------------

// 4.1 Platform Landing Zone Integration Logic
var varIsPlatformLz = flagPlatformLandingZone
var varDeployPdnsAndPe = !varIsPlatformLz

// 4.2 DNS Zone Configuration Variables
var varUseExistingPdz = {
  cognitiveservices: !empty(privateDnsZonesDefinition.?cognitiveservicesZoneId)
  apim: !empty(privateDnsZonesDefinition.?apimZoneId)
  openai: !empty(privateDnsZonesDefinition.?openaiZoneId)
  aiServices: !empty(privateDnsZonesDefinition.?aiServicesZoneId)
  search: !empty(privateDnsZonesDefinition.?searchZoneId)
  cosmosSql: !empty(privateDnsZonesDefinition.?cosmosSqlZoneId)
  blob: !empty(privateDnsZonesDefinition.?blobZoneId)
  keyVault: !empty(privateDnsZonesDefinition.?keyVaultZoneId)
  appConfig: !empty(privateDnsZonesDefinition.?appConfigZoneId)
  containerApps: !empty(privateDnsZonesDefinition.?containerAppsZoneId)
  acr: !empty(privateDnsZonesDefinition.?acrZoneId)
  appInsights: !empty(privateDnsZonesDefinition.?appInsightsZoneId)
}

// Common variables for VNet name and resource ID (used in DNS zone VNet links)
var varVnetName = split(virtualNetworkResourceId, '/')[8]
var varVnetResourceId = virtualNetworkResourceId

// 4.3 Private Endpoint Variables
var varPeSubnetId = empty(resourceIds.?virtualNetworkResourceId!)
  ? '${virtualNetworkResourceId}/subnets/pe-subnet'
  : '${resourceIds.virtualNetworkResourceId!}/subnets/pe-subnet'

// Service availability checks for private endpoints
var varHasAppConfig = !empty(resourceIds.?appConfigResourceId!) || varDeployAppConfig
var varHasApim = !empty(resourceIds.?apimServiceResourceId!) || varDeployApim
var varHasContainerEnv = !empty(resourceIds.?containerEnvResourceId!) || varDeployContainerAppEnv
var varHasAcr = !empty(resourceIds.?containerRegistryResourceId!) || varDeployAcr
var varHasStorage = !empty(resourceIds.?storageAccountResourceId!) || varDeploySa
var varHasCosmos = cosmosDbDefinition != null
var varHasSearch = aiSearchDefinition != null
var varHasKv = keyVaultDefinition != null

// 4.4 API Management Private DNS Zone
@description('Optional. API Management Private DNS Zone configuration.')
param apimPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

module privateDnsZoneApim 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.apim) {
  name: 'dep-apim-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.azure-api.net'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (privateDnsZonesDefinition.?createNetworkLinks ?? true)
          ? [
              {
                name: '${varVnetName}-apim-link'
                registrationEnabled: false
                virtualNetworkResourceId: varVnetResourceId
              }
            ]
          : []
      },
      apimPrivateDnsZoneDefinition ?? {}
    )
  }
}

// 4.5 Cognitive Services Private DNS Zone
@description('Optional. Cognitive Services Private DNS Zone configuration.')
param cognitiveServicesPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

module privateDnsZoneCogSvcs 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.cognitiveservices) {
  name: 'dep-cogsvcs-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.cognitiveservices.azure.com'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (privateDnsZonesDefinition.?createNetworkLinks ?? true)
          ? [
              {
                name: '${varVnetName}-cogsvcs-link'
                registrationEnabled: false
                virtualNetworkResourceId: varVnetResourceId
              }
            ]
          : []
      },
      cognitiveServicesPrivateDnsZoneDefinition ?? {}
    )
  }
}

// 4.6 OpenAI Private DNS Zone
@description('Optional. OpenAI Private DNS Zone configuration.')
param openAiPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

module privateDnsZoneOpenAi 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.openai) {
  name: 'dep-openai-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.openai.azure.com'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (privateDnsZonesDefinition.?createNetworkLinks ?? true)
          ? [
              {
                name: '${varVnetName}-openai-link'
                registrationEnabled: false
                virtualNetworkResourceId: varVnetResourceId
              }
            ]
          : []
      },
      openAiPrivateDnsZoneDefinition ?? {}
    )
  }
}

// 4.7 AI Services Private DNS Zone
@description('Optional. AI Services Private DNS Zone configuration.')
param aiServicesPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

module privateDnsZoneAiService 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.aiServices) {
  name: 'dep-aiservices-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.services.ai.azure.com'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (privateDnsZonesDefinition.?createNetworkLinks ?? true)
          ? [
              {
                name: '${varVnetName}-aiservices-link'
                registrationEnabled: false
                virtualNetworkResourceId: varVnetResourceId
              }
            ]
          : []
      },
      aiServicesPrivateDnsZoneDefinition ?? {}
    )
  }
}

// 4.8 Azure AI Search Private DNS Zone
@description('Optional. Azure AI Search Private DNS Zone configuration.')
param searchPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

module privateDnsZoneSearch 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.search) {
  name: 'dep-search-std-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.search.windows.net'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (privateDnsZonesDefinition.?createNetworkLinks ?? true)
          ? [
              {
                name: '${varVnetName}-search-std-link'
                registrationEnabled: false
                virtualNetworkResourceId: varVnetResourceId
              }
            ]
          : []
      },
      searchPrivateDnsZoneDefinition ?? {}
    )
  }
}

// 4.9 Cosmos DB (SQL API) Private DNS Zone
@description('Optional. Cosmos DB Private DNS Zone configuration.')
param cosmosPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

module privateDnsZoneCosmos 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.cosmosSql) {
  name: 'dep-cosmos-std-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.documents.azure.com'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (privateDnsZonesDefinition.?createNetworkLinks ?? true)
          ? [
              {
                name: '${varVnetName}-cosmos-std-link'
                registrationEnabled: false
                virtualNetworkResourceId: varVnetResourceId
              }
            ]
          : []
      },
      cosmosPrivateDnsZoneDefinition ?? {}
    )
  }
}

// 4.10 Blob Storage Private DNS Zone
@description('Optional. Blob Storage Private DNS Zone configuration.')
param blobPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

module privateDnsZoneBlob 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.blob) {
  name: 'dep-blob-std-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.blob.${environment().suffixes.storage}'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (privateDnsZonesDefinition.?createNetworkLinks ?? true)
          ? [
              {
                name: '${varVnetName}-blob-std-link'
                registrationEnabled: false
                virtualNetworkResourceId: varVnetResourceId
              }
            ]
          : []
      },
      blobPrivateDnsZoneDefinition ?? {}
    )
  }
}

// 4.11 Key Vault Private DNS Zone
@description('Optional. Key Vault Private DNS Zone configuration.')
param keyVaultPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

module privateDnsZoneKeyVault 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.keyVault) {
  name: 'kv-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.vaultcore.azure.net'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (privateDnsZonesDefinition.?createNetworkLinks ?? true)
          ? [
              {
                name: '${varVnetName}-kv-link'
                registrationEnabled: false
                virtualNetworkResourceId: varVnetResourceId
              }
            ]
          : []
      },
      keyVaultPrivateDnsZoneDefinition ?? {}
    )
  }
}

// 4.12 App Configuration Private DNS Zone
@description('Optional. App Configuration Private DNS Zone configuration.')
param appConfigPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

module privateDnsZoneAppConfig 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.appConfig) {
  name: 'appconfig-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.azconfig.io'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (privateDnsZonesDefinition.?createNetworkLinks ?? true)
          ? [
              {
                name: '${varVnetName}-appcfg-link'
                registrationEnabled: false
                virtualNetworkResourceId: varVnetResourceId
              }
            ]
          : []
      },
      appConfigPrivateDnsZoneDefinition ?? {}
    )
  }
}

// 4.13 Container Apps Private DNS Zone
@description('Optional. Container Apps Private DNS Zone configuration.')
param containerAppsPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

module privateDnsZoneContainerApps 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.containerApps) {
  name: 'dep-containerapps-env-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.${location}.azurecontainerapps.io'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (privateDnsZonesDefinition.?createNetworkLinks ?? true)
          ? [
              {
                name: '${varVnetName}-containerapps-link'
                registrationEnabled: false
                virtualNetworkResourceId: varVnetResourceId
              }
            ]
          : []
      },
      containerAppsPrivateDnsZoneDefinition ?? {}
    )
  }
}

// 4.14 Container Registry Private DNS Zone
@description('Optional. Container Registry Private DNS Zone configuration.')
param acrPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

module privateDnsZoneAcr 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.acr) {
  name: 'acr-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.azurecr.io'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (privateDnsZonesDefinition.?createNetworkLinks ?? true)
          ? [
              {
                name: '${varVnetName}-acr-link'
                registrationEnabled: false
                virtualNetworkResourceId: varVnetResourceId
              }
            ]
          : []
      },
      acrPrivateDnsZoneDefinition ?? {}
    )
  }
}

// 4.15 Application Insights Private DNS Zone
@description('Optional. Application Insights Private DNS Zone configuration.')
param appInsightsPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

module privateDnsZoneInsights 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.appInsights) {
  name: 'ai-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.applicationinsights.azure.com'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (privateDnsZonesDefinition.?createNetworkLinks ?? true)
          ? [
              {
                name: '${varVnetName}-ai-link'
                registrationEnabled: false
                virtualNetworkResourceId: varVnetResourceId
              }
            ]
          : []
      },
      appInsightsPrivateDnsZoneDefinition ?? {}
    )
  }
}

// -----------------------
// 5 NETWORKING - PUBLIC IP ADDRESSES
// -----------------------

// 5.1 Application Gateway Public IP
@description('Conditional Public IP for Application Gateway. Requred when deploy applicationGatewayPublicIp is true and no existing ID is provided.')
param appGatewayPublicIp publicIpDefinitionType?

var varDeployApGatewayPip = deployToggles.applicationGatewayPublicIp && empty(resourceIds.?appGatewayPublicIpResourceId)

module appGatewayPipWrapper 'wrappers/avm.res.network.public-ip-address.bicep' = if (varDeployApGatewayPip) {
  name: 'm-appgw-pip'
  params: {
    pip: union(
      {
        name: 'pip-agw-${baseName}'
        skuName: 'Standard'
        skuTier: 'Regional'
        publicIPAllocationMethod: 'Static'
        publicIPAddressVersion: 'IPv4'
        zones: [1, 2, 3]
        location: location
        enableTelemetry: enableTelemetry
      },
      appGatewayPublicIp ?? {}
    )
  }
}

var appGatewayPublicIpResourceId = resourceIds.?appGatewayPublicIpResourceId ?? (varDeployApGatewayPip
  ? appGatewayPipWrapper!.outputs.resourceId
  : '')

// 5.2 Azure Firewall Public IP
@description('Conditional Public IP for Azure Firewall. Required when deploy firewall is true and no existing ID is provided.')
param firewallPublicIp publicIpDefinitionType?

var varDeployFirewallPip = deployToggles.?firewall && empty(resourceIds.?firewallPublicIpResourceId)

module firewallPipWrapper 'wrappers/avm.res.network.public-ip-address.bicep' = if (varDeployFirewallPip) {
  name: 'm-fw-pip'
  params: {
    pip: union(
      {
        name: 'pip-fw-${baseName}'
        skuName: 'Standard'
        skuTier: 'Regional'
        publicIPAllocationMethod: 'Static'
        publicIPAddressVersion: 'IPv4'
        zones: [1, 2, 3]
        location: location
        enableTelemetry: enableTelemetry
      },
      firewallPublicIp ?? {}
    )
  }
}

var firewallPublicIpResourceId = resourceIds.?firewallPublicIpResourceId ?? (varDeployFirewallPip
  ? firewallPipWrapper!.outputs.resourceId
  : '')

// -----------------------
// 6 NETWORKING - VNET PEERING
// -----------------------

@description('Optional. Hub VNet peering configuration. Configure this to establish hub-spoke peering topology.')
param hubVnetPeeringDefinition hubVnetPeeringDefinitionType?

// 6.1 Hub VNet Peering Configuration
var varDeployHubPeering = hubVnetPeeringDefinition != null && !empty(hubVnetPeeringDefinition.?peerVnetResourceId)

// Parse hub VNet resource ID
var varHubPeerVnetId = varDeployHubPeering ? hubVnetPeeringDefinition!.peerVnetResourceId! : ''
var varHubPeerParts = split(varHubPeerVnetId, '/')
var varHubPeerSub = varDeployHubPeering && length(varHubPeerParts) >= 3
  ? varHubPeerParts[2]
  : subscription().subscriptionId
var varHubPeerRg = varDeployHubPeering && length(varHubPeerParts) >= 5 ? varHubPeerParts[4] : resourceGroup().name
var varHubPeerVnetName = varDeployHubPeering && length(varHubPeerParts) >= 9 ? varHubPeerParts[8] : ''

// 6.2 Spoke VNet with Peering
module spokeVNetWithPeering 'wrappers/avm.res.network.virtual-network.bicep' = if (varDeployHubPeering && varDeployVnet) {
  name: 'm-spoke-vnet-peering'
  params: {
    vnet: union(
      {
        name: 'vnet-${baseName}'
        addressPrefixes: ['192.168.0.0/22']
        location: location
        enableTelemetry: enableTelemetry
        peerings: [
          {
            name: hubVnetPeeringDefinition!.?name ?? 'to-hub'
            remoteVirtualNetworkResourceId: varHubPeerVnetId
            allowVirtualNetworkAccess: hubVnetPeeringDefinition!.?allowVirtualNetworkAccess ?? true
            allowForwardedTraffic: hubVnetPeeringDefinition!.?allowForwardedTraffic ?? true
            allowGatewayTransit: hubVnetPeeringDefinition!.?allowGatewayTransit ?? false
            useRemoteGateways: hubVnetPeeringDefinition!.?useRemoteGateways ?? false
          }
        ]
      },
      hubVnetPeeringDefinition ?? {}
    )
  }
}

// 6.3 Hub-to-Spoke Reverse Peering
module hubToSpokePeering './components/vnet-peering/main.bicep' = if (varDeployHubPeering && (hubVnetPeeringDefinition!.?createReversePeering ?? true)) {
  name: 'm-hub-to-spoke-peering'
  scope: resourceGroup(varHubPeerSub, varHubPeerRg)
  params: {
    localVnetName: varHubPeerVnetName
    remotePeeringName: hubVnetPeeringDefinition!.?reverseName ?? 'to-spoke-${baseName}'
    remoteVirtualNetworkResourceId: varDeployVnet ? spokeVNetWithPeering!.outputs.resourceId : virtualNetworkResourceId
    allowVirtualNetworkAccess: hubVnetPeeringDefinition!.?reverseAllowVirtualNetworkAccess ?? true
    allowForwardedTraffic: hubVnetPeeringDefinition!.?reverseAllowForwardedTraffic ?? true
    allowGatewayTransit: hubVnetPeeringDefinition!.?reverseAllowGatewayTransit ?? false
    useRemoteGateways: hubVnetPeeringDefinition!.?reverseUseRemoteGateways ?? false
  }
}

// -----------------------
// Private DNS Zone Outputs
// -----------------------

@description('API Management Private DNS Zone resource ID (newly created or existing).')
output apimPrivateDnsZoneResourceId string = privateDnsZonesDefinition.?apimZoneId ?? (varDeployPdnsAndPe && !varUseExistingPdz.apim
  ? privateDnsZoneApim!.outputs.resourceId
  : '')

@description('Cognitive Services Private DNS Zone resource ID (newly created or existing).')
output cognitiveServicesPrivateDnsZoneResourceId string = privateDnsZonesDefinition.?cognitiveservicesZoneId ?? (varDeployPdnsAndPe && !varUseExistingPdz.cognitiveservices
  ? privateDnsZoneCogSvcs!.outputs.resourceId
  : '')

@description('OpenAI Private DNS Zone resource ID (newly created or existing).')
output openAiPrivateDnsZoneResourceId string = privateDnsZonesDefinition.?openaiZoneId ?? (varDeployPdnsAndPe && !varUseExistingPdz.openai
  ? privateDnsZoneOpenAi!.outputs.resourceId
  : '')

@description('AI Services Private DNS Zone resource ID (newly created or existing).')
output aiServicesPrivateDnsZoneResourceId string = privateDnsZonesDefinition.?aiServicesZoneId ?? (varDeployPdnsAndPe && !varUseExistingPdz.aiServices
  ? privateDnsZoneAiService!.outputs.resourceId
  : '')

@description('Azure AI Search Private DNS Zone resource ID (newly created or existing).')
output searchPrivateDnsZoneResourceId string = privateDnsZonesDefinition.?searchZoneId ?? (varDeployPdnsAndPe && !varUseExistingPdz.search
  ? privateDnsZoneSearch!.outputs.resourceId
  : '')

@description('Cosmos DB (SQL API) Private DNS Zone resource ID (newly created or existing).')
output cosmosSqlPrivateDnsZoneResourceId string = privateDnsZonesDefinition.?cosmosSqlZoneId ?? (varDeployPdnsAndPe && !varUseExistingPdz.cosmosSql
  ? privateDnsZoneCosmos!.outputs.resourceId
  : '')

@description('Blob Storage Private DNS Zone resource ID (newly created or existing).')
output blobPrivateDnsZoneResourceId string = privateDnsZonesDefinition.?blobZoneId ?? (varDeployPdnsAndPe && !varUseExistingPdz.blob
  ? privateDnsZoneBlob!.outputs.resourceId
  : '')

@description('Key Vault Private DNS Zone resource ID (newly created or existing).')
output keyVaultPrivateDnsZoneResourceId string = privateDnsZonesDefinition.?keyVaultZoneId ?? (varDeployPdnsAndPe && !varUseExistingPdz.keyVault
  ? privateDnsZoneKeyVault!.outputs.resourceId
  : '')

@description('App Configuration Private DNS Zone resource ID (newly created or existing).')
output appConfigPrivateDnsZoneResourceId string = privateDnsZonesDefinition.?appConfigZoneId ?? (varDeployPdnsAndPe && !varUseExistingPdz.appConfig
  ? privateDnsZoneAppConfig!.outputs.resourceId
  : '')

@description('Container Apps Private DNS Zone resource ID (newly created or existing).')
output containerAppsPrivateDnsZoneResourceId string = privateDnsZonesDefinition.?containerAppsZoneId ?? (varDeployPdnsAndPe && !varUseExistingPdz.containerApps
  ? privateDnsZoneContainerApps!.outputs.resourceId
  : '')

@description('Container Registry Private DNS Zone resource ID (newly created or existing).')
output acrPrivateDnsZoneResourceId string = privateDnsZonesDefinition.?acrZoneId ?? (varDeployPdnsAndPe && !varUseExistingPdz.acr
  ? privateDnsZoneAcr!.outputs.resourceId
  : '')

@description('Application Insights Private DNS Zone resource ID (newly created or existing).')
output appInsightsPrivateDnsZoneResourceId string = privateDnsZonesDefinition.?appInsightsZoneId ?? (varDeployPdnsAndPe && !varUseExistingPdz.appInsights
  ? privateDnsZoneInsights!.outputs.resourceId
  : '')

// -----------------------
// 7 NETWORKING - PRIVATE ENDPOINTS
// -----------------------

// The custom AI Foundry component creates private endpoints for:
// - AI Services account
// - AI Search
// - Storage (blob)
// - Cosmos DB (SQL)
// Avoid duplicating those private endpoints here.
var varAiFoundryManagesCorePrivateEndpoints = varDeployPdnsAndPe

// 7.1. App Configuration Private Endpoint
@description('Optional. App Configuration Private Endpoint configuration.')
param appConfigPrivateEndpointDefinition privateDnsZoneDefinitionType?

module privateEndpointAppConfig 'wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPdnsAndPe && varHasAppConfig) {
  name: 'appconfig-private-endpoint-${varUniqueSuffix}'
  params: {
    privateEndpoint: union(
      {
        name: 'pe-appcs-${baseName}'
        location: location
        tags: tags
        subnetResourceId: varPeSubnetId
        enableTelemetry: enableTelemetry
        privateLinkServiceConnections: [
          {
            name: 'appConfigConnection'
            properties: {
              privateLinkServiceId: empty(resourceIds.?appConfigResourceId!)
                ? configurationStore!.outputs.resourceId
                : existingAppConfig.id
              groupIds: ['configurationStores']
            }
          }
        ]
        privateDnsZoneGroup: {
          name: 'appConfigDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'appConfigARecord'
              privateDnsZoneResourceId: !varUseExistingPdz.appConfig
                ? privateDnsZoneAppConfig!.outputs.resourceId
                : privateDnsZonesDefinition.appConfigZoneId!
            }
          ]
        }
      },
      appConfigPrivateEndpointDefinition ?? {}
    )
  }
}

// 7.2. API Management Private Endpoint
@description('Optional. API Management Private Endpoint configuration.')
param apimPrivateEndpointDefinition privateDnsZoneDefinitionType?

// StandardV2 and Premium SKUs support Private Endpoints with gateway groupId
// Basic and Developer SKUs do not support Private Endpoints
var apimSupportsPe = contains(['StandardV2', 'Premium'], (apimDefinition.?sku ?? 'StandardV2'))

module privateEndpointApim 'wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPdnsAndPe && varHasApim && (apimDefinition.?virtualNetworkType ?? 'None') == 'None' && apimSupportsPe) {
  name: 'apim-private-endpoint-${varUniqueSuffix}'
  params: {
    privateEndpoint: union(
      {
        name: 'pe-apim-${baseName}'
        location: location
        tags: tags
        subnetResourceId: varPeSubnetId
        enableTelemetry: enableTelemetry
        privateLinkServiceConnections: [
          {
            name: 'apimGatewayConnection'
            properties: {
              privateLinkServiceId: empty(resourceIds.?apimServiceResourceId!)
                ? apiManagement!.outputs.resourceId
                : existingApim.id
              groupIds: [
                'Gateway'
              ]
            }
          }
        ]
        privateDnsZoneGroup: {
          name: 'apimDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'apimARecord'
              privateDnsZoneResourceId: !varUseExistingPdz.apim
                ? privateDnsZoneApim!.outputs.resourceId
                : privateDnsZonesDefinition.apimZoneId!
            }
          ]
        }
      },
      apimPrivateEndpointDefinition ?? {}
    )
  }
}

// 7.3. Container Apps Environment Private Endpoint
@description('Optional. Container Apps Environment Private Endpoint configuration.')
param containerAppEnvPrivateEndpointDefinition privateDnsZoneDefinitionType?

module privateEndpointContainerAppsEnv 'wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPdnsAndPe && varHasContainerEnv) {
  name: 'containerapps-env-private-endpoint-${varUniqueSuffix}'
  params: {
    privateEndpoint: union(
      {
        name: 'pe-cae-${baseName}'
        location: location
        tags: tags
        subnetResourceId: varPeSubnetId
        enableTelemetry: enableTelemetry
        privateLinkServiceConnections: [
          {
            name: 'ccaConnection'
            properties: {
              privateLinkServiceId: empty(resourceIds.?containerEnvResourceId!)
                ? containerEnv!.outputs.resourceId
                : existingContainerEnv.id
              groupIds: ['managedEnvironments']
            }
          }
        ]
        privateDnsZoneGroup: {
          name: 'ccaDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'ccaARecord'
              privateDnsZoneResourceId: !varUseExistingPdz.containerApps
                ? privateDnsZoneContainerApps!.outputs.resourceId
                : privateDnsZonesDefinition.containerAppsZoneId!
            }
          ]
        }
      },
      containerAppEnvPrivateEndpointDefinition ?? {}
    )
  }
  dependsOn: [
    #disable-next-line BCP321
    varDeployContainerAppEnv ? containerEnv : null
  ]

}

// 7.4. Azure Container Registry Private Endpoint
@description('Optional. Azure Container Registry Private Endpoint configuration.')
param acrPrivateEndpointDefinition privateDnsZoneDefinitionType?

module privateEndpointAcr 'wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPdnsAndPe && varHasAcr) {
  name: 'acr-private-endpoint-${varUniqueSuffix}'
  params: {
    privateEndpoint: union(
      {
        name: 'pe-acr-${baseName}'
        location: location
        tags: tags
        subnetResourceId: varPeSubnetId
        enableTelemetry: enableTelemetry
        privateLinkServiceConnections: [
          {
            name: 'acrConnection'
            properties: {
              privateLinkServiceId: varAcrResourceId
              groupIds: ['registry']
            }
          }
        ]
        privateDnsZoneGroup: {
          name: 'acrDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'acrARecord'
              privateDnsZoneResourceId: !varUseExistingPdz.acr
                ? privateDnsZoneAcr!.outputs.resourceId
                : privateDnsZonesDefinition.acrZoneId!
            }
          ]
        }
      },
      acrPrivateEndpointDefinition ?? {}
    )
  }
  dependsOn: [
    #disable-next-line BCP321
    (varDeployAcr) ? containerRegistry : null
  ]
}

// 7.5. Storage Account (Blob) Private Endpoint
@description('Optional. Storage Account Private Endpoint configuration.')
param storageBlobPrivateEndpointDefinition privateDnsZoneDefinitionType?

module privateEndpointStorageBlob 'wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPdnsAndPe && varHasStorage && !varAiFoundryManagesCorePrivateEndpoints) {
  name: 'blob-private-endpoint-${varUniqueSuffix}'
  params: {
    privateEndpoint: union(
      {
        name: 'pe-st-${baseName}'
        location: location
        tags: tags
        subnetResourceId: varPeSubnetId
        enableTelemetry: enableTelemetry
        privateLinkServiceConnections: [
          {
            name: 'blobConnection'
            properties: {
              privateLinkServiceId: empty(resourceIds.?storageAccountResourceId!)
                ? storageAccount!.outputs.resourceId
                : existingStorage.id
              groupIds: ['blob']
            }
          }
        ]
        privateDnsZoneGroup: {
          name: 'blobDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'blobARecord'
              privateDnsZoneResourceId: !varUseExistingPdz.blob
                ? privateDnsZoneBlob!.outputs.resourceId
                : privateDnsZonesDefinition.blobZoneId!
            }
          ]
        }
      },
      storageBlobPrivateEndpointDefinition ?? {}
    )
  }
}

// 7.6. Cosmos DB (SQL) Private Endpoint
@description('Optional. Cosmos DB Private Endpoint configuration.')
param cosmosPrivateEndpointDefinition privateDnsZoneDefinitionType?

module privateEndpointCosmos 'wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPdnsAndPe && varHasCosmos && !varAiFoundryManagesCorePrivateEndpoints) {
  name: 'cosmos-private-endpoint-${varUniqueSuffix}'
  params: {
    privateEndpoint: union(
      {
        name: 'pe-cos-${baseName}'
        location: location
        tags: tags
        subnetResourceId: varPeSubnetId
        enableTelemetry: enableTelemetry
        privateLinkServiceConnections: [
          {
            name: 'cosmosConnection'
            properties: {
              privateLinkServiceId: deployCosmosDb ? cosmosDbModule!.outputs.resourceId : ''
              groupIds: ['Sql']
            }
          }
        ]
        privateDnsZoneGroup: {
          name: 'cosmosDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'cosmosARecord'
              privateDnsZoneResourceId: !varUseExistingPdz.cosmosSql
                ? privateDnsZoneCosmos!.outputs.resourceId
                : privateDnsZonesDefinition.cosmosSqlZoneId!
            }
          ]
        }
      },
      cosmosPrivateEndpointDefinition ?? {}
    )
  }
}

// 7.7. Azure AI Search Private Endpoint
@description('Optional. Azure AI Search Private Endpoint configuration.')
param searchPrivateEndpointDefinition privateDnsZoneDefinitionType?

module privateEndpointSearch 'wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPdnsAndPe && varHasSearch && !varAiFoundryManagesCorePrivateEndpoints) {
  name: 'search-private-endpoint-${varUniqueSuffix}'
  params: {
    privateEndpoint: union(
      {
        name: 'pe-srch-${baseName}'
        location: location
        tags: tags
        subnetResourceId: varPeSubnetId
        enableTelemetry: enableTelemetry
        privateLinkServiceConnections: [
          {
            name: 'searchConnection'
            properties: {
              privateLinkServiceId: deployAiSearch ? aiSearchModule!.outputs.resourceId : ''
              groupIds: ['searchService']
            }
          }
        ]
        privateDnsZoneGroup: {
          name: 'searchDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'searchARecord'
              privateDnsZoneResourceId: !varUseExistingPdz.search
                ? privateDnsZoneSearch!.outputs.resourceId
                : privateDnsZonesDefinition.searchZoneId!
            }
          ]
        }
      },
      searchPrivateEndpointDefinition ?? {}
    )
  }
  dependsOn: [
    #disable-next-line BCP321
    deployAiSearch ? aiSearchModule : null
    #disable-next-line BCP321
    (empty(resourceIds.?virtualNetworkResourceId!)) ? vNetworkWrapper : null
    #disable-next-line BCP321
    (varDeployPdnsAndPe && !varUseExistingPdz.search) ? privateDnsZoneSearch : null
  ]
}

// 7.8. Key Vault Private Endpoint
@description('Optional. Key Vault Private Endpoint configuration.')
param keyVaultPrivateEndpointDefinition privateDnsZoneDefinitionType?

module privateEndpointKeyVault 'wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPdnsAndPe && varHasKv) {
  name: 'kv-private-endpoint-${varUniqueSuffix}'
  params: {
    privateEndpoint: union(
      {
        name: 'pe-kv-${baseName}'
        location: location
        tags: tags
        subnetResourceId: varPeSubnetId
        enableTelemetry: enableTelemetry
        privateLinkServiceConnections: [
          {
            name: 'kvConnection'
            properties: {
              privateLinkServiceId: deployKeyVault ? keyVaultModule!.outputs.resourceId : ''
              groupIds: ['vault']
            }
          }
        ]
        privateDnsZoneGroup: {
          name: 'kvDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'kvARecord'
              privateDnsZoneResourceId: !varUseExistingPdz.keyVault
                ? privateDnsZoneKeyVault!.outputs.resourceId
                : privateDnsZonesDefinition.keyVaultZoneId!
            }
          ]
        }
      },
      keyVaultPrivateEndpointDefinition ?? {}
    )
  }
}

// -----------------------
// 8 OBSERVABILITY
// -----------------------

// Deployment variables
var varDeployLogAnalytics = empty(resourceIds.?logAnalyticsWorkspaceResourceId!) && deployToggles.logAnalytics
var varDeployAppInsights = empty(resourceIds.?appInsightsResourceId!) && deployToggles.appInsights && varHasLogAnalytics

var varHasLogAnalytics = (!empty(resourceIds.?logAnalyticsWorkspaceResourceId!)) || (varDeployLogAnalytics)

// -----------------------
// 8.1 Log Analytics Workspace
// -----------------------

@description('Conditional. Log Analytics Workspace configuration. Required if deploy.logAnalytics is true and resourceIds.logAnalyticsWorkspaceResourceId is empty.')
param logAnalyticsDefinition logAnalyticsDefinitionType?

resource existingLogAnalytics 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = if (!empty(resourceIds.?logAnalyticsWorkspaceResourceId!)) {
  name: varExistingLawName
  scope: resourceGroup(varExistingLawSubscriptionId, varExistingLawResourceGroupName)
}
var varLogAnalyticsWorkspaceResourceId = varDeployLogAnalytics
  ? logAnalytics!.outputs.resourceId
  : !empty(resourceIds.?logAnalyticsWorkspaceResourceId!) ? existingLogAnalytics.id : ''

// Naming
var varLawIdSegments = empty(resourceIds.?logAnalyticsWorkspaceResourceId!)
  ? ['']
  : split(resourceIds.logAnalyticsWorkspaceResourceId!, '/')
var varExistingLawSubscriptionId = length(varLawIdSegments) >= 3 ? varLawIdSegments[2] : ''
var varExistingLawResourceGroupName = length(varLawIdSegments) >= 5 ? varLawIdSegments[4] : ''
var varExistingLawName = length(varLawIdSegments) >= 1 ? last(varLawIdSegments) : ''
var varLawName = !empty(varExistingLawName)
  ? varExistingLawName
  : (empty(logAnalyticsDefinition.?name ?? '') ? 'log-${baseName}' : logAnalyticsDefinition!.name)

module logAnalytics 'wrappers/avm.res.operational-insights.workspace.bicep' = if (varDeployLogAnalytics) {
  name: 'deployLogAnalytics'
  params: {
    logAnalytics: union(
      {
        name: varLawName
        location: location
        enableTelemetry: enableTelemetry
        tags: tags
        dataRetention: 30
      },
      logAnalyticsDefinition ?? {}
    )
  }
}

// -----------------------
// 8.2 Application Insights
// -----------------------
@description('Conditional. Application Insights configuration. Required if deploy.appInsights is true and resourceIds.appInsightsResourceId is empty; a Log Analytics workspace must exist or be deployed.')
param appInsightsDefinition appInsightsDefinitionType?

resource existingAppInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(resourceIds.?appInsightsResourceId!)) {
  name: varExistingAIName
  scope: resourceGroup(varExistingAISubscriptionId, varExistingAIResourceGroupName)
}

var varAppiResourceId = !empty(resourceIds.?appInsightsResourceId!)
  ? existingAppInsights.id
  : (varDeployAppInsights ? appInsights!.outputs.resourceId : '')

// Naming
var varAiIdSegments = empty(resourceIds.?appInsightsResourceId!) ? [''] : split(resourceIds.appInsightsResourceId!, '/')
var varExistingAISubscriptionId = length(varAiIdSegments) >= 3 ? varAiIdSegments[2] : ''
var varExistingAIResourceGroupName = length(varAiIdSegments) >= 5 ? varAiIdSegments[4] : ''
var varExistingAIName = length(varAiIdSegments) >= 1 ? last(varAiIdSegments) : ''
var varAppiName = !empty(varExistingAIName) ? varExistingAIName : 'appi-${baseName}'

module appInsights 'wrappers/avm.res.insights.component.bicep' = if (varDeployAppInsights) {
  name: 'deployAppInsights'
  params: {
    appInsights: union(
      {
        name: varAppiName
        workspaceResourceId: varLogAnalyticsWorkspaceResourceId
        location: location
        enableTelemetry: enableTelemetry
        tags: tags
        disableIpMasking: true
      },
      appInsightsDefinition ?? {}
    )
  }
}

// -----------------------
// 9 CONTAINER PLATFORM
// -----------------------

// 9.1 Container Apps Environment
var varDeployContainerAppEnv = empty(resourceIds.?containerEnvResourceId!) && deployToggles.containerEnv
var varAcaInfraSubnetId = empty(resourceIds.?virtualNetworkResourceId!)
  ? '${virtualNetworkResourceId}/subnets/aca-env-subnet'
  : '${resourceIds.virtualNetworkResourceId!}/subnets/aca-env-subnet'

@description('Conditional. Container Apps Environment configuration. Required if deploy.containerEnv is true and resourceIds.containerEnvResourceId is empty.')
param containerAppEnvDefinition containerAppEnvDefinitionType?

resource existingContainerEnv 'Microsoft.App/managedEnvironments@2025-02-02-preview' existing = if (!empty(resourceIds.?containerEnvResourceId!)) {
  name: varExistingEnvName
  scope: resourceGroup(varExistingEnvSubscriptionId, varExistingEnvResourceGroup)
}

var varContainerEnvResourceId = !empty(resourceIds.?containerEnvResourceId!)
  ? existingContainerEnv.id
  : (varDeployContainerAppEnv ? containerEnv!.outputs.resourceId : '')

// Naming
var varEnvIdSegments = empty(resourceIds.?containerEnvResourceId!)
  ? ['']
  : split(resourceIds.containerEnvResourceId!, '/')
var varExistingEnvSubscriptionId = length(varEnvIdSegments) >= 3 ? varEnvIdSegments[2] : ''
var varExistingEnvResourceGroup = length(varEnvIdSegments) >= 5 ? varEnvIdSegments[4] : ''
var varExistingEnvName = length(varEnvIdSegments) >= 1 ? last(varEnvIdSegments) : ''
var varContainerEnvName = !empty(resourceIds.?containerEnvResourceId!)
  ? varExistingEnvName
  : (empty(containerAppEnvDefinition.?name ?? '') ? 'cae-${baseName}' : containerAppEnvDefinition!.name)

module containerEnv 'wrappers/avm.res.app.managed-environment.bicep' = if (varDeployContainerAppEnv) {
  name: 'deployContainerEnv'
  params: {
    containerAppEnv: union(
      {
        name: varContainerEnvName
        location: location
        enableTelemetry: enableTelemetry
        tags: tags

        // Keep only the profile you actually use (or omit to inherit module default)
        workloadProfiles: [
          {
            workloadProfileType: 'D4'
            name: 'default'
            minimumCount: 1
            maximumCount: 3
          }
        ]

        infrastructureSubnetResourceId: !empty(varAcaInfraSubnetId) ? varAcaInfraSubnetId : null
        internal: false
        publicNetworkAccess: 'Disabled'
        zoneRedundant: true

        // Application Insights integration
        appInsightsConnectionString: varDeployAppInsights ? appInsights!.outputs.connectionString : ''
      },
      containerAppEnvDefinition ?? {}
    )
  }
  dependsOn: [
    #disable-next-line BCP321
    (empty(resourceIds.?virtualNetworkResourceId!)) ? vNetworkWrapper : null
    #disable-next-line BCP321
    (empty(resourceIds.?logAnalyticsWorkspaceResourceId!)) ? logAnalytics : null
  ]
}

// 9.2 Container Registry
var varDeployAcr = empty(resourceIds.?containerRegistryResourceId!) && deployToggles.containerRegistry

@description('Conditional. Container Registry configuration. Required if deploy.containerRegistry is true and resourceIds.containerRegistryResourceId is empty.')
param containerRegistryDefinition containerRegistryDefinitionType?

resource existingAcr 'Microsoft.ContainerRegistry/registries@2025-04-01' existing = if (!empty(resourceIds.?containerRegistryResourceId!)) {
  name: varExistingAcrName
  scope: resourceGroup(varExistingAcrSub, varExistingAcrRg)
}

var varAcrResourceId = !empty(resourceIds.?containerRegistryResourceId!)
  ? existingAcr.id
  : (varDeployAcr ? containerRegistry!.outputs.resourceId : '')

// Naming
var varAcrIdSegments = empty(resourceIds.?containerRegistryResourceId!)
  ? ['']
  : split(resourceIds.containerRegistryResourceId!, '/')
var varExistingAcrSub = length(varAcrIdSegments) >= 3 ? varAcrIdSegments[2] : ''
var varExistingAcrRg = length(varAcrIdSegments) >= 5 ? varAcrIdSegments[4] : ''
var varExistingAcrName = length(varAcrIdSegments) >= 1 ? last(varAcrIdSegments) : ''
var varAcrName = !empty(resourceIds.?containerRegistryResourceId!)
  ? varExistingAcrName
  : (empty(containerRegistryDefinition.?name!) ? 'cr${baseName}' : containerRegistryDefinition!.name!)

module containerRegistry 'wrappers/avm.res.container-registry.registry.bicep' = if (varDeployAcr) {
  name: 'deployContainerRegistry'
  params: {
    acr: union(
      {
        name: varAcrName
        location: containerRegistryDefinition.?location ?? location
        enableTelemetry: containerRegistryDefinition.?enableTelemetry ?? enableTelemetry
        tags: containerRegistryDefinition.?tags ?? tags
        publicNetworkAccess: containerRegistryDefinition.?publicNetworkAccess ?? 'Disabled'
        acrSku: containerRegistryDefinition.?acrSku ?? 'Premium'
      },
      containerRegistryDefinition ?? {}
    )
  }
}

// 9.3 Container Apps
@description('Optional. List of Container Apps to create.')
param containerAppsList containerAppDefinitionType[] = []

var varDeployContainerApps = !empty(containerAppsList) && (varDeployContainerAppEnv || !empty(resourceIds.?containerEnvResourceId!))

@batchSize(4)
module containerApps 'wrappers/avm.res.app.container-app.bicep' = [
  for (app, index) in containerAppsList: if (varDeployContainerApps) {
    name: 'ca-${app.name}-${varUniqueSuffix}'
    params: {
      containerApp: union(
        {
          name: app.name
          environmentResourceId: !empty(resourceIds.?containerEnvResourceId!)
            ? resourceIds.containerEnvResourceId!
            : containerEnv!.outputs.resourceId
          workloadProfileName: 'default'
          location: location
          tags: tags
        },
        app
      )
    }
    dependsOn: [
      #disable-next-line BCP321
      (empty(resourceIds.?containerEnvResourceId!)) ? containerEnv : null
      #disable-next-line BCP321
      (varDeployPdnsAndPe && !varUseExistingPdz.containerApps && varHasContainerEnv)
        ? privateDnsZoneContainerApps
        : null
      #disable-next-line BCP321
      (varDeployPdnsAndPe && varHasContainerEnv) ? privateEndpointContainerAppsEnv : null
    ]
  }
]

// -----------------------
// 10 STORAGE
// -----------------------

// 10.1 Storage Account
var varDeploySa = empty(resourceIds.?storageAccountResourceId!) && deployToggles.storageAccount

@description('Conditional. Storage Account configuration. Required if deploy.storageAccount is true and resourceIds.storageAccountResourceId is empty.')
param storageAccountDefinition storageAccountDefinitionType?

resource existingStorage 'Microsoft.Storage/storageAccounts@2025-01-01' existing = if (!empty(resourceIds.?storageAccountResourceId!)) {
  name: varExistingSaName
  scope: resourceGroup(varExistingSaSub, varExistingSaRg)
}

var varSaResourceId = !empty(resourceIds.?storageAccountResourceId!)
  ? existingStorage.id
  : (varDeploySa ? storageAccount!.outputs.resourceId : '')

// Naming
var varSaIdSegments = empty(resourceIds.?storageAccountResourceId!)
  ? ['']
  : split(resourceIds.storageAccountResourceId!, '/')
var varExistingSaSub = length(varSaIdSegments) >= 3 ? varSaIdSegments[2] : ''
var varExistingSaRg = length(varSaIdSegments) >= 5 ? varSaIdSegments[4] : ''
var varExistingSaName = length(varSaIdSegments) >= 1 ? last(varSaIdSegments) : ''
var varSaName = !empty(resourceIds.?storageAccountResourceId!)
  ? varExistingSaName
  : (empty(storageAccountDefinition.?name!) ? 'st${baseName}' : storageAccountDefinition!.name!)

module storageAccount 'wrappers/avm.res.storage.storage-account.bicep' = if (varDeploySa) {
  name: 'deployStorageAccount'
  params: {
    storageAccount: union(
      {
        name: varSaName
        location: storageAccountDefinition.?location ?? location
        enableTelemetry: storageAccountDefinition.?enableTelemetry ?? enableTelemetry
        tags: storageAccountDefinition.?tags ?? tags
        kind: storageAccountDefinition.?kind ?? 'StorageV2'
        skuName: storageAccountDefinition.?skuName ?? 'Standard_LRS'
        publicNetworkAccess: storageAccountDefinition.?publicNetworkAccess ?? 'Disabled'
      },
      storageAccountDefinition ?? {}
    )
  }
}

// -----------------------
// 11 APPLICATION CONFIGURATION
// -----------------------

// 11.1 App Configuration Store
var varDeployAppConfig = empty(resourceIds.?appConfigResourceId!) && deployToggles.appConfig

@description('Conditional. App Configuration store settings. Required if deploy.appConfig is true and resourceIds.appConfigResourceId is empty.')
param appConfigurationDefinition appConfigurationDefinitionType?

#disable-next-line no-unused-existing-resources
resource existingAppConfig 'Microsoft.AppConfiguration/configurationStores@2024-06-01' existing = if (!empty(resourceIds.?appConfigResourceId!)) {
  name: varExistingAppcsName
  scope: resourceGroup(varExistingAppcsSub, varExistingAppcsRg)
}

// Naming
var varAppcsIdSegments = empty(resourceIds.?appConfigResourceId!) ? [''] : split(resourceIds.appConfigResourceId!, '/')
var varExistingAppcsSub = length(varAppcsIdSegments) >= 3 ? varAppcsIdSegments[2] : ''
var varExistingAppcsRg = length(varAppcsIdSegments) >= 5 ? varAppcsIdSegments[4] : ''
var varExistingAppcsName = length(varAppcsIdSegments) >= 1 ? last(varAppcsIdSegments) : ''
var varAppConfigName = !empty(resourceIds.?appConfigResourceId!)
  ? varExistingAppcsName
  : (empty(appConfigurationDefinition.?name ?? '') ? 'appcs-${baseName}' : appConfigurationDefinition!.name)

module configurationStore 'wrappers/avm.res.app-configuration.configuration-store.bicep' = if (varDeployAppConfig) {
  name: 'configurationStoreDeploymentFixed'
  params: {
    appConfiguration: union(
      {
        name: varAppConfigName
        location: location
        enableTelemetry: enableTelemetry
        tags: tags
      },
      appConfigurationDefinition ?? {}
    )
  }
}

// -----------------------
// 12 COSMOS DB
// -----------------------
@description('Optional. Cosmos DB settings.')
param cosmosDbDefinition genAIAppCosmosDbDefinitionType?

var deployCosmosDb = cosmosDbDefinition != null

module cosmosDbModule 'wrappers/avm.res.document-db.database-account.bicep' = if (deployCosmosDb) {
  name: 'cosmosDbModule'
  params: {
    cosmosDb: union(
      {
        name: 'cosmos-${baseName}'
        location: location
      },
      cosmosDbDefinition ?? {}
    )
  }
}

// -----------------------
// 13 KEY VAULT
// -----------------------
@description('Optional. Key Vault settings.')
param keyVaultDefinition keyVaultDefinitionType?

var deployKeyVault = keyVaultDefinition != null

module keyVaultModule 'wrappers/avm.res.key-vault.vault.bicep' = if (deployKeyVault) {
  name: 'keyVaultModule'
  params: {
    keyVault: union(
      {
        name: 'kv-${baseName}'
        location: location
      },
      keyVaultDefinition ?? {}
    )
  }
}

// -----------------------
// 14 AI SEARCH
// -----------------------
@description('Optional. AI Search settings.')
param aiSearchDefinition kSAISearchDefinitionType?

var deployAiSearch = aiSearchDefinition != null

module aiSearchModule 'wrappers/avm.res.search.search-service.bicep' = if (deployAiSearch) {
  name: 'aiSearchModule'
  params: {
    aiSearch: union(
      {
        name: empty(aiSearchDefinition!.?name!) ? 'search-${baseName}' : aiSearchDefinition!.name!
        location: aiSearchDefinition!.?location ?? location
      },
      aiSearchDefinition!
    )
  }
}

// -----------------------
// 15 API MANAGEMENT
// -----------------------

@description('Optional. API Management configuration.')
param apimDefinition apimDefinitionType?

// 15.1. API Management Service
var varDeployApim = empty(resourceIds.?apimServiceResourceId!) && deployToggles.apiManagement

// Naming
var varApimIdSegments = empty(resourceIds.?apimServiceResourceId!)
  ? ['']
  : split(resourceIds.apimServiceResourceId!, '/')
var varApimSub = length(varApimIdSegments) >= 3 ? varApimIdSegments[2] : ''
var varApimRg = length(varApimIdSegments) >= 5 ? varApimIdSegments[4] : ''
var varApimNameExisting = length(varApimIdSegments) >= 1 ? last(varApimIdSegments) : ''

resource existingApim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = if (!empty(resourceIds.?apimServiceResourceId!)) {
  name: varApimNameExisting
  scope: resourceGroup(varApimSub, varApimRg)
}

var varApimServiceResourceId = !empty(resourceIds.?apimServiceResourceId!)
  ? existingApim.id
  : (varDeployApim ? apiManagement!.outputs.resourceId : '')

#disable-next-line BCP081
module apiManagement 'wrappers/avm.res.api-management.service.bicep' = if (varDeployApim) {
  name: 'apimDeployment'
  params: {
    apiManagement: union(
      {
        // Required properties
        name: 'apim-${baseName}'
        publisherEmail: 'admin@contoso.com'
        publisherName: 'Contoso'

        // Premium SKU configuration for Internal VNet mode
        // Premium supports full VNet integration with Internal mode
        // Allows complete network isolation without exposing public endpoints
        sku: 'Premium'
        skuCapacity: 3

        // Network Configuration - Internal VNet mode
        // Internal mode: APIM accessible only from within VNet via private IP
        // Requires Premium SKU (StandardV2 does NOT support Internal mode)
        virtualNetworkType: 'Internal'
        subnetResourceId: varApimSubnetId 

        // Basic Configuration
        location: location
        tags: tags
        enableTelemetry: enableTelemetry

        // API Management Configuration
        minApiVersion: '2022-08-01'
      },
      apimDefinition ?? {}
    )
  }
}

// -----------------------
// 16 AI FOUNDRY
// -----------------------

// AI Foundry

@description('Optional. AI Foundry project configuration (account/project, networking, associated resources, and deployments).')
param aiFoundryDefinition aiFoundryDefinitionType = {
  // Required
  baseName: baseName
}

var varAiFoundryModelDeploymentsMapped = [
  for d in (aiFoundryDefinition.?aiModelDeployments ?? []): {
    name: string(d.?name ?? d.model.name)
    modelName: string(d.model.name)
    modelFormat: string(d.model.format)
    modelVersion: string(d.model.version)
    modelSkuName: string(d.sku.name)
    modelCapacity: int(d.sku.capacity ?? 1)
  }
]

var varAiFoundryModelDeployments = empty(varAiFoundryModelDeploymentsMapped)
  ? [
      {
        name: 'gpt-4o'
        modelName: 'gpt-4o'
        modelFormat: 'OpenAI'
        modelVersion: '2024-11-20'
        modelSkuName: 'GlobalStandard'
        modelCapacity: 10
      }
      {
        name: 'text-embedding-3-large'
        modelName: 'text-embedding-3-large'
        modelFormat: 'OpenAI'
        modelVersion: '1'
        modelSkuName: 'Standard'
        modelCapacity: 1
      }
    ]
  : varAiFoundryModelDeploymentsMapped

var varAiFoundryAiSearchResourceId = !empty(resourceIds.?searchServiceResourceId!)
  ? resourceIds.searchServiceResourceId!
  : (deployAiSearch ? aiSearchModule!.outputs.resourceId : '')

var varAiFoundryStorageResourceId = varSaResourceId

var varAiFoundryCosmosResourceId = deployCosmosDb ? cosmosDbModule!.outputs.resourceId : ''

var varAiFoundryCurrentRgName = resourceGroup().name
var varAiFoundryExistingDnsZones = {
  'privatelink.services.ai.azure.com': varDeployPdnsAndPe ? (varUseExistingPdz.aiServices ? split(privateDnsZonesDefinition.aiServicesZoneId!, '/')[4] : varAiFoundryCurrentRgName) : ''
  'privatelink.openai.azure.com': varDeployPdnsAndPe ? (varUseExistingPdz.openai ? split(privateDnsZonesDefinition.openaiZoneId!, '/')[4] : varAiFoundryCurrentRgName) : ''
  'privatelink.cognitiveservices.azure.com': varDeployPdnsAndPe ? (varUseExistingPdz.cognitiveservices ? split(privateDnsZonesDefinition.cognitiveservicesZoneId!, '/')[4] : varAiFoundryCurrentRgName) : ''
  'privatelink.search.windows.net': varDeployPdnsAndPe ? (varUseExistingPdz.search ? split(privateDnsZonesDefinition.searchZoneId!, '/')[4] : varAiFoundryCurrentRgName) : ''
  'privatelink.blob.${environment().suffixes.storage}': varDeployPdnsAndPe ? (varUseExistingPdz.blob ? split(privateDnsZonesDefinition.blobZoneId!, '/')[4] : varAiFoundryCurrentRgName) : ''
  'privatelink.documents.azure.com': varDeployPdnsAndPe ? (varUseExistingPdz.cosmosSql ? split(privateDnsZonesDefinition.cosmosSqlZoneId!, '/')[4] : varAiFoundryCurrentRgName) : ''
}

module aiFoundry 'components/ai-foundry/main.bicep' = {
  name: 'aiFoundryDeployment-${varUniqueSuffix}'
  params: {
    location: location

    // Prefix used by the custom component to build names (it appends a short suffix internally).
    aiServices: 'ai${baseName}'

    firstProjectName: aiFoundryDefinition.?aiFoundryConfiguration.?project.?name ?? 'aifoundry-default-project'
    projectDescription: aiFoundryDefinition.?aiFoundryConfiguration.?project.?description ?? 'This is the default project for AI Foundry.'
    displayName: aiFoundryDefinition.?aiFoundryConfiguration.?project.?displayName ?? 'Default AI Foundry Project.'

    // Reuse landing zone networking; do not create/update subnets here.
    existingVnetResourceId: virtualNetworkResourceId
    vnetName: varVnetName
    agentSubnetName: 'agent-subnet'
    peSubnetName: 'pe-subnet'
    deployVnetAndSubnets: false

    // Reuse resources created by this template when present; otherwise the custom component can create them.
    aiSearchResourceId: varAiFoundryAiSearchResourceId
    azureStorageAccountResourceId: varAiFoundryStorageResourceId
    azureCosmosDBAccountResourceId: varAiFoundryCosmosResourceId

    // Private networking integration
    deployPrivateEndpointsAndDns: varDeployPdnsAndPe
    existingDnsZones: varAiFoundryExistingDnsZones

    // Model deployments
    modelDeployments: varAiFoundryModelDeployments
  }
  dependsOn: [
    #disable-next-line BCP321
    deployAiSearch ? aiSearchModule : null
    #disable-next-line BCP321
    varDeploySa ? storageAccount : null
    #disable-next-line BCP321
    deployCosmosDb ? cosmosDbModule : null
    #disable-next-line BCP321
    (empty(resourceIds.?virtualNetworkResourceId!)) ? vNetworkWrapper : null
    #disable-next-line BCP321
    (varDeployPdnsAndPe && !varUseExistingPdz.search) ? privateDnsZoneSearch : null
    #disable-next-line BCP321
    (varDeployPdnsAndPe && !varUseExistingPdz.blob) ? privateDnsZoneBlob : null
    #disable-next-line BCP321
    (varDeployPdnsAndPe && !varUseExistingPdz.cosmosSql) ? privateDnsZoneCosmos : null
    #disable-next-line BCP321
    (varDeployPdnsAndPe && !varUseExistingPdz.cognitiveservices) ? privateDnsZoneCogSvcs : null
    #disable-next-line BCP321
    (varDeployPdnsAndPe && !varUseExistingPdz.openai) ? privateDnsZoneOpenAi : null
    #disable-next-line BCP321
    (varDeployPdnsAndPe && !varUseExistingPdz.aiServices) ? privateDnsZoneAiService : null
  ]
}

// -----------------------
// 17 BING GROUNDING
// -----------------------

// Grounding with Bing
@description('Conditional. Grounding with Bing configuration. Required if deploy.groundingWithBingSearch is true and resourceIds.groundingServiceResourceId is empty.')
param groundingWithBingDefinition kSGroundingWithBingDefinitionType?

// Decide if Bing module runs (create or reuse+connect)
var varInvokeBingModule = (!empty(resourceIds.?groundingServiceResourceId!)) || (deployToggles.groundingWithBingSearch && empty(resourceIds.?groundingServiceResourceId!))

var varBingNameEffective = empty(groundingWithBingDefinition!.?name!)
  ? 'bing-${baseName}'
  : groundingWithBingDefinition!.name!

// Run this module when:
//  - creating a new Bing account (toggle true, no existing), OR
//  - reusing an existing account (existing ID provided) but we still need to create the CS connection.
module bingSearch 'components/bing-search/main.bicep' = if (varInvokeBingModule) {
  name: 'bingsearchDeployment'
  params: {
    // AF context from the AVM/Foundry module outputs
    accountName: aiFoundry.outputs.aiServicesName
    projectName: aiFoundry.outputs.aiProjectName

    // Deterministic default for the Bing account (only used on create path)
    bingSearchName: varBingNameEffective

    // Reuse path: when provided, the child module will NOT create the Bing account,
    // it will use this existing one and still create the connection.
    existingResourceId: resourceIds.?groundingServiceResourceId ?? ''
  }
  dependsOn: [
    aiFoundry!
  ]
}

// -----------------------
// 18 GATEWAYS AND FIREWALL
// -----------------------

// 18.1 Web Application Firewall (WAF) Policy
@description('Conditional. Web Application Firewall (WAF) policy configuration. Required if deploy.wafPolicy is true and you are deploying Application Gateway via this template.')
param wafPolicyDefinition wafPolicyDefinitionsType?

var varDeployWafPolicy = deployToggles.wafPolicy
var varWafPolicyResourceId = varDeployWafPolicy ? wafPolicy!.outputs.resourceId : '' // cache resourceId for AGW wiring

module wafPolicy 'wrappers/avm.res.network.waf-policy.bicep' = if (varDeployWafPolicy) {
  name: 'wafPolicyDeployment'
  params: {
    wafPolicy: union(
      {
        // Required
        name: 'afwp-${baseName}'
        managedRules: {
          exclusions: []
          managedRuleSets: [
            {
              ruleSetType: 'OWASP'
              ruleSetVersion: '3.2'
              ruleGroupOverrides: []
            }
          ]
        }
        location: location
        tags: tags
      },
      wafPolicyDefinition ?? {}
    )
  }
}

// 18.2 Application Gateway
@description('Conditional. Application Gateway configuration. Required if deploy.applicationGateway is true and resourceIds.applicationGatewayResourceId is empty.')
param appGatewayDefinition appGatewayDefinitionType?

var varDeployAppGateway = empty(resourceIds.?applicationGatewayResourceId!) && deployToggles.applicationGateway

resource existingAppGateway 'Microsoft.Network/applicationGateways@2024-07-01' existing = if (!empty(resourceIds.?applicationGatewayResourceId!)) {
  name: varAgwNameExisting
  scope: resourceGroup(varAgwSub, varAgwRg)
}

var varAppGatewayResourceId = !empty(resourceIds.?applicationGatewayResourceId!)
  ? existingAppGateway.id
  : (varDeployAppGateway ? applicationGateway!.outputs.resourceId : '')

// Naming
var varAgwIdSegments = empty(resourceIds.?applicationGatewayResourceId!)
  ? ['']
  : split(resourceIds.applicationGatewayResourceId!, '/')
var varAgwSub = length(varAgwIdSegments) >= 3 ? varAgwIdSegments[2] : ''
var varAgwRg = length(varAgwIdSegments) >= 5 ? varAgwIdSegments[4] : ''
var varAgwNameExisting = length(varAgwIdSegments) >= 1 ? last(varAgwIdSegments) : ''
var varAgwName = !empty(resourceIds.?applicationGatewayResourceId!)
  ? varAgwNameExisting
  : (empty(appGatewayDefinition.?name ?? '') ? 'agw-${baseName}' : appGatewayDefinition!.name)

// Determine if we need to create a WAF policy
var varAppGatewaySKU = appGatewayDefinition.?sku ?? 'WAF_v2'
var varAppGatewayNeedFirewallPolicy = (varAppGatewaySKU == 'WAF_v2')
var varAppGatewayFirewallPolicyId = (varAppGatewayNeedFirewallPolicy ? varWafPolicyResourceId : '')

// Application Gateway subnet ID
var varAgwSubnetId = empty(resourceIds.?virtualNetworkResourceId!)
  ? '${virtualNetworkResourceId}/subnets/appgw-subnet'
  : '${resourceIds.virtualNetworkResourceId!}/subnets/appgw-subnet'

module applicationGateway 'wrappers/avm.res.network.application-gateway.bicep' = if (varDeployAppGateway) {
  name: 'applicationGatewayDeployment'
  params: {
    applicationGateway: union(
      {
        // Required parameters with defaults
        name: varAgwName
        sku: varAppGatewaySKU

        // Gateway IP configurations - required for Application Gateway
        gatewayIPConfigurations: [
          {
            name: 'appGatewayIpConfig'
            properties: {
              subnet: {
                id: varAgwSubnetId
              }
            }
          }
        ]

        // WAF policy wiring
        firewallPolicyResourceId: varAppGatewayFirewallPolicyId

        // Location and tags
        location: location
        tags: tags

        // Frontend IP configurations - default configuration
        frontendIPConfigurations: concat(
          varDeployApGatewayPip
            ? [
                {
                  name: 'publicFrontend'
                  properties: { publicIPAddress: { id: appGatewayPipWrapper!.outputs.resourceId } }
                }
              ]
            : [],
          [
            {
              name: 'privateFrontend'
              properties: {
                privateIPAllocationMethod: 'Static'
                privateIPAddress: '192.168.0.200'
                subnet: { id: varAgwSubnetId }
              }
            }
          ]
        )

        // Frontend ports - required for Application Gateway
        frontendPorts: [
          {
            name: 'port80'
            properties: { port: 80 }
          }
        ]

        // Backend address pools - required for Application Gateway
        backendAddressPools: [
          {
            name: 'defaultBackendPool'
          }
        ]

        // Backend HTTP settings - required for Application Gateway
        backendHttpSettingsCollection: [
          {
            name: 'defaultHttpSettings'
            properties: {
              cookieBasedAffinity: 'Disabled'
              port: 80
              protocol: 'Http'
              requestTimeout: 20
            }
          }
        ]

        // HTTP listeners - required for Application Gateway
        httpListeners: [
          {
            name: 'httpListener'
            properties: {
              frontendIPConfiguration: {
                id: '${resourceId('Microsoft.Network/applicationGateways', varAgwName)}/frontendIPConfigurations/${varDeployApGatewayPip ? 'publicFrontend' : 'privateFrontend'}'
              }
              frontendPort: {
                id: '${resourceId('Microsoft.Network/applicationGateways', varAgwName)}/frontendPorts/port80'
              }
              protocol: 'Http'
            }
          }
        ]

        // Request routing rules - required for Application Gateway
        requestRoutingRules: [
          {
            name: 'httpRoutingRule'
            properties: {
              backendAddressPool: {
                id: '${resourceId('Microsoft.Network/applicationGateways', varAgwName)}/backendAddressPools/defaultBackendPool'
              }
              backendHttpSettings: {
                id: '${resourceId('Microsoft.Network/applicationGateways', varAgwName)}/backendHttpSettingsCollection/defaultHttpSettings'
              }
              httpListener: {
                id: '${resourceId('Microsoft.Network/applicationGateways', varAgwName)}/httpListeners/httpListener'
              }
              priority: 100
              ruleType: 'Basic'
            }
          }
        ]
      },
      appGatewayDefinition ?? {}
    )
    enableTelemetry: enableTelemetry
  }
  dependsOn: [
    #disable-next-line BCP321
    (varDeployWafPolicy) ? wafPolicy : null
    #disable-next-line BCP321
    (varDeployApGatewayPip) ? appGatewayPipWrapper : null
    #disable-next-line BCP321
    (empty(resourceIds.?virtualNetworkResourceId!)) ? vNetworkWrapper : null
  ]
}

// 18.3 Azure Firewall Policy
@description('Conditional. Azure Firewall Policy configuration. Required if deploy.firewall is true and resourceIds.firewallPolicyResourceId is empty.')
param firewallPolicyDefinition firewallPolicyDefinitionType?

var varDeployAfwPolicy = deployToggles.firewall && empty(resourceIds.?firewallPolicyResourceId!)

module fwPolicy 'wrappers/avm.res.network.firewall-policy.bicep' = if (varDeployAfwPolicy) {
  name: 'firewallPolicyDeployment'
  params: {
    firewallPolicy: union(
      {
        // Required
        name: empty(firewallPolicyDefinition.?name ?? '') ? 'afwp-${baseName}' : firewallPolicyDefinition!.name
        location: location
        tags: tags
      },
      firewallPolicyDefinition ?? {}
    )
    enableTelemetry: enableTelemetry
  }
}

var firewallPolicyResourceId = resourceIds.?firewallPolicyResourceId ?? (varDeployAfwPolicy
  ? fwPolicy!.outputs.resourceId
  : '')

// 18.4 Azure Firewall
@description('Conditional. Azure Firewall configuration. Required if deploy.firewall is true and resourceIds.firewallResourceId is empty.')
param firewallDefinition firewallDefinitionType?

var varDeployFirewall = empty(resourceIds.?firewallResourceId!) && deployToggles.firewall

resource existingFirewall 'Microsoft.Network/azureFirewalls@2024-07-01' existing = if (!empty(resourceIds.?firewallResourceId!)) {
  name: varAfwNameExisting
  scope: resourceGroup(varAfwSub, varAfwRg)
}

var varFirewallResourceId = !empty(resourceIds.?firewallResourceId!)
  ? existingFirewall.id
  : (varDeployFirewall ? azureFirewall!.outputs.resourceId : '')

// Naming
var varAfwIdSegments = empty(resourceIds.?firewallResourceId!) ? [''] : split(resourceIds.firewallResourceId!, '/')
var varAfwSub = length(varAfwIdSegments) >= 3 ? varAfwIdSegments[2] : ''
var varAfwRg = length(varAfwIdSegments) >= 5 ? varAfwIdSegments[4] : ''
var varAfwNameExisting = length(varAfwIdSegments) >= 1 ? last(varAfwIdSegments) : ''
var varAfwName = !empty(resourceIds.?firewallResourceId!)
  ? varAfwNameExisting
  : (empty(firewallDefinition.?name ?? '') ? 'afw-${baseName}' : firewallDefinition!.name)

module azureFirewall 'wrappers/avm.res.network.azure-firewall.bicep' = if (varDeployFirewall) {
  name: 'azureFirewallDeployment'
  params: {
    firewall: union(
      {
        // Required
        name: varAfwName

        // Network configuration - conditional based on resource availability
        virtualNetworkResourceId: varVnetResourceId

        // Public IP configuration - use existing or deployed IP
        publicIPResourceID: !empty(resourceIds.?firewallPublicIpResourceId)
          ? resourceIds.firewallPublicIpResourceId!
          : firewallPublicIpResourceId

        // Firewall Policy - use existing or deployed policy
        firewallPolicyId: firewallPolicyResourceId

        // Default configuration
        availabilityZones: [1, 2, 3]
        azureSkuTier: 'Standard'
        location: location
        tags: tags
      },
      firewallDefinition ?? {}
    )
    enableTelemetry: enableTelemetry
  }
  dependsOn: [
    // Firewall Policy dependency
    #disable-next-line BCP321
    varDeployAfwPolicy ? fwPolicy : null
    // Public IP dependency
    #disable-next-line BCP321
    varDeployFirewallPip ? firewallPipWrapper : null
    // Virtual Network dependency
    #disable-next-line BCP321
    empty(resourceIds.?virtualNetworkResourceId!) ? vNetworkWrapper : null
  ]
}

// -----------------------
// 19 VIRTUAL MACHINES
// -----------------------

// 19.1 Build VM (Linux)
@description('Conditional. Build VM configuration to support CI/CD workers (Linux). Required if deploy.buildVm is true.')
param buildVmDefinition vmDefinitionType?

@description('Optional. Build VM Maintenance Definition. Used when deploy.buildVm is true.')
param buildVmMaintenanceDefinition vmMaintenanceDefinitionType?

// Generates a 23-character password: [8 UPPERCASE hex][8 lowercase hex]@[4 mixed hex]! using newGuid()
@description('Optional. Auto-generated random password for Build VM. Do not override unless necessary.')
@secure()
param buildVmAdminPassword string = '${toUpper(substring(replace(newGuid(), '-', ''), 0, 8))}${toLower(substring(replace(newGuid(), '-', ''), 8, 8))}@${substring(replace(newGuid(), '-', ''), 16, 4)}!'

var varDeployBuildVm = deployToggles.?buildVm ?? false
var varBuildSubnetId = empty(resourceIds.?virtualNetworkResourceId!)
  ? '${virtualNetworkResourceId}/subnets/agent-subnet'
  : '${resourceIds.virtualNetworkResourceId!}/subnets/agent-subnet'

module buildVmMaintenanceConfiguration 'wrappers/avm.res.maintenance.maintenance-configuration.bicep' = if (varDeployBuildVm) {
  name: 'buildVmMaintenanceConfigurationDeployment-${varUniqueSuffix}'
  params: {
    maintenanceConfig: union(
      {
        name: 'mc-${baseName}-build'
        location: location
        tags: tags
      },
      buildVmMaintenanceDefinition ?? {}
    )
  }
}

module buildVm 'wrappers/avm.res.compute.build-vm.bicep' = if (varDeployBuildVm) {
  name: 'buildVmDeployment-${varUniqueSuffix}'
  params: {
    buildVm: union(
      {
        // Required parameters
        name: 'vm-${substring(baseName, 0, 6)}-bld' // Shorter name to avoid length limits
        sku: 'Standard_F4s_v2'
        adminUsername: 'builduser'
        osType: 'Linux'
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts'
          version: 'latest'
        }
        runner: 'github' // Default runner type
        github: {
          owner: 'your-org'
          repo: 'your-repo'
        }
        nicConfigurations: [
          {
            nicSuffix: '-nic'
            ipConfigurations: [
              {
                name: 'ipconfig01'
                subnetResourceId: varBuildSubnetId
              }
            ]
          }
        ]
        osDisk: {
          caching: 'ReadWrite'
          createOption: 'FromImage'
          deleteOption: 'Delete'
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
        // Linux-specific configuration - using password authentication like Jump VM
        disablePasswordAuthentication: false
        adminPassword: buildVmAdminPassword
        // Infrastructure parameters
        availabilityZone: 1 // Set availability zone directly in VM configuration
        location: location
        tags: tags
        enableTelemetry: enableTelemetry
      },
      buildVmDefinition ?? {}
    )
  }
  dependsOn: [
    #disable-next-line BCP321
    (empty(resourceIds.?virtualNetworkResourceId!)) ? vNetworkWrapper : null
  ]
}

// 19.2 Jump VM (Windows)
@description('Conditional. Jump (bastion) VM configuration (Windows). Required if deploy.jumpVm is true.')
param jumpVmDefinition vmDefinitionType?

@description('Optional. Jump VM Maintenance Definition. Used when deploy.jumpVm is true.')
param jumpVmMaintenanceDefinition vmMaintenanceDefinitionType?

// Generates a 23-character password: [8 UPPERCASE hex][8 lowercase hex]@[4 mixed hex]! using newGuid()
@description('Optional. Auto-generated random password for Jump VM. Do not override unless necessary.')
@secure()
param jumpVmAdminPassword string = '${toUpper(substring(replace(newGuid(), '-', ''), 0, 8))}${toLower(substring(replace(newGuid(), '-', ''), 8, 8))}@${substring(replace(newGuid(), '-', ''), 16, 4)}!'

var varDeployJumpVm = deployToggles.?jumpVm ?? false
var varJumpVmMaintenanceConfigured = varDeployJumpVm && (jumpVmMaintenanceDefinition != null)
var varJumpSubnetId = empty(resourceIds.?virtualNetworkResourceId!)
  ? '${virtualNetworkResourceId}/subnets/agent-subnet'
  : '${resourceIds.virtualNetworkResourceId!}/subnets/agent-subnet'

module jumpVmMaintenanceConfiguration 'wrappers/avm.res.maintenance.maintenance-configuration.bicep' = if (varJumpVmMaintenanceConfigured) {
  name: 'jumpVmMaintenanceConfigurationDeployment-${varUniqueSuffix}'
  params: {
    maintenanceConfig: union(
      {
        name: 'mc-${baseName}-jump'
        location: location
        tags: tags
      },
      jumpVmMaintenanceDefinition ?? {}
    )
  }
}

module jumpVm 'wrappers/avm.res.compute.jump-vm.bicep' = if (varDeployJumpVm) {
  name: 'jumpVmDeployment-${varUniqueSuffix}'
  params: {
    jumpVm: union(
      {
        // Required parameters
        name: 'vm-${substring(baseName, 0, 6)}-jmp' // Shorter name to avoid Windows 15-char limit
        sku: 'Standard_D4as_v5'
        adminUsername: 'azureuser'
        osType: 'Windows'
        imageReference: {
          publisher: 'MicrosoftWindowsServer'
          offer: 'WindowsServer'
          sku: '2022-datacenter-azure-edition'
          version: 'latest'
        }
        // Auto-generated random password
        adminPassword: jumpVmAdminPassword
        nicConfigurations: [
          {
            nicSuffix: '-nic'
            ipConfigurations: [
              {
                name: 'ipconfig01'
                subnetResourceId: varJumpSubnetId
              }
            ]
          }
        ]
        osDisk: {
          caching: 'ReadWrite'
          createOption: 'FromImage'
          deleteOption: 'Delete'
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
        // Infrastructure parameters
        ...(varJumpVmMaintenanceConfigured
          ? {
              maintenanceConfigurationResourceId: jumpVmMaintenanceConfiguration!.outputs.resourceId
            }
          : {})
        availabilityZone: 1 // Set availability zone directly in VM configuration
        location: location
        tags: tags
        enableTelemetry: enableTelemetry
      },
      jumpVmDefinition ?? {}
    )
  }
  dependsOn: [
    #disable-next-line BCP321
    (empty(resourceIds.?virtualNetworkResourceId!)) ? vNetworkWrapper : null
  ]
}

// -----------------------
// 20 OUTPUTS
// -----------------------

// Network Security Group Outputs
@description('Agent subnet Network Security Group resource ID (newly created or existing).')
output agentNsgResourceId string = agentNsgResourceId ?? ''

@description('Private Endpoints subnet Network Security Group resource ID (newly created or existing).')
output peNsgResourceId string = peNsgResourceId ?? ''

@description('Application Gateway subnet Network Security Group resource ID (newly created or existing).')
output applicationGatewayNsgResourceId string = applicationGatewayNsgResourceId

@description('API Management subnet Network Security Group resource ID (newly created or existing).')
output apiManagementNsgResourceId string = apiManagementNsgResourceId

@description('Azure Container Apps Environment subnet Network Security Group resource ID (newly created or existing).')
output acaEnvironmentNsgResourceId string = acaEnvironmentNsgResourceId

@description('Jumpbox subnet Network Security Group resource ID (newly created or existing).')
output jumpboxNsgResourceId string = jumpboxNsgResourceId

@description('DevOps Build Agents subnet Network Security Group resource ID (newly created or existing).')
output devopsBuildAgentsNsgResourceId string = devopsBuildAgentsNsgResourceId

@description('Bastion subnet Network Security Group resource ID (newly created or existing).')
output bastionNsgResourceId string = bastionNsgResourceId

// Virtual Network Outputs
@description('Virtual Network resource ID (newly created or existing).')
output virtualNetworkResourceId string = virtualNetworkResourceId

// Public IP Outputs
@description('Application Gateway Public IP resource ID (newly created or existing).')
output appGatewayPublicIpResourceId string = appGatewayPublicIpResourceId

@description('Firewall Public IP resource ID (newly created or existing).')
output firewallPublicIpResourceId string = firewallPublicIpResourceId

// VNet Peering Outputs
@description('Hub to Spoke peering resource ID (if hub peering is enabled).')
output hubToSpokePeeringResourceId string = varDeployHubPeering && (hubVnetPeeringDefinition!.?createReversePeering ?? true)
  ? hubToSpokePeering!.outputs.peeringResourceId
  : ''

// Observability Outputs
@description('Log Analytics workspace resource ID.')
output logAnalyticsWorkspaceResourceId string = varLogAnalyticsWorkspaceResourceId

@description('Application Insights resource ID.')
output appInsightsResourceId string = varAppiResourceId

// Container Platform Outputs
@description('Container App Environment resource ID.')
output containerEnvResourceId string = varContainerEnvResourceId

@description('Container Registry resource ID.')
output containerRegistryResourceId string = varAcrResourceId

// Storage Outputs
@description('Storage Account resource ID.')
output storageAccountResourceId string = varSaResourceId

// Application Configuration Outputs
@description('App Configuration Store resource ID.')
output appConfigResourceId string = !empty(resourceIds.?appConfigResourceId!)
  ? resourceIds.appConfigResourceId!
  : (varDeployAppConfig ? configurationStore!.outputs.resourceId : '')

// Cosmos DB Outputs
@description('Cosmos DB resource ID.')
output cosmosDbResourceId string = deployCosmosDb ? cosmosDbModule!.outputs.resourceId : ''

@description('Cosmos DB name.')
output cosmosDbName string = deployCosmosDb ? cosmosDbModule!.outputs.name : ''

// Key Vault Outputs
@description('Key Vault resource ID.')
output keyVaultResourceId string = deployKeyVault ? keyVaultModule!.outputs.resourceId : ''

@description('Key Vault name.')
output keyVaultName string = deployKeyVault ? keyVaultModule!.outputs.name : ''

// AI Search Outputs
@description('AI Search resource ID.')
output aiSearchResourceId string = deployAiSearch ? aiSearchModule!.outputs.resourceId : ''

@description('AI Search name.')
output aiSearchName string = deployAiSearch ? aiSearchModule!.outputs.name : ''

// API Management Outputs
@description('API Management service resource ID.')
output apimServiceResourceId string = varApimServiceResourceId

@description('API Management service name.')
output apimServiceName string = varDeployApim ? apiManagement!.outputs.name : ''

// AI Foundry Outputs
@description('AI Foundry resource group name.')
output aiFoundryResourceGroupName string = aiFoundry.outputs.resourceGroupName

@description('AI Foundry project name.')
output aiFoundryProjectName string = aiFoundry.outputs.aiProjectName

@description('AI Foundry AI Search service name.')
output aiFoundrySearchServiceName string = aiFoundry.outputs.aiSearchName

@description('AI Foundry AI Services name.')
output aiFoundryAiServicesName string = aiFoundry.outputs.aiServicesName

@description('AI Foundry Cosmos DB account name.')
output aiFoundryCosmosAccountName string = aiFoundry.outputs.cosmosAccountName

@description('AI Foundry Key Vault name.')
output aiFoundryKeyVaultName string = deployKeyVault ? keyVaultModule!.outputs.name : ''

@description('AI Foundry Storage Account name.')
output aiFoundryStorageAccountName string = aiFoundry.outputs.storageAccountName

// Bing Grounding Outputs
@description('Bing Search service resource ID (if deployed).')
output bingSearchResourceId string = varInvokeBingModule ? bingSearch!.outputs.resourceId : ''

@description('Bing Search connection ID (if deployed).')
output bingConnectionId string = varInvokeBingModule ? bingSearch!.outputs.bingConnectionId : ''

@description('Bing Search resource group name (if deployed).')
output bingResourceGroupName string = varInvokeBingModule ? bingSearch!.outputs.resourceGroupName : ''

// Gateways and Firewall Outputs
@description('WAF Policy resource ID (if deployed).')
output wafPolicyResourceId string = varDeployWafPolicy ? wafPolicy!.outputs.resourceId : ''

@description('WAF Policy name (if deployed).')
output wafPolicyName string = varDeployWafPolicy ? wafPolicy!.outputs.name : ''

@description('Application Gateway resource ID (newly created or existing).')
output applicationGatewayResourceId string = varAppGatewayResourceId

@description('Application Gateway name.')
output applicationGatewayName string = varAgwName

@description('Azure Firewall Policy resource ID (if deployed).')
output firewallPolicyResourceId string = firewallPolicyResourceId

@description('Azure Firewall Policy name (if deployed).')
output firewallPolicyName string = varDeployAfwPolicy ? fwPolicy!.outputs.name : ''

@description('Azure Firewall resource ID (newly created or existing).')
output firewallResourceId string = varFirewallResourceId

@description('Azure Firewall name.')
output firewallName string = varAfwName

@description('Azure Firewall private IP address (if deployed).')
output firewallPrivateIp string = (varDeployFirewall && varDeployAfwPolicy) ? azureFirewall!.outputs.privateIp : ''

// Virtual Machines Outputs
@description('Build VM resource ID (if deployed).')
output buildVmResourceId string = varDeployBuildVm ? buildVm!.outputs.resourceId : ''

@description('Build VM name (if deployed).')
output buildVmName string = varDeployBuildVm ? buildVm!.outputs.name : ''

@description('Jump VM resource ID (if deployed).')
output jumpVmResourceId string = varDeployJumpVm ? jumpVm!.outputs.resourceId : ''

@description('Jump VM name (if deployed).')
output jumpVmName string = varDeployJumpVm ? jumpVm!.outputs.name : ''

// Container Apps Outputs
@description('Container Apps deployment count.')
output containerAppsCount int = length(containerAppsList)
