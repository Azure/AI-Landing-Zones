// Private Endpoints Module
// This module deploys all Private Endpoints for the AI Landing Zone

import * as types from '../common/types.bicep'

@description('The base name for resources.')
param baseName string

@description('The Azure region for resources.')
param location string

@description('Enable telemetry for AVM modules.')
param enableTelemetry bool

@description('Resource tags.')
param tags types.tagsType

@description('Private Endpoints subnet ID.')
param varPeSubnetId string

@description('Deploy Private DNS and Private Endpoints flag.')
param varDeployPdnsAndPe bool

@description('Unique suffix for deployment names.')
param varUniqueSuffix string

// Resource existence flags
@description('Has App Configuration flag.')
param varHasAppConfig bool

@description('Has API Management flag.')
param varHasApim bool

@description('Has Container Environment flag.')
param varHasContainerEnv bool

@description('Has Azure Container Registry flag.')
param varHasAcr bool

@description('Has Storage Account flag.')
param varHasStorage bool

@description('Has Cosmos DB flag.')
param varHasCosmos bool

@description('Has Azure AI Search flag.')
param varHasSearch bool

@description('Has Key Vault flag.')
param varHasKv bool

// Resource IDs to link to private endpoints
@description('App Configuration Resource ID.')
param appConfigResourceId string = ''

@description('API Management Resource ID.')
param apimResourceId string = ''

@description('Container Environment Resource ID.')
param containerEnvResourceId string = ''

@description('Azure Container Registry Resource ID.')
param acrResourceId string = ''

@description('Storage Account Resource ID.')
param storageAccountResourceId string = ''

@description('Cosmos DB Resource ID.')
param cosmosDbResourceId string = ''

@description('Azure AI Search Resource ID.')
param aiSearchResourceId string = ''

@description('Key Vault Resource ID.')
param keyVaultResourceId string = ''

// API Management specific parameters
@description('API Management definition for PE support check.')
param apimDefinition types.apimDefinitionType?

// Private Endpoint Configurations
@description('App Configuration Private Endpoint configuration.')
param appConfigPrivateEndpointDefinition types.privateDnsZoneDefinitionType?

@description('API Management Private Endpoint configuration.')
param apimPrivateEndpointDefinition types.privateDnsZoneDefinitionType?

@description('Container Apps Environment Private Endpoint configuration.')
param containerAppEnvPrivateEndpointDefinition types.privateDnsZoneDefinitionType?

@description('Azure Container Registry Private Endpoint configuration.')
param acrPrivateEndpointDefinition types.privateDnsZoneDefinitionType?

@description('Storage Account Private Endpoint configuration.')
param storageBlobPrivateEndpointDefinition types.privateDnsZoneDefinitionType?

@description('Cosmos DB Private Endpoint configuration.')
param cosmosPrivateEndpointDefinition types.privateDnsZoneDefinitionType?

@description('Azure AI Search Private Endpoint configuration.')
param searchPrivateEndpointDefinition types.privateDnsZoneDefinitionType?

@description('Key Vault Private Endpoint configuration.')
param keyVaultPrivateEndpointDefinition types.privateDnsZoneDefinitionType?

// DNS Zone Resource IDs
@description('App Config DNS Zone Resource ID.')
param appConfigDnsZoneId string

@description('APIM DNS Zone Resource ID.')
param apimDnsZoneId string

@description('Container Apps DNS Zone Resource ID.')
param containerAppsDnsZoneId string

@description('ACR DNS Zone Resource ID.')
param acrDnsZoneId string

@description('Blob DNS Zone Resource ID.')
param blobDnsZoneId string

@description('Cosmos DB DNS Zone Resource ID.')
param cosmosSqlDnsZoneId string

@description('Search DNS Zone Resource ID.')
param searchDnsZoneId string

@description('Key Vault DNS Zone Resource ID.')
param keyVaultDnsZoneId string

// -----------------------
// DEPLOYMENT FLAGS
// -----------------------

// StandardV2 and Premium SKUs support Private Endpoints with gateway groupId
var apimSupportsPe = contains(['StandardV2', 'Premium'], (apimDefinition.?sku ?? 'StandardV2'))

// -----------------------
// PRIVATE ENDPOINTS
// -----------------------

