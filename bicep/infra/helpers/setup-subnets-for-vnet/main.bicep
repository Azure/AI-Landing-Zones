// Wrapper component that handles subnet selection and deployment to existing VNet
targetScope = 'resourceGroup'

@description('Required. Configuration for adding subnets to an existing VNet.')
param existingVNetSubnetsDefinition object

@description('Required. NSG resource IDs for automatic association with subnets.')
param nsgResourceIds object

// This wrapper handles subnet selection and deployment logic

// Default subnets for existing VNet scenario (192.168.x.x addressing)
var defaultExistingVnetSubnets = [
  {
    name: 'agent-subnet'
    addressPrefix: '192.168.0.0/25'
    delegation: 'Microsoft.App/environments'
    serviceEndpoints: ['Microsoft.CognitiveServices']
    networkSecurityGroupResourceId: !empty(nsgResourceIds.agentNsgResourceId) ? nsgResourceIds.agentNsgResourceId : null
  }
  {
    name: 'pe-subnet'
    addressPrefix: '192.168.1.64/27'
    serviceEndpoints: ['Microsoft.AzureCosmosDB']
    privateEndpointNetworkPolicies: 'Disabled'
    networkSecurityGroupResourceId: !empty(nsgResourceIds.peNsgResourceId) ? nsgResourceIds.peNsgResourceId : null
  }
  {
    name: 'appgw-subnet'
    addressPrefix: '192.168.0.128/26'
    networkSecurityGroupResourceId: !empty(nsgResourceIds.applicationGatewayNsgResourceId) ? nsgResourceIds.applicationGatewayNsgResourceId : null
  }
  {
    name: 'AzureBastionSubnet'
    addressPrefix: '192.168.0.192/26'
  }
  {
    name: 'AzureFirewallSubnet'
    addressPrefix: '192.168.1.0/26'
  }
  {
    name: 'apim-subnet'
    addressPrefix: '192.168.1.160/27'
    networkSecurityGroupResourceId: !empty(nsgResourceIds.apiManagementNsgResourceId) ? nsgResourceIds.apiManagementNsgResourceId : null
  }
  {
    name: 'jumpbox-subnet'
    addressPrefix: '192.168.1.96/28'
    networkSecurityGroupResourceId: !empty(nsgResourceIds.jumpboxNsgResourceId) ? nsgResourceIds.jumpboxNsgResourceId : null
  }
  {
    name: 'aca-env-subnet'
    addressPrefix: '192.168.1.112/28'
    delegation: 'Microsoft.App/environments'
    serviceEndpoints: ['Microsoft.AzureCosmosDB']
    networkSecurityGroupResourceId: !empty(nsgResourceIds.acaEnvironmentNsgResourceId) ? nsgResourceIds.acaEnvironmentNsgResourceId : null
  }
  {
    name: 'devops-agents-subnet'
    addressPrefix: '192.168.1.128/28'
    networkSecurityGroupResourceId: !empty(nsgResourceIds.devopsBuildAgentsNsgResourceId) ? nsgResourceIds.devopsBuildAgentsNsgResourceId : null
  }
]

// Enrich user subnets with NSG associations (when user provides custom subnets)
module enrichSubnetsWithNsgs '../enrich-subnets-with-nsgs/main.bicep' = if (existingVNetSubnetsDefinition.?useDefaultSubnets == false && !empty(existingVNetSubnetsDefinition.?subnets)) {
  name: 'm-enrich-subnets'
  params: {
    userSubnets: existingVNetSubnetsDefinition.subnets!
    agentNsgResourceId: nsgResourceIds.agentNsgResourceId
    peNsgResourceId: nsgResourceIds.peNsgResourceId
    applicationGatewayNsgResourceId: nsgResourceIds.applicationGatewayNsgResourceId
    apiManagementNsgResourceId: nsgResourceIds.apiManagementNsgResourceId
    jumpboxNsgResourceId: nsgResourceIds.jumpboxNsgResourceId
    acaEnvironmentNsgResourceId: nsgResourceIds.acaEnvironmentNsgResourceId
    devopsBuildAgentsNsgResourceId: nsgResourceIds.devopsBuildAgentsNsgResourceId
    bastionNsgResourceId: nsgResourceIds.bastionNsgResourceId
  }
}

// Determine which subnets to use: custom subnets (enriched with NSGs), defaults, or raw custom
var subnetsForExistingVnet = existingVNetSubnetsDefinition.?useDefaultSubnets != false && empty(existingVNetSubnetsDefinition.?subnets) 
  ? defaultExistingVnetSubnets
  : existingVNetSubnetsDefinition.?useDefaultSubnets == false && !empty(existingVNetSubnetsDefinition.?subnets)
    ? enrichSubnetsWithNsgs!.outputs.enrichedSubnets
    : existingVNetSubnetsDefinition.subnets!

// Deploy subnets to existing VNet
module existingVNetSubnetsDeployment '../deploy-subnets-to-vnet/main.bicep' = {
  name: 'm-deploy-subnets'
  params: {
    existingVNetName: existingVNetSubnetsDefinition.existingVNetName
    subnets: subnetsForExistingVnet
  }
}

@description('Array of deployed subnet resource IDs.')
output subnetResourceIds array = existingVNetSubnetsDeployment.outputs.subnetResourceIds

@description('The resource ID of the parent Virtual Network.')
output virtualNetworkResourceId string = existingVNetSubnetsDeployment.outputs.virtualNetworkResourceId

@description('Array of subnet names.')
output subnetNames array = existingVNetSubnetsDeployment.outputs.subnetNames
