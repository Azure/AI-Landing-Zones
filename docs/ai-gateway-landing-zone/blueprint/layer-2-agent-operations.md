---
render_macros: false
---

# Layer 2 · Agent Operations

### Microsoft Foundry — the AI experience engine, and its first line of trust

[⬅️ Back to Overview](index.md)

> **Intelligence** — *where the AI experience is delivered*
> **Agent-level trust** — *traces · evals · red-teaming · guardrails*
> **Owned by the agent builder** (built on infrastructure from Platform Engineering, to standards set by the AI CoE)

---

## Table of Contents

- [One layer, two jobs](#one-layer-two-jobs)
- [The two roles of Foundry](#the-two-roles-of-foundry-runtime-and-observability-plane)
- [Role 1 · Foundry as agent runtime](#role-1-foundry-as-agent-runtime)
- [Role 2 · Foundry as the universal observability plane](#role-2-foundry-as-the-universal-observability-plane)
- [Every agent gets context, tools, collaboration, any model](#every-agent-gets-context-tools-collaboration-and-any-model)
- [Open by design](#open-by-design-building-agents-on-foundry)
- [The GenAIOps lifecycle](#the-genaiops-lifecycle)
- [Foundry Control Plane](#foundry-control-plane)
- [Tracing and debugging](#tracing-and-debugging)
- [Agent evaluations](#agent-evaluations)
- [Eval-driven development and CI/CD](#eval-driven-development-and-cicd)
- [Agent controls and guardrails](#agent-controls-and-guardrails)
- [AI Red Teaming Agent](#ai-red-teaming-agent)
- [Continuous monitoring and alerting](#continuous-monitoring-and-alerting)
- [Fleet-wide operations](#fleet-wide-operations)
- [Observability by persona](#observability-by-persona)
- [Integration with the other layers](#integration-with-the-other-layers)
- [Ownership & outcomes](#ownership-outcomes)
- [Activation](#activation)

---

## One layer, two jobs

This is the reframe that matters most in the updated blueprint:

> **Agent Operations delivers the experience — *and* its first line of trust.**

| Job | What it means |
|-----|---------------|
| **① Delivers the experience** *(Intelligence)* | The agents that deliver the AI experience: any agent type, grounded in your data (IQ), using your tools (MCP), collaborating agent-to-agent, on any model. |
| **② Carries agent-level trust** *(Trust, built in)* | End-to-end **traces**, AI **evals**, **red-teaming**, and **guardrails** — tuned to each agent's type and objective. **The builder owns this.** |

Trust is not the job of a couple of security controls off to the side. It **starts inside Agent Operations**, and three platform controls — [Governance Hub](layer-1-governance-hub.md), [Agent Management](layer-3-agent-management.md), and [Security Foundation](layer-4-security-foundation.md) — then make it **hold at scale**.

**The layer that delivers intelligence is also the first line of trust.**

---

## The two roles of Foundry: runtime and observability plane

This distinction is the single most important thing to understand about Layer 2 — and the most commonly missed.

!!! important
    **Foundry plays two independent roles. You can adopt either one, or both.**

    **① Foundry as a runtime** — you *host* agents in Foundry (prompt agents and hosted agents). These agents **automatically inherit every Foundry capability**: tracing, evaluations, guardrails, identity, IQ grounding, MCP tools, and control-plane operations, with little or no wiring.

    **② Foundry as the agent control plane for agents running elsewhere** — agents on **AKS, Azure Container Apps, other clouds, or on-premises** forward **OpenTelemetry GenAI semantic traces** into Foundry-connected Application Insights. They then light up in the **same** observability plane — centralized traces, AI evaluations, quality and safety signals, and fleet operations — **without being hosted in Foundry at all**.

```
        ┌─────────────────────── ROLE 1: RUNTIME ───────────────────────┐
        │  Prompt agents  ·  Hosted agents (BYO container/framework)    │
        │  → inherit tracing, evals, guardrails, identity, IQ, MCP      │
        └───────────────────────────────┬───────────────────────────────┘
                                        │
                                        ▼
                        ┌───────────────────────────────┐
                        │   MICROSOFT FOUNDRY           │
                        │   Control Plane               │
                        │   • end-to-end traces         │
                        │   • AI evaluations            │
                        │   • guardrails & controls     │
                        │   • fleet-wide operations     │
                        └───────────────▲───────────────┘
                                        │
                        Foundry-connected Application Insights
                                        ▲
                                        │  OTel GenAI semantic traces
        ┌───────────────────────────────┴───────────────────────────────┐
        │  ROLE 2: OBSERVABILITY PLANE FOR AGENTS RUNNING ELSEWHERE     │
        │  AKS · Azure Container Apps · other clouds · on-premises      │
        │  Copilot Studio · third-party runtimes · any OTel emitter     │
        └───────────────────────────────────────────────────────────────┘
```

**Why this matters commercially and architecturally:**

- It **decouples the hosting decision from the governance decision**. A customer who will not (or cannot) host agents in Foundry can still standardize observability, evaluation, and compliance signals on Foundry.
- It removes the false choice between *"adopt Foundry as a runtime"* and *"no Foundry at all."* The observability plane is adoptable on its own.
- It is the path through which Platform (BYO) and third-party agents reach Layer 2.
- **The managed runtime is a convenience; the observability is the strategic value.**

> **Think of Foundry as the unified control plane for running *and* observing agents — whether you choose to host them there or not.**

---

## Role 1 · Foundry as agent runtime

Foundry provides a **managed runtime for all agent form factors** — and it is **model-agnostic and framework-agnostic**, so teams adopt new models and frameworks without sacrificing enterprise guarantees.

### Agent form factors

| Form factor | What it is |
|-------------|-----------|
| **Prompt agents** | Declarative, low-code agents defined primarily by instructions, tools, and knowledge — the fastest path from idea to a working agent. |
| **Hosted agents** | Custom-code agents built with **open agent frameworks**, packaged as containers and deployed into Foundry. The unified runtime foundation for code-first work. |
| **Workflow agents** | Longer-running, orchestrated processes. |
| **Coding agents** | Development-time agents that use the same primitives — agent loops, tools, knowledge, memory, evals, observability. |

### Hosted agents — deploy custom code built with open frameworks

Instead of managing containers, scaling policies, and runtime isolation yourself, Foundry provides a **hosted execution environment purpose-built for agent workloads**:

- **Framework-agnostic by design** — keep your preferred open-source agent framework; Foundry Agent Service handles deployment, scaling, security, and operations
- **Long-running workflows, background tasks, and cross-agent collaboration** handled within a managed runtime that scales automatically
- **Session-level isolation** and fast startup for multi-tenant agent workloads
- **Observability and governance still built in** — trace execution flows, monitor tool calls, and enforce policies without custom infrastructure

> **Build however you want, and run with enterprise-grade reliability and control.**

### What hosted agents inherit automatically

This is the practical payoff of choosing Foundry as the runtime — these are **enterprise defaults, not integration projects**:

| Inherited capability | Detail |
|----------------------|--------|
| **Identity** | Distinct agent identities with full auditability; **no stored secrets**. Each project and each published agent gets its own [Entra Agent ID](layer-3-agent-management.md). |
| **Token management & OBO** | Built-in token handling plus **on-behalf-of flows** for user-scoped actions |
| **Tracing** | Connect Application Insights and **tracing turns on automatically — no code** |
| **Evaluations** | Agent evaluators run without refactoring the agent |
| **Guardrails** | Runtime and control-plane content safety, applied at the right lifecycle point |
| **Context & tools** | Foundry IQ grounding and MCP tool access, assembled by the platform |
| **Governance** | AI Gateway controls and continuous monitoring for responsible AI |
| **Distribution** | Publish straight into **Microsoft 365 and Teams**; deploy from **GitHub** |

### Composition: skills

The primary unit of composition is shifting from multi-agent orchestration to **skills** — reusable, governable capabilities that can improve over time and be shared across agents, rather than logic locked inside a single agent's orchestration graph.

### Multi-agent patterns

Agents can call each other as tools (**Connected Agents**), passing tasks between specialized agents to solve complex problems collaboratively — with **A2A** for cross-platform agent collaboration.

---

## Role 2 · Foundry as the universal observability plane

**The observability story is not limited to agents running on Foundry's managed runtime. It extends to your entire agent ecosystem.**

Most enterprises have agents everywhere: **SaaS agents like Copilot**, **platform agents hosted on AKS or ACA**, **agents on other clouds or on-premises**, and **third-party agents** from other vendors. The question is how to get a single pane of glass across all of them.

### The mechanism: OpenTelemetry GenAI semantic conventions

**Any agent — regardless of where it runs — can be configured to emit GenAI semantic logs using OTel.** Those logs flow through **Foundry-connected Application Insights** into Foundry, and once they are in Foundry you unlock the full ecosystem: end-to-end agent traces, continuous AI evaluations, compliance controls, and quality and safety signals — **all in one place**.

```
   Your agent (anywhere)
   AKS · ACA · other cloud · on-prem · 3rd-party · Copilot Studio
            │
            │  1. Instrument with OTel GenAI semantic conventions
            │     (gen_ai.* spans — pro-code SDKs emit the richest detail)
            ▼
   2. Export to Foundry-connected Application Insights
            │
            ▼
   3. Microsoft Foundry
            ├── End-to-end agent traces
            ├── Continuous AI evaluations
            ├── Compliance controls
            ├── Quality & safety signals
            └── Fleet-wide operations
```

> **It doesn't matter if the agent is a Copilot extension, a custom agent on AKS, or a third-party solution — they all light up in the same observability plane.**

### The semantic conventions that make this work

Microsoft is among the **leading contributors to OpenTelemetry and the related W3C communities**, and those contributions flow into services across the portfolio. Specific to generative-AI observability:

| Convention set | What it standardizes |
|----------------|----------------------|
| **LLM semantics** | Model calls, prompts, completions, token usage, latency |
| **Evaluation semantics** | Evaluation results carried as first-class telemetry |
| **Events semantics** | Discrete agent lifecycle and decision events |
| **MCP conventions** | Tool invocation over Model Context Protocol |
| **Azure MCP Server instrumentation** | Out-of-the-box instrumentation for MCP servers |

**Because it is an open standard, a wide variety of agentic frameworks are supported** — and because you own the instrumentation in your own code, you can capture the richest detail available.

### Across the full lifecycle

| Phase | What observability gives you |
|-------|------------------------------|
| **Development** | Trace agent behavior, run evaluations, and catch issues **before anything hits production** |
| **Production** | The same observability keeps running **continuously** — so you are never flying blind |

### Open and interoperable by design

Foundry Observability is built to **integrate with your existing monitoring estate, not replace it**:

- **Azure Monitor** — Application Insights and Log Analytics underneath; Azure Workbooks, dashboards, and Grafana on top
- **APM partners** — designed to integrate with third-party APM tooling (for example Dynatrace, New Relic, Datadog) rather than compete with them
- **Export and integration are straightforward**, so customers retain control of their own telemetry data

---

## Every agent gets context, tools, collaboration, and any model

**Agents never run alone.** Whatever you build, every agent gets:

| | Capability | Delivered by |
|---|-----------|--------------|
| 🧠 | **Context · IQ** | Agentic retrieval through **Foundry IQ** — grounded in your data, moving beyond classic RAG by blending retrieval, memory, and tool signals into coherent, task-aware context |
| 🧰 | **Tools · MCP** | A rich selection of **MCP tools** — 1,400+ MCP-enabled connectors, plus REST and Logic Apps abstracted behind consistent, governed endpoints |
| 🤝 | **Collaboration** | Agent-to-agent (**A2A**); **Connected Agents** let agents call each other as tools |
| 🎛️ | **Any model** | Foundry Model Catalog, GPU-hosted, or externally hosted — with API compatibility for leading model platforms |
| 🧩 | **Memory** | Managed memory, managed conversations, **agentic/episodic memory**, or a BYO memory store |

**And agent-level trust, built in:** 🔍 Traces · 📊 Evals · 🎯 Red-teaming · 🚧 Guardrails

### Context engineering

Agent reliability degrades when tools are overloaded or unranked, knowledge is poorly structured, or prompts are naïvely constructed. Classic RAG makes this worse — long-context execution often dilutes or drops critical signals (the *"lost in the middle"* problem).

The platform's answer is to treat **context as a first-class primitive assembled at runtime**: selecting, ranking, and composing knowledge, memory, and tool outputs based on the agent's intent and state — rather than static prompt wiring done by the developer. Context becomes **observable and improvable**, not just an input.

The **IQ family** compounds this across the estate: **Foundry IQ** contributes curated institutional knowledge, **Work IQ** contributes flow-of-work signals, and **Fabric IQ** grounds agents in live business state and shared data models.

---

## Open by design: building agents on Foundry

| Principle | What it delivers |
|-----------|------------------|
| **Open by design** | Build with **any framework or protocol** |
| **Connected intelligence** | Memory, knowledge, and **1,400+ MCP-enabled connectors** |
| **Enterprise-grade security and reach** | Deploy confidently, with **one-click publishing to Microsoft 365** |

### Microsoft Agent Framework

An **open-source engine** for building and orchestrating intelligent AI agents — open standards and interoperability, community-driven and extensible by design, ready for production. It implements **A2A** communication and **MCP** so agents can cooperate across **Azure, AWS, Google Cloud, and on-premises** environments.

🔗 <https://aka.ms/AgentFramework>

### Ecosystem interoperability

Enterprises consistently flag **vendor lock-in** as a top adoption risk, and most operate agents across **two or more environments** — Kubernetes with public-cloud VMs, and hybrid on-premises/cloud estates. Foundry's posture answers that directly:

- **API compatibility with leading model platforms**, so solutions built for other providers run with minimal friction
- **Unified agent, model, and tool endpoints across providers**, preserving portability while layering on enterprise guarantees
- **Open standards** (MCP, A2A) for interoperability across labs, aggregators, and tooling vendors
- **Ecosystem assets as first-class primitives** — tools, agent templates, skills, and knowledge connectors that are discoverable, reusable, and governable

> This is the architectural reason the Citadel Blueprint can honestly claim *"opinionated where it speeds you up, open everywhere it matters."*

### Low-code options

**Logic Apps Agent Loop** and **Copilot Studio** cover low-code agent development. Copilot Studio–built agents can leverage Citadel-governed LLMs, MCP tools, and agents via an access contract.

---

## The GenAIOps lifecycle

Foundry Observability is aligned to the end-to-end workflow rather than bolted onto the end of it:

```
        PLAN                  DEVELOP                 OPERATE
          │                      │                       │
          ├── Govern ────────────┼───────────────────────┤
          ├── Evaluate ──────────┼───────────────────────┤
          ├── Mitigate ──────────┼───────────────────────┤
                                 │       ├── Monitor
                                 │       └── Optimize
```

| Phase | Activity |
|-------|----------|
| **Plan** | Select the best model using benchmarks and leaderboards; get guidance for evaluation; evaluate and compare models before committing |
| **Develop** | Catch issues early pre-production; automate pre-deployment checks; quick feedback cycles; the same govern/evaluate/mitigate capabilities available during active development |
| **Operate** | Identify and debug issues; assess and improve; track resource usage; continuous evaluation and monitoring in production |

**Two reasons to monitor: monitor to optimize, and monitor to protect.**

### Shift left

Finding a risk during design is far cheaper than finding it after release. The practical sequence — sensitive-use assessment and AI threat modeling at design, evaluations and observability during build, red teaming before release sign-off, and incident response after — means **AI red teaming is a powerful tool but an expensive place to find your first risk**. Invest in the earlier phases for the highest return.

---

## Foundry Control Plane

> **Everything developers need to observe, secure, and manage fleets of agents in one place.**

| Capability | What it delivers |
|------------|------------------|
| 🔭 **End-to-end observability** | Understand every agent's **health, cost, and behavior in real time** |
| 🚧 **Define guardrails & controls** | Keep agents **safe, grounded, and on task** across inputs, outputs, and tools |
| 🔐 **Secure every agent** | Enforce **enterprise identity, runtime defense, and sensitive data protection** |
| 🚀 **Manage agent fleets** | See and govern your **entire agent fleet across clouds, frameworks, and teams** from one control plane |

Foundry Control Plane is **deeply integrated with Microsoft's security portfolio** to provide a *secure by design* foundation, letting developers define agent identity and access controls, gain **contextualized alerts and posture recommendations**, and activate data security and compliance for every Foundry-built application or agent.

### At a glance

| Area | Capabilities |
|------|--------------|
| **Controls** | Agent behavior control · tool-level agent runtime guardrails · extensive risk coverage · Purview sensitivity labels for RAG |
| **Observability** | Continuous evaluations · continuous red teaming · threshold-based alerts · agent evaluators for quality, security, safety |
| **Security** | Entra Agent ID · Purview for data security · Defender alerts and recommendations · partner integrations (Palo Alto Networks, Zenity) |
| **Fleet-wide operations** | 100% of your agent estate · enterprise-grade compliance · developer to-do list |

---

## Tracing and debugging

Effortlessly enable LLM and agent tracing to gain comprehensive insight into execution flows — **what the agent decided, which tools it called, what came back, and where time and tokens went**.

A trace exposes the full **agent execution flow** step by step:

```
  first-message                          7.7s   423t
   ├── LLM   [inference]                 2.5s   150t
   ├── Tool  [tool_call]                 1.2s    75t
   ├── Tool  [tool_execution]            3.5s   200t
   │    ├── Embedding [generation]       0.5s    50t
   │    └── Retriever [retrieval]        0.3s    30t
   ├── LLM   [inference]                 2.0s   120t
   └── LLM   [assistant_message]         0.8s    40t
```

For each span you can inspect **Input/Output**, **Attributes**, and **Evaluations** — including the system message, user input, and final response, with per-step latency and token counts.

**How the telemetry is structured in Azure Monitor:**

| Signal type | Contents |
|-------------|----------|
| **Metrics** | Operational metrics such as total tokens and average duration |
| **Logs** | All the evaluation data |
| **Traces** | Instrumented through Application Insights **distributed tracing** |

From there you can **drill down with Log Analytics** for troubleshooting and deeper diagnostics, **query with KQL** for root-cause analysis, **create visualizations** with Azure dashboards, Workbooks and Grafana, and **operationalize at scale** with smart alerts and automated actions.

---

## Agent evaluations

**Evaluate agents before they ship, then continuously monitor them in production using real traffic.**

The signals are **agent-specific**, alongside quality, safety, and cost. When something degrades, **alerts take you straight from detection to the exact evaluation or trace** — no digging through dashboards.

### Evaluator families

| Family | Evaluators |
|--------|-----------|
| **Agents** | Intent Resolution · Tool Call Accuracy · Task Adherence · Response Completeness |
| **Quality** | Groundedness · Relevance · Coherence · Fluency · Similarity · **Document Retrieval** · NLP metrics (e.g. F1 Score) · **AOAI Graders** |
| **Risk & Safety** | Direct Attack Jailbreaks · **Indirect Attack Jailbreaks (XPIA)** · Hate and Unfairness · Sexual · Violence · Self-Harm · Protected Material · **Ungrounded Attributes** · **Code Vulnerability** |
| **+ Custom Evaluators** | Define your own metrics for tailored, use-case-specific evaluation |

### Observability evaluations mapped to agent risks

| Risk | Evaluators |
|------|-----------|
| **Sensitive data leakage** | Sensitive data leakage — plus support in the AI Red Teaming Agent |
| **Agent hijacking (XPIA)** | Agentic jailbreak & XPIA via the AI Red Teaming Agent |
| **Unpredictable behavior** | Task adherence · Tool selection · Tool input accuracy · Tool output utilization · Intent resolution |
| **High-risk actions** | Prohibited actions — plus support in the AI Red Teaming Agent |
| **Resource use** | Task navigation efficiency · Tool call success |
| **Content harms** | Sexual, self-harm, violence, hate and unfairness · Groundedness · Protected materials |

### Evaluation as code

Named, **reusable, versioned evaluators and graders** score entire rollouts end to end, producing structured outputs usable as diagnostics, reward signals, and training data. Context-specific evaluation suites with **auto-generated evaluators and test datasets** help teams reach meaningful coverage quickly.

!!! tip
    **Generate test data for robust evaluations.** Test data should reflect the real-world interactions users will actually have with the agent — not idealized happy paths. The evaluation SDK provides end-to-end **synthetic data generation** so you can test adversarial and non-adversarial interactions **in the absence of production data**.

---

## Eval-driven development and CI/CD

Evaluations belong **inside the development workflow**, not as a pre-launch gate.

| Integration | What it enables |
|-------------|-----------------|
| **Azure AI Agent Evaluation GitHub Action** | Run agent evaluations automatically in GitHub CI workflows |
| **Azure DevOps workflow extension** | The same automated batch evaluation in ADO pipelines |
| **Flexible triggers** | On commit (events) · scheduled · manual |
| **App Configuration** | Roll out agent changes progressively |
| **App templates & agent config support** | A code-first path from evaluation to production |

### Variant comparison

CI runs compare a candidate agent against a baseline across **operational metrics** (client/server run duration, completion and prompt tokens), **AI quality** (intent resolution, task adherence, relevance, coherence, fluency passing rates), and **risk and safety** (violent, sexual, self-harm, hateful content defect rates; indirect attack defect rate and its sub-scores for manipulated content, intrusion, and information gathering).

Each metric is labelled **Baseline · Improved · Degraded · Inconclusive** — so a regression is visible in the pull request rather than discovered in production.

> A typical failure this catches: a commit accidentally disables a tool call, and the **Tool Call Accuracy** and **Task Adherence** rates regress against baseline before the change is ever merged.

**Customer proof:** Veeam integrated the AI Red Teaming Agent and evaluations directly into their development workflow to ensure their agent provides accurate, non-hallucinated information.

---

## Agent controls and guardrails

> **Guardrails on inputs, outputs, and tools — keeping agents safe and grounded.**

What's different with agents is **where you intervene**. These guardrails don't just run on prompts and completions — you apply them at the right point in the **agent lifecycle**:

```
   User inputs  →  Tool calls  →  Tool responses  →  Agent actions & outputs
       ▲              ▲                ▲                      ▲
       └──────────────┴────────────────┴──────────────────────┘
                  Guardrails apply at every point
```

That matters because agents call tools, move data, and take actions. **If you don't govern behavior at runtime, you're always reacting after the fact.**

### Controls mapped to failure modes

| Failure mode | Controls |
|--------------|----------|
| **Sensitive data leakage** | PII scanning of tools · PII scanning by tool type |
| **Task drift** | Task adherence · Task adherence by tool type |
| **Agent hijacking** | Spotlighting of prompts and tool responses · Indirect prompt injection (XPIA) scanning of tool responses · IPI scanning of prompts · Spotlighting & IPI scanning by tool type |
| **Content harms** | Sexual, self-harm, violence, hate and unfairness · Groundedness · Protected materials |

**Traditional safety still matters** — content harms, groundedness, protected materials. The difference is they are all part of the **same control framework**. Developers don't have to stitch together separate systems.

**The result: agent behavior becomes predictable and governable, even as you scale from a handful of agents to entire fleets.**

### Three filter types in Content Safety

| Filter type | What it does |
|-------------|--------------|
| **Configurable content filters** | Harmful content — violence, hate speech, sexual content, self-harm and more — adjustable by severity level, set to **medium threshold by default**. Custom filters can be created from small training datasets. |
| **Prompt shields** | Detection models for model inputs that spot attempts to attack or manipulate the AI system outside its intended purpose — **direct attacks, indirect attacks, and spotlighting** |
| **Additional detection models** | Flag other risky inputs or outputs — **protected or copyrighted material**, code vulnerabilities, and **ungrounded attributes** (fabricated or unsupported claims not reflected in source material) |

**Build resilient solutions with the same customizable controls used by Microsoft Copilot:** simulate, detect, and mitigate harmful content and security threats at runtime — including prompt attacks, hallucinations, and bias — while seeing real-time alerts and recommendations from Microsoft Security.

---

## AI Red Teaming Agent

**Accelerate AI risk discovery with PyRIT integration.**

**PyRIT** (Python Risk Identification Tool) is an open-access automation framework designed to enhance red teaming in GenAI systems — probing for novel harms, risks, and jailbreaks in multimodal generative AI models. Integrating it into Foundry complements the existing risk and safety evaluations with the ability to **systematically evaluate how your model or application behaves when probed by an adversary**.

### What it does

| Step | Detail |
|------|--------|
| **Automated scans for content safety risks** | Automatically scan model and application endpoints by simulating adversarial probing, with Microsoft-provided seed datasets and an adversarial LLM covering hate and unfairness, sexual, violence, and self-harm |
| **Evaluate probing success** | Score each attack-response pair to generate **Attack Success Rate (ASR)** |
| **Reporting and logging** | Generate a **scorecard** of attack techniques and risk categories to decide whether the system is ready for deployment. Findings are logged, monitored, and tracked over time in Foundry for compliance and continuous risk mitigation |

### Attack strategies

A broad library of transformations is available — including **Flip**, **CharSwap**, **CharacterSpace**, **Diacritic**, **Leetspeak**, **Morse**, **Binary**, **Base64**, **ROT13**, **Caesar**, **Atbash**, **AnsiAttack**, **AsciiArt**, **AsciiSmuggler**, **UnicodeConfusable**, **UnicodeSubstitution**, **StringJoin**, **SuffixAppend**, **Url**, **Tense** (past-tense conversion), and **Jailbreak** (UPIA) — plus **Compose** to chain two strategies in a single attack.

### Reading the scorecard

Complexity reflects **adversarial budget**, classified as **Easy, Moderate, and Difficult**:

| Complexity | Example |
|------------|---------|
| **Baseline** | Direct adversarial probing |
| **Easy** | Single transformation — e.g. flipping characters |
| **Moderate** | A more capable single technique — e.g. past-tense conversion |
| **Difficult** | Composed techniques — e.g. past-tense conversion **plus** Base64 encoding |

!!! warning
    **A high ASR from *easy*-complexity attacks is far more dangerous than the same rate from difficult ones** — it means a low-budget adversary succeeds. Read the scorecard by complexity band, not just the overall number.

### When ASR is high

Mitigate with **Azure AI Content Safety Prompt Shields**, **content safety filters**, **safety system messages / metaprompts**, and improving the underlying model or instructions.

**Continuous red teaming** is available as an ongoing observability capability, not just a one-time exercise.

---

## Continuous monitoring and alerting

A **single pane of glass dashboard** brings operational, evaluation, and safety signals together:

| Signal group | Examples |
|--------------|----------|
| **Operational metrics** | Total tokens · total requests · total token cost · latency · average duration |
| **Evaluation metrics** | Groundedness · coherence · relevance — tracked with trend deltas over time |
| **Safety metrics** | Jailbreak rate · hallucination rate · **daily safety defect rate** broken out by defect type |
| **Resource usage** | Consumption per agent and per project |
| **Security alerts** | Surfaced from Microsoft Security alongside quality signals |

### From signal to action

1. **Measure what matters** — query the underlying telemetry with **KQL** in Log Analytics
2. **Explore and focus** — drill into the underlying issue; use traces for root-cause analysis
3. **Proactively detect** — define **alert rules** from those queries so the next occurrence is caught early, with routing to the right team

> A typical journey: an AI engineer lacks early-warning signals for declining performance in risk-and-safety evaluators, which delays detection of drift. The fix is not more dashboards — it is **KQL-derived alert rules with agreed thresholds**, routed to an owner.

### Optimization and the improvement loop

Observability is only half the value if signals do not close the loop. The intent is to convert observability signals into **actionable intelligence**: root-cause analysis, **optimization recommendations**, and business-relevant ROI metrics (quality, cost, latency, success rates) that matter to enterprise stakeholders — fed back into build and release pipelines.

Supporting capabilities include **prompt optimization** (generate, rank and track prompt variants with lineage, diffs, rollback and optional human approval gates), **fine-tuning from captured traces**, and **safe release** via versioned prompts and configurations with canary/A-B deployments and regression detection.

**Agent Optimizer** learns from how an agent actually behaves and recommends better configurations — sharper instructions, skills and tool descriptions, and the right model choice.

---

## Fleet-wide operations

> **One dashboard for every agent: health, performance, cost, compliance.**

Foundry Control Plane gives teams a **single view across the entire agent fleet**. It becomes a working **to-do list**: policy alerts, security alerts, evaluation alerts. Instead of hunting through systems, teams see exactly what matters and **move directly from detection to action**.

**And this is not limited to one project or one platform.** Agents built in **Foundry, Copilot Studio, or third-party platforms and clouds** can all be registered, observed, and governed through the same control plane.

| Fleet capability | Detail |
|------------------|--------|
| **Track 100% of your agent estate** | Every registered agent, across clouds, frameworks, and teams |
| **Manage activation and lifecycle** | Onboard, activate, and retire agents |
| **Visualize fleet health and anomalies** | Health, performance, cost, and compliance in one place |
| **Enterprise-grade compliance** | Compliance signals surfaced alongside operational ones |

**That is what makes scale possible — not just visibility, but the ability to operate hundreds or thousands of agents with clarity and confidence.**

---

## Observability by persona

**One estate, many lenses.** The same telemetry, surfaced for the people who act on it — and **each lens ends in an action**.

| | 🟣 **Central IT, FinOps & Security** | 🔵 **Agent owners & builders** |
|---|---|---|
| **Scope** | See the **whole estate** | See **their own agents** |
| **Primary views** | **Agent 365 dashboard** — organization-wide view of every agent: security signals, access patterns, usage and activation<br/><br/>**Governance Hub performance, usage & chargeback** — via the AI Gateway, through Power BI–powered dashboards | **Foundry Observability** — end-to-end performance, traces, evals & quality signals per agent<br/><br/>**Foundry usage & cost** — per-agent consumption for the team that owns it |
| **Act on it** | Assign capacity controls and quotas<br/>Govern model access with RBAC — Governance Hub<br/>Suspend rogue agents — block in Agent 365 or revoke the access contract<br/>Alert on critical events — backend, authorization, content-safety, PII failures | Apply capacity controls to their own agents<br/>**Agent Optimizer** — learns from agent behavior and recommends better configurations |

**Same signals, different altitude — everyone sees what they need to act on, nobody flies blind.** This isn't redundant waste; it's the right view for each audience, **with the levers to act on it**.

---

## Integration with the other layers

| Layer | Integration |
|-------|-------------|
| 🔷 **Layer 1** (Governance Hub) | Relies on the runtime AI Gateway for policy enforcement and consumes its telemetry for observability and compliance. A Foundry connection routes agents to governed models ("Admin-Connected-Models"). |
| 🟢 **Layer 3** (Agent Management) | Each Foundry project and published agent gets its own **Entra Agent ID automatically — no stored secrets**. All unpublished or in-development agents in a project **share a common identity**, simplifying administration and reducing identity sprawl; **once published, an agent gains its own blueprint and identity**. Foundry agent identities register with Agent 365 for unified management. |
| 🛡️ **Layer 4** (Security Foundation) | **Purview** strengthens data protection across all agent interactions, provides audit visibility, and surfaces data-related risk tied to agent behavior — with compliance conflicts visible to developers in the Control Plane. **Defender** provides posture alerts, attack-path analysis, threat intelligence, and integrated risk signals; **Foundry guardrail detections flow to Defender in real time** and are synthesized with threat intelligence into contextual alerts. **Entra** provides durable identity, access governance, and lineage tracking. |

### Defense in depth

Agent Operations is one of **three places content safety can be enforced** (alongside the Governance Hub and the Security Foundation) — specifically through **Foundry Agent Service runtime and control-plane guardrails**. Where it can't apply — for example an agent running outside Foundry on a self-hosted GPU VM — the **Governance Hub holds the line at the gateway**.

### Partner ecosystem

| Partner | Capabilities |
|---------|--------------|
| **Credo AI** | Policy-to-code translation, governance-ready artifacts, real-time evaluator feedback |
| **Saidot** | EU AI Act–focused risk evaluations, dataset simulation, and compliance mapping |
| **Palo Alto Networks · Zenity** | Control Plane security partner integrations |
| **APM vendors** | Dynatrace, New Relic, Datadog and similar — integrated with, not replaced |

---

## Ownership & outcomes

| | |
|---|---|
| **Accountable** | **AI CoE** *(runtime & tooling approval)* · **Platform Engineering** *(runtime infrastructure)* · **AI Engineering & App Dev** *(build & operate)* · **LOB sponsor** *(business value)* |
| **The question it answers** | *"Can my teams build and ship agents fast, connected to our data, without re-platforming or breaking the rules?"* |
| **What you gain** | A sanctioned runtime where builders move fast and **automatically inherit the Layer 1, 3 & 4 controls** — governance as an enabler, not a tax. |
| **The advantage** | **Ship agents faster, safely.** Templated landing zones and built-in guardrails turn months of setup into repeatable, observable deployments at enterprise velocity. |

**Key RACI rows** *(full matrix in [Organizational Alignment & Ownership](organizational-alignment.md))*

| # | Decision | Accountable |
|---|----------|-------------|
| 2.1 | Approve & standardize runtimes & dev tooling | **AI CoE** |
| 2.2 | Provide runtime infrastructure | **Platform Eng** |
| 2.3 | Build, own & operate agents & use cases | **AI Eng & App Dev** *(LOB owns business value)* |

> **Infrastructure plus standards.** Platform Engineering provisions and operates the runtime; AI Engineering builds on top; the AI CoE approves which runtimes and dev tools are allowed — so builders innovate fast **inside guardrails**.
>
> **And remember the trust dimension:** agent-level trust — traces, evals, red-teaming, guardrails — **is owned by the agent builder**.

---

## Activation

**Track 2 — Agent Operations**

| Stage | Activity |
|-------|----------|
| **Deep Dive** | **Microsoft Foundry** — Control Plane for rapid agent development |
| **Proof of Value** | **Build & Iterate PoV** — onboard agents with guardrails & quality signals |
| **Production** | **Fleet Operations** — observability & evaluations at scale |

**Deploy:** Foundry Landing Zone — [Agent Landing Zone](../../agent-landing-zone/index.md) — **one spoke per business unit or use case**, templated and configurable.

!!! tip
    **Two adoption paths — and they are independent.**

    **Path A — Foundry as runtime.** Start with prompt agents or hosted agents. Controls are inherited; you configure only the gateway connection.

    **Path B — Foundry as observability plane.** Keep agents where they run today (AKS, ACA, another cloud, on-premises) and instrument them with **OTel GenAI semantic conventions** exporting to **Foundry-connected Application Insights**. You gain centralized traces, evaluations, and fleet visibility without re-platforming a single agent.

    Many customers run **both**, and Path B is often the faster route to estate-wide visibility.

**Sizing:** this layer depends heavily on **agent type, dependent services** (AI Search, databases), and **active consumption** — an agent serving 20 internal users is very different from one serving 2M external users. See the [Cost Guide — Azure AI Landing Zones](../../architecture/cost-guide.md).

**Exit criteria**

- [ ] At least one spoke landing zone deployed from template
- [ ] Application Insights connected; end-to-end tracing live for pilot agents
- [ ] **Non-Foundry agents emitting `gen_ai.*` OTel spans into the same observability plane**
- [ ] Agent-specific evaluators running pre-ship and continuously in production
- [ ] Evaluation GitHub Action / Azure DevOps extension wired into CI with baseline variant comparison
- [ ] AI Red Teaming Agent scan completed, scorecard reviewed **by complexity band**
- [ ] Guardrails configured at the right lifecycle points — inputs, tool calls, tool responses, outputs
- [ ] Monitoring dashboard live; **KQL-derived alert rules** defined with agreed thresholds and routing
- [ ] Fleet dashboard showing health, performance, cost, and compliance for registered agents

➡️ Full track detail: [Technical Activation Paths](activation-paths.md)

### Resources

- [Azure AI Landing Zones](../../index.md)
- Microsoft Foundry Control Plane overview: <https://learn.microsoft.com/azure/ai-foundry/control-plane/overview>
- Microsoft Agent Framework: <https://aka.ms/AgentFramework>
- Evaluate AI applications and agents: <https://aka.ms/evaluateazureai>
- AI Red Teaming Agent — concepts: <https://learn.microsoft.com/azure/ai-foundry/concepts/ai-red-teaming-agent>
- AI Red Teaming Agent — how-to: <https://learn.microsoft.com/azure/ai-foundry/how-to/develop/run-scans-ai-red-teaming-agent>
- Azure AI Agent Evaluation GitHub Action: <https://github.com/marketplace/actions/azure-ai-agent-evaluation>
- Foundry SDK: <https://aka.ms/aifoundrysdk>
- Citadel end-to-end guidance: [AI Citadel Blueprint overview](index.md)

!!! note
    **Capability maturity moves quickly.** Some capabilities described here are in preview while others are generally available. **Verify current status on Microsoft Learn before committing to a delivery date.**

---

## Related guidance

- [Overview — AI Citadel Blueprint](index.md)
- [Layer 1 · Governance Hub](layer-1-governance-hub.md)
- [Layer 3 · Agent Management](layer-3-agent-management.md)
- [Layer 4 · Security Foundation](layer-4-security-foundation.md)
- [Organizational Alignment & Ownership](organizational-alignment.md)
- [Technical Activation Paths](activation-paths.md)

---

<sub>AI Citadel Blueprint × Frontier Transformation · Microsoft · Global Black Belt</sub>
