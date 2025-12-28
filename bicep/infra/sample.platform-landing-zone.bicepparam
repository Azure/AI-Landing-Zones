using './main.bicep'

// Platform-integrated (PLZ) training/test parameters.
// - Workload creates the spoke-side peering (spoke → hub).
// - Platform creates hub → spoke peering and links platform DNS to the spoke.

param deployToggles = {
  aiFoundry: true
  logAnalytics: true
  appInsights: true
  containerEnv: true
  containerRegistry: true
  cosmosDb: true
  searchService: false
  keyVault: true
  storageAccount: true
  appConfig: true
  apiManagement: false
  applicationGateway: false
  applicationGatewayPublicIp: false
  firewall: false
  userDefinedRoutes: true
  wafPolicy: false
  buildVm: false
  bastionHost: false
  jumpVm: false
  agentNsg: true
  peNsg: true
  applicationGatewayNsg: false
  apiManagementNsg: false
  acaEnvironmentNsg: true
  jumpboxNsg: false
  devopsBuildAgentsNsg: true
  bastionNsg: false
  virtualNetwork: true
  containerApps: false
  groundingWithBingSearch: false
}

param flagPlatformLandingZone = true
param resourceIds = {}

// Required: spoke → hub peering.
param hubVnetPeeringDefinition = {
  peerVnetResourceId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<hubVnetName>'
}

// Required for forced tunneling: hub firewall/NVA private IP (next hop).
param firewallPrivateIp = '10.0.0.4'
