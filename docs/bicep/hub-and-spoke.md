# Hub-and-spoke deployment runbook

Deploy the **Bicep AI Landing Zone foundation** as a private spoke connected to
an existing customer hub. The hub supplies controlled egress, operator access,
shared DNS and optionally monitoring. For a self-contained network, use the
[Standalone runbook](standalone.md).

Commands below use **PowerShell 7** from the root of
`Azure/bicep-ptn-aiml-landing-zone` at **v2.7.3**. They are not commands to run
inside Agent Landing Zone's `infra/` directory. The foundation provisions a
placeholder Container App, not the complete Agent application. For that product,
start with [Deploy full stack](../agent-landing-zone/deploy-full-stack.md) or
[Deploy infra only](../agent-landing-zone/deploy-infra-only.md), and apply the
network design here through its root parameters. Agent Landing Zone incorporates
foundation source and has additional lifecycle hooks; do not deploy both projects
into the same resource group.

## 1. Agree ownership and prerequisites

| Owner | Responsibilities before deployment |
| --- | --- |
| Workload team | Dedicated spoke resource group, nonoverlapping addresses, workload resources, private endpoints, identities and application configuration |
| Hub/network team | Hub VNet, firewall policy and return routes, reverse peering, Bastion/VPN access and shared route tables |
| DNS team | Zone inventory, cross-scope permissions, VNet links or resolver forwarding, private records and conflict prevention |
| Monitoring team | Shared workspace/component access, telemetry retention and any central Azure Monitor Private Link Scope (AMPLS) connectivity |

Install Git, Azure CLI, Azure Developer CLI and PowerShell 7. Check
[regional availability and quotas](regional-considerations.md) for models,
Search, VMs and Container Apps. Obtain deployment approval and resolve Azure
Policy restrictions first.

The deployment identity needs Contributor and role-assignment authority
(for example User Access Administrator) at the required deployment scopes.
Use [Permissions](permissions.md) to review generated assignments. Separately
authorize peering operations at **both VNet scopes**, including remote
`peer/action`; Contributor on the spoke resource group alone is insufficient.
The hub operator needs peering write permission on the hub. DNS zone-group
operations need permission to join the shared zones, and the DNS operator needs
zone/link write permissions plus VNet join access. Grant monitoring read/link
permissions where needed. Use narrowly scoped roles rather than subscription
Owner; cross-subscription resources must be accessible to the participating
identities and registered providers.

Choose a VNet-connected deployment host (VPN, peered build agent or jumpbox)
with private DNS resolution and authorized data-plane access. ACR Tasks build
pools do not provide connectivity to your deployment host. Bastion provides
interactive VM access, not a VPN for your laptop.

!!! warning "A test hub is not a customer hub"
    The legacy source runbook's `tests/hub/` fixture and `tests/scripts/`
    helpers simulate a hub. Do not deploy them into a customer connectivity
    subscription. Do not copy its empty default route, disabled Search or
    skipped bootstrap/preflight as production settings. This runbook uses
    existing approved hub resources and Azure CLI operations instead.

## 2. Initialize and plan addresses

Replace every `<...>` input before executing. All subsequent `azd` commands
use this environment in this checkout.

```powershell
git clone --branch v2.7.3 https://github.com/Azure/bicep-ptn-aiml-landing-zone.git ailz-spoke
Set-Location ailz-spoke
$subscriptionId = '<spoke-subscription-id>'
$location = '<azure-region>'
$envName = '<unique-spoke-environment-name>'
$resourceGroup = '<dedicated-spoke-resource-group>'
$hubVnetId = '/subscriptions/<hub-subscription-id>/resourceGroups/<hub-rg>/providers/Microsoft.Network/virtualNetworks/<hub-vnet>'
$hubFirewallIp = '<hub-firewall-private-ip>'
$hubBastionId = '/subscriptions/<hub-subscription-id>/resourceGroups/<hub-rg>/providers/Microsoft.Network/bastionHosts/<bastion-name>'
$hubLawId = '/subscriptions/<monitoring-subscription-id>/resourceGroups/<monitoring-rg>/providers/Microsoft.OperationalInsights/workspaces/<workspace-name>'

az login
azd auth login
az account set --subscription $subscriptionId
az group create --name $resourceGroup --location $location
azd env new $envName --subscription $subscriptionId --location $location
azd env set AZURE_RESOURCE_GROUP $resourceGroup
az network vnet show --ids $hubVnetId --query addressSpace.addressPrefixes -o json
```

