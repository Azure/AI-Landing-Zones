# Hub-and-spoke network reference

A private spoke can reuse an existing hub's controlled egress, operator access,
DNS and monitoring rather than recreate them. This page defines the ownership
and inputs for that design. It does not deploy a hub or provide a separate
landing-zone deployment recipe.

Apply these choices in [Deploy infrastructure only](../agent-landing-zone/deploy-infra-only.md)
or [Deploy the full stack](../agent-landing-zone/deploy-full-stack.md).
For a network without shared hub dependencies, use the [standalone reference](standalone.md).

## Agree ownership and permissions

<a id="1-agree-ownership-and-prerequisites"></a>

| Owner | Contract before deployment |
| --- | --- |
| Workload team | Dedicated spoke scope, nonoverlapping addresses, workload resources, private endpoints and identities |
| Hub/network team | Hub VNet, firewall policy, forward/return routes, both peering directions, Bastion/VPN and shared route tables |
| DNS team | Zone inventory, zone groups/records, links or resolver forwarding, cross-scope permissions and conflict prevention |
| Monitoring team | Shared workspace/component access, retention and any central Azure Monitor Private Link Scope (AMPLS) |

Contributor and role-assignment authority on the workload do not automatically
authorize hub operations. Peering needs permissions at both VNet scopes,
including remote `peer/action`. Shared-zone operations need zone join access;
link creation needs zone/link write and VNet join permissions. Authorize
monitoring access separately. Cross-subscription resources require appropriate
provider registration and scoped access.

The deployment host needs private DNS resolution and network/data-plane access.
An ACR Tasks pool is not a connected deployment host. Bastion is interactive VM
access, not a VPN for a workstation.

!!! warning "Test fixtures are not shared-platform deployments"
    Foundation `infra/tests/hub/` and `infra/tests/scripts/` simulate a hub. Do not deploy
    them into an operational connectivity subscription or copy their empty
    route, disabled Search, skipped bootstrap or skipped preflight settings.

## Address and subnet contract

<a id="2-initialize-and-plan-addresses"></a>

