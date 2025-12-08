// Compute Module
// This module deploys Build VM and Jump VM with their Maintenance Configurations

import * as types from '../common/types.bicep'

@description('The base name for resources.')
param baseName string

@description('The Azure region for resources.')
param location string

@description('Enable telemetry for AVM modules.')
param enableTelemetry bool

@description('Resource tags.')
param tags types.tagsType

@description('Deployment toggles for compute resources.')
param deployToggles types.deployTogglesType

@description('Build VM configuration.')
param buildVmDefinition types.vmDefinitionType?

@description('Build VM Maintenance Definition.')
param buildVmMaintenanceDefinition types.vmMaintenanceDefinitionType?

@description('Jump VM configuration.')
param jumpVmDefinition types.vmDefinitionType?

@description('Jump VM Maintenance Definition.')
param jumpVmMaintenanceDefinition types.vmMaintenanceDefinitionType?

@description('Auto-generated random password for Build VM.')
@secure()
param buildVmAdminPassword string

@description('Auto-generated random password for Jump VM.')
@secure()
param jumpVmAdminPassword string

@description('Build VM Subnet ID.')
param buildSubnetId string

@description('Jump VM Subnet ID.')
param jumpSubnetId string

@description('Unique suffix for deployment names.')
param varUniqueSuffix string

// -----------------------
// DEPLOYMENT FLAGS
// -----------------------
var varDeployBuildVm = deployToggles.?buildVm ?? false
var varDeployJumpVm = deployToggles.?jumpVm ?? false
var varJumpVmMaintenanceConfigured = varDeployJumpVm && (jumpVmMaintenanceDefinition != null)

// -----------------------
// BUILD VM
// -----------------------

// Build VM Maintenance Configuration
module buildVmMaintenanceConfiguration '../wrappers/avm.res.maintenance.maintenance-configuration.bicep' = if (varDeployBuildVm) {
  name: 'buildVmMaintenanceConfigurationDeployment-${varUniqueSuffix}'
  params: {
    maintenanceConfig: union(
      {
        name: 'mc-${baseName}-build'
        location: location
        tags: tags
      },
      buildVmMaintenanceDefinition ?? {}
    )
  }
}

// Build VM
module buildVm '../wrappers/avm.res.compute.build-vm.bicep' = if (varDeployBuildVm) {
  name: 'buildVmDeployment-${varUniqueSuffix}'
  params: {
    buildVm: union(
      {
        name: 'vm-${substring(baseName, 0, 6)}-bld'
        sku: 'Standard_F4s_v2'
        adminUsername: 'builduser'
        osType: 'Linux'
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts'
          version: 'latest'
        }
        runner: 'github'
        github: {
          owner: 'your-org'
          repo: 'your-repo'
        }
        nicConfigurations: [
          {
            nicSuffix: '-nic'
            ipConfigurations: [
              {
                name: 'ipconfig01'
                subnetResourceId: buildSubnetId
              }
            ]
          }
        ]
        osDisk: {
          caching: 'ReadWrite'
          createOption: 'FromImage'
          deleteOption: 'Delete'
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
        disablePasswordAuthentication: false
        adminPassword: buildVmAdminPassword
        availabilityZone: 1
        location: location
        tags: tags
        enableTelemetry: enableTelemetry
      },
      buildVmDefinition ?? {}
    )
  }
}

// -----------------------
// JUMP VM
// -----------------------

// Jump VM Maintenance Configuration
module jumpVmMaintenanceConfiguration '../wrappers/avm.res.maintenance.maintenance-configuration.bicep' = if (varJumpVmMaintenanceConfigured) {
  name: 'jumpVmMaintenanceConfigurationDeployment-${varUniqueSuffix}'
  params: {
    maintenanceConfig: union(
      {
        name: 'mc-${baseName}-jump'
        location: location
        tags: tags
      },
      jumpVmMaintenanceDefinition ?? {}
    )
  }
}

// Jump VM
module jumpVm '../wrappers/avm.res.compute.jump-vm.bicep' = if (varDeployJumpVm) {
  name: 'jumpVmDeployment-${varUniqueSuffix}'
  params: {
    jumpVm: union(
      {
        name: 'vm-${substring(baseName, 0, 6)}-jmp'
        sku: 'Standard_D4as_v5'
        adminUsername: 'azureuser'
        osType: 'Windows'
        imageReference: {
          publisher: 'MicrosoftWindowsServer'
          offer: 'WindowsServer'
          sku: '2022-datacenter-azure-edition'
          version: 'latest'
        }
        adminPassword: jumpVmAdminPassword
        nicConfigurations: [
          {
            nicSuffix: '-nic'
            ipConfigurations: [
              {
                name: 'ipconfig01'
                subnetResourceId: jumpSubnetId
              }
            ]
          }
        ]
        osDisk: {
          caching: 'ReadWrite'
          createOption: 'FromImage'
          deleteOption: 'Delete'
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
        ...(varJumpVmMaintenanceConfigured
          ? {
              maintenanceConfigurationResourceId: jumpVmMaintenanceConfiguration!.outputs.resourceId
            }
          : {})
        availabilityZone: 1
        location: location
        tags: tags
        enableTelemetry: enableTelemetry
      },
      jumpVmDefinition ?? {}
    )
  }
}

// -----------------------
// OUTPUTS
// -----------------------

@description('Build VM Resource ID')
output buildVmResourceId string = varDeployBuildVm ? buildVm!.outputs.resourceId : ''

@description('Build VM Name')
output buildVmName string = varDeployBuildVm ? buildVm!.outputs.name : ''

@description('Build VM Maintenance Configuration Resource ID')
output buildVmMaintenanceConfigResourceId string = varDeployBuildVm ? buildVmMaintenanceConfiguration!.outputs.resourceId : ''

@description('Jump VM Resource ID')
output jumpVmResourceId string = varDeployJumpVm ? jumpVm!.outputs.resourceId : ''

@description('Jump VM Name')
output jumpVmName string = varDeployJumpVm ? jumpVm!.outputs.name : ''

@description('Jump VM Maintenance Configuration Resource ID')
output jumpVmMaintenanceConfigResourceId string = varJumpVmMaintenanceConfigured ? jumpVmMaintenanceConfiguration!.outputs.resourceId : ''
