# Agent Landing Zone

Agent Landing Zone provides **Azure infrastructure for agents** and the
**Agent Application**, a reference application built on Microsoft Foundry.
The infrastructure includes the selected networking, identities, AI services
and data stores. It can run the Agent Application or your own application.

An **agent** uses an AI model to answer questions and can call configured
tools. The supplied application provides web chat and can retrieve information
from connected knowledge sources.

Source code: [Azure/agent-landing-zone](https://github.com/Azure/agent-landing-zone)

## Get started

Follow [Deploy your first agent application](get-started.md) for your first installation.
The guide uses Bicep and the reference application with Hosted execution and
`conversational` mode. It creates a private standalone virtual network (VNet),
Azure Bastion and a jumpbox for initial access.

## Architecture overview

[![Standalone Agent Landing Zone reference architecture](../architecture/media/AI-Landing-Zone-without-platform.png?v=aa651551c880)](../architecture/media/AI-Landing-Zone-without-platform.png?v=aa651551c880)

<span id="foundation-and-application"></span>

## Infrastructure and application

Choose the outcome first, then the infrastructure provider.
Bicep is the default. Integrated Terraform uses the same azd
application lifecycle.

| Outcome | Bicep | Terraform |
| --- | --- | --- |
| **Deploy infra only:** create and configure Azure resources without application code | [Guide](deploy-infra-only.md) | [Guide](deploy-terraform-infra-only.md) |
| **Deploy full stack:** create infrastructure and deploy the Agent Application, including a Foundry hosted agent | [Guide](deploy-full-stack.md) | [Guide](deploy-terraform-full-stack.md) |

The default full-stack deployment runs the agent in **Foundry Agent Service**,
the Microsoft Foundry service that hosts and operates agents. A web chat
interface connects users to it. [Agent Application](application.md) explains
the components, knowledge sources and application behavior.

The planning and Agent Application pages explain infrastructure decisions
and application behavior respectively. **Reference** lists deployment inputs.
Execution steps stay together in **Deploy**, with prerequisites, commands,
validation and rollback.

## How the template works

The Azure Developer CLI (`azd`) coordinates the selected infrastructure
provider and the platform's service configuration. The workflow separates
preparing Azure resources from publishing application code.

Start a new project with
[`azd init --template Azure/agent-landing-zone .`](deploy-full-stack.md#step-1-initialize-the-project)
in a new empty project directory. Init prepares the template and local
environment, not Azure resources. Follow the selected provider's guide before
provisioning.

| Stage | What the template does |
| --- | --- |
| Inputs | Resolves the selected environment, target, network and resource choices. |
| Provision | Creates or reuses the selected infrastructure, configures services and prepares access. |
| Deploy | Builds or reuses images and publishes the selected application. |

An infrastructure-only deployment stops after resource provisioning and
service configuration. It does not publish application images or start a
hosted agent. Generic compute placeholders may exist until application deploy.
Reprovisioning preserves application images/revisions already published.

There is no extra application-deployment flag: use native `azd provision`
for the foundation and `azd deploy` for the application.
A full-stack deployment completes the application stage too.
The deployment guides provide the supported sequence and its checks.

For **another application instead of the reference UI/orchestrator**, select
[`AGENTLZ_APP_DEFINITION`](build-your-own-app.md#application-binding-and-selection)
before provision. Its composition declares the names, tools and dependencies;
the reusable foundation accepts generic compute, data, capability and role
inputs. Custom-only applications do not inherit reference MCP, SQL or catalogs.

<span id="choose-your-path"></span>
<span id="agent-application"></span>
<span id="strategies-and-hosting"></span>
<span id="knowledge-ingestion"></span>

## Where do I start?

- **Is this my first installation?** Follow the
  [Get started guide](get-started.md) to deploy the private application,
  configure sign-in, test a task and find its trace.
- **What does the template do?** Review the [deployment lifecycle](#how-the-template-works).
- **What needs planning?** Review [resources, networking and deployment tools](planning.md),
  then use the [Design checklist](../architecture/design-checklist.md) for architecture
  and security decisions.
- **How much capacity and budget are needed?** The
  [Sizing & cost planner](sizing-cost-planner.md) combines guidance, resource
  choices and editable estimates.
- **Do I only need Azure resources?** Deploy infra only
  [with&nbsp;Bicep](deploy-infra-only.md) or [with&nbsp;Terraform](deploy-terraform-infra-only.md).
- **Want the reference application?** Use [Bicep](deploy-full-stack.md) or
  [Terraform](deploy-terraform-full-stack.md) for the full stack.

For an existing environment, **Operate** brings together
[updates and recovery](deployment-operations.md) and
[troubleshooting](troubleshooting.md).
