# Custom applications

Agent Landing Zone deploys the default application (Agent App UI and Agent App Orchestrator, with an optional Agent App Ingestion Container App) unless you select a different one. You can deploy your own application on the same platform by describing it in an **application definition**: a JSON file validated against `contracts/app-definition-v1.schema.json`.

The platform owns identity, networking, and permissions. Your application declares only what it is, where its code lives, and which capabilities it needs.

`DEPLOY_INGESTION_CONTAINER_APP` controls ingestion selection for the bundled
application, not the components of an explicit custom definition. Custom
definitions retain their declared component intent, including a component
named `ingestion`. Do not remove a required custom component because the
fresh bundled application defaults to native ingestion. Native ingestion
supports configured Foundry IQ source kinds and is not feature-equivalent
to Agent App Ingestion; it does not change your source/index bindings or
authentication contract. See
[Ingestion application selection](configuration.md#ingestion-application-selection).

For applications using the bundled UI, ingestion-free operation requires the
platform v4.3.0 / UI v3.3.0 manifest-pinned combination. Follow the
[versioned migration](operations.md#upgrade-ingestion-selection-to-v430).
UI v3.2.2 still calls the ingestion endpoint for attachments; retain explicit
`DEPLOY_INGESTION_CONTAINER_APP=true` on that older combination.
Custom applications own their upload
contract: native source ingestion does not implement conversation uploads
or make an application-specific ingestion client optional.

Custom definitions keep the legacy additive bundled composition, including
the ingestion app, even when the bundled-only switch is `false`. Their
published effective ingestion capability remains `true`; the raw switch is
not permission to remove a custom or bundled dependency.

## How it works

1. You write an application definition and an `azure.yaml` that describes how to build each component.
2. You point an azd environment at the definition with `AGENTLZ_APP_DEFINITION`.
3. `azd up` first validates the definition and checks its environment binding, then provisions the platform, binds the application to the environment, assigns roles from the declared capability profiles, and deploys each component.

The platform's `preup` hook rejects invalid definitions and changed application
IDs before the deployment pipeline can create Azure resources, including an
empty resource group. The `preprovision` hook repeats validation for standalone
`azd provision`, but that later hook cannot guarantee rejection before azd's
own resource-group initialization. For a strict no-Azure-change check before
standalone provisioning, run `azd hooks run preup` first.

!!! note
    One azd environment hosts exactly one application. To deploy a different application, create a new azd environment.

## Application definition

Minimal Container App example, taken from `samples/custom-app/containerapp/app-definition.json`:

```json
{
  "schemaVersion": 1,
  "id": "sample-containerapp",
  "displayName": "Sample custom application (Container App)",
  "components": [
    {
      "name": "web",
      "kind": "containerapp",
      "path": "src",
      "source": { "commit": "0000000000000000000000000000000000000000" },
      "profiles": [],
      "ingress": "external",
      "resources": { "cpu": 0.5, "memory": "1.0Gi" }
    }
  ],
  "settings": [
    { "key": "SAMPLE_GREETING", "value": "Hello from the sample application" }
  ]
}
```

The all-zero commit is a placeholder. Replace it with the commit you deploy (see [Source pinning](#source-pinning)).

### Fields

| Field | Required | Rules |
| --- | --- | --- |
| `schemaVersion` | Yes | Must be `1`. |
| `id` | Yes | Application identifier. |
| `displayName` | No | Human-readable name. |
| `components[].source` | Yes | Either `commit` (40 hex characters) or `imageDigest` (`sha256:` followed by 64 hex characters). |
| `components[].name` | Yes | Matches `^[a-z][a-z0-9-]{1,23}$`. Must match the service name in `azure.yaml`. |
| `components[].kind` | Yes | `containerapp` or `azure.ai.agent`. |
| `components[].path` | Yes | Relative path to the component source. Must not contain `..`. |
| `components[].profiles` | No | Capability profiles. See [Capability profiles](#capability-profiles). |
| `components[].ingress` | No | `external` or `internal`. Default `internal`. Container Apps only. |
| `components[].resources.cpu` | No | `0.25`, `0.5`, `0.75`, `1.0`, `1.5`, or `2.0`. Default `0.5`. Container Apps only. |
| `components[].resources.memory` | No | `0.5Gi` to `4.0Gi`. Default `1.0Gi`. Container Apps only. |
| `settings[]` | No | Each entry has an uppercase `key`, 2–64 characters, which must not start with `AGENTLZ_`, and either `value` or `secret`. |

Components of kind `azure.ai.agent` run as Foundry hosted agents and cannot set `ingress` or `resources`. The hosted sample in `samples/custom-app/hosted/app-definition.json` defines one component named `agent` with `profiles: ["model-user"]`.

Settings are validated against the schema. They are not published to App Configuration by the platform.

### What a definition cannot contain

- Lifecycle hooks.
- Remote repository URLs. Code is always read from the local working tree.
- Azure role names. Permissions come only from capability profiles.

## Capability profiles

Every component receives the `base` profile. Add the others only when the component needs them.

Container App profile assignments are reconciled during post-provisioning.
For custom hosted services, foundation provisioning prepares registry pull
access for the existing Foundry project managed identity. This is separate
from capability-profile reconciliation for each hosted instance: deployment
first verifies the actual routed agent version and its instance identity
against the selected Foundry project, then
reconciles the declared profiles before running the greeting smoke. No bundled
orchestrator permissions are substituted for the custom definition, and this
runtime check does not mean all instance grants precede image pull. The
deployment identity needs permission to create these scoped role assignments;
denied or ambiguous assignments fail deployment. RBAC propagation may require
an explicit, idempotent retry with the same application and image after the
reported failure; deployment does not silently bypass reconciliation.

Key Vault profile assignments use the explicit `AZURE_KEY_VAULT_NAME` override
when present, otherwise the foundation's `KEY_VAULT_NAME` output, followed by
the vault endpoint inputs. The named vault must exist in the selected resource
group. If no name is supplied and more than one vault exists, deployment fails
rather than guessing which vault should receive application permissions.

| Profile | Roles assigned to the component identity |
| --- | --- |
| `base` (always applied) | App Configuration Data Reader, AcrPull, Key Vault Secrets User |
| `model-user` | Cognitive Services User, Cognitive Services OpenAI User |
| `retrieval-reader` | Search Index Data Reader, Storage Blob Data Reader |
| `conversation-store` | Cosmos DB Built-in Data Contributor |
| `blob-delegator` | Storage Blob Data Reader, Storage Blob Delegator |
| `ingestion-writer` | Search Index Data Contributor, Storage Blob Data Contributor |

For reference, the default application uses these profiles:

| Component | Profiles |
| --- | --- |
| UI | `blob-delegator` |
| Orchestrator | `model-user`, `retrieval-reader`, `conversation-store` |
| Ingestion (when selected) | `model-user`, `conversation-store`, `ingestion-writer` |

## Folder layout and `azure.yaml`

The folder that contains the definition must also contain a root `azure.yaml` with one service per component. Service names must equal component names, and the file must not declare hooks.

`components[].path` points to the service source, not to another azd project.
Keep `azure.yaml` next to `app-definition.json` and set each service's `project`
to its source folder. The pre-deploy hook reuses the selected environment in
the definition folder and deploys each declared service by name, rather than
deploying all services repeatedly.

```yaml
name: sample-containerapp
services:
  web:
    host: containerapp
    project: ./src
    language: docker
    docker:
      remoteBuild: true
```

## Source pinning

- **`components[].source.commit`**: must equal the `HEAD` commit of that component's local source folder. Nothing is cloned; the platform builds from your working tree and refuses to deploy if `HEAD` differs.
- **`components[].source.imageDigest`**: deploys a prebuilt image. Set the
  corresponding service's `image` in `azure.yaml` to a qualified registry and
  repository, such as `myregistry.azurecr.io/my-app:v1`. The platform replaces
  its tag or existing digest with the definition's exact digest and deploys it
  with `docker.imagePassthrough: true`; it does not build a different image.
  Environment substitutions in `image` must resolve before deployment.

With `NETWORK_ISOLATION=true`, source-pinned Docker components build through
the foundation's dedicated `ACR_TASK_AGENT_POOL`, and the platform deploys the
immutable digest returned by the completed ACR task. The service `project`
must match `components[].path`, with `Dockerfile` and context `.` in that
folder. Other Docker options or source-build layouts fail with actionable
guidance to supply a prebuilt digest instead; they are not silently ignored.
Public source builds keep the service's normal azd build behavior.

For image handoff, the platform temporarily renders only the selected service
in the child `azure.yaml` and restores the original file even if deployment
fails. Do not run concurrent deploys or edit that file during a deployment.
For a custom Container App using the platform ACR, deployment automatically
wires registry pull authentication to the component's existing sole attached
managed identity before deploying an immutable image. This adds no identity or
RBAC assignment. The automatic wiring is specific to Container Apps and the
platform ACR; configure access separately for other private registries. Hosted
agents use the existing Foundry project managed identity for image pull, with
the foundation's declarative `AcrPull` assignment on the platform ACR, not
Container App registry wiring or a per-instance preactivation grant.
Digest pinning does not bypass registry authorization.

Foundation provisioning publishes the Foundry project and registry deployment
outputs whenever those resources are enabled, even in classic topology.
Selecting any custom `azure.ai.agent` component must also prepare the hosted
foundation (`prepareHostedAgent=true`), even when the bundled orchestrator
topology is classic. This does not deploy the bundled hosted orchestrator
(`deployHostedAgent=false` for that classic topology) or change the topology.
The selection correction tracked in
[agent-landing-zone#695](https://github.com/Azure/agent-landing-zone/issues/695)
is pending; a revision that only fixes foundation outputs is not sufficient
to prepare project-identity image pull for this combination.
For an existing failed custom hosted environment, use a platform revision
containing the selection correction, keep the same definition and immutable
image, select the environment with `azd env select <name>`, then run
`azd hooks run preup`, `azd provision`, `azd env refresh`, and `azd deploy`
from the platform repository root. Provisioning applies the declared
project-identity pull assignment; refreshing alone cannot create it. Use a
VNet-connected host for private environments. Do not copy endpoints from
another environment or substitute broad manual grants, registry admin
credentials, or an OIDC connection workaround.
When an older environment has an empty project output, the quota preflight
can discover a single existing Foundry project in the selected resource group.
It credits only matching, successfully provisioned model allocations after
verifying the account scope and region. Ambiguous projects receive no credit;
select the intended project explicitly instead of bypassing the quota check.

## Reading platform outputs at runtime

Components find platform resources through App Configuration. Each component receives `APP_CONFIG_ENDPOINT` and reads the `AGENTLZ_PLATFORM_OUTPUTS` key with label `agent-lz`. Both samples show the pattern: the Container App sample serves `GET /health` and `GET /`, and the hosted sample answers the Responses protocol.

The platform-output publisher discovers the provisioned Container App identities for the selected definition and publishes their client IDs in `identities` and the matching `AGENTLZ_IDENTITY_<COMPONENT>_CLIENT_ID` keys. Hosted-agent instance identities are not available during foundation provisioning. Missing or ambiguous Container App identities fail publication rather than producing a success-shaped empty map; see [Platform outputs](deploy-infra-only.md#platform-outputs).

Custom hosted services must declare `invocations` or `responses` in their
`azure.yaml` protocols. The greeting smoke uses the selected service name and
declared protocol, preferring `invocations` when both are available. For
Responses services, it validates either Responses SSE or a completed JSON
response with nonempty assistant output. A greeting is not evidence of
document retrieval or authorization.

## Deploy a custom application

Run these commands from the root of the Agent Landing Zone repository.

1. Validate the definition:

    ```bash
    python -m config.appdefinition --validate path/to/your-app
    ```

2. Create a new environment and select the definition:

    ```bash
    azd env new my-custom-app
    azd env set AGENTLZ_APP_DEFINITION path/to/your-app/app-definition.json
    ```

    You can also select the containing folder:
    `azd env set AGENTLZ_APP_DEFINITION path/to/your-app`.

3. Deploy:

    ```bash
    azd up
    ```

During `azd up`, the pre-deploy hook validates the definition and checks that it is bound to the environment. A mismatch stops the deployment with exit code 2.

## `config.appdefinition` reference

| Option | Description |
| --- | --- |
| `--validate [PATH]` | Validate a definition file or folder. Without a path, validates the definition selected for the environment. |
| `--bind` | Bind the selected definition to the environment. |
| `--check-binding` | Verify that the environment is bound to the selected definition. Cannot be combined with `--bind`. |
| `--assign-roles` | Assign capability-profile roles to the identities of `containerapp` components. |
| `--env-name NAME` | azd environment. Defaults to `AZURE_ENV_NAME` or the azd default environment. |
| `--azure-dir PATH` | azd folder. Defaults to `<repo>/.azure`. |

## Related pages

- [Deploy infra only](deploy-infra-only.md)
- [Hosted agents](hosted-agents.md)
- [Configuration](configuration.md)
