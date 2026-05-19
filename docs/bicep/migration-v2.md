# Migration to v2

This page summarizes the upgrade path from AI Landing Zone Bicep **v1.x** to **v2**. For the complete parameter map and rationale, see the full guide at [docs/v2-migration.md](https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/main/docs/v2-migration.md) in the source repository.

!!! info "First-time deployments"
    You do **not** need this page if you are deploying for the first time. Go straight to [How to Deploy](how-to-deploy.md) or the [Hub-and-Spoke Topology](hub-and-spoke.md) walkthrough.

## Why v2?

v1.x assumed a **standalone** topology: the template provisions every networking and platform resource the AI workload needs inside a single subscription. That worked great for green-field demos, but it didn't fit customers integrating the AI workload into an existing **Application Landing Zone** where the hub already provides:

- Azure Firewall and a central NAT egress path
- A Bastion host and shared jumpbox VMs
- Centrally-managed Private DNS zones
- A platform Log Analytics workspace and Application Insights

v2 lets you bring any of those resources from the outside via an existing-resource-ID parameter — while keeping the ability to fall back to "create it for me" on a per-resource basis. Additional features added in v2:

- **Hybrid network access** — combine private endpoints with a public IP allow-list (`allowedIpRanges`) so a dev workstation can hit the data plane without routing the whole team through Bastion.
- **Decoupled hub components** — independently deploy or BYO the jumpbox, Bastion, and NAT Gateway.
- **Topology preset** — set the deployment shape once with `deploymentMode` and the template picks coherent defaults for every networking and identity flag.
- **Pre-flight validation** — a PowerShell script runs as an `azd preprovision` hook and catches misconfigured BYO IDs, undersized subnets, CIDR overlaps, and parameter conflicts before they reach ARM.

## What changed at a glance

| Capability | v1.x | v2 |
|---|---|---|
| Topology preset | Implicit | New `deploymentMode` (`standalone` \| `ailz-integrated`) |
| IP allow-list for PaaS data planes | Not supported | New `allowedIpRanges` parameter, applied to 7 services |
| Jumpbox / Bastion / NAT Gateway | One coarse `deployVM` flag | Three independent flags + BYO resource IDs |
| Observability | Always creates LAW + App Insights | Can reuse existing LAW and App Insights (cross-subscription supported) |
| Private DNS zones | Always created by the spoke | Can BYO **per zone** (15 overrides) plus `dnsZoneLinkSuffix` for shared zones |
| Hub egress | Implicit Azure Firewall in same RG | Can route to an **external** firewall / NVA via next-hop IP |
| Hub peering | Manual post-deploy | Spoke→hub created by `main.bicep` |
| Container app port | Always `8080` | Per-app `target_port` honored (still defaults to `8080`) |
| Pre-flight validation | None | `scripts/Invoke-PreflightChecks.ps1` runs automatically before `azd provision` |

Every v2 parameter has either a sensible default that reproduces v1.x behavior, or a `null`/empty default that means **"don't override"**. Apart from the explicit `deployVM` → `deployJumpbox` / `deployBastion` / `deployNatGateway` split, the v1.x mental model still works.

## Things that need attention when upgrading

### `deployVM` is split into three flags

`deployVM` is removed. Replace each `deployVM=true` with the three independent flags:

```bash
# Before
azd env set DEPLOY_VM true

# After (v2)
azd env set DEPLOY_JUMPBOX      true
azd env set DEPLOY_BASTION      true
azd env set DEPLOY_NAT_GATEWAY  true
```

If you only want the jumpbox VM and not Bastion or the NAT Gateway, set only `DEPLOY_JUMPBOX=true`. The previous all-or-nothing semantics are gone.

### `keyVaultResourceId` is replaced

The flat `keyVaultResourceId` parameter is replaced by a structured BYO Key Vault reference. See the [full migration guide](https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/main/docs/v2-migration.md#3-3-key-vault-byo-parameter-renamed) for the exact replacement and parameter file diff.

### Default container app port

The default Container Apps ingress port is still `8080`, but each entry in `containerAppsList` can now set an explicit `target_port`. If you previously relied on the implicit `80` from a custom image, set `target_port: 80` explicitly.

### Pre-flight hook now runs by default

`azd provision` now invokes `scripts/Invoke-PreflightChecks.ps1` via the `azd preprovision` hook. Set `PREFLIGHT_SKIP=true` in your shell to bypass it.

## Quick upgrade checklist

1. **Read the source guide** — [docs/v2-migration.md](https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/main/docs/v2-migration.md) for the full parameter map.
2. **Bump the submodule** if you consume the template as `infra/` in a downstream accelerator — pin to the latest v2 tag.
3. **Replace `deployVM`** with the three new flags in your `azd env` and/or `main.parameters.json`.
4. **Run the pre-flight script** manually first: `pwsh -File scripts/Invoke-PreflightChecks.ps1 -AzdEnv <your-env>`.
5. **Re-run `azd provision`** in a non-production environment to catch anything the pre-flight script didn't.
6. **Adopt the new features** — `deploymentMode`, `allowedIpRanges`, BYO LAW / App Insights / DNS zones — at your own pace.

## See also

- [Source-repo migration guide](https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/main/docs/v2-migration.md) — exhaustive parameter map, exit codes, pre-flight matrix
- [Source-repo standalone runbook](https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/main/docs/runbook-standalone.md)
- [Source-repo hub-and-spoke runbook](https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/main/docs/runbook-hub-spoke.md)
- [v2 release notes on GitHub](https://github.com/Azure/bicep-ptn-aiml-landing-zone/releases?q=v2&expanded=true)
