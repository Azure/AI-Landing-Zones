using './main.bicep'

// Standalone + AI Foundry dependencies with public networking enabled,
// restricted to:
// - The public IP: 187.13.147.118


param deployToggles = {
  aiFoundry: true
  logAnalytics: true
  appInsights: true
  virtualNetwork: true
  peNsg: true
  agentNsg: false
  acaEnvironmentNsg: false
  apiManagementNsg: false
  applicationGatewayNsg: false
  jumpboxNsg: true
  devopsBuildAgentsNsg: false
  bastionNsg: true
  
  // GenAI App backing services (Search/Cosmos/Key Vault) are deployed in this example
  // with public networking enabled and IP allowlists.
  // Note: the AI Foundry component will also create its own associated Search/Cosmos/Key Vault.
  // These are separate resources.
  storageAccount: false
  keyVault: true
  cosmosDb: true
  searchService: true

  groundingWithBingSearch: false
  containerRegistry: false
  containerEnv: false
  containerApps: false
  buildVm: false
  jumpVm: true
  bastionHost: true
  appConfig: false
  apiManagement: false
  applicationGateway: false
  applicationGatewayPublicIp: false
  wafPolicy: false
  firewall: true
  userDefinedRoutes: true
}

param resourceIds = {}

param flagPlatformLandingZone = false

param firewallPrivateIp = '192.168.0.132'

param firewallPolicyDefinition = {
  name: 'afwp-sample'
  ruleCollectionGroups: [
    {
      name: 'rcg-jumpbox-egress'
      priority: 100
      ruleCollections: [
        {
          name: 'rc-allow-jumpbox-network'
          priority: 100
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'allow-jumpbox-all-egress'
              ruleType: 'NetworkRule'
              ipProtocols: [
                'Any'
              ]
              sourceAddresses: [
                '192.168.1.64/28'
              ]
              destinationAddresses: [
                '0.0.0.0/0'
              ]
              destinationPorts: [
                '*'
              ]
            }
          ]
        }
      ]
    }
    {
      name: 'rcg-foundry-agent-egress'
      priority: 110
      ruleCollections: [
        {
          name: 'rc-allow-foundry-agent-network'
          priority: 100
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'allow-azure-dns-udp'
              ruleType: 'NetworkRule'
              ipProtocols: [
                'UDP'
              ]
              sourceAddresses: [
                '192.168.0.0/27' // agent-subnet
                '192.168.1.0/27' // aca-env-subnet
              ]
              destinationAddresses: [
                '168.63.129.16'
              ]
              destinationPorts: [
                '53'
              ]
            }
            {
              name: 'allow-azure-dns-tcp'
              ruleType: 'NetworkRule'
              ipProtocols: [
                'TCP'
              ]
              sourceAddresses: [
                '192.168.0.0/27' // agent-subnet
                '192.168.1.0/27' // aca-env-subnet
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
                '192.168.0.0/27' // agent-subnet
                '192.168.1.0/27' // aca-env-subnet
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
                '192.168.0.0/27' // agent-subnet
                '192.168.1.0/27' // aca-env-subnet
              ]
              destinationAddresses: [
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
                '192.168.0.0/27' // agent-subnet
                '192.168.1.0/27' // aca-env-subnet
              ]
              destinationAddresses: [
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
                '192.168.0.0/27' // agent-subnet
                '192.168.1.0/27' // aca-env-subnet
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
                '192.168.0.0/27' // agent-subnet
                '192.168.1.0/27' // aca-env-subnet
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
          name: 'rc-allow-foundry-agent-app'
          priority: 110
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'allow-aca-platform-fqdns'
              ruleType: 'ApplicationRule'
              sourceAddresses: [
                '192.168.0.0/27' // agent-subnet
                '192.168.1.0/27' // aca-env-subnet
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'mcr.microsoft.com'
                '*.data.mcr.microsoft.com'
                'packages.aks.azure.com'
                'acs-mirror.azureedge.net'
              ]
            }
          ]
        }
      ]
    }
  ]
}

// AI Foundry: enable public networking but restrict to VNet CIDR + one public IP.
// If you are using Azure Firewall for egress, make `187.13.147.118` the firewall's egress Public IP.
// Note: Cosmos DB IP firewall rules do NOT support RFC1918 ranges (e.g., 192.168.0.0/23).
// For Cosmos DB, keep private access via Private Endpoint and only allowlist public IPs here.
param aiFoundryDefinition = {
  includeAssociatedResources: true
  aiFoundryConfiguration: {
    createCapabilityHosts: true
  }

  aiSearchConfiguration: {
    publicNetworkAccess: 'Enabled'
    networkRuleSet: {
      bypass: 'None'
      ipRules: [
        {
          value: '187.13.147.118'
        }
      ]
    }
  }

  cosmosDbConfiguration: {
    publicNetworkAccess: 'Enabled'
    ipRules: [
      '187.13.147.118'
    ]
  }

  storageAccountConfiguration: {
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
      ipRules: [
        {
          value: '187.13.147.118'
          action: 'Allow'
        }
      ]
      virtualNetworkRules: []
    }
  }

  keyVaultConfiguration: {
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        {
          value: '187.13.147.118'
        }
      ]
      virtualNetworkRules: []
    }
  }
}

// GenAI App (workload) backing services
// - Public networking enabled
// - Restricted to allowlisted public IP(s)
param aiSearchDefinition = {
  publicNetworkAccess: 'Enabled'
  sku: 'basic'
  networkRuleSet: {
    bypass: 'None'
    ipRules: [
      {
        value: '187.13.147.118'
      }
    ]
  }
}

param cosmosDbDefinition = {
  // Avoid zonal redundant account creation in regions/subscriptions with constrained AZ capacity.
  zoneRedundant: false

  networkRestrictions: {
    publicNetworkAccess: 'Enabled'
    ipRules: [
      '187.13.147.118'
    ]
  }

  // NOTE: The Cosmos DB AVM wrapper applies ipRules/virtualNetworkRules
  // only when at least one API resource (e.g., sqlDatabases) is declared.
  sqlDatabases: [
    {
      name: 'appdb'
      throughput: 400
    }
  ]
}

param keyVaultDefinition = {
  publicNetworkAccess: 'Enabled'
  networkAcls: {
    bypass: 'AzureServices'
    defaultAction: 'Deny'
    ipRules: [
      {
        value: '187.13.147.118'
      }
    ]
    virtualNetworkRules: []
  }
}
