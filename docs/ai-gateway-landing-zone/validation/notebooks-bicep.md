---
render_macros: false
---

# Citadel validation notebooks

For private developer access before running these application scenarios, use the
optional [Developer VPN deployment and validation notebook](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-developer-vpn-validation.ipynb)
and its [Bicep deployment notes](../operate/developer-vpn.md).
It creates a separate connectivity resource group and does not require private
APIM data-plane access to bootstrap. Provisioning is explicitly gated because
VPN Gateway and DNS Private Resolver incur ongoing charges.

These notebooks have two purposes: **prove the deployed feature works**, and
**show how it is configured, deployed, and consumed**. Feature definitions,
policy previews, requests, SDK integration, and expected outcomes stay visible.
Shared utilities handle repetitive mechanics; they are not a replacement for
the feature demonstrations.

## Setup and execution

Start with [Environment Setup](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-environment-setup.ipynb) and the
[setup guide](notebook-setup.md). Use the repository-root
`.venv-validation-local` Python 3.11 kernel and the dependencies in
[requirements.txt](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/requirements.txt). The environment name is retained for
compatibility; the active notebook directory is **`validation`**, not
`validation-local`. Do not install or upgrade packages inside scenario notebooks.

Open the repository in VS Code and use **Run All** from a fresh kernel.
Restart the kernel after updating repository helpers or installed packages:
Python otherwise keeps previously imported modules cached. Alerting's configuration
cell explicitly refreshes its consumer helpers before importing their functions,
so rerunning that cell also picks up newly added helpers.
Configuration defaults use the selected azd environment; no edits are needed for
settings or models that azd already supplies. Only genuinely external inputs
(such as separate target resources, provider credentials,
or token/evidence fixtures) need to be supplied when absent. Scenario execution
does not prompt for missing inputs.
Both the repository root and this directory are supported working directories.
Authenticate Azure CLI and select the intended azd environment before starting.
The notebooks must not change your active subscription automatically.

Deploy the gateway first using the [full deployment guide](../deploy/bicep-full-deployment.md).
These scenarios require an existing hub; the environment-setup notebook alone
does not deploy or configure Azure resources.

### Step output and fail-fast initialization

Every executable cell has a short purpose, input, and expected-output guide.
It emits two clearly separated sections:

| Section | What it shows |
|---|---|
| **INFO (blue)** | What will run: command or task, endpoint, selected models, coordinates, and expected outcome. |
| **RESULT (green)** | Task or check completed successfully, with actual response/output and elapsed time. Definition-only cells still confirm execution. |
| **RESULT (amber)** | A warning, optional skip, or an HTTP response whose expected outcome still needs validation. |
| **RESULT (red)** | Failed or blocked required checks, exceptions, and actionable details. |

Shared [output formatters](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/shared/utils.py) render HTML cards and colored
result tables in notebooks, with an ANSI terminal fallback. Output is **compact
by default**: key inputs, models, actual API requests, deployment commands, and
one step result. Routine successful azd/account queries, Bicep compilation, and
individual passing assertions are not printed. Passing checks are counted in the
step result; failures and skips keep their actionable details.

Large payloads are collapsed under **Details**, and API replies are summarized
(chat content, response IDs, embedding dimensions, or image count) rather than
dumping vectors, headers, or image data. Credentials remain redacted and actual
response objects are unchanged. Set `utils.set_output_verbose(True)` after
importing utils to temporarily restore diagnostic commands and detailed payloads;
use `False` to return to compact output. Expected negative responses such as a
policy's HTTP 403 still count as a green **PASS** when the assertion matches.

Initialization validates mandatory inputs before provisioning or feature tests.
Missing, blank, or nested `REPLACE` values produce one error listing the missing
parameter names, without showing secret values. Fill those values and rerun from
the beginning. An empty model plan after exclusions is not a successful
initialization, but operation annotations are **not required by default**.

**Backend Onboarding loads coordinates and `LLM_BACKEND_CONFIG` from azd during
initialization.** Run All uses those values to generate and deploy contracts,
without manual approval flags or a required capability map. It shows the Azure
subscription ID/name, tenant, APIM, resource group, region, backend IDs and model
operation mapping before deployment. Running this notebook refreshes shared
routing from the selected environment's configuration. `model_aliases=None`
loads optional `MODEL_ALIASES`/`LLM_MODEL_ALIASES` from azd; an explicit list wins.
Its functionality tests use **Universal LLM (`/models`) only**, including
discovery, chat, embeddings, Responses creation (POST only), SDK streaming and aliases. The SDK uses
an OpenAI-compatible base URL, not Azure deployment-path routes; its temporary
access contract grants only `universal-llm-api`. Other API deployments are unchanged.
Responses GET and input-items are not tested by onboarding; All Models retains
its separate Responses lifecycle coverage.

