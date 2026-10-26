<span id="deploy-infrastructure-only"></span>

# Deploy infra only

## Objective

Provision the Azure foundation without building or deploying application images.
This is the infrastructure procedure for both Agent Landing Zone and the
standalone AI Landing Zone Bicep foundation. Choose the source first and use
its hooks, parameter files and outputs throughout the procedure.

## When to use

Use this runbook when you need foundation resources first, or will supply your
own application. To deploy the Agent Application now, use
the [Deploy full stack](deploy-full-stack.md) runbook.

<span id="before-you-start"></span>

## Prerequisites

Complete the [permissions and tooling prerequisites](deploy-full-stack.md#prerequisites).
The upstream foundation requires Git, Azure CLI, azd and PowerShell 7; the
Agent platform additionally requires Python and the platform hook dependencies.
Review the [resource inventory and cost scenarios](../bicep/deployed-resources.md)
and [regional capacity caveats](../bicep/regional-considerations.md).
Infrastructure-only still creates billable resources.

Blocks marked `bash` use Bash syntax. In PowerShell, put commands with a
trailing backslash (`\`) on one line and remove the continuation backslashes.
Replace every `<placeholder>` before running a command.

The effective footprint is the combination of enabled services, resource-reuse
inputs, application definition, orchestrator topology and network settings.
This determines which AI services, backing resources, runtimes, data stores,
monitoring, networking and optional add-ons are deployed.
Review the selected source's `main.parameters.json`, Bicep conditions and preview
to identify the resources for your deployment.

## Procedure

<a id="steps"></a>

### Step 1: Choose the source

#### Agent Landing Zone foundation

Use this source if you will deploy the Agent Application or a compatible
custom application later:

```bash
git clone https://github.com/Azure/agent-landing-zone.git
cd agent-landing-zone
```

Run all lifecycle commands from this root, not from `infra/`.
Its `infra/` is repository-owned
source, and `manifest.json` records the coordinated component pins and
upstream foundation provenance.

#### AI Landing Zone foundation without the Agent platform

Use this source for independent foundation resources and their placeholder app:

```bash
git clone https://github.com/Azure/bicep-ptn-aiml-landing-zone.git
cd bicep-ptn-aiml-landing-zone
```

Run from that repository's root, where its `main.bicep`, `main.parameters.json`
and `azure.yaml` live. Its lifecycle does not configure or deploy the Agent
Application. Do not provision this separate project into an Agent environment.
For application deployment, start from the Agent source instead.

Select the approved full Git commit in the chosen repository before continuing:

```bash
git checkout --detach <approved-source-commit>
git rev-parse HEAD
git status --short
```

Expect HEAD to match that commit and no unexpected changes. Record the reviewed
nonsecret root parameters alongside the commit.

For Agent source, [set up Python](deploy-full-stack.md#prepare-python) from
the selected revision before lifecycle commands.

### Step 2: Create and confirm the target

Replace the placeholders for a **new**, dedicated environment:

```bash
az login
azd auth login
az account set --subscription <subscription-id>
azd env new <environment-name>
azd env set AZURE_SUBSCRIPTION_ID <subscription-id>
azd env set AZURE_RESOURCE_GROUP <dedicated-resource-group>
azd env set AZURE_LOCATION <region>
```

Use `azd env select <environment-name>` for an existing environment and keep
its approved inputs. Use separate environment, resource-group, identity,
configuration and data boundaries for each stage; protect local `.azure/` state.
Fork or mirror the source only when maintaining your own inputs or automation.

**Agent source only, from v4.4.0:** a reviewed revision can optionally select
[Foundry and network resource group destinations](configuration.md#resource-group-destinations)
before first provision. The default remains one group; additional targets
share its subscription and must exist unless optional creation is authorized.
Keep the normal root `azd provision` flow, not separate manual deployments per
group. This does not establish support in the independent Bicep source,
Terraform or portal.

### Step 3: Choose the foundation shape

Choose the network design before provisioning. Set the scalar deployment inputs
below in the selected azd environment with `azd env set`; arrays and objects
use the root parameter file as described later in this step.
`DEPLOYMENT_MODE` records the network design intent; routing, DNS and isolation
use their own inputs. Agent's separate `DEPLOYMENT_TOPOLOGY` chooses where the
orchestrator runs. See [How it works](how-it-works.md) for input processing.

#### Public service endpoints

```bash
azd env set NETWORK_ISOLATION false
azd env set DEPLOYMENT_MODE standalone
```

Services use public endpoints with authentication and authorization.
Preserve an existing private environment's isolation settings during recovery.

#### Private standalone network

```bash
azd env set NETWORK_ISOLATION true
azd env set DEPLOYMENT_MODE standalone
azd env set DEPLOY_AZURE_FIREWALL true
azd env set DEPLOY_JUMPBOX true
azd env set DEPLOY_BASTION true
azd env set DEPLOY_NAT_GATEWAY true
```

Review the [standalone reference](../bicep/standalone.md) for nonoverlapping
subnets, network security groups (NSGs), outbound routing and private DNS.
For native Bastion Remote Desktop Protocol (RDP), choose
`BASTION_SKU_NAME=Standard` and `BASTION_ENABLE_TUNNELING=true`; portal access
does not require the native tunneling workflow. Have a connected host ready
for Agent post-provision configuration, or use explicit deferral below.

#### Private spoke using an existing hub

Agree hub routing, reverse peering, DNS and permissions with their owners first.
For a **new** spoke VNet with a hub firewall:

```bash
azd env set NETWORK_ISOLATION true
azd env set DEPLOYMENT_MODE ailz-integrated
azd env set DEPLOY_AZURE_FIREWALL false
azd env set DEPLOY_BASTION false
azd env set DEPLOY_NAT_GATEWAY false
azd env set DEPLOY_JUMPBOX true
azd env set EXISTING_BASTION_RESOURCE_ID <hub-bastion-resource-id>
azd env set HUB_INTEGRATION_HUB_VNET_RESOURCE_ID <hub-vnet-resource-id>
azd env set HUB_INTEGRATION_CREATE_HUB_PEERING true
azd env set HUB_INTEGRATION_EGRESS_NEXT_HOP_IP <hub-firewall-private-ip>
```

Instead of a next-hop IP, a platform-managed route table can be selected with
`HUB_INTEGRATION_EXISTING_ROUTE_TABLE_RESOURCE_ID`; these inputs are mutually
exclusive. Set one when hub egress is required. Shared monitoring
uses `EXISTING_LOG_ANALYTICS_WORKSPACE_RESOURCE_ID` and, when applicable,
`EXISTING_APPLICATION_INSIGHTS_RESOURCE_ID` with its protected connection string.

Apply the [hub-and-spoke DNS and peering contract](../bicep/hub-and-spoke.md)
before provisioning. A network operator may need to complete reverse peering
and DNS links as soon as a fresh spoke VNet exists, before bootstrap can finish.
Use an approved production hub, not the upstream test-hub fixture.

#### Existing networks, private DNS and parameter files

| Choice | Required review |
| --- | --- |
| Existing VNet | Set `USE_EXISTING_VNET=true` and `EXISTING_VNET_RESOURCE_ID`. Decide who owns subnets, NSGs and delegations before setting `DEPLOY_SUBNETS`; both peering directions are externally managed for BYO VNet |
| Shared private DNS | Supply the applicable `EXISTING_PRIVATE_DNS_ZONE_*_RESOURCE_ID` inputs. Their owner supplies VNet links or resolver forwarding; peering alone does not propagate DNS |
| Azure Policy-managed DNS | Use `POLICY_MANAGED_PRIVATE_DNS=true` instead of BYO zone overrides and agree who creates zone groups, records and links |
| Approved public exception | Review native `allowedIpRanges` and Storage trusted-service/resource-instance exceptions to confirm the approved service-specific public access |
| Controlled public frontend | Review [Application Gateway ingress](../bicep/public-ingress.md), certificate ownership, WAF policy and cost before opting in |

Set mapped scalar inputs with `azd env set`. Native arrays/objects such as the
complete address plan, `allowedIpRanges`, Storage controls and `publicIngress`
belong in the reviewed **root** `main.parameters.json`.
In the Agent platform, hooks regenerate `infra/main.parameters.json`;
do not edit that generated copy. The
[parameter reference](../bicep/parameterization.md) describes foundation inputs;
[Deployment settings](configuration.md) describes platform composition and overrides.

#### Bind the future application (Agent source only)

Choose the [orchestrator topology and ingestion selection](deploy-full-stack.md#step-3-choose-the-application-and-network)
now, even if images will be deployed later. For a different application:

```bash
azd env set AGENTLZ_APP_DEFINITION <path-to-app-definition.json>
```

Otherwise use the Agent Application definition. The first provision binds the environment
to its application ID; a different ID requires a new environment.
Preserve the existing layout and ingestion selection during recovery.
The default Agent layout is `hosted-no-panel`, using `maf_lite` and Foundry IQ
without Agent App Ingestion. Set `HOSTED_AGENT_RESOURCE_SCOPE` to the approved
delegated Foundry audience followed by `/.default` before provisioning, even
when application deployment will happen later. See the linked full-stack
runbook for the identity inputs and protected-retrieval integration gate.

### Step 4: Preview and provision

For Agent source, first run `azd hooks run preup` to validate the definition and
binding before azd's resource-group initialization.
Normal `azd provision` automatically runs the Agent preprovision hook to
compose parameters and bootstrap authorized additional groups. Manual
preparation is needed only if you choose to preview first.

#### Optional preview (Agent source)

!!! warning "Preview preparation can create resource groups"
    With azd 1.37.1, `azd provision --preview` does **not** run preprovision
    hooks. It reads the existing `infra/main.parameters.json`, which may still
    be the checked-in seed or another environment's composition, and cannot
    bootstrap missing additional destination groups.

    Before an optional Agent preview, select the intended azd environment,
    activate the prepared Python environment and run **one** matching hook
    from the platform root: `pwsh -File scripts/preProvision.ps1` on Windows,
    or `sh scripts/preProvision.sh` on Linux/macOS. These hooks load selected
    azd values, compose parameters and can create missing additional groups
    when `CREATE_RESOURCE_GROUPS=true`. Otherwise those groups must already
    exist, or a composed split-group preview can fail with `NotFound`.

    Native preview can also create the empty application/root resource group.
    Neither fresh-environment preparation nor preview is guaranteed write-free;
    authorize group creation before running them. A successful preview does
    not prove private connectivity, service configuration or application readiness.

After this preparation for Agent source, or using the independent foundation's
own inputs and lifecycle, the optional preview command is:

```bash
azd provision --preview
```

If previewing, review its scopes, names, routes, resource changes, public access
and role assignments. Resolve quota, Policy, subnet and capacity findings rather
than skipping preflight.

#### Provision

With the resource changes approved, provision normally:

```bash
azd provision
```

Test connectivity after provisioning and application behavior after deploying
your selected application.

| Source | What provisioning completes |
| --- | --- |
| Agent platform | Validation and binding, foundation deployment, then service configuration, role reconciliation and App Configuration publication unless explicitly deferred |
| Upstream Bicep foundation | Foundation preflight and resource deployment; no Agent post-provision modules or application image deployment |

Selected Container Apps can run placeholder images at this point.
An upstream hello-world response checks basic network and runtime reachability.
Validate sign-in, tools, ingestion and document authorization after deploying
the Agent Application.
For initial infrastructure provisioning, inspect platform outputs below and
continue to [Validation](#validation). Use lifecycle tasks only when needed.

<a id="platform-outputs"></a>

### Platform outputs (Agent source only)

After configuration completes, App Configuration publishes the JSON
`AGENTLZ_PLATFORM_OUTPUTS` and matching flat keys under label `agent-lz`.
Search and Cosmos sections are omitted when their endpoints are absent;
other required fields must validate. These derived keys are not written back
to the azd environment.

| Flat key | JSON path |
| --- | --- |
| `AGENTLZ_FOUNDRY_PROJECT_ENDPOINT` | `foundry.projectEndpoint` |
| `AGENTLZ_FOUNDRY_ACCOUNT_NAME` | `foundry.accountName` |
| `AGENTLZ_ACR_LOGIN_SERVER` | `registry.loginServer` |
| `AGENTLZ_APPCONFIG_ENDPOINT` | `appConfig.endpoint` |
| `AGENTLZ_SEARCH_ENDPOINT` | `search.endpoint` |
| `AGENTLZ_STORAGE_BLOB_ENDPOINT` | `storage.blobEndpoint` |
| `AGENTLZ_COSMOS_ENDPOINT` | `cosmos.endpoint` |
| `AGENTLZ_KEYVAULT_URI` | `keyVault.uri` |

`AGENTLZ_NETWORK_ISOLATED` records isolation.
`AGENTLZ_IDENTITY_<COMPONENT>_CLIENT_ID` and the JSON `identities` array
contain discovered Container App identity client IDs, not principal IDs.
Hosted runtime identities are created later, during application deployment.
Missing or ambiguous identities fail publication; system-assigned identity
resolution also requires the exact Entra service-principal read.
`AGENTLZ_COMPONENT_IDENTITIES` is an explicit override input, not an automatic output.

```bash
az appconfig kv show --endpoint <app-configuration-endpoint> \
  --key AGENTLZ_PLATFORM_OUTPUTS --label agent-lz --auth-mode login
```

If only output publication needs refreshing after successful configuration:

```bash
azd env refresh
python -m config.deployment.outputs
```

This does not replace deferred or failed service configuration.

<span id="lifecycle"></span>

<span id="lifecycle-tasks"></span>

### Complete a deferred post-provision

For Agent source, private configuration can be explicitly deferred by
`RUN_FROM_JUMPBOX=false`, or by `AZURE_SKIP_NETWORK_ISOLATION_WARNING=true`
when `RUN_FROM_JUMPBOX` is not truthy. Set the approved deferral before the
first provision when the connected host does not exist yet.
Successful provisioning then reports that application setup is incomplete.
Deferral does not bypass earlier topology/private-service checks.

On a new connected host, restore the **same reviewed source revision** and
root parameter file. Install the prerequisites and Python dependencies,
authenticate both CLIs, then initialize local state only if absent:

```bash
azd env new <same-environment-name>
azd env set AZURE_SUBSCRIPTION_ID <subscription-id>
azd env set AZURE_RESOURCE_GROUP <existing-resource-group>
azd env set AZURE_LOCATION <region>
azd env refresh
```

If the environment is already present, select it instead. Reapply the approved
deployment inputs: refresh restores outputs, not your full configuration.
For the multi-group path, restore the same approved Foundry/network
destination mapping as well; the root group alone is not sufficient.
Do not publish or copy another stage's `.azure/` state as an input artifact.
An authorized runner can use managed-identity sign-in. Verify its scoped
configuration and build roles before running the hooks.

From the connected host, clear deferral and finish configuration:

```bash
azd env set RUN_FROM_JUMPBOX true
azd env set AZURE_SKIP_NETWORK_ISOLATION_WARNING false
azd hooks run postprovision
```

`RUN_FROM_JUMPBOX` requests connectivity checks on the connected host.
Verify platform outputs and required data-plane access before deploying.
Private native Blob sources can require an administrator to approve the
exact Search shared private-link request reported by the readiness gate.
Do not approve every pending connection or bypass the gate.

<span id="reconfigure-or-upgrade-the-foundation"></span>

### Reconfigure the foundation

Record the deployed source revision, approved parameters, outputs and dependent
applications. Back up required data and configuration, check compatibility and
retain existing names, locations, layout and ingestion intent.
If previewing Agent changes, repeat the
[selected-environment preparation](#optional-preview-agent-source) before
reviewing the preview. Apply approved root parameter changes with the provisioning step above.

For Agent environments, integrate the coordinated platform and its `infra/`
tree together; do not replace only its foundation folder with upstream main.
Use the [reapply procedure](deploy-full-stack.md#upgrade-to-a-new-release)
and [rollback](deploy-full-stack.md#rollback) in the Deploy full stack runbook.
Upstream foundation environments use their own source and complete root
parameter contract, without Agent post-provision commands.

Retry a partial deployment with the same approved revision and environment after
repairing the specific failure. Review resource and data changes separately
when reverting code. Do not delete data, rename subnets, move existing
resources to another region, weaken isolation or bypass preflight to recover.
Turning a deploy flag off is not deletion or permission cleanup.

### Add an application later

In an Agent foundation, deploy the same bound application and selected components.
Follow [Step 4 of the Deploy full stack runbook](deploy-full-stack.md#step-4-deploy):
prepare the hosted image, provision its digest handoff, then deploy.
Custom definitions follow their own component contract. An upstream-only
foundation is not a configured Agent environment.

### Remove the foundation

Use the [safe environment removal procedure](deploy-full-stack.md#remove-an-environment)
from the selected source root and environment. Confirm ownership and backups
before deletion. For a spoke, have network/DNS owners remove only the recorded
spoke-specific attachments and preserve shared services. Purge is a separate
irreversible decision, not a normal retry or rollback.

<span id="verify-the-foundation"></span>

## Validation

1. Inspect the selected target and inventory:

    ```bash
    azd env get-value AZURE_SUBSCRIPTION_ID
    azd env get-value AZURE_RESOURCE_GROUP
    az resource list -g <resource-group> --query "[].{name:name,type:type}" -o table
    az network private-endpoint list -g <resource-group> \
      --query "[].{name:name,state:provisioningState,connections:privateLinkServiceConnections[].privateLinkServiceConnectionState.status}" -o json
    ```

    For the multi-group path, repeat resource inventory for every
    distinct destination, and inspect private endpoints in their actual group.
    Do not infer a Foundry or network resource's group from the application group.

2. Compare the inventory with enabled features and reuse inputs. Account for
   both new and reused resources.
3. For private deployments, verify approved connections, private DNS and TCP/TLS
   reachability from the actual deployment host. Use the
   [standalone checks](../bicep/standalone.md#verify-private-connectivity) or
   [hub checks](../bicep/hub-and-spoke.md#verify-the-network-contract).
4. Test required service operations with the authorized configuration identity
   and confirm telemetry reaches the intended workspace.
5. For Agent source, inspect post-provision logs and platform outputs.
   Record explicit deferral or any logged configuration failure as incomplete.
   A placeholder HTTP response does not prove application readiness.

## Rollback

1. Stop retries and record which resources and configuration changed. If only
   local inputs changed, restore reviewed inputs before provisioning.
2. Compare previous inputs with deployed state. Preview the previous compatible
   source and parameters with `azd provision --preview` from the selected root,
   following the [Agent preview preparation](#optional-preview-agent-source) when applicable.
3. Apply with `azd provision` only if reviewed changes preserve data, shared
   resources and the approved network posture.
4. Repeat [Validation](#validation). If inputs cannot safely reverse a change,
   stop and arrange service-specific forward repair or recovery with its owner.

Successful provisioning does not restore deleted data or reverse schema changes.
Disabling a flag does not delete resources or revoke grants. Use the separately
authorized [removal procedure](#remove-the-foundation) only for intentional
retirement, not as a retry.
