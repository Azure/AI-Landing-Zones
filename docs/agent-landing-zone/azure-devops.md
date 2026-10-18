# Deploy applications with Azure DevOps

Use this optional CI/CD runbook when you want to promote one reviewed application
revision through **DEV → TEST → PROD** with protected approvals. It automates the
platform's application and foundation lifecycle; Azure DevOps is not required
for an interactive deployment.

For interactive execution, use [Deploy infrastructure only](deploy-infra-only.md)
or [Deploy the full stack](deploy-full-stack.md). For component changes, see
[Custom applications](build-your-own-app.md#customize-a-bundled-component).

!!! info "Choose the right pipeline"
    The downloadable example below verifies the **same source commit in every
    job** and enforces successful prior stages. It is not a build-once image
    promotion pipeline. The separate [foundation pipeline guide](../bicep/deploy-with-azure-devops.md)
    explains upstream service connections and Environment setup; those assets
    provision infrastructure only, allow independent environment selection and
    do not automatically execute their preview template.

## 1. Prepare the repository and runners

Use your reviewed platform revision. Keep
`manifest.json`, `app-definition.json`, `main.parameters.json`,
`azure.yaml`, `infra/`, `config/`, `contracts/` and `scripts/` together at its root.
Infrastructure is incorporated under `infra/`; do not deploy it from a second
foundation checkout. Commit your configuration and compatible component pins
before queuing a pipeline. Do not commit credentials or local azd environments.

The downloadable example initially deploys the **bundled application** with
`hosted-no-panel`, native Blob ingestion and private endpoints. Set the same
reviewed topology and ingestion selection across the three environments:

| Input | Choices and effect |
| --- | --- |
| `DEPLOYMENT_TOPOLOGY` | `hosted-no-panel`, `hosted-panel`, or `classic`. Classic runs orchestration in Container Apps. |
| `HOSTED_AGENT_RESOURCE_SCOPE` | Required **before first provision** for hosted modes: the deployed Foundry delegated-user audience followed by `/.default`. It has no implicit runtime default. |
| `DEPLOY_INGESTION_CONTAINER_APP` | Explicit `'false'` in this example; set `'true'` if the optional app and conversation uploads are required. Native source ingestion is not feature-equivalent. Retain an existing environment's selection during upgrades. |
| `NETWORK_ISOLATION` | Explicit `'true'`. Do not change it merely to make a pipeline pass. |
| `BUILD_MODE` | `acr-task`; private image builds use the foundation's ACR Tasks pool. Local Docker is not required. |

See [Configuration](configuration.md), [Hosted agents](hosted-agents.md) and
[ingestion compatibility](configuration.md#ingestion-application-selection).
An explicit topology overrides legacy flags; fresh environments otherwise default
to hosted, existing recorded topologies remain sticky, and unmarked older
environments are treated as classic. This example deliberately makes the choice
explicit: **do not use it to switch an existing classic environment to hosted**
without the migration and recovery review.

### Runner requirements

Create authorized **Linux self-hosted Azure Pipelines agent pools**, with a runner
able to reach each environment's private endpoints through its VNet or a peered
hub/VPN. Bootstrap the deployment network before this full-stack pipeline: an
agent cannot depend on the VNet it is about to create to become reachable.
Use [Network isolation](network-isolation.md) for DNS, routing and egress checks.
The CI-only pool need not reach Azure data-plane endpoints.

Every runner needs Bash, PowerShell 7 (`pwsh`), jq, Git, curl, Azure CLI with Bicep,
Azure Developer CLI (`azd`), and Python **3.12+ with pip and venv**. Hosted deployment
also needs an azd version supporting the pinned `hosted-agent/azure.yaml` service.
Install and pin approved tool versions in your agent image; record them in your
release evidence. Populate the self-hosted agent's Python tool cache for
`UsePythonVersion@0` (`3.12`), rather than assuming it can install Python.
Allow package, source and container-build dependency egress. Hooks themselves
bootstrap a temporary pip environment during post-provision.

From the agent's Bash shell, verify:

```bash
python3 --version
pwsh --version
jq --version
git --version
az version
az bicep version
azd version
```

The YAML uses **`pool.name`**, not `pool.vmImage`. A private ACR Tasks agent pool
is a different resource from an Azure Pipelines agent pool: it builds images,
but does not run azd, topology discovery or post-provision hooks. A Microsoft-hosted
public agent is not the default private deployment runner. For an intentionally
public deployment, review network inputs and runner policy separately.

Use dedicated, preferably ephemeral agents. `workspace.clean` isolates jobs;
the final cleanup removes only explicitly listed runtime state directories and
temporary tool configuration, leaving source checkouts intact. Do not place
unrelated files in the agent workspace or run untrusted pull requests on
deployment agents.

## 2. Establish identities and permissions

Create an **Azure Resource Manager workload identity federation (WIF)** service
connection per environment, following the foundation setup. Restrict each
connection to this pipeline and its target subscription/scopes. The
`AzureCLI@2` task authenticates noninteractively; all azd and hook commands run
inside it, with `azd config set auth.useAzCliAuth true`. Do not add interactive
`az login`, `azd auth login`, client secrets or exported federation tokens.

Set `AZURE_PRINCIPAL_ID` to the connection identity's **enterprise application /
service principal object ID**, not its application/client ID or app-registration
object ID. Set `AZURE_PRINCIPAL_TYPE=ServicePrincipal`; the default parameter type
is `User` and is wrong for this job. A connection that can read the subscription
does not necessarily have deployment or data-plane permissions.

Have an administrator approve the minimum role plan:

| Identity | Required access to review |
| --- | --- |
| Deployment service principal | Contributor for resource deployment plus scoped role-assignment authority (for example User Access Administrator) wherever Bicep and hooks create grants. Subscription-scope deployments, provider registration and hub/shared resources can require additional scope; use the foundation guide's scope review. Do not solve data-plane denials by adding Owner. |
| Deployment service principal, configuration/build operations | App Configuration Data Owner for publishing settings; required Key Vault secret access when resolving references; Search service/index configuration permissions and the Foundry configuration/model/deployment actions used by the enabled hooks. ACR Tasks build/run and registry/Container Apps update permissions must also be authorized. These are separate from ARM Contributor. Check the effective grants from Bicep for the explicit principal and add only missing scoped roles. |
| Deployment service principal, hosted authoring | Foundry User (previously Azure AI User) on the exact project, plus account read access; authority to create the scoped runtime assignments in the [hosted access plan](hosted-agents.md#bootstrap-the-agents-runtime-access). Cognitive Services Contributor/OpenAI User alone do not grant hosted-agent data-plane authoring. |
| Runtime managed identities | [Capability-profile roles](build-your-own-app.md#capability-profiles) and separate [hosted project/image-pull/runtime grants](hosted-agents.md#bootstrap-the-agents-runtime-access). Do not substitute the pipeline identity for the runtime identity. |
| Delegated application users | Application consent, Foundry caller/agent access where applicable, and the intended source/document permissions. Pipeline success grants none of these to users. |

Also confirm service/model availability, quota, provider registration and Responsible
AI acceptance in each target subscription. Do not set preflight bypass flags to
work around an unattended failure. Allow RBAC propagation before retrying.

### Complete the application sign-in setup separately

The pipeline service connection is **not** the UI's Entra application registration.
The inspected root configuration and pinned UI deployment scripts do not create
that registration or grant tenant consent. Arrange this with an Entra administrator
for each isolated application environment:

1. Create the confidential application registration; expose its
   `api://<client-id>/user_impersonation` scope and request version-2 access tokens.
2. Register the final HTTPS UI URL with `/auth/oauth/azure-ad/callback`.
   Set `CHAINLIT_URL` to that canonical HTTPS origin without a trailing slash.
   For a first deployment, discover the assigned frontend URL, finish this setup,
   and restart the UI before accepting DEV.
3. Create/rotate its client credential under tenant policy. Store it in Key Vault,
   publish a **Key Vault reference** as `OAUTH_AZURE_AD_CLIENT_SECRET`, and publish
   `OAUTH_AZURE_AD_CLIENT_ID`, `OAUTH_AZURE_AD_TENANT_ID` and
   `OAUTH_AZURE_AD_SCOPES` under App Configuration label `agent-lz`.
   Keep `CHAINLIT_AUTH_SECRET` stable and protected as well.
4. Configure and consent the downstream delegated permissions for the deployed
   audience, including Foundry OBO for hosted mode. Graph scopes are not a
   replacement for the UI's single-token API scope. Grant intended caller access.
5. Review conflicting unlabelled/service settings, restart affected components,
   then perform actual user sign-in and document allow/deny tests.

Follow [delegated authentication](hosted-agents.md#configure-the-uis-delegated-authentication)
for the exact keys and consent boundaries, and
[runtime settings](configuration.md#runtime-settings) for publishing/restart behavior.
Tenant consent and this configuration are an **unattended onboarding gap**, not
work automatically performed by YAML or by granting Azure subscription roles.
Use a separately reviewed administrative procedure or automation; do not give
the deployment connection broad Microsoft Graph permissions to hide the gap.

## 3. Fill the pipeline inputs

Download both files, then place them beside each other in **`.pipelines/` in your
platform repository**, not in its `infra/` folder:

- [azure-pipelines.yml](examples/azure-devops/azure-pipelines.yml)
- [deploy-stage.yml](examples/azure-devops/deploy-stage.yml)
- Optional local check: [validate.py](examples/azure-devops/validate.py)

Replace the following values before authorization. DEV, TEST and PROD must have
separate resource groups, azd environments, connection identities, configuration
stores, secrets and data. Apply the
[environment boundaries](configuration.md#environment-boundaries), including
runtime identities, sign-in, test data and network isolation.

Never copy DEV's `.azure` state into TEST or PROD. Initialize or securely restore
the intended environment on each runner, refresh its outputs when needed and
reapply approved inputs. Keep `.azure` and sibling child state private.

| Exact example input | Required replacement / source |
| --- | --- |
| `REPLACE_CI_LINUX_POOL` | Authorized Linux validation pool with the toolchain above. |
| `REPLACE_DEV_VNET_LINUX_POOL`, `REPLACE_TEST_VNET_LINUX_POOL`, `REPLACE_PROD_VNET_LINUX_POOL` | Authorized, connected Linux deployment pool for each target. May be the same pool only if its connectivity and isolation policy cover all targets. |
| `REPLACE_DEV_WIF_SERVICE_CONNECTION`, `REPLACE_TEST_WIF_SERVICE_CONNECTION`, `REPLACE_PROD_WIF_SERVICE_CONNECTION` | Exact Azure DevOps WIF service connection names, authorized for this pipeline only. |
| `REPLACE_DEV_SUBSCRIPTION_ID`, `REPLACE_TEST_SUBSCRIPTION_ID`, `REPLACE_PROD_SUBSCRIPTION_ID` | Target subscription GUIDs matching those connections' allowed scopes. |
| `REPLACE_DEV_RESOURCE_GROUP`, `REPLACE_TEST_RESOURCE_GROUP`, `REPLACE_PROD_RESOURCE_GROUP` | New target names for first provision, or the exact previously azd-provisioned groups for redeployment. |
| `REPLACE_DEV_REGION`, `REPLACE_TEST_REGION`, `REPLACE_PROD_REGION` | Supported foundation locations (`AZURE_LOCATION`). |
| `REPLACE_DEV_FOUNDRY_REGION`, `REPLACE_TEST_FOUNDRY_REGION`, `REPLACE_PROD_FOUNDRY_REGION` | Foundry/model locations with quota (`AZURE_AI_FOUNDRY_LOCATION`). |
| `REPLACE_DEV_COSMOS_REGION`, `REPLACE_TEST_COSMOS_REGION`, `REPLACE_PROD_COSMOS_REGION` | Cosmos locations supported by the selected topology/foundation (`AZURE_COSMOS_LOCATION`). |
| `REPLACE_DEV_SERVICE_PRINCIPAL_OBJECT_ID`, `REPLACE_TEST_SERVICE_PRINCIPAL_OBJECT_ID`, `REPLACE_PROD_SERVICE_PRINCIPAL_OBJECT_ID` | Connection service principal **object IDs**; keep `AZURE_PRINCIPAL_TYPE: ServicePrincipal`. |
| `REPLACE_DEV_HOSTED_RESOURCE_SCOPE`, `REPLACE_TEST_HOSTED_RESOURCE_SCOPE`, `REPLACE_PROD_HOSTED_RESOURCE_SCOPE` | Explicit delegated-user Foundry scope ending in `/.default`, matched to the deployed audience and consent (for example `https://ai.azure.com/.default` where that is the target audience). Required for both hosted topologies before provisioning; not the UI's `api://<client-id>/user_impersonation` scope. Classic does not consume this hosted input. |
| `environment: agentlz-dev`, `agentlz-test`, `agentlz-prod` | Precreated Azure DevOps Environment resource names. Rename consistently if required; these are approval resources, not azd environments. |
| `AZURE_ENV_NAME: agentlz-dev`, `agentlz-test`, `agentlz-prod` | Unique azd names, retained exactly for subsequent refresh/deploy runs. |
| `variableGroup: agentlz-dev-secrets`, `agentlz-test-secrets`, `agentlz-prod-secrets` | Create these Library variable groups and authorize only this pipeline. Each must contain the secret variable `AGENTLZ_SECRET_SETTINGS_JSON`, initially the string `{}`. |
| `AGENTLZ_SECRET_SETTINGS_JSON` in each group | JSON object of additional documented azd/hook inputs, with string values. It cannot override the inline deployment controls. Empty `{}` is valid for the bundled example. This is **not** automatic publication of OAuth/runtime settings or a private Git credential mechanism. |
| Inline `settings` in each stage | Review topology, ingestion, isolation and regional settings. Add required [configuration](configuration.md) inputs for your approved network, source, models or reused resources. Keep nonsecret configuration reviewable here; never put secret values in YAML. |

The `settings` maps are intentionally inline, not an unexplained external
configuration file. Values are reapplied after environment refresh on every job.
`RUN_FROM_JUMPBOX=true` **requires** the connected-host check; it does not create
connectivity. The example leaves `AZURE_SKIP_NETWORK_ISOLATION_WARNING=false`.
The inspected POSIX preProvision hook's interactive warning checks the legacy
`AZURE_NETWORK_ISOLATION` variable, not the example's `NETWORK_ISOLATION` input.
Do not inherit that legacy alias in the runner or environment. If an existing
workflow must retain a truthy legacy alias, explicitly review setting the warning
flag to `true` for unattended execution while retaining `RUN_FROM_JUMPBOX=true`.
The warning flag alone can defer configuration when `RUN_FROM_JUMPBOX` is not
truthy; never use that combination as a private deployment shortcut.

Protect variable-group edits as well as YAML changes. Secret masking is not a
data-loss prevention system; keep pipeline debug and shell tracing off.
Use Key Vault references for runtime secrets instead of literal secret JSON
wherever the contract supports them.

### Private component repositories and custom definitions

The platform connection authenticates **Azure**, not GitHub or Azure Repos Git.
See [Private Git authentication](build-your-own-app.md#private-git-authentication)
for repository access.
The root deploy hook clones selected bundled components as **sibling checkouts**
using manifest repository/tag pins, then verifies the expected commit. Use
approved read-only Git credentials for those private repositories separately.
The example does not install a private-Git credential: before adopting private
component pins, add your organization's reviewed, job-scoped credential-helper or
SSH-agent/known-host setup **inside the authenticated task**, with guaranteed
cleanup. Test the exact repository/tag access without printing tokens. Source
checkout authorization alone does not authorize the hook's new clones.

Never put tokens in manifest URLs, command-line URLs, `url.insteadOf` global
configuration, `.azure`, or downloadable artifacts. Keep `persistCredentials:
false`; the example uses a temporary `GIT_CONFIG_GLOBAL` because hooks can write
safe-directory entries. Do not rely on an agent owner's persistent Git credentials.
If using an Azure Repos job token, separately grant the build identity read access
to the required repositories and review job-token scope before explicitly mapping
it into the credential mechanism. It is not a GitHub credential.

For a [custom application](build-your-own-app.md), adapt CI validation to the
selected definition and add `AGENTLZ_APP_DEFINITION` to each stage **before first
provision**. Keep the application ID stable. Custom definitions accept **local
sources or immutable image digests**, not remote repository URLs.

Materialize local source in every job with a clean Git checkout at its declared
`source.commit`, preserving `.git` metadata and the definition's relative layout.
Explicitly check out pinned component repositories or pinned submodules if needed,
using the separate Git credentials above. Do not feed these hooks a `git archive`
tree without Git metadata: they check the component's actual `git rev-parse HEAD`.
Source commit checks do not reject uncommitted edits; validate clean trees.

Extend the template's fixed cleanup list with the custom definition folder's
explicit `.azure` and `.logs` paths; never add a source or workspace root.

Custom hosted services follow their own definition/image contract, not an assumed
bundled orchestrator build. The downloaded template's preparation branch is for
the bundled application; replace that branch with the documented custom hosted
workflow before using it for a custom hosted definition.

## 4. Protect and register the pipeline

1. In **Pipelines → Environments**, create the three exact Environment names.
   On **agentlz-test** and **agentlz-prod**, configure **Approvals and checks** outside
   YAML, with accountable reviewers, no self-approval where policy requires it,
   and restricted administrator/pipeline permissions. Approval for TEST accepts
   DEV evidence; approval for PROD accepts TEST evidence. Configure branch control
   and an exclusive lock where appropriate, and avoid overlapping release runs.
2. Authorize this pipeline, not all pipelines, to use the environments, pools,
   WIF connections and variable groups. Protect the release branch and require
   review of pipeline/template changes.
3. In **Pipelines → New pipeline**, select your platform repository and
   **Existing Azure Pipelines YAML file**, then `.pipelines/azure-pipelines.yml`.
   Save it without starting a production run until all inputs/checks are ready.
4. Queue a run from a reviewed branch/commit. This sample has no automatic trigger.
   Leave **all stages selected**; never use stage selection as a promotion bypass.

CI validates the application definition and manifest JSON, installs the hook
dependencies, and compiles Bicep without deploying. It is not a complete security
scan, Bicep what-if, Azure readiness test, or real-user acceptance test. Add your
existing unit/contract tests and review gates before extending it.

Each deployment stage requires `succeeded()` **and an explicit result equal to
`Succeeded` for every prerequisite**. `Failed`, `Canceled`, `Skipped` and
`SucceededWithIssues` cannot promote. Do not replace these conditions with
`always()`, `succeededOrFailed()` or independent stage-selection parameters.
Azure DevOps Environment approvals remain external protected-resource checks;
the YAML does not create or prove their existence.

## 5. Understand what runs on a fresh job

The template checks out `Build.SourceVersion` again and fails if `HEAD` differs.
It activates Python 3.12 and installs `config/requirements.txt` **in that job**;
a CI virtual environment is not available on a later agent.

Inside `AzureCLI@2`, it initializes a local azd environment (or explicitly selects
one already present), sets the intended resource group, and checks group existence:

- **New group:** no refresh is attempted before the first provision.
- **Existing group:** `azd env refresh --environment <name> --no-prompt` must reload
  the previous azd deployment outputs. Access, discovery or refresh errors fail
  the job; there is no `|| true`. An existing empty/unrelated resource group is
  not a prior azd deployment. Use a fresh target for this example or explicitly
  onboard/review the existing foundation before using it.

The same azd name and subscription must locate the previous deployment. Review
the refreshed target and outputs for an existing environment; do not create a
second deployment by renaming the environment. Local `.azure` is disposable here,
not a promoted artifact or backup. Review migration state and application binding
before adopting an existing environment into CI.

After refresh, reviewed environment settings are applied, then the template runs:

| Topology | Ordered commands from the platform root |
| --- | --- |
| Classic | `azd hooks run preup --no-prompt` → `azd provision --no-prompt` → `azd deploy --no-prompt` |
| Bundled hosted | `azd hooks run preup --no-prompt` → `azd provision --no-prompt` → `bash scripts/prepareHostedDeployment.sh` → `azd provision --no-prompt` → `azd deploy --no-prompt` |

Preup validates/checks binding before standalone provisioning. Preprovision
resolves topology using `python -m config.deployment.topology` and composes
`infra/main.parameters.json`; subsequent hooks use `--describe` to read its JSON.
Post-provision configures application services and roles. The first hosted
provision prepares prerequisites, preparation records an image digest, the second
provision materializes that digest in the deployment handoff, and deploy creates
the hosted version plus the other selected components.

This full workflow is deliberately repeatable on fresh agents. A hosted
preparation may reuse a compatible digest when its provenance is available, but
disposable local state and different environment registries can cause rebuilding.
Bundled Container App scripts build per environment. **This is immutable source
promotion, not build-once immutable-image promotion**: mutable base images, package
feeds, tool versions, generated configuration and credentials can affect results.
Pin dependencies/base images and record actual image digests per environment.
If identical images are mandatory, design and validate a separate digest-based
application contract and cross-registry availability/permissions; do not claim
this source workflow already provides it.

No build artifacts are published or downloaded. Do not add a whole-workspace
publish step: hooks copy `.azure` to sibling components and create `.logs`.
Exclude `.azure`, `.env`/environment files, logs, secret files, credential/config
caches, `.git` credentials and Python dependency environments from any future
artifact. If changing to CI artifacts, deploy from the downloaded validated tree
and explicitly solve the Git metadata requirement for local custom sources.

Cleanup runs even after failure. Its fixed path list removes `.azure` and `.logs`
from the platform root, `hosted-agent/`, and the three manifest component sibling
checkouts (`agent-app-ui`, `agent-app-orchestrator`, `agent-app-ingestion`).
It leaves their source files intact and removes the job-specific temporary Python
environment, azd config and Git config. Update the explicit state-directory list
when changing component names or adding a custom definition folder; do not replace
it with recursive deletion of source/workspace roots. AzureCLI@2 owns its isolated
Azure CLI authentication context. Abrupt agent loss can prevent cleanup:
reimage ephemeral agents or securely clean their disks before reuse.

## 6. Verify DEV, approve TEST, then approve PROD

Expected pipeline results are a green CI job, successful DEV deployment, TEST
waiting for its protected Environment check, then PROD waiting after successful
TEST. Check the recorded `Build.SourceVersion` and reviewed manifest pins; do not
approve a different run just because its branch name is the same.

Before each promotion, record the following against the preceding environment
in your release evidence:

1. `azd env get-value AZURE_RESOURCE_GROUP` identifies the intended target.
   App Configuration has the expected platform outputs and effective settings
   under label `agent-lz`; the selected apps have real, healthy image revisions,
   not just provisioned placeholders. Record image digests and hosted routed version.
2. Complete Entra setup above. Verify HTTPS login/callback, authenticated API
   access and (for hosted mode) real-user OBO invocation. The hook's managed-identity
   greeting alone is not proof of these.
3. Ingest a controlled document through the selected configured source. With an
   authorized user, retrieve its expected content/citations. With a user lacking
   that document's permission, verify the content is not returned. Also verify
   unauthenticated requests are rejected where required. Check that logs do not
   contain tokens or protected document bodies.
4. Exercise selected ingestion/upload, history, panel and continuity features;
   check disabled surfaces are actually unavailable. Native Blob ingestion does
   not imply conversation uploads work without the optional app.
5. Inspect service health, RBAC and private endpoint resolution, and attach
   sanitized evidence to the run/change record. See
   [application health and diagnostics](troubleshooting.md) and
   [document authorization guidance](hosted-agents.md#configure-the-uis-delegated-authentication).

Do not approve TEST or PROD until the preceding environment meets these checks.
Hook exit status is necessary but not sufficient: some post-provision setup
sections currently log a configuration failure and continue. Add organization-owned
acceptance checks before promotion; this sample does not pretend those sections
are fail-closed end-to-end tests.

## Troubleshoot, redeploy and recover

| Symptom | Action |
| --- | --- |
| Connection login fails, or azd asks for sign-in | Verify WIF issuer/subject/audience, pipeline authorization and connection scope. Keep azd CLI-auth configuration and commands inside the authenticated task. Do not add interactive login. |
| ARM succeeds but App Configuration/Search/Foundry returns 403 | Check the **deployment principal's** scoped data-plane roles and propagation. For hosted authoring, check exact project access. Do not substitute subscription Owner or disable authorization. |
| Private DNS/connectivity check fails | Verify the Azure Pipelines runner's network/DNS/firewall path. An ACR Tasks pool does not connect the pipeline agent. Keep post-provision nondeferred. |
| Refresh fails | Check the azd environment name, subscription, prior deployment and read permission. Stop; do not swallow the error or silently provision another group. |
| Stale sibling checkout / source mismatch | Use the clean workspace and exact manifest/local source commits. Do not remove commit validation or update pins only in PROD. |
| Hosted handoff/digest missing | Complete provision → prepare → provision → deploy; see [hosted redeployment](hosted-agents.md#redeploy-the-same-image-or-prepare-a-new-one). Do not skip the second provision after a source change. |
| Green deploy but UI login/retrieval fails | Complete registration/consent/runtime settings, inspect sanitized hook/service logs and run the real-user positive/negative checks. See [Troubleshooting](troubleshooting.md). |
| TEST or PROD starts without the expected approval | Stop the run and fix Environment checks/permissions outside YAML before restarting. |

For an application-only redeployment with unchanged compatible foundation/binding
and hosted handoff, use the same initialization/authentication procedure and
`azd deploy`, following [Redeploy applications only](deploy-full-stack.md#redeploy-applications-only).
Do not replace full provisioning with deploy-only for infrastructure, RBAC,
topology or ingestion-selection changes.

For recovery, select the last accepted **complete pinned combination** and
review configuration/data compatibility before rerunning the protected flow.
Follow [Roll back to a previous release](deploy-full-stack.md#roll-back-to-a-previous-release).
Rechecking an old commit does not reverse schema, infrastructure or data changes.
Back up required data/configuration under a separate authorized process, retain
known-good images, and do not use `azd down --purge` as rollback.

## Local example validation

With Python and PyYAML installed, run from the downloaded example directory:

```bash
python -m pip install PyYAML==6.0.3
python validate.py
```

This checks YAML/template wiring, stage conditions against prerequisite result
combinations, embedded Bash/Python syntax, and the exact cleanup targets with
`rm` intercepted (no real deletion) without Azure. It is not the Azure
DevOps template-expansion service and cannot check real service connections,
approvals, RBAC, private connectivity, tenant consent or application behavior.
The example has not been executed against Azure or registered as a live pipeline
as part of this documentation change.
