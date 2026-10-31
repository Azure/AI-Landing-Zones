# Updates & recovery

Use the existing runbooks for changes to a deployed environment. Choose your
infrastructure provider below and follow the linked procedure, including its
prerequisites, validation and recovery guidance.

| Task | Bicep | Terraform |
| --- | --- | --- |
| Reconfigure the foundation | [Reconfigure](deploy-infra-only.md#reconfigure-the-foundation) | [Reconfigure or recover](deploy-terraform-infra-only.md#reconfigure-or-recover-the-foundation) |
| Reapply a full-stack deployment | [Reapply a reviewed deployment](deploy-full-stack.md#reapply-a-reviewed-deployment) | [Update and recover](deploy-terraform-full-stack.md#update-and-recover) |
| Redeploy applications only | [Redeploy applications](deploy-full-stack.md#redeploy-applications-only) | [Application-only changes](deploy-terraform-full-stack.md#update-and-recover) |
| Review recovery and rollback | [Rollback](deploy-full-stack.md#rollback) | [Update and recover](deploy-terraform-full-stack.md#update-and-recover) |
| Remove the foundation | [Remove the foundation](deploy-infra-only.md#remove-the-foundation) | [Remove the foundation](deploy-terraform-infra-only.md#remove-the-foundation) |
| Remove a full-stack environment | [Remove an environment](deploy-full-stack.md#remove-an-environment) | [Remove the environment](deploy-terraform-full-stack.md#remove-the-environment) |

For failures, use [Troubleshooting](troubleshooting.md). For application
settings, administration and monitoring, use
[Agent Application operations](application.md#operations).
