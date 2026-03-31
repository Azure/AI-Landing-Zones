targetScope = 'resourceGroup'

import { containerAppEnvDefinitionType } from '../common/types.bicep'

@description('Container App Environment definition parameter')
param containerAppEnv containerAppEnvDefinitionType

module managedEnvironment 'br/public:avm/res/app/managed-environment:0.11.3' = {
  name: 'cae-avm-${containerAppEnv.name!}'
  params: {
    name: containerAppEnv.name!
    location: containerAppEnv.?location
    enableTelemetry: containerAppEnv.?enableTelemetry
    tags: containerAppEnv.?tags
    
    // Optional infrastructure settings
    dockerBridgeCidr: containerAppEnv.?dockerBridgeCidr
    infrastructureResourceGroupName: containerAppEnv.?infrastructureResourceGroupName
    infrastructureSubnetResourceId: containerAppEnv.?infrastructureSubnetResourceId
    internal: containerAppEnv.?internal
    platformReservedCidr: containerAppEnv.?platformReservedCidr
    platformReservedDnsIP: containerAppEnv.?platformReservedDnsIP
    
    // Workload profiles
    workloadProfiles: containerAppEnv.?workloadProfiles
    
    // Observability settings
    appInsightsConnectionString: containerAppEnv.?appInsightsConnectionString
    appLogsConfiguration: containerAppEnv.?appLogsConfiguration
    
    // Certificate settings
    certificate: containerAppEnv.?certificate
    certificatePassword: containerAppEnv.?certificatePassword
    certificateValue: containerAppEnv.?certificateValue
    
    // Dapr settings
    daprAIConnectionString: containerAppEnv.?daprAIConnectionString
    daprAIInstrumentationKey: containerAppEnv.?daprAIInstrumentationKey
    
    // Other optional settings
    dnsSuffix: containerAppEnv.?dnsSuffix
    lock: containerAppEnv.?lock
    managedIdentities: containerAppEnv.?managedIdentities
    openTelemetryConfiguration: containerAppEnv.?openTelemetryConfiguration
    peerTrafficEncryption: containerAppEnv.?peerTrafficEncryption
    publicNetworkAccess: containerAppEnv.?publicNetworkAccess
    roleAssignments: containerAppEnv.?roleAssignments
    storages: containerAppEnv.?storages
    zoneRedundant: containerAppEnv.?zoneRedundant
  }
}

@description('The resource ID of the container apps managed environment.')
output resourceId string = managedEnvironment.outputs.resourceId

@description('The name of the container apps managed environment.')
output name string = managedEnvironment.outputs.name

@description('The location the resource was deployed into.')
output location string = managedEnvironment.outputs.location

@description('The resource group the container apps managed environment was deployed into.')
output resourceGroupName string = managedEnvironment.outputs.resourceGroupName

@description('The default domain of the container apps managed environment.')
output defaultDomain string = managedEnvironment.outputs.defaultDomain

@description('The static IP of the container apps managed environment.')
output staticIp string = managedEnvironment.outputs.staticIp
