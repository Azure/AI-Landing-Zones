# Deploy the infrastructure only

You can deploy the platform without any application and add one later.

## Deploy

```bash
azd init -t azure/agent-landing-zone
az login
azd auth login
azd env set NETWORK_ISOLATION false
azd provision
```

`azd provision` runs preflight, provisioning, and post-provision configuration. It does not build or deploy application components.

## Platform outputs

After provisioning, the Agent Landing Zone publishes the platform outputs that an application needs. They are stored as one JSON document in the `azd` environment variable `AGENTLZ_PLATFORM_OUTPUTS`, validated against `contracts/platform-outputs-v1.schema.json`, and also exposed as flat keys:

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
| `AGENTLZ_NETWORK_ISOLATED` | `true` when the platform uses private networking |
| `AGENTLZ_IDENTITY_<COMPONENT>_CLIENT_ID` | Client ID of the managed identity created for each application component |
| `AGENTLZ_COMPONENT_IDENTITIES` | JSON map of all component identities |

To republish the outputs manually:

```bash
python -m config.deployment.outputs
```

Read them with `azd env get-values`.

## Add an application later

Run `azd deploy` to deploy the default application. To deploy your own, point `AGENTLZ_APP_DEFINITION` to an application definition file or folder (default: `app-definition.json`) and run `azd up`:

```bash
azd env set AGENTLZ_APP_DEFINITION ./my-app
azd up
```

See [Build your own application](build-your-own-app.md).

An environment hosts **one application**. `AGENTLZ_APP_ID` is bound on the first provision; to deploy a different application, create a new `azd` environment.

## Guard against a missing foundation

`azd deploy` checks that the foundation exists before it builds anything (`python -m config.deployment.outputs --check-foundation`). If `AZURE_RESOURCE_GROUP` or `APP_CONFIG_ENDPOINT` is missing, the deployment stops with:

```text
The foundation is not provisioned. Run azd provision first.
```
