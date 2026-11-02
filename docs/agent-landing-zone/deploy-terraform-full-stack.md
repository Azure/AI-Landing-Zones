# Deploy full stack with Terraform

## Objective

Deploy the Agent Application and the Azure resources it needs, using Terraform.
The default setup provides a web chat in Azure Container Apps.
Microsoft Foundry hosts the agent that answers messages.

Terraform creates the Azure foundation.
The shared azd commands configure services and deploy the application:

| Command | Result |
| --- | --- |
| `azd provision` | Creates and configures Azure resources |
| `azd deploy` | Builds and publishes the application |
| `azd up` | Runs both stages; use only when application login is already configured |

History, feedback and private attachments are off by default.
To enable them or choose workflows, follow the
[shared application and storage choices](deploy-full-stack.md#choose-optional-experiences-and-storage).
Document retrieval also needs the [Foundry IQ setup](foundry-iq.md).
The deployment greeting does not test these optional features.

Only need Azure resources? Use
[Deploy infra only with Terraform](deploy-terraform-infra-only.md).
For the default Bicep provider, use
[Deploy full stack with Bicep](deploy-full-stack.md).
[Terraform templates](terraform.md) explains composition, ownership and
[validation scope](terraform.md#validation-scope).

## Prerequisites

Meet the [Terraform foundation prerequisites](deploy-terraform-infra-only.md#prerequisites)
and the shared [application, identity and tooling prerequisites](deploy-full-stack.md#prerequisites).
Keep the Python environment active. Hosted deployment needs the Foundry agents
azd extension and the required authoring/runtime permissions.
Arrange application sign-in, tenant consent and access to component source
repositories separately from Azure resource deployment.

The bundled hosted path combines user-delegated Foundry invocation with native
Search permission evaluation. Configure [UI sign-in, delegated Search consent
and document authorization](application-auth.md) before onboarding users.
Bicep and Terraform use the same application configuration and per-user access
checks; anonymous or workload identity is not a fallback for source permissions.

Private deployments need a connected deployment host and, for the remote
private-registry build path, the approved ACR Tasks VNet pool. The pool does
not provide private connectivity to the deployment host.
Review [network design](network-isolation.md), quotas and recurring costs.

Replace every `<placeholder>` with an approved value before running a command.

## Procedure

### Step 1: Prepare the Terraform environment

Complete [foundation preparation Steps 1–4](deploy-terraform-infra-only.md#procedure):

- Initialize a new empty project directory with
  `azd init --template Azure/agent-landing-zone .` as shown in that guide.
  Keep the environment init creates; do not follow it with `azd env new`.
- Configure the **root**
  `azure.yaml` once with `infra.provider: terraform` and
  `infra.path: infra/terraform`, with `infra.module: main`.
  Preserve the hooks and services.
- Authenticate, select the intended environment and confirm its target.
- Confirm the cloud: `public`, `usgovernment` or `china`. Preprovision generates
  matching provider and backend cloud settings.
- Configure and verify the Azure Storage backend before provision.
- Set documented environment inputs and root `main.parameters.json` values.
  Preprovision generates typed Terraform inputs automatically.

Run every lifecycle command from the initialized product root, using its
Terraform configuration, not from `infra/terraform/`.
An environment binds to one application ID.

### Step 2: Confirm application and build choices

For a **new** default Agent Application environment:

```bash
azd env set ORCHESTRATION_HOST hosted
azd env set APPLICATION_MODE conversational
azd env set HOSTED_AGENT_RESOURCE_SCOPE <approved-foundry-audience>/.default
azd env set DEPLOY_INGESTION_CONTAINER_APP false
azd env set BUILD_MODE acr-task
```

For the private registry path, also select its build pool before provision:

```bash
azd env set DEPLOY_ACR_TASK_AGENT_POOL true
```

Keep the environment's bound application and build choices during recovery.
Use [Bring your own app](build-your-own-app.md) for a custom definition.

The root `manifest.json` records the compatible Agent Application component
repositories and commits. Hooks validate the definition against those pins,
fetch the selected sources, prepare the hosted image and coordinate deployment.
Foundation outputs pass automatically to the component projects.

Confirm `APPLICATION_MODE` and `ORCHESTRATION_HOST` through the canonical
[native execution selection](configuration.md#native-execution-selection).
Conversation is the default experience. Hosted conversation and workflow
require separate publications when both are selected; pass their actual
distinct endpoints to the UI. The Container Apps alternative uses the
official Durable Extension worker/client and provisioned DTS binding.
Do not treat every canonical runtime key as an implied `azd env` input.

For optional SQL tools, explicitly select both server and toolset before provision:

```bash
azd env set DEPLOY_AGENT_APP_MCP true
azd env set MCP_TOOLSETS '["nl2sql"]'
```

Use the [coordinated MCP platform source](agent-app-mcp.md#use-the-coordinated-platform-source)
and its complete manifest/application definition, not an isolated component
version change in another checkout.

The server default is `false`; toolsets default to `[]`. Empty server compute
does not require the NL2SQL catalog, models or secret grants.

With NL2SQL selected, Terraform projects the application's declared catalog
policies and scoped grants into generic foundation inputs, as Bicep does.
The shared application lifecycle publishes `MCP_TOOLSETS` under `agent-lz`
and generates the consuming MCP connection and authorization.
Search and document ingestion remain independent.

See [Agent App MCP Server](agent-app-mcp.md) for what is automatic and for
operator-owned SQL permissions and approved metadata import.

### Step 3: Provision the foundation

Complete the [Terraform infrastructure review](deploy-terraform-infra-only.md#step-5-review-and-provision)
before the first apply. From the **product root**, with the intended azd
environment selected:

```bash
azd provision
```

Skip this step only if you have already completed and validated the
infrastructure-only guide with the same component selection and requirements.
Adding MCP to an existing compatible installation requires a reviewed
`azd provision` followed by `azd deploy`.

Before Step 4, complete the [post-provision login setup](application-auth.md#3-register-the-final-https-callback):
register the actual UI callback, store Key Vault credential references and
publish sign-in/admission settings. The Azure foundation does not grant tenant
consent. Complete agent-scoped invocation grants after publication if that
scope is not available yet, before user acceptance.

<a id="deploy-the-application"></a>

### Step 4: Deploy the application

For an already configured foundation:

```bash
azd deploy
```

`azd up` is an alternative to Steps 3 and 4 only when login configuration is
already prepared for the intended endpoint. Otherwise keep the separate
stages so that the post-provision identity work happens before deploy.

Provisioning does not build images or publish a running agent.
`azd deploy` fetches the sources selected in `manifest.json`.
It builds the hosted image if needed and records its immutable digest.
It binds the image to the provisioned Foundry project and registry.
Then it publishes the hosted version and selected Container Apps.

If MCP is selected, deployment publishes its image before activating the applications that call it.
It resolves caller identities and checks their authorization.
It publishes allowed-caller and connection settings.

The lifecycle restarts every active MCP revision to load startup-only authentication.
It checks authenticated discovery before activating consumers.
A manual MCP restart is not required during normal deployment.

Provision does not import SQL metadata or grant database permissions.
There is no required standalone image-preparation command or second provision.

azd imports all flat Terraform outputs for the shared hooks automatically. Service
configuration publishes App Configuration values under `agent-lz`, with Key
Vault references for secrets. Do not confuse those runtime/platform settings
with the full infrastructure output contract.
Retain the exact parameter declaration and private deployment records on every
runner; see [configuration ownership](configuration.md#configuration-ownership-and-declarations).

If private configuration was deferred or failed, complete
[connected-host configuration](deploy-terraform-infra-only.md#complete-deferred-private-configuration)
and verify readiness before deploy. Inspect hook logs even after a successful
outer command. Preserve permission and connectivity gates.

## Validation

First complete [foundation validation](deploy-terraform-infra-only.md#validation).
Then follow the shared [application validation](deploy-full-stack.md#validation):

1. Compare the platform source snapshot (or maintained source-checkout revision)
   and fetched component commits with the approved record and manifest.
   Check for uncommitted component changes; template initialization does not
   retain upstream platform Git history.
2. Verify selected Container Apps run application revisions, not placeholders,
   and the Foundry version uses the recorded immutable image digest.
3. Test the UI from the intended network, including Entra sign-in and delegated
   calls. A deployment greeting is not full application validation.
4. Test tools and the configured ingestion path with harmless data. After
   resolving the protected-retrieval gate, prove both permitted document
   retrieval and denial for an unauthorized user.
5. Correlate requests with telemetry and record unmet capabilities as blocked.

For native execution, verify session continuity from a fresh client.
For a selected workflow, test pending review, approval/rejection and
stale/duplicate/wrong-owner replies. Container Apps also needs evidence that
the pending run survives an owned worker restart. Use the same exact product
entrypoints/images on both providers; mocks do not establish deployed parity.
See [Workflows & human input](workflows.md#acceptance-checks).

Record source, manifest, inputs, backend identity/key, provider lock and image
digests without exposing state or secrets. In an authorized test environment,
reprovision after deployment and verify that images, revisions and application
behavior are preserved.

## Update and recover

- **Application-only changes:** use `azd deploy` when foundation outputs,
  application binding and component selection remain compatible.
- **Infrastructure, topology, RBAC or selection changes:** follow
  [Terraform reconfiguration](deploy-terraform-infra-only.md#reconfigure-or-recover-the-foundation),
  review changes, then provision and deploy with the same provider and state.
- **Runtime settings and secret rotation:** follow the shared
  [runtime-setting](deploy-full-stack.md#change-a-runtime-setting) and
  [secret-rotation](deploy-full-stack.md#rotate-a-secret) procedures. Respect
  provisioning-managed values and reload affected application processes.
- **Partial failure:** repair the cause and retry the same environment. Retain
  the reviewed source, inputs, state, provider lock and security settings.
  Follow [single-writer recovery](deploy-terraform-infra-only.md#reconfigure-or-recover-the-foundation);
  do not start a parallel executor.

Rollback is not automatic. Review the complete compatible source, manifest,
inputs and image digest against current resources and data before reapplying.
Reverting code does not restore data or state. Use owner-reviewed state/service
recovery or a forward repair when reversal is unsafe.

For component outbound rules, follow the shared
[rule-recovery order](deploy-full-stack.md#outbound-rule-recovery)
before reverting hooks. Keep Terraform state and single-writer controls intact.

## Remove the environment

Follow [Terraform foundation removal](deploy-terraform-infra-only.md#remove-the-foundation)
with explicit approval, backups, ownership review and the original backend.
Use root `azd down` only within its validated deletion scope; honor all safety
blocks rather than bypassing them. Keep backend storage and recovery access
outside workload teardown. Retained data, shared network/DNS resources and
backend retirement require separate owner decisions.

Terraform uses recorded, state-scoped ownership across its groups; the
infrastructure guide explains the preview and explicit destruction commands.
