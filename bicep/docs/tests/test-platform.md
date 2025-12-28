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
         Platform (Hub) RG: rg-ailz-platform-RANDOM_SUFFIX
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
        | Workload (Spoke) RG: rg-ai-lz-RANDOM_SUFFIX                       |
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
> The hub firewall policy is intentionally **allowlist-based** to support **Foundry Agent Service (Azure Container Apps) + Managed Identity** scenarios behind forced tunneling.
> It does **not** publish inbound services from the internet (no DNAT rules); inbound access to the hub VM is via **Bastion**.

Outbound Internet (hub test VM):
- The hub test template ([bicep/tests/platform.bicep](../../tests/platform.bicep)) uses **forced tunneling** for the hub test VM too: it associates a **route table** to `hub-vm-subnet` with `0.0.0.0/0 -> VirtualAppliance(firewallPrivateIp)`.
- That means the hub test VM only has outbound internet if the **Azure Firewall policy** allows it.
- The default policy in the test hub is optimized for **Foundry Agent Service egress**, not general web browsing.
- Quick validation (from inside the hub VM):
  - `Resolve-DnsName login.microsoftonline.com`
  - `Test-NetConnection login.microsoftonline.com -Port 443`
  - `Resolve-DnsName mcr.microsoft.com`
  - `Test-NetConnection mcr.microsoft.com -Port 443`
  - `Resolve-DnsName packages.aks.azure.com`
  - `Test-NetConnection packages.aks.azure.com -Port 443`
- If validation fails:
  - Confirm the subnet has a route table attached and the default route points at `firewallPrivateIp`.
  - Confirm the Azure Firewall policy allows:
    - DNS (UDP/TCP 53) to Azure DNS (`168.63.129.16`)
    - `AzureActiveDirectory` service tag (Managed Identity)
    - Container Apps / platform dependencies (MCR + AKS package endpoints)
  - Confirm there is **no TLS inspection** (no self-signed cert injection) on the firewall.

## Prerequisites

- Permissions to create resources in the subscription (e.g., `Contributor`)
- Azure CLI authenticated: `az login`
- Bicep available in Azure CLI (usually built-in)

## Step 1 — Deploy the “mini platform” (Hub)

### Naming convention used in this guide

This guide assumes you will use a **single suffix** (the same value everywhere) to avoid name collisions and to keep platform/workload resources easy to correlate:

- Platform RG: `rg-ailz-platform-RANDOM_SUFFIX`
- Platform deployment name: `ailz-platform-RANDOM_SUFFIX`
- Workload RG: `rg-ai-lz-RANDOM_SUFFIX`
- `azd` environment name: `ai-lz-RANDOM_SUFFIX`

The template below deploys all platform resources **inside an existing Resource Group**:

- Template: [bicep/tests/platform.bicep](../../tests/platform.bicep)
- Scope: **resource group**
- Region: **hardcoded to `eastus2`** inside the template

### Commands (Azure CLI)

1) Create the platform RG:

`az group create --name rg-ailz-platform-RANDOM_SUFFIX --location eastus2`

2) Deploy the mini platform to that RG:

`az deployment group create --name ailz-platform-RANDOM_SUFFIX --resource-group rg-ailz-platform-RANDOM_SUFFIX --template-file bicep/tests/platform.bicep --parameters adminPassword='REPLACE_ME_STRONG_PASSWORD'`

Notes:
- Avoid running the command twice at the same time. Azure networking can return `AnotherOperationInProgress` if a previous subnet/VNet update is still running.
- If you hit `AnotherOperationInProgress`, wait a few minutes and re-run the deployment.

Optional (override the test VM image/size):

`az deployment group create --name ailz-platform-RANDOM_SUFFIX --resource-group rg-ailz-platform-RANDOM_SUFFIX --template-file bicep/tests/platform.bicep --parameters adminPassword='REPLACE_ME_STRONG_PASSWORD' vmSize='Standard_D8s_v5' vmImagePublisher='MicrosoftWindowsDesktop' vmImageOffer='windows-11' vmImageSku='win11-25h2-ent' vmImageVersion='latest'`

### Get outputs

`az deployment group show --name ailz-platform-RANDOM_SUFFIX --resource-group rg-ailz-platform-RANDOM_SUFFIX --query properties.outputs -o json`

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

1) Create (or choose) a Resource Group for the workload (spoke), e.g. `rg-ai-lz-RANDOM_SUFFIX`.
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

Use the same flow as [bicep/docs/how_to_use.md](../how_to_use.md) (azd-based provisioning).

