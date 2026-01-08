targetScope = 'resourceGroup'

@description('Name of the virtual machine (in the current resource group) whose system-assigned managed identity will be used as the principal.')
param vmName string

@description('Role definition GUID (e.g., Contributor: b24988ac-6180-42a0-ab88-20f7382dd24c).')
param roleDefinitionGuid string

@description('Principal type for the role assignment. Default: ServicePrincipal (managed identity).')
@allowed([
  'ServicePrincipal'
  'User'
  'Group'
  'ForeignGroup'
  'Device'
  'Application'
])
param principalType string = 'ServicePrincipal'

resource vm 'Microsoft.Compute/virtualMachines@2024-11-01' existing = {
  name: vmName
}

var principalId = vm.identity.?principalId ?? ''

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, vmName, roleDefinitionGuid)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionGuid)
    principalId: principalId
    principalType: principalType
  }
}
