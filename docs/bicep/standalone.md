# Standalone deployment runbook

Deploy the **Bicep AI Landing Zone foundation** in a dedicated resource group,
with its own VNet, DNS, private endpoints, firewall, Bastion and jumpbox. No
customer hub is required. Use [Hub-and-spoke](hub-and-spoke.md) when a platform
team owns shared network services.

This runbook uses **v2.7.3** of `Azure/bicep-ptn-aiml-landing-zone`. Run the
PowerShell 7 commands from that repository's root, where `azure.yaml`,
`main.bicep` and `main.parameters.json` live. The foundation's default Container
App is a hello-world placeholder, **not the full Agent Landing Zone application**.

For the Agent product, use [Deploy full stack](../agent-landing-zone/deploy-full-stack.md)
or [Deploy infra only](../agent-landing-zone/deploy-infra-only.md) instead. Its
foundation is incorporated into `infra/`, but configuration and lifecycle
commands run from the **Agent repository root**. Do not run this separate
foundation deployment into an Agent environment.

## 1. Prepare a pinned checkout

The workload owner manages resources, network policy, backups and cost in the
dedicated group. The security/network owner approves address allocation,
firewall rules and any public access exception. Obtain deployment approval
before provisioning; Azure Firewall, Bastion, VMs and AI services incur costs.

Prerequisites:

- Git, Azure CLI, Azure Developer CLI and PowerShell 7.
- Contributor plus role-assignment authority (for example User Access
  Administrator) at the deployment scopes. Check [Permissions](permissions.md)
  for resource and data-plane assignments; do not use Owner as a troubleshooting
  shortcut.
- Registered resource providers, accepted AI service terms, regional model,
  Search and VM capacity/quota. Review [Regional considerations](regional-considerations.md)
  and preflight findings rather than relying on a fixed vCPU estimate.
- A plan to reach private endpoints from VPN or the deployed jumpbox. Signing
  in successfully does not grant network reachability or data-plane access.

Replace every `<...>` input below:

```powershell
git clone --branch v2.7.3 https://github.com/Azure/bicep-ptn-aiml-landing-zone.git ailz-standalone
Set-Location ailz-standalone
$subscriptionId = '<subscription-id>'
$location = '<azure-region>'
$envName = '<unique-environment-name>'
$resourceGroup = '<dedicated-resource-group>'

az login
azd auth login
az account set --subscription $subscriptionId
az group create --name $resourceGroup --location $location
azd env new $envName --subscription $subscriptionId --location $location
azd env set AZURE_RESOURCE_GROUP $resourceGroup
```

All later `azd` commands run from this checkout against this environment.
Do not commit `.azure/`, credentials or VM passwords.

## 2. Plan addresses

Reserve a range that does not overlap VPN/on-premises networks, other VNets or
future hub connections. Upstream `main.bicep` defaults to `192.168.0.0/21`.
The example below uses **`10.200.0.0/21` only as an illustrative allocation**;
replace the entire plan if it conflicts with your network.

These are **native Bicep parameters**, not mapped azd environment variables.
`azd env set VNET_ADDRESS_PREFIXES ...` and `ALLOWED_IP_RANGES ...` do not update
these values in upstream v2.7.3. The following command merges a complete sample
IP plan into the existing root parameter file while retaining other entries:

```powershell
$ipPlan = [ordered]@{
    vnetAddressPrefixes = @('10.200.0.0/21')
    agentSubnetPrefix = '10.200.0.0/24'
    acaEnvironmentSubnetPrefix = '10.200.4.0/23'
    peSubnetPrefix = '10.200.2.0/26'
    azureBastionSubnetPrefix = '10.200.2.64/26'
    azureFirewallSubnetPrefix = '10.200.2.128/26'
    gatewaySubnetPrefix = '10.200.2.192/26'
    azureAppGatewaySubnetPrefix = '10.200.3.0/27'
    jumpboxSubnetPrefix = '10.200.3.64/27'
    devopsBuildAgentsSubnetPrefix = '10.200.3.96/27'
}
$parameters = Get-Content ./main.parameters.json -Raw | ConvertFrom-Json -AsHashtable
foreach ($entry in $ipPlan.GetEnumerator()) {
    $parameters.parameters[$entry.Key] = @{ value = $entry.Value }
}
$parameters | ConvertTo-Json -Depth 100 | Set-Content ./main.parameters.json -Encoding utf8
git diff -- main.parameters.json
```

Expected: only the approved parameter changes. Every subnet must fit within the
VNet without overlap. Keep `AzureBastionSubnet` and `AzureFirewallSubnet` at
least `/26`; reserve adequate private-endpoint capacity. The example gives the
workload-profile Container Apps environment the recommended `/23`; the current
preflight enforces `/27` minimum and warns below that recommendation. Do not
confuse this with a guarantee of future scale.

Keep the reviewed parameter file with your customer-owned configuration and
carry it to any connected deployment host. Environment refresh does not restore
these custom input edits.

## 3. Configure the standalone private topology

