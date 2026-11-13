<span id="network-isolation"></span>

# Network design

After choosing the [network arrangement](planning.md#decide-who-owns-the-network),
plan how operators, build agents and services will reach one another.
This page explains connectivity and ownership. Use
[Deployment settings](configuration.md#network-and-security) for input names
and the deployment guides for execution.

A virtual network (**VNet**) contains the workload's private address space.
A **private endpoint** gives a service a private address in that network.
Private DNS directs the normal service hostname to that address.

<span id="what-changes-with-isolation"></span>
<span id="enable-isolation"></span>

## Public and private access

Use **private networking for production and sensitive data**.
`NETWORK_ISOLATION` defaults to `false`, so the recommended private design
requires explicit selection before provisioning.

With isolation enabled and an empty `allowedIpRanges`, workload services use
private endpoints and private DNS, with public service access disabled.
A nonempty allowlist can enable IP-restricted public paths on supported
services. Azure Resource Manager remains public. Telemetry and optional
public ingress have their own settings.

Public endpoints still require authentication and authorization.
Private endpoints do not grant access to data. Neither is a reason to bypass
identity checks or weaken the network to recover a failure.

<span id="private-network-access"></span>
<span id="reach-the-private-network"></span>
<span id="connected-host-requirements"></span>
<span id="image-builds-in-isolated-deployments"></span>

## Optional PostgreSQL paths

[Optional PostgreSQL](postgresql.md) is fresh-only and default off. Basic adds
external workload-profiles ACA VNet integration and dedicated Standard NAT/static
outbound IPv4, allowing that exact PG source plus explicit operator ranges.
Legacy Consumption-only and forced default routes that bypass NAT are rejected;
corporate routes and jumpbox NAT are not overwritten. Isolation uses app PE/DNS
and public PG disabled regardless of common allowlists, with no PG delegated
server subnet. Agree BYO/managed/existing/policy DNS ownership and operator access.
Network readiness does not grant SQL permissions; OID-bound bootstrap is manual.

## Plan each connectivity path

| Path | What must be reachable | Planning consequence |
| --- | --- | --- |
| Deployment host to services | Private configuration, secrets and service APIs, as well as Azure management APIs. | Use an authorized VPN-connected workstation, VM or runner with the required DNS and routes. Provisioning can also need private access. |
| Build agents to registry and dependencies | The private registry and approved package destinations. | Isolated remote builds use a pool inside the VNet. This pool does not connect the deployment host. |
| Workloads to services | The selected model, data, configuration and tool endpoints. | Plan private paths and approved outbound access, then grant the appropriate service permissions separately. |
| Search to sources and models | The source and extraction/embedding services. | Native private ingestion can require Search-managed links and approval by the target owners. |

The public Azure management plane alone is not enough for the platform
workflow. Configuration checks can run before or after resource provisioning.
A disconnected operator cannot assume that `azd provision` will complete.

<span id="verify-private-connectivity"></span>
<span id="private-connectivity-checks"></span>

## Plan DNS and routing together

Private DNS must resolve service hostnames to the intended private addresses.
Connect zones to the right networks and arrange forwarding for VPN clients
and connected hubs. Peering by itself does not propagate DNS.

Routing and firewall policy must permit the connection in both directions.
TLS must still validate the original service hostname. Successful connectivity
does not prove that the calling identity can use the API or retrieve a document.

Hub integration requires agreement with the platform team about reverse
peering, routes, DNS, gateway transit and changes to shared resources.
Policy-managed DNS and explicitly reused DNS zones are alternative arrangements.
Their owners must provide the necessary links and readiness.

### BYO hub Private DNS checklist

When central hub DNS or Azure Policy manages Private DNS instead of standalone
deployment zones, ensure every enabled boundary below resolves in the hub,
spoke and operator resolver path:

| Service boundary | Required Private DNS zone or static record |
| --- | --- |
| Microsoft Foundry and AI services | `privatelink.cognitiveservices.azure.com`, `privatelink.openai.azure.com` and `privatelink.services.ai.azure.com`. |
| Search and Blob storage | `privatelink.search.windows.net` and `privatelink.blob.core.windows.net` (used by document storage, Foundry backing storage and AMPLS packs). |
| Cosmos DB | `privatelink.documents.azure.com`. Required even when application Cosmos DB is disabled (`DEPLOY_COSMOS_DB=false`) if Foundry Agent Service provisions or links its associated enterprise memory Cosmos account. |
| App Configuration, Key Vault and Container Registry | `privatelink.azconfig.io`, `privatelink.vaultcore.azure.net` and `privatelink.azurecr.io`. |
| Container Apps Environment | `privatelink.<region>.azurecontainerapps.io`. When the environment is internal (`internal = true`), also create a Private DNS zone for the environment `<defaultDomain>` with static `A` records `*` and `@` pointing to the environment `staticIp`. |
| Internal AI Gateway and optional PostgreSQL | `privatelink.azure-api.net` when integrating an internal or private Azure API Management AI Gateway, plus `privatelink.postgres.database.azure.com` when optional PostgreSQL is enabled. |
| Azure Monitor Private Link Scope (AMPLS) | `privatelink.monitor.azure.com`, `privatelink.oms.opinsights.azure.com`, `privatelink.ods.opinsights.azure.com` and exact hyphenated `privatelink.agentsvc.azure-automation.net` (plus `privatelink.blob.core.windows.net`). AMPLS maps Application Insights ingestion, live metrics and query endpoints through `privatelink.monitor.azure.com` rather than `privatelink.applicationinsights.io`. |

### Hub-and-spoke peering and routing checklist

- **Bidirectional VNet peering:** configure spoke-to-hub peering (`HUB_INTEGRATION_CREATE_HUB_PEERING`) and reverse hub-to-spoke peering with `allowVirtualNetworkAccess` and `allowForwardedTraffic` enabled in both directions.
- **Gateway transit settings:** align `allowGatewayTransit` on the hub peering with `useRemoteGateways` (`HUB_INTEGRATION_PEERING_USE_REMOTE_GATEWAYS`) on the spoke peering when sharing a hub VPN or ExpressRoute gateway.
- **Gateway and firewall return routes:** advertise or configure return routes for the spoke VNet address space on the hub firewall and on VPN or ExpressRoute gateways so operator workstations, DNS resolvers and CI/CD runners reach spoke private endpoints symmetrically.

<span id="isolation-and-provisioning"></span>
<span id="choose-subnet-ownership"></span>
<span id="default-subnets"></span>
<span id="subnet-delegations"></span>

## Allocate subnets and agree ownership

Decide whether the template creates the VNet and subnets, manages selected
subnets in an existing VNet, or uses externally managed subnets.
An existing VNet is not automatically read-only.

Reserve nonoverlapping address space for enabled consumers. The
[subnet address plan](configuration.md#default-subnets) lists default ranges
and delegations. These are configurable reservations, not a promise that
every listed service is deployed.

Turning off subnet creation does not turn off its consumer. Required subnets
must already exist with compatible sizes, names, delegations and security
associations. Application private endpoints have a separate subnet from
Foundry/grounding endpoints, independently of resource group count.

VPN gateways, AI Gateway and Power Platform integrations need their own
setup. Reserving a subnet does not deploy or connect them.
See [subnet inputs](configuration.md#subnet-creation-and-addressing).

!!! warning "Foundry Agent Service subnet binding is immutable"
    Microsoft Foundry Agent Service `networkInjections` subnet binding (`agentSubnetName`, default `agent-subnet`) is **immutable after initial capability-host and account provisioning**. Changing VNets or agent subnets later cannot be applied in place and requires recreating the Foundry resource. Confirm `EXISTING_VNET_RESOURCE_ID` and `agentSubnetName` (`AZURE_AGENT_SUBNET_NAME`) before the first `azd provision`.

### Multi-resource-group placement checklist

Confirm target groups, RBAC and Azure Policy coverage across all four [resource group destinations](configuration.md#resource-group-destinations) before first provision:

| Parameter and environment input | Scope and pre-provision verification |
| --- | --- |
| `AZURE_RESOURCE_GROUP` | Foundry and grounding root resource group. Verify subscription region, Foundry model or gateway plan and root deployment permissions. |
| `applicationResourceGroupName` (`AZURE_APP_RESOURCE_GROUP`) | Application Container Apps, Container Registry, App Configuration, Key Vault, application Cosmos DB and observability resources. Pre-create when `CREATE_RESOURCE_GROUPS=false`. |
| `networkResourceGroupName` (`AZURE_NETWORK_RESOURCE_GROUP`) | Workload-owned VNet, subnets, NSGs, NAT gateway and standalone firewall. Align with existing-VNet ownership when reusing networking. |
| `privateEndpointResourceGroupName` (`AZURE_PE_RESOURCE_GROUP_NAME`) | Explicit private endpoint resource group override (takes precedence over `SIDE_BY_SIDE=false` existing-VNet placement and `AZURE_NETWORK_RESOURCE_GROUP`). Confirm scoped RBAC and Private DNS zone links or policy coverage in the resolved group. |

<span id="component-runtime-egress"></span>
<span id="review-before-provisioning"></span>
<span id="policy-ownership"></span>
<span id="source-scope-and-recovery"></span>
<span id="application-specific-package-feeds"></span>
<span id="firewall-sku-and-management-networking"></span>
<span id="opt-in-firewall-dns-proxy"></span>

## Agree outbound access and firewall ownership

Distinguish build-package access from the destinations used by running workloads.
Approve only the destinations required by the selected components.
The [outbound-access reference](configuration.md#outbound-access)
explains how declarations become scoped rules.

For a platform-managed firewall, the workflow reconciles its owned rules.
For an external firewall, it reports requirements for the network owner to
approve and apply. It does not modify that external policy.

Workloads sharing a source subnet share its allowed destinations.
Subnet-scoped rules are not component-level isolation. Use dedicated subnets
or environments when separate outbound boundaries are required.

Standalone private deployments default to a Basic firewall. Choose Standard
when its features, such as DNS proxy, are required, and plan the corresponding
[firewall networking](configuration.md#firewall-sku-and-management-networking).
Enabling DNS proxy does not redirect client DNS or repair missing private-zone links.

### BYO hub firewall Azure Monitor rules

When spoke subnets route outbound traffic through a BYO hub firewall, allow
outbound HTTPS (`TCP 443`) to AMPLS and Azure Monitor **both ingestion and
query** endpoints: `*.loganalytics.io`, `*.applicationinsights.io`,
`*.monitor.azure.com`, `*.in.applicationinsights.azure.com`,
`*.ods.opinsights.azure.com` and `*.oms.opinsights.azure.com`. The built-in
standalone template firewall already covers `*.loganalytics.io` and
`*.monitor.azure.com`, whereas external hub firewall policies remain
report-only and must allow both ingestion and workspace or trace query FQDNs.

<span id="jumpbox-access"></span>
<span id="use-the-jumpbox"></span>
<span id="post-provision-can-be-deferred"></span>

## Prepare operator access

An approved VPN, a connected VM/runner or a jumpbox reached through Bastion
can provide private access. Choose the path with the network and identity owners.
See [Private access](private-access.md) or
[jumpbox access](deploy-infra-only.md#access-the-jumpbox) for setup.

The host needs the reviewed inputs, deployment state and scoped permissions.
A managed identity does not automatically grant the necessary service roles.
See the deployment guide's prerequisites.

Deferring post-provision leaves configuration incomplete, even if resource
provisioning reports success. Deferral does not establish connectivity or
bypass deployment checks. Follow the
[deferred-configuration procedure](deploy-infra-only.md#complete-a-deferred-post-provision)
from a connected host before deploying applications.

<span id="private-native-blob-ingestion"></span>

## Account for integration-specific paths

Agent App MCP Server needs HTTPS from the actual Hosted or Container Apps
consumer to its separate Container App, plus configuration and identity
connectivity even when `MCP_TOOLSETS=[]`.

Only the selected NL2SQL toolset adds outbound paths to application Cosmos,
generation/embedding models and the approved SQL destination. SQL-password
sources also need the selected Key Vault. The administrative metadata importer
needs its own catalog/model path.

Plan routes, DNS and TLS with the SQL and network owners; provisioning does
not authorize an external database or make its network reachable.

MCP does not add a Search path or Search grant. Other retrieval consumers keep
their independent requirements. See [MCP onboarding](agent-app-mcp.md#onboard-sql-before-inviting-users).

For private native Blob ingestion, plan Search-to-source/model links and
approval by the authorized target owners. Pending approval is not fixed by
public access or weaker permissions. See
[Search private-link requirements](configuration.md#search-shared-private-links)
and [Foundry IQ connectivity](foundry-iq.md#ownership-and-connectivity).

!!! warning "A private foundation does not make every integration private"
    [Teams and Microsoft 365 Copilot publication](publish-to-teams.md) uses a
    manually enabled, source-IP-filtered public Activity endpoint. It is
    **not private end to end**. Do not use that path when public agent ingress
    is prohibited. Other Foundry APIs remain private.

[Copilot Studio](connect-copilot-studio.md) uses a different, delegated
Power Platform private-network path and does not require that Activity exception.

<span id="integrate-with-an-existing-hub"></span>

## Continue to configuration

Use [Deployment settings](configuration.md#hub-integration) for hub, DNS,
subnet and resource-reuse inputs. The provider-specific
[deployment guides](index.md#infrastructure-and-application) own the commands,
connectivity checks and validation.
