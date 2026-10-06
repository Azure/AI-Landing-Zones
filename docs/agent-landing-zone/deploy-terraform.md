# Terraform platform

The automated Agent Landing Zone path (`azd up`) uses the Bicep platform. If your organization standardizes on Terraform, you can deploy the AI Landing Zone platform with Terraform and then run the applications on it.

!!! note
    This path is not automated by `azd`. Expect manual steps.

## Deploy the platform

Use the AI Landing Zone Terraform module: [aka.ms/ailz/terraform](https://aka.ms/ailz/terraform). See also:

- [Terraform](../terraform/index.md)
- [Terraform parity](../terraform-parity.md) for differences from the Bicep pattern.

## Run the applications on it

1. Deploy the Terraform platform with the same services the Bicep platform provides: Azure AI Foundry, Azure AI Search, Cosmos DB, Storage, Key Vault, App Configuration, Container Registry and a Container Apps environment.
2. Create an `azd` environment in the Agent Landing Zone repository and set the variables that point to the existing resources, matching the [platform outputs](deploy-infra-only.md#platform-outputs).
3. Grant the application identities the roles they need. See [Role assignments](operations.md#role-assignments-classic-topology).
4. Run the post-provision configuration (`scripts/postProvision`) so App Configuration is populated.
5. Run `azd deploy`.

If the platform outputs are missing, `azd deploy` stops with the foundation-missing error. See [Troubleshooting](troubleshooting.md).
