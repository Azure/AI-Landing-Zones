# Deploy infra only

Use this path to provision the Agent Landing Zone foundation without building
or deploying application images. Resources depend on the selected topology
and parameters. Provisioning still creates the selected Container Apps with
placeholder images and prepares their identities and permissions.

Choose the application before the first provision, even if you plan to deploy
it later. The application ID is bound to the environment at provision time.

## Before you start

Complete the [prerequisites in Deploy full stack](deploy-full-stack.md#prerequisites). The tools, permissions and quota are the same.

## Steps

1. Get the template and sign in:

    ```bash
    git clone --branch v4.3.0 https://github.com/Azure/agent-landing-zone.git
    cd agent-landing-zone
    az login
    azd auth login
    ```

    [Prepare Python](deploy-full-stack.md#prepare-python) before continuing.

2. Create an environment and choose the network mode:

    ```bash
    azd env new <environment-name>
    azd env set AZURE_LOCATION <region>
    azd env set NETWORK_ISOLATION false
    ```

    For private networking, set `NETWORK_ISOLATION=true` and follow
    [Network isolation](network-isolation.md).

3. If you plan to deploy a custom application, select its definition now:

    ```bash
    azd env set AGENTLZ_APP_DEFINITION path/to/your-app/app-definition.json
    ```

    Skip this step to use the bundled application. See
    [Custom applications](build-your-own-app.md) for the definition format.

4. Provision the foundation:

    ```bash
    azd provision
    ```

`azd provision` validates and binds the application definition, runs preflight,
deploys the infrastructure, then configures the services in `postprovision`.
It publishes the platform outputs described below when post-provision
configuration completes. It does not build or deploy application images.
For isolated deployments, post-provision may be explicitly deferred until
you connect from a VNet-connected host.

## Platform outputs

Post-provision publishes platform outputs in Azure App Configuration as the
JSON key `AGENTLZ_PLATFORM_OUTPUTS` and matching flat keys, all with label
`agent-lz`. The publisher reads values from the azd environment. It does not
write the derived keys back into that environment. Search and Cosmos DB
sections are omitted when their endpoints are absent.

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
| `AGENTLZ_IDENTITY_<COMPONENT>_CLIENT_ID` | Client ID of each provisioned Container App component's managed identity, also listed in the JSON `identities` array. Hosted-agent instance identities are created at deployment, not foundation provision time. |

Without an explicit `AGENTLZ_COMPONENT_IDENTITIES` environment input, the publisher discovers the selected definition's provisioned Container Apps by their service tags and reads their actual identity client IDs. Missing or ambiguous identities fail publication. Principal IDs are not substituted for client IDs. An explicit JSON map remains an override input, not an automatically published flat key. User-assigned identities use ARM discovery. For system-assigned identities, resolving the client ID also requires reading the exact service principal in Microsoft Entra ID.

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

Deploy the same application definition selected before provisioning. The bundled
application includes Agent App UI and an orchestrator agent, with optional
Agent App Ingestion. Fresh environments use native Foundry IQ Blob ingestion
with `DEPLOY_INGESTION_CONTAINER_APP=false`. Existing environments keep their
selection. Choose ingestion before provisioning so the provisioned resources
and deployed components agree. See
[Ingestion application selection](configuration.md#ingestion-application-selection).

The application ID (`AGENTLZ_APP_ID`) is bound on the first provision.
Deploying a definition with a different ID fails the binding check.
Create a new environment for a different application.

Before activating an ingestion-free bundled application, complete the
[v4.3.0 / UI v3.3.0 migration](operations.md#upgrade-ingestion-selection-to-v430),
using the complete manifest-pinned combination. On
v4.2.3 / UI v3.2.2, retain `DEPLOY_INGESTION_CONTAINER_APP=true`.
that older UI does not gate attachment uploads on the new selection.
Native source ingestion is not a conversation upload implementation. See
the [versioned compatibility requirements](configuration.md#ingestion-application-selection).

For the bundled application in the classic topology, deploy it with:

```bash
azd deploy
```

For the bundled application's hosted topology, follow the preparation,
second provision and deploy steps in
[Deploy full stack](deploy-full-stack.md#step-4-deploy).
For a custom application, follow [Custom applications](build-your-own-app.md).

If you run `azd deploy` in an environment that has not been provisioned, it stops with:

```text
The foundation is not provisioned. Run azd provision first.
```

## Related pages

- [Network isolation](network-isolation.md)
- [Configuration](configuration.md)
- [Custom applications](build-your-own-app.md)
