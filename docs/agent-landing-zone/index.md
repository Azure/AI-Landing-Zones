# Agent Landing Zone

Agent Landing Zone provides **Azure infrastructure for agents** and the
**Agent Application**, a reference application built on Microsoft Foundry.
The infrastructure includes the selected networking, identities, AI services
and data stores. It can run the Agent Application or your own application.

An **agent** uses an AI model to answer questions and can call configured
tools. The supplied application provides web chat and can retrieve information
from connected knowledge sources.

Source code: [Azure/agent-landing-zone](https://github.com/Azure/agent-landing-zone)

<span id="foundation-and-application"></span>

## Infrastructure and application

The deployment template creates Azure resources separately from the application
code that runs on them. This supports two deployment runbooks:

| Runbook | Result |
| --- | --- |
| [Deploy infra only](deploy-infra-only.md) | Creates and configures the selected Azure resources without deploying application code. |
| [Deploy full stack](deploy-full-stack.md) | Creates the infrastructure and deploys the Agent Application, including a Foundry hosted agent. |

The default full-stack deployment runs the agent in **Foundry Agent Service**,
the Microsoft Foundry service that hosts and operates agents. A web chat
interface connects users to it. [Agent Application](application.md) explains
the components, knowledge sources and application behavior.

The planning and Agent Application pages explain concepts and settings.
Execution steps stay together in the **Runbooks**, with prerequisites,
commands, validation and rollback.

<span id="choose-your-path"></span>
<span id="agent-application"></span>
<span id="strategies-and-hosting"></span>
<span id="knowledge-ingestion"></span>

## Where do I start?

- **What does the template do?** [How it works](how-it-works.md) introduces the
  deployment flow and explains where settings belong.
- **What needs planning?** [Deployment choices](planning.md) covers resources,
  network integration and deployment tools. The
  [Design checklist](../architecture/design-checklist.md) supports architecture
  and security review.
- **How much capacity and budget are needed?** [Sizing and capacity](sizing.md)
  and [Cost planning](cost-planning.md) describe the starting points.
- **Do I only need Azure resources?** [Deploy infra only](deploy-infra-only.md)
  provisions the infrastructure without deploying an application.
- **Do I want the supplied application running?** [Deploy full stack](deploy-full-stack.md)
  provisions the infrastructure and deploys the Agent Application.
