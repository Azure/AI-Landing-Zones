metadata name = 'AI/ML Landing Zone'
metadata description = 'Deploys a secure AI/ML landing zone (resource groups, networking, AI services, private endpoints, and guardrails) using AVM resource modules - Modularized Version.'

///////////////////////////////////////////////////////////////////////////////////////////////////
// main.bicep - Modularized Version
//
// This version uses extracted modules to reduce file size and improve maintainability.
// All deployment logic has been moved to dedicated modules in the ./modules/ directory.
///////////////////////////////////////////////////////////////////////////////////////////////////

targetScope = 'resourceGroup'

import {
  deployTogglesType
  resourceIdsType
  tagsType
  vNetDefinitionType
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
  appGatewayDefinitionType
  firewallPolicyDefinitionType
  firewallDefinitionType
  vmDefinitionType
  vmMaintenanceDefinitionType
  privateDnsZoneDefinitionType
} from './common/types.bicep'

// -----------------------
// 1. GLOBAL PARAMETERS
// -----------------------

@description('Required. Per-service deployment toggles.')
param deployToggles deployTogglesType

@description('Optional. Enable platform landing zone integration.')
param flagPlatformLandingZone bool = false

@description('Optional. Existing resource IDs to reuse.')
param resourceIds resourceIdsType = {}

@description('Optional. Azure region for AI LZ resources.')
param location string = resourceGroup().location

@description('Optional. Deterministic token for resource names.')
param resourceToken string = toLower(uniqueString(subscription().id, resourceGroup().name, location))

@description('Optional. Base name to seed resource names.')
param baseName string = substring(resourceToken, 0, 12)

@description('Optional. Enable/Disable usage telemetry.')
param enableTelemetry bool = true

@description('Optional. Tags to apply to all resources.')
param tags tagsType = {}

@description('Optional. Enable Microsoft Defender for AI.')
param enableDefenderForAI bool = true

// -----------------------
// 2. NSG DEFINITIONS
// -----------------------

@description('Optional. NSG definitions per subnet role.')
param nsgDefinitions nsgPerSubnetDefinitionsType?

// -----------------------
// 3. NETWORKING PARAMETERS
// -----------------------

@description('Conditional. Virtual Network configuration.')
param vNetDefinition vNetDefinitionType?

// Removed unused parameter: existingVNetSubnetsDefinition

@description('Conditional. Public IP for Application Gateway.')
param appGatewayPublicIp publicIpDefinitionType?

@description('Conditional. Public IP for Azure Firewall.')
param firewallPublicIp publicIpDefinitionType?

@description('Optional. Hub VNet peering configuration.')
param hubVnetPeeringDefinition hubVnetPeeringDefinitionType?

// -----------------------
// 4. PRIVATE DNS ZONES
// -----------------------

@description('Optional. Private DNS Zone configuration.')
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

@description('Optional. API Management Private DNS Zone configuration.')
param apimPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

@description('Optional. Cognitive Services Private DNS Zone configuration.')
param cognitiveServicesPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

@description('Optional. OpenAI Private DNS Zone configuration.')
param openAiPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

@description('Optional. AI Services Private DNS Zone configuration.')
param aiServicesPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

@description('Optional. Azure AI Search Private DNS Zone configuration.')
param searchPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

@description('Optional. Cosmos DB Private DNS Zone configuration.')
param cosmosPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

@description('Optional. Blob Storage Private DNS Zone configuration.')
param blobPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

@description('Optional. Key Vault Private DNS Zone configuration.')
param keyVaultPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

@description('Optional. App Configuration Private DNS Zone configuration.')
param appConfigPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

@description('Optional. Container Apps Private DNS Zone configuration.')
param containerAppsPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

@description('Optional. Container Registry Private DNS Zone configuration.')
param acrPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

@description('Optional. Application Insights Private DNS Zone configuration.')
param appInsightsPrivateDnsZoneDefinition privateDnsZoneDefinitionType?

