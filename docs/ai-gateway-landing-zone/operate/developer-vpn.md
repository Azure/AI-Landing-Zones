---
render_macros: false
---

# Developer VPN connectivity add-on

Use the [deployment and validation notebook](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-developer-vpn-validation.ipynb)
to add private developer access to an existing accelerator. It discovers the actual
primary network/DNS configuration, checks CIDR conflicts, writes Bicep parameters,
runs Azure validation/what-if, deploys on explicit approval, generates VPN profiles,
and validates private DNS and trusted HTTPS from the local machine.

This infrastructure runbook intentionally lives in `validation-local` and is
tracked individually; generated `.runs` artifacts remain ignored. Unlike the
application validation suite, it must work **before** private APIM access exists,
so discovery uses ARM rather than initializing the APIM data-plane client.

## Resources and boundaries

- **New dedicated RG:** hub VNet, `/27` `GatewaySubnet`, Standard static public IP,
  route-based P2S VPN Gateway (`VpnGw1AZ` by default), optional DNS Private Resolver
  and dedicated delegated `/28` inbound subnet. No outbound DNS endpoint is needed.
- **Existing primary VNet:** only a new reverse peering with
  `useRemoteGateways=true`. Hub peering enables gateway transit; both allow
  forwarded traffic. No primary subnet, NSG, UDR, DNS server setting or public
  access configuration is changed.
- **Existing DNS zone scopes:** optional resolution-only VNet links
  (`registrationEnabled=false`), not new zones or records. Discovery includes
  primary-RG zones, zones linked to the primary VNet and primary endpoint zone
  groups. Additional external zones can be supplied by full resource ID.
- The hub uses Azure-provided DNS. The developer's VPN profile uses the static
  resolver inbound IP. Existing custom DNS may be supplied instead when resolver
  deployment is disabled.

Client DNS always comes from the actual deployment output (or the explicit
external resolver when none is deployed), not the preflight address calculation.
The Bicep `cidrHost(subnet, 4)` expression returns subnet base + 5; for the
default network the inbound IP is `10.171.0.37`. Existing infrastructure does not
need redeployment for a client DNS/profile correction.

No certificate/private key or client secret is needed for **Entra ID + OpenVPN**.
The Microsoft-registered client audience is used by default. Apply organizational
VPN access restrictions through approved Entra application assignment,
Conditional Access and/or a custom audience; this template does not configure
identity policies. Azure Public cloud and same-tenant subscriptions are the
supported scope.

**Windows and macOS are supported. Linux is not supported in this Entra-only
design:** the Azure VPN Client for Linux retired August 31, 2026. Generic OpenVPN
and strongSwan alternatives do not support Entra authentication for Azure P2S.
Certificate/RADIUS authentication is a separate design, intentionally not enabled.

## Configuration and safe operation

1. Use the repository's existing notebook environment and Azure CLI/Bicep.
   Log in and select the intended subscription **outside** the notebook.
2. Select the intended azd environment and run the initialization cell unchanged.
   One `azd env get-values` snapshot supplies the primary subscription, RG, region
   and APIM name. The VPN RG defaults to `<primary-rg>-vpn` and resource names use
   `citadel-vpn`. `None` means automatic; explicit overrides always win.
   `init_from_azd=False` supports fully manual primary coordinates.
   Restart the kernel after updating shared helpers.
3. Review the discovered zones and actual address ranges. Example hub
   `10.171.0.0/24` and client pool `172.30.240.0/24` are **not guaranteed free**.
   The primary VNet is discovered from the RG, APIM subnet or private endpoints;
   supply `primary_vnet_id` only for ambiguous topologies. Active local/corporate
   private IPv4 routes are detected automatically. The notebook checks the VPN
   CIDRs against those routes and primary/direct-peer VNets. Override
   `local_network_cidrs` for additional organizational ranges as necessary.
   Run preflight disconnected from this developer VPN; after connecting, execute
   the local validation cell directly so the VPN's own routes do not appear as
   overlap conflicts.
4. Review the generated parameters and Azure what-if. Enable deployment
   deliberately; this creates ongoing charges and can take 45 minutes or more.
   Check resolver regional availability, gateway/IP quota and pricing first.
5. Generate/import the OS-specific XML, connect Azure VPN Client and authenticate.
   Windows profiles include configurable public service DNS suffixes and NRPT;
   macOS profiles omit unsupported persistent suffix entries. Review any
   organizational macOS split-DNS requirements.
   Import `azurevpnconfig-windows-0.xml` on Windows, not the original XML/ZIP or
   macOS profile. Generated connections have distinct names including the OS
   and deployed DNS IP, so they cannot be confused with the raw VNet-only
   connection. Disconnect the old connection and connect the newly named entry;
   importing does not reconfigure a tunnel that is already connected.
6. Enable local validation **after connecting**, using a local VS Code kernel.
   Targets default to actual primary endpoint DNS/NIC settings and internal APIM
   gateway/private IPs. Override `validation_targets` only when discovery cannot
   infer the required targets or to select a subset. Direct DNS, OS DNS and
   TCP/TLS must all succeed. Complete browser and service authorization checks
   separately; TLS connectivity is not proof of API permissions. Redis targets
   are reported separately because they require a service-specific port/client,
   not the notebook's HTTPS 443 test.