The same azd-first behavior applies throughout this suite. Deployments required
by a scenario are enabled by default; review/source approval flags are not
mandatory user inputs. Optional explicit routing parameter files and coordinate
overrides still take precedence. Model skip keywords apply before selection and
request planning, including when a scenario rebuilds its catalog. Unrelated
image or embedding entries in a mixed deployment are not missing parameters for
a chat scenario: inapplicable cases are reported as SKIP.

**Access Contracts enables Key Vault and Foundry scenarios by default.** Provide
explicit target subscription/resource-group/vault and account/project coordinates
in its configuration cell. The hub's azd resources are not silently substituted
for these external targets. Setting an integration flag to `False` explicitly
opts out and removes only that scenario's input requirement.
No manually supplied Foundry project identity token is required. Access Contracts
keeps `ProjectManagedIdentity` connection authentication and its JWT-enforcing
policy, validates the deployed configuration/publication, and explicitly defers
identity-protected API and load requests to Agent Frameworks. Direct API-key
contracts are still exercised here; deferred identity checks are SKIP, not PASS.

Required secrets and token fixtures come from documented environment variables
or an explicit secret-store lookup, never `input()`/`getpass()` midway through
Run All. Interactive authentication examples are disabled by default and must
be run deliberately. Environment Setup remains a prerequisite: package
installation can require a kernel restart before running scenarios.

### Supplying genuinely external inputs once

These optional values can be resolved from the selected azd environment when
provided; missing external values are reported by name rather than replaced
with invented resources. Explicit notebook overrides still win.

| Scenario input | Supported configuration |
|---|---|
| External Key Vault target | `VALIDATION_EXTERNAL_KEYVAULT` JSON: `{"subscriptionId":"<subscription>","resourceGroupName":"rg-consumers","name":"kv-consumers"}` |
| External Foundry target | `VALIDATION_EXTERNAL_FOUNDRY` JSON: `{"subscriptionId":"<subscription>","resourceGroupName":"rg-agents","accountName":"aif-agents","projectName":"project-agents"}` |
| Entra client secret / role-control tokens | Automatically loaded/acquired after [Entra setup](../security/entra-id-setup.md). `VALIDATION_ENTRA_CLIENT_SECRET`, `VALIDATION_JWT_NO_ROLE_TOKEN`, and `VALIDATION_JWT_DEVICE_TOKEN` are optional overrides |
| Existing published agent | `VALIDATION_FOUNDRY_AGENT_NAME` or `FOUNDRY_AGENT_NAME`; project coordinates use `FOUNDRY_ACCOUNT_NAME`, `FOUNDRY_PROJECT_NAME`, `FOUNDRY_PROJECT_ENDPOINT`, or an unambiguous `AI_FOUNDRY_SERVICES` entry |
| Agent predecessor contracts | Automatically uses the latest complete local Access Contracts handoff for the selected gateway. Optional `VALIDATION_ACCESS_CONTRACTS_MANIFEST` or keyed JSON `VALIDATION_AGENT_CONTRACTS` pins an explicit source. |
| Optional alert notification recipient | `VALIDATION_ALERT_EMAIL` or `ALERT_EMAIL_ADDRESS`; no value runs rules without email. `alert_email_address=""` explicitly disables a saved recipient. |
| Application Insights | `APIM_APP_INSIGHTS_NAME`, otherwise exact unambiguous APIM logger resource discovery using the supported ARM REST API (`az rest`) |
| Self-hosted gateway target | `VALIDATION_SELF_HOSTED_GATEWAY_URL` (HTTPS origin, no `/models`) and `VALIDATION_SELF_HOSTED_GATEWAY_ID` (APIM gateway resource name); notebook overrides win |
| Optional Cosmos key authentication | `VALIDATION_COSMOS_KEY`; prefer the default identity-based access |

The target JSON examples are illustrative, not valid deployed resources. Keep
secrets in an approved secret store or private runtime environment, never saved
notebook source or source control. Access Contracts intentionally does not
substitute the hub's vault/project for these external target inputs.

