# Bring your own app

## Objective

Customize the Agent Application or deploy a different, customer-owned application
with pinned deployment inputs. A different application must implement the
authentication, UI and ingestion API contracts for any components it reuses.

## When to use

Use this runbook when documented configuration is insufficient or you need a
different application. Choose the branch that matches your change:

| Goal | Start here |
| --- | --- |
| Change a documented setting | [Deployment settings](configuration.md); no source fork needed |
| Extend the Agent Application orchestrator or tools | [Agent tools](agent-tools.md), then pin only changed components below |
| Deploy a different application | The custom hosted example and its application definition below |

For the Agent Application orchestrator hosted in Foundry, use [Foundry IQ](foundry-iq.md) for
knowledge base retrieval. Custom strategies and tools must implement and test
the hosted entrypoint and authorization path before deployment to Foundry.
The default remains `maf_lite` with Foundry IQ.

The supplied UI/hosted native path integrates delegated Search authorization.
A source fork or capability profile does not automatically preserve it.
Custom applications must implement and test the same identity and source
permission boundaries before using protected documents; do not substitute a
strategy flag.

<span id="before-you-start"></span>

## Prerequisites

- Prepare the platform checkout, Python hook dependencies, Azure sign-in and
  deployment permissions in the [Deploy full stack runbook](deploy-full-stack.md).
  Commands below run from the platform root unless stated otherwise.
- The deployment identity must be able to create scoped role assignments.
  Private Git sources also require noninteractive read access on the actual
  runner; Azure sign-in does not authorize Git.
