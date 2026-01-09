## Existing VNet Example

Choose Existing VNet when you need the landing zone to deploy into networking that already exists. In this mode the template reuses your VNet and subnets rather than creating new networking resources.

Start from [bicep/infra/sample.existing-vnet.bicepparam](https://github.com/Azure/AI-Landing-Zones/blob/main/bicep/infra/sample.existing-vnet.bicepparam). This setup reuses an existing VNet, expects the required subnets to already exist (by name), and may still update subnet associations based on your selected toggles.

Key parameters in this sample:

| Setting | Typical value |
|---|---|
| `deployToggles.virtualNetwork` | `false` |
| `resourceIds.virtualNetworkResourceId` | Existing VNet resource ID (required) |
| `deployToggles.userDefinedRoutes` | Optional; associates route tables when enabled |
| `firewallPolicyDefinition` | Optional; allowlist policy for forced tunneling |
| `firewallPrivateIp` | Optional; firewall private IP when forced tunneling is used |

Addressing note: the sample uses `192.168.0.24` in some allowlist `sourceAddresses`. If your VNet uses different CIDRs, update those entries accordingly.

> Note: Walkthrough comming soon