// -----------------------
// 5. OBSERVABILITY PARAMETERS
// -----------------------

@description('Conditional. Log Analytics Workspace configuration.')
param logAnalyticsDefinition logAnalyticsDefinitionType?

@description('Conditional. Application Insights configuration.')
param appInsightsDefinition appInsightsDefinitionType?

// -----------------------
// 6. DATA SERVICES PARAMETERS
// -----------------------

@description('Conditional. Storage Account configuration.')
param storageAccountDefinition storageAccountDefinitionType?

@description('Optional. App Configuration store settings.')
param appConfigurationDefinition appConfigurationDefinitionType?

@description('Optional. Cosmos DB settings.')
param cosmosDbDefinition genAIAppCosmosDbDefinitionType?

@description('Optional. Key Vault settings.')
param keyVaultDefinition keyVaultDefinitionType?

@description('Optional. AI Search settings.')
param aiSearchDefinition kSAISearchDefinitionType?

// -----------------------
// 7. CONTAINER PLATFORM PARAMETERS
// -----------------------

@description('Conditional. Container Apps Environment configuration.')
param containerAppEnvDefinition containerAppEnvDefinitionType?

@description('Conditional. Container Registry configuration.')
param containerRegistryDefinition containerRegistryDefinitionType?

@description('Optional. List of Container Apps to create.')
param containerAppsList containerAppDefinitionType[] = []

// -----------------------
// 8. PRIVATE ENDPOINTS PARAMETERS
// -----------------------

@description('Optional. App Configuration Private Endpoint configuration.')
param appConfigPrivateEndpointDefinition privateDnsZoneDefinitionType?

@description('Optional. API Management Private Endpoint configuration.')
param apimPrivateEndpointDefinition privateDnsZoneDefinitionType?

@description('Optional. Container Apps Environment Private Endpoint configuration.')
param containerAppEnvPrivateEndpointDefinition privateDnsZoneDefinitionType?

@description('Optional. Azure Container Registry Private Endpoint configuration.')
param acrPrivateEndpointDefinition privateDnsZoneDefinitionType?

@description('Optional. Storage Account Private Endpoint configuration.')
param storageBlobPrivateEndpointDefinition privateDnsZoneDefinitionType?

@description('Optional. Cosmos DB Private Endpoint configuration.')
param cosmosPrivateEndpointDefinition privateDnsZoneDefinitionType?

@description('Optional. Azure AI Search Private Endpoint configuration.')
param searchPrivateEndpointDefinition privateDnsZoneDefinitionType?

@description('Optional. Key Vault Private Endpoint configuration.')
param keyVaultPrivateEndpointDefinition privateDnsZoneDefinitionType?

// -----------------------
// 9. API MANAGEMENT PARAMETERS
// -----------------------

@description('Optional. API Management configuration.')
param apimDefinition apimDefinitionType?

// -----------------------
// 10. GATEWAY & SECURITY PARAMETERS
// -----------------------

@description('Conditional. Application Gateway configuration.')
param appGatewayDefinition appGatewayDefinitionType?

@description('Conditional. Azure Firewall Policy configuration.')
param firewallPolicyDefinition firewallPolicyDefinitionType?

@description('Conditional. Azure Firewall configuration.')
param firewallDefinition firewallDefinitionType?

// -----------------------
// 11. COMPUTE PARAMETERS
// -----------------------

@description('Conditional. Build VM configuration.')
param buildVmDefinition vmDefinitionType?

@description('Optional. Build VM Maintenance Definition.')
param buildVmMaintenanceDefinition vmMaintenanceDefinitionType?

@description('Optional. Auto-generated random password for Build VM.')
@secure()
param buildVmAdminPassword string = '${toUpper(substring(replace(newGuid(), '-', ''), 0, 8))}${toLower(substring(replace(newGuid(), '-', ''), 8, 8))}@${substring(replace(newGuid(), '-', ''), 16, 4)}!'

