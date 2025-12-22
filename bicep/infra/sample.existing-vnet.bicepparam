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

  // Routing
  userDefinedRoutes: false
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

// -----------------------------------------------------------------------------
// OPTIONAL: UDR to hub firewall (Platform / Existing VNet)
// -----------------------------------------------------------------------------
// When enabled, creates a Route Table with a default route (0.0.0.0/0) pointing
// to the hub firewall/NVA IP and associates it to key workload subnets.
//
// IMPORTANT:
// - This is optional; enabling without a valid next hop can break egress.
// - If the template cannot determine a consistent firewall signal, it will skip
//   deploying UDR (defensive behavior).
//
// To enable:
// 1) In deployToggles above, set: userDefinedRoutes: true
// 2) Set firewallPrivateIp
// 3) Optional: set appGatewayInternetRoutingException = true to keep App Gateway v2 subnet using Internet routing
// param firewallPrivateIp = '10.0.0.4'
