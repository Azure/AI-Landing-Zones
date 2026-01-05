using './main.bicep'

// Platform Landing Zone mode: integrate workload (spoke) with an existing hub (platform).

// Spoke VNet/subnets in this sample:
// - This sample keeps `resourceIds = {}` and sets `deployToggles.virtualNetwork = true`, so the workload deployment
//   will CREATE the spoke VNet and its subnets.
// - Because this sample does NOT set `vNetDefinition`, the template uses the main.bicep defaults:
//   - VNet address space: 192.168.0.0/22
//   - Subnets:
//     - agent-subnet:        192.168.0.0/27
//     - pe-subnet:           192.168.0.32/27
//     - AzureBastionSubnet:  192.168.0.64/26
//     - AzureFirewallSubnet: 192.168.0.128/26 (note: in PLZ the firewall is in the HUB; this subnet may exist but no spoke firewall is deployed)
//     - jumpbox-subnet:      192.168.1.0/28
//     - devops-agents-subnet:192.168.1.32/27
//     - aca-env-subnet:      192.168.2.0/23
//     - appgw-subnet:        192.168.0.192/27
//     - apim-subnet:         192.168.0.224/27
//
// Why this matters: the `firewallPolicyDefinition` below contains `sourceAddresses` examples that assume the subnet CIDRs above
// (for example, jumpbox-subnet = 192.168.1.0/28; agent-subnet = 192.168.0.0/27).
// If you override `vNetDefinition` / subnet CIDRs, update the `sourceAddresses` in the firewall policy to match.

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
  keyVault: true
  storageAccount: true
  cosmosDb: false
  searchService: false
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
  // In Platform Landing Zone mode, the firewall lives in the hub.
  // This workload template should not deploy a spoke firewall.
  firewall: false
  userDefinedRoutes: true
}

param resourceIds = {}

param flagPlatformLandingZone = true

// Required for forced tunneling: hub Azure Firewall private IP (next hop).
// For the test platform deployed via bicep/tests/platform.bicep, this is typically 10.0.0.4.
param firewallPrivateIp = '10.0.0.4'

param hubVnetPeeringDefinition = {
  peerVnetResourceId: '/subscriptions/<hub-subscription-id>/resourceGroups/<hub-resource-group>/providers/Microsoft.Network/virtualNetworks/<hub-vnet-name>'
}


// Default egress for Jump VM (jumpbox-subnet) via Azure Firewall Policy.
// This is a strict allowlist designed to keep bootstrap tooling working under forced tunneling.
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
                '192.168.1.0/28'
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
              name: 'allow-azure-resource-manager-https'
              ruleType: 'NetworkRule'
              ipProtocols: [
                'TCP'
              ]
              sourceAddresses: [
                '192.168.0.0/27' // agent-subnet
                '192.168.2.0/23' // aca-env-subnet
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
                '192.168.0.0/27' // agent-subnet
                '192.168.2.0/23' // aca-env-subnet
              ]
              destinationAddresses: [
                // Broad Azure public-cloud endpoints (helps avoid TLS failures caused by missing ancillary Azure endpoints).
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
