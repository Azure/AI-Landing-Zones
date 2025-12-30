targetScope = 'resourceGroup'

var location = 'eastus2'

@description('Admin username for the test VM.')
param adminUsername string = 'azureuser'

@secure()
@description('Admin password for the test VM.')
param adminPassword string

@description('Optional. Cache-busting tag for the VM Custom Script Extension. Defaults to a new GUID each deployment to force re-run.')
param testVmCseForceUpdateTag string = newGuid()

@description('Size of the test VM')
param vmSize string = 'Standard_D8s_v5'

@description('Image SKU (e.g., win11-25h2-ent, win11-23h2-ent, 2022-datacenter).')
param vmImageSku string = 'win11-25h2-ent'

@description('Image publisher (Windows 11: MicrosoftWindowsDesktop, Windows Server: MicrosoftWindowsServer).')
param vmImagePublisher string = 'MicrosoftWindowsDesktop'

@description('Image offer (Windows 11: windows-11, Windows Server: WindowsServer).')
param vmImageOffer string = 'windows-11'

@description('Image version (use latest unless you need a pinned build).')
param vmImageVersion string = 'latest'

@description('Optional. Resource ID of an existing spoke VNet. When provided, the template will link all Private DNS Zones to it (in addition to the hub VNet).')
param spokeVnetResourceId string = ''

var hubVnetName = 'vnet-ai-lz-hub'
var hubVnetCidr = '10.0.0.0/16'

var firewallSubnetCidr = '10.0.0.0/26'
var bastionSubnetCidr = '10.0.0.64/26'
var hubVmSubnetName = 'hub-vm-subnet'
var hubVmSubnetCidr = '10.0.1.0/24'

var firewallName = 'afw-ai-lz-hub'
var firewallPipName = 'pip-ai-lz-afw'

var firewallPolicyName = 'fwp-ai-lz-hub'
var firewallRuleCollectionGroupName = 'rcg-allow-egress'

var bastionName = 'bas-ai-lz-hub'
var bastionPipName = 'pip-ai-lz-bastion'

var hubUdrName = 'udr-ai-lz-hub'

// Windows computerName has a 15 character limit.
var testVmName = 'vm-ailz-hubtst'
var testVmNicName = '${testVmName}-nic'
var vmNsgName = 'nsg-${hubVmSubnetName}'

// Deterministic short token used by the install script for AZD env naming.
var resourceToken = toLower(substring(uniqueString(resourceGroup().id), 0, 6))

var privateDnsZoneNames = [
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.file.${environment().suffixes.storage}'
  'privatelink.vaultcore.azure.net'
  'privatelink.azurecr.io'
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.services.ai.azure.com'
  'privatelink.search.windows.net'
  'privatelink.documents.azure.com'
]

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: hubVnetName
  location: location
  tags: {
    workload: 'ai-landing-zones'
    purpose: 'platform-test'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVnetCidr
      ]
    }
  }
}

resource firewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: hubVnet
  name: 'AzureFirewallSubnet'
  properties: {
    addressPrefix: firewallSubnetCidr
  }
}

resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: hubVnet
  name: 'AzureBastionSubnet'
  properties: {
    addressPrefix: bastionSubnetCidr
  }
  dependsOn: [
    firewallSubnet
  ]
}

resource hubVmNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: vmNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRdpFromAzureBastionSubnet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: bastionSubnetCidr
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource hubUdr 'Microsoft.Network/routeTables@2023-11-01' = {
  name: hubUdrName
  location: location
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'default-to-hub-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}

resource hubVmSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: hubVnet
  name: hubVmSubnetName
  properties: {
    addressPrefix: hubVmSubnetCidr
    networkSecurityGroup: {
      id: hubVmNsg.id
    }
    routeTable: {
      id: hubUdr.id
    }
  }
  dependsOn: [
    bastionSubnet
  ]
}

resource firewallPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: firewallPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: firewallPolicyName
  location: location
  properties: {
    sku: {
      tier: 'Standard'
    }
  }
}

