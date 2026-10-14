# Agent Landing Zone

Agent Landing Zone deploys a secure, production-ready Azure foundation for AI agents and, on top of it, an agent application. It provisions Azure AI Foundry, Azure AI Search, Azure Container Apps, Azure App Configuration, Key Vault, Cosmos DB and Azure Monitor with managed identities, least-privilege role assignments and optional private networking, and then deploys a retrieval-augmented agent application that is ready to use.

Source code: [Azure/agent-landing-zone](https://github.com/Azure/agent-landing-zone)

## Layers

Agent Landing Zone has two layers that you can deploy together or separately.

| Layer | What it contains | Deployed by |
| --- | --- | --- |
| Infrastructure | Foundry account and project, model deployments, Azure AI Search, Storage, Cosmos DB, Container Apps environment, Container Registry, App Configuration, Key Vault, Log Analytics, Application Insights and, with network isolation, the virtual network, private endpoints, firewall, Bastion and jumpbox | `azd provision` |
| Application | The default agent application or your own application, described by an application definition | `azd deploy` |

`azd up` runs both layers in sequence.

## Default application

The default application includes Agent App UI and Agent App Orchestrator, with an optional Agent App Ingestion Container App. Each component lives in its own repository, and `manifest.json` pins the exact version that each release validates.

| Component | Role | Repository |
| --- | --- | --- |
| Agent App UI | Web chat front end | [Azure/agent-app-ui](https://github.com/Azure/agent-app-ui) |
| Agent App Orchestrator | Agent runtime that plans, retrieves and answers. Runs as a Foundry hosted agent by default, or as a Container App | [Azure/agent-app-orchestrator](https://github.com/Azure/agent-app-orchestrator) |
| Agent App Ingestion (optional) | Application-managed document ingestion into Azure AI Search | [Azure/agent-app-ingestion](https://github.com/Azure/agent-app-ingestion) |

Fresh environments default to `DEPLOY_INGESTION_CONTAINER_APP=false` for
supported, configured native Foundry IQ ingestion. Existing environments retain
their ingestion selection; explicit custom definitions retain their declared
components. Ingestion selection is independent of classic or hosted
orchestration. UI chat, authentication and retrieval are retained; attachments
can require the optional app. Native ingestion is supported for
the configured source kinds, but is **not feature-equivalent** to the optional
application. See [Ingestion application selection](configuration.md#ingestion-application-selection)
before changing an existing deployment.

### v4.3.0 component combination

Agent Landing Zone **v4.3.0** coordinates optional ingestion, guarded private
Search readiness, shared-source permission options, Search region/quota
checks and opt-in firewall DNS proxy with **agent-app-ui v3.3.0**.
The component pins below come from the platform's `manifest.json`.

| Component | Version | Commit |
| --- | --- | --- |
| agent-app-ui | v3.3.0 | `858ed4205d866b7bfbff43ca9ed20ab812baa24e` |
| agent-app-orchestrator | v5.2.1 | `27f952fcf8d48a2ba6267c237ea6bea8361fedd2` |
| agent-app-ingestion | v3.1.1 | `72efd8d7d51e10d38bf8b89f03b7eb42e1ed8ff2` |
| infra / AI Landing Zone | v2.7.3 | `97e2375b89dcda4900d75aac9e7ffb7b20cce165` |

The infrastructure row records upstream provenance (`infra.source`), not a
separately deployed infrastructure package. The platform owns its `infra/`
source, including reviewed local changes; use the platform release's exact
tree rather than substituting the upstream tag.

Ingestion-free deployments require the coordinated v4.3.0 / UI v3.3.0
combination. On v4.2.3 / UI v3.2.2, retain
`DEPLOY_INGESTION_CONTAINER_APP=true`: that UI does not gate attachment uploads.
See the [versioned compatibility requirements](configuration.md#ingestion-application-selection)
and [upgrade runbook](operations.md#upgrade-ingestion-selection-to-v430).

You can replace this application with your own. See [Custom applications](build-your-own-app.md).

## Choose your path

| I want to | Go to |
| --- | --- |
| Deploy the infrastructure and the default application | [Deploy full stack](deploy-full-stack.md) |
| Deploy only the infrastructure and bring my own workload | [Deploy infra only](deploy-infra-only.md) |
| Deploy with private networking | [Network isolation](network-isolation.md) |
| Run the orchestrator as a Foundry hosted agent, or switch to Container Apps | [Hosted agents](hosted-agents.md) |
| Change parameters and runtime settings | [Configuration](configuration.md) |
| Deploy my own agent application | [Custom applications](build-your-own-app.md) |
| Understand what the Bicep templates deploy | [Deploy with Bicep](deploy-bicep.md) |
| Use Terraform | [Terraform implementation status](deploy-terraform.md) |
| Upgrade, redeploy, monitor or delete an environment | [Operations](operations.md) |
| Fix a failed deployment | [Troubleshooting](troubleshooting.md) |

## Before you start

!!! warning "Cost"
    The deployment creates billable resources, including Azure AI Search, Cosmos DB, Container Apps, model deployments and, with network isolation, Azure Firewall, Bastion and a virtual machine. Delete environments you no longer use with `azd down --purge`.

!!! note "Quota and region"
    The target region must offer every service in the deployment, and the subscription must have quota for the configured model deployments. A preflight check runs before provisioning and stops early when a service or quota is missing.

!!! note "Duration"
    A first deployment usually takes 30 to 60 minutes. Deployments with network isolation take longer because of the firewall, private endpoints and private DNS zones.
