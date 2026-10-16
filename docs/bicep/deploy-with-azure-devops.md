# Deploy with Azure DevOps

This guide explains how to deploy the AI Landing Zone (Bicep) from Azure DevOps
Pipelines. It covers what the pipelines do, what you need to set up first, how to
wire everything together in your project, and how the pipelines relate to the
pre-flight checks that run before each deployment.

Use this when you want repeatable, gated deployments to Dev, Test, and Prod
instead of running `azd provision` by hand. If you only need a one-off local
deployment, see [How to Deploy](how-to-deploy.md) instead.

The pipeline assets live in the landing zone repository under
`pipelines/azuredevops/`. This page is the source of truth for setup and usage;
the YAML files in that folder are the assets it references.

!!! important "Foundation, not the full application"
    These assets belong to [Azure/bicep-ptn-aiml-landing-zone](https://github.com/Azure/bicep-ptn-aiml-landing-zone/tree/main/pipelines/azuredevops)
    and run from that repository's root. They provision the foundation, not the
    Agent Landing Zone runtime. For customer-owned repositories and application
    deployment, follow [Customer environments](../agent-landing-zone/customer-environments.md)
    and the [full-stack Azure DevOps walkthrough](../agent-landing-zone/azure-devops.md).
    Copying these YAML files into the platform repository without adapting paths
    and lifecycle steps is not a full-stack pipeline.

## What the pipelines do

There are two pipelines that work together.

**CI pipeline (`ci-pipeline.yml`)** validates the Bicep templates. It runs on
pull requests and on pushes to `main`, filtered to the paths that affect the
deployment (`*.bicep`, `*.json`, `modules/`, `constants/`, and
`pipelines/azuredevops/`). It has a single `Validate` stage that:

- installs the Bicep CLI,
- compiles the template with `az bicep build`,
- lints the template with `az bicep lint`,
- publishes the repository as a pipeline artifact named `bicep-templates`.

No Azure sign-in or provisioning happens in CI. It only proves the templates are
well formed, and it hands a validated artifact to the CD pipeline.

**CD pipeline (`cd-pipeline.yml`)** deploys the landing zone. It does not trigger
automatically (`trigger: none` and `pr: none`); you run it on demand and choose
which environments to deploy to. Its Build stage downloads and republishes the CI
artifact for traceability, but each deployment job uses `checkout: self` and runs
from that source checkout. The existing pipeline does **not** guarantee deployment
of the downloaded artifact. Compare the CI revision with the CD checkout before
deployment; use an explicitly artifact-based workflow when that guarantee is required.

```mermaid
flowchart LR
  PR[PR or push to main] --> CI[CI pipeline\nbuild + lint]
  CI --> ART[(bicep-templates\nartifact)]
  ART --> CD[CD pipeline\ntraceability download]
  SRC[CD source checkout] --> Dev
  CD --> Dev[DEV]
  Dev --> Test[TEST]
  Test --> Prod[PROD]
```

### Deployment stages and gating

When you queue the CD pipeline, you pick the environments to deploy with three
boolean parameters: `Deploy to DEV`, `Deploy to TEST`, and `Deploy to PROD`. All
default to off, so a run deploys only what you opt into.

The stages run in a fixed order through stage dependencies: Dev depends on the
artifact download, Test depends on Dev, and Prod depends on Test. If a selected
environment fails, the later environments are skipped. Each environment deploys
with the reusable `deploy-bicep.yml` template, which runs `azd provision` against
that environment.

```mermaid
flowchart LR
  Build[Download CI artifact] --> Dev[DEV\nno approval]
  Dev --> Test[TEST\napproval gate]
  Test --> Prod[PROD\napproval gate]
```

Approvals are not defined in YAML. They live on the Azure DevOps Environment
resource, so you control them from the portal without editing the pipeline. The
recommended setup is no approval on `dev` and a required approval on `test` and
`prod`. When an approval is configured, the pipeline pauses before that stage
until an approver allows it to continue.

### Reusable templates

The pipelines are built from small templates under
`pipelines/azuredevops/templates/`:

- `validate-bicep.yml` compiles and lints the template and publishes the
  artifact. Used by CI.
- `deploy-bicep.yml` installs `azd` and the Bicep CLI, resolves the deploying
  principal, sets the azd environment, and runs `azd provision` with an optional
  retry loop. Used by each CD stage.
- `preview-bicep.yml` runs `azd provision --preview` (a what-if) against a target
  environment. It is provided but **not called** by the existing CD stages.
  Adding a preview requires explicitly wiring the template and its inputs.
- `variables.yml` holds the shared values you fill in for your environment.

## Prerequisites

Before the first run, set up the following in Azure DevOps.

**1. Service connections.** Create one Azure Resource Manager service connection
per environment you plan to use (Dev, Test, Prod). Each service principal needs
`Contributor` and `User Access Administrator` on the target subscription, because
the landing zone creates resources and assigns roles. You will reference these
connection names in `variables.yml`.

In **Project settings > Service connections > New service connection**, select
**Azure Resource Manager**, then workload identity federation with an app
registration or an existing user-assigned managed identity, as permitted by your
organization. Set the intended tenant and subscription and use distinct names
such as `azure-ailz-dev`, `azure-ailz-test` and `azure-ailz-prod`.
Do not grant access to all pipelines: authorize only the deployment pipeline.
Follow Microsoft's [federated service connection setup](https://learn.microsoft.com/azure/devops/pipelines/library/connect-to-azure?view=azure-devops)
for the available identity creation options.

An administrator assigns deployment permissions to the **service principal object
ID**, not the application/client ID. A client ID identifies the application;
an object ID identifies its principal in the target tenant. The deployment
template tries to resolve this with `az ad sp show`; if directory lookup is
restricted, provide the administrator-verified object ID as `AZURE_PRINCIPAL_ID`
and `AZURE_PRINCIPAL_TYPE=ServicePrincipal`. Do not add directory permissions or
subscription Owner merely to bypass a lookup failure.

Verify assignments on the target subscription in **Access control (IAM)**.
`Contributor` creates resources; `User Access Administrator` permits role
assignments. A hub in another scope needs separately approved network permissions
there. These infrastructure roles do not prove access to application data planes.
The deploy task signs in through its service connection and sets
`azd config set auth.useAzCliAuth true` so azd uses that Azure CLI session;
do not add interactive `az login` to an unattended job.

**2. Environments.** Create Azure DevOps Environments named `dev`, `test`, and
`prod`. Add an approval check on `test` and `prod` so deployments to those
environments pause for a human. Leave `dev` without an approval for fast
iteration.

In each environment, open **Approvals and checks > Approvals**, select the
approvers, and disallow self-approval where required by policy. Restrict who can
administer these checks. The YAML `environment:` name must match the protected
resource exactly. A stage dependency orders execution; it does not create an approval.

**3. Variable group.** Create a variable group named `ailz-secrets` and add a
secret variable `secretOrRandomPassword`. This value is used as the jumpbox VM
admin password in Zero Trust deployments. Link the group to the CD pipeline.

Create it under **Pipelines > Library > Variable groups**, mark the password as
secret, and grant the CD pipeline access under **Pipeline permissions**.
Never place the password in YAML, a repository, a published artifact or a command
that echoes it. Treat local azd environment state and deployment logs as sensitive.

**4. Fill in `variables.yml`.** Edit
`pipelines/azuredevops/templates/variables.yml` and set the values for your
environment:

| Variable | What to set |
| --- | --- |
| `azureServiceConnectionDev` | Name of the Dev ARM service connection |
| `azureServiceConnectionTest` | Name of the Test ARM service connection |
| `azureServiceConnectionProd` | Name of the Prod ARM service connection |
| `location` | Azure region for the deployment, for example `eastus2` |
| `environmentName` | Base azd environment name, default `ailz-bicep` |
| `deploymentMode` | `zeroTrust` for network isolation, or `basic` for public networking |
| `agentPool` | Hosted image name such as `ubuntu-latest`; see the self-hosted change below |
| `deployRetryCount` | Extra `azd provision` attempts on transient Azure failures, default `0` |
| `templateFile` | Bicep entry point, default `main.bicep` |

The `deploymentMode` value maps directly to network isolation. `zeroTrust` sets
`NETWORK_ISOLATION true` (VNet, private endpoints, Bastion), and `basic` sets it
to `false` for public networking. This is the same toggle described in
[How to Deploy](how-to-deploy.md).

`deploymentMode` in this variables file means **network isolation** (`basic` or
`zeroTrust`), not the Bicep topology parameter `deploymentMode` (`standalone` or
`ailz-integrated`). Configure hub integration separately using the
[hub-and-spoke runbook](hub-and-spoke.md).

For a self-hosted pool, replace each applicable `pool: { vmImage: $(agentPool) }`
with `pool: { name: '<connected-agent-pool>' }`; changing the variable alone is
not sufficient. Preinstall the documented tools and provide routes, private DNS
and required outbound access. A Microsoft-hosted agent has no automatic access
to private endpoints. An ACR Tasks pool builds images; it is not an Azure Pipelines
runner and does not supply connectivity to pipeline jobs.

!!! note
    The pipelines deploy with the Azure Developer CLI (`azd provision`), which
    handles resource group creation, parameter filtering, and principal ID
    resolution. You do not need to pre-create the resource group.

## How to wire it up in Azure DevOps

**1. Create the CI pipeline.** In your Azure DevOps project, go to Pipelines, New
pipeline, point it at this repository, and select
`pipelines/azuredevops/ci-pipeline.yml`. Name it exactly `AI Landing Zone - CI`.
The CD pipeline references the CI pipeline by that name to pull its artifact, so
the name must match.

**2. Create the CD pipeline.** Create a second pipeline from
`pipelines/azuredevops/cd-pipeline.yml`. Link the `ailz-secrets` variable group
to it (Edit, Variables, Variable groups).

**3. Run a deployment.** Run the CD pipeline manually. Turn on `Deploy to DEV`
to start, and add `Deploy to TEST` or `Deploy to PROD` when you are ready to
promote. The run downloads the CI-validated artifact, then deploys to each
selected environment in order, pausing at any environment that has an approval
gate.

Before the first CD run, authorize its CI pipeline resource, service connections,
agent pool and variable group when Azure DevOps reports **Permission needed**.
Confirm the selected CI run succeeded and record both the CI and CD source
revisions. Successful setup means CI publishes `bicep-templates`, CD resolves its
identity, and each selected Environment records a successful deployment.
Then verify the actual resources with the appropriate
[standalone](standalone.md) or [integrated](hub-and-spoke.md) runbook.

!!! tip
    For strict promotion, Test must require `dependencies.Dev.result` to equal
    `Succeeded`, and Prod must likewise require a successful Test. The default condition
    uses `not(failed())`, which lets you deploy directly to Test or Prod without
    deploying Dev first. See the complete
    [strict promotion example](../agent-landing-zone/azure-devops.md).

## Relationship to the pre-flight checks

Every deployment runs the repository pre-flight script,
`scripts/Invoke-PreflightChecks.ps1`, through the `azd` preprovision hook before
the template deployment. The hook is not a guarantee that azd has not initialized
a resource group. The pipelines do not call the script
directly. They run `azd provision`, and azd runs the hook.

The script is read-only and never changes Azure state. It catches the common
topology mistakes that otherwise surface as deep, late ARM errors, such as
conflicting Private DNS settings, mutually exclusive hub-integration parameters,
invalid IP allow-list shapes, subnet prefixes that overflow or overlap, subnets
too small for the services that use them, and bring-your-own resources that were
promised but do not exist. It also checks regional readiness, including provider
registration, jumpbox VM SKU availability, and AI model quota.

If a check fails, the pipeline reports the failure before submitting the template
deployment (azd may already
have initialized its resource group). You can narrow or skip checks with the script switches and
environment variables documented in the script header, for example
`LZ_PREFLIGHT_REGIONAL_SKIP` to skip only the regional block, or
`PREFLIGHT_SKIP` as an emergency escape hatch. Skipping is meant for unblocking,
not for normal runs.

## Troubleshooting

**The CD pipeline cannot find the CI artifact.** Confirm the CI pipeline is named
exactly `AI Landing Zone - CI` and that it has run successfully at least once, so
the `bicep-templates` artifact exists.

**Deployment fails with a missing password error.** Confirm the `ailz-secrets`
variable group is linked to the CD pipeline and contains a secret variable named
`secretOrRandomPassword`.

**Deployment fails resolving the deployment principal.** Set the
`AZURE_PRINCIPAL_ID` pipeline variable to the Entra object ID of the deploying
identity. The deploy template tries to resolve it automatically from the service
connection, but you can set it explicitly if resolution fails.

**Role assignment errors during provisioning.** Confirm the service principal
behind the environment's service connection has both `Contributor` and
`User Access Administrator` on the target subscription.