@description('Conditional. Jump VM configuration.')
param jumpVmDefinition vmDefinitionType?

@description('Optional. Jump VM Maintenance Definition.')
param jumpVmMaintenanceDefinition vmMaintenanceDefinitionType?

@description('Optional. Auto-generated random password for Jump VM.')
@secure()
param jumpVmAdminPassword string = '${toUpper(substring(replace(newGuid(), '-', ''), 0, 8))}${toLower(substring(replace(newGuid(), '-', ''), 8, 8))}@${substring(replace(newGuid(), '-', ''), 16, 4)}!'

// -----------------------
// 12. AI FOUNDRY PARAMETERS
// -----------------------

@description('Optional. AI Foundry Hub configuration.')
param aiFoundryDefinition aiFoundryDefinitionType?

// -----------------------
// 13. BING GROUNDING PARAMETERS
// -----------------------

@description('Optional. Bing Grounding configuration.')
param bingGroundingDefinition kSGroundingWithBingDefinitionType?

// -----------------------
// TELEMETRY
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
// VARIABLES
// -----------------------

var varUniqueSuffix = substring(uniqueString(deployment().name, location, resourceGroup().id), 0, 8)

// Private DNS and Private Endpoint control flags
var varDeployPdnsAndPe = !flagPlatformLandingZone
var varUseExistingPdz = {
  apim: !empty(privateDnsZonesDefinition.?apimZoneId ?? '')
  cognitiveservices: !empty(privateDnsZonesDefinition.?cognitiveservicesZoneId ?? '')
  openai: !empty(privateDnsZonesDefinition.?openaiZoneId ?? '')
  aiServices: !empty(privateDnsZonesDefinition.?aiServicesZoneId ?? '')
  search: !empty(privateDnsZonesDefinition.?searchZoneId ?? '')
  cosmosSql: !empty(privateDnsZonesDefinition.?cosmosSqlZoneId ?? '')
  blob: !empty(privateDnsZonesDefinition.?blobZoneId ?? '')
  keyVault: !empty(privateDnsZonesDefinition.?keyVaultZoneId ?? '')
  appConfig: !empty(privateDnsZonesDefinition.?appConfigZoneId ?? '')
  containerApps: !empty(privateDnsZonesDefinition.?containerAppsZoneId ?? '')
  acr: !empty(privateDnsZonesDefinition.?acrZoneId ?? '')
  appInsights: !empty(privateDnsZonesDefinition.?appInsightsZoneId ?? '')
}

// Resource existence flags for private endpoints
var varDeployAppConfig = empty(resourceIds.?appConfigResourceId!) && deployToggles.appConfig
var varDeployContainerAppEnv = empty(resourceIds.?containerEnvResourceId!) && deployToggles.containerEnv
var varDeployAcr = empty(resourceIds.?containerRegistryResourceId!) && deployToggles.containerRegistry
var varDeploySa = empty(resourceIds.?storageAccountResourceId!) && deployToggles.storageAccount

var varHasAppConfig = !empty(resourceIds.?appConfigResourceId!) || varDeployAppConfig
var varHasApim = !empty(resourceIds.?apimServiceResourceId!) || deployToggles.apiManagement
var varHasContainerEnv = !empty(resourceIds.?containerEnvResourceId!) || varDeployContainerAppEnv
var varHasAcr = !empty(resourceIds.?containerRegistryResourceId!) || varDeployAcr
var varHasStorage = !empty(resourceIds.?storageAccountResourceId!) || varDeploySa
var varHasCosmos = cosmosDbDefinition != null
var varHasSearch = aiSearchDefinition != null
var varHasKv = keyVaultDefinition != null

var deployKeyVault = keyVaultDefinition != null

// -----------------------
// MICROSOFT DEFENDER FOR AI
// -----------------------

