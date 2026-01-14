using './main.bicep'

// ACA minimal: deploys 1 Container Apps Managed Environment + 1 Container App using main.bicep.
//
// Notes:
// - Keeps everything else disabled.
// - Uses a new VNet (so the environment can use the default `aca-env-subnet`).
// - Uses internal-only Container Apps (no public ingress / no public environment endpoints).
// - Deploys Jump VM + Bastion for access/testing.
// - Deploys Azure Firewall + UDRs to force egress through the firewall (forced tunneling).

param deployToggles = {
  aiFoundry: false
  logAnalytics: false
  appInsights: false
  virtualNetwork: true
  peNsg: true
  agentNsg: false
  acaEnvironmentNsg: false
  apiManagementNsg: false
  applicationGatewayNsg: false
  jumpboxNsg: true
  devopsBuildAgentsNsg: false
  bastionNsg: true
  keyVault: false
  storageAccount: false
  cosmosDb: false
  searchService: false
  groundingWithBingSearch: false
  containerRegistry: false
  containerEnv: true
  containerApps: true
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

// Treat as PLZ for DNS (no PDNS zones created by this template).
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
                '192.168.1.0/27' // aca-env-subnet
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

param containerAppEnvDefinition = {
  name: 'cae-aca-minimal'

  // Keep it minimal and avoid WAF-compliance conditional fields.
  zoneRedundant: false

  // Internal-only environment endpoints.
  publicNetworkAccess: 'Disabled'
  internal: true
}

param containerAppsList = [
  {
    name: 'ca-aca-helloworld'

    activeRevisionsMode: 'Single'

    // Internal-only ingress.
    ingressExternal: false
    ingressTargetPort: 80
    ingressAllowInsecure: true
  }
]