1) Create the workload RG:

`az group create --name rg-ai-lz-RANDOM_SUFFIX --location eastus2`

2) Initialize the project environment (run once per new environment name):

`azd init -e ai-lz-RANDOM_SUFFIX`

3) Set environment variables (PowerShell):

`$env:AZURE_LOCATION = "eastus2"`

`$env:AZURE_RESOURCE_GROUP = "rg-ai-lz-RANDOM_SUFFIX"`

`$env:AZURE_SUBSCRIPTION_ID = "00000000-1111-2222-3333-444444444444"`

Note: this repo uses Template Specs (`ts:`) by default during `azd provision`. The preprovision hook restores artifacts automatically.
If you still see `ts:` restore/auth timeouts, re-run `az login` and retry `azd provision`.

4) Configure parameters for this PLZ test:

- Copy the PLZ sample parameters into the file used by `azd`:

`Copy-Item bicep/infra/sample.platform-landing-zone.bicepparam bicep/infra/main.bicepparam -Force`

- Edit `bicep/infra/main.bicepparam` and set:
  - `firewallPrivateIp = <firewallPrivateIp from Step 1>`
  - `hubVnetPeeringDefinition.peerVnetResourceId = <hubVnetResourceId from Step 1>`

5) Provision the workload:

`azd provision`

After provisioning, capture the spoke VNet resource ID for Step 3:

`az network vnet show --resource-group rg-ai-lz-RANDOM_SUFFIX --name vnet-<baseName> --query id -o tsv`

## Step 3 — Link the PDNS zones to the Spoke VNet

In PLZ setups, the platform typically owns **creating PDNS VNet links** for spoke VNets.

How to get the spoke VNet resource ID:

- Recommended (Azure CLI, greenfield default VNet name):

`az network vnet show --resource-group rg-ai-lz-RANDOM_SUFFIX --name vnet-<baseName> --query id -o tsv`

- Or from the Azure Portal: Spoke VNet → Overview → Resource ID

The platform test template creates (at minimum) these Private DNS Zones:

- `privatelink.blob.<storageSuffix>` (example: `privatelink.blob.core.windows.net`)
- `privatelink.file.<storageSuffix>` (example: `privatelink.file.core.windows.net`)
- `privatelink.vaultcore.azure.net`
- `privatelink.azurecr.io`
- `privatelink.cognitiveservices.azure.com`
- `privatelink.openai.azure.com`
- `privatelink.services.ai.azure.com`
- `privatelink.search.windows.net`
- `privatelink.documents.azure.com`

Create **Virtual network links** from each zone (in the platform RG) to the **spoke VNet**.

Option A — Azure Portal (recommended for manual testing)
1) Go to the platform RG: `rg-ailz-platform-RANDOM_SUFFIX`
2) Open each **Private DNS zone** listed above
3) Go to **Virtual network links** → **Add**
4) Configure:
  - **Link name**: `spoke-link`
  - **Virtual network**: select the spoke VNet (or paste/select by resource ID)
  - **Enable auto registration**: Disabled
5) Create the link and repeat for all zones.

Option B — Azure CLI

1) Capture the spoke VNet resource ID:

`$spokeVnetId = az network vnet show --resource-group rg-ai-lz-RANDOM_SUFFIX --name vnet-<baseName> --query id -o tsv`

2) Create a VNet link for each zone (PowerShell example):

Note: if you are not using Azure public cloud, replace `privatelink.blob.core.windows.net` with the correct storage DNS suffix for your cloud.

`$platformRg = 'rg-ailz-platform-RANDOM_SUFFIX'`

`$zones = @(
  "privatelink.blob.core.windows.net",
  "privatelink.file.core.windows.net",
  "privatelink.vaultcore.azure.net",
  "privatelink.azurecr.io",
  "privatelink.cognitiveservices.azure.com",
  "privatelink.openai.azure.com",
  "privatelink.services.ai.azure.com",
  "privatelink.search.windows.net",
  "privatelink.documents.azure.com"
)`

`foreach ($zone in $zones) { az network private-dns link vnet create --resource-group $platformRg --zone-name $zone --name spoke-link --virtual-network $spokeVnetId --registration-enabled false }`

Validation (Azure CLI):

`az network private-dns link vnet list --resource-group rg-ailz-platform-RANDOM_SUFFIX --zone-name privatelink.openai.azure.com -o table`

## Step 4 — Establish hub↔spoke connectivity (peering)

In many PLZ setups, the workload deployment identity cannot create peering on the **hub** VNet (platform-owned).

