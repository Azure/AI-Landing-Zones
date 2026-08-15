# AI Citadel — Terraform Simple Deployment Steps

Concise, copy-paste guide for deploying the AI Citadel Governance Hub to **dev** or **prod**.
For full detail, see [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) and [VARIABLES.md](VARIABLES.md).

---

## Prerequisites

- **Terraform** ≥ 1.5.0
- **Azure CLI** ≥ 2.57 (`az --version`)
- **Bash shell** — required to run the `scripts/*.sh` helpers (macOS/Linux: built-in; Windows: use [Git Bash](https://git-scm.com) or [WSL](https://learn.microsoft.com/windows/wsl/install))
- **Azure subscription** with Owner (or equivalent) role
- (Optional, validation notebooks only) **Python** ≥ 3.10
- (Optional, Entra add-on only) Tenant permission `Application.ReadWrite.All`

---

## Step 1 — Sign in to Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
az account show   # verify
```

---

## Step 2 — Pick your environment file

Copy the example template for your target environment, then edit the copy:

```bash
# Dev
cp environments/dev.tfvars.example environments/dev.tfvars

# Prod
cp environments/prod.tfvars.example environments/prod.tfvars
```

- Dev → [environments/dev.tfvars.example](environments/dev.tfvars.example) → `environments/dev.tfvars`
- Prod → [environments/prod.tfvars.example](environments/prod.tfvars.example) → `environments/prod.tfvars`

Set at minimum:

```hcl
subscription_id     = "<your-subscription-id>"
location            = "swedencentral"     # or your region
environment_name    = "citadel-dev"       # or citadel-prod
resource_group_name = "rg-citadel-dev"    # or rg-citadel-prod
```

Leave `llm_backend_config = []` (the default). APIM backends and pools are
auto-derived from your Foundry instances + models — no second apply required.
Only populate `llm_backend_config` if you want to override with external
(non-Foundry) endpoints.

### 2a — Region vs. APIM SKU (important for prod)

APIM **StandardV2 / PremiumV2** (stv2 platform) are only available in a subset
of regions. Classic **Developer / Premium** are globally available. If your
target region doesn't support v2, either pick a v2-supported region
(e.g. `swedencentral`, `francecentral`, `germanywestcentral`, `eastus`,
`eastus2`, `westus3`, `uksouth`) or set `apim_sku = "Premium"`.

Verify before deploying:

```bash
az apim list-skus --location "<your-region>" -o table
```

See [VARIABLES.md](VARIABLES.md) → `apim_sku` for the full region list and the
authoritative Microsoft doc link.

### 2b — Key Vault bootstrap allowlist (prod only)

Prod defaults to `network_acl_default_action = "Deny"` and
`kv_public_network_access_enabled = false` — the deny-by-default posture.
However, the **first** `terraform apply` writes an `apim-gateway-key`
placeholder secret to the Key Vault **data plane** from the machine running
Terraform. If that machine is outside the VNet, the call will 403 with
`ForbiddenByFirewall` / `ForbiddenByConnection`.

Two options (pick one):

**A) Temporary IP allowlist (recommended for non-VNet runners)**

In [environments/prod.tfvars](environments/prod.tfvars):

```hcl
kv_deployer_ip_rules       = ["<your.public.ip>/32"]  # IP Azure sees for this runner
kv_auto_detect_deployer_ip = false
```

To find the IP Azure actually sees (may differ from `curl ifconfig.me` behind
corporate proxies / VPN), either run `terraform apply` once and read the
`Client address: x.x.x.x` line from the 403 error, or check the Key Vault
**Networking** blade in the portal after the first failed apply.

When `kv_deployer_ip_rules` is non-empty, the module automatically flips the
KV to "Allow from selected networks" mode (required — Azure ignores `ip_rules`
when public access is fully disabled). Default-action `Deny` still restricts
traffic to the allowlist + private endpoints.

**B) Run Terraform from inside the VNet**

Skip the allowlist entirely and use a self-hosted CI runner / jumpbox / Azure
DevOps agent on a subnet that can reach the KV private endpoint. Nothing to
set in tfvars.

### 2c — Lock down after bootstrap (second run)

Once the first apply succeeds and all secrets are seeded, re-apply with the
allowlist removed to return the Key Vault to private-endpoint-only access:

```hcl
# environments/prod.tfvars (second apply onward)
kv_deployer_ip_rules       = []
kv_auto_detect_deployer_ip = false
# kv_public_network_access_enabled stays false (default)
```

Then:

```bash
./scripts/deploy.sh prod
```

This second run will flip the KV back to "Disable public access". After this
point, any future secret writes must come from inside the VNet.

**Other variables that follow the same "loose on first run, tighten later"
pattern:**

| Variable | Bootstrap value | Hardened value | Why |
|---|---|---|---|
| `kv_deployer_ip_rules` | `["<ip>/32"]` | `[]` | KV data-plane write for `apim-gateway-key` placeholder |
| `kv_auto_detect_deployer_ip` | `false` (prefer explicit IP) | `false` | Unreliable behind proxies/VPN |
| `apim_v2_public_network_access` | `true` | `false` | APIM v2 can't be *created* with public access disabled; module handles the flip automatically on subsequent applies via `azapi_update_resource.apim_public_network_access` |
| `eventhub_network_access` | `"Enabled"` | `"Disabled"` | Must be Enabled on first deploy so Terraform can seed consumer groups; tighten post-apply |
| `apim_network_type` | `"External"` | `"Internal"` | Flip to Internal only after you have custom domain + DNS wired up |

---

## Step 3 — Deploy core infrastructure

### Dev

```bash
./scripts/deploy.sh dev
```

### Prod

```bash
./scripts/deploy.sh prod
```

Takes ~25–35 min on first run. Creates ~35 resources (VNet, APIM, Foundry, Cosmos, Event Hub, Key Vault, Logic App, etc.).

---

## Step 4 — Validate

```bash
./scripts/validate.sh dev       # or: prod
terraform output
```

Check the output for any errors and verify key resources in the portal (APIM, Foundry, Cosmos DB, Key Vault, Event Hub, Logic App).

### Optional — Run the validation notebooks

The [validation/](validation/) folder has Jupyter notebooks that test a live
deployment: backend onboarding, universal LLM API (all models), access
contracts, and model aliases. Each notebook is configured **manually** in its
first code cell — fill in the `"REPLACE"` values (resource group, location,
etc.). You can pull these straight from your Terraform state, e.g.
`terraform output -raw resource_group_name` and `terraform output -raw location`.

```bash
pip install -r shared/requirements.txt
# open any notebook in validation/ and fill in the first (config) cell
```

See [validation/README.md](validation/README.md) for the per-notebook variable map.

---

## Step 5 (optional) — Enable add-ons

Add one or more flags to enable add-ons. Re-run whenever you want to layer one on.

| Flag | What it does |
|---|---|
| `--with-entra` | Creates Entra app registration + SP + secret, enables JWT auth |
| `--with-foundry-conn` | Creates Foundry → APIM connection + dedicated subscription |
| `--with-access-contracts` | Creates per-use-case APIM products/policies (requires `access_contracts` in tfvars) |
| `--with-mcp-samples` | Adds Weather API + Weather MCP + MS Learn MCP |
| `--with-apic-onboarding` | Registers APIs in API Center |
| `--with-jwt` | Enable JWT auth with existing app reg (set `jwt_tenant_id` + `jwt_app_registration_id`) |
| `--all-addons` | Shortcut for all of the above |

Examples:

```bash
# Dev — enable everything in one pass
./scripts/deploy.sh dev --all-addons

# Prod — staged, add identity only
./scripts/deploy.sh prod --with-entra

# Prod — phased rollout (core first, add-ons second)
./scripts/deploy.sh prod --all-addons --phased
```

---

## Common operations

```bash
# Plan only (no changes)
terraform plan -var-file=environments/dev.tfvars

# Re-publish Logic App workflow code only
./scripts/deploy.sh dev --logic-app-code-only

# Skip workflow code publish
./scripts/deploy.sh dev --skip-logic-app-code

# Tear down (dev)
./scripts/destroy.sh dev
```

---

## Troubleshooting quick hits

- **`az login` expired** → re-run `az login`.
- **Quota / region errors** → change `location` or request quota.
- **APIM gateway returns 404 on model calls** → check `terraform output ai_foundry_endpoints` is populated and `enable_ai_foundry = true`. If you overrode with `llm_backend_config`, verify endpoints + auth scheme.
- **Full error logs** → `terraform apply -var-file=environments/dev.tfvars` directly for full Terraform output.

For deeper guidance see [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md).