## Recommended execution order

The 15 scenarios are:

| Order | Notebook | What it proves / prerequisites |
|---|---|---|
| 1 | [Backend Onboarding](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/llm-backend-onboarding-runner.ipynb) | Backend/pool/fragment deployment, discovery, HTTP/SDK consumption and aliases through Universal LLM only. Review complete routing configuration before replacing shared fragments. |
| 2 | [All Models](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-universal-llm-api-all-models-tests.ipynb) | Unrestricted discovery, chat, embeddings, stored Responses create/get/input-items. Operations are inferred by default. |
| 3 | [Access Contracts](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-access-contracts-tests.ipynb) | Business-unit model grants and capacity; explicit Key Vault/Foundry targets are required by default, with deliberate opt-outs. Retain its manifest for the next notebook. |
| 4 | [Agent Frameworks](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-agent-frameworks-tests.ipynb) | Microsoft Agent Framework, Foundry SDK, and LangChain consumption of the preceding contracts. |
| 5 | [Model Aliases](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-model-aliases-tests.ipynb) | Discovery, direct controls, priority/weighted selection, and RBAC across APIs. Needs compatible alias members. |
| 6 | [PII Processing](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-pii-processing-tests.ipynb) | Masking/restoration evidence, blocking, chunked large payloads, optional Cosmos analytics. Needs Language Service and appropriate telemetry access. |
| 7 | [Unified AI API](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-unified-ai-api-tests.ipynb) | Native/compatible routing, Responses, streaming, authentication, denied paths, RBAC, and headers. |
| 8 | [JWT Authentication](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-jwt-authentication-tests.ipynb) | Universal `/models/chat/completions` and Unified OpenAI v1 `/unified-ai/v1/chat/completions` only. Run after Entra setup without manual inputs. Automatically acquires/decodes application, current-user and negative-client tokens; tests both positive identities and missing-Model.Invoke rejection. |
| 9 | [Extended Providers](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/llm-backend-onboarding-extended-providers-runner.ipynb) | Bedrock, Gemini, Anthropic native versus OpenAI-compatible protocols, credential formats, and compatible aliases. Provider credentials are separate prerequisites. |
| 10 | [Session Affinity](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-session-affinity-tests.ipynb) | Independent cookie jars and successful stateful response chaining. Requires a Responses-capable model served by multiple backends. |
| 11 | [Gateway Alerting](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-alerting-tests.ipynb) | Restrictive capacity, HTTP 429/403, configured rules, and observed telemetry. Runs from azd without email; only chat-capable names containing `gpt` but not `image` are eligible, including explicit overrides and skip filters. Requires Application Insights/Monitor permissions. |
| 12 | [Publish Contract](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-publish-contract-tests.ipynb) | MCP initialization/list/call, A2A card/invocation, mixed-asset grants, metrics, and resiliency configuration. Requires the selected source assets. |
| 13 | [Image Models](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-image-models-tests.ipynb) | Real generation/edit images, body/path/header model selection, multipart requests, and negative policy cases. Uses inferred/overridden image operations and configured native provider paths. |
| 14 | [Foundry HR Web Search Chat](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-foundry-hr-web-search-tests.ipynb) | A real Foundry Prompt Agent reusing the HR contract, 10 visualized turns, web-search/citation evidence, and bounded visible token-limit recovery. Run Access Contracts first. |
| 15 | [Self-hosted Gateway](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-self-hosted-gateway-tests.ipynb) | Existing gateway in another cloud/on premises; provisions an access contract with default-on token limits, model RBAC, Content Safety and request PII anonymization. Authenticated `/models/deployments` discovery and a filtered GPT text-only chat loop run exclusively against the self-hosted origin. |

The environment-setup notebook is a separate prerequisite, not an additional
scenario. Archived notebooks and `validation-local` are outside this workflow.

### Self-hosted gateways in other clouds or on premises

The [Self-hosted Gateway notebook](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-self-hosted-gateway-tests.ipynb) requires
an existing gateway, a reachable trusted HTTPS origin, and the `models` API
already associated with that gateway. It does not install containers, change
shared routing, or fall back to the Azure managed gateway. Azure management
access is still required to create or update the scenario's product/subscription.

