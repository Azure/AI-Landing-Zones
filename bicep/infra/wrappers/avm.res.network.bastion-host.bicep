metadata name = 'AVM Bastion Host Wrapper'
metadata description = 'This module wraps the AVM Bastion Host module.'

@description('Required. The name of the Bastion Host.')
param name string

@description('Required. The location of the Bastion Host.')
param location string

@description('Optional. Tags of the resource.')
param tags object = {}

@description('Required. The resource ID of the virtual network.')
param virtualNetworkResourceId string

@description('Required. The resource ID of the public IP address.')
param publicIPAddressResourceId string

@description('Optional. Enable telemetry.')
param enableTelemetry bool = true

module bastionHost 'br/public:avm/res/network/bastion-host:0.5.0' = {
  name: 'bastionHostDeployment'
  params: {
    name: name
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    virtualNetworkResourceId: virtualNetworkResourceId
    bastionSubnetPublicIpResourceId: publicIPAddressResourceId
  }
}

output resourceId string = bastionHost.outputs.resourceId
output name string = bastionHost.outputs.name
