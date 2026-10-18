# Custom applications

You can extend a bundled component or bring a different application to the
foundation. Choose the contract that matches your change:

| Goal | Approach |
| --- | --- |
| Change a documented setting | Use [Configuration](configuration.md); no source fork is needed. |
| Extend the bundled UI, agent strategies/tools or ingestion code | Fork only the component you change and update its coordinated pins below. |
| Deploy a different application composition | Supply an application definition and its matching `azure.yaml`. |

The orchestrator is an extensible agent architecture. Its registered strategies
include model/tool coordination, MCP, NL2SQL, multimodal and retrieval-oriented
behavior. A strategy is not a hosting topology: Foundry hosting versus Container
Apps is a separate choice, and each strategy still needs its own configured
tools, data sources and authorization.

The platform owns identity, networking, and permissions. Your application declares only what it is, where its code lives, and which capabilities it needs.

For the platform-wide mechanism, read [How the template works](how-it-works.md).
For execution, use [Deploy infrastructure only](deploy-infra-only.md) or
[Deploy the full stack](deploy-full-stack.md).

## Customize a bundled component

An unmodified deployment does not require four forks. Fork or mirror the platform
when you need versioned deployment inputs, automation or platform changes. Fork
only the runtime repositories whose source you change. The platform fetches the
selected components; changing its Git remote does not change their repository
URLs.

Prefer configuration over source changes. Forking the orchestrator to add a
strategy does not require forking the UI, ingestion or upstream infrastructure.
Keep your platform changes in its repository-owned `infra/` tree when needed,
with upstream provenance recorded separately in `manifest.json`.

<details markdown="1">
<summary>Updating older repository remotes</summary>

Older clones can still use the previous repository names. Update your remotes
and automation to the current names even where GitHub redirects still work:

| Previous | Current |
| --- | --- |
| `Azure/GPT-RAG` | `Azure/agent-landing-zone` |
| `Azure/gpt-rag-ui` | `Azure/agent-app-ui` |
| `Azure/gpt-rag-orchestrator` | `Azure/agent-app-orchestrator` |
| `Azure/gpt-rag-ingestion` | `Azure/agent-app-ingestion` |

