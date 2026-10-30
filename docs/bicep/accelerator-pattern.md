# Customize the incorporated foundation

The maintained Bicep foundation lives in
[Azure/agent-landing-zone under `infra/bicep/`](https://github.com/Azure/agent-landing-zone/tree/main/infra/bicep).
It is regular repository-owned source, not a Git submodule or a separate
checkout to initialize. Foundation changes are reviewed and released with the
platform.

## Application and infrastructure boundaries

For a different application, use the
[application-definition contract](../agent-landing-zone/build-your-own-app.md).
Keep application images and runtime configuration outside foundation modules.
Use [Deploy infrastructure only](../agent-landing-zone/deploy-infra-only.md)
when the foundation is needed before application deployment, or
[Deploy the full stack](../agent-landing-zone/deploy-full-stack.md) for both.

## Parameters and lifecycle

Keep `azure.yaml`, `manifest.json`, the root `main.parameters.json`, `infra/`,
`config/`, `contracts/` and `scripts/` together at the reviewed platform
revision. Run `azd` from the platform root.

The platform hooks validate the selected application and immutable environment
binding, compose the root parameters into `infra/bicep/main.parameters.json`, and
run foundation preflight. Do not edit the generated parameter copy or replace
the hooks with submodule initialization scripts.
See [How it works](../agent-landing-zone/how-it-works.md) and
[Deployment settings](../agent-landing-zone/configuration.md).

<a id="boolean-rewrite-edge-case"></a>

Use `azd env set` for documented environment variables that take one value,
such as `NETWORK_ISOLATION`. Settings containing lists (`[...]`) or groups of
named fields (`{...}`) belong in the reviewed root `main.parameters.json` file.
Parameters without a documented environment-variable equivalent also go in
that file.

Keep the JSON value types shown in the parameter examples: for instance, use
`true` for a boolean, not the text `"true"`, and keep lists and objects in their
original JSON format. Follow the
[parameter reference](parameterization.md) rather than copying legacy hook
starters.

## Changes and upgrades

Review changes to the incorporated Bicep source with their compatible platform
parameters, hooks and contracts. `manifest.json` `infra.source` records where
the foundation was incorporated from; it does not select a separate
infrastructure checkout at deployment time.

Upgrade through a coordinated platform release and preserve the previous
compatible revision and approved inputs for rollback. Follow the
[upgrade and rollback runbook](../agent-landing-zone/deploy-full-stack.md#upgrade-to-a-new-release)
rather than fetching a foundation tag into `infra/`.
