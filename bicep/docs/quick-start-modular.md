# Quick Start: Modularized AI Landing Zone

## For Developers

### Testing the Modularized Version

1. **Build & Validate**:
   ```powershell
   # Compile the modularized template
   az bicep build --file bicep/infra/main-modularized.bicep
   
   # Check for errors
   az bicep build --file bicep/infra/main-modularized.bicep --stdout | ConvertFrom-Json | Select-Object -ExpandProperty errors
   ```

2. **What-If Analysis** (Non-destructive):
   ```powershell
   az deployment group what-if `
     --resource-group <your-rg-name> `
     --template-file bicep/infra/main-modularized.bicep `
     --parameters bicep/infra/main.bicepparam
   ```

3. **Deploy to Test Environment**:
   ```powershell
   az deployment group create `
     --resource-group <test-rg-name> `
     --template-file bicep/infra/main-modularized.bicep `
     --parameters bicep/infra/main.bicepparam `
     --confirm-with-what-if
   ```

### Module Development Workflow

#### Adding a New Module

1. Create module file in `bicep/infra/modules/`:
   ```bicep
   // modules/my-new-module.bicep
   targetScope = 'resourceGroup'
   
   param baseName string
   param location string
   // ... other parameters
   
   // Resources
   resource myResource 'Microsoft.Provider/type@2024-01-01' = {
     name: 'resource-${baseName}'
     location: location
     properties: {}
   }
   
   // Outputs
   output resourceId string = myResource.id
   ```

2. Reference in `main-modularized.bicep`:
   ```bicep
   module myNewModule './modules/my-new-module.bicep' = {
     name: 'deploy-my-module-${varUniqueSuffix}'
     params: {
       baseName: baseName
       location: location
     }
   }
   
   var myResourceId = myNewModule.outputs.resourceId
   ```

#### Modifying an Existing Module

1. Open the module file: `bicep/infra/modules/<module-name>.bicep`
2. Make your changes
3. Validate: `az bicep build --file bicep/infra/modules/<module-name>.bicep`
4. Test the main template: `az bicep build --file bicep/infra/main-modularized.bicep`

### Module Reference

| Module | File | Purpose | Key Outputs |
|--------|------|---------|-------------|
| Network Security | `network-security.bicep` | NSGs for all subnets | NSG Resource IDs |
| Networking Core | `networking-core.bicep` | VNet, subnets, peering | VNet ID, Subnet IDs |
| Private DNS Zones | `private-dns-zones.bicep` | DNS zones for private endpoints | Zone Resource IDs |
| Observability | `observability.bicep` | Log Analytics, App Insights | Workspace ID, App Insights ID |
| Data Services | `data-services.bicep` | Storage, Cosmos, Key Vault, AI Search | Service Resource IDs |
| Container Platform | `container-platform.bicep` | ACR, Container Apps Environment | ACR ID, Environment ID |
| Private Endpoints | `private-endpoints.bicep` | Private endpoints for all services | PE Resource IDs |
| Gateway Security | `gateway-security.bicep` | App Gateway, Firewall, WAF | Gateway ID, Firewall ID |
| Compute | `compute.bicep` | Build VM, Jump VM | VM Resource IDs |

### Common Tasks

#### Add a New Parameter

1. Add to `main-modularized.bicep`:
   ```bicep
   @description('Optional. My new parameter.')
   param myNewParameter string = 'default-value'
   ```

2. Pass to relevant module:
   ```bicep
   module myModule './modules/my-module.bicep' = {
     params: {
       // ... existing params
       myNewParameter: myNewParameter
     }
   }
   ```

3. Use in module:
   ```bicep
   param myNewParameter string
   
   resource myResource '...' = {
     properties: {
       setting: myNewParameter
     }
   }
   ```

#### Add a New Output

1. Add to module file:
   ```bicep
   output myNewOutput string = myResource.property
   ```

2. Capture in `main-modularized.bicep`:
   ```bicep
   var myValue = myModule.outputs.myNewOutput
   ```

3. Expose at top level (optional):
   ```bicep
   @description('My new output description')
   output myNewOutput string = myValue
   ```

#### Disable a Service

Use `deployToggles` parameter:

```bicep
param deployToggles = {
  agentNsg: true
  vnet: true
  logAnalytics: true
  appInsights: true
  storageAccount: false  // Disable storage account
  cosmosDb: true
  // ... other toggles
}
```

### Troubleshooting

#### Error: "Module not found"

**Cause**: Module file path is incorrect or file doesn't exist.

**Solution**:
```powershell
# Check file exists
Test-Path bicep/infra/modules/<module-name>.bicep

