using './main.bicep'

// Platform Landing Zone mode: integrate workload (spoke) with an existing hub (platform).

// Spoke VNet/subnets in this sample:
// - This sample keeps `resourceIds = {}` and sets `deployToggles.virtualNetwork = true`, so the workload deployment
//   will CREATE the spoke VNet and its subnets.
// - Because this sample does NOT set `vNetDefinition`, the template uses the main.bicep defaults:
//   - VNet address space: 192.168.0.0/23
//   - Subnets:
//     - agent-subnet:        192.168.0.0/27
//     - pe-subnet:           192.168.0.32/27
//     - devops-agents-subnet:192.168.1.32/27
//     - aca-env-subnet:      192.168.1.0/27
//     - appgw-subnet:        192.168.0.192/27
//     - apim-subnet:         192.168.0.224/27

param deployToggles = {
  aiFoundry: true
  logAnalytics: true
  appInsights: true
  virtualNetwork: true
  peNsg: true
  agentNsg: false
  acaEnvironmentNsg: false
  apiManagementNsg: false
  applicationGatewayNsg: false
  jumpboxNsg: true
  devopsBuildAgentsNsg: false
  bastionNsg: true
  keyVault: true
  storageAccount: true
  cosmosDb: false
  searchService: false
  groundingWithBingSearch: false
  containerRegistry: false
  containerEnv: false
  containerApps: false
  buildVm: false
  jumpVm: true
  bastionHost: true
  appConfig: false
  apiManagement: false
  applicationGateway: false
  applicationGatewayPublicIp: false
  wafPolicy: false
  // In Platform Landing Zone mode, the firewall lives in the hub.
  // This workload template should not deploy a spoke firewall.
  firewall: false
  userDefinedRoutes: true
}

param resourceIds = {
}

param flagPlatformLandingZone = true

// Required for forced tunneling: hub Azure Firewall private IP (next hop).
// For the test platform deployed via bicep/tests/platform.bicep, this is typically 10.0.0.4.
param firewallPrivateIp = '10.0.0.4'

param hubVnetPeeringDefinition = {
  peerVnetResourceId: '/subscriptions/<hub-subscription-id>/resourceGroups/<hub-resource-group>/providers/Microsoft.Network/virtualNetworks/<hub-vnet-name>'
}
