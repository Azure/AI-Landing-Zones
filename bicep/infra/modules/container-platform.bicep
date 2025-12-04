// Container Platform Module
// This module deploys Container Apps Environment, Container Registry, and Container Apps

import * as types from '../common/types.bicep'

@description('The base name for resources.')
param baseName string

@description('The Azure region for resources.')
param location string

@description('Enable telemetry for AVM modules.')
param enableTelemetry bool

@description('Resource tags.')
param tags types.tagsType

@description('Deployment toggles for container platform.')
param deployToggles types.deployTogglesType

@description('Resource IDs for existing container resources to reuse.')
param resourceIds types.resourceIdsType

@description('Container Apps Environment configuration.')
param containerAppEnvDefinition types.containerAppEnvDefinitionType?

@description('Container Registry configuration.')
param containerRegistryDefinition types.containerRegistryDefinitionType?

@description('List of Container Apps to create.')
param containerAppsList types.containerAppDefinitionType[] = []

@description('Virtual Network Resource ID for Container Apps Environment subnet.')
param virtualNetworkResourceId string

@description('Application Insights connection string.')
param appInsightsConnectionString string = ''

@description('Unique suffix for deployment names.')
param varUniqueSuffix string

// -----------------------
// DEPLOYMENT FLAGS
// -----------------------
var varDeployContainerAppEnv = empty(resourceIds.?containerEnvResourceId!) && deployToggles.containerEnv
var varDeployAcr = empty(resourceIds.?containerRegistryResourceId!) && deployToggles.containerRegistry
var varDeployContainerApps = !empty(containerAppsList) && (varDeployContainerAppEnv || !empty(resourceIds.?containerEnvResourceId!))

var varAcaInfraSubnetId = empty(resourceIds.?virtualNetworkResourceId!)
  ? '${virtualNetworkResourceId}/subnets/aca-env-subnet'
  : '${resourceIds.virtualNetworkResourceId!}/subnets/aca-env-subnet'

// -----------------------
// EXISTING RESOURCES
// -----------------------

// Existing Container Apps Environment
resource existingContainerEnv 'Microsoft.App/managedEnvironments@2025-02-02-preview' existing = if (!empty(resourceIds.?containerEnvResourceId!)) {
  name: varExistingEnvName
  scope: resourceGroup(varExistingEnvSubscriptionId, varExistingEnvResourceGroup)
}

// Existing Container Registry
resource existingAcr 'Microsoft.ContainerRegistry/registries@2025-04-01' existing = if (!empty(resourceIds.?containerRegistryResourceId!)) {
  name: varExistingAcrName
  scope: resourceGroup(varExistingAcrSub, varExistingAcrRg)
}

// -----------------------
// RESOURCE NAMING
// -----------------------

// Container Apps Environment naming
var varEnvIdSegments = empty(resourceIds.?containerEnvResourceId!)
  ? ['']
  : split(resourceIds.containerEnvResourceId!, '/')
var varExistingEnvSubscriptionId = length(varEnvIdSegments) >= 3 ? varEnvIdSegments[2] : ''
var varExistingEnvResourceGroup = length(varEnvIdSegments) >= 5 ? varEnvIdSegments[4] : ''
var varExistingEnvName = length(varEnvIdSegments) >= 1 ? last(varEnvIdSegments) : ''
var varContainerEnvName = !empty(resourceIds.?containerEnvResourceId!)
  ? varExistingEnvName
  : (empty(containerAppEnvDefinition.?name ?? '') ? 'cae-${baseName}' : containerAppEnvDefinition!.name)

// Container Registry naming
var varAcrIdSegments = empty(resourceIds.?containerRegistryResourceId!)
  ? ['']
  : split(resourceIds.containerRegistryResourceId!, '/')
