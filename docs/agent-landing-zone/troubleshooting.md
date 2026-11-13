# Troubleshooting

## Objective

Find the **first failing stage and its exact error**, then use the matching
section below. Deployment proceeds through resource provisioning, service
configuration, image preparation and application deployment. Runtime checks
confirm the application can authenticate and use its dependencies.

## When to use

Use this guide after a provisioning, configuration, deployment or runtime
failure. Diagnose the failing stage before retrying or changing inputs.

| What you see | Start here |
| --- | --- |
| Init created a nested project or the environment already exists | [Initialization directory and environment](#initialization-directory-and-environment) |
| Multi-group setup reports a missing target or denied access | [Resource group destination checks](#resource-group-destination-checks) |
| `azd down` is blocked for split resource group destinations | [Split-group cleanup safety check](#split-group-cleanup-safety-check) |
| Hosted deployment asks for preparation | [Hosted handoff](#hosted-deployment-is-not-prepared) |
| Private endpoint or build-pool failure | [Private prerequisites](#private-deployment-prerequisites-failed), [package installation](#package-installation-fails-inside-the-build-pool) |
| Foundry agent subnet change, reserved hosted variable or workload profile fails | [Foundry network injection](#foundry-network-injection-or-agent-subnet-change-fails), [definition and workload profile checks](#custom-hosted-variable-or-workload-profile-validation-fails) |
| Configuration stops after provisioning | [Post-provision diagnostics](#provision-and-post-provision-stages) |
| Deploy reports success but the application fails | [Revision health](#check-application-health), [startup authentication](#deploy-succeeds-but-the-ui-or-administrative-panel-does-not-start) |
| Chat, history, AI Gateway or authorization fails | [Runtime diagnostics](#runtime), [service access](#access-denied-between-services) |
| Foundry portal Operate, Traces or hosted evaluations fail | [Operate, Traces and evaluations](#foundry-portal-operate-traces-or-hosted-evaluations-fail) |

<span id="before-changing-anything"></span>

## Prerequisites

1. Run diagnostics from the platform repository root. Confirm the intended
   environment with `azd env list` and the Azure CLI subscription with
   `az account show`. Verify the identity used by `azd` separately from the
   CLI identity; each tool can use a different account.
2. Record the failing command, time, stage, source revision and relevant
   non-secret settings, such as `NETWORK_ISOLATION`, `BUILD_MODE` and
   `ORCHESTRATION_HOST` and `APPLICATION_MODE`.
3. For private environments, use a host with the required VPN/VNet connectivity.
   Inspect DNS, TLS and authorization separately.
4. Preserve local work, data, environment bindings and security controls while
   investigating. Use the recovery steps below for the failed stage.

The default host is `hosted` and mode is `conversational`, with the UI
included automatically. Record the canonical host/mode before recovery.
History, feedback and attachments are independent default-off features;
workflow or `both` requires UI metadata even with those flags off.
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

### Initialization directory and environment

**Symptom:** the template files are in a nested directory, or `azd env new`
reports that the environment already exists after init.

**Check:** locate the directory containing root `azure.yaml`, `manifest.json`
and `main.parameters.json`. Run `azd env list` there to confirm the local
environment.

**Correct:** for a fresh installation, create and enter a new empty directory,
then run `azd init --template Azure/agent-landing-zone .`. The trailing `.`
explicitly uses the current directory; without it, current azd creates a
template-named subdirectory. Interactive init creates/selects the named
environment, so do not follow it with another `azd env new`.

For an already initialized project, enter its actual root and use
`azd env select <environment-name>` to resume. Do not delete `.azure/`, rerun
template initialization over local work, or create a different environment to
evade an existing deployment binding.

**Verify:** confirm the selected environment, target subscription/region and
root `azure.yaml` provider/path before following the
[deployment guide](index.md#infrastructure-and-application). Initialization is
not evidence of successful provisioning or application deployment.

### Deploy stage

#### Resource group destination checks

For **Bicep and Terraform deployments**, compare the selected environment's
`AZURE_RESOURCE_GROUP`, `applicationResourceGroupName`
(`AZURE_APP_RESOURCE_GROUP`), `networkResourceGroupName`
(`AZURE_NETWORK_RESOURCE_GROUP`) and `privateEndpointResourceGroupName`
(`AZURE_PE_RESOURCE_GROUP_NAME`) with the approved
[destination mapping](configuration.md#resource-group-destinations) and
[placement checklist](network-isolation.md#multi-resource-group-placement-checklist).
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

For **Bicep**, the `predown` hook blocks
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

For **Terraform**, split groups use recorded state-scoped ownership. Missing
original group/backend records or changed destinations block teardown;
restore the original environment metadata instead of recreating bindings.
Follow [Terraform removal](deploy-terraform-infra-only.md#remove-the-foundation)
for the required records, preview and explicit destruction approval.

#### Hosted deployment is not prepared

**Symptom:** Deployment reports missing hosted foundation prerequisites or
automatic image preparation fails.

**Diagnose:** Provision creates prerequisites and records the foundation
handoff. Deployment builds or reuses the immutable image,
records its application handoff and creates the running agent version. A missing
digest before deployment is normal; it does not require another provision.

**Correct:** Provision if the foundation is missing. Otherwise review the failed
build, pinned source, registry access and private ACR Tasks pool, then retry
`azd deploy`. A foundation project or registry binding mismatch must be resolved
against the intended environment, not bypassed by editing output flags.
Follow the [full-stack deployment guide](deploy-full-stack.md#step-4-deploy).
For an unchanged, compatible image, use the
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
Retain the original environment's binding and canonical host/mode selection.

**Verify:** Definition validation and binding checks pass for the intended
environment. See [Custom applications](build-your-own-app.md).

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

#### Custom hosted variable or workload profile validation fails

**Symptom:** `config.appdefinition` or preflight rejects a custom hosted
environment override in `azure.yaml` or `agent.yaml`, or fails fast on
Container Apps `profile_name` resolution before deployment.

**Diagnose:** Microsoft Foundry Hosted Agents reserve `FOUNDRY_*` (such as
`FOUNDRY_PROJECT_ENDPOINT`, `FOUNDRY_PROJECT_ARM_ID`, `FOUNDRY_AGENT_NAME`,
`FOUNDRY_AGENT_VERSION`, `FOUNDRY_AGENT_SESSION_ID`), `AGENT_*` and
`APPLICATIONINSIGHTS_CONNECTION_STRING`. For Container Apps, `profile_name`
resolves against effective `workloadProfiles` (`WORKLOAD_PROFILES`) and rejects
unknown names or ambiguous multi-profile lists without `"main"` or
`"Consumption"`.

**Correct:** Remove overrides of reserved `FOUNDRY_*`, `AGENT_*` and
`APPLICATIONINSIGHTS_CONNECTION_STRING` entries from `azure.yaml` and
`agent.yaml` (`APPLICATIONINSIGHTS_STATSBEAT_DISABLED_ALL` and `OTEL_*` remain
valid). For Container Apps, align `profile_name` and `WORKLOAD_PROFILES` using
[Container Apps workload profiles](configuration.md#container-apps-workload-profiles).

**Verify:** Run `python -m config.appdefinition --validate` and confirm
preflight succeeds before running `azd deploy`.

#### Private connectivity checks

Check service hostnames from the actual deployment runner, including
`APP_CONFIG_ENDPOINT`. Test these boundaries separately:

| Check | Expected result |
| --- | --- |
| DNS | Only private IPv4 addresses in 10.x, 172.16 through 31.x or 192.168.x. |
| TCP | Connection succeeds on port 443. |
| TLS | The original hostname validates with normal certificate verification. |

Public answers usually indicate a missing private-zone link or incorrect
VPN/hub forwarding. On Windows, `nslookup` can differ from the operating
system resolver used by the prerequisite check, especially with VPN NRPT rules.
That check rejects mixed public/private, IPv6, loopback and link-local answers.

The transport check sends no HTTP request or credential. Successful DNS,
TCP and TLS are not proof of API or document authorization. Test those
separately with the intended identities. Keep isolation and TLS verification.

For BYO hub and central Private DNS topologies, also verify:

- `privatelink.documents.azure.com` exists and links to the hub/spoke even when `DEPLOY_COSMOS_DB=false` if Foundry Agent Service provisions its enterprise memory Cosmos account.
- Internal Container Apps environments (`internal = true`) have a Private DNS zone for `<defaultDomain>` with static `A` records `*` and `@` pointing to `staticIp`, alongside `privatelink.<region>.azurecontainerapps.io`.
- Internal AI Gateway integrations resolve `privatelink.azure-api.net`.
- AMPLS zones include `privatelink.monitor.azure.com` (which maps Application Insights ingestion, live and query endpoints rather than `privatelink.applicationinsights.io`), `privatelink.oms.opinsights.azure.com`, `privatelink.ods.opinsights.azure.com`, exact hyphenated `privatelink.agentsvc.azure-automation.net` and `privatelink.blob.core.windows.net`.
- Both spoke-to-hub and reverse hub-to-spoke peerings enable `allowVirtualNetworkAccess` and `allowForwardedTraffic`, gateway transit matches, and VPN or ExpressRoute gateways advertise return routes for the spoke address space.
- BYO hub firewalls allow outbound HTTPS (`443`) to Azure Monitor ingestion and query endpoints (`*.loganalytics.io`, `*.applicationinsights.io`, `*.monitor.azure.com`, `*.in.applicationinsights.azure.com`, `*.ods.opinsights.azure.com`, `*.oms.opinsights.azure.com`). See the [BYO hub checklists](network-isolation.md#byo-hub-private-dns-checklist).

#### Private deployment prerequisites failed

**Symptom:**

```text
Private deployment prerequisites failed. Use a VPN/VNet-connected host; RUN_FROM_JUMPBOX is not a connectivity bypass.
```

**Diagnose:** With `NETWORK_ISOLATION=true`, the host cannot resolve or establish
TLS to App Configuration, or to the Foundry project endpoint for hosted
topologies. The gate allows up to 20 seconds per endpoint.

**Correct:** Move to the approved jumpbox, VPN or peered-VNet runner and inspect
the [private connectivity path](troubleshooting.md#private-connectivity-checks).
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
Tasks path. See [isolated image builds](configuration.md#private-image-builds).

**Verify:** Confirm the selected environment has the provisioned pool output
and that a build runs in it. Then resume the topology's
[deployment sequence](deploy-full-stack.md#step-4-deploy); `azd deploy` resumes
automatic hosted image preparation.

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
[application-specific package feeds](configuration.md#application-specific-package-feeds).
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

**Correct:** Review the selected components' [runtime egress declarations](configuration.md#outbound-access).
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
See [Private native Blob ingestion](configuration.md#search-shared-private-links).

#### Ingestion selection does not match the source configuration

**Symptom:** A fresh environment has no ingestion Container App, a source
combination fails validation, or attachment behavior differs from expectations.

**Diagnose:** Fresh Agent Application deployments default to
`DEPLOY_INGESTION_CONTAINER_APP=false`, independently of orchestrator hosting.
Native source ingestion uses Search's service-managed pipeline.
Agent App Ingestion features require explicit selection.
Private attachments have a separate feature gate and file-processing path;
ingestion selection does not enable them.
Existing environments and custom definitions retain their component selections.

**Correct:** Check the resolved component selection, retrieval backend, source
kind and index bindings using [Ingestion](ingestion.md). To retain or restore
Agent App Ingestion, select it explicitly and run the
[full workflow](deploy-full-stack.md#step-4-deploy), not only `azd deploy`.
An externally populated index must be named explicitly where required.

**Verify:** Confirm the effective `agent-lz` key and intended UI revision.
With attachments disabled, controls must be unavailable and direct/stale
uploads rejected. With attachments enabled, verify the supported file path,
owner-bound reads/downloads and denied cross-user access. Verify chat and retrieval
separately, including the
[delegated retrieval checks](#protected-retrieval-fails-after-hosted-sign-in).
Ingestion selection is not a source of delegated user or owner context.

If ingestion is selected, confirm the selection is `true` and test its actual
document-processing APIs. Processing success does not prove authorized
retrieval or enable a native attachment path.
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
[the accepted permission values](foundry-iq.md#shared-source-permission-metadata)
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
See [Firewall DNS proxy](configuration.md#opt-in-firewall-dns-proxy).

**Verify:** Resolve the required names and test private TLS from the actual
client with public access still disabled.

#### Hosted configuration TLS handshake stalls

**Symptom:** Hosted bootstrap stalls while loading App Configuration or Key
Vault references.

**Diagnose:** Distinguish name resolution, routing, TLS and HTTP authorization
errors at both endpoints. Confirm the actual runtime identity and identify
which connection stage stalls before choosing a recovery action.

Runtime availability handling catches Azure SDK and Requests transport
failures, not arbitrary provider exceptions. An unexpected provider failure
propagates unchanged; do not diagnose it as disabled configuration or successful
empty settings. Distinguish the failure family before applying transport recovery.

**Correct:** Only for the confirmed transport compatibility case, use the
[transport and TLS guidance](application-settings.md#orchestrator-tls-compatibility).
Supply the actual `KEY_VAULT_URI`, deliberately select
`APP_CONFIG_TLS_COMPATIBILITY=true` and deploy a new agent version.
To restore SDK defaults, use `false` and
redeploy. Keep certificate verification, the minimum TLS version and scoped
role assignments intact.

If bootstrap resolves a UI-only secret, inspect the
[actual label selectors](application-settings.md#overrides-and-effective-values): in the SDK,
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
deployment and remaining regional quota. Reprovisioning must use the same
reviewed account and model inputs. Hosted image preparation itself does not
require reprovisioning.

**Correct:** Verify environment, account region, deployment, model/version and
SKU. Preflight credits only verified successful matching capacity and aggregates quota
pools. Fresh allocations and changed/unverified targets still need capacity.
If a matching deployment is not credited, retain the gates and escalate with
sanitized account, region, model and capacity evidence.

**Verify:** Both preflight gates evaluate the intended incremental request.
Retain the existing deployment, intended capacity and preflight gates.
Model availability checks still apply.

When routing all model inference through an external AI Gateway with zero local
Foundry model deployments, set `DEPLOY_MODEL_DEPLOYMENTS=false`
(`deployModelDeployments = false`) before provision so local chat and embedding
deployments and regional model quota preflight checks are skipped while
`config.aifoundry.setup` preserves account-level RAI policies. Features
requiring a local Foundry planning or embedding deployment retain their
validation guards. See
[external AI Gateway mode](configuration.md#model-deployments-and-external-ai-gateway).

#### Foundry network injection or agent subnet change fails

**Symptom:** Reprovisioning fails when changing `EXISTING_VNET_RESOURCE_ID`,
`agentSubnetName` (`AZURE_AGENT_SUBNET_NAME`) or Foundry Agent Service
`networkInjections` on an existing Foundry account or capability host.

**Diagnose:** Microsoft Foundry Agent Service `networkInjections` (`agent-subnet`
binding) is immutable after initial capability-host and account provisioning.
Azure rejects in-place VNet or delegated agent-subnet changes.

**Correct:** Restore the original VNet and `agentSubnetName` to keep the
existing Foundry resource, or plan an owner-approved replacement that recreates
the Foundry resource in the target VNet and `agent-subnet` before capability-host
provisioning.

**Verify:** Confirm the target VNet and `agentSubnetName` match the provisioned
Foundry `networkInjections` binding and `azd provision` completes cleanly.

#### Foundry rejects evaluation API-key creation

**Symptom:** `Failed to list key. disableLocalAuth is set to be true`.

**Diagnose:** The account requires Entra ID. Identify the caller still trying
to obtain an API key.

**Correct:** Keep local authentication disabled and use Entra ID for evaluation.
The supported configuration skips inapplicable key injection. Investigate
unexpected key or Key Vault errors instead of enabling local authentication.

**Verify:** Post-provision reports the expected Entra-only path and evaluation
works with the intended identity while local authentication remains disabled.

#### Required UI metadata database is missing

**Symptom:** Workflow/both or an enabled product feature requires metadata,
but the UI cannot resolve its database account or name.

**Diagnose:** Identify the selected database account and name, then check
process inputs and the settings published in App Configuration.

**Correct:** Confirm the two settings under `agent-lz` for the selected
environment. Setup reads published settings when process inputs are absent.
Resolve missing or conflicting values in their provisioning source.

**Verify:** UI metadata configuration resolves the actual account/database and
preserves container-scoped grants. Compare the resolved names with the
provisioned resources and keep permissions scoped to the required containers.

#### Deployment metadata verification failed

**Symptom:** A `schema`, `source`, `context`, `cache`, `resource` or
`prerequisite` diagnostic stops post-provision, pre-deploy or direct setup.

**Diagnose:** Run the
[read-only metadata check](deployment-operations.md#verify-deployment-metadata).
Deployment discovery uses native provider output, not App Configuration keys.
A missing store is valid in a compatible `containerEnv` selection, but not for
a selected store-dependent runtime or feature.

**Correct:** Restore the intended environment and immutable bindings. Refresh
stale cached outputs. For missing/old metadata, reprovision with compatible
hooks and the same provider, inputs and backend. Repair exact resource/identity
permissions, backend access and private connectivity when those checks fail.
Do not hand-copy metadata, change backend bindings or grant broader roles to
bypass verification.

**Verify:** The metadata check succeeds before retrying the selected operation.

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
the [infrastructure-only deployment guide](deploy-infra-only.md) to generate the required outputs.

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
[foundation workflow](deploy-infra-only.md#review-infrastructure-changes).
For a name conflict, identify the existing resource and its owner before
deciding whether to reuse it or choose another name.

**Verify:** The failed deployment and post-provision configuration both complete.
Then deploy the application and run its authenticated task and access checks.

### Runtime

#### Protected retrieval fails after hosted sign-in

**Symptom:** UI login and a greeting work, but protected Foundry IQ retrieval
lacks delegated user context, is denied or omits documents.

**Diagnose:** Distinguish UI-to-Foundry OBO from downstream source authorization.
The hosted gateway does not forward the caller's `Authorization` header
unchanged. The built-in native path instead uses a separately exchanged Search
token in `x-client-search-token`, followed by
`x-ms-query-source-authorization` at Search.

**Correct:**

1. **Check the implementation.** Confirm the UI and hosted runtime are the
   matching implementation with `RETRIEVAL_AUTH_MODE=native_search`.
2. **Check the delegated retrieval path.** Review delegated Search consent,
   the authenticated UI assertion/refresh, supported custom-header forwarding,
   source permission metadata and private connectivity.
3. **Match recovery to the failure.** A transport-role denial and a user's
   source denial are different failures:

    **Consent or Conditional Access:** Use the UI's explicit authentication
    recovery action. Standalone sessions complete the configured OAuth
    callback; embedded sessions use portal MSAL and authenticated bootstrap.

    **Source `403` without usable claims:** Diagnose source access rather
    than repeating sign-in.

4. **Submit a new turn after authentication recovery.** The failed turn is
   not automatically replayed.

!!! warning "Do not bypass user authorization"
    Do not log tokens or claims challenges. Do not invent identity headers,
    enable anonymous retrieval or replace the user with a service identity.
    Stop sensitive-data rollout until denial works.

**Verify:** Use two users with different source permissions and confirm
permitted retrieval and denial through the actual UI or channel, including
references and downloads. A unit test or successful greeting is not
authorization evidence for a deployed source.

#### A protected citation download is denied

**Diagnose:** Shared Blob/ADLS citation reads require the current user's
Storage OBO, delegated `user_impersonation` consent and source RBAC/ACLs.
Knowing the URL or possessing an old signed selector is not sufficient.
Native private attachments are inline inputs, not Blob/SAS downloads or
Search-indexed conversation uploads.

**Correct:** Sign in again after session expiry and resolve consent or source
permissions at their own boundary. Confirm the configured storage locations,
Search index and bundled UI `retrieval-reader` profile. The native route
limits a download to 100 MiB and 120 seconds. An unverified target beyond
those bounds is denied, not read with elevated access.

Do not re-enable the legacy reader, mint SAS or replace user Storage access
with workload access to make the download succeed.

**Verify:** Repeat allowed/denied-user, expiry and permission-revocation checks
through the authenticated citation route. Test private attachments separately
using their supported inline formats and denied cross-owner session.
See [protected citation downloads](application-auth.md#protected-citation-downloads).

#### The orchestrator returns HTTP 422

**Symptom:** The agent rejects a request with validation details.

**Diagnose:** Check the selected native client, application kind and typed
input. Hosted Responses and the durable client have different contracts.
A workflow's initial input and its pending human reply are also different
operations. A native session/run ID selects execution; it does not establish
ownership or replace the pending request ID.

**Correct:** Use the returned validation detail and the correct
[native client contract](application-api.md). Do not send a retired strategy-specific
ask envelope to a native entrypoint, strip native state selectors to force
stateless execution, or manufacture a human reply for a different request.

**Verify:** A request in the intended endpoint's format succeeds through that endpoint.

#### Hosted chat works but history is unavailable

**Symptom:** A greeting works, but saved history is unavailable.

**Diagnose:** Separate native execution continuity from saved-history discovery.
Foundry owns Hosted state; DTS owns Container Apps durable state.
The UI/BFF owns the authenticated owner map and display metadata.
A successful greeting does not prove that the metadata store, native state
read and owner-bound resume path are ready. An administrative panel is not
required to obtain native persistence.

**Correct:** Check the selected publication or durable registration, current
identity, owner mapping, metadata dependency and native client permissions.

Saved listing/history requires `ENABLE_CHAT_HISTORY=true`; known workflow
resume does not. With conversational mode and all product flags off, bounded
volatile UI owner maps are lost on restart. Native state does not reconstruct
them.

Follow [Conversations & files](conversations.md) and
[Agent hosting](hosted-agents.md#calling-the-agent).

Report a failed state read rather than presenting empty history or replaying
a UI transcript as a replacement execution store. Switching hosts does not
import a session from the previous backend.

**Verify:** Open a saved conversation in a new session as its owner and confirm
the transcript is available. Repeat as another user and confirm access is denied.

#### The application starts but does not answer

**Symptom:** The application loads but an authenticated task fails.

**Diagnose:**

1. Confirm the intended image and revision or routed hosted version using
   [health checks](#check-application-health).
2. Read startup and request logs using [correlated diagnostics](#monitoring).
3. Inspect the effective configuration using the
   [actual component selectors](application-settings.md#overrides-and-effective-values).
4. Follow the first failing model, retrieval, tool or identity dependency.

**Correct:** Repair the identified dependency, then use the appropriate
[runtime-setting lifecycle](deploy-full-stack.md#change-a-runtime-setting)
or [redeployment](deploy-full-stack.md#redeploy-applications-only).
Use provisioning for infrastructure changes and a new process or hosted version
for startup settings, as specified in those workflows.

**Verify:** Repeat the same authenticated task and test document authorization
when retrieval is involved. Keep credentials and content out of diagnostics.

#### Agent App MCP failures

Start at the first failed boundary, not the UI symptom. A successful
`/healthz` probe establishes liveness only.

| Symptom | Check | Correct safely |
| --- | --- | --- |
| Entra setup fails during deploy | Deployer's directory rights for API registration/service principal and app-role assignment | Arrange required directory permissions; ARM Contributor alone is insufficient |
| Authenticated discovery returns no tools | Effective startup `MCP_TOOLSETS`, default `[]` | Empty server is supported. For SQL, explicitly set `["nl2sql"]` before provision/deploy and restart/redeploy; server compute does not imply SQL |
| Toolset selection fails at startup/preflight | JSON array shape, supported names and duplicates; reference server compute selection | Use `[]` or `["nl2sql"]`; unknown/duplicate/invalid values fail closed. Reference apps require compute selection for nonempty toolsets |
| Custom application rejects reference compute selection | Selected `AGENTLZ_APP_DEFINITION` and `DEPLOY_AGENT_APP_MCP` | Remove the reference compute switch. Custom apps may explicitly supply `MCP_TOOLSETS` with their own compute/configuration/dependency/grant declarations |
| MCP discovery returns 401/403 | Actual caller, tenant, v2 audience, allowed client ID and `MCP.Invoke` role | Repair the generated identity/assignment through the platform lifecycle; do not accept an ARM token, API key or user-context JSON |
| NL2SQL Cosmos selection conflicts | Deliberately set or persisted `DEPLOY_COSMOS_DB=false` | Unset the declaration for automatic selection or set it to `true`; an empty server does not need the catalog |
| Vector provisioning fails | Throughput compatibility, preserved capabilities, model dimensions and new-container policies | Review compatibility; do not recreate accounts/containers or convert throughput as a retry |
| Catalog name/dimension change is rejected | Existing catalog declarations and selected embedding model | Arrange explicit migration/reindexing; in-place name/dimension changes are not a supported retry |
| Sources are absent or metadata is incomplete | Enabled approved source and active, completely imported metadata version | Complete the administrative import; provisioning does not discover SQL schemas |
| SQL connection or authorization fails | MCP identity/secret, SQL read principal, approved objects, DNS, routes and TLS | Obtain SQL-owner-approved read access or fix the declared network/secret; do not grant SQL access to the orchestrator |
| Query exceeds a limit | 30-second SQL, 1,000-row and 256-KiB result limits; 75-second default complete deadline | Ask a narrower question or repair the dependency; never silently truncate or fabricate rows |

Preserve source and object denial. There is no direct SQL fallback inside the
orchestrator. Cancellation must not close cursor/connection resources while
an ODBC worker is still running and does not guarantee instant SQL-server
cancellation.

Verify authenticated discovery and denied callers even for an empty server.
With NL2SQL selected, also check a known approved result, denied objects
and explicit limit/error behavior after repair. Use query IDs and metadata
versions without logging tokens, SQL or business rows.
See [SQL failure handling](nl2sql.md#failures-cancellation-and-cleanup).

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
| Key Vault Secrets User | Required secrets or selected Key Vault | Resolve references only for components that actually consume those secrets |

Additional grants depend on declared profiles, selected resources and topology.
Hosted bootstrap, native invocation, product metadata and panel permissions are
reconciled separately.
Use the relevant workflow to grant only the roles required by the actual caller.

When model or tool calls traverse an AI Gateway and return HTTP `401` or `403`,
confirm that each hosted agent's **dedicated runtime identity** (created on
first `azd deploy` publication, including both publications when
`APPLICATION_MODE=both`) is allowlisted at the AI Gateway rather than only the
Foundry project identity.

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
claim, signed-URL or document logging to fill that gap.

A failed optional panel
index write needs repair even when the chat continues. Confirm the expected
owner-index record exists after retrying the write.

Telemetry content capture is off by default. Keep prompts and answers private;
diagnose with request references and dependency status.

#### Foundry portal Operate, Traces or hosted evaluations fail

**Symptom:** Foundry portal **Operate** or **Traces** views fail to load in an
isolated network, `responseCompleted` continuous evaluation rules fail on hosted
agents, or scheduled trace evaluations return authorization errors or skewed
scores.

**Diagnose:** Separate human operator AMPLS connectivity and RBAC from hosted
evaluation configuration:

- **Portal Operate and Traces in isolated networks:** human operators need VPN or ExpressRoute connectivity with Private DNS Resolver forwarding to the AMPLS endpoints (`privatelink.monitor.azure.com` and companion `opinsights`, `agentsvc.azure-automation.net` and `blob` zones), BYO hub firewall HTTPS (`443`) access to Azure Monitor ingestion and query endpoints, and `Log Analytics Reader` on Application Insights and its workspace (plus `Privileged Monitoring Data Reader` when `AppGenAIContent` is `Protected`).
- **Hosted agent evaluations:** `responseCompleted` continuous evaluation rules are not supported for hosted agents, and custom hosted handlers without `azure-ai-agentserver-responses` or OpenTelemetry `invoke_agent` spans produce no evaluation traces.

**Correct:**

- Verify AMPLS DNS resolution, firewall query rules and operator Azure Monitor roles using [Administration](operations.md#inspect-operate-and-traces-in-isolated-networks).
- Switch hosted evaluations to **scheduled trace evaluations** (`azure_ai_traces`), ensure custom hosted agents use `azure-ai-agentserver-responses` (which serves persisted `GET /responses/{id}` lookups and emits `invoke_agent` spans automatically when `APPLICATIONINSIGHTS_CONNECTION_STRING` is injected), and check per-item `gen_ai.agent.version` (`FOUNDRY_AGENT_VERSION`) and non-empty output across rolling lookback windows.
- Opt in to `GRANT_PROJECT_TRACE_EVALUATION_READER=true` (and strictly opt-in `GRANT_PROJECT_PROTECTED_TRACE_CONTENT_READER=true` with its ABAC v2.0 `AppGenAIContent` condition only when protected content reads are approved) before running `azd provision`.

**Verify:** Confirm **Operate** and **Traces** render for an authorized
connected operator and scheduled `azure_ai_traces` runs score only non-empty
spans from the intended `FOUNDRY_AGENT_VERSION`.

## Validation

1. Repeat the exact operation that failed, from the intended host and identity.
2. Confirm the intended source commit, immutable image and routed hosted version
   or Container App revision. A placeholder response is not application health.
3. Test user sign-in, the required tool or retrieval operation, and allowed and
   denied access to protected data. Treat an unexpected allow as a failure;
   preserve source permissions while correcting it.
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
- [Full-stack deployment guide](deploy-full-stack.md)
- [Deployment settings](configuration.md)
- [Network design](network-isolation.md)
- [Ingestion](ingestion.md)
