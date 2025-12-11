using './main.bicep'

param deployToggles = {
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

// Existing resource IDs (empty means create new).
param resourceIds = {}

// Enable platform landing zone integration. When true, private DNS zones and private endpoints are managed by the platform landing zone.
param flagPlatformLandingZone = false
