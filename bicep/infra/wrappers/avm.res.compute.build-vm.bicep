// AVM Virtual Machine Build VM wrapper (pass-through)
targetScope = 'resourceGroup'

import { vmDefinitionType } from '../common/types.bicep'

@description('Build VM configuration.')
param buildVm vmDefinitionType

module inner 'br/public:avm/res/compute/virtual-machine:0.20.0' = {
  name: 'buildvm-avm-${buildVm.name!}'
  params: {
    // Required parameters
    name: buildVm.name!
    adminUsername: buildVm.adminUsername!
    vmSize: buildVm.sku!
    imageReference: buildVm.imageReference!
    osType: buildVm.osType!
    encryptionAtHost: buildVm.?encryptionAtHost
    
    // Optional    
    location: buildVm.?location
    tags: buildVm.?tags
    enableTelemetry: buildVm.?enableTelemetry
    nicConfigurations: buildVm.nicConfigurations!
    osDisk: buildVm.osDisk!
    disablePasswordAuthentication: buildVm.?disablePasswordAuthentication ?? false
    availabilityZone: buildVm.?availabilityZone ?? -1
    lock: buildVm.?lock
    managedIdentities: buildVm.?managedIdentities
    roleAssignments: buildVm.?roleAssignments
    adminPassword: buildVm.?adminPassword
    publicKeys: buildVm.?publicKeys
  }
}

output resourceId string = inner.outputs.resourceId
output name string = inner.outputs.name
output location string = inner.outputs.location
output resourceGroupName string = inner.outputs.resourceGroupName
