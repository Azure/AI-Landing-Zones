// Subnet deployment to existing VNet 
targetScope = 'resourceGroup'

@description('Required. Subnet configuration array.')
param subnets array

@description('Required. Existing Virtual Network name or Resource ID. When using Resource ID, the component should be deployed to the target resource group scope.')
param existingVNetName string

@description('Optional. If set, and a subnet named apim-subnet has no explicit delegation, this delegation will be applied. Used for APIM VNet injection requirements.')
param apimSubnetDelegationServiceName string = ''

var effectiveDelegationPerSubnet = [for subnet in subnets: !empty(subnet.?delegation ?? '')
  ? subnet.delegation
  : (subnet.name == 'apim-subnet' ? apimSubnetDelegationServiceName : '')
]

// Parse Resource ID to extract VNet name (supports both name and Resource ID formats)
var vnetIdSegments = split(existingVNetName, '/')
var vnetName = length(vnetIdSegments) > 1 ? last(vnetIdSegments) : existingVNetName

// Reference existing VNet (assumes component is deployed to correct scope)
resource existingVNet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
}

// Deploy each subnet to the existing VNet
resource deployedSubnets 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = [for (subnet, index) in subnets: {
  name: subnet.name
  parent: existingVNet
  properties: {
    addressPrefix: subnet.?addressPrefix
    addressPrefixes: subnet.?addressPrefixes
    applicationGatewayIPConfigurations: subnet.?applicationGatewayIPConfigurations
    defaultOutboundAccess: subnet.?defaultOutboundAccess
    delegations: !empty(effectiveDelegationPerSubnet[index]) ? [
      {
        name: '${subnet.name}-delegation'
        properties: {
          serviceName: effectiveDelegationPerSubnet[index]
        }
      }
    ] : []
    natGateway: !empty(subnet.?natGatewayResourceId ?? '') ? {
      id: subnet.natGatewayResourceId
    } : null
    networkSecurityGroup: !empty(subnet.?networkSecurityGroupResourceId ?? '') ? {
      id: subnet.networkSecurityGroupResourceId
    } : null
    privateEndpointNetworkPolicies: subnet.?privateEndpointNetworkPolicies
    privateLinkServiceNetworkPolicies: subnet.?privateLinkServiceNetworkPolicies
    routeTable: !empty(subnet.?routeTableResourceId ?? '') ? {
      id: subnet.routeTableResourceId
    } : null
    serviceEndpointPolicies: subnet.?serviceEndpointPolicies
    serviceEndpoints: [for serviceName in (subnet.?serviceEndpoints ?? []): {
      service: serviceName
    }]
    sharingScope: subnet.?sharingScope
  }
}]

@description('Array of deployed subnet resource IDs.')
output subnetResourceIds array = [for (subnet, index) in subnets: deployedSubnets[index].id]

@description('The resource ID of the parent Virtual Network.')
output virtualNetworkResourceId string = existingVNet.id

@description('Array of subnet names.')
output subnetNames array = [for (subnet, index) in subnets: deployedSubnets[index].name]
