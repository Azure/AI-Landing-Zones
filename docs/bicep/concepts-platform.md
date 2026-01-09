# Platform Landing Zone integration

This repository supports two main deployment modes for the AI Landing Zone workload:

| Mode | What the workload deployment does | What the platform is expected to provide |
|---|---|---|
| Standalone | Creates the workload VNet (if enabled), private endpoints, and (optionally) private DNS zones. | Nothing required beyond standard subscription/RG permissions. |
| Platform-integrated | Creates workload resources and private endpoints in the workload VNet. | Shared private DNS zones and the platform DNS pattern used for name resolution. |

The mode is selected with `flagPlatformLandingZone` in the main template.

**Ownership model (hub-and-spoke)**

In a typical hub-and-spoke split, the platform owns shared DNS and central egress. The workload owns its private endpoints inside the spoke VNet.

**Behavior of `flagPlatformLandingZone`**

| Setting | Private Endpoints | Private DNS Zones | VNet links to zones | Zone groups |
|---|---|---|---|---|
| `flagPlatformLandingZone = false` | Created as needed | Created unless you provide zone IDs | Created unless disabled | Configured when zone IDs are available |
| `flagPlatformLandingZone = true` | Created in the workload VNet | Not created by the workload template | Not created by the workload template | Not configured by the workload template |

**Platform-integrated notes (permissions and responsibilities)**

In platform-integrated mode, the workload deployment is intentionally limited to workload-owned resources. It can create spoke-to-hub peering when it only requires permissions on the spoke side. It does not create hub-to-spoke peering, does not create private DNS zone links, and does not configure private endpoint zone groups. The platform must establish hub↔spoke connectivity and ensure the shared zones are linked to the workload VNet (or that an equivalent DNS solution is in place).

If you provide platform private DNS zone IDs via `privateDnsZonesDefinition.*ZoneId`, they are used for outputs/visibility only in platform-integrated mode.

**Private DNS Zones (platform-owned)**

When integrating with a Platform Landing Zone, you typically pass shared private DNS zone resource IDs that live in the platform networking resource group.

| Parameter | Zone name |
|---|---|
| `privateDnsZonesDefinition.openaiZoneId` | `privatelink.openai.azure.com` |
| `privateDnsZonesDefinition.cognitiveservicesZoneId` | `privatelink.cognitiveservices.azure.com` |
| `privateDnsZonesDefinition.aiServicesZoneId` | `privatelink.services.ai.azure.com` |
| `privateDnsZonesDefinition.searchZoneId` | `privatelink.search.windows.net` |
| `privateDnsZonesDefinition.blobZoneId` | `privatelink.blob.core.windows.net` |
| `privateDnsZonesDefinition.cosmosSqlZoneId` | `privatelink.documents.azure.com` |
| `privateDnsZonesDefinition.keyVaultZoneId` | `privatelink.vaultcore.azure.net` |
| `privateDnsZonesDefinition.appConfigZoneId` | `privatelink.azconfig.io` |
| `privateDnsZonesDefinition.acrZoneId` | `privatelink.azurecr.io` |
| `privateDnsZonesDefinition.containerAppsZoneId` | `privatelink.<region>.azurecontainerapps.io` |
| `privateDnsZonesDefinition.apimZoneId` | `privatelink.azure-api.net` |

In standalone mode, private endpoints can still be created even when a zone ID is not provided, but DNS integration for that endpoint is skipped. In platform-integrated mode, DNS integration is always handled by the platform DNS pattern.

**Private Endpoints**

Private endpoints are created in the workload VNet, typically in `pe-subnet`. When AI Foundry is enabled, it can manage a subset of “core” endpoints (for example AI account, Storage, Search, Cosmos) to avoid duplication.

**User Defined Routes (forced tunneling)**

The deployment can optionally create a route table with a default route and associate it to selected workload subnets.

| Setting | Purpose |
|---|---|
| `deployToggles.userDefinedRoutes` | Enables route table deployment and subnet associations. |
| `firewallPrivateIp` | Next hop IP used for the default route. |
| `appGatewayInternetRoutingException` | Uses a dedicated route table for `appgw-subnet` with internet routing (App Gateway v2 exception). |

Default subnet associations (when the corresponding subnets exist): `agent-subnet`, `jumpbox-subnet`, `aca-env-subnet`, `devops-agents-subnet`, `appgw-subnet`, `apim-subnet`.

The template applies defensive gating: if UDR is enabled but a consistent next hop is not provided, it skips route table deployment to avoid breaking egress.

**Example: Platform-integrated deployment**

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

**Example: Standalone deployment with UDR**

```bicep
param flagPlatformLandingZone = false

param deployToggles = {
  userDefinedRoutes: true
}

// If you are reusing an existing firewall (resourceIds.firewallResourceId), set this explicitly.
// If the firewall is deployed by this template, you can omit it.
param firewallPrivateIp = '192.168.0.132'
```
