---
render_macros: false
---

# Organizational Alignment & Ownership

### Aligning your operating model to the four Citadel layers — with a clear Responsible / Accountable / Consulted / Informed ownership model

[⬅️ Back to Overview](index.md)

---

## Table of Contents

- [Why alignment decides the outcome](#why-alignment-decides-the-outcome)
- [The operating model: three build-and-run functions](#the-operating-model-three-build-and-run-functions)
- [Trust is everybody's responsibility](#trust-is-everybodys-responsibility)
- [Master RACI matrix](#master-raci-matrix)
- [Layer-by-layer ownership and outcomes](#layer-by-layer-ownership-and-outcomes)
- [The cross-layer convener](#the-cross-layer-convener)
- [Putting this into practice](#putting-this-into-practice)
- [Common anti-patterns](#common-anti-patterns)

---

## Why alignment decides the outcome

A blueprint only works if your organization is aligned behind it. The technology in Citadel is well understood — the failure mode is almost never the architecture. It is **three roles people habitually blur together**:

1. **Who sets the standards**
2. **Who runs the platform**
3. **Who builds the agents**

The single biggest predictor of a smooth rollout is **keeping those three functions distinct** and giving **every decision one clear accountable owner**.

!!! important
    **No single team owns all four Citadel layers — and that's the point.** Each layer has a *different* accountable owner. The job of the operating model is not to centralize ownership; it is to make the handoffs explicit.

---

## The operating model: three build-and-run functions

**Three build-and-run functions, one governed estate.**

| Function | What it owns | Responsibility |
|----------|--------------|----------------|
| 🎓 **AI CoE** (AI Center of Excellence) | **OWNS THE POLICY** | Sets the standards: approved models, capacity rules, allowed runtimes, and the trustworthy-agent bar. **It sets the bar without building the agents.** |
| 🏗️ **Platform Engineering (CCoE)** | **OWNS THE PLATFORM** | Provides the landing zone and infrastructure for **Layers 1–2**, plus assisted deployment to onboard teams. |
| 👨‍💻 **AI Engineering & App Dev** | **OWNS THE PRODUCT** | Designs, builds, owns, and operates the agents — **to the CoE's standards, on the platform provided**. |

> **The AI CoE owns the policy · Platform Engineering owns the platform · AI Engineering owns the product.**

### Around these sit

| Function | Contribution |
|----------|--------------|
| 💰 **FinOps** | Cost & capacity economics, chargeback |
| 🔑 **IAM** | Agent identity, lifecycle, inventory |
| 🛡️ **Security & Compliance** | Posture, threat, data protection, audit evidence (SecOps · DPO · GRC) |
| 🏢 **Line of Business** | Sponsors the use case and owns its business value |
| 👔 **Exec Sponsor (CAIO)** | Cross-layer convener; owns the overall outcome |

### RACI legend

| | Meaning |
|---|---|
| **R** | **Responsible** — does the work |
| **A** | **Accountable** — one owner, the buck stops here |
| **C** | **Consulted** — input before the decision (two-way) |
| **I** | **Informed** — kept up to date (one-way) |
| **–** | Not involved |

---

## Trust is everybody's responsibility

Trust isn't one team's job and it isn't a couple of security controls bolted on the side. It's layered across **four interconnected controls — complementary, not sequential** — each with a named owner.

| Control | Scope | What it delivers | **Owned by** |
|---------|-------|------------------|--------------|
| 🔶 **Agent Operations** | **Agent-level** | End-to-end traces, AI evals, red-teaming & guardrails — tuned to each agent's type and objective | **The agent builder** |
| 🔷 **Governance Hub** | **Platform · Govern** | Every model, tool & agent call flows through one governed gateway — routing, policy, content safety, capacity & observability | **The AI CoE & platform team** |
| 🟢 **Agent Management** | **Platform · Identify** | Every agent is an owned enterprise asset — first-class identity, owner, lifecycle & audit trail | **IAM & security** |
| 🛡️ **Security Foundation** | **Platform · Protect** | Defender, Purview & Entra deliver threat protection, data governance & access beneath every agent | **The security org** |

**Trust starts inside the agent and extends across the platform — from 10 to 10,000 agents.**

---

## Master RACI matrix

**Org units × Citadel Blueprint layers — one Accountable owner per decision.**

### Layer 1 — Governance Hub · *AI Hub Gateway: APIM + API Center*

| # | Activity / Decision | AI CoE | Plat Eng | AI Eng | FinOps | IAM | Sec & Comp | Exec |
|---|---------------------|:------:|:--------:|:------:|:------:|:---:|:----------:|:----:|
| 1.1 | Set AI-adoption standards & policy | **A** | C | C | C | I | C | I |
| 1.2 | Provide & operate gateway infrastructure | C | **A** | I | I | C | C | I |
| 1.3 | Capacity & cost management / attribution (PTU/PAYG) | C | **R** | I | **A** | – | I | I |

### Layer 2 — Agent Operations / Runtime · *Microsoft Foundry, Agent Service, Container Apps*

| # | Activity / Decision | AI CoE | Plat Eng | AI Eng | FinOps | IAM | Sec & Comp | Exec |
|---|---------------------|:------:|:--------:|:------:|:------:|:---:|:----------:|:----:|
| 2.1 | Approve & standardize runtimes & dev tooling | **A** | C | C | I | I | C | I |
| 2.2 | Provide runtime infrastructure | C | **A** | C | I | I | C | I |
| 2.3 | Build, own & operate agents & use cases | C | C | **A** | I | C | C | I |

### Layer 3 — Agent Management & Lifecycle · *Entra Agent ID, Workload Identity, Agent 365*

| # | Activity / Decision | AI CoE | Plat Eng | AI Eng | FinOps | IAM | Sec & Comp | Exec |
|---|---------------------|:------:|:--------:|:------:|:------:|:---:|:----------:|:----:|
| 3.1 | Issue & govern agent identities | C | C | **R** | – | **A** | C | I |
| 3.2 | Agent lifecycle & ownership | C | I | **R** | – | **A** | C | I |
| 3.3 | Agent inventory & behavioural insight | I | I | C | – | **A** | **R** | I |

### Layer 4 — Security Foundation · *Defender for AI / Cloud, Microsoft Purview, Entra*

| # | Activity / Decision | AI CoE | Plat Eng | AI Eng | FinOps | IAM | Sec & Comp | Exec |
|---|---------------------|:------:|:--------:|:------:|:------:|:---:|:----------:|:----:|
| 4.1 | AI security posture & threat protection | C | C | C | – | C | **A** *(SecOps)* | I |
| 4.2 | Data security & classification for AI | C | I | C | – | I | **A** *(DPO)* | I |
| 4.3 | Compliance, audit & regulatory evidence | C | I | I | – | C | **A** *(GRC)* | I |

!!! note
    **The Line-of-Business sponsor is Accountable for each use case's business value (row 2.3)** and Informed elsewhere. It is kept in this footnote so the grid stays readable.

### How to read the matrix

- **Read down a column** → one team's total load across the whole estate.
- **Read across a row** → exactly who needs to be in the room for that one decision.
- **Trace accountability diagonally** → the philosophy in one glance:
  - The **AI CoE** is Accountable only on the *standards* rows (1.1 and 2.1). It owns the policy — the rules of the road. It does **not** own the infrastructure and it does **not** build the agents.
  - **Platform Engineering** is Accountable for the *infrastructure* rows (1.2, 2.2).
  - **AI Engineering** is Accountable for *building and operating the agents* (2.3).
  - **IAM** owns identity and inventory across all of Layer 3.
  - **Security & Compliance** owns posture, data, and audit across all of Layer 4.

---

## Layer-by-layer ownership and outcomes

Each layer answers a question your teams are already asking — and delivers a concrete outcome. **Frame every layer around the value it delivers, not the technology.**

### Layer 1 · Governance Hub

> *AI Hub Gateway · Azure API Management + Azure API Center*

**What it is:** the central control plane for all AI model and agent traffic — routing, capacity (PTU / PAYG) management, observability, policy enforcement, and cost attribution.

**It is infrastructure, not just policy.** That distinction tells you who does what: Platform Engineering **provides and operates** the gateway and offers assisted deployment; the AI CoE **sets the policy** it enforces; FinOps **owns capacity economics** and cost attribution.

| | |
|---|---|
| **Accountable** | AI CoE *(standards)* · Platform Eng *(gateway infra)* · FinOps *(cost & chargeback)* |
| **The question it answers** | *"How do I give every team access to AI without losing control of cost, capacity, and policy?"* |
| **What you gain** | One managed front door for all AI traffic — policy enforced centrally and spend attributable per consumer, **turning AI sprawl into a charge-backable service**. |

---

### Layer 2 · Agent Operations

> *Microsoft Foundry · Foundry Agent Service · Azure Container Apps*

**What it is:** where agents are built, hosted, orchestrated, and connected to enterprise data and tools.

**Infrastructure plus standards.** Platform Engineering **provisions and operates** the runtime; AI Engineering **builds on top**; the AI CoE **approves which runtimes and dev tools are allowed** — so builders innovate fast inside guardrails instead of dragging in an unvetted framework.

| | |
|---|---|
| **Accountable** | AI CoE *(runtime & tooling approval)* · Platform Eng *(runtime infra)* · AI Eng *(build & operate)* · LOB *(business value)* |
| **The question it answers** | *"Can my teams build and ship agents fast, connected to our data, without re-platforming or breaking the rules?"* |
| **What you gain** | A sanctioned runtime where builders move fast and **automatically inherit the Layer 1, 3 & 4 controls** — governance as an enabler, not a tax. |

---

### Layer 3 · Agent Management & Lifecycle

> *Entra Agent ID · Workload Identity · Microsoft Agent 365*

**What it is:** identity, authentication, and authorization for agents and the humans or systems they act on behalf of.

**Identity is the asset-management control point.** This is not *"give the agent a login."* An enterprise identity **turns an agent into a managed asset** — lifecycle (provision, change scope, decommission), named ownership so there are no orphaned agents, an authoritative inventory of every agent in the estate, and — through Agent 365 linking Entra, Defender, and Purview — genuine **behavioural insight** into how that agent actually acts.

| | |
|---|---|
| **Accountable** | IAM *(identity, lifecycle & inventory)* · AI Eng *(register & own)* · Security *(behavioural insight)* |
| **The question it answers** | *"When an agent acts, whose identity is it using, who owns it, what can it touch, and can I see it and revoke it?"* |
| **What you gain** | Every agent becomes a first-class, owned, **least-privilege** enterprise identity with full inventory and behavioural visibility — **closing the shadow-agent gap before it appears**. |

!!! warning
    This is the **most under-scoped layer in almost every customer conversation**. Slow down here.

---

### Layer 4 · Security Foundation

> *Defender for AI / Cloud · Microsoft Purview · Microsoft Entra*

**What it is:** posture, threat protection, data security, and compliance for AI workloads — built hand-in-hand with the security organization.

**Regulated-industry gatekeepers.** For banking and government accounts, the **DPO and GRC are not just consulted — they are gatekeepers**. No production AI reaches users without their sign-off. Bring them in **early, not at the finish line**.

| | |
|---|---|
| **Accountable** | SecOps *(posture & threat)* · DPO / Purview *(data security)* · GRC *(compliance & evidence)* — all under the CISO |
| **The question it answers** | *"Can I prove this AI estate is protected, compliant, and auditable — to my board and my regulator?"* |
| **What you gain** | AI-specific threat protection, data-loss controls, and compliance evidence unified across the estate — **the layer that converts pilot into approved-for-production**. |

---

## The cross-layer convener

**No single team owns all four layers — and that's by design.**

| Role | Scope |
|------|-------|
| **Chief AI Officer / AI Governance Board** | **Cross-layer convener** — owns the outcome: *deploy AI at scale without losing control of cost, identity, data, security & compliance.* |
| **CIO / CTO** | Layers 1–2 |
| **CISO** | Layers 3–4 |
| **CRO** | Layer 4 compliance |

Citadel gives you **one coherent way to align four normally-siloed teams behind a single goal**.

---

## Putting this into practice

| # | Step | What to do |
|---|------|-----------|
| **1** | **Map your teams to these roles** | Confirm you have a **distinct AI CoE**. If you don't, **that's gap number one** — flag it before anything else. |
| **2** | **Start where you're strongest** | Find the single layer where you're furthest ahead — that's your beachhead. The other three become your expansion path. |
| **3** | **Use the RACI to assign clear owners** | Each layer has a different accountable owner. Walk the matrix row by row and name a real person or team for every **A**. |
| **4** | **Engage each owner on their outcomes** | Frame every layer around the **value it delivers**, not the technology — use the four questions above verbatim. |

!!! important
    **Keep flexibility in mind.** The blueprint is a guide, not a mandate — adapt it to your organization's unique structure and culture. The principle to preserve is **separating standards, infrastructure, and builders** across the layers, even if the exact team names and org-chart boxes differ.

---

## Common anti-patterns

| Anti-pattern | Why it breaks | The fix |
|--------------|---------------|---------|
| **One team tries to do all three** — sets the standards, runs the platform, *and* builds the agents | Standards get bent to fit delivery deadlines; the platform becomes a bottleneck | Split into AI CoE / Platform Engineering / AI Engineering, even if they are small |
| **No distinct AI CoE** | There is nobody accountable for approved models, capacity rules, or the trustworthy-agent bar — so each team invents its own | Stand up the CoE first; it is gap number one |
| **Security engaged at the finish line** | In regulated industries, DPO and GRC are gatekeepers — late engagement means late rejection | Bring SecOps, DPO, and GRC in at deep-dive stage, not at production |
| **Identity (Layer 3) treated as "just a login"** | The shadow-agent gap opens quietly and becomes the biggest risk at scale | Reframe identity as the **asset-management control point** — it is what lights up Layer 4 |
| **Two Accountable owners on one decision** | The buck stops nowhere | One **A** per row. Everyone else is R, C, or I |
| **Business value with no named sponsor** | Agents ship that nobody can justify | LOB sponsor is Accountable for each use case's business value (row 2.3) |

---

## Related guidance

- [Overview — AI Citadel Blueprint](index.md)
- [Technical Activation Paths](activation-paths.md) — the four parallel tracks each of these owners runs
- [Layer 1 · Governance Hub](layer-1-governance-hub.md)
- [Layer 2 · Agent Operations](layer-2-agent-operations.md)
- [Layer 3 · Agent Management](layer-3-agent-management.md)
- [Layer 4 · Security Foundation](layer-4-security-foundation.md)

---

<sub>AI Citadel Blueprint × Frontier Transformation · Microsoft · Global Black Belt</sub>
