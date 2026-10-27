---
search:
  exclude: true
---

# Bicep deployment considerations

Deployment instructions are consolidated into two runbooks:

- [Deploy infrastructure only](../agent-landing-zone/deploy-infra-only.md)
  provisions the incorporated foundation from the Agent Landing Zone root.
- [Deploy the full stack](../agent-landing-zone/deploy-full-stack.md)
  includes Agent application images and runtime deployment.

This reference retains foundation-specific rollout and Storage compatibility
details. It is not an alternative initialization or provisioning procedure.

<a id="prerequisites"></a>
<a id="basic-deployment"></a>
<a id="zero-trust-deployment"></a>
<a id="using-the-jumpbox-vm"></a>
<a id="optional-public-endpoint"></a>

Choose public, private standalone or private hub integration in the
[foundation runbook](../agent-landing-zone/deploy-infra-only.md#step-3-choose-the-foundation-shape).
Use [standalone](standalone.md) and [hub-and-spoke](hub-and-spoke.md) for their
address, DNS, routing, access and ownership contracts. Optional
[Application Gateway ingress](public-ingress.md) is separate from private
service access.

### Private build pool ordering

The private Container Registry build agent pool has an explicit `dependsOn` on the **conditionally deployed BYO-VNet subnet module**. When that module creates the build subnet, the pool must wait for it to complete; constructing a subnet resource ID alone does not establish deployment ordering.

Build subnet creation and pool ordering respect `networkIsolation`, `useExistingVNet`, `deploySubnets`, `deployDevopsBuildAgentsSubnet`, `deployNsgs`, registry-deployment and pool-deployment gates. The dependency must respect the subnet module's condition rather than require a module that is not deployed. When `deploySubnets=false` or `deployDevopsBuildAgentsSubnet=false`, the build subnet must already exist and be valid before provisioning the enabled pool; a creation flag does not disable the pool.

For a cold-start verification, record that the target build subnet is **absent before the first attempt** in the BYO-VNet scenario where the template creates subnets. Record the first attempt's deployment operations, the pool's final provisioning state, and `countSucceeded`, counting only operations that actually reached `Succeeded`.

A submitted or running deployment is not proof of success. A retry after an earlier attempt created the subnet, or a run against an already-existing subnet, cannot prove the cold-start ordering fix. Keep retry results separate from first-attempt evidence.

### BYO VNet Bastion subnet NSGs

For BYO-VNet subnet creation, the reserved `AzureBastionSubnet` is excluded
from generic NSG attachment. When Bastion is enabled, its explicit, dedicated
Bastion-compliant NSG takes precedence and is preserved.

The reserved `GatewaySubnet` is also excluded from generic NSG attachment.
It must have no NSG, default-route UDR or delegation.

Do not automatically rename existing subnets, renumber `subnetCidr` entries,
or move their assigned address prefixes to undo an older workaround. Plan
migration explicitly to avoid prefix overlap and disruption to existing subnets.

## Solution Storage profile

The [parameter reference](parameterization.md#solution-storage-controls) defines the three inputs and exact bypass union. They affect **solution Storage only** and retain Storage AVM `0.26.2`. They do not redesign Firewall, VPN, Network Security Perimeter (NSP), VM, or auxiliary AI Foundry Storage, or change deployment defaults.

Use the reviewed, version-controlled root `main.parameters.json` for the
selected platform revision. The JSON examples below are fragments of its
`parameters` object, not complete files. Preserve the rest of the compatible
parameter file. These settings take native strings, arrays and booleans;
there are no environment substitutions or JSON-string aliases for them to set
with `azd env set`. Follow the
[platform parameter-composition workflow](accelerator-pattern.md), not edits
to generated infrastructure.

### Omitted inputs or compatible defaults

Omit the three inputs to retain bypass `AzureServices`, an empty resource-instance rules list (`[]`), and Shared Key access enabled (`true`), or use the [explicit default fragment](parameterization.md#native-parameter-values-and-defaults). These are compatibility defaults, not a private-only profile. On redeployment, the empty desired list can remove existing manual or Defender-added resource-instance rules; omission is not a request to preserve live exceptions.

With Bicep `0.42.1`, an explicit top-level `null` for any of these defaulted parameters also selects its default. Do not use `null` to request a stricter profile: set bypass to `None` and Shared Key access to `false` explicitly, and supply the complete rules array (`[]` when no exceptions are desired).

This does not allow nested `null`, missing required rule fields, empty strings, wrong types, or invalid bypass values; see the [parameter contract](parameterization.md#native-parameter-values-and-defaults). No runtime fallback or product-default change is introduced.

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

If Defender malware scanning is already configured and must be retained, obtain the **exact existing scanner ARM resource ID** and its tenant ID from the approved configuration. Review them with the resource owner. Replace both placeholders below; they are illustrative text, not deployable IDs.

Do not construct a scanner scope from a Storage account ID, guess its resource group or name, use a wildcard, or broaden the rule to all resources in a scope.

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
2. **Review the platform revision and parameters together.** Use a reviewed Agent Landing Zone release and update its root parameter file. Review the full desired resource-instance rules list, including any required approved scanner entry, and obtain approval for the intended access changes. Keep the previous coordinated revision and inputs for rollback; do not patch generated infrastructure or change AVM `0.26.2`.
3. **Verify the effective configuration and consumers.** After an approved deployment, check the solution account's bypass, complete resource-instance rules list, and Shared Key setting, along with the unchanged PNA, IP, `defaultAction`, and private-endpoint behavior. Test migrated clients and, if required, the existing scanner. The change does not remove AVM's secure `listKeys` outputs, so it is not a key-free management-plane deployment guarantee. Local documentation checks do not supply this live evidence.
4. **Rollback through the same platform revision/input workflow.** Review the intended access state before reverting. An older implementation may reject the inputs, restore bypass `AzureServices`, or drop approved resource-instance rules; match its parameter contract and assess those effects first. Restoring wider bypass or enabling keys again requires explicit approval, not an automatic fallback. Preserve approved exceptions on a compatible revision where possible and verify effective settings and consumers after rollback.

<a id="ai-landing-zone-integrated-deployment"></a>

## Existing hub integration

Use the actual `HUB_INTEGRATION_*` and `EXISTING_*_RESOURCE_ID` mappings
listed in the [hub-and-spoke reference](hub-and-spoke.md#hub-integration-inputs).
A deployment-mode label alone does not establish routing, private DNS or access.
Test-hub fixtures are not production hub setup.

## Next steps
- [Public Ingress with Application Gateway](public-ingress.md) — Publish a private Container App through Application Gateway WAF v2
- [Parameterization](parameterization.md) — Customize your deployment
- [Permissions](permissions.md) — Understand the role assignments
