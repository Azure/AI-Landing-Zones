# Main.bicep Module Integration Guide

## Overview
This guide shows how to integrate all 9 extracted modules back into `main.bicep`, replacing the inline resource deployments with module calls.

## Integration Order

Modules must be integrated in dependency order:

1. **Network Security Groups** (no dependencies)
2. **Networking Core** (depends on NSGs)
3. **Private DNS Zones** (depends on Networking Core)
4. **Observability** (no dependencies)
5. **Data Services** (no dependencies)
6. **Container Platform** (depends on Networking Core, Observability)
7. **Private Endpoints** (depends on DNS Zones, Data Services, Container Platform, Networking Core)
8. **Gateway & Security** (depends on Networking Core)
9. **Compute** (depends on Networking Core)

## Module Call Template

Each module follows this pattern in main.bicep:

```bicep
module <moduleName> './modules/<module-file>.bicep' = {
  name: 'deploy-<module-name>-${varUniqueSuffix}'
  params: {
    // Common parameters
    baseName: baseName
    location: location
    enableTelemetry: enableTelemetry
    tags: tags
    deployToggles: deployToggles
    resourceIds: resourceIds
    
    // Module-specific parameters
    <specificParam>: <specificValue>
  }
}
```

## Variables to Keep in main.bicep

Keep these at the top of main.bicep:
- `varUniqueSuffix` - for unique deployment names
- `varDeployPdnsAndPe` - controls private DNS and endpoints
- `varUseExistingPdz` - flags for existing DNS zones
- All `varHas*` flags (varHasAppConfig, varHasApim, etc.)

## Section-by-Section Replacement

### 1. Replace NSG Section (Lines ~270-620)

**REMOVE:**
```bicep
// 2 SECURITY - NETWORK SECURITY GROUPS
module agentNsgWrapper 'wrappers/avm.res.network.network-security-group.bicep' = if (varDeployAgentNsg) { ... }
module peNsgWrapper ... { ... }
// ... all 8 NSG modules
var agentNsgResourceId = ...
var peNsgResourceId = ...
// ... all NSG resource ID assignments
```

**REPLACE WITH:**
```bicep
// 2 SECURITY - NETWORK SECURITY GROUPS
module nsgs './modules/network-security.bicep' = {
  name: 'deploy-nsgs-${varUniqueSuffix}'
  params: {
    baseName: baseName
    location: location
    enableTelemetry: enableTelemetry
    deployToggles: deployToggles
    resourceIds: resourceIds
    nsgDefinitions: nsgDefinitions
  }
}

// Use NSG outputs
var agentNsgResourceId = nsgs.outputs.agentNsgResourceId
var peNsgResourceId = nsgs.outputs.peNsgResourceId
var applicationGatewayNsgResourceId = nsgs.outputs.applicationGatewayNsgResourceId
var apiManagementNsgResourceId = nsgs.outputs.apiManagementNsgResourceId
var acaEnvironmentNsgResourceId = nsgs.outputs.acaEnvironmentNsgResourceId
var jumpboxNsgResourceId = nsgs.outputs.jumpboxNsgResourceId
var devopsBuildAgentsNsgResourceId = nsgs.outputs.devopsBuildAgentsNsgResourceId
var bastionNsgResourceId = nsgs.outputs.bastionNsgResourceId
```

### 2. Replace Networking Core Section (Lines ~750-1400)

**REMOVE:**
- VNet deployment module
- Public IP modules (App Gateway, Firewall)
- VNet peering modules
- All subnet ID variables

