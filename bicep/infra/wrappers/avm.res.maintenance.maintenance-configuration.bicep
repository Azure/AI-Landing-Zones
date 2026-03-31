// Wrapper for Maintenance Configuration
// Purpose: Wrap the AVM Maintenance Configuration module to provide a consistent interface
// Version: Wraps avm/res/maintenance/maintenance-configuration:0.3.1

import { vmMaintenanceDefinitionType } from '../common/types.bicep'

@description('Maintenance Configuration.')
param maintenanceConfig vmMaintenanceDefinitionType

// Inner module reference to AVM
module inner 'br/public:avm/res/maintenance/maintenance-configuration:0.3.1' = {
  name: 'maint-avm-${maintenanceConfig.name!}'
  params: {
    // Required
    name: maintenanceConfig.name!
    
    // Pass through optional properties
    location: maintenanceConfig.?location
    tags: maintenanceConfig.?tags
  }
}

// Outputs
@description('The resource ID of the Maintenance Configuration.')
output resourceId string = inner.outputs.resourceId

@description('The resource name of the Maintenance Configuration.')
output name string = inner.outputs.name

@description('The resource group the Maintenance Configuration was deployed into.')
output resourceGroupName string = inner.outputs.resourceGroupName

@description('The location the resource was deployed into.')
output location string = inner.outputs.location