module defenderModule './components/defender/main.bicep' = if (enableDefenderForAI) {
  name: 'defender-${varUniqueSuffix}'
  scope: subscription()
  params: {
    enableDefenderForAI: enableDefenderForAI
    enableDefenderForKeyVault: deployKeyVault
  }
}

// -----------------------
// MODULE 1: NETWORK SECURITY GROUPS
// -----------------------

module nsgs './modules/network-security.bicep' = {
  name: 'deploy-nsgs-${varUniqueSuffix}'
  params: {
    baseName: baseName
    location: location
    enableTelemetry: enableTelemetry
    deployToggles: deployToggles
    resourceIds: resourceIds
    nsgDefinitions: nsgDefinitions
  }
}

// NSG outputs
var agentNsgResourceId = nsgs.outputs.agentNsgResourceId
var peNsgResourceId = nsgs.outputs.peNsgResourceId
var applicationGatewayNsgResourceId = nsgs.outputs.applicationGatewayNsgResourceId
var apiManagementNsgResourceId = nsgs.outputs.apiManagementNsgResourceId
var acaEnvironmentNsgResourceId = nsgs.outputs.acaEnvironmentNsgResourceId
var jumpboxNsgResourceId = nsgs.outputs.jumpboxNsgResourceId
var devopsBuildAgentsNsgResourceId = nsgs.outputs.devopsBuildAgentsNsgResourceId
var bastionNsgResourceId = nsgs.outputs.bastionNsgResourceId

// -----------------------
// MODULE 2: NETWORKING CORE
// -----------------------

module networkingCore './modules/networking-core.bicep' = {
  name: 'deploy-networking-${varUniqueSuffix}'
  params: {
    baseName: baseName
    location: location
    enableTelemetry: enableTelemetry
    deployToggles: deployToggles
    resourceIds: resourceIds
    vNetDefinition: vNetDefinition
    appGatewayPublicIp: appGatewayPublicIp
    firewallPublicIp: firewallPublicIp
    hubVnetPeeringDefinition: hubVnetPeeringDefinition
    agentNsgResourceId: agentNsgResourceId
    peNsgResourceId: peNsgResourceId
    applicationGatewayNsgResourceId: applicationGatewayNsgResourceId
    apiManagementNsgResourceId: apiManagementNsgResourceId
    acaEnvironmentNsgResourceId: acaEnvironmentNsgResourceId
    jumpboxNsgResourceId: jumpboxNsgResourceId
    devopsBuildAgentsNsgResourceId: devopsBuildAgentsNsgResourceId
    bastionNsgResourceId: bastionNsgResourceId
  }
}

// Networking outputs
var virtualNetworkResourceId = networkingCore.outputs.virtualNetworkResourceId
var varPeSubnetId = networkingCore.outputs.peSubnetId
var varAppGatewaySubnetId = networkingCore.outputs.appGatewaySubnetId
var appGatewayPublicIpResourceId = networkingCore.outputs.appGatewayPublicIpResourceId
var firewallPublicIpResourceId = networkingCore.outputs.firewallPublicIpResourceId

// -----------------------
// MODULE 3: PRIVATE DNS ZONES
// -----------------------

module privateDnsZones './modules/private-dns-zones.bicep' = if (varDeployPdnsAndPe) {
  name: 'deploy-dns-zones-${varUniqueSuffix}'
  params: {
    location: location
    enableTelemetry: enableTelemetry
    privateDnsZonesDefinition: privateDnsZonesDefinition
    varDeployPdnsAndPe: varDeployPdnsAndPe
    varUseExistingPdz: varUseExistingPdz
    varVnetResourceId: virtualNetworkResourceId
    varVnetName: 'vnet-${baseName}'
    apimPrivateDnsZoneDefinition: apimPrivateDnsZoneDefinition
    cognitiveServicesPrivateDnsZoneDefinition: cognitiveServicesPrivateDnsZoneDefinition
    openAiPrivateDnsZoneDefinition: openAiPrivateDnsZoneDefinition
    aiServicesPrivateDnsZoneDefinition: aiServicesPrivateDnsZoneDefinition
    searchPrivateDnsZoneDefinition: searchPrivateDnsZoneDefinition
    cosmosPrivateDnsZoneDefinition: cosmosPrivateDnsZoneDefinition
    blobPrivateDnsZoneDefinition: blobPrivateDnsZoneDefinition
    keyVaultPrivateDnsZoneDefinition: keyVaultPrivateDnsZoneDefinition
    appConfigPrivateDnsZoneDefinition: appConfigPrivateDnsZoneDefinition
    containerAppsPrivateDnsZoneDefinition: containerAppsPrivateDnsZoneDefinition
    acrPrivateDnsZoneDefinition: acrPrivateDnsZoneDefinition
    appInsightsPrivateDnsZoneDefinition: appInsightsPrivateDnsZoneDefinition
  }
}

