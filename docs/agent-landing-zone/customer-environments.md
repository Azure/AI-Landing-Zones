# Customer repositories and environments

Use this guide to decide what to own, where to customize it, and how to keep
DEV, TEST and PROD separate. It describes the Agent Landing Zone v4.3.0
deployment contract. Start with the [full-stack prerequisites](deploy-full-stack.md#prerequisites)
and [Python setup](deploy-full-stack.md#prepare-python).

## Do I need four forks?

**No.** For an unmodified deployment, check out one coordinated platform
release:

```bash
git clone --branch v4.3.0 https://github.com/Azure/agent-landing-zone.git
cd agent-landing-zone
```

The platform hooks fetch selected application components automatically.
Bundled Container App components are cloned into sibling folders using
`manifest.json`. Hosted preparation separately fetches the pinned orchestrator
into a temporary build folder. Only selected components are deployed; for
example, fresh environments do not select the optional ingestion app.

Fork or mirror the platform repository when you need customer-owned deployment
inputs, automation or platform changes. Fork an individual runtime repository
only when you change its source. You do not need to fork the other components
or the foundation repository just to deploy.

| Responsibility | Repository or file to own |
| --- | --- |
| Release combination and component repository URLs | `Azure/agent-landing-zone`: `manifest.json` |
| Foundation infrastructure | Platform repository's `infra/` tree. `manifest.json` → `infra.source` records its upstream provenance; it is not a separately deployed submodule. |
| Deployment inputs and topology | Platform root `main.parameters.json`, plus each selected azd environment's deployment variables |
| Composition and lifecycle | Platform root `azure.yaml`, `scripts/` and `config/`; the hooks generate `infra/main.parameters.json`. Do not edit that generated file. |
| Runtime configuration and secrets | Each environment's Azure App Configuration store, label `agent-lz`; secrets in Key Vault, referenced rather than copied into source |
| Frontend code | `Azure/agent-app-ui` |
| Agent strategies, tools and orchestration | `Azure/agent-app-orchestrator` |
| Optional application ingestion code | `Azure/agent-app-ingestion` |
| A different application composition | Customer application folder with its own definition and `azure.yaml`; see [Custom applications](build-your-own-app.md) |

Prefer documented [configuration inputs](configuration.md) over source changes.
For example, selecting native ingestion does not require an ingestion fork.
Native source ingestion does not replace conversation uploads or every
application ingestion feature.

## Customer repository layout

For a customer that changes only orchestration code, a workspace can look like
this:

```text
customer-ai/
├── agent-landing-zone/             # customer platform fork
│   ├── manifest.json
│   ├── app-definition.json
│   ├── main.parameters.json
│   ├── azure.yaml
│   ├── infra/
│   ├── config/
│   ├── scripts/
│   └── environments/              # optional customer-owned, nonsecret input records
├── agent-app-orchestrator/         # customer fork, when classic deploy selects it
└── agent-app-ui/                   # fetched automatically from upstream
```

The `environments/` folder is an example customer convention, not an input
directory loaded by the platform. Apply its recorded settings explicitly
with `azd env set`. Local `.azure/` state is not a versioned deployment input.
The hooks copy it into child projects; keep those sibling workspaces private
as well.

## Pin customer components

Keep the manifest component **names** exactly `agent-app-ui`,
`agent-app-orchestrator` and `agent-app-ingestion`. Keep the bundled definition
component names `ui`, `orchestrator` and `ingestion`. The hooks use these
names to match components and choose sibling folder names.

For example, to use `https://github.com/contoso/agent-app-orchestrator.git`:

1. Fork the orchestrator, make and test your changes, commit them, and publish
   a customer tag such as `customer-v1.0.0`. Ensure the tag exists in that
   repository and resolves to the intended full commit SHA.
2. In the customer platform fork's `manifest.json`, change the
   `agent-app-orchestrator` entry's `repo`, `tag` and `commit` together.
   Record the exact 40-character SHA, not a shortened SHA or branch tip.
   Leave unchanged component entries at their coordinated release pins.
3. In the bundled root `app-definition.json`, set the `orchestrator`
   component's `source.commit` to the **same** SHA. A manifest-only change
   fails bundled definition validation. Keep the bundled application ID
   `agent-lz-default` for this existing application.
4. From the platform root, with the hook dependencies installed, validate:

    ```bash
    python -m config.appdefinition --validate app-definition.json
    ```

5. Commit both pin files in one customer platform revision. Promote that same
   reviewed revision through DEV, TEST and PROD. This customer combination
   needs its own integration validation; upstream release validation does
   not cover your modified component.

You can confirm a local component SHA with
`git -C ../agent-app-orchestrator rev-parse HEAD`. Existing sibling
checkouts are verified, not automatically advanced to new pins. Preserve
local work, then relocate a stale checkout so the hook can fetch the selected
version. Keep deployment working trees clean: matching `HEAD` alone does
not prove that uncommitted files are absent.

The Container App fetch path selects a published tag, or an explicit branch
when no tag is set, then verifies `HEAD` against `commit`. Use stable customer
tags for promotion. Do not change only the platform remote, assume every
component now comes from that organization, or rely on a commit SHA to fetch
a repository without a matching selectable ref.

### Private Git authentication

Azure authentication and Git authentication are separate. An Azure service
connection does not grant access to private GitHub or Azure Repos repositories.
The deployment host needs noninteractive Git read access to every selected
private component, including the orchestrator fetched during hosted preparation.

Use repository URLs in the format supported by your Git provider, and configure
an approved credential helper, short-lived token or SSH identity on the runner.
Authorize the required repositories explicitly. Never put a token in a manifest
URL, definition, checked-in environment file or command log. Validate access
from the actual runner identity before deployment. Avoid shared credentials
with write access when read access is sufficient.

### Different applications are a separate contract

For a different application, select `AGENTLZ_APP_DEFINITION` **before the first
provision**. A custom definition uses local source pinned to its `HEAD`, or
an immutable image digest; it is not a list of remote repositories to clone.
Its folder owns the corresponding child `azure.yaml`. One azd environment
is bound to one application ID; create a new environment for a different ID.
Use [Custom applications](build-your-own-app.md#source-pinning) for source,
image, capability-profile and validation rules instead of adapting the bundled
manifest into a different application contract.

## Hosted images use the pinned code

Bundled hosted preparation builds the orchestrator from the manifest's
repository, ref and verified commit. It resolves that base image to a digest,
then builds a small derived image with the hosted port and startup command:

```text
uvicorn src.api.hosted_entrypoint:app --host 0.0.0.0 --port 8088
```

The hosted entrypoint is in the pinned orchestrator source, not an unrelated
platform implementation. Changing a startup variable alone does not turn the
classic image into the hosted image. The supported startup command is fixed.
The platform's `hosted-agent/azure.yaml` is the child deployment project.

Preparation records `HOSTED_AGENT_IMAGE_VERSION` as `sha256:…`, with generated
source and startup-command provenance. It can reuse a generated digest when
both still match. An operator-supplied digest without that provenance is
operator-managed and is not rebuilt automatically. You must verify its
compatibility and registry access.

Promoting the same source pins is **not** proof of promoting the same image:
building in each environment can produce different digests. An immutable-image
promotion process must separately preserve and verify the image digest and its
availability in each target registry. See
[Hosted image redeployment](hosted-agents.md#redeploy-the-same-image-or-prepare-a-new-one).

## Deployment lifecycle

Run root commands from `agent-landing-zone/`, with the intended azd environment
selected and both `az` and `azd` authenticated.

| Command or stage | Current behavior |
| --- | --- |
| `azd up` → `preup` | Validates the definition and checks its application binding before the deployment pipeline creates resources. |
| `azd provision` → `preprovision` | Revalidates and binds the application, resolves topology, generates infrastructure parameters, and runs preflight checks. Then Bicep provisions the foundation and selected placeholders. |
| `postprovision` | Configures services, reconciles application access and publishes runtime settings and outputs. Provisioning alone does not run the application code. |
| `azd deploy` → `predeploy` | Checks foundation readiness, binding, topology and private reachability, then deploys the selected applications through child projects. Bundled Container Apps use verified manifest checkouts; hosted orchestration uses the prepared handoff. |

For **classic**, set `DEPLOYMENT_TOPOLOGY=classic` before first provisioning,
then use `azd up` for the complete workflow.

For a **first bundled hosted deployment**, the default for a fresh environment
is `hosted-no-panel`. Run:

```bash
azd provision
pwsh scripts/prepareHostedDeployment.ps1
azd provision
azd deploy
```

On Linux or macOS use `./scripts/prepareHostedDeployment.sh` instead of the
PowerShell preparation command. The first provision prepares prerequisites;
preparation records the image; the second provision materializes the immutable
handoff; deployment creates the hosted version and deploys the remaining apps.
A fresh hosted `azd up` stops at deployment without that prepared handoff.
See [Hosted agents](hosted-agents.md#deploy-with-a-hosted-topology).

For a strict validation/binding check before standalone provisioning, run
`azd hooks run preup` first. Unlike the `azd up` preup gate, `preprovision`
cannot guarantee rejection before azd's own resource-group initialization.

## Isolate DEV, TEST and PROD

Use a separate azd environment and target resource group for each stage.
Separate subscriptions provide a stronger administrative and quota boundary;
if subscriptions are shared, keep resource groups, permissions and data separate.
An azd environment name alone is not a security boundary.

| Boundary | Keep separate |
| --- | --- |
| Deployment target | Subscription/resource group, azd environment, region and network inputs |
| Deployment identity | Environment-scoped service connection or identity and its authorized pipelines; do not give DEV deployment access to PROD |
| Runtime identity and sign-in | Component managed identities, role assignments, environment-specific application registrations or explicitly separated callbacks and consent |
| Configuration and secrets | App Configuration endpoint, Key Vault and secret references; the `agent-lz` label is shared by convention, not an environment separator |
| Data and operations | Document sources, indexes, Cosmos data, conversation/history stores and retention; use approved test data rather than copying production documents |
| Network and builds | Required DNS, routes and private endpoints, plus a connected deployment runner; the ACR Tasks build pool is not the Azure DevOps agent |

For example, from the platform root, after signing in:

```bash
azd env new contoso-agent-dev
azd env set AZURE_SUBSCRIPTION_ID "<dev-subscription-id>"
azd env set AZURE_RESOURCE_GROUP "rg-contoso-agent-dev"
azd env set AZURE_LOCATION "<supported-region>"
azd env set DEPLOYMENT_TOPOLOGY classic
azd env set DEPLOY_INGESTION_CONTAINER_APP false
```

Replace the bracketed values, confirm that native ingestion meets your needs,
and apply the remaining [configuration](configuration.md) and
[network settings](network-isolation.md) before deploying. Repeat environment
creation for `contoso-agent-test` and `contoso-agent-prod`, using their own
subscription IDs and resource groups. Choose the required topology explicitly
for each. Verify the selected target before any provisioning or deployment:

```bash
azd env select contoso-agent-dev
azd env get-value AZURE_SUBSCRIPTION_ID
azd env get-value AZURE_RESOURCE_GROUP
```

Never copy DEV's `.azure/` directory into TEST or PROD as configuration.
Fresh runners must initialize or restore the intended environment securely,
refresh its Azure outputs when needed, and reapply its approved inputs.
Do not publish `.azure/`, `.env`, credentials, child deployment logs or Python
dependency environments as pipeline artifacts.

A customer promotion pipeline should require successful DEV before TEST,
successful TEST before PROD, and approvals on the TEST and PROD Azure DevOps
Environment resources. Use the same reviewed source revision and pins at every
stage, with different environment inputs. The existing upstream foundation
pipeline allows independent environment selection; it does not enforce this
strict application promotion policy for you.

## Upgrade, redeploy and recover

1. Record the deployed customer platform revision, manifest, definition,
   environment inputs and hosted digest. Back up configuration and relevant
   data using your approved service-specific procedures.
2. Review the target upstream release's changes. Integrate the coordinated
   platform tree, including `infra/`, and reconcile customer changes. Update
   the manifest and bundled definition together. Do not independently advance
   all component branches to their latest tips.
3. Validate in DEV, then promote through TEST and PROD with the same reviewed
   source. Use the full topology workflow for infrastructure, role, topology
   or component-selection changes. A changed hosted source pin requires
   preparation, provisioning the new handoff, then deployment.
4. Verify deployed revisions, sign-in/OBO, retrieval and document allow/deny
   behavior, plus ingestion and history features you use. Hook success or a
   hosted greeting is not application acceptance.

For application-only redeployment, run `azd deploy` from the platform root
only when foundation outputs, binding, component selection and image handoff
are still compatible. Hosted deploy-only reuses the prepared image; it does
not rebuild a changed source pin.

After a failure, stop promotion and preserve diagnostics securely. Correct
the reported prerequisite and retry the same approved workflow. Do not bypass
quota, network, authorization or image checks. Restore a known compatible
application revision/digest and configuration when that recovery is supported;
do not assume that checking out an old tag safely reverses infrastructure or
data changes. Some changes need forward repair or a new environment and data
migration. In particular, v3 environments cannot be upgraded in place to v4.
`azd down --purge` is destructive cleanup, not rollback.

Follow the detailed [upgrade](operations.md#upgrade-to-a-new-release),
[application redeployment](operations.md#redeploy-applications-only),
[ingestion migration](operations.md#upgrade-ingestion-selection-to-v430) and
[troubleshooting](troubleshooting.md) procedures.

## Implementation references

The contracts above can be checked against the v4.3.0 source:

- [Manifest](https://github.com/Azure/agent-landing-zone/blob/v4.3.0/manifest.json)
  and [bundled definition](https://github.com/Azure/agent-landing-zone/blob/v4.3.0/app-definition.json).
- [Lifecycle wiring](https://github.com/Azure/agent-landing-zone/blob/v4.3.0/azure.yaml)
  and [component fetch/deploy hook](https://github.com/Azure/agent-landing-zone/blob/v4.3.0/scripts/preDeploy.ps1).
- [Bundled pin validation](https://github.com/Azure/agent-landing-zone/blob/v4.3.0/config/appdefinition/validator.py).
- [Hosted preparation](https://github.com/Azure/agent-landing-zone/blob/v4.3.0/config/deployment/hosted_prepare.py)
  and [source/derived-image build](https://github.com/Azure/agent-landing-zone/blob/v4.3.0/config/deployment/hosted_image.py).
