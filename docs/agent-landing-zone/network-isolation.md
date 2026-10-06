# Network isolation

Set `NETWORK_ISOLATION=true` to deploy Agent Landing Zone with private endpoints and no public data-plane access. This page explains what changes, how to deploy, and how to check that the network works.

## What changes

When network isolation is on:

- Data-plane services (Azure AI Foundry, Azure AI Search, Cosmos DB, Storage, Key Vault, App Configuration and Container Registry) are reachable only through private endpoints in the landing zone virtual network.
- Private DNS zones resolve service names to private (RFC 1918) addresses.
- A jumpbox virtual machine and Azure Bastion are deployed so you can run the steps that need private network access.
- An **Azure Container Registry Tasks agent pool** is created inside the virtual network. Application images are built there, so you do not need Docker on your workstation or on the jumpbox.

When `NETWORK_ISOLATION=false`, none of these network resources are created and images are built with regular ACR Tasks.

## Deploy

Provisioning runs from your workstation. Application configuration and deployment must run from inside the network, because they call private endpoints.

1. From your workstation, provision the platform:

    ```bash
    azd env set NETWORK_ISOLATION true
    azd provision
    ```

2. Connect to the jumpbox through Azure Bastion (or through a VPN gateway connected to the virtual network). The jumpbox user is `testvmuser`; the password is stored in the landing zone Key Vault.

3. On the jumpbox, clone the repository at the same release tag and sign in with the virtual machine's managed identity:

    ```bash
    az login --identity
    azd auth login --managed-identity
    azd env refresh -e <environment-name>
    ```

4. Run the post-provision configuration:

    ```bash
    # PowerShell
    ./scripts/postProvision.ps1
    # Bash
    ./scripts/postProvision.sh
    ```

5. Deploy the applications:

    ```bash
    azd deploy
    ```

    Images are built by the ACR Tasks agent pool inside the virtual network.

!!! note "Local builds on the jumpbox"
    Building images locally on the jumpbox is a fallback only. Use it if the agent pool cannot be used in your subscription. It requires Docker on the jumpbox and is slower.

## Check connectivity

Run these checks from the jumpbox before you deploy applications.

| Check | How | Expected result |
| --- | --- | --- |
| DNS | `nslookup <service>.privatelink...` or `nslookup <service-hostname>` | The name resolves to a private address (10.x, 172.16–31.x or 192.168.x) |
| TCP | `Test-NetConnection <service-hostname> -Port 443` | `TcpTestSucceeded : True` |
| TLS | `curl -sv https://<service-hostname>/ -o /dev/null` | TLS handshake completes; HTTP 401 or 403 is fine |

If a name resolves to a public address, the private DNS zone is not linked to the virtual network the jumpbox uses. See [Troubleshooting](troubleshooting.md).

## Integrate with an existing hub (`ailz-integrated`)

To place the workload in a spoke that uses an existing hub network, set `DEPLOYMENT_MODE=ailz-integrated` and provide the hub resources:

| Variable | Purpose |
| --- | --- |
| `HUB_INTEGRATION_EGRESS_NEXT_HOP_IP` | Private IP of the hub firewall used as the next hop for egress |
| `HUB_INTEGRATION_EXISTING_ROUTE_TABLE_RESOURCE_ID` | Existing route table to attach to the spoke subnets |
| `AZURE_PE_RESOURCE_GROUP_NAME` | Resource group where private endpoints are created |
| `AZURE_PE_LOCATION` | Region for the private endpoints |
| `EXISTING_*` resource IDs | Existing virtual network, subnets and private DNS zones to reuse |

For the hub-and-spoke design itself, see [Hub and spoke](../bicep/hub-and-spoke.md).

## Related pages

- [Configuration](configuration.md#deployment-parameters)
- [Deploy the full stack](deploy-full-stack.md)
- [Troubleshooting](troubleshooting.md)
