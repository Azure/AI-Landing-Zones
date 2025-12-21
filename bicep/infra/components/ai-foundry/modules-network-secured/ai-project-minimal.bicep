param accountName string
param location string
param projectName string
param projectDescription string
param displayName string

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
}

output projectName string = project.name
output projectId string = project.id
output projectPrincipalId string = project.identity.principalId

#disable-next-line BCP053
output projectWorkspaceId string = project.properties.internalId

// No associated resources: return empty connection names.
output cosmosDBConnection string = ''
output azureStorageConnection string = ''
output aiSearchConnection string = ''
