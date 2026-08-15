# AI Citadel Governance Hub - APIM Policy Architecture — Terraform

> **Scope:** How every API Management policy, fragment, and named value in
> this repo is modeled, wired up, and applied at runtime. Covers the core
> inference APIs (`universal-llm-api`, `azure-openai-api`), the wildcard
> `unified-ai-api`, operation-level policies, product-level policies
> (including the `citadel-access-contracts` add-on), and the MCP sample APIs.
>
> **Related files:**
> [modules/apim/policy-fragments.tf](modules/apim/policy-fragments.tf) ·
> [modules/apim/main.tf](modules/apim/main.tf) ·
> [modules/apim/extra-apis.tf](modules/apim/extra-apis.tf) ·
> [modules/apim/named-values-extras.tf](modules/apim/named-values-extras.tf) ·
> [modules/apim/backends.tf](modules/apim/backends.tf) ·
> [modules/access-contracts/main.tf](modules/access-contracts/main.tf) ·
> [citadel-access-contracts/main.tf](citadel-access-contracts/main.tf) ·
> [llm-backend-onboarding/main.tf](llm-backend-onboarding/main.tf)
>
> The two standalone root modules `citadel-access-contracts/` and
> `llm-backend-onboarding/` apply the same product/fragment/named-value
> model against an **already-deployed** APIM (via `data` sources) for
> day-2 onboarding. See [§9](#9-standalone-onboarding-modules).

---

## 1. Mental model

APIM policies are XML documents that run at one of four **scopes**. Each
scope maps 1:1 to a distinct Terraform resource type:

| Scope | Terraform resource | What it controls |
|---|---|---|
| **Global** | `azurerm_api_management_policy` | All APIs across the service. Not currently used in this port. |
| **Product** | `azurerm_api_management_product_policy` | All APIs attached to a given product. Used for access contracts + unified-ai. |
| **API** | `azurerm_api_management_api_policy` | One API's inbound/backend/outbound/on-error pipeline. Used by every inference API. |
| **Operation** | `azurerm_api_management_api_operation_policy` | A single operation inside an API. Used for `deployments` + `deployment-by-name`. |

Policy **fragments** are separate, reusable chunks that live alongside those
four scopes. A fragment is a standalone APIM resource
(`azurerm_api_management_policy_fragment`) that is uploaded **once** and
then referenced from any policy document with:

```xml
<include-fragment fragment-id="security-handler" />
```

APIM validates every `<include-fragment>` tag and every `{{named-value}}`
reference at the moment the policy is saved, so the fragments + named values
must exist **before** any policy that references them. Terraform enforces
this via `depends_on`.

---

## 2. How `.tf` files become a module

Terraform automatically loads **every `.tf` file in a module directory** and
merges them into one configuration — there is no `include` or `import`
directive, and file names are purely organizational. For the APIM module,
these files are all parsed together as one unit:

```
modules/apim/
  main.tf                      # APIM service, loggers, diagnostic, named values, universal-llm + azure-openai APIs
  policy-fragments.tf          # ~25 fragments (static + dynamic)
  backends.tf                  # LLM backends, pools, content safety, AI search, embeddings
  extra-apis.tf                # unified-ai, ai-search, doc-intel, ai-model-inference, openai-realtime, weather, MCP
  named-values-extras.tf       # JWT-* named values, PII key, operation policies
  api-center-onboarding.tf     # API Center registration (optional)
  foundry-subscription.tf      # Dedicated APIM subscription for Foundry (optional)
```

The resources in `policy-fragments.tf` plug into the dependency graph via:

1. **Shared `local.*` blocks** — e.g. `local.all_pools` defined in
   [backends.tf](modules/apim/backends.tf) is consumed by
   `local.backend_pools_code` in
   [policy-fragments.tf](modules/apim/policy-fragments.tf).
2. **Direct resource references** — e.g. `azurerm_api_management.citadel.id`
   in the fragment resource's `api_management_id`.
3. **Explicit `depends_on`** — every `azurerm_api_management_api_policy`
   that uses `<include-fragment>` lists the fragment resources in its
   `depends_on` so APIM's server-side validation finds them.

---

## 3. Fragments (the reusable building blocks)

All fragments are declared in
[modules/apim/policy-fragments.tf](modules/apim/policy-fragments.tf) and
their XML bodies live in [modules/apim/policies/](modules/apim/policies/)
prefixed with `frag-`. There are three kinds.

### 3.1 Static fragments (unconditional)

Mirrored from Bicep's `policy-fragments.bicep`. Declared as a map and
created with `for_each`:

```hcl
resource "azurerm_api_management_policy_fragment" "static" {
  for_each          = local.all_static_fragments
  api_management_id = azurerm_api_management.citadel.id
  name              = each.key
  format            = "rawxml"
  description       = each.value.description
  value             = file("${path.module}/policies/${each.value.file}")
  depends_on        = [ /* all named values */ ]
}
```

The map `local.all_static_fragments = merge(local.static_fragments, local.unified_ai_fragments)`:

| Sub-map | Always on? | Fragment IDs |
|---|---|---|
| `static_fragments` | Yes | `set-backend-authorization`, `set-target-backend-pool`, `set-llm-usage`, `set-llm-requested-model`, `validate-model-access`, `ai-usage`, `raise-throttling-events`, `throttling-events`, `security-handler`, `entra-auth`, `aad-auth`, `aad-auth-custom`, `ai-foundry-deployments`, `llm-usage`, `openai-usage`, `openai-usage-streaming`, `ai-foundry-compatibility`, `set-response-headers`, `responses-id-security`, `responses-id-cache-store`, `strip-backend-headers` |
| `unified_ai_fragments` | `var.enable_unified_ai_api = true` | `central-cache-manager`, `request-processor`, `path-builder` |

> **PII fragments are no longer part of this `for_each` merge.** The
> `pii-anonymization` / `pii-deanonymization` / `pii-state-saving`
> fragments (gated on `var.enable_pii_anonymization`) are now managed by
> `azapi_resource.pii_fragment` (a direct idempotent PUT) because the
> `azurerm` fragment resource hit an LRO polling bug (404 *PolicyFragment
> not found* during `CreateOrUpdate`). `scripts/migrate-pii-fragments.sh`
> drops the old `azurerm` state entries without destroying the fragments.

> **`responses-id-security` / `responses-id-cache-store`** enforce
> per-subscription ownership of Responses API objects; **`strip-backend-headers`**
> removes browser / App Service (ARR) / `X-Forwarded-*` headers before the
> request is forwarded to an AI backend.

### 3.2 Dynamic fragments (computed from `var.llm_backend_config` + `var.model_aliases`)

Mirrored from Bicep's `llm-policy-fragments.bicep`. Each one takes a
placeholder-based XML template from
[modules/apim/policies/](modules/apim/policies/) and injects generated code
into it at plan time via `replace()`. They are **always created** (even
when `llm_backend_config` is empty) because the core API policies reference
them unconditionally and APIM validates fragment IDs at policy-save time.

| Fragment | Source XML | Placeholder | Injected content |
|---|---|---|---|
| `set-backend-pools` | `frag-set-backend-pools.xml` | `//{backendPoolsCode}` | C# `JObject` literals for every pool in `local.all_pools` |
| `get-available-models` | `frag-get-available-models.xml` | `//{modelDeploymentsCode}` | C# `JObject` literals for every model across all backends **plus an alias deployment entry per `var.model_aliases`** |
| `metadata-config` | `frag-metadata-config.xml` | `//{modelsConfigCode}` / `//{modelAliasesCode}` | JSON mapping `model → {pool, apiVersion, timeout}` + alias-to-model mappings |
| `resolve-model-alias` | `frag-resolve-model-alias.xml` | `//{inlineAliasesCode}` | C# alias→underlying-model lookup generated from `var.model_aliases` (own resource `azurerm_api_management_policy_fragment.resolve_model_alias`, always created) |

The generators live in `locals { … }` blocks at the top of
[policy-fragments.tf](modules/apim/policy-fragments.tf):

- `local.backend_pools_code` iterates `local.all_pools` (which is derived in
  [backends.tf](modules/apim/backends.tf) by grouping
  `var.llm_backend_config` by supported model).
- `local.model_deployments_code` iterates a flattened list of all models
  across all backends.
- `local.metadata_models_code` produces a `model → pool` lookup using the
  first backend that advertises support for each model.

Each `replace(file(...), "//{placeholder}", local.generated)` produces the
final XML string stored in `local.set_backend_pools_xml`,
`local.get_available_models_xml`, and `local.metadata_config_xml`, which is
what `azurerm_api_management_policy_fragment.{set_backend_pools,
get_available_models, metadata_config}` upload.

### 3.3 Named values (variables fragments consume)

Named values are APIM's `{{key}}` substitutions. They must exist before any
policy or fragment that references them. Declared in two files:

| Named value | File | Populated from |
|---|---|---|
| `uami-client-id` | [main.tf](modules/apim/main.tf) | `var.managed_identity_client_id` |
| `piiServiceUrl` | [main.tf](modules/apim/main.tf) | `var.pii_service_endpoint` (count-gated on PII) |
| `contentSafetyServiceUrl` | [main.tf](modules/apim/main.tf) | `var.content_safety_endpoint` (count-gated on content safety) |
| `tenant-id`, `client-id`, `audience`, `entra-auth` | [main.tf](modules/apim/main.tf) | `var.entra_*` with safe placeholder fallbacks |
| `JWT-TenantId`, `JWT-AppRegistrationId`, `JWT-Issuer`, `JWT-OpenIdConfigUrl` | [named-values-extras.tf](modules/apim/named-values-extras.tf) | `var.jwt_*` or `not-configured` |
| `piiServiceKey` (secret) | [named-values-extras.tf](modules/apim/named-values-extras.tf) | `var.pii_service_key` |
| `aws-access-key`, `aws-secret-key` (secret), `aws-region` | [named-values-extras.tf](modules/apim/named-values-extras.tf) | `var.aws_*` or `NOT_CONFIGURED` — always created so the `set-backend-authorization` fragment compiles even without an AWS Bedrock backend |
| `backend_api_key` (per-backend, secret) | [named-values-extras.tf](modules/apim/named-values-extras.tf) | One per backend whose `auth_config.named_value_key` is set; a Key Vault reference when `key_vault_secret_uri` is supplied, otherwise an explicit value |

Every static-fragment resource declares `depends_on` on **all** named
values above so APIM can resolve `{{…}}` tokens at fragment-create time.

---

## 4. Policy scopes in this repo

### 4.1 API-level policies

Each API loads a full policy document and wires in behavior by
`<include-fragment>`ing the fragments above.

| API resource | Policy XML | Uses fragments |
|---|---|---|
| `azurerm_api_management_api_policy.universal_llm` ([main.tf](modules/apim/main.tf)) | [policies/universal-llm-api-policy-v2.xml](modules/apim/policies/universal-llm-api-policy-v2.xml) | `security-handler`, `set-llm-requested-model`, `validate-model-access`, `set-backend-pools`, `set-target-backend-pool`, `set-backend-authorization`, `set-llm-usage`, `ai-foundry-compatibility`, `set-response-headers`, `raise-throttling-events` |
| `azurerm_api_management_api_policy.azure_openai` ([main.tf](modules/apim/main.tf)) | [policies/azure-open-ai-api-policy.xml](modules/apim/policies/azure-open-ai-api-policy.xml) | `security-handler`, `set-llm-requested-model`, `validate-model-access`, `set-backend-pools`, `set-target-backend-pool`, `set-backend-authorization`, `set-llm-usage`, `set-response-headers`, `raise-throttling-events` |
| `azurerm_api_management_api_policy.unified_ai` ([extra-apis.tf](modules/apim/extra-apis.tf)) | [policies/unified-ai-api-policy.xml](modules/apim/policies/unified-ai-api-policy.xml) | `security-handler`, `central-cache-manager`, `request-processor`, `path-builder`, `set-backend-pools`, `set-target-backend-pool`, `set-backend-authorization`, `set-response-headers` |
| `azurerm_api_management_api_policy.ai_search` | [policies/ai-search-index-api-policy.xml](modules/apim/policies/ai-search-index-api-policy.xml) | `security-handler`, `ai-usage` |
| `azurerm_api_management_api_policy.doc_intelligence_legacy` + `doc_intelligence` | [policies/doc-intelligence-api-policy.xml](modules/apim/policies/doc-intelligence-api-policy.xml) | `security-handler`, `ai-usage` |
| `azurerm_api_management_api_policy.ai_model_inference` | [policies/ai-model-inference-api-policy.xml](modules/apim/policies/ai-model-inference-api-policy.xml) | `security-handler`, `ai-usage` |
| `azapi_resource.openai_realtime_policy` | [policies/openai-realtime-policy.xml](modules/apim/policies/openai-realtime-policy.xml) | WebSocket auth only |
| `azurerm_api_management_api_policy.weather` | [sample/weather/policy.xml](modules/apim/sample/weather/policy.xml) | None (sample) |
| `azapi_resource.weather_mcp_policy` + `ms_learn_mcp_policy` | [policies/mcp-default-policy.xml](modules/apim/policies/mcp-default-policy.xml) | MCP default auth |

Every one of these API-policy resources declares:

```hcl
depends_on = [
  azurerm_api_management_policy_fragment.static,
  azurerm_api_management_policy_fragment.set_backend_pools,
  azurerm_api_management_policy_fragment.get_available_models,
  azurerm_api_management_policy_fragment.metadata_config,
]
```

so APIM finds every `<include-fragment>` target at validation time.

### 4.2 Operation-level policies

Declared in [named-values-extras.tf](modules/apim/named-values-extras.tf).

| Operation | API | Policy XML |
|---|---|---|
| `deployments` (GET `/deployments`) | `universal-llm-api` | [policies/universal-llm-api-deployments-policy.xml](modules/apim/policies/universal-llm-api-deployments-policy.xml) |
| `deployment-by-name` (GET `/deployments/{id}`) | `universal-llm-api` | [policies/universal-llm-api-deployment-by-name-policy.xml](modules/apim/policies/universal-llm-api-deployment-by-name-policy.xml) |
| `openai-deployments` (GET `/deployments`) | `azure-openai-api` | [policies/universal-llm-api-deployments-policy.xml](modules/apim/policies/universal-llm-api-deployments-policy.xml) |
| `openai-deployment-by-name` (GET `/deployments/{id}/info`) | `azure-openai-api` | [policies/universal-llm-api-deployment-by-name-policy.xml](modules/apim/policies/universal-llm-api-deployment-by-name-policy.xml) |
| `deployments` + `deployment-by-name` (unified-AI) | `unified-ai-api` | [policies/unified-ai-api-deployments-policy.xml](modules/apim/policies/unified-ai-api-deployments-policy.xml), [policies/unified-ai-api-deployment-by-name-policy.xml](modules/apim/policies/unified-ai-api-deployment-by-name-policy.xml) |

All four `deployments` / `deployment-by-name` operation policies
`<include-fragment fragment-id="get-available-models" />`, which means they
are **count-gated** on `length(var.llm_backend_config) > 0` — if no LLM
backends are configured, the dynamic fragment isn't created and these
operation policies aren't attached.

### 4.3 Product-level policies

| Product | Policy XML | Where |
|---|---|---|
| `default-ai-access` | None (inline policy not set here) | [main.tf](modules/apim/main.tf) |
| `unified-ai-product` | [policies/unified-ai-product-subscription.xml](modules/apim/policies/unified-ai-product-subscription.xml) | [extra-apis.tf](modules/apim/extra-apis.tf) |
| Per-use-case access-contract products | Per-service `policy_xml`, or [citadel-access-contracts/policies/default-ai-product-policy.xml](citadel-access-contracts/policies/default-ai-product-policy.xml) when blank | [citadel-access-contracts/main.tf](citadel-access-contracts/main.tf) (standalone) / [modules/access-contracts/main.tf](modules/access-contracts/main.tf) |

Access-contract product policies set context variables (e.g. the
`allowedModels` set-variable and `enableResponseHeaders`) and include the
`set-llm-requested-model`, `validate-model-access`, and `set-response-headers`
fragments to enforce per-product rules. See [§9.1](#91-access-contracts-onboarding).

---

## 5. End-to-end request flow (Universal LLM API)

What happens at runtime when a client calls
`POST /models/chat/completions`:

```text
1. APIM matches request → universal-llm-api (policy: universal-llm-api-policy-v2.xml)

2. inbound {
     <base/>                                  // inherits global + product policy
     <include-fragment id="security-handler"/>       // API-key + optional JWT
     <include-fragment id="set-llm-requested-model"/> // reads body.model
     <set-variable name="allowedBackendPools" .../>   // per-instance RBAC
     <set-variable name="defaultBackendPool" .../>
     <include-fragment id="validate-model-access"/>  // enforces contract allowedModels
     <include-fragment id="set-backend-pools"/>      // DYNAMIC: injects pool defs from llm_backend_config
     <include-fragment id="set-target-backend-pool"/> // picks pool for requested model
     <include-fragment id="set-backend-authorization"/> // MI token, key, or OAuth
     <include-fragment id="set-llm-usage"/>          // captures token usage for EH
     <include-fragment id="ai-foundry-compatibility"/> // CORS
   }

3. backend {
     <retry count="2" condition="...">              // retries 429 + 5xx (not pool-exhausted)
       <forward-request buffer-request-body="true"/>
     </retry>
   }

4. outbound {
     <base/>
     <include-fragment id="set-response-headers"/>   // UAIG-* diagnostic headers
   }

5. on-error {
     <base/>
     <include-fragment id="raise-throttling-events"/> // pushes 429 metrics to Monitor
     <include-fragment id="set-response-headers"/>
   }
```

The two dynamic fragments (`set-backend-pools`, `get-available-models`) are
what make this pipeline generic — re-apply with a new `llm_backend_config`
and the routing logic updates without touching any XML.

---

## 6. Apply-time ordering (why `depends_on` matters)

Terraform's graph resolves to roughly this order inside the APIM module:

```text
1. azurerm_api_management.citadel
2. Named values (uami, pii, content-safety, entra-*, JWT-*, piiServiceKey)
3. azurerm_api_management_policy_fragment.static            (for_each map)
   azurerm_api_management_policy_fragment.set_backend_pools  (dynamic)
   azurerm_api_management_policy_fragment.get_available_models
   azurerm_api_management_policy_fragment.metadata_config
   azurerm_api_management_policy_fragment.resolve_model_alias
   azapi_resource.pii_fragment                              (PII, when enabled)
4. azurerm_api_management_backend.* / azapi_resource.llm_backend / pool / content-safety / embeddings
5. azurerm_api_management_api.{universal_llm, azure_openai, unified_ai, ...}
   azurerm_api_management_api_operation.* (chat-completions, deployments, deployment-by-name, ...)
6. azurerm_api_management_api_policy.*               ← validates <include-fragment> + {{named-value}}
   azurerm_api_management_api_operation_policy.*    ← validates <include-fragment>
7. azurerm_api_management_product.*
   azurerm_api_management_product_policy.*
   azurerm_api_management_product_api.*
```

If you ever see a 400 at apply time like
*"Policy reference is not resolved: The fragment 'xxx' cannot be found"* or
*"Named value 'yyy' is not defined"*, the fix is always to add the missing
entry to the `depends_on` of the policy resource — the graph doesn't know
about `<include-fragment>` text inside an XML file.

---

## 7. Feature-flag matrix

| Variable | Effect on fragments | Effect on policies |
|---|---|---|
| `enable_unified_ai_api` | Creates 4 unified-AI fragments (`central-cache-manager`, `request-processor`, `path-builder`, `set-response-headers`) | Creates unified-AI API + its policy + 2 op policies + product + product policy |
| `enable_pii_anonymization` | Creates 3 PII fragments via `azapi_resource.pii_fragment` | No direct policy; referenced from universal-llm + unified-ai |
| `enable_pii_redaction` | — | Creates `piiServiceUrl` + `piiServiceKey` named values + `pii-usage-eventhub-logger` |
| `enable_content_safety` | — | Creates `contentSafetyServiceUrl` named value + content-safety backend |
| `enable_jwt_auth` | — | Populates 4 JWT-* named values (else placeholders) |
| `enable_azure_ai_search` | — | Creates `azure-ai-search-index-api` + its policy + `ai_search` backends |
| `enable_document_intelligence` | — | Creates two document intelligence APIs + policies |
| `enable_ai_model_inference` | — | Creates `ai-model-inference-api` + policy |
| `enable_openai_realtime` | — | Creates WebSocket API + policy via azapi |
| `is_mcp_sample_deployed` | — | Creates weather-api + weather-mcp + ms-learn-mcp + 3 policies |
| `length(var.llm_backend_config) > 0` | Creates the dynamic fragments | Enables 4 operation policies on universal-llm / azure-openai |
| `length(var.model_aliases) > 0` | Injects alias deployments into `get-available-models` / `metadata-config` and populates `resolve-model-alias` | Aliases resolve to underlying models at request time |
| Standalone `citadel-access-contracts/` (`var.services` + `var.use_case`) | — | Creates per-use-case products + product-API links + subscription + policy (+ optional KV secrets / Foundry connection) against existing APIM |

---

## 8. Where to change things

| Task | Edit this file |
|---|---|
| Add a new reusable policy snippet (available in all APIs) | Add XML to [modules/apim/policies/](modules/apim/policies/) + add entry to `local.static_fragments` in [policy-fragments.tf](modules/apim/policy-fragments.tf) |
| Change which fragments an API uses | Edit the API's policy XML (e.g. [universal-llm-api-policy-v2.xml](modules/apim/policies/universal-llm-api-policy-v2.xml)); no Terraform changes needed |
| Add a new API with its own policy | Add `azurerm_api_management_api` + `azurerm_api_management_api_policy` in [extra-apis.tf](modules/apim/extra-apis.tf) with `depends_on` on the fragments used |
| Add a new named value | Add resource in [main.tf](modules/apim/main.tf) or [named-values-extras.tf](modules/apim/named-values-extras.tf) + append to the `depends_on` list of `azurerm_api_management_policy_fragment.static` |
| Add a new backend pool routing rule | Add to `var.llm_backend_config` — dynamic fragments regenerate automatically |
| Add a per-use-case access contract | Add a service entry to `var.services` (+ `var.api_name_mapping`) in the standalone [citadel-access-contracts/](citadel-access-contracts/) module (no XML edits unless you need custom per-service `policy_xml`) |
| Onboard an LLM backend to a live APIM | Add to `var.llm_backend_config` in the standalone [llm-backend-onboarding/](llm-backend-onboarding/) module |

---

## 9. Standalone onboarding modules

Two root modules re-use the same policy model but target an **already-running**
APIM via `data` sources (no APIM creation). They are for day-2 onboarding and
are not wired from the core deployment.

### 9.1 Access contracts onboarding

[citadel-access-contracts/main.tf](citadel-access-contracts/main.tf) onboards a
single use-case. Inputs are `var.apim`, `var.use_case`
(`{ business_unit, use_case_name, environment }`), `var.api_name_mapping`
(service code → existing APIM API names), and `var.services` (list of
`{ code, endpoint_secret_name, api_key_secret_name, policy_xml }`). Per service
`code` it creates:

- An APIM product `<code>-<business_unit>-<use_case_name>-<environment>`.
- Product→API links from `var.api_name_mapping[code]`.
- A product policy (`policy_xml`, else `policies/default-ai-product-policy.xml`).
- A subscription `<…>-SUB-01`.
- Optional Key Vault secrets for the endpoint + key (`var.use_target_key_vault`; secret names lower-cased, `_`→`-`).
- An optional Foundry connection (`var.use_target_foundry`) via
  `azapi_resource.foundry_connection`, type
  `Microsoft.CognitiveServices/accounts/projects/connections@2026-03-01`
  (auth `ApiKey`, metadata from `var.foundry_config`).

> This replaces the older `enable_access_contracts` + `var.access_contracts`
> wiring. `modules/access-contracts/` is the equivalent in-graph module and
> uses the same `var.services` / `var.use_case` shape but is **not wired from
> the root** in the current deployment.

### 9.2 LLM backend onboarding

[llm-backend-onboarding/main.tf](llm-backend-onboarding/main.tf) registers LLM
backends + routing against an existing APIM (`data.azurerm_api_management.citadel`).
It creates:

- `azapi_resource.llm_backend` (`Microsoft.ApiManagement/service/backends@2024-06-01-preview`) per backend, with circuit-breaker rules gated on `var.configure_circuit_breaker`, and `<model>-backend-pool`s for any model served by 2+ backends.
- The 3 dynamic fragments (`set-backend-pools`, `get-available-models`, `metadata-config`) plus `resolve-model-alias`, all with `var.model_aliases` support.
- A focused static-fragment set: `set-backend-authorization`, `set-target-backend-pool`, `set-llm-requested-model`, `set-llm-usage`, `validate-model-access`, `responses-id-security`, `responses-id-cache-store`.
- Named values `aws-access-key` / `aws-secret-key` / `aws-region` (AWS Bedrock auth, `NOT_CONFIGURED` defaults) and a per-backend `backend_api_key` named value (Key Vault reference or explicit value) for each backend with `auth_config.named_value_key`.