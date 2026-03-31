// AVM Virtual Machine Jump VM wrapper (pass-through)
targetScope = 'resourceGroup'

import { vmDefinitionType } from '../common/types.bicep'

@description('Jump VM configuration.')
param jumpVm vmDefinitionType

module inner 'br/public:avm/res/compute/virtual-machine:0.20.0' = {
  name: 'jumpvm-avm-${jumpVm.name!}'
  params: {
    // Required parameters
    name: jumpVm.name!
    adminUsername: jumpVm.adminUsername!
    vmSize: jumpVm.sku!
    imageReference: jumpVm.imageReference!
    osType: jumpVm.osType!
    encryptionAtHost: jumpVm.?encryptionAtHost
    
    // Optional
    nicConfigurations: jumpVm.nicConfigurations!
    osDisk: jumpVm.osDisk!
    location: jumpVm.?location 
    tags: jumpVm.?tags
    enableTelemetry: jumpVm.?enableTelemetry
    adminPassword: jumpVm.?adminPassword
    availabilityZone: jumpVm.?availabilityZone ?? -1
    lock: jumpVm.?lock
    managedIdentities: jumpVm.?managedIdentities
    roleAssignments: jumpVm.?roleAssignments
    maintenanceConfigurationResourceId: jumpVm.?maintenanceConfigurationResourceId
    patchMode: jumpVm.?patchMode
    enableAutomaticUpdates: jumpVm.?enableAutomaticUpdates
    publicKeys: jumpVm.?publicKeys
  }
}

output resourceId string = inner.outputs.resourceId
output name string = inner.outputs.name
output location string = inner.outputs.location
output resourceGroupName string = inner.outputs.resourceGroupName
output systemAssignedMIPrincipalId string = inner.outputs.?systemAssignedMIPrincipalId ?? ''
