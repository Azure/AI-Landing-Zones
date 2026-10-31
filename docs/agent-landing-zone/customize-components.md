# Customize components

Change application source when a documented setting is insufficient.
Prefer [Application settings](application-settings.md) and
[Strategies & prompts](agent-strategies.md) before creating a fork.
Use [Run locally](local-development.md) to prepare a development environment.

## Choose the owner

| Change | Repository and starting point |
| --- | --- |
| Agent reasoning flow, prompts, model/tool composition | [Orchestrator](https://github.com/Azure/agent-app-orchestrator), `src/strategies/`, `src/prompts/`, and `src/plugins/` |
| File parsing, chunking, source jobs, indexing | [Ingestion](https://github.com/Azure/agent-app-ingestion), `chunking/`, `jobs/`, and `tools/` |
| Chat presentation, identity/session handling, backend client | [UI](https://github.com/Azure/agent-app-ui), `src/gpt_rag_ui/`, `public/`, and `.chainlit/` |
| Operator dashboard | The relevant service's `frontend/`, not the chat UI |
| Platform resources, component selection, immutable source pins | [Agent Landing Zone](https://github.com/Azure/agent-landing-zone), not component `infra/` placeholders |

Make the smallest change in its owning repository. Keep executable examples,
sample documents, schemas, and regression tests with the code. User, operator,
and developer guides belong on this central site. Local engineering contracts,
ADRs, policies, and changelogs retain their own repository purpose.

## Strategies and prompts

A strategy is the orchestrator's implementation of how a turn uses models,
retrieval, and tools. To add or extend one:

1. Inspect a nearby implementation in `src/strategies/` and the shared
   `base_agent_strategy.py`. Preserve its async construction and streaming
   behavior rather than adding a second execution loop to the HTTP handler.
2. Register a new key in `agent_strategies.py` and
   `agent_strategy_factory.py`. The factory handles synchronous and awaitable
   constructors. An enum member alone does not enable a strategy.
3. Keep prompts in the appropriate directory under `src/prompts/`. The loader
   supports `.jinja2` templates and `.txt` prompts. Preserve the variables
   expected by the selected strategy and test missing/invalid templates.
   The classic path can use configured Cosmos-backed prompts.
   The hosted path requires file-backed prompts.
4. Preserve typed turn events and protocol adapters in `src/orchestration/`
   and `src/api/`. Test cancellation and failures as well as a successful answer.
5. Test classic and hosted paths separately if both are intended. Hosted
   eligibility is enforced by `hosted_strategies.py`, not inferred from the
   classic registry. Do not add a hosted strategy merely by relaxing its guard.

The registered classic keys are `maf_lite`, `maf_agent_service`,
`single_agent_rag`, `mcp`, `multimodal`, and `nl2sql`. `multiagent` is not
registered. `rag` and `multimodal_rag` are not keys. Hosted execution admits
only the first four, requires caller-supplied history, and does not use classic
Cosmos conversation state or profile memory.

Prompt variants and settings do not grant source permissions. Preserve denied
retrieval as an error where strict authorization requires it.
See [API reference](application-api.md) for protocol boundaries.

## Tools and retrieval

A tool is an operation the agent can call. Model Context Protocol, or MCP,
is a protocol for exposing tools. An MCP tool called by a strategy is distinct
from an MCP knowledge source consulted by Foundry IQ.

- Extend the existing plugin/connector used by the strategy. Keep argument
  validation, timeout, cancellation, and result shaping at that boundary.
- Follow [Tools & MCP](agent-tools.md) for supported integrations rather than
  embedding endpoint URLs or credentials in a prompt.
- Preserve the separation between workload authentication and delegated user
  authorization. Hosted Toolbox calls need validated platform call context.
  Native retrieval and protected downloads require their own user tokens.
- Do not accept client-supplied groups, user IDs, indexes, or document URLs as
  proof of access. Add negative tests for cross-user and source-denied requests.
- For SQL, keep a read-only database principal as the primary security boundary.
  Generated-SQL validation is not a substitute for database permissions.

Retrieval backend selection does not switch every datasource or tool.
Use [Foundry IQ](foundry-iq.md) and the relevant source guide for source
registration. Source configuration and consent remain operator tasks.

## Chunkers and ingestion jobs

A chunker splits a document into the records used for retrieval. In the
ingestion repository:

1. Implement or extend a class under `chunking/chunkers/` using
   `base_chunker.py` and a nearby parser as the contract.
2. Register format selection in `chunking/chunker_factory.py`.
   Preserve the distinction between text fallback, transcripts, spreadsheets,
   JSON, document analysis, and multimodal processing. Office support depends
   on the selected analysis service and version.
3. Exercise the parser through `DocumentChunker` in
   `chunking/document_chunking.py`. It returns chunks, record errors, and
   warnings. Keep expected index field names, embedding dimensions, and
   document/conversation authorization metadata.
4. Test empty, malformed, oversized, unsupported, and partially failed input.
   Mock analysis, embedding, Blob, and Search clients. A successful HTTP
   envelope is not proof every chunk was indexed.
5. For source jobs, extend the existing job owner. `main.py` composes startup
   and shutdown. `jobs/runtime.py` owns scheduler state, the registry, lock,
   running-job tracking, and cron map. Admin routes use that interface, not
   mutable state imported from `main`.

Do not test a parser by starting the service against production storage.
Startup and cron can index or purge data even without an explicit HTTP request.
Use [Jobs & schedules](ingestion-jobs.md) for execution and recovery.
Keep source samples under the repository's `samples/` rather than adding
document bodies to a guide or a telemetry fixture.

## Chat UI ownership and imports

The distribution installs the **`gpt_rag_ui`** package from `src/gpt_rag_ui/`.
Use imports such as `from gpt_rag_ui.services.history import HistoryService`,
not filesystem-path manipulation.

| Canonical area | Owns |
| --- | --- |
| `bootstrap.py` | ASGI composition and auth-before-Chainlit mount order |
| `api/` | Routes, callbacks, history adapter, and session bridge |
| `services/` | Chat, citations, history, continuity, conversation/download policy, and panel metadata |
| `auth/` | Identity, OAuth, session, and transport security |
| `clients/` | Orchestrator, ingestion, hosted runtime, Conversations, Blob, and Cosmos transports |
| `config/` | Provider/cache, typed settings, and staged asset-root resolution |
| `telemetry/` and `util/` | Instrumentation and pure constants |

Root `main.py`, `app.py`, `datalayer.py`, and `connectors/` are supported
compatibility adapters, not implementation owners. Patch canonical owners in
tests, not private adapter globals. `.quality/migration.json` freezes the
legacy export inventory and `.quality/policy.json` tracks the current scope.
Do not add `sys.path` or `sys.modules` workarounds.

`api.history.OrchestratorDataLayer` adapts Chainlit callbacks and
`get_data_layer()` creates a fresh adapter.
`services.history.HistoryService` owns history/user operations and the shared
user cache. Keep ambient session selection and consume-once request metadata
in the API. Services receive an explicit `HistoryOperationContext`.
Callback, history, and OAuth registration must remain idempotent.
Classic history registration is specific to `CHAT_BACKEND=orchestrator`.

For presentation, start with `public/theme.json`, `public/custom.css`, and
`.chainlit/config.toml`. Preserve light/dark themes, keyboard focus, readable
contrast, responsive layout, and reduced-motion behavior.
Keep the [staged assets](local-development.md#chat-ui) with the installed code.
For embedding, use the existing [portal contract](embed-chat.md), not new
browser-stored credentials or weakened origin checks.

## Operator dashboard changes

Edit React/TypeScript under the owning service's `frontend/`.
Use its [local proxy and Node setup](local-development.md#operator-dashboard-frontend),
start the backend separately, and keep typed frontend payloads aligned with
the [API reference](application-api.md). Do not copy the ingestion configuration
payload into the orchestrator dashboard. They are different contracts.

Test read-only, administrator, unauthenticated, denied, empty, loading, and
failure states. A local development admin bypass is not production
authorization. Configuration writes, unblocking files, manual jobs, and
curation decisions mutate data.

## Validate and adopt the change

Run the owning repository's [behavioral and quality checks](application-testing.md).
Record which protocols and negative-access cases were tested and which live
checks remain unperformed. Follow its local engineering and contribution rules.

When a customized component is ready for separately authorized deployment,
use [Bring your own app](build-your-own-app.md#customize-a-bundled-component).
That guide owns source pinning, application definitions, deployment, and
rollback. Changing a Git remote or pushing a component branch does not update
the platform's validated combination.