**REPLACE WITH:**
```bicep
// 3 NETWORKING CORE
module networkingCore './modules/networking-core.bicep' = {
  name: 'deploy-networking-${varUniqueSuffix}'
  params: {
    baseName: baseName
    location: location
    enableTelemetry: enableTelemetry
    deployToggles: deployToggles
    resourceIds: resourceIds
    vNetDefinition: vNetDefinition
    appGatewayPublicIp: appGatewayPublicIp
    firewallPublicIp: firewallPublicIp
    hubVnetPeeringDefinition: hubVnetPeeringDefinition
    agentNsgResourceId: agentNsgResourceId
    peNsgResourceId: peNsgResourceId
    applicationGatewayNsgResourceId: applicationGatewayNsgResourceId
    apiManagementNsgResourceId: apiManagementNsgResourceId
    acaEnvironmentNsgResourceId: acaEnvironmentNsgResourceId
    jumpboxNsgResourceId: jumpboxNsgResourceId
    devopsBuildAgentsNsgResourceId: devopsBuildAgentsNsgResourceId
    bastionNsgResourceId: bastionNsgResourceId
  }
  dependsOn: [nsgs]
}

// Use Networking outputs
var virtualNetworkResourceId = networkingCore.outputs.virtualNetworkResourceId
var varPeSubnetId = networkingCore.outputs.peSubnetId
var varApimSubnetId = networkingCore.outputs.apimSubnetId
var varAppGatewaySubnetId = networkingCore.outputs.appGatewaySubnetId
var varJumpboxSubnetId = networkingCore.outputs.jumpboxSubnetId
var varDevOpsBuildAgentsSubnetId = networkingCore.outputs.devOpsBuildAgentsSubnetId
var varAzureFirewallSubnetId = networkingCore.outputs.azureFirewallSubnetId
var appGatewayPublicIpResourceId = networkingCore.outputs.appGatewayPublicIpResourceId
var firewallPublicIpResourceId = networkingCore.outputs.firewallPublicIpResourceId
```

### 3. Replace Private DNS Zones Section (Lines ~950-1290)

**REMOVE:** All 14 private DNS zone modules

**REPLACE WITH:**
```bicep
// 4 PRIVATE DNS ZONES
module privateDnsZones './modules/private-dns-zones.bicep' = if (varDeployPdnsAndPe) {
  name: 'deploy-dns-zones-${varUniqueSuffix}'
  params: {
    location: location
    enableTelemetry: enableTelemetry
    privateDnsZonesDefinition: privateDnsZonesDefinition
    varDeployPdnsAndPe: varDeployPdnsAndPe
    varUseExistingPdz: varUseExistingPdz
    varVnetResourceId: virtualNetworkResourceId
    varVnetName: 'vnet-${baseName}'
    apimPrivateDnsZoneDefinition: apimPrivateDnsZoneDefinition
    cognitiveServicesPrivateDnsZoneDefinition: cognitiveServicesPrivateDnsZoneDefinition
    openAiPrivateDnsZoneDefinition: openAiPrivateDnsZoneDefinition
    aiServicesPrivateDnsZoneDefinition: aiServicesPrivateDnsZoneDefinition
    searchPrivateDnsZoneDefinition: searchPrivateDnsZoneDefinition
    cosmosPrivateDnsZoneDefinition: cosmosPrivateDnsZoneDefinition
    blobPrivateDnsZoneDefinition: blobPrivateDnsZoneDefinition
    keyVaultPrivateDnsZoneDefinition: keyVaultPrivateDnsZoneDefinition
    appConfigPrivateDnsZoneDefinition: appConfigPrivateDnsZoneDefinition
    containerAppsPrivateDnsZoneDefinition: containerAppsPrivateDnsZoneDefinition
    acrPrivateDnsZoneDefinition: acrPrivateDnsZoneDefinition
    appInsightsPrivateDnsZoneDefinition: appInsightsPrivateDnsZoneDefinition
  }
  dependsOn: [networkingCore]
}

// Use DNS Zone outputs
var apimDnsZoneId = privateDnsZones.outputs.apimDnsZoneId
var cognitiveServicesDnsZoneId = privateDnsZones.outputs.cognitiveServicesDnsZoneId
// ... etc for all 14 zones
```

### 4. Replace Observability Section (Lines ~1860-1947)

**REMOVE:** Log Analytics and App Insights modules

**REPLACE WITH:**
```bicep
// 8 OBSERVABILITY
module observability './modules/observability.bicep' = {
  name: 'deploy-observability-${varUniqueSuffix}'
  params: {
    baseName: baseName
    location: location
    enableTelemetry: enableTelemetry
    tags: tags
    deployToggles: deployToggles
    resourceIds: resourceIds
    logAnalyticsDefinition: logAnalyticsDefinition
    appInsightsDefinition: appInsightsDefinition
  }
}

var varLogAnalyticsWorkspaceResourceId = observability.outputs.logAnalyticsWorkspaceResourceId
var varAppiResourceId = observability.outputs.appInsightsResourceId
```

