# Standalone network reference

A standalone foundation manages its own workload network rather than relying
on a shared hub. With isolation enabled it can include local private DNS,
private endpoints, firewall, Bastion and a jumpbox. For shared network services,
use the [hub-and-spoke design](hub-and-spoke.md).

Execute [Deploy infrastructure only](../agent-landing-zone/deploy-infra-only.md)
for either the independent Bicep foundation or the Agent foundation.
Execute [Deploy the full stack](../agent-landing-zone/deploy-full-stack.md)
when the Agent application is required. This page is the network reference
for those procedures, not a third deployment path.

## Ownership and scope

<a id="1-prepare-a-pinned-checkout"></a>

The workload team owns resources, backups and cost in its dedicated group.
The network/security owners approve addresses, egress and public exceptions.
Confirm regional capacity, resource-provider registration and scoped deployment
permissions before provisioning.

The upstream Bicep foundation creates a hello-world Container App, not the
Agent application. Agent Landing Zone instead uses its repository-owned
`infra/` and additional hooks. Do not deploy both sources into one environment.
The [inventory and cost estimates](deployed-resources.md) describe the independent
foundation; selected Agent application resources can differ.

## Address planning

<a id="2-plan-addresses"></a>

Reserve a VNet range that does not overlap other VNets, VPN/on-premises ranges
or future hub connections. The upstream default VNet is `192.168.0.0/21`.
Changing only that prefix does not change the individual subnet prefixes.

The following is a **complete illustrative allocation**, not a universally safe
range. Replace it as a unit if it conflicts with your approved design.

| Native parameter | Example allocation |
| --- | --- |
| `vnetAddressPrefixes` | `["10.200.0.0/21"]` |
| `agentSubnetPrefix` | `10.200.0.0/24` |
| `acaEnvironmentSubnetPrefix` | `10.200.4.0/23` |
| `peSubnetPrefix` | `10.200.2.0/26` |
| `azureBastionSubnetPrefix` | `10.200.2.64/26` |
| `azureFirewallSubnetPrefix` | `10.200.2.128/26` |
| `gatewaySubnetPrefix` | `10.200.2.192/26` |
| `azureAppGatewaySubnetPrefix` | `10.200.3.0/27` |
| `jumpboxSubnetPrefix` | `10.200.3.64/27` |
| `devopsBuildAgentsSubnetPrefix` | `10.200.3.96/27` |

These native values belong in the selected source's reviewed root
`main.parameters.json`; there is no `VNET_ADDRESS_PREFIXES` mapping.
Keep the complete file with the deployment inputs and carry it to a connected
host. Environment refresh does not restore file customizations.

Every subnet must fit without overlap. Keep `AzureBastionSubnet` and
`AzureFirewallSubnet` at least `/26`. Reserve private-endpoint capacity and
growth. The workload-profile Container Apps environment example uses the
recommended `/23`; current preflight enforces `/27` minimum and warns below
the recommendation. That minimum is not a future-scale guarantee.

## Private network choices

<a id="3-configure-the-standalone-private-topology"></a>

| Input | Private standalone intent |
| --- | --- |
| `DEPLOYMENT_MODE` | `standalone`; records intent, not a replacement for explicit flags |
| `NETWORK_ISOLATION` | `true` |
| `DEPLOY_AZURE_FIREWALL` | `true` for local inspected egress |
| `DEPLOY_JUMPBOX`, `DEPLOY_BASTION`, `DEPLOY_NAT_GATEWAY` | Independently selected; the canonical runbook shows the self-contained choice |
| `BASTION_SKU_NAME`, `BASTION_ENABLE_TUNNELING` | Standard/Premium with tunneling for native RDP |
| `DEPLOY_ACR_TASK_AGENT_POOL` | Upstream defaults off; the Agent platform selects it for private remote builds |