Set the external target variables above or the corresponding notebook settings.
Keep all four feature switches on, or explicitly turn individual features off
before initialization. Optional `model_allowlist` and `skipped_models` narrow the
configured GPT text/chat plan; empty or invalid selections fail before deployment.
With model RBAC on, deployment discovery must match the grant exactly. With RBAC
off, other deployments may be visible but are never added to the text test loop.

Use a gateway image supporting the selected AI policies. Configure off-cloud
authentication and connectivity for shared inference routing, the Content Safety
backend, and Azure AI Language. The contract reuses the PII implementation locally
with Microsoft Entra Workload ID, not the managed identity of the Azure APIM
resource; grant the workload identity the required Language-service permissions.
No shared fragment is overwritten. PII is request-only anonymization with synthetic
data and fail-closed service errors. Set `REQUESTS_CA_BUNDLE` for private CAs;
certificate verification stays enabled.

Highlighted feature tables appear at initialization, deployment and summary.
Per-model checks require the actual edge gateway ID/current contract marker,
token-accounting headers, completed safety-policy traversal and a masking
transformation when enabled. RBAC denial is verified with its specific error code.
An optional existing **benign text blocklist** fixture verifies Content Safety
denial; without it negative enforcement is SKIP. Deliberate quota exhaustion is
also SKIP, not claimed as proven by accounting headers. Token counters are
gateway-local, not a global cross-cloud quota. Disabling a contract feature does
not remove inherited global/API controls. Cleanup is opt-in and deletes only
this run's newly created product/subscription, retaining the gateway and association.

### HR career-coaching chat with Foundry web search

[Foundry HR Web Search Chat](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-foundry-hr-web-search-tests.ipynb) automatically
loads the HR contract's project connection and granted model. It creates or reuses
the stable `HR-Career-Coach` agent with Foundry's native `WebSearchTool`, then runs one persistent
10-turn conversation about career development, learning, privacy-conscious AI use
and productivity. Every user message, assistant reply, actual source citation,
usage and retry is visualized in the notebook. No separate Bing key is needed
for the general web-search tool; see the
[official Foundry web-search guide](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/tools/web-search).
The tenth prompt asks the agent to recall the earlier name, role, time horizon
and weekly learning budget before rehearsing the manager conversation, matching
the final context-validation check.

The existing gateway-connected model and Foundry project must support that tool.
The notebook does not silently substitute a direct model endpoint if tool use
fails. Its summary requires observed `web_search_call` activity and URL citations,
not just a successfully created agent.

SDK automatic retries are disabled. A rate/token-limit response is highlighted,
then the notebook honors Retry-After/reset hints for at most **one retry per turn**.
`max_wait_seconds=300` bounds that wait; absent usable hints, a visible
`fallback_wait_seconds=90` pause is used. It does not claim to know token
availability without a server hint. Quota exhaustion, repeated limits and waits
beyond the ceiling stop clearly rather than producing invented replies or retrying
forever. User messages are appended once; earlier transcript entries remain
available after a failed turn. Retry idempotency headers are stable per turn.

This exercise creates billable Foundry resources and public-web searches. Use only
the supplied synthetic employee context or equally non-sensitive prompts. Cleanup
is off by default and limited to this run's agent version/conversation; it never
deletes the HR contract or its published connection.

## Configuration and model selection

Explicit notebook configuration takes precedence over the selected azd environment.
Manual mode requires complete resource coordinates and skips azd. Missing required
values, placeholders, malformed JSON, ambiguous resources, or a subscription
mismatch must be corrected before deployment. Enabling an integration is an
explicit decision; discovering a vault does not itself enable Key Vault.

The context reads environment values once. Important existing outputs include
`LLM_BACKEND_CONFIG`, `APIM_NAME`, `AZURE_RESOURCE_GROUP`, `AZURE_LOCATION`,
`AZURE_SUBSCRIPTION_ID`, `AI_FOUNDRY_SERVICES`, and `KEY_VAULT_NAME`.
Restart initialization after changing environment or provisioning outside the
notebook. azd outputs describe configuration, not current provider availability.

### Automatic operations, overrides, and excluded models

Without operation overrides, models use explicitly supplied operation metadata
when present, otherwise these case-insensitive substring rules, in order:

| Model name contains | Assumed operations |
|---|---|
| `image` or `flux` | `image-generation`, `image-edit` |
| Otherwise `embedding` or `text` | `embeddings` |
| Otherwise `gpt` | `chat`, `responses` |
| Anything else | `chat` |

