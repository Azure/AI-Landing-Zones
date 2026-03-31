// AVM Virtual Network wrapper (pass-through)
targetScope = 'resourceGroup'

import { vNetDefinitionType } from '../common/types.bicep'

@description('Virtual Network definition.')
param vnet vNetDefinitionType

module inner 'br/public:avm/res/network/virtual-network:0.7.0' = {
  name: 'vnet-${uniqueString(vnet.name!)}'
  params: {
    name: vnet.name
    addressPrefixes: vnet.addressPrefixes
    subnets: vnet.?subnets
    location: vnet.?location
    ddosProtectionPlanResourceId: vnet.?ddosProtectionPlanResourceId
    diagnosticSettings: vnet.?diagnosticSettings
    dnsServers: vnet.?dnsServers
    enableTelemetry: vnet.?enableTelemetry
    enableVmProtection: vnet.?enableVmProtection
    flowTimeoutInMinutes: vnet.?flowTimeoutInMinutes
    ipamPoolNumberOfIpAddresses: vnet.?ipamPoolNumberOfIpAddresses
    lock: vnet.?lock
    peerings: vnet.?peerings
    roleAssignments: vnet.?roleAssignments
    tags: vnet.?tags
    virtualNetworkBgpCommunity: vnet.?virtualNetworkBgpCommunity
    vnetEncryption: vnet.?vnetEncryption
    vnetEncryptionEnforcement: vnet.?vnetEncryptionEnforcement
  }
}

@description('Virtual Network resource ID.')
output resourceId string = inner.outputs.resourceId