### 5. Replace Data Services Section (Lines ~2097-2245)

**REMOVE:** Storage, App Config, Cosmos, Key Vault, Search modules

**REPLACE WITH:**
```bicep
// 10-14 DATA SERVICES
module dataServices './modules/data-services.bicep' = {
  name: 'deploy-data-services-${varUniqueSuffix}'
  params: {
    baseName: baseName
    location: location
    enableTelemetry: enableTelemetry
    tags: tags
    deployToggles: deployToggles
    resourceIds: resourceIds
    storageAccountDefinition: storageAccountDefinition
    cosmosDbDefinition: cosmosDbDefinition
    keyVaultDefinition: keyVaultDefinition
    aiSearchDefinition: aiSearchDefinition
    appConfigurationDefinition: appConfigurationDefinition
  }
}

var varSaResourceId = dataServices.outputs.storageAccountResourceId
var cosmosDbResourceId = dataServices.outputs.cosmosDbResourceId
var keyVaultResourceId = dataServices.outputs.keyVaultResourceId
var aiSearchResourceId = dataServices.outputs.aiSearchResourceId
var appConfigResourceId = dataServices.outputs.appConfigResourceId
```

### 6. Replace Container Platform Section (Lines ~1948-2096)

**REMOVE:** Container Env, ACR, Container Apps modules

**REPLACE WITH:**
```bicep
// 9 CONTAINER PLATFORM
module containerPlatform './modules/container-platform.bicep' = {
  name: 'deploy-container-platform-${varUniqueSuffix}'
  params: {
    baseName: baseName
    location: location
    enableTelemetry: enableTelemetry
    tags: tags
    deployToggles: deployToggles
    resourceIds: resourceIds
    containerAppEnvDefinition: containerAppEnvDefinition
    containerRegistryDefinition: containerRegistryDefinition
    containerAppsList: containerAppsList
    virtualNetworkResourceId: virtualNetworkResourceId
    appInsightsConnectionString: observability.outputs.appInsightsResourceId
    varUniqueSuffix: varUniqueSuffix
  }
  dependsOn: [networkingCore, observability]
}

var varContainerEnvResourceId = containerPlatform.outputs.containerEnvResourceId
var varAcrResourceId = containerPlatform.outputs.containerRegistryResourceId
```

### 7. Replace Private Endpoints Section (Lines ~1477-1850)

**REMOVE:** All 8 private endpoint modules

**REPLACE WITH:**
```bicep
// 7 PRIVATE ENDPOINTS
module privateEndpoints './modules/private-endpoints.bicep' = if (varDeployPdnsAndPe) {
  name: 'deploy-private-endpoints-${varUniqueSuffix}'
  params: {
    baseName: baseName
    location: location
    enableTelemetry: enableTelemetry
    tags: tags
    varPeSubnetId: varPeSubnetId
    varDeployPdnsAndPe: varDeployPdnsAndPe
    varUniqueSuffix: varUniqueSuffix
    varHasAppConfig: varHasAppConfig
    varHasApim: varHasApim
    varHasContainerEnv: varHasContainerEnv
    varHasAcr: varHasAcr
    varHasStorage: varHasStorage
    varHasCosmos: varHasCosmos
    varHasSearch: varHasSearch
    varHasKv: varHasKv
    appConfigResourceId: appConfigResourceId
    apimResourceId: varApimServiceResourceId
    containerEnvResourceId: varContainerEnvResourceId
    acrResourceId: varAcrResourceId
    storageAccountResourceId: varSaResourceId
    cosmosDbResourceId: cosmosDbResourceId
    aiSearchResourceId: aiSearchResourceId
    keyVaultResourceId: keyVaultResourceId
    apimDefinition: apimDefinition
    appConfigDnsZoneId: privateDnsZones.outputs.appConfigDnsZoneId
    apimDnsZoneId: privateDnsZones.outputs.apimDnsZoneId
    containerAppsDnsZoneId: privateDnsZones.outputs.containerAppsDnsZoneId
    acrDnsZoneId: privateDnsZones.outputs.acrDnsZoneId
    blobDnsZoneId: privateDnsZones.outputs.blobDnsZoneId
    cosmosSqlDnsZoneId: privateDnsZones.outputs.cosmosSqlDnsZoneId
    searchDnsZoneId: privateDnsZones.outputs.searchDnsZoneId
    keyVaultDnsZoneId: privateDnsZones.outputs.keyVaultDnsZoneId
    appConfigPrivateEndpointDefinition: appConfigPrivateEndpointDefinition
    apimPrivateEndpointDefinition: apimPrivateEndpointDefinition
    containerAppEnvPrivateEndpointDefinition: containerAppEnvPrivateEndpointDefinition
    acrPrivateEndpointDefinition: acrPrivateEndpointDefinition
    storageBlobPrivateEndpointDefinition: storageBlobPrivateEndpointDefinition
    cosmosPrivateEndpointDefinition: cosmosPrivateEndpointDefinition
    searchPrivateEndpointDefinition: searchPrivateEndpointDefinition
    keyVaultPrivateEndpointDefinition: keyVaultPrivateEndpointDefinition
  }
  dependsOn: [privateDnsZones, dataServices, containerPlatform, networkingCore]
}
```

