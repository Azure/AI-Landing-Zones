# Regional Considerations

Choosing the right Azure region for an AI Landing Zone deployment is more than provider/location support. Some resources can be **listed as supported** in a region but still fail at provision time because of **transient regional capacity** that is not exposed by any reliable pre-create quota API.

## Why provider/location support is not enough

Azure Resource Manager only tells you whether a resource type is **registered and available** in a region. It does not tell you whether that region has free capacity *right now* for your subscription tier and SKU. The control plane only attempts allocation when the deployment actually runs, and capacity-related failures surface as errors such as `InsufficientResourcesAvailable` or `ServiceUnavailable` minutes into a provision that otherwise looked healthy.

## Resources with known transient capacity caveats

The following resource types are part of the AI Landing Zone and have been observed to fail at provision time even when the region lists them as supported. Treat these as **regions to validate, not regions to trust blindly**:

- **Azure AI Search** — may return `InsufficientResourcesAvailable` for the chosen SKU/region combination. There is no pre-create quota API to consult.
- **Azure Cosmos DB** — may return high-demand `ServiceUnavailable` errors during account creation in popular regions.
- **Azure Container Apps Environment** — managed environment creation can fail in regions under heavy demand, especially for workload profile environments.

This is not an exhaustive list; AI Foundry and AI Services model deployments are governed instead by **regional model quota**, which *can* be checked ahead of time and should be validated separately for each model SKU you plan to deploy.

## Recommended practice

- **Pick a primary region and an alternate region up front.** If the primary fails on capacity, you want to fail over quickly rather than redesign.
- **Validate model quota first.** Use `az cognitiveservices usage list --location <region>` for the model SKUs you need. This is the one signal you *can* trust before provisioning. As of **landing zone [v2.0.3](https://github.com/Azure/bicep-ptn-aiml-landing-zone/releases/tag/v2.0.3)** the `azd preprovision` hook does this automatically for every `format=OpenAI` entry in `modelDeploymentList` and fails fast (`MODEL_QUOTA_INSUFFICIENT`) if `(limit − currentValue) < sku.capacity` for any of them.
- **Treat the first provision as a capacity probe.** If it fails on `InsufficientResourcesAvailable` or `ServiceUnavailable`, retry in the alternate region. Do not assume the failure means the deployment template is broken.
- **Tear down failed provisions asynchronously.** Resource groups holding Cosmos DB, AI Search, or Container Apps Environment can take 10–30 minutes to delete. Use `az group delete --no-wait` and move on with a fresh resource group name.

!!! info "What the preflight now covers (v2.0.3+)"
    Starting with [v2.0.3](https://github.com/Azure/bicep-ptn-aiml-landing-zone/releases/tag/v2.0.3) (issue [#72](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/72)), `scripts/Invoke-PreflightChecks.ps1` extends its read-only validation with a regional readiness pass that runs from the `azd preprovision` hook. It checks: **subscription drift** vs. the azd env, **provider/location support per resource type** (AI Search, Cosmos DB, Container Apps, AI Foundry/Cognitive Services, Key Vault, Storage, App Configuration, Log Analytics, Application Insights), **jumpbox VM SKU availability** in the region, and **AI model quota**. Each check is gated on the corresponding `deploy*` feature flag.

!!! warning
    Even with v2.0.3+, the preflight surfaces **transient regional capacity** caveats for AI Search, Cosmos DB, and Container Apps Environment as **`WARN` (non-blocking)** findings only, because Azure does not expose that signal before allocation. A passing preflight does not guarantee a successful provision in a capacity-constrained region — the WARN just makes it obvious what to retry in your alternate region if provisioning later fails.

    You can opt out of the new regional block (while keeping parameter/topology/BYO validation) via the `LZ_PREFLIGHT_REGIONAL_SKIP=true` env var or the `-SkipRegional` switch on the script. The full preflight can still be bypassed via `PREFLIGHT_SKIP=true` or `-SkipAzureLookups` (offline/CI).

## See also

- [How to Deploy](how-to-deploy.md) — covers the `azd preprovision` hook and parameter validation.
- [Parameterization](parameterization.md) — how to set the deployment region and BYO resource overrides.
