# Deploy infrastructure only

Provision the Azure foundation without building or deploying application images.
This is the infrastructure procedure for both Agent Landing Zone and the
standalone AI Landing Zone Bicep foundation. Choose the source first: their
hooks, parameter files and outputs are not interchangeable.

To run the agent application as well, use [Deploy the full stack](deploy-full-stack.md).

## Before you start

Complete the [permissions and tooling prerequisites](deploy-full-stack.md#prerequisites).
The upstream foundation requires Git, Azure CLI, azd and PowerShell 7; the
Agent platform additionally requires Python and the platform hook dependencies.
Review the [resource inventory and cost scenarios](../bicep/deployed-resources.md)
and [regional capacity caveats](../bicep/regional-considerations.md).
Infrastructure-only still creates billable resources.

The effective footprint is the combination of enabled services, resource-reuse
inputs, application definition, orchestrator topology and network settings.
This affects AI services and their backing resources, runtimes, data stores,
monitoring, networking and optional add-ons—not just one or two services.
Use the selected source's `main.parameters.json`, Bicep conditions and preview
as the authority; the foundation inventory is not an Agent application bill of materials.

<a id="steps"></a>

## Step 1: Choose the source

### Agent Landing Zone foundation

Use this source if you will deploy the bundled agent application or a compatible
custom application later:

```bash
git clone https://github.com/Azure/agent-landing-zone.git
cd agent-landing-zone
```

Follow [Python setup](deploy-full-stack.md#prepare-python). Run all lifecycle
commands from this root, not from `infra/`. Its `infra/` is repository-owned
source, and `manifest.json` records the coordinated component pins and
upstream foundation provenance.

### AI Landing Zone foundation without the Agent platform

Use this source for independent foundation resources and their placeholder app:

```bash
git clone https://github.com/Azure/bicep-ptn-aiml-landing-zone.git
cd bicep-ptn-aiml-landing-zone
```

Run from that repository's root, where its `main.bicep`, `main.parameters.json`
and `azure.yaml` live. Its lifecycle does not configure or deploy the Agent
application. Do not provision this separate project into an Agent environment.
For application deployment, start from the Agent source instead.

Both clones use the current default `main`, not `develop`. Record the resolved
commit and reviewed nonsecret inputs for repeatability. The
[full-stack source guidance](deploy-full-stack.md#step-1-get-the-code) explains
optional release selection.

## Step 2: Create and confirm the target

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

## Step 3: Choose the foundation shape

The following choices apply before provisioning. `DEPLOYMENT_MODE` records the
network design intent; it does not configure routing, DNS or isolation by itself.
It is separate from Agent's `DEPLOYMENT_TOPOLOGY`, which chooses the orchestrator.

### Public service endpoints

```bash
azd env set NETWORK_ISOLATION false
azd env set DEPLOYMENT_MODE standalone
```

Service authentication and authorization still apply. This is not a private
deployment or a way to repair an existing private environment.

### Private standalone network

```bash
azd env set NETWORK_ISOLATION true
azd env set DEPLOYMENT_MODE standalone
azd env set DEPLOY_AZURE_FIREWALL true
azd env set DEPLOY_JUMPBOX true
azd env set DEPLOY_BASTION true
azd env set DEPLOY_NAT_GATEWAY true
```

Review the [standalone reference](../bicep/standalone.md) for nonoverlapping
subnets, NSGs, egress and private DNS. For native Bastion RDP, choose
`BASTION_SKU_NAME=Standard` and `BASTION_ENABLE_TUNNELING=true`; portal access
does not require the native tunneling workflow. Have a connected host ready
for Agent post-provision configuration, or use explicit deferral below.

### Private spoke using an existing hub

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
exclusive. Do not leave both unset if hub egress is required. Shared monitoring
uses `EXISTING_LOG_ANALYTICS_WORKSPACE_RESOURCE_ID` and, when applicable,
`EXISTING_APPLICATION_INSIGHTS_RESOURCE_ID` with its protected connection string.

Apply the [hub-and-spoke DNS and peering contract](../bicep/hub-and-spoke.md)
before provisioning. A network operator may need to complete reverse peering
and DNS links as soon as a fresh spoke VNet exists, before bootstrap can finish.
The upstream test-hub fixture is not a production connectivity deployment.

### Existing networks, private DNS and parameter files

| Choice | Required review |
| --- | --- |
| Existing VNet | Set `USE_EXISTING_VNET=true` and `EXISTING_VNET_RESOURCE_ID`. Decide who owns subnets, NSGs and delegations before setting `DEPLOY_SUBNETS`; both peering directions are externally managed for BYO VNet |
| Shared private DNS | Supply the applicable `EXISTING_PRIVATE_DNS_ZONE_*_RESOURCE_ID` inputs. Their owner supplies VNet links or resolver forwarding; peering alone does not propagate DNS |
| Azure Policy-managed DNS | Use `POLICY_MANAGED_PRIVATE_DNS=true` instead of BYO zone overrides and agree who creates zone groups, records and links |
| Approved public exception | Review native `allowedIpRanges` and Storage trusted-service/resource-instance exceptions explicitly; isolation is not a blanket public-access guarantee |
| Controlled public frontend | Review [Application Gateway ingress](../bicep/public-ingress.md), certificate ownership, WAF policy and cost before opting in |

Set mapped scalar inputs with `azd env set`. Native arrays/objects such as the
complete address plan, `allowedIpRanges`, Storage controls and `publicIngress`
belong in the reviewed **root** `main.parameters.json`, not invented environment
variables. In the Agent platform, hooks regenerate `infra/main.parameters.json`;
do not edit that generated copy. The
[parameter reference](../bicep/parameterization.md) describes foundation inputs;
[Agent configuration](configuration.md) describes platform composition and overrides.

### Bind the future application (Agent source only)

Choose the [orchestrator topology and ingestion selection](deploy-full-stack.md#step-3-choose-the-application-and-network)
now, even if images will be deployed later. For a different application:

```bash
azd env set AGENTLZ_APP_DEFINITION <path-to-app-definition.json>
```

Otherwise use the bundled definition. The first provision binds the environment
to its application ID; a different ID requires a new environment.
Keep the existing topology and ingestion selection on upgrades.

## Step 4: Preview and provision

For Agent source, first run `azd hooks run preup` to validate the definition and
binding before azd's resource-group initialization. Then, in either source:

```bash
azd provision --preview
azd provision
```

Review the preview's scopes, names, routes, resource changes, public access and
role assignments before the second command. Resolve quota, Policy, subnet and
capacity findings rather than skipping preflight. Preview is not an application
or connectivity test.

| Source | What provisioning completes |
| --- | --- |
| Agent platform | Validation and binding, foundation deployment, then service configuration, role reconciliation and App Configuration publication unless explicitly deferred |
| Upstream Bicep foundation | Foundation preflight and resource deployment; no Agent post-provision modules or application image deployment |

Selected Container Apps can run placeholder images at this point.
An upstream hello-world response proves only that network/runtime smoke test.
It is not evidence of Agent authentication, tools, ingestion or document authorization.

## Verify the foundation

Inspect the intended environment and selected resources:

```bash
azd env get-value AZURE_SUBSCRIPTION_ID
azd env get-value AZURE_RESOURCE_GROUP
az resource list -g <resource-group> --query "[].{name:name,type:type}" -o table
az network private-endpoint list -g <resource-group> \
  --query "[].{name:name,state:provisioningState,connections:privateLinkServiceConnections[].privateLinkServiceConnectionState.status}" -o json
```

Compare the inventory with enabled features and reuse inputs, not a fixed
resource count. For private deployments, verify approved connections, private
DNS resolution and TCP/TLS reachability from the actual deployment host.
Then test each required data plane with its authorized identity and confirm
telemetry reaches the intended workspace. See the
[standalone checks](../bicep/standalone.md#verify-private-connectivity) and
[hub-specific checks](../bicep/hub-and-spoke.md#verify-the-network-contract).

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

## Lifecycle

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
Do not publish or copy another stage's `.azure/` state as an input artifact.
Managed-identity sign-in is an option for an appropriately authorized runner,
not proof that its configuration/build roles are sufficient.

From the connected host, clear deferral and finish configuration:

```bash
azd env set RUN_FROM_JUMPBOX true
azd env set AZURE_SKIP_NETWORK_ISOLATION_WARNING false
azd hooks run postprovision
```

`RUN_FROM_JUMPBOX` requests checks; it does not provide connectivity.
Verify platform outputs and required data-plane access before deploying.
Private native Blob sources can require an administrator to approve the
exact Search shared private-link request reported by the readiness gate.
Do not approve every pending connection or bypass the gate.

### Reconfigure or upgrade the foundation

Record the deployed source revision, approved parameters, outputs and dependent
applications. Back up required data and configuration, review the new source's
migrations and retain existing names, locations, topology and ingestion intent.
Review preview before applying approved root parameter changes with the
provisioning step above.

For Agent environments, integrate the coordinated platform and its `infra/`
tree together; do not replace only its foundation folder with upstream main.
See [platform upgrades and rollback](deploy-full-stack.md#upgrade-to-a-new-release).
Upstream foundation environments use their own source and complete root
parameter contract, without Agent post-provision commands.

Retry a partial deployment with the same approved revision and environment after
repairing the specific failure. Reverting code is not guaranteed to reverse
resource or data changes. Do not delete data, rename subnets, move existing
resources to another region, weaken isolation or bypass preflight to recover.
Turning a deploy flag off is not deletion or permission cleanup.

### Add an application later

In an Agent foundation, deploy the same bound application and selected components.
Follow [Step 4 of the full-stack runbook](deploy-full-stack.md#step-4-deploy):
classic can deploy after configuration; bundled hosted needs image preparation
and a second provision first. Custom definitions follow their own component
contract. An upstream-only foundation is not a configured Agent environment.

### Remove the foundation

Use the [safe environment removal procedure](deploy-full-stack.md#remove-an-environment)
from this source's root and selected environment. Confirm ownership and backups
before deletion. For a spoke, have network/DNS owners remove only the recorded
spoke-specific attachments and preserve shared services. Purge is a separate
irreversible decision, not a normal retry or rollback.
