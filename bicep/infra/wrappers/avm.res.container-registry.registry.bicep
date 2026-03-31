// AVM Container Registry wrapper (pass-through)
targetScope = 'resourceGroup'

import { containerRegistryDefinitionType } from '../common/types.bicep'

@description('Container Registry definition.')
param acr containerRegistryDefinitionType

module inner 'br/public:avm/res/container-registry/registry:0.9.3' = {
  name: 'acr-avm-${acr.name}'
  params: {
    name: acr.name
    location: acr.?location
    roleAssignments: acr.?roleAssignments
    cacheRules: acr.?cacheRules
    credentialSets: acr.?credentialSets
    customerManagedKey: acr.?customerManagedKey
    diagnosticSettings: acr.?diagnosticSettings
    lock: acr.?lock
    managedIdentities: acr.?managedIdentities
    networkRuleSetIpRules: acr.?networkRuleSetIpRules
    privateEndpoints: acr.?privateEndpoints
    publicNetworkAccess: acr.?publicNetworkAccess
    replications: acr.?replications
    scopeMaps: acr.?scopeMaps
    tags: acr.?tags
    webhooks: acr.?webhooks
    enableTelemetry: acr.?enableTelemetry
  }
}

@description('The resource ID of the container registry.')
output resourceId string = inner.outputs.resourceId

@description('The name of the container registry.')
output name string = inner.outputs.name

@description('The resource group the container registry was deployed into.')
output resourceGroupName string = inner.outputs.resourceGroupName

@description('The location the resource was deployed into.')
output location string = inner.outputs.location

@description('The principal ID of the system assigned identity.')
output systemAssignedMIPrincipalId string = inner.outputs.?systemAssignedMIPrincipalId ?? ''

@description('The login server for the container registry.')
output loginServer string = inner.outputs.loginServer
