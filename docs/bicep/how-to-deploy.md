# How to Deploy

Choose your preferred deployment mode based on project requirements and environment constraints.

## Prerequisites

**Required permissions:**

- Azure subscription with **Contributor** and **User Access Admin** roles
- Agreement to Responsible AI terms for Azure AI Services

**Required tools:**

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- [Git](https://git-scm.com/downloads)

!!! note
    Azure CLI is included as a prerequisite for future pre/post provisioning hooks that may depend on it.

## Basic Deployment

Quick setup for demos and development environments without network isolation.

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

For deployments that **require network isolation**. All services communicate through private endpoints and public access is disabled.

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

## Next steps

- [Parameterization](parameterization.md) — Customize your deployment
- [Permissions](permissions.md) — Understand the role assignments