# Verify path in main file
# Should be: './modules/module-name.bicep'
```

#### Error: "Parameter not provided"

**Cause**: Module requires a parameter that wasn't passed.

**Solution**:
1. Check module's required parameters
2. Add missing parameter to module call
3. Or make parameter optional in module with default value

#### Error: "Output may be null"

**Cause**: Accessing output of a conditional module without null check.

**Solution**:
```bicep
// ❌ Bad - may fail if module is not deployed
var value = conditionalModule.outputs.property

// ✅ Good - safe with null check
var value = condition ? conditionalModule!.outputs.property : ''
```

#### Error: "Circular dependency"

**Cause**: Two modules reference each other's outputs.

**Solution**:
1. Remove explicit `dependsOn` statements (Bicep auto-detects)
2. Restructure to break circular reference
3. Pass resource IDs as parameters instead of using outputs

### Best Practices

1. **Always validate before committing**:
   ```powershell
   az bicep build --file bicep/infra/main-modularized.bicep
   ```

2. **Use What-If before deploying**:
   ```powershell
   az deployment group what-if --template-file bicep/infra/main-modularized.bicep ...
   ```

3. **Keep modules focused**: One responsibility per module

4. **Document parameters**: Use `@description()` decorators

5. **Provide defaults where sensible**: Make parameters optional when possible

6. **Test incrementally**: Validate each module change individually

7. **Avoid unnecessary dependsOn**: Let Bicep resolve dependencies automatically

8. **Use consistent naming**: Follow the `var<Purpose>` and `var<Service>ResourceId` patterns

### CI/CD Integration

The GitHub Actions workflow (`.github/workflows/azure-dev.yml`) is already configured to work with the modularized structure:

```yaml
- name: Deploy Bicep
  run: |
    az deployment group create \
      --resource-group ${{ env.RESOURCE_GROUP }} \
      --template-file bicep/infra/main.bicep \  # Will use main-modularized.bicep after cut-over
      --parameters bicep/infra/main.bicepparam
```

### IDE Setup

**VS Code Extensions**:
- Bicep (Microsoft)
- Azure Resource Manager (ARM) Tools

**Settings** (`.vscode/settings.json`):
```json
{
  "bicep.lint.rules": {
    "no-unused-params": {
      "level": "warning"
    },
    "no-unused-vars": {
      "level": "warning"
    }
  }
}
```

### Resources

- **Main Template**: `bicep/infra/main-modularized.bicep`
- **Modules**: `bicep/infra/modules/*.bicep`
- **Documentation**:
  - Architecture: `bicep/docs/breaking-down-main-bicep.md`
  - Integration Guide: `bicep/docs/module-integration-guide.md`
  - Summary: `bicep/docs/modularization-summary.md`
- **Azure Bicep Docs**: https://learn.microsoft.com/azure/azure-resource-manager/bicep/

### Support

Questions? Issues?

1. Check lint errors: `az bicep build --file <file>`
2. Review documentation in `bicep/docs/`
3. Check Azure deployment logs in Portal
4. Open an issue with full error output

---

**Quick Reference Version**: 1.0  
**Last Updated**: January 2025
