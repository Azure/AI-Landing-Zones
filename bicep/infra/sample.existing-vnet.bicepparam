using './main.bicep'

// Existing VNet: creates the landing zone subnets inside an existing VNet.
// Required: set `existingVNetSubnetsDefinition.existingVNetName`.

param deployToggles = {
  aiFoundry: true
  logAnalytics: true
  appInsights: true
  containerEnv: true
  containerRegistry: true
  cosmosDb: true
  searchService: false
  keyVault: true
  storageAccount: true
  appConfig: true
  apiManagement: false
  applicationGateway: false
  applicationGatewayPublicIp: false
  firewall: true
  wafPolicy: false
  buildVm: false
  bastionHost: true
  jumpVm: true
  agentNsg: true
  peNsg: true
  applicationGatewayNsg: false
  apiManagementNsg: false
  acaEnvironmentNsg: true
  jumpboxNsg: true
  devopsBuildAgentsNsg: true
  bastionNsg: true
  virtualNetwork: false
  containerApps: false
  groundingWithBingSearch: false
  userDefinedRoutes: true
}

param existingVNetSubnetsDefinition = {
  existingVNetName: 'your-existing-vnet-name'
  useDefaultSubnets: false
  subnets: [
    {
      name: 'agent-subnet'
      addressPrefix: '192.168.0.0/27'
      delegation: 'Microsoft.App/environments'
        serviceEndpoints: [
          'Microsoft.CognitiveServices'
        ]
    }
    {
      name: 'pe-subnet'
      addressPrefix: '192.168.0.32/27'
        serviceEndpoints: [
          'Microsoft.AzureCosmosDB'
        ]
      privateEndpointNetworkPolicies: 'Disabled'
    }
    {
      name: 'aca-env-subnet'
      addressPrefix: '192.168.2.0/23'
      delegation: 'Microsoft.App/environments'
        serviceEndpoints: [
          'Microsoft.AzureCosmosDB'
        ]
    }
    {
      name: 'devops-agents-subnet'
      addressPrefix: '192.168.1.32/27'
    }
    {
      name: 'AzureBastionSubnet'
      addressPrefix: '192.168.0.64/26'
    }
    {
      name: 'AzureFirewallSubnet'
      addressPrefix: '192.168.0.128/26'
    }
    {
      name: 'jumpbox-subnet'
      addressPrefix: '192.168.1.0/28'
    }
    {
      name: 'appgw-subnet'
      addressPrefix: '192.168.0.192/27'
    }
    {
      name: 'apim-subnet'
      addressPrefix: '192.168.0.224/27'
    }
  ]
}

param resourceIds = {}

param flagPlatformLandingZone = false

// Required for forced tunneling: Azure Firewall private IP (next hop).
// With the default subnet layout, Azure Firewall is assigned the first usable IP in AzureFirewallSubnet (192.168.0.128/26) => 192.168.0.132.
param firewallPrivateIp = '192.168.0.132'

// Default egress for Jump VM (jumpbox-subnet) via Azure Firewall Policy.
// - DNS to Azure DNS (168.63.129.16) on TCP/UDP 53
// - Web to internet on TCP 80/443
param firewallPolicyDefinition = {
  name: 'afwp-sample'
  ruleCollectionGroups: [
    {
      name: 'rcg-jumpbox-egress'
      priority: 100
      ruleCollections: [
        {
          name: 'rc-allow-dns'
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
                '192.168.1.0/28'
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
                '192.168.1.0/28'
              ]
              destinationAddresses: [
                '168.63.129.16'
              ]
              destinationPorts: [
                '53'
              ]
            }
          ]
        }
        {
          name: 'rc-allow-web'
          priority: 200
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'allow-https-out'
              ruleType: 'NetworkRule'
              ipProtocols: [
                'TCP'
              ]
              sourceAddresses: [
                '192.168.1.0/28'
              ]
              destinationAddresses: [
                '*'
              ]
              destinationPorts: [
                '443'
              ]
            }
            {
              name: 'allow-http-out'
              ruleType: 'NetworkRule'
              ipProtocols: [
                'TCP'
              ]
              sourceAddresses: [
                '192.168.1.0/28'
              ]
              destinationAddresses: [
                '*'
              ]
              destinationPorts: [
                '80'
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
          name: 'rc-allow-foundry-agent'
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
                '192.168.2.0/23' // aca-env-subnet
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
                '192.168.2.0/23' // aca-env-subnet
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
                '192.168.2.0/23' // aca-env-subnet
              ]
              destinationAddresses: [
                'AzureActiveDirectory'
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
                '192.168.2.0/23' // aca-env-subnet
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
                '192.168.2.0/23' // aca-env-subnet
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
            {
              name: 'allow-aca-platform-fqdns'
              ruleType: 'ApplicationRule'
              sourceAddresses: [
                '192.168.0.0/27' // agent-subnet
                '192.168.2.0/23' // aca-env-subnet
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

// Optional (subscription-scoped): enable Defender for AI pricing.
// param enableDefenderForAI = true
