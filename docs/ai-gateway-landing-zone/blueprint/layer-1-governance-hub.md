---
render_macros: false
---

# Layer 1 · Governance Hub

### The runtime enforcement plane — one governed front door for every model, tool, and agent call

[⬅️ Back to Overview](index.md)

> **Platform · GOVERN** — *govern every call*
> **Owned by the AI CoE & platform team**

---

## Table of Contents

- [The runtime governance imperative](#the-runtime-governance-imperative)
- [What it is](#what-it-is)
- [One governed front door: four dimensions](#one-governed-front-door-four-dimensions)
- [Dimension 01 · Governance](#dimension-01-governance)
- [Dimension 02 · Security](#dimension-02-security)
- [Dimension 03 · Operations](#dimension-03-operations)
- [Dimension 04 · Cloud & Hybrid](#dimension-04-cloud-hybrid)
- [Resiliency deep dive](#resiliency-deep-dive)
- [Hub-and-spoke deployment](#hub-and-spoke-deployment)
- [Integration with the other layers](#integration-with-the-other-layers)
- [Ownership & outcomes](#ownership-outcomes)
- [Activation](#activation)

---

## The runtime governance imperative

**Moving from shadow AI to unified AI access.**

In an AI system, **three primary assets** are critical and must be governed:

| Asset | Why it matters |
|-------|----------------|
| 🧠 **LLMs** | Provide the brain for AI agents |
| 🧰 **Tools and knowledge** | Allow agents to be grounded, with the ability to act |
| 🤖 **External agents** | Enable collaboration as AI systems grow |

All of these assets run on **APIs with standard protocols** — HTTP/REST, **MCP**, and **A2A**. Having those interactions governed is essential: AI APIs must be **managed, secured, and governed** to reduce both operational and security risk.

**Without central AI access governance, organizations face:**

| Risk | What it looks like |
|------|--------------------|
| 💸 **Unpredictable costs** | Token misuse and lack of oversight lead to financial surprises and an inability to attribute cost to use cases or users |
| ⚠️ **Reliability issues** | Unchecked APIs suffer performance bottlenecks and downtime |
| 🔓 **Security threats** | Weak protection leaves APIs vulnerable to attacks and data breaches |
| 😤 **Developer friction** | Inefficient processes slow innovation and complicate workflows |
| 😱 **Governance nightmares** | Staying compliant becomes a struggle without clear oversight |

**The goal: transform AI governance from a bottleneck into an innovation accelerator.**

---

## What it is

The **Governance Hub** is the **runtime enforcement layer** that mediates AI traffic between agents and LLMs, tools, and other agents. This is where governance becomes real — **every AI call flows through this layer, and nothing bypasses it**.

**Core components**

| Component | Platform | Role |
|-----------|----------|------|
| 🌐 **Unified AI Gateway** | Azure API Management | Single control point for models, tools, and agents |
| 📖 **Universal AI Registry** | Azure API Center | Centralized catalog for discovery and reuse |

**Enforcement capabilities**

- 🔑 Identity validation
- 📜 Access contracts
- 🚨 Per-request safety and guardrail enforcement
- ⚙️ Smart operations — token rate limiting, capacity management, cost attribution

### The gateway as a mediator

Because every call is **proxied through the gateway**, governance is enforced **centrally in policy** — clients get resilient, observable, well-managed AI **without changing app code**. That single mediation point unlocks:

- Content safety
- Resilient AI routing
- Scalable hub-and-spoke implementation
- Pluggable traffic mediation for usage, access controls, and other critical policies
- Global reports and dashboards across AI assets
- Smooth developer and agentic-platform onboarding

---

## One governed front door: four dimensions

Every model, tool, and agent call flows through a single gateway — governed across four dimensions **at the same time**.

| Dimension | Capabilities | Focus |
|-----------|--------------|-------|
| **01 · Governance** | 5 — Resiliency · Observability · Capacity Management · Universal AI Routing · Universal AI Catalog | Run AI as a managed platform |
| **02 · Security** | 4 — AuthN & AuthZ · Content Safety · PII Processing · Audit Logs | Zero-trust access to every AI asset |
| **03 · Operations** | 3 — Access Contracts · Publish Contracts · Backend Contracts | Declarative, automated day-2 onboarding |
| **04 · Cloud & Hybrid** | 3 — Hybrid Data Plane · Any Model, Tool or Agent · Centrally protected, anywhere | One control plane, data plane everywhere |

> **One control plane.** Consistent routing, security, operations, and placement — applied to every AI asset the enterprise consumes.

Instead of each team wiring up its own routing, keys, and monitoring, **one consistent control plane applies to every AI asset the business consumes.**

---

## Dimension 01 · Governance

> **Run AI as a managed platform** — not a pile of one-off integrations.

Centralized routing, cataloging, capacity, observability, and resiliency for every model, tool, and agent. This is the **operational backbone** that keeps AI reliable and well-behaved as usage scales.

| # | Capability | What it does | Scope |
|---|-----------|--------------|-------|
| **01** | **Resiliency** | Circuit breaking, failover, and session affinity keep traffic flowing | See [deep dive](#resiliency-deep-dive) |
| **02** | **Observability** | Performance monitoring and FinOps cost tracking with chargeback | Perf · Cost |
| **03** | **Capacity Management** | Flexible request- and token-based limits per use case | Rate limits |
| **04** | **Universal AI Routing** | Centrally route to models, tools, and agents across environments | One endpoint |
| **05** | **Universal AI Catalog** | Discover models, tools, agents, and skills via Azure API Center | API Center |

**Five capabilities, one platform: route · catalog · scale · observe · recover — governed from a single hub.**

### 01 · Resiliency — *keep LLM traffic flowing when backends throttle, fail, or hold state*

| | |
|---|---|
| **What** | **Fail-fast + recover** — circuit breakers park unhealthy backends, then probe them back<br/>**Automated failover** — retries transient 429 / 5xx on a healthy backend, pool, or provider<br/>**Session affinity** — pins stateful conversations to the member that holds their state |
| **How** | **Central policy** — enforced in gateway policy and backend config, no app-side change<br/>**Pools & aliases** — priority / weight routing with cross-model, cross-provider fallback<br/>**Structured errors** — every branch returns a typed error clients can react to |
| **Value** | **Higher availability** — graceful degradation across models, pools, and clouds<br/>**Transparent** — protection applies to every consumer automatically |

**Four layers, one request:** `Affinity → Load balance → Retry / failover → Circuit breaker`

### 02 · Observability — *see performance and cost for every use case, team, model, and backend*

| | |
|---|---|
| **What** | **Performance monitoring** — latency, throughput, throttling, and errors per product, model, and backend<br/>**FinOps** — token and request cost tracked for showback and chargeback |
| **How** | **Proxied telemetry** — every call is captured centrally in Application Insights / Log Analytics<br/>**Debug headers** — per-call routing decisions exposed for diagnostics<br/>**Cost mapping** — usage attributed to the calling access contract |
| **Value** | **Full visibility** — capacity planning and SLO management with **no per-app instrumentation**<br/>**Accountability** — each team and use case sees its own performance and spend |

**Signal to insight:** `Every call → Metrics + usage → Dashboards → Chargeback`

### 03 · Capacity Management — *protect shared model capacity with flexible, per-use-case limits*

| | |
|---|---|
| **What** | **Flexible limits** — rate limiting by requests and by tokens, per access contract<br/>**Quotas & priorities** — fair share of scarce model capacity across teams and use cases |
| **How** | **Policy at the gateway** — token / request policies applied per product and subscription<br/>**Priority routing** — critical workloads served first when capacity is tight<br/>**Spillover** — overflow routes to additional backends when limits are reached |
| **Value** | **No noisy neighbors** — one workload can't exhaust capacity for the rest<br/>**Budget control** — consumption is bounded and predictable per use case |

**How limits apply:** `Request / token limit → Quota + priority → Spillover`

### 04 · Universal AI Routing — *one endpoint, many backends*

| | |
|---|---|
| **What** | **Centrally managed** — route to models, tools, and agents on Azure, on-premises, and hybrid<br/>**Strategy-driven** — select by performance, model, or priority |
| **How** | **Pools & aliases** — a logical name resolves to the best available backend<br/>**Priority or weighted** — failover across members, models, and providers<br/>**One protocol surface** — works for LLMs, MCP tools, and A2A agents alike |
| **Value** | **Stable endpoint** — clients call one address; placement stays swappable<br/>**Governed by default** — routing and fallback remain centrally controlled |

**Resolution path:** `Logical name → Pool / alias → Best backend`

### 05 · Universal AI Catalog — *a single registry of models, tools, agents, and skills*

| | |
|---|---|
| **What** | **One catalog** — models, tools, agents, and skills registered via Azure API Center<br/>**Right visibility** — internal discovery plus potential external visibility |
| **How** | **API Center registry** — assets carry metadata, ownership, and versioning<br/>**Searchable** — teams find approved assets for reuse in minutes<br/>**Gateway-governed** — access and policy apply through the same front door |
| **Value** | **No shadow AI** — duplicated, ungoverned endpoints are designed out<br/>**Reuse first** — discover and consume vetted assets across the org |

**Catalog scope:** `Models → Tools → Agents → Skills`

!!! tip
    The registry also enables **MCP discovery and consumption across the enterprise** — including exposing your MCP servers to GitHub Copilot in VS Code and to Copilot Studio.

---

## Dimension 02 · Security

> **Zero-trust access to every AI asset.**

Nothing reaches a model until it's authenticated, authorized, screened for safety and PII, and logged for audit — **all enforced right at the gateway**.

> **No master keys, no direct endpoints.** Every request proves identity, is scoped to its contract, is screened for safety and PII, and is logged for audit.

| # | Capability | What it does | Scope |
|---|-----------|--------------|-------|
| **01** | **Authentication & Authorization** | API keys, IdP JWT tokens, and per-contract access to assets | Per contract |
| **02** | **Content Safety** | Prompt and response screening, tuned per access contract | Per contract |
| **03** | **PII Processing** | Detect and anonymize sensitive data in-line at the gateway | Inline |
| **04** | **Audit Logs** | Request metadata and optional bodies feed Defender / Sentinel | SIEM / XDR |

**Defense in depth:** identity, least-privilege, safety, data protection, and audit — layered on one governed path.

### 01 · Authentication & Authorization

| | |
|---|---|
| **What** | **Layered identity** — API key, or API key plus IdP-issued JWT tokens<br/>**Scoped access** — per-access-contract authorization to specific models, tools, and agents |
| **How** | **Gateway-managed** — keys and JWTs validated **before any backend is reached**<br/>**Allow-lists** — a contract binds a use case to the exact assets it may call<br/>**Least privilege** — default-deny; access is granted explicitly |
| **Value** | **No master keys** — consumers never hold raw provider credentials<br/>**Blast-radius control** — a compromised client is limited to its contract |

**Access path:** `API key + JWT → Access contract → Allowed assets`

### 02 · Content Safety

| | |
|---|---|
| **What** | **Two-way screening** — moderation and prompt-shield on requests *and* responses<br/>**Per contract** — categories and thresholds tuned to each use case's risk |
| **How** | **Inline policy** — Azure AI Content Safety invoked in the gateway pipeline<br/>**Block or flag** — unsafe content stopped before it reaches model or client<br/>**No app work** — guardrails apply without any client-side integration |
| **Value** | **Consistent guardrails** — the same protection across every use case<br/>**Right-sized** — strict where it must be, permissive where it can be |

**Screening path:** `Prompt → Content safety → Model → Response check`

### 03 · PII Processing

| | |
|---|---|
| **What** | **Inline detection** — PII detected in request (and response) bodies at the gateway<br/>**Anonymization** — sensitive entities redacted before forwarding upstream |
| **How** | **Gateway policy** — detection and anonymization run **before the model is called**<br/>**Fail-safe** — failures surface as a structured `502` clients can handle<br/>**Configurable** — entity types and handling set per use case; supports both natural detection and regular expressions |
| **Value** | **Central minimization** — sensitive data protected regardless of app or model<br/>**Compliance-ready** — consistent data handling across the estate |

**Protection path:** `Request → PII detect → Anonymize → Model`

### 04 · Audit Logs

| | |
|---|---|
| **What** | **Metadata always** — every call logs request metadata by default<br/>**Bodies optional** — request / response bodies captured where policy allows |
| **How** | **Structured per call** — identity, contract, model, routing, and outcome recorded<br/>**Streamed to SIEM** — logs feed Microsoft Defender and Microsoft Sentinel<br/>**One choke point** — all AI traffic is auditable from a single path |
| **Value** | **Investigation-ready** — trace any request end to end<br/>**Compliance + detection** — threats and misuse surface centrally |

**Audit path:** `Every call → Audit log → Defender / Sentinel`

---

## Dimension 03 · Operations

> **Declarative, automated day-2 onboarding.**

Instead of ticket-driven, ad-hoc changes every time someone wants to add a use case or a backend, **everything is onboarded through contracts**. Onboarding becomes configuration — versioned, repeatable, and centrally governed.

**Governance Hub philosophy: policy as code.** Shift governance left by treating backend and access rules as **binding contracts**.

| # | Contract type | Direction | Purpose |
|---|---------------|-----------|---------|
| **01** | **Access Contracts** | Northbound | Onboard a **consuming use case** with the assets, limits, and policies it is allowed to use. Governance travels with the contract and is injected into every call. |
| **02** | **Backend Contracts** | Southbound | Onboard a **model backend** from Azure, on-premises, or hybrid — with its endpoint, auth, resiliency, and capacity — once, then reuse across many contracts. |

### 01 · Access Contracts — *onboard a use case with the models, limits, and policies it's allowed*

| | |
|---|---|
| **What** | **Use-case onboarding** — a declarative contract for each consuming application or agent<br/>**Governance bundled** — allowed assets plus security, capacity, and safety policy in one place |
| **How** | **Declarative definition** — assets, auth method, rate limits, content-safety, and PII settings<br/>**Runtime injection** — the contract's policies are injected into **every API call**<br/>**Versioned** — changes are tracked and repeatable |
| **Value** | **Self-describing** — governance lives with the use case, not buried in app config<br/>**Fast, consistent** — new use cases go live through configuration |

**Onboarding flow:** `Define contract → Gateway enforces → Use case live`

### 02 · Backend Contracts — *onboard a model backend from Azure, on-premises, or hybrid — once*

| | |
|---|---|
| **What** | **Backend onboarding** — registers a model backend and its native properties into the gateway<br/>**Reusable** — one backend serves many access contracts |
| **How** | **Endpoint + auth** — connection and credentials defined declaratively<br/>**Pool placement** — priority / weight, plus native circuit-breaker resiliency, attached at onboarding<br/>**Any location** — Azure, on-premises, or hybrid targets |
| **Value** | **Swap centrally** — add or replace backends **without touching consumers**<br/>**Consistent behavior** — resiliency and routing are standard from day one |

**Onboarding flow:** `Register backend → Pool + resiliency → Available to contracts`

---

## Dimension 04 · Cloud & Hybrid

> **One control plane, data plane everywhere.**

Deploy the gateway on Azure, on-premises, or another cloud — and govern assets anywhere with network line-of-sight. That gives central governance **without forcing all the traffic through one location**.

> **The gateway is a mediator.** Deploy it where your AI runs so traffic stays local, while policy, routing, and audit remain centrally governed.

### 01 · Hybrid Data Plane

| | |
|---|---|
| **What** | **Deploy anywhere** — gateway runs on Azure, on-premises, and on other clouds<br/>**Mediator** — data-plane traffic stays close to the models and agents |
| **How** | **Central control plane** — policy and configuration managed in one place<br/>**Distributed enforcement** — local gateway instances handle traffic where it lives<br/>**Line-of-sight** — assets reachable wherever networking connects |
| **Value** | **Low latency** — requests avoid unnecessary round-trips<br/>**Data residency** — sensitive traffic stays within its boundary |

**Topology:** `Central control plane → Local gateway → Nearby models / agents`

### 02 · Any Model, Tool, or Agent

| Category | Coverage |
|----------|----------|
| **Any model** | **Out of the box** — Azure AI Foundry, Google Gemini, AWS Bedrock, Anthropic Claude<br/>**OpenAI-compatible** — Llama, Qwen, and other open-source models |
| **Any tool** | **MCP protocol** — convert an existing REST API into MCP<br/>**Bring your own** — register an existing MCP server under gateway governance |
| **Any agent** | **A2A protocol** — register A2A agents into the gateway<br/>**Governed access** — consumers reach protected agents through gateway security |

**Under one gateway:** `Foundry · Gemini · Bedrock · Claude → MCP tools → A2A agents`

> **Central control, local data.** Governance and visibility stay in one place; the traffic goes where it belongs.

---

## Resiliency deep dive

**Reliable AI access to LLMs and protected AI assets — keeping traffic flowing when backends throttle, fail, or hold state.**

| # | Capability | What it does |
|---|-----------|--------------|
| **01** | **Circuit Breaker** | Fail fast on an unhealthy backend, then auto-recover by probing it back |
| **02** | **Session Affinity** | Keep stateful conversations on the backend that holds their state |
| **03** | **Automated Failover** | Keep a request alive when the first-choice target throttles or errors |
| **04** | **Error Handling** | Structured errors so clients can diagnose — and know what's safe to retry |

**Putting it together:** a resilient production onboarding combines **all four dimensions** — governance, security, operations, and placement — behind a single access contract.

**Reliable AI routing**

- **Priority & resilient routing** — set priority groups with automatic fallback for a failing LLM instance
- **Load balancing** — weighted distribution across pool members
- **Capacity flow control** — support for both **token-based** limits (suitable for LLMs) and **request-based** limits (suitable for tools / MCP)

---

## Hub-and-spoke deployment

### AI Governance Hub — central deployment

> **AI Hub Gateway Landing Zone** — [AI Gateway Landing Zone](../index.md)

- Deployed **centrally** to serve as the **runtime command center**
- One deployment governing both production and non-production, **or** two deployments (one each) — more can be added per requirements
- Unified AI gateway for all model, tool, and agent access
- Universal AI registry for centralized catalog and discovery
- Centralized logging, monitoring, and policy enforcement
- Platform-level observability and audit trail — centralized performance metrics, usage tracking, with optional request/response logging
- Shared infrastructure every project leverages

### Agent Environment Spokes

> **Foundry Landing Zone** — [Agent Landing Zone](../../agent-landing-zone/index.md)

- Deployed multiple times — **one per business unit or use case**
- Fully self-contained and secure, with dedicated compute, storage, data, and dependent services
- Teams work autonomously without stepping on each other's toes
- Each spoke connects back to the hub for centralized governance and observability

**This architecture delivers "local freedom" in each project area under a common governance framework enforced by the hub.**

---

## Integration with the other layers

| Layer | Integration |
|-------|-------------|
| 🔶 **Layer 2** (Agent Operations) | Foundry relies on the runtime AI Gateway for policy enforcement, and the gateway's telemetry feeds observability and compliance. Foundry agents route to governed models via a Foundry connection ("Admin-Connected-Models"). |
| 🟢 **Layer 3** (Agent Management) | Agent 365 / Entra Agent ID identities are **validated at the gateway** for access control and policy enforcement. A rogue agent can be stopped by revoking its access contract. |
| 🛡️ **Layer 4** (Security Foundation) | Defender for API provides an added layer of security and threat intelligence; gateway audit logs stream into Defender and Sentinel; Purview enforces data governance policies at the gateway level. |

### Defense in depth

The Governance Hub is one of **three places content safety can be enforced** (alongside Agent Operations and the Security Foundation). Critically, it is the control that **holds the line when an agent runs outside Foundry** — for example a self-hosted model on a GPU VM — because that traffic still flows through the gateway as a mediator between agent and model.

---

## Ownership & outcomes

| | |
|---|---|
| **Accountable** | **AI CoE** *(standards)* · **Platform Engineering** *(gateway infrastructure)* · **FinOps** *(capacity & cost attribution)* |
| **The question it answers** | *"How do I give every team access to AI without losing control of cost, capacity, and policy?"* |
| **What you gain** | One managed front door for all AI traffic — policy enforced centrally and spend attributable per consumer, **turning AI sprawl into a charge-backable service**. |
| **The advantage** | **Govern once, enforce everywhere.** Control scales *with* adoption instead of fighting it — the more AI you deploy, the more leverage this layer gives you. |

**Key RACI rows** *(full matrix in [Organizational Alignment & Ownership](organizational-alignment.md))*

| # | Decision | Accountable | Responsible |
|---|----------|-------------|-------------|
| 1.1 | Set AI-adoption standards & policy | **AI CoE** | — |
| 1.2 | Provide & operate gateway infrastructure | **Platform Eng** | — |
| 1.3 | Capacity & cost management / attribution (PTU/PAYG) | **FinOps** | Platform Eng |

> **It is infrastructure, not just policy.** Platform Engineering provides and operates the gateway and offers assisted deployment; the AI CoE sets the policy it enforces; FinOps owns capacity economics and cost attribution.

---

## Activation

**Track 1 — Governance Hub**

| Stage | Activity |
|-------|----------|
| **Deep Dive** | Align AI Hub Gateway & enforcement requirements |
| **Proof of Value** | **Unified Access PoV** — validate policy across models, tools & agents |
| **Production** | **Central Governance** — standardize onboarding; operationalize org-wide |

**Sizing:** T-shirt sizing guide — [AI Citadel Governance Hub sizing guide](../plan/sizing-guide.md)

➡️ Full track detail: [Technical Activation Paths](activation-paths.md)

### Resources

- AI Hub Gateway Landing Zone: [AI Gateway Landing Zone](../index.md)
- AI Hub Gateway solution accelerator: <https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator>
- AI Gateway capabilities in Azure API Management: <https://learn.microsoft.com/azure/api-management/genai-gateway-capabilities>
- Azure API Management — unified AI gateway design pattern: <https://techcommunity.microsoft.com/blog/integrationsonazureblog/azure-api-management---unified-ai-gateway-design-pattern/4495436>
- Citadel end-to-end guidance: [AI Citadel Blueprint overview](index.md)

---

## Related guidance

- [Overview — AI Citadel Blueprint](index.md)
- [Layer 2 · Agent Operations](layer-2-agent-operations.md)
- [Layer 3 · Agent Management](layer-3-agent-management.md)
- [Layer 4 · Security Foundation](layer-4-security-foundation.md)
- [Organizational Alignment & Ownership](organizational-alignment.md)
- [Technical Activation Paths](activation-paths.md)

---

<sub>AI Citadel Blueprint × Frontier Transformation · Microsoft · Global Black Belt</sub>
