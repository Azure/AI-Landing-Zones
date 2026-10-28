---
search:
  exclude: true
---

<span id="lifecycle-guidance-has-moved"></span>

# Operations

Use the task-specific runbook for operational changes and recovery:

- For integrated Terraform, use [foundation reconfiguration and recovery](deploy-terraform-infra-only.md#reconfigure-or-recover-the-foundation),
  [application updates](deploy-terraform-full-stack.md#update-and-recover) and
  [removal](deploy-terraform-infra-only.md#remove-the-foundation). Retain the
  provider and backend and follow the
  [single-writer execution policy](deploy-terraform-infra-only.md#state-protection).
- [Reapply a reviewed deployment](deploy-full-stack.md#upgrade-to-a-new-release), [redeploy applications](deploy-full-stack.md#redeploy-applications-only), [change runtime settings](deploy-full-stack.md#change-a-runtime-setting) and [rotate secrets](deploy-full-stack.md#rotate-a-secret) in the Deploy full stack runbook.
- [Rollback](deploy-full-stack.md#roll-back-to-a-previous-release) and [safe environment removal](deploy-full-stack.md#remove-an-environment).
- [Reconfigure the foundation](deploy-infra-only.md#reconfigure-or-upgrade-the-foundation) and [complete deferred configuration](deploy-infra-only.md#complete-a-deferred-post-provision).
- [Identity and capability profiles](build-your-own-app.md#capability-profiles), [hosted runtime access](hosted-agents.md#bootstrap-the-agents-runtime-access), and [health, logs and recovery](troubleshooting.md).

Run lifecycle commands from the platform root with the intended azd environment
selected. Record the deployed revision and approved inputs before changing them.
Environment removal is a separate destructive task, not a rollback procedure.

For [multi-resource-group deployments](configuration.md#resource-group-destinations),
preserve the approved destination mapping on retries and inventory every target
before cleanup. A `predown` safety hook blocks `azd down` when the destinations
span distinct groups **for Bicep**.

For Terraform, preserve the original common group/application bindings,
`terraform-resource-groups.json` and `terraform-backend.json` on every runner.
The guard verifies those records before native state-scoped destroy across
recorded owned/BYO groups; it does not perform imperative group deletion.
Follow [Terraform removal](deploy-terraform-infra-only.md#remove-the-foundation)
for preview and explicit destruction.

Where automatic removal is blocked, use separately authorized, itemized
cleanup after owner review, preserving shared resources and required data.

<span id="upgrade-ingestion-selection-to-v430"></span>
<span id="change-ingestion-selection-safely"></span>
For ingestion selection and safe retirement, see [Ingestion](ingestion.md).
For private-link and shared-source controls, see
[Network isolation](network-isolation.md#private-native-blob-ingestion) and
[permission options](configuration.md#explicit-shared-source-permission-options).
