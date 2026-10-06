# Configuration

Configuration has two parts:

- **Deployment parameters** — `azd` environment variables read by `infra/main.parameters.json` at provision time.
- **Runtime settings** — keys in Azure App Configuration that the application components read at run time.

## Deployment parameters

Set a parameter with `azd env set <NAME> <value>` before `azd provision` or `azd up`.

### Required

| Variable | Notes |
| --- | --- |
| `AZURE_ENV_NAME` | Set by `azd` |
| `AZURE_LOCATION` | Primary region |
| `AZURE_AI_FOUNDRY_LOCATION` | Region for Foundry |
| `AZURE_COSMOS_LOCATION` | Region for Cosmos DB |
| `AZURE_PRINCIPAL_ID` | Set by `azd`; receives data-plane roles |
| `NETWORK_ISOLATION` | `true` or `false` |
| `USE_UAI` | Use user-assigned managed identities |
| `ENABLE_AGENTIC_RETRIEVAL` | Enable agentic retrieval |

### General

| Variable | Default | Notes |
| --- | --- | --- |
| `AZURE_PRINCIPAL_TYPE` | `User` | `ServicePrincipal` for pipelines |
| `DEPLOYMENT_MODE` | `standalone` | `ailz-integrated` attaches to an existing hub; see [Network isolation](network-isolation.md) |
| `RESOURCE_NAMING_MODE` | `caf` | `legacy` keeps the pre-v4 naming |
| `USE_CAPP_API_KEY` | `false` | |
| `APP_RUNTIME_CONFIGURATION_MODE` | `appConfig` | |
| `ENABLE_COSMOS_ANALYTICAL_STORAGE` | `false` | |
| `AZURE_SEARCH_LOCATION`, `AZURE_SPEECH_LOCATION` | empty | Defaults to `AZURE_LOCATION` |
| `AZURE_PE_LOCATION`, `AZURE_PE_RESOURCE_GROUP_NAME` | empty | Private endpoint placement |
| `EXISTING_*_RESOURCE_ID` | empty | Reuse existing resources |
| `EXISTING_APPLICATION_INSIGHTS_CONNECTION_STRING` | empty | |

### Retrieval and Foundry IQ

| Variable | Default |
| --- | --- |
| `RETRIEVAL_BACKEND` | `foundry_iq` |
| `FOUNDRY_IQ_PATTERN` | `azureBlob` |
| `FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND` | `azureBlob` |
| `FOUNDRY_IQ_API_VERSION` | `2026-05-01-preview` |
| `FOUNDRY_IQ_KNOWLEDGE_RETRIEVAL_BILLING_PLAN` | `free` |
| `KNOWLEDGE_BASE_NAME` | `knowledge-base` |
| `KNOWLEDGE_BASE_CONNECTION_NAME` | `knowledge-base-connection` |
| `FOUNDRY_IQ_KNOWLEDGE_SOURCE_NAME` | `knowledge-base-blob-ks` |
| `FOUNDRY_IQ_SEARCH_INDEX_NAME` | `agent-lz-index` |
| `FOUNDRY_IQ_SEMANTIC_CONFIGURATION_NAME` | `default` |
| `FOUNDRY_IQ_SECURITY_FIELD_NAME` | `metadata_security_id` |
| `FOUNDRY_IQ_STORAGE_CONTAINER_NAME` | `documents` |
| `FOUNDRY_IQ_IS_ADLS_GEN2` | `false` |
| `FOUNDRY_IQ_CONTENT_EXTRACTION_MODE` | `standard` |
| `FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS` | `["rbacScope"]` |
| `FOUNDRY_IQ_FILTER_ADD_ON_ENABLED` | `false` |

### Hosted agent

| Variable | Default |
| --- | --- |
| `DEPLOYMENT_TOPOLOGY` | `hosted-no-panel` |
| `DEPLOY_AAF_AGENT_SVC` | `true` |
| `PREPARE_HOSTED_AGENT` | `false` |
| `DEPLOY_HOSTED_AGENT` | `false` |
| `HOSTED_AGENT_NAME` | `agent-app-orchestrator` |
| `HOSTED_AGENT_IMAGE` | `agent-app-orchestrator` |
| `HOSTED_AGENT_CONTAINER_CPU` | `2` |
| `HOSTED_AGENT_CONTAINER_MEMORY` | `4Gi` |
| `HOSTED_AGENT_RESPONSES_PROTOCOL_VERSION` | `2.0.0` |
| `HOSTED_AGENT_INVOCATIONS_PROTOCOL_VERSION` | `1.0.0` |
| `HOSTED_CONVERSATION_OWNER_BINDING` | `delegated` |
| `HOSTED_CONVERSATION_CAPABILITY_KEY_ID` | `v1` |
| `HOSTED_CONVERSATION_CAPABILITY_TTL_SECONDS` | `900` |
| `HOSTED_HISTORY_MAX_ITEMS` | `100` |
| `HOSTED_HISTORY_MAX_TOKENS` | `32000` |

See [Hosted agents](hosted-agents.md) for the validation rules.

### Network and services

| Variable | Default | Notes |
| --- | --- | --- |
| `DEPLOY_AZURE_FIREWALL` | `true` | Only with isolation |
| `DEPLOY_ACR_TASK_AGENT_POOL` | `true` | The pool is created only when `NETWORK_ISOLATION=true` |
| `DEPLOY_JUMPBOX`, `DEPLOY_BASTION`, `DEPLOY_NAT_GATEWAY` | derived | Follow `NETWORK_ISOLATION` unless set |
| `BASTION_SKU_NAME` | `Standard` | |
| `BASTION_ENABLE_TUNNELING` | `false` | |
| `ENABLE_ACS_MEDIA_EGRESS` | `false` | |
| `HUB_INTEGRATION_EGRESS_NEXT_HOP_IP` | empty | `ailz-integrated` only |
| `HUB_INTEGRATION_EXISTING_ROUTE_TABLE_RESOURCE_ID` | empty | `ailz-integrated` only |
| `DEPLOY_GROUNDING_WITH_BING` | `false` | |
| `DEPLOY_KEY_VAULT` | `true` | |
| `DEPLOY_VM_KEY_VAULT` | `false` | |
| `DEPLOY_LOG_ANALYTICS` | `true` | |
| `ENABLE_PRIVATE_LOG_ANALYTICS` | `true` | |
| `ALLOW_MIXED_OBSERVABILITY_WORKSPACES` | `false` | |
| `DEPLOY_SEARCH_SERVICE` | `true` | |
| `DEPLOY_SPEECH_SERVICE` | `false` | |
| `SPEECH_SERVICE_SKU` | `S0` | |
| `DEPLOY_STORAGE_ACCOUNT` | `true` | |

### Lifecycle switches

| Variable | Effect |
| --- | --- |
| `AGENTLZ_REGIONAL_PREFLIGHT_SKIP` | `true` skips the regional preflight |
| `AGENTLZ_APP_DEFINITION` | Path of the application definition (default `app-definition.json`) |

## Runtime settings

Post-provision publishes runtime settings to Azure App Configuration with the label **`agent-lz`**. Components read `agent-lz` first and fall back to the legacy `gpt-rag` label, so settings written by earlier versions continue to work during the transition.

To change a runtime setting, edit the key in App Configuration (label `agent-lz`) and restart the affected Container App revision. To add settings for your own application, declare them in `settings[]` of the [application definition](build-your-own-app.md); secret settings are stored as Key Vault references.
