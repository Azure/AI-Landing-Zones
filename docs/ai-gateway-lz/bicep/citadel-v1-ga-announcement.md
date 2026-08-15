# Citadel Governance Hub v1 GA Announcement Pack

## Full announcement: Citadel Governance Hub v1 is generally available

We are announcing the general availability of **Citadel Governance Hub v1**, the Layer 1 reference implementation of the [AI Citadel Blueprint](https://aka.ms/foundry-citadel).

Citadel Governance Hub is an enterprise AI landing-zone accelerator that provides a centralized, governable, and observable gateway plane for AI consumption. Built on Azure API Management, it gives platform teams a repeatable way to onboard AI backends, enforce runtime policy, provide governed access to applications and agents, and attribute usage across teams and environments.

The accelerator is available from the [Azure Samples repository](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator) and at [aka.ms/ai-hub-gateway](https://aka.ms/ai-hub-gateway).

## GA highlights

### One governed gateway for multi-provider AI

- Unified routing for Microsoft Foundry, Azure OpenAI, Amazon Bedrock, Google Gemini, Anthropic Claude, and OpenAI-compatible providers.
- Native and OpenAI-compatible API surfaces for chat, embeddings, responses, realtime, and supported image-generation scenarios.
- Dynamic model discovery and model aliases that decouple client-facing model names from backend deployments.

### Contract-driven onboarding and governance

- **Backend Contracts** declare providers, models, authentication, pools, routing behavior, and resiliency settings as infrastructure-as-code.
- **Access Contracts** create governed APIM products and subscriptions with model authorization, throttling, quotas, content safety, PII controls, and optional layered JWT authentication.
- Version-controlled Bicep parameters support repeatable onboarding through pull requests and CI/CD workflows without requiring teams to edit shared gateway policies.

### Resilient routing for production workloads

- Load-balanced backend pools with priority and weighted routing.
- Circuit breakers, automated failover, retry-aware behavior, and configurable error handling.
- Session affinity for stateful model workloads that need follow-up requests routed to the same backend.
- Multi-region and business-continuity guidance for globally deployed governance hubs.

### Security, observability, and cost attribution

- Managed identity for supported Azure service-to-service authentication.
- Central policy enforcement for content safety, PII handling, API keys, JWT validation, rate limits, and quotas.
- Application Insights, Log Analytics, Event Hubs, Logic Apps, and Cosmos DB integration for operational and usage telemetry.
- Power BI reporting for usage analysis, cost allocation, and chargeback by product, application, model, and backend.

### Deployment, operations, and validation

- Bicep-based deployment through Azure Developer CLI, with a separate [Terraform implementation](https://github.com/Azure/terraform-ai-gateway-landing-zone).
- Quick-start and full deployment paths for evaluation and enterprise landing-zone scenarios.
- Post-deployment guides for backend onboarding, access contracts, authentication, reporting, resiliency, and business continuity.
- Validation notebooks covering routing, model aliases, multi-provider access, image models, session affinity, security policies, and agent-framework integration.
- Runtime release visibility through `GET /version` and active backend-contract visibility through `GET /version/backend-contract`.

## Available in Preview

The following capabilities ship with v1 as functional Preview features. Their configuration surfaces may change before general availability, so pin exact versions and validate changes in a non-production environment:

- **Citadel Publish Contracts `1.0.0-preview`** for publishing Tools (MCP) and Agents (A2A), including Foundry-hosted A2A agents, with baseline policies, usage tracking, supported backend resiliency, and optional Azure API Center registration.
- **Microsoft Foundry APIM connection and Foundry-hosted A2A integration**, enabling governed agent access and agent publishing through the gateway.
- **APIM Gateway Upgrade `1.0.0-preview`** for applying gateway capabilities to an existing Citadel or classic AI Hub Gateway deployment without re-provisioning the surrounding landing-zone infrastructure.

## Release versions

| Component | Version | Status |
|-----------|---------|--------|
| Citadel Governance Hub | `1.0.2` | GA |
| Routing | `1.0.0` | GA |
| Backend Contract | `1.1.0` | GA |
| Access Contract | `1.2.0` | GA |
| Usage ingestion | `1.1.0` | GA |
| Publish Contract | `1.0.0-preview` | Preview |
| APIM Gateway Upgrade | `1.0.0-preview` | Preview |

## Get started

1. Review the [architecture and capabilities](../README.md).
2. Use the [Quick Deployment Guide](./quick-deployment-guide.md) for a non-production evaluation or the [Full Deployment Guide](./full-deployment-guide.md) for an enterprise deployment.
3. Follow the [Post-Deployment Guide](./post-deployment-guide.md) to onboard backends and use cases.
4. Run the [validation notebooks](../validation/README.md) before promoting the gateway to production.
5. Review [Release Version Management](./release-version-management.md) before adopting subsequent releases or Preview updates.

We welcome feedback and contributions through the repository's [GitHub issues](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/issues).

---