```powershell
azd env set DEPLOYMENT_MODE standalone
azd env set NETWORK_ISOLATION true
azd env set DEPLOY_AZURE_FIREWALL true
azd env set DEPLOY_JUMPBOX true
azd env set DEPLOY_BASTION true
azd env set DEPLOY_NAT_GATEWAY true
azd env set BASTION_SKU_NAME Standard
azd env set BASTION_ENABLE_TUNNELING true
```

`DEPLOYMENT_MODE` records intent; the explicit flags select the resources.
This private path keeps Search enabled, creates local monitoring and DNS zones,
and leaves `allowedIpRanges` empty. It does not enable optional public ingress.
The NAT gateway supports the jumpbox subnet; it is not a firewall or an
alternative to inspecting the effective route. The template creates the
workload default route to the local firewall.

Review the [v2.7.3 firewall egress allowlist](https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/v2.7.3/README.md#firewall-egress-allow-list-network-isolation)
for Azure services, registry pulls and jumpbox software bootstrap. Optional
private ACR Tasks builds require their build-subnet egress too. The foundation
defaults `DEPLOY_ACR_TASK_AGENT_POOL=false`; the Agent product configures that
pool separately. A pool is not a VNet-connected deployment agent.

Do not turn `NETWORK_ISOLATION` off or add broad public IP exceptions to
troubleshoot. `allowedIpRanges` is a native array in `main.parameters.json`;
a nonempty approved value can enable IP-restricted public access even with
isolation on. Storage trusted-service/resource-instance exceptions and Shared
Key access are independent controls: network isolation alone does not remove
them. Review [Parameterization](parameterization.md) before changing them.
The public demo path in [How to deploy](how-to-deploy.md#basic-deployment) is a
different security posture, not this private runbook.

## 4. Preview and provision

From the foundation checkout:

```powershell
pwsh ./scripts/Invoke-PreflightChecks.ps1
azd provision --preview
# Review scopes, routes, public access, role assignments and Policy findings.
# After deployment approval:
azd provision
azd env refresh
```

Preflight also runs as the repository's `preprovision` hook. Resolve failed
checks; do not skip it. Preview is a change review, not proof of connectivity
or authorization. Allow time for firewall, AI services and VM bootstrap.

Expected: selected deployments succeed and outputs are saved in the azd
environment. The default foundation lifecycle does not build or deploy the
Agent application. The optional VM bootstrap (`DEPLOY_SOFTWARE`, default
`true`) installs tools; inspect its extension result rather than assuming it
prepared every application prerequisite.

## 5. Verify private connectivity

First inspect the deployment from the foundation checkout:

```powershell
$resourceGroup = azd env get-value AZURE_RESOURCE_GROUP
az resource list --subscription $subscriptionId --resource-group $resourceGroup --query '[].{name:name,type:type,state:properties.provisioningState}' -o table
az containerapp list --subscription $subscriptionId --resource-group $resourceGroup --query '[].{name:name,fqdn:properties.configuration.ingress.fqdn}' -o table
az vm list --subscription $subscriptionId --resource-group $resourceGroup --show-details --query '[].{name:name,state:powerState}' -o table
az network private-endpoint list --subscription $subscriptionId --resource-group $resourceGroup --query '[].{name:name,state:provisioningState,connections:privateLinkServiceConnections[].privateLinkServiceConnectionState.status}' -o json
```

Expected: selected resources are `Succeeded`, the jumpbox is running and
private endpoint connections are `Approved`. Resource counts vary with enabled
features and are not a success criterion.

Choose names from these listings rather than assuming the first resource is
the correct one. Test the foundation's hello-world app **inside the VNet**,
using the Windows jumpbox's Run Command:

```powershell
$vmName = '<jumpbox-name-from-list>'
$appName = '<foundation-container-app-name-from-list>'
$fqdn = az containerapp show --subscription $subscriptionId --resource-group $resourceGroup --name $appName --query properties.configuration.ingress.fqdn -o tsv
$script = @"
`$ErrorActionPreference = 'Stop'
Resolve-DnsName -Type A '$fqdn'
Test-NetConnection -ComputerName '$fqdn' -Port 443
`$response = Invoke-WebRequest -Uri 'https://$fqdn' -UseBasicParsing -TimeoutSec 30
if (`$response.StatusCode -ne 200) { throw 'Unexpected HTTP response' }
Write-Output ('Status=' + `$response.StatusCode)
"@
az vm run-command invoke --subscription $subscriptionId --resource-group $resourceGroup --name $vmName --command-id RunPowerShellScript --scripts $script --query 'value[].{code:code,message:message}' -o json
```

Expected: DNS resolves to the approved private endpoint/environment IP,
`TcpTestSucceeded=True`, and `Status=200` with the placeholder page. Check the
guest output for errors: a submitted Run Command operation alone is not proof
that the request succeeded.

For interactive access, use Bastion in the portal or, from a supported Windows
client with the Azure CLI Bastion extension:

```powershell
az network bastion list --subscription $subscriptionId --resource-group $resourceGroup --query '[].{name:name,sku:sku.name,tunneling:enableTunneling}' -o table
$bastionName = '<bastion-name-from-list>'
$vmId = az vm show --subscription $subscriptionId --resource-group $resourceGroup --name $vmName --query id -o tsv
az network bastion rdp --subscription $subscriptionId --resource-group $resourceGroup --name $bastionName --target-resource-id $vmId
```

Native RDP requires Standard/Premium Bastion with tunneling enabled. Use the
provisioned VM credential; if unavailable, an authorized operator can reset it
in the portal (default username `testvmuser`). Do not put a password in shell
history or add a public IP to the VM.

From the connected Windows host, repeat DNS and TCP checks for the actual
Search, Storage, App Configuration and ACR names:

```powershell
$serviceFqdns = @(
    '<search-service>.search.windows.net',
    '<storage-account>.blob.core.windows.net',
    '<app-configuration>.azconfig.io',
    '<registry>.azurecr.io'
)
foreach ($name in $serviceFqdns) {
    Resolve-DnsName -Name $name -Type A
    Test-NetConnection -ComputerName $name -Port 443
}
```

Expected: private answers matching the deployed endpoint NICs and successful
TCP connections. Then test each data plane with its intended authorized
identity. A 401/403 is not a successful authorization test, even if it proves
the endpoint responds. Check telemetry in the intended workspace. An
unconnected workstation must not serve the private app or read private service
data; a public DNS answer outside the VNet alone does not prove exposure.

Hello-world success proves only this network path. It does not validate Agent
configuration, ingestion, retrieval, Entra sign-in or document-level
authorization. Those require the application deployment and positive/negative
authorization tests with representative identities.

## 6. Recover without weakening isolation

Inspect failed operations and app logs before changing configuration:

```powershell
az deployment group list --subscription $subscriptionId --resource-group $resourceGroup --query '[].{name:name,state:properties.provisioningState}' -o table
$deploymentName = '<failed-deployment-name-from-list>'
az deployment operation group list --subscription $subscriptionId --resource-group $resourceGroup --name $deploymentName --query "[?properties.provisioningState=='Failed'].properties.statusMessage" -o json
# If the app exists:
az containerapp logs show --subscription $subscriptionId --resource-group $resourceGroup --name $appName --type system --tail 50
```

| Symptom | Recovery |
| --- | --- |
| Token expiry/disconnected CLI | Run `azd auth login`, inspect the still-running ARM deployment, then retry with the same environment |
| Preflight, quota, capacity or Policy error | Correct the specific input or obtain approved quota/policy/capacity; do not disable required services |
| DNS failure or public answer inside VNet | Inspect private endpoint approval, zone records and VNet links; for custom DNS, repair resolver forwarding |
| 502, failed revision or image pull | Inspect system logs and firewall denies; allow only required image/package destinations for the correct source subnet |
| VM bootstrap failure | Inspect the VM's Custom Script Extension and firewall logs; resolve tooling/egress failure before retrying |
| Data-plane 403 | Verify network path and the caller's service-specific role at the correct scope, allow propagation, then retest |

After correction, review `azd provision --preview` and rerun `azd provision`.
Keep the same source revision, parameter file and environment. Preserve data
and identity assignments; do not delete a partially deployed group, purge
soft-deleted services or move existing resources to another region as a generic
retry. Reverting infrastructure code is not a guaranteed rollback; review its
effects on resources and security settings with the owners.

## 7. Clean up a dedicated environment

Inventory resources and dependencies first, obtain data-retention approval and
back up required data. Confirm there are no shared or externally owned resources
in the deletion scope:

```powershell
azd env select $envName
azd env get-value AZURE_SUBSCRIPTION_ID
azd env get-value AZURE_RESOURCE_GROUP
az resource list --subscription $subscriptionId --resource-group $resourceGroup --query '[].{name:name,type:type}' -o table
# Only after confirming the exact dedicated scope:
azd down
```

Review the interactive deletion prompt. Do not add `--force --purge` by default:
soft-deleted services may be recoverable, while purge removes that option.
Check for retained chargeable resources and externally created links afterward.
Setting a deploy flag to `false` on an incremental deployment is not cleanup.
If this environment later adopted a hub, follow
[spoke-only cleanup](hub-and-spoke.md#8-clean-up-only-the-spoke) and leave shared
hub resources untouched.

## Next steps

- [Hub-and-spoke deployment](hub-and-spoke.md): integrate with shared DNS,
  firewall, monitoring and operator access.
- [Agent network isolation](../agent-landing-zone/network-isolation.md):
  connect a host and complete private post-provision/deploy operations. `azd
  provision` may defer application setup; success is not readiness.
- [Deploy full stack](../agent-landing-zone/deploy-full-stack.md) and
  [Hosted agents](../agent-landing-zone/hosted-agents.md): use the Agent
  repository's supported lifecycle, including the first hosted deployment's
  provision/prepare/provision/deploy sequence.
