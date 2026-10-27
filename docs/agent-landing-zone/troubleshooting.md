# Troubleshooting

## Objective

Find the **first failing stage and its exact error**, then use the matching
section below. Deployment proceeds through resource provisioning, service
configuration, image preparation and application deployment. Runtime checks
confirm the application can authenticate and use its dependencies.

## When to use

Use this runbook after a provisioning, configuration, deployment or runtime
failure. Diagnose the failing stage before retrying or changing inputs.

| What you see | Start here |
| --- | --- |
| Multi-group setup reports a missing target or denied access | [Resource group destination checks](#resource-group-destination-checks) |
| `azd down` is blocked for split resource group destinations | [Split-group cleanup safety check](#split-group-cleanup-safety-check) |
| Hosted deployment asks for preparation | [Hosted handoff](#hosted-deployment-is-not-prepared) |
| Private endpoint or build-pool failure | [Private prerequisites](#private-deployment-prerequisites-failed), [package installation](#package-installation-fails-inside-the-build-pool) |
| Configuration stops after provisioning | [Post-provision diagnostics](#provision-and-post-provision-stages) |
| Deploy reports success but the application fails | [Revision health](#check-application-health), [startup authentication](#deploy-succeeds-but-the-ui-or-administrative-panel-does-not-start) |
| Chat, history or authorization fails | [Runtime diagnostics](#runtime) |

<span id="before-changing-anything"></span>

## Prerequisites

1. Run diagnostics from the platform repository root. Confirm the intended
   environment with `azd env list` and the Azure CLI subscription with
   `az account show`. Verify the identity used by `azd` separately from the
   CLI identity; each tool can use a different account.
2. Record the failing command, time, stage, source revision and relevant
   non-secret settings, such as `NETWORK_ISOLATION`, `BUILD_MODE` and
   `DEPLOYMENT_TOPOLOGY`.
3. For private environments, use a host with the required VPN/VNet connectivity.
   Inspect DNS, TLS and authorization separately.
4. Preserve local work, data, environment bindings and security controls while
   investigating. Use the recovery steps below for the failed stage.

The default `hosted-no-panel` layout runs the orchestrator in Foundry, with
`maf_lite` and Foundry IQ. Confirm the recorded layout before recovery.
Do not switch runtimes or weaken authentication to diagnose a failure.

!!! tip "Share useful, redacted diagnostics"
    Hooks write to the terminal. Agent Application Container App component deployments
    also write child logs under `<component>/.logs`. Share the exact error and
    relevant log excerpt, not the full output of `azd env get-values`.
    Remove private environment names, user identifiers, document contents,
    signed URLs, tokens, cookies and credentials.

## Procedure

1. Capture the first error and match it to a diagnostic entry below.
2. Check the named source, identity, endpoint and selected environment.
3. Apply only the entry's scoped correction, then run its verification.
4. Complete [Validation](#validation) before reopening access or promotion.

### Deploy stage

#### Resource group destination checks

For **Agent Bicep/azd deployments**, compare the selected environment's
`AZURE_RESOURCE_GROUP`, `AZURE_APP_RESOURCE_GROUP` and
`AZURE_NETWORK_RESOURCE_GROUP` with the approved
[destination mapping](configuration.md#resource-group-destinations).
New environments initialize separate application and network destinations;
existing single-group environments retain their mapping.

With `CREATE_RESOURCE_GROUPS=false`, have the owner pre-create missing additional
groups. Enabling creation instead requires explicit authorization and
subscription-level `Microsoft.Resources/subscriptions/resourceGroups/write`.
An authorization failure is not evidence that the group is absent. Check the
actual identity and denied action; do not grant subscription Owner or bypass
the failure.

After partial creation, keep the same destinations, repair the cause and retry.
Do not delete created/shared groups as rollback, change destinations to evade
a binding check, or move existing resources through these inputs. Verify resource
IDs and scoped permissions in every destination before continuing.

#### Split-group cleanup safety check

The `predown` hook blocks
`azd down` when the workload destinations span distinct resource groups.
This is an intentional safety check, not a provisioning or permission failure.
No automatic deletion or bypass option is provided; do not bypass the hook or change the
destination mapping to make teardown proceed.

Inventory resources in every destination and identify shared dependencies,
retained data, locks and ownership. Additional groups created by the feature
do not receive the `azd-env-name` tag, so tag-based discovery is not a complete
inventory. Arrange separately authorized, itemized manual removal with the
owners. Confirm retained/shared resources remain intact afterward.
The normal single-group `azd down` path is unchanged; its
[deletion review](deploy-full-stack.md#remove-an-environment) still applies.

#### Hosted deployment is not prepared

**Symptom:** Deployment reports missing hosted preparation or an incomplete
image handoff.

**Diagnose:** The first provision creates prerequisites and records
`HOSTED_AGENT_PREPARED=true`. Preparation records an immutable image digest.
A subsequent provision records the `DEPLOY_HOSTED_AGENT=true` handoff.
Deployment then creates the running agent version.

**Correct:** Follow the hosted sequence in
the [Deploy full stack runbook](deploy-full-stack.md#step-4-deploy) from the first
incomplete step. For an unchanged, compatible image, use the
[redeployment guidance](deploy-full-stack.md#redeploy-applications-only).
Let the workflow generate its output flags.

**Verify:** Deployment targets the intended digest and routed agent version.
Then test authenticated task execution and the retrieval/authorization features
you use.

#### Hosted agent deployment returns an agent permission denial

**Symptom:** HTTP 403 names
`Microsoft.CognitiveServices/accounts/AIServices/agents/read`.

**Diagnose:** Compare the denied object ID with the actual deployment principal.
Foundry data-plane permission is granted separately from ARM provisioning access.

**Correct:** Have an authorized administrator review the minimum project-scoped
agent authoring role for that principal. A runner creating/updating agents needs
**Foundry User** or the appropriate equivalent
custom role. Azure AI Developer targets different hub/workspace scenarios.
Allow role propagation before retrying, keeping grants scoped to the project.

**Verify:** The same principal can perform the previously denied operation.
Test delegated-user/OBO access separately.

#### Application definition does not match the environment

**Symptom:** `Application definition binding check failed. No changes were made.`
with exit code `2`. An invalid definition instead exits with code `1`.

**Diagnose:** Compare the selected definition's application ID with the existing
`AGENTLZ_APP_ID` binding. The application ID identifies the application selected
for that environment; orchestrator topology is a separate choice.

**Correct:** Restore the matching definition. For a different application ID,
use a separate environment and select the definition **before first provision**.
Retain the original environment's binding and topology.

**Verify:** Definition validation and binding checks pass for the intended
environment. See [Custom applications](build-your-own-app.md).

<span id="custom-hosted-image-pull-fails-with-a-classic-bundled-orchestrator"></span>

<span id="custom-hosted-image-pull-fails-with-a-classic-agent-application-orchestrator"></span>

#### Custom hosted image pull fails

**Symptom:** A custom `azure.ai.agent` service cannot activate its private image,
although Foundry project and registry outputs exist.

**Diagnose:** Check the Foundry **project identity's** registry pull grant and
the exact image/registry. Custom hosted components require hosted foundation
preparation regardless of where any other component runs.

**Correct:** Preserve the
environment, definition and immutable image, then rerun the
[custom application workflow](build-your-own-app.md#deploy-a-different-application).
Provisioning applies the declarative pull grant; refreshing outputs alone
cannot. For an external registry, review its supported pull-role mode and
resource scope separately.

**Verify:** Image activation succeeds and the actual runtime principal receives
the declared capabilities. Check the routed version before testing the agent.
Keep registry authentication identity-based, grants narrowly scoped and
delegated-user/OBO authentication intact.

#### Private deployment prerequisites failed

**Symptom:**

```text
Private deployment prerequisites failed. Use a VPN/VNet-connected host; RUN_FROM_JUMPBOX is not a connectivity bypass.
```

**Diagnose:** With `NETWORK_ISOLATION=true`, the host cannot resolve or establish
TLS to App Configuration, or to the Foundry project endpoint for hosted
topologies. The gate allows up to 20 seconds per endpoint.

**Correct:** Move to the approved jumpbox, VPN or peered-VNet runner and inspect
the [private connectivity path](network-isolation.md#verify-private-connectivity).
The `RUN_FROM_JUMPBOX` input requests a connectivity check from that host.

**Verify:** Resolve and reach each required endpoint from that runner, then
retry the failed stage. If it returns an authorization error, check the
requesting principal and its permissions next.

#### ACR Task agent pool is missing

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
alternative. The jumpbox does not include Docker by default. Automatic hosted
image preparation and isolated custom source builds require the supported ACR
Tasks path. See [isolated image builds](network-isolation.md#image-builds-in-isolated-deployments).

**Verify:** Confirm the selected environment has the provisioned pool output
and that a build runs in it. Then resume the topology's
[deployment sequence](deploy-full-stack.md#step-4-deploy); hosted preparation
may still be incomplete.

#### Package installation fails inside the build pool

**Symptom:** An ACR run starts, but package installation fails. npm can report
`Exit handler never called!`, followed by `tsc: not found`.

**Diagnose:** Retrieve the failed ACR run log from a connected host. Correlate
timestamps and the build-agent source address with firewall deny logs. Check
the pinned lockfile's `resolved` URLs, including redirect CDN destinations.
Base-image registries and package feeds can require separate firewall allowances.

**Correct:** Confirm the pool and `extendFirewallForAcrTaskBuilds` are enabled
and the shipped firewall changes are provisioned. The platform includes the
orchestrator's Microsoft npm feeds, `*.vsblob.vsassets.io` and the existing
`packages.microsoft.com` OS-package allowance. For additional verified
dependencies, use
[application-specific package feeds](network-isolation.md#application-specific-package-feeds).
Keep exceptions limited to build-subnet HTTPS traffic.

**Verify:** Retry the same pinned source and confirm package installation and
compilation both complete. Once dependencies are installed, diagnose the first
remaining compilation error.

#### Tokenizer initialization fails with an empty cache

**Symptom:** Orchestrator or ingestion startup fails while downloading a
tiktoken encoding from `openaipublic.blob.core.windows.net`.

**Diagnose:** Check the failing HTTPS/443 destination and the actual workload
subnet against firewall logs. A warm tokenizer cache can conceal this
dependency; successful image builds do not verify runtime egress.

**Correct:** Review the selected components' [runtime egress declarations](network-isolation.md#component-runtime-egress).
Both bundled tokenizer consumers declare this exact host. For a managed
firewall, follow the normal provisioning sequence to save the declaration
plan and reconcile its owned rules. For an external firewall, send the
read-only resolved report to its policy owner. Keep the exception on the
required workload subnet; do not allow all Blob Storage or Internet traffic.

**Verify:** From the actual workload network, initialize the configured
tokenizer with a newly empty cache and confirm its asset download and startup
complete. A local cold-cache test establishes the dependency, not traversal
through the deployed firewall.

#### Component egress reconciliation stops

**Symptom:** A hook reports a missing or stale egress plan, ownership collision,
invalid source subnet or concurrent policy change.

**Correct:** Keep the same application binding. Review
`python -m config.deployment.egress --plan --environment <environment-name>`
and rerun the normal provisioning sequence after approved input changes.
For collisions or changed policies, have the network owner inspect the
reported group and current rules before retrying; do not delete unrelated
entries, broaden sources or bypass the ownership checks.

**Verify:** The read-only `--review` report has the intended destinations and
actual workload prefixes. Managed reconciliation completes without changing
unrelated rules; external policies remain report-only.

#### Stale component checkout

**Symptom:** `Remove or relocate the stale sibling checkout`.

**Diagnose:** An Agent Application component's sibling folder exists at a different commit
from `manifest.json`. Check `HEAD` and local modifications before replacing it.

**Correct:** Inspect the named checkout, preserve local modifications and move
it aside. Retry deployment to obtain the expected source. Delete it only after
confirming it contains nothing needed; keep component development elsewhere.

**Verify:** The deployed source matches the manifest's tag **and commit**, and
the intended application revision is healthy.

#### A component deployment fails

**Symptom:** `One or more components failed. See logs above.`

**Diagnose:** Find the first failing component and its newest `.logs` file.
Distinguish source checkout, image build/push, role and application-update failures.

**Correct:** Repair the dependency identified by that log. Use the private
connectivity or build-pool entries above when appropriate.

**Verify:** Retry the failed workflow and inspect the actual image, intended
revision and startup logs.

#### Deploy succeeds but the UI or administrative panel does not start

**Symptom:** Child commands succeed, but the latest revision is unhealthy.
Logs name `OAUTH_AZURE_AD_CLIENT_ID`, `OAUTH_AZURE_AD_CLIENT_SECRET`,
`OAUTH_AZURE_AD_TENANT_ID` or missing panel OAuth settings.

**Diagnose:** Inspect the intended revision and image. A previous healthy
placeholder can still serve HTTP 200 while the new revision fails.

**Correct:** Configure
[delegated authentication](application-auth.md).
Store the credential in Key Vault and publish its reference, not its value,
under label `agent-lz`. Reload configuration through the supported
[lifecycle workflow](deploy-full-stack.md#change-a-runtime-setting).

**Verify:** Check revision health, the Entra login redirect, real user login,
OBO and rejection of unauthenticated panel data requests. Keep panel
authentication required throughout recovery.

### Provision and post-provision stages

#### Search shared private links are not ready

**Symptom:** Private native `azureBlob` source configuration reports pending
approval, denied Search reads or a readiness timeout.

**Diagnose:** Inspect the **exact** reported Search service, link name, target
and group. Search uses its own outbound private links to storage and models,
separately from the runner's network access. Each required source link must
report both `Approved` and `Succeeded`.

**Correct:**

- **Pending:** Have an authorized administrator investigate and approve only
  the exact target request using
  [Microsoft's procedure](https://learn.microsoft.com/azure/search/search-indexer-howto-access-private).
- **ARM 401/403:** Review the runner's
  `Microsoft.Search/searchServices/sharedPrivateLinkResources/read` permission.
  The runner needs this read permission in addition to target approval.
- **Approved but provisioning:** Allow propagation and inspect the failed
  link's state. Readiness polling has a 600-second budget, 10-second intervals
  and requests bounded by 30 seconds and the remaining budget.
- **Missing link manifest:** Re-provision the reviewed template through an
  authorized deployment to publish `SEARCH_SHARED_PRIVATE_LINKS` under
  `agent-lz`. Use the published link names to identify the matching requests.

**Verify:** Rerun post-provision from a connected host, then verify source
processing and authorized retrieval. The gate runs before dependent Search
mutation and source creation. Retain private access and the readiness gate;
approve only the requests for the intended source targets.
See [Private native Blob ingestion](network-isolation.md#private-native-blob-ingestion).

#### Ingestion selection does not match the source configuration

**Symptom:** A fresh environment has no ingestion Container App, a source
combination fails validation, or attachment behavior differs from expectations.

**Diagnose:** Fresh Agent Application deployments default to
`DEPLOY_INGESTION_CONTAINER_APP=false`, independently of orchestrator hosting.
Native source ingestion uses Search's service-managed pipeline. Conversation
uploads and Agent App Ingestion features require separate selection.
Existing environments and custom definitions retain their component selections.

**Correct:** Check the resolved component selection, retrieval backend, source
kind and index bindings using [Ingestion](ingestion.md). To retain or restore
Agent App Ingestion, select it explicitly and run the
[full workflow](deploy-full-stack.md#step-4-deploy), not only `azd deploy`.
An externally populated index must be named explicitly where required.

**Verify:** Confirm the effective `agent-lz` key and intended UI revision.
With ingestion disabled, attachment controls must be hidden and direct/stale
uploads rejected. Verify text chat and retrieval separately, including the
[protected-retrieval integration gate](#protected-retrieval-fails-after-hosted-sign-in).
Ingestion selection is not a source of delegated user or owner context.

If ingestion is selected, confirm the selection is `true` and test only
eligible authenticated uploads. Processing success does not prove authorized
conversation retrieval.
Retire existing apps and permissions only as a
separate authorized task, preserving documents and indexes.

#### Shared-source permission options are rejected or unexpected

**Symptom:** Source configuration rejects
`FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS`, or a source has unexpected permission
metadata.

**Diagnose:** Omitted or null values retain `["rbacScope"]`. For active native
Blob ingestion, explicit `[]` selects shared access only for recognized non-ADLS `azureBlob`
configuration. Unsupported or ambiguous active sources fail closed. In
non-native `ai_search` or `foundry_iq`/`searchIndex` modes, accepted `[]` is
unused metadata; the source's access policy remains unchanged.

**Correct:** Supply valid JSON for the intended source policy. For protected
Blob ingestion, restore `["rbacScope"]`. Nonempty non-ADLS Blob lists support
only `rbacScope` and `sensitivityLabels`. Review
[the accepted permission values](configuration.md#explicit-shared-source-permission-options)
for source and pattern constraints.

**Verify:** Rerun source configuration, inspect permission metadata and test
document allow/deny behavior. Select `[]` only for an intentionally shared
corpus; resolve private-link, RBAC and authentication failures separately.

#### Firewall DNS proxy is enabled but clients still resolve incorrectly

**Symptom:** Private names resolve incorrectly after enabling the DNS proxy.

**Diagnose:** `ENABLE_FIREWALL_DNS_PROXY` defaults to `false`; its opt-in applies
only with firewall deployment and isolation enabled. VNet/VPN client DNS
settings and build-feed egress are configured separately.

**Correct:** Inspect the affected client's DNS server, zone links and forwarding
path. Make client DNS changes deliberately and separately from proxy enablement.
See [Firewall DNS proxy](network-isolation.md#opt-in-firewall-dns-proxy).

**Verify:** Resolve the required names and test private TLS from the actual
client with public access still disabled.

#### Hosted configuration TLS handshake stalls

**Symptom:** Hosted bootstrap stalls while loading App Configuration or Key
Vault references.

**Diagnose:** Distinguish name resolution, routing, TLS and HTTP authorization
errors at both endpoints. Confirm the actual runtime identity and identify
which connection stage stalls before choosing a recovery action.

**Correct:** Only for the confirmed transport compatibility case, use the
[endpoint-scoped TLS profile](hosted-agents.md#configuration-tls-compatibility).
Supply the actual `KEY_VAULT_URI`, deliberately select
`APP_CONFIG_TLS_COMPATIBILITY=true` and deploy a new agent version.
To restore SDK defaults, use `false` and
redeploy. Keep certificate verification, the minimum TLS version and scoped
role assignments intact.

If bootstrap resolves a UI-only secret, inspect the
[actual label selectors](configuration.md#runtime-settings): in the SDK,
`None` selects all labels, while `"\0"` selects only unlabelled settings.
Use the intended selector while retaining scoped vault permissions and labels.

**Verify:** The new version completes configuration using valid TLS and the
intended identity. Test real application behavior separately.

#### Search preflight region and quota

**Symptom:** Preflight checks `AZURE_LOCATION` despite
`AZURE_SEARCH_LOCATION`, or counts only one service when two will be created.

**Diagnose:** An empty `AZURE_SEARCH_LOCATION` falls back to `AZURE_LOCATION`. Both workload
and newly created Agent Service Search must be accounted for.

**Correct:** Check the effective region and selected resources using
[Search region and quota](configuration.md#search-region-and-quota).
Verify local hooks and repository-owned infrastructure match the intended
coordinated source. Request quota or deliberately select a supported region;
do not set `PREFLIGHT_SKIP` or `AGENTLZ_REGIONAL_PREFLIGHT_SKIP`.

**Verify:** Preflight checks the effective region and full creation count,
then provisioning succeeds. Capacity remains subject to availability at
provisioning time.

#### Quota check rejects an unchanged existing deployment

**Symptom:** Re-provision reports insufficient remaining model quota for the
same account, deployment and configured capacity.

**Diagnose:** Compare the requested capacity with the existing successful
deployment and remaining regional quota. A second hosted provision must use
the same reviewed account and model inputs.

**Correct:** Verify environment, account region, deployment, model/version and
SKU. Preflight credits only verified successful matching capacity and aggregates quota
pools. Fresh allocations and changed/unverified targets still need capacity.
If a matching deployment is not credited, retain the gates and escalate with
sanitized account, region, model and capacity evidence.

**Verify:** Both preflight gates evaluate the intended incremental request.
Retain the existing deployment, intended capacity and preflight gates.
Model availability checks still apply.

#### Foundry rejects evaluation API-key creation

**Symptom:** `Failed to list key. disableLocalAuth is set to be true`.

**Diagnose:** The account requires Entra ID. Identify the caller still trying
to obtain an API key.

**Correct:** Keep local authentication disabled and use Entra ID for evaluation.
The supported configuration skips inapplicable key injection. Investigate
unexpected key or Key Vault errors instead of enabling local authentication.

**Verify:** Post-provision reports the expected Entra-only path and evaluation
works with the intended identity while local authentication remains disabled.

#### Administrative panel cannot resolve its Cosmos database

**Symptom:** `DEPLOY_ADMINISTRATIVE_PANEL is true but DATABASE_ACCOUNT_NAME is not set`.

**Diagnose:** Identify the selected database account and name, then check
process inputs and the settings published in App Configuration.

**Correct:** Confirm the two settings under `agent-lz` for the selected
environment. Setup reads published settings when process inputs are absent.
Resolve missing or conflicting values in their provisioning source.

**Verify:** Panel configuration resolves the actual account/database and
preserves container-scoped grants. Compare the resolved names with the
provisioned resources and keep permissions scoped to the required containers.

#### Missing endpoint output

**Symptom:**

```text
Missing <KEY>. Run provisioning and load the selected azd environment outputs before this stage.
```

**Diagnose:** The selected environment lacks a required output such as
`APP_CONFIG_ENDPOINT`, `AZURE_AI_PROJECT_ENDPOINT` or
`AZURE_CONTAINER_REGISTRY_ENDPOINT`.

**Correct:** Confirm the environment first. If it is already provisioned and
you moved machines, use `azd env refresh`. If provision is incomplete, follow
the [Deploy infra only runbook](deploy-infra-only.md) to generate the required outputs.

**Verify:** Confirm the outputs identify this environment's resources before
retrying the failed stage.

#### Private post-provision prerequisites failed

**Symptom:**

```text
Private post-provision prerequisites failed. Connect through VPN/VNet and rerun postProvision; configuration has not started.
```

**Diagnose:** Provisioning completed, but the runner cannot reach private App
Configuration, so configuration has not started.

**Correct:** Connect through an approved jumpbox, VPN or peered VNet. Follow
[Complete a deferred post-provision](deploy-infra-only.md#complete-a-deferred-post-provision).

**Verify:** Complete the configuration hook from the connected host before
resuming application deployment.

#### Post-provision was deferred

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
checking from the runner's existing network path.

**Verify:** Post-provision logs show completed configuration rather than another
deferral before resuming application deployment.

#### `NETWORK_ISOLATION` is not a boolean

**Symptom:** A hook rejects the isolation value.

**Diagnose:** The selected environment contains a value other than literal
`true` or `false`.

**Correct:** Restore the value required by the intended network design, for
example `azd env set NETWORK_ISOLATION true` for an isolated environment.
Use `false` only when the intended network design is non-isolated.

**Verify:** The effective value matches the intended network design and validation
passes before any provisioning changes.

#### Provisioning fails in Azure

**Symptom:** Preflight passes but Azure resource deployment fails.

**Diagnose:** Open **Resource group > Deployments** in the Azure portal and
inspect the first failed operation, including its policy, quota, region or
resource-name error.

**Correct:** Resolve that specific cause. Region/name changes can replace
stateful resources, so review their impact before retrying the
[foundation workflow](deploy-infra-only.md#reconfigure-or-upgrade-the-foundation).
For a name conflict, identify the existing resource and its owner before
deciding whether to reuse it or choose another name.

**Verify:** The failed deployment and post-provision configuration both complete.
Then deploy the application and run its authenticated task and access checks.

### Runtime

#### Protected retrieval fails after hosted sign-in

**Symptom:** UI login and a greeting work, but protected Foundry IQ retrieval
lacks delegated user context, is denied or omits documents.

**Diagnose:** Distinguish UI-to-Foundry OBO from downstream source authorization.
The hosted gateway does not forward the caller's `Authorization` header.
The shipped `maf_lite` direct connector does not complete the authenticated
Toolbox integration needed for protected per-user retrieval.

**Correct:** Stop protected-data rollout and have a developer implement and
validate the supported hosted identity integration. Follow the capability gate
in the [Deploy full stack runbook](deploy-full-stack.md#prerequisites).
Do not select another strategy as a workaround, invent identity headers, enable
anonymous retrieval or replace the user with a service identity.

**Verify:** Use two users with different source permissions and confirm
permitted retrieval and denial through the actual UI or channel. If that
integration is absent, mark the capability **blocked**.

#### The orchestrator returns HTTP 422

**Symptom:** The agent rejects a request with validation details.

**Diagnose:** The stateless **Responses 2.0.0** adapter rejects non-null
`previous_response_id`, empty asks and message arrays not ending with a user
message. The adapter ignores top-level `conversation`.
The UI's `/invocations?api-version=v1` uses another request shape.

**Correct:** Use the returned validation detail and the correct
[request format](hosted-agents.md#calling-the-agent). For stateless Responses,
remove state selectors and supply complete, ordered context.

**Verify:** A request in the intended endpoint's format succeeds through that endpoint.

#### Hosted chat works but history is unavailable

**Symptom:** A greeting works, but history is unavailable or panel history
returns 503.

**Diagnose:** Hosted runtime is stateless. Without separately activated
continuity, context is limited to the active UI session. Agent Application Cosmos DB
in `hosted-panel` stores owner/index and feedback metadata, not transcripts.
UI history requires continuity and the separately documented panel gates.

**Correct:** Review continuity activation, panel gates, owner binding and
agent-scoped permissions in [Hosted agents](hosted-agents.md#calling-the-agent).
Apply configuration changes through the full workflow using hosted continuity
and owner-scoped permissions. Keep the hosted container's conversation access
restricted; do not enable the panel merely to obtain persistence.

**Verify:** Open a saved conversation in a new session as its owner and confirm
the transcript is available. Repeat as another user and confirm access is denied.

#### The application starts but does not answer

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
Use provisioning for infrastructure changes and a new process or hosted version
for startup settings, as specified in those workflows.

**Verify:** Repeat the same authenticated task and test document authorization
when retrieval is involved. Keep credentials and content out of diagnostics.

#### Access denied between services

**Symptom:** A dependency returns HTTP 401/403 or names a denied action.

**Diagnose:** Identify the caller's actual principal, target, denied action
and scope. Project, deployment and hosted runtime principals each have their own
grants. Check service authentication separately from delegated-user authorization.

**Correct:** Compare the deployed grants with
[capability profiles](build-your-own-app.md#capability-profiles) and the
[hosted runtime access model](hosted-agents.md#bootstrap-the-agents-runtime-access).
Allow new assignments to propagate before requesting additional access. Use
[hosted recovery](deploy-full-stack.md#recover-hosted-runtime-access) where
required, keeping role assignments scoped to the required resources.

For application-component configuration failures, use this checklist of base
capability permissions:

| Role | Intended resource scope | Purpose |
| --- | --- | --- |
| App Configuration Data Reader | Selected App Configuration store | Read runtime settings |
| AcrPull | Selected container registry | Pull images |
| Key Vault Secrets User | Selected Key Vault | Resolve secret references |

Additional grants depend on declared profiles, selected resources and topology.
Hosted bootstrap, continuity and panel permissions are reconciled separately.
Use the relevant workflow to grant only the roles required by the actual caller.

**Verify:** The same intended identity can perform the required operation while
unauthorized users/documents remain denied.

<span id="collect-evidence"></span>

### Collect diagnostics

#### Check application health

List the latest and latest-ready **Container Apps** revisions:

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

#### Stream logs from a container app

Select the failing revision explicitly:

```bash
az containerapp logs show -g "<resource-group>" -n "<container-app-name>" --revision "<revision-name>" --follow
```

If the revision has multiple replicas or containers, select the relevant ones
using the command's `--replica` and `--container` options. Confirm the logs
belong to the failed revision and image.

#### Monitoring

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
they cover Container Apps rather than Foundry hosted runtime logs. If no rows
match, check the time range, log destination and failing revision, then inspect
application health directly.

UI records containing `exception_type` and `failure_site` intentionally omit
dependency error payloads. Correlate the static operation, code location and
request reference with dependency telemetry. Do not enable raw token, cookie,
claim, signed-URL or document logging to fill that gap. A failed optional panel
index write needs repair even when the chat continues. Confirm the expected
owner-index record exists after retrying the write.

Telemetry content capture is off by default. Keep prompts and answers private;
diagnose with request references and dependency status.

## Validation

1. Repeat the exact operation that failed, from the intended host and identity.
2. Confirm the intended source commit, immutable image and routed hosted version
   or Container App revision. A placeholder response is not application health.
3. Test user sign-in, the required tool or retrieval operation, and allowed and
   denied access to protected data. Keep unresolved runtime integration gates
   explicitly blocked.
4. Record sanitized timestamps, request IDs, statuses and the scoped correction.
   Do not claim success from a green hook exit alone.

## Rollback

1. Stop retries and promotion. Preserve the diagnostic record and known-good
   source, input and image records.
2. Restore only the settings or grants changed during diagnosis, using the
   recorded values and exact assignment IDs. Preserve unrelated access.
3. If an application or infrastructure redeployment is required, follow
   [deployment rollback](deploy-full-stack.md#rollback) or
   [infrastructure rollback](deploy-infra-only.md#rollback).
4. Repeat [Validation](#validation). Keep access closed if safe reversal or
   protected-data enforcement is not established. Arrange service-specific
   data recovery with the owner when necessary.

### Related pages

- [Copilot Studio private integration](connect-copilot-studio.md#troubleshooting)
- [Deploy full stack runbook](deploy-full-stack.md)
- [Deployment settings](configuration.md)
- [Network isolation](network-isolation.md)
- [Ingestion](ingestion.md)
