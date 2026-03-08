param accountName string
param location string
param modelName string
param modelFormat string
param modelVersion string
param modelSkuName string
param modelCapacity int
@description('Optional. List of model deployments to create. If provided and non-empty, it takes precedence over the single-model parameters.')
param modelDeployments array = []
param agentSubnetId string
param networkInjection string = 'true'

@description('Optional. Name for the default content filter RAI policy applied to all model deployments. Defaults to "default-content-filter".')
param defaultRaiPolicyName string = 'default-content-filter'

var varIsNetworkInjected = networkInjection == 'true'

var effectiveModelDeployments = !empty(modelDeployments)
  ? modelDeployments
  : [
      {
        name: modelName
        modelName: modelName
        modelFormat: modelFormat
        modelVersion: modelVersion
        modelSkuName: modelSkuName
        modelCapacity: modelCapacity
      }
    ]

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: accountName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: accountName
    networkAcls: varIsNetworkInjected ? {
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
      bypass: 'AzureServices'
    } : {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
      bypass: 'AzureServices'
    }
    publicNetworkAccess: varIsNetworkInjected ? 'Disabled' : 'Enabled'
    networkInjections: varIsNetworkInjected
      ? any([
          {
            scenario: 'agent'
            subnetArmId: agentSubnetId
            useMicrosoftManagedNetwork: false
          }
        ])
      : null
    disableLocalAuth: false
  }
}

// Default content filter policy: blocks harmful content at Medium severity across all categories.
// Applied to every model deployment unless overridden per-deployment via raiPolicyName.
#disable-next-line BCP081
resource defaultContentFilter 'Microsoft.CognitiveServices/accounts/raiPolicies@2025-04-01-preview' = {
  parent: account
  name: defaultRaiPolicyName
  properties: {
    mode: 'Blocking'
    contentFilters: [
      { name: 'Hate',      blocking: true, enabled: true, severityThreshold: 'Medium', source: 'Prompt'     }
      { name: 'Hate',      blocking: true, enabled: true, severityThreshold: 'Medium', source: 'Completion' }
      { name: 'Sexual',    blocking: true, enabled: true, severityThreshold: 'Medium', source: 'Prompt'     }
      { name: 'Sexual',    blocking: true, enabled: true, severityThreshold: 'Medium', source: 'Completion' }
      { name: 'Violence',  blocking: true, enabled: true, severityThreshold: 'Medium', source: 'Prompt'     }
      { name: 'Violence',  blocking: true, enabled: true, severityThreshold: 'Medium', source: 'Completion' }
      { name: 'SelfHarm',  blocking: true, enabled: true, severityThreshold: 'Medium', source: 'Prompt'     }
      { name: 'SelfHarm',  blocking: true, enabled: true, severityThreshold: 'Medium', source: 'Completion' }
      // Prompt shield (jailbreak detection) - prompts only
      { name: 'Jailbreak', blocking: true, enabled: true, source: 'Prompt' }
    ]
  }
}

@batchSize(1)
#disable-next-line BCP081
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = [
  for d in effectiveModelDeployments: {
    parent: account
    name: (empty(d.?name ?? '') ? string(d.modelName) : string(d.name))
    sku: {
      capacity: int(d.modelCapacity ?? 1)
      name: string(d.modelSkuName)
    }
    properties: {
      model: {
        name: string(d.modelName)
        format: string(d.modelFormat)
        version: string(d.modelVersion)
      }
      raiPolicyName: !empty(d.?raiPolicyName ?? '') ? string(d.raiPolicyName) : defaultRaiPolicyName
    }
    dependsOn: [defaultContentFilter]
  }
]

var modelDeploymentPairs = [
  for (d, i) in effectiveModelDeployments: {
    name: modelDeployment[i].name
    id: modelDeployment[i].id
  }
]

output accountName string = account.name
output accountID string = account.id
output accountTarget string = account.properties.endpoint
output accountPrincipalId string = account.identity.principalId

@description('Name of the default RAI content filter policy created on the account.')
output defaultRaiPolicyName string = defaultContentFilter.name

@description('Map of model deployment name to deployment resource ID.')
output modelDeploymentResourceIdsByName object = reduce(modelDeploymentPairs, {}, (acc, p) => union(acc, {
  '${p.name}': p.id
}))