// -----------------------
// MODULE 4: OBSERVABILITY
// -----------------------

module observability './modules/observability.bicep' = {
  name: 'deploy-observability-${varUniqueSuffix}'
  params: {
    baseName: baseName
    location: location
    enableTelemetry: enableTelemetry
    tags: tags
    deployToggles: deployToggles
    resourceIds: resourceIds
    logAnalyticsDefinition: logAnalyticsDefinition
    appInsightsDefinition: appInsightsDefinition
  }
}

var varLogAnalyticsWorkspaceResourceId = observability.outputs.logAnalyticsWorkspaceResourceId
var varAppiResourceId = observability.outputs.appInsightsResourceId

// -----------------------
// MODULE 5: DATA SERVICES
// -----------------------

module dataServices './modules/data-services.bicep' = {
  name: 'deploy-data-services-${varUniqueSuffix}'
  params: {
    baseName: baseName
    location: location
    enableTelemetry: enableTelemetry
    tags: tags
    deployToggles: deployToggles
    resourceIds: resourceIds
    storageAccountDefinition: storageAccountDefinition
    cosmosDbDefinition: cosmosDbDefinition
    keyVaultDefinition: keyVaultDefinition
    aiSearchDefinition: aiSearchDefinition
    appConfigurationDefinition: appConfigurationDefinition
  }
}

var varSaResourceId = dataServices.outputs.storageAccountResourceId
var appConfigResourceId = dataServices.outputs.appConfigResourceId
var cosmosDbResourceId = dataServices.outputs.cosmosDbResourceId
var keyVaultResourceId = dataServices.outputs.keyVaultResourceId
var aiSearchResourceId = dataServices.outputs.aiSearchResourceId

// -----------------------
// MODULE 6: CONTAINER PLATFORM
// -----------------------

module containerPlatform './modules/container-platform.bicep' = {
  name: 'deploy-container-platform-${varUniqueSuffix}'
  params: {
    baseName: baseName
    location: location
    enableTelemetry: enableTelemetry
    tags: tags
    deployToggles: deployToggles
    resourceIds: resourceIds
    containerAppEnvDefinition: containerAppEnvDefinition
    containerRegistryDefinition: containerRegistryDefinition
    containerAppsList: containerAppsList
    virtualNetworkResourceId: virtualNetworkResourceId
    appInsightsConnectionString: varAppiResourceId
    varUniqueSuffix: varUniqueSuffix
  }
}

var varContainerEnvResourceId = containerPlatform.outputs.containerEnvResourceId
var varAcrResourceId = containerPlatform.outputs.containerRegistryResourceId

// -----------------------
// MODULE 7: PRIVATE ENDPOINTS
// -----------------------

