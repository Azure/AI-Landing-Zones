# Platform Landing Zone (PLZ) Test

This guide provisions a **minimal platform (Hub) environment** so you can test `flagPlatformLandingZone=true` with the main template.

The goal is to have:
- Hub VNet with **Azure Firewall**
- **Private DNS Zones** (PDNS) + **VNet links**
- **Azure Bastion** (jump host)
- A **test VM in the hub**

> Note: this environment is for **testing only**. It intentionally uses permissive Firewall Policy rules to simplify validation.

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

```bash
az group create --name rg-ai-lz-test-platform --location eastus2
```

2) Deploy the mini platform to that RG:

```bash
az deployment group create \
  --name platform-test \
  --resource-group rg-ai-lz-test-platform \
  --template-file bicep/tests/platform.bicep \
  --parameters adminPassword='REPLACE_ME_STRONG_PASSWORD'
```

Optional (override the test VM image/size):

```bash
az deployment group create \
  --name platform-test \
  --resource-group rg-ai-lz-test-platform \
  --template-file bicep/tests/platform.bicep \
  --parameters \
      adminPassword='REPLACE_ME_STRONG_PASSWORD' \
      vmSize='Standard_D8s_v5' \
      vmImagePublisher='MicrosoftWindowsDesktop' \
      vmImageOffer='windows-11' \
      vmImageSku='win11-25h2-ent' \
      vmImageVersion='latest'
```

### Get outputs

```bash
az deployment group show \
  --name platform-test \
  --resource-group rg-ai-lz-test-platform \
  --query properties.outputs \
  -o json
```

Keep these outputs handy:
- `platformResourceGroupName`
- `hubVnetResourceId`
- `firewallPrivateIp`
- `privateDnsZonesDeployed` (array of `{ name, id }`)

## Step 2 — Deploy the workload (Spoke) with `flagPlatformLandingZone=true`

Now deploy the main template for your workload/spoke and reference the platform outputs.

1) Create (or choose) a Resource Group for the workload (spoke), e.g. `rg-ai-lz-workload-test`.
2) Start from the PLZ parameter file:
   - [bicep/infra/sample.platform-landing-zone.bicepparam](../../infra/sample.platform-landing-zone.bicepparam)

### What you must set in the `.bicepparam`

- `flagPlatformLandingZone = true`
- `deployToggles.userDefinedRoutes = true` (to validate forced-tunneling/UDR in the spoke)
- `firewallPrivateIp = <firewallPrivateIp output from step 1>`
- `resourceIds.privateDnsZones = ...` pointing to the PDNS zones created in the hub

> Tip: `privateDnsZonesDeployed` from step 1 gives you the zone IDs.

### Deploy the workload

Example (adjust RG and parameter file as needed):

```bash
az deployment group create \
  --resource-group rg-ai-lz-workload-test \
  --template-file bicep/infra/main.bicep \
  --parameters bicep/infra/sample.platform-landing-zone.bicepparam
```

## Step 3 — (Optional) Link the PDNS zones to the Spoke VNet

In PLZ setups, the platform typically owns **creating PDNS VNet links** for spoke VNets.

The template [bicep/tests/platform.bicep](../../tests/platform.bicep) supports an optional parameter:
- `spokeVnetResourceId` (resource ID of the spoke VNet)

After the spoke VNet exists, re-deploy the platform template adding that parameter to create the VNet links.

Example:

```bash
az deployment group create \
  --name platform-test \
  --resource-group rg-ai-lz-test-platform \
  --template-file bicep/tests/platform.bicep \
  --parameters adminPassword='REPLACE_ME_STRONG_PASSWORD' spokeVnetResourceId='/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/...'
```

## Validation checklist

- **Bastion**
  - Connect to `vm-ai-lz-hubtest` via Bastion in the Azure Portal

- **DNS**
  - The hub VM can resolve `privatelink.*` names (e.g., after a Private Endpoint exists in the spoke)

- **Forced tunneling (Spoke UDR)**
  - With `deployToggles.userDefinedRoutes=true` in the workload, validate the spoke route tables point to `firewallPrivateIp`

- **Hub → Spoke connectivity**
  - Ensure hub↔spoke peering exists (if required by your scenario)

## Cleanup

Delete the mini platform RG:

```bash
az group delete --name rg-ai-lz-test-platform --yes --no-wait
```

Delete the workload RG:

```bash
az group delete --name rg-ai-lz-workload-test --yes --no-wait
```
