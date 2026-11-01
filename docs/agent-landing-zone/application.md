<span id="configure-the-application"></span>

# Agent Application

Agent Application is the reference application included with Agent Landing Zone.
It brings together a Chainlit chat/process interface, native Microsoft Agent
Framework (MAF) execution and optional document processing. Use an Agent for
conversation or a Workflow for a published process with human input.

Start with [Deploy full stack](deploy-full-stack.md) to deploy the application.
The guides below explain how to configure, operate and extend it.

## How the components fit together

| Component | What it does |
| --- | --- |
| Agent App UI/BFF | Provides sign-in, chat/process presentation, owner mappings, product metadata and feedback. |
| Agent App Orchestrator | Runs native MAF Agents and Workflows, using the explicit integration for the selected host. |
| Agent App Ingestion | Provides optional application-managed document processing and indexing. |

## Default deployment

The default deployment has web chat in Azure Container Apps and an
orchestrator hosted in Microsoft Foundry, without an administrative panel.
The deployment setting calls this layout `hosted-no-panel`.
`APPLICATION_MODE` defaults to `conversational`. Native Hosted execution does
not require application-owned Cosmos DB; Foundry backing resources and
optional UI product storage are separate concerns.
Search, Foundry IQ, MCP, NL2SQL and multimodal tool flags default to off.
Preparing a source does not register a tool. History, feedback and private
attachments also default to off; conversational UI owner maps are then bounded
and volatile, not a restart-safe saved-session store.

Foundry IQ manages
ingestion for the configured native Blob source. Deploy Agent App Ingestion
only when a selected custom processing path needs it; it is disabled by
default. A private conversation attachment is not a shared source-ingestion
request. Hosting owns native execution state, not the UI's history discovery,
feedback or per-user document authorization.

## Application mode and host

`APPLICATION_MODE` selects `conversational`, `workflow` or `both`.
`ORCHESTRATION_HOST` selects `hosted` or `container_apps`.
These are deployment choices, not a user-facing strategy selector.

Hosted uses the official Responses integration and native persistence.
Container Apps uses the official Durable Extension worker/client and
Durable Task Scheduler. When both experiences use Hosted, conversation and
workflow are published as separate applications with separate endpoints.
See [Agent hosting](hosted-agents.md) and
[Workflows & human input](workflows.md).

The application repositories contain the code. These guides are the shared
documentation for all three components. The
[release manifest](https://github.com/Azure/agent-landing-zone/blob/main/manifest.json)
records their compatible versions.

<span id="capability-readiness"></span>

## Before you invite users

Deployment creates the selected resources, but connecting a source and signing
in do not by themselves prove that every user has the right document access.
Complete the [sign-in and access setup](application-auth.md), configure the
sources you need and check both allowed and denied access.

Optional capabilities have their own prerequisites. Saved history and feedback
default to off; a selected workflow declares UI metadata storage independently
of native execution state. Private attachments have an explicit feature gate,
an owner-bound inline native input path and their own retention requirements.
They are conversational only; transport support is not proof of model
PDF/image understanding.
Additional channels and external tools have separate integration requirements.

<span id="choose-a-task"></span>
<span id="application-components"></span>

## Find your guide

<span id="agent-hosting"></span>
<span id="model-tools-and-knowledge-base"></span>

### Agents

Choose [where execution runs](hosted-agents.md), configure
[agents and prompts](agent-strategies.md), operate
[workflows and human input](workflows.md), or connect
[tools and MCP servers](agent-tools.md). A tool lets an agent perform an
operation. Retrieval supplies information for its answer.

<span id="frontend"></span>

### Chat & channels

Configure [sign-in and access](application-auth.md),
[conversations and files](conversations.md), and [user feedback](user-feedback.md).
To reach users elsewhere, [embed chat in a portal](embed-chat.md),
[publish to Teams and Microsoft 365](publish-to-teams.md), or
[connect Copilot Studio](connect-copilot-studio.md).
These channels have different identity and network requirements. They do not
all use the web chat's session or sign-in flow.

<span id="grounding"></span>

### Knowledge & retrieval

Retrieval finds relevant information from your connected sources so that
the agent can use it in an answer. Start with [Foundry IQ](foundry-iq.md),
then follow the guide for [Work IQ](work-iq.md), [Fabric IQ](fabric-iq.md),
[SharePoint](sharepoint.md) or [structured data and NL2SQL](nl2sql.md).
These guides explain the available integration paths and their prerequisites.

<span id="ingestion"></span>
<span id="capabilities-and-extensions"></span>

### Document ingestion

Decide [when you need the ingestion service](ingestion.md), check
[document formats and image processing](multimodality.md), and configure
[jobs and schedules](ingestion-jobs.md).
Preparing a shared document collection is not private conversation input.
Shared ingestion does not enable private uploads. Processing images inside a
shared document also does not imply direct image or voice chat input.

### Operations

Change [application settings](application-settings.md), use the
[administrative panels](operations.md), and review
[monitoring and audit events](application-monitoring.md).
For failures, use [Troubleshooting](troubleshooting.md).

### AgentOps

Use the [AgentOps Accelerator](agentops.md) to evaluate, ship and operate
your workload on Agent Landing Zone.

### Development & customization

[Run the components locally](local-development.md),
[customize their behavior](customize-components.md), consult the
[API reference](application-api.md), and run the
[tests and quality checks](application-testing.md).
To replace the reference application, follow [Bring your own app](build-your-own-app.md).

## Know what you are changing

**Deployment settings** select resources, networking and which components are
deployed. They belong in the [deployment configuration](configuration.md).
**Application settings** control runtime behavior and normally live in Azure
App Configuration under the `agent-lz` label.
[Application settings](application-settings.md) explains how to change them
and when a reload or restart is required.

Keep deployment and redeployment steps in the
[deployment guide](deploy-full-stack.md). Do not run deployment hooks merely
to inspect a configuration value or execute a local test.
