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
