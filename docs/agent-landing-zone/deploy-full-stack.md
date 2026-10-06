# Deploy the full stack

This guide deploys the infrastructure layer and the default application (`agent-app-ui`, `agent-app-orchestrator`, `agent-app-ingestion`) with a single `azd up`.

## Prerequisites

**Azure permissions**

- **Contributor** and **User Access Administrator** (or **Owner**) on the target subscription or resource group. The deployment creates role assignments for managed identities.
- The Responsible AI terms accepted for Azure AI services in the subscription.
- Model quota in the target region for the model deployments configured in `infra/main.parameters.json`.

**Tools**

| Tool | Notes |
| --- | --- |
| [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) | Latest version |
| [Azure CLI (`az`)](https://learn.microsoft.com/cli/azure/install-azure-cli) | Used by the lifecycle hooks |
| PowerShell 7 or Bash | Hooks run in PowerShell on Windows and Bash on Linux and macOS |
| Git | Used to fetch the pinned application components |
| Python 3.12 | Used by the post-provision configuration |

Docker is not required: container images are built in Azure Container Registry with ACR Tasks.

## Deploy

```bash
azd init -t azure/agent-landing-zone
az login
azd auth login
azd env set NETWORK_ISOLATION false
azd up
```

`azd up` asks for the environment name, subscription, and region. `infra/main.parameters.json` ships with the template; you do not create it.

To deploy with private networking, set `NETWORK_ISOLATION true` and follow [Network isolation](network-isolation.md).

## What `azd up` does

| Stage | What happens |
| --- | --- |
| Preflight | Checks region availability and quota for the selected services. Set `AGENTLZ_REGIONAL_PREFLIGHT_SKIP=true` to skip it. |
| Provision | Deploys the infrastructure layer from `infra/` (Bicep). |
| Post-provision | Configures Foundry, Azure AI Search, Container Apps, and role assignments, and publishes runtime settings to Azure App Configuration with the label `agent-lz`. |
| Deploy | Builds each component image with ACR Tasks and deploys it to Container Apps or, for the hosted topology, to Foundry Agent Service. |

## Choose a topology

`DEPLOYMENT_TOPOLOGY` controls how the orchestrator runs:

| Value | Orchestrator | Administrative panel |
| --- | --- | --- |
| `hosted-no-panel` (default) | Foundry hosted agent | Not deployed |
| `hosted-panel` | Foundry hosted agent | Deployed |
| `classic` | Container App | Not applicable |

```bash
azd env set DEPLOYMENT_TOPOLOGY classic
```

The legacy flags `DEPLOY_HOSTED_AGENT_ORCHESTRATION` and `DEPLOY_ADMINISTRATIVE_PANEL` still work: hosted orchestration `false` selects `classic`; hosted `true` with the panel `true` selects `hosted-panel`. When `DEPLOYMENT_TOPOLOGY` is set, it takes precedence. See [Hosted agents](hosted-agents.md) for the hosted requirements.

## Verify

1. Run `azd show` and open the `agent-app-ui` endpoint.
2. Upload a document to the `documents` container of the storage account. The ingestion component indexes it on its next run.
3. Ask a question about the document in the UI.

## Next steps

- [Configuration](configuration.md)
- [Operations](operations.md)
- [Troubleshooting](troubleshooting.md)
