// Networking Core Module
// This module deploys Virtual Network, Subnets, Public IPs, and VNet Peering

import * as types from '../common/types.bicep'

@description('The base name for resources.')
param baseName string

@description('The Azure region for resources.')
param location string

@description('Enable telemetry for AVM modules.')
param enableTelemetry bool

@description('Deployment toggles for networking resources.')
param deployToggles types.deployTogglesType

@description('Resource IDs for existing networking resources to reuse.')
param resourceIds types.resourceIdsType

@description('Virtual Network configuration.')
param vNetDefinition types.vNetDefinitionType?

@description('Application Gateway Public IP configuration.')
param appGatewayPublicIp types.publicIpDefinitionType?

@description('Azure Firewall Public IP configuration.')
param firewallPublicIp types.publicIpDefinitionType?

@description('Hub VNet peering configuration.')
param hubVnetPeeringDefinition types.hubVnetPeeringDefinitionType?

// NSG Resource IDs from Network Security module
@description('Agent NSG Resource ID.')
param agentNsgResourceId string = ''

@description('Private Endpoints NSG Resource ID.')
param peNsgResourceId string = ''

@description('Application Gateway NSG Resource ID.')
param applicationGatewayNsgResourceId string = ''

@description('API Management NSG Resource ID.')
param apiManagementNsgResourceId string = ''

@description('Container Apps Environment NSG Resource ID.')
param acaEnvironmentNsgResourceId string = ''

@description('Jumpbox NSG Resource ID.')
param jumpboxNsgResourceId string = ''

@description('DevOps Build Agents NSG Resource ID.')
param devopsBuildAgentsNsgResourceId string = ''

@description('Bastion NSG Resource ID.')
param bastionNsgResourceId string = ''

// -----------------------
// DEPLOYMENT FLAGS
// -----------------------
var varDeployVnet = deployToggles.virtualNetwork && empty(resourceIds.?virtualNetworkResourceId)
var varDeployApGatewayPip = deployToggles.applicationGatewayPublicIp && empty(resourceIds.?appGatewayPublicIpResourceId)
var varDeployFirewallPip = deployToggles.?firewall && empty(resourceIds.?firewallPublicIpResourceId)
var varDeployHubPeering = hubVnetPeeringDefinition != null && !empty(hubVnetPeeringDefinition.?peerVnetResourceId)

// -----------------------
// RESOURCE NAMING & PARSING
// -----------------------

// Parse hub VNet resource ID for peering
var varHubPeerVnetId = varDeployHubPeering ? hubVnetPeeringDefinition!.peerVnetResourceId! : ''
var varHubPeerParts = split(varHubPeerVnetId, '/')
var varHubPeerSub = varDeployHubPeering && length(varHubPeerParts) >= 3
  ? varHubPeerParts[2]
  : subscription().subscriptionId
var varHubPeerRg = varDeployHubPeering && length(varHubPeerParts) >= 5 ? varHubPeerParts[4] : resourceGroup().name
var varHubPeerVnetName = varDeployHubPeering && length(varHubPeerParts) >= 9 ? varHubPeerParts[8] : ''

// -----------------------
// VIRTUAL NETWORK
// -----------------------

var agentSubnet = union(
  {
    enabled: true
    name: 'agent-subnet'
    addressPrefix: '192.168.0.0/27'
    delegation: 'Microsoft.App/environments'
    serviceEndpoints: ['Microsoft.CognitiveServices']
  },
  !empty(agentNsgResourceId) ? { networkSecurityGroupResourceId: agentNsgResourceId } : {}
)

var peSubnet = union(
  {
    enabled: true
    name: 'pe-subnet'
    addressPrefix: '192.168.0.32/27'
    serviceEndpoints: ['Microsoft.AzureCosmosDB']
    privateEndpointNetworkPolicies: 'Disabled'
  },
  !empty(peNsgResourceId) ? { networkSecurityGroupResourceId: peNsgResourceId } : {}
)

var bastionSubnet = union(
  {
    enabled: true
    name: 'AzureBastionSubnet'
    addressPrefix: '192.168.0.64/26'
  },
  !empty(bastionNsgResourceId) ? { networkSecurityGroupResourceId: bastionNsgResourceId } : {}
)

var firewallSubnet = {
  enabled: true
  name: 'AzureFirewallSubnet'
  addressPrefix: '192.168.0.128/26'
}

var appGatewaySubnet = union(
  {
    enabled: true
    name: 'appgw-subnet'
    addressPrefix: '192.168.0.192/27'
  },
  !empty(applicationGatewayNsgResourceId) ? { networkSecurityGroupResourceId: applicationGatewayNsgResourceId } : {}
)

