metadata name = 'content-safety'
metadata description = 'Deploy an Azure AI Content Safety account and register it as a connection on the AI Foundry account.'

@description('Required. Name of the AI Services account (used as the parent for the connection resource).')
param accountName string

@description('Required. Name for the Content Safety resource.')
param contentSafetyName string

@description('Required. Azure region for the Content Safety resource.')
param location string

@description('Optional. Tags to apply to the Content Safety resource.')
param tags object = {}

@description('Optional. SKU. F0 is free tier (limited); S0 for production.')
param sku string = 'S0'

@description('Optional. Existing Content Safety resource ID to reuse instead of creating a new one.')
param existingResourceId string = ''

var varIsReuse = !empty(existingResourceId)
var varIdSegs  = split(existingResourceId, '/')
var varExSub   = length(varIdSegs) >= 3 ? varIdSegs[2] : ''
var varExRg    = length(varIdSegs) >= 5 ? varIdSegs[4] : ''
var varExName  = length(varIdSegs) >= 1 ? last(varIdSegs) : ''

// Parent AI Services account (for the connection resource)
#disable-next-line BCP081
resource aiServicesAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
}

// Reuse path
#disable-next-line BCP081
resource existingCs 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = if (varIsReuse) {
  name: varExName
  scope: resourceGroup(varExSub, varExRg)
}

// Create path
#disable-next-line BCP081
resource contentSafetyAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = if (!varIsReuse) {
  name: contentSafetyName
  location: location
  tags: tags
  sku: { name: sku }
  kind: 'ContentSafety'
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: contentSafetyName
    publicNetworkAccess: 'Enabled'
  }
}

var varCsId       = varIsReuse ? existingResourceId                   : contentSafetyAccount.id
var varCsEndpoint = varIsReuse ? existingCs!.properties.endpoint      : contentSafetyAccount!.properties.endpoint
var varCsKey      = varIsReuse ? existingCs!.listKeys().key1          : contentSafetyAccount!.listKeys().key1
var varCsLocation = varIsReuse ? existingCs!.location                 : location

// Register as a connection on the AI Foundry account so it is discoverable in AI Foundry portal
#disable-next-line BCP081
resource csConnection 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = {
  name: '${contentSafetyName}-connection'
  parent: aiServicesAccount
  properties: {
    category: 'AzureAIContentSafety'
    target: varCsEndpoint
    authType: 'ApiKey'
    credentials: { key: varCsKey }
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      Location: varCsLocation
      ResourceId: varCsId
    }
  }
}

@description('Resource ID of the Content Safety account (created or reused).')
output resourceId string = varCsId

@description('Name of the resource group where the Content Safety account is deployed.')
output resourceGroupName string = resourceGroup().name

@description('Name of the connection registered on the AI Foundry account.')
output connectionName string = csConnection.name