var varExistingAcrSub = length(varAcrIdSegments) >= 3 ? varAcrIdSegments[2] : ''
var varExistingAcrRg = length(varAcrIdSegments) >= 5 ? varAcrIdSegments[4] : ''
var varExistingAcrName = length(varAcrIdSegments) >= 1 ? last(varAcrIdSegments) : ''
var varAcrName = !empty(resourceIds.?containerRegistryResourceId!)
  ? varExistingAcrName
  : (empty(containerRegistryDefinition.?name!) ? 'cr${baseName}' : containerRegistryDefinition!.name!)

// -----------------------
// RESOURCE ID RESOLUTION
// -----------------------
var varContainerEnvResourceId = !empty(resourceIds.?containerEnvResourceId!)
  ? existingContainerEnv.id
  : (varDeployContainerAppEnv ? containerEnv!.outputs.resourceId : '')

var varAcrResourceId = !empty(resourceIds.?containerRegistryResourceId!)
  ? existingAcr.id
  : (varDeployAcr ? containerRegistry!.outputs.resourceId : '')

// -----------------------
// MODULE DEPLOYMENTS
// -----------------------

// Container Apps Environment
module containerEnv '../wrappers/avm.res.app.managed-environment.bicep' = if (varDeployContainerAppEnv) {
  name: 'deployContainerEnv'
  params: {
    containerAppEnv: union(
      {
        name: varContainerEnvName
        location: location
        enableTelemetry: enableTelemetry
        tags: tags

        workloadProfiles: [
          {
            workloadProfileType: 'D4'
            name: 'default'
            minimumCount: 1
            maximumCount: 3
          }
        ]

        infrastructureSubnetResourceId: !empty(varAcaInfraSubnetId) ? varAcaInfraSubnetId : null
        internal: false
        publicNetworkAccess: 'Disabled'
        zoneRedundant: true

        // Application Insights integration
        appInsightsConnectionString: appInsightsConnectionString
      },
      containerAppEnvDefinition ?? {}
    )
  }
}

// Container Registry
module containerRegistry '../wrappers/avm.res.container-registry.registry.bicep' = if (varDeployAcr) {
  name: 'deployContainerRegistry'
  params: {
    acr: union(
      {
        name: varAcrName
        location: containerRegistryDefinition.?location ?? location
        enableTelemetry: containerRegistryDefinition.?enableTelemetry ?? enableTelemetry
        tags: containerRegistryDefinition.?tags ?? tags
        publicNetworkAccess: containerRegistryDefinition.?publicNetworkAccess ?? 'Disabled'
        acrSku: containerRegistryDefinition.?acrSku ?? 'Premium'
      },
      containerRegistryDefinition ?? {}
    )
  }
}

// Container Apps
@batchSize(4)
module containerApps '../wrappers/avm.res.app.container-app.bicep' = [
  for (app, index) in containerAppsList: if (varDeployContainerApps) {
    name: 'ca-${app.name}-${varUniqueSuffix}'
    params: {
      containerApp: union(
        {
          name: app.name
          environmentResourceId: !empty(resourceIds.?containerEnvResourceId!)
            ? resourceIds.containerEnvResourceId!
            : containerEnv!.outputs.resourceId
          workloadProfileName: 'default'
          location: location
          tags: tags
        },
        app
      )
    }
  }
]

// -----------------------
// OUTPUTS
// -----------------------

@description('Container Apps Environment Resource ID')
output containerEnvResourceId string = varContainerEnvResourceId

@description('Container Apps Environment Name')
output containerEnvName string = varContainerEnvName

@description('Container Registry Resource ID')
output containerRegistryResourceId string = varAcrResourceId

@description('Container Registry Name')
output containerRegistryName string = varAcrName

@description('Container Apps Resource IDs')
output containerAppsResourceIds array = [for (app, index) in containerAppsList: varDeployContainerApps ? containerApps[index]!.outputs.resourceId : '']

@description('Container Apps Names')
output containerAppsNames array = [for (app, index) in containerAppsList: app.name]
