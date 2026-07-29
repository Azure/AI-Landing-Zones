# Bug Report: Maintenance Configuration Wrapper Drops Parameters

**Repository:** Azure/bicep-ptn-aiml-landing-zone  
**Component:** `modules/common/maintenanceConfiguration.bicep` → compiled wrapper `avm.res.maintenance.maintenance-configuration.json`  
**Severity:** High — deployment failure  
**Affected Version:** v2.3.0 (published 2026-07-02)

---

## Title

`avm.res.maintenance.maintenance-configuration.json` wrapper does not forward `maintenanceScope` or scheduling properties to inner template — defaults to `Host` scope, breaking non-isolated VMs

## Summary

The compiled ARM wrapper for the maintenance configuration resource only passes `name`, `location`, and `tags` to its inner nested deployment. All other properties from the `maintenanceConfig` parameter object — including `maintenanceScope`, `maintenanceWindow`, `extensionProperties`, `rebootSetting`, `duration`, `recurEvery`, `startDateTime`, and `timeZone` — are silently dropped.

Because the inner template's `maintenanceScope` parameter has `"defaultValue": "Host"`, the maintenance configuration is **always** created with `Host` scope regardless of what the caller specifies.

## Steps to Reproduce

1. Deploy the solution with `jumpVmMaintenanceDefinition` set to:
   ```json
   {
     "maintenanceScope": "InGuestPatch",
     "rebootSetting": "IfRequired",
     "duration": "03:00",
     "recurEvery": "1Week Saturday",
     "startDateTime": "2024-06-15 22:00",
     "timeZone": "UTC",
     "extensionProperties": { "InGuestPatchMode": "User" }
   }
   ```
2. Use a non-isolated VM SKU (e.g., `Standard_D4as_v5`).
3. The maintenance configuration is created with `maintenanceScope: "Host"` (ignoring the caller's `InGuestPatch`).
4. When the AVM VM wrapper attempts to create a `Microsoft.Maintenance/configurationAssignments` on the VM, it fails.

## Error Message

```
Code: UnsupportedResourceOperation
Message: Invalid configurationAssignment: Non-Isolated VMs are currently not permitted to opt in to Maintenance
Target: vm-{baseName}-jmp
```

## Root Cause

In the compiled wrapper JSON (line ~265), the inner deployment parameters block:

```json
"parameters": {
  "name": {
    "value": "[parameters('maintenanceConfig').name]"
  },
  "location": {
    "value": "[tryGet(parameters('maintenanceConfig'), 'location')]"
  },
  "tags": {
    "value": "[tryGet(parameters('maintenanceConfig'), 'tags')]"
  }
}
```

**Missing parameters that should be forwarded:**
- `maintenanceScope` → defaults to `"Host"` instead of caller's `"InGuestPatch"`
- `maintenanceWindow` → scheduling window not applied
- `extensionProperties` → `InGuestPatchMode` lost
- `installPatches` → patch classification config lost
- `namespace` → not forwarded
- `visibility` → not forwarded

## Expected Behavior

The wrapper should forward all properties from the `maintenanceConfig` input object to the inner AVM module parameters, or at minimum:

```json
"parameters": {
  "name": { "value": "[parameters('maintenanceConfig').name]" },
  "location": { "value": "[tryGet(parameters('maintenanceConfig'), 'location')]" },
  "tags": { "value": "[tryGet(parameters('maintenanceConfig'), 'tags')]" },
  "maintenanceScope": { "value": "[tryGet(parameters('maintenanceConfig'), 'maintenanceScope')]" },
  "maintenanceWindow": { "value": "[tryGet(parameters('maintenanceConfig'), 'maintenanceWindow')]" },
  "extensionProperties": { "value": "[tryGet(parameters('maintenanceConfig'), 'extensionProperties')]" },
  "installPatches": { "value": "[tryGet(parameters('maintenanceConfig'), 'installPatches')]" },
  "namespace": { "value": "[tryGet(parameters('maintenanceConfig'), 'namespace')]" },
  "visibility": { "value": "[tryGet(parameters('maintenanceConfig'), 'visibility')]" }
}
```

## Impact

- **Jump VM maintenance**: Cannot enable automated guest patching via Portal deployment
- **Build VM maintenance**: Same issue (same wrapper used for both)
- **Workaround**: Both maintenance toggles disabled in Portal form; users must configure maintenance post-deployment via Azure Update Manager directly

## Portal Re-enablement Steps (after upstream fix)

Once the upstream Bicep module is fixed and a new release is published:

1. Recompile the `avm.res.maintenance.maintenance-configuration.json` wrapper from the fixed Bicep source
2. In `portal/form.json`, restore the Jump VM maintenance toggle:
   - Change `"visible": false` → `"visible": "[equals(steps('devops').deployJumpVm, 'true')]"`
   - Restore tooltip: `"Enable automated maintenance configuration for the Jump VM. This configures scheduled patching and updates for the Windows VM."`
   - Restore output: `"jumpVmMaintenanceDefinition": "[if(equals(steps('devops').enableJumpVmMaintenance, 'true'), parse('{\"maintenanceScope\":\"InGuestPatch\",\"rebootSetting\":\"IfRequired\",\"duration\":\"03:00\",\"recurEvery\":\"1Week Saturday\",\"startDateTime\":\"2024-06-15 22:00\",\"timeZone\":\"UTC\",\"extensionProperties\":{\"InGuestPatchMode\":\"User\"}}'), parse('{}'))]"`
3. In `portal/form.json`, restore the Build VM maintenance toggle:
   - Change `"visible": false` → `"visible": "[equals(steps('devops').deployBuildVm, 'true')]"`
   - Restore tooltip: `"Enable automated maintenance configuration for the Build VM. This configures scheduled patching and updates for the Linux VM."`
   - Restore output: `"buildVmMaintenanceDefinition": "[if(equals(steps('devops').enableBuildVmMaintenance, 'true'), parse('{\"maintenanceScope\":\"InGuestPatch\",\"rebootSetting\":\"IfRequired\",\"duration\":\"03:00\",\"recurEvery\":\"1Week Sunday\",\"startDateTime\":\"2024-06-16 22:00\",\"timeZone\":\"UTC\",\"extensionProperties\":{\"InGuestPatchMode\":\"User\"}}'), parse('{}'))]"`
4. Remove entry #37 from `bicep-only-no-portal.md`
5. Test deployment with maintenance enabled on both VMs

## Environment

- Bicep compiler version: 0.38.33.27573
- AVM module inner templateHash: `16060601297152129929`
- Inner Bicep version stamp: `0.34.44.8038`
- Region tested: `swedencentral`
- VM SKU: `Standard_D4as_v5`

## Suggested Fix Location

The Bicep source module that compiles to this wrapper needs to pass through the `maintenanceScope` and scheduling parameters in its nested module call. Likely in `modules/common/maintenanceConfiguration.bicep` or the equivalent composition module.
