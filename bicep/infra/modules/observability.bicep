// Observability Module
// This module deploys Log Analytics Workspace and Application Insights

import * as types from '../common/types.bicep'

@description('The base name for resources.')
param baseName string

@description('The Azure region for resources.')
param location string

@description('Enable telemetry for AVM modules.')
param enableTelemetry bool

@description('Resource tags.')
param tags types.tagsType

@description('Deployment toggles for observability resources.')
param deployToggles types.deployTogglesType

@description('Resource IDs for existing observability resources to reuse.')
param resourceIds types.resourceIdsType

@description('Log Analytics Workspace configuration.')
param logAnalyticsDefinition types.logAnalyticsDefinitionType?

@description('Application Insights configuration.')
param appInsightsDefinition types.appInsightsDefinitionType?

// -----------------------
// DEPLOYMENT FLAGS
// -----------------------
var varDeployLogAnalytics = empty(resourceIds.?logAnalyticsWorkspaceResourceId!) && deployToggles.logAnalytics
var varDeployAppInsights = empty(resourceIds.?appInsightsResourceId!) && deployToggles.appInsights && varHasLogAnalytics

var varHasLogAnalytics = (!empty(resourceIds.?logAnalyticsWorkspaceResourceId!)) || (varDeployLogAnalytics)

// -----------------------
// EXISTING RESOURCES
// -----------------------

// Existing Log Analytics Workspace
resource existingLogAnalytics 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = if (!empty(resourceIds.?logAnalyticsWorkspaceResourceId!)) {
  name: varExistingLawName
  scope: resourceGroup(varExistingLawSubscriptionId, varExistingLawResourceGroupName)
}

// Existing Application Insights
resource existingAppInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(resourceIds.?appInsightsResourceId!)) {
  name: varExistingAIName
  scope: resourceGroup(varExistingAISubscriptionId, varExistingAIResourceGroupName)
}

// -----------------------
// RESOURCE NAMING
// -----------------------

// Log Analytics Workspace naming
var varLawIdSegments = empty(resourceIds.?logAnalyticsWorkspaceResourceId!)
  ? ['']
  : split(resourceIds.logAnalyticsWorkspaceResourceId!, '/')
var varExistingLawSubscriptionId = length(varLawIdSegments) >= 3 ? varLawIdSegments[2] : ''
var varExistingLawResourceGroupName = length(varLawIdSegments) >= 5 ? varLawIdSegments[4] : ''
var varExistingLawName = length(varLawIdSegments) >= 1 ? last(varLawIdSegments) : ''
var varLawName = !empty(varExistingLawName)
  ? varExistingLawName
  : (empty(logAnalyticsDefinition.?name ?? '') ? 'log-${baseName}' : logAnalyticsDefinition!.name)

// Application Insights naming
var varAiIdSegments = empty(resourceIds.?appInsightsResourceId!) ? [''] : split(resourceIds.appInsightsResourceId!, '/')
var varExistingAISubscriptionId = length(varAiIdSegments) >= 3 ? varAiIdSegments[2] : ''
var varExistingAIResourceGroupName = length(varAiIdSegments) >= 5 ? varAiIdSegments[4] : ''
var varExistingAIName = length(varAiIdSegments) >= 1 ? last(varAiIdSegments) : ''
var varAppiName = !empty(varExistingAIName) ? varExistingAIName : 'appi-${baseName}'

// -----------------------
// RESOURCE ID RESOLUTION
// -----------------------
var varLogAnalyticsWorkspaceResourceId = varDeployLogAnalytics
  ? logAnalytics!.outputs.resourceId
  : !empty(resourceIds.?logAnalyticsWorkspaceResourceId!) ? existingLogAnalytics.id : ''

var varAppiResourceId = !empty(resourceIds.?appInsightsResourceId!)
  ? existingAppInsights.id
  : (varDeployAppInsights ? appInsights!.outputs.resourceId : '')

// -----------------------
// MODULE DEPLOYMENTS
// -----------------------

// Log Analytics Workspace
module logAnalytics '../wrappers/avm.res.operational-insights.workspace.bicep' = if (varDeployLogAnalytics) {
  name: 'deployLogAnalytics'
  params: {
    logAnalytics: union(
      {
        name: varLawName
        location: location
        enableTelemetry: enableTelemetry
        tags: tags
        dataRetention: 30
      },
      logAnalyticsDefinition ?? {}
    )
  }
}

// Application Insights
module appInsights '../wrappers/avm.res.insights.component.bicep' = if (varDeployAppInsights) {
  name: 'deployAppInsights'
  params: {
    appInsights: union(
      {
        name: varAppiName
        workspaceResourceId: varLogAnalyticsWorkspaceResourceId
        location: location
        enableTelemetry: enableTelemetry
        tags: tags
        disableIpMasking: true
      },
      appInsightsDefinition ?? {}
    )
  }
}

// -----------------------
// OUTPUTS
// -----------------------

@description('Log Analytics Workspace Resource ID')
output logAnalyticsWorkspaceResourceId string = varLogAnalyticsWorkspaceResourceId

@description('Application Insights Resource ID')
output appInsightsResourceId string = varAppiResourceId

@description('Application Insights Name')
output appInsightsName string = varAppiName

@description('Log Analytics Workspace Name')
output logAnalyticsWorkspaceName string = varLawName
