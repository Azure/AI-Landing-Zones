# Agent Landing Zone

Agent Landing Zone provides **Azure infrastructure for agents** and the
**Agent Application**, a reference application built on Microsoft Foundry.
The infrastructure includes the selected networking, identities, AI services
and data stores. It can run the Agent Application or your own application.

An **agent** uses an AI model to answer questions and can call configured
tools. The supplied application provides web chat and can retrieve information
from connected knowledge sources.

Source code: [Azure/agent-landing-zone](https://github.com/Azure/agent-landing-zone)

## Architecture overview

[![Standalone Agent Landing Zone reference architecture](../architecture/media/AI-Landing-Zone-without-platform.png?v=aa651551c880)](../architecture/media/AI-Landing-Zone-without-platform.png?v=aa651551c880)

<span id="foundation-and-application"></span>

## Infrastructure and application

The deployment template creates Azure resources separately from the application
code that runs on them. Choose the outcome first, then the infrastructure
provider. Bicep is the default; integrated Terraform uses the same azd
application lifecycle.

| Outcome | With Bicep | With Terraform |
| --- | --- | --- |
| **Deploy infra only:** create and configure Azure resources without application code | [Runbook](deploy-infra-only.md) | [Runbook](deploy-terraform-infra-only.md) |
| **Deploy full stack:** create infrastructure and deploy the Agent Application, including a Foundry hosted agent | [Runbook](deploy-full-stack.md) | [Runbook](deploy-terraform-full-stack.md) |

The default full-stack deployment runs the agent in **Foundry Agent Service**,
the Microsoft Foundry service that hosts and operates agents. A web chat
interface connects users to it. [Agent Application](application.md) explains
the components, knowledge sources and application behavior.

The planning and Agent Application pages explain concepts and settings.
Execution steps stay together in **Deploy**, with prerequisites,
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
- **How much capacity and budget are needed?** The
  [Sizing & cost planner](sizing-cost-planner.md) combines guidance, resource
  choices and editable estimates.
- **Do I only need Azure resources?** Deploy infra only
  [with&nbsp;Bicep](deploy-infra-only.md) or [with&nbsp;Terraform](deploy-terraform-infra-only.md).
- **Do I want the supplied application running?** Deploy full stack
  [with&nbsp;Bicep](deploy-full-stack.md) or [with&nbsp;Terraform](deploy-terraform-full-stack.md).

For an existing environment, **Operate** brings together
[updates and recovery](deployment-operations.md) and
[troubleshooting](troubleshooting.md).