// App Configuration Private Endpoint
module privateEndpointAppConfig '../wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPdnsAndPe && varHasAppConfig) {
  name: 'appconfig-private-endpoint-${varUniqueSuffix}'
  params: {
    privateEndpoint: union(
      {
        name: 'pe-appcs-${baseName}'
        location: location
        tags: tags
        subnetResourceId: varPeSubnetId
        enableTelemetry: enableTelemetry
        privateLinkServiceConnections: [
          {
            name: 'appConfigConnection'
            properties: {
              privateLinkServiceId: appConfigResourceId
              groupIds: ['configurationStores']
            }
          }
        ]
        privateDnsZoneGroup: {
          name: 'appConfigDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'appConfigARecord'
              privateDnsZoneResourceId: appConfigDnsZoneId
            }
          ]
        }
      },
      appConfigPrivateEndpointDefinition ?? {}
    )
  }
}

// API Management Private Endpoint
module privateEndpointApim '../wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPdnsAndPe && varHasApim && (apimDefinition.?virtualNetworkType ?? 'None') == 'None' && apimSupportsPe) {
  name: 'apim-private-endpoint-${varUniqueSuffix}'
  params: {
    privateEndpoint: union(
      {
        name: 'pe-apim-${baseName}'
        location: location
        tags: tags
        subnetResourceId: varPeSubnetId
        enableTelemetry: enableTelemetry
        privateLinkServiceConnections: [
          {
            name: 'apimGatewayConnection'
            properties: {
              privateLinkServiceId: apimResourceId
              groupIds: ['Gateway']
            }
          }
        ]
        privateDnsZoneGroup: {
          name: 'apimDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'apimARecord'
              privateDnsZoneResourceId: apimDnsZoneId
            }
          ]
        }
      },
      apimPrivateEndpointDefinition ?? {}
    )
  }
}

// Container Apps Environment Private Endpoint
module privateEndpointContainerAppsEnv '../wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPdnsAndPe && varHasContainerEnv) {
  name: 'containerapps-env-private-endpoint-${varUniqueSuffix}'
  params: {
    privateEndpoint: union(
      {
        name: 'pe-cae-${baseName}'
        location: location
        tags: tags
        subnetResourceId: varPeSubnetId
        enableTelemetry: enableTelemetry
        privateLinkServiceConnections: [
          {
            name: 'ccaConnection'
            properties: {
              privateLinkServiceId: containerEnvResourceId
              groupIds: ['managedEnvironments']
            }
          }
        ]
        privateDnsZoneGroup: {
          name: 'ccaDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'ccaARecord'
              privateDnsZoneResourceId: containerAppsDnsZoneId
            }
          ]
        }
      },
      containerAppEnvPrivateEndpointDefinition ?? {}
    )
  }
}

// Azure Container Registry Private Endpoint
module privateEndpointAcr '../wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPdnsAndPe && varHasAcr) {
  name: 'acr-private-endpoint-${varUniqueSuffix}'
  params: {
    privateEndpoint: union(
      {
        name: 'pe-acr-${baseName}'
        location: location
        tags: tags
        subnetResourceId: varPeSubnetId
        enableTelemetry: enableTelemetry
        privateLinkServiceConnections: [
          {
            name: 'acrConnection'
            properties: {
              privateLinkServiceId: acrResourceId
              groupIds: ['registry']
            }
          }
        ]
        privateDnsZoneGroup: {
          name: 'acrDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'acrARecord'
              privateDnsZoneResourceId: acrDnsZoneId
            }
          ]
        }
      },
      acrPrivateEndpointDefinition ?? {}
    )
  }
}

// Storage Account (Blob) Private Endpoint
module privateEndpointStorageBlob '../wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPdnsAndPe && varHasStorage) {
  name: 'blob-private-endpoint-${varUniqueSuffix}'
  params: {
    privateEndpoint: union(
      {
        name: 'pe-st-${baseName}'
        location: location
        tags: tags
        subnetResourceId: varPeSubnetId
        enableTelemetry: enableTelemetry
        privateLinkServiceConnections: [
          {
            name: 'blobConnection'
            properties: {
              privateLinkServiceId: storageAccountResourceId
              groupIds: ['blob']
            }
          }
        ]
        privateDnsZoneGroup: {
          name: 'blobDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'blobARecord'
              privateDnsZoneResourceId: blobDnsZoneId
            }
          ]
        }
      },
      storageBlobPrivateEndpointDefinition ?? {}
    )
  }
}

