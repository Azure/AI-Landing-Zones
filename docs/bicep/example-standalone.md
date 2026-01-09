# AI LZ without Platform Landing Zone

Use this scenario when you want a clean, isolated deployment where the workload resource group owns the networking end to end.

**Sample parameter file**

[bicep/infra/sample.standalone.bicepparam](https://github.com/Azure/AI-Landing-Zones/blob/main/bicep/infra/sample.standalone.bicepparam)

**What this walkthrough validates**

| Capability | Notes |
|---|---|
| Workload-owned networking | Creates a new VNet and subnets in the workload resource group. |
| Private connectivity | Creates Private Endpoints, Private DNS Zones, and VNet links for enabled services. |
| Forced tunneling | Sends egress (`0.0.0.0/0`) through Azure Firewall via UDRs. |

**Key settings (from the sample)**

| Setting | Value |
|---|---|
| `flagPlatformLandingZone` | `false` |
| `deployToggles.virtualNetwork` | `true` |
| `deployToggles.firewall` | `true` |
| `deployToggles.userDefinedRoutes` | `true` |
| `deployToggles.jumpVm` | `true` |
| `deployToggles.bastionHost` | `true` |

If you use a different parameter file (or modify `bicep/infra/main.bicepparam`), treat the validation steps as conditional. For example, disabling VNet creation changes the networking checks, and disabling specific services changes what you should expect in the private endpoint and DNS sections.

> Note: this walkthrough is intended for validation and learning. Adjust naming, IP ranges, and hardening before using it for production.

**Prerequisites**

You need permissions to create resources in the target subscription (for example, `Contributor`), and you must be signed in with Azure CLI (`az login`). You also need Azure Developer CLI installed (`azd`), because this walkthrough uses it to initialize the repository locally and to run the deployment.

**Deployment**

Create a local working directory and run the commands from there.

```powershell
mkdir deploy
cd deploy
```

Initialize the environment.

```powershell
azd init -e ailz-standalone-RANDOM_SUFFIX
```

Set environment variables.

```powershell
$env:AZURE_LOCATION = "eastus2"
$env:AZURE_RESOURCE_GROUP = "rg-ailz-standalone-RANDOM_SUFFIX"
$env:AZURE_SUBSCRIPTION_ID = "00000000-1111-2222-3333-444444444444"

# Convenience variable used by the commands below
$rg = $env:AZURE_RESOURCE_GROUP
```

Copy the sample into the active parameter file used by `azd`.

```powershell
Copy-Item bicep/infra/sample.standalone.bicepparam bicep/infra/main.bicepparam -Force
```

Optional edits in `bicep/infra/main.bicepparam`.

| Scenario | Change |
|---|---|
| You change subnet CIDRs | Update the firewall policy `sourceAddresses` entries to match. |
| You do not want Jump VM auto-install | Set `jumpVmDefinition.enableAutoInstall = false`. |
| Your org manages RBAC outside the template | If you hit `RoleAssignmentExists`, set `jumpVmDefinition.assignContributorRoleAtResourceGroup = false`. |

Provision.

```powershell
azd provision
```

**Validation: networking (VNet and subnets)**

If you do not see a VNet in the workload resource group after provisioning, confirm that you are inspecting the correct resource group.

Validate the VNet and subnets.

```powershell
az network vnet list --resource-group $rg -o table

# If you have only one VNet in this RG, capture it:
$vnetName = (az network vnet list --resource-group $rg --query "[0].name" -o tsv)

az network vnet subnet list --resource-group $rg --vnet-name $vnetName -o table
```

Expected subnets (default template layout):

| Subnet name |
|---|
| `agent-subnet` |
| `pe-subnet` |
| `AzureBastionSubnet` |
| `AzureFirewallSubnet` |
| `jumpbox-subnet` |

**Validation: forced tunneling (Firewall and UDR)**

Validate the firewall and capture its private IP.

```powershell
az network firewall list --resource-group $rg -o table

$afwName = (az network firewall list --resource-group $rg --query "[0].name" -o tsv)
$afwPrivateIp = (az network firewall show --resource-group $rg --name $afwName --query "ipConfigurations[0].privateIPAddress" -o tsv)
$afwPrivateIp
```

The sample sets `firewallPrivateIp` based on the default `AzureFirewallSubnet` prefix (`192.168.0.128/26`) and the first usable IP (`192.168.0.132`). If you changed the firewall subnet prefix, update `firewallPrivateIp` in your parameter file.

Validate the route table and subnet association.

```powershell
az network route-table list --resource-group $rg -o table

# Check that jumpbox-subnet has a route table attached
az network vnet subnet show --resource-group $rg --vnet-name $vnetName --name jumpbox-subnet --query routeTable.id -o tsv
```

**Validation: private endpoints and private DNS**

In standalone mode, the workload deployment creates and manages private DNS zones.

Validate that private endpoints exist.

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

Validate that private DNS zones exist and are linked.

```powershell
az network private-dns zone list --resource-group $rg -o table

# Example: check OpenAI private link zone exists and has a VNet link
az network private-dns link vnet list --resource-group $rg --zone-name privatelink.openai.azure.com -o table
```

Validate that A records exist.

```powershell
az network private-dns record-set a list --resource-group $rg --zone-name privatelink.openai.azure.com -o table
```

**Validation: access (Bastion and Jump VM)**

Confirm that Bastion exists.

```powershell
az network bastion list --resource-group $rg -o table
```

Connect to the Jump VM using Bastion. Because the VM password is auto-generated during deployment, reset it in the Azure portal before connecting. Open the workload resource group, select the jump VM (the `*-jmp` VM), choose Reset password, and set a strong password for `azureuser` (unless you changed `jumpVmDefinition.adminUsername`). Then connect using Bastion (RDP).

Optional (inside the Jump VM): validate outbound connectivity under forced tunneling:

```powershell
Resolve-DnsName login.microsoftonline.com
Test-NetConnection login.microsoftonline.com -Port 443
```

Validate DNS resolution for the created services from inside the Jump VM. The goal is to confirm that service hostnames resolve to private IPs via the `privatelink.*` private DNS zones.

From your local machine, capture the Private Endpoint FQDNs created by the deployment:

```powershell
# List all Private Endpoints expect to resolve
az network private-endpoint list --resource-group $rg --query "[].{name:name}" -o jsonc

# Extract FQDNs from the DNS zone groups:
$peName = '<private-endpoint-name>'
az network private-endpoint dns-zone-group list --resource-group $rg --endpoint-name $peName --query "[].privateDnsZoneConfigs[].recordSets[].fqdn" -o tsv
```

Then, inside the Jump VM (PowerShell), run `nslookup` for the exact FQDNs returned by the command above.

Examples:

```powershell
nslookup <fqdn-from-customDnsConfigs>

# Optional: show the CNAME chain (useful for troubleshooting)
Resolve-DnsName <fqdn-from-customDnsConfigs> | Format-List
```

Expected outcome:

| Check | Expected |
|---|---|
| `nslookup` | Returns a private IP address (typically within your VNet range). |
| `Resolve-DnsName` | Shows a CNAME into the matching `privatelink.*` zone. |

**Cleanup**

Delete the resource group.

```powershell
az group delete --name $rg --yes --no-wait
```
