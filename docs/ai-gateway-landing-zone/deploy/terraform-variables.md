---
render_macros: false
---

# AI Citadel Governance Hub — Variable Reference

Comprehensive reference for all input variables exposed by the **root Terraform module** ([variables.tf](https://github.com/Azure/terraform-ai-gateway-landing-zone/blob/main/variables.tf)). These are the only variables consumers set directly (typically via environments/dev.tfvars / environments/prod.tfvars). Sub-module variables are wired from these root values in [main.tf](https://github.com/Azure/terraform-ai-gateway-landing-zone/blob/main/main.tf) and are noted per section when relevant.

> Legend — ★ = required, ☆ = optional with default, 🔒 = sensitive.

---

## Table of Contents

1. [Basic Configuration](#1-basic-configuration)
2. [Resource Naming](#2-resource-naming)
3. [Security / Key Vault](#3-security-key-vault)
4. [Networking](#4-networking)
5. [Compute SKU & Sizing](#5-compute-sku-sizing)
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
20. [APIM Logic Plane (JWT / PII / MCP)](#20-apim-logic-plane-jwt-pii-mcp)
21. [Entra ID Add-On (App Registration)](#21-entra-id-add-on-app-registration)
22. [Foundry → APIM Connection](#22-foundry-apim-connection)
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
| ☆ `apim_logger_credentials_in_key_vault` | bool | `true` | Stores the APIM logger credentials (App Insights connection string, managed identity client ID) as Key Vault secrets `apim-logger-*` (written through ARM) and points the loggers at Key Vault-backed named values, so APIM generates no secret `Logger-Credentials--*` named values (policy "API Management secret named values should be stored in Azure Key Vault"). Needs APIM to reach the vault (V2 SKU, `apim_network_type` External/Internal, or an open vault). See [Terraform deployment guide §9.5](terraform-deployment-guide.md#95-apim-logger-credentials-in-key-vault). |
| ☆ `key_vault_sku` | string | `standard` | `standard` or `premium`. |

## 4. Networking

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `use_existing_vnet` | bool | `false` | Brownfield mode. |
| ☆ `existing_vnet_rg` | string | `""` | Required when `use_existing_vnet=true`. |
| ☆ `vnet_name` | string | `""` | Existing VNet or name for new one. |
| ☆ `vnet_address_prefix` | string | `10.170.0.0/24` | Only for greenfield. |
| ☆ `apim_subnet_name` | string | `snet-citadel-apim` | V2 SKUs: dedicated to APIM outbound VNet integration and delegated to `Microsoft.Web/serverFarms` (automatic for a new VNet; with `use_existing_vnet=true` the subnet must already be empty and delegated). |
| ☆ `apim_subnet_prefix` | string | `10.170.0.0/26` | |
| ☆ `private_endpoint_subnet_name` | string | `snet-citadel-pe` | |
| ☆ `private_endpoint_subnet_prefix` | string | `10.170.0.64/26` | |
| ☆ `logic_app_subnet_name` | string | `snet-citadel-functions` | |
| ☆ `logic_app_subnet_prefix` | string | `10.170.0.128/26` | |
| ☆ `enable_agent_subnet` | bool | `true` | Create a dedicated subnet for Foundry agent network injection. |
| ☆ `agent_subnet_name` | string | `snet-agents` | Agent subnet name. |
| ☆ `agent_subnet_prefix` | string | `10.170.0.192/26` | Agent subnet address prefix (for new VNet). |
| ☆ `ase_subnet_name` | string | `snet-citadel-ase` | ASE v3 subnet; only used when `logic_app_hosting_model = "AppServiceEnvironmentV3"`. With `use_existing_vnet=true` it must already exist, be empty and be delegated to `Microsoft.Web/hostingEnvironments`. |
| ☆ `ase_subnet_prefix` | string | `10.170.1.0/24` | ASE v3 subnet prefix (new VNet). Min `/27`, `/24` recommended. Appended to the VNet as an extra address space when it is outside `vnet_address_prefix`. |
| ☆ `apim_network_type` | string | `External` | `External`, `Internal`, or `None`. V1 SKUs only. With `Internal`, per-hostname private DNS zones (`<apim>.azure-api.net`, `.portal`, `.developer`, `.management`, `.scm`) pointing at the APIM private IP are created and linked to the VNet (skipped when BYO DNS zones are used). Changing `External` ↔ `Internal` on an existing APIM forces **replacement** in the azurerm provider. |
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
| ☆ `logic_app_sku_size` | string | `WS1` | `WS1`/`WS2`/`WS3`. Used only with `logic_app_hosting_model = "WorkflowStandard"`. |
| ☆ `logic_app_hosting_model` | string | `WorkflowStandard` | `WorkflowStandard` (WS plan + regional VNet integration; storage account **must keep shared-key access** for the Azure Files content share) or `AppServiceEnvironmentV3` (Isolated v2 plan in a dedicated ASE v3; runtime storage via the usage UAMI, no content share, **shared-key access disabled**). See [Logic App hosting on ASE v3](#logic-app-hosting-on-ase-v3). |
| ☆ `logic_app_ase_sku_size` | string | `I1v2` | Isolated v2 SKU (`I1v2`–`I6v2`, `I1mv2`–`I5mv2`). ASE v3 only. |
| ☆ `logic_app_ase_worker_count` | number | `1` | Isolated v2 instance count. ASE v3 only. |
| ☆ `ase_internal_load_balancing_mode` | string | `Web, Publishing` | `Web, Publishing` = internal (ILB) ASE; `None` = external (public VIP). |
| ☆ `ase_zone_redundant` | bool | `false` | Zone-redundant ASE v3 (region must support AZs; raises minimum billed instances). |
| ☆ `ase_create_private_dns_zone` | bool | `true` | ILB ASE only: create `<ase>.appserviceenvironment.net` (`*`, `*.scm`, `@` → ILB IP) and link it to the VNet. Set `false` when DNS is centralised in a hub. |
| ☆ `language_service_sku` | string | `S` | |
| ☆ `content_safety_sku` | string | `S0` | |
| ☆ `api_center_sku` | string | `Free` | |

### Logic App hosting on ASE v3

Logic Apps Standard on the **Workflow Service Plan** (WS1/WS2/WS3) keeps its site content on an Azure Files share that is mounted with the storage account key, so [shared-key access cannot be disabled](https://learn.microsoft.com/azure/logic-apps/create-single-tenant-workflows-azure-portal#set-up-managed-identity-access-to-your-storage-account). Set `logic_app_hosting_model = "AppServiceEnvironmentV3"` when policy requires `allowSharedKeyAccess = false`. This mode:

- Creates a dedicated subnet `ase_subnet_name` / `ase_subnet_prefix`, delegated to `Microsoft.Web/hostingEnvironments`. The default `/24` VNet is full, so the ASE prefix (default `10.170.1.0/24`) is added as a second VNet address space.
- Deploys an App Service Environment v3 (internal by default), an Isolated v2 plan (`logic_app_ase_sku_size`) and, for ILB, the `<ase>.appserviceenvironment.net` private DNS zone.
- Deploys the Logic App via `azapi` (`Microsoft.Web/sites`, kind `functionapp,workflowapp`) because `azurerm_logic_app_standard` always requires a storage key. Runtime storage uses `AzureWebJobsStorage__*` identity settings with the usage UAMI; no content share is created and `shared_access_key_enabled = false`.
- The existing `snet-citadel-functions` subnet is kept but unused.

Things to plan for:

- **Cost:** an ASE v3 is billed for at least one Windows I1v2 instance even when empty, so it costs considerably more than WS1.
- **Duration:** first-time ASE creation is slow and can take an hour or more.
- **Code publish:** with an ILB ASE, `enable_logic_app_code_deploy` pushes the zip to `<app>.scm.<ase>.appserviceenvironment.net`, which is only reachable from inside the VNet. Run `terraform apply` from a VNet-connected agent.
- **Switching:** switching an existing deployment between hosting models replaces the App Service plan and the Logic App site. The storage account is kept and only its shared-key setting changes.
- **Cosmos DB:** independent of hosting model, the workflows' Cosmos DB connection uses the Logic App's managed identity and Cosmos key auth is off by default (`cosmos_db_local_auth_enabled`).

## 6. Feature Flags

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `enable_api_center` | bool | `true` | Deploy API Center as AI Registry. |
| ☆ `enable_pii_redaction` | bool | `true` | Deploy Language Service. |
| ☆ `enable_content_safety` | bool | `true` | Deploy Content Safety. |
| ☆ `enable_redis_cache` | bool | `false` | Deploy Azure Managed Redis and attach it as the APIM external cache (connection string in Key Vault, Key Vault-backed named value `redis-cache-connection-string`). With `enable_embeddings_backend`, turns the semantic cache on. See [Terraform deployment guide §9.6](terraform-deployment-guide.md#96-semantic-cache-azure-managed-redis). |
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
| ☆ `cosmos_db_local_auth_enabled` | bool | `false` | Key / connection-string auth on Cosmos DB. `false` = Entra ID (RBAC) only; the Logic App's Cosmos connection uses its system-assigned managed identity. Set `true` only if an external client (e.g. a Power BI report refreshed with the account key) still needs keys. |
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

**No manual configuration required.** `llm_backend_config` defaults to `[]`, which triggers auto-derivation in [main.tf](https://github.com/Azure/terraform-ai-gateway-landing-zone/blob/main/main.tf) (`locals.auto_llm_backends`):

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
| ☆ `primary_foundry_embedding_model_name` | string | `""` | Embeddings deployment on the primary Foundry account (must also be in `ai_foundry_models` with `ai_service_index = 0`); the embeddings backend URL is derived from it when `embeddings_backend_url` is empty. |
| ☆ `enable_embeddings_backend` | bool | `false` | Register the embeddings backend (`foundry-embeddings`) used by the semantic cache lookup. With `enable_redis_cache`, turns the semantic cache on (adds APIM's system-assigned identity + *Cognitive Services OpenAI User* on the Foundry accounts). |
| ☆ `embeddings_backend_url` | string | `""` | Full embeddings endpoint without a query string (e.g. `https://<account>.openai.azure.com/openai/deployments/<name>/embeddings`); overrides the derived one. An account outside this deployment needs *Cognitive Services OpenAI User* for APIM's system-assigned identity. |
| ☆ `semantic_cache` | object | `{}` | Tuning: `score_threshold` (0.05), `ttl_seconds` (300), `ignore_system_messages` (true), `max_message_count` (10). |

## 19. Logic App Content Share

| Variable | Type | Default | Notes |
|---|---|---|---|
| ☆ `logic_content_share_name` | string | `""` | `WEBSITE_CONTENTSHARE`; auto-derived if blank. Ignored with `logic_app_hosting_model = "AppServiceEnvironmentV3"` (no content share). |
| ☆ `enable_logic_app_code_deploy` | bool | `true` | Zip + publish the Logic App Standard workflows via `az functionapp deployment source config-zip` after infra is ready. Requires the `az` CLI on the deployer (no extra extension). The publish only runs when `logic_app_code_source_path` is non-empty. See [Terraform deployment guide §7.8](terraform-deployment-guide.md#78-logic-app-workflow-code-off-by-default). |
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
| ☆ `enable_foundry_apim_connection` | bool | `false` | Creates the dedicated `foundry-apim-connection` APIM subscription and, in every Foundry project, one `ApiManagement` connection per `foundry_apim_connections` entry (ApiKey = that subscription's key). |
| ☆ `foundry_apim_connections` | list(object) | Universal LLM API (`/models`, discovery via `/deployments`) | APIs exposed to Foundry projects. Fields mirror the Foundry connection metadata: `api_name`, `api_path`, `connection_name` (default `apim-<apim>-<api>`), `deployment_in_path`, `inference_api_version`, `list_models_endpoint` / `get_model_endpoint` / `deployment_provider` (dynamic discovery) or `static_models`, `custom_headers`. |

---

## 23. Sub-Module Variable Map

Sub-modules are not configured directly — their inputs are wired from root variables in [main.tf](https://github.com/Azure/terraform-ai-gateway-landing-zone/blob/main/main.tf). Only internals that extend root-level behavior are listed here.

### [modules/apim](https://github.com/Azure/terraform-ai-gateway-landing-zone/blob/main/modules/apim/variables.tf)
Consumes the full LLM/policy surface plus APIM-specific identity + eventhub wiring. All user-facing toggles (`enable_*`, `llm_backend_config`, `entra_*`, `jwt_*`, `configure_circuit_breaker`, MCP URLs, API-Center onboarding) flow through from root.

### [modules/networking](https://github.com/Azure/terraform-ai-gateway-landing-zone/blob/main/modules/networking/variables.tf)
Consumes `use_existing_vnet`, VNet/subnet names + prefixes, `apim_network_type`, DNS zone configuration, and the computed `is_apim_vnet` / `is_apim_v2` / `create_dns_zones` flags.

### [modules/security](https://github.com/Azure/terraform-ai-gateway-landing-zone/blob/main/modules/security/variables.tf)
Receives Key Vault naming/SKU, soft-delete/purge/RBAC toggles, tenant + deployer + MI object IDs, and Foundry principal IDs for RBAC grants.

### [modules/foundry](https://github.com/Azure/terraform-ai-gateway-landing-zone/blob/main/modules/foundry/variables.tf)
Receives `ai_foundry_instances` and `ai_foundry_models`, external-access flag, and APIM-connection parameters. Internally uses `enable_apim_connections`, `apim_connections` (per-API connection definitions), and `disable_key_auth`.

### modules/ai-services
Receives the `enable_pii_redaction`, `enable_content_safety`, and `enable_api_center` flags plus their SKUs and external-access toggles.

### [modules/monitoring](https://github.com/Azure/terraform-ai-gateway-landing-zone/blob/main/modules/monitoring/variables.tf)
Receives Log Analytics config (new vs existing), `create_dashboards`, and AMPLS settings (`use_azure_monitor_private_link_scope`, subnet/dns zone).

### [modules/cosmosdb](https://github.com/Azure/terraform-ai-gateway-landing-zone/blob/main/modules/cosmosdb/variables.tf)
Receives account name, `cosmos_db_rus` → `throughput_rus`, `cosmos_db_public_access`, `cosmos_db_local_auth_enabled` → `local_authentication_enabled`, subnet/dns wiring, and MI principal.

### [modules/eventhub](https://github.com/Azure/terraform-ai-gateway-landing-zone/blob/main/modules/eventhub/variables.tf)
Receives namespace name, capacity/partition sizing, `eventhub_network_access`, APIM + Logic App MI principals, and `disaster_recovery_config`.

### [modules/logic-app](https://github.com/Azure/terraform-ai-gateway-landing-zone/blob/main/modules/logic-app/variables.tf)
Consumes `logic_app_sku_tier`/`logic_app_sku_size`, the hosting model (`logic_app_hosting_model` → `hosting_model`, plus `logic_app_ase_*` / `ase_*` settings, `module.networking.ase_subnet_id` and `vnet_id`), Cosmos/Event Hub endpoints, MI trio, `logic_content_share_name` (WorkflowStandard only), PE subnet + DNS zones for the storage account, toggles for storage PEs / Cosmos role / azuremonitorlogs API connection, and the workflow-code publish inputs (`enable_code_deploy`, `code_source_path`) wired from the root `enable_logic_app_code_deploy` / `logic_app_code_source_path`.

### [modules/redis](https://github.com/Azure/terraform-ai-gateway-landing-zone/blob/main/modules/redis/variables.tf)
Mirrors all `redis_*` root variables plus `use_private_endpoint`, subnet + DNS zone.

### [modules/entra-id](https://github.com/Azure/terraform-ai-gateway-landing-zone/blob/main/modules/entra-id/variables.tf)
Mirrors `enable_entra_id_setup`, `entra_app_display_name_prefix`, `entra_client_secret_name`, `entra_client_secret_rotation_days`, and receives the Key Vault ID.

### [modules/access-contracts](https://github.com/Azure/terraform-ai-gateway-landing-zone/blob/main/modules/access-contracts/variables.tf)
Not wired from root in the current deployment; used as a standalone per-use-case onboarding module. Accepts `use_case`, `api_name_mapping`, `services[]`, and optional Key Vault / Foundry connection targets.

---

## 24. Outputs

Defined in [outputs.tf](https://github.com/Azure/terraform-ai-gateway-landing-zone/blob/main/outputs.tf). Read with `terraform output <name>` (add
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
Terraform-output bridge in [shared/utils.py](https://github.com/Azure/terraform-ai-gateway-landing-zone/blob/main/shared/utils.py) (azd-var → output
alias map). See [Terraform validation notebooks guide](../validation/notebooks-terraform.md) and
[Terraform deployment guide §9.4](terraform-deployment-guide.md#94-validation-notebooks-validation-shared).

---

**See also:** [Terraform deployment guide](terraform-deployment-guide.md) · [NETWORKING.md](../plan/network-approach.md) · [Terraform overview](terraform.md)
