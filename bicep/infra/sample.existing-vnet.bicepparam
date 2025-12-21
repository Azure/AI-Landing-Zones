using './main.bicep'

// Existing VNet — reuse an existing virtual network.
// This scenario creates the AI Landing Zone subnets inside an existing VNet.
// NOTE: you must set existingVNetSubnetsDefinition.existingVNetName (and likely ensure the VNet exists in the same subscription/resource group scope).

param deployToggles = {
  // AI
  aiFoundry: true

  // Application and data services
  logAnalytics: true
  appInsights: true
  containerEnv: true
  containerRegistry: true
  cosmosDb: true
  searchService: false
  keyVault: true
  storageAccount: true
  appConfig: true

  // Infra components not deployed in this scenario
  apiManagement: false
  applicationGateway: false
  applicationGatewayPublicIp: false
  firewall: false
  wafPolicy: false
  buildVm: false
  bastionHost: false
  jumpVm: false

  // NSGs for subnets created
  agentNsg: true
  peNsg: true
  applicationGatewayNsg: false
  apiManagementNsg: false
  acaEnvironmentNsg: true
  jumpboxNsg: false
  devopsBuildAgentsNsg: true
  bastionNsg: false

  // VNet already exists
  virtualNetwork: false

  // Container Apps workloads not deployed in this example
  containerApps: false
  groundingWithBingSearch: false
}

param existingVNetSubnetsDefinition = {
  existingVNetName: 'your-existing-vnet-name'
  useDefaultSubnets: false
  subnets: [
    {
      name: 'agent-subnet'
      addressPrefix: '192.168.0.0/27'
      delegation: 'Microsoft.App/environments'
      serviceEndpoints: ['Microsoft.CognitiveServices']
    }
    {
      name: 'pe-subnet'
      addressPrefix: '192.168.0.32/27'
      serviceEndpoints: ['Microsoft.AzureCosmosDB']
      privateEndpointNetworkPolicies: 'Disabled'
    }
    {
      name: 'aca-env-subnet'
      addressPrefix: '192.168.2.0/23'
      delegation: 'Microsoft.App/environments'
      serviceEndpoints: ['Microsoft.AzureCosmosDB']
    }
    {
      name: 'devops-agents-subnet'
      addressPrefix: '192.168.1.32/27'
    }
    // Other infra subnets (AppGW, Bastion, Firewall, Jumpbox, APIM) omitted here
  ]
}

param resourceIds = {}

param flagPlatformLandingZone = false