module privateEndpoints './modules/private-endpoints.bicep' = if (varDeployPdnsAndPe) {
  name: 'deploy-private-endpoints-${varUniqueSuffix}'
  params: {
    baseName: baseName
    location: location
    enableTelemetry: enableTelemetry
    tags: tags
    varPeSubnetId: varPeSubnetId
    varDeployPdnsAndPe: varDeployPdnsAndPe
    varUniqueSuffix: varUniqueSuffix
    varHasAppConfig: varHasAppConfig
    varHasApim: varHasApim
    varHasContainerEnv: varHasContainerEnv
    varHasAcr: varHasAcr
    varHasStorage: varHasStorage
    varHasCosmos: varHasCosmos
    varHasSearch: varHasSearch
    varHasKv: varHasKv
    appConfigResourceId: appConfigResourceId
    apimResourceId: '' // Will be populated after APIM module
    containerEnvResourceId: varContainerEnvResourceId
    acrResourceId: varAcrResourceId
    storageAccountResourceId: varSaResourceId
    cosmosDbResourceId: cosmosDbResourceId
    aiSearchResourceId: aiSearchResourceId
    keyVaultResourceId: keyVaultResourceId
    apimDefinition: apimDefinition
    appConfigDnsZoneId: varDeployPdnsAndPe ? privateDnsZones!.outputs.appConfigDnsZoneId : ''
    apimDnsZoneId: varDeployPdnsAndPe ? privateDnsZones!.outputs.apimDnsZoneId : ''
    containerAppsDnsZoneId: varDeployPdnsAndPe ? privateDnsZones!.outputs.containerAppsDnsZoneId : ''
    acrDnsZoneId: varDeployPdnsAndPe ? privateDnsZones!.outputs.acrDnsZoneId : ''
    blobDnsZoneId: varDeployPdnsAndPe ? privateDnsZones!.outputs.blobDnsZoneId : ''
    cosmosSqlDnsZoneId: varDeployPdnsAndPe ? privateDnsZones!.outputs.cosmosSqlDnsZoneId : ''
    searchDnsZoneId: varDeployPdnsAndPe ? privateDnsZones!.outputs.searchDnsZoneId : ''
    keyVaultDnsZoneId: varDeployPdnsAndPe ? privateDnsZones!.outputs.keyVaultDnsZoneId : ''
    appConfigPrivateEndpointDefinition: appConfigPrivateEndpointDefinition
    apimPrivateEndpointDefinition: apimPrivateEndpointDefinition
    containerAppEnvPrivateEndpointDefinition: containerAppEnvPrivateEndpointDefinition
    acrPrivateEndpointDefinition: acrPrivateEndpointDefinition
    storageBlobPrivateEndpointDefinition: storageBlobPrivateEndpointDefinition
    cosmosPrivateEndpointDefinition: cosmosPrivateEndpointDefinition
    searchPrivateEndpointDefinition: searchPrivateEndpointDefinition
    keyVaultPrivateEndpointDefinition: keyVaultPrivateEndpointDefinition
  }
}

// -----------------------
// MODULE 8: API MANAGEMENT
// -----------------------

var varDeployApim = empty(resourceIds.?apimServiceResourceId!) && deployToggles.apiManagement

module apiManagement 'wrappers/avm.res.api-management.service.bicep' = if (varDeployApim) {
  name: 'apiManagementDeployment'
  params: {
    apiManagement: union(
      {
        name: 'apim-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
        tags: tags
        publisherEmail: 'admin@contoso.com'
        publisherName: 'Contoso'
      },
      apimDefinition ?? {}
    )
  }
}

// -----------------------
// MODULE 9: GATEWAY & SECURITY
// -----------------------

module gatewaySecurity './modules/gateway-security.bicep' = {
  name: 'deploy-gateway-security-${varUniqueSuffix}'
  params: {
    baseName: baseName
    location: location
    enableTelemetry: enableTelemetry
    tags: tags
    deployToggles: deployToggles
    resourceIds: resourceIds
    appGatewayDefinition: appGatewayDefinition
    firewallPolicyDefinition: firewallPolicyDefinition
    firewallDefinition: firewallDefinition
    virtualNetworkResourceId: virtualNetworkResourceId
    appGatewaySubnetId: varAppGatewaySubnetId
    appGatewayPublicIpResourceId: appGatewayPublicIpResourceId
    firewallPublicIpResourceId: firewallPublicIpResourceId
    varDeployApGatewayPip: deployToggles.applicationGatewayPublicIp && empty(resourceIds.?appGatewayPublicIpResourceId)
  }
}

