# Troubleshooting

Start with the **first failing stage and its exact error**, not the last command
that returned success. Provisioning, post-provision configuration, image
preparation, application deployment and runtime access are separate checks.

| What you see | Start here |
| --- | --- |
| Hosted deployment asks for preparation | [Hosted handoff](#hosted-deployment-is-not-prepared) |
| Private endpoint or build-pool failure | [Private prerequisites](#private-deployment-prerequisites-failed), [package installation](#package-installation-fails-inside-the-build-pool) |
| Configuration stops after provisioning | [Post-provision diagnostics](#provision-and-post-provision-stages) |
| Deploy reports success but the application fails | [Revision health](#check-application-health), [startup authentication](#deploy-succeeds-but-the-ui-or-administrative-panel-does-not-start) |
| Chat, history or authorization fails | [Runtime diagnostics](#runtime) |

## Before changing anything

1. Run diagnostics from the platform repository root. Confirm the intended
   environment with `azd env list` and the Azure CLI subscription with
   `az account show`. Verify the identity used by `azd` separately from the
   CLI identity; they need not be the same.
2. Record the failing command, time, stage, source revision and relevant
   non-secret settings, such as `NETWORK_ISOLATION`, `BUILD_MODE` and
   `DEPLOYMENT_TOPOLOGY`.
3. For private environments, use a host with the required VPN/VNet connectivity.
   Inspect DNS, TLS and authorization separately.
4. Preserve local work and data. Do not delete resources, clear bindings,
   disable authentication or bypass preflight to make an error disappear.

Here, `classic` means the orchestrator runs in a **Container App**; hosted
topologies run it in **Foundry Agent Service**. Confirm the selected topology
before following a recovery path.

!!! tip "Share useful, redacted diagnostics"
    Hooks write to the terminal. Bundled Container App component deployments
    also write child logs under `<component>/.logs`. Share the exact error and
    relevant log excerpt, not the full output of `azd env get-values`.
    Remove tokens, cookies, credentials, signed URLs, document contents,
    user identifiers and private environment names.

## Deploy stage

### Hosted deployment is not prepared

**Symptom:** Deployment asks you to run the hosted preparation script or reports
an incomplete image handoff.

**Diagnose:** The first provision creates prerequisites and records
`HOSTED_AGENT_PREPARED=true`. Preparation records an immutable image digest.
A subsequent provision materializes the `DEPLOY_HOSTED_AGENT=true` handoff.
None of these steps alone creates the data-plane agent version.

**Correct:** Follow the hosted sequence in
[Deploy the full stack](deploy-full-stack.md#step-4-deploy) from the first
incomplete step. For an unchanged, compatible image, use the
[redeployment guidance](deploy-full-stack.md#redeploy-applications-only).
Do not set generated output flags manually.

**Verify:** Deployment targets the intended digest and routed agent version.
Then test authenticated task execution and the retrieval/authorization features
you use; a protocol greeting alone is not acceptance.

### Hosted agent deployment returns an agent permission denial

**Symptom:** HTTP 403 names
`Microsoft.CognitiveServices/accounts/AIServices/agents/read`.

**Diagnose:** Compare the denied object ID with the actual deployment principal.
Successful ARM provisioning or a TLS connection does not prove Foundry
data-plane permission.

**Correct:** Have an authorized administrator review the minimum project-scoped
agent authoring role for that principal. A runner creating/updating agents needs
**Foundry User** (formerly **Azure AI User**) or the appropriate equivalent
custom role. Azure AI Developer targets different hub/workspace scenarios.
Allow role propagation before retrying; do not grant resource-group Owner as
a substitute.

**Verify:** The same principal can perform the previously denied operation.
Test delegated-user/OBO access separately.

### Application definition does not match the environment

**Symptom:** `Application definition binding check failed. No changes were made.`
with exit code `2`. An invalid definition instead exits with code `1`.

**Diagnose:** Compare the selected definition's application ID with the existing
`AGENTLZ_APP_ID` binding. A custom hosted component does not automatically require
switching the bundled orchestrator's topology.

**Correct:** Restore the matching definition. For a different application ID,
use a separate environment and select the definition **before first provision**.
Do not delete the binding or switch topology to bypass the mismatch.

**Verify:** Definition validation and binding checks pass for the intended
environment. See [Custom applications](build-your-own-app.md).

### Custom hosted image pull fails with a classic bundled orchestrator

**Symptom:** A custom `azure.ai.agent` service cannot activate its private image,
although Foundry project and registry outputs exist.

**Diagnose:** Check the Foundry **project identity's** registry pull grant and
the exact image/registry. A legacy composition defect omitted hosted foundation
preparation when the bundled orchestrator stayed in a Container App. The
correction shipped in v4.2.3
([PR #779](https://github.com/Azure/agent-landing-zone/pull/779)).

**Correct:** Use the complete corrected platform combination. Preserve the
environment, definition and immutable image, then rerun the
[full-stack provisioning workflow](deploy-full-stack.md#step-4-deploy).
Provisioning applies the declarative pull grant; refreshing outputs alone
cannot. For an external registry, review its supported pull-role mode and
resource scope separately.

**Verify:** Image activation succeeds and the actual runtime principal receives
the declared capabilities. Check the routed version before testing the agent.
Do not enable registry admin credentials, grant broad roles or replace
delegated-user/OBO authentication with a service identity.

### Private deployment prerequisites failed

**Symptom:**

```text
Private deployment prerequisites failed. Use a VPN/VNet-connected host; RUN_FROM_JUMPBOX is not a connectivity bypass.
```

**Diagnose:** With `NETWORK_ISOLATION=true`, the host cannot resolve or establish
TLS to App Configuration, or to the Foundry project endpoint for hosted
topologies. The gate allows up to 20 seconds per endpoint.

**Correct:** Move to the approved jumpbox, VPN or peered-VNet runner and inspect
the [private connectivity path](network-isolation.md#verify-private-connectivity).
`RUN_FROM_JUMPBOX` is not a bypass.

**Verify:** Resolve and reach each required endpoint from that runner, then
retry the failed stage. A reachable endpoint can still reject authorization.

### ACR Task agent pool is missing

**Symptom:**

```text
Run 'azd env set DEPLOY_ACR_TASK_AGENT_POOL true' and 'azd provision', or set BUILD_MODE=local on a VNet-connected host with Docker.
```

**Diagnose:** The private environment has no `ACR_TASK_AGENT_POOL` output and
`BUILD_MODE` is not `local`. This guard also applies to a custom service with
a prebuilt digest.

**Correct:** Select the pool intentionally and run the foundation workflow:

```bash
azd env set DEPLOY_ACR_TASK_AGENT_POOL true
azd provision
```

For supported Container App builds, local Docker on a connected host is an
alternative. The jumpbox does not include Docker by default. Local mode is
**not** a fallback for automatic hosted image preparation or isolated custom
source builds. See [isolated image builds](network-isolation.md#image-builds-in-isolated-deployments).

**Verify:** Confirm the selected environment has the provisioned pool output
and that a build runs in it. Then resume the topology's
[deployment sequence](deploy-full-stack.md#step-4-deploy); hosted preparation
may still be incomplete.

### Package installation fails inside the build pool

**Symptom:** An ACR run starts, but package installation fails. npm can report
`Exit handler never called!`, followed by `tsc: not found`.

**Diagnose:** Retrieve the failed ACR run log from a connected host. Correlate
timestamps and the build-agent source address with firewall deny logs. Check
the pinned lockfile's `resolved` URLs, including redirect CDN destinations.
A pulled base image does not prove package-feed access.

**Correct:** Confirm the pool and `extendFirewallForAcrTaskBuilds` are enabled
and the shipped firewall changes are provisioned. The platform includes the
orchestrator's Microsoft npm feeds, `*.vsblob.vsassets.io` and the existing
`packages.microsoft.com` OS-package allowance. For additional verified
dependencies, use
[application-specific package feeds](network-isolation.md#application-specific-package-feeds).
Keep exceptions limited to build-subnet HTTPS traffic.

**Verify:** Retry the same pinned source and confirm package installation and
compilation both complete. Do not upgrade npm speculatively or assume a missing
compiler proves a dependency-version defect.

### Stale component checkout

**Symptom:** `Remove or relocate the stale sibling checkout`.

**Diagnose:** A bundled component's sibling folder exists at a different commit
from `manifest.json`. Matching `HEAD` alone would not establish that local work
is absent.

**Correct:** Inspect the named checkout, preserve local modifications and move
it aside. Retry deployment to obtain the expected source. Delete it only after
confirming it contains nothing needed; keep component development elsewhere.

**Verify:** The deployed source matches the manifest's tag **and commit**, and
the intended application revision is healthy.

### A component deployment fails

**Symptom:** `One or more components failed. See logs above.`

**Diagnose:** Find the first failing component and its newest `.logs` file.
Separate source checkout, image build/push, role and application-update errors.

**Correct:** Repair the dependency identified by that log. Use the private
connectivity or build-pool entries above when appropriate. Do not assume every
component failure is a registry-permission problem.

**Verify:** Retry the failed workflow and inspect the actual image, intended
revision and startup logs, not only the child command's exit status.

### Deploy succeeds but the UI or administrative panel does not start

**Symptom:** Child commands succeed, but the latest revision is unhealthy.
Logs name `OAUTH_AZURE_AD_CLIENT_ID`, `OAUTH_AZURE_AD_CLIENT_SECRET`,
`OAUTH_AZURE_AD_TENANT_ID` or missing panel OAuth settings.

**Diagnose:** Inspect the intended revision and image. A previous healthy
placeholder can still serve HTTP 200 while the new revision fails.

**Correct:** Configure
[delegated authentication](hosted-agents.md#configure-the-uis-delegated-authentication).
Store the credential in Key Vault and publish its reference, not its value,
under label `agent-lz`. Reload configuration through the supported
[lifecycle workflow](deploy-full-stack.md#change-a-runtime-setting).

**Verify:** Check revision health, the Entra login redirect, real user login,
OBO and rejection of unauthenticated panel data requests. Do not disable the
panel or authentication to turn a missing-authentication error into a pass.

## Provision and post-provision stages

### Search shared private links are not ready

**Symptom:** Private native `azureBlob` source configuration reports pending
approval, denied Search reads or a readiness timeout.

**Diagnose:** Inspect the **exact** reported Search service, link name, target
and group. Runner private access and successful ARM provisioning do not prove
Search-managed outbound access. Each required source link must report both
`Approved` and `Succeeded`.

**Correct:**

- **Pending:** Have an authorized administrator investigate and approve only
  the exact target request using
  [Microsoft's procedure](https://learn.microsoft.com/azure/search/search-indexer-howto-access-private).
  Configuration does not approve requests automatically.
- **ARM 401/403:** Review the runner's
  `Microsoft.Search/searchServices/sharedPrivateLinkResources/read` permission.
  Target approval does not replace it.
- **Approved but provisioning:** Allow propagation and inspect the failed
  link's state. Readiness polling has a 600-second budget, 10-second intervals
  and requests bounded by 30 seconds and the remaining budget.
- **Missing long-name manifest:** Re-provision the updated template through an
  authorized deployment to publish `SEARCH_SHARED_PRIVATE_LINKS` under
  `agent-lz`. Do not invent a hashed name or edit metadata to approve another
  request.

**Verify:** Rerun post-provision from a connected host, then verify source
processing and authorized retrieval. The gate runs before dependent Search
mutation and source creation. Do not approve unrelated requests, enumerate
target connections as a workaround, enable public access or bypass the gate.
See [Private native Blob ingestion](network-isolation.md#private-native-blob-ingestion).

### Ingestion selection does not match the source configuration

**Symptom:** A fresh environment has no ingestion Container App, a source
combination fails validation, or attachment behavior differs from expectations.

**Diagnose:** Fresh bundled deployments default
`DEPLOY_INGESTION_CONTAINER_APP=false`, independently of orchestrator hosting.
Native source ingestion covers supported Foundry IQ sources, not all ingestion
application features or conversation uploads. Existing environments and custom
definitions retain their component intent.

**Correct:** Check the resolved component selection, retrieval backend, source
kind and index bindings using [Ingestion](ingestion.md). To retain or restore the
application, select it explicitly and run the
[full workflow](deploy-full-stack.md#step-4-deploy), not only `azd deploy`.
An externally populated index must be named explicitly where required.

!!! warning "Older UI compatibility"
    The upload gate was introduced with platform v4.3.0 / UI v3.3.0.
    On platform v4.2.3 / UI v3.2.2, retain
    `DEPLOY_INGESTION_CONTAINER_APP=true` until the coordinated
    [upgrade](ingestion.md#upgrade-and-retirement-safety) is complete.
    Clearing ingestion endpoints or editing the attachment widget is not a
    supported opt-out. Never switch to anonymous authentication to hide uploads.

**Verify:** Confirm the effective `agent-lz` key and intended UI revision.
With supported opt-out, attachment controls must be hidden and direct/stale
uploads rejected, while text chat, authentication, retrieval and document
authorization still work. A missing key retains legacy behavior; explicit
`false` activates the gate. Do not delete existing apps, documents or indexes
as incidental cleanup.

### Shared-source permission options are rejected or unexpected

**Symptom:** Source configuration rejects
`FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS`, or a source has unexpected permission
metadata.

**Diagnose:** Omitted or actual-null values retain `["rbacScope"]`; explicit
`[]` means something different. For active native Blob ingestion, an empty list
deliberately selects shared access only for recognized non-ADLS `azureBlob`
configuration. Unsupported or ambiguous active sources fail closed. In
non-native `ai_search` or `foundry_iq`/`searchIndex` modes, accepted `[]` is
unused metadata, not shared-source activation.

**Correct:** Supply valid JSON for the intended source policy. For protected
Blob ingestion, restore `["rbacScope"]`. Nonempty non-ADLS Blob lists support
only `rbacScope` and `sensitivityLabels`. Review
[the full input contract](configuration.md#explicit-shared-source-permission-options)
for source/pattern constraints and the historical `managed` alias.

**Verify:** Rerun source configuration, inspect permission metadata and test
document allow/deny behavior. Do not use `[]` to bypass private-link, RBAC or
authentication failures.

### Firewall DNS proxy is enabled but clients still resolve incorrectly

**Symptom:** Private names resolve incorrectly after enabling the DNS proxy.

**Diagnose:** `ENABLE_FIREWALL_DNS_PROXY` defaults to `false`; its opt-in applies
only with firewall deployment and isolation enabled. It does not change VNet/VPN
client DNS settings or build-feed egress.

**Correct:** Inspect the affected client's DNS server, zone links and forwarding
path. Make client DNS changes deliberately and separately from proxy enablement.
See [Firewall DNS proxy](network-isolation.md#opt-in-firewall-dns-proxy).

**Verify:** Resolve the required names and test private TLS from the actual
client. Do not enable public access as a workaround.

### Hosted configuration TLS handshake stalls

**Symptom:** Hosted bootstrap stalls while loading App Configuration or Key
Vault references.

**Diagnose:** Distinguish name resolution, routing, TLS and HTTP authorization
errors at both endpoints. Confirm the actual runtime identity. MTU is not an
established cause of every timeout.

**Correct:** Only for the confirmed transport compatibility case, use the
[endpoint-scoped TLS profile](hosted-agents.md#configuration-tls-compatibility).
It was introduced in platform v4.2.3 with orchestrator v5.2.1. Supply the actual
`KEY_VAULT_URI`, deliberately select `APP_CONFIG_TLS_COMPATIBILITY=true` and
deploy the corrected agent version. To restore SDK defaults, use `false` and
redeploy. Never disable certificate verification, downgrade TLS globally or
broaden roles to conceal a transport failure.

If bootstrap resolves a UI-only secret, inspect the
[actual label selectors](configuration.md#runtime-settings): in the SDK,
`None` selects all labels, while `"\0"` selects only unlabelled settings.
Use the corrected selector, not weaker vault permissions or deleted labels.

**Verify:** The new version completes configuration using valid TLS and the
intended identity. Test real application behavior separately.

### Search preflight region and quota

**Symptom:** Preflight checks `AZURE_LOCATION` despite
`AZURE_SEARCH_LOCATION`, or counts only one service when two will be created.

**Diagnose:** Earlier hooks had region/count defects corrected in v4.2.3.
An empty `AZURE_SEARCH_LOCATION` falls back to `AZURE_LOCATION`. Both workload
and newly created Agent Service Search must be accounted for.

**Correct:** Check the effective region and selected resources using
[Search region and quota](configuration.md#search-region-and-quota).
Verify local hooks and repository-owned infrastructure match the intended
coordinated source. Request quota or deliberately select a supported region;
do not set `PREFLIGHT_SKIP` or `AGENTLZ_REGIONAL_PREFLIGHT_SKIP`.

**Verify:** Preflight checks the effective region and full creation count,
then provisioning succeeds. Preflight does not reserve capacity.

### Quota check rejects an unchanged existing deployment

**Symptom:** Re-provision reports insufficient remaining model quota for the
same account, deployment and configured capacity.

**Diagnose:** The v4.2.2 preflight compared full requested capacity with unused
regional quota, without crediting an existing matching deployment. This could
block the second provision of a hosted deployment.

**Correct:** Verify environment, account region, deployment, model/version and
SKU. Use the coordinated correction introduced in v4.2.3
([PR #773](https://github.com/Azure/agent-landing-zone/pull/773)).
It credits only verified successful matching capacity and aggregates quota
pools. Fresh allocations and changed/unverified targets still need capacity.

**Verify:** Both preflight gates evaluate the intended incremental request.
Do not delete the existing deployment, reduce capacity just to pass or disable
the gate. Model availability checks still apply.

### Foundry rejects evaluation API-key creation

**Symptom:** `Failed to list key. disableLocalAuth is set to be true`.

**Diagnose:** The account requires Entra ID. Legacy v4.2.2 post-provision still
attempted evaluation-key injection; its final success message did not prove
the secret existed.

**Correct:** Keep local authentication disabled and use Entra ID for evaluation.
The correction introduced in v4.2.3
([PR #773](https://github.com/Azure/agent-landing-zone/pull/773)) skips
inapplicable key injection and surfaces unexpected key/Key Vault errors.

**Verify:** Post-provision reports the expected Entra-only path and evaluation
works with the intended identity. Do not enable keys to hide the error.

### Administrative panel cannot resolve its Cosmos database

**Symptom:** `DEPLOY_ADMINISTRATIVE_PANEL is true but DATABASE_ACCOUNT_NAME is not set`.

**Diagnose:** Legacy v4.2.2 panel role setup expected process inputs even when
`DATABASE_ACCOUNT_NAME` and `DATABASE_NAME` were published in App Configuration.

**Correct:** Confirm the two settings under `agent-lz` for the selected
environment. Use the coordinated correction introduced in v4.2.3
([PR #773](https://github.com/Azure/agent-landing-zone/pull/773)), which reads
published settings when process inputs are absent.

**Verify:** Panel configuration resolves the actual account/database and
preserves container-scoped grants. Do not guess a database name or broaden
permissions to the whole account.

### Missing endpoint output

**Symptom:**

```text
Missing <KEY>. Run provisioning and load the selected azd environment outputs before this stage.
```

**Diagnose:** The selected environment lacks a required output such as
`APP_CONFIG_ENDPOINT`, `AZURE_AI_PROJECT_ENDPOINT` or
`AZURE_CONTAINER_REGISTRY_ENDPOINT`.

**Correct:** Confirm the environment first. If it is already provisioned and
you moved machines, use `azd env refresh`. If provision is incomplete, follow
[Deploy infrastructure only](deploy-infra-only.md). Do not invent endpoint
values to satisfy a guard.

**Verify:** The environment's outputs refer to its actual provisioned resources,
then retry the failed stage.

### Private post-provision prerequisites failed

**Symptom:**

```text
Private post-provision prerequisites failed. Connect through VPN/VNet and rerun postProvision; configuration has not started.
```

**Diagnose:** Provisioning completed, but the runner cannot reach private App
Configuration, so configuration has not started.

**Correct:** Connect through an approved jumpbox, VPN or peered VNet. Follow
[Complete a deferred post-provision](deploy-infra-only.md#complete-a-deferred-post-provision).

**Verify:** The configuration hook actually completes from the connected host.
Do not infer success from resource provisioning alone.

### Post-provision was deferred

**Symptom:**

```text
Post-provision configuration explicitly deferred; application setup is incomplete.
```

**Diagnose:** An explicit deferral can exit successfully without configuring
the application. In isolated mode, `RUN_FROM_JUMPBOX=false` (also `0`, `no`,
`skip`) or a truthy `AZURE_SKIP_NETWORK_ISOLATION_WARNING` without a truthy
`RUN_FROM_JUMPBOX` selects deferral.

**Correct:** Complete
[the deferred step](deploy-infra-only.md#complete-a-deferred-post-provision)
from a connected host. A truthy `RUN_FROM_JUMPBOX` requests connectivity
checking; it does not provide connectivity.

**Verify:** Post-provision logs show completed configuration rather than another
deferral before resuming application deployment.

### `NETWORK_ISOLATION` is not a boolean

**Symptom:** A hook rejects the isolation value.

**Diagnose:** The selected environment contains a value other than literal
`true` or `false`.

**Correct:** Restore the value required by the intended network design, for
example `azd env set NETWORK_ISOLATION true` for an isolated environment.
Do not flip it to `false` merely to pass connectivity checks.

**Verify:** The effective value matches the intended topology and validation
passes before any provisioning changes.

### Provisioning fails in Azure

**Symptom:** A resource deployment fails after preflight.

**Diagnose:** Open **Resource group > Deployments** in the Azure portal and
inspect the first failed operation, including its policy, quota, region or
resource-name error.

**Correct:** Resolve that specific cause. Region/name changes can replace
stateful resources, so review their impact before retrying the
[foundation workflow](deploy-infra-only.md#reconfigure-or-upgrade-the-foundation).
Never delete an existing resource just because its name is occupied.

**Verify:** The failed deployment and post-provision configuration both complete.
Incremental ARM success is not application acceptance.

## Runtime

### The orchestrator returns HTTP 422

**Symptom:** The agent rejects a request with validation details.

**Diagnose:** The stateless **Responses 2.0.0** adapter rejects non-null
`previous_response_id`, empty asks and message arrays not ending with a user
message. Top-level `conversation` is ignored by this adapter, not itself the
reason for a rejection. The UI's `/invocations?api-version=v1` uses another
request shape.

**Correct:** Use the returned validation detail and the correct
[calling contract](hosted-agents.md#calling-the-agent). For stateless Responses,
remove state selectors and supply complete, ordered context.

**Verify:** A valid request succeeds through the intended endpoint. Do not
interchange endpoint request bodies.

### Hosted chat works but history is unavailable

**Symptom:** A greeting works, but history is unavailable or panel history
returns 503.

**Diagnose:** Hosted runtime is stateless. Without separately activated
continuity, context is limited to the active UI session. Application Cosmos DB
in `hosted-panel` stores owner/index and feedback metadata, not transcripts.
Agent Service backing resources alone do not enable UI history.

**Correct:** Review continuity activation, panel gates, owner binding and
agent-scoped permissions in [Hosted agents](hosted-agents.md#calling-the-agent).
Apply deliberate configuration changes through the full workflow. Do not
register the Container App/Dapr history layer for hosted chat or grant broad
conversation access to the hosted container.

**Verify:** Test intended persistence across sessions, same-owner access and
cross-user denial. A greeting or a page reload is not sufficient evidence.

### The application starts but does not answer

**Symptom:** The application loads but an authenticated task fails.

**Diagnose:**

1. Confirm the intended image and revision or routed hosted version using
   [health checks](#check-application-health).
2. Read startup and request logs using [correlated diagnostics](#monitoring).
3. Inspect the effective configuration using the
   [actual component selectors](configuration.md#runtime-settings).
4. Follow the first failing model, retrieval, tool or identity dependency.

**Correct:** Repair the identified dependency, then use the appropriate
[runtime-setting lifecycle](deploy-full-stack.md#change-a-runtime-setting)
or [redeployment](deploy-full-stack.md#redeploy-applications-only).
Do not assume a restart can apply infrastructure or process-only settings.

**Verify:** Repeat the same authenticated task and test document authorization
when retrieval is involved. Keep credentials and content out of diagnostics.

### Access denied between services

**Symptom:** A dependency returns HTTP 401/403 or names a denied action.

**Diagnose:** Identify the caller's actual principal, target, denied action
and scope. A project identity, deployment principal and hosted runtime identity
are not interchangeable. Also distinguish a service call from delegated-user
authorization.

**Correct:** Compare the deployed grants with
[capability profiles](build-your-own-app.md#capability-profiles) and the
[hosted runtime access model](hosted-agents.md#bootstrap-the-agents-runtime-access).
Allow new assignments to propagate before requesting additional access. Use
[hosted recovery](deploy-full-stack.md#recover-hosted-runtime-access) where
required; do not assign blanket roles manually.

For application-component configuration failures, the catalog's implicit base
profile is a useful checklist:

| Role | Intended resource scope | Purpose |
| --- | --- | --- |
| App Configuration Data Reader | Selected App Configuration store | Read runtime settings |
| AcrPull | Selected container registry | Pull images |
| Key Vault Secrets User | Selected Key Vault | Resolve secret references |

Additional grants depend on declared profiles, selected resources and topology.
Hosted bootstrap, continuity and panel permissions are reconciled separately;
this table is not a script for assigning identical grants to every principal.

**Verify:** The same intended identity can perform the required operation while
unauthorized users/documents remain denied.

## Collect evidence

### Check application health

For **Container Apps**, list the latest and latest-ready revisions:

```bash
az containerapp list -g "<resource-group>" --query "[].{name:name,state:properties.runningStatus,latest:properties.latestRevisionName,ready:properties.latestReadyRevisionName}" -o table
az containerapp revision list -g "<resource-group>" -n "<container-app-name>" --query "[].{name:name,active:properties.active,health:properties.healthState,image:properties.template.containers[].image}" -o json
```

Compare the intended image/revision with the ready revision and traffic routing.
An older placeholder can return HTTP 200 while the intended application fails.
Inspect system and startup logs for that exact revision.

For a **Foundry hosted orchestrator**, inspect its routed version, immutable
image and Foundry runtime logs separately. Container Apps commands cover the UI,
optional ingestion and Container App orchestration, not hosted agent compute.

### Stream logs from a container app

Select the failing revision explicitly:

```bash
az containerapp logs show -g "<resource-group>" -n "<container-app-name>" --revision "<revision-name>" --follow
```

If the revision has multiple replicas or containers, select the relevant ones
using the command's `--replica` and `--container` options. Avoid treating output
from another healthy revision as evidence about the failed image.

### Monitoring

Use **Application Insights > Transaction search** to correlate a request with
its dependencies and traces. Use **Log Analytics** for container output and
platform events. Confirm diagnostic settings and the selected workspace if
expected logs are absent.

Recent Container Apps errors:

```kusto
ContainerAppConsoleLogs_CL
| where TimeGenerated > ago(1h)
| where Log_s has_any ("ERROR", "Exception", "Traceback")
| project TimeGenerated, ContainerAppName_s, Log_s
| order by TimeGenerated desc
```

Revision, scaling and startup events:

```kusto
ContainerAppSystemLogs_CL
| where TimeGenerated > ago(1h)
| project TimeGenerated, ContainerAppName_s, Reason_s, Log_s
| order by TimeGenerated desc
```

These queries depend on the configured Container Apps log destination and schema;
they do not query Foundry hosted runtime logs. No matching rows does not establish
application health.

UI records containing `exception_type` and `failure_site` intentionally omit
dependency error payloads. Correlate the static operation, code location and
request reference with dependency telemetry. Do not enable raw token, cookie,
claim, signed-URL or document logging to fill that gap. A failed optional panel
index write needs repair even when the chat continues; it is not proof the index
was persisted.

Telemetry content capture is a separate, default-off privacy choice, not a
prerequisite for successful chat or safe diagnosis.

## Related pages

- [Deployment runbook](deploy-full-stack.md)
- [Configuration](configuration.md)
- [Network isolation](network-isolation.md)
- [Ingestion](ingestion.md)
