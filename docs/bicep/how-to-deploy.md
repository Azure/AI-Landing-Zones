# How to Deploy

Choose your preferred deployment mode based on project requirements and environment constraints.

## Prerequisites

**Required permissions:**

- Azure subscription with **Contributor** and **User Access Admin** roles
- Agreement to Responsible AI terms for Azure AI Services

**Required tools:**

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- [PowerShell 7+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell) — required by the pre-flight validation hook (v2.0.0+)
- [Git](https://git-scm.com/downloads)

!!! note
    Azure CLI and PowerShell 7+ are required by the `azd preprovision` hook that runs `scripts/Invoke-PreflightChecks.ps1` before deployment. You can bypass the hook by setting `PREFLIGHT_SKIP=true` in your shell, but the script is the fastest way to catch parameter mistakes (subnet sizing, CIDR overlap, BYO resource typos) before they reach ARM.

## Basic Deployment

Quick setup for demos and development environments without network isolation. This is the **standalone** topology (the default in v2.0.0).

**1. Initialize the project**

```bash
azd init -t azure/bicep-ptn-aiml-landing-zone
```

**2. Sign in to Azure**

```bash
az login
azd auth login
```

!!! tip
    Add `--tenant` for `az` or `--tenant-id` for `azd` if you want to target a specific tenant.

**3. Provision infrastructure**

```bash
azd provision
```

!!! info "Optional customization"
    You can change parameter values in `main.parameters.json` or set them using `azd env set` before running `azd provision`. The latter applies only to parameters that support environment variable substitution. See [Parameterization](parameterization.md) for the full reference.

## Zero Trust Deployment

For deployments that **require network isolation**. All services communicate through private endpoints and public access is disabled (unless you supplement with an `allowedIpRanges` list, see below).

**1. Initialize the project**

```bash
azd init -t azure/bicep-ptn-aiml-landing-zone
```

**2. Enable network isolation**

```bash
azd env set NETWORK_ISOLATION true
```

!!! info "Optional customization"
    Update other parameters in `main.parameters.json` or via `azd env set` before provisioning. See [Parameterization](parameterization.md) for available settings.

**3. Sign in to Azure**

```bash
az login
azd auth login
```

!!! tip
    Add `--tenant` for `az` or `--tenant-id` for `azd` if you want to target a specific tenant.

**4. Provision infrastructure**

```bash
azd provision
```

### Using the Jumpbox VM

After a Zero Trust deployment, use the Jumpbox VM to access services inside the virtual network.

**1. Reset the VM password** (required on first access if not set in deployment parameters):

   - In the Azure Portal, go to your VM resource → **Support + troubleshooting** → **Reset password**
   - Set new credentials (default username is `testvmuser`)

**2. Connect via Azure Bastion**

   - In the Azure Portal, go to your VM resource → **Connect** → **Bastion**
   - Enter the credentials you set in step 1

## AI Landing Zone Integrated Deployment

For deployments that **plug into an existing Azure Landing Zone** — i.e. the spoke peers to a corporate hub that already provides Bastion, Firewall, Private DNS zones, and Log Analytics.

This topology assumes you (or another team) already operate a hub VNet and shared platform services. The AI Landing Zone spoke consumes them rather than re-creating them.

**1. Initialize the project**

```bash
azd init -t azure/bicep-ptn-aiml-landing-zone
```

**2. Set the topology preset and hub integration**

```bash
azd env set DEPLOYMENT_MODE ailz-integrated
azd env set HUB_VNET_RESOURCE_ID "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<hub-vnet>"
azd env set EGRESS_NEXT_HOP_IP "<hub firewall private IP>"
```

You'll typically also bring your own observability and DNS zones:

```bash
azd env set EXISTING_LOG_ANALYTICS_WORKSPACE_ID "/subscriptions/.../workspaces/<law>"
azd env set EXISTING_APPLICATION_INSIGHTS_ID    "/subscriptions/.../components/<ai>"
# Plus per-zone EXISTING_PRIVATE_DNS_ZONE_* IDs as needed — see Parameterization
```

**3. Sign in and provision**

```bash
az login
azd auth login
azd provision
```

!!! info "Full walkthrough"
    The [Hub-and-Spoke Topology](hub-and-spoke.md) page documents this scenario end-to-end, including a minimal test hub Bicep template, IP planning, peering setup, and verifying connectivity through the hub Bastion.

## Next steps
- [Migration to v2.0](migration-v2.md) — Upgrade guide for users coming from v1.x
- [Parameterization](parameterization.md) — Customize your deployment
- [Permissions](permissions.md) — Understand the role assignments
