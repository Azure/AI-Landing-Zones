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

    `azd up` re-runs provisioning (idempotent for unchanged resources), post-provision configuration, and the deployment of every selected pinned component.

!!! warning "Environments created with GPT-RAG v3"
    Environments created with GPT-RAG v3.x cannot be upgraded in place to Agent Landing Zone v4. Deploy a new environment, then migrate documents, search indexes, and conversation history from the old one. Remove the old environment only after you validate the new one.

## Redeploy applications only

When the infrastructure is unchanged and you only need to push the pinned application components again (for example, after a failed deployment or a configuration change that requires new revisions):

```bash
azd deploy
```

`azd deploy` runs the `predeploy` hook, which validates the environment, checks private connectivity when network isolation is enabled, and deploys each selected component at the tag and commit pinned in `manifest.json`. Deployment logs for each component are written to `<component>/.logs` in the sibling checkout.

## Change ingestion selection safely

Fresh environments default to `DEPLOY_INGESTION_CONTAINER_APP=false`, but an
upgrade must retain an existing environment's ingestion selection. Absence
of the new variable is not permission to remove an existing component.
Explicit custom definitions retain their component intent.

Before opting out of the bundled ingestion app, record the current selection,
retrieval backend, configured source kind, source/index bindings and any
application-managed ingestion dependencies. Confirm that supported native
Foundry IQ ingestion covers your requirements; it is not feature-equivalent
to the optional application. Export or back up relevant configuration and
data before migration.

With the currently pinned UI v3.2.2, chat attachments still require the
ingestion app and ignore the new flag. A coordinated UI release and validated
umbrella pin update are required **before activating ingestion-free deployments**;
retain explicit `true` until that dependency is integrated. Native source ingestion
does not make the attachment client optional. With the coordinated gate,
`false` disables controls and server/client upload paths while retaining chat,
authentication and retrieval; missing flags retain legacy behavior and `true`
retains existing upload eligibility checks. See the
[runtime compatibility warning](configuration.md#ingestion-application-selection).

Make the selection explicit before provisioning:

```bash
azd env set DEPLOY_INGESTION_CONTAINER_APP false
```

Use `true` to retain or restore the optional app. Run the selected topology's
full [deployment workflow](deploy-full-stack.md#step-4-deploy), not only
`azd deploy`, so provisioning, post-provision reconciliation and application
deployment use the same component selection. For private environments use a
connected runner. Switching classic/hosted orchestration does not select an
ingestion path. Chat/authentication/retrieval are separate from attachment
eligibility.

Validate source processing, retrieval and document authorization before
retiring any old ingestion dependency. Do not delete an existing app,
documents or indexes merely to match the fresh default. Explicit opt-out
excludes the component from subsequent provisioning, deployment and
reconciliation; it does not delete a deployed app or revoke its existing
identity/RBAC. Any resource retirement or permission cleanup is a separate,
deliberately authorized operation. To roll back,
restore the previous explicit selection and source/index configuration, then
rerun the matching deployment workflow and revalidate. Enabling the app alone
does not change a retrieval backend or repair source bindings.

## Private ingestion and shared-source recovery

Native `azureBlob` source configuration must wait for its required
Search-managed outbound shared private links. This guarded implementation
does not automatically approve target requests; pending links stop
immediately with the exact deployment Search service, link name, target
resource and expected group. Use an authorized administrator to investigate
and approve that exact request. Never approve all pending requests.
Approved source links use bounded readiness polling; denied Search read
permissions or a timeout require operator recovery, not bypassing the gate. See
[Private native Blob ingestion](network-isolation.md#private-native-blob-ingestion).

Configuration checks readiness before dependent Search cleanup/mutation and
again before native source creation. Recovery is idempotent: after an
administrator approves the exact target connection, rerun configuration;
only the exact source Search links are read, with no target PEC enumeration
or approval writes or pagination. The readiness budget is 600 seconds with
10-second polling and each ARM request is limited to at most 30 seconds,
bounded by the remaining budget. Each source link must report `Approved` and `Succeeded`, as
[Microsoft documents in section 3](https://learn.microsoft.com/en-us/azure/search/search-indexer-howto-access-private).
Opaque Microsoft-managed endpoint identities or paginated target collections
do not block already-approved sources. This is an ARM readiness check, not
proof of end-to-end network reachability or successful document ingestion.

For active native Blob ingestion,
`FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS=[]` is an explicit shared-source
choice, not a private-link repair. It requires a recognized non-ADLS
`azureBlob` source kind using `foundry_iq` and the `azureBlob` pattern (or
historical `managed` compatibility alias). For `ai_search` with any pattern,
or `foundry_iq` with `searchIndex`, infrastructure-published `[]` is accepted
as unused metadata: no native Blob source is rendered, and no shared-source
opt-in is implied. Active ADLS or mismatched/ambiguous source configuration
still fails closed. Record
the source audience and permission metadata before changing it. Omission
or actual null preserves `["rbacScope"]`; textual `null` and other invalid
input fail closed. Roll back to protected ingestion with `["rbacScope"]`,
rerun source configuration, and verify source/index metadata and document
allow/deny behavior. Do not assume already-ingested documents are protected
merely because the setting has changed. Other sources, Entra ID/OBO, RBAC
and network restrictions must remain unchanged.

Set `ENABLE_FIREWALL_DNS_PROXY=false` and provision to disable the firewall
DNS proxy only after confirming the DNS path does not rely on it. The
default-off opt-in does not rewrite VNet or VPN DNS settings and is independent
of build-feed egress. Reverting a private-link readiness gate does not revoke
approved connections: revocation is a separate, deliberate operator action.

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
| Agent App Ingestion (when selected) | `model-user`, `conversation-store`, `ingestion-writer` |

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
