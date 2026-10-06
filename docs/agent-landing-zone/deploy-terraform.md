# Terraform implementation status

Agent Landing Zone deploys with Bicep through `azd`. A Terraform implementation
of the same infrastructure exists in AI Landing Zone, but the Agent Landing
Zone deployment flow does not use it yet.

## What is available today

| Area | Bicep | Terraform |
| --- | --- | --- |
| Infrastructure | Supported through `azd up` and `azd provision` | Available as the AI Landing Zone Terraform implementation |
| Post-provision configuration (roles, App Configuration, Search, Foundry) | Runs automatically | Not wired |
| Application deploy | `azd deploy` | Not validated |

## How parity is kept

The Bicep and Terraform implementations are kept at the same infrastructure
level through automated synchronization followed by human review. The
`infra-terraform-parity.yml` workflow reports differences, and maintainers
review each change before it is merged. See
[Terraform parity](../terraform-parity.md) for the current status.

## Using Terraform for the infrastructure

You can deploy the infrastructure with the AI Landing Zone Terraform
implementation and then deploy the applications yourself. This path is not
validated. You must provide the same outputs that the Bicep deployment
publishes, run the post-provision configuration, and run `azd deploy` against
an environment that contains those values. Expect to debug missing settings.

If you need a supported path today, use Bicep:

- [Deploy full stack](deploy-full-stack.md)
- [Deploy infra only](deploy-infra-only.md)

## Reference

- [Terraform implementation](../terraform/index.md)
- [Terraform parity](../terraform-parity.md)
- [Terraform module](https://aka.ms/ailz/terraform)
