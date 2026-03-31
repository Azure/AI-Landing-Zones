import { appGatewayDefinitionType } from '../common/types.bicep'

@description('Required. Application Gateway configuration object.')
param applicationGateway appGatewayDefinitionType

@description('Optional. Enable telemetry collection for the module.')
param enableTelemetry bool = true

// Create the Application Gateway using the AVM resource module
module inner 'br/public:avm/res/network/application-gateway:0.7.2' = {
  name: 'agw-avm-${applicationGateway.name!}'
  params: {
    // Required
    name: applicationGateway.name!

    // Optional pass-throughs with defaults
    sku: applicationGateway.?sku ?? 'WAF_v2'
    firewallPolicyResourceId: applicationGateway.?firewallPolicyResourceId
    gatewayIPConfigurations: applicationGateway.?gatewayIPConfigurations
    frontendIPConfigurations: applicationGateway.?frontendIPConfigurations
    frontendPorts: applicationGateway.?frontendPorts
    backendAddressPools: applicationGateway.?backendAddressPools
    backendHttpSettingsCollection: applicationGateway.?backendHttpSettingsCollection
    httpListeners: applicationGateway.?httpListeners
    requestRoutingRules: applicationGateway.?requestRoutingRules
    probes: applicationGateway.?probes
    redirectConfigurations: applicationGateway.?redirectConfigurations
    rewriteRuleSets: applicationGateway.?rewriteRuleSets
    sslCertificates: applicationGateway.?sslCertificates
    trustedRootCertificates: applicationGateway.?trustedRootCertificates
    enableHttp2: applicationGateway.?enableHttp2
    customErrorConfigurations: applicationGateway.?customErrorConfigurations
    capacity: applicationGateway.?capacity
    autoscaleMinCapacity: applicationGateway.?autoscaleMinCapacity
    autoscaleMaxCapacity: applicationGateway.?autoscaleMaxCapacity
    enableTelemetry: enableTelemetry
    location: applicationGateway.?location
    tags: applicationGateway.?tags
    lock: applicationGateway.?lock
    managedIdentities: applicationGateway.?managedIdentities
    roleAssignments: applicationGateway.?roleAssignments
    diagnosticSettings: applicationGateway.?diagnosticSettings
  }
}

// Outputs
@description('Application Gateway resource ID.')
output resourceId string = inner.outputs.resourceId

@description('Application Gateway name.')
output name string = inner.outputs.name

@description('Application Gateway resource group name.')
output resourceGroupName string = inner.outputs.resourceGroupName

@description('Application Gateway location.')
output location string = inner.outputs.location
