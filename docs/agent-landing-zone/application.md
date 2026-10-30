<span id="configure-the-application"></span>

# Agent Application

Agent Application is the reference application included with Agent Landing Zone.
It brings together a chat interface, an agent orchestration service and optional
document processing. You can configure the supplied application or adapt its
components to your own requirements.

Start with [Deploy full stack](deploy-full-stack.md) to deploy the application.
The guides below explain how to configure, operate and extend it.

## How the components fit together

| Component | What it does |
| --- | --- |
| Agent App UI | Provides the web chat, sign-in, citations and conversation controls. |
| Agent App Orchestrator | Runs the selected agent strategy, calls the model and connects retrieval and tools. |
| Agent App Ingestion | Provides optional application-managed document processing and indexing. |

In the default topology, the UI runs in Azure Container Apps and the
orchestrator runs as a hosted agent in Microsoft Foundry. Foundry IQ manages
ingestion for the configured native Blob source. Deploy Agent App Ingestion
only when your chosen processing or conversation-upload workflow needs it.

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

Optional capabilities have their own prerequisites. Conversation history,
file uploads, additional channels and external tools are not all enabled by
the default deployment. Each guide explains what is supplied, what to configure
and where application development is needed.

<span id="choose-a-task"></span>
<span id="application-components"></span>

## Find your guide

<span id="agent-hosting"></span>
<span id="model-tools-and-knowledge-base"></span>

### Agents

Choose [where the agent runs](hosted-agents.md), select its
[strategy and prompts](agent-strategies.md), or connect
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
Preparing a shared document collection is different from uploading a file
to a conversation. Processing images inside a document also does not imply
support for direct image or voice input in chat.

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
[deployment runbook](deploy-full-stack.md). Do not run deployment hooks merely
to inspect a configuration value or execute a local test.
