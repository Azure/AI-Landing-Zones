param cosmosDBConnection string 
param azureStorageConnection string 
param aiSearchConnection string
param projectName string
param accountName string
param projectCapHost string

@description('Optional. How long to wait (in seconds) before creating the project capability host, to give the service time to finish provisioning the account-level capability host.')
param capabilityHostWaitSeconds int = 600

@description('Optional. When false, skips the best-effort deployment script delay used before creating the project capability host.')
param enableCapabilityHostDelayScript bool = true

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
// Example existing name: '${accountName}@aml_aiagentservice'.
// If it is still provisioning, creating the project capability host can fail transiently.
var accountCapHostName = '${accountName}@aml_aiagentservice'

resource accountCapabilityHost 'Microsoft.CognitiveServices/accounts/capabilityHosts@2025-06-01' existing = {
  name: accountCapHostName
  parent: account
}

// Best-effort mitigation for a transient service race condition:
// In some environments, deploymentScripts do not allow SystemAssigned identity, and the user may not want UserAssigned.
// This script intentionally does not use identity and only performs Start-Sleep.
resource waitForAccountCapabilityHost 'Microsoft.Resources/deploymentScripts@2023-08-01' = if (enableCapabilityHostDelayScript && capabilityHostWaitSeconds > 0) {
  name: '${projectName}-wait-capabilityhost'
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '11.0'
    scriptContent: 'Start-Sleep -Seconds ${capabilityHostWaitSeconds}'
    forceUpdateTag: projectCapHost
    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
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
  dependsOn: enableCapabilityHostDelayScript && capabilityHostWaitSeconds > 0
    ? [
        accountCapabilityHost
        waitForAccountCapabilityHost
      ]
    : [
        accountCapabilityHost
      ]

}

output projectCapHost string = projectCapabilityHost.name