### 8. Replace Gateway & Security Section (Lines ~2550-2855)

**REMOVE:** WAF, App Gateway, Firewall Policy, Firewall modules

**REPLACE WITH:**
```bicep
// 18 GATEWAY & SECURITY
module gatewaySecurity './modules/gateway-security.bicep' = {
  name: 'deploy-gateway-security-${varUniqueSuffix}'
  params: {
    baseName: baseName
    location: location
    enableTelemetry: enableTelemetry
    tags: tags
    deployToggles: deployToggles
    resourceIds: resourceIds
    appGatewayDefinition: appGatewayDefinition
    firewallPolicyDefinition: firewallPolicyDefinition
    firewallDefinition: firewallDefinition
    virtualNetworkResourceId: virtualNetworkResourceId
    appGatewaySubnetId: varAppGatewaySubnetId
    appGatewayPublicIpResourceId: appGatewayPublicIpResourceId
    firewallPublicIpResourceId: firewallPublicIpResourceId
    varDeployApGatewayPip: deployToggles.applicationGatewayPublicIp
  }
  dependsOn: [networkingCore]
}

var varAppGatewayResourceId = gatewaySecurity.outputs.applicationGatewayResourceId
var varFirewallResourceId = gatewaySecurity.outputs.firewallResourceId
var firewallPolicyResourceId = gatewaySecurity.outputs.firewallPolicyResourceId
```

### 9. Replace Compute Section (Lines ~2855-3050)

**REMOVE:** Build VM and Jump VM modules with maintenance configs

**REPLACE WITH:**
```bicep
// 19 COMPUTE
module compute './modules/compute.bicep' = {
  name: 'deploy-compute-${varUniqueSuffix}'
  params: {
    baseName: baseName
    location: location
    enableTelemetry: enableTelemetry
    tags: tags
    deployToggles: deployToggles
    buildVmDefinition: buildVmDefinition
    buildVmMaintenanceDefinition: buildVmMaintenanceDefinition
    jumpVmDefinition: jumpVmDefinition
    jumpVmMaintenanceDefinition: jumpVmMaintenanceDefinition
    buildVmAdminPassword: buildVmAdminPassword
    jumpVmAdminPassword: jumpVmAdminPassword
    buildSubnetId: '${virtualNetworkResourceId}/subnets/agent-subnet'
    jumpSubnetId: '${virtualNetworkResourceId}/subnets/jumpbox-subnet'
    varUniqueSuffix: varUniqueSuffix
  }
  dependsOn: [networkingCore]
}
```

## Testing Strategy

After integration:

1. **Syntax Check**: `az bicep build --file bicep/infra/main.bicep`
2. **Validate Parameters**: Ensure all parameter definitions are still present
3. **Check Dependencies**: Verify module dependency chains
4. **What-If Deployment**: Run Azure What-If to see changes
5. **Test Deployment**: Deploy to a test environment

## Expected Results

- **main.bicep**: Reduced from 3,191 lines to ~800-1,000 lines
- **Compilation**: Should compile without errors
- **Template Size**: ARM JSON should be under 4MB
- **Deployment**: Should work identically to before
