# Bicep implementation

AI Landing Zones repo includes a **Bicep-based implementation** of the AI Landing Zone, built to deploy a secure, modular baseline for AI apps and agents on Azure. It is designed to work in multiple enterprise patterns:

- **Standalone workload (default)**: the deployment creates networking and (optionally) private DNS.
- **Platform-integrated workload**: the workload deploys resources and Private Endpoints, while the **platform** owns shared DNS/networking patterns.
- **Reuse existing resources**: you can reuse an existing VNet (and other resources) and deploy into it.

## How the Bicep is organized

The main orchestrator template is:

- `bicep/infra/main.bicep`

Supporting folders (source-of-truth lives under `bicep/infra/`):

- `components/`: repo-specific components and orchestration glue
- `wrappers/`: wrappers around Azure Verified Modules (AVM) used by this repo
- `common/`: shared types/helpers (including strongly typed parameter objects)
- `helpers/`: helper modules for subnet setup and related operations
- `sample.*.bicepparam`: scenario-focused parameter files you can copy

> Note: The recommended way to deploy is via `azd` (see [how-to-use.md](how-to-use.md)).

## Key switches and deployment patterns

### Deploy toggles

The template uses a `deployToggles` object to turn features on/off. This is the quickest way to customize what gets deployed.

### Resource reuse

The template supports “create new” and “reuse existing” patterns via a `resourceIds` object.

A common example is reusing a VNet:

- Set the VNet toggle off (so the template doesn’t try to create it)
- Provide the VNet resource id in `resourceIds`
- Ensure required subnets exist with the expected names

See: [examples](example-standalone.md) and the existing-VNet runbook under `tests/`.

### Platform integration

`flagPlatformLandingZone` controls the split between workload-owned and platform-owned responsibilities.

- `false` (standalone): workload deployment can create Private DNS zones + VNet links
- `true` (platform-integrated): workload expects platform-managed DNS (and often hub networking)

## How deployments run (azd + Template Specs)

Deployments typically run through `azd provision`.

This repo uses **Template Specs** during provisioning to bypass the ARM template size limit. In general:

- Pre-provision scripts build/publish Template Specs
- The deployment executes using those Template Specs
- Post-provision scripts remove the temporary Template Specs after success

Details and prerequisites: [how-to-use.md](how-to-use.md)

## Where to go next

- Start with [how-to-use.md](how-to-use.md).
- Understand all inputs in [parameterization.md](parameterization.md).
- Pick a scenario from [examples](example-standalone.md).