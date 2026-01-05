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

Note on defaults: the spoke CIDRs shown above are the **default subnet ranges** used by the main template when you do not override `vNetDefinition`.
If you override the spoke VNet/subnet CIDRs, also update any CIDR-dependent settings (especially `firewallPolicyDefinition` `sourceAddresses` in your workload `.bicepparam`) to match your actual subnet ranges.
```

> Note: this environment is for **testing only**.
> The hub firewall policy is intentionally **allowlist-based** to support **Foundry Agent Service (Azure Container Apps) + Managed Identity** scenarios behind forced tunneling.
> It does **not** publish inbound services from the internet (no DNAT rules); inbound access to the hub VM is via **Bastion**.

Outbound Internet (hub test VM):
- The hub test template ([bicep/tests/platform.bicep](../../tests/platform.bicep)) uses **forced tunneling** for the hub test VM too: it associates a **route table** to `hub-vm-subnet` with `0.0.0.0/0 -> VirtualAppliance(firewallPrivateIp)`.
- That means the hub test VM only has outbound internet if the **Azure Firewall policy** allows it.
- For training and troubleshooting simplicity, the test template allows **full outbound internet** from `hub-vm-subnet`.
- Quick validation (from inside the hub VM):
  - `Resolve-DnsName login.microsoftonline.com`
  - `Test-NetConnection login.microsoftonline.com -Port 443`
  - `Resolve-DnsName mcr.microsoft.com`
  - `Test-NetConnection mcr.microsoft.com -Port 443`
  - `Resolve-DnsName packages.aks.azure.com`
  - `Test-NetConnection packages.aks.azure.com -Port 443`
- If validation fails:
  - Confirm the subnet has a route table attached and the default route points at `firewallPrivateIp`.
  - Confirm the Azure Firewall policy includes an allow rule for the hub VM subnet (in the test template this is named `allow-hub-vm-all-egress`).
  - Confirm there is **no TLS inspection** (no self-signed cert injection) on the firewall.

## Prerequisites

- Permissions to create resources in the subscription (e.g., `Contributor`)
- Azure CLI authenticated: `az login`
- Bicep available in Azure CLI (usually built-in)
- A local clone of this repo (commands reference local paths like `bicep/tests/platform.bicep`)

Tip: run all commands from the repo root directory.

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

## Step 1.5 — Validate tools installation on the hub test VM

The test hub deploys a Windows VM (`vm-ailz-hubtst`) that you can reach via **Bastion**.

By default, the template runs `install.ps1` via **Custom Script Extension (CSE)**.
The script automatically installs:
- Chocolatey package manager
- Azure CLI
- Git
- Python 3.11
- VS Code
- PowerShell 7
- Docker Desktop
- Azure Developer CLI (azd)
- WSL2 features (Microsoft-Windows-Subsystem-Linux, VirtualMachinePlatform)
- WSL kernel update MSI

CSE logs are written to: `C:\WindowsAzure\Logs\AI-Landing-Zones_CustomScriptExtension.txt`

In the current test config, CSE uses `-skipReboot:$true -skipRepoClone:$true -skipAzdInit:$true` to install tools without automatic reboot, repo cloning, or AZD initialization.

Note: WSL and Docker Desktop are **not required** for this PLZ connectivity test (hub-spoke peering, forced tunneling, firewall validation). They are installed for convenience if you want to use the hub VM for development/testing. **If you want to use WSL/Docker, you must reboot the VM** after CSE completes (see optional steps below).

Important (when testing changes to `install.ps1`): the VM downloads the script from GitHub.
If your changes are in a fork/branch or tag, deploy the hub template overriding the repo/release:

`az deployment group create --name ailz-platform-RANDOM_SUFFIX --resource-group rg-ailz-platform-RANDOM_SUFFIX --template-file bicep/tests/platform.bicep --parameters adminPassword='REPLACE_ME_STRONG_PASSWORD' testVmInstallScriptRepo='YOUR_GH_ORG/AI-Landing-Zones' testVmInstallScriptRelease='YOUR_BRANCH_OR_TAG'`

Note: `testVmInstallScriptRelease` accepts a **branch name** (e.g., `main`, `release/2.0.1`) or a **tag** (e.g., `v1.0.0`).

### Post-CSE validation

Connect to `vm-ailz-hubtst` using **Bastion** (RDP).
Important: This VM uses **forced tunneling** through Azure Firewall.

### Validate core tools (PowerShell)

```powershell
# Validate installed versions
az --version | Select-String 'azure-cli'
git --version
python --version
code --version
pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
azd version
```

Troubleshooting:
- **If CSE failed**: Check `C:\WindowsAzure\Logs\AI-Landing-Zones_CustomScriptExtension.txt` and retry deployment
- **If `az` not found**: Verify PATH includes `C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin`
- **If `azd` not found**: Verify PATH includes `C:\Program Files\Azure Dev CLI`

### Optional: WSL and Docker Desktop setup

WSL and Docker Desktop are **not required** for this PLZ connectivity test. Only set them up if you need them for development.

1) **Reboot the VM** to enable WSL features:
   - Via Bastion → Send Ctrl+Alt+Del → Restart
   - Or via Azure Portal → VM → Restart

2) **After reboot**, finalize WSL setup (elevated PowerShell):

```powershell
wsl.exe --install --no-distribution
wsl.exe --set-default-version 2
wsl.exe --status
```

3) **Start Docker Desktop** (Start menu) and validate:

```powershell
docker info
```

If Docker Desktop fails with "Virtualization support not detected":
- Ensure VM was rebooted (WSL features require reboot)
- Validate Hyper-V requirements: `systeminfo | findstr /i "Hyper-V Requirements"`
- Verify VM SKU supports nested virtualization (Standard_D8s_v5 does, some SKUs don't)

### Optional: Clone the repo for hands-on testing

If you want the VM ready for hands-on testing from inside the hub:

`New-Item -ItemType Directory -Path 'C:\github' -Force | Out-Null`

`Set-Location 'C:\github'`

`git clone https://github.com/Azure/AI-Landing-Zones --depth 1`

