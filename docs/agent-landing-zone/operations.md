# Operations

This page covers day-2 tasks for a running Agent Landing Zone environment: upgrades, redeployments, identity and roles, monitoring, and routine runbooks.

!!! note "Repository names"
    The repositories were renamed. GitHub redirects the old URLs, but update existing clones so tooling and scripts use the current names:

    | Previous name | Current name |
    | --- | --- |
    | `Azure/GPT-RAG` | `Azure/agent-landing-zone` |
    | `Azure/gpt-rag-ui` | `Azure/agent-app-ui` |
    | `Azure/gpt-rag-orchestrator` | `Azure/agent-app-orchestrator` |
    | `Azure/gpt-rag-ingestion` | `Azure/agent-app-ingestion` |

    ```bash
    git remote set-url origin https://github.com/Azure/agent-landing-zone.git
    ```

## Upgrade to a new release

Each release pins a validated combination of infrastructure and application components in `manifest.json`. Upgrade by moving the whole environment to a new release tag, not by upgrading components individually.

1. Read the release notes for the target version on the [releases page](https://github.com/Azure/agent-landing-zone/releases). Check the **Component versions** table and any breaking changes.
2. Check out the release tag in your clone:

    ```bash
    git fetch --tags
    git checkout vX.Y.Z
    ```

3. Select the environment and run the full workflow:

    ```bash
    azd env select <environment>
    azd up
    ```

    `azd up` re-runs provisioning (idempotent for unchanged resources), post-provision configuration, and the deployment of every pinned component.

!!! warning "Environments created with GPT-RAG v3"
    Environments created with GPT-RAG v3.x cannot be upgraded in place to Agent Landing Zone v4. Deploy a new environment, then migrate documents, search indexes, and conversation history from the old one. Remove the old environment only after you validate the new one.

## Redeploy applications only

When the infrastructure is unchanged and you only need to push the pinned application components again (for example, after a failed deployment or a configuration change that requires new revisions):

```bash
azd deploy
```

`azd deploy` runs the `predeploy` hook, which validates the environment, checks private connectivity when network isolation is enabled, and deploys each component at the tag and commit pinned in `manifest.json`. Deployment logs for each component are written to `<component>/.logs` in the sibling checkout.

## Identity and roles

Every application uses its own user-assigned managed identity. No keys or connection strings are stored in application settings.

All applications receive these base roles:

| Role | Scope | Purpose |
| --- | --- | --- |
| App Configuration Data Reader | App Configuration store | Read runtime settings |
| AcrPull | Container registry | Pull container images |
| Key Vault Secrets User | Key Vault | Resolve Key Vault references |

Additional roles come from the capability profiles declared for each component. The default application uses these profiles:

| Component | Capability profiles |
| --- | --- |
| Agent App UI | `blob-delegator` |
| Agent App Orchestrator | `model-user`, `retrieval-reader`, `conversation-store` |
| Agent App Ingestion | `model-user`, `conversation-store`, `ingestion-writer` |

For what each profile grants and how to use them in your own application, see [Capability profiles](build-your-own-app.md#capability-profiles).

## Monitoring

Agent Landing Zone sends telemetry to Application Insights and Log Analytics, both deployed with the infrastructure.

- **Application Insights**: requests, dependencies, exceptions, and traces from each component. Use **Transaction search** to follow a single request from the UI through the orchestrator to model and search calls.
- **Log Analytics**: container output and platform events.

UI failure diagnostics intentionally avoid dependency error payloads at application
boundaries. When a record includes `exception_type` and `failure_site`, use its
static operation description, code location and request reference to correlate
the failure with dependency telemetry. Do not interpret missing exception text as
successful processing or enable raw token, cookie, claim or signed-URL logging to
investigate it. A failed optional panel index write still requires repair even
when the chat turn continues; it does not confirm that the index was persisted.

Useful Log Analytics queries:

```kusto
// Recent errors from all container apps
ContainerAppConsoleLogs_CL
| where TimeGenerated > ago(1h)
| where Log_s has_any ("ERROR", "Exception", "Traceback")
| project TimeGenerated, ContainerAppName_s, Log_s
| order by TimeGenerated desc
```

```kusto
// Revision, scaling, and startup events
ContainerAppSystemLogs_CL
| where TimeGenerated > ago(1h)
| project TimeGenerated, ContainerAppName_s, Reason_s, Log_s
| order by TimeGenerated desc
```

## Runbooks

### Check application health

```bash
az containerapp list -g <resource-group> \
  --query "[].{name:name, state:properties.runningStatus, revision:properties.latestReadyRevisionName}" -o table
```

A healthy app shows `Running` and a ready revision. If a revision fails to start, check `ContainerAppSystemLogs_CL` for the reason.

### Stream logs from a container app

```bash
az containerapp logs show -g <resource-group> -n <container-app-name> --follow
```

### Change a runtime setting

Runtime settings live in Azure App Configuration under the label `agent-lz`.

1. Update the key:

    ```bash
    az appconfig kv set --endpoint <app-config-endpoint> --auth-mode login \
      --key <KEY> --value <value> --label agent-lz --yes
    ```

2. Restart the active revision of each affected app so it reads the new value:

    ```bash
    az containerapp revision restart -g <resource-group> -n <container-app-name> \
      --revision <revision-name>
    ```

For the available settings, see [Configuration](configuration.md).

!!! note
    With network isolation enabled, App Configuration is reachable only from the private network. Run these commands from a VPN- or VNet-connected host.

### Rotate a secret

Secrets are stored in Key Vault and referenced from App Configuration. To rotate one, add a new version of the Key Vault secret, then restart the revisions of the apps that use it. No App Configuration change is needed because the reference points to the secret, not to a specific version.

### Roll back to a previous release

Roll back by redeploying the previous validated combination:

```bash
git checkout v<previous-version>
azd deploy
```

If the newer release changed infrastructure, run `azd up` instead so that provisioning, configuration, and application deployment stay consistent with the older pins. Check the release notes for changes that cannot be reverted, such as data migrations.

### Complete a deferred post-provision

When post-provision configuration was deferred (for example, provisioning ran from a host without private network access), the environment is not fully configured. From a VPN- or VNet-connected host, run:

```bash
azd hooks run postprovision
```

See [Post-provision can be deferred](network-isolation.md#post-provision-can-be-deferred).

### Remove an environment

```bash
azd down --purge
```

`--purge` also permanently deletes soft-deleted resources such as Key Vault and Azure AI services accounts, so their names can be reused. Export any data you want to keep first.