Changing a remote does not update component pins or migrate an Azure deployment.
Use the [upgrade runbook](deploy-full-stack.md#upgrade-to-a-new-release) for that.

</details>

### Pin the modified component

For example, when using your organization's orchestrator fork:

1. Test and commit the component change, then publish a stable tag that resolves
   to its intended **full 40-character SHA**. The fetch path selects a published
   tag, or a branch when no tag is set, and verifies that `HEAD` matches the SHA.
   A SHA alone is not a selectable fetch ref.
2. Update that component's `repo`, `tag` and `commit` together in the platform
   `manifest.json`. Keep unchanged components at their coordinated release pins.
3. Set the bundled `app-definition.json` orchestrator `source.commit` to the
   **same SHA**. Keep application ID `agent-lz-default`. A manifest-only change
   fails bundled definition validation.
4. Validate both files with the existing hook dependencies installed:

    ```bash
    python -m config.appdefinition --validate app-definition.json
    ```

5. Commit the two pin files together and validate the complete combination before
   promotion. Upstream release validation does not cover your modified component.

Keep manifest names `agent-app-ui`, `agent-app-orchestrator` and
`agent-app-ingestion`, and bundled definition names `ui`, `orchestrator` and
`ingestion`. Hooks use those names to map entries and sibling folders.

Existing sibling checkouts are verified, not advanced automatically. Preserve
local work and relocate stale checkouts before allowing hooks to fetch selected
versions. Keep deployment working trees clean: a matching `HEAD` does not prove
there are no uncommitted changes.

Bundled hosted image preparation fetches and verifies the manifest-pinned
orchestrator separately. It builds the hosted entrypoint from that source, not a
different platform implementation. Changing only a startup variable does not
convert a classic image into a supported hosted image. See
[Image provenance and redeployment](hosted-agents.md#redeploy-the-same-image-or-prepare-a-new-one).

### Private Git authentication

Azure authentication does not authorize GitHub or Azure Repos clones. The actual
deployment runner needs noninteractive **read access** to every selected private
repository, including hosted image preparation's orchestrator checkout.

Use an approved credential helper, short-lived token or SSH identity with explicit
repository access. Test access using that runner identity. Never embed tokens in
manifest URLs, definitions, environment files or logs. Avoid shared write-enabled
credentials when read-only access is sufficient. For a protected promotion
pipeline, see the optional [Azure DevOps runbook](azure-devops.md).

## Application binding and selection

An **application definition** is validated against
`contracts/app-definition-v1.schema.json`. Its folder supplies the matching
`azure.yaml`. Select `AGENTLZ_APP_DEFINITION` before the first provision, not just
before deployment. When omitted, the bundled application is selected.

The platform's `preup` hook rejects invalid definitions and changed application
IDs before the deployment pipeline can create Azure resources, including an
empty resource group. The `preprovision` hook repeats validation for standalone
`azd provision`, but that later hook cannot guarantee rejection before azd's
own resource-group initialization. For a strict no-Azure-change check before
standalone provisioning, run `azd hooks run preup` first.

!!! note
    One azd environment hosts exactly one application. To deploy a different application, create a new azd environment.

<details markdown="1">
<summary>Ingestion and additive composition</summary>

`DEPLOY_INGESTION_CONTAINER_APP` selects the bundled app, not components in an
explicit custom definition. Custom definitions keep their declared intent,
including any component named `ingestion`.

Current foundation composition is additive: bundled Container App
placeholders, including ingestion, remain alongside custom resources even
with the bundled-only switch set to `false`. Deployment uses the definition's
declared components. The effective published ingestion capability is `true`;
it is not evidence that your custom app implements uploads.

Preserve your application's upload/source/authentication contracts. Native
source ingestion does not replace conversation uploads or every application
ingestion feature. Applications reusing the bundled UI must also meet its
[upload-gate migration requirements](ingestion.md#upgrade-and-retirement-safety).

</details>

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
| `id` | Yes | Application identifier matching `^[a-z][a-z0-9-]{2,39}$`. Bound to the environment at the first provision. |
| `displayName` | No | Human-readable name. |
| `components[].source` | Yes | Either `commit` (40 lowercase hex characters) or `imageDigest` (`sha256:` followed by 64 lowercase hex characters). |
| `components[].name` | Yes | Matches `^[a-z][a-z0-9-]{1,23}$`. Must match the service name in `azure.yaml`. |
| `components[].kind` | Yes | `containerapp` or `azure.ai.agent`. |
| `components[].path` | Yes | Relative path to the component source. Must not contain `..`. |
| `components[].profiles` | No | Capability profiles. See [Capability profiles](#capability-profiles). |
| `components[].ingress` | No | `external` or `internal`. Default `internal`. Container Apps only. |
| `components[].resources.cpu` | No | `0.25`, `0.5`, `0.75`, `1.0`, `1.5`, or `2.0`. Default `0.5`. Container Apps only. |
| `components[].resources.memory` | No | One of `0.5Gi`, `1.0Gi`, `1.5Gi`, `2.0Gi`, `3.0Gi` or `4.0Gi`. Default `1.0Gi`. Container Apps only. |
| `settings[]` | No | Each entry requires an uppercase `key` of 2 to 64 characters that does not start with `AGENTLZ_`. Optional `value` and `secret: true` are mutually exclusive. |
| `components[].settings[]` | No | Component settings with the same key and value rules as application settings. They cannot duplicate an application setting. |

Components of kind `azure.ai.agent` run as Foundry hosted agents and cannot set `ingress` or `resources`. The hosted sample in `samples/custom-app/hosted/app-definition.json` defines one component named `agent` with `profiles: ["model-user"]`.

Settings are validated against the schema. They are not published to App Configuration by the platform.

### What a definition cannot contain

- Lifecycle hooks.
- Remote URLs in definition fields, including setting values. The optional
  `$schema` field is exempt. Configure runtime endpoints outside the
  definition, and keep source code in the local working tree.
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
deployment identity needs permission to create these scoped role assignments.
Denied or ambiguous assignments fail deployment. RBAC propagation may require
an explicit, idempotent retry with the same application and image after the
reported failure. Deployment does not silently bypass reconciliation.

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

- **`components[].source.commit`**: must equal the `HEAD` commit of that component's local source folder. Nothing is cloned. The platform builds from the working tree and refuses to deploy if `HEAD` differs. Keep the working tree clean because the commit check does not reject uncommitted source changes.
- **`components[].source.imageDigest`**: deploys a prebuilt image. Set the
  corresponding service's `image` in `azure.yaml` to a qualified registry and
  repository, such as `myregistry.azurecr.io/my-app:v1`. The platform replaces
  its tag or existing digest with the definition's exact digest and deploys it
  with `docker.imagePassthrough: true`. It does not build a different image.
  Environment substitutions in `image` must resolve before deployment.

With `NETWORK_ISOLATION=true`, source-pinned Docker components build through
the foundation's dedicated `ACR_TASK_AGENT_POOL`, and the platform deploys the
immutable digest returned by the completed ACR task. The service `project`
must match `components[].path`, with `Dockerfile` and context `.` in that
folder. Other Docker options or source-build layouts fail with actionable
guidance to supply a prebuilt digest instead. They are not silently ignored.
Public source builds keep the service's normal azd build behavior.

For image handoff, the platform temporarily updates the selected service's
image and Docker settings in the child `azure.yaml`, then restores the
original file even if deployment fails. It deploys that service by name.
Do not run concurrent deploys or edit that file during a deployment.
For a custom Container App using the platform ACR, deployment automatically
wires registry pull authentication to the component's existing sole attached
managed identity before deploying an immutable image. This adds no identity or
RBAC assignment. The automatic wiring is specific to Container Apps and the
platform ACR. Configure access separately for other private registries. Hosted
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
The current platform prepares these prerequisites for custom hosted
components independently of the bundled orchestrator topology.

For recovery, retain the same application definition and immutable image, then
apply the current coordinated platform's foundation through the
[full-stack runbook](deploy-full-stack.md). Provisioning applies the declared
project-identity pull grant; refreshing outputs alone cannot create it.

Use a connected host for private environments. Never substitute another
environment's endpoints, broad manual grants, registry admin credentials or
an OIDC connection workaround. See
[Custom hosted image-pull recovery](troubleshooting.md#custom-hosted-image-pull-fails-with-a-classic-bundled-orchestrator).

When an older environment has an empty project output, the quota preflight
can discover a single existing Foundry project in the selected resource group.
It credits only matching, successfully provisioned model allocations after
verifying the account scope and region. Ambiguous projects receive no credit.
Select the intended project explicitly instead of bypassing the quota check.

## Reading platform outputs at runtime

Components find platform resources through App Configuration. Each component receives `APP_CONFIG_ENDPOINT` and reads the `AGENTLZ_PLATFORM_OUTPUTS` key with label `agent-lz`. Both samples show the pattern: the Container App sample serves `GET /health` and `GET /`, and the hosted sample answers the Responses protocol.

The platform-output publisher discovers the provisioned Container App identities for the selected definition and publishes their client IDs in `identities` and the matching `AGENTLZ_IDENTITY_<COMPONENT>_CLIENT_ID` keys. Hosted-agent instance identities are not available during foundation provisioning. Missing or ambiguous Container App identities fail publication rather than producing an empty map. See [Platform outputs](deploy-infra-only.md#platform-outputs).

Custom hosted services must declare an explicit agent `name` and either
`invocations` or `responses` in their `azure.yaml` service definition.
The greeting smoke uses the selected service name and
declared protocol, preferring `invocations` when both are available. For
Responses services, it validates either Responses SSE or a completed JSON
response with nonempty assistant output. A greeting is not evidence of
document retrieval or authorization.

## Validate and select a definition

From the platform root, with the hook dependencies installed:

```bash
python -m config.appdefinition --validate path/to/your-app
```

The deployment input is a file or its containing folder:

```bash
azd env set AGENTLZ_APP_DEFINITION path/to/your-app/app-definition.json
```

Apply it to a **new environment before provisioning**, following
[Deploy infrastructure only](deploy-infra-only.md) or
[Deploy the full stack](deploy-full-stack.md). Pre-deploy revalidates the
definition and binding; a mismatch exits with code 2.

Selecting the bundled foundation's `classic` topology avoids a bundled hosted
orchestrator handoff. It does not prevent custom `azure.ai.agent` components from
receiving their own hosted prerequisites. Custom hosted services use their own
definition and service configuration, not the bundled image preparation script.

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
