# How to Deploy

Choose your preferred deployment mode based on project requirements and environment constraints.

## Prerequisites

**Required permissions:**

- Azure subscription with **Contributor** and **User Access Admin** roles
- Agreement to Responsible AI terms for Azure AI Services

**Required tools:**

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- [PowerShell 7+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell) — required by the pre-flight validation hook
- [Git](https://git-scm.com/downloads)

!!! note
    Azure CLI and PowerShell 7+ are required by the `azd preprovision` hook that runs `scripts/Invoke-PreflightChecks.ps1` before deployment. You can bypass the hook by setting `PREFLIGHT_SKIP=true` in your shell, but the script is the fastest way to catch parameter mistakes (subnet sizing, CIDR overlap, BYO resource typos) before they reach ARM.

!!! warning "Azure AI Foundry delegated subnet CIDR limitation"
    If your deployment creates or reuses the Azure AI Foundry delegated subnet, do **not** plan that subnet inside `10.0.0.0/8`. Current Azure AI Foundry delegated subnet behavior supports private ranges within `172.16.0.0/12` or `192.168.0.0/16` only. Validate `VNET_ADDRESS_PREFIXES` and any BYO subnet prefixes before running `azd provision`.

## Basic Deployment

Quick setup for demos and development environments without network isolation. This is the **standalone** topology.

**1. Initialize the project**

```bash
azd init -t azure/bicep-ptn-aiml-landing-zone
```

**2. Sign in to Azure**

```bash
az login
azd auth login
```

!!! tip
    Add `--tenant` for `az` or `--tenant-id` for `azd` if you want to target a specific tenant.

**3. Provision infrastructure**

```bash
azd provision
```

!!! info "Optional customization"
    You can change parameter values in `main.parameters.json` or set them using `azd env set` before running `azd provision`. The latter applies only to parameters that support environment variable substitution. See [Parameterization](parameterization.md) for the full reference.

## Zero Trust Deployment

For deployments that **require network isolation**. The network-isolated configuration uses private endpoints and disables public network access unless an `allowedIpRanges` list is configured. For Storage, review trusted-service and resource-instance exceptions separately: public network access `Disabled` does not necessarily remove their access. See [Storage firewall limitations](https://learn.microsoft.com/azure/storage/common/storage-network-security-limitations).

**1. Initialize the project**

```bash
azd init -t azure/bicep-ptn-aiml-landing-zone
```

**2. Enable network isolation**

```bash
azd env set NETWORK_ISOLATION true
```

!!! info "Optional customization"
    Update other parameters in `main.parameters.json` or via `azd env set` before provisioning. See [Parameterization](parameterization.md) for available settings.

**3. Sign in to Azure**

```bash
az login
azd auth login
```

!!! tip
    Add `--tenant` for `az` or `--tenant-id` for `azd` if you want to target a specific tenant.

**4. Provision infrastructure**

```bash
azd provision
```

### Using the Jumpbox VM

After a Zero Trust deployment, use the Jumpbox VM to access services inside the virtual network.

**1. Reset the VM password** (required on first access if not set in deployment parameters):

   - In the Azure Portal, go to your VM resource → **Support + troubleshooting** → **Reset password**
   - Set new credentials (default username is `testvmuser`)

**2. Connect via Azure Bastion**

   - In the Azure Portal, go to your VM resource → **Connect** → **Bastion**
   - Enter the credentials you set in step 1

### Optional public endpoint

If a private Container App must be reachable through a controlled public endpoint, use [Public Ingress with Application Gateway](public-ingress.md). The template first provisions an inert Application Gateway skeleton, then you complete the hostname, certificate, DNS, and allowed-source configuration.

### Private build pool ordering

!!! warning "Available in v2.7.0 - live cold-start validation not verified"
    The ordering change for [Azure/bicep-ptn-aiml-landing-zone#159](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/159) is available in [Bicep implementation v2.7.0](https://github.com/Azure/bicep-ptn-aiml-landing-zone/releases/tag/v2.7.0). Release availability and successful CI do not establish that a live cold-start deployment has succeeded; collect the first-attempt evidence described below.

The private Container Registry build agent pool has an explicit `dependsOn` on the **conditionally deployed BYO-VNet subnet module**. When that module creates the build subnet, the pool must wait for it to complete; constructing a subnet resource ID alone does not establish deployment ordering.

The existing `networkIsolation`, `useExistingVNet`, `deploySubnets`, `deployNsgs`, registry-deployment, and pool-deployment gates remain unchanged. The dependency must respect the subnet module's condition rather than require a module that is not deployed. When `deploySubnets=false`, subnet existence and readiness remain the external network owner's responsibility before provisioning the pool.

For a cold-start verification, record that the target build subnet is **absent before the first attempt** in the BYO-VNet scenario where the template creates subnets. Record the first attempt's deployment operations, the pool's final provisioning state, and `countSucceeded`, counting only operations that actually reached `Succeeded`. A submitted or running deployment is not proof of success. A retry after an earlier attempt created the subnet, or a run against an already-existing subnet, cannot prove the cold-start ordering fix. Keep retry results separate from first-attempt evidence.

### BYO VNet Bastion subnet NSG patch (v2.7.1)

The [v2.7.1 patch](https://github.com/Azure/bicep-ptn-aiml-landing-zone/releases/tag/v2.7.1) targets [Azure/bicep-ptn-aiml-landing-zone#168](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/168): BYO-VNet subnet creation with `useExistingVNet=true`, `deploySubnets=true`, `deployNsgs=true`, and `deployBastion=false` could fail because the reserved `AzureBastionSubnet` received a generic NSG. The patch still creates the reserved subnet but excludes it from generic NSG attachment. When Bastion is enabled, its explicit, dedicated Bastion-compliant NSG takes precedence and is preserved. Deployment gates, outputs, defaults, and resource creation are unchanged.

New deployments using the patch do not need the subnet-renaming workaround. For an existing workaround, do not automatically rename subnets, renumber `subnetCidr` entries, or move their assigned address prefixes. Plan migration explicitly to avoid prefix overlap and disruption to existing subnets. Confirm the source release/tag is published before selecting the patch; documentation CI does not establish live Azure validation.

## Solution Storage profile

!!! warning "Available in v2.7.0 - live Azure validation not verified"
    The inputs used in these examples are available in [Bicep implementation v2.7.0](https://github.com/Azure/bicep-ptn-aiml-landing-zone/releases/tag/v2.7.0) for [Azure/bicep-ptn-aiml-landing-zone#160](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/160). They require a compatible implementation revision. Release availability and successful CI are not evidence of a successful live Azure deployment; scanner and client behavior still require environment-specific validation.

The [parameter reference](parameterization.md#solution-storage-controls) defines the three inputs and exact bypass union. They affect **solution Storage only** and retain Storage AVM `0.26.2`. They do not redesign Firewall, VPN, Network Security Perimeter (NSP), VM, or auxiliary AI Foundry Storage, or change deployment defaults.

Use a reviewed, version-controlled `main.parameters.json` overlay for the pinned ALZ revision. The JSON examples below are fragments of its `parameters` object, not complete files. Preserve the rest of the compatible parameter file. These settings take native strings, arrays, and booleans; there are no new environment substitutions, environment names, or JSON-string aliases to set with `azd env set`. Follow the existing [overlay and version-pin workflow](accelerator-pattern.md), not edits to generated infrastructure.

### Omitted inputs or compatible defaults

Omit the three inputs to retain bypass `AzureServices`, an empty resource-instance rules list (`[]`), and Shared Key access enabled (`true`), or use the [explicit default fragment](parameterization.md#native-parameter-values-and-defaults). These are compatibility defaults, not a private-only profile. On redeployment, the empty desired list can remove existing manual or Defender-added resource-instance rules; omission is not a request to preserve live exceptions.

With Bicep `0.42.1`, an explicit top-level `null` for any of these defaulted parameters also selects its default. Do not use `null` to request a stricter profile: set bypass to `None` and Shared Key access to `false` explicitly, and supply the complete rules array (`[]` when no exceptions are desired). This does not allow nested `null`, missing required rule fields, empty strings, wrong types, or invalid bypass values; see the [parameter contract](parameterization.md#native-parameter-values-and-defaults). No runtime fallback or product-default change is introduced.

### Explicit no-bypass profile without Defender scanning

For a deployment that does not require a Defender scanner exception or any other resource-instance exception, explicitly select `None`, `false`, and `[]`:

```json
{
  "storageAccountNetworkAclsBypass": {
    "value": "None"
  },
  "storageAccountResourceAccessRules": {
    "value": []
  },
  "storageAccountAllowSharedKeyAccess": {
    "value": false
  }
}
```

Complete the client inventory and migration below **before** disabling Shared Key. This fragment does not disable an existing Defender plan, and must not be used to remove a required scanner exception unintentionally. It neither enables network isolation nor changes existing PNA, IP rules, `defaultAction`, or private endpoints. Bypass `None` is not sufficient to make an account private, and PNA `Disabled` is not sufficient to disregard configured trusted-service/resource-instance exceptions.

### Optional approved existing scanner

If Defender malware scanning is already configured and must be retained, obtain the **exact existing scanner ARM resource ID** and its tenant ID from the approved configuration. Review them with the resource owner. Replace both placeholders below; they are illustrative text, not deployable IDs. Do not construct a scanner scope from a Storage account ID, guess its resource group or name, use a wildcard, or broaden the rule to all resources in a scope.

```json
{
  "storageAccountNetworkAclsBypass": {
    "value": "None"
  },
  "storageAccountResourceAccessRules": {
    "value": [
      {
        "resourceId": "<approved-existing-scanner-arm-resource-id>",
        "tenantId": "<approved-scanner-tenant-id>"
      }
    ]
  },
  "storageAccountAllowSharedKeyAccess": {
    "value": false
  }
}
```

This example assumes that the scanner is the **only** approved resource-instance exception. If others are required, include every approved entry in the reviewed list. The list is complete desired state: redeployment removes undesired or manual entries not listed, without merging live rules. Azure checks resource eligibility, existence, and the same-tenant requirement; input shape checks alone are not evidence that the scanner can access data.

The rule grants network eligibility, not data permissions. The scanner's managed identity and data-plane roles, Defender plan, and scanning configuration must already be managed separately. No scanner, plan, or role assignment is created by these inputs. Consult [Defender malware scanning prerequisites and resources](https://learn.microsoft.com/azure/defender-for-cloud/introduction-malware-scanning#resources-deployed-by-malware-scanning) and [Storage resource-instance rules](https://learn.microsoft.com/azure/storage/common/storage-network-security-resource-instances). Verify scanning after an approved deployment rather than inferring it from a successful Storage resource update.

### Migration and rollback

1. **Inventory and prepare clients.** Identify account-key clients, key-based connection strings, service SAS, account SAS, and Azure Files clients and tools. Migrate and verify required workflows before opting into `storageAccountAllowSharedKeyAccess=false`. Microsoft Entra authentication and Blob user delegation SAS are separate from key-signed SAS; they still need network connectivity and appropriate data-plane permissions. Review [Shared Key compatibility guidance](https://learn.microsoft.com/azure/storage/common/shared-key-authorization-prevent), including file-client constraints. Do not assume all SAS traffic is key-based or that every file client can migrate unchanged.
2. **Review the pin and overlay together.** Select a normal, compatible ALZ revision with the v2.7.0 contract, then update the complete parameter-file overlay. Review the full desired resource-instance rules list, including any required approved scanner entry, and obtain approval for the intended access changes. Keep the previous pin and overlay for rollback; do not patch generated infrastructure or change AVM `0.26.2`.
3. **Verify the effective configuration and consumers.** After an approved deployment, check the solution account's bypass, complete resource-instance rules list, and Shared Key setting, along with the unchanged PNA, IP, `defaultAction`, and private-endpoint behavior. Test migrated clients and, if required, the existing scanner. The change does not remove AVM's secure `listKeys` outputs, so it is not a key-free management-plane deployment guarantee. Local documentation checks do not supply this live evidence.
4. **Rollback through the same pin/overlay workflow.** Review the intended access state before reverting. An older implementation may reject the new inputs, restore bypass `AzureServices`, or drop approved resource-instance rules; match its parameter contract and assess those effects first. Restoring wider bypass or enabling keys again requires explicit approval, not an automatic fallback. Preserve approved exceptions on a compatible revision where possible and verify effective settings and consumers after rollback.

## AI Landing Zone Integrated Deployment

For deployments that **plug into an existing Azure Landing Zone** — i.e. the spoke peers to a corporate hub that already provides Bastion, Firewall, Private DNS zones, and Log Analytics.

This topology assumes you (or another team) already operate a hub VNet and shared platform services. The AI Landing Zone spoke consumes them rather than re-creating them.

**1. Initialize the project**

```bash
azd init -t azure/bicep-ptn-aiml-landing-zone
```

**2. Set the topology preset and hub integration**

```bash
azd env set DEPLOYMENT_MODE ailz-integrated
azd env set HUB_VNET_RESOURCE_ID "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<hub-vnet>"
azd env set EGRESS_NEXT_HOP_IP "<hub firewall private IP>"
```

You'll typically also bring your own observability and DNS zones:

```bash
azd env set EXISTING_LOG_ANALYTICS_WORKSPACE_ID "/subscriptions/.../workspaces/<law>"
azd env set EXISTING_APPLICATION_INSIGHTS_ID    "/subscriptions/.../components/<ai>"
# Plus per-zone EXISTING_PRIVATE_DNS_ZONE_* IDs as needed — see Parameterization
```

**3. Sign in and provision**

```bash
az login
azd auth login
azd provision
```

!!! info "Full walkthrough"
    The [Hub-and-Spoke Topology](hub-and-spoke.md) page documents this scenario end-to-end, including a minimal test hub Bicep template, IP planning, peering setup, and verifying connectivity through the hub Bastion.

## Next steps
- [Public Ingress with Application Gateway](public-ingress.md) — Publish a private Container App through Application Gateway WAF v2
- [Parameterization](parameterization.md) — Customize your deployment
- [Permissions](permissions.md) — Understand the role assignments
