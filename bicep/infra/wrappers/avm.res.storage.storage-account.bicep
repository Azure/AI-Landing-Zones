// AVM Storage Account wrapper (pass-through)
targetScope = 'resourceGroup'

import { storageAccountDefinitionType } from '../common/types.bicep'

@description('Storage Account definition.')
param storageAccount storageAccountDefinitionType

module inner 'br/public:avm/res/storage/storage-account:0.27.0' = {
  name: 'st-avm-${storageAccount.name}'
  params: {
    name: storageAccount.name
    location: storageAccount.?location
    kind: storageAccount.?kind
    skuName: storageAccount.?skuName
    accessTier: storageAccount.?accessTier
    allowBlobPublicAccess: storageAccount.?allowBlobPublicAccess
    allowCrossTenantReplication: storageAccount.?allowCrossTenantReplication
    allowedCopyScope: storageAccount.?allowedCopyScope
    allowSharedKeyAccess: storageAccount.?allowSharedKeyAccess
    azureFilesIdentityBasedAuthentication: storageAccount.?azureFilesIdentityBasedAuthentication
    blobServices: storageAccount.?blobServices
    customDomainName: storageAccount.?customDomainName
    customDomainUseSubDomainName: storageAccount.?customDomainUseSubDomainName
    customerManagedKey: storageAccount.?customerManagedKey
    defaultToOAuthAuthentication: storageAccount.?defaultToOAuthAuthentication
    diagnosticSettings: storageAccount.?diagnosticSettings
    dnsEndpointType: storageAccount.?dnsEndpointType
    enableHierarchicalNamespace: storageAccount.?enableHierarchicalNamespace
    enableNfsV3: storageAccount.?enableNfsV3
    enableSftp: storageAccount.?enableSftp
    fileServices: storageAccount.?fileServices
    isLocalUserEnabled: storageAccount.?isLocalUserEnabled
    keyType: storageAccount.?keyType
    largeFileSharesState: storageAccount.?largeFileSharesState
    localUsers: storageAccount.?localUsers
    lock: storageAccount.?lock
    managedIdentities: storageAccount.?managedIdentities
    managementPolicyRules: storageAccount.?managementPolicyRules
    minimumTlsVersion: storageAccount.?minimumTlsVersion
    networkAcls: storageAccount.?networkAcls
    privateEndpoints: storageAccount.?privateEndpoints
    publicNetworkAccess: storageAccount.?publicNetworkAccess
    queueServices: storageAccount.?queueServices
    requireInfrastructureEncryption: storageAccount.?requireInfrastructureEncryption
    roleAssignments: storageAccount.?roleAssignments
    sasExpirationAction: storageAccount.?sasExpirationAction
    sasExpirationPeriod: storageAccount.?sasExpirationPeriod
    secretsExportConfiguration: storageAccount.?secretsExportConfiguration
    supportsHttpsTrafficOnly: storageAccount.?supportsHttpsTrafficOnly
    tableServices: storageAccount.?tableServices
    tags: storageAccount.?tags
    enableTelemetry: storageAccount.?enableTelemetry
  }
}

output resourceId string = inner.outputs.resourceId
output name string = inner.outputs.name
output location string = inner.outputs.location
output resourceGroupName string = inner.outputs.resourceGroupName
output serviceEndpoints object = inner.outputs.serviceEndpoints
output systemAssignedMIPrincipalId string = inner.outputs.?systemAssignedMIPrincipalId ?? ''
