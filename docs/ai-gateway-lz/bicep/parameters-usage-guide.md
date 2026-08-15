# Using Bicep Parameter Files for Deployment

This guide explains how to use Bicep parameter files (.bicepparam) for deploying the AI Hub Gateway Solution Accelerator.

## Overview

Bicep parameter files (.bicepparam) provide a strongly-typed, native way to define deployment configurations separately from your Bicep templates, offering:
- Type safety and IntelliSense support in VS Code
- Better validation and error checking at design time
- Cleaner syntax with support for expressions and functions
- Environment variable support with `readEnvironmentVariable()`
- Direct integration with Azure CLI and Azure Developer CLI
- Manage different environment configurations (dev, test, prod)
- Version control your deployment settings

## Available Parameter Files

The solution provides native Bicep parameter files:

### 1. `main.bicepparam` (Minimal - for Azure Developer CLI)
This file contains only essential parameters and reads values from environment variables for Azure Developer CLI (`azd`):

```bicep
using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'citadel-dev')
param location = readEnvironmentVariable('AZURE_LOCATION', 'eastus')
param entraAuth = bool(readEnvironmentVariable('AZURE_ENTRA_AUTH', 'false'))
...
```

**Use this file when:**
- Deploying with `azd up` or `azd provision`
- Using Azure Developer CLI workflow
- Following the quick-start deployment path
- Want environment variable substitution

### 2. `main.parameters.complete.bicepparam` (Comprehensive Template)
This file contains **all** available parameters with default values and detailed comments:

**Use this file as a template when:**
- Creating custom environment configurations
- Deploying directly with Azure CLI or Bicep
- Customizing resource names, SKUs, or network configurations
- Need full control over all deployment settings

### 3. Environment-Specific Files
- `main.parameters.dev.bicepparam` - Development environment optimized for cost
- `main.parameters.prod.bicepparam` - Production environment with HA configuration

### 4. `resources.parameters.<env>.bicepparam` (Exception - existing resource group)

Create this file only when subscription-scoped deployment is not possible and the hub resource group already exists. Copy the values from the matching `main.parameters.<env>.bicepparam` file, omit `resourceGroupName`, and point the file at `resources.bicep`. 

**Use this file as a template when:**
- Deploying directly with Azure CLI or Bicep
- Targeting an existing resource group
- Avoiding subscription-scope resource group creation
  
## Deployment Methods

### Method 1: Using Azure Developer CLI (azd) - Recommended for Quick Start

The Azure Developer CLI uses `main.bicepparam` automatically and reads values from your `.azure/<env-name>/.env` file.

**Steps:**

1. **Initialize your environment:**
   ```powershell
   azd init
   ```

2. **Configure environment variables:**
   Edit `.azure/<your-env-name>/.env` to set your values:
   ```bash
   AZURE_ENV_NAME="citadel-dev"
   AZURE_LOCATION="eastus"
   AZURE_SUBSCRIPTION_ID="your-subscription-id"
   AZURE_ENTRA_AUTH="false"
   ```

3. **Deploy:**
   ```powershell
   # Provision and deploy all services
   azd up
   ```
   
   or
   ```powershell
   # Only provision infrastructure
   azd provision
   ```

### Method 2: Using Azure CLI with Bicep Parameters File

For more control, use Bicep parameter files (.bicepparam) directly with Azure CLI.

**Steps:**

1. **Use an existing environment file or copy the complete template:**
   ```powershell
   # Use existing dev or prod configuration
   # OR copy the complete template
   Copy-Item bicep/infra/main.parameters.complete.bicepparam bicep/infra/main.parameters.myenv.bicepparam
   ```

2. **Edit your .bicepparam file** to match your requirements:
   - Set `environmentName` parameter (e.g., 'citadel-dev')
   - Set `location` parameter (e.g., 'eastus')
   - Customize resource names, SKUs, networking, etc.
   - Use native Bicep syntax, no JSON quotes needed

3. **Deploy using Azure CLI:**
   ```powershell
   # Create the deployment
   az deployment sub create `
     --name "citadel-deployment" `
     --location "eastus" `
     --template-file "bicep/infra/main.bicep" `
     --parameters "bicep/infra/main.parameters.dev.bicepparam"
   ```
   
   Note: Use the file path directly (no @ prefix needed for .bicepparam files)

