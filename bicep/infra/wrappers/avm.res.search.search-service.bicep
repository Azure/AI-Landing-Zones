// AVM AI Search wrapper (pass-through)
targetScope = 'resourceGroup'

import { kSAISearchDefinitionType } from '../common/types.bicep'

@description('AI Search definition.')
param aiSearch kSAISearchDefinitionType

module inner 'br/public:avm/res/search/search-service:0.11.1' = {
  name: 'search-avm-${aiSearch.name}'
  params: {
    name: aiSearch.name
    location: aiSearch.?location
    authOptions: aiSearch.?authOptions
    diagnosticSettings: aiSearch.?diagnosticSettings
    cmkEnforcement: aiSearch.?cmkEnforcement
    hostingMode: aiSearch.?hostingMode
    lock: aiSearch.?lock
    managedIdentities: aiSearch.?managedIdentities
    networkRuleSet: aiSearch.?networkRuleSet
    partitionCount: aiSearch.?partitionCount
    privateEndpoints: aiSearch.?privateEndpoints
    publicNetworkAccess: aiSearch.?publicNetworkAccess
    replicaCount: aiSearch.?replicaCount
    roleAssignments: aiSearch.?roleAssignments
    secretsExportConfiguration: aiSearch.?secretsExportConfiguration
    semanticSearch: aiSearch.?semanticSearch
    sku: aiSearch.?sku
    tags: aiSearch.?tags
    enableTelemetry: aiSearch.?enableTelemetry
  }
}

output resourceId string = inner.outputs.resourceId
output name string = inner.outputs.name
output location string = inner.outputs.location
output resourceGroupName string = inner.outputs.resourceGroupName
output systemAssignedMIPrincipalId string = inner.outputs.?systemAssignedMIPrincipalId ?? ''
