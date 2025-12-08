// Gateway & Security Module
// This module deploys WAF Policy, Application Gateway, Firewall Policy, and Azure Firewall

import * as types from '../common/types.bicep'

@description('The base name for resources.')
param baseName string

@description('The Azure region for resources.')
param location string

@description('Enable telemetry for AVM modules.')
param enableTelemetry bool

@description('Resource tags.')
param tags types.tagsType

@description('Deployment toggles for gateway and security resources.')
param deployToggles types.deployTogglesType

@description('Resource IDs for existing resources to reuse.')
param resourceIds types.resourceIdsType

@description('Application Gateway configuration.')
param appGatewayDefinition types.appGatewayDefinitionType?

@description('Firewall Policy configuration.')
param firewallPolicyDefinition types.firewallPolicyDefinitionType?

@description('Azure Firewall configuration.')
param firewallDefinition types.firewallDefinitionType?

// Networking resource IDs
@description('Virtual Network Resource ID.')
param virtualNetworkResourceId string

@description('Application Gateway Subnet ID.')
param appGatewaySubnetId string

@description('Application Gateway Public IP Resource ID.')
param appGatewayPublicIpResourceId string = ''

@description('Azure Firewall Public IP Resource ID.')
param firewallPublicIpResourceId string = ''

@description('Deploy Application Gateway Public IP flag.')
param varDeployApGatewayPip bool

// -----------------------
// DEPLOYMENT FLAGS
// -----------------------
var varDeployWafPolicy = deployToggles.wafPolicy
var varDeployAppGateway = empty(resourceIds.?applicationGatewayResourceId!) && deployToggles.applicationGateway
var varDeployAfwPolicy = deployToggles.firewall && empty(resourceIds.?firewallPolicyResourceId!)
var varDeployFirewall = empty(resourceIds.?firewallResourceId!) && deployToggles.firewall

// -----------------------
// RESOURCE NAMING
// -----------------------

// Application Gateway naming
var varAgwIdSegments = empty(resourceIds.?applicationGatewayResourceId!)
  ? ['']
  : split(resourceIds.applicationGatewayResourceId!, '/')
var varAgwSub = length(varAgwIdSegments) >= 3 ? varAgwIdSegments[2] : ''
var varAgwRg = length(varAgwIdSegments) >= 5 ? varAgwIdSegments[4] : ''
var varAgwNameExisting = length(varAgwIdSegments) >= 1 ? last(varAgwIdSegments) : ''
var varAgwName = !empty(resourceIds.?applicationGatewayResourceId!)
  ? varAgwNameExisting
  : (empty(appGatewayDefinition.?name ?? '') ? 'agw-${baseName}' : appGatewayDefinition!.name)

// Azure Firewall naming
var varAfwIdSegments = empty(resourceIds.?firewallResourceId!) ? [''] : split(resourceIds.firewallResourceId!, '/')
var varAfwSub = length(varAfwIdSegments) >= 3 ? varAfwIdSegments[2] : ''
var varAfwRg = length(varAfwIdSegments) >= 5 ? varAfwIdSegments[4] : ''
var varAfwNameExisting = length(varAfwIdSegments) >= 1 ? last(varAfwIdSegments) : ''
var varAfwName = !empty(resourceIds.?firewallResourceId!)
  ? varAfwNameExisting
  : (empty(firewallDefinition.?name ?? '') ? 'afw-${baseName}' : firewallDefinition!.name)

// -----------------------
// EXISTING RESOURCES
// -----------------------

// Existing Application Gateway
resource existingAppGateway 'Microsoft.Network/applicationGateways@2024-07-01' existing = if (!empty(resourceIds.?applicationGatewayResourceId!)) {
  name: varAgwNameExisting
  scope: resourceGroup(varAgwSub, varAgwRg)
}

// Existing Azure Firewall
resource existingFirewall 'Microsoft.Network/azureFirewalls@2024-07-01' existing = if (!empty(resourceIds.?firewallResourceId!)) {
  name: varAfwNameExisting
  scope: resourceGroup(varAfwSub, varAfwRg)
}

// -----------------------
// APPLICATION GATEWAY CONFIGURATION
// -----------------------

// Determine if we need to create a WAF policy
var varAppGatewaySKU = appGatewayDefinition.?sku ?? 'WAF_v2'
var varAppGatewayNeedFirewallPolicy = (varAppGatewaySKU == 'WAF_v2')
var varWafPolicyResourceId = varDeployWafPolicy ? wafPolicy!.outputs.resourceId : ''
var varAppGatewayFirewallPolicyId = (varAppGatewayNeedFirewallPolicy ? varWafPolicyResourceId : '')

// -----------------------
// RESOURCE ID RESOLUTION
// -----------------------
var varAppGatewayResourceId = !empty(resourceIds.?applicationGatewayResourceId!)
  ? existingAppGateway.id
  : (varDeployAppGateway ? applicationGateway!.outputs.resourceId : '')

var firewallPolicyResourceId = resourceIds.?firewallPolicyResourceId ?? (varDeployAfwPolicy
  ? fwPolicy!.outputs.resourceId
  : '')

var varFirewallResourceId = !empty(resourceIds.?firewallResourceId!)
  ? existingFirewall.id
  : (varDeployFirewall ? azureFirewall!.outputs.resourceId : '')

// -----------------------
// MODULE DEPLOYMENTS
// -----------------------

