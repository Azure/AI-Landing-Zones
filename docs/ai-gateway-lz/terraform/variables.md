# AI Citadel Governance Hub — Variable Reference

Comprehensive reference for all input variables exposed by the **root Terraform module** ([variables.tf](variables.tf)). These are the only variables consumers set directly (typically via [environments/dev.tfvars](environments/dev.tfvars) / [environments/prod.tfvars](environments/prod.tfvars)). Sub-module variables are wired from these root values in [main.tf](main.tf) and are noted per section when relevant.

> Legend — ★ = required, ☆ = optional with default, 🔒 = sensitive.

---

## Table of Contents

1. [Basic Configuration](#1-basic-configuration)
2. [Resource Naming](#2-resource-naming)
3. [Security / Key Vault](#3-security--key-vault)
4. [Networking](#4-networking)
5. [Compute SKU & Sizing](#5-compute-sku--sizing)
6. [Feature Flags](#6-feature-flags)
7. [Log Analytics Strategy](#7-log-analytics-strategy)
8. [Network Access Settings](#8-network-access-settings)
9. [Entra ID Authentication](#9-entra-id-authentication)
10. [AI Foundry](#10-ai-foundry)
11. [LLM Backend Routing](#11-llm-backend-routing)
12. [Diagnostic Logging](#12-diagnostic-logging)
13. [Redis (Azure Managed Redis)](#13-redis-azure-managed-redis)
14. [Optional APIM Extra APIs](#14-optional-apim-extra-apis)
15. [API Center](#15-api-center)
16. [AI Search Instances](#16-ai-search-instances)
17. [Azure Monitor Private Link](#17-azure-monitor-private-link)
18. [Foundry Embeddings](#18-foundry-embeddings)
19. [Logic App Content Share](#19-logic-app-content-share)
20. [APIM Logic Plane (JWT / PII / MCP)](#20-apim-logic-plane-jwt--pii--mcp)
21. [Entra ID Add-On (App Registration)](#21-entra-id-add-on-app-registration)
22. [Foundry → APIM Connection](#22-foundry--apim-connection)
23. [Sub-Module Variable Map](#23-sub-module-variable-map)
24. [Outputs](#24-outputs)

---

## 1. Basic Configuration

| Variable | Type | Default | Notes |
|---|---|---|---|
| ★ `subscription_id` | string | — | Azure subscription for the deployment. |
| ☆ `environment_name` | string | `citadel-dev` | 3–24 lower-case alphanum/hyphen. Used in naming and tags. |
| ☆ `location` | string | `eastus` | Primary Azure region for the resource group. |
| ☆ `tags` | map(string) | `{}` | Merged with defaults (`azd-env-name`, `Solution`, `ManagedBy`). |
| ☆ `purge_soft_delete_on_destroy` | bool | `false` | If `true`, purges soft-deleted Key Vault / Cosmos on destroy (dev convenience). |

## 2. Resource Naming

Leave values empty (`""`) to auto-generate (`<prefix>-<resource_token>`).

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `resource_group_name` | string | `""` | Auto: `rg-<environment_name>`. |
| ☆ `use_existing_resource_group` | bool | `false` | `true` imports RG instead of creating. |
| ☆ `apim_service_name` | string | `""` | Auto: `apim-<token>`. |
| ☆ `cosmos_db_account_name` | string | `""` | Auto: `cosmos-<token>`. |
| ☆ `eventhub_namespace_name` | string | `""` | Auto: `evhns-<token>`. |
| ☆ `log_analytics_name` | string | `""` | Auto: `law-<token>`. |
| ☆ `key_vault_name` | string | `""` | Auto: `kv-<token>`. |

## 3. Security / Key Vault

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `soft_delete_retention_days` | number | `7` | 1–90. |
| ☆ `purge_protection_enabled` | bool | `true` | Prevents permanent deletion. |
| ☆ `rbac_authorization_enabled` | bool | `true` | RBAC vs access policies. |
| ☆ `network_acl_default_action` | string | `Deny` | `Allow` or `Deny`. |
| ☆ `kv_public_network_access_enabled` | bool | `false` | Enable public network access to Key Vault. |
| ☆ `kv_deployer_ip_rules` | list(string) | `[]` | Optional public IPs / CIDRs added to KV `network_acls.ip_rules`. Use to let a CI runner or admin workstation perform data-plane writes (secrets) when `network_acl_default_action = "Deny"`. Accepts `"203.0.113.4"` or `"203.0.113.0/24"`. **When non-empty, `public_network_access_enabled` is automatically forced to `true`** — Azure ignores `ip_rules` when public access is fully disabled. Default-action `Deny` still restricts traffic to the allowlist + private endpoints. Leave empty in production; prefer running Terraform from inside the VNet. |
| ☆ `kv_auto_detect_deployer_ip` | bool | `false` | When `true`, auto-detects the current public IP (via `https://api.ipify.org`) and appends `<ip>/32` to `kv_deployer_ip_rules`. Same auto-flip of `public_network_access_enabled` applies. Convenient for local bootstrap. Not recommended for CI with unstable egress IPs. |
| ☆ `create_apim_gateway_key_secret` | bool | `false` | When `true`, writes a placeholder `apim-gateway-key` secret (value `PLACEHOLDER-update-after-apim-deploy`) to Key Vault for optional downstream tooling. Nothing in this stack reads it; validation notebooks fetch the real key via `az apim subscription show`. Enabling it requires KV data-plane write access from the deployer IP (see `kv_deployer_ip_rules` / `kv_auto_detect_deployer_ip`) and is the most common cause of 403 `ForbiddenByFirewall` errors on first apply. |
| ☆ `key_vault_sku` | string | `standard` | `standard` or `premium`. |

## 4. Networking

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `use_existing_vnet` | bool | `false` | Brownfield mode. |
| ☆ `existing_vnet_rg` | string | `""` | Required when `use_existing_vnet=true`. |
| ☆ `vnet_name` | string | `""` | Existing VNet or name for new one. |
| ☆ `vnet_address_prefix` | string | `10.170.0.0/24` | Only for greenfield. |
| ☆ `apim_subnet_name` | string | `snet-citadel-apim` | |
| ☆ `apim_subnet_prefix` | string | `10.170.0.0/26` | |
| ☆ `private_endpoint_subnet_name` | string | `snet-citadel-pe` | |
| ☆ `private_endpoint_subnet_prefix` | string | `10.170.0.64/26` | |
| ☆ `logic_app_subnet_name` | string | `snet-citadel-functions` | |
| ☆ `logic_app_subnet_prefix` | string | `10.170.0.128/26` | |
| ☆ `enable_agent_subnet` | bool | `true` | Create a dedicated subnet for Foundry agent network injection. |
| ☆ `agent_subnet_name` | string | `snet-agents` | Agent subnet name. |
| ☆ `agent_subnet_prefix` | string | `10.170.0.192/26` | Agent subnet address prefix (for new VNet). |
| ☆ `apim_network_type` | string | `External` | `External`, `Internal`, or `None`. V1 SKUs only. |
| ☆ `apim_v2_use_private_endpoint` | bool | `true` | V2 SKUs: create private endpoint. |
| ☆ `apim_v2_public_network_access` | bool | `true` | V2 SKUs: allow public plane. |
| ☆ `dns_zone_rg` | string | `""` | Existing private DNS zones RG. |
| ☆ `dns_subscription_id` | string | `""` | Cross-sub DNS zones. |
| ☆ `existing_private_dns_zones` | map(string) | `{}` | Map zone→resource ID. |

## 5. Compute SKU & Sizing

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `apim_sku` | string | `StandardV2` | `Developer`, `StandardV2`, `Premium`, `PremiumV2`. **Region-constrained:** `StandardV2` / `PremiumV2` (v2 platform) are only available in a subset of regions — If your `location` doesn't support v2, use `Premium` (classic) which is globally available. Verify with `az apim list-skus --location <region>` or [API Management region availability](https://learn.microsoft.com/azure/api-management/api-management-region-availability). |
| ☆ `apim_sku_units` | number | `1` | Scale units. |
| ☆ `apim_publisher_email` | string | `admin@contoso.com` | |
| ☆ `apim_publisher_name` | string | `AI Citadel Admin` | |
| ☆ `cosmos_db_rus` | number | `400` | Provisioned RU/s. |
| ☆ `eventhub_capacity_units` | number | `1` | |
| ☆ `eventhub_partition_count` | number | `4` | |
| ☆ `eventhub_disaster_recovery_config` | object | `null` | `{partner_namespace_id, alias}` for geo-DR pairing. |
| ☆ `logic_app_sku_tier` | string | `WorkflowStandard` | |
| ☆ `logic_app_sku_size` | string | `WS1` | `WS1`/`WS2`/`WS3`. |
| ☆ `language_service_sku` | string | `S` | |
| ☆ `content_safety_sku` | string | `S0` | |
| ☆ `api_center_sku` | string | `Free` | |

## 6. Feature Flags

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `enable_api_center` | bool | `true` | Deploy API Center as AI Registry. |
| ☆ `enable_pii_redaction` | bool | `true` | Deploy Language Service. |
| ☆ `enable_content_safety` | bool | `true` | Deploy Content Safety. |
| ☆ `enable_redis_cache` | bool | `false` | Deploy Azure Managed Redis (semantic cache). |
| ☆ `create_app_insights_dashboards` | bool | `true` | App Insights dashboard JSON. |

## 7. Log Analytics Strategy

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `use_existing_log_analytics` | bool | `false` | BYO workspace. |
| ☆ `existing_log_analytics_id` | string | `""` | Full resource ID. |
| ☆ `existing_log_analytics_subscription_id` | string | `""` | Cross-sub LAW. |

## 8. Network Access Settings

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `cosmos_db_public_access` | string | `Disabled` | `Enabled`/`Disabled`. |
| ☆ `eventhub_network_access` | string | `Enabled` | Must be Enabled on first deploy. |
| ☆ `ai_foundry_external_access` | bool | `false` | |

## 9. Entra ID Authentication

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `entra_auth_enabled` | bool | `false` | Turn on JWT validation in APIM. |
| ☆ `entra_tenant_id` | string | `""` | |
| ☆ `entra_client_id` | string | `""` | Application (client) ID. |
| ☆ `entra_audience` | string | `""` | JWT `aud`. |
| ☆🔒 `entra_client_secret` | string | `""` | Persisted to Key Vault if set. |

## 10. AI Foundry

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `foundry_network_injection_enabled` | bool | `true` | Global default for injecting Foundry accounts into the VNet (agent subnet). Per-instance `network_injection_enabled` overrides this. |

### `ai_foundry_instances` (list of object)

```hcl
{
  name                      = optional(string, "")     # auto-generated if blank
  location                  = string                   # required
  custom_subdomain          = optional(string, "")
  default_project_name      = optional(string, "citadel-governance-project")
  network_injection_enabled = optional(bool, true)     # per-instance VNet injection override
}
```

### `ai_foundry_models` (list of object)

```hcl
{
  name             = string                       # e.g. "gpt-4o"
  publisher        = optional(string, "OpenAI")
  version          = string
  sku              = optional(string, "GlobalStandard")
  capacity         = optional(number, 100)
  ai_service_index = optional(number, 0)          # index into ai_foundry_instances
}
```

## 11. LLM Backend Routing

### Auto-derivation (default)

**No manual configuration required.** `llm_backend_config` defaults to `[]`, which triggers auto-derivation in [main.tf](main.tf) (`locals.auto_llm_backends`):

- One APIM backend per entry in `ai_foundry_instances` (Foundry is always deployed).
- `backend_id = "foundry-${location}-${index}"`, `priority = 1` for index `0` and `2` for subsequent, `auth_scheme = "managedIdentity"` (`auth_type = "managed-identity"`).
- `endpoint` sourced from `module.foundry.foundry_endpoints[i]` (late-bound; known after apply — no second-phase apply required).
- Models grouped by `ai_service_index`: every `ai_foundry_models` entry targeting instance `i` is attached to that instance's backend.

This produces a fully-routed gateway in a single `terraform apply`.

### `llm_backend_config` — full override (optional)

Populate ONLY when you need to replace the auto-derived list entirely (e.g. external Azure OpenAI, third-party LLM gateway, on-prem endpoint). Non-empty value takes full precedence; auto-derivation is skipped.

```hcl
{
  backend_id   = string                            # unique
  backend_type = string                            # "ai-foundry" | "azure-openai" | "external"
  endpoint     = string                            # https://...
  auth_scheme  = string                            # "managedIdentity" | "apiKey" | "token"
  auth_type    = optional(string)                  # "managed-identity"|"aws-sigv4"|"api-key-bearer"|"api-key-header"|"none"
  auth_config  = optional(object({                 # e.g. named value holding the key
    named_value_key = optional(string)
  }))
  priority     = optional(number, 1)
  weight       = optional(number, 100)
  supported_models = list(object({
    name                = string
    sku                 = optional(string, "Standard")
    capacity            = optional(number, 100)
    modelFormat         = optional(string, "OpenAI")
    modelVersion        = optional(string, "1")
    apiVersion          = optional(string, "2024-02-15-preview")
    timeout             = optional(number, 120)
    inferenceApiVersion = optional(string, "")
    retirementDate      = optional(string, "")
  }))
}
```

### `extra_llm_backends` — append to auto-derived list (optional)

Same object shape as `llm_backend_config` (including the optional `auth_type` / `auth_config` fields). Leave `llm_backend_config = []` and populate this to mix Foundry (auto) with external backends in the same gateway. Ignored when `llm_backend_config` is non-empty.

```hcl
extra_llm_backends = [
  {
    backend_id   = "external-aoai-0"
    backend_type = "azure-openai"
    endpoint     = "https://my-aoai-resource.openai.azure.com/"
    auth_scheme  = "apiKey"
    priority     = 2
    weight       = 100
    supported_models = [
      { name = "gpt-4.1", sku = "GlobalStandard", capacity = 100, modelFormat = "OpenAI", modelVersion = "2025-04-14" },
    ]
  },
]
```

## 12. Diagnostic Logging

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `apim_log_verbosity` | string | `information` | `verbose`/`information`/`error`. |
| ☆ `apim_log_body_bytes` | number | `8192` | Body bytes per log entry. |
| ☆ `azure_monitor_log_settings` | object | `{}` | `{enabled, log_request_body_bytes, log_response_body_bytes}`. |
| ☆ `app_insights_log_settings` | object | `{}` | + `sampling_percentage`. |

## 13. Redis (Azure Managed Redis)

Used only when `enable_redis_cache = true`.

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `redis_sku_name` | string | `Balanced_B10` | `Microsoft.Cache/redisEnterprise` SKU. |
| ☆ `redis_sku_capacity` | number | `2` | Only for `Enterprise_*`/`EnterpriseFlash_*`. |
| ☆ `redis_public_network_access` | string | `Disabled` | |
| ☆ `redis_minimum_tls_version` | string | `1.2` | |

## 14. Optional APIM Extra APIs

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `enable_ai_model_inference` | bool | `false` | Azure AI Model Inference API. |
| ☆ `enable_document_intelligence` | bool | `false` | Doc Intel legacy + v4. |
| ☆ `inference_api_type` | string | `OpenAIV1` | Universal LLM API inference contract. One of `AzureOpenAI`, `AzureAI`, `OpenAI`, `OpenAIV1`. |
| ☆ `enable_azure_ai_search` | bool | `false` | AI Search Index API. |
| ☆ `enable_openai_realtime` | bool | `false` | Realtime WebSocket API. |
| ☆ `enable_unified_ai_api` | bool | `false` | Wildcard Unified AI API. |
| ☆ `enable_ai_gateway_pii_redaction` | bool | `false` | PII redaction inside gateway. |
| ☆ `is_mcp_sample_deployed` | bool | `false` | Sample MCP API + weather backend. |

## 15. API Center

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `apic_location` | string | `""` | Override region if APIC not in primary. |
| ☆ `enable_api_center_onboarding` | bool | `false` | Register APIs in APIC. |

## 16. AI Search Instances

`ai_search_instances` — existing AI Search endpoints registered as APIM backends.

```hcl
[
  { name = "search1", endpoint = "https://...search.windows.net" }
]
```

## 17. Azure Monitor Private Link

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `use_azure_monitor_private_link_scope` | bool | `false` | Create AMPLS for private ingestion. |

## 18. Foundry Embeddings

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `primary_foundry_embedding_model_name` | string | `""` | For semantic-cache embeddings backend. |
| ☆ `enable_embeddings_backend` | bool | `false` | Register embeddings backend in APIM. |
| ☆ `embeddings_backend_url` | string | `""` | Used only when flag above is true. |

## 19. Logic App Content Share

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `logic_content_share_name` | string | `""` | `WEBSITE_CONTENTSHARE`; auto-derived if blank. |
| ☆ `enable_logic_app_code_deploy` | bool | `true` | Zip + publish the Logic App Standard workflows via `az functionapp deployment source config-zip` after infra is ready. Requires the `az` CLI on the deployer (no extra extension). The publish only runs when `logic_app_code_source_path` is non-empty. See [DEPLOYMENT_GUIDE.md §7.8](DEPLOYMENT_GUIDE.md#78-logic-app-workflow-code-on-by-default). |
| ☆ `logic_app_code_source_path` | string | `""` | Path to the Logic App Standard project folder to publish (the examples use `logicapp-src/usage-ingestion-logicapp`). **Blank disables the workflow-code publish** — there is no vendored fallback path. |

## 20. APIM Logic Plane (JWT / PII / MCP)

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `configure_circuit_breaker` | bool | `true` | Per-backend circuit breakers. |
| ☆ `enable_pii_anonymization` | bool | `true` | Policy fragments for PII redact/deanonymize. |
| ☆ `ms_learn_mcp_backend_url` | string | `https://learn.microsoft.com/api/mcp` | Only used when MCP sample is enabled. |
| ☆ `enable_jwt_auth` | bool | `false` | Populate JWT-* named values. |
| ☆ `jwt_tenant_id` | string | `""` | |
| ☆ `jwt_app_registration_id` | string | `""` | |
| ☆🔒 `pii_service_key` | string | `"replace-with-language-service-key-if-needed"` | Only when MI auth unavailable. |
| ☆ `azure_login_endpoint` | string | `https://login.microsoftonline.com/` | For sovereign clouds. |

## 21. Entra ID Add-On (App Registration)

Port of `entra-id-setup/setup.ps1`. When enabled, creates an app registration + SP + client secret and writes the secret to Key Vault. The generated `client_id`/`tenant_id` **overrides** `jwt_*` and populates APIM JWT named values.

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `enable_entra_id_setup` | bool | `false` | Master switch. |
| ☆ `entra_app_display_name_prefix` | string | `ai-citadel-gateway` | Suffixed with `environment_name`. |
| ☆ `entra_client_secret_name` | string | `ENTRA-APP-CLIENT-SECRET` | KV secret name. |
| ☆ `entra_client_secret_rotation_days` | number | `730` | Rotate after N days. |

## 22. Foundry → APIM Connection

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `enable_foundry_apim_connection` | bool | `false` | Dedicated APIM subscription + per-project connections. |

---

## 23. Sub-Module Variable Map

Sub-modules are not configured directly — their inputs are wired from root variables in [main.tf](main.tf). Only internals that extend root-level behavior are listed here.

### [modules/apim](modules/apim/variables.tf)
Consumes the full LLM/policy surface plus APIM-specific identity + eventhub wiring. All user-facing toggles (`enable_*`, `llm_backend_config`, `entra_*`, `jwt_*`, `configure_circuit_breaker`, MCP URLs, API-Center onboarding) flow through from root.

### [modules/networking](modules/networking/variables.tf)
Consumes `use_existing_vnet`, VNet/subnet names + prefixes, `apim_network_type`, DNS zone configuration, and the computed `is_apim_vnet` / `create_dns_zones` flags.

### [modules/security](modules/security/variables.tf)
Receives Key Vault naming/SKU, soft-delete/purge/RBAC toggles, tenant + deployer + MI object IDs, and Foundry principal IDs for RBAC grants.

### [modules/foundry](modules/foundry/variables.tf)
Receives `ai_foundry_instances` and `ai_foundry_models`, external-access flag, and APIM-connection parameters. Internally uses `enable_apim_connections`, `apim_connections` (per-API connection definitions), and `disable_key_auth`.

### [modules/ai-services](modules/ai-services/variables.tf)
Receives the `enable_pii_redaction`, `enable_content_safety`, and `enable_api_center` flags plus their SKUs and external-access toggles.

### [modules/monitoring](modules/monitoring/variables.tf)
Receives Log Analytics config (new vs existing), `create_dashboards`, and AMPLS settings (`use_azure_monitor_private_link_scope`, subnet/dns zone).

### [modules/cosmosdb](modules/cosmosdb/variables.tf)
Receives account name, `cosmos_db_rus` → `throughput_rus`, `cosmos_db_public_access`, subnet/dns wiring, and MI principal.

### [modules/eventhub](modules/eventhub/variables.tf)
Receives namespace name, capacity/partition sizing, `eventhub_network_access`, APIM + Logic App MI principals, and `disaster_recovery_config`.

### [modules/logic-app](modules/logic-app/variables.tf)
Consumes `logic_app_sku_tier`/`logic_app_sku_size`, Cosmos/Event Hub endpoints, MI trio, `logic_content_share_name`, PE subnet + DNS zones for the storage account, toggles for storage PEs / Cosmos role / azuremonitorlogs API connection, and the workflow-code publish inputs (`enable_code_deploy`, `code_source_path`) wired from the root `enable_logic_app_code_deploy` / `logic_app_code_source_path`.

### [modules/redis](modules/redis/variables.tf)
Mirrors all `redis_*` root variables plus `use_private_endpoint`, subnet + DNS zone.

### [modules/entra-id](modules/entra-id/variables.tf)
Mirrors `enable_entra_id_setup`, `entra_app_display_name_prefix`, `entra_client_secret_name`, `entra_client_secret_rotation_days`, and receives the Key Vault ID.

### [modules/access-contracts](modules/access-contracts/variables.tf)
Not wired from root in the current deployment; used as a standalone per-use-case onboarding module. Accepts `use_case`, `api_name_mapping`, `services[]`, and optional Key Vault / Foundry connection targets.

---

## 24. Outputs

Defined in [outputs.tf](outputs.tf). Read with `terraform output <name>` (add
`-raw` for a single scalar, `-json` for objects/lists).

| Output | Type | Notes |
|---|---|---|
| `resource_group_name` | string | Deployed resource group. |
| `location` | string | Primary region. Added for the validation notebooks. |
| `subscription_id` | string | Subscription of the deployment. Added for the validation notebooks. |
| `apim_name` | string | API Management service name. |
| `apim_gateway_url` | string | APIM gateway base URL. |
| `key_vault_name` | string | Key Vault name. Added for the validation notebooks. |
| `key_vault_uri` | string | Key Vault URI. |
| `cosmos_db_endpoint` / `cosmos_db_account_name` | string | Cosmos DB account. |
| `eventhub_namespace` / `event_hub_name` | string | Event Hub namespace + AI-usage hub. |
| `log_analytics_workspace_id` / `app_insights_name` | string | Monitoring resources. |
| `vnet_id` | string | Virtual network resource ID. |
| `ai_foundry_endpoints` | list(string) | Foundry account endpoints. |
| `ai_foundry_project_endpoints` | list(string) | Foundry project endpoints (one per account). |
| `ai_foundry_services` | list(object) | Foundry accounts in the azd `AI_FOUNDRY_SERVICES` shape (`cognitiveServiceName` + `foundryProjectEndpoint`). Added for the validation notebooks. |
| `llm_backend_config` | list(object) | Effective (auto-derived or overridden) APIM LLM backend config. Added for the validation notebooks. |
| `universal_llm_api_url` | string | `POST /models/chat/completions` endpoint. |
| `azure_openai_api_url` | string | Azure OpenAI compatible base URL. |
| `apim_managed_identity_client_id` / `..._principal_id` | string | APIM UAMI. |
| `usage_managed_identity_client_id` / `..._principal_id` | string | Logic App / usage UAMI. |

The `location`, `subscription_id`, `key_vault_name`, `ai_foundry_services`, and
`llm_backend_config` outputs are consumed by the validation notebooks via the
Terraform-output bridge in [shared/utils.py](shared/utils.py) (azd-var → output
alias map). See [validation/README.md](validation/README.md) and
[DEPLOYMENT_GUIDE.md §9.4](DEPLOYMENT_GUIDE.md#94-validation-notebooks-validation--shared).

---

**See also:** [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) · [NETWORKING.md](NETWORKING.md) · [README.md](README.md)