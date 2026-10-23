# How the template works

Agent Landing Zone connects deployment inputs, Azure infrastructure and
application code through the Azure Developer CLI (`azd`). This page explains
that connection for the **Bicep/azd implementation**. Use the deployment runbooks
for the commands to execute. Start with [Deployment choices](planning.md) if
you have not selected the implementation and topology.

## Repository boundaries

The platform repository composes the solution. It does not contain every
application's runtime source.

| Area | Responsibility |
| --- | --- |
| Foundation: platform `infra/` | Repository-owned Bicep source for Azure resources, identities and access. `manifest.json` → `infra.source` records the upstream AI Landing Zone source it incorporates. |
| Platform integration: root files, `scripts/` and `config/` | Selects the application, composes deployment parameters, configures provisioned services and coordinates deployment. |
| Runtime component repositories | Own Agent App UI, Agent App Orchestrator (strategies and tools), and optional Agent App Ingestion. The manifest identifies their repositories and source pins. |

The `infra.source` entry is **provenance**, not a separately deployed package or
submodule. Deploy the platform's reviewed `infra/` tree, including its platform
changes, rather than substituting an upstream infrastructure tag.

## The manifest records a validated combination

[`manifest.json`](https://github.com/Azure/agent-landing-zone/blob/main/manifest.json)
records the platform release and each Agent Application component's repository, ref and
exact commit. It is the authoritative source for the coordinated combination;
the documentation does not maintain a second component-version table.

The hooks fetch selected Agent Application Container App components into sibling
directories and verify their commits. Hosted image preparation fetches the
pinned orchestrator separately for its build. You do not need to fork every
repository to deploy the unmodified Agent Application.

If you change component source, its repository and the platform's pins must
agree. The Agent Application's `app-definition.json` also declares component source pins and
is validated against the manifest. A modified combination needs its own
integration validation. See [Custom applications](build-your-own-app.md) for
repository customization and pinning rules.

## Parameters describe the environment

The checked-in root
[`main.parameters.json`](https://github.com/Azure/agent-landing-zone/blob/main/main.parameters.json)
maps deployment inputs to infrastructure parameters. Values can be literals or
references to the selected azd environment's variables. Inline defaults apply
where declared; other unset inputs can use Bicep defaults.

Before provisioning, the hooks resolve the selected application and hosting
topology, apply the environment inputs and generate `infra/main.parameters.json`.
Bicep consumes that generated file.

!!! note "Edit the source, not the generated output"
    Use documented deployment inputs and the root parameter file. Do not edit
    `infra/main.parameters.json`; the next composition can overwrite it.
    See [Configuration](configuration.md) for the available inputs and defaults.

An **application definition** describes the selected application's components
and capabilities. Select a custom definition before the first provision: one
azd environment is bound to one application ID. It is not a late switch that
changes only the deployment command.

Hosting, orchestration strategy and ingestion selection are separate decisions.
For example, choosing a hosted orchestrator does not select an ingestion path.
The configuration and application definition must form a supported combination.

## `azure.yaml` connects azd to the lifecycle

The root
[`azure.yaml`](https://github.com/Azure/agent-landing-zone/blob/main/azure.yaml)
points azd at `infra/` and registers PowerShell and shell lifecycle hooks. Those
hooks run the platform's configuration modules and coordinate the child
application projects.

| Stage | What the platform does |
| --- | --- |
| Before `azd up` (`preup`) | Validates the application definition and checks its environment binding. |
| Before provisioning (`preprovision`) | Resolves application selection and topology, composes infrastructure parameters and runs preflight checks. |
| After provisioning (`postprovision`) | Configures Azure services, reconciles application access and publishes runtime settings and outputs. |
| Before deployment (`predeploy`) | Checks foundation readiness and application binding, validates topology and required connectivity, then coordinates the selected application deployments. |

`azd provision` therefore includes service configuration through its
post-provision hook. It does **not** mean the pinned application code is running:
some provisioned Container Apps initially contain placeholder images.

For Agent Application Container Apps, deployment uses the verified component checkouts
and their child `azure.yaml` projects to build and deploy the code. Hosted
orchestration uses the prepared image described below. Custom applications
provide their own definition and child project.

## App Configuration carries runtime settings

Deployment inputs describe what to create. **Runtime settings** describe how
applications use the resulting services.

Provisioning and configuration publish settings to Azure App Configuration
under the **`agent-lz` label**. The Agent Application loaders also select other
labels, so check the [runtime selector warnings](configuration.md#runtime-settings)
before changing keys. Bootstrap values such as the store endpoint must be
available before remote configuration can load. Secrets belong in Key Vault
and are referenced rather than copied into checked-in settings.

The label is a shared convention, not an environment boundary. Keep development,
test and production configuration, identities and data separated, following the
[environment boundaries](configuration.md#environment-boundaries) guidance. Local
`.azure/` state is private deployment state, not a source-controlled input file;
the hooks also copy state into child projects, so protect those workspaces.

See [Configuration](configuration.md) for setting names, sources and restart
requirements.

## Why hosted agents need image preparation

A Foundry hosted agent needs an immutable image before its agent version can be
deployed. That creates a bootstrap dependency on the registry and Foundry
resources.

1. **Create the prerequisites.** Initial provisioning establishes the foundation
   and runs its service configuration.
2. **Prepare the image.** The preparation script builds the pinned orchestrator
   and a derived image with the supported hosted entrypoint, then records the
   image digest and build provenance.
3. **Record the handoff.** A further provision materializes the immutable
   deployment handoff using that digest.
4. **Deploy the application.** Deployment creates the hosted agent version and
   deploys the other selected application components.

Image preparation does not start the agent, and provisioning does not create
the running data-plane agent version. Deploy-only reuses a compatible prepared
image rather than rebuilding changed orchestrator source.

The same source pins do not guarantee the same image digest when images are
built independently. If a promotion process requires the identical image,
preserve and verify its digest and registry availability separately.

For execution steps, use [Deploy the full stack](deploy-full-stack.md). For
strategy eligibility and image behavior, see [Agent hosting](hosted-agents.md).

## From understanding to deployment

Review [deployment choices](planning.md), [sizing](sizing.md) and
[cost planning](cost-planning.md), then choose
[Deploy infrastructure only](deploy-infra-only.md) or
[Deploy the full stack](deploy-full-stack.md). Those runbooks contain the
prerequisites, topology-specific sequence and validation steps.
