The AI Landing Zone repo includes a **Bicep-based implementation** of the AI Landing Zone to deploy a secure, modular baseline for AI apps and agents on Azure. Follow the steps below for prerequisites and deployment.

**1) Prerequisites**

* **Azure CLI** and **Azure Developer CLI** installed and signed in  
* A **resource group** in your target subscription  
* **Owner** or **Contributor + User Access Administrator** permissions on the subscription  

**2) Quick start with azd**

**Deployment steps**

2.1.  **Sign in to Azure**

   ```bash
   az login
   ```

   ```bash
   azd auth login
   ```

   > Note: If you work with multiple tenants, you can specify the tenant explicitly. For Azure CLI, use `az login --tenant <TENANT_ID_OR_DOMAIN>`. For Azure Developer CLI, use `azd auth login --tenant-id <TENANT_ID_OR_DOMAIN>`. For more sign-in options (device code, service principal, managed identity), see the documentation for `az login` and `azd auth login`.

2.2. **Create the resource group** where you will deploy the AI Landing Zone resources

   ```bash
   az group create --name "rg-ai-lz-RANDOM_SUFFIX" --location "eastus2"
   ```

   > Note: Replace `RANDOM_SUFFIX` with a unique value (for example a timestamp or a short random number) to avoid name collisions.

2.3. **Initialize the project**

   In an empty folder (e.g., `deploy`), run:

   ```bash
   azd init -t Azure/AI-Landing-Zones -e ai-lz-RANDOM_SUFFIX
   ```

2.4. **Set environment variables** `AZURE_LOCATION`, `AZURE_RESOURCE_GROUP`, `AZURE_SUBSCRIPTION_ID`.

**Bash (Linux/macOS, WSL, Cloud Shell)**

```bash
export AZURE_LOCATION="eastus2"
export AZURE_RESOURCE_GROUP="rg-ai-lz-RANDOM_SUFFIX"
export AZURE_SUBSCRIPTION_ID="00000000-1111-2222-3333-444444444444"
```

**PowerShell (Windows/PowerShell Core)**

```powershell
$env:AZURE_LOCATION = "eastus2"
$env:AZURE_RESOURCE_GROUP = "rg-ai-lz-RANDOM_SUFFIX"
$env:AZURE_SUBSCRIPTION_ID = "00000000-1111-2222-3333-444444444444"
```

2.5. **(Optional) Customize parameters**

   Edit `bicep/infra/main.bicepparam` if you want to adjust deployment options. The default configuration assumes a greenfield deployment scenario. For more deployment scenarios, see [Parameterization](./parameterization.md) and [Examples](./example-standalone.md).

2.6. **Provision the infrastructure**

   ```bash
   azd provision
   ```

   > Note: Provisioning uses Template Specs to bypass the 4 MB ARM template size limit. Pre-provision scripts build and publish them, while post-provision scripts remove them after success.

   > Tip: Alternative deployment with Azure CLI. Clone the repo, set environment variables manually (for example, `$env:VAR="value"`), run the pre-provision script, then use `az deployment group create` instead of `azd provision`. Remember to run the post-provision script after deployment.

**3) Accessing VMs**

> Note: VM deployment is optional. This section applies only if you chose to deploy the Jump VM or Build VM during provisioning.

**VM Credentials**

The template uses auto-generated random passwords by default for security. You can optionally provide custom passwords (or SSH keys for the Linux Build VM) as parameters during deployment.

**Default usernames:**

- Jump VM (Windows): `azureuser`
- Build VM (Linux): `builduser`

**Resetting Passwords**

If you used auto-generated passwords (default), reset them through the Azure Portal before connecting:

1. Navigate to the VM resource
2. Go to **Help** → **Reset password**
3. Enter the username and your new password
4. Click **Update**

![Reset Password in Azure Portal](media/reset_password.png)

**Connecting to VMs**

- **Jump VM (Windows)**: Azure Bastion or RDP
- **Build VM (Linux)**: SSH

Both VMs provide access to resources within the virtual network.


**4) Reference docs**

For detailed configuration and examples, see:

* **[Parameterization](./parameterization.md)** — Learn how to parameterize the deployment
* **[Examples](./example-standalone.md)** — Common deployment scenarios
