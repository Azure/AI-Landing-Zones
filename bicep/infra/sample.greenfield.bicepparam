using './main.bicep'

// Greenfield — full new and isolated deployment.

param deployToggles = {
  // AI
  aiFoundry: true

  // OBSERVABILITY - Monitoring
  logAnalytics: true
  appInsights: true

  // NETWORKING - Virtual Network
  virtualNetwork: true

  // NETWORKING - Network Security Groups
  peNsg: true
  agentNsg: false
  acaEnvironmentNsg: false
  apiManagementNsg: false
  applicationGatewayNsg: false
  jumpboxNsg: false
  devopsBuildAgentsNsg: false
  bastionNsg: false

  // SECURITY - Key Management & Storage
  keyVault: true
  storageAccount: true

  // DATA - Databases
  cosmosDb: false

  // DATA - Search & Knowledge
  searchService: false
  groundingWithBingSearch: false

  // COMPUTE - Container Infrastructure
  containerRegistry: false
  containerEnv: false
  containerApps: false

  // COMPUTE - Virtual Machines
  buildVm: false
  jumpVm: false
  bastionHost: false

  // GOVERNANCE - Configuration & Management
  appConfig: false
  apiManagement: false

  // NETWORKING - Gateways & Security
  applicationGateway: false
  applicationGatewayPublicIp: false
  wafPolicy: false
  firewall: false
}

param resourceIds = {}

param flagPlatformLandingZone = false
