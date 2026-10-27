# Network isolation

Private networking is selected with the `NETWORK_ISOLATION` deployment input,
which defaults to `false`. This page explains connectivity, DNS and build
requirements rather than deployment steps. [How it works](how-it-works.md)
introduces the input formats and deployment lifecycle.

A **private endpoint** gives a service a private IP address in a VNet.
Private DNS directs its normal hostname to that address. A **virtual private
network (VPN)** connects an authorized remote computer or network to the VNet.
A **jumpbox** is a virtual machine (VM) used for administration; Azure Bastion
provides remote access to it. A NAT gateway provides outbound address
translation. None of these connections grants permission to read service data.

With `NETWORK_ISOLATION=true`, Agent Landing Zone uses private endpoints and private DNS for the deployed workload services. With the default empty `allowedIpRanges`, public access to those service endpoints is disabled. Azure Resource Manager remains public; telemetry and optional public ingress have separate settings.

An explicit, nonempty `allowedIpRanges` in `main.parameters.json` enables
IP-restricted public access on services that support those rules, even with
isolation enabled. Those public paths and any reused network or DNS resources
remain part of the connectivity design.

The [Deploy infra only](deploy-infra-only.md) and
[Deploy full stack](deploy-full-stack.md) runbooks contain the procedures.
The [Azure DevOps runbook](azure-devops.md) covers optional pipeline automation.
[Deployment choices](planning.md) explains standalone and hub integration.
An AI Gateway governs model requests, not workload networking or user access.
Private endpoints, DNS, routes, firewall rules and authorization remain necessary.

