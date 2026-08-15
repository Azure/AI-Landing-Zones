# 🏰 AI Gateway Landing Zone — Terraform Implementation

Complete Terraform implementation of the [Azure AI Citadel Governance Hub](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/tree/citadel-v1) solution accelerator. Mirrors the Bicep reference architecture using Terraform + AzureRM + AzAPI providers.

---

## 📐 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Resource Group                           │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │            Virtual Network (hub or spoke)            │   │
│  │  ┌───────────────┐ ┌──────────────┐ ┌────────────┐   │   │
│  │  │  APIM Subnet  │ │   PE Subnet  │ │  LA Subnet │   │   │
│  │  └──────┬────────┘ └──────┬───────┘ └─────┬──────┘   │   │
│  └─────────┼────────────────┼───────────────┼───────────┘   │
│            │                │               │               │
│   ┌────────▼──────┐  Private Endpoints:     │               │
│   │  API Mgmt     │  • Key Vault            │               │
│   │  (Citadel     │  • Cosmos DB     ┌──────▼───────┐       │
│   │   Gateway)    │  • Event Hub     │  Logic App   │       │
│   └──────┬────────┘  • AI Services   │  (Usage      │       │
│          │           • Storage       │   Ingestion) │       │
│          │                           └──────┬───────┘       │
│   Named Values:                             │               │
│   • uami-client-id   ┌──────────────────────▼─────────┐     │
│   • piiServiceUrl    │         Cosmos DB              │     │
│   • entra-auth       │  usage-db / model-pricing      │     │
│                      └────────────────────────────────┘     │
│                                                             │
│  Supporting:  Key Vault · Log Analytics · App Insights      │
│               Event Hub · AI Foundry · Language Service     │
│               Content Safety · API Center                   │
└─────────────────────────────────────────────────────────────┘
```

---

## ⚡ Quick Start

> **In a hurry?** See [QUICK_START.md](QUICK_START.md) for a concise, copy-paste
> deployment walkthrough (dev & prod, add-ons, and common operations).

### Prerequisites

| Tool | Min Version | Install |
|------|-------------|---------|
| Terraform | ≥ 1.5 | [Install](https://developer.hashicorp.com/terraform/install) |
| Azure CLI | ≥ 2.50 | [Install](https://aka.ms/installazurecli) |
| Git | Any | [Install](https://git-scm.com) |
| Bash shell (`scripts/*.sh`) | Any | macOS/Linux: built-in. Windows: use [Git Bash](https://git-scm.com) or [WSL](https://learn.microsoft.com/windows/wsl/install). |
| PowerShell (`scripts/*.ps1`) | 7+ | Cross-platform on macOS/Linux/Windows — [Install pwsh](https://learn.microsoft.com/powershell/scripting/install/installing-powershell). |

### 1 — Clone and configure

```bash
git clone https://github.com/Azure/terraform-ai-gateway-landing-zone.git
cd citadel-terraform

```

### 2 — (Optional) Set up remote state backend

```bash
# Bash (Linux/macOS):
# -------------------
./scripts/bootstrap-state.sh eastus
# Then uncomment the backend block in versions.tf and re-run terraform init
```

```powershell
# PowerShell (cross-platform pwsh):
# --------------------------------
./scripts/bootstrap-state.ps1 eastus
```

### 3 — Deploy

```bash
# Copy the environment template and fill in your values
cp environments/dev.tfvars.example environments/dev.tfvars
# Edit environments/dev.tfvars — set subscription_id and other required values
# (for production: cp environments/prod.tfvars.example environments/prod.tfvars)

# Bash (Linux/macOS):
# -------------------
# Development environment (30-45 min for APIM)
./scripts/deploy.sh dev

# Production environment
./scripts/deploy.sh prod

# Skip confirmation prompt
./scripts/deploy.sh dev --auto-approve
```

```powershell
# PowerShell (cross-platform pwsh):
# ---------------------------------
./scripts/deploy.ps1 dev
./scripts/deploy.ps1 prod

# Skip confirmation prompt
./scripts/deploy.ps1 dev -AutoApprove
```

### 4 — Validate

```bash
# Bash
./scripts/validate.sh dev
```

```powershell
# PowerShell
./scripts/validate.ps1 dev
```

### 5 — Tear down

```bash
# Bash
./scripts/destroy.sh dev
```

```powershell
# PowerShell
./scripts/destroy.ps1 dev
```

---

## 🔧 Configuration

All configuration is done through `.tfvars` files in `environments/`. Key settings:

### T-Shirt Sizing

| Size | APIM SKU | Cosmos RU/s | Event Hub Units | Use Case |
|------|----------|-------------|-----------------|----------|
| Small (dev) | `Developer` | 400 | 1 | Dev/test, no SLA |
| Medium | `StandardV2` | 400 | 1 | Non-prod with SLA |
| Large | `PremiumV2` | 1000 | 2 | Multi-zone production |

### Network Approach

**Greenfield (new VNet):**
```hcl
use_existing_vnet   = false
vnet_address_prefix = "10.170.0.0/24"
apim_network_type   = "External"   # or "Internal" for fully private
```

**Brownfield (existing enterprise VNet):**
```hcl
use_existing_vnet    = true
existing_vnet_rg     = "rg-network-hub"
vnet_name            = "vnet-hub-prod-eastus"
apim_subnet_name     = "snet-citadel-apim"
dns_zone_rg          = "rg-network-dns"
dns_subscription_id  = "00000000-0000-0000-0000-000000000000"
```

### Entra ID Authentication

```hcl
entra_auth_enabled = true
entra_tenant_id    = "your-tenant-id"
entra_client_id    = "your-client-id"
entra_audience     = "api://ai-citadel-prod"
```

### AI Foundry Multi-Region

```hcl
ai_foundry_instances = [
  { location = "eastus",  default_project_name = "citadel-prod" },
  { location = "eastus2", default_project_name = "citadel-prod-secondary" }
]
ai_foundry_models = [
  { name = "gpt-4o", version = "2024-11-20", capacity = 100, ai_service_index = 0 },
  { name = "gpt-4o", version = "2024-11-20", capacity = 100, ai_service_index = 1 }
]
```

---

## 🌐 API Endpoints (post-deploy)

| API | URL Pattern | Use Case |
|-----|-------------|---------|
| Universal LLM | `{gateway_url}/models/chat/completions` | Recommended — all models |
| Azure OpenAI Compat | `{gateway_url}/openai/deployments/{model}/chat/completions` | SDK compatibility |
| List Models | `GET {gateway_url}/models/` | Discover available models |

### Test the gateway

```bash
# Get subscription key from APIM portal → Subscriptions
APIM_URL=$(terraform output -raw universal_llm_api_url)
SUB_KEY="your-apim-subscription-key"

curl -X POST "$APIM_URL" \
  -H "Content-Type: application/json" \
  -H "api-key: $SUB_KEY" \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"Hello from Citadel!"}]}'
```

---

## 🧪 Validation Notebooks

The [validation/](validation/) folder contains the Jupyter test notebooks ported
from the upstream accelerator, plus their Python helpers in [shared/](shared/).
They exercise a **live** deployment, and the recommended baseline order is steps
1–4 (run them on every new Governance Hub deployment before the scenario-specific
ones):

| # | Notebook | Purpose |
|---|----------|---------|
| 1 | [llm-backend-onboarding-runner.ipynb](validation/llm-backend-onboarding-runner.ipynb) ⭐ | Register AI backends and deploy routing logic into APIM (run first). Drives the [`llm-backend-onboarding/`](llm-backend-onboarding/) module. |
| 2 | [citadel-universal-llm-api-all-models-tests.ipynb](validation/citadel-universal-llm-api-all-models-tests.ipynb) ⭐ | Validate every gateway-configured model (chat / embeddings / Responses API) through `/models`. |
| 3 | [citadel-access-contracts-tests.ipynb](validation/citadel-access-contracts-tests.ipynb) ⭐ | Provision per-team access contracts with Key Vault + Foundry integration. Drives the [`citadel-access-contracts/`](citadel-access-contracts/) module. |
| 4 | [citadel-model-aliases-tests.ipynb](validation/citadel-model-aliases-tests.ipynb) | Validate the shared `resolve-model-alias` policy fragment (priority + weighted strategies, RBAC, discovery). |

See [validation/README.md](validation/README.md) for the full per-notebook
variable map, prerequisites, and execution guide.

### Terraform autoload (no azd required)

The notebooks were written for an `azd`-deployed environment and bootstrap their
config with `init_from_azd = True`. This repo deploys with **Terraform, not azd**,
so [shared/utils.py](shared/utils.py) adds a transparent bridge:
`azd_env_get()` tries `azd` first, then falls back to `terraform output -json`.
An internal alias map translates each azd-style variable the notebooks request
into the matching Terraform output, so the existing `init_from_azd = True` /
`utils.load_azd_env(...)` cells work **unchanged**:

| azd env var | Terraform output |
|---|---|
| `AZURE_RESOURCE_GROUP`, `GOVERNANCE_HUB_RESOURCE_GROUP` | `resource_group_name` |
| `AZURE_LOCATION`, `LOCATION` | `location` |
| `AZURE_SUBSCRIPTION_ID` | `subscription_id` |
| `KEY_VAULT_NAME` | `key_vault_name` |
| `AI_FOUNDRY_SERVICES` | `ai_foundry_services` |
| `LLM_BACKEND_CONFIG`, `LLM_BACKENDS_CONFIG` | `llm_backend_config` |
| `APIM_NAME` | `apim_name` |
| `APIM_GATEWAY_URL` | `apim_gateway_url` |

The bridge resolves the Terraform root as the parent of `shared/` (the repo
root). Override with the `CITADEL_TF_DIR` environment variable to point the
notebooks at a different state directory (e.g. `llm-backend-onboarding/`).
Outputs only appear after a `terraform apply`. See
[validation/README.md](validation/README.md) for the full per-notebook variable
map.

### Run

```bash
pip install -r shared/requirements.txt
# then open any notebook in validation/ and run the first (config) cell
```

`apimtools.py` is deployment-tool-agnostic — it uses `az` + the Azure SDK with
the resource group / APIM name passed as parameters, so no azd/Terraform coupling
there.

---

## 🏗️ Modules Reference

| Module | Resources Created |
|--------|-------------------|
| `networking` | VNet, 3 subnets, NSG, route table, 12 private DNS zones |
| `monitoring` | Log Analytics workspace, 2× Application Insights, dashboard |
| `security` | Key Vault, RBAC assignments, PE |
| `cosmosdb` | Cosmos DB account, `usage-db` database, `usage` + `model-pricing` containers |
| `eventhub` | Event Hub namespace, `apim-usage` + `pii-usage` hubs, auth rules, consumer groups |
| `ai-services` | Language Service (PII), Content Safety, AI Foundry (n instances + models), API Center |
| `apim` | APIM instance, Universal LLM API, Azure OpenAI API, named values, loggers, diagnostic settings |
| `logic-app` | Logic App Standard, App Service Plan, Storage Account (runtime) |

---

## 🔌 Standalone Onboarding Modules

Beyond the root deployment, the repo ships two **independently-applyable** Terraform
root modules that target an **already-deployed** Governance Hub APIM. They are the
Terraform ports of the upstream [`bicep/infra/llm-backend-onboarding`](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/tree/citadel-v1/bicep/infra/llm-backend-onboarding) and
[`bicep/infra/citadel-access-contracts`](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/tree/citadel-v1/bicep/infra/citadel-access-contracts) modules, and each has its own state,
`terraform.tfvars`, and `scripts/` (`deploy.sh` / `destroy.sh` / `test.sh`).

### LLM Backend Onboarding — [`llm-backend-onboarding/`](llm-backend-onboarding/)

Registers LLM backends and routing logic into an existing APIM gateway. Use it to
add or update model backends without touching the core infrastructure.

| Resource | Description |
|----------|-------------|
| **APIM Backends** | One backend per LLM endpoint (native managed-identity creds for Azure OpenAI / AI Foundry) |
| **Backend Pools** | Load-balanced pools for models served by multiple backends (priority + weight) |
| **Policy Fragments** | Dynamic model-based routing, model aliases, Responses API isolation |
| **Named Values** | AWS Bedrock credentials + per-backend API-key values (Key Vault ref or explicit) |

```bash
cd llm-backend-onboarding
cp terraform.tfvars.example terraform.tfvars   # set apim + llm_backend_config
./scripts/deploy.sh
./scripts/test.sh --api-key "<apim-subscription-key>"
```

Supports **model aliases** (`model_aliases`) that expose a single client-facing
name routing to one or more real models (`priority` or `weighted` strategy),
honored by `/deployments` discovery and `validate-model-access` RBAC. See
[llm-backend-onboarding/README.md](llm-backend-onboarding/README.md) for the full
backend / model schema.

### Access Contracts — [`citadel-access-contracts/`](citadel-access-contracts/)

Onboards a **use-case** (business unit) to the gateway by provisioning per-service
APIM products, subscriptions, and inbound policies — optionally writing keys to Key
Vault and creating Azure AI Foundry connections.

| Resource | Description |
|----------|-------------|
| **APIM Product** | `<code>-<businessUnit>-<useCase>-<env>` (e.g. `LLM-Finance-CustomerSupport-DEV`) |
| **Product → API links** | Attaches published APIs from `api_name_mapping[code]` to the product |
| **Product Policy** | Per-service inbound XML or the bundled `default-ai-product-policy.xml` |
| **Subscription** | `<product>-SUB-01` with primary/secondary keys |
| **Key Vault Secrets** *(optional)* | Endpoint URL + subscription key per service (`use_target_key_vault = true`) |
| **Foundry Connection** *(optional)* | One connection per service pointing at the gateway (`use_target_foundry = true`) |

```bash
cd citadel-access-contracts
cp terraform.tfvars.example terraform.tfvars   # set apim + use_case + services
./scripts/deploy.sh
./scripts/test.sh                              # or --api-key "<key>" when keys are in Key Vault
```

Naming follows `<code>-<business_unit>-<use_case_name>-<environment>`. See
[citadel-access-contracts/README.md](citadel-access-contracts/README.md) for the
service object and Foundry connection options.

---

## 📋 Post-Deployment Checklist

- [ ] Run `./scripts/validate.sh <env>` (or `./scripts/validate.ps1 <env>`) — all checks pass
- [ ] Retrieve APIM subscription key from Azure Portal → APIM → Subscriptions
- [ ] Test `POST /models/chat/completions` with a sample request
- [ ] Load `model-pricing.json` into Cosmos DB `model-pricing` container
- [ ] Connect Power BI desktop to Cosmos DB endpoint
- [ ] For production: disable Event Hub public access post-deploy
- [ ] For production: configure APIM custom domains + TLS certificates
- [ ] Configure CI/CD pipeline to call `./scripts/deploy.sh prod --auto-approve` (or `./scripts/deploy.ps1 prod -AutoApprove`)

---

## 🔑 Sensitive Values

Never commit real secrets to source control. Use one of:

1. **Environment variables before deploy:**
   ```bash
   export TF_VAR_entra_tenant_id="your-tenant-id"
   export TF_VAR_entra_client_id="your-client-id"
   ```

2. **Azure Key Vault references in tfvars** (requires azurerm data source)

3. **CI/CD pipeline secret variables** (Azure DevOps / GitHub Actions secrets)

---


## 📁 Project Structure

```
citadel-terraform/
├── versions.tf              # Provider + Terraform version constraints
├── providers.tf             # AzureRM, AzAPI, Random provider config
├── main.tf                  # Root module — orchestrates all modules
├── variables.tf             # All input variables (mirrors Bicep params)
├── outputs.tf               # Key deployment outputs
├── .gitignore
│
├── modules/
│   ├── networking/          # VNet, subnets, NSGs, route tables, DNS zones
│   ├── monitoring/          # Log Analytics, Application Insights, dashboards
│   ├── security/            # Key Vault, RBAC assignments, private endpoints
│   ├── cosmosdb/            # Cosmos DB account, databases, containers
│   ├── eventhub/            # Event Hub namespace, hubs, auth rules
│   ├── ai-services/         # Language Service, Content Safety, AI Foundry, API Center
│   ├── apim/                # API Management + APIs + policies + named values
│   │   └── policies/        # APIM policy XML templates
│   └── logic-app/           # Logic App Standard for usage ingestion
│
├── llm-backend-onboarding/  # Standalone module — onboard LLM backends to an existing APIM
│   ├── main.tf              # Backends, backend pools, policy fragments, named values
│   ├── terraform.tfvars.example
│   ├── policies/            # Routing policy-fragment templates
│   └── scripts/             # deploy.sh / destroy.sh / test.sh
│
├── citadel-access-contracts/ # Standalone module — onboard a use-case to an existing APIM
│   ├── main.tf              # APIM products, subscriptions, policies, KV secrets, Foundry conns
│   ├── terraform.tfvars.example
│   ├── contracts/           # Per-use-case contract definitions
│   ├── policies/            # Inbound product policy XML (incl. default-ai-product-policy.xml)
│   └── scripts/             # deploy.sh / destroy.sh / test.sh
│
├── environments/
│   ├── dev.tfvars.example   # Development template — copy to dev.tfvars and fill in
│   ├── dev.tfvars           # Development (Developer SKU, public access)
│   ├── prod.tfvars.example  # Production template — copy to prod.tfvars and fill in
│   └── prod.tfvars          # Production (PremiumV2, fully private)
│
├── scripts/                # Bash (*.sh) + PowerShell (*.ps1) equivalents
│   ├── deploy.sh / .ps1        # Full deploy script (init + plan + apply)
│   ├── destroy.sh / .ps1       # Teardown script
│   ├── validate.sh / .ps1      # Post-deployment smoke tests
│   ├── import-existing.sh / .ps1  # Import pre-existing resources into state
│   └── bootstrap-state.sh / .ps1  # One-time remote state backend setup
│
├── shared/                  # Python helpers for the validation notebooks
│   ├── utils.py             # Config bootstrap (+ Terraform-output bridge), APIM helpers
│   ├── apimtools.py         # APIMClientTool — backend/policy/trace discovery (az + SDK)
│   ├── requirements.txt     # Python deps for the notebooks
│   └── snippets/            # Standalone az/REST example scripts
│
└── validation/              # Jupyter test notebooks (run against a live deployment)
    ├── llm-backend-onboarding-runner.ipynb              # 1 — onboard LLM backends ⭐
    ├── citadel-universal-llm-api-all-models-tests.ipynb # 2 — validate all models ⭐
    ├── citadel-access-contracts-tests.ipynb            # 3 — provision access contracts ⭐
    ├── citadel-model-aliases-tests.ipynb              # 4 — model alias routing
    ├── README.md            # Variable map + Terraform autoload instructions
    └── requirements.txt
```

---

## 📚 Related Documentation

- [AI Citadel Governance Hub README](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/tree/citadel-v1)
- [Full Deployment Guide](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/citadel-v1/guides/full-deployment-guide.md)
- [LLM Routing Architecture](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/citadel-v1/guides/llm-routing-architecture.md)
- [Network Approach Guide](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/citadel-v1/guides/network-approach.md)

---

## 📄 License

MIT — see [LICENSE](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/citadel-v1/LICENSE)