Why:
- `--depth 1` reduces download size/time (important behind strict egress).
- Cloning gives you local access to templates/scripts for inspection and manual operations.

Note: if you want to test a specific branch, add `-b <branchName>` to the `git clone` command.

### Optional: Managed identity login

If the VM has a managed identity and your environment allows it:

`az login --identity --allow-no-subscriptions`

Why: signs in using the VM's managed identity without requiring interactive browser auth.

`azd auth login --managed-identity`

Why: allows AZD commands that need auth context to run using managed identity.

### Capture Step 1 outputs for Step 2

After the platform deployment completes, you need to capture these outputs manually:
- `hubVnetResourceId`
- `firewallPrivateIp`

You can retrieve them from the deployment outputs (replace `RANDOM_SUFFIX` with your actual suffix):

`az deployment group show --name ailz-platform-RANDOM_SUFFIX --resource-group rg-ailz-platform-RANDOM_SUFFIX --query properties.outputs -o json`

Copy these values - you'll use them in Step 2 when configuring `main.bicepparam`.

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

- Edit `bicep/infra/main.bicepparam` and add these lines (using the values from Step 1):

```bicep
// Platform Landing Zone configuration
using 'main.bicep'

// Required: Platform outputs from Step 1
param firewallPrivateIp = '<firewallPrivateIp from Step 1>'
param hubVnetPeeringDefinition = {
  peerVnetResourceId: '<hubVnetResourceId from Step 1>'
}

// Enable PLZ mode and forced tunneling
param flagPlatformLandingZone = true
param deployToggles = {
  userDefinedRoutes: true
  // ... keep other default values from sample.platform-landing-zone.bicepparam
}
```

Example with actual values:

