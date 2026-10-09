# Custom applications

Agent Landing Zone deploys the default application (Agent App UI, Agent App Orchestrator, and Agent App Ingestion) unless you select a different one. You can deploy your own application on the same platform by describing it in an **application definition**: a JSON file validated against `contracts/app-definition-v1.schema.json`.

The platform owns identity, networking, and permissions. Your application declares only what it is, where its code lives, and which capabilities it needs.

## How it works

1. You write an application definition and an `azure.yaml` that describes how to build each component.
2. You point an azd environment at the definition with `AGENTLZ_APP_DEFINITION`.
3. `azd up` provisions the platform, validates the definition, binds it to the environment, assigns roles from the declared capability profiles, and deploys each component.

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
For custom hosted services, deployment first verifies the actual routed agent
version and its instance identity against the selected Foundry project, then
reconciles the declared profiles before running the greeting smoke. No bundled
orchestrator permissions are substituted for the custom definition. The
deployment identity needs permission to create these scoped role assignments;
denied or ambiguous assignments fail deployment. RBAC propagation may require
an idempotent retry with the same application and image.

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
| Ingestion | `model-user`, `conversation-store`, `ingestion-writer` |

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
Private registry access must already be configured for the Container App or
Foundry project identity; digest pinning does not bypass registry RBAC.

Foundation provisioning publishes the Foundry project and registry deployment
outputs whenever those resources are enabled, even in classic topology.
Custom hosted services do not require selection of the bundled hosted
orchestrator merely to receive their project endpoint. After upgrading the
foundation output correction, rerun provisioning to refresh the selected azd
environment before deploying; do not copy endpoints from another environment.
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
