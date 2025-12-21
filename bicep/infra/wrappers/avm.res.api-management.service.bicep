// AVM API Management wrapper (pass-through)
targetScope = 'resourceGroup'

import { apimDefinitionType } from '../common/types.bicep'

// ============================================================================
// Parameters
// ============================================================================

@description('Required. API Management service configuration.')
param apiManagement apimDefinitionType

// ============================================================================
// Resources
// ============================================================================

#disable-next-line BCP081
module apiManagementService 'br/public:avm/res/api-management/service:0.13.0' = {
  name: 'apim-service-${apiManagement.name!}'
  params: {
    name: apiManagement.name
    publisherEmail: apiManagement.publisherEmail
    publisherName: apiManagement.publisherName
    sku: any(apiManagement.?sku)
    skuCapacity: apiManagement.?skuCapacity
    location: apiManagement.?location
    tags: apiManagement.?tags
    enableTelemetry: apiManagement.?enableTelemetry
    diagnosticSettings: apiManagement.?diagnosticSettings
    disableGateway: apiManagement.?disableGateway
    enableClientCertificate: apiManagement.?enableClientCertificate
    enableDeveloperPortal: apiManagement.?enableDeveloperPortal
    hostnameConfigurations: apiManagement.?hostnameConfigurations
    identityProviders: apiManagement.?identityProviders
    portalsettings: apiManagement.?portalsettings
    lock: apiManagement.?lock
    loggers: apiManagement.?loggers
    managedIdentities: apiManagement.?managedIdentities
    minApiVersion: apiManagement.?minApiVersion
    namedValues: apiManagement.?namedValues
    newGuidValue: apiManagement.?newGuidValue
    notificationSenderEmail: apiManagement.?notificationSenderEmail
    policies: apiManagement.?policies
    products: apiManagement.?products
    publicIpAddressResourceId: apiManagement.?publicIpAddressResourceId
    restore: apiManagement.?restore
    roleAssignments: apiManagement.?roleAssignments
    subnetResourceId: apiManagement.?subnetResourceId
    subscriptions: apiManagement.?subscriptions
    virtualNetworkType: apiManagement.?virtualNetworkType
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('The resource ID of the API Management service.')
output resourceId string = apiManagementService.outputs.resourceId

@description('The resource group the API Management service was deployed into.')
output resourceGroupName string = apiManagementService.outputs.resourceGroupName

@description('The name of the API Management service.')
output name string = apiManagementService.outputs.name

@description('The principal ID of the system assigned identity.')
output systemAssignedMIPrincipalId string = apiManagementService.outputs.?systemAssignedMIPrincipalId ?? ''

@description('The location the resource was deployed into.')
output location string = apiManagementService.outputs.location
