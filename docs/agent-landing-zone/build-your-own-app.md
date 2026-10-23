# Bring your own app

Choose whether to customize the bundled application or deploy a different one.
The result is a pinned, reproducible application deployment—not automatic
compatibility with the bundled UI, authentication or ingestion APIs.

| Goal | Start here |
| --- | --- |
| Change a documented setting | [Configuration](configuration.md); no source fork needed |
| Extend the bundled agent or tools | [Agent tools](agent-tools.md), then pin only changed components below |
| Deploy a different application | The shipped hosted sample and its application definition below |

For the bundled agent hosted in Foundry, use [Foundry IQ](foundry-iq.md) for
knowledge base retrieval. Custom strategies and tools must support the hosted
entrypoint and authorization path; registering a strategy does not make a
classic-only implementation hosted-ready.

## Before you start

- Prepare the platform checkout, Python hook dependencies, Azure sign-in and
  deployment permissions in [Full stack deploy](deploy-full-stack.md).
  Commands below run from the platform root unless stated otherwise.
- The deployment identity must be able to create scoped role assignments.
  Private Git sources also require noninteractive read access on the actual
  runner; Azure sign-in does not grant Git access.
- Private deployments require a connected host with private DNS resolution.
  An ACR build pool does not provide that host's connectivity.
- For a different application, create a **new azd environment** through the
  deployment runbook and select its definition before provisioning.

Definitions and manifests are deployment inputs, not runtime configuration.
Keep secrets out of both. For App Configuration updates under label `agent-lz`
and hosted redeployment requirements, follow [Configuration](configuration.md).
Do not restart a Container App to refresh a Foundry-hosted agent.

## Customize a bundled component

Prefer configuration first. Fork only runtime repositories whose source you
change; an orchestrator extension does not require UI or ingestion forks.
Fork or mirror the platform when maintaining deployment inputs or automation.
Changing its Git remote does not change component repository URLs.

<details markdown="1">
<summary>Updating older repository remotes</summary>

