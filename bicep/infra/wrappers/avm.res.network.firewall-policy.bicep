import { firewallPolicyDefinitionType } from '../common/types.bicep'

@description('Required. Azure Firewall Policy configuration object.')
param firewallPolicy firewallPolicyDefinitionType

@description('Optional. Enable telemetry collection for the module.')
param enableTelemetry bool = true

// Create the Firewall Policy using the AVM resource module
module inner 'br/public:avm/res/network/firewall-policy:0.3.1' = {
  name: 'fwp-avm-${firewallPolicy.name!}'
  params: {
    // Required
    name: firewallPolicy.name!

    // Optional pass-throughs
    allowSqlRedirect: firewallPolicy.?allowSqlRedirect
    basePolicyResourceId: firewallPolicy.?basePolicyResourceId
    certificateName: firewallPolicy.?certificateName
    defaultWorkspaceResourceId: firewallPolicy.?defaultWorkspaceResourceId
    enableProxy: firewallPolicy.?enableProxy
    enableTelemetry: enableTelemetry
    fqdns: firewallPolicy.?fqdns
    insightsIsEnabled: firewallPolicy.?insightsIsEnabled
    intrusionDetection: firewallPolicy.?intrusionDetection
    ipAddresses: firewallPolicy.?ipAddresses
    keyVaultSecretId: firewallPolicy.?keyVaultSecretId
    location: firewallPolicy.?location
    lock: firewallPolicy.?lock
    managedIdentities: firewallPolicy.?managedIdentities
    retentionDays: firewallPolicy.?retentionDays
    roleAssignments: firewallPolicy.?roleAssignments
    ruleCollectionGroups: firewallPolicy.?ruleCollectionGroups
    servers: firewallPolicy.?servers
    snat: firewallPolicy.?snat
    tags: firewallPolicy.?tags
    threatIntelMode: firewallPolicy.?threatIntelMode
    tier: firewallPolicy.?tier
    workspaces: firewallPolicy.?workspaces
  }
}

// Outputs
@description('Firewall Policy resource ID.')
output resourceId string = inner.outputs.resourceId

@description('Firewall Policy name.')
output name string = inner.outputs.name

@description('Firewall Policy resource group name.')
output resourceGroupName string = inner.outputs.resourceGroupName

@description('Firewall Policy location.')
output location string = inner.outputs.location