Image rules take priority over `gpt` (so GPT image models are not sent chat
requests). Streaming is assumed for inferred chat models. These are test-planning
assumptions, not evidence that every provider supports the operation; actual
requests still determine the result. Image coverage belongs to Image Models,
and text-only runners record it as explicitly out of scope rather than sending
image models to chat.

Every scenario configuration includes these optional controls:

```python
operation_overrides = None  # Use optional azd mapping, otherwise metadata/inference.
skipped_models = None       # Use optional VALIDATION_SKIPPED_MODELS, otherwise [].

# Examples: use exact names from the displayed model inventory.
operation_overrides = {
    "my-chat-model": ["chat", "responses"],
    "my-image-model": ["image-generation"],
    "my-disabled-model": [],
}
skipped_models = ["mini", "legacy"]  # Case-insensitive substring matching.
```

A supplied `operation_overrides` dictionary replaces the saved azd operation map.
Each entry fully replaces that model's inferred operations; omitted models use
their metadata/inference. An empty list disables a model's tests.
`operation_overrides={}` clears azd operation overrides and restores automatic
fallback. Optional `VALIDATION_MODEL_CAPABILITIES` is a JSON object with the same
shape; it is no longer a required deployment output.

Skip keywords exclude requests, selections, and alias-member tests containing
those names. They do **not** filter the deployed backend configuration or its
discovery results; temporary validation contracts use the selected eligible test
models. An explicit `skipped_models=[]` clears saved exclusions. If every
eligible model is excluded, initialization explains why no tests can run.

For strict manually mapped operation support, set
`overrides["infer_operations"] = False` and provide the required mappings.
Operation labels are case-sensitive: `chat`, `responses`, `embeddings`,
`image-generation`, `image-edit`, and explicit `streaming` for overridden chat
models. Native provider scenarios retain their protocol-specific requests.

**Responses GET and input-items GET returning HTTP 404 are warnings for every
model**, including explicitly overridden models. They are recorded as SKIP, not
FAIL or PASS: retrieval was not validated, and the run may continue. This also
applies to Unified AI's Responses GET; its DELETE checks retain their existing
failure behavior.

Other unsupported retrieval results (405/501, or a specific unsupported-operation
400) remain optional only for **inferred GPT-mini** models. Explicit operation
overrides make those non-404 checks required. Responses POST/create failures,
authentication errors, throttling and general server failures still fail.

Each configuration guide includes input explanations and samples. Some scenarios
need external credentials, existing agents, predecessor manifests, or observed
telemetry that azd does not provide; those remain real prerequisites, not invented
defaults. Access Contracts intentionally keeps explicit external targets mandatory.

Defaults are selected deterministically from compatible deployed entries.
Explicit model overrides must also exist and meet operation/contract constraints.
Declared retirement dates produce warnings, not automatic exclusion. Selecting a
newer model requires deploying it; default operation inference then applies.
Override only exceptions rather than changing thirteen notebooks. Infrastructure
model defaults are not modified by this refactor.

## Contracts and artifacts

Access, backend, and publish deployments use **`.bicepparam` as their primary
editable parameter files and actual deployment inputs**. Shared
[contract helpers](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/shared/contracttools.py) render nested configuration,
preserve escaping, and validate the current file before deployment.

1. Define the feature configuration visibly.
2. Generate and inspect the parameter/policy artifacts.
3. Make any intentional edits to the generated `.bicepparam`.
4. Run the deployment cell, which validates that actual file.
5. Validate deployed state and make real feature requests.

New run artifacts belong under ignored `.runs/<scenario>/<run-id>/`.

### Stable asset identities and reruns

Cloud assets use stable, scenario-specific names, not a run ID or timestamp.
Rerunning a notebook updates the same access-contract products (IDs and display
names), subscriptions, connections, secret names, model aliases, alerts and
action groups. Separate feature cases, such as PII masking, blocking and analytics,
retain separate identities. Validation aliases replace only their own named
entries while preserving unrelated aliases and the full backend inventory.
ARM deployment names are stable too, with a deterministic gateway-scope suffix
and a maximum length of 64 characters so different gateways do not collide.

Foundry uses the stable `HR-ChatAgent` and `HR-Career-Coach` agent names.
An unchanged definition reuses its latest version; a changed definition creates
a new immutable version under the same name, as required by the Foundry API.
Only versions actually created by the current run are cleanup-eligible.

