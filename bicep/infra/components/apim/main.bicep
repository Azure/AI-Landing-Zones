metadata name = 'apim'
metadata description = 'Deploys an API Management service instance using the native Microsoft.ApiManagement/service resource (supports PremiumV2).'

targetScope = 'resourceGroup'

import { apimDefinitionType } from '../../common/types.bicep'

@description('Required. API Management service configuration.')
param apiManagement apimDefinitionType

var skuName = apiManagement.?sku ?? 'PremiumV2'
var skuCapacity = apiManagement.?skuCapacity ?? (skuName == 'Consumption' ? 0 : 1)

var apimLocation = apiManagement.?location ?? resourceGroup().location

var miSystemAssigned = apiManagement.?managedIdentities.?systemAssigned ?? false
var miUserAssignedIds = apiManagement.?managedIdentities.?userAssignedResourceIds ?? []

var miHasUserAssigned = length(miUserAssignedIds) > 0
var miHasSystemAssigned = miSystemAssigned

var identityType = miHasSystemAssigned && miHasUserAssigned
  ? 'SystemAssigned, UserAssigned'
  : (miHasSystemAssigned ? 'SystemAssigned' : (miHasUserAssigned ? 'UserAssigned' : 'None'))

// Note: Some Bicep CLI versions fail parsing object-comprehension maps for this use.
// Build the ARM identity map via JSON to keep compatibility.
var userAssignedIdentitiesEntries = [for identityResourceId in miUserAssignedIds: '"${identityResourceId}":{}']

var userAssignedIdentitiesDelimiter = ','

var userAssignedIdentities = miHasUserAssigned
  ? json('{${join(userAssignedIdentitiesEntries, userAssignedIdentitiesDelimiter)}}')
  : {}

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apiManagement.name
  location: apimLocation
  tags: apiManagement.?tags

  identity: (miHasSystemAssigned || miHasUserAssigned)
    ? (miHasUserAssigned
        ? {
            type: identityType
            userAssignedIdentities: userAssignedIdentities
          }
        : {
            type: identityType
          })
    : null

  sku: {
    name: skuName
    capacity: skuCapacity
  }

  properties: union(
    {
      publisherEmail: apiManagement.publisherEmail
      publisherName: apiManagement.publisherName
    },
    apiManagement.?notificationSenderEmail != null ? { notificationSenderEmail: apiManagement.notificationSenderEmail! } : {},
    apiManagement.?disableGateway != null ? { disableGateway: apiManagement.disableGateway! } : {},
    apiManagement.?enableClientCertificate != null ? { enableClientCertificate: apiManagement.enableClientCertificate! } : {},
    apiManagement.?enableDeveloperPortal != null
      ? {
          developerPortalStatus: apiManagement.enableDeveloperPortal! ? 'Enabled' : 'Disabled'
        }
      : {},
    apiManagement.?hostnameConfigurations != null ? { hostnameConfigurations: apiManagement.hostnameConfigurations! } : {},
    apiManagement.?customProperties != null ? { customProperties: apiManagement.customProperties! } : {},
    apiManagement.?restore != null ? { restore: apiManagement.restore! } : {},
    apiManagement.?minApiVersion != null ? { apiVersionConstraint: { minApiVersion: apiManagement.minApiVersion! } } : {},
    apiManagement.?publicIpAddressResourceId != null ? { publicIpAddressId: apiManagement.publicIpAddressResourceId! } : {},
    apiManagement.?virtualNetworkType != null ? { virtualNetworkType: apiManagement.virtualNetworkType! } : {},
    apiManagement.?subnetResourceId != null
      ? {
          virtualNetworkConfiguration: {
            subnetResourceId: apiManagement.subnetResourceId!
          }
        }
      : {}
  )
}

@description('The resource ID of the API Management service.')
output resourceId string = apim.id

@description('The resource group the API Management service was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The name of the API Management service.')
output name string = apim.name

@description('The principal ID of the system assigned identity (empty if not enabled).')
output systemAssignedMIPrincipalId string = miHasSystemAssigned ? apim.identity.principalId : ''

@description('The location the resource was deployed into.')
output location string = apim.location