### Method 3: Using Azure CLI with Bicep Parameters File and Existing Resource Group

Create `resources.parameters.<env>.bicepparam` only when subscription-scoped deployment is not possible and the target resource group already exists. This deploys the same hub resources as the subscription wrapper, but skips resource group creation and uses an Azure CLI resource-group deployment.

**Steps:**

1. **Confirm the target resource group exists** in the target subscription.

2. **Create a resource-scope parameter file** such as `bicep/infra/resources.parameters.dev.bicepparam`. Copy the values from `main.parameters.dev.bicepparam`, remove `resourceGroupName`, and start the file with `using './resources.bicep'`.

3. **Preview and deploy using Azure CLI:**

   ```powershell
   az deployment group what-if `
     --resource-group "<existing-hub-resource-group>" `
     --template-file "bicep/infra/resources.bicep" `
     --parameters "bicep/infra/resources.parameters.dev.bicepparam"

   az deployment group create `
     --resource-group "<existing-hub-resource-group>" `
     --template-file "bicep/infra/resources.bicep" `
     --parameters "bicep/infra/resources.parameters.dev.bicepparam"
   ```

## Parameter File Structure

### Understanding the Complete Parameters File

The `main.parameters.complete.bicepparam` file is organized into sections:

#### 1. **Basic Parameters**
```bicep
param environmentName = 'citadel-dev'
param location = 'eastus'
param tags = {
  environment: 'dev'
  solution: 'ai-hub-gateway'
}
```

#### 2. **Resource Names**
Leave empty ('') for auto-generated names or specify custom names:
```bicep
param apimServiceName = ''  // Auto-generated
param apimServiceName = 'my-apim-service'  // Custom
```

#### 3. **Networking Parameters**
Configure VNet, subnets, and network security:
```bicep
param vnetAddressPrefix = '10.170.0.0/24'
param useExistingVnet = false
param apimNetworkType = 'External'
// AI Foundry network injection (enabled by default). When true, an additional
// agent subnet delegated to Microsoft.App/environments is provisioned (greenfield)
// or required (brownfield via agentSubnetName).
param foundryNetworkInjectionEnabled = true
param agentSubnetPrefix = '10.170.0.192/26'
```

#### 4. **Feature Flags**
Enable or disable specific capabilities:
```bicep
param enableAPICenter = true
param enableAIGatewayPiiRedaction = true
```

#### 5. **Compute SKU & Size**
Define service tiers and capacity:
```bicep
param apimSku = 'StandardV2'
param apimSkuUnits = 1
param cosmosDbRUs = 400
```

#### 6. **AI Foundry Configuration**
Configure AI Foundry instances and model deployments. The first entry in `aiFoundryInstances` is the **primary** Foundry — its endpoint also powers APIM content safety and PII processing policies. Additional entries are optional and provide extra regional Foundry resources for LLM model deployments:
```bicep
param aiFoundryInstances = [...]
param aiFoundryModelsConfig = [...]
```

## Creating Environment-Specific Parameters

### Development Environment

**File:** `main.parameters.dev.bicepparam`

```bicep
using './main.bicep'

param environmentName = 'citadel-dev'
param location = 'eastus'
param apimSku = 'Developer'
param apimSkuUnits = 1
param cosmosDbRUs = 400
param createAppInsightsDashboards = true
param enableAPICenter = false
```

### Production Environment

**File:** `main.parameters.prod.bicepparam`

```bicep
using './main.bicep'

param environmentName = 'citadel-prod'
param location = 'eastus'
param apimSku = 'PremiumV2'
param apimSkuUnits = 2
param cosmosDbRUs = 1000
param eventHubCapacityUnits = 2
param createAppInsightsDashboards = true
param enableAPICenter = true
param entraAuth = true
param entraTenantId = 'your-tenant-id'
param entraClientId = 'your-client-id'
param entraAudience = 'your-audience'
```

## Common Customization Scenarios

### Scenario 1: Bring Your Own Network

