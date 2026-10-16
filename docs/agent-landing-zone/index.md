# Agent Landing Zone

Agent Landing Zone provides an Azure foundation for AI agents and a retrieval-augmented agent application. You can provision the foundation first and deploy the application later. The foundation uses Microsoft Foundry, Azure AI Search, Azure Container Apps, Azure App Configuration, Key Vault and Azure Monitor, with managed identities, scoped role assignments and optional private networking. Application Cosmos DB is provisioned when the selected topology needs it.

Source code: [Azure/agent-landing-zone](https://github.com/Azure/agent-landing-zone)

Deploying in your organization? Start with [Customer environments](customer-environments.md)
for repository ownership and customization, then follow the
[Azure DevOps walkthrough](azure-devops.md) for gated deployments across environments.

## Layers

Agent Landing Zone has two layers that you can deploy together or separately.

| Layer | What it contains | Deployed by |
| --- | --- | --- |
| Infrastructure | Foundry account and project, model deployments, Azure AI Search, Storage, Container Apps environment and placeholder apps, Container Registry, App Configuration, Key Vault and monitoring. Cosmos DB and private networking resources depend on the selected topology and parameters | `azd provision` |
| Application | The default agent application or your own application, described by an application definition | `azd deploy` |

For the classic topology, `azd up` runs both layers in sequence. The first deployment of the default hosted topology needs an image preparation step between two provisions. Follow the topology-specific commands in [Deploy full stack](deploy-full-stack.md#step-4-deploy).

## Default application

The default application includes Agent App UI and Agent App Orchestrator, with an optional Agent App Ingestion Container App. Each component lives in its own repository, and `manifest.json` pins the exact version that each release validates.

| Component | Role | Repository |
| --- | --- | --- |
| Agent App UI | Web chat front end | [Azure/agent-app-ui](https://github.com/Azure/agent-app-ui) |
| Agent App Orchestrator | Agent runtime that plans, retrieves and answers. Runs as a Foundry hosted agent by default, or as a Container App | [Azure/agent-app-orchestrator](https://github.com/Azure/agent-app-orchestrator) |
| Agent App Ingestion (optional) | Application-managed document ingestion into Azure AI Search | [Azure/agent-app-ingestion](https://github.com/Azure/agent-app-ingestion) |

Fresh environments default to `DEPLOY_INGESTION_CONTAINER_APP=false` for
supported, configured native Foundry IQ ingestion. Existing environments retain
their ingestion selection. Explicit custom definitions retain their declared
components. Ingestion selection is independent of classic or hosted
orchestration. UI chat, authentication and retrieval remain available without
the ingestion app, but chat attachment uploads require it and the existing
upload eligibility checks. Native ingestion handles configured Blob sources,
but is **not feature-equivalent** to the optional application.
See [Ingestion application selection](configuration.md#ingestion-application-selection)
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
source, including reviewed local changes. Use the platform release's exact
tree rather than substituting the upstream tag.

Ingestion-free deployments require the coordinated v4.3.0 / UI v3.3.0
combination. On v4.2.3 / UI v3.2.2, retain
`DEPLOY_INGESTION_CONTAINER_APP=true`: that UI does not gate attachment uploads.
See the [versioned compatibility requirements](configuration.md#ingestion-application-selection)
and [upgrade runbook](operations.md#upgrade-ingestion-selection-to-v430).

You can select your own application before the first provision. Custom definitions deploy their declared components, while provisioning currently retains the bundled foundation resources as well. See [Custom applications](build-your-own-app.md).

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
    The target region must offer the enabled services, and the subscription must have quota for the configured deployments. Preflight checks run before provisioning to identify unsupported regions and insufficient quota. A passing preflight does not guarantee that Azure can complete the deployment.

!!! note "Duration"
    Allow extra time for a first deployment, especially with network isolation. Resource provisioning, image builds, role propagation and private-link approval all affect the duration.