// Cosmos DB (SQL) Private Endpoint
module privateEndpointCosmos '../wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPdnsAndPe && varHasCosmos) {
  name: 'cosmos-private-endpoint-${varUniqueSuffix}'
  params: {
    privateEndpoint: union(
      {
        name: 'pe-cos-${baseName}'
        location: location
        tags: tags
        subnetResourceId: varPeSubnetId
        enableTelemetry: enableTelemetry
        privateLinkServiceConnections: [
          {
            name: 'cosmosConnection'
            properties: {
              privateLinkServiceId: cosmosDbResourceId
              groupIds: ['Sql']
            }
          }
        ]
        privateDnsZoneGroup: {
          name: 'cosmosDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'cosmosARecord'
              privateDnsZoneResourceId: cosmosSqlDnsZoneId
            }
          ]
        }
      },
      cosmosPrivateEndpointDefinition ?? {}
    )
  }
}

// Azure AI Search Private Endpoint
module privateEndpointSearch '../wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPdnsAndPe && varHasSearch) {
  name: 'search-private-endpoint-${varUniqueSuffix}'
  params: {
    privateEndpoint: union(
      {
        name: 'pe-srch-${baseName}'
        location: location
        tags: tags
        subnetResourceId: varPeSubnetId
        enableTelemetry: enableTelemetry
        privateLinkServiceConnections: [
          {
            name: 'searchConnection'
            properties: {
              privateLinkServiceId: aiSearchResourceId
              groupIds: ['searchService']
            }
          }
        ]
        privateDnsZoneGroup: {
          name: 'searchDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'searchARecord'
              privateDnsZoneResourceId: searchDnsZoneId
            }
          ]
        }
      },
      searchPrivateEndpointDefinition ?? {}
    )
  }
}

// Key Vault Private Endpoint
module privateEndpointKeyVault '../wrappers/avm.res.network.private-endpoint.bicep' = if (varDeployPdnsAndPe && varHasKv) {
  name: 'kv-private-endpoint-${varUniqueSuffix}'
  params: {
    privateEndpoint: union(
      {
        name: 'pe-kv-${baseName}'
        location: location
        tags: tags
        subnetResourceId: varPeSubnetId
        enableTelemetry: enableTelemetry
        privateLinkServiceConnections: [
          {
            name: 'kvConnection'
            properties: {
              privateLinkServiceId: keyVaultResourceId
              groupIds: ['vault']
            }
          }
        ]
        privateDnsZoneGroup: {
          name: 'kvDnsZoneGroup'
          privateDnsZoneGroupConfigs: [
            {
              name: 'kvARecord'
              privateDnsZoneResourceId: keyVaultDnsZoneId
            }
          ]
        }
      },
      keyVaultPrivateEndpointDefinition ?? {}
    )
  }
}

// -----------------------
// OUTPUTS
// -----------------------

@description('App Configuration Private Endpoint Resource ID')
output appConfigPrivateEndpointId string = (varDeployPdnsAndPe && varHasAppConfig) ? privateEndpointAppConfig!.outputs.resourceId : ''

@description('API Management Private Endpoint Resource ID')
output apimPrivateEndpointId string = (varDeployPdnsAndPe && varHasApim && apimSupportsPe) ? privateEndpointApim!.outputs.resourceId : ''

@description('Container Apps Environment Private Endpoint Resource ID')
output containerAppsEnvPrivateEndpointId string = (varDeployPdnsAndPe && varHasContainerEnv) ? privateEndpointContainerAppsEnv!.outputs.resourceId : ''

@description('Azure Container Registry Private Endpoint Resource ID')
output acrPrivateEndpointId string = (varDeployPdnsAndPe && varHasAcr) ? privateEndpointAcr!.outputs.resourceId : ''

@description('Storage Account Private Endpoint Resource ID')
output storageBlobPrivateEndpointId string = (varDeployPdnsAndPe && varHasStorage) ? privateEndpointStorageBlob!.outputs.resourceId : ''

@description('Cosmos DB Private Endpoint Resource ID')
output cosmosPrivateEndpointId string = (varDeployPdnsAndPe && varHasCosmos) ? privateEndpointCosmos!.outputs.resourceId : ''

@description('Azure AI Search Private Endpoint Resource ID')
output searchPrivateEndpointId string = (varDeployPdnsAndPe && varHasSearch) ? privateEndpointSearch!.outputs.resourceId : ''

@description('Key Vault Private Endpoint Resource ID')
output keyVaultPrivateEndpointId string = (varDeployPdnsAndPe && varHasKv) ? privateEndpointKeyVault!.outputs.resourceId : ''
