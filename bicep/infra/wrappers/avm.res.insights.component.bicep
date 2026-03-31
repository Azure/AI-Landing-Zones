targetScope = 'resourceGroup'

import { appInsightsDefinitionType } from '../common/types.bicep'

@description('Application Insights configuration.')
param appInsights appInsightsDefinitionType

module appInsightsComponent 'br/public:avm/res/insights/component:0.6.0' = {
  name: 'appi-avm-${appInsights.name!}'
  params: {
    name: appInsights.name!
    workspaceResourceId: appInsights.workspaceResourceId!
    location: appInsights.?location
    tags: appInsights.?tags
    enableTelemetry: appInsights.?enableTelemetry
    applicationType: appInsights.?applicationType
    diagnosticSettings: appInsights.?diagnosticSettings
    disableIpMasking: appInsights.?disableIpMasking
    disableLocalAuth: appInsights.?disableLocalAuth
    flowType: appInsights.?flowType
    forceCustomerStorageForProfiler: appInsights.?forceCustomerStorageForProfiler
    kind: appInsights.?kind
    linkedStorageAccountResourceId: appInsights.?linkedStorageAccountResourceId
    lock: appInsights.?lock
    publicNetworkAccessForIngestion: appInsights.?publicNetworkAccessForIngestion
    publicNetworkAccessForQuery: appInsights.?publicNetworkAccessForQuery
    requestSource: appInsights.?requestSource
    retentionInDays: appInsights.?retentionInDays
    roleAssignments: appInsights.?roleAssignments
    samplingPercentage: appInsights.?samplingPercentage
  }
}

@description('The resource ID of the Application Insights component.')
output resourceId string = appInsightsComponent.outputs.resourceId

@description('The name of the Application Insights component.')
output name string = appInsightsComponent.outputs.name

@description('The resource group the Application Insights component was deployed into.')
output resourceGroupName string = appInsightsComponent.outputs.resourceGroupName

@description('The location the Application Insights component was deployed into.')
output location string = appInsightsComponent.outputs.location

@description('The connection string of the Application Insights component.')
output connectionString string = appInsightsComponent.outputs.connectionString

@description('The instrumentation key of the Application Insights component.')
output instrumentationKey string = appInsightsComponent.outputs.instrumentationKey
