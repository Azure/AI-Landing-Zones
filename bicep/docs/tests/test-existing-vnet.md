# Existing VNet Test (reuse an already-created VNet)

This guide provisions the landing zone into an **existing VNet** using the parameters in:
- [bicep/infra/sample.existing-vnet.bicepparam](../../infra/sample.existing-vnet.bicepparam)

Primary scenario validated by this guide:
- `flagPlatformLandingZone=false` (workload-owned networking)
- **VNet reuse**: the workload deployment reuses an **existing VNet** that already contains the required subnets
- The deployment creates **Private Endpoints**, **Private DNS Zones**, and **VNet links** as part of the workload (not platform-owned)

This runbook is written to match the default toggle set in the sample parameter file:

- Enabled (as shipped in the sample): `aiFoundry`, `cosmosDb`, `keyVault`, `storageAccount`, `appConfig`, `containerRegistry`, `containerEnv`, `logAnalytics`, `appInsights`, `firewall`, `bastionHost`, `jumpVm`, `userDefinedRoutes`
- Disabled (as shipped in the sample): `virtualNetwork` (VNet reuse), `searchService`, `apiManagement`, `applicationGateway`, `buildVm`, `containerApps`, `groundingWithBingSearch`

What you should expect after `azd provision` with the sample toggles:

- A reused VNet (created by you in Step 1)
- A jump VM + Bastion (for access)
- Azure Firewall + UDRs (forced tunneling test)
- Private Endpoints for enabled PaaS services (names vary)
- Private DNS zones + VNet links in the workload RG (since `flagPlatformLandingZone=false`)

Resource group scope note (split RGs):

- The existing VNet and its subnets live in a "networking RG" (created in Step 1)
- The landing zone workload resources live in a separate "workload RG" (set via `AZURE_RESOURCE_GROUP`)
- When the VNet is reused via `resourceIds.virtualNetworkResourceId`, VNet-bound operations (Azure Firewall, subnet associations)
  are deployed into the VNet's RG

Subscription scope note:

- For this runbook, the existing VNet must be in the SAME subscription used by the `azd` environment (`AZURE_SUBSCRIPTION_ID`).
  This deployment creates resources that attach to subnets (Private Endpoints, VM/NIC, Bastion, etc.), which must live in the same subscription as the VNet.

> Scope note: this is a test runbook. Adjust naming, IP ranges, and hardening for production.

## Prerequisites

- Permissions to create resources in the subscription (e.g., `Contributor`)
- Azure CLI authenticated: `az login`
- Bicep available in Azure CLI (usually built-in)
- AZD installed if you’ll use `azd provision` (recommended for this repo)
- A local clone of this repo (the `azd` workflow and file paths like `bicep/infra/main.bicepparam` require it)

Tip: run all commands from the repo root directory.

## Step 1 — Create the existing VNet and required subnets

### 1.1 Choose names and ranges

Pick values and use them consistently:

- Location: `eastus2` (recommended for parity with other tests; you can change it)
- Networking Resource Group (VNet RG): `rg-ailz-vnet-RANDOM_SUFFIX`
- VNet name: `vnet-existing-RANDOM_SUFFIX`

This runbook assumes the subnet layout from the sample parameter file:

- VNet address space: `192.168.0.0/22`
- Subnets:
  - `agent-subnet` `192.168.0.0/27` (delegation `Microsoft.App/environments`)
  - `pe-subnet` `192.168.0.32/27` (**Private Endpoints subnet**, with Private Endpoint network policies disabled)
  - `AzureBastionSubnet` `192.168.0.64/26`
  - `AzureFirewallSubnet` `192.168.0.128/26`
  - `jumpbox-subnet` `192.168.1.0/28`
  - `devops-agents-subnet` `192.168.1.32/27`
  - `aca-env-subnet` `192.168.2.0/23` (delegation `Microsoft.App/environments`)
  - `appgw-subnet` `192.168.0.192/27`
  - `apim-subnet` `192.168.0.224/27`

Important:
- Do not overlap this VNet range with any other VNet you intend to peer.
- Keep subnet names exactly as expected by the template.

In the "reuse VNet as-is" mode (this runbook), the template will reference subnets by name (for example, `.../subnets/pe-subnet`).
If the subnet does not exist with the expected name, deployment will fail.

Minimum required subnet properties for this runbook:
- `pe-subnet`: Private Endpoint network policies must be **Disabled**
- `agent-subnet` and `aca-env-subnet`: must be delegated to `Microsoft.App/environments`

### 1.2 Create the RG and VNet

```powershell
az group create --name rg-ailz-vnet-RANDOM_SUFFIX --location eastus2

az network vnet create --resource-group rg-ailz-vnet-RANDOM_SUFFIX --name vnet-existing-RANDOM_SUFFIX --address-prefixes 192.168.0.0/22
```

### 1.3 Create subnets

Create each subnet to match the sample. Use the commands below as a starting point (adjust if you change ranges).

