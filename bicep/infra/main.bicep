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
  genAIAppCosmosDbDefinitionInputType
  keyVaultDefinitionInputType
  kSAISearchDefinitionInputType
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

@description('Optional. Enable platform landing zone integration. When true, private DNS zones are managed by the platform landing zone. Private endpoints are still deployed in the workload VNet.')
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
param enableDefenderForAI bool = false

// Deploy Microsoft Defender for AI at subscription level via module
module defenderModule './components/defender/main.bicep' = if (enableDefenderForAI) {
  name: 'defender-${varUniqueSuffix}'
  scope: subscription()
  params: {
    enableDefenderForAI: enableDefenderForAI
    enableDefenderForKeyVault: varHasKv
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

// APIM Internal/External VNet injection requires an NSG on the APIM subnet.
// Force NSG deployment when APIM is enabled and virtualNetworkType is not 'None', even if the toggle is off.
var varApimRequiresSubnetNsg = deployToggles.apiManagement && ((apimDefinition.?virtualNetworkType ?? 'Internal') != 'None')
var varDeployApiManagementNsg = (deployToggles.apiManagementNsg || varApimRequiresSubnetNsg) && empty(resourceIds.?apiManagementNsgResourceId)

// APIM VNet injection also requires the APIM subnet to be delegated.
// See: https://aka.ms/apim-vnet-outbound
var varApimSubnetDelegationServiceName = varApimRequiresSubnetNsg ? 'Microsoft.Web/hostingEnvironments' : ''

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
              destinationPortRange: '1433'
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

// Determine the Resource Group scope where the VNet lives.
// This must be start-of-deployment evaluable (BCP177-safe), so we ONLY derive it from inputs:
// - resourceIds.virtualNetworkResourceId (preferred when reusing an existing VNet)
// - existingVNetSubnetsDefinition.existingVNetName (only when it is a full resource ID)
// When neither is provided, the VNet is created in the current resource group.
var varHasSpokeVnetResourceId = !empty(resourceIds.?virtualNetworkResourceId)
var varSpokeVnetIdSegments = varHasSpokeVnetResourceId ? split(resourceIds.virtualNetworkResourceId!, '/') : array([])
var varSpokeVnetSubscriptionId = varHasSpokeVnetResourceId && length(varSpokeVnetIdSegments) >= 3
  ? varSpokeVnetIdSegments[2]
  : ''
var varSpokeVnetResourceGroupName = varHasSpokeVnetResourceId && length(varSpokeVnetIdSegments) >= 5
  ? varSpokeVnetIdSegments[4]
  : ''

var varVnetScopeSubscriptionId = varHasSpokeVnetResourceId
  ? varSpokeVnetSubscriptionId
  : (varIsCrossScope ? varExistingVNetSubscriptionId : subscription().subscriptionId)
var varVnetScopeResourceGroupName = varHasSpokeVnetResourceId
  ? varSpokeVnetResourceGroupName
  : (varIsCrossScope ? varExistingVNetResourceGroupName : resourceGroup().name)
var varVnetResourceGroupScope = resourceGroup(varVnetScopeSubscriptionId, varVnetScopeResourceGroupName)

// When reusing an existing spoke VNet, we may still want to create the spoke->hub peering.
// To keep peering deployment conditions start-of-deployment evaluable (BCP177), derive the local VNet name only from inputs.
var varSpokeVnetNameForPeering = !empty(resourceIds.?virtualNetworkResourceId)
  ? split(resourceIds.virtualNetworkResourceId!, '/')[8]
  : (varDeploySubnetsToExistingVnet
    ? (varIsExistingVNetResourceId
      ? varExistingVNetIdSegments[8]
      : existingVNetSubnetsDefinition!.existingVNetName)
    : '')

// Default subnet set for standalone spoke deployments.
// In Platform Landing Zone mode, hub-level subnets (Firewall/Bastion/Jumpbox) are expected to exist in the platform hub,
// so they should not be created in the spoke.
var varDefaultSpokeSubnetsFull = [
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
  union(
    {
      enabled: true
      name: 'apim-subnet'
      addressPrefix: '192.168.0.224/27'
      networkSecurityGroupResourceId: apiManagementNsgResourceId
      // Min: /28 (16 IPs) for dev/test SKUs
      // Recommended: /27 or larger for production multi-zone APIM
    },
    !empty(varApimSubnetDelegationServiceName) ? { delegation: varApimSubnetDelegationServiceName } : {}
  )
  {
    enabled: true
    name: 'jumpbox-subnet'
    addressPrefix: '192.168.1.64/28'
    networkSecurityGroupResourceId: jumpboxNsgResourceId
    // Min: /29 (8 IPs) for 1–2 VMs
    // Recommended: /28 (16 IPs) to host a couple of VMs comfortably
  }
  {
    enabled: true
    name: 'aca-env-subnet'
    addressPrefix: '192.168.1.0/27' // ACA (workload profiles) requires /27 minimum
    delegation: 'Microsoft.App/environments'
    serviceEndpoints: ['Microsoft.AzureCosmosDB']
    networkSecurityGroupResourceId: acaEnvironmentNsgResourceId
    // Min (workload profiles): /27 (32 IPs)
    // Note: Consumption-only environment requires /23 (512 IPs)
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

var varDefaultSpokeSubnetsPlatformLz = [
  {
    enabled: true
    name: 'agent-subnet'
    addressPrefix: '192.168.0.0/27'
    delegation: 'Microsoft.App/environments'
    serviceEndpoints: ['Microsoft.CognitiveServices']
    networkSecurityGroupResourceId: agentNsgResourceId
  }
  {
    enabled: true
    name: 'pe-subnet'
    addressPrefix: '192.168.0.32/27'
    serviceEndpoints: ['Microsoft.AzureCosmosDB']
    privateEndpointNetworkPolicies: 'Disabled'
    networkSecurityGroupResourceId: peNsgResourceId
  }
  {
    enabled: true
    name: 'appgw-subnet'
    addressPrefix: '192.168.0.192/27'
    networkSecurityGroupResourceId: applicationGatewayNsgResourceId
  }
  union(
    {
      enabled: true
      name: 'apim-subnet'
      addressPrefix: '192.168.0.224/27'
      networkSecurityGroupResourceId: apiManagementNsgResourceId
    },
    !empty(varApimSubnetDelegationServiceName) ? { delegation: varApimSubnetDelegationServiceName } : {}
  )
  {
    enabled: true
    name: 'aca-env-subnet'
    addressPrefix: '192.168.1.0/27' // ACA (workload profiles) requires /27 minimum
    delegation: 'Microsoft.App/environments'
    serviceEndpoints: ['Microsoft.AzureCosmosDB']
    networkSecurityGroupResourceId: acaEnvironmentNsgResourceId
  }
  {
    enabled: true
    name: 'devops-agents-subnet'
    addressPrefix: '192.168.1.32/27'
    networkSecurityGroupResourceId: devopsBuildAgentsNsgResourceId
  }
]

var varDefaultSpokeSubnets = flagPlatformLandingZone ? varDefaultSpokeSubnetsPlatformLz : varDefaultSpokeSubnetsFull

// 3.1 Virtual Network and Subnets
module vNetworkWrapper 'wrappers/avm.res.network.virtual-network.bicep' = if (varDeployVnet && !(hubVnetPeeringDefinition != null && !empty(hubVnetPeeringDefinition.?peerVnetResourceId))) {
  name: 'm-vnet'
  params: {
    vnet: union(
      {
        name: 'vnet-${baseName}'
        addressPrefixes: ['192.168.0.0/23']
        location: location
        enableTelemetry: enableTelemetry
        subnets: vNetDefinition.?subnets ?? varDefaultSpokeSubnets
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
    flagPlatformLandingZone: flagPlatformLandingZone
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
    apimSubnetDelegationServiceName: varApimSubnetDelegationServiceName
  }
}

// Deploy subnets to existing VNet (cross-scope)
module existingVNetSubnetsCrossScope './helpers/setup-subnets-for-vnet/main.bicep' = if (varDeploySubnetsToExistingVnet && varIsCrossScope) {
  name: 'm-existing-vnet-subnets-cross-scope'
  scope: resourceGroup(varExistingVNetSubscriptionId, varExistingVNetResourceGroupName)
  params: {
    flagPlatformLandingZone: flagPlatformLandingZone
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
    apimSubnetDelegationServiceName: varApimSubnetDelegationServiceName
  }
}

var existingVNetResourceId = varDeploySubnetsToExistingVnet
  ? (varIsCrossScope
      ? existingVNetSubnetsCrossScope!.outputs.virtualNetworkResourceId
      : existingVNetSubnets!.outputs.virtualNetworkResourceId)
  : ''

// 3.3 VNet Resource ID Resolution
var virtualNetworkResourceId = resourceIds.?virtualNetworkResourceId ?? (varDeploySpokeToHubPeering && varDeployVnet
  ? spokeVNetWithPeering!.outputs.resourceId
  : (varDeployVnet ? vNetworkWrapper!.outputs.resourceId : existingVNetResourceId))

// -----------------------
// 3.4 Subnet resource ID resolution (for outputs)
// -----------------------
// Note: Outputs are derived from conventional subnet names. If you override subnet names in vNetDefinition,
// update these outputs accordingly.
var varAgentSubnetResourceId = !empty(virtualNetworkResourceId) ? '${virtualNetworkResourceId}/subnets/agent-subnet' : ''
var varPrivateEndpointsSubnetResourceId = !empty(virtualNetworkResourceId) ? '${virtualNetworkResourceId}/subnets/pe-subnet' : ''
var varApplicationGatewaySubnetResourceId = !empty(virtualNetworkResourceId) ? '${virtualNetworkResourceId}/subnets/appgw-subnet' : ''
var varApiManagementSubnetResourceId = !empty(virtualNetworkResourceId) ? '${virtualNetworkResourceId}/subnets/apim-subnet' : ''
var varAcaEnvironmentSubnetResourceId = !empty(virtualNetworkResourceId) ? '${virtualNetworkResourceId}/subnets/aca-env-subnet' : ''
var varDevopsAgentsSubnetResourceId = !empty(virtualNetworkResourceId) ? '${virtualNetworkResourceId}/subnets/devops-agents-subnet' : ''

// Hub-level subnets are expected in the platform hub when integrating with Platform Landing Zone.
var varJumpboxSubnetResourceId = (!flagPlatformLandingZone && !empty(virtualNetworkResourceId)) ? '${virtualNetworkResourceId}/subnets/jumpbox-subnet' : ''
var varBastionSubnetResourceId = (!flagPlatformLandingZone && !empty(virtualNetworkResourceId)) ? '${virtualNetworkResourceId}/subnets/AzureBastionSubnet' : ''
var varFirewallSubnetResourceId = (!flagPlatformLandingZone && !empty(virtualNetworkResourceId)) ? '${virtualNetworkResourceId}/subnets/AzureFirewallSubnet' : ''

// -----------------------
// 4 NETWORKING - PRIVATE DNS ZONES
// -----------------------

// 4.1 Platform Landing Zone Integration Logic
var varIsPlatformLz = flagPlatformLandingZone
// Platform Landing Zone integration model in this repo:
// - Private Endpoints are created in the workload (spoke) VNet in both modes.
// - Private DNS Zones are created by this template only when NOT integrating with a Platform Landing Zone.
// IMPORTANT: This must be start-of-deployment evaluable (BCP178-safe). Do not reference module outputs here.
var varHasVnet = deployToggles.virtualNetwork || !empty(resourceIds.?virtualNetworkResourceId) || (existingVNetSubnetsDefinition != null)
var varDeployPrivateDnsZones = !varIsPlatformLz && varHasVnet
var varDeployPrivateEndpoints = varHasVnet

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
var varVnetIdSegments = varHasVnet ? split(virtualNetworkResourceId, '/') : array([])
var varVnetName = (varHasVnet && length(varVnetIdSegments) >= 9) ? varVnetIdSegments[8] : ''
var varVnetResourceId = varHasVnet ? virtualNetworkResourceId : ''

// 4.3 Private Endpoint Variables
var varPeSubnetId = varHasVnet ? '${virtualNetworkResourceId}/subnets/pe-subnet' : ''

// Service availability checks for private endpoints
var varHasAppConfig = !empty(resourceIds.?appConfigResourceId!) || varDeployAppConfig
var varHasApim = !empty(resourceIds.?apimServiceResourceId!) || varDeployApim
var varHasContainerEnv = !empty(resourceIds.?containerEnvResourceId!) || varDeployContainerAppEnv
var varHasAcr = !empty(resourceIds.?containerRegistryResourceId!) || varDeployAcr
var varHasStorage = !empty(resourceIds.?storageAccountResourceId!) || varDeploySa
var varHasCosmos = !empty(resourceIds.?dbAccountResourceId!) || varDeployCosmosDb
var varHasSearch = !empty(resourceIds.?searchServiceResourceId!) || varDeployAiSearch
var varHasKv = !empty(resourceIds.?keyVaultResourceId!) || varDeployKeyVault

// 4.4 API Management Private DNS Zone
@description('Optional. API Management Private DNS Zone configuration.')
param apimPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

module privateDnsZoneApim 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPrivateDnsZones && !varUseExistingPdz.apim) {
  name: 'dep-apim-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.azure-api.net'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (varHasVnet && (privateDnsZonesDefinition.?createNetworkLinks ?? true))
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

module privateDnsZoneCogSvcs 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPrivateDnsZones && !varUseExistingPdz.cognitiveservices) {
  name: 'dep-cogsvcs-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.cognitiveservices.azure.com'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (varHasVnet && (privateDnsZonesDefinition.?createNetworkLinks ?? true))
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

module privateDnsZoneOpenAi 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPrivateDnsZones && !varUseExistingPdz.openai) {
  name: 'dep-openai-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.openai.azure.com'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (varHasVnet && (privateDnsZonesDefinition.?createNetworkLinks ?? true))
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

module privateDnsZoneAiService 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPrivateDnsZones && !varUseExistingPdz.aiServices) {
  name: 'dep-aiservices-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.services.ai.azure.com'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (varHasVnet && (privateDnsZonesDefinition.?createNetworkLinks ?? true))
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

module privateDnsZoneSearch 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPrivateDnsZones && !varUseExistingPdz.search) {
  name: 'dep-search-std-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.search.windows.net'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (varHasVnet && (privateDnsZonesDefinition.?createNetworkLinks ?? true))
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

module privateDnsZoneCosmos 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPrivateDnsZones && !varUseExistingPdz.cosmosSql) {
  name: 'dep-cosmos-std-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.documents.azure.com'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (varHasVnet && (privateDnsZonesDefinition.?createNetworkLinks ?? true))
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

module privateDnsZoneBlob 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPrivateDnsZones && !varUseExistingPdz.blob) {
  name: 'dep-blob-std-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.blob.${environment().suffixes.storage}'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (varHasVnet && (privateDnsZonesDefinition.?createNetworkLinks ?? true))
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

module privateDnsZoneKeyVault 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPrivateDnsZones && !varUseExistingPdz.keyVault) {
  name: 'kv-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.vaultcore.azure.net'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (varHasVnet && (privateDnsZonesDefinition.?createNetworkLinks ?? true))
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

module privateDnsZoneAppConfig 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPrivateDnsZones && !varUseExistingPdz.appConfig) {
  name: 'appconfig-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.azconfig.io'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (varHasVnet && (privateDnsZonesDefinition.?createNetworkLinks ?? true))
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

module privateDnsZoneContainerApps 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPrivateDnsZones && !varUseExistingPdz.containerApps) {
  name: 'dep-containerapps-env-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.${location}.azurecontainerapps.io'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (varHasVnet && (privateDnsZonesDefinition.?createNetworkLinks ?? true))
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

module privateDnsZoneAcr 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPrivateDnsZones && !varUseExistingPdz.acr) {
  name: 'acr-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.azurecr.io'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (varHasVnet && (privateDnsZonesDefinition.?createNetworkLinks ?? true))
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

module privateDnsZoneInsights 'wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPrivateDnsZones && !varUseExistingPdz.appInsights) {
  name: 'ai-private-dns-zone'
  params: {
    privateDnsZone: union(
      {
        name: 'privatelink.applicationinsights.azure.com'
        location: 'global'
        tags: !empty(privateDnsZonesDefinition.?tags) ? privateDnsZonesDefinition!.tags! : {}
        enableTelemetry: enableTelemetry
        virtualNetworkLinks: (varHasVnet && (privateDnsZonesDefinition.?createNetworkLinks ?? true))
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

// Resolve Private DNS Zone resource IDs (existing or newly created). In Platform LZ mode,
// these will typically be provided via privateDnsZonesDefinition.*ZoneId.
var varApimPrivateDnsZoneResourceId = (!empty(privateDnsZonesDefinition.?apimZoneId))
  ? privateDnsZonesDefinition!.apimZoneId!
  : (varDeployPrivateDnsZones && !varUseExistingPdz.apim
      ? privateDnsZoneApim!.outputs.resourceId
      : '')
var varCognitiveServicesPrivateDnsZoneResourceId = (!empty(privateDnsZonesDefinition.?cognitiveservicesZoneId))
  ? privateDnsZonesDefinition!.cognitiveservicesZoneId!
  : (varDeployPrivateDnsZones && !varUseExistingPdz.cognitiveservices
      ? privateDnsZoneCogSvcs!.outputs.resourceId
      : '')
var varOpenAiPrivateDnsZoneResourceId = (!empty(privateDnsZonesDefinition.?openaiZoneId))
  ? privateDnsZonesDefinition!.openaiZoneId!
  : (varDeployPrivateDnsZones && !varUseExistingPdz.openai
      ? privateDnsZoneOpenAi!.outputs.resourceId
      : '')
var varAiServicesPrivateDnsZoneResourceId = (!empty(privateDnsZonesDefinition.?aiServicesZoneId))
  ? privateDnsZonesDefinition!.aiServicesZoneId!
  : (varDeployPrivateDnsZones && !varUseExistingPdz.aiServices
      ? privateDnsZoneAiService!.outputs.resourceId
      : '')
var varSearchPrivateDnsZoneResourceId = (!empty(privateDnsZonesDefinition.?searchZoneId))
  ? privateDnsZonesDefinition!.searchZoneId!
  : (varDeployPrivateDnsZones && !varUseExistingPdz.search
      ? privateDnsZoneSearch!.outputs.resourceId
      : '')
var varCosmosSqlPrivateDnsZoneResourceId = (!empty(privateDnsZonesDefinition.?cosmosSqlZoneId))
  ? privateDnsZonesDefinition!.cosmosSqlZoneId!
  : (varDeployPrivateDnsZones && !varUseExistingPdz.cosmosSql
      ? privateDnsZoneCosmos!.outputs.resourceId
      : '')
var varBlobPrivateDnsZoneResourceId = (!empty(privateDnsZonesDefinition.?blobZoneId))
  ? privateDnsZonesDefinition!.blobZoneId!
  : (varDeployPrivateDnsZones && !varUseExistingPdz.blob
      ? privateDnsZoneBlob!.outputs.resourceId
      : '')
var varKeyVaultPrivateDnsZoneResourceId = (!empty(privateDnsZonesDefinition.?keyVaultZoneId))
  ? privateDnsZonesDefinition!.keyVaultZoneId!
  : (varDeployPrivateDnsZones && !varUseExistingPdz.keyVault
      ? privateDnsZoneKeyVault!.outputs.resourceId
      : '')
var varAppConfigPrivateDnsZoneResourceId = (!empty(privateDnsZonesDefinition.?appConfigZoneId))
  ? privateDnsZonesDefinition!.appConfigZoneId!
  : (varDeployPrivateDnsZones && !varUseExistingPdz.appConfig
      ? privateDnsZoneAppConfig!.outputs.resourceId
      : '')
var varContainerAppsPrivateDnsZoneResourceId = (!empty(privateDnsZonesDefinition.?containerAppsZoneId))
  ? privateDnsZonesDefinition!.containerAppsZoneId!
  : (varDeployPrivateDnsZones && !varUseExistingPdz.containerApps
      ? privateDnsZoneContainerApps!.outputs.resourceId
      : '')
var varAcrPrivateDnsZoneResourceId = (!empty(privateDnsZonesDefinition.?acrZoneId))
  ? privateDnsZonesDefinition!.acrZoneId!
  : (varDeployPrivateDnsZones && !varUseExistingPdz.acr
      ? privateDnsZoneAcr!.outputs.resourceId
      : '')
var varAppInsightsPrivateDnsZoneResourceId = (!empty(privateDnsZonesDefinition.?appInsightsZoneId))
  ? privateDnsZonesDefinition!.appInsightsZoneId!
  : (varDeployPrivateDnsZones && !varUseExistingPdz.appInsights
      ? privateDnsZoneInsights!.outputs.resourceId
      : '')

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

// In Platform Landing Zone mode, do not deploy a spoke firewall. Forced tunneling is expected to route to the hub firewall.
var varDeploySpokeFirewall = (deployToggles.?firewall ?? false) && !varIsPlatformLz

var varDeployFirewallPip = varDeploySpokeFirewall && empty(resourceIds.?firewallPublicIpResourceId)

module firewallPipWrapper 'wrappers/avm.res.network.public-ip-address.bicep' = if (varDeployFirewallPip) {
  name: 'm-fw-pip'
  scope: varVnetResourceGroupScope
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
// Platform Landing Zone (Model B): workload deployments typically do not have permissions on the hub VNet / hub RG.
// In PLZ mode, we allow creating ONLY the spoke-side peering (workload scope) and never attempt hub-side reverse peering.
var varWantsHubPeering = hubVnetPeeringDefinition != null && !empty(hubVnetPeeringDefinition.?peerVnetResourceId)
var varDeploySpokeToHubPeering = varWantsHubPeering
var varDeployHubToSpokePeering = !varIsPlatformLz && varWantsHubPeering && (hubVnetPeeringDefinition.?createReversePeering ?? true)

// Parse hub VNet resource ID
var varHubPeerVnetId = varWantsHubPeering ? hubVnetPeeringDefinition!.peerVnetResourceId! : ''
var varHubPeerParts = split(varHubPeerVnetId, '/')
var varHubPeerSub = varWantsHubPeering && length(varHubPeerParts) >= 3
  ? varHubPeerParts[2]
  : subscription().subscriptionId
var varHubPeerRg = varWantsHubPeering && length(varHubPeerParts) >= 5 ? varHubPeerParts[4] : resourceGroup().name
var varHubPeerVnetName = varWantsHubPeering && length(varHubPeerParts) >= 9 ? varHubPeerParts[8] : ''

// 6.2 Spoke VNet with Peering
module spokeVNetWithPeering 'wrappers/avm.res.network.virtual-network.bicep' = if (varDeploySpokeToHubPeering && varDeployVnet) {
  name: 'm-spoke-vnet-peering'
  params: {
    vnet: union(
      {
        name: 'vnet-${baseName}'
        addressPrefixes: ['192.168.0.0/23']
        location: location
        enableTelemetry: enableTelemetry
        subnets: vNetDefinition.?subnets ?? varDefaultSpokeSubnets
        peerings: [
          {
            name: hubVnetPeeringDefinition!.?name ?? 'to-hub'
            remoteVirtualNetworkResourceId: varHubPeerVnetId
            allowVirtualNetworkAccess: hubVnetPeeringDefinition!.?allowVirtualNetworkAccess ?? true
            allowForwardedTraffic: hubVnetPeeringDefinition!.?allowForwardedTraffic ?? true
            allowGatewayTransit: hubVnetPeeringDefinition!.?allowGatewayTransit ?? false
            useRemoteGateways: hubVnetPeeringDefinition!.?useRemoteGateways ?? false
            // Important for PLZ: never attempt to create the hub-side peering from the workload deployment.
            // The hub-side peering is created either by the platform team (manual) or by the dedicated hub-to-spoke module
            // when not in Platform Landing Zone mode.
            remotePeeringEnabled: false
          }
        ]
      },
      vNetDefinition ?? {}
    )
  }
}

// Spoke-to-hub peering when reusing an existing spoke VNet
module spokeToHubPeering './components/vnet-peering/main.bicep' = if (varDeploySpokeToHubPeering && !varDeployVnet && !varIsCrossScope && !empty(varSpokeVnetNameForPeering)) {
  name: 'm-spoke-to-hub-peering'
  params: {
    localVnetName: varSpokeVnetNameForPeering
    remotePeeringName: hubVnetPeeringDefinition!.?name ?? 'to-hub'
    remoteVirtualNetworkResourceId: varHubPeerVnetId
    allowVirtualNetworkAccess: hubVnetPeeringDefinition!.?allowVirtualNetworkAccess ?? true
    allowForwardedTraffic: hubVnetPeeringDefinition!.?allowForwardedTraffic ?? true
    allowGatewayTransit: hubVnetPeeringDefinition!.?allowGatewayTransit ?? false
    useRemoteGateways: hubVnetPeeringDefinition!.?useRemoteGateways ?? false
  }
}

module spokeToHubPeeringCrossScope './components/vnet-peering/main.bicep' = if (varDeploySpokeToHubPeering && !varDeployVnet && varIsCrossScope && !empty(varSpokeVnetNameForPeering)) {
  name: 'm-spoke-to-hub-peering-cross-scope'
  scope: resourceGroup(varExistingVNetSubscriptionId, varExistingVNetResourceGroupName)
  params: {
    localVnetName: varSpokeVnetNameForPeering
    remotePeeringName: hubVnetPeeringDefinition!.?name ?? 'to-hub'
    remoteVirtualNetworkResourceId: varHubPeerVnetId
    allowVirtualNetworkAccess: hubVnetPeeringDefinition!.?allowVirtualNetworkAccess ?? true
    allowForwardedTraffic: hubVnetPeeringDefinition!.?allowForwardedTraffic ?? true
    allowGatewayTransit: hubVnetPeeringDefinition!.?allowGatewayTransit ?? false
    useRemoteGateways: hubVnetPeeringDefinition!.?useRemoteGateways ?? false
  }
}

// 6.3 Hub-to-Spoke Reverse Peering
module hubToSpokePeering './components/vnet-peering/main.bicep' = if (varDeployHubToSpokePeering) {
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
// 7 NETWORKING - PRIVATE ENDPOINTS
// -----------------------

// Note: AI Foundry dependencies are treated as separate resources from the GenAI App backing services.
// This landing zone may deploy private endpoints for the GenAI App backing services independently.
var varDeployAiFoundry = deployToggles.aiFoundry

// 7.1. App Configuration Private Endpoint
@description('Optional. App Configuration Private Endpoint configuration.')
param appConfigPrivateEndpointDefinition privateDnsZoneDefinitionType?

module privateEndpointAppConfig 'wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPrivateEndpoints && varHasAppConfig) {
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
        privateDnsZoneGroup: (!varIsPlatformLz && !empty(varAppConfigPrivateDnsZoneResourceId)) ? {
          name: 'appConfigDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'appConfigARecord'
              privateDnsZoneResourceId: varAppConfigPrivateDnsZoneResourceId
            }
          ]
        } : null
      },
      appConfigPrivateEndpointDefinition ?? {}
    )
  }
  dependsOn: [
    #disable-next-line BCP321
    varDeployUdrEffective ? udrSubnetAssociation06 : null
  ]
}

// 7.2. API Management Private Endpoint
@description('Optional. API Management Private Endpoint configuration.')
param apimPrivateEndpointDefinition privateDnsZoneDefinitionType?

// StandardV2 and Premium SKUs support Private Endpoints with gateway groupId
// Basic and Developer SKUs do not support Private Endpoints
// IMPORTANT: APIM default in this template is Premium + Internal VNet.
// Private Endpoint is not supported for APIM when virtualNetworkType is Internal.
// Only create the APIM private endpoint when the user explicitly sets virtualNetworkType to 'None'.
var varApimSkuEffectiveForPe = apimDefinition.?sku ?? 'PremiumV2'
var apimSupportsPe = contains(['StandardV2', 'Premium', 'PremiumV2'], varApimSkuEffectiveForPe)
var varApimWantsPrivateEndpoint = (apimDefinition != null) && ((apimDefinition.?virtualNetworkType ?? 'Internal') == 'None')

module privateEndpointApim 'wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPrivateEndpoints && varHasApim && varApimWantsPrivateEndpoint && apimSupportsPe) {
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
                ? (varDeployApimNative ? apiManagementNative!.outputs.resourceId : apiManagement!.outputs.resourceId)
                : existingApim.id
              groupIds: [
                'Gateway'
              ]
            }
          }
        ]
        privateDnsZoneGroup: (!varIsPlatformLz && !empty(varApimPrivateDnsZoneResourceId)) ? {
          name: 'apimDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'apimARecord'
              privateDnsZoneResourceId: varApimPrivateDnsZoneResourceId
            }
          ]
        } : null
      },
      apimPrivateEndpointDefinition ?? {}
    )
  }
  dependsOn: [
    #disable-next-line BCP321
    varDeployUdrEffective ? udrSubnetAssociation06 : null
  ]
}

