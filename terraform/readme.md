# Terraform Deployment Guide for AI Landing Zones

## What This Deployment Does

This Terraform configuration deploys an **AI Landing Zone** which is a complete AI/ML platform environment ready for development and deployment of AI applications.

---

## Prerequisites

### 1. Install Required Tools

**Terraform (version 1.9 or higher, but less than 2.0):**
- Download from [terraform.io](https://www.terraform.io/downloads.html)
- After installation, verify by running: `terraform --version`
- You should see output like: `Terraform v1.9.x`

**Azure CLI:**
- Download from [docs.microsoft.com/en-us/cli/azure/install-azure-cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- After installation, verify by running: `az --version`
- You should see Azure CLI version information

### 2. Azure Subscription Requirements

- An active Azure subscription
- **Owner** or **Contributor** role on the subscription (required to create resources)
- Sufficient quota for the resources being deployed (VMs, networking, AI services)

### 3. Register Required Resource Providers

Before deploying, ensure these Azure resource providers are registered.  If not, terraform will register the providers during deployment, which may cause delays:

```powershell
az provider register --namespace Microsoft.CognitiveServices
az provider register --namespace Microsoft.MachineLearningServices
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.DocumentDB
az provider register --namespace Microsoft.Search
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.Compute
az feature register --name EncryptionAtHost --namespace Microsoft.Compute
```

**Note:** Provider registration can take 5-10 minutes. Check status with:
```powershell
az provider show --namespace Microsoft.CognitiveServices --query "registrationState"
```

---

## Step-by-Step Deployment Instructions

### Step 1: Authenticate to Azure

There are two methods to authenticate: **Interactive Login** (recommended for personal use) or **Service Principal** (recommended for automation/CI/CD).

#### Option A: Interactive Login (Easiest for Getting Started)

Open PowerShell and log in to Azure:

```powershell
az login
```

**What happens:**
- A browser window will open
- Sign in with your Azure account
- The CLI will display your available subscriptions

**Set the correct subscription (if you have multiple):**
```powershell
# List all subscriptions
az account list --output table

# Set the subscription you want to use
az account set --subscription "<YOUR_SUBSCRIPTION_ID_OR_NAME>"

# Verify the correct subscription is selected
az account show --output table
```

#### Option B: Service Principal Authentication (For Automation)

**When to use Service Principals:**
- Running Terraform in CI/CD pipelines (Azure DevOps, GitHub Actions)
- Automated deployments without interactive login
- Shared environments where multiple people deploy
- When you need specific permission boundaries

**Step 1: Get Your Subscription ID**
```powershell
az login  # Log in first to create the service principal
az account show --query id --output tsv
```

**Step 2: Create the Service Principal**
```powershell
# Replace <SUBSCRIPTION_ID> with your actual subscription ID
# Replace <SP_NAME> with a descriptive name (e.g., "terraform-ai-landing-zone-sp")
# The below command creates a Service Principal and assigns contributor role to the subscription
az ad sp create-for-rbac --name "<SP_NAME>" --role="Contributor" --scopes="/subscriptions/<SUBSCRIPTION_ID>"
```

**Example output:**

```json
{
  "appId": "12345678-1234-1234-1234-123456789abc",
  "displayName": "terraform-ai-landing-zone-sp",
  "password": "abcdefgh-1234-5678-90ab-cdefghijklmn",
  "tenant": "87654321-4321-4321-4321-210987654321"
}
```

**Save these values securely!** You won't be able to see the password again.

**Add Role assignment to Service Principal**

```powershell
# The Service Principal requires the "User Access Administrator" role to grant Key Vault permissions. 
# Replace <SP_AppId> with the Application ID from the output above. This value corresponds to the Service Principal's AppId.
# Assigning the role:
az role assignment create --assignee "<SP_AppID>" --role="User Access Administrator" --scope="/subscriptions/<SUBSCRIPTION_ID>"
```
**Step 3: Set Environment Variables**

In PowerShell, set these environment variables (they must be named exactly as shown):

```powershell
# Set environment variables for the current session
$env:ARM_CLIENT_ID="<appId from output>"
$env:ARM_CLIENT_SECRET="<password from output>"
$env:ARM_TENANT_ID="<tenant from output>"
$env:ARM_SUBSCRIPTION_ID="<your subscription ID>"
$env:ARM_USE_AZUREAD=true

# Verify they're set
echo "Client ID: $env:ARM_CLIENT_ID"
echo "Tenant ID: $env:ARM_TENANT_ID"
echo "Subscription ID: $env:ARM_SUBSCRIPTION_ID"
echo "Client Secret is set: $($env:ARM_CLIENT_SECRET -ne $null)"
echo "Use Azure AD: $env:ARM_USE_AZUREAD"
```

**To make these permanent (persist across PowerShell sessions):**
```powershell
# Set user environment variables (permanent)
[System.Environment]::SetEnvironmentVariable('ARM_CLIENT_ID', '<appId>', 'User')
[System.Environment]::SetEnvironmentVariable('ARM_CLIENT_SECRET', '<password>', 'User')
[System.Environment]::SetEnvironmentVariable('ARM_TENANT_ID', '<tenant>', 'User')
[System.Environment]::SetEnvironmentVariable('ARM_SUBSCRIPTION_ID', '<subscription_id>', 'User')
[System.Environment]::SetEnvironmentVariable('ARM_USE_AZUREAD', 'true', 'User')

# Refresh your current session to load the variables
$env:ARM_CLIENT_ID = [System.Environment]::GetEnvironmentVariable('ARM_CLIENT_ID', 'User')
$env:ARM_CLIENT_SECRET = [System.Environment]::GetEnvironmentVariable('ARM_CLIENT_SECRET', 'User')
$env:ARM_TENANT_ID = [System.Environment]::GetEnvironmentVariable('ARM_TENANT_ID', 'User')
$env:ARM_SUBSCRIPTION_ID = [System.Environment]::GetEnvironmentVariable('ARM_SUBSCRIPTION_ID', 'User')
$env:ARM_USE_AZUREAD = [System.Environment]::GetEnvironmentVariable('ARM_USE_AZUREAD', 'User')
```

**Step 4: Test the Service Principal**
```powershell
# Login using the service principal
az login --service-principal --username $env:ARM_CLIENT_ID --password $env:ARM_CLIENT_SECRET --tenant $env:ARM_TENANT_ID

# Verify access
az account show
```

**Important Notes:**
- When these environment variables are set, Terraform automatically uses them
- You don't need to run `az login` when using service principal environment variables
- Keep the client secret secure - treat it like a password
- Service principals can have specific permissions (Contributor role in this case)

**For CI/CD Pipelines:**
Store these as secrets in your pipeline:
- **Azure DevOps:** Pipeline > Edit > Variables > Add (select "Keep this value secret")
- **GitHub Actions:** Repository > Settings > Secrets and variables > Actions > New repository secret

---

### Step 2: Navigate to the Terraform Directory

```powershell
cd C:\Git\AI-Landing-Zones\terraform
```

---

### Step 3: (Optional) Set Up Remote Backend

**What is a backend?**
Terraform stores information about your infrastructure in a "state file". By default, this is stored locally. For production or team environments, you should store it in Azure Storage.

**Option A: Use Local Backend (Recommended for Testing)**

No action needed. Terraform will create a `terraform.tfstate` file locally.

**Option B: Use Azure Storage Backend (Recommended for Production)**

First, create the backend resources:

```powershell
# Set variables (customize these)
$RESOURCE_GROUP_NAME="tfstate-rg"
$STORAGE_ACCOUNT_NAME="tfstate$(Get-Random -Minimum 10000 -Maximum 99999)"  # Must be globally unique
$CONTAINER_NAME="tfstate"
$LOCATION="eastus"

# Create resource group
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

# Create storage account
az storage account create --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP_NAME --location $LOCATION --sku Standard_LRS

# Create blob container
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --auth-mode login
```

**Then create a file named `backend.tf` in the terraform directory:**

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstate12345"  # Use the name from above
    container_name       = "tfstate"
    key                  = "ai-landing-zone.tfstate"
  }
}
```

---

### Step 4: Configure Variables (Optional)

The code has default values, but you can customize them by creating a `terraform.tfvars` file:

```hcl
# terraform.tfvars
enable_telemetry = true  # Set to false if you don't want to send telemetry to Microsoft
```

**Note:** The location and resource names are hardcoded in `main.tf`. If you want to change them, edit `main.tf` directly:
- Look for `location = "swedencentral"` (line ~17)
- Look for `resource_group_name = "ai-lz-rg-01"` (line ~19)

---

### Step 5: Initialize Terraform

This downloads the required providers and modules:

```powershell
terraform init
```

**Expected output:**
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "~> 4.21"...
- Finding hashicorp/http versions matching "~> 3.4"...
- Installing hashicorp/azurerm v4.21.x...
- Installed hashicorp/azurerm v4.21.x

Terraform has been successfully initialized!
```

