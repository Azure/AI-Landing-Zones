using './main.bicep'

// Existing VNet (create/update subnets): deploy the landing zone into an existing VNet and let the
// template create/update the required subnets in that VNet.
//
// Single source of truth:
// - Identify the VNet ONLY via `resourceIds.virtualNetworkResourceId`.
// - Provide subnet definitions ONLY via `existingVNetSubnetsDefinition`.
//
// Cross-resource-group note:
// If your VNet is in a different resource group than the workload deployment RG, the template will deploy
// subnet operations (and other VNet-bound resources like Azure Firewall) into the VNet's RG derived from the
// VNet resource ID.

// Addressing assumption (matches sample.existing-vnet.bicepparam and this runbook):
// - VNet address space: 192.168.0.0/23
// - Subnets:
//   - agent-subnet:        192.168.0.0/27
//   - pe-subnet:           192.168.0.32/27
//   - AzureBastionSubnet:  192.168.0.64/26
//   - AzureFirewallSubnet: 192.168.0.128/26
//   - appgw-subnet:        192.168.0.192/27
//   - apim-subnet:         192.168.0.224/27
//   - aca-env-subnet:      192.168.1.0/27
//   - devops-agents-subnet:192.168.1.32/27
//   - jumpbox-subnet:      192.168.1.64/28

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
  virtualNetworkResourceId: '/subscriptions/00000000-1111-2222-3333-444444444444/resourceGroups/rg-ailz-vnet-123/providers/Microsoft.Network/virtualNetworks/vnet-existing-123'
}

param flagPlatformLandingZone = false

// Create/update required subnets in the existing VNet.
param existingVNetSubnetsDefinition = {
  useDefaultSubnets: false
  subnets: [
    {
      name: 'agent-subnet'
      addressPrefix: '192.168.0.0/27'
      delegation: 'Microsoft.App/environments'
      serviceEndpoints: ['Microsoft.CognitiveServices']
    }
    {
      name: 'pe-subnet'
      addressPrefix: '192.168.0.32/27'
      privateEndpointNetworkPolicies: 'Disabled'
      serviceEndpoints: ['Microsoft.AzureCosmosDB']
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
      name: 'appgw-subnet'
      addressPrefix: '192.168.0.192/27'
    }
    {
      name: 'apim-subnet'
      addressPrefix: '192.168.0.224/27'
    }
    {
      name: 'aca-env-subnet'
      addressPrefix: '192.168.1.0/27'
      delegation: 'Microsoft.App/environments'
      serviceEndpoints: ['Microsoft.AzureCosmosDB']
    }
    {
      name: 'devops-agents-subnet'
      addressPrefix: '192.168.1.32/27'
    }
    {
      name: 'jumpbox-subnet'
      addressPrefix: '192.168.1.64/28'
    }
  ]
}

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
        {
          name: 'rc-allow-jumpbox-app'
          priority: 110
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'allow-jumpbox-app-egress'
              ruleType: 'ApplicationRule'
              sourceAddresses: [
                '192.168.1.64/28'
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'aka.ms'
                'download.visualstudio.microsoft.com'
                'download.microsoft.com'
                'go.microsoft.com'
                'packages.microsoft.com'
                'vscode.download.prss.microsoft.com'
                'vscode.download.prss.microsoft.com.edgesuite.net'
                'vscode.blob.core.windows.net'
                'azurecliprod.blob.core.windows.net'
                'releases.hashicorp.com'
                'checkpoint-api.hashicorp.com'
                'api.github.com'
                'github.com'
                'objects.githubusercontent.com'
                'raw.githubusercontent.com'
                'codeload.github.com'
                'pip.pypa.io'
                'pypi.org'
                'files.pythonhosted.org'
                'registry.npmjs.org'
                'nodejs.org'
                'dl.k8s.io'
                'packages.cloud.google.com'
                'gcr.io'
                'ghcr.io'
                'mcr.microsoft.com'
                'docker.io'
                'production.cloudflare.docker.com'
                'auth.docker.io'
                'index.docker.io'
                'dl-cdn.alpinelinux.org'
                'deb.debian.org'
                'security.debian.org'
                'archive.ubuntu.com'
                'security.ubuntu.com'
                'chocolatey.org'
                'community.chocolatey.org'
                'repo.spongepowered.org'
                'dist.nuget.org'
                'nuget.org'
                'api.nuget.org'
                'www.powershellgallery.com'
                'psg-prod-eastus.azureedge.net'
                'prod-powershellgallery-cache.azureedge.net'
                'onegetcdn.azureedge.net'
              ]
            }
          ]
        }
      ]
    }
  ]
}
