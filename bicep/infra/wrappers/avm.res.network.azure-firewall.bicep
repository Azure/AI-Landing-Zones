import { firewallDefinitionType } from '../common/types.bicep'

@description('Required. Azure Firewall configuration object.')
param firewall firewallDefinitionType

@description('Optional. Enable telemetry collection for the module.')
param enableTelemetry bool = true

// Create the Azure Firewall using the AVM resource module
module inner 'br/public:avm/res/network/azure-firewall:0.8.0' = {
  name: 'afw-avm-${firewall.name!}'
  params: {
    // Required
    name: firewall.name!

    // Optional pass-throughs
    hubIPAddresses: firewall.?hubIPAddresses
    virtualHubResourceId: firewall.?virtualHubResourceId
    virtualNetworkResourceId: firewall.?virtualNetworkResourceId
    additionalPublicIpConfigurations: firewall.?additionalPublicIpConfigurations
    applicationRuleCollections: firewall.?applicationRuleCollections
    autoscaleMaxCapacity: firewall.?autoscaleMaxCapacity
    autoscaleMinCapacity: firewall.?autoscaleMinCapacity
    availabilityZones: firewall.?availabilityZones
    azureSkuTier: firewall.?azureSkuTier
    diagnosticSettings: firewall.?diagnosticSettings
    enableForcedTunneling: firewall.?enableForcedTunneling
    enableTelemetry: enableTelemetry
    firewallPolicyId: firewall.?firewallPolicyId
    location: firewall.?location
    lock: firewall.?lock
    managementIPAddressObject: firewall.?managementIPAddressObject
    managementIPResourceID: firewall.?managementIPResourceID
    natRuleCollections: firewall.?natRuleCollections
    networkRuleCollections: firewall.?networkRuleCollections
    publicIPAddressObject: firewall.?publicIPAddressObject
    publicIPResourceID: firewall.?publicIPResourceID
    roleAssignments: firewall.?roleAssignments
    tags: firewall.?tags
    threatIntelMode: firewall.?threatIntelMode
  }
}

// Outputs
@description('Azure Firewall resource ID.')
output resourceId string = inner.outputs.resourceId

@description('Azure Firewall name.')
output name string = inner.outputs.name

@description('Azure Firewall resource group name.')
output resourceGroupName string = inner.outputs.resourceGroupName

@description('Azure Firewall location.')
output location string = inner.outputs.location

@description('Azure Firewall private IP address.')
output privateIp string = inner.outputs.privateIp
