# Agent Landing Zone (azd accelerator)

The **Agent Landing Zone** is an `azd` accelerator built on the AI Landing Zones reference architecture. One template deploys two layers:

- the **infrastructure layer** (the platform), from the Bicep implementation of AI Landing Zones;
- an optional **application layer**, made of agent and retrieval components that run on that platform.

Source repository: [Azure/agent-landing-zone](https://github.com/Azure/agent-landing-zone).

!!! note "Formerly GPT-RAG"
    The Agent Landing Zone was previously published as **GPT-RAG**. Starting with v4.0.0 every resource, component, configuration label, and repository uses the Agent Landing Zone naming. v4.0.0 supports **new deployments only**; there is no in-place upgrade from a GPT-RAG v3 environment. See [Operations](operations.md#upgrading).

## Layers

| Layer | What it contains | How you deploy it |
| --- | --- | --- |
| Infrastructure | Microsoft Foundry account and project, model deployments, Azure AI Search, Storage, Cosmos DB, Key Vault, App Configuration, Container Registry, Container Apps environment, monitoring, and, when network isolation is on, the virtual network, private endpoints, jumpbox, and Bastion | `azd provision` |
| Application | Container Apps and, optionally, a Foundry hosted agent, described by an application definition | `azd deploy` |

`azd up` runs both. You can also deploy the infrastructure alone and add an application later. See [Deploy the infrastructure only](deploy-infra-only.md).

## Default application

When you do not supply your own application definition, the accelerator deploys three components:

| Component | Repository | Role |
| --- | --- | --- |
| `agent-app-ui` | [Azure/agent-app-ui](https://github.com/Azure/agent-app-ui) | Web chat front end |
| `agent-app-orchestrator` | [Azure/agent-app-orchestrator](https://github.com/Azure/agent-app-orchestrator) | Agent orchestration, retrieval, and tool calls. Runs as a Container App or as a Foundry hosted agent |
| `agent-app-ingestion` | [Azure/agent-app-ingestion](https://github.com/Azure/agent-app-ingestion) | Document ingestion, chunking, and indexing |

The exact versions of each release are pinned in `manifest.json` in the accelerator repository and listed in each [GitHub Release](https://github.com/Azure/agent-landing-zone/releases).

## Choose a path

| I want to | Read |
| --- | --- |
| Deploy the platform and the default application in one step | [Deploy the full stack](deploy-full-stack.md) |
| Deploy only the platform | [Deploy the infrastructure only](deploy-infra-only.md) |
| Run the orchestrator as a Foundry hosted agent | [Hosted agents](hosted-agents.md) |
| Deploy with private networking | [Network isolation](network-isolation.md) |
| Deploy my own application on the platform | [Build your own application](build-your-own-app.md) |
| Change parameters or runtime settings | [Configuration](configuration.md) |
| Upgrade, redeploy, monitor, or remove | [Operations](operations.md) |
| Fix a failed deployment | [Troubleshooting](troubleshooting.md) |
| Understand the Bicep source of `infra/` | [Deploy with Bicep](deploy-bicep.md) |
| Use the Terraform implementation instead | [Deploy with Terraform](deploy-terraform.md) |
