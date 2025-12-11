using './main.bicep'

param deployToggles = {
  acaEnvironmentNsg: true
  agentNsg: true
  apiManagement: false
  apiManagementNsg: false
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

param resourceIds = {}

param flagPlatformLandingZone = false