With the [resource group destinations](configuration.md#resource-group-destinations),
locally owned private endpoints default to the resolved network group, which
can differ from their services' groups. The explicit
`AZURE_PE_RESOURCE_GROUP_NAME` override and existing-VNet/`SIDE_BY_SIDE`
precedence in [Deployment settings](configuration.md#general) still apply.

!!! note "Teams and Microsoft 365 Copilot publication"
    [Publish to Teams and M365](publish-to-teams.md) adds a manual, source-IP-filtered
    public exception for the Foundry Activity route while Foundry and Bot Service
    public network access stays disabled. Channel delivery does not use Private
    Link; other Foundry APIs remain private. The template does not enable this exception.

The [Connect Copilot Studio](connect-copilot-studio.md) runbook describes an
authenticated agent flow and Power Platform VNet delegation to reach the Foundry
private endpoint; it does not require the Activity-route public exception.

## What changes with isolation

| Area | `NETWORK_ISOLATION=false` | `NETWORK_ISOLATION=true` |
| --- | --- | --- |
| Workload service access | Public endpoints, with service authentication and authorization | Private endpoints by default |
| DNS | Public DNS | Private DNS zones linked to the VNet |
| Jumpbox, Azure Bastion, NAT gateway | Not deployed by default | Deployed by default |
| Container image builds | Local Docker or regular ACR Tasks | ACR Task agent pool inside the VNet by default |
| Post-provision and deploy | Run from an authorized host that can reach the endpoints | Run from an authorized host connected to the VNet |

!!! note
    The ACR Task agent pool is created only for isolated deployments. When isolation is off, supported components can build with local Docker or regular ACR Tasks. No pool is created, even if `DEPLOY_ACR_TASK_AGENT_POOL` is `true`.

<span id="enable-isolation"></span>

## Isolation and provisioning

`NETWORK_ISOLATION=true` is resolved before provisioning.

The
[application private endpoint subnet pair](configuration.md#optional-application-private-endpoint-subnet)
is optional regardless of whether the workload uses one, two or three resource
groups. Empty `AZURE_APPLICATION_PE_SUBNET_NAME` and
`AZURE_APPLICATION_PE_SUBNET_PREFIX` retain the shared subnet. Supply both to
place enabled application Cosmos DB, Key Vault, App Configuration, Container
Apps, ACR and Azure Monitor Private Link Scope endpoints on a separate subnet;
Foundry/grounding keeps the existing `peSubnetName`/`peSubnetPrefix` subnet.
The application subnet needs a distinct name and an aligned IPv4 CIDR of `/29`
or shorter within the VNet, without overlap with base subnet prefixes.
Existing-VNet ownership and compatibility checks still apply; no extra subnet
is selected merely by splitting resource groups.

Azure Resource Manager (ARM) creates and manages Azure resources through a
public control plane, but `azd provision` also
runs lifecycle hooks. An existing environment can need private App Configuration
access before ARM deployment to resolve its topology. Post-provision also needs
private connectivity, so an unconnected host cannot complete every stage.

The matching deployment runbook therefore requires a connected host. The
default Foundry hosted deployment also needs the image preparation and
deployment metadata stages described in
[Deploy full stack](deploy-full-stack.md).

<span id="reach-the-private-network"></span>

## Private network access

Private services can be reached through:

- **Point-to-site or site-to-site VPN** into the landing zone VNet or a peered hub.
- **A VM or build agent** in the VNet or a peered VNet, with private DNS zone access.
- **The jumpbox VM** deployed by the landing zone, reached through Azure Bastion.

<span id="use-the-jumpbox"></span>

### Jumpbox access

The default jumpbox is a Windows VM. Unless overridden, its administrator user is
`testvmuser`. The password is supplied through the secure `vmAdminPassword`
provisioning input, not a documented Key Vault secret. Unavailable credentials
require an authorized administrator's approved reset procedure, without
exposing passwords in shell history or logs.

Azure Bastion provides portal access to the VM. It still needs the
[deployment prerequisites](deploy-full-stack.md#prerequisites). Docker is not
installed by default and is unnecessary for ACR Task agent-pool builds.

## Connected-host requirements

The connected host needs the same reviewed platform Git commit or release tag
and approved inputs as the original workspace. Its local azd environment also
needs current provisioning outputs. The
[Deploy infra only](deploy-infra-only.md) runbook explains environment
selection, output refresh and separate provisioning/configuration steps.

The jumpbox's managed identity, an Azure-managed service identity that does
not need a stored password, needs the selected application's configuration
and build roles. For hosted-agent authoring,
the runner needs **Foundry User** on the exact
Foundry project, plus read access to the Foundry account. Cognitive Services
Contributor and OpenAI User alone do not grant the agent data-plane actions.
Subscription or resource-group Owner is not an appropriate fix for this denial.
See [Foundry RBAC](https://learn.microsoft.com/azure/foundry/concepts/rbac-foundry)
for the current role catalog and scopes. New grants need time to propagate.

An infrastructure-only deployment stops after provisioning and post-provision
configuration. It can contain placeholder Container Apps without running the
selected applications. The [Deploy full stack](deploy-full-stack.md)
runbook also deploys application code.

### Post-provision can be deferred

When isolation is enabled, post-provision can be **deferred** instead of failing.
`RUN_FROM_JUMPBOX=false` (or `0`, `no`, `skip`) requests deferral, as does
`AZURE_SKIP_NETWORK_ISOLATION_WARNING=true` while `RUN_FROM_JUMPBOX` is not
truthy. A truthy `RUN_FROM_JUMPBOX`, such as `true`, requests the connectivity
check even if the warning flag is set. Deferral produces:

```text
Post-provision configuration explicitly deferred; application setup is incomplete.
```

If the other provisioning stages succeed, `azd provision` reports success, but
the application is **not** configured. Deferral does not bypass earlier topology
or provisioning checks. Configuration remains incomplete until deferral is
cleared and configuration succeeds from a connected host. The
[Deploy infra only](deploy-infra-only.md#complete-a-deferred-post-provision)
runbook provides those steps.

When the deferral settings are not set and the private endpoints cannot be reached, post-provision fails with:

```text
Private post-provision prerequisites failed. Connect through VPN/VNet and rerun postProvision; configuration has not started.
```

!!! warning
    `RUN_FROM_JUMPBOX` only controls whether post-provision is deferred. It does not provide connectivity. `azd deploy` always checks private reachability, and fails with "Private deployment prerequisites failed" when the host cannot reach the endpoints.

## Image builds in isolated deployments

Public build agents cannot reach the default private registry. Remote builds
use an **ACR Task agent pool** inside the VNet
(`DEPLOY_ACR_TASK_AGENT_POOL=true`). Hosted topology composition selects this
pool when network isolation is enabled.

If the pool is missing, `azd deploy` stops before building. Pool creation uses
`DEPLOY_ACR_TASK_AGENT_POOL=true` through the matching deployment runbook.
Where a component supports local builds, `BUILD_MODE=local` instead needs a
VNet-connected host with working Docker.

The local alternative applies to component scripts that support `BUILD_MODE=local`.
Automatic hosted orchestrator image preparation and isolated custom source builds
still require the private pool. Supplying an already-built immutable digest can
skip those builds. To deploy without a pool, the root pre-deploy check also
requires `BUILD_MODE=local`. Each remaining service must support local builds
for that exception to work.

### Application-specific package feeds

The root deployment defaults include dependency-verified package feed
destinations alongside common language and OS package registries, through
the scoped infrastructure build-egress configuration. This is a build-only
allowlist, not a runtime or general Internet exception. It does not allow
every mirror recorded in a custom application's lockfile. The exact component
commit's `resolved` URLs and download redirects determine its build needs.

Additional dependencies are declared in
`parameters.additionalAcrTaskBuildFqdns.value` in the root `main.parameters.json`.
This is an explicit array, not an `azd` environment variable. Provisioning
applies it; the connected runner needs the same reviewed parameter file to
preserve the setting on later provisions.

The Agent Application orchestrator frontend lockfile uses
`ms-feed-2.pkgs.visualstudio.com`, `ms-feed-12.pkgs.visualstudio.com`,
`ms-feed-17.pkgs.visualstudio.com`, and `ms-feed-25.pkgs.visualstudio.com`.
Their public package downloads redirect to `*.vsblob.vsassets.io`.
These four exact feeds and the redirect content delivery network (CDN) are included in the Agent Landing
Zone default build allowlist. `packages.microsoft.com` is already included in
the OS-package rule and does not need an additional entry.

With `extendFirewallForAcrTaskBuilds=true` (the default) and an effective ACR
Task agent pool, the feeds, redirect CDN, and additional hosts are allowed only
from the build-agent subnet over HTTPS on port 443. They are not added to
jumpbox, application, or agent-subnet rules. The additional-host array defaults
to empty.

Disabling the build-egress extension removes these package rules.
Re-enabling it restores them. This egress rule has no DNS-proxy dependency and
does not change client DNS.

Do not enable public registry access, allow all Internet egress, disable TLS
verification, or change dependency integrity hashes to work around a failed build.

See [Package installation fails inside the build pool](troubleshooting.md#package-installation-fails-inside-the-build-pool)
for diagnosis.

## Component runtime egress

Application components declare additional runtime destinations in
[`components[].egress`](build-your-own-app.md#runtime-egress-declarations).
The plan follows actual enabled workloads: optional ingestion, hosted or
preserved Container App orchestration, and additive custom applications.
The bundled UI needs no additional fixed destination. Both orchestrator and
ingestion initialize tiktoken, whose empty-cache startup downloads encoding
assets from `openaipublic.blob.core.windows.net` over HTTPS/443.

These are runtime rules, not build-feed rules or replacements for private
endpoints, authentication, DNS or routing. Configured SharePoint, SQL, MCP
and other custom destinations require their own dependency review.

### Review before provisioning

From the platform root with the prepared Python environment, set the intended
topology, ingestion selection and application definition in the selected azd
environment, then run:

```bash
python -m config.deployment.egress --plan --environment <environment-name>
```

This reads the named local azd environment and validates declarations without
Azure access. Review `policyMode`, selected components, destinations and
purposes. The preprovision hook repeats this calculation, prints it and saves
`.azure/<environment-name>/component-egress-plan.json` before foundation
deployment. Approval of provisioning includes these declared requirements.

After infrastructure exists and local provisioning outputs are current, use:

```bash
python -m config.deployment.egress --review --environment <environment-name>
```

This is read-only. It resolves actual workload subnet prefixes and, for a
deployment-managed policy, reports additions, updates and removals. A fresh
deployment cannot resolve subnet prefixes until its infrastructure exists.
Postprovision and predeploy print this resolved plan before managed
reconciliation. If postprovision is explicitly deferred, reconciliation is
also deferred; predeploy still enforces the connectivity and plan checks.

### Policy ownership

| Deployment | Behavior |
| --- | --- |
| `NETWORK_ISOLATION=false` | No component firewall reads or writes; declarations do not create a firewall |
| Isolated with a deployment-managed firewall | Reconciles only marked application rules in `AgentLzComponentEgress`, priority 400 |
| Isolated with an external firewall | Reports required rules and legacy components; never reads or mutates the external policy |

For managed policies, the runner needs management-plane subnet reads and
`Microsoft.Network/firewallPolicies/ruleCollectionGroups/read` and `write`
on the deployment policy. The reconciler does not write the parent policy.
For external policies, the network owner compares the report with their own
policy and applies approved changes. Reporting does not prove that egress is
allowed.

Shared destination/protocol/port tuples produce one rule, with sources and
ownership combined across components. Removing one owner narrows sources where
possible; the rule remains until its final declared owner disappears.
Enabled legacy components with absent declarations retain their earlier owned
requirements. Other rules and collections, including unmarked entries inside
the component group, are preserved. Ownership collisions, malformed marked
rules, conflicting priorities or concurrent changes fail rather than being
silently adopted or overwritten.

### Source scope and recovery

Rules use the actual provisioned Container Apps or Foundry agent subnet
prefixes, including existing-VNet selections, not the whole VNet or `*`.
**Subnet scope is not component isolation:** every workload sharing a source
subnet can use its union of allowed destinations. Existing platform rules can
also allow traffic. Use dedicated subnets or environments and an approved
network design when workloads need distinct egress boundaries.

After changing declarations or selections, review the new local plan and run
the normal provisioning sequence before deploying. A missing or stale saved
plan stops apply before Azure access. Do not copy a plan or provisioning
outputs from another environment.

For rollback, first review explicit empty declarations for the components
whose additional rules should be removed, then reconcile using the current
hooks. Keep declarations for any remaining consumers. Only afterward roll
back hooks or metadata: reverting code alone does not remove existing rules.
Never delete shared foundation groups or externally managed policy content.

<span id="verify-private-connectivity"></span>

## Private connectivity checks

The runbooks check service hostnames from the deployment runner, including
the host in `APP_CONFIG_ENDPOINT`:

| Check | Expected result | Meaning |
| --- | --- | --- |
| DNS | Only private IPv4 addresses (10.x, 172.16 through 31.x or 192.168.x) | The runner resolves the private endpoint rather than the public endpoint. |
| Transmission Control Protocol (TCP) | Connection succeeds on port 443 | Routing and firewall policy allow the endpoint connection. |
| TLS | Handshake succeeds with the original hostname and normal certificate validation | The connection reaches the expected service securely. |

Public DNS answers usually indicate a missing private-zone link or an
incorrect VPN/hub forwarding path.

On Windows, `nslookup` can differ from the operating system resolver used by
the Python prerequisite check, especially with VPN Name Resolution Policy
Table (NRPT) rules. That check requires private IPv4 answers and rejects mixed
public/private, IPv6, loopback and link-local answers. It then verifies TCP 443
and TLS without sending an HTTP request or credentials. Connectivity is not
authorization: API access and document permissions still need tests with the
intended user identities.

### Opt-in firewall DNS proxy

`ENABLE_FIREWALL_DNS_PROXY` defaults to `false` and maps to the Bicep boolean
`enableFirewallDnsProxy` (also default `false`), which sets
`dnsSettings.enableProxy`. It applies only when the existing
`deployAzureFirewall` and `networkIsolation` gates enable firewall deployment.
It is intended for a topology that deliberately uses the firewall as its DNS
forwarding path. The matching deployment runbook applies the selection through
normal provisioning. Enabling the proxy does
**not** redirect VNet or VPN clients to the firewall or rewrite their DNS
configuration. It is independent of the build-feed egress allowlist.

Client DNS routing and private-zone resolution remain separate requirements.
A proxy cannot repair missing zone links, VPN routes or application
authentication. Disabling it requires confirmation that the deployed DNS path
does not depend on it before reprovisioning.

## Private native Blob ingestion

For the default native Blob path, Search reads and processes Blob documents
for Foundry IQ retrieval. A `searchIndex` source instead exposes an index
populated by another pipeline. Their private-network setup differs.

Native `azureBlob` ingestion uses outbound shared private links managed by
Search. Configuration verifies deployment-owned links, targets and groups
before dependent cleanup/mutation and again before knowledge source creation.
It **does not automatically approve** target connections. Pending links
require approval by an authorized target administrator for each connection.

The gate is limited to `NETWORK_ISOLATION=true`, `RETRIEVAL_BACKEND=foundry_iq`
and rendered native `azureBlob` sources, excluding the `searchIndex` pattern.
It checks the Agent Application Search link to deployment Blob storage (`blob`)
and the links to the deployment Foundry account (`openai_account`,
`foundry_account`, `cognitiveservices_account`). It does not configure the
separate Foundry Search service or unrelated services. Exact names come from
the template's `SEARCH_SHARED_PRIVATE_LINKS` manifest, including bounded
Foundry names. The exact Search shared-link GET must return the expected
name, target and group. If its body includes a resource ID, that must match
too.

The target service receives a private endpoint connection (PEC) request.
Because its name, message and endpoint ID may not identify the originating
Search link, an administrator must verify and approve the correct request.
The configuration script reads the deployment's Search links and leaves
target-side approval to that administrator. See Microsoft's
[approval and shared-link status procedure, sections 2 and 3](https://learn.microsoft.com/en-us/azure/search/search-indexer-howto-access-private).

A `Pending` source link stops immediately with its exact Search ID, target
ID, group and link name for administrator investigation and approval.
After approval, configuration needs another run. Each source link must report connection
status `Approved` and provisioning state `Succeeded` before configuration
continues. Read timeouts or denials require restored connectivity or Search
read permissions, not public access. See
[Search shared private links are not ready](troubleshooting.md#search-shared-private-links-are-not-ready).

Polling has a 600-second total readiness budget, a 10-second interval and
ARM request timeouts of at most 30 seconds (limited by the remaining budget).
Each exact Search shared link must be `Approved` and `Succeeded`, the
documented source-side readiness signal. Approved links whose provisioning
is still propagating use bounded polling. Pending approval does not spend
this budget waiting for an unprovable target match. Administrator-approved
links are usable even when target PECs are paginated, opaque or unreadable
by the runner. The existing Azure CLI/managed-identity credential is reused.
The runner needs Search shared-link read permission, with no new secret,
target PEC read/write requirement or automatic RBAC grant.

Native ingestion supports configured Foundry IQ source kinds and is not
feature-equivalent to Agent App Ingestion. Choosing it does not remove
Entra ID authentication, on-behalf-of (OBO) token exchange, RBAC or
document-level authorization. OBO exchanges a user's token for another API's
token while retaining that user's delegated identity.
Azure Data Lake Storage (ADLS) Gen2 uses Blob storage with a hierarchical
directory namespace. In particular,
`FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS=[]` is a deliberate shared-source
metadata choice for active, supported non-ADLS native Blob ingestion, not a
workaround for a private connection failure. Infrastructure-published `[]`
for `ai_search` (any pattern) or `foundry_iq` / `searchIndex` is accepted as
unused metadata, not a shared-source opt-in: no native Blob source is rendered.
See
[Explicit shared-source permission options](configuration.md#explicit-shared-source-permission-options).

## Integrate with an existing hub

Hub integration uses `DEPLOYMENT_MODE=ailz-integrated` with explicit settings:

| Setting | Purpose |
| --- | --- |
| `DEPLOYMENT_MODE=ailz-integrated` | Declares integration intent; does not attach a hub or override component flags by itself |
| `HUB_INTEGRATION_HUB_VNET_RESOURCE_ID` | Hub VNet to peer with |
| `HUB_INTEGRATION_CREATE_HUB_PEERING` | Create spoke-to-hub peering for a new spoke VNet (default `true`); hub owner supplies reverse peering. Existing VNet peerings are externally managed |
| `HUB_INTEGRATION_PEERING_ALLOW_GATEWAY_TRANSIT` | Allow gateway transit (default `false`) |
| `HUB_INTEGRATION_PEERING_USE_REMOTE_GATEWAYS` | Use the hub gateway (default `false`) |
| `HUB_INTEGRATION_EGRESS_NEXT_HOP_IP` | Next hop for egress, for example the hub firewall |
| `HUB_INTEGRATION_EXISTING_ROUTE_TABLE_RESOURCE_ID` | Existing route table to attach |
| `AZURE_PE_RESOURCE_GROUP_NAME`, `AZURE_PE_LOCATION` | Where to place private endpoints |
| `EXISTING_*` | Reuse the existing VNet, private DNS zones, jumpbox, Bastion, NAT gateway or monitoring resources |

[Deployment settings](configuration.md#network-and-security) lists the inputs;
[hub-and-spoke design](../bicep/hub-and-spoke.md) explains their network effects.
Execution steps belong to the
[Deploy infra only](deploy-infra-only.md) runbook.