The NAT gateway supports its configured subnet; it is not a firewall or a
substitute for reviewing effective routes. Inspect the local firewall route and
required destinations in the
[upstream egress reference](https://github.com/Azure/bicep-ptn-aiml-landing-zone#firewall-egress-allow-list-network-isolation).
Agent platform build egress also includes its own dependency-specific inputs.
An ACR Tasks pool does not make the deployment host VNet-connected.

With empty native `allowedIpRanges`, private service endpoints are the intended
path. A nonempty approved list can enable IP-restricted public access.
Storage trusted-service/resource-instance exceptions and Shared Key access
remain independent controls; see [Storage controls](parameterization.md#solution-storage-controls).
Optional [Application Gateway ingress](public-ingress.md) is a separate,
explicitly reviewed public entry point.

## Existing VNet and DNS ownership

With `USE_EXISTING_VNET=true`, decide who manages each subnet, NSG, route table
and delegation. Do not update existing subnets under isolation with
`DEPLOY_NSGS=false`; retain managed NSGs or use `DEPLOY_SUBNETS=false` and have
the network owner prepare the complete subnet configuration.

Choose local DNS, per-zone BYO IDs or Azure Policy-managed DNS deliberately.
Shared zones require links or forwarding for every actual client VNet;
peering alone does not propagate zone links. Avoid duplicate authoritative
zones. See [private DNS parameters](parameterization.md#private-dns-zones)
and [Policy ownership](hub-and-spoke.md#private-dns-ownership).

The BYO-VNet reserved `AzureBastionSubnet` is excluded from generic NSG attachment
when Bastion is disabled; enabled Bastion uses its dedicated compliant NSG.
Do not rename subnets, renumber prefixes or reapply an older workaround
automatically on existing deployments. Plan such migrations explicitly.

## Provisioning boundary

<a id="4-preview-and-provision"></a>

Return to [preview and provision](../agent-landing-zone/deploy-infra-only.md#step-4-preview-and-provision)
after the network inputs are approved. Preflight validates parameters and
regional readiness, not successful bootstrap or data-plane access.
Inspect the VM Custom Script Extension result if software bootstrap is selected;
it is not evidence that all Agent prerequisites are installed.

For a new build subnet created in a BYO VNet, the ACR Tasks pool depends on the
conditional subnet deployment. With `DEPLOY_SUBNETS=false`, subnet readiness is
the external network owner's responsibility. A first-attempt cold-start check
must start with that subnet absent, record successful operations and the pool's
final state, and distinguish retries from the first attempt. Source availability
and offline CI do not prove this live result.

## Verify private connectivity

<a id="5-verify-private-connectivity"></a>

Inspect the actual endpoint names and approvals in the selected resource group:

```bash
az containerapp list -g <resource-group> \
  --query "[].{name:name,fqdn:properties.configuration.ingress.fqdn}" -o table
az network private-endpoint list -g <resource-group> \
  --query "[].{name:name,state:provisioningState,connections:privateLinkServiceConnections[].privateLinkServiceConnectionState.status}" -o json
```

From the actual connected Windows host, repeat these checks for the app, Search,
Storage, App Configuration and registry hostnames:

```powershell
Resolve-DnsName -Name <service-hostname> -Type A
Test-NetConnection -ComputerName <service-hostname> -Port 443
```

Expect private answers matching the intended endpoint NICs and successful TCP
connections. Test HTTPS with normal certificate validation and the intended
authorized identity. A 401/403 can show an endpoint responds, but is not a
successful data-access authorization test. Confirm telemetry reaches the
intended workspace.

For the independent foundation's placeholder app, an HTTPS 200 from inside the
network is a runtime/network smoke test only. Agent acceptance also requires
sign-in, agent/tool execution and positive/negative document-access tests.
An unconnected workstation must not serve a private app or read private data;
public DNS outside the VNet alone does not establish exposure.

Use the portal's Bastion connection or approved VPN for interactive access.
Native Bastion RDP requires a supported Windows client, Standard/Premium SKU and
tunneling. Use the provisioned VM credential or an authorized portal reset
(default username `testvmuser`); never put passwords in command history or add a
public VM IP as a shortcut.

## Recovery and retirement

<a id="6-recover-without-weakening-isolation"></a>
<a id="7-clean-up-a-dedicated-environment"></a>

Inspect failed deployment operations, system logs and firewall denies. Correct
the specific quota, Policy, DNS, route, egress or role failure; preserve the same
approved inputs on retry. Do not disable isolation, purge a partially deployed
group or move existing resources to another region as generic recovery.

Use [foundation reconfiguration](../agent-landing-zone/deploy-infra-only.md#reconfigure-or-upgrade-the-foundation)
and [safe removal](../agent-landing-zone/deploy-full-stack.md#remove-an-environment).
If this environment later adopted a hub, preserve shared services and retire
only its own attachments with their owners.