**If you see errors:**
- Check your internet connection
- Ensure you have Terraform 1.9+ installed
- Try running `terraform init -upgrade`

---

### Step 6: Review the Deployment Plan

See what Terraform will create without actually creating it:

```powershell
terraform plan
```

**Expected output:**
- A long list of resources to be created (50+ resources)
- At the end: `Plan: XX to add, 0 to change, 0 to destroy.`

**Review the output carefully:**
- Check that the location is correct
- Check that resource names make sense
- Ensure no unexpected resources are being created

---

### Step 7: Deploy the Infrastructure

Apply the configuration to create the resources:

```powershell
terraform apply
```

**What happens:**
1. Terraform will show the plan again
2. You'll be prompted: `Do you want to perform these actions?`
3. Type `yes` and press Enter

**Expected duration:** 15-30 minutes

**You'll see progress output like:**
```
module.test.azurerm_resource_group.this: Creating...
module.test.azurerm_virtual_network.this: Creating...
module.test.azurerm_resource_group.this: Creation complete after 2s
...
Apply complete! Resources: XX added, 0 changed, 0 destroyed.
```

**If deployment fails:**
- Read the error message carefully
- Common issues:
  - Quota limits (request quota increase in Azure Portal)
  - Region capacity (try a different region)
  - Permission issues (ensure you have Contributor role)
  - Provider not registered (see Prerequisites Step 3)

