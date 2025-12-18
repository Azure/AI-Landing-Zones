import { aiFoundryDefinitionType } from '../common/types.bicep'

@description('Required. AI Foundry deployment configuration object. This object contains all the settings for the AI Foundry account, project, and associated resources.')
param aiFoundry aiFoundryDefinitionType

@description('Optional. Enable telemetry collection for the module.')
param enableTelemetry bool = true

// Create the AI Foundry deployment using the AVM pattern module
module inner 'br/public:avm/ptn/ai-ml/ai-foundry:0.6.0' = {
  name: 'aif-avm-${aiFoundry.baseName!}'
  params: {
    // Required
    baseName: aiFoundry.baseName!

    // Optional (guarded)
    baseUniqueName: aiFoundry.?baseUniqueName
    enableTelemetry: enableTelemetry
    includeAssociatedResources: aiFoundry.?includeAssociatedResources
    location: aiFoundry.?location
    lock: aiFoundry.?lock
    tags: aiFoundry.?tags
    privateEndpointSubnetResourceId: aiFoundry.?privateEndpointSubnetResourceId
    aiFoundryConfiguration: aiFoundry.?aiFoundryConfiguration
    aiModelDeployments: aiFoundry.?aiModelDeployments
    aiSearchConfiguration: aiFoundry.?aiSearchConfiguration
    cosmosDbConfiguration: aiFoundry.?cosmosDbConfiguration
    keyVaultConfiguration: aiFoundry.?keyVaultConfiguration
    storageAccountConfiguration: aiFoundry.?storageAccountConfiguration
  }
}

// Outputs
@description('AI Foundry resource group name.')
output resourceGroupName string = inner.outputs.resourceGroupName

@description('AI Foundry project name.')
output aiProjectName string = inner.outputs.aiProjectName

@description('AI Foundry AI Search service name.')
output aiSearchName string = inner.outputs.aiSearchName

@description('AI Foundry AI Services name.')
output aiServicesName string = inner.outputs.aiServicesName

@description('AI Foundry Cosmos DB account name.')
output cosmosAccountName string = inner.outputs.cosmosAccountName

@description('AI Foundry Key Vault name.')
output keyVaultName string = inner.outputs.keyVaultName

@description('AI Foundry Storage Account name.')
output storageAccountName string = inner.outputs.storageAccountName