// 7.3. Container Apps Environment Private Endpoint
@description('Optional. Container Apps Environment Private Endpoint configuration.')
param containerAppEnvPrivateEndpointDefinition privateDnsZoneDefinitionType?

module privateEndpointContainerAppsEnv 'wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPrivateEndpoints && varHasContainerEnv) {
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
        privateDnsZoneGroup: (!varIsPlatformLz && !empty(varContainerAppsPrivateDnsZoneResourceId)) ? {
          name: 'ccaDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'ccaARecord'
              privateDnsZoneResourceId: varContainerAppsPrivateDnsZoneResourceId
            }
          ]
        } : null
      },
      containerAppEnvPrivateEndpointDefinition ?? {}
    )
  }
  dependsOn: [
    #disable-next-line BCP321
    varDeployContainerAppEnv ? containerEnv : null
    #disable-next-line BCP321
    varDeployUdrEffective ? udrSubnetAssociation06 : null
  ]

}

// 7.4. Azure Container Registry Private Endpoint
@description('Optional. Azure Container Registry Private Endpoint configuration.')
param acrPrivateEndpointDefinition privateDnsZoneDefinitionType?

module privateEndpointAcr 'wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPrivateEndpoints && varHasAcr) {
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
        privateDnsZoneGroup: (!varIsPlatformLz && !empty(varAcrPrivateDnsZoneResourceId)) ? {
          name: 'acrDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'acrARecord'
              privateDnsZoneResourceId: varAcrPrivateDnsZoneResourceId
            }
          ]
        } : null
      },
      acrPrivateEndpointDefinition ?? {}
    )
  }
  dependsOn: [
    #disable-next-line BCP321
    (varDeployAcr) ? containerRegistry : null
    #disable-next-line BCP321
    varDeployUdrEffective ? udrSubnetAssociation06 : null
  ]
}

