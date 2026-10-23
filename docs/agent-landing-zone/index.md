# Agent Landing Zone

Agent Landing Zone provides a secure Azure foundation and the extensible
**Agent Application** built on Microsoft Foundry. Deploy the foundation on its
own, deploy it with the Agent Application, or bring your own application.

Source code: [Azure/agent-landing-zone](https://github.com/Azure/agent-landing-zone)

## Foundation and application

The template separates Azure resource provisioning from application deployment.
Deployment parameters and application selection determine what is created.

| Layer | What it contains | Deployed by |
| --- | --- | --- |
| Foundation | Azure resources, identities and service configuration selected by the deployment inputs | `azd provision` and its configuration hooks |
| Application | The selected application components and, for hosted orchestration, the agent version | `azd deploy` and its deployment hooks |

Start with [How it works](how-it-works.md) for the deployment flow and how to
set parameters. Then use [Deployment choices](planning.md) to choose a topology, tool and
resource footprint. Compare the shared
[foundation inventory](../bicep/deployed-resources.md) with your selected
topology and reuse settings to identify the resources in your deployment.

## Agent Application

The [Agent App Orchestrator](https://github.com/Azure/agent-app-orchestrator)
coordinates models, knowledge sources and configured tools through a selected
**orchestration strategy**. Extend its strategies and tools to implement your
workload's behavior. The [Agent App UI](https://github.com/Azure/agent-app-ui)
provides the conversational interface.

Use [Agent Application](application.md) for sign-in, document access,
grounding sources, agent tools and its UI.

```mermaid
flowchart LR
    user[User] <--> ui[Agent App UI]
    ui <--> orchestrator[Orchestrator and selected strategy]
    orchestrator --> models[Models]
    orchestrator --> tools[Configured tools]
    orchestrator --> knowledge[Knowledge sources]
```

### Strategies and hosting

A strategy determines how the agent uses models, obtains context and invokes
tools. Hosting determines where the orchestrator runs. These are separate
choices, and not every strategy supports both hosts.

| Hosting option | Execution model |
| --- | --- |
| Foundry hosted agent | The default for a fresh environment. Foundry Agent Service runs the orchestrator image with a supported strategy. |
| Azure Container Apps | Runs the orchestrator as a Container App, including strategies that are not yet supported by the hosted runtime. |

See [Agent hosting](hosted-agents.md) for supported strategies and the differences
in history, continuity and optional administration features.

### Knowledge ingestion

The optional [Agent App Ingestion](https://github.com/Azure/agent-app-ingestion)
provides application-managed document processing, including format-aware
chunking, embeddings and configured SharePoint ingestion. Native Foundry IQ can
instead ingest configured Blob sources without Agent App Ingestion.

Choose the path for the sources and features you need. Conversation attachments
require Agent App Ingestion and the UI's upload eligibility checks. SharePoint
requires its own connector and permissions. See [Ingestion choices](ingestion.md)
for the supported paths and their setup requirements.

## Choose your path

Review the design checklist, plan the deployment, then choose a deployment
runbook. [What's new](whats-new.md) covers recent changes.

| I want to | Guidance |
| --- | --- |
| Review architecture and security decisions | [Design checklist](../architecture/design-checklist.md) |
| Understand the deployment flow and how to set parameters | [How it works](how-it-works.md) |
| Choose standalone, hub integration or AI Gateway, and a deployment tool | [Deployment choices](planning.md) |
| Plan private connectivity, DNS and a connected runner | [Network isolation](network-isolation.md) |
| Size models, Search, compute and data services | [Sizing and capacity](sizing.md) |
| Estimate and control spending | [Cost planning](cost-planning.md) |
| Look up deployment inputs and runtime settings | [Configuration](configuration.md) |
| Provision a foundation without deploying application code | [Deploy infrastructure only](deploy-infra-only.md) |
| Deploy the foundation and Agent Application | [Deploy full stack](deploy-full-stack.md) |
| Put the web UI behind Application Gateway | [Application Gateway](application-gateway.md) |
| Reach private services from a workstation | [Private access over VPN](private-access.md) |
| Make a hosted agent available in Teams and Microsoft 365 Copilot | [Publish to Teams and M365](publish-to-teams.md) |
| Call a private Foundry agent from Copilot Studio | [Connect Copilot Studio](connect-copilot-studio.md) |
| Integrate my own application or modify a component | [Custom applications](build-your-own-app.md) |
| Configure the Agent Application and its knowledge sources | [Agent Application](application.md) |
| Evaluate foundation-only tools | [Terraform templates](../terraform/index.md) or [Deploy via portal](../portal/Readme.md). Neither runs the Agent Application lifecycle. |
| Automate deployments with Azure DevOps (optional) | [Deploy with Azure DevOps](azure-devops.md) |
| Diagnose a deployment or runtime problem | [Troubleshooting](troubleshooting.md) |
