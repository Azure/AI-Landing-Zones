# Agent Governance Toolkit (AGT) Integration Guide

This guide explains how to integrate the [Agent Governance Toolkit (AGT)](https://github.com/microsoft/agent-governance-toolkit) with Citadel Governance Hub to add **agent-level governance** on top of gateway-level controls.

**Related guides:**
- [Quick Deployment Guide](./quick-deployment-guide.md): Deploy Citadel Governance Hub
- [Access Contracts README](../bicep/infra/citadel-access-contracts/README.md): Configure agent-to-hub contracts
- [Foundry Citadel Platform](https://aka.ms/foundry-citadel): Full 4-layer architecture overview

---

## Why Integrate AGT with Citadel?

Citadel Governance Hub governs the **infrastructure perimeter**: which models, tools, and agents can be accessed, at what rate, with what safety filters. This is essential, but insufficient for production agent deployments where agents make dozens of tool calls per interaction.

AGT governs the **agent behavior itself**: what actions the agent takes, whether it follows its policies, trust relationships between agents, and tamper-evident audit logging. These are complementary enforcement boundaries, not competing approaches.

**Use AGT alongside Citadel when you need:**
- Per-action tool call allow/deny inside the agent runtime (not just at the gateway)
- Continuous trust scoring (0-1000) that adapts based on agent behavior
- Cryptographic agent identity (Ed25519 / SPIFFE) for inter-agent trust
- Tamper-evident audit logs with hash-chain evidence preservation

| Concern | Citadel (Gateway) | AGT (Agent Runtime) |
|---------|-------------------|---------------------|
| **Enforcement point** | APIM gateway (centralized) | Agent runtime library (in-process) |
| **Latency** | Network hop through gateway | Sub-millisecond (<0.1 ms per evaluation) |
| **Policy granularity** | Rate limits, content filters, quotas | Per-action allow/deny, caller restrictions, justification requirements |
| **Identity** | Entra ID / subscription keys | Ed25519 / SPIFFE cryptographic identity |
| **Trust model** | Binary (authenticated or not) | Continuous scoring (0-1000) with automatic credential revocation |
| **Audit** | APIM request logs | Hash-chain tamper-evident governance events |

Together, they provide defense-in-depth: Citadel enforces coarse-grained rules at the perimeter, AGT enforces fine-grained rules at the agent. Both must pass for an action to proceed.

---

## How AGT Maps to Citadel's 4 Layers

AGT is not confined to a single Citadel layer. It provides capabilities that complement each layer:

### Layer 1: Governance Hub

[Citadel Access Contracts](../bicep/infra/citadel-access-contracts/README.md) can reference **AGT policy bundles** that are loaded into agent environments at deployment time. The gateway enforces infrastructure policies (rate limits, content safety, JWT validation). AGT enforces agent-level policies (action restrictions, justification requirements, caller ACLs) inside the runtime.

**Policy precedence:** Gateway rules are evaluated first (at the network boundary). AGT rules are evaluated second (inside the agent process). Both must allow an action for it to proceed. This means a denied action at either layer is blocked, regardless of the other layer's decision.

> [!NOTE]
> Access Contract-based policy injection is a reference pattern. Today, policy bundles are loaded by the agent application at startup (from file, Key Vault, or URL). Full declarative contract binding is a planned enhancement.

### Layer 2: AI Control Plane

AGT exports governance telemetry (policy decisions, trust score changes, action interceptions) to Azure Event Hub and Application Insights via the `CitadelAuditExporter`. These events include **correlation IDs** linking AGT decisions to APIM request traces and Foundry execution traces, enabling unified observability dashboards.

The `apim_request_id` correlation field comes from the APIM response header (`x-ms-request-id`), which the agent captures and includes in its governance events.

### Layer 3: Agent Identity

[Entra ID / Agent 365](https://learn.microsoft.com/en-us/entra/id-governance/agent-id-governance-overview) remains the authoritative source for enterprise agent identity. AGT's Ed25519/SPIFFE identities handle runtime cryptographic credentials for agent-to-agent trust. The integration is **attestation-based federation**: AGT trust scores surface as risk labels in telemetry, not as primary Entra metadata. The `EntraIdentityBridge` binds AGT agent identities to Entra object IDs without write-back.

### Layer 4: Security Fabric

AGT's `data_classification` policy labels align with [Purview sensitivity labels](https://learn.microsoft.com/en-us/purview/sensitivity-labels). AGT trust scores can surface as risk signals in Defender for AI through the Event Hub telemetry pipeline.

---

## Integration Architecture

```
Agent Runtime (Spoke)                Citadel Hub                    Azure Monitor
┌──────────────────────┐            ┌──────────────────┐          ┌──────────────┐
│                      │            │                  │          │              │
│  Agent Application   │   LLM     │  APIM Gateway    │          │  App Insights│
│  ┌────────────────┐  │  request  │  ┌────────────┐  │          │              │
│  │ AGT Policy     ├──┼──────────►│  │ Rate Limit │──┼────►LLM  │  Event Hub   │
│  │ Engine         │  │           │  │ Content    │  │          │              │
│  │                │  │  response │  │ JWT Auth   │  │          │  Log         │
│  │ allow/deny     │◄─┼──────────┼──│ Cost Attr  │  │          │  Analytics   │
│  └──────┬─────────┘  │  (incl.  │  └────────────┘  │          └──────┬───────┘
│         │            │  x-ms-   │                   │                 │
│         │            │  request- │                   │                 │
│  ┌──────▼─────────┐  │  id)     ├──────────────────┐│                 │
│  │ Citadel Audit  ├──┼─────────►│  Event Hub /     │├─────────────────┘
│  │ Exporter       │  │  events  │  App Insights    ││
│  │ (correlation)  │  │  with    └──────────────────┘│
│  └────────────────┘  │  corr ID                     │
└──────────────────────┘                              │
```

**Data flow:**
1. Agent receives a task and evaluates it against the AGT policy engine (sub-millisecond).
2. If allowed, the agent sends the LLM request through the Citadel APIM gateway.
3. APIM applies gateway policies (rate limit, content safety, JWT validation) and returns the response with `x-ms-request-id`.
4. The agent captures the APIM request ID and includes it as a correlation field in the AGT governance event.
5. The `CitadelAuditExporter` batches and sends events to Event Hub / App Insights, preserving the hash-chain evidence from AGT's audit system.

---

## Getting Started

### Prerequisites

- A deployed [Citadel Governance Hub](./quick-deployment-guide.md) (or mock mode for local testing)
- Python 3.10+

### 1. Install AGT

```bash
# Core governance toolkit
pip install agent-governance-toolkit

# Azure integration (required for production; not needed for mock mode)
pip install azure-eventhub azure-monitor-opentelemetry-exporter azure-keyvault-secrets azure-identity
```

### 2. Configure the Citadel audit exporter

Set the following environment variables in your agent spoke:

```bash
# Required for audit export to Azure
export CITADEL_EVENTHUB_CONNECTION_STRING="Endpoint=sb://your-namespace.servicebus.windows.net/;..."
export CITADEL_APPINSIGHTS_CONNECTION_STRING="InstrumentationKey=your-key;IngestionEndpoint=..."

# Optional tuning
export CITADEL_EVENTHUB_NAME="agt-governance-events"    # Default: agt-governance-events
export CITADEL_EXPORT_BATCH_SIZE="50"                    # Default: 50
```

### 3. Load a policy bundle

AGT policy bundles define agent-level governance rules (which actions are allowed, which require justification, which are blocked). They can be loaded from a file, Azure Key Vault, or a URL:

```python
from agent_os.integrations.citadel import PolicyBundleResolver

resolver = PolicyBundleResolver()

# From a local file (development)
bundle = resolver.resolve_from_file("policies/agent-policy.yaml")

# From Key Vault (production)
bundle = resolver.resolve_from_keyvault(
    vault_url="https://myvault.vault.azure.net",
    secret_name="agt-policy-bundle-customer-support",
)
```

A policy bundle YAML looks like this:

```yaml
# policies/agent-policy.yaml
name: customer-support-policy
version: "1.0"
rules:
  - action: "query_customer_database"
    effect: allow
    conditions:
      caller_trust_score_min: 500
  - action: "delete_*"
    effect: deny
  - action: "*"
    effect: allow
```

### 4. Export governance events

```python
import asyncio
from agent_os.exporters import CitadelAuditExporter
from agent_os.exporters.citadel_exporter import (
    GovernanceEvent,
    GovernanceEventType,
    Decision,
    CorrelationContext,
)

exporter = CitadelAuditExporter.from_env()

event = GovernanceEvent(
    event_type=GovernanceEventType.POLICY_DECISION,
    agent_id="customer-support-agent-01",
    action="query_customer_database",
    decision=Decision.ALLOW,
    policy_name="customer-support-policy",
    trust_score=800,
    correlation=CorrelationContext(
        apim_request_id="abc-123",  # From APIM response header: x-ms-request-id
        agt_decision_id="def-456",
    ),
)

exporter.export_event(event)

# Flush sends buffered events to Event Hub / App Insights
asyncio.run(exporter.flush())
```

### 5. End-to-end example

For a complete working example with mock mode for local testing, see the [Citadel Governed Agent example](https://github.com/microsoft/agent-governance-toolkit/tree/main/examples/citadel-governed-agent) in the AGT repository.

```bash
# Local mode (no Azure required)
pip install agent-governance-toolkit
python examples/citadel-governed-agent/src/agent.py --mock

# With Citadel gateway
export CITADEL_GATEWAY_URL=https://your-apim.azure-api.net
export CITADEL_API_KEY=your-subscription-key
export CITADEL_EVENTHUB_CONNECTION_STRING=Endpoint=sb://...
python examples/citadel-governed-agent/src/agent.py
```

---

## Coverage Boundaries

Understanding what each system handles avoids duplication and clarifies where to configure each policy:

| Concern | Handled By |
|---------|-----------|
| LLM model access control | Citadel Layer 1 (APIM products/subscriptions) |
| Token rate limiting | Citadel Layer 1 (APIM policies) |
| Content safety filtering | Citadel Layer 1 (Azure Content Safety) |
| PII detection at gateway | Citadel Layer 1 (Azure Language Service) |
| Per-action policy evaluation | AGT Policy Engine |
| Tool call allow/deny | AGT Capability Model |
| Agent-to-agent trust | AGT Trust Layer (Ed25519, SPIFFE) |
| Trust scoring (0-1000) | AGT AgentMesh |
| Tamper-evident audit logs | AGT Audit System |
| Correlated fleet observability | Citadel Layer 2 + AGT Exporter |
| Agent enterprise identity | Citadel Layer 3 (Entra ID) |
| Threat detection | Citadel Layer 4 (Defender) |
| Data governance labels | Citadel Layer 4 (Purview) + AGT `data_classification` |

---

## Failure Modes

| Component Unavailable | Behavior |
|----------------------|----------|
| Azure Event Hub / App Insights | AGT continues operating normally. Events are buffered in memory and retried on the next flush cycle. Events are lost if the process exits before connectivity is restored. |
| Citadel APIM Gateway | Agent cannot reach LLM/tools through the gateway. AGT policy engine continues to evaluate actions locally. |
| AGT Policy Engine | Configurable: fail-open (actions proceed ungoverned) or fail-closed (all actions blocked). Default is fail-closed. |
| Key Vault (policy bundle source) | Agent cannot load or refresh policy bundles. The last successfully loaded bundle remains active. |

---

## Glossary

| Term | Definition |
|------|-----------|
| **Access Contract** | A Citadel deployment artifact that declares which AI services, models, tools, and agents a spoke environment can access, along with policy bindings. See [Access Contracts Guide](../bicep/infra/citadel-access-contracts/README.md). |
| **Policy Bundle** | A YAML file defining AGT governance rules (allow/deny per action, trust score requirements, caller restrictions). |
| **Trust Score** | A continuous value (0-1000) that AGT assigns to each agent based on behavior, policy compliance, and peer attestations. Scores below configurable thresholds trigger automatic credential revocation. |
| **SPIFFE** | [Secure Production Identity Framework for Everyone](https://spiffe.io/). AGT uses SPIFFE Verifiable Identity Documents (SVIDs) for runtime agent identity. |
| **Agent 365** | Microsoft's agent identity platform built on Entra ID. Provides enterprise-grade identity, lifecycle management, and access packages for AI agents. |
| **`data_classification`** | An AGT policy label that maps to Purview sensitivity labels, enabling data governance enforcement at the agent level. |

---

## References

- [Agent Governance Toolkit](https://github.com/microsoft/agent-governance-toolkit): Full documentation and source code
- [AGT + Citadel Integration Architecture](https://github.com/microsoft/agent-governance-toolkit/blob/main/docs/integrations/citadel-integration.md): Detailed architecture reference
- [End-to-End Example](https://github.com/microsoft/agent-governance-toolkit/tree/main/examples/citadel-governed-agent): Working example with mock mode for local testing
- [Foundry Citadel Platform](https://aka.ms/foundry-citadel): Full 4-layer architecture overview
- [AGT Quickstart](https://github.com/microsoft/agent-governance-toolkit/blob/main/docs/quickstart.md): Zero to governed agents in 10 minutes