// 7.5. Storage Account (Blob) Private Endpoint
@description('Optional. Storage Account Private Endpoint configuration.')
param storageBlobPrivateEndpointDefinition privateDnsZoneDefinitionType?

module privateEndpointStorageBlob 'wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPrivateEndpoints && varHasStorage) {
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
        privateDnsZoneGroup: (!varIsPlatformLz && !empty(varBlobPrivateDnsZoneResourceId)) ? {
          name: 'blobDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'blobARecord'
              privateDnsZoneResourceId: varBlobPrivateDnsZoneResourceId
            }
          ]
        } : null
      },
      storageBlobPrivateEndpointDefinition ?? {}
    )
  }
  dependsOn: [
    #disable-next-line BCP321
    varDeployUdrEffective ? udrSubnetAssociation06 : null
  ]
}

// 7.6. Cosmos DB (SQL) Private Endpoint
@description('Optional. Cosmos DB Private Endpoint configuration.')
param cosmosPrivateEndpointDefinition privateDnsZoneDefinitionType?

module privateEndpointCosmos 'wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPrivateEndpoints && varHasCosmos) {
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
              privateLinkServiceId: varCosmosDbResourceId
              groupIds: ['Sql']
            }
          }
        ]
        privateDnsZoneGroup: (!varIsPlatformLz && !empty(varCosmosSqlPrivateDnsZoneResourceId)) ? {
          name: 'cosmosDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'cosmosARecord'
              privateDnsZoneResourceId: varCosmosSqlPrivateDnsZoneResourceId
            }
          ]
        } : null
      },
      cosmosPrivateEndpointDefinition ?? {}
    )
  }
  dependsOn: [
    #disable-next-line BCP321
    varDeployCosmosDb ? cosmosDbModule : null
    #disable-next-line BCP321
    varDeployUdrEffective ? udrSubnetAssociation06 : null
  ]
}

