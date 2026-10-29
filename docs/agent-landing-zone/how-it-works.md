<span id="how-the-template-works"></span>

# How it works

Agent Landing Zone connects deployment inputs, Azure infrastructure and
application code through the Azure Developer CLI (`azd`). This page introduces
those concepts for the **Bicep and integrated Terraform implementations**, so
you can understand what the deployment does without memorizing commands or
parameters.

A **command-line interface (CLI)** runs commands in a terminal. Bicep or
Terraform describes Azure resources as code; `azd` coordinates their creation
and application deployment. **Azure Blob Storage** stores files, and **Azure AI Search** indexes
content so the application can retrieve relevant passages.
An **application programming interface (API)** lets code send requests to a
service.

An **orchestrator** coordinates model calls, retrieval and tools. The default
Agent Application runs it in Foundry Agent Service with `maf_lite`, the
supplied orchestration **strategy** (the code path that coordinates a turn).
It has no administration panel and uses native Foundry IQ Blob ingestion,
where Azure AI Search prepares Blob documents for retrieval.

The sections below explain how that application and its
infrastructure are prepared. The **Deploy infra only** and
**Deploy full stack** runbooks provide the execution steps.

## How to read deployment settings

A **deployment parameter** tells the template what to create or reuse, such
as a private network or an existing hub. An **`azd` environment** groups the
settings and deployment state for one deployment, such as development or
production. Both infrastructure providers use the same operator inputs:

| Input form | Source |
| --- | --- |
| Uppercase input, such as `NETWORK_ISOLATION` | The selected `azd` environment. The hooks resolve documented mappings before provisioning. |
| Structured value, such as `modelDeploymentList` | The root `main.parameters.json`, inside `parameters.<name>.value`. Keep arrays, objects, booleans and numbers in their native JSON types. |

For example, `NETWORK_ISOLATION=true` selects private networking. Deployment
inputs and the root parameter file are resolved before provisioning.
For Terraform, a typed adapter generates the ignored
`infra/terraform/main.tfvars.json`. The generated `infra/main.parameters.json`
supports shared preflight diagnostics; Bicep uses that file for its deployment.
The [Deployment settings](configuration.md) reference lists inputs and defaults;
choose the provider-specific **Deploy infra only** or **Deploy full stack**
runbook for their application order.

!!! note "Application-specific runtime settings"
    Runtime settings control an application's behavior and vary by application.
    Here they describe **Agent Application**, the supplied reference app.
    Its settings are usually stored in Azure App Configuration.

## Repository boundaries

The platform repository coordinates infrastructure and application deployment.
The Agent Application's runtime code lives in separate component repositories.

| Area | Responsibility |
| --- | --- |
| Bicep infrastructure: platform `infra/` | Bicep source for Azure resources, identities and access. |
| Terraform infrastructure: platform `infra/terraform/` | AVM composition, complementary resources, generated typed inputs, native outputs and committed provider lock file. |
| Platform integration: root files, `scripts/` and `config/` | Selects the application, composes deployment parameters, configures provisioned services and coordinates deployment. |
| Runtime component repositories | Own Agent App UI, Agent App Orchestrator (strategies and tools), and optional Agent App Ingestion. The manifest identifies their repositories and source pins. |

Deployment uses the product's infrastructure source for the selected provider.

## The manifest records a validated combination

