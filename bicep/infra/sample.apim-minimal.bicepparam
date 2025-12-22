using './main.bicep'

// Minimal deployment focused on testing API Management (APIM).
// - Deploys only the Virtual Network (with default subnets) and APIM.
// - Disables Platform Landing Zone integration so the template does not attempt to manage Private DNS Zones / Private Endpoints.
//
// Notes:
// - Default APIM in this repo is PremiumV2 with Internal VNet injection.
// - You can override APIM settings via the apimDefinition parameter if needed.

param deployToggles = {
  // AI
  aiFoundry: false

  // OBSERVABILITY - Monitoring
  logAnalytics: false
  appInsights: false

  // NETWORKING - Virtual Network
  virtualNetwork: true

  // NETWORKING - Network Security Groups
  peNsg: false
  agentNsg: false
  acaEnvironmentNsg: false
  apiManagementNsg: false
  applicationGatewayNsg: false
  jumpboxNsg: false
  devopsBuildAgentsNsg: false
  bastionNsg: false

  // SECURITY - Key Management & Storage
  keyVault: false
  storageAccount: false

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
  apiManagement: true

  // NETWORKING - Gateways & Security
  applicationGateway: false
  applicationGatewayPublicIp: false
  wafPolicy: false
  firewall: false
  userDefinedRoutes: false
}

// Existing resource IDs (empty means create new).
param resourceIds = {}

// Enable platform landing zone integration. When true, private DNS zones and private endpoints are managed by the platform landing zone.
param flagPlatformLandingZone = true

// -----------------------------------------------------------------------------
// OPTIONAL: Test APIM Private Endpoint path
// -----------------------------------------------------------------------------
// By default, this file focuses on APIM with Internal VNet injection (no APIM PE).
//
// If you want to specifically test the APIM Private Endpoint workflow instead:
// 1) Change the line above to:  param flagPlatformLandingZone = false
//    (so this template creates Private DNS Zones + Private Endpoints)
// 2) In deployToggles above, set: peNsg: true   (recommended)
// 3) Uncomment the params below.
//
// Notes:
// - APIM Private Endpoint is only created when apimDefinition.virtualNetworkType = 'None'
// - Supported SKUs for APIM PE in this template: StandardV2, Premium, PremiumV2
//
// param baseName = 'apimpe-test'
//
// param apimDefinition = {
//   name: 'apim-${baseName}'
//   publisherEmail: 'admin@contoso.com'
//   publisherName: 'Contoso'
//
//   // Make APIM public (required for APIM Private Endpoint in this template)
//   sku: 'StandardV2'
//   skuCapacity: 1
//   virtualNetworkType: 'None'
// }
//
// Optional: override APIM private endpoint naming (defaults exist in main.bicep)
// param apimPrivateEndpointDefinition = {
//   name: 'pe-apim-${baseName}'
// }