var varAppGatewayResourceId = gatewaySecurity.outputs.applicationGatewayResourceId
var varFirewallResourceId = gatewaySecurity.outputs.firewallResourceId
var firewallPolicyResourceId = gatewaySecurity.outputs.firewallPolicyResourceId

// -----------------------
// MODULE 10: COMPUTE
// -----------------------

module compute './modules/compute.bicep' = {
  name: 'deploy-compute-${varUniqueSuffix}'
  params: {
    baseName: baseName
    location: location
    enableTelemetry: enableTelemetry
    tags: tags
    deployToggles: deployToggles
    buildVmDefinition: buildVmDefinition
    buildVmMaintenanceDefinition: buildVmMaintenanceDefinition
    jumpVmDefinition: jumpVmDefinition
    jumpVmMaintenanceDefinition: jumpVmMaintenanceDefinition
    buildVmAdminPassword: buildVmAdminPassword
    jumpVmAdminPassword: jumpVmAdminPassword
    buildSubnetId: '${virtualNetworkResourceId}/subnets/agent-subnet'
    jumpSubnetId: '${virtualNetworkResourceId}/subnets/jumpbox-subnet'
    varUniqueSuffix: varUniqueSuffix
  }
}

// -----------------------
// MODULE 11: AI FOUNDRY
// -----------------------

var varAiServicesDnsZoneId = varDeployPdnsAndPe ? privateDnsZones.outputs.aiServicesDnsZoneId : privateDnsZonesDefinition.aiServicesZoneId
var varCognitiveServicesDnsZoneId = varDeployPdnsAndPe ? privateDnsZones.outputs.cognitiveServicesDnsZoneId : privateDnsZonesDefinition.cognitiveservicesZoneId
var varOpenAiDnsZoneId = varDeployPdnsAndPe ? privateDnsZones.outputs.openAiDnsZoneId : privateDnsZonesDefinition.openaiZoneId

var defaultAiFoundryNetworking = {
  aiServicesPrivateDnsZoneResourceId: varAiServicesDnsZoneId
  cognitiveServicesPrivateDnsZoneResourceId: varCognitiveServicesDnsZoneId
  openAiPrivateDnsZoneResourceId: varOpenAiDnsZoneId
  agentServiceSubnetResourceId: '${virtualNetworkResourceId}/subnets/agent-subnet'
}

var userAiFoundryConfig = aiFoundryDefinition.?aiFoundryConfiguration ?? {}
var mergedNetworking = union(
  defaultAiFoundryNetworking,
  userAiFoundryConfig.?networking ?? {}
)

var finalAiFoundryConfig = union(
  userAiFoundryConfig,
  { networking: mergedNetworking }
)

module aiFoundry 'wrappers/avm.ptn.ai-ml.ai-foundry.bicep' = if (aiFoundryDefinition != null) {
  name: 'aiFoundryDeployment'
  params: {
    aiFoundry: union(
      {
        baseName: baseName
        name: 'aihub-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
        tags: tags
        privateEndpointSubnetResourceId: varPeSubnetId
        aiSearchConfiguration: !empty(aiSearchResourceId) ? { existingResourceId: aiSearchResourceId } : {}
        keyVaultConfiguration: !empty(keyVaultResourceId) ? { existingResourceId: keyVaultResourceId } : {}
        storageAccountConfiguration: !empty(varSaResourceId) ? { existingResourceId: varSaResourceId } : {}
        cosmosDbConfiguration: !empty(cosmosDbResourceId) ? { existingResourceId: cosmosDbResourceId } : {}
      },
      aiFoundryDefinition ?? {},
      {
        aiFoundryConfiguration: finalAiFoundryConfig
      }
    )
  }
}

