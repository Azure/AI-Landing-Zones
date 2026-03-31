param accountName string
param location string
param projectName string
param projectDescription string
param displayName string

param aiSearchName string
param aiSearchServiceResourceGroupName string
param aiSearchServiceSubscriptionId string

param cosmosDBName string
param cosmosDBSubscriptionId string
param cosmosDBResourceGroupName string

param azureStorageName string
param azureStorageSubscriptionId string
param azureStorageResourceGroupName string

resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' existing = {
  name: aiSearchName
  scope: resourceGroup(aiSearchServiceSubscriptionId, aiSearchServiceResourceGroupName)
}
resource cosmosDBAccount 'Microsoft.DocumentDB/databaseAccounts@2024-12-01-preview' existing = {
  name: cosmosDBName
  scope: resourceGroup(cosmosDBSubscriptionId, cosmosDBResourceGroupName)
}
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: azureStorageName
  scope: resourceGroup(azureStorageSubscriptionId, azureStorageResourceGroupName)
}

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
  scope: resourceGroup()
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: account
  name: projectName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: projectDescription
    displayName: displayName
  }

  resource project_connection_cosmosdb_account 'connections@2025-04-01-preview' = {
    name: cosmosDBName
    properties: {
      category: 'CosmosDB'
      // Avoid referencing runtime properties of a resource that may still be finalizing provisioning.
      // Cosmos DB SQL API document endpoint follows the well-known pattern below.
      target: 'https://${cosmosDBName}.documents.azure.com:443/'
      authType: 'AAD'
      metadata: {
        ApiType: 'Azure'
        ResourceId: cosmosDBAccount.id
        location: location
      }
    }
  }

  resource project_connection_azure_storage 'connections@2025-04-01-preview' = {
    name: azureStorageName
    properties: {
      category: 'AzureStorageAccount'
      // Avoid referencing runtime properties of a resource that may still be finalizing provisioning.
      // Blob primary endpoint follows the well-known pattern below.
      target: 'https://${azureStorageName}.blob.${environment().suffixes.storage}/'
      authType: 'AAD'
      metadata: {
        ApiType: 'Azure'
        ResourceId: storageAccount.id
        location: location
      }
    }
  }

  resource project_connection_azureai_search 'connections@2025-04-01-preview' = {
    name: aiSearchName
    properties: {
      category: 'CognitiveSearch'
      target: 'https://${aiSearchName}.search.windows.net'
      authType: 'AAD'
      metadata: {
        ApiType: 'Azure'
        ResourceId: searchService.id
        location: location
      }
    }
  }

}

output projectName string = project.name
output projectId string = project.id
output projectPrincipalId string = project.identity.principalId

#disable-next-line BCP053
output projectWorkspaceId string = project.properties.internalId

// return the BYO connection names
output cosmosDBConnection string = cosmosDBName
output azureStorageConnection string = azureStorageName
output aiSearchConnection string = aiSearchName
