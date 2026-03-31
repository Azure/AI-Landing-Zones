metadata name = 'content-safety'
metadata description = 'Deploy an Azure AI Content Safety account and register it as a connection on the AI Foundry account.'

@description('Required. Name of the AI Services account (used as the parent for the connection resource).')
param accountName string

@description('Required. Name to use for the Content Safety account when creating a new one, and as the base name for the AI Foundry connection when reusing an existing account (does not need to match the existing resource name).')
param contentSafetyName string

@description('Required. Azure region for the Content Safety resource.')
param location string

@description('Optional. Tags to apply to the Content Safety resource.')
param tags object = {}

@description('Optional. SKU. F0 is free tier (limited); S0 for production.')
param sku string = 'S0'

@description('Optional. Existing Content Safety resource ID to reuse instead of creating a new one.')
param existingResourceId string = ''

@description('Optional. Whether public network access is enabled. Set to Disabled for secure-by-default deployments. Default: Disabled.')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Disabled'

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
    publicNetworkAccess: publicNetworkAccess
  }
}

var varCsId       = varIsReuse ? existingResourceId                   : contentSafetyAccount.id
var varCsEndpoint = varIsReuse ? existingCs!.properties.endpoint      : contentSafetyAccount!.properties.endpoint
var varCsLocation = varIsReuse ? existingCs!.location                 : location

// Register as a connection on the AI Foundry account so it is discoverable in AI Foundry portal.
// Uses AAD auth (managed identity) to avoid dependency on listKeys / local auth.
#disable-next-line BCP081
resource csConnection 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = {
  name: '${contentSafetyName}-connection'
  parent: aiServicesAccount
  properties: {
    category: 'AzureAIContentSafety'
    target: varCsEndpoint
    authType: 'AAD'
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
output resourceGroupName string = varIsReuse ? varExRg : resourceGroup().name

@description('Name of the connection registered on the AI Foundry account.')
output connectionName string = csConnection.name
