# Resource naming

Infrastructure resource names are deployment inputs, not runtime settings.
They are resolved before provisioning, including when the orchestrator is
hosted in Foundry. Changing an input does not rename an existing Azure
resource or move its data.

This page explains the naming model. The
[Deploy infra only](deploy-infra-only.md) and
[Deploy full stack](deploy-full-stack.md) runbooks provide the input and
preview steps. [Deployment settings](configuration.md) describes other inputs;
[resource reuse](planning.md#select-reuse-or-omit-resources) is separate from naming.

The unreleased [resource group destination inputs](configuration.md#resource-group-destinations)
select where resources belong, not a naming mode. Select them before first
provision; changing a group's input is not an existing-resource move or migration.

## Defaults

Cloud Adoption Framework (CAF) naming is the default
(`RESOURCE_NAMING_MODE=caf`). Generated names have the general shape
`type-workload-environment-region-instance`, such as
`kv-chatapp-dev-eus2-001`.

| Deployment input | Default when not supplied |
| --- | --- |
| `CAF_WORKLOAD_NAME` | First six characters of Bicep `uniqueString(subscription().id, environmentName, location)` |
| `CAF_ENVIRONMENT_NAME` | azd environment name (`AZURE_ENV_NAME`) |
| `CAF_REGION_NAME` | Deployment location (`AZURE_LOCATION`), mapped to a short code, such as `eastus2` → `eus2` |
| `CAF_INSTANCE` | `001` |

Tokens are lowercased. Region input also has spaces removed; unmapped regions
use its first five characters. The naming region is based on the deployment
location, not individual service-location overrides. `CAF_REGION_NAME`
changes the name token, **not** where resources deploy.
Overriding the CAF environment or region token does not change the inputs to
the workload's deterministic six-character hash.

Storage and registry names omit hyphens. Generated names are truncated to
service-specific lengths, so long tokens can lose distinguishing suffixes.
Azure's [resource naming rules and uniqueness scopes](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules)
still apply, including global name availability where required.

<span id="set-names-for-a-new-environment"></span>

## Naming inputs and explicit overrides

CAF defaults need no extra inputs. A readable `CAF_WORKLOAD_NAME` can express
the workload name; the other tokens support organizational naming policies.
The instance token distinguishes deliberately separate parallel copies,
not successive updates to one deployment.

Explicit infrastructure parameters include `keyVaultName`,
`storageAccountName`, `searchServiceName` and `aiFoundryAccountName`.
They belong in the reviewed root `main.parameters.json`, not the generated
`infra/main.parameters.json`. The root file does not map these examples to
environment variables.

A nonempty explicit name normally takes precedence. The template can
recognize an explicit value as a generated default and substitute the CAF
name, so the deployment preview is the authority for the resolved result.
Explicit names must satisfy each service's rules; CAF truncation does not
sanitize them.

<span id="preserve-an-existing-deployment"></span>

## Naming stability

Stable subscription, environment, location and naming inputs keep generated
names stable. Changing a token or explicit resource name can create parallel
resources or require replacement. Endpoints, identities, role assignments and
private connections can change, while data remains in the original resources.
Parallel resources can also incur duplicate costs.

The runbooks' preview allows comparison with existing names and resource IDs.
It needs deployment permissions, not just Reader access, and can reveal naming
collisions after truncation. Unexpected creates or deletes need review before
any resource changes proceed.

Restoring earlier inputs does not move data or clean up resources already
created under different names. Recovery requires dependency, data and access
review before any cleanup. [Operations](operations.md) covers ongoing
deployment management.
