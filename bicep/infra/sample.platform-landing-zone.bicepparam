using './main.bicep'

// Platform Landing Zone — PDNS/PE managed by the platform.
// Provide IDs of existing Private DNS Zones managed by the platform landing zone.

param deployToggles = {
  // AI
  aiFoundry: true

  // Application and data services
  logAnalytics: true
  appInsights: true
  containerEnv: true
  containerRegistry: true
  cosmosDb: true
  searchService: false
  keyVault: true
  storageAccount: true
  appConfig: true

  // Infra components managed by platform or excluded
  apiManagement: false
  applicationGateway: false
  applicationGatewayPublicIp: false
  firewall: false
  wafPolicy: false
  buildVm: false
  bastionHost: false
  jumpVm: false

  // NSGs still required for local subnets
  agentNsg: true
  peNsg: true
  applicationGatewayNsg: false
  apiManagementNsg: false
  acaEnvironmentNsg: true
  jumpboxNsg: false
  devopsBuildAgentsNsg: true
  bastionNsg: false

  // Workload VNet created if pattern requires isolation
  virtualNetwork: true

  // Container Apps workloads not deployed in this example
  containerApps: false
  groundingWithBingSearch: false
}

param flagPlatformLandingZone = true

param privateDnsZonesDefinition = {
  allowInternetResolutionFallback: false
  createNetworkLinks: false
  cognitiveservicesZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com'
  openaiZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com'
  aiServicesZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com'
  searchZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net'
  cosmosSqlZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com'
  blobZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'
  keyVaultZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'
  appConfigZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.azconfig.io'
  containerAppsZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.eastus2.azurecontainerapps.io'
  acrZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io'
  appInsightsZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.applicationinsights.azure.com'
  tags: { ManagedBy: 'PlatformLZ' }
}

param resourceIds = {}
