// Network Security Groups Module
// This module deploys all NSGs for the AI Landing Zone

import * as types from '../common/types.bicep'

@description('The base name for resources.')
param baseName string

@description('The Azure region for resources.')
param location string

@description('Enable telemetry for AVM modules.')
param enableTelemetry bool

@description('Deployment toggles for NSGs.')
param deployToggles types.deployTogglesType

@description('Resource IDs for existing NSGs to reuse.')
param resourceIds types.resourceIdsType

@description('NSG definitions per subnet role.')
param nsgDefinitions types.nsgPerSubnetDefinitionsType?

// -----------------------
// DEPLOYMENT FLAGS
// -----------------------
var varDeployAgentNsg = deployToggles.agentNsg && empty(resourceIds.?agentNsgResourceId)
var varDeployPeNsg = deployToggles.peNsg && empty(resourceIds.?peNsgResourceId)
var varDeployApplicationGatewayNsg = deployToggles.applicationGatewayNsg && empty(resourceIds.?applicationGatewayNsgResourceId)
var varDeployApiManagementNsg = deployToggles.apiManagementNsg && empty(resourceIds.?apiManagementNsgResourceId)
var varDeployAcaEnvironmentNsg = deployToggles.acaEnvironmentNsg && empty(resourceIds.?acaEnvironmentNsgResourceId)
var varDeployJumpboxNsg = deployToggles.jumpboxNsg && empty(resourceIds.?jumpboxNsgResourceId)
var varDeployDevopsBuildAgentsNsg = deployToggles.devopsBuildAgentsNsg && empty(resourceIds.?devopsBuildAgentsNsgResourceId)
var varDeployBastionNsg = deployToggles.bastionNsg && empty(resourceIds.?bastionNsgResourceId)

// -----------------------
// NSG MODULES
// -----------------------

// Agent Subnet NSG
module agentNsgWrapper '../wrappers/avm.res.network.network-security-group.bicep' = if (varDeployAgentNsg) {
  name: 'm-nsg-agent'
  params: {
    nsg: union(
      {
        name: 'nsg-agent-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
      },
      nsgDefinitions!.?agent ?? {}
    )
  }
}

// Private Endpoints Subnet NSG
module peNsgWrapper '../wrappers/avm.res.network.network-security-group.bicep' = if (varDeployPeNsg) {
  name: 'm-nsg-pe'
  params: {
    nsg: union(
      {
        name: 'nsg-pe-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
      },
      nsgDefinitions!.?pe ?? {}
    )
  }
}

// Application Gateway Subnet NSG
module applicationGatewayNsgWrapper '../wrappers/avm.res.network.network-security-group.bicep' = if (varDeployApplicationGatewayNsg) {
  name: 'm-nsg-appgw'
  params: {
    nsg: union(
      {
        name: 'nsg-appgw-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
      },
      nsgDefinitions!.?applicationGateway ?? {}
    )
  }
}

// API Management Subnet NSG
module apiManagementNsgWrapper '../wrappers/avm.res.network.network-security-group.bicep' = if (varDeployApiManagementNsg) {
  name: 'm-nsg-apim'
  params: {
    nsg: union(
      {
        name: 'nsg-apim-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
      },
      nsgDefinitions!.?apiManagement ?? {}
    )
  }
}

// Azure Container Apps Environment Subnet NSG
module acaEnvironmentNsgWrapper '../wrappers/avm.res.network.network-security-group.bicep' = if (varDeployAcaEnvironmentNsg) {
  name: 'm-nsg-aca'
  params: {
    nsg: union(
      {
        name: 'nsg-aca-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
      },
      nsgDefinitions!.?acaEnvironment ?? {}
    )
  }
}

// Jumpbox Subnet NSG
module jumpboxNsgWrapper '../wrappers/avm.res.network.network-security-group.bicep' = if (varDeployJumpboxNsg) {
  name: 'm-nsg-jumpbox'
  params: {
    nsg: union(
      {
        name: 'nsg-jumpbox-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
      },
      nsgDefinitions!.?jumpbox ?? {}
    )
  }
}

// DevOps Build Agents Subnet NSG
module devopsBuildAgentsNsgWrapper '../wrappers/avm.res.network.network-security-group.bicep' = if (varDeployDevopsBuildAgentsNsg) {
  name: 'm-nsg-devops'
  params: {
    nsg: union(
      {
        name: 'nsg-devops-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
      },
      nsgDefinitions!.?devopsBuildAgents ?? {}
    )
  }
}

