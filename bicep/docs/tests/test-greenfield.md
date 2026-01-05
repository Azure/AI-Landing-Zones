# Greenfield Test (create a new VNet)

This guide provisions the landing zone in a **new (greenfield) VNet** using the parameters in:
- [bicep/infra/sample.greenfield.bicepparam](../../infra/sample.greenfield.bicepparam)

Primary scenario validated by this guide:
- `flagPlatformLandingZone=false` (workload-owned networking)
- **Greenfield networking**: the workload deployment creates a **new VNet + subnets** (when `deployToggles.virtualNetwork=true`)
- The deployment creates **Private Endpoints**, **Private DNS Zones**, and **VNet links** as part of the workload (for the services you enabled)
- Forced tunneling test: **Azure Firewall + UDRs** with default route `0.0.0.0/0` to the firewall

This runbook is written to match the default toggle set in the sample parameter file (`bicep/infra/sample.greenfield.bicepparam`).
If you changed `bicep/infra/main.bicepparam` (or used a different param file), treat the validation steps below as **conditional**:
- If `deployToggles.virtualNetwork=false`, you will not see a new VNet created in this resource group (use the existing-VNet runbook instead).
- If `deployToggles.keyVault=false`, skip Key Vault validation and Key Vault-related DNS checks.
- Enabled (as shipped in the sample): `aiFoundry`, `virtualNetwork`, `keyVault`, `storageAccount`, `logAnalytics`, `appInsights`, `jumpVm`, `bastionHost`, `firewall`, `userDefinedRoutes`
- Disabled (as shipped in the sample): `cosmosDb`, `searchService`, `containerEnv`, `containerApps`, `containerRegistry`, `buildVm`, `apiManagement`, `applicationGateway`, `groundingWithBingSearch`

> Scope note: this is a test runbook. Adjust naming, IP ranges, and hardening for production.

## Prerequisites

- Permissions to create resources in the subscription (e.g., `Contributor`)
- Azure CLI authenticated: `az login`
- Bicep available in Azure CLI (usually built-in)
- AZD installed (recommended for this repo)
- A local clone of this repo (commands reference local paths like `bicep/infra/main.bicepparam`)

Tip: run all commands from the repo root directory.

## Step 1 — Deploy the greenfield workload

### 1.1 Initialize the environment

```powershell
azd init -e ailz-greenfield-RANDOM_SUFFIX
```

### 1.2 Set environment variables

```powershell
$env:AZURE_LOCATION = "eastus2"
$env:AZURE_RESOURCE_GROUP = "rg-ailz-greenfield-RANDOM_SUFFIX"
$env:AZURE_SUBSCRIPTION_ID = "00000000-1111-2222-3333-444444444444"

# Convenience variable used by the commands below
$rg = $env:AZURE_RESOURCE_GROUP
```

### 1.3 Use the greenfield sample parameters

Copy the sample into the active parameter file used by `azd`:

```powershell
Copy-Item bicep/infra/sample.greenfield.bicepparam bicep/infra/main.bicepparam -Force
```

Optional edits in `bicep/infra/main.bicepparam`:
- If you change the subnet CIDRs, also update the firewall policy `sourceAddresses` entries accordingly.
- If you don’t want the Jump VM to self-install tools via CSE, set:
  - `jumpVmDefinition.enableAutoInstall = false`
- If your org manages RBAC outside the template (and you hit `RoleAssignmentExists`), set:
  - `jumpVmDefinition.assignContributorRoleAtResourceGroup = false`

### 1.4 Provision

```powershell
azd provision
```

## Step 2 — Validate networking (VNet/Subnets)

If you do **not** see a VNet in this resource group after provisioning, it usually means one of the following:
- `deployToggles.virtualNetwork=false` (you are not in greenfield networking mode)
- You deployed into a different resource group than the one you are listing

### 2.1 Validate the VNet and subnets exist

```powershell
az network vnet list --resource-group $rg -o table

# If you have only one VNet in this RG, capture it:
$vnetName = (az network vnet list --resource-group $rg --query "[0].name" -o tsv)

az network vnet subnet list --resource-group $rg --vnet-name $vnetName -o table
```

