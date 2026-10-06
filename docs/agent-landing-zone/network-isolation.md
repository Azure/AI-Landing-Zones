# Network isolation

With `NETWORK_ISOLATION=true`, Agent Landing Zone deploys every data-plane service behind private endpoints. Public network access is disabled, and the services resolve through private DNS zones linked to the landing zone virtual network.

This page explains what changes when isolation is on, how to reach the private network, and how to complete a deployment from a connected host.

## What changes with isolation

| Area | `NETWORK_ISOLATION=false` | `NETWORK_ISOLATION=true` |
| --- | --- | --- |
| Data-plane access | Public endpoints, protected by Microsoft Entra ID | Private endpoints only |
| DNS | Public DNS | Private DNS zones linked to the VNet |
| Jumpbox, Azure Bastion, NAT gateway | Not deployed | Deployed by default |
| Container image builds | Regular ACR Tasks | ACR Task agent pool inside the VNet |
| Post-provision and deploy | Run from any workstation | Run from a host connected to the VNet |

!!! note
    The ACR Task agent pool is created only for isolated deployments. When isolation is off, images are built with regular ACR Tasks and no pool is created, even if `DEPLOY_ACR_TASK_AGENT_POOL` is `true`.

## Enable isolation

Set the flag before the first provision:

```bash
azd env set NETWORK_ISOLATION true
azd up
```

`azd provision` succeeds from any workstation, because Azure Resource Manager is a public control plane. The steps that follow (post-provision configuration and `azd deploy`) talk to data-plane endpoints and must run from a host that can reach the private network.

## Reach the private network

Use one of these options:

- **Point-to-site or site-to-site VPN** into the landing zone VNet, or into a hub that is peered with it.
- **A VM or build agent inside the VNet**, or inside a peered VNet with access to the private DNS zones.
- **The jumpbox VM** deployed by the landing zone, reached through Azure Bastion.

### Use the jumpbox

The jumpbox is a Windows VM. Its administrator user is `testvmuser`. The password is not stored in Key Vault, so set one before your first sign-in:

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

Then run post-provision and deploy. On Windows, use `./scripts/postProvision.ps1` instead of the shell script.

```bash
./scripts/postProvision.sh
azd deploy
```

### Post-provision can be deferred

When provisioning runs from a host without private network access, post-provision can be **deferred** instead of failing. This happens when `RUN_FROM_JUMPBOX` is set to `false` (or `0`, `no`, `skip`) or when `AZURE_SKIP_NETWORK_ISOLATION_WARNING` is `true`. You then see:

```text
Post-provision configuration explicitly deferred; application setup is incomplete.
```

`azd provision` still reports success, but the application is **not** configured. Clear the deferral setting and rerun post-provision from a connected host:

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

Container registries in an isolated deployment reject public build agents, so images are built in an **ACR Task agent pool** that runs inside the VNet. It is created by default (`DEPLOY_ACR_TASK_AGENT_POOL=true`).

If the pool is missing, `azd deploy` stops before building and offers two fixes:

1. **Create the pool (recommended):**

    ```bash
    azd env set DEPLOY_ACR_TASK_AGENT_POOL true
    azd provision
    azd deploy
    ```

2. **Build locally:** on a VNet-connected host with Docker installed, run:

    ```bash
    azd env set BUILD_MODE local
    azd deploy
    ```

## Verify private connectivity

Run these checks from the host you will deploy from. Use the endpoint host names from `azd env get-value <NAME>`, for example `APP_CONFIG_ENDPOINT`.

| Check | Command | Expected result |
| --- | --- | --- |
| DNS | `nslookup <service-host>` | A private address (10.x, 172.16–31.x or 192.168.x) |
| TCP | `Test-NetConnection <service-host> -Port 443` | `TcpTestSucceeded : True` |
| TLS | `curl -sv https://<service-host>/ -o /dev/null` | TLS handshake completes. HTTP 401 or 403 is fine. |

If DNS returns a public address, the host is not using the private DNS zones. Check the VNet link of the zone, or the DNS forwarder on your VPN or hub.

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
