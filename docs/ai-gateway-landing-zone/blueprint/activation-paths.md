---
render_macros: false
---

# Technical Activation Paths

### From strategy to scale — four parallel tracks to production

[⬅️ Back to Overview](index.md)

---

## Table of Contents

- [One continuous journey](#one-continuous-journey)
- [Activation path across the four layers](#activation-path-across-the-four-layers)
- [Infrastructure vs. activation layers](#infrastructure-vs-activation-layers)
- [Four parallel tracks to production](#four-parallel-tracks-to-production)
- [Track 1 · Governance Hub](#track-1-governance-hub)
- [Track 2 · Agent Operations](#track-2-agent-operations)
- [Track 3 · Agent Management](#track-3-agent-management)
- [Track 4 · Security Foundation](#track-4-security-foundation)
- [Convergence](#convergence)
- [Deployment approach: hub-and-spoke for scale](#deployment-approach-hub-and-spoke-for-scale)
- [Sizing guidance](#sizing-guidance)
- [Where to start](#where-to-start)

---

## One continuous journey

The strategy and the implementation are **one journey with three moves**.

| | Phase | What happens |
|---|-------|--------------|
| **01** | 🟣 **STRATEGY — Frontier Vision Conversation** | Identify goals, priorities, and where AI creates the most value across the business — every room of the house. |
| **02** | 🔵 **IMPLEMENTATION — Citadel Activation** | Stand up the experience engine (Agent Operations) and the trust controls — Governance Hub, Agent Management, Security Foundation — each via **Deep Dive → Proof of Value → Production**. |
| **03** | 🟢 **SCALE — Converge & Operate** | Converge into one production rollout and operating model — target model, rollout waves, success metrics — run by your **AI CoE**. |

**Outcome:** a single, actionable path — from the strategy conversation to agentic AI in production, securely and at enterprise velocity.

---

## Activation path across the four layers

Not every layer is provisioned the same way. Two layers are **infrastructure** you deploy; two are **activations** you turn on.

### Layer 1 · AI Governance Hub — *Provision Infrastructure*

**AI Hub Gateway Landing Zone** — [AI Gateway Landing Zone](../index.md)

- Deployed **centrally** — governs production and non-production
- Unified AI Gateway, model catalog, universal registry
- **Links to Layer 4:** ships signals to Defender · uses Entra for authentication & authorization

### Layer 2 · Agent Operations — *Provision Infrastructure*

**Foundry Landing Zone / Copilot Studio** — [Agent Landing Zone](../../agent-landing-zone/index.md)

- Deployed **at a spoke** — one per business unit or use case
- Templated, configurable deployment to scale
- **Links to Layer 4:** registers identity in Entra · signals to Defender · Purview for data tools

### Layer 3 · Agent Management — *Activate — no infra to provision*

**Microsoft Agent 365** — agent management blueprints

- Activate Agent 365 — **no landing zone required**
- Create and govern agent identity blueprints, plus overall agent management
- **Links to Layer 4:** consolidates Entra · Defender · Purview insights into a unified Agent 365 dashboard

### Layer 4 · Security Foundation — *Activate across every layer*

| Component | Contribution |
|-----------|--------------|
| **Defender** | Threat signals & AI security posture |
| **Purview** | Data governance & compliance |
| **Entra** | Agent identity & access |

### The connective mechanics

| Mechanism | Direction | Purpose |
|-----------|-----------|---------|
| **Backend Contracts** | Southbound | Onboard a model backend from Azure, on-premises, or hybrid — once, then reuse |
| **Access Contracts** | Northbound | Onboard a consuming use case with the assets, limits, and policies it's allowed |
| **Publish Contracts** | Spoke → Hub | Publish a spoke's agents/tools into the governed registry |
| **Register Agent ID** | Spoke → L3 | Give the agent an Entra Agent ID so Layer 4 lights up |

---

## Infrastructure vs. activation layers

| Layer | Type | What it means for planning |
|-------|------|---------------------------|
| 🔷 **L1 · Governance Hub** | **Infrastructure** | Azure resources to design, deploy, size, and operate. Owned by Platform Engineering. |
| 🔶 **L2 · Agent Operations** | **Infrastructure** *(runtime)* **+ Activation** *(observability)* | Landing zones per spoke, plus dependent services (AI Search, databases) when Foundry is the **runtime**. When adopted purely as the **observability plane** for agents running elsewhere, the work is instrumentation and an Application Insights connection — no runtime landing zone required. Sizing varies heavily by agent type and consumption. |
| 🟢 **L3 · Agent Management** | **Activation** | No landing zone. Licensing-based — align with the Security team for assessment. |
| 🛡️ **L4 · Security Foundation** | **Activation** | Turn on across every layer. Defender for AI pricing is driven by estimated input/output tokens. |

---

## Four parallel tracks to production

To move from strategy to scale, progress along **four parallel tracks — coordinated, but able to advance independently**. Every track follows the same rhythm:

```
   Deep Dive Workshop  →  Proof of Value  →  Production Adoption  ─┐
                                                                   ├─→  CONVERGE
   (× 4 tracks, running in parallel)                              ─┘
```

| | Track | Deep Dive Workshop | Proof of Value | Production Adoption |
|---|-------|--------------------|----------------|---------------------|
| 🔷 | **L1 · Governance Hub** | **Governance Hub (AI Gateway)** — align AI Hub Gateway & enforcement requirements | **Unified Access PoV** — validate policy across models, tools & agents | **Central Governance** — standardize onboarding; operationalize org-wide |
| 🔶 | **L2 · Agent Operations** | **Microsoft Foundry** — Control Plane for rapid agent development | **Build & Iterate PoV** — onboard agents with guardrails & quality signals | **Fleet Operations** — observability & evaluations at scale |
| 🟢 | **L3 · Agent Management** | **Microsoft Agent 365** — agent management, ownership & lifecycle | **Govern Agents PoV** — register, activate & monitor real agents | **Scale Identities** — safe & consistent across the organization |
| 🛡️ | **L4 · Security Foundation** | **Defender & Purview** — threat models, data governance & compliance mapping | **Controls in Action PoV** — detection, classification & compliance evidence | **Unified Posture** — measurable security & compliance |

---

## Track 1 · Governance Hub

**Establish a strong runtime foundation.**

| Stage | Activity |
|-------|----------|
| **Deep Dive** | Deep dive into the Citadel Governance Hub and the AI Hub Gateway; align on enforcement requirements — approved models, capacity rules, content-safety posture, PII handling, audit expectations. |
| **Proof of Value** | Validate **unified access** to models, tools, and agents under one consistent policy. Prove that a single access contract enforces auth, rate limits, content safety, and PII processing on every call. |
| **Production** | Standardize onboarding and operationalize central governance across environments and teams — backend contracts for every model source, access contracts for every consuming use case. |

**Deploy:** AI Hub Gateway Landing Zone — [AI Gateway Landing Zone](../index.md)
**Accelerator:** <https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator>

**Accountable owners:** AI CoE *(standards)* · Platform Engineering *(gateway infra)* · FinOps *(capacity & cost attribution)*

**Exit criteria**

- [ ] One (or two) gateway deployments live, governing production and non-production
- [ ] Backend contracts registered for every approved model source (Azure, on-prem, other clouds)
- [ ] Access contracts defined per consuming use case, with auth, limits, and safety policy bundled
- [ ] Universal AI catalog populated in Azure API Center — models, tools, agents, skills
- [ ] Performance, usage, and chargeback dashboards live and attributed per consumer
- [ ] Audit logs streaming to Defender / Sentinel

➡️ [Layer 1 · Governance Hub in detail](layer-1-governance-hub.md)

---

## Track 2 · Agent Operations

**Speed without sacrificing control.**

| Stage | Activity |
|-------|----------|
| **Deep Dive** | Deep dive into Microsoft Foundry and the Foundry Control Plane for rapid agent development, observability, evaluations, and fleet-wide operations. |
| **Proof of Value** | Show how teams **build, onboard, and iterate on agents quickly** while maintaining guardrails, quality signals, and production readiness. |
| **Production** | Scale to **fleet-wide operations** with full observability and continuous evaluations across the estate. |

**Deploy:** Foundry Landing Zone — [Agent Landing Zone](../../agent-landing-zone/index.md) — one spoke per business unit or use case.

!!! tip
    **This track has two independent adoption paths — run either, or both.**

    **Path A — Foundry as runtime.** Start with **prompt agents** or **hosted agents** (your own container and framework). Controls are inherited automatically: tracing, evaluations, guardrails, identity, IQ grounding, MCP tools. You configure only the gateway connection.

    **Path B — Foundry as the observability plane.** Keep agents where they run today — **AKS, Azure Container Apps, other clouds, on-premises, Copilot Studio, third-party runtimes** — and instrument them with **OpenTelemetry GenAI semantic conventions** exporting to **Foundry-connected Application Insights**. They land in the same plane for centralized traces, AI evaluations, and fleet visibility **without re-platforming a single agent**.

    Path B is often the **faster route to estate-wide visibility**, and it decouples the hosting decision from the governance decision. See [Layer 2 · Agent Operations](layer-2-agent-operations.md).

**Accountable owners:** AI CoE *(runtime & tooling approval)* · Platform Engineering *(runtime infra)* · AI Engineering *(build & operate)* · LOB *(business value)*

**Exit criteria**

- [ ] At least one spoke landing zone deployed from template
- [ ] Application Insights connected; end-to-end tracing live for the pilot agents
- [ ] Agent-specific evaluators running pre-ship and continuously in production
- [ ] AI Red Teaming Agent scan completed with a scorecard
- [ ] Guardrails configured at the right lifecycle points — inputs, tool calls, tool responses, outputs
- [ ] **Non-Foundry agents emitting `gen_ai.*` OTel spans into the same observability plane** (Path B)
- [ ] Evaluation GitHub Action / Azure DevOps extension wired into CI with baseline variant comparison
- [ ] Monitoring dashboard live; **KQL-derived alert rules** defined with agreed thresholds and routing
- [ ] Fleet dashboard showing health, performance, cost, and compliance for registered agents

➡️ [Layer 2 · Agent Operations in detail](layer-2-agent-operations.md)

---

## Track 3 · Agent Management

**Treat agents as enterprise assets.**

| Stage | Activity |
|-------|----------|
| **Deep Dive** | Using Microsoft Agent 365, establish agent management, ownership, and lifecycle — and design the **agent identity blueprints**. |
| **Proof of Value** | **Register, activate, monitor, and retire real agents** — proving visibility and control end to end. |
| **Production** | Scale agent identities **safely and consistently** across the organization. |

**Activate:** Microsoft Agent 365 — **no landing zone required**.

**Accountable owners:** IAM *(identity, lifecycle & inventory)* · AI Engineering *(register & own)* · Security *(behavioural insight)*

**Exit criteria**

- [ ] Agent 365 activated and the agent identity blueprint defined
- [ ] Every published agent carries a unique Entra Agent ID with a **named human or team owner**
- [ ] Shadow-agent detection running; discovered agents triaged
- [ ] Lifecycle workflows in place — provision, change scope, decommission, access review and expiry
- [ ] Authoritative agent inventory visible in the Agent 365 dashboard
- [ ] Revocation tested — a rogue agent can be blocked in Agent 365 or have its access contract revoked

➡️ [Layer 3 · Agent Management in detail](layer-3-agent-management.md)

---

## Track 4 · Security Foundation

**Embed security and compliance by default.**

| Stage | Activity |
|-------|----------|
| **Deep Dive** | With Defender and Purview, map **threat models, data governance, and regulatory requirements**. |
| **Proof of Value** | Demonstrate real controls in action — **threat detection, data classification, and compliance evidence** — so security is operational and measurable, not theoretical. |
| **Production** | Arrive at a **unified, measurable security posture** across the estate. |

**Activate:** Defender for AI / Cloud · Microsoft Purview · Microsoft Entra — across every layer.

**Accountable owners:** SecOps *(posture & threat)* · DPO *(data security)* · GRC *(compliance & evidence)* — all under the CISO.

!!! warning
    For **banking and government** accounts, the DPO and GRC are **gatekeepers, not stakeholders** — no production AI reaches users without their sign-off. Engage them at deep-dive stage, not at the finish line.

**Exit criteria**

- [ ] Defender for AI enabled; posture recommendations and attack-path analysis reviewed
- [ ] Purview sensitivity labels applied to AI-reachable data; agent activity flowing into Purview audit
- [ ] Entra conditional access and least-privilege policies applied to agent identities
- [ ] Gateway audit logs and Foundry traces feeding SIEM/XDR
- [ ] Compliance evidence pack assembled and mapped to the applicable regime (e.g. EU AI Act)
- [ ] Regulated-account sign-off from DPO and GRC obtained

➡️ [Layer 4 · Security Foundation in detail](layer-4-security-foundation.md)

---

## Convergence

The four tracks come together in a **single production adoption workshop**.

| Converge on | Detail |
|-------------|--------|
| **Target operating model** | Who owns which layer in steady state — see [Organizational Alignment & Ownership](organizational-alignment.md) |
| **Rollout waves** | Which business units and use cases onboard in which order |
| **Success metrics** | Time-to-value, cost per use case, compliance coverage, fleet health, shadow-agent rate |

**Outcome:** a clear, actionable path to scale agentic AI — **securely, governably, and at enterprise velocity** — run by your AI Center of Excellence.

---

## Deployment approach: hub-and-spoke for scale

The architecture is intentionally designed around a **hub-and-spoke model**.

### AI Governance Hub — central deployment

> **AI Hub Gateway Landing Zone** — [AI Gateway Landing Zone](../index.md)

- Deployed **centrally**
- **One deployment** governing both production and non-production, **or two** (one production, one non-production) — more can be added per requirements
- Hosts the **unified AI Gateway**, the **model and tool registry**, **centralized logging and monitoring**, and **policy enforcement**
- Enforces runtime policies-as-code for all AI interactions across the organization
- Platform-level observability and audit trail: centralized performance metrics, usage tracking, with optional request/response logging

### Agents Environment — spoke deployment

> **Foundry Landing Zone** — [Agent Landing Zone](../../agent-landing-zone/index.md)

- Deployed **at a spoke**, with **many deployments** across the organization
- **One deployment per business unit or use case**
- Fully self-contained and secure, with dedicated compute, storage, data, and dependent services
- Teams work **autonomously** without stepping on each other's toes
- Accelerates development through **templated deployment that is configurable**
- Each spoke connects back to the hub for centralized governance and observability

**Every AI workload — whether an agent, a tool, or a model call — connects back to the hub to access centrally protected AI assets.**

> **Governance stays centralized, while execution scales horizontally.** That is how organizations grow from a handful of use cases to hundreds or thousands of agents with full visibility, consistent control, and no loss of trust.
>
> In short: **local freedom, global rules.**

---

## Sizing guidance

Citadel positions four layers: **two are infrastructure layers, two are activation layers.** Suggested sizing approach:

| Layer | Type | Sizing driver | Guidance |
|-------|------|---------------|----------|
| 🔷 **L1 · Governance Hub** (via APIM) | **Infrastructure** | Gateway throughput and tier | T-shirt sizing guide: [AI Citadel Governance Hub sizing guide](../plan/sizing-guide.md) |
| 🔶 **L2 · Agent Operations** (via Foundry) | **Infrastructure** | **Agent type, dependent services** (AI Search, databases), and **active consumption** — an agent serving 20 internal users is very different from one serving 2M external users | [Cost Guide — Azure AI Landing Zones](../../architecture/cost-guide.md) |
| 🟢 **L3 · Agent Management** (via Agent 365) | **Activation** | **License per user per month** — no per-agent or per-agent-instance licensing. **Strongly recommend alignment with the Security team** for customer assessment and sizing. | Microsoft Agent 365 field FAQ *(Microsoft internal)* |
| 🛡️ **L4 · Security Foundation** (Defender for AI, Purview, Entra) | **Activation** | **Defender for AI** relies on estimated input/output tokens (usually a fixed price for each) | [AI threat protection in Microsoft Defender for Cloud](https://learn.microsoft.com/azure/defender-for-cloud/ai-threat-protection) |

!!! note
    Layer 2 sizing carries the widest variance of the four. Model it per-use-case rather than estate-wide, and revisit it after the Build & Iterate PoV when real consumption data exists.

---

## Where to start

**A strong place to begin the journey is Layer 1 (the runtime Governance Hub) together with Layer 2 (Agent Operations).** These two layers establish the foundation required to scale AI safely and consistently.

That said, the sequencing advice from the operating model still applies:

1. **Start where you're strongest.** Find the single layer where you're furthest ahead — that's your beachhead. The other three become your expansion path.
2. **Run the tracks in parallel, not in series.** They are coordinated but independent; serializing them costs months for no risk reduction.
3. **Don't defer Layer 3.** Identity is the hinge that lights up Layer 4 — it is the most under-scoped layer in most conversations, and the shadow-agent gap opens quietly.
4. **Engage Security early.** In regulated industries they are gatekeepers, and late engagement means late rejection.

| If the customer… | Start with |
|------------------|-----------|
| Has AI sprawl, no cost attribution, teams holding raw provider keys | **Track 1 — Governance Hub** |
| Has motivated builders but no sanctioned runtime or observability | **Track 2 — Agent Operations** |
| Already has agents in production but can't answer "who owns this one?" | **Track 3 — Agent Management** |
| Is in a regulated industry and blocked on security/compliance sign-off | **Track 4 — Security Foundation** |

---

## Related guidance

- [Overview — AI Citadel Blueprint](index.md)
- [Organizational Alignment & Ownership](organizational-alignment.md) — who runs each track
- [Layer 1 · Governance Hub](layer-1-governance-hub.md)
- [Layer 2 · Agent Operations](layer-2-agent-operations.md)
- [Layer 3 · Agent Management](layer-3-agent-management.md)
- [Layer 4 · Security Foundation](layer-4-security-foundation.md)

**Deployment resources**

- Citadel end-to-end guidance: [AI Citadel Blueprint overview](index.md)
- AI Hub Gateway Landing Zone: [AI Gateway Landing Zone](../index.md)
- AI Hub Gateway solution accelerator: <https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator>
- [Azure AI Landing Zones](../../index.md)

---

<sub>AI Citadel Blueprint × Frontier Transformation · Microsoft · Global Black Belt</sub>
