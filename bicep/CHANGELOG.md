# Changelog

The latest version of the changelog can be found [here](https://github.com/Azure/AI-Landing-Zones/blob/main/bicep/CHANGELOG.md).

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
