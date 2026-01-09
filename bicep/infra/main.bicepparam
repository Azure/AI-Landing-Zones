using './main.bicep'

// Sample test

param deployToggles = {
  aiFoundry: true
  logAnalytics: true
  appInsights: true
  virtualNetwork: false
  peNsg: false
  agentNsg: false
  acaEnvironmentNsg: false
  apiManagementNsg: false
  applicationGatewayNsg: false
  jumpboxNsg: false
  devopsBuildAgentsNsg: false
  bastionNsg: false
  keyVault: true
  storageAccount: true
  cosmosDb: false
  searchService: true
  groundingWithBingSearch: false
  containerRegistry: false
  containerEnv: false
  containerApps: false
  buildVm: false
  jumpVm: false
  bastionHost: false
  appConfig: false
  apiManagement: false
  applicationGateway: false
  applicationGatewayPublicIp: false
  wafPolicy: false
  firewall: false
  userDefinedRoutes: false
}
