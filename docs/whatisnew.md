# What's New

## 18th May 2026
- **AI Landing Zones Bicep v2.0.0 released.** Adds hub-and-spoke composability and granular reuse of platform resources for Application Landing Zone (ALZ) integrated topologies. Highlights:
    - **Topology preset** — new `deploymentMode` parameter (`standalone` / `ailz-integrated`)
    - **IP allow-lists** — new `allowedIpRanges` parameter for "Zero Trust + named developer IPs" hybrid scenarios, applied uniformly to 7 PaaS services
    - **Decoupled jumpbox / Bastion / NAT Gateway** — split from the old monolithic `deployVM` flag, each independently controllable, each with a BYO `existingResourceId` variant
    - **Observability reuse** — bring your own Log Analytics workspace and Application Insights, including cross-subscription scenarios
    - **Granular BYO Private DNS** — 15 per-zone override parameters, plus `dnsZoneLinkSuffix` for multi-spoke shared-zone topologies
    - **Hub integration** — new spoke→hub VNet peering (created by `main.bicep`) and external-egress UDR via hub firewall/NVA
    - **Pre-flight validation** — new `scripts/Invoke-PreflightChecks.ps1` runs as an `azd preprovision` hook to catch parameter mistakes before they reach ARM
    - See the [Migration to v2.0](bicep/migration-v2.md) guide and the [Hub-and-Spoke Topology](bicep/hub-and-spoke.md) runbook for full details. Release: [v2.0.0](https://github.com/Azure/bicep-ptn-aiml-landing-zone/releases/tag/v2.0.0).

## 17th November 2025
- AI Landing Zones goes from preview to GA
- AI Landing Zones [Terraform guide](https://github.com/Azure/AI-Landing-Zones/blob/main/terraform/readme.md) published

## 6th November 2025
- AI Landing Zones Cost Guide added to documentation

## 5th November 2025
- Updated the AI Landing Zones Design checklist with new checks along with restructuring by design areas, considerations and recommendations.
- Update the terraform sample code for AI Landing Zones.