[`manifest.json`](https://github.com/Azure/agent-landing-zone/blob/main/manifest.json)
records the platform release and each Agent Application component's repository,
release tag and exact Git commit. A **Git commit** identifies an exact source
revision; a tag is a readable label for a version. These identify the code
versions validated together.

The hooks fetch selected Container App components into sibling directories
and verify their commits. Hosted image preparation fetches the pinned
orchestrator separately. Deploying the reference app needs no repository forks.

The Agent Application's `app-definition.json` also records component commits
and is validated against the manifest. A modified combination needs its own
integration validation. See [Custom applications](build-your-own-app.md) for
repository customization and pinning rules.

## Parameters describe the environment

The checked-in root
[`main.parameters.json`](https://github.com/Azure/agent-landing-zone/blob/main/main.parameters.json)
maps deployment inputs to infrastructure parameters. Values can be literals or
references to the selected azd environment's variables. Inline defaults apply
where declared; other unset inputs can use Bicep defaults.

Before provisioning, the hooks validate the provider/application binding,
resolve the shared hosting topology and apply environment inputs.

| Provider | Generated deployment input |
| --- | --- |
| Bicep | `infra/main.parameters.json` |
| Terraform | `infra/terraform/main.tfvars.json` |

Terraform renders backend settings from `infra/terraform/provider.conf.json`.
Its generated `infra/main.parameters.json` is only a shared preflight artifact,
not the Terraform deployment input.

!!! note "Terraform cloud and backend records"
    The adapter qualifies `public`, `usgovernment` or `china` and generates
    the matching `azureCloud` context and backend environment. See
    [Azure cloud settings](configuration.md#azure-cloud).

    An immutable private backend record is created on first use before
    settings are persisted and verified thereafter. Clean runners need the
    original backend, group and application/environment bindings, not
    reconstructed files.

!!! note "Edit the source, not the generated output"
    Use documented environment inputs and root `main.parameters.json`.
    Do not edit generated `infra/main.parameters.json`,
    `infra/terraform/main.tfvars.json` or `.azure/` inputs.
    See [Deployment settings](configuration.md) for inputs and defaults.

An **application definition** describes the selected application's components
and capabilities. The environment records that definition's `id` on first
provision and rejects a different one later. This identifies the deployed
application; it is not a Microsoft Entra ID application registration ID.

Microsoft Entra ID handles sign-in and service identities in an organization's
directory, called a **tenant**. An application registration describes a sign-in
application to that service. Custom application selection therefore happens
before the first provision.

Hosting, orchestration strategy and ingestion selection are separate decisions.
For example, choosing a hosted orchestrator does not select an ingestion path.
The configuration and application definition must form a supported combination.
The hosted runtime rejects unsupported strategies rather than silently
switching strategy or host. The `multimodal` and `nl2sql` strategies are not
supported by this host.

<span id="azureyaml-connects-azd-to-the-lifecycle"></span>

## Deployment lifecycle

The root
[`azure.yaml`](https://github.com/Azure/agent-landing-zone/blob/main/azure.yaml)
selects the infrastructure provider/path and registers PowerShell and shell
lifecycle hooks. Bicep at `infra/` remains the default. To use Terraform,
configure `infra.provider: terraform`, `infra.path: infra/terraform` and
`infra.module: main` once before a new environment's first provision.
This selection applies to the
checkout, not independently to each environment in it.
Use the selected provider for provisioning, updates and removal.

The shared hooks configure Azure services and coordinate application deployment.

| Stage | What the platform does |
| --- | --- |
| Before `azd up` (`preup`) | Validates the application definition and checks that it matches the environment's recorded application. |
| Before provisioning (`preprovision`) | Validates provider/application binding, resolves shared topology, generates provider-specific typed inputs and runs preflight checks. |
| After provisioning (`postprovision`) | Configures Azure services, reconciles application access and publishes runtime settings and outputs. |
| Before deployment (`predeploy`) | Checks infrastructure readiness and the recorded application, validates topology and required connectivity, then coordinates the selected application deployments. |

`azd provision` includes service configuration through its post-provision hook.
Some Container Apps initially contain placeholder images; `azd deploy` replaces
them with the selected application code. `azd up` runs both stages.
Provisioning does not build or publish application images; reapplying
infrastructure must preserve application-managed images and revisions.
All flat Terraform outputs feed azd and those shared hooks automatically;
operators do not copy outputs into application projects.

The Terraform backend uses existing Azure Storage outside workload teardown.
Native azd disables state locking. Shared and production state uses one
authorized executor with queued, non-canceling operations per backend state
identity; see the [single-writer policy](deploy-terraform-infra-only.md#state-protection).

Container App deployment builds verified component code through each
component's `azure.yaml`. Hosted orchestration uses the prepared image
described below. Custom applications supply their own definitions and projects
for deployment.

## App Configuration carries runtime settings

Deployment inputs describe what to create. **Runtime settings** describe how
applications use the resulting services.

### Who publishes settings

Provisioning and configuration publish settings to Azure App Configuration
under the **`agent-lz` label**.

Terraform owns foundation connections and model metadata. Shared defaults
seed only missing keys, while the runtime publisher updates its owned settings
from the declared parameter document and selected environment.

Labels, content types and Key Vault-reference metadata follow the
[configuration ownership contract](configuration.md#configuration-ownership-and-declarations).

### How applications load settings

The Agent Application loaders also select other labels, which can affect
[which setting takes precedence](configuration.md#runtime-settings).
Bootstrap values such as the store endpoint must be
available before remote configuration can load.

### Secrets and environment boundaries

Secrets belong in Key Vault and are referenced rather than copied into
checked-in settings.

The same label is used across environments, so separation depends on distinct
configuration, identities and data, as described in
[Environment boundaries](configuration.md#environment-boundaries).

Local `.azure/` state is private deployment state, not a source-controlled input file.
Child workspaces receive copies and need the same protection.
Terraform's backend and group records are also required for state-scoped
teardown; output refresh does not replace them.

See [Deployment settings](configuration.md) for setting names, sources and reload
requirements.

## Why hosted agents need image preparation

A Foundry hosted agent needs an immutable image before its agent version can be
deployed. That creates a bootstrap dependency on the registry and Foundry
resources.

An **image digest** identifies the built container image by its content.
It is not a source commit or a mutable image tag.

1. **Infrastructure prerequisites.** Initial provisioning creates and configures
   the required Azure services and access rules.
2. **Automatic image preparation during deploy.** The deployment hook builds
   the pinned orchestrator and its hosted entrypoint image when needed,
   recording the digest and build details.
3. **Application handoff during deploy.** The hook binds the image to the
   provisioned project, registry and network metadata without another provision.
4. **Application publication.** Deployment creates the hosted agent version and
   deploys the other selected application components.

Image preparation does not start the agent, and provisioning does not create
the running data-plane agent version. Deploy-only reuses a compatible generated
image, or rebuilds when generated source/startup provenance changes.
Operators use `azd provision` followed by `azd deploy`, or `azd up`;
there is no required standalone preparation command.

The same source pins do not guarantee the same image digest when images are
built independently. If a promotion process requires the identical image,
its digest and registry availability need separate preservation and verification.

The full-stack runbooks for [Bicep](deploy-full-stack.md) and
[Terraform](deploy-terraform-full-stack.md) provide execution steps. For
strategy eligibility and image behavior, see [Agent hosting](hosted-agents.md).

## From understanding to deployment

The planning references explain [deployment design](planning.md),
the [Sizing & cost planner](sizing-cost-planner.md).
For execution, choose the outcome and then the provider:

- **Deploy infra only:** [With Bicep](deploy-infra-only.md) or
  [With Terraform](deploy-terraform-infra-only.md).
- **Deploy full stack:** [With Bicep](deploy-full-stack.md) or
  [With Terraform](deploy-terraform-full-stack.md).

Those runbooks contain the
prerequisites, topology-specific sequence and validation steps.
