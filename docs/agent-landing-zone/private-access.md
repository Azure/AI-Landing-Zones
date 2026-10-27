# Private access over VPN

## Objective

Connect a deployment host or developer workstation to an isolated Agent Landing
Zone using a point-to-site (P2S) VPN. The result is private DNS resolution and
HTTPS access to the workload services from that computer. Once connected,
you can run deployment hooks or development tools directly; **Bastion and a
jumpbox are not required for this path**.

## When to use

Use this runbook when a workstation must reach private workload endpoints
without using a jumpbox. Reuse an approved corporate VPN when available; create
a new gateway only with the network owner's approval.

The foundation creates private endpoints and DNS zones when isolation is
enabled. It does **not** create a VPN gateway, configure P2S authentication,
issue certificates, distribute client profiles or create a DNS Private
Resolver. These tasks need network administration outside `azd`.

<span id="before-you-start"></span>

## Prerequisites

- Use the reviewed platform checkout, intended azd environment and approved
  inputs from the [Deploy full stack runbook](deploy-full-stack.md). This procedure does
  not change the hosted orchestrator topology or Foundry IQ configuration.
- Arrange network permissions at the gateway, VNet, peering and DNS scopes.
  The network administrator needs permission to create or update those
  resources; a developer connecting an approved VPN does not need those
  deployment permissions.
- Agree on nonoverlapping address ranges for the VNet, peered networks, P2S
  client pool and workstation's local network.
- Have a supported VPN client and either an approved client certificate or
  an authorized Microsoft Entra account. VPN authentication is separate from
  Azure CLI, azd and application authentication.

## Procedure

Run azd commands from the reviewed platform root with the intended environment
selected. Record any existing gateway, peering, route and DNS settings before
changing them, and identify which changes affect other users.

### 1. Select the private network

The following deployment inputs control workload isolation and hub connectivity.
Set them in the selected azd environment with `azd env set`; see
[How it works](how-it-works.md) for input processing.
For a **new** isolated environment, enable isolation before provisioning:

```bash
azd env set NETWORK_ISOLATION true
```

Keep `parameters.allowedIpRanges.value` empty in `main.parameters.json` for
the default private-only workload service posture. Do not enable public access
to make the VPN work. See [Network isolation](network-isolation.md) for the
separate control-plane, telemetry and optional ingress boundaries.

Choose one network path:

| Path | Foundation inputs and network work |
| --- | --- |
| Standalone VNet | Keep `DEPLOYMENT_MODE=standalone`. The administrator adds a route-based Azure VPN Gateway and P2S configuration to the target VNet separately. |
| Existing hub VPN | Set `DEPLOYMENT_MODE=ailz-integrated` and `HUB_INTEGRATION_HUB_VNET_RESOURCE_ID` to the hub's full ARM resource ID. Reuse its approved gateway, P2S policy and DNS path, and configure gateway transit and client routes as described below. |

For a newly created spoke using a hub-owned gateway, the shipped inputs are:

```bash
azd env set DEPLOYMENT_MODE ailz-integrated
azd env set HUB_INTEGRATION_HUB_VNET_RESOURCE_ID <hub-vnet-resource-id>
azd env set HUB_INTEGRATION_CREATE_HUB_PEERING true
azd env set HUB_INTEGRATION_PEERING_USE_REMOTE_GATEWAYS true
azd env set HUB_INTEGRATION_PEERING_ALLOW_GATEWAY_TRANSIT false
```

These flags configure the **spoke-to-hub** peering. The hub administrator must
create/configure the reverse **hub-to-spoke** peering with gateway transit
allowed, and confirm the hub gateway exists before applying the spoke inputs.
The template does not configure that reverse peering.

Do not set the
spoke's `ALLOW_GATEWAY_TRANSIT` flag to true to share a hub-owned gateway.
For an existing VNet (`USE_EXISTING_VNET=true` with
`EXISTING_VNET_RESOURCE_ID`), have the network owner configure both peering
directions separately.

Preserve approved egress routing through
`HUB_INTEGRATION_EGRESS_NEXT_HOP_IP` or
`HUB_INTEGRATION_EXISTING_ROUTE_TABLE_RESOURCE_ID` where required. These do
not configure P2S client routes or authentication. Use the
[network reference](network-isolation.md) for other reuse inputs.

For a fresh VPN-only deployment, you may explicitly set `DEPLOY_JUMPBOX=false`
and `DEPLOY_BASTION=false` before provisioning. They otherwise default on for
isolation. Verify the VPN before removing an existing access path.

Provision using the [Deploy infra only runbook](deploy-infra-only.md). If the VPN
cannot exist until the VNet is provisioned, use that runbook's deferred
post-provision procedure, then return here. Deferral leaves application setup
incomplete and does not bypass earlier private-access checks.

