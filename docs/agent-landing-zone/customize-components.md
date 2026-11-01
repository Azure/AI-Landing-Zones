# Customize components

Change application source when a documented setting is insufficient.
Prefer [Application settings](application-settings.md) and
[Agents & prompts](agent-strategies.md) before creating a fork.
Use [Run locally](local-development.md) to prepare a development environment.

## Choose the owner

| Change | Repository and starting point |
| --- | --- |
| Agent definitions, workflow graphs, prompts and registered tools | [Orchestrator](https://github.com/Azure/agent-app-orchestrator), application definitions and tool/connector owners under `src/` |
| File parsing, chunking, source jobs, indexing | [Ingestion](https://github.com/Azure/agent-app-ingestion), `chunking/`, `jobs/`, and `tools/` |
| Chat presentation, identity/session handling, backend client | [UI](https://github.com/Azure/agent-app-ui), `src/gpt_rag_ui/`, `public/`, and `.chainlit/` |
| Ingestion operator dashboard | Ingestion `frontend/`, not the chat UI or native runtime |
| Platform resources, component selection, immutable source pins | [Agent Landing Zone](https://github.com/Azure/agent-landing-zone), not component `infra/` placeholders |

Make the smallest change in its owning repository. Keep executable examples,
sample documents, schemas, and regression tests with the code. User, operator,
and developer guides belong on this central site. Local engineering contracts,
ADRs, policies, and changelogs retain their own repository purpose.

<span id="strategies-and-prompts"></span>

## Agents, workflows and prompts

A MAF Agent handles conversation; a MAF Workflow defines a published process.
Hosting and tools are separate choices. To extend the application:

1. Extend the owning agent definition or workflow graph. Use the official MAF
   execution and human-input APIs, not a second execution loop, polling queue
   or application-owned checkpoint engine.
2. Register the intended capabilities explicitly. Foundry IQ, Search, MCP and
   optional [NL2SQL](nl2sql.md#direct-nl2sql-tool) are tools/capabilities, not a
   mixed strategy registry or a user-facing host picker.
3. Keep packaged instructions and typed tool inputs with the reviewed source.
   Test missing/invalid configuration and prompts. Functional App Configuration
   values refresh through the supported provider; an existing workflow retains
   its run snapshot without freezing authorization.
4. Use the explicit host integration: request-aware Hosted agent/workflow
   factories and native Responses persistence, or the official Durable
   Extension worker/client with DTS. Do not build a universal protocol or
   state SDK to hide these differences.
5. Keep workflow/executor and native registration names stable within a
   compatible publication. Test reconnect, rejection, stale/duplicate human
   replies, ownership denial and required-tool failure on each supported host.

Prompt variants and settings do not grant source permissions. Preserve denied
retrieval as an error where strict authorization requires it.
See [Workflows & human input](workflows.md) for state and recovery, and the
[API reference](application-api.md) for host-specific client boundaries.

## Tools and retrieval

A tool is an operation the agent can call. Model Context Protocol, or MCP,
is a protocol for exposing tools. A registered MCP operation is distinct
from an MCP knowledge source consulted by Foundry IQ.

- Extend the existing tool/connector used by the application. Keep argument
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
Import the installed package rather than using filesystem-path manipulation.

| Canonical area | Owns |
| --- | --- |
| `bootstrap.py` | ASGI composition and auth-before-Chainlit mount order |
| `api/` | Authenticated `/api/native` routes, callbacks and session bridge |
| `services/` | Native application operations, owner metadata, feedback, citations and download policy |
| `auth/` | Identity, OAuth, session, and transport security |
| `clients/` | Explicit Hosted and DTS clients, plus separately required ingestion, Blob and Cosmos transports |
| `config/` | Provider/cache, typed settings, and staged asset-root resolution |
| `telemetry/` and `util/` | Instrumentation and pure constants |

Root `main.py`, `app.py`, `datalayer.py`, and `connectors/` are supported
compatibility adapters, not implementation owners. Patch canonical owners in
tests, not private adapter globals. `.quality/migration.json` freezes the
legacy export inventory and `.quality/policy.json` tracks the current scope.
Do not add `sys.path` or `sys.modules` workarounds.

Keep native session selection and consume-once request metadata at the
authenticated API boundary. The native application service owns UI UUID
mapping and product metadata; explicit host clients own execution calls.
Do not route native operations through an old orchestrator data-layer adapter.
Callback, history, and OAuth registration must remain idempotent.
Native history uses the selected host client plus UI-owned metadata, not a
retired orchestrator conversation API. Keep session/run owner checks explicit
before native reads, continuation and pending human replies.

For presentation, start with `public/theme.json`, `public/custom.css`, and
`.chainlit/config.toml`. Preserve light/dark themes, keyboard focus, readable
contrast, responsive layout, and reduced-motion behavior.
Keep the [staged assets](local-development.md#chat-ui) with the installed code.
For embedding, use the existing [portal contract](embed-chat.md), not new
browser-stored credentials or weakened origin checks.

## Operator dashboard changes

Edit React/TypeScript under ingestion's `frontend/`.
Use its [local proxy and Node setup](local-development.md#operator-dashboard-frontend),
start the backend separately, and keep typed frontend payloads aligned with
the [API reference](application-api.md). Native orchestrator entrypoints do
not mount retired dashboard/admin APIs.

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
