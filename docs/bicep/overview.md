# Overview

The Azure AI Landing Zone is an enterprise-scale, production-ready reference architecture designed to deploy secure and resilient AI applications and agents on Azure. The Bicep implementation is maintained in a dedicated repository.

**Source repository:** [Azure/bicep-ptn-aiml-landing-zone](https://github.com/Azure/bicep-ptn-aiml-landing-zone/)

![Architecture Diagram](https://raw.githubusercontent.com/Azure/bicep-ptn-aiml-landing-zone/main/media/Architecture%20Diagram.png)

## Deployment modes

The template supports three deployment topologies. You pick one with the `deploymentMode` parameter — each topology is a curated set of defaults, and every individual flag remains overridable.

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

## Highlights

The Bicep implementation supports two deployment shapes that matter most for everyday use:

1. **A topology switch** — set `deploymentMode` to one of:
    - **`standalone`** — the AI Landing Zone provisions everything it needs (VNet, private endpoints, Bastion, jumpbox, NAT Gateway, observability). Best for sandboxes, evaluations, and teams without a corporate hub.
    - **`ailz-integrated`** — the AI Landing Zone deploys only the **spoke** (VNet + private endpoints + AI services) and peers into a hub VNet you already operate, reusing the hub's Firewall, Bastion, Private DNS zones, and Log Analytics workspace. Best for production inside an existing Azure Landing Zone.
2. **Granular reuse of existing resources** — every platform service can be brought from the outside via an `existing*ResourceId` parameter (cross-subscription IDs are accepted): Log Analytics, Application Insights, Private DNS zones (per zone, 15 available), hub VNet, jumpbox, Bastion, NAT Gateway, route table.

A handful of other quality-of-life additions:

- **`allowedIpRanges`** — let named CIDRs reach the data plane of Storage, Key Vault, Cosmos DB, AI Search, ACR, AI Foundry, and App Configuration without disabling private endpoints. Use this when developers need to query the workload from their laptops without routing through Bastion.
- **Decoupled hub components** — `deployJumpbox`, `deployBastion`, and `deployNatGateway` are now independent flags.
- **Hub integration helpers** — `hubIntegration.hubVnetResourceId` creates the spoke→hub peering for you; `hubIntegration.egressNextHopIp` routes spoke egress through your hub firewall / NVA.
- **Pre-flight validation** — `scripts/Invoke-PreflightChecks.ps1` runs automatically as an `azd preprovision` hook and catches the usual mistakes (CIDR overlap, undersized subnets, missing BYO resource IDs, conflicting flags) before they reach ARM. Bypass with `PREFLIGHT_SKIP=true`.

## Next steps

- [How to Deploy](how-to-deploy.md) — Prerequisites and deployment instructions
- [Hub-and-Spoke Topology](hub-and-spoke.md) — Step-by-step walkthrough for ALZ-integrated deployments
- [Public Ingress with Application Gateway](public-ingress.md) — Publish a private Container App through Application Gateway WAF v2
- [Parameterization](parameterization.md) — Full parameter reference
- [Permissions](permissions.md) — Role assignments provisioned by the template
