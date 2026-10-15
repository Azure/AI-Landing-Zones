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

Each release pins a compatible combination of infrastructure and application
components in `manifest.json`. Upgrade the environment as a whole, not by
upgrading components independently. The `infra.source` entry records upstream
provenance, not a separately checked-out infrastructure dependency. Use the
release's repository-owned `infra/` tree, including its platform changes.

1. Read the release notes for the target version on the [releases page](https://github.com/Azure/agent-landing-zone/releases). Check the **Component versions** table and any breaking changes.
2. Check out the release tag in your clone:

    ```bash
    git fetch --tags
    git checkout vX.Y.Z
    ```

3. Select the environment and run the workflow for its topology. For classic:

    ```bash
    azd env select <environment>
    azd up
    ```

    `azd up` runs provisioning, post-provision configuration and deployment
    of the selected components. Review configuration and data reconciliation
    before treating any upgrade as a no-op. Private environments require a
    connected runner, including when existing topology is read from private
    App Configuration.

    For hosted deployments, a generated image from a different orchestrator
    source pin must be prepared again. Run the preparation script, provision
    the new immutable handoff, then deploy. If the foundation is not yet
    provisioned, provision it before preparation. Follow
    [Hosted deployment and redeployment](hosted-agents.md#deploy-with-a-hosted-topology).
    A single `azd up` does not build a missing hosted image or repair a stale
    generated-image handoff. If the image and provisioned handoff remain
    compatible, the normal full workflow can reuse them.

4. Verify the intended revisions and routed hosted version, authentication,
   retrieval, document allow/deny behavior and any ingestion or history
   features you rely on. A successful hook or greeting is not that acceptance
   test. The v4.3.0 release records offline validation, not new Azure
   deployment or live-environment validation.

!!! warning "Environments created with GPT-RAG v3"
    Environments created with GPT-RAG v3.x cannot be upgraded in place to Agent Landing Zone v4. Deploy a new environment, then migrate documents, search indexes, and conversation history from the old one. Remove the old environment only after you validate the new one.

## Redeploy applications only

When provisioning and post-provision configuration are complete and their
outputs, component selection and image handoff are still compatible, redeploy
the applications from the platform repository root:

```bash
azd deploy
```

`azd deploy` runs the `predeploy` hook, which checks the foundation and
application binding, validates topology, checks private reachability when
isolation is enabled, and deploys the selected components. Bundled Container
App components use the manifest's tag and commit in sibling checkouts. Their
child deployment logs are written to `<component>/.logs`.

Hosted orchestration reuses the prepared digest. It does not build a new
orchestrator image during `azd deploy`. For a changed source pin or image,
follow [same-image and new-image redeployment](hosted-agents.md#redeploy-the-same-image-or-prepare-a-new-one).
Custom components use their selected definition's source pins, not an
assumed manifest entry. Do not use application-only deployment to apply
infrastructure, RBAC, topology or ingestion-selection changes.

An infrastructure-only environment may already contain Container Apps with
placeholder images. `azd provision` and post-provision configuration do not
run the pinned applications. Classic applications can be deployed once that
foundation is configured. Hosted applications additionally need digest
preparation and a second provision before deployment.
If using a custom application, select its definition before the first
provision so binding, resource planning and later deployment agree. Selecting
it only before the first deploy is too late for an already-bound environment.

## Change ingestion selection safely

### Upgrade ingestion selection to v4.3.0

This migration targets Agent Landing Zone **v4.3.0** with **agent-app-ui
v3.3.0**. Use the complete
[component combination](index.md#v430-component-combination), not an
independently upgraded UI or a locally edited configuration key.

1. Confirm that the selected platform v4.3.0 release
   manifest pins UI v3.3.0 at its exact tag and commit. Compare the platform changelog
   and GitHub Release **Component versions** table with that manifest for
   the entire combination, including infrastructure provenance. Do not
   activate ingestion-free operation with only a locally changed key.
2. Record and retain the existing ingestion selection during the upgrade.
   On the older v4.2.3 / UI v3.2.2 combination, explicitly retain `true`.
   That UI does not enforce the upload gate.
3. Upgrade the whole pinned platform combination using the selected
   topology's full workflow. Verify that App Configuration publishes the
   effective `DEPLOY_INGESTION_CONTAINER_APP` value under label `agent-lz`
   and that the UI consumes it.
4. Only then opt out if source/index bindings and ingestion requirements
   support it, following the selection and validation steps below. Verify
   that attachment controls are hidden and stale/direct uploads are
   rejected, while text chat, authentication and retrieval still work.
   Native source ingestion does not implement conversation uploads.

For rollback to UI v3.2.2, restore the explicit ingestion selection to
`true` and its required application endpoint/source configuration **before**
restoring the older platform-pinned combination. Revalidate the full
workflow and upload eligibility. Do not downgrade the UI while leaving an
ingestion-free configuration or assume a missing endpoint disables uploads.
Resource retirement and permission cleanup remain separately authorized
operations. Rollback must not delete documents or indexes.

### Select and validate the ingestion path

Fresh environments default to `DEPLOY_INGESTION_CONTAINER_APP=false`, but an
upgrade must retain an existing environment's ingestion selection. Absence
of the new variable is not permission to remove an existing component.
Explicit custom definitions retain their component intent.

Before opting out of the bundled ingestion app, record the current selection,
retrieval backend, configured source kind, source/index bindings and any
application-managed ingestion dependencies. Confirm that supported native
Foundry IQ ingestion covers your requirements. It is not feature-equivalent
to the optional application. Export or back up relevant configuration and
data before migration.

In the v4.3.0 / UI v3.3.0 contract,
`false` disables controls and server/client upload paths while retaining chat,
authentication and retrieval. Missing flags retain legacy behavior and `true`
retains existing upload eligibility checks. On v4.2.3 / UI v3.2.2, retain
explicit `true` until the versioned migration above is complete.

Make the selection explicit before provisioning:

```bash
azd env set DEPLOY_INGESTION_CONTAINER_APP false
```

Opt-out is supported for `foundry_iq` with the native `azureBlob` pattern
and source kind. For `ai_search`, or `foundry_iq` with both pattern and kind
set to `searchIndex`, supply `SEARCH_RAG_INDEX_NAME` explicitly and populate
that index through an independent ingestion pipeline. The switch does not
create that pipeline, infer an index, change a backend or rewrite source
bindings. Unsupported source combinations and
`FOUNDRY_IQ_CONVERSATION_UPLOAD_ENABLED=true` fail validation with opt-out.
Retain the app when its ingestion or conversation-upload path is required.

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
reconciliation. It does not delete a deployed app or revoke its existing
identity/RBAC. Any resource retirement or permission cleanup is a separate,
deliberately authorized operation. To roll back,
restore the previous explicit selection and source/index configuration, then
rerun the matching deployment workflow and revalidate. Enabling the app alone
does not change a retrieval backend or repair source bindings.

## Private ingestion and shared-source recovery

Native `azureBlob` source configuration must wait for its required
Search-managed outbound shared private links. This guarded implementation
does not automatically approve target requests. Pending links stop
immediately with the exact deployment Search service, link name, target
resource and expected group. Use an authorized administrator to investigate
and approve that exact request. Never approve all pending requests.
Approved source links use bounded readiness polling. Denied Search read
permissions or a timeout require operator recovery, not bypassing the gate. See
[Private native Blob ingestion](network-isolation.md#private-native-blob-ingestion).

Configuration checks readiness before dependent Search cleanup/mutation and
again before native source creation. Recovery is idempotent: after an
administrator approves the exact target connection, rerun configuration.
Only the exact source Search links are read, with no target PEC enumeration
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
or actual null preserves `["rbacScope"]`. Textual `null` and other invalid
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

Provisioned Container Apps use separate user-assigned managed identities
by default. Secrets such as OAuth client credentials belong in Key Vault,
referenced from App Configuration, not literal application settings. The
platform also supports optional API-key paths, so do not assume that every
deployment is secret-free.

The application capability catalog includes these implicit base roles:

| Role | Scope | Purpose |
| --- | --- | --- |
| App Configuration Data Reader | App Configuration store | Read runtime settings |
| AcrPull | Container registry | Pull container images |
| Key Vault Secrets User | Key Vault | Resolve Key Vault references |

Additional roles come from the capability profiles declared for each
component. The bundled definition declares the profiles below. Effective
grants also depend on the topology and deployed resources, so this is not
a promise of identical grants in classic and hosted modes.

| Component | Capability profiles |
| --- | --- |
| Agent App UI | `blob-delegator` |
| Agent App Orchestrator | `model-user`, `retrieval-reader`, `conversation-store` |
| Agent App Ingestion (when selected) | `model-user`, `conversation-store`, `ingestion-writer` |

For what each profile grants and how to use them in your own application, see [Capability profiles](build-your-own-app.md#capability-profiles).

The bundled hosted orchestrator uses a separate, discovered runtime
principal and the narrower [hosted bootstrap plan](hosted-agents.md#bootstrap-the-agents-runtime-access).
Its project identity's registry pull role is a foundation prerequisite,
not a replacement for runtime grants. Continuity and panel permissions are
feature-owned and reconciled separately. A deployment principal's ability
to assign roles does not prove that a delegated user can call the agent or
retrieve a protected document.

## Monitoring

Agent Landing Zone sends telemetry to Application Insights and Log Analytics, both deployed with the infrastructure.

- **Application Insights**: requests, dependencies, exceptions, and traces from each component. Use **Transaction search** to follow a single request from the UI through the orchestrator to model and search calls.
- **Log Analytics**: container output and platform events.

The Container Apps queries and commands below cover Container Apps, not
the Foundry hosted orchestrator. Inspect the routed agent version and its
Foundry runtime logs separately. Telemetry content capture is a separate,
default-off privacy choice, not a requirement for a successful chat.

UI failure diagnostics intentionally avoid dependency error payloads at application
boundaries. When a record includes `exception_type` and `failure_site`, use its
static operation description, code location and request reference to correlate
the failure with dependency telemetry. Do not interpret missing exception text as
successful processing or enable raw token, cookie, claim or signed-URL logging to
investigate it. A failed optional panel index write still requires repair even
when the chat turn continues. It does not confirm that the index was persisted.

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

A healthy app shows `Running` and a ready revision. Also verify the image
and latest intended revision. An older healthy placeholder can still serve
HTTP 200 while the new application revision fails. Check
`ContainerAppSystemLogs_CL` and startup logs for that revision.

### Stream logs from a container app

```bash
az containerapp logs show -g <resource-group> -n <container-app-name> --follow
```

### Change a runtime setting

Post-provision publishes shared runtime settings to Azure App Configuration
under label `agent-lz`. That is not a label-isolation guarantee. Check the
[actual component selectors and overwrite behavior](configuration.md#runtime-settings)
and whether provisioning manages the setting before editing it.
Infrastructure and deployment-selection inputs require their full workflow,
not just a key update or restart.

1. Update the key:

    ```bash
    az appconfig kv set --endpoint <app-config-endpoint> --auth-mode login \
      --key <KEY> --value <value> --label agent-lz --yes
    ```

2. Restart each affected Container App revision so it reads the new value:

    ```bash
    az containerapp revision restart -g <resource-group> -n <container-app-name> \
      --revision <revision-name>
    ```

For a hosted version, use the root `azd deploy` workflow with the existing
compatible image handoff. Process environment values declared in
`hosted-agent/azure.yaml` are immutable version inputs and require deployment
of a new agent version. An App Configuration key cannot substitute for a
process-only setting such as `APP_CONFIG_TLS_COMPATIBILITY`.

For the available settings, see [Configuration](configuration.md).

!!! note
    With network isolation enabled, App Configuration is reachable only from the private network. Run these commands from a VPN- or VNet-connected host.

### Rotate a secret

Secrets are stored in Key Vault and referenced from App Configuration.
Inspect the reference before rotation. An unversioned secret URI resolves
the current version when configuration is reloaded, so no reference change
is needed. A versioned URI must be updated deliberately. Add the new secret
version, retain the required access, then restart the affected Container App
revisions or redeploy the hosted version to reload configuration. Verify
the new credential before retiring the old one.

### Roll back to a previous release

Review the previous release's migration constraints and restore its complete
compatible combination. When only classic application pins changed and
the existing foundation remains compatible, application-only rollback uses:

```bash
git checkout v<previous-version>
azd deploy
```

If infrastructure or configuration changed, rerun the selected topology's
full workflow so provisioning, configuration and applications agree. For
hosted rollback, prepare the previous pinned image or deliberately restore
its verified digest, provision the handoff, then deploy. `azd up` is not a
substitute for that image step. Check the release notes for changes that
cannot be reverted, such as data migrations, and restore ingestion before
downgrading to a UI without the upload gate.

### Complete a deferred post-provision

When post-provision configuration was deferred, the environment is not
fully configured. From a VPN- or VNet-connected host, select the intended
environment, clear the deferral and rerun the hook:

```bash
azd env set RUN_FROM_JUMPBOX true
azd env set AZURE_SKIP_NETWORK_ISOLATION_WARNING false
azd hooks run postprovision
```

See [Post-provision can be deferred](network-isolation.md#post-provision-can-be-deferred).

### Remove an environment

```bash
azd down --purge
```

`--purge` also permanently deletes soft-deleted resources such as Key Vault and Azure AI services accounts, so their names can be reused. Export any data you want to keep first.
