using './main.bicep'

// Base name for resources to avoid naming conflicts with soft-deleted resources
param baseName = 'ailzhb02'

// Per-service deployment toggles.
param deployToggles = {
  acaEnvironmentNsg: true
  agentNsg: true
  apiManagement: false
  apiManagementNsg: false
  appConfig: true
  appInsights: true
  applicationGateway: false
  applicationGatewayNsg: false
  applicationGatewayPublicIp: false
  bastionHost: true
  bastionNsg: true
  buildVm: true
  containerApps: true
  containerEnv: true
  containerRegistry: true
  cosmosDb: true
  devopsBuildAgentsNsg: true
  firewall: true
  groundingWithBingSearch: true
  jumpVm: true
  jumpboxNsg: true
  keyVault: true
  logAnalytics: true
  peNsg: true
  searchService: true
  storageAccount: true
  virtualNetwork: true
  wafPolicy: true
}

// Existing resource IDs (empty means create new).
param resourceIds = {}

// Enable platform landing zone integration. When true, private DNS zones and private endpoints are managed by the platform landing zone.
param flagPlatformLandingZone = false

// AI Foundry Configuration
param aiFoundryDefinition = {
  aiFoundryConfiguration: {
    createCapabilityHosts: true
    project: {
      name: 'project-hb'
      displayName: 'HB Foundry Project'
    }
  }
  aiModelDeployments: [
    {
      name: 'gpt-4o'
      model: {
        format: 'OpenAI'
        name: 'gpt-4o'
        version: '2024-05-13'
      }
      sku: {
        name: 'Standard'
        capacity: 10
      }
    }
  ]
}