// -----------------------
// MODULE 12: BING GROUNDING
// -----------------------

// Decide if Bing module runs (create or reuse+connect)
var varInvokeBingModule = (!empty(resourceIds.?groundingServiceResourceId!)) || (deployToggles.groundingWithBingSearch && empty(resourceIds.?groundingServiceResourceId!))

var varBingNameEffective = empty(bingGroundingDefinition!.?name!)
  ? 'bing-${baseName}'
  : bingGroundingDefinition!.name!

module bingSearch './components/bing-search/main.bicep' = if (varInvokeBingModule && aiFoundryDefinition != null) {
  name: 'bingSearchDeployment'
  params: {
    // AI Foundry context from the AI Foundry module outputs
    accountName: aiFoundry!.outputs.aiServicesName
    projectName: aiFoundry!.outputs.aiProjectName
    
    // Deterministic default for the Bing account (only used on create path)
    bingSearchName: varBingNameEffective
    
    // Optional: custom connection name
    bingConnectionName: '${varBingNameEffective}-connection'
    
    // Reuse path: when provided, the child module will NOT create the Bing account,
    // it will use this existing one and still create the connection
    existingResourceId: resourceIds.?groundingServiceResourceId ?? ''
  }
}

// -----------------------
// OUTPUTS
// -----------------------

@description('Network Security Group Outputs')
output agentNsgResourceId string = agentNsgResourceId
output peNsgResourceId string = peNsgResourceId
output applicationGatewayNsgResourceId string = applicationGatewayNsgResourceId
output apiManagementNsgResourceId string = apiManagementNsgResourceId
output acaEnvironmentNsgResourceId string = acaEnvironmentNsgResourceId
output jumpboxNsgResourceId string = jumpboxNsgResourceId
output devopsBuildAgentsNsgResourceId string = devopsBuildAgentsNsgResourceId
output bastionNsgResourceId string = bastionNsgResourceId

@description('Virtual Network Outputs')
output virtualNetworkResourceId string = virtualNetworkResourceId
output bastionHostResourceId string = networkingCore.outputs.bastionHostResourceId

@description('Observability Outputs')
output logAnalyticsWorkspaceResourceId string = varLogAnalyticsWorkspaceResourceId
output appInsightsResourceId string = varAppiResourceId

@description('Data Services Outputs')
output storageAccountResourceId string = varSaResourceId
output appConfigResourceId string = appConfigResourceId
output cosmosDbResourceId string = cosmosDbResourceId
output keyVaultResourceId string = keyVaultResourceId
output aiSearchResourceId string = aiSearchResourceId

@description('Container Platform Outputs')
output containerEnvResourceId string = varContainerEnvResourceId
output containerRegistryResourceId string = varAcrResourceId

@description('Gateway & Security Outputs')
output applicationGatewayResourceId string = varAppGatewayResourceId
output firewallResourceId string = varFirewallResourceId
output firewallPolicyResourceId string = firewallPolicyResourceId

@description('Compute Outputs')
output buildVmResourceId string = compute.outputs.buildVmResourceId
output jumpVmResourceId string = compute.outputs.jumpVmResourceId
#disable-next-line outputs-should-not-contain-secrets
output jumpVmAdminPassword string = jumpVmAdminPassword

@description('AI Foundry Output')
output aiFoundryProjectName string = (aiFoundryDefinition != null) ? aiFoundry!.outputs.aiProjectName : ''

@description('Bing Search Outputs')
output bingSearchResourceId string = (varInvokeBingModule && aiFoundryDefinition != null) ? bingSearch!.outputs.resourceId : ''
output bingConnectionId string = (varInvokeBingModule && aiFoundryDefinition != null) ? bingSearch!.outputs.bingConnectionId : ''
output bingResourceGroupName string = (varInvokeBingModule && aiFoundryDefinition != null) ? bingSearch!.outputs.resourceGroupName : ''
