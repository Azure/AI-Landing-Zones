// AVM Private DNS Zone wrapper (pass-through)
targetScope = 'resourceGroup'

import { privateDnsZoneDefinitionType } from '../common/types.bicep'

@description('Private DNS Zone definition.')
param privateDnsZone privateDnsZoneDefinitionType

module inner 'br/public:avm/res/network/private-dns-zone:0.8.0' = {
  name: 'pdns-${uniqueString(privateDnsZone.name!)}'
  params: {
    name: privateDnsZone.name
    location: privateDnsZone.?location ?? 'global'
    tags: privateDnsZone.?tags
    enableTelemetry: privateDnsZone.?enableTelemetry
    virtualNetworkLinks: privateDnsZone.?virtualNetworkLinks
    a: privateDnsZone.?a
    lock: privateDnsZone.?lock
    roleAssignments: privateDnsZone.?roleAssignments
  }
}

@description('Private DNS Zone resource ID.')
output resourceId string = inner.outputs.resourceId

@description('Private DNS Zone name.')
output name string = inner.outputs.name