If direct resolver queries succeed but normal OS/applications fail to resolve,
the tunnel/private zones are not sufficient: Windows needs effective NRPT rules
for those names. Validation now checks the most-specific effective Windows rule
before proceeding. Run `Get-DnsClientNrptPolicy -Effective` and confirm each
service suffix uses the deployed inbound resolver. Reimport the generated Windows
XML and reconnect; then clear the DNS cache manually if a negative entry persists.
If a managed rule overrides the VPN rule, contact the network administrator.
The notebook never changes corporate DNS/NRPT, edits hosts files or falls back to
public endpoints/direct-IP bypasses.

The default notebook reaches Azure validation/what-if without replacing
placeholders. Provisioning, profile downloads, local connectivity tests and
cleanup keep their existing explicit gates. Invalid/missing azd settings,
ambiguous primary networks, address conflicts, and route-discovery failures are
reported as errors rather than silently bypassing checks.
Validation checks the Azure CLI exit status without consuming its response body.
What-if still requires valid JSON and a successful result before deployment can
proceed; resource queries also keep strict JSON parsing.
The notebook compiles Bicep once, then supplies `main.json` and
`@parameters.json` to validation, what-if and deployment. This avoids the Bicep
installation status text that Azure CLI 2.83 can emit before JSON when given
Bicep source files. Deployment checks fingerprints of the compiled inputs and
the unchanged source parameters so it cannot silently deploy different files
from those reviewed in what-if.

After resolving a missing subscription feature or another deployment failure,
retry Step 5 with the unchanged reviewed artifacts; owned partial resources are
reused. To enable deployment without resetting discovery, run
`deploy_enabled = True` in a cell before Step 5. If initialization was rerun and
reset the automatic primary VNet ID, Step 5 restores it from the fingerprint-checked
compiled parameters. Explicit target changes require a fresh preview, and missing
or invalid ownership tags are still rejected. After updating helpers, run
`import importlib; importlib.reload(vpn)` without restarting the kernel to retain
the reviewed plan.

Primary networks with an existing gateway/route server or another remote gateway
are rejected for network-owner review. Disabled gateway route propagation is
rejected. Other UDRs/NSGs/firewalls must allow P2S traffic and its return path.
Peering is not transitive; the add-on does not provide automatic access to other
VNets peered with the primary. Remote containers/kernels have separate DNS/routes.

When `linkPrivateDnsZones=false`, automatic linking is omitted; equivalent
resolver visibility must already exist. When `deployDnsResolver=false`, supply
an existing reachable private DNS resolver in the notebook. DNS visibility is not
inherited through peering.

Deployments are incremental. Renaming resources, disabling DNS links or changing
the zone list does not remove previously created resources. Clean up the old
configuration first. Re-running the primary deployment may reconcile networking
and remove externally managed peerings; reverify this add-on afterward. Regenerate
and reimport VPN profiles after topology/address changes.

## Bicep entry points

- [main.bicep](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/bicep/infra/developer-vpn/main.bicep): subscription deployment and dedicated RG.
- [main.bicepparam](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/bicep/infra/developer-vpn/main.bicepparam): reviewable placeholder parameter file.
- [hub](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/bicep/infra/developer-vpn/modules/hub.bicep), [peering](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/bicep/infra/developer-vpn/modules/peering.bicep) and
  [DNS link](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/bicep/infra/developer-vpn/modules/dns-link.bicep): scoped resource deployment.

The notebook generates a populated `.bicepparam` under its ignored local run
directory, leaving the checked-in sample untouched. Direct CLI deployments are
also possible, but **do not bypass** the notebook's overlap, ownership, existing
gateway and DNS discovery checks. The Bicep template alone cannot discover LAN
networks, assert existing RG ownership, or inventory all primary private zones.

```powershell
az bicep build --file .\bicep\infra\developer-vpn\main.bicep
az bicep build-params --file .\bicep\infra\developer-vpn\main.bicepparam
# After populating a separate parameter file and performing the prerequisite checks:
az deployment sub what-if --location <region> --parameters <populated.bicepparam>
az deployment sub create --location <region> --parameters <populated.bicepparam>
```

Cleanup is disabled by default and requires the exact VPN RG name. It verifies
ownership, deletes the add-on's external DNS links and primary peering, then
deletes only the dedicated VPN RG. Primary zones, records and workloads remain.
Disconnect first; remove desktop profiles separately. Inspect partial failures
and deployment operations rather than deleting guessed resources.

## Microsoft references

- [Entra ID P2S gateway](https://learn.microsoft.com/azure/vpn-gateway/point-to-site-entra-gateway)
- [Gateway-transit peering](https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-peering-gateway-transit)
- [DNS resolver endpoints and static IPs](https://learn.microsoft.com/azure/dns/private-resolver-endpoints-rulesets)
- [DNS resolver regional/subnet constraints](https://learn.microsoft.com/azure/dns/dns-private-resolver-overview)
- [Client XML DNS/routing, NRPT and macOS limitations](https://learn.microsoft.com/azure/vpn-gateway/azure-vpn-client-optional-configurations)
- [Linux retirement and supported alternatives](https://learn.microsoft.com/azure/vpn-gateway/azure-vpn-client-linux-retirement)
- [VPN Gateway settings and deployment time](https://learn.microsoft.com/azure/vpn-gateway/tutorial-create-gateway-portal)
- [VPN pricing](https://azure.microsoft.com/pricing/details/vpn-gateway/)
  and [DNS pricing](https://azure.microsoft.com/pricing/details/dns/)