```bicep
using './main.bicep'

param useExistingVnet = true
param existingVnetRG = 'network-rg'
param vnetName = 'my-existing-vnet'
param apimSubnetName = 'snet-apim'
param privateEndpointSubnetName = 'snet-pe'
param functionAppSubnetName = 'snet-func'
// Required when foundryNetworkInjectionEnabled = true (default).
// Subnet must already be delegated to Microsoft.App/environments.
param agentSubnetName = 'snet-agents'
param foundryNetworkInjectionEnabled = true
param dnsZoneRG = 'dns-rg'
param dnsSubscriptionId = 'your-subscription-id'
```

### Scenario 2: Custom Resource Names

```bicep
using './main.bicep'

param apimServiceName = 'mycompany-apim-prod'
param cosmosDbAccountName = 'mycompany-cosmos-prod'
param eventHubNamespaceName = 'mycompany-evhns-prod'
param logAnalyticsName = 'mycompany-law-prod'
```

### Scenario 3: AI Foundry with Custom Models

```bicep
using './main.bicep'

param aiFoundryInstances = [
  {
    name: 'my-foundry-eastus'
    location: 'eastus'
    customSubDomainName: ''
    defaultProjectName: 'production-project'
  }
]
param aiFoundryModelsConfig = [
  {
    name: 'gpt-4o'
    publisher: 'OpenAI'
    version: '2024-11-20'
    sku: 'GlobalStandard'
    capacity: 100
    aiserviceIndex: 0
  }
]
```

### Scenario 4: Enable Microsoft Entra ID Authentication

**Auto-provisioning (recommended):** Run the standalone Entra ID setup script after the first `azd up`, then re-deploy.

```bicep
using './main.bicep'

param entraAuth = true
// Values populated by: bicep/infra/entra-id-setup/setup.ps1
param entraTenantId = ''
param entraClientId = ''
param entraAudience = ''
```

**Bring your own app registration:**

```bicep
using './main.bicep'

param entraAuth = true
param entraTenantId = 'your-tenant-id'
param entraClientId = 'your-client-id'
param entraAudience = 'api://your-api-id'
```

When `entraAuth=true`:
- APIM named values `JWT-TenantId`, `JWT-AppRegistrationId`, `JWT-Issuer`, `JWT-OpenIdConfigUrl` are configured
- The `security-handler` policy fragment is deployed to support JWT validation across all APIs
- Access contracts can enable JWT per-product via `jwtAuth.enabled: true`
- The client secret is stored in Key Vault as `ENTRA-APP-CLIENT-SECRET`
- Deploying user needs `Application.ReadWrite.All` permission for auto-provisioning

### Scenario 5: Configure AI Search Integration

```bicep
using './main.bicep'

param enableAzureAISearch = true
param aiSearchInstances = [
  {
    name: 'ai-search-prod-01'
    url: 'https://mysearch01.search.windows.net/'
    description: 'Production AI Search Instance 1'
  }
  {
    name: 'ai-search-prod-02'
    url: 'https://mysearch02.search.windows.net/'
    description: 'Production AI Search Instance 2'
  }
]
```

## Parameter Override Precedence

When using parameters, values are resolved in this order (highest to lowest priority):

1. **Command-line parameters** (e.g., `--parameters key=value`)
2. **Parameters file** (e.g., `main.parameters.dev.bicepparam`)
3. **Default values** in the Bicep template

### Example with Mixed Approach:

```powershell
az deployment sub create `
  --name "citadel-deployment" `
  --location "eastus" `
  --template-file "bicep/infra/main.bicep" `
  --parameters "bicep/infra/main.parameters.dev.bicepparam" `
  --parameters environmentName="citadel-test" apimSku="StandardV2"
```

In this example:
- Most values come from `main.parameters.dev.bicepparam`
- `environmentName` and `apimSku` are overridden via command line

## Validation and Best Practices

### 1. Validate Before Deployment

Use What-If to preview changes:

```powershell
az deployment sub what-if `
  --name "citadel-deployment" `
  --location "eastus" `
  --template-file "bicep/infra/main.bicep" `
  --parameters "bicep/infra/main.parameters.dev.bicepparam"