The current repositories are `Azure/agent-landing-zone`, `Azure/agent-app-ui`,
`Azure/agent-app-orchestrator` and `Azure/agent-app-ingestion`, replacing
`Azure/GPT-RAG` and the corresponding `Azure/gpt-rag-*` runtime names.
Remote changes do not update pins or migrate Azure deployments; use the
[upgrade runbook](deploy-full-stack.md#upgrade-to-a-new-release).

</details>

### Pin the modified component

For an orchestrator customization:

1. Implement and test the hosted entrypoint and changed behavior, including
   Foundry IQ retrieval where relevant. Commit and publish a stable tag.
2. Update its `repo`, `tag` and full 40-character `commit` together in the
   platform `manifest.json`. The fetch path selects a tag, or branch when no
   tag is set, then verifies HEAD. A SHA alone is not a selectable fetch ref.
3. Set the bundled definition's orchestrator `source.commit` to the **same SHA**.
   Keep application ID `agent-lz-default` and unchanged component pins.
4. Validate:

    ```bash
    python -m config.appdefinition --validate app-definition.json
    ```

5. Commit both pin files together. Follow [Full stack deploy](deploy-full-stack.md)
   and [hosted image preparation](hosted-agents.md), which builds from the
   manifest-pinned orchestrator. A startup-variable change cannot convert a
   classic image into a supported hosted image.
6. Verify the deployed version and changed behavior through the UI. Test both
   authorized and denied access to protected content; a greeting is insufficient.

Keep manifest names `agent-app-ui`, `agent-app-orchestrator`,
`agent-app-ingestion` and definition names `ui`, `orchestrator`, `ingestion`.
Hooks use these to map sibling folders. Existing checkouts are verified, not
advanced automatically: preserve local work before relocating stale checkouts.
Matching HEAD does not detect uncommitted source changes.

To undo, restore both pin files to the previous tested combination and redeploy
its hosted image. Upstream release validation does not cover your modifications.

### Private Git authentication

Use an approved credential helper, short-lived token or SSH identity with
repository read access, including for hosted image preparation. Test it as the
deployment runner. Never put credentials in URLs, definitions, environment files
or logs. See [Azure DevOps](azure-devops.md) for the optional pipeline.

## Application binding and selection

One azd environment hosts one application ID. `AGENTLZ_APP_DEFINITION` selects
a definition file or containing folder; omission selects the bundled app.
Select it **before first provision**, not merely before deployment.

`preup` rejects invalid definitions and changed application IDs before Azure
resource creation. `preprovision` repeats validation for standalone
`azd provision`, but cannot guarantee rejection before azd initializes its
resource group. Run `azd hooks run preup` first for that safeguard.
Do not edit a binding to force another application into an existing environment.

<details markdown="1">
<summary>Ingestion and additive composition</summary>

`DEPLOY_INGESTION_CONTAINER_APP` selects bundled composition, not components in
an explicit custom definition. Foundation composition remains additive:
bundled Container App placeholders can remain alongside custom resources.
Published ingestion capability is not proof that your app implements uploads.
If reusing the bundled UI, preserve its
[upload-gate contract](ingestion.md#upgrade-and-retirement-safety).

</details>

## Application definition

### Deploy a different application

Use `samples/custom-app/hosted/`. Its minimal Responses server demonstrates
deployment and configuration access, not retrieval, conversation storage or
the bundled UI API. Microsoft's
[Hosted agents documentation](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/hosted-agents)
describes service protocols and identities; the platform contracts below govern
this release's deployment.

1. Inspect the sample's `app-definition.json`, `azure.yaml` and `src/main.py`.
   Keep component/service name `agent`, the explicit hosted agent name and
   Responses protocol aligned.
2. Replace the answer logic, preserving the protocol and health endpoints.
   Implement authentication, authorization and runtime configuration loading;
   capability profiles do not implement these behaviors.
3. Commit source changes. Obtain the full source repository commit:

    ```bash
    git rev-parse HEAD
    ```

    Replace the definition's all-zero `components[0].source.commit` with that
    value. The shipped `src` belongs to the platform repository; a separate
    source repository needs its own HEAD. Set the pin in the deployment
    workspace **after checkout**; another commit changes HEAD again. Keep source
    files unchanged. For durable committed inputs in a single-repository layout,
    consider the prebuilt image digest contract below.
4. Validate and select in the **new** environment:

    ```bash
    python -m config.appdefinition --validate samples/custom-app/hosted
    azd env set AGENTLZ_APP_DEFINITION samples/custom-app/hosted/app-definition.json
    azd hooks run preup
    ```

    Expect validation to pass. This checks schema, folder/service contracts and
    binding—not image availability or application behavior. Schema validation
    accepts the all-zero editing marker; deployment requires actual source HEAD.
5. Follow the **custom-application path** in [Full stack deploy](deploy-full-stack.md),
   not the bundled hosted-orchestrator image handoff. The platform deploys the
   declared service and runs its greeting smoke.
6. With the sample answer logic, confirm the response names the intended project
   endpoint, not `unknown` or `unavailable`. The sample can greet successfully
   despite failed configuration access; inspect logs for either value. With your
   logic, verify actual application behavior and denied-access cases.

The definition `id` binds the environment; `agent` names the component/service;
`sample-hosted-agent` names the sample Foundry agent. None is the project endpoint
URL. For a Container App instead, use `samples/custom-app/containerapp/` and its
matching service file; changing only the hosted sample's `kind` is insufficient.

### Verify and recover

Retain the definition, service file, source/image pin and environment together.
For HEAD mismatches, compare `git rev-parse HEAD` inside the source folder with
the pin; do not remove the check.

For image-pull or role failures, keep the same application ID and immutable image.
Use [custom hosted image-pull recovery](troubleshooting.md#custom-hosted-image-pull-fails-with-a-classic-bundled-orchestrator).
Do not substitute another environment's endpoints, broad grants or registry admin
credentials. Role propagation can require an explicit retry.

Rollback restores the tested definition, service configuration and pinned
source/image before redeployment; it does not reverse data/schema changes.
Use [Full stack deploy](deploy-full-stack.md) for environment cleanup; deleting
the local definition does not remove Azure resources.

### Shipped example

Use the versioned
[hosted sample files](https://github.com/Azure/agent-landing-zone/tree/v4.3.0/samples/custom-app/hosted)
rather than copying an illustrative payload.

### Fields

The authoritative
[v1 schema](https://github.com/Azure/agent-landing-zone/blob/v4.3.0/contracts/app-definition-v1.schema.json)
defines required fields and allowed values. In particular, names must match
services, paths stay inside the application folder, and hosted components
cannot set Container App `ingress` or `resources`.

Definition settings are validated but **not published to App Configuration**.
Arrange runtime configuration separately.

### What a definition cannot contain

No lifecycle hooks, Azure role names or remote URLs (except `$schema`).
Configure endpoints outside the definition and permissions through profiles.

## Capability profiles

Every component receives `base`; add only required profiles from the
[profile catalog](https://github.com/Azure/agent-landing-zone/blob/v4.3.0/config/appdefinition/profiles.py).
These service-resource grants are not user consent or document ACL enforcement.
Preserve [authentication and OBO](application-auth.md) and
[Foundry IQ source permissions](foundry-iq.md).

Container App profiles reconcile during post-provisioning. Hosted image pull
uses the existing Foundry **project** managed identity. After deployment verifies
the routed agent version and **instance** identity, it reconciles that instance's
declared profiles before greeting smoke. Bundled orchestrator grants are not
substituted; denied or ambiguous assignments fail deployment.

Key Vault targeting and scope resolution follow the
[role assignment contract](https://github.com/Azure/agent-landing-zone/blob/v4.3.0/config/appdefinition/roles.py);
ambiguous resources are not guessed.

## Folder layout and `azure.yaml`

Keep `azure.yaml` beside the definition, with a matching service for each
component and no project/service hooks. `components[].path` points to source,
not another azd project; align the service's `project` with it.
Hosted services need an explicit agent `name` and `responses` or `invocations`.
Deployment reuses the selected environment and deploys each service by name.

## Source pinning

- **`source.commit`:** must equal the local source folder's HEAD. Nothing is
  cloned; builds use the working tree, including uncommitted changes.
- **`source.imageDigest`:** requires a qualified service `image` in `azure.yaml`.
  Deployment replaces its tag/digest with the exact declared digest and uses
  image passthrough, not a new build. Environment substitutions must resolve.

With `NETWORK_ISOLATION=true`, source Docker builds use `ACR_TASK_AGENT_POOL`
and deploy the resulting digest. Service `project` must match component path,
with `Dockerfile` and context `.` there. Unsupported layouts/options fail;
provide a prebuilt digest instead. Public builds retain normal azd behavior.
See the [deployment contract](https://github.com/Azure/agent-landing-zone/blob/v4.3.0/config/deployment/custom_application.py).

Deployment temporarily rewrites image settings in the child `azure.yaml` and
restores it even on failure. Do not edit it or deploy concurrently.
Digest pins do not bypass registry authorization. Custom Container Apps using
the platform ACR receive registry wiring to their sole attached identity;
other registries need separate access configuration. Hosted agents use the
project identity's declarative platform-ACR pull grant.

Custom hosted components receive hosted foundation prerequisites even with a
classic bundled topology; this does not deploy the bundled hosted orchestrator.
Reapplying foundation can repair its declared pull grant; refreshing outputs
alone cannot. Follow the recovery link above.

## Reading platform outputs at runtime

Read `AGENTLZ_PLATFORM_OUTPUTS` from `APP_CONFIG_ENDPOINT` with label `agent-lz`,
as both samples demonstrate. The publisher exposes selected Container App
client IDs; hosted instance identities are unavailable during foundation
provisioning. See [Platform outputs](deploy-infra-only.md#platform-outputs).

The hosted greeting checks nonempty assistant output using the declared
protocol, preferring `invocations` when both are present. It does not verify
retrieval or authorization.

## Validate and select a definition

Use the validation/selection commands above with your own definition path.
Pre-deploy rechecks definition and binding; mismatches exit with code 2.
For foundation without application deployment, follow
[Deploy infrastructure only](deploy-infra-only.md).

## `config.appdefinition` reference

Use `python -m config.appdefinition --help` for options. The
[CLI source](https://github.com/Azure/agent-landing-zone/blob/v4.3.0/config/appdefinition/__main__.py)
defines validation, binding checks, environment selection and Container App
profile assignment. Binding commands are not a migration mechanism.

## Related pages

- [Full stack deploy](deploy-full-stack.md)
- [Hosted agents](hosted-agents.md)
- [Configuration](configuration.md)