```powershell
# agent-subnet (delegated to Container Apps managed environment)
az network vnet subnet create --resource-group rg-ailz-vnet-RANDOM_SUFFIX --vnet-name vnet-existing-RANDOM_SUFFIX --name agent-subnet --address-prefixes 192.168.0.0/27 --delegations Microsoft.App/environments

# pe-subnet (Private Endpoints)
# IMPORTANT: Private Endpoint network policies must be Disabled
az network vnet subnet create --resource-group rg-ailz-vnet-RANDOM_SUFFIX --vnet-name vnet-existing-RANDOM_SUFFIX --name pe-subnet --address-prefixes 192.168.0.32/27 --disable-private-endpoint-network-policies true

# AzureBastionSubnet
az network vnet subnet create --resource-group rg-ailz-vnet-RANDOM_SUFFIX --vnet-name vnet-existing-RANDOM_SUFFIX --name AzureBastionSubnet --address-prefixes 192.168.0.64/26

# AzureFirewallSubnet
az network vnet subnet create --resource-group rg-ailz-vnet-RANDOM_SUFFIX --vnet-name vnet-existing-RANDOM_SUFFIX --name AzureFirewallSubnet --address-prefixes 192.168.0.128/26

# jumpbox-subnet
az network vnet subnet create --resource-group rg-ailz-vnet-RANDOM_SUFFIX --vnet-name vnet-existing-RANDOM_SUFFIX --name jumpbox-subnet --address-prefixes 192.168.1.0/28

# devops-agents-subnet
az network vnet subnet create --resource-group rg-ailz-vnet-RANDOM_SUFFIX --vnet-name vnet-existing-RANDOM_SUFFIX --name devops-agents-subnet --address-prefixes 192.168.1.32/27

# aca-env-subnet (delegated)
az network vnet subnet create --resource-group rg-ailz-vnet-RANDOM_SUFFIX --vnet-name vnet-existing-RANDOM_SUFFIX --name aca-env-subnet --address-prefixes 192.168.2.0/23 --delegations Microsoft.App/environments

# appgw-subnet
az network vnet subnet create --resource-group rg-ailz-vnet-RANDOM_SUFFIX --vnet-name vnet-existing-RANDOM_SUFFIX --name appgw-subnet --address-prefixes 192.168.0.192/27

# apim-subnet
az network vnet subnet create --resource-group rg-ailz-vnet-RANDOM_SUFFIX --vnet-name vnet-existing-RANDOM_SUFFIX --name apim-subnet --address-prefixes 192.168.0.224/27
```

> Note on service endpoints: the sample parameter file includes some service endpoints inside `existingVNetSubnetsDefinition`. Depending on template behavior, those may be set by the deployment itself. For this runbook, focus on getting the subnet names/ranges and the PE policy right.

> Note on subnet updates: with the sample toggles, `userDefinedRoutes=true` attaches route tables to subnets.
> That means the deployment will update existing subnets (associations only) even though the VNet itself is reused.

### 1.4 Verify subnet creation

```powershell
az network vnet subnet list --resource-group rg-ailz-vnet-RANDOM_SUFFIX --vnet-name vnet-existing-RANDOM_SUFFIX -o table
```

### 1.5 Capture the VNet resource ID for Step 2

```powershell
$vnetId = az network vnet show --resource-group rg-ailz-vnet-RANDOM_SUFFIX --name vnet-existing-RANDOM_SUFFIX --query id -o tsv
$vnetId
```

## Step 2 — Deploy the workload (reuse the existing VNet)

This scenario uses:
- `flagPlatformLandingZone=false`
- `deployToggles.virtualNetwork=false` (do not create a new VNet)
- `resourceIds.virtualNetworkResourceId=<your existing VNet resource ID>`

### 2.1 Prepare parameters

Start from:
- [bicep/infra/sample.existing-vnet.bicepparam](../../infra/sample.existing-vnet.bicepparam)

Required edits for your environment:
- Set `resourceIds.virtualNetworkResourceId` to your VNet resource ID (from Step 1.5)
- Ensure `deployToggles.virtualNetwork = false`
- Keep `flagPlatformLandingZone = false`

Important:
- Do **not** use `existingVNetSubnetsDefinition` in this mode.
  If you set it, the template will try to create/update subnets (which is not what this runbook is validating).

Forced tunneling note:
- The sample enables `deployToggles.userDefinedRoutes = true` and `deployToggles.firewall = true`.
- The `firewallPrivateIp` must match the **Azure Firewall private IP** in `AzureFirewallSubnet`.
  - If you keep `AzureFirewallSubnet` as `192.168.0.128/26`, the test guidance assumes the first usable IP is `192.168.0.132`.
  - If you change the firewall subnet prefix, update `firewallPrivateIp` accordingly.
- If you use different subnet CIDRs than the sample (for example, a different `jumpbox-subnet` range), update `firewallPolicyDefinition.ruleCollectionGroups[*].ruleCollections[*].rules[*].sourceAddresses` to match your actual subnet ranges.

### 2.2 Deploy using AZD (recommended)

1) Initialize the environment:

```powershell
azd init -e ailz-RANDOM_SUFFIX
```

2) Set environment variables (PowerShell):

