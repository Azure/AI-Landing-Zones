import { wafPolicyDefinitionsType } from '../common/types.bicep'

@description('Required. Web Application Firewall (WAF) policy configuration object.')
param wafPolicy wafPolicyDefinitionsType

// Create the WAF Policy using native ARM resource
resource wafPolicyDeployment 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2024-01-01' = {
  name: wafPolicy.name!
  location: wafPolicy.?location ?? resourceGroup().location
  tags: wafPolicy.?tags
  properties: {
    policySettings: wafPolicy.?policySettings ?? {
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
      state: 'Enabled'
      mode: 'Prevention'
    }
    customRules: wafPolicy.?customRules ?? []
    managedRules: {
      managedRuleSets: [for ruleSet in wafPolicy.managedRules!.managedRuleSets: {
        ruleSetType: ruleSet.ruleSetType
        ruleSetVersion: ruleSet.ruleSetVersion
      }]
    }
  }
}

// Outputs
@description('WAF Policy resource ID.')
output resourceId string = wafPolicyDeployment.id

@description('WAF Policy name.')
output name string = wafPolicyDeployment.name

@description('WAF Policy resource group name.')
output resourceGroupName string = resourceGroup().name

@description('WAF Policy location.')
output location string = wafPolicyDeployment.location
