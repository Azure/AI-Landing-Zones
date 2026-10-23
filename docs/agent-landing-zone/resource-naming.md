# Resource naming

Choose foundation resource names **before provisioning**. These are deployment
inputs, not runtime App Configuration settings; they apply equally when the
orchestrator is hosted in Foundry. Changing them does not rename existing Azure
resources or migrate their data.

Use the selected environment and deployment permissions from
[Full stack deploy](deploy-full-stack.md). Keep the same subscription,
environment and location when updating an existing deployment.
Return to [Configuration](configuration.md#resource-naming) for other deployment
inputs. For selecting existing resources, use
[resource reuse](planning.md#select-reuse-or-omit-resources), not naming overrides.

## Defaults

`RESOURCE_NAMING_MODE` maps to the foundation's `resourceNamingMode` parameter.
The allowed values are `caf` (**default**) and `legacy`.

CAF generates names with the general shape
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
location, not individual service-location overrides. Setting `CAF_REGION_NAME`
changes the name token, **not** where resources deploy.
Overriding the CAF environment or region token does not change the inputs to
the default workload hash.

Storage and registry names omit hyphens. Generated names are truncated to
service-specific lengths, so long tokens can lose distinguishing suffixes.
Keep tokens short and follow Azure's
[resource naming rules and uniqueness scopes](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules).
The deterministic workload hash is not a guarantee of global name availability.

## Set names for a new environment

1. Select your new azd environment using the deployment guide. No naming
   settings are required to use the CAF defaults.
2. Optionally choose a readable workload token before provisioning:

   ```bash
   azd env set RESOURCE_NAMING_MODE caf
   azd env set CAF_WORKLOAD_NAME chatapp
   ```

   Override `CAF_ENVIRONMENT_NAME`, `CAF_REGION_NAME` or `CAF_INSTANCE` only
   when the defaults do not suit your naming policy. Use another instance token
   for a deliberately separate parallel copy; do not increment it for updates.
3. For a specific resource, the foundation supports explicit parameters such
   as `keyVaultName`, `storageAccountName`, `searchServiceName` and
   `aiFoundryAccountName`. Supply supported parameters through the reviewed
   root `main.parameters.json` deployment inputs, not the generated
   `infra/main.parameters.json`; the shipped root file does **not**
   expose environment-variable mappings for these examples. Setting an
   invented `KEY_VAULT_NAME` variable will not override `keyVaultName`.
   For example, add `"keyVaultName": { "value": "kv-chatapp-dev-eus2-001" }`
   inside the root file's `parameters` object, preserving valid JSON and
   choosing an available name.

   A nonempty explicit name normally wins over generated naming. **Exception:**
   in CAF mode, a value equal to that resource's legacy-generated name is
   treated as the old default and replaced by its CAF name. Use `legacy` mode
   to preserve those names. Explicit names must satisfy the service's rules;
   the CAF truncation logic does not sanitize explicit overrides.
4. Review the resolved resource names before provisioning, using your
   deployment workflow's
   [ARM/Bicep what-if preview](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-what-if).
   What-if requires deployment permissions, not just Reader access.
   Confirm names remain distinct after truncation, then continue provisioning.

## Preserve an existing deployment

For an environment created with legacy resource-token naming, set this
**before the next provision**, including after upgrading the template:

```bash
azd env set RESOURCE_NAMING_MODE legacy
```

Record the deployed names and previous naming inputs before upgrading.
Retain the original explicit overrides and any custom `resourceToken` input.
The default legacy token is the lowercased
`uniqueString(subscription().id, environmentName, location)`, not the six-character
CAF workload token. Keep the original CAF inputs instead if the environment
was already deployed with CAF naming.

**Verify:** compare the preview's resource names and IDs with the existing
deployment. Investigate unexpected creates or deletes before proceeding.
After provisioning, confirm
the expected names in the Azure portal resource group resource list.

Switching modes, changing a token or changing an explicit resource name can
create parallel resources or require replacement, rather than update the
existing resource. This can change endpoints, identities, role assignments and
private connections, leave data in the old resources and incur duplicate cost.
Naming is not an existing-resource reuse mechanism.

**Recovery:** if the preview shows unintended names, stop and restore the
previous inputs before provisioning. If new resources were already created,
restoring inputs alone does not migrate data or clean them up. Identify which
resources hold production data and dependencies, plan migration or rollback,
and remove duplicates only after verification. See
[Operations](operations.md) for ongoing deployment management and
[Configuration](configuration.md) for the broader input model.
