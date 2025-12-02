using './main.bicep'

@description('Per-service deployment toggles.')
param deployToggles = {
  acaEnvironmentNsg: true
  agentNsg: true
  apiManagement: true
  apiManagementNsg: true
  appConfig: true
  appInsights: true
  applicationGateway: true
  applicationGatewayNsg: true
  applicationGatewayPublicIp: true
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

@description('Existing resource IDs (empty means create new).')
param resourceIds = {}

@description('Enable platform landing zone integration. When true, private DNS zones and private endpoints are managed by the platform landing zone.')
param flagPlatformLandingZone = false
