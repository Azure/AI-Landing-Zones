---
search:
  exclude: true
---

# Lifecycle guidance has moved

This address is retained for existing links. Deployment and maintenance procedures
now live with the deployment they affect:

- [Upgrade](deploy-full-stack.md#upgrade-to-a-new-release), [redeploy applications](deploy-full-stack.md#redeploy-applications-only), [change runtime settings](deploy-full-stack.md#change-a-runtime-setting) and [rotate secrets](deploy-full-stack.md#rotate-a-secret).
- [Rollback](deploy-full-stack.md#roll-back-to-a-previous-release) and [safe environment removal](deploy-full-stack.md#remove-an-environment).
- [Reconfigure the foundation](deploy-infra-only.md#reconfigure-or-upgrade-the-foundation) and [complete deferred configuration](deploy-infra-only.md#complete-a-deferred-post-provision).
- [Identity and capability profiles](build-your-own-app.md#capability-profiles), [hosted runtime access](hosted-agents.md#bootstrap-the-agents-runtime-access), and [health, logs and recovery](troubleshooting.md).

<span id="upgrade-ingestion-selection-to-v430"></span>
<span id="change-ingestion-selection-safely"></span>
For ingestion selection, older-UI compatibility and safe retirement, see
[Ingestion and conversation uploads](ingestion.md#upgrade-and-retirement-safety).
For private-link and shared-source controls, see
[Network isolation](network-isolation.md#private-native-blob-ingestion) and
[permission options](configuration.md#explicit-shared-source-permission-options).
