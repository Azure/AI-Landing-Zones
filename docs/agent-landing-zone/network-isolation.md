# Network isolation

With `NETWORK_ISOLATION=true`, Agent Landing Zone uses private endpoints and private DNS for the deployed workload services. With the default empty `allowedIpRanges`, public access to those service endpoints is disabled. This is not a blanket block on every public endpoint: Azure Resource Manager remains public, and telemetry and optional public ingress have separate settings.

An explicit, nonempty `allowedIpRanges` in `main.parameters.json` enables IP-restricted public access on services that support those rules, even with isolation enabled. Review that exception and any existing network or DNS resources before describing a deployment as private-only.

This page explains what changes when isolation is on, how to reach the private network, and how to complete a deployment from a connected host.

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

## Enable isolation

Set the flag before the first provision:

```bash
azd env set NETWORK_ISOLATION true
azd provision
```

The ARM resource deployment uses a public control plane, but `azd provision` also runs lifecycle hooks. Existing-environment topology discovery can require private App Configuration access before ARM deployment, and post-provision configuration requires private connectivity afterward. Provisioning therefore does not always succeed from an unconnected workstation.

For a complete deployment, use a connected host. A single `azd up` can run the classic workflow when prerequisites and connectivity are ready. A first hosted deployment needs the separate [provision, prepare, provision, deploy sequence](hosted-agents.md#deploy-with-a-hosted-topology). Starting it with `azd up` does not remove the image-preparation or second-provision requirement.

## Reach the private network

Use one of these options:

- **Point-to-site or site-to-site VPN** into the landing zone VNet, or into a hub that is peered with it.
- **A VM or build agent inside the VNet**, or inside a peered VNet with access to the private DNS zones.
- **The jumpbox VM** deployed by the landing zone, reached through Azure Bastion.

### Use the jumpbox

The default jumpbox is a Windows VM. Unless overridden, its administrator user is `testvmuser`. Its password comes from the secure `vmAdminPassword` provisioning input, not a documented Key Vault secret. If you do not have that credential, an authorized operator can reset it before sign-in:

```bash
az vm user update \
  --resource-group <resource-group> \
  --name <jumpbox-vm-name> \
  --username testvmuser \
  --password '<new-password>'
```

Connect through Azure Bastion from the Azure portal, then install the [deployment prerequisites](deploy-full-stack.md#prerequisites). Docker is not installed on the jumpbox by default, and it is not required: image builds run in the ACR Task agent pool.

## Complete the deployment from a connected host

On the connected host, clone the repository at the same release tag you provisioned with, then select the environment:

```bash
git clone --branch <release-tag> https://github.com/Azure/agent-landing-zone.git
cd agent-landing-zone

az login                     # or: az login --identity
azd auth login               # or: azd auth login --managed-identity

azd env new <environment-name>        # same name as the provisioned environment
azd env set AZURE_SUBSCRIPTION_ID <subscription-id>
azd env set AZURE_LOCATION <location>
azd env refresh
```

`azd env refresh` reloads the provisioning outputs (endpoints, resource names) into the local environment.

Signing in with the jumpbox's managed identity does not prove that all
deployment permissions are present. Verify its existing configuration and
build roles, then have an authorized administrator grant only the missing
permissions required by the selected application. For hosted-agent authoring,
the runner needs **Foundry User** (previously **Azure AI User**) on the exact
Foundry project, plus read access to the Foundry account. Cognitive Services
Contributor and OpenAI User alone do not grant the agent data-plane actions.
Do not grant subscription or resource-group Owner to resolve this denial.
See [Foundry RBAC](https://learn.microsoft.com/azure/foundry/concepts/rbac-foundry)
for the current role catalog and scopes. Allow role propagation before retrying.

Then complete any deferred post-provision configuration. On Windows, use `./scripts/postProvision.ps1` instead of the shell script.

```bash
./scripts/postProvision.sh
azd deploy
```

The commands above complete a classic deployment, or redeploy a hosted environment whose immutable image handoff is already provisioned. For a new hosted deployment, run `prepareHostedDeployment` after configuration, run `azd provision` again, and only then run `azd deploy`. An infrastructure-only deployment stops after provisioning and post-provision configuration. It can contain placeholder Container Apps without running the pinned applications.

### Post-provision can be deferred

When isolation is enabled, post-provision can be **deferred** instead of failing. Set `RUN_FROM_JUMPBOX` to `false` (or `0`, `no`, `skip`), or set `AZURE_SKIP_NETWORK_ISOLATION_WARNING=true` while `RUN_FROM_JUMPBOX` is not truthy. A truthy `RUN_FROM_JUMPBOX`, such as `true`, requests the connectivity check even if the warning flag is set. Deferral produces:

```text
Post-provision configuration explicitly deferred; application setup is incomplete.
```

If the other provisioning stages succeed, `azd provision` reports success, but the application is **not** configured. Deferral does not bypass earlier topology or provisioning checks. Clear the deferral setting and rerun post-provision from a connected host:

```bash
azd env set RUN_FROM_JUMPBOX true
azd env set AZURE_SKIP_NETWORK_ISOLATION_WARNING false
./scripts/postProvision.sh      # or ./scripts/postProvision.ps1
```

When the deferral settings are not set and the private endpoints cannot be reached, post-provision fails with:

```text
Private post-provision prerequisites failed. Connect through VPN/VNet and rerun postProvision; configuration has not started.
```

!!! warning
    `RUN_FROM_JUMPBOX` only controls whether post-provision is deferred. It does not provide connectivity. `azd deploy` always checks private reachability, and fails with "Private deployment prerequisites failed" when the host cannot reach the endpoints.

## Image builds in isolated deployments

With the default private registry configuration, public build agents cannot reach the registry. Remote builds use an **ACR Task agent pool** inside the VNet. It is created by default (`DEPLOY_ACR_TASK_AGENT_POOL=true`), and the root hosted topology composition selects it for isolated deployments.

If the pool is missing, `azd deploy` stops before building and offers two fixes:

1. **Create the pool (recommended):**

    ```bash
    azd env set DEPLOY_ACR_TASK_AGENT_POOL true
    azd provision
    azd deploy
    ```

2. **Build supported Container App components locally:** on a VNet-connected host with Docker installed, run:

    ```bash
    azd env set BUILD_MODE local
    azd deploy
    ```

The local alternative applies to component scripts that support `BUILD_MODE=local`. Automatic hosted orchestrator image preparation and isolated custom source builds still require the private pool. Supplying an already-built immutable digest can skip those builds, but does not bypass the root pre-deploy pool guard unless `BUILD_MODE=local` is selected. That guard is not proof that the remaining services can build locally.

### Application-specific package feeds

The root deployment defaults include dependency-verified package feed
destinations alongside common language and OS package registries, through
the scoped foundation build-egress configuration. This is a build-only
allowlist, not a runtime or general Internet exception. It does not allow
every mirror recorded in a custom application's lockfile. Check the
`resolved` URLs and download redirects for the exact component commit
before building.

For additional dependencies, set
`parameters.additionalAcrTaskBuildFqdns.value` in `main.parameters.json` and
provision the updated configuration. This is an explicit array, not an `azd`
environment variable. Copy the same parameter file to a VNet-connected runner
so a later provision preserves the setting.

The orchestrator `v5.2.1` frontend lockfile uses
`ms-feed-2.pkgs.visualstudio.com`, `ms-feed-12.pkgs.visualstudio.com`,
`ms-feed-17.pkgs.visualstudio.com`, and `ms-feed-25.pkgs.visualstudio.com`.
Their public package downloads redirect to `*.vsblob.vsassets.io`.
These four exact feeds and the redirect CDN are included in the Agent Landing
Zone default build allowlist. `packages.microsoft.com` is already included in
the OS-package rule and does not need an additional entry.
With `extendFirewallForAcrTaskBuilds=true` (the default) and an effective ACR
Task agent pool, the feeds, redirect CDN, and additional hosts are allowed only
from the build-agent subnet over HTTPS on port 443. They are not added to
jumpbox, application, or agent-subnet rules. The additional-host array defaults
to empty. Disabling the build-egress extension removes these package rules.
Re-enabling it restores them. This egress rule has no DNS-proxy dependency and
does not change client DNS. Do not enable public
registry access, allow all Internet egress, disable TLS verification, or
change dependency integrity hashes to work around a failed build.

See [Package installation fails inside the build pool](troubleshooting.md#package-installation-fails-inside-the-build-pool)
for diagnosis.

## Verify private connectivity

Run these checks from the host you will deploy from. Use the endpoint host names from `azd env get-value <NAME>`, for example `APP_CONFIG_ENDPOINT`.

| Check | Command | Expected result |
| --- | --- | --- |
| DNS | `nslookup <service-host>` | Only private IPv4 addresses (10.x, 172.16 through 31.x or 192.168.x) |
| TCP | `Test-NetConnection <service-host> -Port 443` | `TcpTestSucceeded : True` |
| TLS | `curl -sv https://<service-host>/ -o /dev/null` | TLS handshake completes. HTTP 401 or 403 is fine. |

If DNS returns a public address, the host is not using the private DNS zones. Check the VNet link of the zone, or the DNS forwarder on your VPN or hub.

On Windows, also check resolution through the operating system resolver, especially when a VPN uses NRPT rules. `nslookup` alone can differ from the resolver used by the Python prerequisite check. That check rejects public, mixed public/private, IPv6, loopback and link-local answers, then verifies TCP 443 and TLS with the original hostname and normal certificate validation. It sends no HTTP request or credentials. Passing it does not prove API health, RBAC, OBO or document authorization.

### Opt-in firewall DNS proxy

The DNS proxy opt-in and guarded private ingestion guidance below target
platform v4.3.0. Use the platform release's exact infrastructure tree and
[component combination](index.md#v430-component-combination). The upstream
infrastructure provenance alone does not include platform-owned changes.

`ENABLE_FIREWALL_DNS_PROXY` defaults to `false` and maps to the Bicep boolean
`enableFirewallDnsProxy` (also default `false`), which sets
`dnsSettings.enableProxy`. It applies only when the existing
`deployAzureFirewall` and `networkIsolation` gates enable firewall deployment.
Opt in only for a topology that deliberately uses the firewall as its DNS
forwarding path:

```bash
azd env set ENABLE_FIREWALL_DNS_PROXY true
azd provision
```

The selection persists through normal provisioning. Enabling the proxy does
**not** redirect VNet or VPN clients to the firewall or rewrite their DNS
configuration. It is independent of the build-feed egress allowlist.

Confirm the actual client DNS path and private-zone resolution separately
from proxy enablement. A proxy cannot repair missing private DNS zone links,
VPN routes or application authentication. For rollback, set
`ENABLE_FIREWALL_DNS_PROXY=false` and provision only after confirming that
the deployed DNS path does not depend on it.

## Private native Blob ingestion

Private `azureBlob` ingestion uses Search-managed outbound shared private
links. Before dependent Search cleanup/mutation and again before native
knowledge source creation, configuration verifies the exact
deployment-owned Search shared links, their expected targets and groups.
This guarded implementation does **not** automatically approve target-side
connections: pending links require authorized administrator approval.

The gate is limited to `NETWORK_ISOLATION=true`, `RETRIEVAL_BACKEND=foundry_iq`
and rendered native `azureBlob` sources, excluding the `searchIndex` pattern.
It checks the application Search link to deployment Blob storage (`blob`)
and the links to the deployment Foundry account (`openai_account`,
`foundry_account`, `cognitiveservices_account`). It does not configure the
separate Foundry Search service or unrelated services. Exact names come from
the template's `SEARCH_SHARED_PRIVATE_LINKS` manifest, including bounded
Foundry names. The exact Search shared-link GET must return the expected
name, target and group. If its body includes a resource ID, that must match
too.

Microsoft documents that the backend endpoint is provisioned in a
Microsoft-managed tenant. A target PEC can contain an opaque
`Microsoft.Network/privateEndpoints` ID and omit a source Search/link
binding. Its name or request message alone is not proof of ownership.
Configuration therefore does not enumerate target PECs, follow their
pagination links, or write approvals. See Microsoft's
[approval and shared-link status procedure, sections 2 and 3](https://learn.microsoft.com/en-us/azure/search/search-indexer-howto-access-private).

A `Pending` source link stops immediately with its exact Search ID, target
ID, group and link name for administrator investigation and approval.
After approval, rerun configuration. An approved source still needs to be
ready. ARM visibility alone does not prove readiness. A timeout or denied
Search read permission is a configuration failure, not a reason to enable
public access or bypass readiness. See
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
Entra ID/OBO, RBAC or document-level authorization. In particular,
`FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS=[]` is a deliberate shared-source
metadata choice for active, supported non-ADLS native Blob ingestion, not a
workaround for a private connection failure. Infrastructure-published `[]`
for `ai_search` (any pattern) or `foundry_iq` / `searchIndex` is accepted as
unused metadata, not a shared-source opt-in: no native Blob source is rendered.
See
[Explicit shared-source permission options](configuration.md#explicit-shared-source-permission-options).

## Integrate with an existing hub

To place the landing zone in an existing hub-and-spoke network, use the `ailz-integrated` deployment mode:

| Setting | Purpose |
| --- | --- |
| `DEPLOYMENT_MODE=ailz-integrated` | Deploy as a spoke of an existing hub |
| `HUB_INTEGRATION_HUB_VNET_RESOURCE_ID` | Hub VNet to peer with |
| `HUB_INTEGRATION_CREATE_HUB_PEERING` | Create the peering (default `true`) |
| `HUB_INTEGRATION_PEERING_ALLOW_GATEWAY_TRANSIT` | Allow gateway transit (default `false`) |
| `HUB_INTEGRATION_PEERING_USE_REMOTE_GATEWAYS` | Use the hub gateway (default `false`) |
| `HUB_INTEGRATION_EGRESS_NEXT_HOP_IP` | Next hop for egress, for example the hub firewall |
| `HUB_INTEGRATION_EXISTING_ROUTE_TABLE_RESOURCE_ID` | Existing route table to attach |
| `AZURE_PE_RESOURCE_GROUP_NAME`, `AZURE_PE_LOCATION` | Where to place private endpoints |
| `EXISTING_*` | Reuse the existing VNet, private DNS zones, jumpbox, Bastion, NAT gateway or monitoring resources |

See [Configuration](configuration.md#network-and-security) for the full list, and the [hub-and-spoke guide](../bicep/hub-and-spoke.md) for the network design.