Review the [complete address plan](standalone.md#address-planning) against hub,
spokes, VPN/on-premises and future networks. A VNet prefix alone does not update
its default subnets. Store the approved native parameters in the selected
source's root parameter file.

For an existing VNet, preserve externally owned subnets, NSGs and delegations.
With `USE_EXISTING_VNET=true`, the template does not create forward peering;
the network team owns both directions. Do not update isolated existing subnets
with native root `deployNsgs=false`: retain managed NSGs or set `DEPLOY_SUBNETS=false` and
have the network owner prepare the complete configuration.

## Hub integration inputs

<a id="3-configure-hub-integration"></a>

`DEPLOYMENT_MODE=ailz-integrated` records intent. The explicit inputs below select
resources and behavior; the preset alone does not enable isolation or wire a hub.

| Environment input | Intended value or role |
| --- | --- |
| `NETWORK_ISOLATION` | `true` |
| `DEPLOY_AZURE_FIREWALL` | `false` when using hub egress |
| `DEPLOY_BASTION`, `DEPLOY_NAT_GATEWAY` | `false` when not deploying local counterparts |
| `DEPLOY_JUMPBOX` | Explicit choice; `true` creates a workload jumpbox |
| `EXISTING_BASTION_RESOURCE_ID` | Exact approved hub Bastion ID |
| `HUB_INTEGRATION_HUB_VNET_RESOURCE_ID` | Exact hub VNet ID |
| `HUB_INTEGRATION_CREATE_HUB_PEERING` | `true` creates spoke→hub for a new isolated VNet; `false` leaves it externally managed |
| `HUB_INTEGRATION_EGRESS_NEXT_HOP_IP` | Hub firewall/NVA private IP for the workload default route |
| `HUB_INTEGRATION_EXISTING_ROUTE_TABLE_RESOURCE_ID` | Alternative approved route table; mutually exclusive with next-hop IP |
| `EXISTING_LOG_ANALYTICS_WORKSPACE_RESOURCE_ID` | Approved shared workspace, if reused |
| `EXISTING_APPLICATION_INSIGHTS_RESOURCE_ID` | Optional reused component; also supply its protected `EXISTING_APPLICATION_INSIGHTS_CONNECTION_STRING` |

With a next-hop IP, the template creates a spoke route table with `0.0.0.0/0`
to the hub appliance. A supplied route table is reused, not rewritten.
Neither input being set does not enforce hub egress. Confirm region, association
permissions and routes before choosing a shared table.

Allow required spoke source CIDRs and destinations before bootstrap, image pulls
and data-plane configuration. Review the
[foundation firewall source](https://github.com/Azure/agent-landing-zone/blob/main/infra/modules/networking/azure-firewall.bicep)
and the Agent platform's [build-egress requirements](../agent-landing-zone/network-isolation.md).
Check return paths, DNS transport, NSGs and forwarded traffic rather than
opening unrestricted Internet access. Peering is not transitive.

Reusing a central workspace does not automatically create local AMPLS. Local
private monitoring has its own conditions; the central monitoring owner must
provide private ingestion/query connectivity when needed. Confirm a reused
Application Insights component belongs to the selected workspace. Do not enable
mixed workspaces just to suppress validation.

## Private DNS ownership

<a id="4-select-shared-dns-zones"></a>

Choose one ownership model:

| Model | Responsibility |
| --- | --- |
| Locally managed | Template creates applicable zones and links |
| Per-zone BYO | Exact existing zone IDs suppress local creation and automatic VNet links; owners supply links/resolution |
| Azure Policy-managed | `POLICY_MANAGED_PRIVATE_DNS=true` suppresses template DNS zones/zone groups; clear BYO overrides and agree the Policy-owned records/groups/links |

**Peering does not propagate DNS zone links.** Every client VNet needs a direct
link or explicit DNS resolver/forwarding path to a linked network. With custom
DNS, a zone link alone does not reconfigure clients. Avoid duplicate
authoritative zones that hide records.

Use actual approved zone IDs, not guessed names or synthesized cross-scope IDs.
The following suffixes complete `EXISTING_PRIVATE_DNS_ZONE_<SUFFIX>_RESOURCE_ID`
for Azure public cloud:

| Suffix | Zone |
| --- | --- |
| `COGSVCS` | `privatelink.cognitiveservices.azure.com` |
| `OPENAI` | `privatelink.openai.azure.com` |
| `AISERVICES` | `privatelink.services.ai.azure.com` |
| `SEARCH` | `privatelink.search.windows.net` |
| `COSMOS` | `privatelink.documents.azure.com` |
| `BLOB` | `privatelink.blob.core.windows.net` |
| `KEYVAULT` | `privatelink.vaultcore.azure.net` |
| `APPCONFIG` | `privatelink.azconfig.io` |
| `CONTAINERAPPS` | `privatelink.<region>.azurecontainerapps.io` — must match the deployment region |
| `ACR` | `privatelink.azurecr.io` |
| `AZUREMONITOR` | `privatelink.monitor.azure.com` |
| `OMSOPSINSIGHTS` | `privatelink.oms.opinsights.azure.com` |
| `ODSOPSINSIGHTS` | `privatelink.ods.opinsights.azure.com` |
| `AZUREAUTOMATION` | `privatelink.agentsvc.azure.automation.net` |
| `APPINSIGHTS` | `privatelink.applicationinsights.io` |

Monitoring overrides apply only when the corresponding local private-monitoring
resources are created; they do not configure a central AMPLS. Provide only
applicable zones. See the [full parameter reference](parameterization.md#private-dns-zones).
Use unique link names where multiple spokes share zones; `DNS_ZONE_LINK_SUFFIX`
only affects links the template itself creates.

## Peering and bootstrap ordering

<a id="5-provision-and-complete-both-peering-directions"></a>

A fresh spoke can require the network operator during the first provision.
As soon as the VNet exists, complete the authorized reverse peering and DNS
links so bootstrap and private configuration can resolve and reach dependencies.
Waiting for those stages to finish first can cause a recoverable failure.

The template creates **spoke→hub only**, for a new isolated VNet when enabled.
The hub owner creates the matching **hub→spoke** peering with forwarded traffic
and VNet access. If peering is externally managed or the VNet is BYO, the
network owner creates both. Record exact spoke-specific names for retirement.

Gateway transit is a separate design choice. To consume the hub's gateway,
the hub side allows gateway transit and the spoke uses remote gateways
(`HUB_INTEGRATION_PEERING_USE_REMOTE_GATEWAYS=true` for template-managed peering).
Do not set the spoke's `ALLOW_GATEWAY_TRANSIT` to consume a hub gateway; that is
the opposite direction.

## Verify the network contract

<a id="6-link-dns-and-verify-from-the-connected-host"></a>

Use exact selected names and IDs:

```bash
az network vnet peering list -g <hub-resource-group> --vnet-name <hub-vnet> \
  --subscription <hub-subscription-id> -o table
az network vnet peering list -g <spoke-resource-group> --vnet-name <spoke-vnet> \
  --subscription <spoke-subscription-id> -o table
az network private-dns link vnet list -g <dns-resource-group> \
  --zone-name <private-zone-name> --subscription <dns-subscription-id> -o table
```

Expect both peerings `Connected` with the approved forwarded-traffic/gateway
settings, and required DNS links `Completed`. Inspect effective routes on a
running workload/jumpbox NIC and route-table associations on managed subnets:

```bash
az network nic show-effective-route-table --ids <running-jumpbox-nic-id> -o table
az network vnet subnet list -g <spoke-resource-group> --vnet-name <spoke-vnet> \
  --query "[].{name:name,prefix:addressPrefix,routeTable:routeTable.id}" -o table
```

Expect the intended hub `VirtualAppliance` default route or approved shared route
policy. Confirm the actual deployment host's private DNS/TCP/TLS path with the
[standalone connectivity checks](standalone.md#verify-private-connectivity).
Check service authorization and a new test trace in the intended workspace.
`Connected` alone proves none of those data-plane results.

For interactive access, use the **hub's** Bastion or approved VPN, not a local
Bastion that this design disabled. Native RDP requires supported client/SKU
and tunneling. An authorized portal password reset is safer than placing
credentials in shell history or adding a public VM IP.

## Recovery and spoke retirement

<a id="7-recover-safely"></a>
<a id="8-clean-up-only-the-spoke"></a>

| Symptom | Inspect before retry |
| --- | --- |
| Peering not connected | Both IDs, overlap, remote-scope permissions and reverse peering |
| Public/NXDOMAIN answers inside the network | Zone IDs, groups/records, links for the actual client VNet and resolver forwarding |
| Bootstrap, pull or package timeout | Effective UDR/NSG, reverse peering and firewall denies for the actual source subnet/destination |
| Missing central telemetry | Workspace/component permissions and association, AMPLS, DNS and ingestion/query paths |
| Quota, Policy or expired token | Failed deployment operations and the specific approved capacity, policy or authentication repair |

Retry with the same approved revision, parameters and environment after repair;
do not disable Search, open endpoints or skip checks for a green result.
Use [foundation reconfiguration](../agent-landing-zone/deploy-infra-only.md#reconfigure-or-upgrade-the-foundation).

For [safe removal](../agent-landing-zone/deploy-full-stack.md#remove-an-environment),
obtain workload/data-retention approval and inventory dependencies first.
Retire only recorded reverse peering and DNS links dedicated to this spoke with
their owners. Preserve shared zones, hub VNet, Bastion, firewall, route tables,
workspace and Application Insights. Confirm other spokes remain healthy.