Agree the complete spoke/subnet plan against hub, other spokes, VPN/on-premises
and future ranges. Apply the native parameter update in
[Standalone: Plan addresses](standalone.md#2-plan-addresses) **in this checkout**;
do not run its standalone topology configuration. The example uses
`10.200.0.0/21`, not a universally safe allocation. Upstream defaults are
`192.168.0.0/21`; setting only a VNet prefix leaves its default subnets unchanged.
There is no upstream `VNET_ADDRESS_PREFIXES` environment mapping.

This path creates a new spoke VNet. If reusing one instead, review
[BYO VNet parameters](parameterization.md) and preserve externally owned subnets,
NSGs and delegations. With `USE_EXISTING_VNET=true`, the template does **not**
create the forward peering: the network team must manage both directions.
Do not update existing subnets with isolation on and `DEPLOY_NSGS=false`;
either retain managed NSGs or use `DEPLOY_SUBNETS=false` and have the network
owner prepare the complete subnet configuration.

## 3. Configure hub integration

These are the actual v2.7.3 environment mappings; `DEPLOYMENT_MODE` records
intent but does not configure routing, DNS or peering by itself.

```powershell
azd env set DEPLOYMENT_MODE ailz-integrated
azd env set NETWORK_ISOLATION true
azd env set DEPLOY_AZURE_FIREWALL false
azd env set DEPLOY_JUMPBOX true
azd env set DEPLOY_BASTION false
azd env set EXISTING_BASTION_RESOURCE_ID $hubBastionId
azd env set DEPLOY_NAT_GATEWAY false
azd env set HUB_INTEGRATION_HUB_VNET_RESOURCE_ID $hubVnetId
azd env set HUB_INTEGRATION_CREATE_HUB_PEERING true
azd env set HUB_INTEGRATION_EGRESS_NEXT_HOP_IP $hubFirewallIp
azd env set EXISTING_LOG_ANALYTICS_WORKSPACE_RESOURCE_ID $hubLawId
```

This creates a spoke route table with `0.0.0.0/0` to the hub firewall and
attaches it to the managed workload subnets. No local firewall/NAT is created.
The hub team must allow the spoke source CIDRs and required destinations
**before** bootstrap, image pulls or data-plane operations. Review the
[v2.7.3 firewall allowlist](https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/v2.7.3/README.md#firewall-egress-allow-list-network-isolation),
including Azure identity/control plane, MCR/ACR, bootstrap and package feeds.
Extend only the required destinations, not unrestricted Internet access.
Check return paths, DNS transport, NSGs, forwarded traffic and any gateway route
propagation. Peering is not transitive; on-premises and multi-spoke routing
require explicit network design.

**Alternative: platform-owned route table.** Replace the next-hop setting with
an existing, same-region route table that the network team has configured and
authorized for the spoke subnet associations:

```powershell
azd env set HUB_INTEGRATION_EGRESS_NEXT_HOP_IP ''
azd env set HUB_INTEGRATION_EXISTING_ROUTE_TABLE_RESOURCE_ID '/subscriptions/<spoke-subscription-id>/resourceGroups/<network-rg>/providers/Microsoft.Network/routeTables/<route-table-name>'
```

These two inputs are mutually exclusive. The template does not modify a shared
route table's routes. An unset next hop without a supplied route table does not
enforce hub egress.

**Monitoring:** the example reuses the hub LAW and creates workload Application
Insights against it. To reuse Application Insights too, set
`EXISTING_APPLICATION_INSIGHTS_RESOURCE_ID` and
`EXISTING_APPLICATION_INSIGHTS_CONNECTION_STRING` to the approved component's
values through protected environment configuration. Do not print connection
strings or commit `.azure/`. Confirm that the component uses the selected LAW;
do not enable mixed workspaces to silence a validation failure.

Central workspace reuse does **not** automatically create a local AMPLS:
v2.7.3 creates that scope only when both LAW and Application Insights are
created locally with private monitoring enabled. The monitoring team must
provide and verify central private ingestion/query paths if required. A
successful infrastructure deployment is not proof that telemetry is flowing.

## 4. Select shared DNS zones

Supplying an existing zone ID suppresses its local creation and automatic VNet
link. **Peering does not propagate DNS zone links.** Every client VNet needs a
zone link or an explicit DNS resolver/forwarding path to a linked network.
Avoid duplicate authoritative zones that hide records.

For this example the ten workload zones already exist in one central resource
group in Azure public cloud. Replace the DNS inputs; if your inventory spans
resource groups, use each zone's actual resource ID instead of constructing it.
The Container Apps zone must match `$location`.

```powershell
$dnsSubscriptionId = '<dns-subscription-id>'
$dnsResourceGroup = '<shared-dns-resource-group>'
$zoneNames = [ordered]@{
    COGSVCS = 'privatelink.cognitiveservices.azure.com'
    OPENAI = 'privatelink.openai.azure.com'
    AISERVICES = 'privatelink.services.ai.azure.com'
    SEARCH = 'privatelink.search.windows.net'
    COSMOS = 'privatelink.documents.azure.com'
    BLOB = 'privatelink.blob.core.windows.net'
    KEYVAULT = 'privatelink.vaultcore.azure.net'
    APPCONFIG = 'privatelink.azconfig.io'
    CONTAINERAPPS = "privatelink.$location.azurecontainerapps.io"
    ACR = 'privatelink.azurecr.io'
}
$sharedZoneIds = @()
foreach ($entry in $zoneNames.GetEnumerator()) {
    $zoneId = "/subscriptions/$dnsSubscriptionId/resourceGroups/$dnsResourceGroup/providers/Microsoft.Network/privateDnsZones/$($entry.Value)"
    az network private-dns zone show --ids $zoneId --query name -o tsv
    if ($LASTEXITCODE -ne 0) { throw "Shared zone unavailable: $($entry.Value)" }
    azd env set "EXISTING_PRIVATE_DNS_ZONE_$($entry.Key)_RESOURCE_ID" $zoneId
    $sharedZoneIds += $zoneId
}
```

The mappings above target `existingPrivateDnsZone<Namespace>ResourceId` in root
`main.parameters.json`. Additional monitoring mappings, when applicable:

| Variable between `EXISTING_PRIVATE_DNS_ZONE_` and `_RESOURCE_ID` | Zone |
| --- | --- |
| `AZUREMONITOR` | `privatelink.monitor.azure.com` |
| `OMSOPSINSIGHTS` | `privatelink.oms.opinsights.azure.com` |
| `ODSOPSINSIGHTS` | `privatelink.ods.opinsights.azure.com` |
| `AZUREAUTOMATION` | `privatelink.agentsvc.azure.automation.net` |
| `APPINSIGHTS` | `privatelink.applicationinsights.io` |

Set applicable extra IDs with `azd env set` and include them in
`$sharedZoneIds` if this deployment needs new direct links. Monitoring overrides
are only consumed when local AMPLS is created; they do not configure a central
scope. Where Azure Policy owns DNS, use `POLICY_MANAGED_PRIVATE_DNS=true`
**instead of** BYO overrides, clear all those overrides, and agree who creates
zone groups and links. Do not combine both models.

## 5. Provision and complete both peering directions

From the spoke checkout, review preflight and preview before approval:

```powershell
pwsh ./scripts/Invoke-PreflightChecks.ps1
azd provision --preview
# After the owners approve the preview:
azd provision
```

Resolve findings rather than bypassing preflight. A fresh spoke needs a network
operator available **during the first provision**: as soon as the VNet exists,
complete the reverse peering and DNS links below from a second authorized
PowerShell session. Waiting for bootstrap/image pulls to finish before doing
this can cause the first deployment to fail on hub connectivity. A partial
deployment is recoverable; do not delete it to retry.

In the network operator's session, set these inputs from the agreed deployment.
Copy the exact spoke VNet ID from the listing; do not assume the first VNet is
the right one.

```powershell
$subscriptionId = '<spoke-subscription-id>'
$resourceGroup = '<dedicated-spoke-resource-group>'
$hubVnetId = '/subscriptions/<hub-subscription-id>/resourceGroups/<hub-rg>/providers/Microsoft.Network/virtualNetworks/<hub-vnet>'
az network vnet list --subscription $subscriptionId --resource-group $resourceGroup --query '[].{name:name,id:id}' -o table
$spokeVnetId = '<spoke-vnet-resource-id-from-list>'
$hubParts = $hubVnetId.Split('/')
$spokeParts = $spokeVnetId.Split('/')
$reversePeeringName = '<unique-hub-to-this-spoke-peering-name>'

az network vnet peering create --subscription $hubParts[2] --resource-group $hubParts[4] --vnet-name $hubParts[8] --name $reversePeeringName --remote-vnet $spokeVnetId --allow-vnet-access --allow-forwarded-traffic
az network vnet peering list --subscription $hubParts[2] --resource-group $hubParts[4] --vnet-name $hubParts[8] --query '[].{name:name,state:peeringState,forwarded:allowForwardedTraffic}' -o table
az network vnet peering list --subscription $spokeParts[2] --resource-group $spokeParts[4] --vnet-name $spokeParts[8] --query '[].{name:name,state:peeringState,forwarded:allowForwardedTraffic}' -o table
```

Expected: the pair is `Connected`, with forwarded traffic enabled in both
directions. The template creates spoke→hub only for a new isolated VNet with
`HUB_INTEGRATION_CREATE_HUB_PEERING=true`. If the network team owns that side,
set the flag to `false` before provision and create it explicitly:

```powershell
$forwardPeeringName = '<unique-spoke-to-hub-peering-name>'
az network vnet peering create --subscription $spokeParts[2] --resource-group $spokeParts[4] --vnet-name $spokeParts[8] --name $forwardPeeringName --remote-vnet $hubVnetId --allow-vnet-access --allow-forwarded-traffic
```

These commands leave gateway transit off. For an approved hub-gateway design,
the hub side must allow gateway transit and the spoke must use remote gateways
(`HUB_INTEGRATION_PEERING_USE_REMOTE_GATEWAYS=true` for template-managed
peering). Do not enable `ALLOW_GATEWAY_TRANSIT` on the spoke to consume a hub
gateway; that flag has the opposite direction.

## 6. Link DNS and verify from the connected host

Run in the original spoke session with a DNS-authorized identity, or transfer
the approved zone-ID inventory to the DNS operator. Define the spoke ID there:

```powershell
$spokeVnetId = '<spoke-vnet-resource-id-from-step-5>'
$dnsLinkName = '<unique-link-name-for-this-spoke>'
foreach ($zoneId in $sharedZoneIds) {
    $parts = $zoneId.Split('/')
    $linksJson = az network private-dns link vnet list --subscription $parts[2] --resource-group $parts[4] --zone-name $parts[8] -o json
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect links for $zoneId" }
    $links = @($linksJson | ConvertFrom-Json)
    $links | Select-Object name, virtualNetworkLinkState, virtualNetwork
    if (-not ($links | Where-Object { $_.virtualNetwork.id -eq $spokeVnetId })) {
        az network private-dns link vnet create --subscription $parts[2] --resource-group $parts[4] --zone-name $parts[8] --name $dnsLinkName --virtual-network $spokeVnetId --registration-enabled false
        if ($LASTEXITCODE -ne 0) { throw "Cannot create link for $zoneId" }
    }
}
```

Existing links to this spoke are reused rather than recreated. Expected link
state is `Completed`. If the host resides in the hub or another
VNet, the DNS team must also supply resolution there. With custom DNS, configure
conditional forwarding through an Azure DNS Private Resolver or approved DNS
servers; a spoke link alone does not change the client's DNS servers.

After provision completes, run the
[foundation verification commands](standalone.md#5-verify-private-connectivity)
from this spoke checkout and its connected host. Verify approved private
endpoint connections and private IP resolution for the app, Search, Storage,
App Configuration and registry; check TCP/HTTPS access using an authorized
identity for data-plane tests. Check firewall logs and effective routes:

```powershell
az network nic list --subscription $subscriptionId --resource-group $resourceGroup --query '[].{name:name,id:id}' -o table
$nicId = '<running-jumpbox-nic-resource-id-from-list>'
az network nic show-effective-route-table --ids $nicId -o table
$spokeParts = $spokeVnetId.Split('/')
az network vnet subnet list --subscription $spokeParts[2] --resource-group $spokeParts[4] --vnet-name $spokeParts[8] --query '[].{name:name,prefix:addressPrefix,routeTable:routeTable.id}' -o table
```

Expected: managed workload subnets reference the intended route table, and the
effective default route uses `VirtualAppliance` with the hub firewall IP
(or the network team's approved route policy). Peering `Connected` alone does
not establish working DNS, permitted egress or telemetry. Have the monitoring
owner confirm a new test trace/query reaches the intended workspace.

For interactive jumpbox access, use the **hub** Bastion, not the standalone
runbook's local Bastion listing. From a supported Windows client, with hub
Bastion Standard/Premium and native tunneling enabled:

```powershell
$hubBastionParts = $hubBastionId.Split('/')
$vmName = '<spoke-jumpbox-name>'
$vmId = az vm show --subscription $subscriptionId --resource-group $resourceGroup --name $vmName --query id -o tsv
az network bastion rdp --subscription $hubBastionParts[2] --resource-group $hubBastionParts[4] --name $hubBastionParts[8] --target-resource-id $vmId
```

Alternatively connect through the portal or the approved VPN. Use the provisioned
VM credential or an authorized portal reset; do not add a public IP to the VM.

## 7. Recover safely

| Failure | Action before retry |
| --- | --- |
| Peering `Initiated`/`Disconnected` | Check both resource IDs, overlap, remote-scope permissions and matching reverse peering; have the owning team repair its side |
| Public/NXDOMAIN answers from a connected host | Check zone IDs, zone groups/records, links for the actual client VNet and custom DNS forwarding; do not enable public access |
| Bootstrap, image pull or package download timeout | Check reverse peering, effective UDR/NSG rules and firewall deny logs for the actual source subnet and destination; add only approved rules |
| Shared observability denied or no telemetry | Check workspace/component permissions and association, central AMPLS, DNS and ingestion/query reachability |
| Token expiry, quota or Policy failure | Inspect deployment operations, refresh authentication or obtain the approved capacity/policy change; keep resource locations consistent |

Use the [Standalone recovery commands](standalone.md#6-recover-without-weakening-isolation)
to inspect operations and logs. Once the owners correct the cause, rerun preview
then `azd provision` with the **same environment, source and parameter file**.
Keep data and identities intact. Do not disable Search, open public endpoints,
skip preflight or remove egress controls to get a green result.

## 8. Clean up only the spoke

Obtain workload/data-retention approval. Inventory dependencies and resources
outside the spoke group first. Record only the reverse peering and DNS links
created specifically for this spoke; have their owners remove those attachments
when the spoke is retired, **not** shared zones, records still in use by others,
hub VNet, Bastion, firewall, route tables, LAW or Application Insights.

From the spoke checkout:

```powershell
azd env select $envName
azd env get-value AZURE_SUBSCRIPTION_ID
azd env get-value AZURE_RESOURCE_GROUP
az resource list --subscription $subscriptionId --resource-group $resourceGroup --query '[].{name:name,type:type}' -o table
# Only after confirming the exact dedicated spoke scope and backups:
azd down
```

Review the interactive deletion scope. Do not use unattended `--force --purge`:
purging soft-deleted services removes recovery options. In the authorized network
session, remove only the recorded reverse peering after retirement:

```powershell
az network vnet peering delete --subscription $hubParts[2] --resource-group $hubParts[4] --vnet-name $hubParts[8] --name $reversePeeringName
```

The DNS owner can remove each recorded, spoke-only link with
`az network private-dns link vnet delete --subscription <dns-subscription-id> --resource-group <dns-rg> --zone-name <zone-name> --name <spoke-only-link-name>`.
Confirm shared hub resources and other spokes remain healthy. Turning a deploy
flag off in an incremental deployment does not delete previous resources.

## Next: deploy the Agent application

Foundation hello-world success is a network smoke test, not application readiness
or proof of document-level authorization. In the Agent project, follow
[Network isolation](../agent-landing-zone/network-isolation.md) for connected-host
setup and post-provision work, [Deploy full stack](../agent-landing-zone/deploy-full-stack.md)
for application deployment, and [Hosted agents](../agent-landing-zone/hosted-agents.md)
for the first hosted provision/prepare/provision/deploy sequence. Keep approved
network inputs consistent across hosts; `azd env refresh` restores outputs, not
your full custom input file or environment configuration.
