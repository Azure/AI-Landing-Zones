// Simple VNet peering component
targetScope = 'resourceGroup'

@description('Required. Local VNet name to create peering from.')
param localVnetName string

@description('Required. Name for the peering resource.')
param remotePeeringName string

@description('Required. Resource ID of the remote VNet to peer with.')
param remoteVirtualNetworkResourceId string

@description('Optional. Allow virtual network access.')
param allowVirtualNetworkAccess bool = true

@description('Optional. Allow forwarded traffic.')
param allowForwardedTraffic bool = true

@description('Optional. Allow gateway transit.')
param allowGatewayTransit bool = false

@description('Optional. Use remote gateways.')
param useRemoteGateways bool = false

// Create the peering from local to remote VNet
resource vnetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-03-01' = {
  name: '${localVnetName}/${remotePeeringName}'
  properties: {
    allowVirtualNetworkAccess: allowVirtualNetworkAccess
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: useRemoteGateways
    remoteVirtualNetwork: {
      id: remoteVirtualNetworkResourceId
    }
  }
}

@description('The resource ID of the created peering.')
output peeringResourceId string = vnetPeering.id

@description('The name of the created peering.')
output peeringName string = vnetPeering.name