Expected subnets (default template layout):
- `agent-subnet`
- `pe-subnet`
- `AzureBastionSubnet`
- `AzureFirewallSubnet`
- `jumpbox-subnet`

## Step 3 — Validate forced tunneling (Firewall + UDR)

### 3.1 Validate firewall exists and get its private IP

```powershell
az network firewall list --resource-group $rg -o table

$afwName = (az network firewall list --resource-group $rg --query "[0].name" -o tsv)
$afwPrivateIp = (az network firewall show --resource-group $rg --name $afwName --query "ipConfigurations[0].privateIPAddress" -o tsv)
$afwPrivateIp
```

The sample file sets `firewallPrivateIp` assuming the default `AzureFirewallSubnet` prefix (`192.168.0.128/26`) and the first usable IP (`192.168.0.132`).
If you changed the firewall subnet prefix, you must update `firewallPrivateIp` in the params.

### 3.2 Validate the route table and subnet associations

```powershell
az network route-table list --resource-group $rg -o table

# Check that jumpbox-subnet has a route table attached
az network vnet subnet show --resource-group $rg --vnet-name $vnetName --name jumpbox-subnet --query routeTable.id -o tsv
```

## Step 4 — Validate Private Endpoints + Private DNS

Because this is `flagPlatformLandingZone=false`, the workload deployment should create and manage Private DNS Zones.

### 4.1 Validate Private Endpoints exist

```powershell
az network private-endpoint list --resource-group $rg -o table

# Helpful: show what each Private Endpoint targets + which FQDNs it expects to resolve
az network private-endpoint list --resource-group $rg \
  --query "[].{name:name,target:privateLinkServiceConnections[0].privateLinkServiceId,groupIds:privateLinkServiceConnections[0].groupIds,fqdns:customDnsConfigs[].fqdn}" -o jsonc

# Note: sometimes `customDnsConfigs` returns empty. In that case, query DNS zone groups per Private Endpoint:
# $peName = '<private-endpoint-name>'
# az network private-endpoint dns-zone-group list --resource-group $rg --endpoint-name $peName \
#   --query "[].privateDnsZoneConfigs[].recordSets[].fqdn" -o tsv
```

With the shipped sample toggles, you should see Private Endpoints for Key Vault, Storage, and AI Foundry.
If you changed toggles, validate based on what you actually enabled.

### 4.2 Validate Private DNS Zones exist and are linked

```powershell
az network private-dns zone list --resource-group $rg -o table

# Example: check OpenAI private link zone exists and has a VNet link
az network private-dns link vnet list --resource-group $rg --zone-name privatelink.openai.azure.com -o table
```

### 4.3 Validate A records exist

```powershell
az network private-dns record-set a list --resource-group $rg --zone-name privatelink.openai.azure.com -o table
```

## Step 5 — Validate access (Bastion + Jump VM)

### 5.1 Confirm Bastion exists

```powershell
az network bastion list --resource-group $rg -o table
```

### 5.2 Connect to the Jump VM via Bastion

Because the Jump VM password is auto-generated during deployment, the easiest way to access it is to **reset the password in the Azure Portal** before connecting.

1) Azure Portal → Resource Group `rg-ailz-greenfield-RANDOM_SUFFIX`

2) Open the Jump VM (the `*-jmp` VM) → **Reset password**

3) Choose **Reset password**, set:
- Username: `azureuser` (unless you overrode `jumpVmDefinition.adminUsername`)
- Password: set a strong password

4) Save

Use Azure Portal:
- Resource Group: `rg-ailz-greenfield-RANDOM_SUFFIX`
- VM: the `*-jmp` VM
- Connect using Bastion (RDP)

Optional (inside the Jump VM): validate outbound works under forced tunneling:
- `Resolve-DnsName login.microsoftonline.com`
- `Test-NetConnection login.microsoftonline.com -Port 443`

### 5.3 (Inside the Jump VM) Validate DNS resolution for created services

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

Delete the resource group:

```powershell
az group delete --name $rg --yes --no-wait
```
