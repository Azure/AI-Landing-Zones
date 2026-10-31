---
search:
  exclude: true
---

# Deploy with Azure DevOps

Use the maintained [Agent Landing Zone Azure DevOps deployment guide](../agent-landing-zone/azure-devops.md)
for runner prerequisites, federated service connections, protected
Environments, stage-specific inputs and source promotion.

The foundation is maintained in
[Azure/agent-landing-zone under `infra/bicep/`](https://github.com/Azure/agent-landing-zone/tree/main/infra/bicep).
Pipeline jobs must retain the platform files and execute lifecycle commands
from the repository root. Do not use a separate foundation checkout or assume
its pipeline paths and lifecycle are interchangeable with the platform.

For infrastructure-only automation, apply the
[infrastructure guide](../agent-landing-zone/deploy-infra-only.md)
with the same reviewed platform revision, parameters, identity and connected
runner requirements. Review the selected application's egress plan, run
`azd hooks run preup`, and use the root `azd provision` lifecycle; omit
application image preparation and deployment. This still runs service
configuration unless explicitly deferred.

For interactive deployment, use
[Deploy infrastructure only](../agent-landing-zone/deploy-infra-only.md)
or [Deploy the full stack](../agent-landing-zone/deploy-full-stack.md).
