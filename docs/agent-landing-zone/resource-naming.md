# Resource naming

Use this reference to understand generated names, choose organizational
overrides and assess changes to an existing deployment.
Names are provisioned infrastructure inputs, not application runtime settings.

## Read a generated name

The default follows Cloud Adoption Framework (CAF) naming:
`type-workload-environment-region-instance`.
For example, `kv-chatapp-dev-eus2-001` identifies a Key Vault for workload
`chatapp`, environment `dev`, region token `eus2` and instance `001`.

The tokens describe a name, not the deployment target. Changing the region
token does not change the Azure region. Choosing a name does not select an
existing resource for reuse or change its resource group destination.

## Defaults

`RESOURCE_NAMING_MODE=caf` is the default.

| Input | Default when not supplied |
| --- | --- |
| `CAF_WORKLOAD_NAME` | A generated six-character workload token. See provider details below. |
| `CAF_ENVIRONMENT_NAME` | azd environment name, `AZURE_ENV_NAME`. |
| `CAF_REGION_NAME` | Deployment location, `AZURE_LOCATION`, mapped to a short code. |
| `CAF_INSTANCE` | `001`. |

<span id="set-names-for-a-new-environment"></span>
<span id="naming-inputs-and-explicit-overrides"></span>

## Customize a new environment

Use the documented environment bindings and root `main.parameters.json`
before first provision. [Deployment settings](configuration.md#deployment-inputs)
distinguishes environment inputs from native JSON parameters.
Do not edit generated provider inputs.

A readable workload token can express your organizational naming convention.
Use the instance token for deliberately separate parallel copies, not for
successive updates to the same deployment.

Explicit names such as `keyVaultName`, `storageAccountName`,
`searchServiceName` and `aiFoundryAccountName` belong in the root parameter
file. They do not have corresponding environment mappings in that file.
A nonempty explicit name normally takes precedence, but the template can
recognize a generated default and substitute its CAF name. Review the
resolved deployment preview rather than assuming an override won.

Use supported [reuse inputs](configuration.md#existing-resources) to reuse
resources, and [resource group destinations](configuration.md#resource-group-destinations)
to choose their groups. Those are separate from naming.

<span id="preserve-an-existing-deployment"></span>

## Naming stability

!!! warning "Changing an input does not rename or migrate a resource"
    Changing naming tokens or explicit names can create parallel resources
    or require replacement. Endpoints, identities, role assignments and
    private connections can change while data remains in the old resources.
    Parallel copies can also incur additional costs.

Keep the subscription, environment, location and naming inputs stable for
updates. Review the deployment preview's names and resource IDs before applying.
Unexpected creates or deletes need owner review. Preview requires deployment
permissions, not just Reader access.

Restoring previous inputs does not move data or clean up resources already
created under other names. Follow [Updates & recovery](deployment-operations.md)
and review dependencies, data and access before any cleanup.

## Provider and service details

Both providers consume naming overrides from root `main.parameters.json`.
Do not assume their generated names are identical. For Terraform, follow
the [input procedure](deploy-terraform-infra-only.md#step-4-choose-the-application-and-foundation-inputs)
and review the resolved names before provisioning.

Bicep's default workload token is the first six characters of
`uniqueString(subscription().id, environmentName, location)`.
CAF environment and region token overrides do not change that hash's inputs.

Tokens are lowercased. Region input has spaces removed and uses its first
five characters when unmapped. Naming uses the deployment location, not
individual service-location overrides.

Storage and registry names omit hyphens. Generated names are truncated to
service-specific lengths, which can remove distinguishing suffixes.
Explicit names must already satisfy each service's rules: CAF truncation
does not sanitize them. Azure's
[naming rules and uniqueness scopes](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules)
still apply, including global name availability where required.
