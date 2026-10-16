# What's New

## 14th October 2026

**Agent Landing Zone v4.3.0 released.**

- **Independent ingestion deployment** — fresh, supported native-ingestion deployments omit the ingestion Container App. Existing and custom deployments retain their component choices; disabling deployment does not delete existing applications or document data. See [ingestion application selection](agent-landing-zone/configuration.md#ingestion-application-selection).
- **Ingestion-aware uploads** — UI v3.3.0 disables upload controls and rejects attachments server-side when the ingestion application is disabled. Text chat, authentication and retrieval remain available.
- **Private native Blob ingestion safeguards** — network-isolated setup requires the exact Search shared private links to be approved and successfully provisioned, with administrator approval instructions when pending. No unrelated or target-side connections are approved automatically. See [private native Blob ingestion](agent-landing-zone/network-isolation.md#private-native-blob-ingestion).
- **Explicit shared-source permissions** — deliberately shared, non-ADLS Blob sources can use empty ingestion permission options; protected defaults remain unchanged. Review the [shared-source permission guidance](agent-landing-zone/configuration.md#explicit-shared-source-permission-options) before opting in.
- **Isolated image builds and DNS** — build-subnet-only HTTPS egress now covers the pinned Microsoft npm feeds and package-download CDN without requiring firewall DNS proxy. The separate `ENABLE_FIREWALL_DNS_PROXY` option defaults to `false` and does not change client DNS. See [image builds](agent-landing-zone/network-isolation.md#image-builds-in-isolated-deployments) and [firewall DNS proxy](agent-landing-zone/network-isolation.md#opt-in-firewall-dns-proxy).

The [release manifest](https://github.com/Azure/agent-landing-zone/blob/v4.3.0/manifest.json) pins UI **v3.3.0**, orchestrator **v5.2.1**, ingestion **v3.1.1**, and infrastructure / AI Landing Zone **v2.7.3**.

Start with the [full-stack deployment guide](agent-landing-zone/deploy-full-stack.md). For complete changes and reported validation, see the [v4.3.0 release notes](https://github.com/Azure/agent-landing-zone/releases/tag/v4.3.0).

## 19th May 2026
- **AI Landing Zones Bicep v2.0.2 released.** Hotfix for a v2.0.0 regression that caused `azd provision` to fail mid-deployment with `InvalidTemplate: 'databaseAccount_privateEndpoints[0]' / 'keyVault_privateEndpoints[0]' ... 'reference' is not valid: all function arguments should be string literals.` whenever `networkIsolation=false` was combined with the default `deployAiFoundry=true`. The fix gates the AI Foundry private-endpoint subnet on `_networkIsolation`, mirroring an existing sibling pattern in the same file. No behavior change for the `networkIsolation=true` (Zero Trust) topology. Release: [v2.0.2](https://github.com/Azure/bicep-ptn-aiml-landing-zone/releases/tag/v2.0.2).
- **AI Landing Zones Bicep v2.0.1 released.** Hotfix for a v2.0.0 regression in the AI Foundry account private-endpoint emission that caused `azd provision` to fail with `InvalidTemplate: 'The resource 'Microsoft.Resources/deployments/module.account.pe.<name>' is not defined in the template'` during template validation. Single-line fix; no behavior change for any topology. Release: [v2.0.1](https://github.com/Azure/bicep-ptn-aiml-landing-zone/releases/tag/v2.0.1).

## 18th May 2026

**AI Landing Zones Bicep v2 released.** Adds hub-and-spoke composability and granular reuse of platform resources for Application Landing Zone (ALZ) integrated topologies.

**Highlights:**

- **Topology preset** — new `deploymentMode` parameter (`standalone` / `ailz-integrated`) picks the deployment shape in one place
- **IP allow-lists** — new `allowedIpRanges` parameter for "Zero Trust + named developer IPs" hybrid scenarios, applied uniformly to 7 PaaS services
- **Decoupled jumpbox / Bastion / NAT Gateway** — each is now an independent flag, each with a BYO `existingResourceId` variant
- **Observability reuse** — bring your own Log Analytics workspace and Application Insights, including cross-subscription scenarios
- **Granular BYO Private DNS** — 15 per-zone override parameters, plus `dnsZoneLinkSuffix` for multi-spoke shared-zone topologies
- **Hub integration** — new spoke→hub VNet peering (created by `main.bicep`) and external-egress UDR via hub firewall/NVA
- **Pre-flight validation** — `scripts/Invoke-PreflightChecks.ps1` runs as an `azd preprovision` hook and catches parameter mistakes before they reach ARM

See the [Hub-and-Spoke Topology](bicep/hub-and-spoke.md) runbook for full details. Release: [v2.0.0](https://github.com/Azure/bicep-ptn-aiml-landing-zone/releases/tag/v2.0.0).

## 17th November 2025
- AI Landing Zones goes from preview to GA
- AI Landing Zones [Terraform guide](terraform/index.md) published

## 6th November 2025
- AI Landing Zones Cost Guide added to documentation

## 5th November 2025
- Updated the AI Landing Zones Design checklist with new checks along with restructuring by design areas, considerations and recommendations.
- Update the terraform sample code for AI Landing Zones.
