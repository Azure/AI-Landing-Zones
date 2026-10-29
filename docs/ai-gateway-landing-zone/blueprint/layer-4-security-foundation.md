---
render_macros: false
---

# Layer 4 · Security Foundation

### Defender, Purview, and Entra — protect and detect beneath every agent

[⬅️ Back to Overview](index.md)

> **Platform · PROTECT** — *protect & detect*
> **Owned by the security org**

---

## Table of Contents

- [What it is](#what-it-is)
- [The customer concerns this layer answers](#the-customer-concerns-this-layer-answers)
- [The expanding attack surface](#the-expanding-attack-surface)
- [Microsoft Defender — posture](#microsoft-defender-ai-security-posture-management)
- [Microsoft Defender — threat protection](#microsoft-defender-threat-protection)
- [Microsoft Purview — data security and compliance](#microsoft-purview-data-security-and-compliance)
- [Microsoft Entra — identity and access](#microsoft-entra-identity-and-access)
- [How the three work as one fabric](#how-the-three-work-as-one-fabric)
- [Defense in depth](#defense-in-depth)
- [Regulatory alignment: EU AI Act, NIST AI RMF, ISO 42001](#regulatory-alignment-eu-ai-act-nist-ai-rmf-iso-42001)
- [AI TRiSM alignment](#ai-trism-alignment)
- [Integration with the other layers](#integration-with-the-other-layers)
- [Ownership & outcomes](#ownership-outcomes)
- [Activation](#activation)

---

## What it is

**Posture, threat protection, data security, and compliance for AI workloads** — Microsoft Defender, Microsoft Purview, and Microsoft Entra, built hand-in-hand with the security organization.

This layer provides **real-time defense against AI-specific threats** and integrates **across all governance layers**. It is the layer that converts a **pilot into something approved for production**.

| Component | Contribution | Its job in one line |
|-----------|--------------|---------------------|
| 🛡️ **Microsoft Defender** | Threat intelligence and **AI security posture management** | *Defend against emerging AI threats and vulnerabilities* |
| 📚 **Microsoft Purview** | **Data governance**, labeling, and compliance | *Prevent sensitive data oversharing and ensure data compliance* |
| 🔐 **Microsoft Entra** | **Agent and application identity**, authentication and authorization | *Manage agent sprawl, govern permissions, protect resource access* |

Together these create a **defense-in-depth security fabric**. The key takeaway: **governance, identity, and security are not bolt-ons — they are built in from day one.**

!!! important
    **This layer is switched on by identity.** Once an agent has an Entra Agent ID and is registered in [Agent 365](layer-3-agent-management.md), these controls apply to it **automatically**. That is why Layer 3 is the hinge — and why the two layers are deliberately coupled rather than separate programmes.

---

## The customer concerns this layer answers

| Concern | The data |
|---------|----------|
| **Data leakage and inaccuracy** | **80%+** of leaders cite leakage of sensitive data as their main concern |
| **Emerging AI threats and vulnerabilities** | **50%+** of successful cybersecurity attacks against AI agents are expected to exploit **access control issues**, using direct or indirect prompt injection as an attack vector through 2029 |
| **Agent sprawl and risk** | **88%** of organizations are exploring or piloting AI agents — contributing to growing agent sprawl and increasing exposure |
| **Non-compliance** | **55%** of leaders lack understanding of how AI is and will be regulated, and are seeking guidance on how to adhere |

*Sources: ISMG First Annual Generative AI Study (Q3 2023, N=400); Gartner, "How to Secure Custom-Built AI Agents" (17 March 2025); KPMG AI Pulse Survey (Q4 2024).*

**Security concerns aren't hypothetical — they show up in nearly every boardroom conversation about AI.**

---

## The expanding attack surface

What used to be about securing cloud infrastructure and data — virtual machines, containers, storage, databases — has **moved up into AI models, apps, and agents**.

| Layer of surface | What's exposed |
|------------------|----------------|
| **Cloud application attack surfaces** | Virtual machine · container · storage · database |
| **Generative AI attack surfaces** | Prompts · AI model · grounding data · training data — *prompt injection, data leakage, model manipulation* |
| **Agentic AI attack surface** | Agent-to-agent · agentic memory · tool use · MCP servers · human-in-the-loop — *memory leaks, agent-to-agent data sharing* |

> Attackers are no longer just breaching networks — **they're exploiting how AI understands and responds.** And with agentic AI, agents talk to other agents, use external tools, and operate through orchestration frameworks like MCP servers. **This connectedness unlocks huge potential but also creates new exposures.**

### Threats in scope

Direct prompt injection (UPIA) · indirect prompt injection (XPIA) · unauthorized access · denial of service / wallet abuse · sensitive data exfiltration · training data poisoning · model theft · credential theft · lateral movement · malicious tool use · intent breaking and goal manipulation · privilege compromise

### Protection across every build platform

Customers build AI agents in different ways, and **Defender delivers consistent protection across the entire ecosystem** — whether that's low-code/no-code makers in **Copilot Studio** through natural language, or developers building code-first applications in **Microsoft Foundry, Azure, VS Code, and GitHub**.

> **From build to runtime: start secure, stay secure.**

---

## Microsoft Defender — AI security posture management

**Start secure.** Get visibility across all AI assets, identify vulnerabilities early, and reduce risk before a breach happens.

### 1 · Get comprehensive AI visibility

- **A unified inventory of all AI models and agents** across platforms — **Microsoft Foundry, Copilot Studio, Azure ML, Amazon Bedrock, and Google Vertex AI**
- See **metadata, agent instructions, identities, and connected agentic tools**
- Understand what AI assets exist, **who owns them**, and how they connect
- **Agentless** — visibility across multi-cloud environments with a few clicks, no deployment per workload
- **Cloud security explorer** lets you discover assets and their components, build custom queries, or use built-in query templates

> For organizations building dozens or hundreds of AI apps, this is the first step: **minimize agent sprawl and eliminate shadow agents.**

### 2 · Identify and remediate vulnerabilities

- Discover **AI misconfigurations, insecure instructions, and excessive permissions** to tools and agents
- The **agent detail page** shows linked MCP servers, models, and connected tools — with risk-based recommendations
- Recommendations are **grouped by severity for prioritization**, with detailed remediation guidance you can **assign to an owner** — promoting traceability and progress visibility across the team
- Follow recommendations to remediate posture issues among AI pipelines, deployments, and sensitive data stores

> A concrete example: a recommendation warning that **essential agent instructions are absent** — because if system instructions are missing, agents can act unpredictably and breach risk goes up.

### 3 · Prioritize and reduce risk with attack path analysis

- Use **risk context to know what to fix first**
- Find **direct and indirect exploitable paths** to your AI assets
- Visualizes relationships between cloud resources, agents, models, and data sources, mapping **toxic combinations** of posture issues

> **Worked example:** an internet-exposed container with severe vulnerabilities enables **lateral movement to a Foundry agent grounded with sensitive data**. Defender correlates risk signals from the GitHub repository, the container, Foundry, and the sensitive data source — flagging posture risk **from code to cloud**, and illustrating how code issues amplify into future attacks. Descriptions and attack stories attached to each path give the security admin contextual understanding.

---

## Microsoft Defender — threat protection

**Stay secure.** Continuously monitor for malicious AI activity, detect and respond in real time, and correlate signals into incidents.

### Detect threats across diverse forms and patterns

| Signal class | What it looks for |
|--------------|-------------------|
| **Suspicious content** | Jailbreak (malicious intent) · secrets and sensitive data · malicious URLs · encodings and manipulations |
| **Suspicious behaviors** | User/agent behavior · application behavior · tool behavior · access parameters — *powered by Microsoft Threat Intelligence* |

By analyzing **both prompts and responses**, Defender finds things that shouldn't be there — using both threat intelligence and AI to comb through each conversation.

!!! important
    **Certain attacks can't be found by looking at content alone.** Malicious tool invocation, intent manipulation, and wallet abuse **do not differ in content** — but *can* be detected by looking at the **patterns** of the user or the application. By examining the control plane alongside threat intelligence, Defender identifies familiar attack vehicles and **captures attacks even at the reconnaissance stage**.

### Monitor, detect, respond

| Capability | What it delivers |
|------------|------------------|
| **Monitor for malicious activities** | Detect suspicious **AI model interactions, agentic tool calling, memory changes, and LLM invocations** — powered by Microsoft Threat Intelligence |
| **Real-time detection and response** | AI model alerts for **jailbreak, sensitive data exposure, and credential theft** — blocked in real time |
| **Agent-specific threats** | **Intent breaking, goal manipulation, tool misuse, and privilege compromise** — with evidence and response details that trace back to the problematic agent |
| **Out-of-the-box + custom detections** | Ready-made detections plus the ability to build your own |
| **Correlate and contextualize** | Incidents correlated across multiple assets and agents, integrated with **Defender XDR and Microsoft Sentinel** |
| **Advanced hunting** | Query agent invocation and inference activity directly to build custom detections |

### Investigate and respond with rich context

Detecting suspicious events isn't enough — security teams need to **triage, contain, and respond swiftly and in an informed way**. Defender supplies the evidence that most organizations simply don't log:

| Evidence type | Why it matters |
|---------------|----------------|
| **Prompt and response evidence** | Visibility most orgs lack entirely — enables swift classification of user intent |
| **Application context** | AI resources are shared between applications; this lets the SOC **differentiate expected from unexpected content** |
| **User context** | Most AI calls go via proxy or gateway, **losing user identity in the process**. Defender recovers it — giving the SOC a real way to identify internal vs. external users and **trace an attack to its source** |
| **Grounding / prompt-to-grounding mapping** | Detects **where the data originated** — a true understanding of whether organizational data was compromised, and from where |
| **CNAPP posture context** | Adds runtime traffic insight back into posture — grounding data stores, search engines |
| **Built-in education** | Defender explains what the attack is, how it works, and what else to check in the investigation |

### Enhanced protection with Foundry guardrails integration

Defender's threat protection for GenAI apps and agents **works with Foundry's built-in content filtering** to raise security alerts:

```
1. User inputs a malicious prompt into an app via Foundry models or agents
         ▼
2. Foundry guardrails detect the jailbreak attack and block the response
         ▼
3. Defender ingests the Foundry detection + application context, and synthesizes
   it with Microsoft Threat Intelligence to generate contextual security alerts
         ▼
4. Alerts correlate into incidents for investigation and response in Defender XDR
```

**Real-time signal exchange between Foundry and Defender** means the builder's guardrail and the SOC's alert are the same event, seen from two altitudes.

### Public proof points

| Customer | Outcome |
|----------|---------|
| **Icertis** — intelligent contract management | **50% reduction** in SOC incident volume · **80% faster** alert triage · mean time to resolution down to **25 minutes** · **300+** Azure subscriptions secured |
| **Mia Labs** — conversational AI assistant | *"We've successfully resisted multiple jailbreak attempts. Defender for Cloud shows us how to design our processes with optimal security and monitor where jailbreak attempts may have originated."* — Marwan Kodeih, Chief Product Officer |

### Analyst recognition

Microsoft is named a Leader in **The Forrester Wave™: Infrastructure-As-A-Service Platform Native Security**, the **Frost Radar™: Cloud Native Application Protection Platforms**, and the **KuppingerCole Leadership Compass for CNAPP**.

---

## Microsoft Purview — data security and compliance

**DSPM for AI is a centralized place where you discover, protect, and then govern the interactions with AI apps.**

| Pillar | What it delivers |
|--------|------------------|
| 🔍 **Discover** | Insights and analytics into Microsoft Copilot experiences, enterprise AI, and other AI activity in your organization |
| 🛡️ **Protect** | Ready-to-use policies to monitor and protect data in AI prompts |
| 📋 **Govern** | Compliance controls to apply optimal data handling and storage policies |

### Discover — see the AI data risk

| Capability | Detail |
|------------|--------|
| **DSPM for AI reporting** | Total interactions over time · **sensitive interactions per AI app** · top unethical AI interactions · top sensitivity labels referenced · insider risk severity per AI app · potential risky AI usage |
| **Activity explorer** | AI interactions **including prompts and responses** · sensitive info types detected · DLP rule matched events |
| **Data risk assessment** | Identify oversharing exposure before and during rollout |
| **Audit** | Auditing of prompts and responses across Copilot experiences and agents |
| **Cross-platform visibility** | Sensitive data detection across Microsoft Copilot, enterprise AI apps, and **third-party AI tools** |

### Protect — stop oversharing and leaks

| Capability | Detail |
|------------|--------|
| **Sensitivity labels** | Agents honour labels; **a Copilot conversation inherits the most restrictive sensitivity label** from the references used to form a response |
| **Access control on labeled content** | Only content the user has appropriate permission for is included in responses. If the user lacks rights, the agent **informs them and provides a link but does not use the content** |
| **Encryption rights** | Honouring **view and extract usage rights** for content encrypted by Information Protection |
| **DLP for AI** | Policy conditions that **prevent processing of labeled Office files and PDFs in SharePoint** — sensitive content isn't used to generate responses |
| **DLP for agents** | Block file processing based on sensitivity labels for agents in Microsoft 365 |
| **Insider Risk Management** | **Risky AI Usage** indicator and policy template |
| **Communication compliance** | Detect business or code-of-conduct violations in prompts and responses; **detect prompt injection attacks, jailbreak, and mentions of protected materials** in GenAI prompts and responses |
| **Purview SDK / APIs** | Bring the **same level of security and compliance controls that Microsoft 365 Copilot supports** to your own custom AI apps and agents registered in Entra |

> The controls above were developed with financial-services customers deploying Copilot in highly regulated environments — establishing a **minimum standard for AI controls** that unblocked adoption. Top customers now expect that bar **whether it's Microsoft 365 Copilot or their own custom chatbot**.

### Govern — evidence and lifecycle

| Capability | Detail |
|------------|--------|
| **Compliance Manager** | Guided assistance to AI regulations via **assessment templates for the EU AI Act, NIST AI RMF, and ISO 42001** |
| **Data Lifecycle Management** | Retention policies to retain and/or delete AI interactions; auto-apply retention to referenced files via cloud-attachment policy |
| **eDiscovery** | **Preserve, collect, analyze, review, and export** AI interactions by creating an eDiscovery case |
| **Audit** | A durable record of interactions for investigation and regulatory response |

### Coverage across Copilot experiences and agents

Interactions in DSPM for AI, **audit of interactions**, capturing/classifying prompts and responses, Insider Risk Management, communication compliance, eDiscovery, and Data Lifecycle Management span **Microsoft 365 Copilot** (including Copilot Chat and agents in Microsoft 365), **Security Copilot**, **Copilot in Fabric**, and **Copilot Studio agents**. Sensitivity-label adherence, encryption adherence, and DLP apply to Microsoft 365 Copilot and to Copilot Studio agents **when using SharePoint as the data source**.

### Common causes of oversharing — fix these first

Site privacy set to public · default sharing option set to everyone · broken permission inheritance · use of the "everyone except external users" domain group · sites and files **without sensitivity labels**

> A staged approach works: **discover** oversharing risk with data risk assessment → **restrict** sensitive information from agent access with DLP → **increase** site privacy and labeling → **operate** with lifecycle policies and continuous assessment.

---

## Microsoft Entra — identity and access

**Identity, lineage, and access control for agents and applications.**

| Capability | What it delivers |
|------------|------------------|
| **Durable identity** | Every agent receives a **durable identity at build time** |
| **Access governance** | Enforces **policy-based access and conditional permissions** |
| **Identity alignment** | Agent identity aligns with **existing enterprise identity systems** |
| **Lineage tracking** | Tracks **ownership and access lineage across the lifecycle** |
| **Permission control** | Teams manage agent permissions through **familiar identity governance** |
| **Identity Protection for agents** | Risk signals — unfamiliar resource access, high sign-in volume, anomalous patterns — detected and responded to in real time |
| **Conditional Access for agents** | Policies targeting agent identities, conditioned on risk level, location, and device compliance |
| **Global Secure Access** | Web content filtering and threat filtering for **agent-initiated web access and outbound agent traffic** |
| **Lifecycle Workflows** | Auto-revoke on owner departure, agent retirement, or risk threshold exceeded |
| **Shadow agent discovery** | Surfaces agents operating outside central control |

➡️ Entra is also the engine behind [Layer 3 · Agent Management](layer-3-agent-management.md) — the full identity model, blueprints, and third-party SDK integration are documented there.

---

## How the three work as one fabric

- 🔄 **Coordinated threat response** across Defender, Entra, and Purview
- 👁️ **End-to-end visibility and audit trails** — every AI call auditable from a single path
- ⚡ **Real-time protection and compliance by design**
- 📡 **Signals feed SIEM / XDR** — gateway audit logs and Foundry traces stream into Defender and Microsoft Sentinel

### Signals surface where each team already works

!!! tip
    **The same signal appears in the console each persona already uses.** Defender surfaces security signals inside **Foundry Control Plane** (so developers see compliance conflicts and fix them where they build) and inside **Agent 365** (so IT sees them agent by agent). **Purview detections and alerts appear directly in the Defender portal** — so a SOC analyst investigating an incident sees the DLP verdict without switching tools. Nobody is forced into a single console, and nobody has to correlate by hand.

### A single investigation, three products

| Step | Product | What it showed |
|------|---------|----------------|
| Jailbreak attempt on an agent | **Foundry guardrails → Defender** | Attack blocked; Defender confirms and explains the technique |
| Malicious URL sent to the agent | **Defender** | Blocked by policy preventing agents from accessing user-supplied URLs |
| Sensitive data processing attempt | **Purview → surfaced in Defender** | Blocked from processing sensitive data and from sending it externally — **exactly as it would have been for a user** |
| Resolution | **Agent 365** | Agent confirmed trustworthy and returned to work, with evidence |

---

## Defense in depth

**One control is never enough — enforce critical guardrails in more than one place.**

Standard security practice: never depend on a single layer. If it's bypassed or simply can't apply, the system is exposed. **Citadel's controls deliberately overlap**, so coverage holds however an agent is built or hosted.

**Worked example — content safety is enforceable at three controls:**

| Control | Where it applies |
|---------|------------------|
| 🔷 **Governance Hub** | At the AI gateway and at Foundry-hosted models |
| 🔶 **Agent Operations** | In Foundry — Agent Service runtime & control-plane guardrails |
| 🛡️ **Security Foundation** | **Microsoft Defender (Defender for AI) monitoring across the estate** |

**When one control can't apply, another holds the line:**

| Scenario | What can't apply | What holds |
|----------|------------------|-----------|
| **Agent runs outside Foundry** — a self-hosted model on a GPU VM | Agent Operations & Security Foundation can't apply out of the box | 🔷 **Governance Hub enforces it at the gateway** |
| **Microsoft Copilot agents** — traffic doesn't traverse your gateway or Foundry | Governance Hub & Agent Operations can't apply out of the box | 🟢 **Agent Management (Agent 365)** and 🛡️ **Security Foundation (Defender)** enforce it — with Copilot's native protections |

**Same risk, multiple enforcement points — if one control can't apply or is bypassed, another does. That's the whole point of layering.**

---

## Regulatory alignment: EU AI Act, NIST AI RMF, ISO 42001

> **Compliance cannot be a manual checkbox at the scale of 10,000+ agents.**

Governance approaches that depend on **periodic audits** or **one-time approvals** collapse the moment adoption scales. As soon as many agents are acting across tools, data, and workflows, governance must become **built into the platform** — not bolted on.

Citadel is positioned as a **blueprint to future-proof AI investments**: layered governance places controls that **scale as adoption grows**, and keeps the platform aligned not just with current regulations but with future updates. It is designed to address both **limited-risk and high-risk** use cases — which matters because enterprises rarely run only one category of AI workload. **The controls flex with risk level, without forcing a rewrite of your architecture.**

### Three things working together

| | What it provides |
|---|---|
| **1. Runtime enforcement — [Governance Hub](layer-1-governance-hub.md)** | A unified AI gateway for models, tools, and agents, backed by a universal registry — enforcing **identity validation**, **access contracts**, and **per-request safety and guardrail enforcement**. When controls are enforced **at runtime**, compliance scales with adoption: you are not hoping teams follow guidelines, the platform applies policy consistently. |
| **2. Attribution and accountability — [Agent Management](layer-3-agent-management.md)** | The registry, the **named sponsor**, approval gates, versioned blueprints, and agent-level audit logs — the connective tissue that ties an action back to **a specific, owned agent** rather than a shared gateway credential. |
| **3. A unified security fabric — Security Foundation** | **Defender** for threat intelligence and AI security posture; **Purview** for data governance, labeling, audit, retention, eDiscovery and compliance; **Entra** for enterprise-grade authentication and authorization. |

### Turning obligations into evidence

| Obligation theme | Evidence the stack produces |
|------------------|------------------------------|
| **Risk management & assessment** | Compliance Manager **assessment templates for EU AI Act, NIST AI RMF, ISO 42001** — guided control mapping with evidence collection |
| **Record-keeping & logging** | Gateway audit logs, Foundry traces, Purview audit of prompts and responses, Entra agent sign-in logs |
| **Transparency & traceability** | Prompt-to-grounding mapping, sensitivity-label citation, per-call routing and outcome records |
| **Human oversight** | Named sponsor per agent, publish/activate approval gates, HITL escalation routing at the gateway |
| **Data governance** | Classification, labeling, DLP, oversharing assessment, retention and eDiscovery |
| **Accuracy & robustness** | Foundry evaluations, groundedness and task-adherence evaluators, continuous red teaming |
| **Cybersecurity** | Defender posture management, attack-path analysis, real-time threat detection, SIEM/XDR correlation |
| **Incident response** | Correlated incidents with prompt/response evidence, application and user context, and a tested revocation path |

> **The point:** a regulator does not ask whether your platform is secure. They ask you to **show a specific decision, made by a specific system, and prove who was accountable.** These layers together are what makes that answerable.

---

## AI TRiSM alignment

Gartner's **AI TRiSM** (Trust, Risk, and Security Management) framework addresses the new trust, risk, and security challenges introduced by AI systems — especially generative and agentic AI — by providing a unified framework of technical and governance controls that enforce policies, manage risk, and **secure AI behavior at runtime** rather than relying on static design-time guardrails.

It requires runtime technical controls that **continuously inspect AI inputs** — not just outputs or model configs. In RAG and agentic pipelines, **retrieved content is effectively untrusted input**: malicious or poisoned documents can alter model behavior through **indirect prompt injection (IPI)**, making pre-ingestion validation a first-class governance concern.

> **In TRiSM-aligned systems, retrieved content is treated as untrusted input.**
> If validation happens *only* at output time, indirect prompt injection remains unmitigated.

### The seven IPI controls mapped to Citadel

| # | IPI control | TRiSM pillar | Citadel layer(s) | How Citadel addresses it |
|---|-------------|--------------|------------------|--------------------------|
| 1 | **Instruction-separation & role enforcement** — detect retrieved content that issues instructions, redefines roles, or introduces execution directives | Risk, Security | 🔷 L1 + 🛡️ L4 | Gateway content-safety and prompt-shield policies block instruction-injection patterns at runtime; Defender provides real-time jailbreak and prompt-injection detection; Purview communication compliance detects prompt-injection attempts in prompts and responses |
| 2 | **Policy-aware semantic classification** — classify chunks by intent (instructional vs. informational) rather than keyword blocklists | Risk, Trust | 🔶 L2 | Foundry Control Plane evaluators run semantic classification against retrieved context; the AI Red Teaming Agent validates that paraphrased attacks are caught |
| 3 | **Source authenticity & provenance** — verify trusted source identity, approved pipeline, and document lineage | Trust, Compliance | 🔷 L1 (Universal AI Catalog) + 🟢 L3 | Azure API Center catalogs approved assets and data sources; Entra Agent ID validates agent and service identities accessing retrieval pipelines; Defender's prompt-to-grounding mapping identifies where retrieved data actually originated |
| 4 | **Sensitive data & policy constraints** — detect PII / regulated data and enforce masking or exclusion *before* prompt assembly | Compliance, Trust | 🛡️ L4 (Purview) + 🔷 L1 (Gateway) | Purview enforces labels, **sensitivity labels for RAG**, and DLP on retrieved content; gateway PII processing redacts or excludes flagged content before it leaves the boundary |
| 5 | **Contextual relevance & scope bounding** — ensure chunks are relevant and within task scope to reduce attack surface | Trust, Risk | 🔶 L2 | Foundry evaluators assess retrieval relevance, task adherence, and scope drift; fleet dashboards surface over-retrieval anomalies across agents |
| 6 | **Risk scoring & enforcement decisioning** — score each chunk (Low/Medium/High) and route to allow, sanitize, exclude, or human review | Risk, Security | 🔶 L2 + 🔷 L1 | Control Plane risk-scores retrieved content via evaluators; the gateway enforces the routing decision (pass / sanitize / block / escalate to HITL) |
| 7 | **Audit logging & explainability** — log content ID, validation result, enforcement action, and reason codes | Compliance, Trust | 🔶 L2 + 🛡️ L4 + 🟢 L3 | Foundry traces capture end-to-end retrieval decisions; gateway audit logs and Purview audit trails provide compliance-ready evidence; Agent 365 attributes all of it to a named, owned agent |

### Maturity model for retrieved-content controls

| Level | Capability | Citadel coverage |
|-------|-----------|------------------|
| L0 | No validation (raw retrieval injected) | — |
| L1 | Keyword filtering | 🔷 Gateway basic policies |
| L2 | Pattern + source allowlists | 🔷 Gateway + 🔷 API Center registry |
| L3 | Semantic intent classification | 🔶 Control Plane evaluators |
| **L4 (TRiSM)** | **Policy-mapped, risk-scored, auditable validation before ingestion** | **All four Citadel layers operating together** |

!!! note
    Reaching **L4 maturity requires all four Citadel layers working in concert**: the Governance Hub enforces runtime decisions, Agent Operations provides risk scoring and observability, Agent Management ensures provenance and accountability, and the Security Foundation delivers threat detection, data governance, and audit trails.

---

## Integration with the other layers

| Layer | Integration |
|-------|-------------|
| 🔷 **Layer 1** (Governance Hub) | **Defender** provides runtime protection for the AI Gateway and consumes its audit logs; **Purview** enforces data governance policies at the gateway level; **Entra** backs gateway authentication and authorization. Gateway audit logs stream to Defender and Sentinel, recovering the user identity that proxying would otherwise lose. |
| 🔶 **Layer 2** (Agent Operations) | **Defender and Purview surface security insights and compliance monitoring directly inside Foundry Control Plane** — developers see compliance conflicts and fix them where they work. **Foundry guardrail detections flow to Defender in real time** and are synthesized with threat intelligence into contextual alerts. **Entra** ensures identity governance for every project and published agent. Partner integrations (Palo Alto Networks, Zenity) extend coverage. |
| 🟢 **Layer 3** (Agent Management) | **Entra** provides identity governance for agents; **Defender** monitors for identity-based threats and contributes agent inventory and attack-path context; **Purview** enforces data governance based on agent access and behavior. **Agent 365 consolidates all three into one unified dashboard** — and registration in Agent 365 is what switches this layer on for BYO and third-party agents. |

**Once an agent has an identity and is registered in Agent 365, this layer's controls apply automatically — that is why identity is the connective tissue.**

---

## Ownership & outcomes

| | |
|---|---|
| **Accountable** | **SecOps** *(posture & threat)* · **DPO / Purview** *(data security)* · **GRC** *(compliance & evidence)* — all under the CISO |
| **The question it answers** | *"Can I prove this AI estate is protected, compliant, and auditable — to my board and my regulator?"* |
| **What you gain** | AI-specific threat protection, data-loss controls, and compliance evidence unified across the estate — **the layer that converts pilot into approved-for-production**. |
| **The advantage** | **Security & compliance, built in.** Defender, Purview, and Entra deliver continuous threat protection, data governance, and access control **beneath every layer** — a constant, not an afterthought. |

**Key RACI rows** *(full matrix in [Organizational Alignment & Ownership](organizational-alignment.md))*

| # | Decision | Accountable |
|---|----------|-------------|
| 4.1 | AI security posture & threat protection | **Security — SecOps** |
| 4.2 | Data security & classification for AI | **Security — DPO** |
| 4.3 | Compliance, audit & regulatory evidence | **Security — GRC** |

!!! warning
    **Regulated-industry gatekeepers.** For **banking and government** accounts, the DPO and GRC are **not just consulted — they are gatekeepers**. There is no production AI without their sign-off. **Bring them into the conversation early, not at the finish line.**

---

## Activation

**Track 4 — Security Foundation**

| Stage | Activity |
|-------|----------|
| **Deep Dive** | **Defender & Purview** — threat models, data governance & compliance mapping |
| **Proof of Value** | **Controls in Action PoV** — detection, classification & compliance evidence |
| **Production** | **Unified Posture** — measurable security & compliance |

**Activate across every layer** — there is no separate landing zone for this layer; it is switched on and integrated wherever AI runs.

### Discovery questions to run first

**Identity & access**

- Are Conditional Access policies currently applied to non-human / workload identities?
- Is Microsoft Entra ID Protection enabled and generating risk signals today?
- Are there existing Privileged Identity Management policies in the tenant?
- Do agents currently operate with broader permissions than strictly needed?

**Data security**

- What sensitivity labels are in use — are they applied to SharePoint and OneDrive?
- Have any data oversharing incidents involving Copilot or AI tools been identified?
- Is Purview DLP actively enforced for Microsoft 365 workloads?
- How is sensitive data (PII, IP, financial) currently protected from agent access?

**Threat detection**

- Is Microsoft Defender XDR deployed and the Microsoft 365 connector configured?
- Are audit logs enabled in the Purview portal?
- Does the SOC have playbooks for responding to AI-related security incidents?
- Are there existing advanced hunting queries or custom detections for AI workloads?
- Has the security team assessed the risk of adversarial agent attacks or jailbreaks?

> **Lead with the Defender integration and Conditional Access story** — these map directly to controls security stakeholders already understand.

**Exit criteria**

- [ ] Defender for AI enabled; agent inventory populated across Foundry, Copilot Studio, and multi-cloud
- [ ] Posture recommendations triaged and assigned; attack-path analysis reviewed
- [ ] Foundry guardrail → Defender signal exchange verified end to end
- [ ] Purview audit enabled; sensitivity labels published to SharePoint and OneDrive
- [ ] DSPM for AI data risk assessment completed; oversharing remediation underway
- [ ] DLP for AI policies enforced; Insider Risk *Risky AI Usage* policy live
- [ ] Communication compliance detecting prompt injection and protected materials
- [ ] Entra conditional access and least-privilege policies applied to agent identities
- [ ] Gateway audit logs and Foundry traces feeding SIEM / XDR
- [ ] Compliance Manager assessment started for the applicable regime (EU AI Act / NIST AI RMF / ISO 42001)
- [ ] Retention and eDiscovery configured for AI interactions
- [ ] Regulated-account sign-off from DPO and GRC obtained

**Sizing:** **Defender for AI** pricing relies on **estimated input/output tokens** (usually a fixed price for each). Engage the Security specialist team for a comprehensive estimation across Defender, Purview, and Entra.

➡️ Full track detail: [Technical Activation Paths](activation-paths.md)

### Resources

- AI threat protection in Microsoft Defender for Cloud: <https://learn.microsoft.com/azure/defender-for-cloud/ai-threat-protection>
- Microsoft Purview DSPM for AI: <https://learn.microsoft.com/purview/ai-microsoft-purview>
- Purview for Microsoft 365 Copilot: <https://learn.microsoft.com/purview/ai-m365-copilot>
- Purview for Copilot Studio agents: <https://learn.microsoft.com/purview/ai-copilot-studio>
- Addressing oversharing for Copilot deployment: <https://aka.ms/Copilot/Oversharing>
- OWASP Top 10 for LLM Applications: <https://owasp.org/www-project-top-10-for-large-language-model-applications/>
- Microsoft named a Leader in the IDC MarketScape for Unified AI Governance Platforms: <https://www.microsoft.com/en-us/security/blog/2026/01/14/microsoft-named-a-leader-in-idc-marketscape-for-unified-ai-governance-platforms/>
- Citadel end-to-end guidance: [AI Citadel Blueprint overview](index.md)

!!! note
    **Capability maturity moves quickly.** Some capabilities described here are in preview while others are generally available. **Verify current status on Microsoft Learn before committing to a delivery date.**

---

## Related guidance

- [Overview — AI Citadel Blueprint](index.md)
- [Layer 1 · Governance Hub](layer-1-governance-hub.md)
- [Layer 2 · Agent Operations](layer-2-agent-operations.md)
- [Layer 3 · Agent Management](layer-3-agent-management.md) — identity is what lights this layer up
- [Organizational Alignment & Ownership](organizational-alignment.md)
- [Technical Activation Paths](activation-paths.md)

---

<sub>AI Citadel Blueprint × Frontier Transformation · Microsoft · Global Black Belt</sub>
