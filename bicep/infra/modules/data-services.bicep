// Data Services Module
// This module deploys Storage Account, Cosmos DB, Key Vault, and Azure AI Search

import * as types from '../common/types.bicep'

@description('The base name for resources.')
param baseName string

@description('The Azure region for resources.')
param location string

@description('Enable telemetry for AVM modules.')
param enableTelemetry bool

@description('Resource tags.')
param tags types.tagsType

@description('Deployment toggles for data services.')
param deployToggles types.deployTogglesType

@description('Resource IDs for existing data services to reuse.')
param resourceIds types.resourceIdsType

@description('Storage Account configuration.')
param storageAccountDefinition types.storageAccountDefinitionType?

@description('Cosmos DB configuration.')
param cosmosDbDefinition types.genAIAppCosmosDbDefinitionType?

@description('Key Vault configuration.')
param keyVaultDefinition types.keyVaultDefinitionType?

@description('Azure AI Search configuration.')
param aiSearchDefinition types.kSAISearchDefinitionType?

@description('App Configuration store configuration.')
param appConfigurationDefinition types.appConfigurationDefinitionType?

// -----------------------
// DEPLOYMENT FLAGS
// -----------------------
var varDeploySa = empty(resourceIds.?storageAccountResourceId!) && deployToggles.storageAccount
var varDeployAppConfig = empty(resourceIds.?appConfigResourceId!) && deployToggles.appConfig
var deployCosmosDb = cosmosDbDefinition != null
var deployKeyVault = keyVaultDefinition != null
var deployAiSearch = aiSearchDefinition != null

// -----------------------
// EXISTING RESOURCES
// -----------------------

// Existing Storage Account
resource existingStorage 'Microsoft.Storage/storageAccounts@2025-01-01' existing = if (!empty(resourceIds.?storageAccountResourceId!)) {
  name: varExistingSaName
  scope: resourceGroup(varExistingSaSub, varExistingSaRg)
}

// Existing App Configuration
#disable-next-line no-unused-existing-resources
resource existingAppConfig 'Microsoft.AppConfiguration/configurationStores@2024-06-01' existing = if (!empty(resourceIds.?appConfigResourceId!)) {
  name: varExistingAppcsName
  scope: resourceGroup(varExistingAppcsSub, varExistingAppcsRg)
}

// -----------------------
// RESOURCE NAMING
// -----------------------

// Storage Account naming
var varSaIdSegments = empty(resourceIds.?storageAccountResourceId!)
  ? ['']
  : split(resourceIds.storageAccountResourceId!, '/')
var varExistingSaSub = length(varSaIdSegments) >= 3 ? varSaIdSegments[2] : ''
var varExistingSaRg = length(varSaIdSegments) >= 5 ? varSaIdSegments[4] : ''
var varExistingSaName = length(varSaIdSegments) >= 1 ? last(varSaIdSegments) : ''
var varSaName = !empty(resourceIds.?storageAccountResourceId!)
  ? varExistingSaName
  : (empty(storageAccountDefinition.?name!) ? 'st${baseName}' : storageAccountDefinition!.name!)

// App Configuration naming
var varAppcsIdSegments = empty(resourceIds.?appConfigResourceId!) ? [''] : split(resourceIds.appConfigResourceId!, '/')
var varExistingAppcsSub = length(varAppcsIdSegments) >= 3 ? varAppcsIdSegments[2] : ''
var varExistingAppcsRg = length(varAppcsIdSegments) >= 5 ? varAppcsIdSegments[4] : ''
var varExistingAppcsName = length(varAppcsIdSegments) >= 1 ? last(varAppcsIdSegments) : ''
var varAppConfigName = !empty(resourceIds.?appConfigResourceId!)
  ? varExistingAppcsName
  : (empty(appConfigurationDefinition.?name ?? '') ? 'appcs-${baseName}' : appConfigurationDefinition!.name)

// -----------------------
// RESOURCE ID RESOLUTION
// -----------------------
var varSaResourceId = !empty(resourceIds.?storageAccountResourceId!)
  ? existingStorage.id
  : (varDeploySa ? storageAccount!.outputs.resourceId : '')

// -----------------------
// MODULE DEPLOYMENTS
// -----------------------

// Storage Account
module storageAccount '../wrappers/avm.res.storage.storage-account.bicep' = if (varDeploySa) {
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

// App Configuration Store
module configurationStore '../wrappers/avm.res.app-configuration.configuration-store.bicep' = if (varDeployAppConfig) {
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

// Cosmos DB
module cosmosDbModule '../wrappers/avm.res.document-db.database-account.bicep' = if (deployCosmosDb) {
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

// Key Vault
module keyVaultModule '../wrappers/avm.res.key-vault.vault.bicep' = if (deployKeyVault) {
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

// Azure AI Search
module aiSearchModule '../wrappers/avm.res.search.search-service.bicep' = if (deployAiSearch) {
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
// OUTPUTS
// -----------------------

@description('Storage Account Resource ID')
output storageAccountResourceId string = varSaResourceId

@description('Storage Account Name')
output storageAccountName string = varSaName

@description('App Configuration Resource ID')
output appConfigResourceId string = varDeployAppConfig ? configurationStore!.outputs.resourceId : (!empty(resourceIds.?appConfigResourceId!) ? resourceIds.appConfigResourceId! : '')

@description('App Configuration Name')
output appConfigName string = varAppConfigName

@description('Cosmos DB Resource ID')
output cosmosDbResourceId string = deployCosmosDb ? cosmosDbModule!.outputs.resourceId : ''

@description('Cosmos DB Name')
output cosmosDbName string = deployCosmosDb ? cosmosDbModule!.outputs.name : ''

@description('Key Vault Resource ID')
output keyVaultResourceId string = deployKeyVault ? keyVaultModule!.outputs.resourceId : ''

@description('Key Vault Name')
output keyVaultName string = deployKeyVault ? keyVaultModule!.outputs.name : ''

@description('Azure AI Search Resource ID')
output aiSearchResourceId string = deployAiSearch ? aiSearchModule!.outputs.resourceId : ''

@description('Azure AI Search Name')
output aiSearchName string = deployAiSearch ? aiSearchModule!.outputs.name : ''
