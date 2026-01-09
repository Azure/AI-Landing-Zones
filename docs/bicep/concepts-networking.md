# Networking concepts

This guide describes the networking expectations when deploying the AI Landing Zone with Bicep from this repository. It focuses on how the workload VNet, private endpoints, DNS, and forced tunneling are typically configured.

For platform integration behavior and private DNS zone mapping, see [Platform Landing Zone integration](concepts-platform.md). 

For the complete parameter reference, see [Parameterization](parameterization.md).

**What the deployment can configure**

Depending on your parameters, the deployment can create or reuse a workload (spoke) VNet and subnets, create private endpoints for workload services (including AI Foundry when enabled), optionally create private DNS zones and link them to the workload VNet, and optionally deploy user-defined routes (UDR) for forced tunneling.

**Platform-integrated vs standalone**

| Mode | Private endpoints | Private DNS zones | DNS integration |
|---|---|---|---|
| Standalone | Created in the workload VNet | Can be created by the workload deployment | Zone groups can be configured when zone IDs exist |
| Platform-integrated | Created in the workload VNet | Not created by the workload deployment | Name resolution follows the platform DNS pattern |

**Workload VNet and default subnets**

When the deployment creates the workload VNet (instead of reusing an existing one), the default name is `vnet-${baseName}` and the default address space is `192.168.0.0/24`. If you do not provide `vNetDefinition.subnets`, the template applies a default subnet set.

The default subnet set differs by mode. Standalone mode uses the full set (including Bastion/Firewall/Jumpbox subnets). Platform-integrated mode uses a reduced set, because those components are expected to live in the platform hub.

**Subnet sizing guidance**

The table below summarizes the default CIDR used by the template and the sizing guidance (minimum vs recommended) captured in the Bicep defaults.

Minimum is the smallest supported subnet prefix for the component (a hard requirement when enforced by Azure). Recommended is the typical sizing guidance for most deployments.

