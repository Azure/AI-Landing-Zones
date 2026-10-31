# Deploy infra only with Terraform

## Objective

Create and configure the Agent Landing Zone Azure foundation using the native
azd Terraform provider, without building or publishing application images.
Use the product's `infra/terraform/` composition.

To deploy application code as well, use
[Deploy full stack with Terraform](deploy-terraform-full-stack.md).
For the default Bicep path, use
[Deploy infra only with Bicep](deploy-infra-only.md).
[Terraform templates](terraform.md) explains the architecture and
[validation scope](terraform.md#validation-scope).

## Prerequisites

Complete the shared [permissions, tooling and identity prerequisites](deploy-full-stack.md#prerequisites),
including Python and the platform hook dependencies. Also install
[Terraform](https://developer.hashicorp.com/terraform/install) at a version
supported by the checked-in Terraform configuration and AVM dependencies.
Microsoft documents the native
[azd Terraform provider](https://learn.microsoft.com/azure/developer/azure-developer-cli/use-terraform-for-azd)
as beta. Use Terraform **1.13.0** and azd **1.37.1**, the versions used for
verification.

Arrange remote-state storage and access **before the first provision**, as
described below. Foundation creation, RBAC and service configuration need
separate permissions from backend access. Contributor alone does not grant
role-assignment or service data-plane access.

Private deployments need a connected runner with private DNS resolution,
routes and data-plane permissions. It must also reach the state backend and
approved provider/module registries. An ACR Tasks pool is not the deployment
host. Review [network design](network-isolation.md), service/model quota
and the [Sizing & cost planner](sizing-cost-planner.md). Infrastructure-only is still billable.

Commands marked `bash` use Bash syntax. Replace every `<placeholder>` with an
approved value. In PowerShell, remove any Bash continuation backslashes and
run the command on one line.

## Procedure

### Step 1: Get the product source and select Terraform once

```bash
git clone https://github.com/Azure/agent-landing-zone.git
cd agent-landing-zone
```

[Prepare Python](deploy-full-stack.md#prepare-python) in this checkout and
keep its environment active.

In the **root** `azure.yaml`, set these fields while preserving services,
hooks and other settings:

```yaml
infra:
  provider: terraform
  path: infra/terraform
  module: main
```

Run all lifecycle commands from the product root. Provider selection applies to
the checkout; use its Terraform configuration for provisioning, updates and
removal. Bicep is the default choice in an unconfigured checkout.

### Step 2: Authenticate and select the target

For a **new**, dedicated environment:

```bash
az login
azd auth login
az account set --subscription <subscription-id>
azd env new <environment-name>
azd env set AZURE_SUBSCRIPTION_ID <subscription-id>
azd env set AZURE_RESOURCE_GROUP <dedicated-resource-group>
azd env set AZURE_LOCATION <region>
```

For an existing Terraform environment, select it with
`azd env select <environment-name>` and retain its approved inputs and backend.
Confirm the cloud, tenant and subscription for both CLIs and Terraform.
Interactive use needs Azure CLI and azd sessions. Automation can supply
process-scoped `ARM_*` credentials for its selected authentication method.
The hooks do not change global authentication settings.

The supported clouds are `public`, `usgovernment` and `china`.
For CLI authentication, preprovision verifies the selected subscription and
active cloud metadata. For process credentials, select the cloud explicitly:

```bash
azd env set ARM_ENVIRONMENT <public-or-usgovernment-or-china>
```

If `ARM_ENVIRONMENT` is also present in the process, both values must agree.
Preprovision persists the canonical cloud for the backend and generates the
matching `azureCloud` provider/storage context. Do not edit that generated
context.

Preprovision detects a missing caller object ID for ordinary Azure CLI,
service-principal and managed-identity authentication. For certificate, OIDC
or custom managed-identity configurations, supply the caller explicitly:

```bash
azd env set AZURE_PRINCIPAL_ID <caller-object-id>
azd env set AZURE_PRINCIPAL_TYPE <User-or-ServicePrincipal>
```

Use the identity's **object ID**, not its client ID. Detection failures report
the required inputs. Explicit identity inputs do not authenticate the process;
keep credentials out of checked-in files.

Separate environment, resource-group, identity, data and configuration
boundaries by stage. Set the
[resource group destinations](configuration.md#resource-group-destinations)
before first provision. Preserve existing mappings on retries.

### Step 3: Prepare remote state outside the workload

An **existing Azure Storage account and blob container** are required. The
workload does not create or bootstrap them. Keep the backend outside **every**
workload resource group and outside the workload's Terraform-managed resources.
It must remain available after `azd down`.

The authorized executor needs **Reader** on the storage account for metadata
lookup and **Storage Blob Data Contributor** on the state container.
The backend uses Microsoft Entra ID (AzureAD) Blob authentication. Arrange
network access from each deployment runner, restricted access, retention or
backups, and an owner-reviewed recovery process.

Configure the selected azd environment:

```bash
azd env set TF_STATE_RESOURCE_GROUP <state-resource-group>
azd env set TF_STATE_STORAGE_ACCOUNT <state-storage-account>
azd env set TF_STATE_CONTAINER <state-container>
```

`TF_STATE_SUBSCRIPTION_ID` defaults to `AZURE_SUBSCRIPTION_ID`. For a backend in
a different subscription, also set:

```bash
azd env set TF_STATE_SUBSCRIPTION_ID <state-subscription-id>
```

The state key is `agent-landing-zone/${AZURE_ENV_NAME}.tfstate`, giving each
environment its own blob. azd renders `infra/terraform/provider.conf.json`
from these settings, including the canonical `ARM_ENVIRONMENT`.
Confirm the cloud, account, container and environment name
before provisioning; keep `.azure/` metadata private. See the official
[remote-state guidance](https://learn.microsoft.com/azure/developer/azure-developer-cli/use-terraform-for-azd#local-vs-remote-state)
and [Azure Storage backend reference](https://developer.hashicorp.com/terraform/language/backend/azurerm).

#### State protection

azd 1.37.1 passes `-lock=false` to Terraform plan and apply, so these operations
do not acquire the Azure Blob lease used for native state protection.
Use the execution and access controls below; they do not enable backend locking.

- **Individual environments:** local azd may operate the configured remote
  backend. Do not overlap writers to the same state.
- **Shared and production environments:** allow **one authorized
  writer/executor**, normally a pipeline. Restrict state write access to that
  executor and queue all operations without canceling an active run.
- **Serialize by actual state identity:** cloud, backend subscription, storage
  account, container and resolved state key. Branch-scoped concurrency and
  `cancel-in-progress` are insufficient. No other branch, checkout, terminal
  or pipeline may write the same state concurrently.
- **Keep workspaces separate:** each active environment operation needs its own
  checkout/workspace so generated inputs are not overwritten.

#### Private deployment records

Before persisting backend settings, the adapter creates
`.azure/<environment-name>/terraform-backend.json` on first use and verifies it
on subsequent runs. This immutable, nonsecret record binds the backend
subscription, resource group, account, container, resolved key and cloud.
Keep it private with the environment metadata.

Retain the original `resource-groups.json`, `terraform-resource-groups.json`
and application/environment bindings from that same directory. They record
destinations and Terraform group ownership. Restore these original records on
a clean runner before refresh, provisioning or teardown. Output refresh does
not reconstruct them; missing or changed bindings block the operation.

### Step 4: Choose the application and foundation inputs

Even an infrastructure-only deployment binds to an application definition.
Choose the application, topology and ingestion intent before first provision;
one environment binds to one application ID. For a custom definition, follow
[Bring your own app](build-your-own-app.md) and set:

```bash
azd env set AGENTLZ_APP_DEFINITION <path-to-app-definition.json>
```

For the supplied Agent Application, the default is `hosted-no-panel`, with
`maf_lite`, Foundry IQ and no Agent App Ingestion. It still needs the approved
`HOSTED_AGENT_RESOURCE_SCOPE` before service configuration. Review the
[application and identity choices](deploy-full-stack.md#step-3-choose-the-application-and-network)
and configure [per-user document authorization](application-auth.md) before
deploying the application.

Use private networking for production or sensitive data:

```bash
azd env set NETWORK_ISOLATION true
```

Plan standalone or hub integration, existing VNet/DNS ownership, permitted
egress, models, optional resources and regions using
[Deployment choices](planning.md) and [Deployment settings](configuration.md).
Public endpoints are only for approved, short-lived evaluations without
sensitive data. Do not weaken isolation to recover a failure.

Use documented `azd env set` inputs and the **root `main.parameters.json`** for
structured values. Keep JSON booleans, numbers, arrays and objects in their
native types. For example, an empty public IP allowlist is the existing
`parameters.allowedIpRanges.value` entry set to `[]`.

Preprovision validates the provider/application binding, resolves the shared
topology and runs a typed adapter to generate
`infra/terraform/main.tfvars.json`. This file is ignored by Git and regenerated;
do not edit it.
For Terraform, the generated, ignored `infra/shared/main.parameters.json` is a
preflight-only diagnostic artifact, never a Terraform deployment input. Also leave generated `.azure/`
files to azd.

When a managed jumpbox is enabled and no password is supplied, Terraform owns
the persistent generated password. Treat state and generated inputs as
sensitive; the hooks do not generate a fresh password on each run.

### Step 5: Review and provision

Confirm the selected environment, source revision, provider/path, backend key,
destination groups, approved inputs, quota and permissions before applying.
Review the resolved resources, network exposure, routes and role changes.
The read-only application egress report is:

```bash
python -m config.deployment.egress --plan --environment <environment-name>
```

This report covers application egress only; it is not a Terraform infrastructure
preview. Obtain approval for the infrastructure changes before provisioning.

After the backend, inputs and infrastructure changes are approved:

```bash
azd provision
```

azd invokes Terraform and the shared pre/post-provision hooks. Provisioning
creates the foundation, reconciles access and configures services; it does
not build or publish application images or create a running hosted agent
version. Selected Container Apps may initially have placeholder images.
Reprovisioning must not restore placeholders over deployed application images.

All flat Terraform outputs flow natively into azd and are consumed by the
shared postprovision and predeploy hooks. No manual output copying is needed.
Terraform publishes foundation-owned App Configuration connections, model
metadata and declared additional settings. Shared postprovision seeds only
missing defaults; the runtime publisher updates its explicitly owned keys.
See [configuration ownership](configuration.md#configuration-ownership-and-declarations).
The shared [platform output reference](deploy-infra-only.md#platform-outputs)
explains `AGENTLZ_PLATFORM_OUTPUTS` and flat keys published in App Configuration
under label `agent-lz`. The platform document is not the full azd output set.

## Validation

1. Confirm Terraform and **every required configuration step** succeeded.
   Record failures as incomplete even if an outer command returned success.
2. Inventory every destination group and compare new and reused resources with
   the approved inputs. Verify private endpoints in their actual groups.
3. Check backend access and state-key isolation without printing state or
   secrets. Confirm that resources and state refer to this environment.
4. Read the expected platform output from the actual configuration store:

    ```bash
    az appconfig kv show --endpoint <app-configuration-endpoint> \
      --key AGENTLZ_PLATFORM_OUTPUTS --label agent-lz --auth-mode login
    ```

5. From the intended runner, verify private DNS, TLS reachability, approved
   private-link connections and service data-plane roles. Do not expose public
   endpoints to bypass a failed check.
6. Confirm no application image build or publication occurred. A placeholder
   response is not evidence that application sign-in or retrieval works.

Keep the source revision, manifest, provider lock file, nonsecret inputs and
validation results. Protect state, plans, generated inputs, logs and `.azure/`.

## Complete deferred private configuration

If provisioning explicitly deferred service configuration while a connected
host was prepared, keep the same source, provider/path, application binding,
destination mapping, inputs and remote backend on that host.
Securely restore the [original deployment records](#private-deployment-records),
selected environment/application bindings and the exact reviewed parameter
declaration, including any required private declaration. Keep the same backend
and cloud. `azd env refresh` does not restore those records or declared intent.
Missing required declarations fail rather than being reconstructed from
defaults, outputs or state.
After restoring the environment, complete configuration:

```bash
azd env set RUN_FROM_JUMPBOX true
azd env set AZURE_SKIP_NETWORK_ISOLATION_WARNING false
azd hooks run postprovision
```

Verify platform outputs and data-plane readiness before deploying applications.
Do not bypass private-link approval or protected-retrieval gates.

## Reconfigure or recover the foundation

Keep the same provider and remote state. Back up required data and
configuration, preserve names, regions, application layout and group mappings,
and review proposed changes before re-running `azd provision`.
Use the coordinated product source, committed provider lock and reviewed
module versions for each update.

After a failure or interrupted run, pause the queue and confirm the executor
and its Terraform operation have stopped before starting any replacement.
Inspect actual resources and remote state, then recover or retry through the
same authorized executor. Do not use a parallel manual session for recovery.
If executor authority must move, revoke the former writer's access and confirm
it has stopped before authorizing its replacement.

Restore state only under an owner-reviewed recovery plan consistent with
actual resources, with other writes stopped. Reverting code does not restore
data or guarantee rollback.
Preserve state, resource names and security settings during recovery.

Every direct and transitive provider version is pinned exactly, with
Windows/Linux checksums in `infra/terraform/.terraform.lock.hcl`. Native azd
initialization uses `-upgrade`; the exact pins constrain provider selection.
Read-only lock-file validation runs separately in CI, not as an inline azd
option. Review provider and module updates deliberately.

## Add the application later

With the same configured foundation and bound application, continue at
[Deploy the application](deploy-terraform-full-stack.md#deploy-the-application).
`azd deploy` consumes the manifest pins and outputs; another provision is not
required merely to prepare the hosted image.

## Remove the foundation

Removal is destructive and needs separate authorization. Inventory every
destination and dependent application, back up retained data, and review
Terraform ownership and the deletion scope, including reused resources and
hub/DNS attachments. Do not infer safety from a resource-group name or tag.

Use the same product root, Terraform configuration and selected environment.
The guard verifies the original common group binding,
`terraform-resource-groups.json` and `terraform-backend.json`. Missing records
or changes to the provider, groups or backend address block teardown.

Native azd delegates to **Terraform state-scoped destroy**, including owned
and bring-your-own split-group layouts. The hook does not issue imperative
resource-group deletion. Review the plan and all Terraform-owned groups:
owning a group can put its contents within the destruction boundary.
Bring-your-own groups retain their recorded lookup-only ownership.

At the verified azd **1.37.1**, review without deletion:

```bash
azd down --no-prompt
```

Without `--force`, that Terraform command previews and skips deletion.
After separate deletion approval, interactive `azd down` requests confirmation.
Automation can use `azd down --force` only to explicitly authorize destruction,
through the same single-writer queue. Do not use force or purge as a repair
shortcut or bypass a failed binding check.

The backend storage, container, permissions and recovery data must remain
outside workload teardown and available throughout recovery. Retiring that
backend is a separate owner-approved operation after workload retirement and
retention review. Preserve shared hub, DNS, monitoring and other reused
resources.
