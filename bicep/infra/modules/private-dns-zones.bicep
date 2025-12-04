// Private DNS Zones Module
// This module deploys all Private DNS Zones for the AI Landing Zone

import * as types from '../common/types.bicep'

@description('The Azure region for resources.')
param location string

@description('Enable telemetry for AVM modules.')
param enableTelemetry bool

@description('Private DNS Zones configuration.')
param privateDnsZonesDefinition types.privateDnsZonesDefinitionType

@description('Deploy Private DNS and Private Endpoints flag.')
param varDeployPdnsAndPe bool

@description('Use existing Private DNS zones flags.')
param varUseExistingPdz object

@description('Virtual Network Resource ID for DNS zone links.')
param varVnetResourceId string

@description('Virtual Network Name for link naming.')
param varVnetName string

// Individual DNS Zone Configurations
@description('API Management Private DNS Zone configuration.')
param apimPrivateDnsZoneDefinition types.privateDnsZoneDefinitionType?

@description('Cognitive Services Private DNS Zone configuration.')
param cognitiveServicesPrivateDnsZoneDefinition types.privateDnsZoneDefinitionType?

@description('OpenAI Private DNS Zone configuration.')
param openAiPrivateDnsZoneDefinition types.privateDnsZoneDefinitionType?

@description('AI Services Private DNS Zone configuration.')
param aiServicesPrivateDnsZoneDefinition types.privateDnsZoneDefinitionType?

@description('Azure AI Search Private DNS Zone configuration.')
param searchPrivateDnsZoneDefinition types.privateDnsZoneDefinitionType?

@description('Cosmos DB Private DNS Zone configuration.')
param cosmosPrivateDnsZoneDefinition types.privateDnsZoneDefinitionType?

@description('Blob Storage Private DNS Zone configuration.')
param blobPrivateDnsZoneDefinition types.privateDnsZoneDefinitionType?

@description('Key Vault Private DNS Zone configuration.')
param keyVaultPrivateDnsZoneDefinition types.privateDnsZoneDefinitionType?

@description('App Configuration Private DNS Zone configuration.')
param appConfigPrivateDnsZoneDefinition types.privateDnsZoneDefinitionType?

@description('Container Apps Private DNS Zone configuration.')
param containerAppsPrivateDnsZoneDefinition types.privateDnsZoneDefinitionType?

@description('Container Registry Private DNS Zone configuration.')
param acrPrivateDnsZoneDefinition types.privateDnsZoneDefinitionType?

@description('Application Insights Private DNS Zone configuration.')
param appInsightsPrivateDnsZoneDefinition types.privateDnsZoneDefinitionType?

// -----------------------
// PRIVATE DNS ZONES
// -----------------------

// API Management Private DNS Zone
module privateDnsZoneApim '../wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.apim) {
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

// Cognitive Services Private DNS Zone
module privateDnsZoneCogSvcs '../wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.cognitiveservices) {
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

// OpenAI Private DNS Zone
module privateDnsZoneOpenAi '../wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.openai) {
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

// AI Services Private DNS Zone
module privateDnsZoneAiService '../wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.aiServices) {
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

// Azure AI Search Private DNS Zone
module privateDnsZoneSearch '../wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.search) {
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

// Cosmos DB (SQL API) Private DNS Zone
module privateDnsZoneCosmos '../wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.cosmosSql) {
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

// Blob Storage Private DNS Zone
module privateDnsZoneBlob '../wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.blob) {
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

// Key Vault Private DNS Zone
module privateDnsZoneKeyVault '../wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.keyVault) {
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

// App Configuration Private DNS Zone
module privateDnsZoneAppConfig '../wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.appConfig) {
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

// Container Apps Private DNS Zone
module privateDnsZoneContainerApps '../wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.containerApps) {
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

// Container Registry Private DNS Zone
module privateDnsZoneAcr '../wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.acr) {
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

// Application Insights Private DNS Zone
module privateDnsZoneInsights '../wrappers/avm.res.network.private-dns-zone.bicep' = if (varDeployPdnsAndPe && !varUseExistingPdz.appInsights) {
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
// OUTPUTS
// -----------------------

@description('API Management DNS Zone Resource ID')
output apimDnsZoneId string = (varDeployPdnsAndPe && !varUseExistingPdz.apim) ? privateDnsZoneApim!.outputs.resourceId : privateDnsZonesDefinition.apimZoneId!

@description('Cognitive Services DNS Zone Resource ID')
output cognitiveServicesDnsZoneId string = (varDeployPdnsAndPe && !varUseExistingPdz.cognitiveservices) ? privateDnsZoneCogSvcs!.outputs.resourceId : privateDnsZonesDefinition.cognitiveservicesZoneId!

@description('OpenAI DNS Zone Resource ID')
output openAiDnsZoneId string = (varDeployPdnsAndPe && !varUseExistingPdz.openai) ? privateDnsZoneOpenAi!.outputs.resourceId : privateDnsZonesDefinition.openaiZoneId!

@description('AI Services DNS Zone Resource ID')
output aiServicesDnsZoneId string = (varDeployPdnsAndPe && !varUseExistingPdz.aiServices) ? privateDnsZoneAiService!.outputs.resourceId : privateDnsZonesDefinition.aiServicesZoneId!

@description('Azure AI Search DNS Zone Resource ID')
output searchDnsZoneId string = (varDeployPdnsAndPe && !varUseExistingPdz.search) ? privateDnsZoneSearch!.outputs.resourceId : privateDnsZonesDefinition.searchZoneId!

@description('Cosmos DB DNS Zone Resource ID')
output cosmosSqlDnsZoneId string = (varDeployPdnsAndPe && !varUseExistingPdz.cosmosSql) ? privateDnsZoneCosmos!.outputs.resourceId : privateDnsZonesDefinition.cosmosSqlZoneId!

@description('Blob Storage DNS Zone Resource ID')
output blobDnsZoneId string = (varDeployPdnsAndPe && !varUseExistingPdz.blob) ? privateDnsZoneBlob!.outputs.resourceId : privateDnsZonesDefinition.blobZoneId!

@description('Key Vault DNS Zone Resource ID')
output keyVaultDnsZoneId string = (varDeployPdnsAndPe && !varUseExistingPdz.keyVault) ? privateDnsZoneKeyVault!.outputs.resourceId : privateDnsZonesDefinition.keyVaultZoneId!

@description('App Configuration DNS Zone Resource ID')
output appConfigDnsZoneId string = (varDeployPdnsAndPe && !varUseExistingPdz.appConfig) ? privateDnsZoneAppConfig!.outputs.resourceId : privateDnsZonesDefinition.appConfigZoneId!

@description('Container Apps DNS Zone Resource ID')
output containerAppsDnsZoneId string = (varDeployPdnsAndPe && !varUseExistingPdz.containerApps) ? privateDnsZoneContainerApps!.outputs.resourceId : privateDnsZonesDefinition.containerAppsZoneId!

@description('Container Registry DNS Zone Resource ID')
output acrDnsZoneId string = (varDeployPdnsAndPe && !varUseExistingPdz.acr) ? privateDnsZoneAcr!.outputs.resourceId : privateDnsZonesDefinition.acrZoneId!

@description('Application Insights DNS Zone Resource ID')
output appInsightsDnsZoneId string = (varDeployPdnsAndPe && !varUseExistingPdz.appInsights) ? privateDnsZoneInsights!.outputs.resourceId : privateDnsZonesDefinition.appInsightsZoneId!
