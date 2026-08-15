# Citadel Governance Hub - Testing & Validation Guide

## Executive Summary

This testing suite provides a comprehensive, end-to-end validation framework for the Citadel Governance Hub — an enterprise-grade AI gateway built on Azure API Management (APIM). The notebooks in this directory enable platform teams to onboard LLM backends, provision access contracts for different business units, test agent framework integrations, verify PII processing capabilities, validate JWT authentication with role-based access control, and test unified AI API routing patterns — all through guided, reproducible Jupyter workflows.

The recommended execution order is:

> **Strongly recommended baseline (steps 1–4):** these four notebooks together exercise the core gateway plumbing — backend onboarding, full model surface area, access-contract provisioning, and real-world agent consumption. Run them in order on every new Governance Hub deployment before moving on to the optional scenario-specific notebooks.

1. **Backend Contracts (LLM Onboarding)** — Register AI backends and deploy routing logic into APIM ⭐ *strongly recommended*
2. **Universal LLM API — All-Models Tests** — Validate every gateway-configured model (chat / embeddings / Responses API) through `/models` ⭐ *strongly recommended*
3. **Access Contracts** — Create per-team access contracts with Key Vault and Foundry integrations ⭐ *strongly recommended*
4. **Agent Frameworks** — Validate agent-based consumption of provisioned contracts (Microsoft Agent Framework, Foundry Agent SDK, LangChain) ⭐ *strongly recommended*
5. **Model Aliases** — Validate the shared `resolve-model-alias` policy fragment across all 3 LLM APIs (priority + weighted strategies, RBAC, discovery)
6. **PII Processing** — Test PII anonymization, deanonymization, and blocking policies
7. **Unified AI API** — Test multi-provider routing patterns through the Unified AI Wildcard API
8. **JWT Authentication** — Validate JWT-enforced and role-based access control across all API endpoints
9. **Extended Providers Backend Onboarding** — Onboard and validate non-Microsoft-Foundry AI backends (AWS Bedrock, GCP Gemini, Anthropic Claude) through native and OpenAI-compatible routing to confirm multi-cloud support
10. **Session Affinity** — Validate backend-pool sticky routing for the stateful OpenAI Responses API — a per-session cookie jar keeps all requests in a session pinned to the same backend
11. **Gateway Alerting** — Trigger real alerts: provision a restrictive access contract, force throttling (HTTP 429) *and* quota exhaustion (HTTP 403), deploy Azure Monitor metric alerts on the `AI Gateway Alert` custom metric, and verify the metrics + rules
12. **Publish Contract** — Publish three protected AI assets (API→MCP tool, remote MCP tool, Foundry A2A agent), then validate MCP handshakes, the A2A agent card + JSON-RPC call, `mcp-usage`/`a2a-usage` custom metrics, and per-asset circuit breakers

Each notebook is self-contained with initialization, deployment, testing, visualization, and cleanup stages, enabling both interactive exploration and repeatable validation.

---

## Prerequisites

> **First time running these notebooks?** Follow the [Validation Notebook Setup Guide](notebook-setup-guide.md) to create the repository's isolated `.venv`, install dependencies, select the correct VS Code kernel, and verify the notebook working directory.

Before running any notebook, ensure the following are in place:

- **Citadel Governance Hub** deployed ([Full Deployment Guide](../guides/full-deployment-guide.md) or [Quick Deployment Guide](../guides/quick-deployment-guide.md))
- **Azure CLI** installed and authenticated (`az login`)
- **Python 3.11** with the repository-root `.venv` selected as the notebook kernel
- **Dependencies** installed into `.venv` from the repository root (Windows PowerShell):
    ```powershell
    py -3.11 -m venv .venv
    .\.venv\Scripts\python.exe -m pip install --upgrade pip setuptools wheel
    .\.venv\Scripts\python.exe -m pip install -r .\validation\requirements.txt
    .\.venv\Scripts\python.exe -m pip install ipykernel
  ```
- **VS Code** with the Jupyter extension (recommended for running notebooks)

### Optional (per notebook)

| Capability | Required By | Details |
|---|---|---|
| Universal LLM API (`models`) imported in APIM | Universal LLM All-Models Tests, Model Aliases | Required for `/models` discovery and per-model operation tests |
| Azure Key Vault | Access Contracts, Agent Frameworks | A Key Vault with secrets for LLM endpoint and API key |
| Azure AI Foundry | Access Contracts, Agent Frameworks | A Foundry account and project for connection integration |
| Azure AI Language Service | PII Processing | PII detection endpoint with managed identity access |
| Event Hub | PII Processing | For PII state saving and audit logging |
| Unified AI API (`unified-ai`) imported in APIM | Unified AI API, Model Aliases (full coverage) | Required for the wildcard `/unified-ai/**` routing patterns |
| `resolve-model-alias` policy fragment + alias-aware backend onboarding | Model Aliases | Re-deployed by the notebook itself via the LLM backend onboarding Bicep with `modelAliases` populated |
| Entra ID App Registration | JWT Authentication | Client credentials (client ID + secret) with app roles configured |
| MSAL Library | JWT Authentication | Optional — for interactive device code flow token acquisition |
| Google Gemini API | Unified AI API | Optional — for testing Gemini routing pattern |
| Unified AI API (`unified-ai`) imported in APIM | Extended Providers Backend Onboarding | Required for native `/bedrock/**`, `/gemini/**`, and `/claude/**` routing |
| AWS Bedrock / GCP Gemini / Anthropic API keys | Extended Providers Backend Onboarding | Optional per provider — fill the `REPLACE_*` placeholders to enable each backend's tests |
| Azure Key Vault (provider secrets) | Extended Providers Backend Onboarding | Optional — recommended over inline secrets to hold non-Azure provider keys |
| Target model pooled across 2+ backends with `sessionAwareModel: true` | Session Affinity | Required — the notebook enables it for you by regenerating the LLM backend onboarding Bicep into a `-local.bicepparam` |
| Unified AI API (`unified-ai`) imported in APIM | Session Affinity | Required — the Responses API is called at `/unified-ai/openai/responses` |
| `openai`, `httpx`, `pandas` Python packages | Session Affinity | Installed via `../shared/requirements.txt` — used for the OpenAI SDK + per-session cookie jar + visualization |
---

## Initializing Variables from `azd` Environment

Every validation notebook supports a one-line **`init_from_azd = True`** toggle in its first code cell that auto-populates Citadel Governance Hub variables (resource group, location, Key Vault name, LLM backend config, Foundry account/project, Entra IDs, Cosmos account, …) directly from your active `azd` environment.

This is the recommended path when the accelerator was deployed with `azd up`, because the relevant deployment outputs (`AZURE_RESOURCE_GROUP`, `AZURE_LOCATION`, `LLM_BACKEND_CONFIG`, `KEY_VAULT_NAME`, `AI_FOUNDRY_SERVICES`, `ENTRA_*`, `COSMOS_DB_ACCOUNT_NAME`, …) are already written to the active `azd` env file by the Bicep deployment.

### How It Works

Each notebook's init cell follows the same pattern:

