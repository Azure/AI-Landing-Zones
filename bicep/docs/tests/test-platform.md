# Platform Landing Zone (PLZ) Test

This guide provisions a **minimal platform (Hub) environment** so you can test `flagPlatformLandingZone=true` with the main template.

Primary scenario validated by this guide:
- A **workload/spoke** deployment uses `flagPlatformLandingZone=true` and reuses **platform-owned Private DNS Zones**.
- The spoke enables **forced tunneling** with `deployToggles.userDefinedRoutes=true`, sending egress (`0.0.0.0/0`) to the **hub firewall**.

The goal is to have:
- Hub VNet with **Azure Firewall**
- **Private DNS Zones** (PDNS) + **VNet links**
- **Azure Bastion** (jump host)
- A **test VM in the hub**

Who does what in this test:
- **Platform steps (this guide):** deploy the hub, own the PDNS zones, create hub→spoke peering, and link PDNS zones to the spoke VNet.
- **Workload steps:** deploy the spoke workload with `flagPlatformLandingZone=true`, create spoke→hub peering, and enable forced tunneling via UDR.

## Topology (default CIDRs)

> Important: hub and spoke address spaces must NOT overlap, otherwise VNet peering will fail.

```text
                         Platform (Hub) RG: rg-ai-lz-test-platform
                   VNet: vnet-ai-lz-hub  [10.0.0.0/16]   (eastus2)
        +--------------------------------------------------------------------+
        |                                                                    |
        |  AzureFirewallSubnet [10.0.0.0/26]                                 |
        |    - Azure Firewall: afw-ai-lz-hub                                  |
        |    - Private IP: firewallPrivateIp (deployment output)              |
        |                                                                    |
        |  AzureBastionSubnet [10.0.0.64/26]                                  |
        |    - Bastion: bas-ai-lz-hub                                         |
        |                                                                    |
        |  hub-vm-subnet [10.0.1.0/24]                                        |
        |    - Test VM: vm-ailz-hubtst                                        |
        |      (RDP via Bastion only)                                         |
        +--------------------------------------------------------------------+
                               ||  VNet peering (must be Connected)
                               ||  - spoke -> hub : required (workload creates)
                               ||  - hub   -> spoke: required (platform must create)
                               ||  - allowForwardedTraffic: enabled (required for FT)
                               \/
        +--------------------------------------------------------------------+
        | Workload (Spoke) RG: rg-ai-lz-workload-test                         |
        | VNet (default): vnet-<baseName> [192.168.0.0/22]                    |
        |                                                                    |
        |  pe-subnet          [192.168.0.32/27]   (Private Endpoints)         |
        |  agent-subnet       [192.168.0.0/27]                                |
        |  jumpbox-subnet     [192.168.1.0/28]                                |
        |  aca-env-subnet     [192.168.2.0/23]                                |
        |  devops-agents-subnet[192.168.1.32/27]                              |
        |  appgw-subnet       [192.168.0.192/27]                              |
        |  apim-subnet        [192.168.0.224/27]                              |
        +--------------------------------------------------------------------+

DNS (platform-owned):
  - `bicep/tests/platform.bicep` creates the Private DNS Zones and links them to the hub VNet.
  - Step 3 links those zones to the spoke VNet after the spoke exists.
  - In platform-integrated mode, the workload deployment does NOT write DNS records into the platform zones
    (it does not create Private DNS Zone Groups). Use your platform process for that.

Routing (forced tunneling test):
  - Spoke UDR: 0.0.0.0/0 -> VirtualAppliance(firewallPrivateIp)
  - Requires hub↔spoke connectivity (peering Connected on both sides).
```

> Note: this environment is for **testing only**.
> The hub firewall policy is intentionally permissive for **outbound/forwarded traffic from private IP ranges** (RFC1918) to avoid test failures.
> It does **not** publish inbound services from the internet (no DNAT rules); inbound access to the hub VM is via **Bastion**.

## Prerequisites

- Permissions to create resources in the subscription (e.g., `Contributor`)
- Azure CLI authenticated: `az login`
- Bicep available in Azure CLI (usually built-in)

## Step 1 — Deploy the “mini platform” (Hub)

The template below deploys all platform resources **inside an existing Resource Group**:

- Template: [bicep/tests/platform.bicep](../../tests/platform.bicep)
- Scope: **resource group**
- Region: **hardcoded to `eastus2`** inside the template

### Commands (Azure CLI)

1) Create the platform RG:

`az group create --name rg-ai-lz-test-platform --location eastus2`

2) Deploy the mini platform to that RG:

`az deployment group create --name platform-test --resource-group rg-ai-lz-test-platform --template-file bicep/tests/platform.bicep --parameters adminPassword='REPLACE_ME_STRONG_PASSWORD'`

Notes:
- Avoid running the command twice at the same time. Azure networking can return `AnotherOperationInProgress` if a previous subnet/VNet update is still running.
- If you hit `AnotherOperationInProgress`, wait a few minutes and re-run the deployment.

Optional (override the test VM image/size):

`az deployment group create --name platform-test --resource-group rg-ai-lz-test-platform --template-file bicep/tests/platform.bicep --parameters adminPassword='REPLACE_ME_STRONG_PASSWORD' vmSize='Standard_D8s_v5' vmImagePublisher='MicrosoftWindowsDesktop' vmImageOffer='windows-11' vmImageSku='win11-25h2-ent' vmImageVersion='latest'`

### Get outputs

`az deployment group show --name platform-test --resource-group rg-ai-lz-test-platform --query properties.outputs -o json`

Keep these outputs handy:
- `platformResourceGroupName`
- `hubVnetResourceId`
- `firewallPrivateIp`

