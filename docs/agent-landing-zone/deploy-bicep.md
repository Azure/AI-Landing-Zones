# Deploy with Bicep

Agent Landing Zone uses Bicep for its infrastructure. The Bicep source lives in
the `infra/` folder of the repository, and `azd` calls it for you. This page
explains how that works, what you can change, and why you should not call the
Bicep template directly.

## How `azd` uses Bicep

When you run `azd provision` or `azd up`, three things happen in order:

1. The `preprovision` hook validates your environment, runs the preflight
   checks, and composes `infra/main.parameters.json` from your `azd`
   environment values.
2. `azd` deploys `infra/main.bicep` with those parameters.
3. The `postprovision` hook assigns roles, publishes runtime settings to Azure
   App Configuration (label `agent-lz`), and configures Azure AI Search and
   Microsoft Foundry.

`azd deploy` then builds and deploys the application components.

## Change parameters

Set values in your `azd` environment, then provision again:

```bash
azd env set NETWORK_ISOLATION true
azd env set AZURE_LOCATION eastus2
azd provision
```

You do not need to edit `infra/main.parameters.json`. The `preprovision` hook
rewrites it from your environment on every run. See
[Configuration](configuration.md) for the full list of parameters and their
defaults.

## Resource naming

| `RESOURCE_NAMING_MODE` | Behavior |
| --- | --- |
| `caf` (default) | Names follow Cloud Adoption Framework abbreviations, for example `ca-<token>-orchestrator`. |
| `legacy` | Keeps the naming scheme used by earlier GPT-RAG releases. Use it only when you must match existing resource names. |

## Do not call Bicep directly

Avoid `az deployment group create` or `az deployment sub create` against
`infra/main.bicep`. A direct deployment skips:

- environment composition and the preflight checks;
- the hosted agent state;
- role assignments;
- App Configuration publishing;
- the application deploy.

The result is infrastructure that the application cannot use.

!!! warning "Do not use `what-if` with `main.parameters.json`"
    `infra/main.parameters.json` contains `${...}` substitutions and secret
    placeholders that only `azd` resolves. Passing it to `az deployment ... what-if`
    produces wrong or failing results. Use `azd provision --preview` instead.

## Reference

The Bicep modules and their parameters are documented in the AI Landing Zone
pages:

- [How to deploy the Bicep implementation](../bicep/how-to-deploy.md)
- [Bicep parameterization](../bicep/parameterization.md)

## Related pages

- [Deploy full stack](deploy-full-stack.md)
- [Deploy infra only](deploy-infra-only.md)
- [Configuration](configuration.md)