```python
init_from_azd = True   # Set False to fill REPLACE values manually below

# Manual fallbacks (used when azd env var is missing OR init_from_azd = False)
governance_hub_resource_group = "REPLACE"
location                      = "REPLACE"
# ... other notebook-specific REPLACE values ...

if init_from_azd:
    loaded = utils.load_azd_env({
        "resource_group": ["AZURE_RESOURCE_GROUP", "GOVERNANCE_HUB_RESOURCE_GROUP"],
        "location":       ["AZURE_LOCATION", "LOCATION"],
        # ... notebook-specific azd vars ...
    }, verbose=False)
    # Manually-set values (anything not equal to the REPLACE sentinel) win over azd values.
```

The shared helper [`utils.load_azd_env`](../shared/utils.py) in [`shared/utils.py`](../shared/utils.py) wraps `azd env get-value <NAME>` per variable, supports fallback name lists, and JSON-decodes complex values (`LLM_BACKEND_CONFIG`, `AI_FOUNDRY_SERVICES`).

### Pre-flight

```pwsh
# Make sure the right azd environment is selected
azd env list
azd env select <env-name>

# (Optional) inspect what will be auto-loaded
azd env get-values
```

> **Important:** Manually edited values (anything not equal to the `"REPLACE"` sentinel string in the init cell) **always win** over values pulled from `azd`. Set `init_from_azd = False` to disable the lookup entirely and force purely manual configuration.

### Per-Notebook Variable Map

The table below summarizes which `azd` env variables each notebook auto-loads when `init_from_azd = True`. Variables in *italics* are optional / only used when the notebook actually exercises the corresponding integration.

| Notebook | `azd` env variables auto-loaded → notebook variables |
|---|---|
| `llm-backend-onboarding-runner` | `AZURE_RESOURCE_GROUP` → `governance_hub_resource_group`<br>`AZURE_LOCATION` → `location`<br>`LLM_BACKEND_CONFIG` (JSON) → `llm_backends_config`<br>*`KEY_VAULT_NAME` → `key_vault_name`* |
| `citadel-universal-llm-api-all-models-tests` | `AZURE_RESOURCE_GROUP` → `governance_hub_resource_group`<br>`AZURE_LOCATION` → `location` |
| `citadel-access-contracts-tests` | `AZURE_RESOURCE_GROUP` → `governance_hub_resource_group`<br>`AZURE_LOCATION` → `location`<br>`AZURE_SUBSCRIPTION_ID` → `keyvault_subscription_id` / `foundry_subscription_id`<br>*`KEY_VAULT_NAME` → `keyvault_name`*<br>*`AI_FOUNDRY_SERVICES[0]` (JSON) → `foundry_account_name` + `foundry_project_name`* |
| `citadel-agent-frameworks-tests` | Same as `citadel-access-contracts-tests` |
| `citadel-model-aliases-tests` | `AZURE_RESOURCE_GROUP` → `governance_hub_resource_group`<br>`AZURE_LOCATION` → `location`<br>`LLM_BACKEND_CONFIG` (JSON) → `llm_backends_config` |
| `citadel-pii-processing-tests` | `AZURE_RESOURCE_GROUP` → `governance_hub_resource_group`<br>`AZURE_LOCATION` → `location`<br>*`COSMOS_DB_ACCOUNT_NAME` → `cosmos_account_endpoint`* |
| `citadel-unified-ai-api-tests` | `AZURE_RESOURCE_GROUP` → `governance_hub_resource_group`<br>`AZURE_LOCATION` → `location` |
| `citadel-jwt-authentication-tests` | `AZURE_RESOURCE_GROUP` → `governance_hub_resource_group`<br>`AZURE_LOCATION` → `location`<br>`AZURE_SUBSCRIPTION_ID` → `keyvault_subscription_id` / `foundry_subscription_id`<br>`ENTRA_TENANT_ID` → `entra_tenant_id`<br>`ENTRA_CLIENT_ID` → `entra_client_id`<br>`ENTRA_AUDIENCE` → `entra_audience` (defaults to `api://<client_id>` if missing)<br>*`KEY_VAULT_NAME` → `keyvault_name`*<br>*`AI_FOUNDRY_SERVICES[0]` (JSON) → `foundry_account_name` + `foundry_project_name`*<br>**Note:** `entra_client_secret` is intentionally **not** auto-loaded — set it manually before running JWT tests. |
| `llm-backend-onboarding-extended-providers-runner` | `AZURE_RESOURCE_GROUP` → `governance_hub_resource_group`<br>`AZURE_LOCATION` → `location`<br>`LLM_BACKEND_CONFIG` (JSON) → merged with the extended-provider backends in `llm_backends_config`<br>*`KEY_VAULT_NAME` → `key_vault_name`*<br>**Note:** `init_from_azd` defaults to **`False`** here so the in-notebook `REPLACE_*` provider placeholders are preserved; flip to `True` to merge your azd-maintained Foundry backends with the new providers. |
| `citadel-session-affinity-tests` | `AZURE_RESOURCE_GROUP` → `governance_hub_resource_group`<br>`AZURE_LOCATION` → `location`<br>`LLM_BACKEND_CONFIG` (JSON) → `llm_backends_config` (used to enable `sessionAwareModel` for the target model) |
| `citadel-alerting-tests` | `AZURE_RESOURCE_GROUP` → `governance_hub_resource_group`<br>`AZURE_LOCATION` → `location`<br>`AZURE_SUBSCRIPTION_ID` → `subscription_id`<br>*`APIM_APP_INSIGHTS_NAME` → `app_insights_name`* (auto-discovered from the hub RG if unset) |

> **Multi-environment teams:** Run `azd env select <env-name>` before launching the notebook to switch which deployment the notebook talks to. Each `.azure/<env-name>/.env` file is fully self-contained.

### When to Set `init_from_azd = False`

