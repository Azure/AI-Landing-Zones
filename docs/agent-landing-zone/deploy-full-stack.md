# Deploy full stack

This guide deploys the infrastructure layer and the default application (Agent App UI and Agent App Orchestrator, with an optional Agent App Ingestion Container App) into a new environment with public endpoints. For private networking, read this page and then [Network isolation](network-isolation.md).

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

### Choose ingestion independently

!!! warning "Do not activate the fresh default with the old UI pin"
    Ingestion-free deployments require the coordinated UI release and a
    validated umbrella pin update. The current UI v3.2.2 ignores the selection
    for attachments. Until that dependency is integrated, explicitly set
    `DEPLOY_INGESTION_CONTAINER_APP=true` before provisioning. These source
    changes do not imply that a new release has been published. See
    [Pinned UI compatibility](configuration.md#ingestion-application-selection).

Fresh environments default to `DEPLOY_INGESTION_CONTAINER_APP=false`.
The default `foundry_iq` / `azureBlob` configuration uses native ingestion
for the configured Blob source; it does not need the ingestion Container App.
Native ingestion does not provide every capability of Agent App Ingestion.
Check your source kind, retrieval backend, source/index bindings and required
ingestion features before choosing it.

To select the optional application before provisioning:

```bash
azd env set DEPLOY_INGESTION_CONTAINER_APP true
```

This choice works with both classic and hosted orchestration. It does not
switch the retrieval backend, rebind sources or indexes, or change UI
authentication. Existing environments keep their prior selection, and
explicit custom definitions keep their declared components. See
[Ingestion application selection](configuration.md#ingestion-application-selection).

With the coordinated UI gate, disabling ingestion disables attachment
controls and rejects stale/direct uploads before resolving an ingestion
endpoint; chat, authentication and retrieval remain available. Native source
ingestion does not implement conversation uploads. Select the optional app
when those uploads are required, subject to the existing eligibility checks.

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

If the second provision step reports insufficient quota for an unchanged
deployment that already exists in the same account, see
[Quota check rejects an unchanged existing deployment](troubleshooting.md#quota-check-rejects-an-unchanged-existing-deployment).
Do not bypass the quota gate to complete this sequence.

## What happens during the deployment

| Stage | Hook | What happens |
| --- | --- | --- |
| Application validation (`azd up`) | `preup` | Validates the selected definition and checks its environment binding before the deployment pipeline creates resources. |
| Preflight | `preprovision` | Checks that the region offers the required services and that quota is available. |
| Provision | — | Deploys the infrastructure from `infra/` (Bicep). |
| Post-provision | `postprovision` | Configures Foundry, Azure AI Search, Container Apps and role assignments, and publishes runtime settings to App Configuration with the label `agent-lz`. |
| Deploy | `predeploy` | Validates the environment, clones each selected component at the commit pinned in `manifest.json`, builds its image and deploys it. |

## Verify

1. Run `azd env get-value AZURE_RESOURCE_GROUP` and open the resource group in the Azure portal.
2. Open the Container App whose name ends with `frontend` and browse to its URL.
3. Upload a document to the configured source (`documents` for the default Blob configuration). Verify that the selected native or application-managed ingestion path has processed it; do not expect an ingestion Container App in a fresh native deployment.
4. Ask a question about the document in the UI, then verify document allow/deny behavior with the intended user identities. A successful answer alone does not prove authorization.

## Clean up

```bash
azd down --purge
```

This deletes the environment and all of its data.

## Next steps

- [Configuration](configuration.md)
- [Operations](operations.md)
- [Troubleshooting](troubleshooting.md)
