targetScope = 'resourceGroup'

import { appConfigurationDefinitionType } from '../common/types.bicep'

@description('App Configuration definition parameter')
param appConfiguration appConfigurationDefinitionType

module configurationStore 'br/public:avm/res/app-configuration/configuration-store:0.9.2' = {
  name: 'appcs-avm-${appConfiguration.name!}'
  params: {
    name: appConfiguration.name!
    location: appConfiguration.?location
    enableTelemetry: appConfiguration.?enableTelemetry
    tags: appConfiguration.?tags
    
    // Optional configuration settings
    createMode: appConfiguration.?createMode
    customerManagedKey: appConfiguration.?customerManagedKey
    dataPlaneProxy: appConfiguration.?dataPlaneProxy
    diagnosticSettings: appConfiguration.?diagnosticSettings
    disableLocalAuth: appConfiguration.?disableLocalAuth
    enablePurgeProtection: appConfiguration.?enablePurgeProtection
    keyValues: appConfiguration.?keyValues
    lock: appConfiguration.?lock
    managedIdentities: appConfiguration.?managedIdentities
    privateEndpoints: appConfiguration.?privateEndpoints
    publicNetworkAccess: appConfiguration.?publicNetworkAccess
    replicaLocations: appConfiguration.?replicaLocations
    roleAssignments: appConfiguration.?roleAssignments
    sku: appConfiguration.?sku
    softDeleteRetentionInDays: appConfiguration.?softDeleteRetentionInDays
  }
}

@description('The resource ID of the configuration store.')
output resourceId string = configurationStore.outputs.resourceId

@description('The name of the configuration store.')
output name string = configurationStore.outputs.name

@description('The location the resource was deployed into.')
output location string = configurationStore.outputs.location

@description('The resource group the configuration store was deployed into.')
output resourceGroupName string = configurationStore.outputs.resourceGroupName

@description('The endpoint of the configuration store.')
output endpoint string = configurationStore.outputs.endpoint

@description('The system-assigned managed identity principal ID.')
output systemAssignedMIPrincipalId string = configurationStore.outputs.?systemAssignedMIPrincipalId! ?? ''
