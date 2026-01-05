# Platform Landing Zone integration

This repo supports deploying the **AI workload landing zone** in two modes:

- **Standalone workload** (default): this template creates the workload VNet, Private Endpoints, and (optionally) the required Private DNS Zones.
- **Platform-integrated workload**: this template creates the workload resources and **Private Endpoints in the workload VNet**, but it expects **Private DNS Zones to be provided by the Platform Landing Zone**.

The switch is controlled by `flagPlatformLandingZone` in [infra/main.bicep](../infra/main.bicep).

The goal of Platform mode is to align with the common hub/spoke split:

- Platform (hub) owns shared DNS zones (and typically the central egress components)
- Workload (spoke) owns its Private Endpoints

## What `flagPlatformLandingZone` means

### `flagPlatformLandingZone = false` (Standalone)

- Private Endpoints: **created** (when the corresponding services are deployed)
- Private DNS Zones: **created** (unless you provide existing zone IDs via `privateDnsZonesDefinition.*ZoneId`)
- VNet links to the zones: **created** (unless you set `privateDnsZonesDefinition.createNetworkLinks = false`)

### `flagPlatformLandingZone = true` (Platform-integrated)

- Private Endpoints: **created** (in the workload VNet)
- Private DNS Zones: **not created** by this template

Important (hub/spoke split and permissions):

- This template can create **spoke → hub** VNet peering in Platform mode (because it only requires permissions on the workload/spoke VNet).
- This template does **not** create the **hub → spoke** reverse peering in Platform mode.
- This template does **not** configure Private Endpoint **Private DNS Zone Groups** in Platform mode.

In other words: the workload deployment should not need (and usually should not have) permissions on platform-owned resources (hub VNet, shared Private DNS Zones).

If you provide the Platform Private DNS Zone IDs via `privateDnsZonesDefinition.*ZoneId`, they are used for outputs/visibility only in Platform mode (the workload deployment will not attempt to join them).

Important:

- This template does **not** create Private DNS Zone **virtual network links** in Platform mode.
- The Platform Landing Zone must already link the shared zones to the workload VNet (or you must link them via a separate process with permissions on the zones).

Additionally:

- The Platform Landing Zone must establish hub↔spoke **peering** (or equivalent connectivity) before forced tunneling via UDR will work.

This matches the typical hub/spoke model:

- Platform (hub) owns shared DNS zones
- Workload (spoke) owns its Private Endpoints

## Private DNS Zones (PDNS)

When integrating with a Platform Landing Zone, you typically pass the zone IDs that live in the shared networking resource group.

Common zone IDs used by this repo:

- `privateDnsZonesDefinition.openaiZoneId` → `privatelink.openai.azure.com`
- `privateDnsZonesDefinition.cognitiveservicesZoneId` → `privatelink.cognitiveservices.azure.com`
- `privateDnsZonesDefinition.aiServicesZoneId` → `privatelink.services.ai.azure.com`
- `privateDnsZonesDefinition.searchZoneId` → `privatelink.search.windows.net`
- `privateDnsZonesDefinition.blobZoneId` → `privatelink.blob.core.windows.net`
- `privateDnsZonesDefinition.cosmosSqlZoneId` → `privatelink.documents.azure.com`
- `privateDnsZonesDefinition.keyVaultZoneId` → `privatelink.vaultcore.azure.net`
- `privateDnsZonesDefinition.appConfigZoneId` → `privatelink.azconfig.io`
- `privateDnsZonesDefinition.acrZoneId` → `privatelink.azurecr.io`
- `privateDnsZonesDefinition.containerAppsZoneId` → `privatelink.<region>.azurecontainerapps.io`
- `privateDnsZonesDefinition.apimZoneId` → `privatelink.azure-api.net`

Notes:

- Standalone mode: if a zone ID is not provided, the corresponding Private Endpoint can still be created, but DNS zone-group configuration for that endpoint is skipped.
- Platform mode: DNS zone-group configuration is always skipped by the workload template; name resolution requires a platform DNS pattern (zone groups managed by platform, Private DNS Resolver, custom DNS with conditional forwarders, etc.).

## Private Endpoints (PE)

Private Endpoints are created in the workload VNet `pe-subnet`.

If you enable AI Foundry (`deployToggles.aiFoundry = true`), the AI Foundry component manages the “core” Private Endpoints (AI account, Search, Storage, Cosmos) to avoid duplication.

## User Defined Routes (UDR)

This repo can optionally create a Route Table with a default route (`0.0.0.0/0`) and associate it to selected workload subnets.

Parameters in [infra/main.bicep](../infra/main.bicep):

- `deployToggles.userDefinedRoutes`: enables route table + association
- `firewallPrivateIp`: next hop IP
- `appGatewayInternetRoutingException`: when true, uses a separate route table for `appgw-subnet` with `0.0.0.0/0 -> Internet` (App Gateway v2 exception)

Subnets associated by default:

- `agent-subnet`
- `jumpbox-subnet`
- `aca-env-subnet`
- `devops-agents-subnet`
- `appgw-subnet`
- `apim-subnet`

Next hop behavior:

- Default route uses `firewallPrivateIp`.

App Gateway v2 routing exception (Terraform parity):

- If `appGatewayInternetRoutingException = true`, this repo creates a second route table (`rt-appgw-${baseName}`) and associates it only to `appgw-subnet`.
- That route table contains `0.0.0.0/0 -> Internet`.
- All other UDR-associated subnets continue to use `0.0.0.0/0 -> VirtualAppliance` pointing at `firewallPrivateIp`.

Defensive behavior:

- Even if `deployToggles.userDefinedRoutes = true`, the template only deploys the UDR route table when a consistent firewall/NVA next-hop is provided.
  - Requires `firewallPrivateIp` and/or an explicit firewall signal (deploying/reusing firewall).
- If the inputs are inconsistent, UDR deployment is skipped to avoid breaking egress.

## Example: Platform-integrated deployment

```bicep
param flagPlatformLandingZone = true

// Optional: create the spoke-side peering (spoke → hub). The platform must still create the hub → spoke peering.
param hubVnetPeeringDefinition = {
  peerVnetResourceId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<hubVnetName>'
}

// Optional: provide shared Platform Landing Zone Private DNS Zones (for outputs/visibility)
param privateDnsZonesDefinition = {
  openaiZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com'
  cognitiveservicesZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com'
  aiServicesZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com'
  searchZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net'
  blobZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'
  cosmosSqlZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com'
}

// Optional: steer egress to the hub firewall
param deployToggles = {
  userDefinedRoutes: true
}
param firewallPrivateIp = '10.0.0.4'
```

## Example: Standalone deployment with UDR

```bicep
param flagPlatformLandingZone = false

param deployToggles = {
  userDefinedRoutes: true
}

// If you are reusing an existing firewall (resourceIds.firewallResourceId), set this explicitly.
// If the firewall is deployed by this template, you can omit it.
param firewallPrivateIp = '192.168.0.132'
```
