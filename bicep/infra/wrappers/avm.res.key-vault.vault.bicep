// AVM Key Vault wrapper (pass-through)
targetScope = 'resourceGroup'

import { keyVaultDefinitionType } from '../common/types.bicep'

@description('Key Vault definition.')
param keyVault keyVaultDefinitionType

module inner 'br/public:avm/res/key-vault/vault:0.13.3' = {
  name: 'kv-avm-${keyVault.name}'
  params: {
    name: keyVault.name
    location: keyVault.?location
    accessPolicies: keyVault.?accessPolicies
    diagnosticSettings: keyVault.?diagnosticSettings
    enablePurgeProtection: keyVault.?enablePurgeProtection
    enableRbacAuthorization: keyVault.?enableRbacAuthorization
    enableSoftDelete: keyVault.?enableSoftDelete
    enableVaultForDeployment: keyVault.?enableVaultForDeployment
    enableVaultForDiskEncryption: keyVault.?enableVaultForDiskEncryption
    enableVaultForTemplateDeployment: keyVault.?enableVaultForTemplateDeployment
    keys: keyVault.?keys
    lock: keyVault.?lock
    networkAcls: keyVault.?networkAcls
    privateEndpoints: keyVault.?privateEndpoints
    publicNetworkAccess: keyVault.?publicNetworkAccess
    roleAssignments: keyVault.?roleAssignments
    secrets: keyVault.?secrets
    sku: keyVault.?sku
    softDeleteRetentionInDays: keyVault.?softDeleteRetentionInDays
    tags: keyVault.?tags
    enableTelemetry: keyVault.?enableTelemetry
  }
}

output resourceId string = inner.outputs.resourceId
output name string = inner.outputs.name
output location string = inner.outputs.location
output resourceGroupName string = inner.outputs.resourceGroupName
output uri string = inner.outputs.uri
