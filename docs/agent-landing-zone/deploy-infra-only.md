# Deploy infra only

Use this path when you want the Agent Landing Zone foundation (networking, Microsoft Foundry, Azure AI Search, storage, Cosmos DB, App Configuration, Key Vault, Container Registry, Container Apps environment and monitoring) without deploying the default application. You can add the default application or your own application to the same environment later.

## Before you start

Complete the [prerequisites in Deploy full stack](deploy-full-stack.md#prerequisites). The tools, permissions and quota are the same.

## Steps

1. Get the template and sign in:

    ```bash
    azd init -t Azure/agent-landing-zone
    az login
    azd auth login
    ```

2. Create an environment and choose the network mode:

    ```bash
    azd env new <environment-name>
    azd env set NETWORK_ISOLATION false   # or true; see Network isolation
    ```

3. Provision the foundation:

    ```bash
    azd provision
    ```

`azd provision` runs the `preprovision` hook (preflight checks), deploys the infrastructure, then runs the `postprovision` hook, which configures the services and publishes the platform outputs described below. It does not build or deploy any application.

## Platform outputs

After provisioning, the foundation publishes a stable set of outputs that any application can consume in Azure App Configuration: the JSON key `AGENTLZ_PLATFORM_OUTPUTS` and its flat keys, all with label `agent-lz`. The publisher reads the foundation values from the azd environment; it does not write these derived keys back into that environment.

| Flat key | JSON path |
| --- | --- |
| `AGENTLZ_FOUNDRY_PROJECT_ENDPOINT` | `foundry.projectEndpoint` |
| `AGENTLZ_FOUNDRY_ACCOUNT_NAME` | `foundry.accountName` |
| `AGENTLZ_ACR_LOGIN_SERVER` | `registry.loginServer` |
| `AGENTLZ_APPCONFIG_ENDPOINT` | `appConfig.endpoint` |
| `AGENTLZ_SEARCH_ENDPOINT` | `search.endpoint` |
| `AGENTLZ_STORAGE_BLOB_ENDPOINT` | `storage.blobEndpoint` |
| `AGENTLZ_COSMOS_ENDPOINT` | `cosmos.endpoint` |
| `AGENTLZ_KEYVAULT_URI` | `keyVault.uri` |

Additional keys:

| Key | Meaning |
| --- | --- |
| `AGENTLZ_NETWORK_ISOLATED` | `true` when the foundation was deployed with private endpoints. |
| `AGENTLZ_IDENTITY_<COMPONENT>_CLIENT_ID` | Client ID of each provisioned Container App component's managed identity; also listed in the JSON `identities` array. Hosted-agent instance identities are created at deployment, not foundation provision time. |

Without an explicit `AGENTLZ_COMPONENT_IDENTITIES` environment input, the publisher discovers the selected definition's provisioned Container Apps by their service tags and reads their actual identity client IDs. Missing or ambiguous identities fail publication; principal IDs are not substituted for client IDs. An explicit JSON map remains an override input, not an automatically published flat key. User-assigned identities use ARM discovery. For system-assigned identities, resolving the client ID also requires reading the exact service principal in Microsoft Entra ID.

Read the outputs from App Configuration:

```bash
az appconfig kv show \
  --endpoint <app-configuration-endpoint> \
  --key AGENTLZ_PLATFORM_OUTPUTS \
  --label agent-lz \
  --auth-mode login
```

If the outputs are missing or out of date (for example after a deferred post-provision on an isolated network), republish them from the repository root:

```bash
azd env refresh
python -m config.deployment.outputs
```

## Add an application later

The environment deploys one application. By default this is the application described in `app-definition.json` (Agent App UI, Agent App Orchestrator and Agent App Ingestion). To use another application, point `AGENTLZ_APP_DEFINITION` at its definition file before the first deployment; see [Custom applications](build-your-own-app.md).

The application identity (`AGENTLZ_APP_ID`) is bound to the environment on the first provision. Deploying a different application to the same environment fails the binding check; create a new environment instead.

To deploy the application:

```bash
azd deploy
```

If you run `azd deploy` in an environment that has not been provisioned, it stops with:

```text
The foundation is not provisioned. Run azd provision first.
```

## Related pages

- [Network isolation](network-isolation.md)
- [Configuration](configuration.md)
- [Custom applications](build-your-own-app.md)
