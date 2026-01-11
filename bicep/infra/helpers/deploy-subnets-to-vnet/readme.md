# Existing VNet Subnets Component

This component allows you to deploy subnets to an existing Virtual Network instead of creating a new VNet.

## Use Cases

This is particularly useful in enterprise scenarios where:
- Network teams manage VNets centrally
- Application teams need to deploy their own subnets
- You want to add AI/ML landing zone subnets to an existing network infrastructure
- Compliance requirements mandate using pre-existing network resources

## Usage

### Scenario 1: Deploy New VNet with Subnets (Default)

```bicep
param deploy = {
  virtualNetwork: true
  // ... other deploy toggles
}

param vNetDefinition = {
  name: 'my-vnet'
  addressPrefixes: ['192.168.0.0/23']
  // VNet will be created with all AI/ML landing zone subnets
}
```

### Scenario 2: Add Default Subnets to Existing VNet

```bicep
param resourceIds = {
  // Full resource ID of the existing VNet (single source of truth)
  virtualNetworkResourceId: '/subscriptions/.../resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/corp-hub-vnet-001'
}

param deploy = {
  virtualNetwork: false  // Don't create new VNet
  // ... NSG deploy toggles can still be true to create NSGs
  agentNsg: true
  peNsg: true
  // ... other NSG toggles
}

param existingVNetSubnetsDefinition = {
  useDefaultSubnets: true  // Use default AI Landing Zone subnets with 192.168.x.x addressing
  // subnets: []  // Empty or omitted = use defaults
}
```

### Scenario 3: Add Custom Subnets to Existing VNet

```bicep
param resourceIds = {
  // Full resource ID of the existing VNet (single source of truth)
  virtualNetworkResourceId: '/subscriptions/.../resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/corp-production-vnet'
}

param deploy = {
  virtualNetwork: false  // Don't create new VNet
  // ... NSG deploy toggles can still be true to create NSGs  
  agentNsg: true
  peNsg: true
  applicationGatewayNsg: true
  // ... other NSG toggles
}

param existingVNetSubnetsDefinition = {
  useDefaultSubnets: false  // Use custom subnet definitions
  subnets: [
    {
      name: 'agent-subnet'  // Standard name = auto NSG assignment
      addressPrefix: '10.100.10.0/24'  // Custom addressing to fit existing VNet
      delegation: 'Microsoft.App/environments'
      serviceEndpoints: ['Microsoft.CognitiveServices']
      // NSG will be automatically assigned because name matches 'agent-subnet'
    }
    {
      name: 'pe-subnet'  // Standard name = auto NSG assignment
      addressPrefix: '10.100.11.0/24'
      serviceEndpoints: ['Microsoft.AzureCosmosDB']
      privateEndpointNetworkPolicies: 'Disabled'
      // NSG auto-assigned for 'pe-subnet'  
    }
    {
      name: 'appgw-subnet'  // Standard name = auto NSG assignment
      addressPrefix: '10.100.12.0/24'
      // NSG auto-assigned for 'appgw-subnet'
    }
    {
      name: 'custom-workload-subnet'  // Custom name = manual NSG
      addressPrefix: '10.100.20.0/24'
      networkSecurityGroupResourceId: '/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/networkSecurityGroups/nsg-custom'
      // Manual NSG assignment for non-standard subnet names
    }
    // Add only the subnets you need...
  ]
}
```

### Real-World Example: Enterprise Hub-Spoke