| Subnet name | Default CIDR | Default IPs | Minimum | Recommended | Reference |
|---|---:|---:|---:|---:|---|
| `agent-subnet` | `192.168.0.0/27` | 32 | `/27` | `/24` | [Agent Service FAQ](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/faq?view=foundry-classic#what-is-the-minimum-size-for-the-agent-subnet--and-how-many-ips-should-i-use-) |
| `pe-subnet` | `192.168.0.32/27` | 32 | `/28` | `/27` or larger | [Private Endpoint properties](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview#private-endpoint-properties) |
| `AzureBastionSubnet` | `192.168.0.64/26` | 64 | `/26` | `/26` | [Bastion subnet requirements](https://learn.microsoft.com/en-us/azure/bastion/configuration-settings#azure-bastion-subnet) |
| `AzureFirewallSubnet` | `192.168.0.128/26` | 64 | `/26` | `/26`; `/25` for headroom | [Firewall subnet size FAQ](https://learn.microsoft.com/en-us/azure/firewall/firewall-faq#why-does-azure-firewall-need-a--26-subnet-size) |
| `appgw-subnet` | `192.168.0.192/27` | 32 | `/29` | `/27` or larger | [Application Gateway subnet sizing](https://learn.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure#size-of-the-subnet) |
| `apim-subnet` | `192.168.0.224/27` | 32 | `/28` | `/27` or larger | [API Management subnet sizing](https://learn.microsoft.com/en-us/azure/api-management/virtual-network-injection-resources#subnet-size) |
| `jumpbox-subnet` | `192.168.1.0/28` | 16 | `/29` | `/28` | - |
| `aca-env-subnet` | `192.168.2.0/27` | 32 | `/27` | `/23`; `/22` for scale-out | [Container Apps subnet requirements](https://learn.microsoft.com/en-us/azure/container-apps/custom-virtual-networks#subnet) |
| `devops-agents-subnet` | `192.168.1.32/27` | 32 | `/28` | `/27` | - |

> Notes:
> - `agent-subnet` and `aca-env-subnet` are delegated to `Microsoft.App/environments`.
> - `pe-subnet` disables private endpoint network policies and is intended to host private endpoints.
> - In platform-integrated mode, the template typically creates or uses `agent-subnet`, `pe-subnet`, `appgw-subnet`, `apim-subnet`, `aca-env-subnet`, and `devops-agents-subnet`.
> - You can override defaults by setting `vNetDefinition.addressPrefixes` and/or `vNetDefinition.subnets`.
> - Azure reserves 5 IP addresses in each subnet; usable IPs are fewer than the total: https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-faq#are-there-any-restrictions-on-using-ip-addresses-within-these-subnets.

**Platform-integrated mode: subnet set created in the spoke**

In platform-integrated mode, the template avoids creating hub-owned subnets (Bastion/Firewall/Jumpbox) inside the spoke VNet.

| Subnet name | Default CIDR | Default IPs | Minimum | Recommended | Reference |
|---|---:|---:|---:|---:|---|
| `agent-subnet` | `192.168.0.0/27` | 32 | `/27` | `/24` | [Agent Service FAQ](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/faq?view=foundry-classic#what-is-the-minimum-size-for-the-agent-subnet--and-how-many-ips-should-i-use-) |
| `pe-subnet` | `192.168.0.32/27` | 32 | `/28` | `/27` or larger | [Private Endpoint properties](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview#private-endpoint-properties) |
| `appgw-subnet` | `192.168.0.192/27` | 32 | `/29` | `/27` or larger | [Application Gateway subnet sizing](https://learn.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure#size-of-the-subnet) |
| `apim-subnet` | `192.168.0.224/27` | 32 | `/28` | `/27` or larger | [API Management subnet sizing](https://learn.microsoft.com/en-us/azure/api-management/virtual-network-injection-resources#subnet-size) |
| `aca-env-subnet` | `192.168.2.0/27` | 32 | `/23` | `/23`; `/22` for scale-out | [Container Apps subnet requirements](https://learn.microsoft.com/en-us/azure/container-apps/custom-virtual-networks#subnet) |
| `devops-agents-subnet` | `192.168.1.32/27` | 32 | `/28` | `/27` | - |

**Private endpoints and DNS**

Private endpoints are created inside the workload VNet, typically in `pe-subnet`. For DNS integration, if a matching `privateDnsZonesDefinition.*ZoneId` is provided, the deployment can attach a zone group so the endpoint registers into that zone. If a zone ID is not provided, the private endpoint can still be created, but DNS integration is skipped for that endpoint.

**Forced tunneling with UDR**

Enable UDR when you want forced tunneling (spoke subnet egress routed via a firewall or NVA) instead of sending internet-bound traffic directly.

| Setting | Purpose |
|---|---|
| `deployToggles.userDefinedRoutes` | Enables UDR deployment and subnet associations. |
| `firewallPrivateIp` | Next hop used for `0.0.0.0/0 -> VirtualAppliance`. |
| `appGatewayInternetRoutingException` | Routes App Gateway subnet to the internet (App Gateway v2 exception). |

The template applies defensive logic to prevent misconfigurations. If you enable UDR (`deployToggles.userDefinedRoutes = true`) but do not provide a valid `firewallPrivateIp`, the deployment will skip creating the route table and subnet associations. This prevents accidentally blocking all outbound traffic from the environment.

**Quick configuration guide**

Use platform-integrated mode by setting `flagPlatformLandingZone = true` and ensure the platform DNS pattern provides name resolution for private endpoints. Use standalone mode by keeping `flagPlatformLandingZone = false` and allowing the workload deployment to manage private DNS zones as needed.

Enable forced tunneling by setting `deployToggles.userDefinedRoutes = true` and providing `firewallPrivateIp`. If you use App Gateway v2, consider enabling `appGatewayInternetRoutingException` to keep the gateway subnet internet-routed.

Override address space and subnet layout by setting `vNetDefinition.addressPrefixes` and/or `vNetDefinition.subnets`.