// 7.7. Azure AI Search Private Endpoint
@description('Optional. Azure AI Search Private Endpoint configuration.')
param searchPrivateEndpointDefinition privateDnsZoneDefinitionType?

module privateEndpointSearch 'wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPrivateEndpoints && varHasSearch) {
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
              privateLinkServiceId: varAiSearchResourceId
              groupIds: ['searchService']
            }
          }
        ]
        privateDnsZoneGroup: (!varIsPlatformLz && !empty(varSearchPrivateDnsZoneResourceId)) ? {
          name: 'searchDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'searchARecord'
              privateDnsZoneResourceId: varSearchPrivateDnsZoneResourceId
            }
          ]
        } : null
      },
      searchPrivateEndpointDefinition ?? {}
    )
  }
  dependsOn: [
    #disable-next-line BCP321
    varDeployAiSearch ? aiSearchModule : null
    #disable-next-line BCP321
    (empty(resourceIds.?virtualNetworkResourceId!)) ? vNetworkWrapper : null
    #disable-next-line BCP321
    (varDeployPrivateDnsZones && !varUseExistingPdz.search) ? privateDnsZoneSearch : null
    #disable-next-line BCP321
    varDeployUdrEffective ? udrSubnetAssociation06 : null
  ]
}

// 7.8. Key Vault Private Endpoint
@description('Optional. Key Vault Private Endpoint configuration.')
param keyVaultPrivateEndpointDefinition privateDnsZoneDefinitionType?

module privateEndpointKeyVault 'wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPrivateEndpoints && varHasKv) {
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
              privateLinkServiceId: varKeyVaultResourceId
              groupIds: ['vault']
            }
          }
        ]
        privateDnsZoneGroup: (!varIsPlatformLz && !empty(varKeyVaultPrivateDnsZoneResourceId)) ? {
          name: 'kvDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'kvARecord'
              privateDnsZoneResourceId: varKeyVaultPrivateDnsZoneResourceId
            }
          ]
        } : null
      },
      keyVaultPrivateEndpointDefinition ?? {}
    )
  }
  dependsOn: [
    #disable-next-line BCP321
    varDeployKeyVault ? keyVaultModule : null
    #disable-next-line BCP321
    varDeployUdrEffective ? udrSubnetAssociation06 : null
  ]
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

        // Use a deterministic infra RG name to avoid conflicts with pre-existing ME_<envName> groups on redeploy.
        infrastructureResourceGroupName: take('ME-${varContainerEnvName}-${substring(uniqueString(subscription().subscriptionId, resourceGroup().id, varContainerEnvName), 0, 8)}', 90)

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
      (varDeployPrivateDnsZones && !varUseExistingPdz.containerApps && varHasContainerEnv)
        ? privateDnsZoneContainerApps
        : null
      #disable-next-line BCP321
      (varDeployPrivateEndpoints && varHasContainerEnv) ? privateEndpointContainerAppsEnv : null
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
param cosmosDbDefinition genAIAppCosmosDbDefinitionInputType?

var varCosmosDbResourceIdInput = resourceIds.?dbAccountResourceId ?? ''
var varDeployCosmosDb = empty(varCosmosDbResourceIdInput) && deployToggles.cosmosDb

resource existingCosmosDb 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = if (!empty(varCosmosDbResourceIdInput)) {
  name: varExistingCosmosName
  scope: resourceGroup(varExistingCosmosSub, varExistingCosmosRg)
}

// Naming
var varCosmosIdSegments = empty(varCosmosDbResourceIdInput) ? [''] : split(varCosmosDbResourceIdInput, '/')
var varExistingCosmosSub = length(varCosmosIdSegments) >= 3 ? varCosmosIdSegments[2] : ''
var varExistingCosmosRg = length(varCosmosIdSegments) >= 5 ? varCosmosIdSegments[4] : ''
var varExistingCosmosName = length(varCosmosIdSegments) >= 1 ? last(varCosmosIdSegments) : ''
var varCosmosDbNameFromDefinition = cosmosDbDefinition.?name ?? ''
var varCosmosDbName = !empty(varCosmosDbResourceIdInput)
  ? varExistingCosmosName
  : (empty(varCosmosDbNameFromDefinition) ? 'cosmos-${baseName}' : varCosmosDbNameFromDefinition)

