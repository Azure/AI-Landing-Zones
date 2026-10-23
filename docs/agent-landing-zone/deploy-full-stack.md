<span id="full-stack-deploy"></span>

# Deploy the full stack

## Objective

Deploy the Azure foundation and the Agent Application: Agent App UI, an
orchestrator and, when selected, Agent App Ingestion. Choose where the
orchestrator runs and how the deployment connects to Azure before provisioning.

## When to use

Use this runbook for a new Agent Application deployment or to add it to its
already configured Agent foundation. For a customer-owned application, use
[Bring your own app](build-your-own-app.md) for its deployment branch.
Only need the foundation? Use [Deploy infrastructure only](deploy-infra-only.md).
For the relationship between the template, its manifest and lifecycle hooks,
see [How the template works](how-it-works.md).

## Prerequisites

- **Permissions:** Owner, or Contributor plus User Access Administrator, at the
  required deployment scopes. Shared networks, DNS and monitoring can require
  additional permissions in their own scopes. See [Permissions](../bicep/permissions.md).
- **Subscription readiness:** accepted Responsible AI terms, registered resource
  providers, supported service/model regions and sufficient quota for the
  selected parameters. [Regional considerations](../bicep/regional-considerations.md)
  explain why passing preflight does not guarantee available capacity.
- **Private deployments:** an authorized VPN/VNet-connected deployment host with
  private DNS resolution. An ACR Tasks build pool is not that host.