Run IDs still isolate local evidence, request correlation, conversations and
the alerting probe's token counters. Reusing a product must not inherit the
previous probe's exhausted quota. Run a given scenario serially against a gateway:
its policy and configuration are shared, not concurrent per-run resources.
Existing assets with old run-suffixed names are not automatically renamed or deleted.

Keep secrets out of saved notebooks, previews, manifests, and parameter files.
Prefer Key Vault references for provider credentials. Do not print deployment
outputs containing API keys. Retrieve the exact contract subscription rather
than choosing the first available APIM key.
Deployment output filtering preserves allowlisted product/subscription identifiers
and Key Vault reference names, plus Foundry connection names, targets and
authentication metadata, even when the compiled contract refers to secret plans.
Credential values remain excluded; the matching subscription key is read
separately through APIM. An omitted or empty Foundry `connectionNamePrefix` uses
the existing `Hub-<businessUnit>-<useCaseName>-<environment>` naming convention,
including when only selected `foundryConfig` fields are overridden.

The Access Contracts pilot writes a sanitized `access-contracts.json` manifest.
Run Agent Frameworks afterwards: with its unchanged defaults, it automatically
loads the latest complete manifest matching the selected subscription, resource
group, APIM service and recorded azd environment. It maps the three contracts to:

| Agent | Framework | Predecessor contract / consumption |
|---|---|---|
| Sales Assistant | Microsoft Agent Framework | Sales Assistant contract; endpoint/key read from Key Vault |
| HR Chat Agent | Foundry Prompt Agent SDK | HR ChatAgent contract; published project connection with ProjectManagedIdentity |
| Support Bot | LangChain ChatOpenAI | Support Bot contract; exact APIM subscription credential |

The actual product/subscription IDs, selected models and connection methods are
displayed during initialization. Credentials are fetched afresh; the manifest
does not contain keys. Explicit `manifest_path`/contract records or azd source
overrides remain available, and ambiguous equally recent handoffs require an
explicit selection. Keep these products until the successor notebook has finished.
Disabled Foundry publication can return null-valued placeholder metadata; it is
ignored for Sales/Support. Only the HR Foundry contract requires project coordinates.

Backend onboarding refreshes shared routing policies. Confirm that the supplied
configuration includes **all** intended backends and aliases; a partial azd
snapshot is not a safe source for a lossless shared update.

## Results and feature evidence

The shared result collector distinguishes:

- **PASS:** the expected feature outcome was observed, including expected denial.
- **FAIL:** unexpected response, transport error, or invalid response body.
- **SKIP:** an explicitly disabled/unavailable optional feature, with a reason.
- **BLOCKED:** missing prerequisites or evidence for required coverage.

Required failures/blocks and empty required runs cannot produce a successful
final verdict. A green HTTP 200 does not by itself prove PII masking, correct
model routing, streaming completion, or a working image edit.

JWT role tests need a real valid token lacking the required role; an invalid
token's 401 is not evidence of role enforcement. Setup supplies a separate
MCP.Invoke-only client, and the notebook obtains its token automatically. Decoded
claims are checked locally; only live APIM requests prove signature acceptance.
The current user's CLI session must be valid; required MFA/sign-in is surfaced
as an explicit error, not an automatic interactive prompt. Telemetry checks distinguish
configured rules, observed HTTP limits, metric ingestion, alert firing, and
notification delivery. Never infer email delivery from a successful deployment.
Circuit-breaker configuration is distinct from a disruptive trip/recovery test.

Feature-essential load tests are bounded and visible. Additional stress tests
are opt-in. Retries must not hide throttling, weighted selection, or stateful
routing behavior. Cloud requests, generated images, deployment, telemetry
polling, and quota probes incur cost and can alter shared state.

## Cleanup and testing

Cleanup is **off by default**. Preview owned resources first. Delete only new
products/assets created by that run, never a predecessor contract, reused
resource, or shared backend configuration. Retained artifacts may be needed to
investigate failures; a failed summary does not prevent manually running cleanup.

Run local helper/structure tests without cloud credentials from the repository:

```powershell
.\.venv-validation-local\Scripts\python.exe -m unittest discover -s .\validation\tests -v
```

Tests mock external boundaries. Bicep compilation checks generated parameter
syntax, not successful deployment. A fresh-kernel live run in the intended
environment remains necessary to establish actual gateway/provider behavior.