```powershell
$env:AZURE_LOCATION = "eastus2"
$env:AZURE_RESOURCE_GROUP = "rg-ailz-RANDOM_SUFFIX"  # workload RG
$env:AZURE_SUBSCRIPTION_ID = "00000000-1111-2222-3333-444444444444"  # must match the existing VNet subscription
```

3) Copy the sample parameter file into the active parameter file used by `azd`:

```powershell
Copy-Item bicep/infra/sample.existing-vnet.bicepparam bicep/infra/main.bicepparam -Force
```

4) Edit `bicep/infra/main.bicepparam`:

- Update `resourceIds.virtualNetworkResourceId`
- (Optional) adjust toggles to reduce deployed services if you want a faster test

5) Provision:

```powershell
azd provision
```

## Step 3 — Validate networking + Private Link DNS

### 3.1 Validate Private Endpoints exist

In the workload Resource Group, confirm that Private Endpoints were created (names vary by toggle set).

Azure CLI:

```powershell
az network private-endpoint list --resource-group rg-ailz-RANDOM_SUFFIX -o table
```

### 3.2 Validate Private DNS Zones exist and are linked

Because `flagPlatformLandingZone=false`, this scenario expects the deployment to create and manage Private DNS Zones.

With the sample toggles, you should expect **multiple** `privatelink.*` zones for the enabled services (Storage/Key Vault/Cosmos/ACR/AI Foundry).
Because `searchService=false` in the sample, you should **not** expect Search Private Endpoints or `privatelink.search.windows.net`.

```powershell
az network private-dns zone list --resource-group rg-ailz-RANDOM_SUFFIX -o table

# With the sample toggles (aiFoundry=true), this zone should exist:
az network private-dns link vnet list --resource-group rg-ailz-RANDOM_SUFFIX --zone-name privatelink.openai.azure.com -o table
```

### 3.3 Validate DNS records exist (A records)

If Private DNS Zone Groups are enabled by the deployment, `A` records should be present automatically.

Example checks:

```powershell
az network private-dns record-set a list --resource-group rg-ailz-RANDOM_SUFFIX --zone-name privatelink.openai.azure.com -o table
```

If you don’t see the expected `A` records:
- Check each Private Endpoint → **DNS configuration** to see which `*.privatelink.*` FQDNs exist
- Confirm the matching Private DNS zone exists and is linked to the VNet

### 3.4 Validate routes if forced tunneling is enabled

If the sample toggles are kept (`userDefinedRoutes=true`), confirm route tables exist and the default route points to the firewall.

```powershell
az network route-table list --resource-group rg-ailz-RANDOM_SUFFIX -o table
```

To confirm that the route table is associated to the subnets in the VNet RG:

```powershell
az network vnet subnet show --resource-group rg-ailz-vnet-RANDOM_SUFFIX --vnet-name vnet-RANDOM_SUFFIX --name jumpbox-subnet --query routeTable.id -o tsv
```

## Step 4 — Validate access (Bastion + Jump VM)

Because the Jump VM password is auto-generated during deployment, the easiest way to access it is to **reset the password in the Azure Portal** before connecting.

1) Azure Portal → Resource Group `rg-ailz-RANDOM_SUFFIX`

2) Open the Jump VM (the `*-jmp` VM) → **Reset password**

3) Choose **Reset password**, set:
- Username: `azureuser` (unless you overrode `jumpVmDefinition.adminUsername`)
- Password: set a strong password

4) Save

Then connect using Bastion:
- Resource Group: `rg-ailz-RANDOM_SUFFIX`
- VM: the `*-jmp` VM
- Connect using Bastion (RDP)

### 4.1 (Inside the Jump VM) Validate DNS resolution for created services

Goal: confirm that service hostnames resolve to **private IPs** via the `privatelink.*` Private DNS Zones.

From your local machine, capture the Private Endpoint FQDNs created by the deployment:

```powershell
# List all Private Endpoints expect to resolve
az network private-endpoint list --resource-group $rg --query "[].{name:name}" -o jsonc

# Extract `fqdns from the DNS zone groups:
$peName = '<private-endpoint-name>'
az network private-endpoint dns-zone-group list --resource-group $rg --endpoint-name $peName --query "[].privateDnsZoneConfigs[].recordSets[].fqdn" -o tsv
```

Then, inside the Jump VM (PowerShell), run `nslookup` for the **exact FQDNs** shown in the `customDnsConfigs[].fqdn` output above.

Examples:

```powershell
nslookup <fqdn-from-customDnsConfigs>

# Optional: show the CNAME chain (useful for troubleshooting)
Resolve-DnsName <fqdn-from-customDnsConfigs> | Format-List
```

Expected outcome:
- Each lookup returns a **private IP address** (typically in your VNet range)
- `Resolve-DnsName` shows a CNAME into the matching `privatelink.*` zone

## Cleanup

Delete the workload resource group:

```powershell
az group delete --name rg-ailz-RANDOM_SUFFIX --yes --no-wait
```

Delete the networking resource group (VNet RG) if this was a test-only VNet:

```powershell
az group delete --name rg-ailz-vnet-RANDOM_SUFFIX --yes --no-wait
```