- Hosted components require the runner's Foundry agent-authoring access on the
  exact project, plus account read access. Review the
  [hosted deployment permissions](deploy-full-stack.md#foundry-orchestrator-hosted-no-panel-or-hosted-panel)
  for the required scopes.
- Private deployments require a connected host with private DNS resolution.
  An ACR build pool does not provide that host's connectivity.
- For a different application, create a **new azd environment** through the
  deployment runbook and select its definition before provisioning.

Definitions and manifests are deployment inputs, not runtime configuration.
Keep secrets out of both. For App Configuration updates under label `agent-lz`
and hosted redeployment requirements, follow [Deployment settings](configuration.md).
Do not restart a Container App to refresh a Foundry-hosted agent.

## Procedure

Choose **Customize an Agent Application component** for a source change.
For a different application, follow **Application binding and selection**, then
**Deploy a different application**. Inspect the contract reference below when
editing the definition.

<span id="customize-a-bundled-component"></span>

### Customize an Agent Application component

Prefer configuration first. Fork only runtime repositories whose source you
change; an orchestrator extension does not require UI or ingestion forks.
Fork or mirror the platform when maintaining deployment inputs or automation.
Changing its Git remote does not change component repository URLs.

#### Pin the modified component

For an orchestrator customization:

1. Implement and test the hosted entrypoint and changed behavior, including
   Foundry IQ retrieval where relevant. Commit and publish a stable tag.
2. Update its `repo`, `tag` and full 40-character Git commit hash together in the
   platform `manifest.json`. The fetch path selects a tag, or branch when no
   tag is set, then verifies HEAD. A commit hash alone is not a selectable fetch reference.
3. Set the Agent Application definition's orchestrator `source.commit` to the **same hash**.
   Keep application ID `agent-lz-default` and unchanged component pins.
4. Validate:

    ```bash
    python -m config.appdefinition --validate app-definition.json
    ```

5. Commit both pin files together. Follow the [Deploy full stack runbook](deploy-full-stack.md)
   and [hosted image preparation](hosted-agents.md), which builds from the
   manifest-pinned orchestrator. A startup-variable change cannot convert a
   Container App image into a supported hosted image.
6. Verify the deployed version and changed behavior through the UI. Test both
   authorized and denied access to protected content.

Keep manifest names `agent-app-ui`, `agent-app-orchestrator`,
`agent-app-ingestion` and definition names `ui`, `orchestrator`, `ingestion`.
Hooks use these to map sibling folders. Existing checkouts are verified, not
advanced automatically: preserve local work before relocating stale checkouts.
Matching HEAD does not detect uncommitted source changes. Run
`git status --porcelain` in each source folder and require no output for the
source being built; retain reviewed deployment-input edits separately.

Upstream validation does not cover your modifications. Before deployment,
record the previous tested pin files and image provenance for [deployment rollback](#rollback).

#### Private Git authentication

Use an approved credential helper, short-lived token or SSH identity with
repository read access, including for hosted image preparation. Test it as the
deployment runner. Never put credentials in URLs, definitions, environment files
or logs. See [Azure DevOps](azure-devops.md) for the optional pipeline.

### Application binding and selection

One azd environment hosts one application ID. Set `AGENTLZ_APP_DEFINITION` in
that environment with `azd env set` to select a definition file or containing
folder; omission selects the Agent Application.
Select it **before first provision**.

The `preup` lifecycle hook rejects invalid definitions and changed application IDs
before Azure resource creation. The `preprovision` hook repeats validation for standalone
`azd provision`, but cannot guarantee rejection before azd initializes its
resource group. Run `azd hooks run preup` first for that safeguard.
Do not edit a binding to force another application into an existing environment.

<details markdown="1">
<summary>Ingestion and additive composition</summary>

`DEPLOY_INGESTION_CONTAINER_APP` selects Agent Application composition, not components in
an explicit custom definition. Foundation composition remains additive:
Agent Application Container App placeholders can remain alongside custom resources.
Published ingestion capability describes the platform's ingestion selection;
your application must implement uploads if it needs them.
If reusing Agent App UI, preserve its
[upload-gate contract](ingestion.md).

</details>

### Deploy a different application

Use `samples/custom-app/hosted/`. Its minimal Responses server demonstrates
deployment and configuration access, not retrieval, conversation storage or
the Agent App UI API. Microsoft's
[Hosted agents documentation](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/hosted-agents)
describes service protocols and identities; the platform contracts below govern
this release's deployment.

1. Inspect the custom hosted example's `app-definition.json`, `azure.yaml`
   and `src/main.py`.
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
    value. Run `git rev-parse HEAD` from the source repository: the shipped `src`
    belongs to the platform repository; a separate source repository needs its
    own HEAD.

    Set the pin in the deployment
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
    binding, not image availability or application behavior. Schema validation
    accepts the all-zero editing marker; deployment requires actual source HEAD.

5. For a custom-only deployment, set `DEPLOYMENT_TOPOLOGY=classic` in the azd
   environment **before first provision** to suppress the bundled hosted
   orchestrator selection. This is a custom-definition composition requirement,
   not a second Agent Application deployment path. The custom hosted component
   receives its required hosted foundation resources.

    Then provision the selected definition using
    the [Deploy infra only runbook](deploy-infra-only.md), and run root `azd deploy`.
    Its service uses its own source/image
    contract, not the Agent Application hosted image-preparation handoff.

6. With the custom hosted example's answer logic, confirm the response names
   the intended project endpoint. A value of `unknown` or `unavailable` indicates
   missing project configuration or failed configuration access. Check the
   published outputs and logs, and resolve the issue before proceeding.
   With your logic, verify actual application behavior and denied-access cases.

The definition `id` binds the environment; `agent` names the component/service;
`sample-hosted-agent` names the custom example's Foundry agent. The project endpoint
URL is supplied separately at runtime. For a Container App instead, use
`samples/custom-app/containerapp/` and its matching service file; changing only
the hosted example's `kind` is insufficient.

### Verify and recover

Retain the definition, service file, source/image pin and environment together.
For HEAD mismatches, compare `git rev-parse HEAD` inside the source folder with
the declared pin without disabling validation.

For image-pull or role failures, keep the same application ID and immutable image.
Use [custom hosted image-pull recovery](troubleshooting.md#custom-hosted-image-pull-fails-with-a-classic-bundled-orchestrator).
Do not substitute another environment's endpoints, broad grants or registry admin
credentials. Role propagation can require an explicit retry.

### Application definition

#### Shipped example

Inspect the
[custom hosted example files](https://github.com/Azure/agent-landing-zone/tree/main/samples/custom-app/hosted)
rather than copying an illustrative payload.
Read them at your recorded platform commit; the default branch can advance.

#### Fields

The authoritative
[v1 schema](https://github.com/Azure/agent-landing-zone/blob/main/contracts/app-definition-v1.schema.json)
defines required fields and allowed values. In particular, names must match
services, paths stay inside the application folder, and hosted components
cannot set Container App `ingress` or `resources`.

Definition settings are validated but **not published to App Configuration**.
Arrange runtime configuration separately.

#### Runtime egress declarations

Each component can declare additional outbound dependencies with `egress`:

```json
"egress": [
  {
    "fqdn": "api.example.com",
    "protocol": "https",
    "port": 443,
    "purpose": "Retrieve the application's approved reference data"
  }
]
```

Use exact DNS FQDNs, lowercase `http` or `https`, an integer port from 1 to
64000 and a nonblank purpose of at most 256 characters. URLs, paths, wildcards,
IP addresses and local hostnames are rejected. Each component supports at most
100 entries; destinations are normalized to lowercase.

An explicit `egress: []` means no additional runtime egress and removes that
component's ownership of previously generated requirements. Omitting `egress`
remains valid: an enabled legacy component retains its previously owned
requirements, but a fresh legacy definition adds none. Removing a component
removes its ownership, not another component's shared dependency.

Review the exact source's fixed downloads and configured integrations when
editing these declarations. The bundled UI declares `[]`; both orchestrator
and ingestion declare the tiktoken asset host over HTTPS/443. A custom
definition is additive, so its plan can also include bundled workloads.
Follow [runtime egress review and reconciliation](network-isolation.md#component-runtime-egress)
before provisioning. Build registries and package feeds are configured
[separately](network-isolation.md#application-specific-package-feeds).

#### What a definition cannot contain

No lifecycle hooks, Azure role names or remote URLs (except `$schema`).
Configure endpoints separately and grant permissions through capability profiles.

### Capability profiles

Every component receives `base`; add only required profiles from the
[profile catalog](https://github.com/Azure/agent-landing-zone/blob/main/config/appdefinition/profiles.py).
These profiles grant service-resource access to component identities.
Configure user consent and document authorization separately, preserving
[authentication and OBO](application-auth.md) and
[Foundry IQ source permissions](foundry-iq.md).

Container App profiles reconcile during post-provisioning. Hosted image pull
uses the existing Foundry **project** managed identity. After deployment verifies
the routed agent version and **instance** identity, it reconciles that instance's
declared profiles before greeting smoke. Agent Application orchestrator grants are not
substituted; denied or ambiguous assignments fail deployment.

Key Vault targeting and scope resolution follow the
[role assignment contract](https://github.com/Azure/agent-landing-zone/blob/main/config/appdefinition/roles.py);
ambiguous resources are not guessed.

### Folder layout and `azure.yaml`

Keep `azure.yaml` beside the definition, with a matching service for each
component and no project/service hooks. `components[].path` points to source,
not another azd project; align the service's `project` with it.
Hosted services need an explicit agent `name` and `responses` or `invocations`.
Deployment reuses the selected environment and deploys each service by name.

### Source pinning

- **`source.commit`:** must equal the local source folder's HEAD. Nothing is
  cloned; builds include uncommitted working-tree changes.
- **`source.imageDigest`:** requires a qualified service `image` in `azure.yaml`.
  Deployment replaces its tag/digest with the exact declared digest and uses
  image passthrough, not a new build. All environment substitutions must resolve.

With `NETWORK_ISOLATION=true`, source Docker builds use `ACR_TASK_AGENT_POOL`
and deploy the resulting digest. Service `project` must match component path,
with `Dockerfile` and context `.` there. Unsupported layouts/options fail;
provide a prebuilt digest instead. Public builds retain normal azd behavior.
See the [deployment contract](https://github.com/Azure/agent-landing-zone/blob/main/config/deployment/custom_application.py).

Deployment temporarily rewrites image settings in the child `azure.yaml` and
restores it even on failure. Do not edit it or deploy concurrently.
Digest pins do not bypass registry authorization. Custom Container Apps using
the platform ACR receive registry wiring to their sole attached identity;
other registries need separate access configuration. Hosted agents use the
project identity's declarative platform-ACR pull grant.

Custom hosted components receive hosted foundation prerequisites even with a
Container App layout for the bundled orchestrator; this does not deploy the
bundled hosted orchestrator.
Reapplying foundation can repair its declared pull grant; refreshing outputs
alone cannot. Follow the recovery link above.

### Reading platform outputs at runtime

Read `AGENTLZ_PLATFORM_OUTPUTS` from `APP_CONFIG_ENDPOINT` with label `agent-lz`,
as both custom application examples demonstrate. The publisher exposes selected Container App
client IDs; hosted instance identities are unavailable during foundation
provisioning. See [published platform outputs](deploy-infra-only.md#platform-outputs).

The hosted greeting checks for nonempty assistant output using the declared
protocol, preferring `invocations` when both are present. Validate retrieval and
authorization with representative tasks and allowed and denied identities.

### Validate and select a definition

Use the validation/selection commands above with your own definition path.
Pre-deploy rechecks definition and binding; mismatches exit with code 2.
For foundation without application deployment, follow
the [Deploy infra only runbook](deploy-infra-only.md).

### `config.appdefinition` reference

Use `python -m config.appdefinition --help` for options. The
[CLI source](https://github.com/Azure/agent-landing-zone/blob/main/config/appdefinition/__main__.py)
defines validation, binding checks, environment selection and Container App
profile assignment. Do not use binding commands to replace an environment's application.

### Related pages

- [Deploy full stack runbook](deploy-full-stack.md)
- [Hosted agents](hosted-agents.md)
- [Deployment settings](configuration.md)

## Validation

1. Run definition validation and confirm the environment remains bound to its
   intended application ID.
2. In each source folder, compare `git rev-parse HEAD` with its declared commit.
   Inspect `git status --porcelain`; permit only recorded deployment-input edits,
   not uncommitted application source changes.
3. Compare the registry digest and selected service/version image with the
   recorded build or prebuilt digest. Confirm placeholders are no longer serving.
4. Exercise the changed behavior with allowed and denied identities. For the
   custom hosted example, confirm configuration access as described in Step 6.
   Do not accept protected retrieval until its identity integration is proven.

## Rollback

1. Stop promotion. Restore the previous tested definition and service file,
   keeping the same application ID. For Agent Application customizations,
   restore both manifest and definition pins together.
2. Restore the source checkout to its declared commit, preserving local work
   separately, or verify the previous immutable image remains available to the
   runtime identity. Do not replace a digest with a mutable tag.
3. Preview foundation changes before applying them. Redeploy through the same
   procedure used above: automatic hosted Agent Application image preparation
   during deploy, or the custom service's own definition contract.
4. Restore separately managed settings using recorded values and repeat
   [Validation](#validation). Redeployment does not reverse data/schema changes;
   use an owner-approved recovery plan if the previous application is incompatible.

Do not edit the binding, delete data or broaden permissions to force rollback.
Deleting the local definition does not remove Azure resources.