var apimSubnet = union(
  {
    enabled: true
    name: 'apim-subnet'
    addressPrefix: '192.168.0.224/27'
  },
  !empty(apiManagementNsgResourceId) ? { networkSecurityGroupResourceId: apiManagementNsgResourceId } : {}
)

var jumpboxSubnet = union(
  {
    enabled: true
    name: 'jumpbox-subnet'
    addressPrefix: '192.168.1.0/28'
  },
  !empty(jumpboxNsgResourceId) ? { networkSecurityGroupResourceId: jumpboxNsgResourceId } : {}
)

var acaEnvSubnet = union(
  {
    enabled: true
    name: 'aca-env-subnet'
    addressPrefix: '192.168.2.0/23'
    delegation: 'Microsoft.App/environments'
    serviceEndpoints: ['Microsoft.AzureCosmosDB']
  },
  !empty(acaEnvironmentNsgResourceId) ? { networkSecurityGroupResourceId: acaEnvironmentNsgResourceId } : {}
)

var devopsAgentsSubnet = union(
  {
    enabled: true
    name: 'devops-agents-subnet'
    addressPrefix: '192.168.1.32/27'
  },
  !empty(devopsBuildAgentsNsgResourceId) ? { networkSecurityGroupResourceId: devopsBuildAgentsNsgResourceId } : {}
)

module vNetworkWrapper '../wrappers/avm.res.network.virtual-network.bicep' = if (varDeployVnet) {
  name: 'm-vnet'
  params: {
    vnet: union(
      {
        name: 'vnet-${baseName}'
        addressPrefixes: ['192.168.0.0/22']
        location: location
        enableTelemetry: enableTelemetry
        subnets: [
          agentSubnet
          peSubnet
          bastionSubnet
          firewallSubnet
          appGatewaySubnet
          apimSubnet
          jumpboxSubnet
          acaEnvSubnet
          devopsAgentsSubnet
        ]
      },
      vNetDefinition ?? {}
    )
  }
}

// VNet Resource ID resolution
var virtualNetworkResourceId = resourceIds.?virtualNetworkResourceId ?? (varDeployVnet
  ? vNetworkWrapper!.outputs.resourceId
  : '')

// Subnet IDs
var varApimSubnetId = empty(resourceIds.?virtualNetworkResourceId!)
  ? '${virtualNetworkResourceId}/subnets/apim-subnet'
  : '${resourceIds.virtualNetworkResourceId!}/subnets/apim-subnet'

var varPeSubnetId = empty(resourceIds.?virtualNetworkResourceId!)
  ? '${virtualNetworkResourceId}/subnets/pe-subnet'
  : '${resourceIds.virtualNetworkResourceId!}/subnets/pe-subnet'

var varAppGatewaySubnetId = empty(resourceIds.?virtualNetworkResourceId!)
  ? '${virtualNetworkResourceId}/subnets/appgw-subnet'
  : '${resourceIds.virtualNetworkResourceId!}/subnets/appgw-subnet'

var varJumpboxSubnetId = empty(resourceIds.?virtualNetworkResourceId!)
  ? '${virtualNetworkResourceId}/subnets/jumpbox-subnet'
  : '${resourceIds.virtualNetworkResourceId!}/subnets/jumpbox-subnet'

var varDevOpsBuildAgentsSubnetId = empty(resourceIds.?virtualNetworkResourceId!)
  ? '${virtualNetworkResourceId}/subnets/devops-agents-subnet'
  : '${resourceIds.virtualNetworkResourceId!}/subnets/devops-agents-subnet'

var varAzureFirewallSubnetId = empty(resourceIds.?virtualNetworkResourceId!)
  ? '${virtualNetworkResourceId}/subnets/AzureFirewallSubnet'
  : '${resourceIds.virtualNetworkResourceId!}/subnets/AzureFirewallSubnet'

// -----------------------
// PUBLIC IP ADDRESSES
// -----------------------

// Application Gateway Public IP
module appGatewayPipWrapper '../wrappers/avm.res.network.public-ip-address.bicep' = if (varDeployApGatewayPip) {
  name: 'm-appgw-pip'
  params: {
    pip: union(
      {
        name: 'pip-agw-${baseName}'
        skuName: 'Standard'
        skuTier: 'Regional'
        publicIPAllocationMethod: 'Static'
        publicIPAddressVersion: 'IPv4'
        zones: [1, 2, 3]
        location: location
        enableTelemetry: enableTelemetry
      },
      appGatewayPublicIp ?? {}
    )
  }
}

