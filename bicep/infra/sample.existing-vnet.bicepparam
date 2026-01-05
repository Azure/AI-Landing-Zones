using './main.bicep'

// Existing VNet (reuse as-is): deploy the landing zone into an already-created VNet.
// In this mode you provide `resourceIds.virtualNetworkResourceId` and the template will
// reference subnets by name.
//
// Note on subnet changes:
// - If you enable features that require subnet association updates (for example `userDefinedRoutes=true`),
//   the template will update the existing subnets to attach route tables / NSGs / delegations as needed.
// - If you want a strict "no subnet modifications" deployment, keep `userDefinedRoutes=false` and
//   provide pre-configured NSG/UDR/delegations on the subnets.
//
// IMPORTANT: the existing VNet must already contain the required subnets with the expected names.
// With the default toggle set below, you should have (at minimum):
// - agent-subnet (delegated to Microsoft.App/environments)
// - aca-env-subnet (delegated to Microsoft.App/environments)
// - pe-subnet (Private Endpoint subnet, with Private Endpoint network policies Disabled)
// - jumpbox-subnet
// - AzureBastionSubnet
// - AzureFirewallSubnet
// - devops-agents-subnet
// - appgw-subnet (even if Application Gateway is disabled; safe to keep for parity)
// - apim-subnet (even if APIM is disabled; safe to keep for parity)

// Addressing assumption (matches main.bicep defaults):
// - VNet address space: 192.168.0.0/22
// - Subnets:
//   - agent-subnet:        192.168.0.0/27
//   - pe-subnet:           192.168.0.32/27
//   - AzureBastionSubnet:  192.168.0.64/26
//   - AzureFirewallSubnet: 192.168.0.128/26
//   - jumpbox-subnet:      192.168.1.0/28
//   - devops-agents-subnet:192.168.1.32/27
//   - aca-env-subnet:      192.168.2.0/23
//   - appgw-subnet:        192.168.0.192/27
//   - apim-subnet:         192.168.0.224/27
//
// Why this matters: the `firewallPolicyDefinition` below contains `sourceAddresses` examples that are
// intentionally aligned to these subnet ranges (for example, jumpbox-subnet = 192.168.1.0/28).
// If your existing VNet uses different CIDRs, update the `sourceAddresses` to match your subnets.

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

param resourceIds = {
  // Required for VNet reuse: full resource ID of the existing VNet.
  // Example:
  // '/subscriptions/00000000-1111-2222-3333-444444444444/resourceGroups/rg-ailz-vnet-123/providers/Microsoft.Network/virtualNetworks/vnet-existing-123'
  virtualNetworkResourceId: '/subscriptions/00000000-1111-2222-3333-444444444444/resourceGroups/<existing-resource-group>/providers/Microsoft.Network/virtualNetworks/<existing-vnet-name>'
}

// Cross-resource-group note:
// If your VNet is in a different resource group than the workload deployment RG, the template will deploy
// VNet-bound resources (like Azure Firewall, its Public IP, and subnet associations) into the VNet's RG.
// Ensure the deploying identity has permissions on BOTH resource groups.

param flagPlatformLandingZone = false

// Required for forced tunneling: Azure Firewall private IP (next hop).
// With the default subnet layout, Azure Firewall is assigned the first usable IP in AzureFirewallSubnet (192.168.0.128/26) => 192.168.0.132.
param firewallPrivateIp = '192.168.0.132'

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

// Optional (subscription-scoped): enable Defender for AI pricing.
// param enableDefenderForAI = true
