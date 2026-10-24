# Terraform templates

The AI Landing Zone Terraform module provides Azure infrastructure modules
and example deployments. Its deployment strategy is under review. It is not
the standard deployment workflow for the Agent Application.

The Agent Landing Zone runbooks use **Bicep** for Azure infrastructure
definitions and the **Azure Developer CLI (`azd`)** to coordinate deployment.
They also configure services and prepare the hosted agent image. Terraform
does not run this application lifecycle.

The [Terraform infrastructure reference](../terraform/index.md) covers the
module, examples and state management. The
[Deploy full stack](deploy-full-stack.md) runbook deploys the supplied
Agent Application.