resource firewallPolicyRcg 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: firewallPolicy
  name: firewallRuleCollectionGroupName
  properties: {
    priority: 100
    ruleCollections: [
      {
        name: 'AllowAILandingZoneNetwork'
        priority: 100
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'allow-azure-dns'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
              'UDP'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
              '172.16.0.0/12'
              '192.168.0.0/16'
            ]
            destinationAddresses: [
              '168.63.129.16'
            ]
            destinationPorts: [
              '53'
            ]
          }
          {
            name: 'allow-azuread-https'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
              '172.16.0.0/12'
              '192.168.0.0/16'
            ]
            destinationAddresses: [
              'AzureActiveDirectory'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            name: 'allow-azure-resource-manager-https'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
              '172.16.0.0/12'
              '192.168.0.0/16'
            ]
            destinationAddresses: [
              // Required for Azure CLI / AZD to call ARM after obtaining tokens.
              'AzureResourceManager'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            name: 'allow-azure-cloud-https'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
              '172.16.0.0/12'
              '192.168.0.0/16'
            ]
            destinationAddresses: [
              // Broad Azure public-cloud endpoints (helps Azure CLI/AZD avoid TLS failures caused by missing ancillary Azure endpoints).
              'AzureCloud'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            name: 'allow-mcr-and-afd-https'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
              '172.16.0.0/12'
              '192.168.0.0/16'
            ]
            destinationAddresses: [
              'MicrosoftContainerRegistry'
              'AzureFrontDoorFirstParty'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            name: 'allow-foundry-agent-infra-private'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'Any'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
              '172.16.0.0/12'
              '192.168.0.0/16'
            ]
            destinationAddresses: [
              '10.0.0.0/8'
              '172.16.0.0/12'
              '192.168.0.0/16'
              '100.64.0.0/10'
            ]
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
      {
        name: 'AllowAILandingZoneApp'
        priority: 110
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'allow-bootstrap-fqdns'
            ruleType: 'ApplicationRule'
            sourceAddresses: [
              '10.0.0.0/8'
              '172.16.0.0/12'
              '192.168.0.0/16'
            ]
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              // CSE downloads + repo clone
              'raw.githubusercontent.com'
              '*.githubusercontent.com'
              'github.com'
              'codeload.github.com'

              // Chocolatey bootstrap + package downloads (used by install.ps1)
              'community.chocolatey.org'
              'chocolatey.org'
              'packages.chocolatey.org'

              // Common Chocolatey package payload sources (used by install.ps1)
              // VS Code
              'update.code.visualstudio.com'
              'vscode.download.prss.microsoft.com'
              'az764295.vo.msecnd.net'

              // Azure CLI
              'azurecliprod.blob.${environment().suffixes.storage}'
              'azcliprod.blob.${environment().suffixes.storage}'

              // Python
              'www.python.org'
              'python.org'

              // Docker Desktop
              'desktop.docker.com'
              'download.docker.com'

              // Visual C++ Redistributables (python311 dependency)
              'download.visualstudio.microsoft.com'

              // TLS revocation/OCSP endpoints (can break downloads if blocked)
              'crl.microsoft.com'
              'ocsp.msocsp.com'
              'www.digicert.com'
              'ocsp.digicert.com'
              'crl3.digicert.com'
              'crl4.digicert.com'

              // WSL update MSI (used by install.ps1)
              'wslstorestorage.blob.${environment().suffixes.storage}'

              'mcr.microsoft.com'
              '*.data.mcr.microsoft.com'
              'packages.aks.azure.com'
              'acs-mirror.azureedge.net'
            ]
          }
          {
            name: 'allow-chocolatey-http'
            ruleType: 'ApplicationRule'
            sourceAddresses: [
              '10.0.0.0/8'
              '172.16.0.0/12'
              '192.168.0.0/16'
            ]
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
            ]
            targetFqdns: [
              'community.chocolatey.org'
              'chocolatey.org'
            ]
          }
          {
            name: 'allow-tls-revocation-http'
            ruleType: 'ApplicationRule'
            sourceAddresses: [
              '10.0.0.0/8'
              '172.16.0.0/12'
              '192.168.0.0/16'
            ]
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
            ]
            targetFqdns: [
              // OCSP/CRL checks are commonly done over HTTP (80)
              'crl.microsoft.com'
              'ocsp.msocsp.com'
              'ocsp.digicert.com'
              'crl3.digicert.com'
              'crl4.digicert.com'
            ]
          }
        ]
      }
    ]
  }
}

resource azureFirewall 'Microsoft.Network/azureFirewalls@2024-03-01' = {
  name: firewallName
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    firewallPolicy: {
      id: firewallPolicy.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: firewallSubnet.id
          }
          publicIPAddress: {
            id: firewallPip.id
          }
        }
      }
    ]
  }
  dependsOn: [
    firewallPolicyRcg
  ]
}

resource bastionPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: bastionPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2023-11-01' = {
  name: bastionName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    scaleUnits: 2
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: bastionSubnet.id
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

resource testVmNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: testVmNicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: hubVmSubnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource testVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: testVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    securityProfile: {
      encryptionAtHost: false
    }
    osProfile: {
      computerName: testVmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: vmImagePublisher
        offer: vmImageOffer
        sku: vmImageSku
        version: vmImageVersion
      }
      osDisk: {
        caching: 'ReadWrite'
        createOption: 'FromImage'
        diskSizeGB: 250
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: testVmNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

var testVmInstallFileUris = [
  'https://raw.githubusercontent.com/Azure/AI-Landing-Zones/refs/heads/fix/issue-63/bicep/infra/install.ps1'
]

resource testVmCse 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  parent: testVm
  name: 'cse'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    forceUpdateTag: testVmCseForceUpdateTag
    settings: {
      fileUris: testVmInstallFileUris
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File install.ps1 -release fix/issue-63 -azureTenantID ${subscription().tenantId} -azureSubscriptionID ${subscription().subscriptionId} -AzureResourceGroupName ${resourceGroup().name} -azureLocation ${location} -AzdEnvName ai-lz-${resourceToken} -resourceToken ${resourceToken} -useUAI false'
    }
  }
}

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2024-06-01' = [for zoneName in privateDnsZoneNames: {
  name: zoneName
  location: 'global'
}]

resource privateDnsZoneLinksHub 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (zoneName, i) in privateDnsZoneNames: {
  parent: privateDnsZones[i]
  name: '${hubVnetName}-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: hubVnet.id
    }
    registrationEnabled: false
  }
}]

resource privateDnsZoneLinksSpoke 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (zoneName, i) in privateDnsZoneNames: if (spokeVnetResourceId != '') {
  parent: privateDnsZones[i]
  name: 'spoke-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: spokeVnetResourceId
    }
    registrationEnabled: false
  }
}]

output platformResourceGroupName string = resourceGroup().name
output hubVnetResourceId string = hubVnet.id
output hubVnetName string = hubVnet.name
output firewallResourceId string = azureFirewall.id
output firewallPrivateIp string = azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
output bastionResourceId string = bastion.id
output testVmResourceId string = testVm.id
output privateDnsZonesDeployed array = [for (zoneName, i) in privateDnsZoneNames: {
  name: zoneName
  id: privateDnsZones[i].id
}]
