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
// OPTIONAL: UDR to spoke firewall (Standalone)
// -----------------------------------------------------------------------------
// When enabled, creates a Route Table with a default route (0.0.0.0/0) pointing
// to a firewall/NVA in the spoke VNet and associates it to key workload subnets.
//
// IMPORTANT:
// - Only enable this if you have a valid next hop.
// - Either deploy a firewall via deployToggles.firewall=true OR reuse an existing firewall,
//   and set firewallPrivateIp to the firewall/NVA private IP.
//
// To enable:
// 1) In deployToggles above, set: userDefinedRoutes: true
// 2) Set firewallPrivateIp
// 3) Optional: set appGatewayInternetRoutingException = true to keep App Gateway v2 subnet using Internet routing
// param firewallPrivateIp = '192.168.0.132'

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
