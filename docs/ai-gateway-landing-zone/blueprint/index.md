---
render_macros: false
---

# AI Citadel Blueprint

### Frontier, made executable — one governed platform for any agent, any data, any tool, any model

**Frontier Transformation is the destination. The AI Citadel Blueprint is how you get there.**

Frontier Transformation is Microsoft's strategy for how organizations move from experimenting with AI to transforming at enterprise scale — the *what* and the *why*. The AI Citadel Blueprint is the *how*: the opinionated technical implementation that carries that strategy into production, securely and at scale.

The promise of that *how* is **universality**. Regardless of the agent you build, the data you hold, the tools you need, or the models you choose, you get intelligence delivered through **one governed platform** — where **trust is everybody's responsibility**, layered by design.

!!! note
    AI Citadel Blueprint provides opinionated, pre-built patterns for AI governance that leverage Microsoft's unique capabilities and ecosystem while remaining **model-diverse, open, and supportive of heterogeneous environments**. It is not a one-size-fits-all solution — it is a proven architectural approach to adapt and extend based on your organizational structure, risk profile, and regulatory context.

    *Opinionated where it speeds you up — open everywhere it matters.*

---

## Table of Contents

**This document — the Overview**

- [The opportunity — and the wall](#the-opportunity-and-the-wall)
- [Frontier success framework: four pillars](#frontier-success-framework-four-pillars)
- [The Frontier transformation engine: Intelligence + Trust](#the-frontier-transformation-engine-intelligence-trust)
- [Citadel Blueprint: the four layers](#citadel-blueprint-the-four-layers)
- [Trust is everybody's responsibility](#trust-is-everybodys-responsibility)
- [Defense in depth: no single point of failure](#defense-in-depth-no-single-point-of-failure)
- [Layered observability: one estate, many lenses](#layered-observability-one-estate-many-lenses)
- [Every Frontier pillar, delivered](#every-frontier-pillar-delivered)
- [Measurable business impact](#measurable-business-impact)
- [Key resources](#key-resources-and-references)

**Companion guidance**

| Document | What it covers |
|----------|----------------|
| [Organizational Alignment & Ownership](organizational-alignment.md) | The operating model and the full RACI: who sets the standards, who runs the platform, who builds the agents |
| [Technical Activation Paths](activation-paths.md) | The four parallel tracks — deep dive → proof of value → production — plus what to provision, what to activate, and sizing |
| [Layer 1 · Governance Hub](layer-1-governance-hub.md) | The runtime enforcement plane — one governed front door across four dimensions |
| [Layer 2 · Agent Operations](layer-2-agent-operations.md) | The AI experience engine and its first line of trust |
| [Layer 3 · Agent Management](layer-3-agent-management.md) | Agents as owned, accountable enterprise and auditable assets |
| [Layer 4 · Security Foundation](layer-4-security-foundation.md) | Protect and detect beneath every agent across all layers |

---

## The opportunity — and the wall

**The ambition is proven. Execution is where it breaks.**

<table markdown="1">
<tr markdown="1">
<th align="left">🟣 THE OPPORTUNITY</th>
<th align="left">🔴 THE WALL</th>
</tr>
<tr valign="top" markdown="1">
<td markdown="block">

**88%** of Frontier Firms report strength in top-line growth — compared to just **23%** for laggards.

**2.3x** average ROI reported for agentic AI.

</td>
<td markdown="block">

**95%** of AI pilots never reach production — as agents scale, risk, integration, and cost compound exponentially.

**84%** of companies haven't redesigned work around AI capabilities.

</td>
</tr>
</table>

*Sources: Deloitte, State of AI in the Enterprise (Jan 2026); IDC InfoBrief sponsored by Microsoft (US53838325, Nov 2025); Microsoft (95% pilot figure).*

**Strategy sets the destination — something must carry it into production, securely and at scale.**

### Why scaling agents breaks current infrastructure

Early AI innovation feels fast — teams spin up agents quickly. But once organizations move beyond **50–100 agents**, things break. Not because the technology failed, but because **governance didn't scale**. Two things happen at once:

- **Shadow AI** emerges outside central control.
- **Operational friction** explodes as security and risk teams fall back on manual reviews.

The result is higher cost, less visibility, and loss of trust. This is the **production wall** — a structural problem, not a tooling problem.

### Traditional security is blind to agentic intent

When AI moves from *chatting* to *acting*, the threat model changes completely. Traditional security inspects packets, headers, and endpoints — but **it cannot understand intent**. Agents reason, plan, and take actions at machine speed, which introduces **semantic risk**: prompt injection, jailbreaks, unintended actions, and cascading failures.

Identity changes too. Agents are not users and they are not applications. They require **dynamic, policy-aware identities**, not static service accounts. Governance must understand **context, intent, and behavior in real time**.

> **The real question:** what must be true for an organization to scale from **10 agents to 10,000**, while staying grounded in **insight, control, and trust**?

**The answer: AI governance is the bridge to scale.** This is where governance stops being a blocker and becomes an enabler.

!!! tip
    **The proof.** In January 2026, Microsoft was named a **Leader** in the IDC MarketScape for Worldwide Unified AI Governance Platforms 2025–2026, recognized for end-to-end governance spanning traditional machine learning, generative AI, and agentic AI. But the real differentiator is not the analyst label — it is the ability to **execute governance at enterprise scale**.

---

## Frontier success framework: four pillars

Frontier Firms move beyond experimentation to enterprise-scale transformation — organized around four pillars of **business value**, not technology.

| # | Pillar | What it means |
|---|--------|---------------|
| **01** | **Enrich employee experiences** | Automate the routine so people do their best, most human work — with AI in the flow of work. |
| **02** | **Reinvent customer engagement** | Deliver personalized, responsive experiences at every touchpoint — grounded in your context. |
| **03** | **Reshape business processes** | Reimagine workflows end-to-end — not incremental fixes — with agents acting on the business. |
| **04** | **Bend the curve on innovation** | Put the power to build in every role, closest to the problem — and scale it enterprise-wide. |

Every one of these pillars is delivered by **the same platform** — just pointed at a different experience.

---

## The Frontier transformation engine: Intelligence + Trust

Frontier Transformation rests on two forces working together:

- **Intelligence** — deep business context: the agents that actually deliver the experience.
- **Trust** — security, governance, and control: what lets you move faster with confidence.

Citadel Blueprint is the **opinionated implementation** of that engine — layered, yet integrated, so rich intelligence and uncompromised trust ship together at the speed of innovation.

| | **Rich intelligence** | **Uncompromised trust** | **Undiminished speed** |
|---|---|---|---|
| | *Intelligence layer* | *Trust, shared* | *Speed of innovation* |
| | Any model, any agent type — SaaS, managed, BYO, 3rd-party | Agent-level: traces, evals, red-teaming, guardrails | Opinionated defaults, not a blank canvas |
| | Grounded in heterogeneous context (IQ) | Platform-level: Governance Hub, Agent Management | Controls live in the platform, not in every build |
| | Extended by your tools (MCP), agent-to-agent | Security Foundation protects & detects across the estate | New agents inherit trust on day one |

### The mapping that matters

Both forces map onto the blueprint — but **not the way people expect**:

- **Intelligence is surfaced through Agent Operations (Layer 2).** The agents that deliver the experience: any type, grounded in your data, using your tools, on any model.
- **Trust is not the job of a couple of security controls off to the side.** It starts *inside* Agent Operations — end-to-end traces, AI evaluations, red-teaming, and guardrails tuned to each agent's type and objective. That is **agent-level trust, and the builder owns it.**
- **Three platform controls then extend trust across the whole estate** — Governance Hub governs every call, Agent Management makes every agent accountable, and Security Foundation protects and detects.

> **The layer that delivers intelligence is also the first line of trust — then the platform controls make it hold at scale.**

---

## Citadel Blueprint: the four layers

These are not four disconnected point tools. They are four reinforcing layers that compound into one governed, defensible system for production AI.

| Layer | Name | Role | Built on | The advantage |
|-------|------|------|----------|---------------|
| 🔷 **L1** | [Governance Hub](layer-1-governance-hub.md) | Runtime enforcement plane — **govern every call** | Azure API Management · Azure API Center | **Govern once, enforce everywhere.** Policy set centrally applies to every model, tool, and agent — control scales *with* adoption instead of fighting it. |
| 🔶 **L2** | [Agent Operations](layer-2-agent-operations.md) | The AI experience engine **and its first line of trust** | Microsoft Foundry · Agent Service · Foundry IQ · Control Plane · Container Apps / AKS | **Ship agents faster, safely.** Templated landing zones and built-in guardrails turn months of setup into repeatable, observable deployments. **Foundry serves as runtime *and* as the observability plane for agents running anywhere.** |
| 🟢 **L3** | [Agent Management](layer-3-agent-management.md) | **The command center for every agent** — every agent owned | Microsoft Agent 365 · Entra Agent ID · Agent 365 SDK | **Every agent owned and accountable.** One registry, one identity model, one audit trail — spanning SaaS, managed runtime, BYO, and third-party agents. **Identity is the connective tissue that lights up Layer 4.** |
| 🛡️ **L4** | [Security Foundation](layer-4-security-foundation.md) | Unified protection across all layers — **protect & detect** | Microsoft Defender · Microsoft Purview · Microsoft Entra | **Security & compliance, built in.** Continuous threat protection, data governance, and access control beneath every layer. |

```
┌──────────────────────────────────────────────────────────────────────────┐
│  THE EXPERIENCES · FRONTIER PILLARS                                      │
│  Enrich employees │ Reinvent customers │ Reshape process │ Bend the curve│
├──────────────────────────────────────────────────────────────────────────┤
│  L2 · AGENT OPERATIONS — one layer, two jobs                             │
│                                                                          │
│  DELIVERS THE EXPERIENCE                                                 │
│    Mixed agent types · Context (IQ) · Tools (MCP) · Collaboration        │
│                                                                          │
│  AGENT-LEVEL TRUST — BUILT IN                                            │
│    Traces · Evals · Red-teaming · Guardrails                             │
├──────────────────────────────────────────────────────────────────────────┤
│  PLATFORM TRUST — spans every pillar & every agent                       │
│    L1 Governance Hub  — govern every call                                │
│    L3 Agent Management — every agent owned                               │
│    L4 Security Foundation — protect & detect                             │
└──────────────────────────────────────────────────────────────────────────┘
```

**Regardless of the agent, data, tools, or models — trust is shared: agent-level in Agent Operations, platform-level across the controls.**

### Separation of concerns with unified oversight

Each layer owns a distinct governance responsibility, yet all layers interlock. This layered separation means teams can evolve any single capability — upgrade the gateway, add new compliance evaluators, onboard new agent types, adopt emerging detections — **without destabilizing the rest of the stack**. The result is an architecture that scales from 10 to 10,000 agents while keeping governance both comprehensive and composable.

The Governance Hub and the Agent Operations spokes are deployed **hub-and-spoke**: a centrally managed gateway enforces runtime policy while each business unit gets an autonomous environment to build in. **Governance stays centralized; execution scales horizontally.** In short — **local freedom, global rules**.

---

## Trust is everybody's responsibility

Trust isn't one team's job — it's layered across **four interconnected controls that are complementary, not sequential**. Note the ownership line under each; this is the heart of the model.

| Control | Scope | What it delivers | **Owned by** |
|---------|-------|------------------|--------------|
| 🔶 **Agent Operations** | **Agent-level** | End-to-end traces, AI evals, red-teaming & guardrails — tuned to each agent's type and objective | **The agent builder** |
| 🔷 **Governance Hub** | **Platform · Govern** | Every model, tool & agent call flows through one governed gateway — routing, policy, content safety, capacity & observability | **The AI CoE & platform team** |
| 🟢 **Agent Management** | **Platform · Identify** | Every agent is an owned enterprise asset — a first-class identity, sponsor, lifecycle & audit trail, **whoever built it and wherever it runs** | **IAM & security** |
| 🛡️ **Security Foundation** | **Platform · Protect** | Defender, Purview & Entra deliver threat protection, data governance & access beneath every agent | **The security org** |

**Trust starts inside the agent and extends across the platform — from 10 to 10,000 agents.**

➡️ Full operating model and RACI: **[Organizational Alignment & Ownership](organizational-alignment.md)**

### Agent Management is the command center — and the connective tissue

One layer deserves a closer look, because it is the most under-scoped in practice and the highest-leverage in effect.

> **Microsoft Agent 365 is not the control plane for *Microsoft* agents. It is the control plane for *every* agent.**

| Agent type | How it lands in Agent 365 |
|------------|---------------------------|
| **SaaS** — Microsoft 365 Copilot, Copilot Studio | Native — automatic identity and registry entry |
| **Managed runtime** — Microsoft Foundry Agent Service | Native — identity per project and per published agent |
| **Platform / BYO** — your framework on AKS, ACA, Agent Framework | Register via workload identity + the **Agent 365 SDK** |
| **Third-party & on-prem** — partner and non-Microsoft runtimes | Federate via the **Agent 365 SDK**, which a broad partner ecosystem already integrates with |

**One registry. One identity model. One policy surface. One audit trail.** Organised around three pillars — **Observe** (registry, agent map, analytics), **Govern** (onboarding, lifecycle, audit, data compliance), and **Secure** (access control, data security, threat protection).

It earns the "command center" name in two ways:

1. **It attributes traffic to an agent.** Most AI calls reach models via proxies or gateways, **losing the calling identity in the process**. Without this layer you can see that *something* called a model — not *which agent*, *on whose behalf*, *under what approval*, or *with what data*.
2. **It aggregates signals from the whole stack.** Agent 365 consolidates **Entra, Defender, and Purview** insights — alongside gateway audit logs and Foundry traces — into one agent-centric control plane with **detailed logs for audit and triage**.

> **The governing principle:** the best way to manage agents is to **extend the infrastructure you already use to manage users**. Same Entra, same Purview, same Defender, same admin center — agents simply become another identity type.

➡️ Full detail: **[Layer 3 · Agent Management](layer-3-agent-management.md)**

---

## Defense in depth: no single point of failure

**One control is never enough — enforce critical guardrails in more than one place.**

Standard security practice: never depend on a single layer. If it's bypassed or simply can't apply, the system is exposed. Citadel's controls **deliberately overlap**, so coverage holds however an agent is built or hosted.

**Worked example — content safety is enforceable at three controls:**

| Control | Where it applies |
|---------|------------------|
| 🔷 **Governance Hub** | At the AI gateway and at Foundry-hosted models |
| 🔶 **Agent Operations** | In Foundry — Agent Service runtime & control-plane guardrails |
| 🛡️ **Security Foundation** | Microsoft Defender (Defender for AI) monitoring across the estate |

**When one control can't apply, another holds the line:**

| Scenario | What breaks | What holds |
|----------|-------------|-----------|
| **Agent runs outside Foundry** — a self-hosted model on a GPU VM | Agent Operations & Security Foundation can't apply out of the box | ➡️ **Governance Hub enforces it at the gateway**, because that traffic still flows through the gateway as mediator between agent and model |
| **Microsoft Copilot agents** — traffic doesn't traverse your gateway or Foundry | Governance Hub & Agent Operations can't apply out of the box | ➡️ **Agent Management (Agent 365) and Security Foundation (Defender) enforce it** — on top of Copilot's native protections |

**Same risk, multiple enforcement points — if one control can't apply or is bypassed, another does.**

---

## Layered observability: one estate, many lenses

The same telemetry, surfaced for the people who act on it. Redundancy isn't waste — it's the right **altitude** for each audience, and **each lens ends in an action**.

<table markdown="1">
<tr markdown="1">
<th align="left" width="50%">🟣 CENTRAL IT, FinOps &amp; SECURITY<br/><sub>See the whole estate</sub></th>
<th align="left" width="50%">🔵 AGENT OWNERS &amp; BUILDERS<br/><sub>See their own agents</sub></th>
</tr>
<tr valign="top" markdown="1">
<td markdown="block">

**Agent 365 dashboard** — organization-wide view of every agent: security signals, access patterns, usage and activation.

**Governance Hub performance, usage & chargeback** — organization-wide, via the AI Gateway, surfaced through Power BI–powered dashboards.

**Act on it**

- Assign capacity controls and quotas
- Govern model access with RBAC — Governance Hub
- Suspend rogue agents — block in Agent 365 or revoke the access contract
- Alert on critical events — backend, authorization, content-safety, PII failures

</td>
<td markdown="block">

**Foundry Observability** — end-to-end performance, traces, evals and quality signals per agent.

**Foundry usage & cost** — per-agent consumption for the team that owns it.

**Act on it**

- Apply capacity controls to their own agents
- **Agent Optimizer** — learns from agent behavior and recommends better configurations: sharper instructions, skills and tool descriptions, and model selection

</td>
</tr>
</table>

**Same signals, different altitude — everyone sees what they need to act on, nobody flies blind.**

---

## Every Frontier pillar, delivered

One experience engine, four experiences. The **trust controls are identical in every row** — that's the point: they don't change with the agent type.

| Pillar | The experience | Agent pattern | Public proof point |
|--------|----------------|---------------|--------------------|
| **01 · Enrich employee experiences** | Copilot — and pro-code agents in the flow of work. Low-code SaaS agents get every maker started; then publish pro-code Foundry agents straight into Microsoft 365, bringing specialist depth into the same employee experience. | **Copilot Studio (SaaS) + Foundry Agents published to Microsoft 365** | **Children International** — cut solution development from 3 months to 2 days; on track to grow direct child interventions 25% in four years with no budget increase. |
| **02 · Reinvent customer engagement** | Customer-facing agents that act — grounded in your product and customer IQ, using MCP tools to act in real systems, at scale, without running the infrastructure. | **Managed runtime — Microsoft Foundry Agent Service** | **Alaska Airlines** — embedded AI into service workflows: 75% less customer planning time, 90% guest satisfaction, 87% would use it again. |
| **03 · Reshape business processes** | Autonomous, collaborating agents. Redesign the workflow, don't just speed it up — bring your own framework on Azure managed compute and let multiple agents collaborate on the state of the business, within clear boundaries. | **Managed compute (BYO) on AKS / ACA + multi-agent collaboration** | **Levi's** — work once estimated at up to a year completed in a single day; a 97% productivity gain. |
| **04 · Bend the curve on innovation** | A maker in every role. Innovation stalls when only specialists can build — give every role the full range of agent types on one platform, with shared IQ, tools, and templates. | **The full mix — SaaS + Foundry + BYO + 3rd-party/on-prem, any model** | **Accenture** — centralized enterprise AI platform: build time down 50%, efficiency up 30%, costs down 20%; 17 use cases shipped in 4 months. |

### Agent Operations: runtime *and* observability & control plane

A second layer worth calling out, because the distinction unlocks adoption for customers who cannot re-platform.

**Microsoft Foundry plays two independent roles — adopt either, or both:**

| Role | What it means |
|------|---------------|
| **① Runtime** | Host agents in Foundry — **prompt agents** and **hosted agents** (your own container and framework). They **automatically inherit every Foundry capability**: tracing, evaluations, guardrails, identity, IQ grounding, MCP tools, and fleet operations. |
| **② Observability plane for agents running elsewhere** | Agents on **AKS, Azure Container Apps, other clouds, or on-premises** forward **OpenTelemetry GenAI semantic traces** into Foundry-connected Application Insights — and light up in the **same** plane for centralized traces, AI evaluations, quality and safety signals, and fleet operations, **without being hosted in Foundry at all**. |

This **decouples the hosting decision from the governance decision**. There is no forced choice between "adopt Foundry as a runtime" and "no Foundry at all" — estate-wide observability is adoptable on its own, and it is often the faster route to visibility across a heterogeneous estate.

> **The managed runtime is a convenience; the observability is the strategic value.**

➡️ Full detail: **[Layer 2 · Agent Operations](layer-2-agent-operations.md)**

---

## Measurable business impact

| Outcome | What it looks like |
|---------|--------------------|
| 🚀 **Faster time-to-value** | Pre-built patterns and templated landing zones turn months of build-out into days |
| 🛡️ **Reduced risk** | Compliance is woven in from the start, not bolted on — agents operate within safe boundaries from day one |
| 💰 **Cost control** | Granular usage tracking, quotas, and per-consumer chargeback — no surprise invoices |
| 📈 **Scalable adoption** | When one team succeeds, others follow the same blueprint instead of reinventing the wheel |
| 🤝 **Cross-functional alignment** | Compliance officers and AI developers work from the same explicit, automated requirements |
| 🔁 **Unified AI ecosystem & reuse** | All shared models, tools, and agents reachable through one gateway and listed in one registry — more reuse, less duplication |

### Future-proofing

- 🔌 **Protocol-agnostic** — REST, MCP, A2A, and emerging protocols
- ☁️ **Multi-cloud and hybrid capable** — one control plane, data plane everywhere
- 🧩 **Extensible** — partner integrations (Credo AI, Saidot, Palo Alto Networks, Zenity) enhance capabilities
- 📜 **Regulatory alignment** — with layered controls in place, mapping new regulatory requirements to technical controls becomes straightforward

---

## The bottom line

**Frontier is the destination. The AI Citadel Blueprint is how you get there — any agent, at scale.**

It reduces to two ideas:

1. **One experience engine.** Agent Operations delivers every experience — any agent, grounded in your data, using your tools, on any model.
2. **Shared trust.** It starts inside the agent with traces, evals, red-teaming, and guardrails, and extends across the platform through Governance Hub, Agent Management, and Security Foundation — **layered deliberately, so no single control is a single point of failure.**

That is what lets you scale from ten agents to ten thousand **without trading away cost control, identity, data protection, or compliance**. And it isn't theoretical for Microsoft — we are Customer Zero.

> 💡 **Those that can trust will scale. Those that scale AI effectively will win.**

---

## Key resources and references

**Citadel Blueprint**

- 🏛️ Citadel Governance Hub Landing Zone (central deployment): [AI Gateway Landing Zone](../index.md)
- 🧱 Citadel Agents Operations Landing Zone (spoke deployments): [Agent Landing Zone](../../agent-landing-zone/index.md)
- 🎯 Agent Management (Agent 365): <https://www.microsoft.com/en-us/microsoft-agent-365>
- 🛡️ Citadel Security Foundation Landing Zone: <https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-threat-protection>

**Microsoft Learn**

- AI Gateway capabilities in Azure API Management: <https://learn.microsoft.com/azure/api-management/genai-gateway-capabilities>
- Microsoft Foundry Control Plane overview: <https://learn.microsoft.com/azure/ai-foundry/control-plane/overview>
- Governing agent identities with Entra ID: <https://learn.microsoft.com/entra/id-governance/agent-id-governance-overview>
- AI threat protection in Microsoft Defender for Cloud: <https://learn.microsoft.com/azure/defender-for-cloud/ai-threat-protection>

**Build**

- Microsoft Agent Framework: <https://aka.ms/AgentFramework>
- [Azure AI Landing Zones](../../index.md)
- AI Hub Gateway solution accelerator: <https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator>

**Recognition & references**

- Microsoft named a Leader in the IDC MarketScape for Unified AI Governance Platforms: <https://www.microsoft.com/en-us/security/blog/2026/01/14/microsoft-named-a-leader-in-idc-marketscape-for-unified-ai-governance-platforms/>
- Azure API Management — unified AI gateway design pattern: <https://techcommunity.microsoft.com/blog/integrationsonazureblog/azure-api-management---unified-ai-gateway-design-pattern/4495436>
- Discovery Bank customer story: <https://www.microsoft.com/en/customers/story/26157-discovery-bank-azure-openai-in-foundry-models>

---

<sub>AI Citadel Blueprint × Frontier Transformation · Microsoft · Global Black Belt</sub>
