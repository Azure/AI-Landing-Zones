# Terraform foundation reference

!!! note "Strategy under review"
    The Terraform deployment strategy is currently under review.

The [Terraform AI Landing Zone module](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone)
provides infrastructure building blocks and examples. Use its source and input
reference for Terraform-managed foundations.

For the Agent Landing Zone application, follow [Deploy infrastructure only](../agent-landing-zone/deploy-infra-only.md)
or [Deploy the full stack](../agent-landing-zone/deploy-full-stack.md). Those
runbooks describe the Bicep/`azd` workflow, including application configuration,
identity and image preparation. A Terraform apply is not an application
deployment.

## Choose an example

The implementation lives in its own repository, not in a `terraform` directory
of the documentation or Agent Landing Zone repository.

| Example | Purpose |
| --- | --- |
| [Standalone](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/tree/main/examples/standalone) | Foundation without an existing platform landing zone. |
| [Default](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/tree/main/examples/default) | Demonstrates platform integration with an example hub. It creates demonstration hub resources too. |
| [Standalone with an existing VNet](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/tree/main/examples/standalone-byo-vnet) | Starting point for a standalone foundation using an existing virtual network. |
| [Default with an existing VNet](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/tree/main/examples/default-byo-vnet) | Starting point for platform integration using an existing virtual network. |

!!! warning "Examples require a security and cost review"
    The examples are test configurations, not production-ready security policies.
    For example, the standalone example includes test-runner public Key Vault
    access, some disabled diagnostic settings and purge-on-destroy settings.
    Review the actual source before applying it. Adapt networking, data
    protection and monitoring to your requirements rather than copying those
    settings into production.

## Prepare the deployment

You need:

- [Terraform](https://developer.hashicorp.com/terraform/install) matching the
  selected example's `required_version` constraint.
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), an Azure
  subscription and quota for the services and models you select.
- Resource creation permissions at the intended deployment scope. If the
  configuration creates role assignments, the deployment identity also needs
  the appropriate role-assignment permissions. Contributor alone cannot create
  role assignments.
- A runner that can reach the required private data-plane endpoints.
- An approved state-storage and recovery plan before creating resources.

For interactive use, authenticate and confirm the subscription:

```powershell
az login
az account set --subscription "<subscription-id>"
az account show --query "{subscription:id, tenant:tenantId}" --output table
$env:ARM_SUBSCRIPTION_ID = "<subscription-id>"
```

For automation, prefer your runner's supported managed identity or federated
identity configuration. Follow the
[AzureRM provider authentication guidance](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
for the selected method. Do not put client secrets in `.tf` files, shell
history or persistent user environment variables.

Clone the implementation and open the example you reviewed:

```powershell
git clone https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone.git
Set-Location terraform-azurerm-avm-ptn-aiml-landing-zone
Set-Location examples\standalone
terraform version
```

Inspect `main.tf`, `variables.tf` and the example README. Confirm the region,
names, models, network access, backing services and all enabled add-ons.
Some example settings are literal values in `main.tf`; setting an unrelated
variable will not override them. Use the selected module's
[input definitions](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/blob/main/variables.tf)
when creating your own root configuration.

## Protect Terraform state

State and saved plans can contain secrets and sensitive resource details.
Do not commit them or share unredacted `terraform show` output. Keep state
encrypted, access-controlled, backed up and separate for each environment.

For team use, configure an approved
[Azure Storage backend](https://developer.hashicorp.com/terraform/language/backend/azurerm)
before the first `terraform init`, using identity-based authentication and state
locking. Grant only the required backend data access. If resources already
exist, plan state migration explicitly; do not initialize a new empty backend
and apply against the same resources.

## Validate, plan and apply

Run these commands from the selected example or your reviewed root module:

```powershell
terraform init
terraform validate
terraform plan -out=deployment.tfplan
terraform show deployment.tfplan
```

Review additions, updates and deletions, including provider registration,
role assignments, public access and recurring charges. Commit the reviewed
dependency lock file according to your repository policy. Do not use
`terraform init -upgrade` as a generic repair for authentication or network
failures.

Apply only the approved plan:

```powershell
terraform apply deployment.tfplan
```

Applying a saved plan does not ask for another approval. Protect it and use your
normal approval process before this command. If configuration or the environment
has changed since planning, create and review a new plan.

## Verify the foundation

1. Confirm Terraform reports a successful apply.
2. Inspect resources in the **actual resource group named in your configuration
   or plan**, not a fixed example name:

    ```powershell
    az resource list --resource-group "<resource-group>" --output table
    ```

3. Verify private DNS, network access and identities from the intended runner
   and application network. Resource existence does not prove data-plane access.
4. Check the intended Foundry project and model deployments, diagnostic
   settings and data-protection controls.
5. Record the source revision, lock file, reviewed plan and verification
   results without exposing sensitive values.

## Diagnose common failures

| Symptom | Diagnosis and corrective action | Verify |
| --- | --- | --- |
| Authentication fails or the subscription is missing | Identify whether Terraform uses Azure CLI, managed identity or federation. Confirm the tenant/subscription for that method; an interactive `az login` does not repair an unrelated CI identity. | Re-run `terraform plan` with the intended identity. |
| `AuthorizationFailed` while assigning a role | Check the denied action and exact scope. Ask an authorized administrator for the minimum required permission, not blanket Owner access. | Retry the plan/apply after propagation and inspect the intended assignment. |
| Resource provider is not registered | Inspect the provider named in the error. Have an authorized identity register only the required provider and wait for `Registered`. | Query `az provider show --namespace "<namespace>" --query registrationState`. |
| Quota or model availability blocks creation | Compare the selected region, model and SKU with current availability and subscription quota. Request capacity or deliberately revise the design. | Review a new plan before applying a region or model change. |
| Key Vault or another private endpoint returns a connection error | Check runner DNS, routes, TLS and data-plane permissions separately. Move to an approved connected runner; do not enable public access just to pass the deployment. | Test the endpoint from the actual runner and retry the failed operation. |
| `A resource with the ID ... already exists` | Determine who owns the resource and which state manages it. Use a reviewed import or a deliberately different resource identity where appropriate. Do not delete it blindly. | Review the resulting plan for unintended replacement or deletion. |
| Module/provider download fails | Check the reported registry URL, proxy and egress rules. Preserve the state and lock file while investigating. | Re-run `terraform init` without a speculative provider upgrade. |

## Changes and retirement

Treat configuration changes as reviewed plans. Changing a region or a resource
name may replace resources and lose data; it is not an in-place migration
procedure.

Before retiring a foundation, confirm ownership, backups, retention obligations
and dependent applications. Inspect the example's purge settings and keep the
state backend available for recovery.

```powershell
terraform plan -destroy -out=retirement.tfplan
terraform show retirement.tfplan
```

Only after the deletion plan is explicitly approved:

```powershell
terraform apply retirement.tfplan
```

Do not run deletion to repair a failed apply, and do not remove shared resources
or the state backend as incidental cleanup. Follow the module repository's
[README](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/blob/main/README.md)
for implementation-specific requirements.
