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
- **Validate model quota first.** Use `az cognitiveservices usage list --location <region>` for the model SKUs you need. The platform's `azd preprovision` hook runs foundation preflight for every `format=OpenAI` entry in `modelDeploymentList` and fails fast (`MODEL_QUOTA_INSUFFICIENT`) if `(limit − currentValue) < sku.capacity` for any of them. Available quota does not reserve allocation capacity.
- **Separate a fresh capacity test from an existing deployment.** If a fresh
  deployment fails on `InsufficientResourcesAvailable` or `ServiceUnavailable`,
  review failed operations and approved regional alternatives. A different region
  needs a new environment and dedicated scope; do not move existing data-bearing
  resources or silently change their locations.
- **Preserve partial deployments until recovery is decided.** Inventory created
  resources and data, then retry the same approved inputs or obtain approval for
  [safe removal](../agent-landing-zone/deploy-full-stack.md#remove-an-environment).
  A capacity failure is not permission to delete or purge a resource group.

!!! info "Regional preflight checks"
    The platform's `azd preprovision` hook invokes
    `infra/scripts/Invoke-PreflightChecks.ps1`. Its read-only regional pass
    checks **subscription drift** vs. the azd environment,
    **provider/location support per resource type** (AI Search, Cosmos DB,
    Container Apps, AI Foundry/Cognitive Services, Key Vault, Storage,
    App Configuration, Log Analytics, Application Insights),
    **jumpbox VM SKU availability** and **AI model quota**. Each check is
    gated on the corresponding `deploy*` feature flag.

!!! warning
    Preflight surfaces **transient regional capacity** caveats for AI Search,
    Cosmos DB and Container Apps Environment as **`WARN` (non-blocking)**
    findings because Azure does not expose that signal before allocation.
    A passing preflight does not guarantee successful provisioning in a
    capacity-constrained region.

    Offline validation cannot establish live regional readiness. Resolve
    findings in the approved environment; do not skip preflight to recover a
    provisioning failure.

## See also

- [Deploy infrastructure only](../agent-landing-zone/deploy-infra-only.md) — provisioning and preflight.
- [Parameterization](parameterization.md) — how to set the deployment region and BYO resource overrides.
