# Deploy full stack

This guide deploys the infrastructure layer and the default application (Agent App UI, Agent App Orchestrator and Agent App Ingestion) into a new environment with public endpoints. For private networking, read this page and then [Network isolation](network-isolation.md).

## Prerequisites

**Azure permissions**

- **Owner**, or **Contributor** plus **User Access Administrator**, on the target subscription. The deployment creates role assignments for managed identities.
- Responsible AI terms accepted for Azure AI services in the subscription.
- Quota in the target region for the model deployments configured in `infra/main.parameters.json`.

**Tools**

| Tool | Notes |
| --- | --- |
| [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) | Latest version |
| [Azure CLI (`az`)](https://learn.microsoft.com/cli/azure/install-azure-cli) | Used by the lifecycle hooks |
| PowerShell 7 or Bash | Hooks run in PowerShell on Windows and in Bash on Linux and macOS |
| Git | Fetches the pinned application components |
| Python 3.12 | Runs the post-provision configuration |
| Docker (optional) | Builds images locally. Without Docker, images are built remotely in Azure Container Registry |

## Step 1: Get the code

```bash
azd init -t azure/agent-landing-zone
```

To pin a specific release, clone the repository at its tag instead:

```bash
git clone --branch v4.2.0 https://github.com/Azure/agent-landing-zone.git
cd agent-landing-zone
```

`infra/main.parameters.json` ships with the repository. You do not create or edit it; set parameters with `azd env set` instead (see [Configuration](configuration.md)).

## Step 2: Sign in and create an environment

```bash
az login
azd auth login
azd env new <environment-name>
azd env set AZURE_LOCATION <region>
azd env set NETWORK_ISOLATION false
```

## Step 3: Choose a topology

`DEPLOYMENT_TOPOLOGY` controls where the orchestrator runs.

| Value | Orchestrator | Administrative panel | Cosmos DB |
| --- | --- | --- | --- |
| `hosted-no-panel` (default for new environments) | Foundry hosted agent | Not deployed | Not deployed |
| `hosted-panel` | Foundry hosted agent | Deployed | Deployed |
| `classic` | Container App | Not applicable | Deployed |

```bash
azd env set DEPLOYMENT_TOPOLOGY classic
```

The legacy flags still work when `DEPLOYMENT_TOPOLOGY` is not set: `DEPLOY_HOSTED_AGENT_ORCHESTRATION=false` selects `classic`, and `DEPLOY_HOSTED_AGENT_ORCHESTRATION=true` with `DEPLOY_ADMINISTRATIVE_PANEL=true` selects `hosted-panel`. An explicit `DEPLOYMENT_TOPOLOGY` always wins.

## Step 4: Deploy

**Classic topology**

```bash
azd up
```

**Hosted topologies (`hosted-no-panel`, `hosted-panel`)**

The hosted agent needs an image digest before it can be created, so the first deployment has an extra preparation step:

```bash
azd provision
pwsh scripts/prepareHostedDeployment.ps1   # or: ./scripts/prepareHostedDeployment.sh
azd provision
azd deploy
```

See [Hosted agents](hosted-agents.md) for what each step does. Later deployments of the same environment only need `azd deploy`.

## What happens during the deployment

| Stage | Hook | What happens |
| --- | --- | --- |
| Preflight | `preprovision` | Checks that the region offers the required services and that quota is available. |
| Provision | — | Deploys the infrastructure from `infra/` (Bicep). |
| Post-provision | `postprovision` | Configures Foundry, Azure AI Search, Container Apps and role assignments, and publishes runtime settings to App Configuration with the label `agent-lz`. |
| Deploy | `predeploy` | Validates the environment, clones each component at the commit pinned in `manifest.json`, builds its image and deploys it. |

## Verify

1. Run `azd env get-value AZURE_RESOURCE_GROUP` and open the resource group in the Azure portal.
2. Open the Container App whose name ends with `frontend` and browse to its URL.
3. Upload a document to the `documents` container of the storage account. The ingestion component indexes it on its next run.
4. Ask a question about the document in the UI.

## Clean up

```bash
azd down --purge
```

This deletes the environment and all of its data.

## Next steps

- [Configuration](configuration.md)
- [Operations](operations.md)
- [Troubleshooting](troubleshooting.md)
