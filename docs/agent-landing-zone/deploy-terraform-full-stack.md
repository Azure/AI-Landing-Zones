# Deploy full stack with Terraform

## Objective

Provision the Azure foundation with Terraform and deploy the Agent Application
through the shared azd lifecycle. The default `hosted-no-panel` layout uses a
Foundry-hosted orchestrator, a Container Apps UI and native Foundry IQ ingestion
and retrieval, without an administrative panel or Agent Application Cosmos DB.

Terraform owns the foundation, not a second application deployment mechanism.
`azd provision` creates and configures the foundation, `azd deploy` builds and
publishes the selected application, and `azd up` runs both.

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
Review [network isolation](network-isolation.md), quotas and recurring costs.

Replace every `<placeholder>` with an approved value before running a command.

## Procedure

### Step 1: Prepare the Terraform environment

Complete [foundation preparation Steps 1–4](deploy-terraform-infra-only.md#procedure):

- Use the reviewed Agent Landing Zone source and configure the **root**
  `azure.yaml` once with `infra.provider: terraform` and
  `infra.path: infra/terraform`, with `infra.module: main`.
  Preserve the hooks and services.
- Authenticate, select the intended environment and confirm its target.
- Confirm the cloud: `public`, `usgovernment` or `china`. Preprovision generates
  matching provider and backend cloud settings.
- Configure and verify the Azure Storage backend before provision.
- Set documented environment inputs and root `main.parameters.json` values.
  Preprovision generates typed Terraform inputs automatically.

Use this checkout's Terraform configuration for every lifecycle command.
An environment binds to one application ID.

### Step 2: Confirm application and build choices

For a **new** default Agent Application environment:

```bash
azd env set DEPLOYMENT_TOPOLOGY hosted-no-panel
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

### Step 3: Provision the foundation

Complete the [Terraform infrastructure review](deploy-terraform-infra-only.md#step-5-review-and-provision)
before the first apply. From the **product root**, with the intended azd
environment selected:

```bash
azd provision
```

Skip this step if you have already completed and validated the
infrastructure-only deployment guide for this environment.

<a id="deploy-the-application"></a>

### Step 4: Deploy the application

For an already configured foundation:

```bash
azd deploy
```

For a new deployment, `azd up` is an alternative to Steps 3 and 4: it performs
both stages after the same preparation.

Provisioning does not build application images or create the running hosted
agent version. Deploy fetches manifest-pinned sources, prepares the immutable
hosted image when needed, binds it to the provisioned Foundry project and
registry, then publishes the hosted version and selected Container Apps.
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

1. Compare the platform revision and fetched component commits with the approved
   manifest and check for uncommitted source changes.
2. Verify selected Container Apps run application revisions, not placeholders,
   and the Foundry version uses the recorded immutable image digest.
3. Test the UI from the intended network, including Entra sign-in and delegated
   calls. A deployment greeting is not full application validation.
4. Test tools and the configured ingestion path with harmless data. After
   resolving the protected-retrieval gate, prove both permitted document
   retrieval and denial for an unauthorized user.
5. Correlate requests with telemetry and record unmet capabilities as blocked.

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

## Remove the environment

Follow [Terraform foundation removal](deploy-terraform-infra-only.md#remove-the-foundation)
with explicit approval, backups, ownership review and the original backend.
Use root `azd down` only within its validated deletion scope; honor all safety
blocks rather than bypassing them. Keep backend storage and recovery access
outside workload teardown. Retained data, shared network/DNS resources and
backend retirement require separate owner decisions.
Terraform uses recorded, state-scoped ownership across its groups; the
infrastructure guide explains the preview and explicit destruction commands.
