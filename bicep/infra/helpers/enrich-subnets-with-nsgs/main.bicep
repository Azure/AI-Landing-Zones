// Helper module to enrich user subnets with NSG associations
targetScope = 'resourceGroup'

@description('Required. User-defined subnet array.')
param userSubnets array

@description('Optional. Agent NSG Resource ID.')
param agentNsgResourceId string = ''

@description('Optional. Private Endpoints NSG Resource ID.')
param peNsgResourceId string = ''

@description('Optional. Application Gateway NSG Resource ID.')
param applicationGatewayNsgResourceId string = ''

@description('Optional. Jumpbox NSG Resource ID.')
param jumpboxNsgResourceId string = ''

@description('Optional. ACA Environment NSG Resource ID.')
param acaEnvironmentNsgResourceId string = ''

@description('Optional. DevOps Build Agents NSG Resource ID.')
param devopsBuildAgentsNsgResourceId string = ''

@description('Optional. Bastion NSG Resource ID.')
param bastionNsgResourceId string = ''

// Enrich subnets with NSGs based on naming conventions
var enrichedSubnets = [for subnet in userSubnets: union(subnet, {
  networkSecurityGroupResourceId: subnet.name == 'agent-subnet' && !empty(agentNsgResourceId) ? agentNsgResourceId
    : subnet.name == 'pe-subnet' && !empty(peNsgResourceId) ? peNsgResourceId  
    : subnet.name == 'appgw-subnet' && !empty(applicationGatewayNsgResourceId) ? applicationGatewayNsgResourceId
    : subnet.name == 'jumpbox-subnet' && !empty(jumpboxNsgResourceId) ? jumpboxNsgResourceId
    : subnet.name == 'aca-env-subnet' && !empty(acaEnvironmentNsgResourceId) ? acaEnvironmentNsgResourceId
    : subnet.name == 'devops-agents-subnet' && !empty(devopsBuildAgentsNsgResourceId) ? devopsBuildAgentsNsgResourceId
    : subnet.name == 'AzureBastionSubnet' && !empty(bastionNsgResourceId) ? bastionNsgResourceId
    : subnet.?networkSecurityGroupResourceId
})]

@description('Enriched subnets with NSG associations.')
output enrichedSubnets array = enrichedSubnets
