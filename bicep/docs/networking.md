# Bicep networking guide

This document explains how networking is expected to be planned/configured when using the Bicep deployment in this repo.

It complements:

- The Platform Landing Zone specifics: [bicep/docs/platform.md](../../bicep/docs/platform.md)
- The baseline parameters: [bicep/infra/main.bicepparam](../../bicep/infra/main.bicepparam)

## What this repo configures

Depending on parameters, the Bicep deployment can:

- Create or reuse a workload (spoke) VNet and subnets
- Create Private Endpoints (PEs) for workload services (including AI Foundry when enabled)
- Optionally create Private DNS Zones (PDNS) and link them to the workload VNet (standalone mode)
- Optionally create User Defined Routes (UDR) and associate route tables to subnets (forced tunneling)

## Platform vs standalone

### Standalone (`flagPlatformLandingZone = false`)

- The template can create Private DNS Zones and create VNet links to the workload VNet.
- Private Endpoints are created as needed, and zone-groups can be configured against the zones the template created.

### Platform-integrated (`flagPlatformLandingZone = true`)

- The template still creates Private Endpoints in the workload VNet.
- The template does not create Private DNS Zones.
- You must provide the platform-owned zone resource IDs via `privateDnsZonesDefinition.*ZoneId` if you want this template to configure Private Endpoint zone-groups.
- The Platform Landing Zone must link those zones to the workload VNet (or you must link them separately with permissions).

See [bicep/docs/platform.md](../../bicep/docs/platform.md) for the detailed list of zones and behavior.

## Private Endpoints and DNS

### Private Endpoints

- Private Endpoints are created inside the workload VNet, in the relevant subnet (typically `pep-subnet`).
- In Platform mode, this repo assumes the platform provides shared services (DNS zones, central egress) but the workload still owns the endpoints.

### DNS zone-groups

For a given Private Endpoint:

- If a matching `privateDnsZonesDefinition.*ZoneId` is provided, the deployment can attach a zone-group so the endpoint registers into that zone.
- If the zone ID is not provided, the Private Endpoint can still be created, but DNS integration is skipped for that endpoint.

## Forced tunneling with UDR

### When to enable

Enable UDR when you want “forced tunneling” (spoke subnet egress routed via a firewall/NVA) instead of sending Internet-bound traffic directly.

In this repo, UDR is controlled by:

- `deployToggles.userDefinedRoutes`: enable/disable UDR deployment
- `firewallPrivateIp`: next hop for `0.0.0.0/0 -> VirtualAppliance`

### Defensive behavior

This template uses defensive gating:

- If `deployToggles.userDefinedRoutes = true` but there is not a consistent next-hop signal (e.g., missing `firewallPrivateIp`), the deployment skips creating UDR resources.
- This is intentional to avoid breaking egress by attaching a route table with an invalid next hop.

### App Gateway v2 internet routing exception

App Gateway v2 commonly requires Internet routing from its subnet.

If you enable:

- `appGatewayInternetRoutingException = true`

Then the repo deploys a dedicated route table for `appgw-subnet` with:

- `0.0.0.0/0 -> Internet`

All other subnets that receive UDR association continue to use:

- `0.0.0.0/0 -> VirtualAppliance` pointing at `firewallPrivateIp`

## Quick decision checklist

- Platform LZ?
  - Set `flagPlatformLandingZone = true`
  - Provide `privateDnsZonesDefinition.*ZoneId`
  - Ensure platform PDNS zones are linked to the workload VNet
- Need forced tunneling?
  - Set `deployToggles.userDefinedRoutes = true`
  - Set `firewallPrivateIp`
  - If using App Gateway v2, consider `appGatewayInternetRoutingException = true`
