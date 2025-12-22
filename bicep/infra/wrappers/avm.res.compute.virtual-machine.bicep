// AVM Virtual Machine wrapper (pass-through)
targetScope = 'resourceGroup'

import { vmDefinitionType } from '../common/types.bicep'

@description('Virtual Machine configuration.')
param virtualMachine vmDefinitionType

module inner 'br/public:avm/res/compute/virtual-machine:0.20.0' = {
  name: 'vm-avm-${virtualMachine.name!}'
  params: {
    name: virtualMachine.name!
    adminUsername: virtualMachine.adminUsername!
    vmSize: virtualMachine.sku!
    imageReference: virtualMachine.imageReference!
    osType: virtualMachine.osType!
    encryptionAtHost: virtualMachine.?encryptionAtHost
    location: virtualMachine.?location ?? resourceGroup().location
    tags: virtualMachine.?tags
    enableTelemetry: virtualMachine.?enableTelemetry ?? true
    nicConfigurations: virtualMachine.?nicConfigurations ?? []
    osDisk: virtualMachine.?osDisk ?? {
      caching: 'ReadWrite'
      createOption: 'FromImage'
      deleteOption: 'Delete'
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    availabilityZone: virtualMachine.?availabilityZone ?? -1
    adminPassword: virtualMachine.?adminPassword
    lock: virtualMachine.?lock
    managedIdentities: virtualMachine.?managedIdentities
    roleAssignments: virtualMachine.?roleAssignments
    publicKeys: virtualMachine.?publicKeys
    disablePasswordAuthentication: virtualMachine.?disablePasswordAuthentication
    maintenanceConfigurationResourceId: virtualMachine.?maintenanceConfigurationResourceId
    patchMode: virtualMachine.?patchMode
    enableAutomaticUpdates: virtualMachine.?enableAutomaticUpdates
  }
}

output resourceId string = inner.outputs.resourceId
output name string = inner.outputs.name
output location string = inner.outputs.location
output resourceGroupName string = inner.outputs.resourceGroupName