```bicep
// Example: Adding AI Landing Zone to existing hub-spoke with 10.x.x.x addressing
param resourceIds = {
  // Full resource ID of the existing spoke VNet (single source of truth)
  virtualNetworkResourceId: '/subscriptions/.../resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/spoke-workloads-vnet-001'
}

param existingVNetSubnetsDefinition = {
  useDefaultSubnets: false
  subnets: [
    {
      name: 'agent-subnet' 
      addressPrefix: '10.20.100.0/24'  // Fits in existing spoke address space
      delegation: 'Microsoft.App/environments'
      serviceEndpoints: ['Microsoft.CognitiveServices']
    }
    {
      name: 'pe-subnet'
      addressPrefix: '10.20.101.0/24'
      serviceEndpoints: ['Microsoft.AzureCosmosDB', 'Microsoft.KeyVault', 'Microsoft.Storage']
      privateEndpointNetworkPolicies: 'Disabled'
    }
    {
      name: 'aca-env-subnet'  
      addressPrefix: '10.20.102.0/24'
      delegation: 'Microsoft.App/environments'
      serviceEndpoints: ['Microsoft.AzureCosmosDB']
    }
    // Only deploy the subnets needed for your AI workload
  ]
}
```

## Features

- **Flexible Subnet Configuration**: Three ways to deploy subnets:
  1. **Default AI/ML Subnets**: Use `useDefaultSubnets: true` (or omit) for automatic 192.168.x.x subnets
  2. **Custom Subnets**: Specify your own subnet definitions with custom addressing  
  3. **Custom Subnets with Auto-NSG**: Custom subnets get NSGs automatically assigned based on naming
- **NSG Integration**: Automatically associates NSGs (if deployed) with the appropriate subnets  
- **Service Endpoints**: Configures required service endpoints for each subnet type
- **Delegations**: Sets up proper delegations for Container Apps environments  
- **Flexible Addressing**: Supports any address scheme to fit existing VNet infrastructure

## NSG Auto-Assignment

When using custom subnets, NSGs are automatically assigned based on subnet names:

| Subnet Name Pattern | NSG Assignment |
|-------------------|----------------|
| `agent-subnet` | Agent NSG (if created) |
| `pe-subnet` | Private Endpoints NSG (if created) |
| `appgw-subnet` | Application Gateway NSG (if created) |
| `apim-subnet` | API Management NSG (if created) |  
| `jumpbox-subnet` | Jumpbox NSG (if created) |
| `aca-env-subnet` | ACA Environment NSG (if created) |
| `devops-agents-subnet` | DevOps Build Agents NSG (if created) |

> **Tip**: Use standard subnet names to get automatic NSG assignment, or specify `networkSecurityGroupResourceId` manually in your subnet definition.

## Subnet Layout

The component deploys the following subnets to your existing VNet:

| Subnet Name | Address Prefix | Purpose | Special Configuration |
|-------------|----------------|---------|----------------------|
| agent-subnet | 192.168.0.0/25 | AI/ML workloads | Microsoft.App/environments delegation, CognitiveServices endpoint |
| pe-subnet | 192.168.1.64/27 | Private endpoints | Private endpoint policies disabled, AzureCosmosDB endpoint |
| appgw-subnet | 192.168.0.128/26 | Application Gateway | - |
| AzureBastionSubnet | 192.168.0.192/26 | Azure Bastion | - |
| AzureFirewallSubnet | 192.168.1.0/26 | Azure Firewall | - |
| apim-subnet | 192.168.1.160/27 | API Management | - |
| jumpbox-subnet | 192.168.1.96/28 | Jump box VMs | - |
| aca-env-subnet | 192.168.1.112/28 | Container Apps environment | Microsoft.App/environments delegation, AzureCosmosDB endpoint |
| devops-agents-subnet | 192.168.1.128/28 | DevOps build agents | - |

## Prerequisites

- The module deployment must run at the VNet's resource group scope (and the deploying identity must have permissions in that RG)
- The VNet must have sufficient address space to accommodate the subnets (requires at least a /23 or 512 IP addresses)
- Ensure the subnet address ranges don't conflict with existing subnets in the VNet

## Outputs

- `virtualNetworkResourceId`: Resource ID of the existing VNet
- `subnetResourceIds`: Array of resource IDs for all deployed subnets  
- `subnetNames`: Array of names for all deployed subnets