// WAF Policy
module wafPolicy '../wrappers/avm.res.network.waf-policy.bicep' = if (varDeployWafPolicy) {
  name: 'wafPolicyDeployment'
  params: {
    wafPolicy: {
      name: 'afwp-${baseName}'
      managedRules: {
        exclusions: []
        managedRuleSets: [
          {
            ruleSetType: 'OWASP'
            ruleSetVersion: '3.2'
            ruleGroupOverrides: []
          }
        ]
      }
      location: location
      tags: tags
    }
  }
}

// Application Gateway
module applicationGateway '../wrappers/avm.res.network.application-gateway.bicep' = if (varDeployAppGateway) {
  name: 'applicationGatewayDeployment'
  params: {
    applicationGateway: union(
      {
        // Required parameters with defaults
        name: varAgwName
        sku: varAppGatewaySKU

        // Gateway IP configurations
        gatewayIPConfigurations: [
          {
            name: 'appGatewayIpConfig'
            properties: {
              subnet: {
                id: appGatewaySubnetId
              }
            }
          }
        ]

        // WAF policy wiring
        firewallPolicyResourceId: varAppGatewayFirewallPolicyId

        // Location and tags
        location: location
        tags: tags

        // Frontend IP configurations
        frontendIPConfigurations: concat(
          varDeployApGatewayPip
            ? [
                {
                  name: 'publicFrontend'
                  properties: { publicIPAddress: { id: appGatewayPublicIpResourceId } }
                }
              ]
            : [],
          [
            {
              name: 'privateFrontend'
              properties: {
                privateIPAllocationMethod: 'Static'
                privateIPAddress: '192.168.0.200'
                subnet: { id: appGatewaySubnetId }
              }
            }
          ]
        )

        // Frontend ports
        frontendPorts: [
          {
            name: 'port80'
            properties: { port: 80 }
          }
        ]

        // Backend address pools
        backendAddressPools: [
          {
            name: 'defaultBackendPool'
          }
        ]

        // Backend HTTP settings
        backendHttpSettingsCollection: [
          {
            name: 'defaultHttpSettings'
            properties: {
              cookieBasedAffinity: 'Disabled'
              port: 80
              protocol: 'Http'
              requestTimeout: 20
            }
          }
        ]

        // HTTP listeners
        httpListeners: [
          {
            name: 'httpListener'
            properties: {
              frontendIPConfiguration: {
                id: '${resourceId('Microsoft.Network/applicationGateways', varAgwName)}/frontendIPConfigurations/${varDeployApGatewayPip ? 'publicFrontend' : 'privateFrontend'}'
              }
              frontendPort: {
                id: '${resourceId('Microsoft.Network/applicationGateways', varAgwName)}/frontendPorts/port80'
              }
              protocol: 'Http'
            }
          }
        ]

        // Request routing rules
        requestRoutingRules: [
          {
            name: 'httpRoutingRule'
            properties: {
              backendAddressPool: {
                id: '${resourceId('Microsoft.Network/applicationGateways', varAgwName)}/backendAddressPools/defaultBackendPool'
              }
              backendHttpSettings: {
                id: '${resourceId('Microsoft.Network/applicationGateways', varAgwName)}/backendHttpSettingsCollection/defaultHttpSettings'
              }
              httpListener: {
                id: '${resourceId('Microsoft.Network/applicationGateways', varAgwName)}/httpListeners/httpListener'
              }
              priority: 100
              ruleType: 'Basic'
            }
          }
        ]
      },
      appGatewayDefinition ?? {}
    )
    enableTelemetry: enableTelemetry
  }
}

// Firewall Policy
module fwPolicy '../wrappers/avm.res.network.firewall-policy.bicep' = if (varDeployAfwPolicy) {
  name: 'firewallPolicyDeployment'
  params: {
    firewallPolicy: union(
      {
        name: empty(firewallPolicyDefinition.?name ?? '') ? 'afwp-${baseName}' : firewallPolicyDefinition!.name
        location: location
        tags: tags
      },
      firewallPolicyDefinition ?? {}
    )
    enableTelemetry: enableTelemetry
  }
}

// Azure Firewall
module azureFirewall '../wrappers/avm.res.network.azure-firewall.bicep' = if (varDeployFirewall) {
  name: 'azureFirewallDeployment'
  params: {
    firewall: union(
      {
        name: varAfwName
        virtualNetworkResourceId: virtualNetworkResourceId
        publicIPResourceID: firewallPublicIpResourceId
        firewallPolicyId: firewallPolicyResourceId
        availabilityZones: [1, 2, 3]
        azureSkuTier: 'Standard'
        location: location
        tags: tags
      },
      firewallDefinition ?? {}
    )
    enableTelemetry: enableTelemetry
  }
}

// -----------------------
// OUTPUTS
// -----------------------

@description('WAF Policy Resource ID')
output wafPolicyResourceId string = varDeployWafPolicy ? wafPolicy!.outputs.resourceId : ''

@description('Application Gateway Resource ID')
output applicationGatewayResourceId string = varAppGatewayResourceId

@description('Application Gateway Name')
output applicationGatewayName string = varAgwName

@description('Firewall Policy Resource ID')
output firewallPolicyResourceId string = firewallPolicyResourceId

@description('Azure Firewall Resource ID')
output firewallResourceId string = varFirewallResourceId

@description('Azure Firewall Name')
output firewallName string = varAfwName
