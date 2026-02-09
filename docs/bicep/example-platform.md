# AI LZ with Platform Landing Zone

Use this scenario when you already have a platform hub (networking + egress) and want the workload deployment to integrate as a spoke.

**Sample parameter file**

[bicep/infra/sample.platform-landing-zone.bicepparam](https://github.com/Azure/AI-Landing-Zones/blob/main/bicep/infra/sample.platform-landing-zone.bicepparam)

**What this walkthrough validates**

| Capability | Notes |
|---|---|
| Hub-spoke integration | Creates spoke-side VNet peering to the platform hub VNet. Hub-side reverse peering is expected to be created by the platform team (or separately). |
| Forced tunneling to hub | Creates UDRs in the spoke that send egress (`0.0.0.0/0`) to the hub firewall/NVA next hop IP you provide. |
| Private connectivity in the spoke | Creates Private Endpoints in the workload VNet when the corresponding services are enabled. |
| Platform-managed private DNS | In platform mode, this template does not create Private DNS Zones or link them; DNS is expected to be provided by the platform landing zone. |

**Key settings (from the sample)**

| Setting | Value |
|---|---|
| `flagPlatformLandingZone` | `true` |
| `hubVnetPeeringDefinition.peerVnetResourceId` | Hub VNet resource ID |
| `deployToggles.firewall` | `false` (hub firewall is used) |
| `deployToggles.userDefinedRoutes` | `true` |
| `firewallPrivateIp` | Hub firewall private IP (UDR next hop) |

If you use a different parameter file (or modify `bicep/infra/main.bicepparam`), treat the validation steps as conditional. For example, disabling VNet creation changes the networking checks, and disabling specific services changes what you should expect in the private endpoint checks.

> Note: in Platform Landing Zone mode, this repo intentionally creates only the spoke-side peering. If the hub does not have a corresponding peering back to the spoke, traffic will not flow.

**Prerequisites**

- Permissions to create resources in the target subscription (for example, `Contributor`) and you must be signed in with Azure CLI (`az login`).
- Azure Developer CLI installed (`azd`).
- A platform hub already exists with:
	- A hub VNet (resource ID)
	- A firewall/NVA private IP to use as the UDR next hop
	- Private DNS (and DNS forwarding/resolution) configured so spoke workloads can resolve `privatelink.*` zones.

**Deployment**

Create a local working directory and run the commands from there.

```powershell
mkdir deploy
cd deploy
```

Initialize the environment.

```powershell
azd init -e ailz-platform-RANDOM_SUFFIX
```

Set environment variables.

```powershell
$env:AZURE_LOCATION = "eastus2"
$env:AZURE_RESOURCE_GROUP = "rg-ailz-platform-RANDOM_SUFFIX"
$env:AZURE_SUBSCRIPTION_ID = "00000000-1111-2222-3333-444444444444"

# Convenience variable used by the commands below
$rg = $env:AZURE_RESOURCE_GROUP
```

Copy the sample into the active parameter file used by `azd`.

```powershell
Copy-Item bicep/infra/sample.platform-landing-zone.bicepparam bicep/infra/main.bicepparam -Force
```

Update `bicep/infra/main.bicepparam` with your platform hub values.

| Setting | What you must set |
|---|---|
| `hubVnetPeeringDefinition.peerVnetResourceId` | Hub VNet resource ID (full ARM ID) |
| `firewallPrivateIp` | Hub firewall private IP used as next hop for `0.0.0.0/0` |

Provision.

```powershell
azd provision
```

**Validation: networking (spoke VNet and subnets)**

Validate the VNet and subnets in the workload resource group.

```powershell
az network vnet list --resource-group $rg -o table

# If you have only one VNet in this RG, capture it:
$vnetName = (az network vnet list --resource-group $rg --query "[0].name" -o tsv)

az network vnet subnet list --resource-group $rg --vnet-name $vnetName -o table
```

Expected subnets (default platform sample layout):

| Subnet name |
|---|
| `agent-subnet` |
| `pe-subnet` |
| `appgw-subnet` |
| `aca-env-subnet` |
| `devops-agents-subnet` |

In platform mode, hub-level subnets like `AzureFirewallSubnet` and `AzureBastionSubnet` are expected to exist in the hub (not in the workload RG).

**Validation: hub-spoke peering**

Validate that the spoke has a peering to the hub.

```powershell
az network vnet peering list --resource-group $rg --vnet-name $vnetName -o table
```

Expected outcome:

| Check | Expected |
|---|---|
| Spoke peering exists | A peering (often named `to-hub`) with `remoteVirtualNetwork` set to your hub VNet resource ID |
| Spoke peering state | `Connected` (if hub-side peering exists) or `Initiated/Disconnected` (if hub-side peering is missing) |

If you have access to the hub resource group, also validate that the hub has a peering back to the spoke VNet.

**Validation: forced tunneling (UDR to hub firewall)**

In platform mode, the spoke typically does not deploy its own firewall. Instead, you provide `firewallPrivateIp` (the hub firewall/NVA next hop) and the template creates route tables in the workload resource group.

Validate the route table and default route.

```powershell
az network route-table list --resource-group $rg -o table

$rtName = (az network route-table list --resource-group $rg --query "[0].name" -o tsv)

az network route-table route list --resource-group $rg --route-table-name $rtName -o table
```

Confirm that workload subnets have the route table attached (example: `agent-subnet`).

```powershell
az network vnet subnet show --resource-group $rg --vnet-name $vnetName --name agent-subnet --query routeTable.id -o tsv
```

Expected outcome:

| Check | Expected |
|---|---|
| Default route exists | Route `0.0.0.0/0` with next hop type `VirtualAppliance` and next hop IP = your `firewallPrivateIp` |
| Subnet association | `routeTable.id` is non-empty for subnets where forced tunneling is intended |

If you do not see any route tables, confirm:

- `deployToggles.userDefinedRoutes = true`
- `firewallPrivateIp` is set and non-empty

**Validation: private endpoints (spoke)**

Validate that private endpoints exist in the workload resource group for enabled services.

```powershell
az network private-endpoint list --resource-group $rg -o table

# Helpful: show what each Private Endpoint targets
az network private-endpoint list --resource-group $rg `
  --query "[].{name:name,target:privateLinkServiceConnections[0].privateLinkServiceId,groupIds:privateLinkServiceConnections[0].groupIds,subnet:subnet.id}" -o jsonc
```

Because this is Platform Landing Zone mode, the template does not create Private DNS Zones or DNS zone groups for the private endpoints. DNS validation must be done via the platform DNS solution.

**Validation: private DNS (platform-provided)**

From a machine that uses the platform DNS (for example, a hub jumpbox VM, on-premises via VPN/ExpressRoute, or another approved network path), validate that service hostnames resolve to private IPs.

Examples:

```powershell
nslookup <your-service-hostname>

# Optional: show the CNAME chain (useful for troubleshooting)
Resolve-DnsName <your-service-hostname> | Format-List
```

Expected outcome:

| Check | Expected |
|---|---|
| DNS resolution | Returns a private IP (typically within the PE subnet range) |
| CNAME chain | Shows a CNAME into the matching `privatelink.*` zone |

If DNS resolution returns public IPs, the platform landing zone likely is not linking the needed private DNS zones to the hub/spoke DNS resolution path.

**Cleanup**

Delete the workload resource group.

```powershell
az group delete --name $rg --yes --no-wait
```
