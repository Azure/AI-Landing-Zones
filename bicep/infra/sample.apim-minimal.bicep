// Minimal APIM-only deployment sample.
// Equivalent to `sample.apim-minimal.json`, but as a Bicep entrypoint.
//
// Note: This still enables `virtualNetwork=true` because APIM is deployed with VNet integration by default.

targetScope = 'resourceGroup'

module landingZone './main.bicep' = {
  name: 'apim-minimal'
  params: {
    deployToggles: {
      aiFoundry: false
      logAnalytics: false
      appInsights: false
      virtualNetwork: true
      peNsg: false
      agentNsg: false
      acaEnvironmentNsg: false
      apiManagementNsg: false
      applicationGatewayNsg: false
      jumpboxNsg: false
      devopsBuildAgentsNsg: false
      bastionNsg: false
      keyVault: false
      storageAccount: false
      cosmosDb: false
      searchService: false
      groundingWithBingSearch: false
      containerRegistry: false
      containerEnv: false
      containerApps: false
      buildVm: false
      jumpVm: false
      bastionHost: false
      appConfig: false
      apiManagement: true
      applicationGateway: false
      applicationGatewayPublicIp: false
      wafPolicy: false
      firewall: false
      userDefinedRoutes: false
    }
    resourceIds: {}
    flagPlatformLandingZone: true
  }
}