var varCosmosDbResourceId = !empty(varCosmosDbResourceIdInput)
  ? existingCosmosDb.id
  : (varDeployCosmosDb ? cosmosDbModule!.outputs.resourceId : '')

module cosmosDbModule 'wrappers/avm.res.document-db.database-account.bicep' = if (varDeployCosmosDb) {
  name: 'cosmosDbModule'
  params: {
    cosmosDb: union(
      union(
        {
          location: location
          enableTelemetry: enableTelemetry
          tags: tags
          networkRestrictions: {
            publicNetworkAccess: 'Disabled'
          }
        },
        cosmosDbDefinition ?? {}
      ),
      {
        name: varCosmosDbName
      }
    )
  }
}

// -----------------------
// 13 KEY VAULT
// -----------------------
@description('Optional. Key Vault settings.')
param keyVaultDefinition keyVaultDefinitionInputType?

var varKeyVaultResourceIdInput = resourceIds.?keyVaultResourceId ?? ''
var varDeployKeyVault = empty(varKeyVaultResourceIdInput) && deployToggles.keyVault

resource existingKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = if (!empty(varKeyVaultResourceIdInput)) {
  name: varExistingKvName
  scope: resourceGroup(varExistingKvSub, varExistingKvRg)
}

// Naming
var varKvIdSegments = empty(varKeyVaultResourceIdInput) ? [''] : split(varKeyVaultResourceIdInput, '/')
var varExistingKvSub = length(varKvIdSegments) >= 3 ? varKvIdSegments[2] : ''
var varExistingKvRg = length(varKvIdSegments) >= 5 ? varKvIdSegments[4] : ''
var varExistingKvName = length(varKvIdSegments) >= 1 ? last(varKvIdSegments) : ''
var varKeyVaultNameFromDefinition = keyVaultDefinition.?name ?? ''
var varKeyVaultName = !empty(varKeyVaultResourceIdInput)
  ? varExistingKvName
  : (empty(varKeyVaultNameFromDefinition) ? 'kv-${baseName}' : varKeyVaultNameFromDefinition)

var varKeyVaultResourceId = !empty(varKeyVaultResourceIdInput)
  ? existingKeyVault.id
  : (varDeployKeyVault ? keyVaultModule!.outputs.resourceId : '')

module keyVaultModule 'wrappers/avm.res.key-vault.vault.bicep' = if (varDeployKeyVault) {
  name: 'keyVaultModule'
  params: {
    keyVault: union(
      union(
        {
          location: location
          enableTelemetry: enableTelemetry
          tags: tags
          publicNetworkAccess: 'Disabled'
        },
        keyVaultDefinition ?? {}
      ),
      {
        name: varKeyVaultName
      }
    )
  }
}

// -----------------------
// 14 AI SEARCH
// -----------------------
@description('Optional. AI Search settings.')
param aiSearchDefinition kSAISearchDefinitionInputType?

var varAiSearchResourceIdInput = resourceIds.?searchServiceResourceId ?? ''
var varDeployAiSearch = empty(varAiSearchResourceIdInput) && deployToggles.searchService

resource existingAiSearch 'Microsoft.Search/searchServices@2024-06-01-preview' existing = if (!empty(varAiSearchResourceIdInput)) {
  name: varExistingSearchName
  scope: resourceGroup(varExistingSearchSub, varExistingSearchRg)
}

// Naming
var varSearchIdSegments = empty(varAiSearchResourceIdInput) ? [''] : split(varAiSearchResourceIdInput, '/')
var varExistingSearchSub = length(varSearchIdSegments) >= 3 ? varSearchIdSegments[2] : ''
var varExistingSearchRg = length(varSearchIdSegments) >= 5 ? varSearchIdSegments[4] : ''
var varExistingSearchName = length(varSearchIdSegments) >= 1 ? last(varSearchIdSegments) : ''
var varAiSearchNameFromDefinition = aiSearchDefinition.?name ?? ''
var varAiSearchName = !empty(varAiSearchResourceIdInput)
  ? varExistingSearchName
  : (empty(varAiSearchNameFromDefinition) ? 'search-${baseName}' : varAiSearchNameFromDefinition)

var varAiSearchResourceId = !empty(varAiSearchResourceIdInput)
  ? existingAiSearch.id
  : (varDeployAiSearch ? aiSearchModule!.outputs.resourceId : '')