```bicep
param firewallPrivateIp = '10.0.4.4'
param hubVnetPeeringDefinition = {
  peerVnetResourceId: '/subscriptions/00000000-1111-2222-3333-444444444444/resourceGroups/rg-ailz-platform-123/providers/Microsoft.Network/virtualNetworks/vnet-ai-lz-hub'
}
```

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

After the VNet links exist, the platform must ensure the required DNS records exist in the platform zones (Step 4).

Azure Portal
1) Go to the platform RG: `rg-ailz-platform-RANDOM_SUFFIX`
2) Open each **Private DNS zone** listed above
3) Go to **Virtual network links** → **Add**
4) Configure:
  - **Link name**: `spoke-link`
  - **Virtual network**: select the spoke VNet (or paste/select by resource ID)
  - **Enable auto registration**: Disabled
5) Create the link and repeat for all zones.

## Step 4 — Platform-side DNS record management (manual A records)

In PLZ setups, the workload deployment creates **Private Endpoints** in the spoke but typically does **not** have permissions to write DNS records into platform-owned Private DNS Zones. In that case, platform zones will show only the **SOA** record until the platform team creates `A` records.

Goal of this step: create the `A` records in the platform `privatelink.*` zones based on what was actually deployed (no hardcoded names or IPs).

Note (why `privatelink.*` zones matter): many Azure services use this DNS chain for Private Endpoints:
- Your app uses the "public" hostname (example: `*.openai.azure.com`).
- When Private Link is enabled, DNS does **not** usually return an `A` record directly for the public hostname.
  Instead, the public hostname resolves to a **CNAME** that points at a name under a `privatelink.*` zone.
  - Example pattern (OpenAI): `myresource.openai.azure.com` → CNAME → `myresource.privatelink.openai.azure.com`
  - Example pattern (Key Vault): `myvault.vault.azure.net` → CNAME → `myvault.privatelink.vaultcore.azure.net`
  - Example pattern (Storage blob): `mystorage.blob.core.windows.net` → CNAME → `mystorage.privatelink.blob.core.windows.net`
- The **private IP** is returned only when the `privatelink.*` name resolves to an `A` record in the platform-owned `privatelink.*` Private DNS Zone.

Important: in the Azure Portal, the Private Endpoint **DNS configuration** blade typically shows the *private* FQDNs (the `*.privatelink.*` names) that must resolve inside the VNet. In this runbook, the platform team should create the `A` records for those `*.privatelink.*` names (not for the public hostname).

That’s why creating the `A` record in the correct `privatelink.*` zone makes `*.openai.azure.com` (and similar service hostnames) resolve to the Private Endpoint IP inside the VNet.

Azure Portal (recommended)

1) In the Azure Portal, go to the spoke Resource Group: `rg-ai-lz-RANDOM_SUFFIX`
2) Open each **Private Endpoint** that was created by this workload deployment
3) In the Private Endpoint blade, open **DNS configuration**

Important (expected in PLZ): in many PLZ setups you will see the required FQDN/IP pairs under **Custom DNS records**, but the **DNS zone group / Private DNS zone** section can show **"No results"**.

That is not an error: it simply means the Private Endpoint is **not** integrated with a Private DNS Zone Group (automatic DNS record management). This runbook assumes the platform team manages DNS centrally, so the platform team creates the `A` records in the platform-owned `privatelink.*` zones based on the **Custom DNS records** list.

Note: without a DNS zone group, Azure will not auto-update records if the Private Endpoint is recreated or its IP changes. In that case you must update the platform `A` records.
4) For each entry shown, capture:
  - **FQDN** (the private name)
  - **Private IP address**