### 2. Configure the gateway and authentication

For an existing hub VPN, ask its administrator for an approved client profile
and continue to step 3. For a new gateway, follow Microsoft's
[P2S certificate setup](https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-howto-point-to-site-resource-manager-portal)
or [P2S Microsoft Entra setup](https://learn.microsoft.com/azure/vpn-gateway/point-to-site-entra-gateway):

1. Identify the target VNet from the provisioned environment:
   `azd env get-value VNET_RESOURCE_ID`. This is a resource ID, not a VPN server
   address. Create a route-based VPN gateway with a supported SKU and a
   subnet named exactly **`GatewaySubnet`**, using the sizing in the Microsoft
   procedure. The foundation's `gateway-subnet` is **not** that subnet; do
   not rename or repurpose it. Reserve a separate, nonoverlapping range.
   Record ownership of the added gateway and subnet with the network team
   before subsequent foundation provisioning.
2. In the gateway's **Settings > Point-to-site configuration**, select
   **Configure now** for a new configuration and enter the approved client
   address pool. Choose the tunnel/authentication combination for your clients:
   - **Certificate:** upload the public root certificate data; generate and
     install a client certificate signed by that root on each authorized
     computer. Use a unique certificate per device so one device can be
     revoked without replacing every client's certificate. Protect private
     keys and PFX passwords; do not put them in
     source control, command history or the root-certificate upload field.
   - **Microsoft Entra ID:** use **OpenVPN (SSL)** and Azure VPN Client.
     Enter the tenant, audience and issuer values from the current Microsoft
     procedure for your Azure cloud. Prefer its Microsoft-registered audience
     and follow its registration and consent requirements.
     Use a currently supported Windows or macOS client. For Linux, select a
     supported certificate/client combination from the Microsoft procedure.
3. Save the configuration, then select **Download VPN client**. This generates
   a configuration package, not the client application. Install the supported
   client and import the profile using the matching Microsoft instructions.

The gateway administrator controls admission to the VPN. Confirm the approved
certificate or Entra access policy before distributing client profiles.

### 3. Connect DNS and routes

The VPN client needs routes to the workload's private endpoint addresses
**and** a DNS server that can resolve its private zones.

1. Provide a reachable DNS path: an existing hub DNS forwarder, or a separately
   deployed [Azure DNS Private Resolver inbound endpoint](https://learn.microsoft.com/azure/dns/private-resolver-hybrid-dns).
   Ensure the private zones are linked to the resolver/forwarder's VNet, or
   reachable through its approved forwarding design. A spoke zone link alone
   does not make a hub resolver aware of the zone. See
   [private endpoint DNS integration](https://learn.microsoft.com/azure/private-link/private-endpoint-dns-integration)
   for the zone-link and forwarding pattern.
2. Configure the VPN client DNS settings, or the corporate DNS conditional
   forwarders used by that client, to use that path. Permit UDP and TCP 53 to
   the resolver. Do not point remote clients directly at Azure's
   `168.63.129.16` virtual DNS address or use hosts-file entries as the solution.
   Use Microsoft's
   [Azure VPN Client DNS configuration](https://learn.microsoft.com/azure/vpn-gateway/azure-vpn-client-optional-configurations)
   when distributing custom DNS settings in its profile.
3. Confirm the VPN profile includes the destination VNet/spoke routes and the
   resolver's network. Check the return path to the P2S pool and any intervening
   firewall, NSGs and route tables. For a hub VPN, verify traffic can return
   from the workload to the client through the approved hub route. Follow
   [Microsoft's P2S routing guidance](https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-point-to-site-routing)
   for your OS and peering topology; peering is not generally transitive.
4. Connect the VPN. On Windows, inspect `route print` and, for Azure VPN Client,
   its connection details. For Entra connections, inspect
   `Get-DnsClientNrptPolicy` rather than relying on `ipconfig /all` to show
   the VPN DNS servers. After peering, route or DNS changes, regenerate and
   reimport the client profile as required and reconnect.

`ENABLE_FIREWALL_DNS_PROXY=true` only enables the proxy on a deployed isolated
spoke firewall. It does not configure VPN client DNS, link missing zones or
create a resolver. Leave it unchanged unless the approved DNS design uses it.

<span id="4-verify-from-the-actual-host"></span>

## Validation

Run these checks on **each** deployment host and developer workstation, not
only on a VM in Azure. Select the intended environment and refresh outputs
if needed; refresh does not provision or complete configuration.

The shipped outputs include `APP_CONFIG_ENDPOINT`, `KEY_VAULT_URI`,
`AZURE_AI_PROJECT_ENDPOINT`, `AZURE_CONTAINER_REGISTRY_ENDPOINT` and, for the
selected Foundry IQ/Search deployment, `KNOWLEDGE_BASE_ENDPOINT`.
Use each nonempty value's hostname, not the resource ID or a private IP.
The registry output is a login-server hostname; URL outputs include `https://`
and can include a path.

For example, in PowerShell:

```powershell
$endpoint = azd env get-value APP_CONFIG_ENDPOINT
$serviceHost = ([uri]$endpoint).DnsSafeHost
nslookup $serviceHost
[System.Net.Dns]::GetHostAddresses($serviceHost)
Test-NetConnection $serviceHost -Port 443
curl.exe --verbose --output NUL "https://$serviceHost/"
```

Expected results:

- The operating system resolver returns only the intended private IPv4
  addresses. Windows Name Resolution Policy Table (NRPT) rules can make
  `nslookup` differ. If it does, inspect `Get-DnsClientNrptPolicy` and query the
  VPN's intended DNS server directly with `nslookup <hostname> <dns-server-ip>`.
  Resolve the difference before accepting the host's DNS path.
- `TcpTestSucceeded` is `True`, and TLS completes with normal certificate
  validation. A service HTTP 401 or 403 response confirms reachability;
  test service operations with the authorized identity separately. Do not use `--insecure`.

Repeat for the required service hosts. For the registry, assign its
`AZURE_CONTAINER_REGISTRY_ENDPOINT` value directly to `$serviceHost` rather
than parsing it as a URL. Keep their original hostnames for TLS;
do not replace application endpoints with IP addresses or `privatelink` aliases.

The lifecycle prerequisite check rejects public or mixed DNS answers and checks
TCP/TLS reachability: App Configuration before post-provision and deployment,
the Foundry project additionally before hosted deployment, and ACR before hosted
image builds. Test the remaining service hosts individually.

### After validation: deploy or develop

<span id="5-deploy-or-develop"></span>

- **Deployment host:** authenticate Azure CLI and azd with the approved deployment
  identity. Complete deferred post-provision using
  the [Deploy infra only runbook](deploy-infra-only.md), then continue
  the [Deploy full stack runbook](deploy-full-stack.md) for hosted image preparation and
  application deployment. `RUN_FROM_JUMPBOX=true` requests connectivity checks;
  despite its name, it works from a VPN-connected host and does not require
  a jumpbox. Keep the private ACR Task pool for hosted image preparation;
  the pool is not a VPN endpoint or deployment workstation.
- **Developer workstation:** keep the VPN connected while using private Azure
  endpoints. Authenticate development tools separately and use the approved
  project and service roles. Local application development guidance belongs
  in [Custom applications](build-your-own-app.md). Hosted agents continue to
  run in Foundry.

Configure service RBAC and document permissions separately from network access.
Preserve application authentication, OBO and source access-control lists.
For hosted-agent authoring, verify the runner's **Foundry User** role on the
exact project and account read access as described in
[Network isolation](network-isolation.md). Do not grant Owner to solve a
data-plane denial.

<span id="recover-or-disconnect"></span>

### Troubleshooting

| Symptom | Check first |
| --- | --- |
| Tunnel will not connect | Client/tunnel compatibility, certificate validity or Entra policy, and the gateway's current profile. |
| Tunnel connects; names resolve publicly | Client DNS/NRPT, conditional forwarders and private-zone links to the resolver VNet. Do not enable public service access. |
| Private DNS works; TCP 443 fails | Overlapping local ranges, missing spoke routes, reverse peering/transit, return route to the P2S pool, NSGs and firewalls. |
| TLS fails | Original hostname, client trust and any approved inspection path. Do not disable certificate validation. |
| HTTP 401/403 after successful TLS | Correct tenant, token audience and scoped service roles. Check authorization separately from connectivity. |

## Rollback

1. Disconnect the VPN on the affected workstation. Restore its previous approved
   DNS and route/profile configuration if changed, then confirm normal corporate
   connectivity. Keep an existing administrative access path available.
2. To revoke newly granted access, have the gateway administrator use the
   approved certificate-revocation or Entra access policy process. Deleting a
   local profile does not revoke credentials. Remove pilot profiles and device
   certificates only after recording which credential was revoked.
3. Have the network owner review the recorded changes and restore only the
   pilot-specific peering, route or DNS settings that are no longer needed.
   Verify existing consumers still resolve and reach their services.
4. If a dedicated gateway was created only for this pilot, authorize its
   itemized retirement with the network owner after checking dependencies.
   Do not delete a shared hub gateway, resolver, private DNS zone or workload
   private endpoint. Keep workload isolation and application authentication
   unchanged.
