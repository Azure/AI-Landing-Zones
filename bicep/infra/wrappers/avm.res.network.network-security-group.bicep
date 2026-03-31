// AVM Network Security Group wrapper (pass-through)
targetScope = 'resourceGroup'

import { nsgDefinitionType } from '../common/types.bicep'

@description('Network Security Group definition.')
param nsg nsgDefinitionType

module inner 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: 'nsg-${uniqueString(nsg.name!)}'
  params: {
    name: nsg.name!
    location: nsg.?location
    flushConnection: nsg.?flushConnection
    securityRules: nsg.?securityRules
    tags: nsg.?tags
    lock: nsg.?lock
    enableTelemetry: nsg.?enableTelemetry
    diagnosticSettings: nsg.?diagnosticSettings
    roleAssignments: nsg.?roleAssignments
  }
}

@description('Network Security Group resource ID.')
output resourceId string = inner.outputs.resourceId