// Azure Bastion Subnet NSG
module bastionNsgWrapper '../wrappers/avm.res.network.network-security-group.bicep' = if (varDeployBastionNsg) {
  name: 'm-nsg-bastion'
  params: {
    nsg: union(
      {
        name: 'nsg-bastion-${baseName}'
        location: location
        enableTelemetry: enableTelemetry
        securityRules: [
          {
            name: 'AllowHttpsInbound'
            properties: {
              priority: 120
              protocol: 'Tcp'
              access: 'Allow'
              direction: 'Inbound'
              sourceAddressPrefix: 'Internet'
              sourcePortRange: '*'
              destinationAddressPrefix: '*'
              destinationPortRange: '443'
            }
          }
          {
            name: 'AllowGatewayManagerInbound'
            properties: {
              priority: 130
              protocol: 'Tcp'
              access: 'Allow'
              direction: 'Inbound'
              sourceAddressPrefix: 'GatewayManager'
              sourcePortRange: '*'
              destinationAddressPrefix: '*'
              destinationPortRange: '443'
            }
          }
          {
            name: 'AllowAzureLoadBalancerInbound'
            properties: {
              priority: 140
              protocol: 'Tcp'
              access: 'Allow'
              direction: 'Inbound'
              sourceAddressPrefix: 'AzureLoadBalancer'
              sourcePortRange: '*'
              destinationAddressPrefix: '*'
              destinationPortRange: '443'
            }
          }
          {
            name: 'AllowBastionHostCommunication'
            properties: {
              priority: 150
              protocol: '*'
              access: 'Allow'
              direction: 'Inbound'
              sourceAddressPrefix: 'VirtualNetwork'
              sourcePortRange: '*'
              destinationAddressPrefix: 'VirtualNetwork'
              destinationPortRanges: [
                '8080'
                '5701'
              ]
            }
          }
          {
            name: 'AllowSshRdpOutbound'
            properties: {
              priority: 100
              protocol: '*'
              access: 'Allow'
              direction: 'Outbound'
              sourceAddressPrefix: '*'
              sourcePortRange: '*'
              destinationAddressPrefix: 'VirtualNetwork'
              destinationPortRanges: [
                '22'
                '3389'
              ]
            }
          }
          {
            name: 'AllowAzureCloudOutbound'
            properties: {
              priority: 110
              protocol: 'Tcp'
              access: 'Allow'
              direction: 'Outbound'
              sourceAddressPrefix: '*'
              sourcePortRange: '*'
              destinationAddressPrefix: 'AzureCloud'
              destinationPortRange: '443'
            }
          }
          {
            name: 'AllowBastionCommunication'
            properties: {
              priority: 120
              protocol: '*'
              access: 'Allow'
              direction: 'Outbound'
              sourceAddressPrefix: 'VirtualNetwork'
              sourcePortRange: '*'
              destinationAddressPrefix: 'VirtualNetwork'
              destinationPortRanges: [
                '8080'
                '5701'
              ]
            }
          }
          {
            name: 'AllowGetSessionInformation'
            properties: {
              priority: 130
              protocol: '*'
              access: 'Allow'
              direction: 'Outbound'
              sourceAddressPrefix: '*'
              sourcePortRange: '*'
              destinationAddressPrefix: 'Internet'
              destinationPortRange: '80'
            }
          }
        ]
      },
      nsgDefinitions!.?bastion ?? {}
    )
  }
}

// -----------------------
// OUTPUTS
// -----------------------

@description('Agent NSG Resource ID')
output agentNsgResourceId string = resourceIds.?agentNsgResourceId ?? (varDeployAgentNsg ? agentNsgWrapper!.outputs.resourceId : '')

@description('Private Endpoints NSG Resource ID')
output peNsgResourceId string = resourceIds.?peNsgResourceId ?? (varDeployPeNsg ? peNsgWrapper!.outputs.resourceId : '')

@description('Application Gateway NSG Resource ID')
output applicationGatewayNsgResourceId string = resourceIds.?applicationGatewayNsgResourceId ?? (varDeployApplicationGatewayNsg ? applicationGatewayNsgWrapper!.outputs.resourceId : '')

@description('API Management NSG Resource ID')
output apiManagementNsgResourceId string = resourceIds.?apiManagementNsgResourceId ?? (varDeployApiManagementNsg ? apiManagementNsgWrapper!.outputs.resourceId : '')

@description('Container Apps Environment NSG Resource ID')
output acaEnvironmentNsgResourceId string = resourceIds.?acaEnvironmentNsgResourceId ?? (varDeployAcaEnvironmentNsg ? acaEnvironmentNsgWrapper!.outputs.resourceId : '')

@description('Jumpbox NSG Resource ID')
output jumpboxNsgResourceId string = resourceIds.?jumpboxNsgResourceId ?? (varDeployJumpboxNsg ? jumpboxNsgWrapper!.outputs.resourceId : '')

@description('DevOps Build Agents NSG Resource ID')
output devopsBuildAgentsNsgResourceId string = resourceIds.?devopsBuildAgentsNsgResourceId ?? (varDeployDevopsBuildAgentsNsg ? devopsBuildAgentsNsgWrapper!.outputs.resourceId : '')

@description('Bastion NSG Resource ID')
output bastionNsgResourceId string = resourceIds.?bastionNsgResourceId ?? (varDeployBastionNsg ? bastionNsgWrapper!.outputs.resourceId : '')
