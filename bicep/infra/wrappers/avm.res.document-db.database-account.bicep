// AVM Cosmos DB wrapper (pass-through)
targetScope = 'resourceGroup'

import { genAIAppCosmosDbDefinitionType } from '../common/types.bicep'

@description('Cosmos DB definition.')
param cosmosDb genAIAppCosmosDbDefinitionType

module inner 'br/public:avm/res/document-db/database-account:0.16.0' = {
  name: 'cosmos-avm-${cosmosDb.name}'
  params: {
    name: cosmosDb.name
    location: cosmosDb.?location
    automaticFailover: cosmosDb.?automaticFailover
    backupIntervalInMinutes: cosmosDb.?backupIntervalInMinutes
    backupPolicyContinuousTier: cosmosDb.?backupPolicyContinuousTier
    backupPolicyType: cosmosDb.?backupPolicyType
    backupRetentionIntervalInHours: cosmosDb.?backupRetentionIntervalInHours
    backupStorageRedundancy: cosmosDb.?backupStorageRedundancy
    capabilitiesToAdd: cosmosDb.?capabilitiesToAdd
    databaseAccountOfferType: cosmosDb.?databaseAccountOfferType
    dataPlaneRoleAssignments: cosmosDb.?dataPlaneRoleAssignments
    dataPlaneRoleDefinitions: cosmosDb.?dataPlaneRoleDefinitions
    defaultConsistencyLevel: cosmosDb.?defaultConsistencyLevel
    diagnosticSettings: cosmosDb.?diagnosticSettings
    disableKeyBasedMetadataWriteAccess: cosmosDb.?disableKeyBasedMetadataWriteAccess
    disableLocalAuthentication: cosmosDb.?disableLocalAuthentication
    enableAnalyticalStorage: cosmosDb.?enableAnalyticalStorage
    enableFreeTier: cosmosDb.?enableFreeTier
    enableMultipleWriteLocations: cosmosDb.?enableMultipleWriteLocations
    enableTelemetry: cosmosDb.?enableTelemetry
    failoverLocations: cosmosDb.?failoverLocations
    gremlinDatabases: cosmosDb.?gremlinDatabases
    lock: cosmosDb.?lock
    managedIdentities: cosmosDb.?managedIdentities
    maxIntervalInSeconds: cosmosDb.?maxIntervalInSeconds
    maxStalenessPrefix: cosmosDb.?maxStalenessPrefix
    minimumTlsVersion: cosmosDb.?minimumTlsVersion
    mongodbDatabases: cosmosDb.?mongodbDatabases
    networkRestrictions: cosmosDb.?networkRestrictions
    privateEndpoints: cosmosDb.?privateEndpoints
    roleAssignments: cosmosDb.?roleAssignments
    serverVersion: cosmosDb.?serverVersion
    sqlDatabases: cosmosDb.?sqlDatabases
    tables: cosmosDb.?tables
    tags: cosmosDb.?tags
    totalThroughputLimit: cosmosDb.?totalThroughputLimit
    zoneRedundant: cosmosDb.?zoneRedundant
  }
}

output resourceId string = inner.outputs.resourceId
output name string = inner.outputs.name
output location string = inner.outputs.location
output resourceGroupName string = inner.outputs.resourceGroupName
output systemAssignedMIPrincipalId string = inner.outputs.?systemAssignedMIPrincipalId ?? ''
