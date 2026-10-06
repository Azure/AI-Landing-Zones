# Bicep platform

Agent Landing Zone deploys its platform with Bicep. The `infra/` folder in [Azure/agent-landing-zone](https://github.com/Azure/agent-landing-zone) was incorporated from the AI Landing Zone Bicep pattern release v2.7.3 and is now owned and maintained in the Agent Landing Zone repository. The exact source release is recorded in `manifest.json` under `infra.source`.

`azd provision` deploys this Bicep template. You do not need to run Bicep commands yourself.

## Resource naming

`RESOURCE_NAMING_MODE` controls how resources are named:

| Value | Behavior |
| --- | --- |
| `caf` (default) | Names follow Cloud Adoption Framework abbreviations |
| `legacy` | Names follow the scheme used by earlier releases |

Set it before the first provision. Changing it on an existing environment creates new resources with the new names.

## Parameters

Agent Landing Zone sets the Bicep parameters from `azd` environment variables. See [Configuration](configuration.md#deployment-parameters) for the list.

For the meaning of the underlying AI Landing Zone parameters, see:

- [How to deploy the Bicep pattern](../bicep/how-to-deploy.md)
- [Parameterization](../bicep/parameterization.md)
