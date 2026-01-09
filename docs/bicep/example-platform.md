#  AI LZ with Platform Landing Zone Example

Choose to deploy with platform landing zone when you already have a hub environment and want the workload deployment to integrate with platform-provided networking, routing, and governance.

Start from [bicep/infra/sample.platform-landing-zone.bicepparam](https://github.com/Azure/AI-Landing-Zones/blob/main/bicep/infra/sample.platform-landing-zone.bicepparam). This mode enables platform integration and connects the spoke to the hub. Egress is typically handled by the hub, so the spoke usually does not deploy its own firewall and relies on UDR-based forced tunneling to the hub firewall.

Key parameters in this sample:

| Setting | Typical value |
|---|---|
| `flagPlatformLandingZone` | `true` |
| `hubVnetPeeringDefinition.peerVnetResourceId` | Hub VNet resource ID |
| `deployToggles.firewall` | `false` |
| `deployToggles.userDefinedRoutes` | `true` |
| `firewallPrivateIp` | Hub firewall private IP |

Depending on the toggles you select, the spoke footprint can be smaller because some services may be intentionally disabled.

> Note: Walkthrough comming soon
