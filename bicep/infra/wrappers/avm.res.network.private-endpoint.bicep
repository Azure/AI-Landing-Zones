// AVM Private Endpoint wrapper (pass-through)
targetScope = 'resourceGroup'

import { privateEndpointDefinitionType } from '../common/types.bicep'

@description('Private Endpoint definition.')
param privateEndpoint privateEndpointDefinitionType

module inner 'br/public:avm/res/network/private-endpoint:0.11.0' = {
  name: 'pe-avm-${privateEndpoint.name}'
  params: {
    name: privateEndpoint.name
    location: privateEndpoint.?location
    subnetResourceId: privateEndpoint.subnetResourceId
    privateLinkServiceConnections: privateEndpoint.?privateLinkServiceConnections
    manualPrivateLinkServiceConnections: privateEndpoint.?manualPrivateLinkServiceConnections
    customNetworkInterfaceName: privateEndpoint.?customNetworkInterfaceName
    privateDnsZoneGroup: privateEndpoint.?privateDnsZoneGroup
    tags: privateEndpoint.?tags
    lock: privateEndpoint.?lock
    enableTelemetry: privateEndpoint.?enableTelemetry
    roleAssignments: privateEndpoint.?roleAssignments
  }
}

@description('Private Endpoint resource ID.')
output resourceId string = inner.outputs.resourceId

@description('Private Endpoint resource name.')
output name string = inner.outputs.name

@description('Private Endpoint network interface resource IDs.')
output networkInterfaceResourceIds string[] = inner.outputs.networkInterfaceResourceIds
