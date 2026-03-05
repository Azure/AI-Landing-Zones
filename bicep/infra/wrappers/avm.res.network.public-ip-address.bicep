// AVM Public IP wrapper (pass-through)
targetScope = 'resourceGroup'

import { publicIpDefinitionType } from '../common/types.bicep'

@description('Public IP Address definition.')
param pip publicIpDefinitionType

module inner 'br/public:avm/res/network/public-ip-address:0.9.0' = {
  name: 'pip-avm-${pip.name}'
  params: {
    name: pip.name
    location: pip.?location
    publicIPAllocationMethod: pip.?publicIPAllocationMethod
    publicIPAddressVersion: pip.?publicIPAddressVersion
    skuName: pip.?skuName
    skuTier: pip.?skuTier
    dnsSettings: pip.?dnsSettings
    availabilityZones: pip.?zones
    tags: pip.?tags
    lock: pip.?lock
    enableTelemetry: pip.?enableTelemetry
    diagnosticSettings: pip.?diagnosticSettings
    roleAssignments: pip.?roleAssignments
  }
}

@description('Public IP resource ID.')
output resourceId string = inner.outputs.resourceId
