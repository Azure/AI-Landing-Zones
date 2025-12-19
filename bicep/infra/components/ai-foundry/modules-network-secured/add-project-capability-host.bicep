param cosmosDBConnection string 
param azureStorageConnection string 
param aiSearchConnection string
param projectName string
param accountName string
param projectCapHost string

var threadConnections = ['${cosmosDBConnection}']
var storageConnections = ['${azureStorageConnection}']
var vectorStoreConnections = ['${aiSearchConnection}']


resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
   name: accountName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' existing = {
  name: projectName
  parent: account
}

// The Agent Service creates an account-level capability host automatically.
// Attempting to create a second account-level capability host causes Conflict.
// Example existing name: '${accountName}@aml_aiagentservice'.
var accountCapHostName = '${accountName}@aml_aiagentservice'

resource accountCapabilityHost 'Microsoft.CognitiveServices/accounts/capabilityHosts@2025-06-01' existing = {
  name: accountCapHostName
  parent: account
}

resource projectCapabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-06-01' = {
  name: projectCapHost
  parent: project
  properties: {
    capabilityHostKind: 'Agents'
    vectorStoreConnections: vectorStoreConnections
    storageConnections: storageConnections
    threadStorageConnections: threadConnections
  }
  dependsOn: [
    accountCapabilityHost
  ]

}

output projectCapHost string = projectCapabilityHost.name
