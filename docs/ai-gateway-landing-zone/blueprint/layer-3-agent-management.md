---
render_macros: false
---

# Layer 3 · Agent Management

### Microsoft Agent 365 — the command center for every agent, whoever built it and wherever it runs

[⬅️ Back to Overview](index.md)

> **Platform · IDENTIFY** — *every agent owned & managed*
> **Owned by IAM & security**

---

## Table of Contents

- [Positioning: the agent command center](#positioning-the-agent-command-center)
- [Why agents need their own identity class](#why-agents-need-their-own-identity-class)
- [The compounding surface: SaaS, endpoint, cloud](#the-compounding-surface-saas-endpoint-cloud)
- [Observe · Govern · Secure](#observe-govern-secure)
- [Observe — see the whole estate](#observe-see-the-whole-estate)
- [Govern — guardrails and lifecycle](#govern-guardrails-and-lifecycle)
- [Secure — identity, access, data, threats](#secure-identity-access-data-threats)
- [Entra Agent ID: the identity model](#entra-agent-id-the-identity-model)
- [Blueprints and policy templates](#blueprints-and-policy-templates)
- [Heterogeneous by design: any agent, any builder](#heterogeneous-by-design-any-agent-any-builder)
- [The connective tissue: linking traffic to an agent](#the-connective-tissue-linking-traffic-to-an-agent)
- [Regulatory alignment and audit](#regulatory-alignment-and-audit)
- [Prerequisites and dependencies](#prerequisites-and-dependencies)
- [Integration with the other layers](#integration-with-the-other-layers)
- [Ownership & outcomes](#ownership-outcomes)
- [Activation](#activation)

---

## Positioning: the agent command center

Layer 3 is where an agent stops being anonymous software and becomes a **managed enterprise asset**. Microsoft Agent 365 is **the control plane for agents** — and the critical word is *heterogeneous*.

> **Agent 365 is not the control plane for Microsoft agents. It is the control plane for *every* agent.**

| Agent type | How it lands in Agent 365 |
|------------|---------------------------|
| **SaaS** — Microsoft 365 Copilot, Copilot Studio | Native — automatic identity and registry entry |
| **Managed runtime** — Microsoft Foundry Agent Service | Native — identity per project and per published agent |
| **Platform / BYO** — your framework on AKS, ACA, Agent Framework | Register via workload identity + the **Agent 365 SDK** |
| **Third-party & on-prem** — partner and non-Microsoft runtimes | Federate via the **Agent 365 SDK**; a broad partner ecosystem already integrates with it |

**One registry. One identity model. One policy surface. One audit trail.**

!!! important
    **Identity is the connective tissue of the entire Citadel Blueprint.** Once an agent is in Agent 365, [Layer 4](layer-4-security-foundation.md) security and governance apply to it **automatically** — Defender posture and threat protection, Purview data governance and audit, Entra access control. Get identity right and the security layer comes along almost for free. **This is the highest-leverage step in the whole blueprint, and the most under-scoped in most customer conversations.**

### The governing principle

> **The best way to manage agents is to extend the infrastructure you already use for managing users.**

Same Entra. Same Purview. Same Defender. Same admin center. **Agents simply become another identity type.** That is what keeps security consistent and reduces blind spots as agent numbers grow — and it is why the team that owns user identity today is the natural owner of agent identity tomorrow.

---

## Why agents need their own identity class

Agents belong in the same identity conversation as users, apps, and devices, because **they take actions and access resources**. But they do not fit neatly into the old buckets:

- Sometimes an agent acts **on behalf of a user**.
- Sometimes it behaves more like an **application**.
- Unlike traditional apps, agents are **not static** — they can acquire new skills as model capabilities evolve, which changes what they are able to do over time.

That is exactly why an agent needs to be treated as a **first-class identity**. When it has one, you can answer the questions that actually matter:

> **Who is it? What can it access? What did it do? And can I revoke it?**

Without an identity, those answers get fuzzy fast. You cannot separate human actions from agent actions, apply consistent controls, or respond quickly when something changes. **If an agent is compromised, it operates at speed and scale** — identity is how you get attribution, enforce protections consistently, and investigate quickly.

### Three agent interaction patterns

As agent roles change, so should permissions. The identity model supports three:

| Pattern | Behavior | Permission model |
|---------|----------|------------------|
| **Interactive agents** — *"Assist me"* | Acts on demand by user prompting, or on behalf of a user | Uses **delegated user permissions**; needs no access rights of its own. Ideal for summarizing email or responding to queries. |
| **Autonomous agents** — *"Do it for me"* | Acts on behalf of itself, or coordinates actions on the user's behalf and schedule | Has **its own roles and permissions**, enabling complex goal-oriented work independently — monitoring logs, auditing activity. |
| **Digital colleagues** — *"Work with others"* | Collaborates with agents, tools, and people; provisions its own access; achieves goals on its own behalf and schedule | Fully provisioned with **user-like credentials** — can join Teams, create and edit documents, interact in conversations, and collaborate with other agents via the registry. |

All three are **governed, auditable, and discoverable through a standards-based registry**.

---

## The compounding surface: SaaS, endpoint, cloud

Agent sprawl is not a single problem — it **compounds across three distinct surfaces**, each with its own risk profile.

| Surface | The questions it raises |
|---------|-------------------------|
| **☁️ SaaS agents** | What agents are employees using via the internet? What are their risk levels? What information is being shared with them? *(This is the next evolution of shadow IT — without visibility, every interaction is a potential data leak.)* |
| **💻 Endpoint agents** | What agents do employees have installed on their devices? What guardrails are built into them? What access and permissions are employees granting? *(An over-permissioned agent on an endpoint is a new attack vector sitting right on the device.)* |
| **🏗️ Cloud agents** | What agents are being developed across cloud and AI platforms? What vulnerabilities could be exploited? What built-in guardrails does the platform provide? *(These have the deepest integrations — APIs, MCP servers, data stores, other agents.)* |

**These three surfaces don't just add risk — they multiply it.** A SaaS agent an employee grants access to can reach endpoint data. A cloud agent can invoke tools that touch SaaS and endpoint resources. The sprawl compounds because **agents interact across boundaries in ways traditional security models were never designed for.**

### Every interaction surface needs protection

| Interaction | What must be protected |
|-------------|------------------------|
| **H2A** — human to agent (prompt) | Protect prompts; govern which users can access which agents; prevent users compromising agents |
| **A2H** — agent to human (response) | Screen responses; apply labels and DLP to what comes back |
| **A2A** — agent to agent (invocation) | Guardrails on which agents may interact; protect A2A connections; prevent agents oversharing data between them |
| **A2LLM** — agent to model (inference) | Prevent agents becoming a vehicle for model poisoning |
| **A2App** — agent to tools/APIs (invocation) | Access governance, real-time protection, and data security policy on MCP tools, APIs, and data sources |

---

## Observe · Govern · Secure

The whole of Agent 365 in three pillars.

| Pillar | Purpose | Capabilities |
|--------|---------|--------------|
| 👁️ **Observe** | *Monitor and manage agents in real time* | **Registry** — register and track every agent · **Mapping** — visualize agent usage and behavior · **Analytics** — measure adoption, performance and ROI · **Role-specific oversight** — extend visibility to security and business leaders |
| 🛡️ **Govern** | *Govern agents throughout their lifecycle* | **Onboarding** — bring agents under control from day one · **Integration management** — control what agents can access and do · **Lifecycle management** — automate lifecycle policies · **Audit and logging** — strengthen traceability and be audit-ready · **Data compliance** — meet AI regulations and policies |
| 🔐 **Secure** | *Protect all agents comprehensively* | **Access control** — protect agent identities and access · **Data security** — prevent oversharing and data leaks · **Threat protection** — defend against threats and vulnerabilities |

> **Observe is inventory. Govern is lifecycle and guardrails. Secure is identity, data, and threats.** For most organizations with divisions building independently, **visibility pays first**.

---

## Observe — see the whole estate

*Gain visibility into agents in your environment, understand how they're used, and act quickly on performance, behavior, and risk signals before they impact the business.*

| Capability | What it gives you |
|------------|-------------------|
| **Agent registry** | A unified view across Microsoft platforms **and** non-Microsoft ecosystems. Every agent registered and tracked. |
| **Agent analytics — measure effectiveness** | Track adoption, quality, performance, speed of task completion, and impact. **This is the evidence layer for a board-level business case.** |
| **Agent map — visualize usage and behavior** | See how agents fit into the broader ecosystem, connect with other agents, and perform over time. **The fastest way to spot an agent chained to sensitive content.** |
| **Custom security attributes** | Tag and group agents in Entra, then apply shared control policies to a whole group at once. |
| **Sign-in and audit logs** | All agent activities logged, **consistent with user audit logs** — same tooling, same investigation workflow. |
| **Role-specific oversight** | The right view for IT admins, security teams, AI admins, and business decision makers — each persona sees what they need to act on. |

### One estate, four personas

Agent management spans every role — **no one person can be all of these, and that is good security practice**:

| Persona | Their question | What they need |
|---------|----------------|----------------|
| **IT admin** | *"How do I unlock agents to deliver safe and scalable impact?"* | Bring agents under management · review & approve · agent usage · permissions, licences and tool access · ROI |
| **Security & compliance** | *"Are the agents secure and our data protected?"* | Enforce least privilege · secure agent access to resources · prevent data leaks · protection from threats and vulnerabilities |
| **AI admin** | *"How do I balance compliance and innovation with AI?"* | Ensure responsible AI usage · manage secure data access · review and approve AI agent usage |
| **Business decision maker** | *"Are agents making my department successful?"* | ROI · status against strategic departmental goals · agent usage |

➡️ The builder-side lens — Foundry Observability, per-agent traces, evals, and cost — lives in [Layer 2 · Agent Operations](layer-2-agent-operations.md#observability-by-persona). **Same signals, different altitude.**

---

## Govern — guardrails and lifecycle

*Establish guardrails for agents and people, onboard agents with IT oversight, and govern agent access to resources and data. Be audit-ready with built-in compliance and data retention.*

### Agent settings — the tenant default

Administrators enforce security, compliance, and governance standards while enabling flexibility for collaboration:

| Setting | Options |
|---------|---------|
| **Allowed agent types** | Allow agents built by **Microsoft** · built by **your organization** · built by **external publishers** — each independently controllable |
| **Sharing** | All users can share org-wide · no users can share org-wide (direct sharing with individuals still allowed) · only **specific groups** can share broadly |
| **User access** | All users *(default)* · no users · **specific users or groups** |
| **Catalog visibility** | Set which users and groups can view and install **specific** agents |

> A practical first question for any deployment: **would you allow external-publisher agents at all in phase one?**

### Admin actions — how an agent reaches users

IT approval is a **real gate**, not a formality:

| Action | Flow |
|--------|------|
| **Publish** — make an agent available for installation | Developer creates and tests → submits for approval → admin views pending submissions → admin starts the publishing wizard → applies default or custom **template** → reviews permissions and grants consent |
| **Activate** — allow users/groups to install and create instances | User requests activation → admin views pending submissions → activation wizard → apply template → review permissions, grant consent |
| **Deploy** — automatically install for users so it's ready to use | Admin selects an undeployed agent from the registry → selects users or groups → reviews permissions, grants consent |
| **Approve updates** | When a developer publishes an update it appears as **Update pending**. **Until approved, the previous version stays live for users** — no silent change in production. |

### Lifecycle automation

Rules-based agent management **automatically enforces lifecycle policies**:

- ⏱️ **Expire inactive agents** — after a pilot phase there are always agents nobody uses and nobody retired
- 🚩 **Flag ownerless agents** — with an alert and escalation workflow for unresolved cases, plus **bulk reassignment** to a manager
- 🚫 **Block risky agents**
- 🔄 **Auto-revoke access** via Entra Lifecycle Workflows — triggers include **owner departure** (account disabled), **agent retirement**, and **risk threshold exceeded**

> **Ownerless agents** arise when the user who created a shared agent is deleted from the organization. You can block, remove, or **reassign ownership** — the new owner gains full edit and delete permissions plus access to files the previous owner uploaded, and the previous owner loses all access including read rights.

### Connected agents

Connected agents are other Copilot-enabled agents that can **share data** with an agent — users can query and receive responses that include information from these linked agents.

!!! warning
    **Connecting two agents connects their data reach.** Treat a connection request as a data-access decision, not a convenience feature.

---

## Secure — identity, access, data, threats

*Secure agent identities, control access to resources, prevent data oversharing and leaks, and defend against threats and vulnerabilities.*

| Area | Capability |
|------|-----------|
| **Access control** | **Guardrails** — policies defining who can create, onboard and manage agents · **Governed access** — give agents access to the apps and resources they need to complete a task · **Conditional access** — enforce real-time access based on context and risk |
| **Start secure** | Extend **conditional access and identity protection** from users to agents — protecting agent identities and preventing breaches |
| **Data security** | Visibility into AI-related data exposure; protect the data agents create and access from **oversharing, leaks, and risky behavior** |
| **DSPM for AI** | Shows which agents are active and **where sensitive data is exposed** |
| **Threat protection** | Protect agents from threats, vulnerabilities and adversarial attacks. Detect, investigate and remediate incidents quickly, **with visibility into attack paths** |

### Conditional access for agents

Conditional Access policies can target **agent identities** directly:

- **Target** — agent identities (select *Agent* as the identity type) and/or specific agent resources
- **Conditions** — agent risk level, location, device compliance
- **Grant** — require compliant resource · **Block** — deny high-risk agent access immediately

**Entra ID Protection for agents** contributes the risk signals: accessing unfamiliar resources, high sign-in attempt volume, anomalous patterns — automatically detecting and responding to risky agent identity behavior in real time.

**Access scoping principles**

1. Grant agents **only the MCP permissions they need** — review permissions at the **blueprint** level, not agent by agent.
2. Use **custom security attributes** in Entra to group agents and apply shared access restrictions.

### Global Secure Access for agents

For Copilot Studio agents that use **Computer Use or web browsing**:

- **Web content filtering** for agent-initiated web access
- **Threat filtering** for outbound agent traffic

> **Agent 365 extends Zero Trust identity controls to every AI agent in your tenant.**

---

## Entra Agent ID: the identity model

Every Agent 365 agent receives a **Microsoft Entra Agent ID** — its enterprise identity. Entra Agent ID delivers *secure access for AI agents, just as you do for employees*, across three pillars:

| Pillar | What it delivers |
|--------|------------------|
| **Manage AI agents at scale** | Visibility into the full agent fleet — agents built on Microsoft platforms **and third parties, with or without Agent ID** — brought under consistent guardrails. New agents are created with **identity built in and secure by default**. |
| **Govern agent identities and lifecycle** | Maintain accountability, manage lifecycle from creation to deactivation, and **prevent access accumulating** as teams and agent capabilities change — so agents do not outlive their purpose. |
| **Protect agent access to resources** | Enforce policy-based access controls, **block risky agents** when signals indicate compromise, and prevent agents reaching malicious or unauthorized resources. |

### Anatomy of an agent identity

| Attribute | Meaning |
|-----------|---------|
| **Identifier** | Each agent identity has a unique ID |
| **Display name** | The name shown when the agent is used |
| **Sponsor** | **The human user responsible for the agent** — this is the accountability anchor |
| **Blueprint** | The reusable template the identity derives from |
| *(optional)* **Agent user** | A user-like identity for agents that act like colleagues |

**How it is modeled:** an agent identity is a **single-tenant service principal with an `agent` subtype classification**. Unlike non-agentic service principals that operate independently, agent identities **require their parent blueprint** for impersonation and token exchange.

| Object | Role |
|--------|------|
| **Agent platform** | The application used to build agents (Copilot Studio, Microsoft Foundry, Security Copilot, third-party) |
| **Agent blueprint** | An application holding the agent's business logic and orchestration; **creates and manages agent identities**. Composed of a blueprint *application* (creates identities) plus a blueprint *service principal* (stores credentials). |
| **Agent identity** | An app-like identity derived from a service principal, representing an autonomous agent (`@odata.type: agentIdentity`). A blueprint can obtain tokens for its child identities through federated identity credential impersonation. |
| **Agent ID user** | An identity that acts like a user to access resources (`@odata.type: agentUser`). Each is tied to a specific agent instance parent, and from there to a blueprint. |

### Authentication scenarios

| Scenario | Behavior |
|----------|----------|
| **Attended** *(delegated / on-behalf-of)* | The agent operates on behalf of a human user, using delegated permissions the user granted, acting under the user's authority. |
| **Unattended — application** | The agent acts under its own authority as a service/application identity, using app-assigned roles, RBAC, or Microsoft Graph permissions. |
| **Unattended — agentic user** | The agent acts as an **autonomous identity with user-like claims**, authenticating and operating independently. |

### Governance tooling

- **Agent ID Administrator** — a built-in RBAC role for dedicated agent-governance staff
- **Agent registry** and **agent collections** in the Entra admin center
- **Agent sign-in logs** — agent activity alongside user, service principal, and managed identity sign-ins

---

## Blueprints and policy templates

Two distinct concepts that are easy to confuse — and together they are how an agent **starts secure instead of being secured afterwards**.

| Concept | What it is |
|---------|-----------|
| **Agent blueprint** | **Identity & architecture template** — an Entra-backed definition of an agent *type*. Defines what the agent is allowed to do, what systems or data it can access, who is responsible for it, and how it proves who it is. |
| **Policy template** | **Governance configuration bundle** — a predefined set of security, compliance, and access rules applied at publish/activate time. A **default template** includes essential security and compliance controls; **custom templates** add policies per your organization's requirements. |

### Why blueprints are the control point

> Instead of managing every agent individually, **you manage a class of agents through its blueprint.** Approve the blueprint once, and teams can create agents that inherit its permissions and policies.

This gives you scalability **and** control:

- Defines capabilities, required **MCP tool access**, security/compliance constraints, and audit rules
- Users request an instance; admins activate the blueprint → **all instances inherit its rules**
- Prevents shadow and rogue agents; anchors every agent in Entra-backed identity and permissions
- **If a class of agents is compromised or behaves unusually, you disable the blueprint and every agent in that class is turned off** — no per-agent firefighting

> **Blueprints are the control point you use to govern what comes in and out of your organization.**

---

## Heterogeneous by design: any agent, any builder

**Agent 365 is not just for Microsoft — it's for any agent.**

### Agent sources that land natively

Microsoft 365 Copilot · Copilot Studio · Microsoft Foundry · Microsoft Teams · Security Copilot

### Agent 365 SDK — bring everything else

A broad **partner ecosystem already integrates with the Agent 365 SDK**, so those agents are ready to start secure out of the box. The SDK carries **Entra, Defender, and Purview**, plus **observability based on OpenTelemetry**.

Integrated partners span agent platforms, enterprise SaaS, and frameworks — including Anthropic, OpenAI, SAP, ServiceNow, Workday, Adobe, Databricks, LangChain, CrewAI, Cognition, Glean, Perplexity, Box, Cursor, NVIDIA, Sophos, Zendesk, and others.

### Third-party agent integration flow

Third-party agent platforms (for example Gemini or Amazon Bedrock) often need secure access to protected resources — custom REST APIs, Azure Blob Storage — during their reasoning or orchestration loops.

```
  3P Agent Runtime          Agent Host App         Entra Agent ID SDK        Microsoft Entra ID
  (Gemini/Bedrock/…)        (Tool Executor)           (sidecar)               (Token Service)
        │                         │                       │                         │
        │── tool call requested ─▶│                       │                         │
        │                         │── execute tool ──────▶│                         │
        │                         │                       │── request token ───────▶│
        │                         │                       │◀── access token (JWT) ──│
        │                         │◀──────────────────────│                         │
        │                         │                                                 │
        │                         └──▶ Protected Resource (Authorization: Bearer …) │
        │◀─ tool result ──────────┘
```

The agent runtime **does not handle authentication or OAuth directly**. The host runtime forwards the request to the SDK, which establishes the execution context — **autonomous** (agent-only identity) or **delegated** (on behalf of a signed-in user via OAuth 2.0 on-behalf-of). Two access models are available:

| Model | Behavior |
|-------|----------|
| **Token Broker** | The SDK acquires an OAuth 2.0 access token from Entra and returns it to the host, which adds it to the Authorization header. **Ideal when you want direct control over API calls.** |
| **Downstream Call Broker** | The SDK handles **both** token acquisition and the HTTP call — minimal involvement in authentication for the host. |

Tokens are standard **JWTs** with issuer, audience, expiration, and authorization claims. **Open standards throughout: A2A protocol, MCP, OIDC, OAuth 2.0.**

> This is how identity stays consistent whether an agent runs in Foundry, on AKS, on-premises, or on another cloud entirely.

---

## The connective tissue: linking traffic to an agent

This is the role that makes Agent 365 more than an inventory: **it is what attributes activity to a specific, owned agent, and what aggregates signals from every layer into one control plane.**

### The attribution problem it solves

Most AI traffic reaches models **via proxies or gateways, losing the user identity in the process**. Without an identity layer you can see that *something* called a model — you cannot say *which agent*, *on whose behalf*, *under what approval*, or *with what data*.

Agent 365 closes that gap:

| Signal source | What it contributes | Where it lands |
|---------------|--------------------|-----------------|
| 🔷 **Layer 1 · Governance Hub** | Gateway audit logs — identity, access contract, model, routing, outcome for **every call** | Streamed to Defender / Sentinel, correlated to the agent identity |
| 🔶 **Layer 2 · Agent Operations** | Foundry traces, evaluations, guardrail decisions, red-team findings | Correlated per agent; Foundry agents carry their Entra Agent ID |
| 🟢 **Layer 3 · Agent Management** | Agent sign-in logs, registry metadata, blueprint, **named sponsor**, lifecycle state, approval history | The Agent 365 dashboard and Entra audit logs |
| 🛡️ **Layer 4 · Security Foundation** | Defender posture, threat detections and attack paths; Purview classification, DLP and audit of interactions | **Consolidated into the unified Agent 365 dashboard** |

**Agent 365 consolidates Entra, Defender, and Purview insights into a single agent-centric view.** That is what turns four separate telemetry streams into one answerable question: *"what did this agent do, and was it allowed to?"*

### Triage in practice

Because activity is attributable, investigation becomes a normal security workflow rather than an archaeology exercise. A worked example from the field:

1. Foundry guardrails **block a jailbreak attempt** on a procurement agent → real-time signal exchange raises a Defender alert.
2. The analyst sees **other alerts correlated into the same incident** — because attackers try multiple routes.
3. A phishing alert shows a malicious URL sent to the agent — **blocked by policy** preventing agents from accessing user-supplied URLs.
4. A **Purview DLP alert**, surfaced *in the same Defender portal*, shows sensitive data processing was blocked and an external email with sensitive data prevented — **exactly as it would have been for a user**.
5. The analyst resolves the incident and returns the agent to work — **with evidence**.

Advanced hunting queries can pivot directly on agent activity — for example filtering cloud app events for agent invocation and inference actions — so the SOC can build custom detections on the same substrate it already uses.

---

## Regulatory alignment and audit

Compliance cannot be a manual checkbox at the scale of thousands of agents. Agent 365 is where **regulatory obligations become evidence**, because it is the only layer that can answer *which agent, owned by whom, did what, to which data, under which approved blueprint*.

| Regulatory need | What Agent 365 and its foundation provide |
|-----------------|-------------------------------------------|
| **Inventory & registration of AI systems** | An authoritative registry spanning Microsoft **and** non-Microsoft agents — the system-of-record for "what AI do we run?" |
| **Accountability & human oversight** | Every agent has a **named sponsor** and owner; ownerless agents are detected, escalated, and reassigned by rule |
| **Attribution & traceability** | Agent sign-in and audit logs **consistent with user audit logs**; activity attributable to a specific agent identity rather than a shared gateway credential |
| **Change control** | Publish/activate approval gates; **update-pending** status so no version change reaches users unreviewed; versioned blueprints |
| **Least privilege & access review** | Blueprint-level permission review, custom security attributes, conditional access, access packages, expiration and recertification |
| **Right to revoke** | Block the agent in Agent 365, disable the **blueprint** to stop an entire class, revoke the access contract at the [Governance Hub](layer-1-governance-hub.md), or auto-revoke via lifecycle workflow |
| **Data handling evidence** | Purview audit of interactions, classification of prompts and responses, DLP enforcement, retention and eDiscovery — see [Layer 4](layer-4-security-foundation.md) |
| **Assessment & reporting** | **Compliance Manager assessment templates for the EU AI Act, NIST AI RMF and ISO 42001** provide guided control mapping and evidence collection |

> **The reason this matters:** a regulator's question is never *"is your platform secure?"* It is *"show me this specific decision, made by this specific system, and prove who was accountable."* Layer 3 is the layer that can answer it.

!!! note
    **Best practice: establish ALL governance policies BEFORE enabling self-service agent creation.** Proactive governance prevents agent sprawl — retrofitting it afterwards is materially harder.

---

## Prerequisites and dependencies

Agent 365 **extends** security and governance to agents — it does not replace the foundation underneath it. It relies on capabilities you configure in the underlying Microsoft 365 security stack:

| Component | What Agent 365 depends on it for |
|-----------|----------------------------------|
| **Purview** | Advanced classification; auto-labeling of grounding data; audit |
| **Defender** | Agent detection; posture and runtime protection; threat hunting and investigation |
| **Entra** | Identity protection; network controls for agents |
| **Intune** | Controls for local agents on Windows endpoints |

!!! important
    **The security foundation is not an optional add-on to the Agent 365 story** — it supplies the core security, identity, endpoint, and data capabilities Agent 365 functionality relies on. Confirm the current licensing prerequisites and the exact capability set with your Microsoft account team; **align with the Security team early** for assessment and sizing.

### Suggested enablement baseline

1. **Enable audit logs** — Purview portal → Audit → verify auditing is ON for the organization
2. **Connect Defender** — Defender portal → Settings → Security for AI → connect the Microsoft 365 connector
3. **Review the Agent 365 enterprise app** — Entra admin center → Enterprise Apps → review permissions and user assignments
4. **Create a conditional access policy** targeting agent identities
5. **Review initial agent risk posture** — Purview → DSPM for AI → AI observability → top recommendations
6. **Create an Insider Risk Management policy** using the *Risky AI Usage* template
7. **Publish sensitivity labels** for SharePoint and OneDrive
8. **Validate** with advanced hunting on agent invocation and inference events

---

## Integration with the other layers

| Layer | Integration |
|-------|-------------|
| 🔷 **Layer 1** (Governance Hub) | Agent identities are **validated at the gateway** for access control and policy enforcement. Gateway audit logs carry the calling identity, so traffic is attributable to a registered agent. **Revoking an agent's access contract is a second, independent kill switch** alongside blocking it in Agent 365. |
| 🔶 **Layer 2** (Agent Operations) | Foundry integrates **natively** with Entra Agent ID across the lifecycle. All unpublished or in-development agents in a project **share a common identity** — simplifying administration, reducing identity sprawl, and preserving developer autonomy during experimentation. **Once published, an agent gains its own blueprint and identity** bound to the agent application resource. Copilot Studio integrates natively via opt-in, with in-development agents in an environment sharing a common blueprint. |
| 🛡️ **Layer 4** (Security Foundation) | **Entra** provides durable identity at build time, access governance with conditional permissions, identity alignment with existing enterprise systems, lineage tracking, and permission control through familiar identity governance. **Defender** monitors for identity-based threats and contributes agent inventory and attack-path context. **Purview** enforces data governance based on agent access and behavior. **Agent 365 consolidates all three into one dashboard.** |

### Defense in depth

Agent Management is the **primary enforcement point for agent types whose traffic never touches your gateway or Foundry**. The worked example: **Microsoft Copilot agents** — their traffic doesn't traverse your gateway or Foundry, so those controls can't apply out of the box, but **Agent 365 together with Defender enforces it**, on top of Copilot's own native protections.

**Same risk, multiple enforcement points — if one control can't apply or is bypassed, another does.**

### Where it earns its keep

The moment agents act **autonomously** on the state of the business — Frontier pillar 3, *Reshape business processes* — Agent Management becomes critical: **whose identity, who owns it, can I revoke it.** Same controls, higher stakes.

---

## Ownership & outcomes

| | |
|---|---|
| **Accountable** | **IAM** *(identity, lifecycle & inventory)* · **AI Engineering** *(register & own)* · **Security** *(behavioural insight)* |
| **The question it answers** | *"When an agent acts, whose identity is it using, who owns it, what can it touch, and can I see it and revoke it?"* |
| **What you gain** | Every agent becomes a first-class, owned, **least-privilege** enterprise identity with full inventory and behavioural visibility — **closing the shadow-agent gap before it appears**. |
| **The advantage** | **Every agent owned and accountable.** First-class identities give each agent a clear owner, lifecycle, and audit trail — **no orphaned or shadow agents across the estate**. |

**Key RACI rows** *(full matrix in [Organizational Alignment & Ownership](organizational-alignment.md))*

| # | Decision | Accountable | Responsible |
|---|----------|-------------|-------------|
| 3.1 | Issue & govern agent identities | **IAM** | AI Eng |
| 3.2 | Agent lifecycle & ownership | **IAM** | AI Eng |
| 3.3 | Agent inventory & behavioural insight | **IAM** | Security |

**IAM is accountable across all three activities.** AI Engineering is responsible for **registering its agents and being the named sponsor**. Security is responsible for the **behavioural and threat insight** that Agent 365 surfaces.

> **Who should own agent identity? The team that owns user identity today.** That is the whole logic of extending existing infrastructure rather than standing up a parallel one.

---

## Activation

**Track 3 — Agent Management**

| Stage | Activity |
|-------|----------|
| **Deep Dive** | **Microsoft Agent 365** — agent management, ownership & lifecycle; design the **agent blueprints** and policy templates |
| **Proof of Value** | **Govern Agents PoV** — register, activate, monitor & retire real agents, proving visibility and control |
| **Production** | **Scale Identities** — safely and consistently across the organization |

**Activate — no infrastructure to provision.** Agent 365 requires **no landing zone**.

**Exit criteria**

- [ ] Audit logs enabled; Defender connector configured; sensitivity labels published
- [ ] Agent blueprints and policy templates defined and approved
- [ ] Every published agent carries a unique Entra Agent ID with a **named sponsor**
- [ ] Agent settings configured — allowed agent types, sharing, user access, catalog visibility
- [ ] Publish / activate / deploy approval gates operating
- [ ] Shadow-agent detection running; discovered agents triaged
- [ ] Lifecycle rules live — expire inactive, flag ownerless, block risky, auto-revoke on owner departure
- [ ] Conditional access policies targeting agent identities
- [ ] Non-Microsoft agents registered via the Agent 365 SDK
- [ ] Authoritative inventory and agent map visible in the Agent 365 dashboard
- [ ] Revocation tested — block in Agent 365, disable the blueprint, **and** revoke the access contract at the gateway

➡️ Full track detail: [Technical Activation Paths](activation-paths.md)

### Resources

- Governing agent identities with Entra ID: <https://learn.microsoft.com/entra/id-governance/agent-id-governance-overview>
- Microsoft Entra Agent ID: <https://learn.microsoft.com/entra/agent-id/>
- Conditional Access for agent identities: <https://learn.microsoft.com/entra/identity/conditional-access/agent-id>
- Citadel end-to-end guidance: [AI Citadel Blueprint overview](index.md)

!!! note
    **Capability maturity moves quickly.** Several capabilities described here are in preview at the time of writing while others are generally available. **Verify current status on Microsoft Learn before committing to a delivery date** — do not promise a preview capability as production-ready.

---

## Related guidance

- [Overview — AI Citadel Blueprint](index.md)
- [Layer 1 · Governance Hub](layer-1-governance-hub.md)
- [Layer 2 · Agent Operations](layer-2-agent-operations.md)
- [Layer 4 · Security Foundation](layer-4-security-foundation.md) — what identity unlocks
- [Organizational Alignment & Ownership](organizational-alignment.md)
- [Technical Activation Paths](activation-paths.md)

---

<sub>AI Citadel Blueprint × Frontier Transformation · Microsoft · Global Black Belt</sub>
