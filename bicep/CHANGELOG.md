# Changelog

The latest version of the changelog can be found [here](https://github.com/Azure/AI-Landing-Zones/blob/main/bicep/CHANGELOG.md).

## 0.1.8

### Changed
- Improved Jump VM (jumpbox) provisioning reliability, especially under forced tunneling ([issue #63](https://github.com/Azure/AI-Landing-Zones/issues/63)):
  - Hardened the Custom Script Extension bootstrap (`install.ps1`) with more reliable WSL detection/installation and a reboot flow when required.
  - Stabilized Docker Desktop readiness checks and post-reboot continuation.
  - Made bootstrap steps more idempotent on reruns (e.g., Python install and tool setup).
  - Adjusted egress allow-listing to keep `az login` / Azure resource access working when egress is restricted.
- Improved AI Foundry deployment stability by increasing the wait time for capability host readiness (eventual consistency) and wiring the wait through the main template.
- Improved redeploy/idempotency behavior:
  - Made Jump VM CSE “force rerun” opt-in (to avoid extension updates failing when the VM is stopped).
  - Added `jumpVmDefinition.assignContributorRoleAtResourceGroup` to optionally skip the resource-group Contributor role assignment (helps avoid `RoleAssignmentExists` in environments where RBAC is managed outside the template).
- Improved support for “Existing VNet” scenarios, including deployments where the target VNet is in a different resource group (scoping VNet-bound operations to the VNet’s resource group derived from the VNet resource ID).
- Documentation updates:
  - Added/updated test runbooks for Platform Landing Zone, Existing VNet, and Greenfield scenarios.

## 0.1.7

### Changed
- Platform Landing Zone integration: decoupled Private DNS Zone creation from Private Endpoint creation.
  - `flagPlatformLandingZone = true` no longer disables Private Endpoints; it only prevents this template from creating Private DNS Zones.
  - Private Endpoint DNS zone-group configuration is now applied only when a corresponding zone ID is available.
- Added optional User Defined Routes (UDR): deploy a Route Table with default route (`0.0.0.0/0`) and associate it to key workload subnets.
  - Toggle is `deployToggles.userDefinedRoutes`.
  - Implemented defensive behavior: if UDR is enabled but firewall/NVA next-hop inputs are inconsistent, UDR deployment is skipped to avoid breaking egress.
  - Added optional App Gateway v2 internet routing exception: when `appGatewayInternetRoutingException = true`, the `appgw-subnet` gets `0.0.0.0/0 -> Internet` via a separate route table.
- Updated AI Foundry wiring to align with the new PDNS/PE split (use Platform-owned DNS zones while still deploying Private Endpoints in the workload VNet).
- Added Platform Landing Zone documentation.

## 0.1.6

### Changed
- Fixed API Management deployment failure by preventing APIM Private Endpoint creation when APIM is deployed with `virtualNetworkType: Internal` (Private Endpoint is only created when explicitly requested with `apimDefinition.virtualNetworkType: None`).
- Updated documentation to reflect APIM defaults (Premium + Internal VNet) and clarify APIM Private Endpoint behavior.
- Fixed API Management NSG SQL outbound port (1433).
- Changed default API Management deployment to `PremiumV2` with `virtualNetworkType: Internal` (VNet injection).
- Added a native APIM deployment path to support `PremiumV2` (the AVM APIM module currently used by this repo does not expose `PremiumV2` as an allowed SKU).
- Added APIM documentation covering networking options and parameterization.
- Added `deployToggles.aiFoundry` to allow disabling AI Foundry (and prevent deployment of its internally-managed dependencies such as Search/Storage/Cosmos when not desired).
- Added support for deploying AI Foundry **account + project + model deployments** without the Foundry Agent Service (Capability Hosts) and without associated resources, controlled via `aiFoundryDefinition.includeAssociatedResources` and `aiFoundryDefinition.aiFoundryConfiguration.createCapabilityHosts`.
- Added AI Foundry documentation covering modes and parameterization.

## 0.1.5

### Changed

- Replaced the Microsoft Foundry implementation that followed the AVM pattern with a custom module adapted from the Microsoft Foundry samples (enables tighter control over deployment ordering and model deployments).

- In the custom Microsoft Foundry module adapted from the Microsoft Foundry samples, the following adjustments were made to improve deployment stability and align with Microsoft Foundry service behavior:

  - Reference the account-level capability host that the Foundry Agent Service creates automatically (name pattern: `${accountName}@aml_aiagentservice`) instead of creating an additional account-level capability host resource (creating another one causes `Conflict`).
    [add-project-capability-host.bicep#L25](https://github.com/Azure/AI-Landing-Zones/blob/090ff5a89211e841790888c57757f5667dbfbbe6/bicep/infra/components/ai-foundry/modules-network-secured/add-project-capability-host.bicep#L25)

  - Keep project capability host creation dependent on the account-level capability host being available (reduces intermittent "CapabilityHost not in succeeded state" failures).
    [add-project-capability-host.bicep#L41](https://github.com/Azure/AI-Landing-Zones/blob/090ff5a89211e841790888c57757f5667dbfbbe6/bicep/infra/components/ai-foundry/modules-network-secured/add-project-capability-host.bicep#L41)

  - Bumped capability host API versions from preview to GA (`2025-06-01`) to align with Foundry Agent Service documentation.
    [add-project-capability-host.bicep#L27](https://github.com/Azure/AI-Landing-Zones/blob/090ff5a89211e841790888c57757f5667dbfbbe6/bicep/infra/components/ai-foundry/modules-network-secured/add-project-capability-host.bicep#L27)

  - Fixed `DeploymentOutputEvaluationFailed` when NSG deploy toggles are disabled by ensuring `agentNsgResourceId`/`peNsgResourceId` outputs never return `null` (return `''` instead).
    [main.bicep#L2923-L2926](https://github.com/Azure/AI-Landing-Zones/blob/2e73bc377d44157e53e4ffeaecd9f3ce59114b2c/bicep/infra/main.bicep#L2923-L2926)

## 0.1.4

### Changed

- [APIM connectivity should be intenal Vnet instead of using private endpoint](https://github.com/Azure/AI-Landing-Zones/issues/21)
- [Azure Defender for AI needs to be enabled during the deployment and configuration - Bicep](https://github.com/Azure/AI-Landing-Zones/issues/27)

## 0.1.3

### Changes

- Updated password parameter configuration.

## 0.1.2

### Changes

- Fixed Linux execution permissions for preprovision.sh and postprovision.sh scripts.
- Added Azure Bastion subnet NSG with required security rules per Microsoft documentation.
- Adapted to new directory structure.

## 0.1.1

### Changes

- Adopted **Template Specs** to bypass ARM 4 MB template size limit (wrappers, pre/post provision scripts).
- Simplified and clarified `README.md`.
- Added `docs/defaults.md` with parameter defaults.
- Updated `azure.yaml` (project rename, paths, hooks).

### Breaking Changes

- None

## 0.1.0

### Changes

- Initial version


## 0.1.1

### Changes

- Adopted **Template Specs** to bypass ARM 4 MB template size limit (wrappers, pre/post provision scripts).
- Simplified and clarified `README.md`.
- Added `docs/defaults.md` with parameter defaults.
- Updated `azure.yaml` (project rename, paths, hooks).

### Breaking Changes

- None

## 0.1.0

### Changes

- Initial version