5) Go to the platform Resource Group: `rg-ailz-platform-RANDOM_SUFFIX`
6) Open **Private DNS zones** and choose the zone that matches the service:
  - Storage Blob: `privatelink.blob.core.windows.net`
  - Storage File: `privatelink.file.core.windows.net`
  - Key Vault: `privatelink.vaultcore.azure.net`
  - OpenAI: `privatelink.openai.azure.com`
  - AI Services: `privatelink.cognitiveservices.azure.com`
  - AI Services (new): `privatelink.services.ai.azure.com`
  - Azure AI Search: `privatelink.search.windows.net`
  - Cosmos DB (SQL): `privatelink.documents.azure.com`
  - ACR: `privatelink.azurecr.io`

For the current PLZ test configuration, you should typically see **4 Private Endpoints** in the spoke RG (names vary):
- **Storage** (often starts with `st...`): create `A` record(s) in `privatelink.blob.core.windows.net` (and/or `privatelink.file.core.windows.net` if DNS configuration shows file endpoints)
- **Cosmos DB (SQL)** (often contains `cosmosdb`): create `A` record(s) in `privatelink.documents.azure.com`
- **Azure AI Search** (often contains `search`): create `A` record(s) in `privatelink.search.windows.net`
- **AI Foundry core service** (often starts with `ai...`): use the **FQDN suffix** shown under **DNS configuration** to choose the right zone:
  - ends with `.privatelink.openai.azure.com` → `privatelink.openai.azure.com`
  - ends with `.privatelink.cognitiveservices.azure.com` → `privatelink.cognitiveservices.azure.com`
  - ends with `.privatelink.services.ai.azure.com` → `privatelink.services.ai.azure.com`

Important: a single Private Endpoint can show multiple DNS entries. Create one `A` record per (FQDN, IP) pair shown.

7) Create the record:
  - Go to **Record sets** → **+ Record set**
  - **Name**: use the left-most label of the FQDN (example: for `myvault.privatelink.vaultcore.azure.net`, name is `myvault`)
  - **Type**: `A`
  - Add the **Private IP address** from the Private Endpoint
  - Save

Repeat for all Private Endpoints and all DNS entries they expose.

Validation (Portal or CLI):
- In the Private DNS zone, the new `A` record should be visible.
- From the hub VM (via Bastion), `nslookup <fqdn>` should return the Private Endpoint IP.

## Step 5 — Establish hub↔spoke connectivity (peering)

In many PLZ setups, the workload deployment identity cannot create peering on the **hub** VNet (platform-owned).

- This runbook requires the workload deployment to create the **spoke → hub** peering (Step 2).
- The platform team must still create the **hub → spoke** peering (reverse peering). Recommended approach for this runbook: Azure CLI (below).
- Ensure peering is configured with forwarded traffic enabled if you expect forced tunneling to work.

### Platform-side action (required): create the hub → spoke peering

You need these inputs:
- Hub VNet RG/name: from Step 1 (this test uses `rg-ailz-platform-RANDOM_SUFFIX` and `vnet-ai-lz-hub`)
- Spoke VNet resource ID: from the workload outputs or Portal

Note (Azure Portal caveat): you can create the hub → spoke peering in the Portal, but it often fails due to an existing spoke → hub peering, because the Portal flow typically tries to configure both directions.

Azure CLI (recommended)

`az network vnet peering create --resource-group rg-ailz-platform-RANDOM_SUFFIX --vnet-name vnet-ai-lz-hub --name hub-to-spoke --remote-vnet /subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/... --allow-vnet-access --allow-forwarded-traffic`

What these flags do:

- `--allow-vnet-access`: Enables **Virtual network access** so resources in the hub VNet can reach **private IPs** in the spoke VNet (and vice-versa on the other peering).
- `--allow-forwarded-traffic`: Enables **Allow forwarded traffic** so traffic that is **routed/forwarded by an appliance** (for example, Azure Firewall in the hub) is allowed across the peering.

Why it matters for this PLZ test:

- With **forced tunneling** in the spoke (`0.0.0.0/0 -> hub firewall private IP`), the hub firewall forwards traffic on behalf of the spoke.
- If forwarded traffic is blocked on either peering direction, forced tunneling via the hub firewall can fail even when routes look correct.

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