You will share (at minimum) `hubVnetResourceId` and `firewallPrivateIp` with the workload tester.

Tip (training-friendly): copy the two values below into your notes:
- `hubVnetResourceId`
- `firewallPrivateIp`

## Step 2 — Deploy the workload (Spoke) with `flagPlatformLandingZone=true`

Now deploy the main template for your workload/spoke and reference the platform outputs.

1) Create (or choose) a Resource Group for the workload (spoke), e.g. `rg-ai-lz-workload-test`.
2) Start from the PLZ parameter file:
   - [bicep/infra/sample.platform-landing-zone.bicepparam](../../infra/sample.platform-landing-zone.bicepparam)

### What you must set in the `.bicepparam`

- `flagPlatformLandingZone = true`
- `deployToggles.userDefinedRoutes = true` (to validate forced-tunneling/UDR in the spoke)
- `firewallPrivateIp = <firewallPrivateIp output from step 1>`

Required for this test procedure:

- `hubVnetPeeringDefinition.peerVnetResourceId = <hubVnetResourceId output from step 1>` (creates the spoke → hub peering)
  - Why we require it in this runbook: it ensures the workload always creates the spoke-side peering (no dependency on a separate platform action for that side).
  - Note: this only requires permissions on the spoke/workload VNet.

### Deploy the workload

Example (adjust RG and parameter file as needed):

`az deployment group create --resource-group rg-ai-lz-workload-test --template-file bicep/infra/main.bicep --parameters bicep/infra/sample.platform-landing-zone.bicepparam`

Tip (recommended): ask the workload tester to send you their deployment outputs (at minimum the spoke VNet resource ID).

## Step 3 — Link the PDNS zones to the Spoke VNet

In PLZ setups, the platform typically owns **creating PDNS VNet links** for spoke VNets.

The template [bicep/tests/platform.bicep](../../tests/platform.bicep) supports a parameter:
- `spokeVnetResourceId` (resource ID of the spoke VNet)

After the spoke VNet exists, re-deploy the platform template adding that parameter to create the VNet links.

How to get the spoke VNet resource ID:
- From the workload deployment outputs (recommended), or
- From the Azure Portal: Spoke VNet → Overview → Resource ID

Example:

`az deployment group create --name platform-test --resource-group rg-ai-lz-test-platform --template-file bicep/tests/platform.bicep --parameters adminPassword='REPLACE_ME_STRONG_PASSWORD' spokeVnetResourceId='/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/...'`

## Step 4 — Establish hub↔spoke connectivity (peering)

In many PLZ setups, the workload deployment identity cannot create peering on the **hub** VNet (platform-owned).

- This runbook requires the workload deployment to create the **spoke → hub** peering (Step 2).
- The platform team must still create the **hub → spoke** peering (reverse peering) using your platform process (Portal, policy-driven automation, or a separate platform deployment).
- Ensure peering is configured with forwarded traffic enabled if you expect forced tunneling to work.

### Platform-side action (required): create the hub → spoke peering

You need these inputs:
- Hub VNet RG/name: from Step 1 (this test uses `rg-ai-lz-test-platform` and `vnet-ai-lz-hub`)
- Spoke VNet resource ID: from the workload outputs or Portal

Option A — Azure Portal (recommended for manual testing)
1) Go to Hub VNet: `vnet-ai-lz-hub`
2) Go to **Peerings** → **Add**
3) Configure:
  - **Peering link name (this virtual network)**: `hub-to-spoke`
  - **Virtual network**: select the spoke VNet (or paste/select by resource ID if available)
  - **Allow virtual network access**: Enabled
  - **Allow forwarded traffic**: Enabled
  - **Allow gateway transit**: Disabled (unless your platform requires it)
  - **Use remote gateways**: Disabled
4) Create and wait until the peering shows **Connected**.

Option B — Azure CLI

`az network vnet peering create --resource-group rg-ai-lz-test-platform --vnet-name vnet-ai-lz-hub --name hub-to-spoke --remote-vnet /subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/... --allow-vnet-access --allow-forwarded-traffic`

Validation commands (Azure CLI):

Hub peerings:

`az network vnet peering list --resource-group rg-ai-lz-test-platform --vnet-name vnet-ai-lz-hub -o table`

Spoke peerings:

`az network vnet peering list --resource-group <spokeRg> --vnet-name <spokeVnetName> -o table`

### What the workload tester should do / provide

Ask the workload tester for:
- The spoke VNet resource ID (or their workload deployment outputs)
- Confirmation whether they enabled `hubVnetPeeringDefinition.peerVnetResourceId` (spoke → hub peering)

If they enabled spoke → hub peering, you should see 2 peerings total (one on each side) once you create the hub → spoke peering.

## Validation checklist

- **Bastion**
  - Connect to `vm-ailz-hubtst` via Bastion in the Azure Portal

- **DNS**
  - The hub VM can resolve `privatelink.*` names (e.g., after a Private Endpoint exists in the spoke)

- **Forced tunneling (Spoke UDR)**
  - With `deployToggles.userDefinedRoutes=true` in the workload, validate the spoke route tables point to `firewallPrivateIp`

- **Hub → Spoke connectivity**
  - Ensure hub↔spoke peering exists (required for forced tunneling to a hub firewall)
  - Ensure both sides show **Connected** and **Allow forwarded traffic** is enabled

## Cleanup

Delete the mini platform RG:

`az group delete --name rg-ai-lz-test-platform --yes --no-wait`

Delete the workload RG:

`az group delete --name rg-ai-lz-workload-test --yes --no-wait`
