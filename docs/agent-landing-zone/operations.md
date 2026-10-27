---
search:
  exclude: true
---

<span id="lifecycle-guidance-has-moved"></span>

# Operations

Use the task-specific runbook for operational changes and recovery:

- [Reapply a reviewed deployment](deploy-full-stack.md#upgrade-to-a-new-release), [redeploy applications](deploy-full-stack.md#redeploy-applications-only), [change runtime settings](deploy-full-stack.md#change-a-runtime-setting) and [rotate secrets](deploy-full-stack.md#rotate-a-secret) in the Deploy full stack runbook.
- [Rollback](deploy-full-stack.md#roll-back-to-a-previous-release) and [safe environment removal](deploy-full-stack.md#remove-an-environment).
- [Reconfigure the foundation](deploy-infra-only.md#reconfigure-or-upgrade-the-foundation) and [complete deferred configuration](deploy-infra-only.md#complete-a-deferred-post-provision).
- [Identity and capability profiles](build-your-own-app.md#capability-profiles), [hosted runtime access](hosted-agents.md#bootstrap-the-agents-runtime-access), and [health, logs and recovery](troubleshooting.md).

Run lifecycle commands from the platform root with the intended azd environment
selected. Record the deployed revision and approved inputs before changing them.
Environment removal is a separate destructive task, not a rollback procedure.

For the [multi-resource-group path available from v4.4.0](configuration.md#resource-group-destinations),
preserve the approved destination mapping on retries and inventory every target
before cleanup. A `predown` safety hook blocks `azd down` when the destinations
span distinct groups; no automatic deletion or bypass option is provided. Use separately
authorized, itemized manual cleanup after owner review, preserving shared
resources and required data. Created additional groups do not have an
`azd-env-name` tag. Single-group teardown remains unchanged. No automatic
resource migration, permission elevation or destructive group rollback is provided.

<span id="upgrade-ingestion-selection-to-v430"></span>
<span id="change-ingestion-selection-safely"></span>
For ingestion selection and safe retirement, see [Ingestion](ingestion.md).
For private-link and shared-source controls, see
[Network isolation](network-isolation.md#private-native-blob-ingestion) and
[permission options](configuration.md#explicit-shared-source-permission-options).
