// Creates Azure dependent resources for Azure AI Agent Service standard agent setup

@description('Azure region of the deployment')
param location string

// @description('The name of the Key Vault')
// param keyvaultName string

@description('The name of the AI Search resource')
param aiSearchName string

@description('Name of the storage account')
param azureStorageName string

@description('Name of the new Cosmos DB account')
param cosmosDBName string

@description('Optional. AI Search public network access. Default: disabled.')
@allowed([
  'enabled'
  'disabled'
])
param aiSearchPublicNetworkAccess string = 'disabled'

@description('Optional. AI Search network rules (used when aiSearchPublicNetworkAccess=enabled). Example: { bypass: "None", ipRules: [ { value: "1.2.3.4" } ] }.')
param aiSearchNetworkRuleSet object = {}

@description('Optional. Cosmos DB public network access. Default: Disabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param cosmosDbPublicNetworkAccess string = 'Disabled'

@description('Optional. Cosmos DB IP allowlist (used when cosmosDbPublicNetworkAccess=Enabled). Example: ["1.2.3.4","5.6.7.0/24"]. Note: RFC1918 ranges (10/8, 172.16/12, 192.168/16, 100.64/10) are not enforceable by Cosmos IP firewall rules; use Private Endpoints and/or VNet rules instead.')
param cosmosDbIpRules string[] = []

@description('Optional. Storage Account public network access. Default: Disabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param storageAccountPublicNetworkAccess string = 'Disabled'

@description('Optional. Storage Account network ACLs (used when storageAccountPublicNetworkAccess=Enabled). Example: { bypass: "AzureServices", defaultAction: "Deny", ipRules: [ { value: "1.2.3.4" } ] }.')
param storageAccountNetworkAcls object = {}

@description('The AI Search Service full ARM Resource ID. This is an optional field, and if not provided, the resource will be created.')
param aiSearchResourceId string

@description('The AI Storage Account full ARM Resource ID. This is an optional field, and if not provided, the resource will be created.')
param azureStorageAccountResourceId string

@description('The Cosmos DB Account full ARM Resource ID. This is an optional field, and if not provided, the resource will be created.')
param cosmosDBResourceId string

// param aiServiceExists bool
param aiSearchExists bool
param azureStorageExists bool
param cosmosDBExists bool

var cosmosParts = split(cosmosDBResourceId, '/')

resource existingCosmosDB 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = if (cosmosDBExists) {
  name: cosmosParts[8]
  scope: resourceGroup(cosmosParts[2], cosmosParts[4])
}

// CosmosDB creation

var canaryRegions = ['eastus2euap', 'centraluseuap']
var cosmosDbRegion = contains(canaryRegions, location) ? 'westus' : location
var cosmosDbIpRulesMapped = [
  for ip in cosmosDbIpRules: {
    ipAddressOrRange: ip
  }
]
resource cosmosDB 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = if(!cosmosDBExists) {
  name: cosmosDBName
  location: cosmosDbRegion
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    disableLocalAuth: true
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    publicNetworkAccess: cosmosDbPublicNetworkAccess
    // Cosmos DB RP is strict about payload shapes; avoid sending null.
    ipRules: cosmosDbPublicNetworkAccess == 'Enabled' ? cosmosDbIpRulesMapped : []
    enableFreeTier: false
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
  }
}

var acsParts = split(aiSearchResourceId, '/')

resource existingSearchService 'Microsoft.Search/searchServices@2024-06-01-preview' existing = if (aiSearchExists) {
  name: acsParts[8]
  scope: resourceGroup(acsParts[2], acsParts[4])
}

// AI Search creation

resource aiSearch 'Microsoft.Search/searchServices@2024-06-01-preview' = if(!aiSearchExists) {
  name: aiSearchName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    disableLocalAuth: false
    authOptions: { aadOrApiKey: { aadAuthFailureMode: 'http401WithBearerChallenge'}}
    encryptionWithCmk: {
      enforcement: 'Unspecified'
    }
    hostingMode: 'default'
    partitionCount: 1
    publicNetworkAccess: aiSearchPublicNetworkAccess
    replicaCount: 1
    semanticSearch: 'disabled'
    networkRuleSet: union({ bypass: 'None', ipRules: [] }, aiSearchNetworkRuleSet)
  }
  sku: {
    name: 'standard'
  }
}

var azureStorageParts = split(azureStorageAccountResourceId, '/')

resource existingAzureStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = if (azureStorageExists) {
  name: azureStorageParts[8]
  scope: resourceGroup(azureStorageParts[2], azureStorageParts[4])
}

// Some regions doesn't support Standard Zone-Redundant storage, need to use Geo-redundant storage
var noZRSRegions = ['southindia', 'westus']
var sku = contains(noZRSRegions, location) ? { name: 'Standard_GRS' } : { name: 'Standard_ZRS' }

// Storage creation

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = if(!azureStorageExists) {
  name: azureStorageName
  location: location
  kind: 'StorageV2'
  sku: sku
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    publicNetworkAccess: storageAccountPublicNetworkAccess
    networkAcls: union({ bypass: 'AzureServices', defaultAction: 'Deny', virtualNetworkRules: [] }, storageAccountNetworkAcls)
    allowSharedKeyAccess: false
  }
}

output aiSearchName string = aiSearchExists ? existingSearchService.name : aiSearch.name
output aiSearchID string = aiSearchExists ? existingSearchService.id : aiSearch.id
output aiSearchServiceResourceGroupName string = aiSearchExists ? acsParts[4] : resourceGroup().name
output aiSearchServiceSubscriptionId string = aiSearchExists ? acsParts[2] : subscription().subscriptionId

output azureStorageName string = azureStorageExists ? existingAzureStorageAccount.name :  storage.name
output azureStorageId string =  azureStorageExists ? existingAzureStorageAccount.id :  storage.id
output azureStorageResourceGroupName string = azureStorageExists ? azureStorageParts[4] : resourceGroup().name
output azureStorageSubscriptionId string = azureStorageExists ? azureStorageParts[2] : subscription().subscriptionId

output cosmosDBName string = cosmosDBExists ? existingCosmosDB.name : cosmosDB.name
output cosmosDBId string = cosmosDBExists ? existingCosmosDB.id : cosmosDB.id
output cosmosDBResourceGroupName string = cosmosDBExists ? cosmosParts[4] : resourceGroup().name
output cosmosDBSubscriptionId string = cosmosDBExists ? cosmosParts[2] : subscription().subscriptionId
// output keyvaultId string = keyVault.id
