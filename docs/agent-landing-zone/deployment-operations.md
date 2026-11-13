# Updates & recovery

Use the existing deployment guides for changes to a deployed environment. Choose your
infrastructure provider below and follow the linked procedure, including its
prerequisites, validation and recovery guidance.

`azd init --template Azure/agent-landing-zone .` is for a new local project,
not an update or recovery command. For an existing installation, keep its
reviewed source, select the existing environment with
`azd env select <environment-name>` and preserve provider, inputs and private
deployment records. A clean replacement runner must restore that same
revision and the records required by the linked recovery procedure.

| Task | Bicep | Terraform |
| --- | --- | --- |
| Review infrastructure changes | [Review changes](deploy-infra-only.md#review-infrastructure-changes) | [Review or recover](deploy-terraform-infra-only.md#reconfigure-or-recover-the-foundation) |
| Retry a full-stack installation | [Retry the same installation](deploy-full-stack.md#retry-the-same-installation) | [Retry and recover](deploy-terraform-full-stack.md#update-and-recover) |
| Redeploy applications only | [Redeploy applications](deploy-full-stack.md#redeploy-applications-only) | [Application-only changes](deploy-terraform-full-stack.md#update-and-recover) |
| Add MCP server or select NL2SQL tools | [Select, provision and deploy](agent-app-mcp.md#add-to-an-existing-installation) | [Select, provision and deploy](agent-app-mcp.md#add-to-an-existing-installation) |
| Review component outbound access | [Read-only review](deploy-infra-only.md#review-component-egress) | [Provisioning review](deploy-terraform-infra-only.md#step-5-review-and-provision) |
| Review recovery and rollback | [Rollback](deploy-full-stack.md#rollback) | [Update and recover](deploy-terraform-full-stack.md#update-and-recover) |
| Remove the foundation | [Remove the foundation](deploy-infra-only.md#remove-the-foundation) | [Remove the foundation](deploy-terraform-infra-only.md#remove-the-foundation) |
| Remove a full-stack environment | [Remove an environment](deploy-full-stack.md#remove-an-environment) | [Remove the environment](deploy-terraform-full-stack.md#remove-the-environment) |

For failures, use [Troubleshooting](troubleshooting.md). For application
settings, administration and monitoring, use
[Agent Application operations](application.md#operations).

For outbound-access changes, retain the
[policy ownership and subnet boundaries](configuration.md#outbound-access).
Remove owned rules with the current reconciliation workflow
[before reverting hooks](deploy-full-stack.md#outbound-rule-recovery).

For MCP, server compute and startup toolset selection are separate.
`MCP_TOOLSETS=[]` registers zero tools; `["nl2sql"]` needs its declared
catalog/model dependencies, SQL-owner approvals and active metadata version.
Provision matching dependencies and restart/redeploy after toolset changes.

Deselection stops initialization but does not delete retained catalog data or
automatically revoke old grants. Review retirement explicitly; recovery does not run direct SQL
inside the orchestrator. Embedding model/dimension changes need reindexing,
not just a runtime-setting refresh.

## Verify deployment metadata

From the reviewed platform checkout, run:

```bash
python -m config.deployment.metadata --check --environment <environment-name>
```

This read-only resource check loads native `DEPLOYMENT_METADATA` and verifies
the selected context, declared capabilities, live destinations and identities.
It does not publish runtime settings or complete deferred configuration.
Bicep reads the selected successful deployment. Terraform requires the
original initialized native working directory and backend configuration, and
rejects backend changes without reconfiguration or state migration.

For stale cached metadata or overlapping aliases, restore the intended
selection and refresh:

```bash
azd env refresh --environment <environment-name>
python -m config.deployment.metadata --check --environment <environment-name>
```

If the output is missing or incompatible, use a compatible platform checkout
and reprovision with the same provider, original root inputs, application/group
bindings and, for Terraform, original backend. Refresh cannot create a missing
output or reconstruct private binding records.

Repair missing ARM/output/identity read permissions, existing backend access or
private DNS/TLS connectivity without broadening runtime roles or guessing
destinations. Retain the selected operation's actual configuration and Key
Vault permissions. Metadata rejection precedes dependent changes.

Keep hooks and provider outputs from a compatible platform revision.
Do not roll a store-free environment back to store-dependent hooks. Recovery
does not delete an existing store or convert an application's runtime mode in
place. See [runtime configuration mode](configuration.md#runtime-configuration-mode).

## PostgreSQL data protection

[Optional PostgreSQL recovery/removal](postgresql.md#protection-recovery-and-deliberate-removal)
requires the original immutable creation-intent record and independent server
CanNotDelete lock outside both provider graphs/state. Same-binding protection
recovery is supported; missing/corrupt records are not adoption/deletion permission.
Down/disable/replacement stop before either provider teardown. Manual removal
needs backup/PITR review, exact inventory, consumer shutdown, data-owner approval
and state/discovery reconciliation; preserve shared DNS/RGs. Privileged bypass
and the partial-provision window remain risks. SQL bootstrap is manual and
restartable across two databases, not cross-database atomic.