```

### 2. Keep Secrets Secure

**Never** store sensitive values in parameter files. Use one of these approaches:

#### Option A: Azure Key Vault Reference
```bicep
using './main.bicep'

param entraTenantId = getSecret(
  '/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{vault-name}',
  'entraTenantId'
)
```

#### Option B: Environment Variables in .bicepparam
```bicep
using './main.bicep'

param entraTenantId = readEnvironmentVariable('ENTRA_TENANT_ID', '')
param entraClientId = readEnvironmentVariable('ENTRA_CLIENT_ID', '')
```

#### Option C: Command-line Override
```powershell
az deployment sub create `
  --parameters "bicep/infra/main.parameters.prod.bicepparam" `
  --parameters entraTenantId="$env:ENTRA_TENANT_ID"
```

#### Option D: Azure Developer CLI Environment Variables
Use `.azure/<env>/.env` file (git-ignored):
```bash
AZURE_TENANT_ID="your-secret-value"
ENTRA_TENANT_ID="your-secret-value"
```

### 3. Version Control

- **DO** commit: `main.parameters.dev.bicepparam`, `main.parameters.prod.bicepparam` (with placeholders)
- **DON'T** commit: Files with actual secrets or sensitive values
- Use `.gitignore` to exclude files with real values:
  ```
  # .gitignore
  *.local.bicepparam
  *.secrets.bicepparam
  .azure/*/.env
  ```

### 4. Documentation

Document your parameter choices with comments:
```bicep
using './main.bicep'

// Using PremiumV2 for production workload with multi-region support
param apimSku = 'PremiumV2'

// High throughput required for production traffic
param cosmosDbRUs = 1000
```

## Troubleshooting

### Issue: Parameter validation errors

**Error:** `The parameter 'environmentName' expects a value of type 'String'`

**Solution:** Ensure your parameter file uses correct Bicep syntax:
```bicep
param environmentName = 'citadel-dev'  // Correct
```

### Issue: Missing 'using' statement

**Error:** `A using declaration must be present in this file`

**Solution:** Ensure your .bicepparam file starts with a `using` statement:
```bicep
using './main.bicep'

param environmentName = 'citadel-dev'
```

### Issue: Template and parameter file mismatch

**Error:** `The parameter 'someParameter' is not defined in the template`

**Solution:** Ensure you're using the correct template and parameter file versions. Remove any parameters not defined in `main.bicep`.

### Issue: Environment variables not substituting

**Error:** `readEnvironmentVariable` returns empty or default values

**Solution:** 
1. For `azd` commands: Verify your `.azure/<env>/.env` file has the required variables
2. For `az` commands: Set environment variables in your shell before deployment
3. Run `azd env refresh` to reload environment variables (for azd)

## Additional Resources

- [Bicep Parameter Files Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/parameter-files)
- [Azure Developer CLI Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Solution Architecture Guide](./architecture.md)
- [Deployment Guide](./deployment.md)
- [Troubleshooting Guide](./deployment-troubleshooting.md)

## Quick Reference

| Deployment Scenario | Command | Parameters File |
|-------------------|---------|-----------------|
| Quick start with azd | `azd up` | `main.bicepparam` (auto) |
| Development deployment | `az deployment sub create --parameters main.parameters.dev.bicepparam` | `main.parameters.dev.bicepparam` |
| Production deployment | `az deployment sub create --parameters main.parameters.prod.bicepparam` | `main.parameters.prod.bicepparam` |
| Full customization | `az deployment sub create --parameters main.parameters.complete.bicepparam` | `main.parameters.complete.bicepparam` |
| Existing resource group deployment | `az deployment group create --parameters resources.parameters.<env>.bicepparam` | User-created `resources.parameters.<env>.bicepparam` |
| Preview changes | `az deployment sub what-if --parameters <file.bicepparam>` | Any .bicepparam file |

## Next Steps

1. Review the [Deployment Guide](./deployment.md) for detailed deployment instructions
2. Customize your parameters file based on your requirements
3. Validate your configuration with `az deployment sub what-if`
4. Deploy using your preferred method
5. Monitor the deployment in Azure Portal