var appGatewayPublicIpResourceId = resourceIds.?appGatewayPublicIpResourceId ?? (varDeployApGatewayPip
  ? appGatewayPipWrapper!.outputs.resourceId
  : '')

// Azure Firewall Public IP
module firewallPipWrapper '../wrappers/avm.res.network.public-ip-address.bicep' = if (varDeployFirewallPip) {
  name: 'm-fw-pip'
  params: {
    pip: union(
      {
        name: 'pip-fw-${baseName}'
        skuName: 'Standard'
        skuTier: 'Regional'
        publicIPAllocationMethod: 'Static'
        publicIPAddressVersion: 'IPv4'
        zones: [1, 2, 3]
        location: location
        enableTelemetry: enableTelemetry
      },
      firewallPublicIp ?? {}
    )
  }
}

var firewallPublicIpResourceId = resourceIds.?firewallPublicIpResourceId ?? (varDeployFirewallPip
  ? firewallPipWrapper!.outputs.resourceId
  : '')

// -----------------------
// VNET PEERING
// -----------------------

// Spoke VNet with Peering to Hub
module spokeVNetWithPeering '../wrappers/avm.res.network.virtual-network.bicep' = if (varDeployHubPeering && varDeployVnet) {
  name: 'm-spoke-vnet-peering'
  params: {
    vnet: union(
      {
        name: 'vnet-${baseName}'
        addressPrefixes: ['192.168.0.0/22']
        location: location
        enableTelemetry: enableTelemetry
        peerings: [
          {
            name: hubVnetPeeringDefinition!.?name ?? 'to-hub'
            remoteVirtualNetworkResourceId: varHubPeerVnetId
            allowVirtualNetworkAccess: hubVnetPeeringDefinition!.?allowVirtualNetworkAccess ?? true
            allowForwardedTraffic: hubVnetPeeringDefinition!.?allowForwardedTraffic ?? true
            allowGatewayTransit: hubVnetPeeringDefinition!.?allowGatewayTransit ?? false
            useRemoteGateways: hubVnetPeeringDefinition!.?useRemoteGateways ?? false
          }
        ]
      },
      hubVnetPeeringDefinition ?? {}
    )
  }
}

// Hub-to-Spoke Reverse Peering
module hubToSpokePeering '../components/vnet-peering/main.bicep' = if (varDeployHubPeering && (hubVnetPeeringDefinition!.?createReversePeering ?? true)) {
  name: 'm-hub-to-spoke-peering'
  scope: resourceGroup(varHubPeerSub, varHubPeerRg)
  params: {
    localVnetName: varHubPeerVnetName
    remotePeeringName: hubVnetPeeringDefinition!.?reverseName ?? 'to-spoke-${baseName}'
    remoteVirtualNetworkResourceId: varDeployVnet ? spokeVNetWithPeering!.outputs.resourceId : virtualNetworkResourceId
    allowVirtualNetworkAccess: hubVnetPeeringDefinition!.?reverseAllowVirtualNetworkAccess ?? true
    allowForwardedTraffic: hubVnetPeeringDefinition!.?reverseAllowForwardedTraffic ?? true
    allowGatewayTransit: hubVnetPeeringDefinition!.?reverseAllowGatewayTransit ?? false
    useRemoteGateways: hubVnetPeeringDefinition!.?reverseUseRemoteGateways ?? false
  }
}

// -----------------------
// OUTPUTS
// -----------------------

@description('Virtual Network Resource ID')
output virtualNetworkResourceId string = virtualNetworkResourceId

@description('Private Endpoints Subnet ID')
output peSubnetId string = varPeSubnetId

@description('API Management Subnet ID')
output apimSubnetId string = varApimSubnetId

@description('Application Gateway Subnet ID')
output appGatewaySubnetId string = varAppGatewaySubnetId

@description('Jumpbox Subnet ID')
output jumpboxSubnetId string = varJumpboxSubnetId

@description('DevOps Build Agents Subnet ID')
output devOpsBuildAgentsSubnetId string = varDevOpsBuildAgentsSubnetId

@description('Azure Firewall Subnet ID')
output azureFirewallSubnetId string = varAzureFirewallSubnetId

@description('Application Gateway Public IP Resource ID')
output appGatewayPublicIpResourceId string = appGatewayPublicIpResourceId

@description('Azure Firewall Public IP Resource ID')
output firewallPublicIpResourceId string = firewallPublicIpResourceId