- You are validating a Citadel Governance Hub that was **not** deployed via `azd` (e.g. deployed via `az deployment sub create` directly, or via a CI/CD pipeline that doesn't write azd env vars).
- You want to point a notebook at a **different** environment than the currently selected `azd` env.
- You are running the notebook on a workstation where `azd` is not installed.

In any of these cases, set `init_from_azd = False` and fill the `REPLACE` values manually. The shared helpers (`utils.azd_env_get`, `utils.azd_env_get_json`, `utils.load_azd_env`) will silently no-op when `azd` isn't available, so leaving `init_from_azd = True` on a machine without `azd` is also harmless — it just won't override your manual values.

---

## Notebooks

### 1. LLM Backend Onboarding Runner

| | |
|---|---|
| **Notebook** | [`llm-backend-onboarding-runner.ipynb`](llm-backend-onboarding-runner.ipynb) |
| **Purpose** | Onboard AI backends into the Citadel Governance Hub and deploy routing logic |
| **Run this** | First — before any other notebook |

#### What It Does

This notebook automates the full lifecycle of registering LLM backends with your APIM gateway. It extracts the current backend configuration, generates a Bicep parameter file with per-model metadata (SKU, capacity, model format, version), deploys the backends and policy fragments, and verifies the deployment through multiple API formats.

#### Steps

| Step | Description |
|---|---|
| 0 | **Initialize variables** — Configure resource group, location, and backend endpoints |
| 1 | **Verify Azure CLI** — Confirm authentication and subscription context |
| 2 | **Initialize APIM Client** — Connect to the existing Governance Hub deployment |
| 3 | **Extract current backends** — Retrieve existing backend pools and routing configuration |
| 4 | **Discover managed identity** — Auto-detect the APIM user-assigned managed identity |
| 5 | **Generate parameter file** — Create a `.bicepparam` file with full backend definitions |
| 6 | **Deploy** — Run the Bicep deployment to create backends, pools, and policy fragments |
| 7 | **Verify deployment** — Confirm backends and policy fragments were created |
| 8 | **Verify GET /deployments** — Test the `get-available-models` policy fragment for Foundry integration |
| Test | **Test models** — Validate via Universal LLM API, Azure OpenAI API, Python SDK, and streaming |

#### Key Configuration

```python
governance_hub_resource_group = "REPLACE"  # Your Governance Hub resource group
location = "REPLACE"                       # e.g., "eastus", "swedencentral"

llm_backends_config = [
    {
        "backendId": "aif-citadel-primary",
        "backendType": "ai-foundry",           # 'ai-foundry' | 'azure-openai' | 'aws-bedrock' | 'gemini' | 'anthropic' | 'external'
        "endpoint": "https://...",
        "authType": "managed-identity",        # 'managed-identity' | 'aws-sigv4' | 'api-key-bearer' | 'api-key-header' | 'api-key-gemini' | 'api-key-anthropic' | 'none' (omit to derive from backendType)
        "supportedModels": [
            { "name": "gpt-4o", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-11-20" }
        ],
        "priority": 1,
        "weight": 100
    }
]
```

#### Output

- Deployed APIM backends with circuit breaker support
- Backend pools with priority/weight-based load balancing
- `set-backend-pools` and `get-available-models` policy fragments
- Verified model routing through both API formats

---

### 2. Universal LLM API — All-Models Tests

| | |
|---|---|
| **Notebook** | [`citadel-universal-llm-api-all-models-tests.ipynb`](citadel-universal-llm-api-all-models-tests.ipynb) |
| **Purpose** | Validate the Universal LLM API (`/models`) against every model exposed by the gateway |
| **Run this** | Immediately after backend onboarding to confirm the full model catalogue is reachable |

#### What It Does

This notebook provisions a single access contract with **`allowedModels = ""`** (no model restriction), then dynamically discovers the live model catalogue via `GET /models/models` and exercises the appropriate OpenAI v1 operation for each model. It is the fastest way to confirm that every onboarded backend pool is end-to-end reachable through the Universal LLM API surface.

#### Operations Exercised Per Model

| Model name pattern | Operations exercised |
|---|---|
| Contains `embedding` | `POST /models/embeddings` |
| Contains `gpt`       | `POST /models/chat/completions` **and** the full Responses API trio: `POST /models/responses`, `GET /models/responses/{response_id}`, `GET /models/responses/{response_id}/input_items?limit=20` |
| Anything else        | `POST /models/chat/completions` |

#### Steps

| Step | Description |
|---|---|
| 0 | **Initialize variables** — Configure resource group, location, API versions, and optional model cap |
| 1 | **Verify Azure CLI** — Confirm authentication and subscription context |
| 2 | **Initialize APIM Client** — Discover the Universal LLM API and supported models |
| 3 | **Provision access contract** — Deploy a Bicep-generated APIM product + subscription with `allowedModels = ""` and a generous capacity allocation |
| 4 | **Retrieve API key** — Get the subscription key for the unrestricted product |
| 5 | **Discover models** — Call `GET /models/models` to enumerate the live model catalogue |
| 6 | **Per-model operation loop** — Auto-classify each model and run chat / embeddings / Responses API operations |
| 7 | **Summary table** — Aggregate per-model pass/fail across all exercised operations |
| Cleanup | **Delete test products** — Optionally remove the unrestricted access contract |

#### Key Configuration

```python
governance_hub_resource_group = "REPLACE"
location                      = "REPLACE"

targetInferenceApi    = "models"               # Universal LLM API
inference_api_version = "2024-05-01-preview"
openai_api_version    = "2024-12-01-preview"

# 0 = test every discovered model; set a positive int to cap for quick smoke tests
max_models_to_test = 0

# Delay between POST /responses and the subsequent GET /responses/{id} calls
responses_get_delay_seconds = 0
```

#### Output

- One Bicep-deployed APIM product + subscription with no model RBAC restriction
- Live discovery of every gateway-configured model via `GET /models/models`
- Per-model results for chat, embeddings, and (where applicable) Responses API operations
- Summary table highlighting any model that failed an expected operation

---

### 3. Citadel Access Contracts Tests

| | |
|---|---|
| **Notebook** | [`citadel-access-contracts-tests.ipynb`](citadel-access-contracts-tests.ipynb) |
| **Purpose** | Create, deploy, and load-test multiple access contracts with different integration patterns |
| **Run this** | After backend onboarding and the Universal LLM all-models smoke test |

#### What It Does

This notebook provisions three distinct access contracts, each representing a different integration pattern. It generates the Bicep parameter files, deploys the contracts as APIM products with subscriptions, performs load testing, and visualizes throttling behavior and token bucket dynamics across all contracts.

#### Access Contracts Created

| Contract | Business Unit | Integration | Description |
|---|---|---|---|
| **Sales-Assistant** | Sales | Key Vault only | Secrets (endpoint + API key) resolved from Azure Key Vault |
| **HR-ChatAgent** | HR | Key Vault + Foundry | Optionally creates a Foundry project connection for agent integration |
| **Support-Bot** | Support | Direct output | No external integrations — uses direct APIM subscription output |

#### Steps

| Step | Description |
|---|---|
| 0 | **Initialize variables** — Configure resource group, Key Vault, and Foundry settings |
| 1 | **Verify Azure CLI** — Confirm authentication and subscription context |
| 2 | **Initialize APIM Client** — Discover APIs and supported models |
| 3 | **Define contracts** — Configure three access contracts with varying integration patterns |
| 4 | **Create parameter files** — Generate `.bicepparam` files with policy XML for each contract |
| 5 | **Deploy contracts** — Run Bicep deployments at subscription scope |
| 6 | **Retrieve API keys** — Extract subscription keys for each deployed product |
| 7 | **Load test** — Send concurrent API requests to each contract and record metrics |
| 8 | **Visualize results** — Compare success/throttled/error rates across contracts |
| 9 | **Token bucket analysis** — Simulate and visualize token bucket refill behavior |
| Cleanup | **Delete test products** — Optionally remove all created APIM products and subscriptions |

#### Key Configuration

```python
governance_hub_resource_group = "REPLACE"
location = "REPLACE"

# Optional integrations
use_keyvault_integration = True
keyvault_name = "REPLACE"

use_foundry_integration = True
foundry_account_name = "REPLACE"
foundry_project_name = "REPLACE"
```

#### Output

- Three deployed APIM products with subscription keys
- Key Vault secrets populated (if enabled)
- Foundry connection created (if enabled)
- Performance charts comparing all contracts
- Token bucket behavior visualization

---

### 4. Citadel Agent Frameworks Tests

| | |
|---|---|
| **Notebook** | [`citadel-agent-frameworks-tests.ipynb`](citadel-agent-frameworks-tests.ipynb) |
| **Purpose** | Validate real-world agent consumption of access contracts using three major frameworks |
| **Run this** | After access contracts are deployed (notebook 3) |

#### What It Does

This notebook instantiates three AI agents — each using a different framework and integration pattern — and runs multi-turn conversations through the Citadel gateway. It measures token consumption, retry behavior, and call reliability, then produces comparative visualizations across all three frameworks.

#### Agent Framework Matrix

| Access Contract | Agent Framework | Integration Type | Target Model |
|---|---|---|---|
| **Sales-Assistant** | Microsoft Agent Framework | Azure Key Vault (endpoint + key) | gpt-4.1 |
| **HR-ChatAgent** | Microsoft Foundry Agent SDK | Foundry Project Connection | gpt-4o |
| **Support-Bot** | LangChain | Local (direct endpoint + key) | phi-4 |

#### Steps

| Step | Description |
|---|---|
| 0 | **Initialize variables** — Configure resource group, Key Vault, Foundry, and model settings |
| 1 | **Verify Azure CLI** — Confirm authentication and subscription context |
| 2 | **Initialize APIM Client** — Discover APIs and supported models |
| 3 | **Retrieve API keys** — Fetch subscription keys for each access contract |
| 4 | **Install packages** — Install agent framework dependencies (`agent-framework`, `azure-ai-projects`, `langchain`, `langchain-openai`) |
| 5 | **Microsoft Agent Framework** — Sales conversation via Key Vault integration |
| 6 | **Foundry Agent SDK** — HR conversation via Foundry project connection |
| 7 | **LangChain** — Support conversation via direct endpoint configuration |
| 8 | **Metrics comparison** — Token consumption pie charts, calls vs. retries, retry rates |
| 9 | **Efficiency analysis** — Token efficiency and call reliability per agent |
| Cleanup | Managed by `citadel-access-contracts-tests.ipynb` |

#### Key Configuration

```python
governance_hub_resource_group = "REPLACE"

# Key Vault (for Sales-Assistant)
keyvault_name = "REPLACE"

# Foundry (for HR-ChatAgent)
foundry_account_name = "REPLACE"
foundry_project_name = "REPLACE"
foundry_connection_name = "HR-ChatAgent-DEV-LLM"

# Models per agent
sales_model_name = "gpt-4.1"
hr_model_name = "gpt-4o"
support_model_name = "phi-4"
```

#### Output

- Multi-turn conversation logs for each agent
- Token usage metrics (prompt, completion, total) per framework
- Retry rate and reliability analysis
- Comparative visualizations saved as `agent_metrics_comparison.png`

---

### 5. Citadel Model Aliases Tests

| | |
|---|---|
| **Notebook** | [`citadel-model-aliases-tests.ipynb`](citadel-model-aliases-tests.ipynb) |
| **Purpose** | Validate the shared `resolve-model-alias` policy fragment across Universal LLM, Azure OpenAI, and Unified AI APIs |
| **Run this** | After backend onboarding (notebook 1). Can be run independently of notebooks 3–4. |

#### What It Does

This notebook re-runs the LLM backend onboarding Bicep with a `modelAliases` parameter populated, which (re)deploys the shared `resolve-model-alias` policy fragment with the configured aliases inlined. It then provisions an access contract scoped to **alias names only** (least-privilege RBAC) and exercises the same aliases through all 3 LLM API surfaces, inspecting the `UAIG-*` debug response headers to verify the gateway's routing decisions end-to-end.

Two alias strategies are validated:

| Alias | Strategy | Behavior |
|---|---|---|
| `adv-gpt` | `priority` | First underlying model wins; remaining models act as cross-model fallback (deterministic per-call) |
| `gpt-blend` | `weighted` | Random-weighted picking across underlying models — useful for A/B model swaps |

#### Steps

| Step | Description |
|---|---|
| 0 | **Initialize variables** — Auto-load from `azd` env (`LLM_BACKEND_CONFIG`) or fill manually; define the two aliases and a direct-test model |
| 1 | **Verify Azure CLI & APIM Client** — Confirm subscription context and discover the APIM resource + managed identity |
| 2 | **Generate `.bicepparam`** — Write `llm-backends-aliases-validation.bicepparam` containing the full backend config + the two aliases |
| 3 | **Deploy onboarding** — Re-run the LLM backend onboarding Bicep so the `resolve-model-alias` fragment is regenerated with the aliases inlined |
| 4 | **Create access contract** — Deploy an APIM product whose `allowedModels` lists ONLY the alias names + `direct_test_model`, with `enableResponseHeaders=true` for `UAIG-*` debug headers |
| 5 | **Resolve API key** — Pick the subscription created for the contract |
| 6 | **Discover endpoints** — Universal LLM (`/models`), Azure OpenAI (`/openai`), Unified AI (`/unified-ai`) |
| Discovery | **`GET /deployments` honors `allowedModels`** — Aliases appear as `type: "alias"` entries with descriptions; underlying real models that aren't in `allowedModels` are filtered out |
| 7 | **Direct model control test** — Call `direct_test_model` on all 3 APIs; resolver should be a no-op (no `UAIG-Alias` header) |
| 8 | **Priority alias test** — Call `adv-gpt` on all 3 APIs; resolves deterministically to the first underlying model |
| 9 | **Weighted alias single call** — Call `gpt-blend` once on each API |
| 10 | **Weighted distribution test** — Send N=30 requests through `gpt-blend` and tally `UAIG-Resolved-Model` against configured weights |
| 11 | **Negative RBAC test** — Send a model NOT in `allowedModels`; expect HTTP 403 `unauthorized_model_access` |
| Summary | **Results overview** — Cross-API consistency check + alias resolution observations |
| Cleanup | **Delete access contract** — `do_cleanup` flag (default `False`); LLM backends and the `resolve-model-alias` fragment are intentionally preserved |

#### `UAIG-*` Response Headers Inspected

| Header | Meaning |
|---|---|
| `UAIG-Model-Id` | Model that was actually routed to (post alias resolution) |
| `UAIG-Alias` | Original alias name the client sent (only present when alias was used) |
| `UAIG-Resolved-Model` | Real model the alias resolved to |
| `UAIG-Backend` | Backend pool / backend that served the request |
| `UAIG-API-Type` | Detected API type (Unified AI only) |
| `UAIG-Final-Path` | Reconstructed backend path (Unified AI only) |
| `UAIG-Auth-Type` | Auth method enforced by `security-handler` (Unified AI only) |
| `UAIG-Cache-Operation` | `cache-hit` / `cache-miss` for `metadata-config` |
| `UAIG-Request-Id` | APIM request id for log correlation |

#### Key Configuration

```python
governance_hub_resource_group = "REPLACE"   # or auto-loaded from azd
location                      = "REPLACE"
llm_backends_config           = []          # auto-loaded from LLM_BACKEND_CONFIG when init_from_azd=True

model_aliases = [
    { "name": "adv-gpt",   "models": ["gpt-5.2", "gpt-5.4-mini", "gpt-4.1"], "strategy": "priority" },
    { "name": "gpt-blend", "models": ["gpt-5.4-mini", "gpt-4.1"],            "strategy": "weighted", "weights": [70, 30] },
]

direct_test_model     = "gpt-4.1"            # control test (must exist in llm_backends_config)
inference_api_version = "2024-05-01-preview"
```

#### Output

- Re-deployed `resolve-model-alias` policy fragment with the two aliases inlined as a static `JObject`
- Access contract scoped to alias names (proves alias-name RBAC works without exposing underlying real models)
- Per-API report of `UAIG-*` headers showing alias → real-model resolution
- Distribution table for the weighted alias compared against the configured weights
- Filtered `GET /deployments` response showing aliases as first-class entries with `properties.capabilities.description`
- 403 negative-test confirmation that unauthorized models are blocked at the gateway

---

### 6. Citadel PII Processing Tests

| | |
|---|---|
| **Notebook** | [`citadel-pii-processing-tests.ipynb`](citadel-pii-processing-tests.ipynb) |
| **Purpose** | Verify PII anonymization, deanonymization, and blocking capabilities |
| **Run this** | After the Governance Hub is deployed with PII policy fragments |

#### What It Does

This notebook creates two specialized access contracts to test PII processing. The first contract enables PII anonymization and deanonymization with state saving (audit logging to Event Hub). The second contract enables PII blocking, which rejects any request containing detected PII. Both contracts support built-in PII categories and custom regex patterns for domain-specific identifiers.

#### Use Cases Tested

| Use Case | Mode | Behavior |
|---|---|---|
| **PII Masking** | Anonymization / Deanonymization | PII in requests is replaced with placeholders (e.g., `<Person_0>`), sent to the LLM, then restored in the response |
| **PII Blocking** | Detection + Rejection | Requests containing PII are rejected with HTTP 400 and a list of detected PII categories |

#### PII Types Covered

- Person names, email addresses, phone numbers
- Physical addresses, IBANs
- Credit card numbers (custom regex)
- Passport numbers (custom regex)
- Emirates ID (custom regex)
- Multiple PII types in a single request

#### Steps

| Step | Description |
|---|---|
| 0 | **Initialize variables** — Configure resource group, location, and Key Vault settings |
| 1 | **Verify Azure CLI** — Confirm authentication and subscription context |
| 2 | **Initialize APIM Client** — Discover APIs and supported models |
| 3.1 | **Define masking contract** — Configure PII anonymization with state saving |
| 3.2 | **Create masking policy** — Generate policy XML with anonymization, deanonymization, and regex patterns |
| 3.3 | **Deploy masking contract** — Deploy via Bicep with generated parameters |
| 3.4 | **Retrieve masking API key** — Get the subscription key for the masking product |
| 3.5 | **Test PII masking** — Send 6 test payloads with various PII types and verify deanonymization |
| 4.1 | **Define blocking contract** — Configure PII detection and blocking |
| 4.2 | **Create blocking policy** — Generate policy XML that detects PII and returns HTTP 400 |
| 4.3 | **Deploy blocking contract** — Deploy via Bicep with generated parameters |
| 4.4 | **Retrieve blocking API key** — Get the subscription key for the blocking product |
| 4.5 | **Test PII blocking** — Send 8 test payloads (5 with PII, 3 without) and verify correct blocking/allowing |
| Summary | **Results overview** — Aggregate pass/fail across both use cases |
| Cleanup | **Delete test products** — Optionally remove PII access contracts and generated files |

#### Key Configuration

```python
governance_hub_resource_group = "REPLACE"
location = "REPLACE"

# PII detection settings (configured in policy XML)
# - Confidence threshold: 0.75–0.8
# - Entity exclusions: PersonType
# - Custom regex: Credit cards, passport numbers, Emirates ID
```

#### Output

- Deployed PII masking and blocking APIM products
- Test results for 14 PII test payloads
- Validation of custom regex pattern detection
- Pass/fail summary for both anonymization and blocking modes

---

### 7. Citadel Unified AI API Tests

| | |
|---|---|
| **Notebook** | [`citadel-unified-ai-api-tests.ipynb`](citadel-unified-ai-api-tests.ipynb) |
| **Purpose** | Validate the Unified AI Wildcard API across multiple LLM providers and API patterns |
| **Run this** | After the Governance Hub is deployed with the Unified AI API enabled |

#### What It Does

This notebook validates the Unified AI Wildcard API (`/unified-ai`) that enables API pattern flexibility across multiple LLM providers. It deploys a test access contract, then tests Azure OpenAI, AI Foundry inference, and Gemini routing patterns, validates model discovery endpoints, verifies API key authentication, and runs a load test with throttling visualization.

#### API Patterns Tested

| Pattern | Path | Provider |
|---|---|---|
| **Azure OpenAI** | `/unified-ai/openai/deployments/{model}/chat/completions` | Azure OpenAI |
| **Foundry Inference** | `/unified-ai/models/chat/completions` | AI Foundry |
| **Gemini OpenAI** | `/unified-ai/v1beta/openai/chat/completions` | Google Gemini (optional) |
| **Deployment Discovery** | `GET /unified-ai/deployments` | All providers |

#### Steps

| Step | Description |
|---|---|
| 0 | **Initialize variables** — Configure resource group, location, and model names per backend |
| 1 | **Verify Azure CLI** — Confirm authentication and subscription context |
| 2 | **Initialize APIM Client** — Discover Unified AI API and retrieve supported models |
| 3 | **Deploy access contract** — Create and deploy a test APIM product with model-scoped policy via Bicep |
| 4 | **Retrieve API key** — Get the subscription key and build endpoint URLs |
| Test 1 | **Model discovery** — `GET /unified-ai/deployments` to list available models |
| Test 2 | **Azure OpenAI pattern** — Chat completion via OpenAI-compatible path; expects 200 |
| Test 3 | **Foundry inference pattern** — Chat completion via inference path with model in body; expects 200 |
| Test 4 | **Deployment queries** — Get existing deployment (200) and non-existent deployment (404) |
| Test 5 | **Gemini pattern** — Chat completion via Gemini OpenAI-compatible path (if configured) |
| Test 6 | **API key authentication** — Valid key (200), missing key (401) |
| Test 7 | **Load test** — 30-second burst requests with throttling visualization |
| Cleanup | **Delete test products** — Optionally remove the access contract product |

#### Key Configuration

```python
governance_hub_resource_group = "REPLACE"
location = "REPLACE"

# Model configuration per backend
openai_model = "gpt-4o"
foundry_inference_model = "Mistral-Large-3"
gemini_model = "gemini-2.5-flash-lite"

# Test toggles
test_gemini = False  # Set True if Gemini backend is configured

# Load test
test_duration = 30   # Seconds
```

#### Output

- Deployed test access contract with model-scoped policy
- Model discovery results from `GET /deployments`
- Response validation across Azure OpenAI, Foundry, and Gemini patterns
- API key authentication enforcement
- Load test visualization (bar chart with 200/429 status codes over time)

---

### 8. Citadel JWT Authentication Tests

| | |
|---|---|
| **Notebook** | [`citadel-jwt-authentication-tests.ipynb`](citadel-jwt-authentication-tests.ipynb) |
| **Purpose** | Validate JWT-based authentication and role-based access control (RBAC) across all LLM API endpoints |
| **Run this** | After the Governance Hub is deployed with JWT configuration and Entra ID app registration |

#### What It Does

This notebook tests dual authentication modes (API Key + JWT Bearer token) and role-based authorization using Entra ID app roles. It supports both service-to-service (client credentials) and interactive user (device code flow) token acquisition, and validates the unified `security-handler` fragment across all three API endpoint flavors (Azure OpenAI, Universal LLM, Unified AI).

#### Use Cases Tested

| Use Case | Mode | Behavior |
|---|---|---|
| **JWT-Enforced Access** | API Key + JWT | Requires both a valid subscription key and a valid JWT Bearer token |
| **Role-Enforced Access** | API Key + JWT + App Role | Additionally requires a specific app role (e.g., `Models.Read`) in the JWT |

#### Steps

| Step | Description |
|---|---|
| 0 | **Initialize variables** — Configure resource group, location, Entra ID tenant/client IDs, and model settings |
| 1 | **Verify Azure CLI** — Confirm authentication and subscription context |
| 2 | **Initialize APIM Client** — Discover all 3 API endpoints and retrieve supported models |
| 3 | **Acquire JWT (Client Credentials)** — Obtain a JWT token via client credentials grant from Entra ID |
| 4 | **Acquire JWT (Device Code Flow)** — Optional interactive sign-in via MSAL for user token acquisition |
| 5 | **Inspect JWT tokens** — Decode and display token header, payload, roles, and lifetime |
| 6 | **Select active token** — Choose between client credentials or device flow token for tests |
| 7 | **Deploy JWT access contract** — Create and deploy a JWT-enforced APIM product via Bicep |
| 8 | **Retrieve API key** — Get the subscription key for the JWT-enforced product |
| Test 1 | **API Key + JWT (Success)** — Send requests with both credentials to all endpoints; expects 200 |
| Test 2 | **API Key Only (Fail)** — Send requests without JWT; expects 401 |
| Test 3 | **Invalid JWT (Fail)** — Send requests with invalid JWT; expects 401 |
| Test 4 | **JWT Only (Fail)** — Send requests without API key; expects 401/403 |
| 9 | **Deploy role-enforced contract** — Create APIM product requiring `Models.Read` app role |
| 10 | **Retrieve role API key** — Get the subscription key for the role-enforced product |
| Test 5 | **Correct Role (Success)** — Send requests with JWT containing `Models.Read`; expects 200 |
| Test 6 | **Missing Role (Fail)** — Send requests without required role; expects 403 |
| Test 7 | **API Key Only on Role Product (Fail)** — Send requests without JWT to role-enforced product; expects 401 |
| Summary | **Results overview** — Aggregate PASS/FAIL across all 7 tests and 4 endpoints |
| Cleanup | **Delete test products** — Optionally remove JWT and role-enforced products |

#### Key Configuration

```python
governance_hub_resource_group = "REPLACE"
location = "REPLACE"

# Entra ID / OAuth
entra_tenant_id = "REPLACE"
entra_client_id = "REPLACE"
entra_client_secret = "REPLACE"

# Model and API versions
model_name = "gpt-4.1"
openai_api_version = "2024-12-01-preview"

# Token source: "client_credentials" or "device_flow"
token_source = "client_credentials"

# Role configuration
requiredRoles = "Models.Read"
```

#### Output

- Deployed JWT-enforced and role-enforced APIM products
- Test results for 7 scenarios across 4 API endpoints
- Decoded JWT token inspection (claims, roles, lifetime)
- PASS/FAIL summary table with overall pass rate

---

### 9. Extended Providers Backend Onboarding (AWS Bedrock + GCP Gemini + Anthropic Claude)

| | |
|---|---|
| **Notebook** | [`llm-backend-onboarding-extended-providers-runner.ipynb`](llm-backend-onboarding-extended-providers-runner.ipynb) |
| **Purpose** | Onboard three non-Microsoft-Foundry LLM backends and validate native + OpenAI-compatible routing across both LLM API surfaces |
| **Run this** | After backend onboarding (notebook 1). This notebook **extends** notebook 1 — it keeps the Foundry pipeline and adds the non-Azure backends. |

#### What It Does

This notebook extends the base LLM backend onboarding flow with three non-Azure backends authenticated by simple API keys (no AWS SigV4 or Workload Identity Federation required for validation). It generates a `.bicepparam` file with the new backend definitions, re-deploys the onboarding Bicep, provisions an access contract that allows every onboarded model, then validates each backend through its native API surface **and** its OpenAI-compatible surface. Each test cell self-skips when a provider's credentials are still `REPLACE_*`, so partial configurations never produce failures.

#### Backends Onboarded

| Backend type | Auth | Native path prefix | OpenAI-compat surface |
|---|---|---|---|
| `aws-bedrock` | `api-key-bearer` (Bedrock API key) | `/unified-ai/bedrock/model/{modelId}/converse` | — |
| `aws-bedrock-mantle` | `api-key-bearer` | — | `/models/chat/completions` and `/unified-ai/v1/chat/completions` |
| `gemini` | `api-key-gemini` (`x-goog-api-key`) | `/unified-ai/gemini/v1beta/models/{model}:generateContent` | — |
| `gemini-openai` | `api-key-bearer` | — | `/models/chat/completions` and `/unified-ai/v1/chat/completions` |
| `anthropic` | `api-key-anthropic` (`x-api-key` + `anthropic-version`) | `/unified-ai/claude/v1/messages` | — |

#### API Surfaces Validated

| API | Inbound path | Surface | Backends covered |
|---|---|---|---|
| **Universal LLM** | `/models/chat/completions` | OpenAI-compat | Foundry, Bedrock-Mantle, Gemini-OpenAI |
| **Unified AI** | `/unified-ai/v1/chat/completions` | OpenAI-compat | Foundry, Bedrock-Mantle, Gemini-OpenAI |
| **Unified AI** | `/unified-ai/bedrock/model/{modelId}/converse` | Native Bedrock Converse | `aws-bedrock` |
| **Unified AI** | `/unified-ai/gemini/v1beta/models/{model}:generateContent` | Native Gemini | `gemini` |
| **Unified AI** | `/unified-ai/claude/v1/messages` | Native Anthropic Messages | `anthropic` |

#### Steps

| Step | Description |
|---|---|
| 0 | **Initialize variables** — Configure resource group and per-provider credentials (inline secret or Key Vault URI); build the backend definitions and opt-in model aliases |
| 1 | **Verify Azure CLI** — Confirm authentication and subscription context |
| 2 | **Initialize APIM Client** — Connect to the existing Governance Hub deployment |
| 3 | **Extract current backends** — Retrieve existing backend pools and routing configuration |
| 4 | **Discover managed identity** — Auto-detect the APIM user-assigned managed identity |
| 5 | **Generate parameter file** — Create a `.bicepparam` with the new backends, auth config, and aliases |
| 6 | **Deploy** — Re-run the onboarding Bicep to add backends, pools, and policy fragments |
| 7–8 | **Verify deployment** — Confirm backends, pools, and `get-available-models` fragment |
| 9 | **Provision access contract** — Deploy an APIM product allowing every onboarded model + alias |
| Test | **Validate routing** — OpenAI-compat (Universal LLM + Unified AI), native Bedrock / Gemini / Anthropic, and model-alias scenarios |

#### Key Configuration

```python
init_from_azd = False   # keeps REPLACE_* provider placeholders; set True to merge azd Foundry backends

governance_hub_resource_group = "REPLACE"
location                      = "REPLACE"

# Provider credentials — leave as REPLACE_* to skip a backend's tests
aws_bedrock_region           = "eu-north-1"
aws_bedrock_native_inline    = "REPLACE_AWS_BEDROCK_BEARER_VALUE"   # full "Bearer sk-..."
gemini_native_inline         = "REPLACE_GEMINI_RAW_KEY"            # raw key for x-goog-api-key
anthropic_inline             = "REPLACE_ANTHROPIC_RAW_KEY"         # raw key for x-api-key
anthropic_version            = "2023-06-01"

# Optional Key Vault to hold provider secrets (recommended over inline values)
key_vault_name = "kv-REPLACE"
```

> **Secret format note:** APIM substitutes `{{namedValueKey}}` on a Backend resource only when it is the entire header value (no concatenation). Bearer-auth secrets must therefore store the **complete** header value (`Bearer sk-...`), while direct-key headers (`x-api-key`, `x-goog-api-key`) store the raw key. A provider with both a native and an OpenAI-compat surface (e.g. Gemini) needs two separate secrets.

#### Output

- Three native + two OpenAI-compat backends onboarded alongside the existing Foundry backends
- Access contract allowing every onboarded model and alias
- Per-surface validation results (native and OpenAI-compat) with `UAIG-*` debug headers
- Optional model-alias scenarios (single-cloud weighted, cross-cloud OpenAI-compat, native Anthropic) that self-skip when members are unavailable

---

### 10. Session Affinity Tests

| | |
|---|---|
| **Notebook** | [`citadel-session-affinity-tests.ipynb`](citadel-session-affinity-tests.ipynb) |
| **Purpose** | Validate backend-pool **session affinity** (sticky routing) for the stateful OpenAI **Responses API** |
| **Run this** | After backend onboarding (notebook 1) and with the Unified AI API imported. Self-contained — creates its own access contract. |

#### What It Does

When a model is served by a **pool** (2+ backends) and flagged `sessionAwareModel: true`, APIM emits a `Set-Cookie: ai-gateway-affinity=…` header and routes any request that replays the cookie back to the **same** backend — required for the stateful Responses API, where a follow-up call (`previous_response_id`) must reach the backend that holds the conversation state.

The notebook enables session affinity for the target model (regenerating the LLM backend onboarding into a `-local.bicepparam` with `sessionAwareModel: true` + `configureSessionAffinity`), provisions an access contract scoped to that model, then drives **4 sessions × 3 requests** with the **OpenAI SDK** over a per-session **`httpx` cookie jar**. The first request in each session creates a response id; the two follow-ups reuse it. It visualizes the response id, responding backend, and session cookie for every request, and asserts that each session stuck to one backend.

#### Steps

| Step | Description |
|---|---|
| 0 | **Initialize variables** — Set `target_model` (default `gpt-5.2`), `num_sessions`, `requests_per_session`, and load backends from `azd` |
| 1 | **Verify Azure CLI** — Confirm authentication and subscription context |
| 2 | **Initialize APIM Client** — Discover the Unified AI API, gateway URL, and managed identity |
| 2B | **Enable session affinity** — Mark `target_model` `sessionAwareModel: true` on every backend that serves it and redeploy the onboarding Bicep (`-local.bicepparam`) |
| 3 | **Provision access contract** — Deploy an APIM product/subscription scoped to the target model with `enableResponseHeaders` |
| 4 | **Retrieve API key** — Pull the contract's subscription key and build the OpenAI base URL (`/unified-ai/openai`) |
| 5 | **Session harness** — One `httpx` cookie jar + OpenAI client per session; capture headers/id/cookie via `with_raw_response` |
| 6 | **Run 4 × 3** — Establish the sessions and requests |
| 7 | **Visualize** — Per-request table of response id, backend (`UAIG-Backend` / `x-ms-region`), and affinity cookie |
| 8 | **Assertions** — Response id reused, one backend per session, affinity cookie maintained |
| 9 | **Summary table** — Per-session response id, backend, and cookie |
| 10 | **Cleanup** *(disabled)* — Delete only the access contract product; the backend onboarding is left intact |

#### Key Configuration

```python
target_model = "gpt-5.2"     # pooled across 2+ backends AND supports the stateful Responses API
num_sessions = 4             # independent sticky sessions
requests_per_session = 3     # 1 create + 2 follow-ups reusing the first response id
run_backend_onboarding = True    # enable sessionAwareModel for target_model via the onboarding Bicep
cleanup_delete_contract = False  # set True to delete the access contract at the end (never the backends)
```

#### Output

- The target model onboarded with session affinity (pool emits the `ai-gateway-affinity` cookie)
- An access contract (product + subscription) scoped to the target model
- A per-request visualization and a per-session summary table (response id, backend, cookie)
- PASS/FAIL assertions confirming each session stuck to one backend with a maintained affinity cookie

---

### 11. Gateway Alerting Tests

| | |
|---|---|
| **Notebook** | [`citadel-alerting-tests.ipynb`](citadel-alerting-tests.ipynb) |
| **Purpose** | Trigger and validate the gateway's **comprehensive alerting** end-to-end by forcing **two** distinct events (throttling + quota-exceeded) and wiring Azure Monitor metric alerts |
| **Run this** | After backend onboarding (notebook 1). Self-contained — creates its own restrictive access contract and alert rules. |

#### What It Does

The [`raise-alert-events`](../bicep/infra/modules/apim/policies/frag-raise-alert-events.xml) policy fragment emits a single `AI Gateway Alert` custom metric (namespace `ai-gateway-alerts`, sliced by `alertType`) for throttling, quota-exceeded, backend, authorization, content-safety, and PII events. This notebook proves the path works by *actually firing* two alerts from the two `llm-token-limit` enforcement dimensions.

It provisions a deliberately **restrictive access contract** (low `tokens-per-minute` **and** small `token-quota`), **auto-selects a `gpt`-family model** (excluding image / embedding / audio / non-Azure cloud models, with an override option), then drives load in two phases:

- **Phase 1 — throttling (429):** a concurrent burst overshoots the per-minute token rate (TPM) → `throttling` alert metric.
- **Phase 2 — quota-exceeded (403):** sustained load exhausts the long-term `token-quota` (`AITokenQuotaExceeded`) → `quota-exceeded` alert metric.

It then deploys the [`app-insights-alert`](../bicep/infra/app-insights-alert/README.md) Bicep (one metric alert rule per `alertType` + an email action group, scoped to the probe contract) and verifies both metrics were emitted and both alert rules were created.

#### Steps

| Step | Description |
|---|---|
| 0 | **Initialize variables** — Governance hub, model-selection filters, alert email, restrictive capacity, and demo-tuned alert thresholds |
| 1 | **Verify Azure CLI** — Confirm authentication and subscription context |
| 2 | **Initialize APIM Client & auto-select model** — Read supported models and pick a `gpt`-family chat model (or honor `model_name_override`) |
| 3 | **Define + deploy the restrictive contract** — Low-TPM + low-quota access contract whose dynamic policy opts into `alertOnThrottling` / `alertOnAuthFailure` |
| 4 | **Discover App Insights & deploy alerts** — Resolve the APIM Application Insights component and deploy the throttling + quota-exceeded rules + email action group |
| 5 | **Phase 1 — throttling** — Burst concurrent requests to force HTTP 429 |
| 5.1 | **Phase 2 — quota-exceeded** — Sustained load until the token-quota is exhausted (HTTP 403) |
| 6 | **Verify** — Query the `AI Gateway Alert` metric split by `alertType` and confirm both alert rules exist |
| 🧹 | **Cleanup** *(disabled)* — Delete the alert rules, action group, probe contract, and generated parameter files |

#### Key Configuration

```python
model_name_override      = ""      # empty = auto-select a gpt-family model
alert_email_address      = "REPLACE@example.com"   # who receives the alert
probe_tokens_per_minute  = 500     # low TPM so a burst throttles (429)
probe_token_quota        = 1200    # small hourly quota so sustained load exhausts it (403)
quota_max_seconds        = 360     # Phase 2 time budget to reach the 403
```

#### Output

- A restrictive access contract (APIM product + subscription) that throttles and then exhausts its quota
- Phase 1 producing HTTP 429 (`throttling`) and Phase 2 producing HTTP 403 (`quota-exceeded`)
- Azure Monitor metric alert rules (throttling + quota-exceeded) + an email action group (deployed via `app-insights-alert`)
- Verification that the `AI Gateway Alert` metric was emitted for both alertTypes and both rules are configured
- Alert emails once Azure Monitor next evaluates the crossed thresholds

> **Note:** Custom metrics can take ~3 minutes to first register, and metric alerts evaluate on a schedule (minimum `PT1M`), so the notification is not instantaneous.

---

## Recommended Execution Order

> **Strongly recommended baseline:** run notebooks **1 → 4** in order on every new Citadel Governance Hub deployment. Steps **5 → 11** are optional, scenario-specific validations that can be run independently afterwards.

```
┌──────────────────────────────────────────────┐
│  1. llm-backend-onboarding-runner            │  ⭐ Onboard LLM backends & routing
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│  2. citadel-universal-llm-api-all-models-    │  ⭐ Smoke-test EVERY onboarded model
│     tests                                    │     (chat / embeddings / Responses API)
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│  3. citadel-access-contracts-tests           │  ⭐ Create access contracts & load test
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│  4. citadel-agent-frameworks-tests           │  ⭐ Test agent frameworks
│                                              │     (uses contracts from step 3)
└──────────────┬───────────────────────────────┘
               │   ── End of strongly recommended baseline ──
               ▼
┌──────────────────────────────────────────────┐
│  5. citadel-model-aliases-tests              │  Optional: alias routing
│                                              │     (priority + weighted strategies)
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│  6. citadel-pii-processing-tests             │  Optional: PII masking & blocking
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│  7. citadel-unified-ai-api-tests             │  Optional: Unified AI wildcard API
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│  8. citadel-jwt-authentication-tests         │  Optional: JWT auth & RBAC
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│  9. llm-backend-onboarding-extended-         │  Optional: AWS Bedrock + GCP Gemini +
│     providers-runner                         │     Anthropic Claude (native + OpenAI-compat)
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│ 10. citadel-session-affinity-tests           │  Optional: sticky routing for the stateful
│                                              │     Responses API (per-session cookie jar)
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│ 11. citadel-alerting-tests                   │  Optional: trigger throttling & wire
│                                              │     Azure Monitor alerts (email action group)
└──────────────────────────────────────────────┘
```

> **Note:** Notebooks 5–11 create their own access contracts and can be run independently after backend onboarding. Notebook 5 re-deploys the LLM backend onboarding Bicep with `modelAliases` populated (the `resolve-model-alias` fragment is regenerated; full cross-API coverage requires the Unified AI API to be imported), notebook 6 requires PII policy fragments (`pii-anonymization`, `pii-deanonymization`, `pii-state-saving`), notebook 7 requires the Unified AI API (`unified-ai`) to be imported into APIM, notebook 8 requires JWT configuration plus an Entra ID app registration, notebook 9 extends backend onboarding with non-Azure providers (native `/bedrock/**`, `/gemini/**`, and `/claude/**` routing requires the Unified AI API to be imported), and notebook 10 re-deploys the onboarding Bicep to enable `sessionAwareModel` for the target model and requires the Unified AI API for the Responses API, and notebook 11 creates a restrictive-TPM access contract and deploys Azure Monitor alert rules (`app-insights-alert`) to trigger and validate throttling alerts.

## Shared Utilities

All notebooks import shared helper modules from the [`../shared/`](../shared/) directory:

| Module | Description |
|---|---|
| `utils.py` | CLI command runner, formatted output helpers (`print_ok`, `print_error`, `print_info`) |
| `apimtools.py` | `APIMClientTool` class for APIM discovery, API key retrieval, policy fragment parsing, and backend management |

## Cleanup

Each notebook includes an optional cleanup cell at the end that removes the APIM products and subscriptions created during testing. Cleanup is controlled by a `cleanup_enabled` flag (default: `True`).

> **Important:** Cleanup does not remove Azure Key Vault secrets, Foundry connections, or LLM backend configurations. Those resources are managed separately.

## Troubleshooting

| Issue | Resolution |
|---|---|
| `az account show` fails | Run `az login` and set the correct subscription with `az account set --subscription <id>` |
| APIM Client Tool initialization fails | Verify the `governance_hub_resource_group` is correct and your identity has Reader access |
| Model not found in backend pool | Run the backend onboarding notebook to register the model |
| Key Vault access denied | Ensure your identity has `Key Vault Secrets User` role on the Key Vault |
| Foundry connection fails | Verify the Foundry account, project, and connection names are correct |
| PII detection not working | Confirm the Azure AI Language Service is deployed and the managed identity has access |
| 429 Throttled responses | Expected during load testing — the token bucket policy is working correctly |