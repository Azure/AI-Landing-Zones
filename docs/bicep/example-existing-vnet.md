# AI LZ using an existing VNet

This walkthrough validates deploying the AI Landing Zone into a VNet that already exists. It is intended for learning and validation, and it follows the same expectations described in the networking and platform guidance.

**Sample parameter files**

| File | Scenario | What happens to the VNet and subnets |
|---|---|---|
| [bicep/infra/sample.existing-vnet.bicepparam](https://github.com/Azure/AI-Landing-Zones/blob/main/bicep/infra/sample.existing-vnet.bicepparam) | Scenario A | Reuses an existing VNet and expects the required subnets to already exist. |
| [bicep/infra/sample.existing-vnet-create-subnets.bicepparam](https://github.com/Azure/AI-Landing-Zones/blob/main/bicep/infra/sample.existing-vnet-create-subnets.bicepparam) | Scenario B | Reuses an existing VNet and creates or updates the required subnets in that VNet. |

**What this walkthrough validates**

| Capability | Notes |
|---|---|
| Existing VNet reuse | Uses `resourceIds.virtualNetworkResourceId` and does not create a new VNet. |
| Workload-owned private connectivity | Creates Private Endpoints and, in this scenario, also creates Private DNS zones and VNet links. |
| Forced tunneling validation | When enabled by toggles, deploys UDRs and routes egress through Azure Firewall. |
| Split resource groups | Keeps the VNet in a dedicated networking resource group and deploys workload resources to a separate workload resource group. |

This walkthrough assumes standalone behavior for platform integration, with `flagPlatformLandingZone` set to `false`.

**Key settings (from the samples)**

| Setting | Value | Notes |
|---|---|---|
| `flagPlatformLandingZone` | `false` | The workload deployment owns private DNS zones and links for this walkthrough. |
| `deployToggles.virtualNetwork` | `false` | The deployment reuses an existing VNet. |
| `resourceIds.virtualNetworkResourceId` | Required | Must be the full resource ID of the existing VNet. |
| `existingVNetSubnetsDefinition` | Optional | Use only for Scenario B, when the deployment should create or update subnets. |

**Scope and assumptions**

The existing VNet must be in the same subscription used by the environment. Resources that attach to subnets, such as Private Endpoints, NICs, Bastion, and route table associations, must be deployed in the same subscription as the VNet.

**Prerequisites**

You need permissions to create resources in the target subscription, and you must be signed in with Azure CLI. This walkthrough uses Azure Developer CLI, so install `azd` and run the commands from the repository root.

**Step 1: Prepare the existing VNet**

Use one of the scenarios below. Both scenarios use the same default VNet address space and subnet layout.

Scenario A expects the required subnets to already exist. Scenario B creates or updates the subnets as part of the deployment.

**Default addressing used by the samples**

VNet address space is `192.168.0.0/23`.

| Subnet name | CIDR | Notes |
|---|---|---|
| `agent-subnet` | `192.168.0.0/27` | Delegated to `Microsoft.App/environments`. |
| `pe-subnet` | `192.168.0.32/27` | Private endpoint network policies must be disabled. |
| `AzureBastionSubnet` | `192.168.0.64/26` | Required minimum size for Bastion. |
| `AzureFirewallSubnet` | `192.168.0.128/26` | Required minimum size for Azure Firewall. |
| `appgw-subnet` | `192.168.0.192/27` | Optional depending on toggles. |
| `apim-subnet` | `192.168.0.224/27` | Optional depending on toggles. |
| `aca-env-subnet` | `192.168.1.0/27` | Delegated to `Microsoft.App/environments`. |
| `devops-agents-subnet` | `192.168.1.32/27` | Build agents subnet. |
| `jumpbox-subnet` | `192.168.1.64/28` | Jump VM subnet. |

**Scenario A: create the VNet and subnets up front**

Choose a location and names that you will reuse across commands.

```powershell
$location = "eastus2"
$netRg = "rg-ailz-vnet-RANDOM_SUFFIX"
$vnetName = "vnet-existing-RANDOM_SUFFIX"
```

Create the networking resource group and VNet.

```powershell
az group create --name $netRg --location $location
az network vnet create --resource-group $netRg --name $vnetName --address-prefixes 192.168.0.0/23
```

Create the required subnets.

```powershell
az network vnet subnet create --resource-group $netRg --vnet-name $vnetName --name agent-subnet --address-prefixes 192.168.0.0/27 --delegations Microsoft.App/environments

az network vnet subnet create --resource-group $netRg --vnet-name $vnetName --name pe-subnet --address-prefixes 192.168.0.32/27 --disable-private-endpoint-network-policies true

az network vnet subnet create --resource-group $netRg --vnet-name $vnetName --name AzureBastionSubnet --address-prefixes 192.168.0.64/26
az network vnet subnet create --resource-group $netRg --vnet-name $vnetName --name AzureFirewallSubnet --address-prefixes 192.168.0.128/26

az network vnet subnet create --resource-group $netRg --vnet-name $vnetName --name appgw-subnet --address-prefixes 192.168.0.192/27
az network vnet subnet create --resource-group $netRg --vnet-name $vnetName --name apim-subnet --address-prefixes 192.168.0.224/27

az network vnet subnet create --resource-group $netRg --vnet-name $vnetName --name aca-env-subnet --address-prefixes 192.168.1.0/27 --delegations Microsoft.App/environments
az network vnet subnet create --resource-group $netRg --vnet-name $vnetName --name devops-agents-subnet --address-prefixes 192.168.1.32/27
az network vnet subnet create --resource-group $netRg --vnet-name $vnetName --name jumpbox-subnet --address-prefixes 192.168.1.64/28
```

Verify subnets and capture the VNet resource ID.

```powershell
az network vnet subnet list --resource-group $netRg --vnet-name $vnetName -o table

$vnetId = az network vnet show --resource-group $netRg --name $vnetName --query id -o tsv
$vnetId
```

**Scenario B: create only the VNet and let the template create or update subnets**

Create the networking resource group and VNet.

```powershell
$location = "eastus2"
$netRg = "rg-ailz-vnet-RANDOM_SUFFIX"
$vnetName = "vnet-existing-RANDOM_SUFFIX"

az group create --name $netRg --location $location
az network vnet create --resource-group $netRg --name $vnetName --address-prefixes 192.168.0.0/23

$vnetId = az network vnet show --resource-group $netRg --name $vnetName --query id -o tsv
$vnetId
```

If you already have a VNet that matches the expected layout, skip the creation commands and only capture the VNet resource ID.

**Step 2: Deploy the workload with azd**

Initialize an azd environment.

```powershell
azd init -e ailz-existing-vnet-RANDOM_SUFFIX
```

Set environment variables.

```powershell
$env:AZURE_LOCATION = "eastus2"
$env:AZURE_RESOURCE_GROUP = "rg-ailz-RANDOM_SUFFIX"
$env:AZURE_SUBSCRIPTION_ID = "00000000-1111-2222-3333-444444444444"

$workloadRg = $env:AZURE_RESOURCE_GROUP
```

Copy the sample parameter file into the active parameter file used by `azd`.

Scenario A uses the reuse-as-is sample.

```powershell
Copy-Item bicep/infra/sample.existing-vnet.bicepparam bicep/infra/main.bicepparam -Force
```

Scenario B uses the create-update-subnets sample.

```powershell
Copy-Item bicep/infra/sample.existing-vnet-create-subnets.bicepparam bicep/infra/main.bicepparam -Force
```

Edit `bicep/infra/main.bicepparam` and set `resourceIds.virtualNetworkResourceId` to `$vnetId`.

For Scenario A, do not set `existingVNetSubnetsDefinition`.

For Scenario B, provide an `existingVNetSubnetsDefinition` block with the subnet layout you want the deployment to create or update.

```bicep
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
```

Provision.

```powershell
azd provision
```

If forced tunneling is enabled, ensure `firewallPrivateIp` matches the private IP assigned to Azure Firewall. With the default `AzureFirewallSubnet` prefix, the common value is `192.168.0.132`, but you should always confirm the actual IP in your environment.

**Validation**

Validate that private endpoints were created in the workload resource group.

```powershell
az network private-endpoint list --resource-group $workloadRg -o table
```

Because this walkthrough uses `flagPlatformLandingZone` set to `false`, validate that private DNS zones exist and are linked.

```powershell
az network private-dns zone list --resource-group $workloadRg -o table

az network private-dns link vnet list --resource-group $workloadRg --zone-name privatelink.openai.azure.com -o table
```

Validate that A records exist.

```powershell
az network private-dns record-set a list --resource-group $workloadRg --zone-name privatelink.openai.azure.com -o table
```

If forced tunneling is enabled, validate that route tables exist and are associated with the expected subnets.

```powershell
az network route-table list --resource-group $workloadRg -o table
az network vnet subnet show --resource-group $netRg --vnet-name $vnetName --name jumpbox-subnet --query routeTable.id -o tsv
```

Validate access through Bastion and the Jump VM.

Reset the Jump VM password in the Azure portal and connect using Bastion. Then, from inside the Jump VM, validate DNS resolution for your created services.

```powershell
Resolve-DnsName login.microsoftonline.com
Test-NetConnection login.microsoftonline.com -Port 443
```

To validate private DNS resolution for specific Private Endpoints, list the FQDNs associated with a Private Endpoint and test resolution inside the Jump VM.

```powershell
$peName = "<private-endpoint-name>"
az network private-endpoint dns-zone-group list --resource-group $workloadRg --endpoint-name $peName --query "[].privateDnsZoneConfigs[].recordSets[].fqdn" -o tsv
```

**Cleanup**

Delete the workload resource group.

```powershell
az group delete --name $workloadRg --yes --no-wait
```

If the VNet was created only for this walkthrough, delete the networking resource group.

```powershell
az group delete --name $netRg --yes --no-wait
```