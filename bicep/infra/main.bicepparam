using './main.bicep'

param deployToggles = {
  // CORE - Monitoring 
  logAnalytics: true
  appInsights: true
  
  // CORE - Networking 
  virtualNetwork: true
  peNsg: true
  
  // CORE - Security & Storage 
  keyVault: true
  storageAccount: true
  
  // OPTIONAL - Container infrastructure 
  containerRegistry: false
  containerEnv: false
  containerApps: false
  
  // DISABLED 
  acaEnvironmentNsg: false
  agentNsg: false
  apiManagement: false
  apiManagementNsg: false
  appConfig: false
  applicationGateway: false
  applicationGatewayNsg: false
  applicationGatewayPublicIp: false
  bastionHost: false
  bastionNsg: false
  buildVm: false
  cosmosDb: false
  devopsBuildAgentsNsg: false
  firewall: false
  groundingWithBingSearch: false
  jumpVm: false
  jumpboxNsg: false
  searchService: false
  wafPolicy: false
}

param resourceIds = {}

param flagPlatformLandingZone = false