| Tool | Required for |
| --- | --- |
| [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) and [Azure CLI (`az`)](https://learn.microsoft.com/cli/azure/install-azure-cli) | Provisioning and lifecycle hooks; use current supported versions |
| PowerShell 7 | Windows hooks and cross-platform preflight checks |
| Bash, jq and curl on Linux/macOS | POSIX hooks and dependency bootstrap |
| Git | Fetching selected, pinned application sources |
| Python 3.12 with pip and venv | Validation, composition and service configuration |
| Docker, when using local builds | Optional for supported Container App builds; hosted preparation uses ACR Tasks |
| Foundry agents azd extension (`azure.ai.agents`) | Hosted deployment; install with `azd extension install azure.ai.agents` if absent |

!!! warning "Cost and time"
    Provisioning creates billable resources before the application is ready.
    Review the [foundation inventory and cost scenarios](../bicep/deployed-resources.md)
    and [cost guide](../architecture/cost-guide.md), then budget for application runtime,
    model usage and data. First deployments take longer because of resource
    creation, image builds, role propagation and private-link approvals.
    There is no fixed completion time.

## Procedure

Run Steps 1-4 in order. After selecting a checkout, run lifecycle commands from
its platform root with the intended environment selected.

### Step 1: Get the code

```bash
git clone https://github.com/Azure/agent-landing-zone.git
cd agent-landing-zone
```

The repository's default `main` branch is the stable deployment source, not
`develop`. Record the resolved commit for repeatable deployments. To deliberately
select a published release instead, use `git fetch --tags` and
`git checkout <release-tag>` before continuing.

Alternatively, `azd init -t Azure/agent-landing-zone` initializes the current
default template in an empty directory. Reuse the environment it creates rather
than creating it again in Step 2.

#### Prepare Python

From the repository root:

```bash
python -m venv .venv
```

On Linux/macOS, use `python3` if `python` is unavailable. Activate
`.\.venv\Scripts\Activate.ps1` in PowerShell or
`source .venv/bin/activate` in Bash, then install:

```bash
python -m pip install -r config/requirements.txt
```

Keep this environment active for the lifecycle commands.

#### Working from your own repository

An unmodified deployment needs only the platform checkout. Hooks fetch selected
runtime components automatically; four forks are not required. Fork or mirror
the platform when you maintain deployment inputs or automation, and fork only
the runtime components whose source you change.

Keep reviewed, nonsecret inputs in source control and apply them explicitly
with `azd env set`; an `environments/` folder is not loaded automatically.
Protect `.azure/`, credentials, sibling component workspaces and deployment
logs. For private components, configure Git read access on the actual deployment
host separately from Azure authentication. Never embed tokens in repository URLs.
See [Custom applications](build-your-own-app.md) for source pinning and composition.

<a id="step-2-sign-in-and-create-an-environment"></a>

### Step 2: Select the deployment target

The following creates a **new** environment. Replace all placeholders:

```bash
az login
azd auth login
az account set --subscription <subscription-id>
azd env new <environment-name>
azd env set AZURE_SUBSCRIPTION_ID <subscription-id>
azd env set AZURE_RESOURCE_GROUP <dedicated-resource-group>
azd env set AZURE_LOCATION <region>
```

For an existing environment, use `azd env select <environment-name>` instead
and preserve its approved inputs. Use separate environments, resource groups,
identities, secrets and data for DEV, TEST and PROD. An environment name or the
App Configuration label alone is not a security boundary. Promote the same
reviewed source revision with stage-specific inputs.

<a id="step-3-choose-a-topology"></a>

### Step 3: Choose the application and network

#### Orchestrator topology

`DEPLOYMENT_TOPOLOGY` chooses where the agent orchestrator runs. It is independent
of the foundation's standalone or hub-and-spoke network shape.

| Value | Orchestrator runs in | Administrative panel | Agent Application Cosmos DB |
| --- | --- | --- | --- |
| `hosted-no-panel` | Foundry Agent Service | Not deployed | Not deployed |
| `hosted-panel` | Foundry Agent Service | Deployed | Deployed |
| `classic` | Azure Container Apps | Not applicable | Deployed |

A new environment defaults to `hosted-no-panel`. To choose another value before
first provision, for example Container Apps:

```bash
azd env set DEPLOYMENT_TOPOLOGY classic
```

Existing environments retain their recorded topology. Older environments
without a topology marker resolve to `classic`; do not change them merely to
match a new-install default. The table describes application resources, not the
Foundry Agent Service's separate backing resources. See [Hosted agents](hosted-agents.md)
for identity, continuity and panel semantics.

#### Ingestion and custom applications

Fresh environments default to `DEPLOY_INGESTION_CONTAINER_APP=false`, using
native Foundry IQ ingestion for the configured default Blob source. Enable
Agent App Ingestion before provisioning if its ingestion features or eligible
conversation uploads are required:

```bash
azd env set DEPLOY_INGESTION_CONTAINER_APP true
```

This does not switch the retrieval backend or rewrite source/index bindings.
Existing environments keep their selection. Before disabling Agent App Ingestion
in an existing environment, review
[ingestion choices and the older-UI migration warning](ingestion.md).
Disabling uploads must not be inferred from a missing endpoint.

For a different application, set `AGENTLZ_APP_DEFINITION` to its definition
path **before the first provision**. The environment binds to that application
ID. Use [Custom applications](build-your-own-app.md) for its contract and
component-specific deployment requirements; do not substitute Agent Application hosted
preparation for a custom definition's build flow.

### Optional Fabric foundation

For the Fabric foundation integration, use a platform feature revision containing
the Fabric module and hook changes. Before provision, set `DEPLOY_FABRIC=true`
and review the [Fabric inputs and permissions](fabric-iq.md#optional-fabric-foundation).
Leave it unset or `false` for the existing deployment behavior.

The same `azd provision` command creates/reuses the capacity and workspace,
provisions the native workspace identity, and grants it Cognitive Services
OpenAI User on the deployed Foundry account. Verify capacity assignment,
workspace access, identity IDs and the account-scoped role assignment.
No Lakehouse, Data Agent, or Foundry IQ knowledge source is created.
A supported Fabric workload must select workspace-identity authentication and
have network access to the model endpoint before inference can work.

### Network and build mode
#### Network and build mode

Choose one network posture for this new environment:

| Choice | Inputs and preparation |
| --- | --- |
| Public service endpoints | `azd env set NETWORK_ISOLATION false`; authentication and authorization still apply |
| Private, self-contained network | `azd env set NETWORK_ISOLATION true`; review the [standalone design](../bicep/standalone.md) |
| Private spoke using an existing hub | `NETWORK_ISOLATION=true`, explicit hub routing, peering, DNS and shared-service inputs from the [hub-and-spoke reference](../bicep/hub-and-spoke.md) |
| Existing VNet | Review subnet ownership, delegations, NSGs and [BYO parameters](../bicep/parameterization.md#networking) before enabling `USE_EXISTING_VNET` |

Apply the approved foundation inputs from
[infrastructure choices](deploy-infra-only.md#step-3-choose-the-foundation-shape).
Do not change `NETWORK_ISOLATION` on an existing environment as a retry shortcut.
With isolation enabled, run configuration, preparation and deployment from the
connected host. If creating that host first, use the
[deferred post-provision procedure](deploy-infra-only.md#complete-a-deferred-post-provision).

| Image build path | Selection |
| --- | --- |
| Public registry, remote builds | `azd env set BUILD_MODE acr-task`; supported components use regular ACR Tasks |
| Private registry, remote builds | Keep `DEPLOY_ACR_TASK_AGENT_POOL=true` before provision and use `BUILD_MODE=acr-task`; builds use the provisioned VNet pool |
| Supported Container Apps, local Docker | `azd env set BUILD_MODE local`; the host must reach the registry and service endpoints |

Automatic hosted image preparation and isolated custom source builds still
require the private pool. `BUILD_MODE=local` is not a local-build alternative
for those paths. See [network isolation](network-isolation.md) for build egress,
DNS and private-link readiness requirements.

### Step 4: Deploy

Confirm the target before creating or changing resources:

```bash
azd env get-value AZURE_SUBSCRIPTION_ID
azd env get-value AZURE_RESOURCE_GROUP
azd hooks run preup
```

Resolve validation, quota, Policy and connectivity failures rather than bypassing
checks. The explicit `preup` check also validates binding before standalone
provisioning, which otherwise runs its check after azd may initialize a resource group.

#### Container Apps orchestrator (`classic`)

```bash
azd up
```

This runs provisioning, post-provision service configuration, image builds and
application deployment.

#### Foundry orchestrator (`hosted-no-panel` or `hosted-panel`)

Confirm the runner has Foundry agent authoring access on the exact project
(Foundry User, previously Azure AI User, or an appropriate equivalent),
account read access and the required scoped role-assignment authority.
Azure sign-in or network connectivity alone is insufficient; see
[private-runner permissions](network-isolation.md) and [hosted identities](hosted-agents.md).

A fresh hosted Agent Application deployment needs this order:

```bash
azd provision
pwsh scripts/prepareHostedDeployment.ps1
azd provision
azd deploy
```

On Linux/macOS replace the preparation command with
`./scripts/prepareHostedDeployment.sh`.

<a id="what-happens-during-the-deployment"></a>

| Stage | Result |
| --- | --- |
| First provision | Creates the foundation and configures its services |
| Preparation | Fetches the pinned orchestrator source, builds its hosted image and records an immutable digest |
| Second provision | Materializes the image and Foundry deployment handoff |
| Deploy | Creates the hosted version, bootstraps runtime access, smoke-tests it and deploys the other selected apps |

A fresh `azd up` does not build the missing hosted handoff. If you started with
it, complete preparation, the second provision and deployment. If the first
provision deferred configuration, complete that work before preparation.
Do not skip the second provision or replace the digest with an image tag.
If the second provision rejects quota for an unchanged deployment, inspect
[quota diagnostics](troubleshooting.md) rather than bypassing the gate.

For an already configured infrastructure-only environment, reuse the same
checkout, inputs and bound application. In `classic`, continue with `azd deploy`.
In a hosted Agent Application topology, continue at preparation above.

<span id="verify"></span>

## Validation

1. Inspect the selected resource group and intended deployed revisions, not just
   an older healthy placeholder:

    ```bash
    azd env get-value AZURE_RESOURCE_GROUP
    az containerapp list -g <resource-group> \
      --query "[].{name:name,state:properties.runningStatus,revision:properties.latestReadyRevisionName}" -o table
    ```

2. Open the frontend URL from the deployment outputs or its Container App
   ingress configuration. Private endpoints require a connected browser.
   Complete [Entra sign-in and delegated-authentication configuration](configuration.md)
   for the intended users.
3. Exercise an agent task and its configured tools with representative identities.
   If using documents, add a test document to the configured source, confirm its
   ingestion, and test both allowed and denied document access. Test uploads only
   when Agent App Ingestion and upload eligibility are selected.
4. In a hosted topology, verify the intended routed version and runtime telemetry
   as well as the remaining Container Apps. A greeting smoke test is not evidence
   of user login, OBO or document authorization.

Use [Troubleshooting](troubleshooting.md) for failures. Do not authorize a cutover
based only on a successful hook or HTTP 200.

To make a hosted agent available in Teams and Microsoft 365 Copilot, continue with
[Publish to Teams and M365](publish-to-teams.md). Bot creation and channel publication
are separate manual tasks, not part of this deployment.

<span id="roll-back-to-a-previous-release"></span>

## Rollback

1. Stop promotion and record the failed revision, inputs and deployed state.
   Select the previous tested **complete compatible combination**, not an
   independent component tip. Review migration constraints before applying it.
2. When only classic application pins changed and the foundation is compatible,
   run from the platform root with the same environment selected:

    ```bash
    git checkout <previous-release-tag>
    azd deploy
    ```

3. For a hosted Agent Application, follow
   [Step 4](#step-4-deploy) with the previous compatible source and approved
   inputs: provision, prepare the pinned image, provision its handoff, then
   deploy. Retain any operator-managed digest and verify its availability and
   compatibility; preparation does not rebuild that image for you.
4. If infrastructure or configuration changed, review the previous inputs and
   preview foundation changes before rerunning the matching full workflow.
   Restore directly managed runtime keys separately using their recorded values
   and reload the affected components. Do not assume checkout restores them.
5. Repeat [Validation](#validation) before reopening access or promotion.

Checking out an old tag does not reverse data migrations or recover lost data.
Restore ingestion requirements before downgrading to a UI without the upload
gate. If reversal is unsupported, use an approved forward repair or a new
environment with data migration. `azd down --purge` is not rollback.

## Lifecycle

Run these tasks from the platform root with the intended environment selected,
Python active, both CLIs authenticated and private connectivity available when
required. Record the source revision, manifest, definition, approved inputs and
hosted digest before a change. Back up configuration and relevant data using
service-specific procedures.

### Upgrade to a new release

1. Read the target [release notes](https://github.com/Azure/agent-landing-zone/releases),
   component versions and migrations. Upgrade the compatible platform combination,
   including its repository-owned `infra/`, rather than independent component tips.
2. Fetch and check out the approved release tag. Reconcile local platform/runtime
   changes and update Agent Application manifest/definition pins together.
3. Preserve the existing topology, ingestion selection, resource naming and
   source/index bindings. Follow [ingestion migration guidance](ingestion.md)
   before opting out or downgrading an older UI.
4. Run the matching [deployment workflow](#step-4-deploy). For a generated hosted
   image with a changed source pin, prepare it again and provision its handoff
   before deployment. Validate in DEV before promoting the same revision.
5. Repeat the [application checks](#verify), including authorization and any
   ingestion, history or continuity features in use.

!!! warning "GPT-RAG v3 environments"
    A v3 environment cannot be upgraded in place to Agent Landing Zone v4.
    Deploy a new environment, migrate the required documents, indexes and
    conversation data, and validate it before retiring the old environment.

### Redeploy applications only

When foundation outputs, application binding, component selection and the image
handoff remain compatible:

```bash
azd deploy
```

Agent Application Container Apps use the manifest's verified sibling checkouts. Preserve
local work and relocate a stale checkout so the hook can fetch the selected
revision; it does not advance an existing checkout automatically. Child logs
are under each component's `.logs` directory and can contain sensitive details.

Hosted deployment reuses the prepared digest. A changed generated source pin or
image requires preparation, provisioning the handoff and deployment again.
An operator-managed digest is not rebuilt automatically: verify its provenance,
compatibility and registry availability. Rebuilding identical source separately
in each environment does not prove identical image digests.

Infrastructure, RBAC, topology or ingestion-selection changes require the full
workflow, not deploy-only. Changing a selection does not delete previously
deployed resources or revoke old permissions; retirement is separately authorized.

### Change a runtime setting

First check [configuration ownership and overwrite behavior](configuration.md).
Provisioning-managed inputs must be changed in their source and applied through
the full workflow. For a directly managed, nonsecret runtime key:

```bash
az appconfig kv set --endpoint <app-config-endpoint> --auth-mode login \
  --key <KEY> --value <value> --label agent-lz --yes
```

Restart each affected Container App revision to reload it:

```bash
az containerapp revision restart -g <resource-group> -n <container-app-name> \
  --revision <revision-name>
```

For a hosted version, run root `azd deploy` with the compatible handoff.
Process environment inputs declared in `hosted-agent/azure.yaml` are immutable
version inputs and require a new agent version. An App Configuration edit
cannot replace a process-only setting such as `APP_CONFIG_TLS_COMPATIBILITY`.
The `agent-lz` label is not an environment-isolation mechanism.

### Rotate a secret

Inspect the Key Vault reference before rotating. An unversioned URI resolves
the current secret version when configuration reloads; a versioned URI must be
updated deliberately. Add the new secret version through your approved secure
process, preserve required access, then restart affected Container App revisions
or redeploy the hosted version. Verify the new credential before retiring the
old one. Never place secrets in plaintext App Configuration or command logs.

### Recover hosted runtime access

The Agent Application post-deploy hook normally bootstraps the discovered runtime principal.
To review the exact read-only role plan from the root's selected environment:

```bash
python -m config.deployment.hosted_access --azd-env --plan
```

An authorized administrator can reconcile only that plan with the idempotent
wrapper:

```powershell
pwsh scripts/bootstrapHostedAccess.ps1
```

On Linux/macOS use `./scripts/bootstrapHostedAccess.sh`. The wrapper selects
`hosted-agent` / `orchestrator-agent` by default; custom services use their own
project/service context. Allow role propagation, then retry root `azd deploy`
so the greeting and remaining deployment gates run before cutover.

The closed bootstrap set grants App Configuration Data Reader, model access
and, when configured, access to the exact audit secret. It is not a grant to
delegated users or a replacement for all capability profiles. Do not grant
Owner or remove unrelated assignments to recover. See [hosted identities](hosted-agents.md).

<a id="clean-up"></a>

### Remove an environment

!!! warning "Destructive action"
    Use the commands below only for an environment whose entire deletion scope
    is dedicated to this deployment and approved for removal. Confirm the
    subscription, resource group and deletion prompt. Export or back up required
    documents, indexes, configuration and conversation data. If the scope
    contains shared resources or retained data, stop and arrange itemized removal
    with the owners instead. Check retention obligations first.

```bash
azd env select <environment-name>
azd env get-value AZURE_SUBSCRIPTION_ID
azd env get-value AZURE_RESOURCE_GROUP
azd down
```

Use `--purge` only when permanent removal of supported soft-deleted resources is
explicitly intended. It removes recovery options. Reused resources outside the
deletion scope and manually created links can remain and continue incurring
charges. For a spoke, retire only its own hub peering/DNS links with their owners;
do not delete shared hub, DNS or monitoring resources.

<a id="next-steps"></a>

## Related runbooks

- [Connect Copilot Studio to a private Foundry agent](connect-copilot-studio.md)
- [Deploy infrastructure only](deploy-infra-only.md)
- [Deploy with Azure DevOps](azure-devops.md) for optional reviewed promotion and automation
