# Breaking Down main.bicep - Implementation Guide

## Problem
The `main.bicep` file is 3191 lines and 119KB, which when compiled to ARM JSON exceeds the 4MB deployment limit.

## Solution Strategy
Extract logical resource groups into separate module files under `bicep/infra/modules/`. This reduces the main file size and improves maintainability.

## Recommended Module Breakdown

### 1. **Network Security Groups Module** ✅ CREATED
- **File**: `modules/network-security.bicep`
- **Lines**: ~270-600 in main.bicep
- **Contains**: All NSG deployments (agent, PE, app gateway, APIM, ACA, jumpbox, DevOps, bastion)
- **Outputs**: NSG resource IDs

### 2. **Private DNS Zones Module**
- **File**: `modules/private-dns-zones.bicep`
- **Lines**: ~950-1290 in main.bicep
- **Contains**: All private DNS zone deployments (APIM, Cognitive Services, OpenAI, AI Services, Search, Cosmos, Blob, Key Vault, App Config, Container Apps, ACR, Insights)
- **Outputs**: DNS zone resource IDs

### 3. **Private Endpoints Module**
- **File**: `modules/private-endpoints.bicep`
- **Lines**: ~1400-1850 in main.bicep
- **Contains**: All private endpoint deployments (App Config, APIM, Container Apps, ACR, Storage, Cosmos, Search, Key Vault)
- **Outputs**: Private endpoint resource IDs

### 4. **Networking Core Module**
- **File**: `modules/networking-core.bicep`
- **Lines**: ~750-1365 in main.bicep
- **Contains**: 
  - Virtual network and subnets
  - Public IPs (App Gateway, Firewall)
  - VNet peering configurations
- **Outputs**: VNet resource ID, subnet IDs, public IP IDs

### 5. **Data Services Module**
- **File**: `modules/data-services.bicep`
- **Lines**: ~2097-2245 in main.bicep
- **Contains**:
  - Storage Account
  - Cosmos DB
  - Azure AI Search
- **Outputs**: Resource IDs for each service

### 6. **Container Platform Module**
- **File**: `modules/container-platform.bicep`
- **Lines**: ~1948-2095 in main.bicep
- **Contains**:
  - Container Apps Environment
  - Container Registry
  - Container Apps
- **Outputs**: Container resource IDs

### 7. **Gateway and Security Module**
- **File**: `modules/gateway-security.bicep`
- **Lines**: ~2615-2855 in main.bicep
- **Contains**:
  - Application Gateway
  - Azure Firewall
  - Firewall Policy
  - WAF Policy
- **Outputs**: Gateway and firewall resource IDs

### 8. **Compute Module**
- **File**: `modules/compute.bicep`
- **Lines**: ~2856-3100 in main.bicep
- **Contains**:
  - Build VM
  - Jump VM
  - Maintenance Configurations
- **Outputs**: VM resource IDs

### 9. **Observability Module**
- **File**: `modules/observability.bicep`
- **Lines**: ~1860-1947 in main.bicep
- **Contains**:
  - Log Analytics Workspace
  - Application Insights
- **Outputs**: Workspace and insights resource IDs

## Implementation Steps

### Step 1: Create the Module Files
For each module listed above:
1. Create the file in `bicep/infra/modules/`
2. Import types: `import * as types from '../common/types.bicep'`
3. Add required parameters (baseName, location, enableTelemetry, deployToggles, resourceIds, specific definitions)
4. Extract the relevant module declarations from main.bicep
5. Add outputs for all resource IDs

### Step 2: Update main.bicep
Replace the extracted sections with module calls:

```bicep
// Network Security Groups
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
// ... etc
```

### Step 3: Update Dependencies
When modules depend on outputs from other modules, pass them as parameters:

```bicep
// Private Endpoints depend on NSGs and DNS zones
module privateEndpoints './modules/private-endpoints.bicep' = {
  name: 'deploy-private-endpoints-${varUniqueSuffix}'
  params: {
    baseName: baseName
    location: location
    vnetResourceId: networkingCore.outputs.vnetResourceId
    peSubnetId: networkingCore.outputs.peSubnetId
    dnsZoneIds: privateDnsZones.outputs.dnsZoneIds
    // ... other params
  }
}
```

### Step 4: Test Incrementally
1. Create one module at a time
2. Update main.bicep to use that module
3. Test compilation: `az bicep build --file bicep/infra/main.bicep`
4. Check the generated JSON size
5. Move to the next module

### Step 5: Update Preprovision Script
The `preprovision.sh` script should automatically handle the new module structure, but verify that:
1. It processes modules in the `modules/` directory
2. Template specs are created for the new modules
3. References are replaced correctly

## Benefits

1. **Size Reduction**: Main file goes from ~3200 lines to ~800-1000 lines
2. **Maintainability**: Logical grouping makes it easier to understand and modify
3. **Reusability**: Modules can be tested and versioned independently
4. **Deployment**: Smaller main.bicep compiles faster and stays under 4MB limit
5. **Collaboration**: Team members can work on different modules without conflicts

## Example: Updated main.bicep Structure

```bicep
// Parameters and imports (~200 lines)

// Module: Network Security Groups (~20 lines)
module nsgs './modules/network-security.bicep' = { ... }

// Module: Networking Core (~30 lines)
module networkingCore './modules/networking-core.bicep' = { ... }

// Module: Private DNS Zones (~20 lines)
module privateDnsZones './modules/private-dns-zones.bicep' = { ... }

// Module: Observability (~20 lines)
module observability './modules/observability.bicep' = { ... }

// Module: Data Services (~20 lines)
module dataServices './modules/data-services.bicep' = { ... }

// Module: Container Platform (~20 lines)
module containerPlatform './modules/container-platform.bicep' = { ... }

// Module: Private Endpoints (~20 lines)
module privateEndpoints './modules/private-endpoints.bicep' = { ... }

// Module: API Management (~30 lines)
module apiManagement './modules/api-management.bicep' = { ... }

// Module: AI Foundry (~50 lines)
module aiFoundry './wrappers/avm.ptn.ai-ml.ai-foundry.bicep' = { ... }

// Module: Gateway and Security (~30 lines)
module gatewaySecurity './modules/gateway-security.bicep' = { ... }

// Module: Compute (~30 lines)
module compute './modules/compute.bicep' = { ... }

// Module: Bing Search (~20 lines)
module bingSearch './components/bing-search/main.bicep' = if (...) { ... }

// Outputs (~100 lines)
```

**Total: ~600-800 lines in main.bicep** (vs 3191 currently)

## Next Steps

1. ✅ Network Security Groups module created
2. ⏳ Create remaining modules (I can help with each one)
3. ⏳ Update main.bicep to use modules
4. ⏳ Test compilation and deployment
5. ⏳ Update documentation

Would you like me to create the next module (Private DNS Zones or Networking Core)?