module aiSearchModule 'wrappers/avm.res.search.search-service.bicep' = if (varDeployAiSearch) {
  name: 'aiSearchModule'
  params: {
    aiSearch: union(
      union(
        {
          location: location
          enableTelemetry: enableTelemetry
          tags: tags
          publicNetworkAccess: 'Disabled'
        },
        aiSearchDefinition ?? {}
      ),
      {
        name: varAiSearchName
      }
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

// PremiumV2 is not yet supported by the AVM APIM module used by this repo.
// When the user selects PremiumV2, we deploy APIM using a native resource module.
var varApimSkuEffective = apimDefinition.?sku ?? 'PremiumV2'
var varDeployApimNative = varDeployApim && (varApimSkuEffective == 'PremiumV2')

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
  : (varDeployApim ? (varDeployApimNative ? apiManagementNative!.outputs.resourceId : apiManagement!.outputs.resourceId) : '')

module apiManagementNative 'components/apim/main.bicep' = if (varDeployApimNative) {
  name: 'apimDeploymentNative'
  params: {
    apiManagement: union(
      {
        // Required properties
        name: 'apim-${baseName}'
        publisherEmail: 'admin@contoso.com'
        publisherName: 'Contoso'

        // PremiumV2 SKU configuration for Internal VNet injection (private gateway)
        sku: 'PremiumV2'
        skuCapacity: 3

        // Network configuration - Internal VNet injection
        virtualNetworkType: 'Internal'
        subnetResourceId: varApimSubnetId

        // Basic configuration
        location: location
        tags: tags

        // API Management configuration
        minApiVersion: '2022-08-01'
      },
      apimDefinition ?? {}
    )
  }
}

#disable-next-line BCP081
module apiManagement 'wrappers/avm.res.api-management.service.bicep' = if (varDeployApim && !varDeployApimNative) {
  name: 'apimDeployment'
  params: {
    apiManagement: union(
      {
        // Required properties
        name: 'apim-${baseName}'
        publisherEmail: 'admin@contoso.com'
        publisherName: 'Contoso'

        // Premium SKU configuration for Internal VNet mode
        // Premium supports full VNet injection with Internal mode
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

  // Defaults: deploy Foundry Agent Service (Capability Hosts) and its dependent resources
  // unless explicitly disabled by the user.
  includeAssociatedResources: true
  aiFoundryConfiguration: {
    createCapabilityHosts: true
  }
}

@description('Optional. When false, disables the best-effort capability-host delay deployment script used to mitigate transient AI Foundry CapabilityHost provisioning races. Default: enabled.')
param enableCapabilityHostDelayScript bool = true

@description('Optional. How long to wait (in seconds) before creating the project capability host, to give the service time to finish provisioning the account-level capability host. Default: 600 (10 minutes).')
param capabilityHostWaitSeconds int = 600

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
        name: 'gpt-5-mini'
        modelName: 'gpt-5-mini'
        modelFormat: 'OpenAI'
        modelVersion: '2025-08-07'
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

// Always separated: AI Foundry dependency resources must not reuse the GenAI App backing services.
// Provide AI Foundry-specific resource IDs via resourceIds.aiFoundry* if you want Foundry to reuse existing resources;
// otherwise leave them empty and the AI Foundry component will create its own dependencies when includeAssociatedResources=true.
var varAiFoundryAiSearchResourceId = resourceIds.?aiFoundrySearchServiceResourceId ?? ''

var varAiFoundryStorageResourceId = resourceIds.?aiFoundryStorageAccountResourceId ?? ''

var varAiFoundryCosmosResourceId = resourceIds.?aiFoundryCosmosDBAccountResourceId ?? ''

var varAiFoundryKeyVaultResourceId = resourceIds.?aiFoundryKeyVaultResourceId ?? ''

var varAiFoundryCurrentRgName = resourceGroup().name
var varAiFoundryExistingDnsZones = {
  'privatelink.services.ai.azure.com': varDeployPrivateEndpoints ? (varUseExistingPdz.aiServices ? split(privateDnsZonesDefinition.aiServicesZoneId!, '/')[4] : varAiFoundryCurrentRgName) : ''
  'privatelink.openai.azure.com': varDeployPrivateEndpoints ? (varUseExistingPdz.openai ? split(privateDnsZonesDefinition.openaiZoneId!, '/')[4] : varAiFoundryCurrentRgName) : ''
  'privatelink.cognitiveservices.azure.com': varDeployPrivateEndpoints ? (varUseExistingPdz.cognitiveservices ? split(privateDnsZonesDefinition.cognitiveservicesZoneId!, '/')[4] : varAiFoundryCurrentRgName) : ''
  'privatelink.search.windows.net': varDeployPrivateEndpoints ? (varUseExistingPdz.search ? split(privateDnsZonesDefinition.searchZoneId!, '/')[4] : varAiFoundryCurrentRgName) : ''
  'privatelink.blob.${environment().suffixes.storage}': varDeployPrivateEndpoints ? (varUseExistingPdz.blob ? split(privateDnsZonesDefinition.blobZoneId!, '/')[4] : varAiFoundryCurrentRgName) : ''
  'privatelink.documents.azure.com': varDeployPrivateEndpoints ? (varUseExistingPdz.cosmosSql ? split(privateDnsZonesDefinition.cosmosSqlZoneId!, '/')[4] : varAiFoundryCurrentRgName) : ''
  'privatelink.vaultcore.azure.net': varDeployPrivateEndpoints ? (varUseExistingPdz.keyVault ? split(privateDnsZonesDefinition.keyVaultZoneId!, '/')[4] : varAiFoundryCurrentRgName) : ''
}

module aiFoundry 'components/ai-foundry/main.bicep' = if (varDeployAiFoundry) {
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

    // AI Foundry backing services (always separated from the GenAI App backing services).
    aiSearchResourceId: varAiFoundryAiSearchResourceId
    azureStorageAccountResourceId: varAiFoundryStorageResourceId
    azureCosmosDBAccountResourceId: varAiFoundryCosmosResourceId
    keyVaultResourceId: varAiFoundryKeyVaultResourceId

    // Public networking + IP allowlisting (applies only when Foundry creates these resources)
    aiSearchPublicNetworkAccess: aiFoundryDefinition.?aiSearchConfiguration.?publicNetworkAccess ?? 'Disabled'
    aiSearchNetworkRuleSet: aiFoundryDefinition.?aiSearchConfiguration.?networkRuleSet ?? {}
    cosmosDbPublicNetworkAccess: aiFoundryDefinition.?cosmosDbConfiguration.?publicNetworkAccess ?? 'Disabled'
    cosmosDbIpRules: aiFoundryDefinition.?cosmosDbConfiguration.?ipRules ?? []
    storageAccountPublicNetworkAccess: aiFoundryDefinition.?storageAccountConfiguration.?publicNetworkAccess ?? 'Disabled'
    storageAccountNetworkAcls: aiFoundryDefinition.?storageAccountConfiguration.?networkAcls ?? {}
    keyVaultPublicNetworkAccess: aiFoundryDefinition.?keyVaultConfiguration.?publicNetworkAccess ?? 'Disabled'
    keyVaultNetworkAcls: aiFoundryDefinition.?keyVaultConfiguration.?networkAcls ?? {}

    // Private networking integration
    deployPrivateEndpointsAndDns: varDeployPrivateEndpoints
    configurePrivateDns: !varIsPlatformLz
    existingDnsZones: varAiFoundryExistingDnsZones

    // Control whether the component creates associated resources and/or capability hosts (agent service)
    includeAssociatedResources: aiFoundryDefinition.?includeAssociatedResources ?? true
    createCapabilityHosts: aiFoundryDefinition.?aiFoundryConfiguration.?createCapabilityHosts ?? true
    enableCapabilityHostDelayScript: enableCapabilityHostDelayScript
    capabilityHostWaitSeconds: capabilityHostWaitSeconds

    // Model deployments
    modelDeployments: varAiFoundryModelDeployments
  }
  dependsOn: [
    #disable-next-line BCP321
    (empty(resourceIds.?virtualNetworkResourceId!)) ? vNetworkWrapper : null
    #disable-next-line BCP321
    (varDeployPrivateDnsZones && !varUseExistingPdz.search) ? privateDnsZoneSearch : null
    #disable-next-line BCP321
    (varDeployPrivateDnsZones && !varUseExistingPdz.blob) ? privateDnsZoneBlob : null
    #disable-next-line BCP321
    (varDeployPrivateDnsZones && !varUseExistingPdz.cosmosSql) ? privateDnsZoneCosmos : null
    #disable-next-line BCP321
    (varDeployPrivateDnsZones && !varUseExistingPdz.keyVault) ? privateDnsZoneKeyVault : null
    #disable-next-line BCP321
    (varDeployPrivateDnsZones && !varUseExistingPdz.cognitiveservices) ? privateDnsZoneCogSvcs : null
    #disable-next-line BCP321
    (varDeployPrivateDnsZones && !varUseExistingPdz.openai) ? privateDnsZoneOpenAi : null
    #disable-next-line BCP321
    (varDeployPrivateDnsZones && !varUseExistingPdz.aiServices) ? privateDnsZoneAiService : null
  ]
}

// -----------------------
// 17 BING GROUNDING
// -----------------------

// Grounding with Bing
@description('Conditional. Grounding with Bing configuration. Required if deploy.groundingWithBingSearch is true and resourceIds.groundingServiceResourceId is empty.')
param groundingWithBingDefinition kSGroundingWithBingDefinitionType?

// Decide if Bing module runs (create or reuse+connect)
var varInvokeBingModule = varDeployAiFoundry && ((!empty(resourceIds.?groundingServiceResourceId!)) || (deployToggles.groundingWithBingSearch && empty(resourceIds.?groundingServiceResourceId!)))

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
    accountName: aiFoundry!.outputs.aiServicesName
    projectName: aiFoundry!.outputs.aiProjectName

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

var varDeployAfwPolicy = varDeploySpokeFirewall && empty(resourceIds.?firewallPolicyResourceId!)

module fwPolicy 'wrappers/avm.res.network.firewall-policy.bicep' = if (varDeployAfwPolicy) {
  name: 'firewallPolicyDeployment'
  scope: varVnetResourceGroupScope
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

var varDeployFirewall = empty(resourceIds.?firewallResourceId!) && varDeploySpokeFirewall

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
  scope: varVnetResourceGroupScope
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
// 18.5 USER DEFINED ROUTES (UDR)
// -----------------------

// Optional. When deployToggles.userDefinedRoutes is true, deploys a Route Table with a default route (0.0.0.0/0)
// and associates it to selected workload subnets.

@description('Optional. Name of the Route Table created when deployToggles.userDefinedRoutes is true.')
param userDefinedRouteTableName string = 'rt-${baseName}'

@description('Optional. Firewall/NVA next hop private IP for the UDR default route.')
param firewallPrivateIp string = ''

@description('Optional. When true, creates an App Gateway subnet routing exception: appgw-subnet gets 0.0.0.0/0 -> Internet instead of 0.0.0.0/0 -> VirtualAppliance. Mirrors Terraform use_internet_routing behavior for App Gateway v2.')
param appGatewayInternetRoutingException bool = false

// Note: next hop must be known at the start of the deployment.
var varUdrNextHopIp = firewallPrivateIp

// Defensive behavior:
// - If UDR is requested but we don't have a consistent firewall/NVA signal + next hop IP,
//   do NOT deploy the route table. This avoids breaking egress by accidentally forcing 0.0.0.0/0 to a bad next hop.
// - If the firewall is deployed/reused, that is a valid signal.
// - If firewallPrivateIp is provided, that is a valid signal.
// UDR can route either via a deployed spoke firewall, an existing firewall resource, or a user-provided next hop IP (e.g., hub firewall).
var varHasFirewallSignal = varDeploySpokeFirewall || !empty(resourceIds.?firewallResourceId!) || !empty(firewallPrivateIp)
var varDeployUdrEffective = deployToggles.userDefinedRoutes && varHasFirewallSignal && !empty(varUdrNextHopIp)

resource udrRouteTable 'Microsoft.Network/routeTables@2023-11-01' = if (varDeployUdrEffective) {
  name: userDefinedRouteTableName
  location: location
  tags: tags
}

resource udrDefaultRoute 'Microsoft.Network/routeTables/routes@2023-11-01' = if (varDeployUdrEffective) {
  name: 'default-route'
  parent: udrRouteTable
  properties: {
    addressPrefix: '0.0.0.0/0'
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: varUdrNextHopIp
  }
}

resource udrAppGwRouteTable 'Microsoft.Network/routeTables@2023-11-01' = if (varDeployUdrEffective && appGatewayInternetRoutingException) {
  name: 'rt-appgw-${baseName}'
  location: location
  tags: tags
}

resource udrAppGwDefaultRoute 'Microsoft.Network/routeTables/routes@2023-11-01' = if (varDeployUdrEffective && appGatewayInternetRoutingException) {
  name: 'default-route'
  parent: udrAppGwRouteTable
  properties: {
    addressPrefix: '0.0.0.0/0'
    nextHopType: 'Internet'
  }
}

var varUdrDefaultRouteTableId = varDeployUdrEffective ? udrRouteTable.id : ''
var varUdrAppGwRouteTableId = (varDeployUdrEffective && appGatewayInternetRoutingException) ? udrAppGwRouteTable.id : ''

var varUdrSubnetDefinitions = [
  {
    name: 'agent-subnet'
    addressPrefix: '192.168.0.0/27'
    delegation: 'Microsoft.App/environments'
    serviceEndpoints: ['Microsoft.CognitiveServices']
    networkSecurityGroupResourceId: agentNsgResourceId
    routeTableResourceId: varUdrDefaultRouteTableId
  }
  {
    name: 'jumpbox-subnet'
    addressPrefix: '192.168.1.64/28'
    networkSecurityGroupResourceId: jumpboxNsgResourceId
    routeTableResourceId: varUdrDefaultRouteTableId
  }
  {
    name: 'aca-env-subnet'
    addressPrefix: '192.168.1.0/27'
    delegation: 'Microsoft.App/environments'
    serviceEndpoints: ['Microsoft.AzureCosmosDB']
    networkSecurityGroupResourceId: acaEnvironmentNsgResourceId
    routeTableResourceId: varUdrDefaultRouteTableId
  }
  {
    name: 'devops-agents-subnet'
    addressPrefix: '192.168.1.32/27'
    networkSecurityGroupResourceId: devopsBuildAgentsNsgResourceId
    routeTableResourceId: varUdrDefaultRouteTableId
  }
  {
    name: 'appgw-subnet'
    addressPrefix: '192.168.0.192/27'
    networkSecurityGroupResourceId: applicationGatewayNsgResourceId
    routeTableResourceId: appGatewayInternetRoutingException ? varUdrAppGwRouteTableId : varUdrDefaultRouteTableId
  }
  {
    name: 'apim-subnet'
    addressPrefix: '192.168.0.224/27'
    networkSecurityGroupResourceId: apiManagementNsgResourceId
    routeTableResourceId: varUdrDefaultRouteTableId
  }
]

module udrSubnetAssociation01 './helpers/deploy-subnets-to-vnet/main.bicep' = if (varDeployUdrEffective) {
  name: 'm-udr-subnet-association-01'
  scope: varVnetResourceGroupScope
  params: {
    existingVNetName: virtualNetworkResourceId
    subnets: [varUdrSubnetDefinitions[0]]
    apimSubnetDelegationServiceName: varApimSubnetDelegationServiceName
  }
  dependsOn: [
    #disable-next-line BCP321
    varDeployVnet ? vNetworkWrapper : null
    #disable-next-line BCP321
    (varDeploySubnetsToExistingVnet && !varIsCrossScope) ? existingVNetSubnets : null
    #disable-next-line BCP321
    (varDeploySubnetsToExistingVnet && varIsCrossScope) ? existingVNetSubnetsCrossScope : null
  ]
}

module udrSubnetAssociation02 './helpers/deploy-subnets-to-vnet/main.bicep' = if (varDeployUdrEffective) {
  name: 'm-udr-subnet-association-02'
  scope: varVnetResourceGroupScope
  params: {
    existingVNetName: virtualNetworkResourceId
    subnets: [varUdrSubnetDefinitions[1]]
    apimSubnetDelegationServiceName: varApimSubnetDelegationServiceName
  }
  dependsOn: [
    udrSubnetAssociation01
  ]
}

module udrSubnetAssociation03 './helpers/deploy-subnets-to-vnet/main.bicep' = if (varDeployUdrEffective) {
  name: 'm-udr-subnet-association-03'
  scope: varVnetResourceGroupScope
  params: {
    existingVNetName: virtualNetworkResourceId
    subnets: [varUdrSubnetDefinitions[2]]
    apimSubnetDelegationServiceName: varApimSubnetDelegationServiceName
  }
  dependsOn: [
    udrSubnetAssociation02
  ]
}

module udrSubnetAssociation04 './helpers/deploy-subnets-to-vnet/main.bicep' = if (varDeployUdrEffective) {
  name: 'm-udr-subnet-association-04'
  scope: varVnetResourceGroupScope
  params: {
    existingVNetName: virtualNetworkResourceId
    subnets: [varUdrSubnetDefinitions[3]]
    apimSubnetDelegationServiceName: varApimSubnetDelegationServiceName
  }
  dependsOn: [
    udrSubnetAssociation03
  ]
}

module udrSubnetAssociation05 './helpers/deploy-subnets-to-vnet/main.bicep' = if (varDeployUdrEffective) {
  name: 'm-udr-subnet-association-05'
  scope: varVnetResourceGroupScope
  params: {
    existingVNetName: virtualNetworkResourceId
    subnets: [varUdrSubnetDefinitions[4]]
    apimSubnetDelegationServiceName: varApimSubnetDelegationServiceName
  }
  dependsOn: [
    udrSubnetAssociation04
  ]
}

module udrSubnetAssociation06 './helpers/deploy-subnets-to-vnet/main.bicep' = if (varDeployUdrEffective) {
  name: 'm-udr-subnet-association-06'
  scope: varVnetResourceGroupScope
  params: {
    existingVNetName: virtualNetworkResourceId
    subnets: [varUdrSubnetDefinitions[5]]
    apimSubnetDelegationServiceName: varApimSubnetDelegationServiceName
  }
  dependsOn: [
    udrSubnetAssociation05
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

var varWantsBuildVm = deployToggles.?buildVm ?? false
// In Platform Landing Zone mode, do not deploy workload VMs.
var varDeployBuildVm = varWantsBuildVm && !varIsPlatformLz
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

@description('Size of the test VM')
param vmSize string = 'Standard_D8s_v5'

@description('Image SKU (e.g., win11-25h2-ent, win11-23h2-ent, 2022-datacenter).')
param vmImageSku string = 'win11-25h2-ent'

@description('Image publisher (Windows 11: MicrosoftWindowsDesktop, Windows Server: MicrosoftWindowsServer).')
param vmImagePublisher string = 'MicrosoftWindowsDesktop'

@description('Image offer (Windows 11: windows-11, Windows Server: WindowsServer).')
param vmImageOffer string = 'windows-11'

@description('Image version (use latest unless you need a pinned build).')
param vmImageVersion string = 'latest'

@description('Optional. Cache-busting tag for the Jump VM Custom Script Extension. When set, forces the extension to re-run. Default: empty (no forced re-run).')
param jumpVmCseForceUpdateTag string = ''

@description('Optional. Public URL of install.ps1 for the Jump VM Custom Script Extension. Override to point to your fork/branch when testing changes.')
param jumpVmInstallScriptUri string = ''

@description('Optional. GitHub repo owner/name used to build the default raw URL for install.ps1 when jumpVmInstallScriptUri is empty.')
param jumpVmInstallScriptRepo string = 'Azure/AI-Landing-Zones'

@description('Optional. Git branch/tag name passed to install.ps1 (-release). Keep in sync with jumpVmInstallScriptUri when overriding.')
param jumpVmInstallScriptRelease string = 'main'

var varDeployJumpVm = (deployToggles.?jumpVm ?? false) && !varIsPlatformLz
var varJumpVmMaintenanceConfigured = varDeployJumpVm && (jumpVmMaintenanceDefinition != null)
var varJumpVmName = empty(jumpVmDefinition.?name ?? '')
  ? 'vm-${substring(baseName, 0, 6)}-jmp'
  : (jumpVmDefinition.?name ?? 'vm-${substring(baseName, 0, 6)}-jmp')
var varJumpSubnetId = empty(resourceIds.?virtualNetworkResourceId!)
  ? '${virtualNetworkResourceId}/subnets/jumpbox-subnet'
  : '${resourceIds.virtualNetworkResourceId!}/subnets/jumpbox-subnet'

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
        name: varJumpVmName // Shorter name to avoid Windows 15-char limit
        sku: vmSize
        adminUsername: 'azureuser'
        osType: 'Windows'
        imageReference: {
          publisher: vmImagePublisher
          offer: vmImageOffer
          sku: vmImageSku
          version: vmImageVersion
        }
        encryptionAtHost: false
        managedIdentities: {
          systemAssigned: true
          userAssignedResourceIds: []
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
          diskSizeGB: 250
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

var jumpVmInstallFileUris = [
  (empty(jumpVmInstallScriptUri)
    ? 'https://raw.githubusercontent.com/${jumpVmInstallScriptRepo}/${jumpVmInstallScriptRelease}/bicep/infra/install.ps1'
    : jumpVmInstallScriptUri)
]

var varAssignJumpVmContributorRoleAtRg = varDeployJumpVm && (jumpVmDefinition.?assignContributorRoleAtResourceGroup ?? true)

module jumpVmRgContributorRole './components/security/vm-role-assignment.bicep' = if (varAssignJumpVmContributorRoleAtRg) {
  name: 'jumpVmRgContributorRole-${varUniqueSuffix}'
  params: {
    vmName: varJumpVmName
    roleDefinitionGuid: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    jumpVm
  ]
}

resource jumpVmCse 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = if (varDeployJumpVm && (jumpVmDefinition.?enableAutoInstall ?? true)) {
  name: '${varJumpVmName}/cse'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: jumpVmInstallFileUris
      commandToExecute: 'powershell.exe -NoProfile -ExecutionPolicy Unrestricted -Command "& { & .\\install.ps1 -release ${jumpVmInstallScriptRelease} -skipReboot:$true -skipRepoClone:$true -skipAzdInit:$true -azureTenantID ${subscription().tenantId} -azureSubscriptionID ${subscription().subscriptionId} -AzureResourceGroupName ${resourceGroup().name} -azureLocation ${location} -AzdEnvName ai-lz-${resourceToken} -resourceToken ${resourceToken} -useUAI false }"'
    }
    ...(empty(jumpVmCseForceUpdateTag) ? {} : {
      forceUpdateTag: jumpVmCseForceUpdateTag
    })
  }
  dependsOn: [
    jumpVm
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

@description('Agent subnet resource ID (agent-subnet) when configured.')
output agentSubnetResourceId string = varAgentSubnetResourceId

@description('Private Endpoints subnet resource ID (pe-subnet) when configured.')
output privateEndpointsSubnetResourceId string = varPrivateEndpointsSubnetResourceId

@description('Application Gateway subnet resource ID (appgw-subnet) when configured.')
output applicationGatewaySubnetResourceId string = varApplicationGatewaySubnetResourceId

@description('API Management subnet resource ID (apim-subnet) when configured.')
output apiManagementSubnetResourceId string = varApiManagementSubnetResourceId

@description('Azure Container Apps Environment subnet resource ID (aca-env-subnet) when configured.')
output acaEnvironmentSubnetResourceId string = varAcaEnvironmentSubnetResourceId

@description('DevOps agents subnet resource ID (devops-agents-subnet) when configured.')
output devopsAgentsSubnetResourceId string = varDevopsAgentsSubnetResourceId

@description('Jumpbox subnet resource ID (jumpbox-subnet) when configured.')
output jumpboxSubnetResourceId string = varJumpboxSubnetResourceId

@description('Azure Bastion subnet resource ID (AzureBastionSubnet) when configured.')
output bastionSubnetResourceId string = varBastionSubnetResourceId

@description('Azure Firewall subnet resource ID (AzureFirewallSubnet) when configured.')
output firewallSubnetResourceId string = varFirewallSubnetResourceId

@description('Azure Bastion host resource ID (existing), if provided.')
output bastionHostResourceId string = resourceIds.?bastionHostResourceId ?? ''

// Private DNS Zone Outputs
@description('API Management Private DNS Zone resource ID (existing or newly created).')
output apimPrivateDnsZoneResourceId string = varApimPrivateDnsZoneResourceId

@description('Cognitive Services Private DNS Zone resource ID (existing or newly created).')
output cognitiveServicesPrivateDnsZoneResourceId string = varCognitiveServicesPrivateDnsZoneResourceId

@description('OpenAI Private DNS Zone resource ID (existing or newly created).')
output openAiPrivateDnsZoneResourceId string = varOpenAiPrivateDnsZoneResourceId

@description('AI Services Private DNS Zone resource ID (existing or newly created).')
output aiServicesPrivateDnsZoneResourceId string = varAiServicesPrivateDnsZoneResourceId

@description('AI Search Private DNS Zone resource ID (existing or newly created).')
output searchPrivateDnsZoneResourceId string = varSearchPrivateDnsZoneResourceId

@description('Cosmos DB (SQL) Private DNS Zone resource ID (existing or newly created).')
output cosmosSqlPrivateDnsZoneResourceId string = varCosmosSqlPrivateDnsZoneResourceId

@description('Blob Storage Private DNS Zone resource ID (existing or newly created).')
output blobPrivateDnsZoneResourceId string = varBlobPrivateDnsZoneResourceId

@description('Key Vault Private DNS Zone resource ID (existing or newly created).')
output keyVaultPrivateDnsZoneResourceId string = varKeyVaultPrivateDnsZoneResourceId

@description('App Configuration Private DNS Zone resource ID (existing or newly created).')
output appConfigPrivateDnsZoneResourceId string = varAppConfigPrivateDnsZoneResourceId

@description('Container Apps Private DNS Zone resource ID (existing or newly created).')
output containerAppsPrivateDnsZoneResourceId string = varContainerAppsPrivateDnsZoneResourceId

@description('Container Registry Private DNS Zone resource ID (existing or newly created).')
output acrPrivateDnsZoneResourceId string = varAcrPrivateDnsZoneResourceId

@description('Application Insights Private DNS Zone resource ID (existing or newly created).')
output appInsightsPrivateDnsZoneResourceId string = varAppInsightsPrivateDnsZoneResourceId

// Public IP Outputs
@description('Application Gateway Public IP resource ID (newly created or existing).')
output appGatewayPublicIpResourceId string = appGatewayPublicIpResourceId

@description('Firewall Public IP resource ID (newly created or existing).')
output firewallPublicIpResourceId string = firewallPublicIpResourceId

// VNet Peering Outputs
@description('Hub to Spoke peering resource ID (if hub peering is enabled).')
output hubToSpokePeeringResourceId string = varDeployHubToSpokePeering
  ? hubToSpokePeering!.outputs.peeringResourceId
  : ''

// UDR Outputs
@description('User Defined Route Table resource ID (if deployed).')
output userDefinedRouteTableResourceId string = varUdrDefaultRouteTableId

@description('User Defined Route Table (App Gateway exception) resource ID (if deployed).')
output userDefinedRouteTableAppGatewayExceptionResourceId string = varUdrAppGwRouteTableId

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

var varContainerAppsPairs = [
  for (app, i) in containerAppsList: {
    name: app.name
    id: resourceId('Microsoft.App/containerApps', app.name)
  }
]

@description('Map of Container App name to resource ID (only populated when Container Apps are deployed).')
output containerAppsResourceIdsByName object = varDeployContainerApps
  ? reduce(varContainerAppsPairs, {}, (acc, p) => union(acc, {
      '${p.name}': p.id
    }))
  : {}

@description('Map of AI Foundry model deployment name to resource ID (only populated when AI Foundry is deployed).')
output aiFoundryModelDeploymentsResourceIdsByName object = varDeployAiFoundry
  ? aiFoundry!.outputs.modelDeploymentsResourceIdsByName
  : {}

// Private Endpoint Outputs
@description('App Configuration Private Endpoint resource ID (if deployed).')
output appConfigPrivateEndpointResourceId string = (varDeployPrivateEndpoints && varHasAppConfig) ? privateEndpointAppConfig!.outputs.resourceId : ''

@description('API Management Private Endpoint resource ID (if deployed).')
output apimPrivateEndpointResourceId string = (varDeployPrivateEndpoints && varHasApim && varApimWantsPrivateEndpoint && apimSupportsPe) ? privateEndpointApim!.outputs.resourceId : ''

@description('Container Apps Environment Private Endpoint resource ID (if deployed).')
output containerAppsEnvPrivateEndpointResourceId string = (varDeployPrivateEndpoints && varHasContainerEnv) ? privateEndpointContainerAppsEnv!.outputs.resourceId : ''

@description('Container Registry Private Endpoint resource ID (if deployed).')
output acrPrivateEndpointResourceId string = (varDeployPrivateEndpoints && varHasAcr) ? privateEndpointAcr!.outputs.resourceId : ''

@description('Storage Account (Blob) Private Endpoint resource ID (if deployed).')
output storageBlobPrivateEndpointResourceId string = (varDeployPrivateEndpoints && varHasStorage) ? privateEndpointStorageBlob!.outputs.resourceId : ''

@description('Cosmos DB (SQL) Private Endpoint resource ID (if deployed).')
output cosmosPrivateEndpointResourceId string = (varDeployPrivateEndpoints && varHasCosmos) ? privateEndpointCosmos!.outputs.resourceId : ''

@description('AI Search Private Endpoint resource ID (if deployed).')
output searchPrivateEndpointResourceId string = (varDeployPrivateEndpoints && varHasSearch) ? privateEndpointSearch!.outputs.resourceId : ''

@description('Key Vault Private Endpoint resource ID (if deployed).')
output keyVaultPrivateEndpointResourceId string = (varDeployPrivateEndpoints && varHasKv) ? privateEndpointKeyVault!.outputs.resourceId : ''

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
output cosmosDbResourceId string = varCosmosDbResourceId

// Key Vault Outputs
@description('Key Vault resource ID.')
output keyVaultResourceId string = varKeyVaultResourceId

// AI Search Outputs
@description('AI Search resource ID.')
output aiSearchResourceId string = varAiSearchResourceId

// API Management Outputs
@description('API Management service resource ID.')
output apimServiceResourceId string = varApimServiceResourceId

// AI Foundry Outputs
// (Names omitted to stay within Bicep 64-output limit; resource IDs are exposed elsewhere.)

// Bing Grounding Outputs
@description('Bing Search service resource ID (if deployed).')
output bingSearchResourceId string = varInvokeBingModule ? bingSearch!.outputs.resourceId : ''

// Gateways and Firewall Outputs
@description('WAF Policy resource ID (if deployed).')
output wafPolicyResourceId string = varDeployWafPolicy ? wafPolicy!.outputs.resourceId : ''

@description('Application Gateway resource ID (newly created or existing).')
output applicationGatewayResourceId string = varAppGatewayResourceId

@description('Azure Firewall Policy resource ID (if deployed).')
output firewallPolicyResourceId string = firewallPolicyResourceId

@description('Azure Firewall resource ID (newly created or existing).')
output firewallResourceId string = varFirewallResourceId

// Virtual Machines Outputs
@description('Build VM resource ID (if deployed).')
output buildVmResourceId string = varDeployBuildVm ? buildVm!.outputs.resourceId : ''

@description('Jump VM resource ID (if deployed).')
output jumpVmResourceId string = varDeployJumpVm ? jumpVm!.outputs.resourceId : ''

// Container Apps Outputs

