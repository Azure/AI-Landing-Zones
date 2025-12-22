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
  userDefinedRoutes: false
}

param resourceIds = {}

param flagPlatformLandingZone = false

// -----------------------------------------------------------------------------
// OPTIONAL: User Defined Routes (UDR)
// -----------------------------------------------------------------------------
// Creates a Route Table with a default route (0.0.0.0/0) pointing to a firewall/NVA
// and associates it to key workload subnets.
//
// To enable:
// 1) In deployToggles above, set: userDefinedRoutes: true
// 2) Set firewallPrivateIp to the firewall/NVA private IP (next hop)
// 3) Optional: set appGatewayInternetRoutingException = true to keep App Gateway v2 subnet using Internet routing
//
// Defensive behavior: if userDefinedRoutes is true but firewallPrivateIp is empty
// (and there is no firewall signal via deploy/reuse), UDR deployment is skipped.
//
// param firewallPrivateIp = ''
// param appGatewayInternetRoutingException = false

// -----------------------------------------------------------------------------
// OPTIONAL: Microsoft Defender for AI (subscription-scoped)
// -----------------------------------------------------------------------------
// WARNING:
// - This configures Defender for Cloud pricing at subscription scope via `Microsoft.Security/pricings`.
// - Requires subscription-level permissions (typically Subscription Owner, or equivalent Security admin permissions).
// - Keep disabled by default to avoid deployments failing in restricted subscriptions.
//
// To enable:
// param enableDefenderForAI = true
