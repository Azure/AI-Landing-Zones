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
    networkAcls: {
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
      bypass:'AzureServices'
    }
    publicNetworkAccess: 'Disabled'
    networkInjections: (networkInjection == 'true')
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
    }
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

@description('Map of model deployment name to deployment resource ID.')
output modelDeploymentResourceIdsByName object = reduce(modelDeploymentPairs, {}, (acc, p) => union(acc, {
  '${p.name}': p.id
}))
