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

## How parity is tracked

The `infra-terraform-parity.yml` workflow is designed to open a draft handoff
containing Bicep changes for Terraform maintainers. It does not translate
templates or prove equivalent behavior. A maintainer must implement, validate
and review the corresponding Terraform changes. Automation can be disabled
and requires approval before publishing a handoff. See
[Terraform parity](../terraform-parity.md) for the current status.

## Using Terraform for the infrastructure

The AI Landing Zone Terraform implementation can provision its infrastructure,
but it is not a supported end-to-end Agent Landing Zone deployment path.
There is no validated procedure here for importing its outputs, running
Agent Landing Zone post-provision configuration and deploying the application.
Populating an azd environment with endpoint values alone does not establish
the required application binding, identities, permissions or hosted image handoff.

If you need a supported path today, use Bicep:

- [Deploy full stack](deploy-full-stack.md)
- [Deploy infra only](deploy-infra-only.md)

## Reference

- [Terraform implementation](../terraform/index.md)
- [Terraform parity](../terraform-parity.md)
- [Terraform module](https://aka.ms/ailz/terraform)
