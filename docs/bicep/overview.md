# Overview

The Azure AI Landing Zone is an enterprise-scale, production-ready reference architecture designed to deploy secure and resilient AI applications and agents on Azure. The Bicep implementation is maintained in a dedicated repository.

**Source repository:** [Azure/bicep-ptn-aiml-landing-zone](https://github.com/Azure/bicep-ptn-aiml-landing-zone/)

![Architecture Diagram](https://raw.githubusercontent.com/Azure/bicep-ptn-aiml-landing-zone/main/media/Architecture%20Diagram.png)

## Deployment modes

The template supports three deployment topologies that you choose with the `deploymentMode` parameter (introduced in **v2.0.0**). Each topology is a curated set of defaults — every individual flag remains overridable.

| Mode | `deploymentMode` value | Network isolation | Jumpbox VM | Hub integration | Use case |
|---|---|---|---|---|---|
| **Standalone** | `standalone` (default) | Optional (`networkIsolation=true`) | Optional | None | Self-contained sandbox: a single spoke that contains its own Bastion, NAT Gateway, and (optionally) Azure Firewall |
| **Hub-and-Spoke (test)** | `standalone` + `hubIntegration.hubVnetResourceId` set | Yes | Yes | Spoke peers to a hub you own | Same template, plus a peering to a hub VNet that hosts the shared Bastion/Firewall |
| **AI LZ Integrated** | `ailz-integrated` | Yes (enforced) | Off by default | Required (via existing hub) | The spoke participates in an Azure Landing Zone: it reuses hub services (Firewall, Bastion, Private DNS, Log Analytics) instead of provisioning its own |

All three topologies are deployed using the [Azure Developer CLI (`azd`)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd). See [How to Deploy](how-to-deploy.md) for step-by-step instructions and the [Hub-and-Spoke Topology](hub-and-spoke.md) runbook for the full hub + spoke walkthrough.

## What gets deployed

The template provisions a complete AI application environment with the following core services:

- **Microsoft Foundry** — AI Foundry account and project with model deployments
- **Azure AI Search** — Search service for retrieval-augmented generation (RAG)
- **Azure Cosmos DB** — Database for conversation history and application data
- **Azure Container Apps** — Container runtime with managed environment and workload profiles
- **Azure Container Registry** — Private registry for container images
- **Azure Key Vault** — Secrets and certificate management
- **Azure App Configuration** — Centralized application configuration
- **Azure Storage Account** — Blob storage for documents and data
- **Azure Application Insights** — Application monitoring and diagnostics
- **Azure Log Analytics** — Centralized logging

When network isolation is enabled, the deployment additionally provisions:

- Virtual network with private endpoints for all services
- Network Security Groups (NSGs)
- Azure Bastion for secure VM access
- Jumpbox VM with pre-installed development tools
- Private DNS zones for name resolution

Every service can be individually toggled on or off via deploy parameters. See [Parameterization](parameterization.md) for the full reference.

## Role assignments

The deployment configures role-based access control (RBAC) for service-to-service communication using managed identities. See [Permissions](permissions.md) for the complete list of role assignments.

## What's new in v2.0.0

**v2.0.0** (May 2026) extends the template with composability features for enterprises integrating the AI Landing Zone into an existing Azure Landing Zone. The major themes:

- **Bring your own platform services** — the spoke can now consume an existing Log Analytics workspace, Application Insights, hub VNet, Private DNS zones, route table, and NAT Gateway / Bastion / jumpbox VM. Cross-subscription scenarios are supported.
- **Hybrid network access** — the new `allowedIpRanges` parameter combines private endpoints with a public IP allow-list across Storage, Key Vault, Cosmos DB, AI Search, ACR, AI Foundry, and Container Registry.
- **Topology preset** — pick `standalone` or `ailz-integrated` once with `deploymentMode`; the template derives a coherent default for every networking and identity flag.
- **Decoupled jumpbox / Bastion / NAT Gateway** — each is now independently controllable; the old `deployVM` umbrella is removed.
- **Pre-flight validation** — `scripts/Invoke-PreflightChecks.ps1` runs automatically before `azd provision` and catches subnet sizing / CIDR overlap / parameter conflicts before they reach ARM.

If you are upgrading from v1.x, read the [Migration to v2.0](migration-v2.md) guide before re-deploying.

## Next steps

- [How to Deploy](how-to-deploy.md) — Prerequisites and deployment instructions
- [Hub-and-Spoke Topology](hub-and-spoke.md) — Step-by-step walkthrough for ALZ-integrated deployments (**new in v2.0**)
- [Migration to v2.0](migration-v2.md) — Breaking-change map and upgrade guide (**new in v2.0**)
- [Parameterization](parameterization.md) — Full parameter reference
- [Permissions](permissions.md) — Role assignments provisioned by the template