---

### Step 8: Verify the Deployment

Check that resources were created:

```powershell
# List resource groups
az group list --output table

# List resources in the AI Landing Zone resource group
az resource list --resource-group ai-lz-rg-01 --output table
```

**You should see resources like:**
- Virtual Network (ai-lz-vnet-01)
- AI Hub
- Storage accounts
- Key Vault
- Container Registry
- And more...

---

### Step 9: Access Your Resources

**Azure Portal:**
1. Go to [portal.azure.com](https://portal.azure.com)
2. Navigate to Resource Groups
3. Click on `ai-lz-rg-01`
4. Explore the deployed resources

**Azure AI Foundry:**
1. Go to [ai.azure.com](https://ai.azure.com)
2. You should see your AI Hub and Project

---

## Making Changes

If you need to modify the configuration:

1. Edit the relevant `.tf` files (usually `main.tf`)
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to apply changes

**Example:** To change the location:
- Open `main.tf`
- Find `location = "swedencentral"`
- Change to your desired region (e.g., `location = "eastus"`)
- Run `terraform plan` and `terraform apply`

---

## Clean Up / Destroy Resources

**WARNING:** This will delete ALL resources created by this Terraform configuration!

```powershell
terraform destroy
```

**What happens:**
1. Terraform shows what will be destroyed
2. You'll be prompted: `Do you really want to destroy all resources?`
3. Type `yes` and press Enter
4. All resources will be deleted (takes 10-15 minutes)

**Note:** If destroy fails due to lingering dependencies, wait a few minutes and try again.

---

## Troubleshooting Common Issues

### Issue: "Error: building account" or authentication errors

**Solution:**
```powershell
# Re-authenticate
az login
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
```

### Issue: "Error: insufficient quota"

**Solution:**
- Go to Azure Portal → Subscriptions → Usage + quotas
- Request a quota increase for the required resource
- Or try deploying to a different region

### Issue: "Error: Resource provider not registered"

**Solution:**
```powershell
# Register the provider mentioned in the error
az provider register --namespace <NAMESPACE_FROM_ERROR>
# Wait a few minutes and try again
```

### Issue: "Error: A resource with the ID already exists"

**Solution:**
- Another resource with the same name exists
- Either delete the existing resource or change the name in `main.tf`

### Issue: Terraform init fails with module download errors

**Solution:**
```powershell
# Clear the cache and re-initialize
Remove-Item -Recurse -Force .terraform
terraform init
```

### Issue: "Error: storage account name is not available"

**Solution:**
- Storage account names must be globally unique
- The code tries to generate a unique name, but if it fails, edit `main.tf` to use a different storage account name

---

## Understanding the Terraform Files

- **`terraform.tf`**: Defines Terraform version and required providers (azurerm, http, random)
- **`variables.tf`**: Defines input variables (only `enable_telemetry` in this case)
- **`main.tf`**: The main configuration that defines all Azure resources
- **`terraform.tfstate`**: Created after deployment, stores current infrastructure state (DO NOT manually edit)
- **`terraform.tfvars`**: (Optional) Your custom variable values
- **`backend.tf`**: (Optional) Remote backend configuration for state storage

---

## Next Steps After Deployment

1. **Explore AI Foundry:**
   - Go to [ai.azure.com](https://ai.azure.com)
   - Open your project: "Project 1 Display Name"
   - Start building AI applications

2. **Connect to Resources:**
   - Use Azure Bastion to securely connect to VMs
   - Access Container Registry to push/pull container images
   - Use Key Vault to manage secrets

3. **Deploy AI Models:**
   - The deployment includes GPT-4o model deployment
   - You can deploy additional models through Azure AI Foundry

4. **Set Up CI/CD:**
   - Integrate with Azure DevOps or GitHub Actions
   - Automate model deployment and application updates

---

## Additional Resources

- [Azure AI Foundry Documentation](https://learn.microsoft.com/azure/ai-studio/)
- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure AI Landing Zone Pattern](https://github.com/Azure/AI-Landing-Zones)

---

## Getting Help

If you encounter issues:
1. Check the error message carefully
2. Review the Troubleshooting section above
3. Check Azure Portal for resource status
4. Review Terraform state: `terraform show`
5. Open an issue on the GitHub repository

---

## Summary Checklist

- [ ] Install Terraform (1.9+)
- [ ] Install Azure CLI
- [ ] Run `az login` and set correct subscription
- [ ] Register required Azure resource providers
- [ ] Navigate to terraform directory
- [ ] (Optional) Create backend storage and `backend.tf`
- [ ] (Optional) Create `terraform.tfvars` with custom values
- [ ] Run `terraform init`
- [ ] Run `terraform plan` and review
- [ ] Run `terraform apply` and type `yes`
- [ ] Wait 15-30 minutes for deployment
- [ ] Verify resources in Azure Portal
- [ ] Access AI Foundry at ai.azure.com

You're now ready to build AI applications on your new AI Landing Zone!