- This runbook requires the workload deployment to create the **spoke → hub** peering (Step 2).
- The platform team must still create the **hub → spoke** peering (reverse peering) using your platform process (Portal, policy-driven automation, or a separate platform deployment).
- Ensure peering is configured with forwarded traffic enabled if you expect forced tunneling to work.

### Platform-side action (required): create the hub → spoke peering

You need these inputs:
- Hub VNet RG/name: from Step 1 (this test uses `rg-ailz-platform-RANDOM_SUFFIX` and `vnet-ai-lz-hub`)
- Spoke VNet resource ID: from the workload outputs or Portal

Important Portal note (common error):
- In Step 2, the workload deployment typically creates the **spoke → hub** peering (for example, named `to-hub`).
- In the Azure Portal, **Add peering** is designed to configure *both directions* (hub → spoke and spoke → hub) in one flow.
- If the spoke → hub peering already exists, the Portal can fail with an error like "Cannot add another peering ... referencing the same remote virtual network".

In this runbook, the platform action you need is **only** the hub → spoke peering. The most reliable way to do that is Azure CLI (Option B). Portal steps (Option A) work best when done using an identity that can manage the hub VNet but does **not** have write permissions on the spoke VNet.

Option A — Azure Portal (recommended for manual testing)
1) Go to Hub VNet: `vnet-ai-lz-hub`
2) Go to **Peerings** → **Add**
3) In **Remote virtual network summary**, select the spoke VNet from the **Virtual network** dropdown (recommended). If you don't have read access to the spoke VNet, check **I know my resource ID** and paste the spoke VNet resource ID.
4) In **Remote virtual network peering settings**, do not change anything (leave defaults). In this runbook you are not trying to configure the spoke-side peering here.
5) In **Local virtual network summary / peering settings** (the hub-side peering), configure:
  - **Peering link name (this virtual network)**: `hub-to-spoke`
  - **Allow virtual network access**: Enabled
  - **Allow forwarded traffic**: Enabled
  - **Allow gateway transit**: Disabled (unless your platform requires it)
  - **Use remote gateways**: Disabled
6) Create and wait until the peering shows **Connected**.

If the Portal fails due to an existing spoke → hub peering, use Option B to create only the hub-side peering.

Option B — Azure CLI

`az network vnet peering create --resource-group rg-ailz-platform-RANDOM_SUFFIX --vnet-name vnet-ai-lz-hub --name hub-to-spoke --remote-vnet /subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/... --allow-vnet-access --allow-forwarded-traffic`

Validation commands (Azure CLI):

Hub peerings:

`az network vnet peering list --resource-group rg-ailz-platform-RANDOM_SUFFIX --vnet-name vnet-ai-lz-hub -o table`

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
  - On the VM, open **PowerShell** and run quick sanity checks:

`hostname`

`whoami`

`ipconfig /all`

`route print`

- **DNS (from the hub VM via Bastion)**
  - Validate the hub VM is using Azure-provided DNS (typical for VNets) and can query your Private DNS Zones.
  - These checks validate the *zone link* exists; they don’t guarantee A records exist (A records depend on Private Endpoint + DNS record management).

`nslookup -type=SOA privatelink.vaultcore.azure.net`

`nslookup -type=SOA privatelink.azurecr.io`

`nslookup -type=SOA privatelink.cognitiveservices.azure.com`

`nslookup -type=SOA privatelink.openai.azure.com`

Optional (if you created Private Endpoints and your process created DNS records in the platform zones):

`nslookup <your-private-endpoint-fqdn>`

- **DNS**
  - The hub VM can resolve `privatelink.*` names (e.g., after a Private Endpoint exists in the spoke)

- **Connectivity smoke tests (from the hub VM via Bastion)**
  - Validate basic outbound connectivity and see the path taken.

`Test-NetConnection www.microsoft.com -Port 443`

`tracert 1.1.1.1`

- **Forced tunneling (Spoke UDR)**
  - With `deployToggles.userDefinedRoutes=true` in the workload, validate the spoke route tables point to `firewallPrivateIp`

- **Hub → Spoke connectivity**
  - Ensure hub↔spoke peering exists (required for forced tunneling to a hub firewall)
  - Ensure both sides show **Connected** and **Allow forwarded traffic** is enabled

## Cleanup

Delete the mini platform RG:

`az group delete --name rg-ailz-platform-RANDOM_SUFFIX --yes --no-wait`

Delete the workload RG:

`az group delete --name rg-ai-lz-RANDOM_SUFFIX --yes --no-wait`
