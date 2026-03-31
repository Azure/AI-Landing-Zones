targetScope = 'resourceGroup'

import { logAnalyticsDefinitionType } from '../common/types.bicep'

@description('Log Analytics Workspace configuration.')
param logAnalytics logAnalyticsDefinitionType

module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.12.0' = {
  name: 'law-avm-${logAnalytics.name!}'
  params: {
    name: logAnalytics.name!
    location: logAnalytics.?location
    tags: logAnalytics.?tags
    enableTelemetry: logAnalytics.?enableTelemetry
    dataRetention: logAnalytics.?dataRetention
    linkedStorageAccounts: logAnalytics.?linkedStorageAccounts
    dataExports: logAnalytics.?dataExports
    tables: logAnalytics.?tables
    roleAssignments: logAnalytics.?roleAssignments
    dailyQuotaGb: logAnalytics.?dailyQuotaGb
    dataSources: logAnalytics.?dataSources
    diagnosticSettings: logAnalytics.?diagnosticSettings
    gallerySolutions: logAnalytics.?gallerySolutions
    lock: logAnalytics.?lock
    publicNetworkAccessForIngestion: logAnalytics.?publicNetworkAccessForIngestion
    publicNetworkAccessForQuery: logAnalytics.?publicNetworkAccessForQuery
    savedSearches: logAnalytics.?savedSearches
    storageInsightsConfigs: logAnalytics.?storageInsightsConfigs
    skuName: logAnalytics.?skuName
    skuCapacityReservationLevel: logAnalytics.?skuCapacityReservationLevel
    forceCmkForQuery: logAnalytics.?forceCmkForQuery
    features: logAnalytics.?features
    managedIdentities: logAnalytics.?managedIdentities
    linkedServices: logAnalytics.?linkedServices
  }
}

@description('The resource ID of the Log Analytics workspace.')
output resourceId string = logAnalyticsWorkspace.outputs.resourceId

@description('The name of the Log Analytics workspace.')
output name string = logAnalyticsWorkspace.outputs.name

@description('The resource group the Log Analytics workspace was deployed into.')
output resourceGroupName string = logAnalyticsWorkspace.outputs.resourceGroupName

@description('The location the Log Analytics workspace was deployed into.')
output location string = logAnalyticsWorkspace.outputs.location
