# API reference

Use this reference when writing a client or changing a component boundary.
Native Hosted execution, durable execution, ingestion and UI product APIs are
different contracts. A bearer accepted by one surface does not automatically
authorize another.

For identity setup, use [Sign-in & access](application-auth.md).
For settings, schedules, administration and recovery, use
[Application settings](application-settings.md),
[Jobs & schedules](ingestion-jobs.md), [Administration](operations.md), and
[Monitoring & audit](application-monitoring.md).
Examples below illustrate requests, not authorization to run them against
production. Do not put keys or tokens in source, browser code or logs.

## Select the surface

| Surface | Service | Authentication boundary |
| --- | --- | --- |
| Native Responses and managed session operations | Foundry Hosted | Foundry ingress authentication, trusted invocation context and separate source/tool authorization |
| Native durable client operations | Container Apps worker and DTS | Identity-based scheduler access plus the authenticated BFF's owner checks |
| `/document-chunking`, `/text-embedding`, `/ingest-documents` | Ingestion | `X-API-KEY`, not a delegated-user replacement |
| `/retrieve` | Ingestion preview | Separately gated delegated user bearer |
| `/api/*`, `/api/panel/*` | Ingestion administration | Mode-specific mounting and distinct admin gates |
| `/api/native/*` | Authenticated UI/BFF | Enabled application, owner-bound UI session ID and feature gates |
| `/panel/overview/metrics`, `/panel/corpus-curation/*` | Ingestion | Explicit operator role/group and feature gates |

JSON errors commonly contain `detail`, but ingestion skill endpoints also
return record errors and some plain-text `400` responses. Do not impose one
error parser on all routes. An error after a streaming response has started
must be read from the stream, even if the HTTP status was `200`.

## Native execution contracts

The application uses explicit host-specific clients, not one universal state
or request SDK. Select `APPLICATION_MODE` and `ORCHESTRATION_HOST` through
deployment composition. UI session creation selects an already enabled
application; it does not change the deployment's host or mode.
Tools, including optional direct NL2SQL, are registered capabilities rather
than strategy keys.

The former classic ask/feedback stream and strategy-specific conversation
envelopes are not the native protocol. UI feedback belongs to the product
metadata service, not a feedback-shaped model invocation.

### Foundry Hosted

Use the official Responses hosting integration and the selected publication's
native client types. Hosted conversational and workflow applications are
separate publications with separate endpoints when both are selected:
`HOSTED_AGENT_BASE_URL` and `HOSTED_WORKFLOW_BASE_URL`.

Conversation context is native server state. The client sends new input with
the native reference returned by the selected integration; it does not replay
a Chainlit transcript as a substitute for persistence. The application does
not force all requests into stateless execution.

Workflow start sends JSON containing `topic` (at most 8,000 characters), with
`store=true`. Pending review is the native `function_call` named `request_info`;
decode its `arguments.request`. Reply using `previous_response_id` and native
`function_call_output` with the actual `call_id`, carrying the JSON business
reply `{"decision":"approve","comment":"Reviewed"}`. Decision is `approve`
or `reject`, and comment is at most 4,000 characters. Terminal output is the
typed `ResearchReviewResult` in `structured_outputs`.
A reply must match the intended run and currently pending request. A free-form
chat message or fabricated event must not be interpreted as an approval.

Foundry authenticates ingress. Request-aware factories use trusted invocation
context and current source/tool authorization. A service bearer, arbitrary
metadata or known session ID does not establish end-user ownership.
Search and Work IQ delegation are distinct credentials, not interchangeable
tool arguments. See [Sign-in & access](application-auth.md).

Parse the selected SDK's native response and streaming events. An event or
partial text is not evidence of successful terminal completion.
Do not synthesize a second Responses event protocol or treat every stream as
the old conversation-ID-prefixed text format.

### Container Apps and DTS

Use the official Durable Extension client against the provisioned
`DURABLE_TASK_SCHEDULER_CONNECTION_STRING`. The nonsecret managed-identity
binding and registered agent/workflow names must match the worker.
Use actual outputs, not guessed scheduler endpoints.

The standalone worker registers the selected native Agent and Workflow.
It does not require public worker HTTP ingress or an Azure Functions app,
and it does not expose an imitation Hosted Responses server.
Agent sessions, workflow execution and pending human input belong to DTS.

The BFF authenticates the user and checks its owner mapping before native
reads, continuation or human replies. Scheduler RBAC authenticates a service
connection, not a product user. IDs are selectors, not capabilities.
Durable progress need not provide Hosted per-token streaming parity.
The native DTS agent entity version is `2`. Keep client and worker registration
names aligned: `agent-lz-conversation` and `agent-lz-research-review`.
Native outputs can contain typed lists/yields; use the runtime's
`native.contracts` codecs rather than flattening them into invented text or
a universal state envelope.

### State and failure boundaries

UI display metadata and feedback are separate from native session/checkpoint
state. A failed native read must not become a successful empty history.
Do not manually append a UI transcript to a second conversation store.
Host changes and incompatible workflow publications do not transfer state.
See [Conversations & files](conversations.md) and
[Workflows & human input](workflows.md).

Validate call shapes against installed published SDKs and exact application
entrypoints. Local SDK/contract tests do not prove deployed checkpoint
durability, source access, tenant isolation or private routing.
Authentication/source denials must not trigger automatic model replay or a
retry under broader workload permissions.

## Ingestion document APIs

All three document endpoints require `X-API-KEY`.
The validator accepts `DATA_INGEST_APP_APIKEY` and legacy
`INGESTION_APP_APIKEY`. Invalid supplied keys return `401`. The shipped
API-key security dependency rejects a missing header with `403`.
Credential-based Azure SDK access does not make these HTTP routes keyless.

These are JSON record envelopes, not multipart uploads.
Record errors are arrays of objects such as `{"message":"..."}`.
Inspect them even on HTTP `200`.

### Chunk a source document

`POST /document-chunking`:

```json
{
  "values": [{
    "recordId": "document-1",
    "data": {
      "documentUrl": "https://<storage-account>.blob.core.windows.net/<container>/policy.pdf",
      "documentContentType": "application/pdf"
    }
  }]
}
```

`values` must be nonempty. Each item requires string `recordId` and
`data.documentUrl`/`data.documentContentType`.
`documentSasToken` is an optional schema field, not a replacement for the
Blob client's configured access. The handler downloads the document through
that client. **If multiple records are supplied, only the last is processed.**
Use one record per request.

Success returns `{"values":[{"recordId":"document-1","data":{"chunks":[]},
"errors":[],"warnings":[]}]}` with actual chunks in `data.chunks`.
Malformed JSON, schema errors and missing values return `400`.
Chunking failures can be represented as record errors.

### Generate embeddings

An embedding is a numeric vector representing text for similarity search.
`POST /text-embedding`:

```json
{"values":[{"recordId":"text-1","data":{"text":"Retention policy summary"}}]}
```

The response uses `values[]` with `recordId`, `data.embedding`, `errors`,
and `warnings`. A failed record has an error and may have empty `data`.
Invalid JSON or a missing `values` field returns `400`.
This handler does not share the strict schema of `/ingest-documents`.

<span id="ingest-conversation-documents"></span>

### Index supplied document records

`POST /ingest-documents` chunks, embeds and uploads records to Search:

```json
{
  "conversationId": "an-authorized-conversation-id",
  "securityUserIds": ["<authenticated-uploader-object-id>"],
  "values": [{
    "recordId": "attachment-1",
    "data": {
      "fileName": "note.txt",
      "contentType": "text/plain",
      "fileBase64": "SGVsbG8="
    }
  }]
}
```

`conversationId` is nonempty. `values` contains `1..5` records with nonempty
`recordId`, `fileName`, `contentType` and `fileBase64`.
The schema rejects unknown fields at the envelope, record and data levels.
`securityUserIds` is optional in the wire schema. The trusted caller must
derive any uploader ACL from authenticated identity, not user-entered IDs.
An API key alone does not establish user ownership.
This separate ingestion API is not the native UI attachment path. Native
private attachments do not dispatch files here or publish them into Search.

Response example:

```json
{"values":[{"recordId":"attachment-1","indexedChunks":1,"errors":[],"warnings":[]}]}
```

`indexedChunks` counts Search-confirmed uploads, not attempted chunks.
Validation failures return `400`. Chunking, embedding, partial Search writes,
and optional original-Blob persistence can produce per-record errors/warnings.
An HTTP `200` with zero confirmed chunks is not successful indexing.

## Retrieval preview

`POST /retrieve` is separately gated by both `HOSTED_RETRIEVAL_ENABLED` and
`HOSTED_RETRIEVAL_INV_002_VALIDATED`, default `false`.
It returns `503` until both are enabled. The validation setting is an operator
attestation of isolated authorization testing, not an automatic readiness test.

```json
{"query":"invoice retention policy","top":5}
```

Only `query` and optional `top` are accepted. Query text is trimmed, nonblank
and `1..1000` characters. `top` is `1..10`, default `5`.
Identity, groups and index selection are server-owned, not request fields.

Send a delegated user bearer for the configured
`HOSTED_RETRIEVAL_TOKEN_AUDIENCE`. Toolbox must pass the user's token through.
The service uses its own Search credential for transport and forwards the
user token unchanged in Search's `x-ms-query-source-authorization`.
Neither a static key nor managed identity alone replaces that user token.

The response is `{"results":[...],"count":n}`. Each result has `id`,
`content`, and optional `title`, `url`, `category`, `source` and `score`.
It excludes ACL/vector fields and caps content at 8,000 characters.
Missing/invalid bearer returns `401`, non-delegated/app-only identity `403`,
schema/bounds violations `422`, missing configuration `500`, and sanitized
Search failures `502`. Cleanup failure can still fail an otherwise completed
query.

## Native endpoint boundary

`python -m native.hosted` and `python -m native.durable` do not mount the
classic orchestrator conversation, feedback, history, upload, dashboard or
administration APIs. The native UI composition does not mount
`/panel/conversations`. Use the native UI routes below, host-native clients
and platform configuration tooling. The independently deployed ingestion
administration APIs remain separate supported surfaces.

## Ingestion administration

Classic mode mounts `/api/*` administration and available dashboard assets.
Hosted mode mounts neither classic administration nor `/api/panel/*` unless
the administrative panel is selected. Mounting is resolved at startup.
Jobs and document APIs are not disabled by hiding the panel.

The classic admin reads do not all require Entra. The `require_admin`
dependency used for job/config mutations permits development access when no
tenant is configured. This is not the strict hosted-panel or operator gate.
In particular, the shipped file-unblock route does not carry an unconditional
Admin dependency. Protect the whole service boundary deliberately.

| Request | Contract |
| --- | --- |
| `GET /api/version`, `GET /api/identity` | Version and browser authentication/role context |
| `GET /api/jobs`, `GET /api/files` | `page` default `1`, `pageSize` `1..100` default `20`, `search`, `sortField`, `sortOrder` (`asc`/`desc`), `indexerType`. Files also accept `blocked`. Returns `items`, `total`, `page`, `pageSize`, `indexerTypes`. |
| `GET /api/jobs/queue` | Registered job state, scheduled time, in-flight run and latest-run information |
| `POST /api/jobs/{job_type}/run` | No body. `202` returns `jobType`, `triggerId`, `status:"queued"`. Invalid type format `400`, unknown type `404`, conflicting run `409`, enqueue failure `500`. Queued is not completed. |
| `POST /api/files/unblock?blobName=<encoded-log-path>` | No body. Resets a blocked file-log blob. Requires a path containing `/files/` and ending `.json`. Invalid path `400`, missing log `404`, read/write failure can return `500`. |
| `GET /api/config` | Curated `sections`, flat `settings`, `canEdit`, `authEnabled` |
| `PUT /api/config` | Body `{"updates":[{"key":"RUN_JOBS_ON_STARTUP","value":false}]}` |
| `POST /api/config/reload` | Refreshes local caches, returns `{"status":"ok"}` |
| `POST /api/config/apply` | Refreshes and reapplies schedules. Returns `status`, `rescheduled`, `note`, not a hard container restart. Schedule failures return `500` with failed/rescheduled keys. |

Configuration updates return `applied`, `failed` and `rescheduled`.
All-success is `200`, partial success `207`, all-invalid/denied entries `422`,
and all-write failure `500`. Confirmed writes remain applied if best-effort
cache refresh fails. Schedule or write errors do not reverse earlier effects.
Use [Application settings](application-settings.md) for allowlists and refresh.
Use the job types reported by the running service, not an invented job name.

### Hosted administrative panel

In ingestion hosted/panel mode, `/api/panel/status` exposes nonsensitive
`mode`, `panelEnabled` and `authEnabled` bootstrap metadata.
Protected `/api/panel/*` routes require a validated bearer and exact `Admin`
role, with **no tenant-absent development bypass**.

| Request | Contract |
| --- | --- |
| `GET /api/panel/overview` | Ingestion jobs/files and feedback aggregates |
| `GET /api/panel/feedback?conversationId=<id>` | Optional conversation filter, returns a list of feedback records |
| `POST /api/panel/feedback` | Strict body shown below, returns a record with generated `id`, `createdBy` and `createdAt`, status `201` |
| `GET /api/panel/conversations/{conversation_id}/history` | Returns `501`. Ingestion does not retrieve managed chat message bodies. |

```json
{
  "conversationId": "an-existing-conversation-id",
  "messageId": "message-1",
  "rating": "up",
  "comment": "Useful grounding.",
  "tags": ["reviewed"]
}
```

`conversationId` is required and bounded to 256 characters.
`rating` is `up` or `down`. Optional `messageId` is at most 256 characters,
`comment` 4,000 and `tags` at most 16 strings of at most 64 characters.
Unknown fields fail validation. Invalid input returns `422`, denied role
`403`, and Cosmos failures or invalid stored records return sanitized `502`.
This admin feedback shape is not the UI owner-feedback contract below.

## Native UI sessions and actions

All native product routes are under `/api/native`. They authenticate the
current user and bind a server-created UI UUID to that owner and the selected
host's native references. A native reference is not the UI session ID and
neither is authorization.
Unknown or nonowned IDs return opaque `404` **before backend access**.
Stale or duplicate actions return `409`.

| Request | Contract |
| --- | --- |
| `POST /api/native/sessions` | `application` is `conversational` or `workflow`; `201` returns `id`, `application`, `title`, `created_at` with an owner-bound UI UUID |
| `GET /api/native/sessions` | Saved session listing; gated by `ENABLE_CHAT_HISTORY` |
| `POST /api/native/sessions/{id}/turns` | Nonblank `text` of `1..8000` characters and optional `attachments`; returns `response` and `native_ref` |
| `POST /api/native/sessions/{id}/start` | `202` starts the workflow with `topic` |
| `GET /api/native/sessions/{id}/progress` | Returns `{id,status,pending,revision,output}` |
| `POST /api/native/sessions/{id}/actions` | `request_id`, `revision` and typed `response` must match current pending state; `202` returns progress |
| `GET /api/native/sessions/{id}/history` | Native history read; gated by `ENABLE_CHAT_HISTORY` |
| `POST /api/native/sessions/{id}/resume` | Resumes a known owner-bound session; known workflow resume remains available with saved history off |
| `POST /api/native/sessions/{id}/feedback` | `native_ref`, rating `-1` or `1`, optional comment at most 2,000 characters; `201` persists feedback; gated by `ENABLE_USER_FEEDBACK` |

Request bodies reject unknown fields. `request_id` and `native_ref` are
`1..512` characters; revision is the current 64-character lowercase hexadecimal
UI revision, not the DTS entity version.
Missing/invalid bearer returns `401`, nondelegated or denied access `403`,
invalid input `422`, unavailable feature/dependency `503`, and sanitized native
dependency failure `502`.
Use `request_id` and `revision` from current progress, not a cached browser
action. Delivery reported as **submitted** does not mean the durable worker
admitted the reply or completed execution. Read progress to observe the actual
native result. Do not invent an exactly-once business-write guarantee.

Conversation turns can carry at most three attachments, each at most 64 KiB:
UTF-8 TXT/Markdown, PDF, PNG or JPEG. Each entry contains
`{name,content_type,data_base64}` and is subject to strict Base64, format/signature
and owner validation. The larger of the Hosted and DTS serialized inline
envelopes must be at most **256 KiB**, including text, JSON escaping, filenames,
MIME metadata and Base64/data-URI expansion. This is not a raw-file-size sum.
Attachments are supported for conversational operation
in `conversational` or `both`, not workflow input.
Hosted uses official `input_file`/image inputs; DTS uses native
`context_messages` and IDs. There is no attachment Blob URL, SAS, ingestion
dispatch or corporate publication. Transport tests do not establish model
PDF/image understanding.

Workflow mode, `both` or any enabled history, feedback or attachment flag
selects Cosmos UI metadata. Its `/principal_id` partition is `tid:oid`.
Metadata holds descriptors and references, not bytes, transcripts or tokens.
With conversational mode and every product flag off, bounded volatile owner
maps are lost on UI restart; persisted host state alone cannot restore them.

## Operator metrics and corpus curation

These ingestion routes are registered independently and return `503` unless
`DEPLOY_ADMINISTRATIVE_PANEL`, `PANEL_OPERATOR_SURFACES_ENABLED`, an explicit
`PANEL_OPERATOR_APP_ROLE` or `PANEL_OPERATOR_GROUP_ID`, and the
`DATA_INGEST_APP_APIKEY` cursor-signing secret are configured.
They require a validated delegated user with the configured role or group.
App-only tokens return `403`.

| Request | Contract |
| --- | --- |
| `GET /panel/overview/metrics` | Returns `schema_version:1`, `generated_at`, `correlation_id`, and `counts` with conversation, feedback, pending-corpus and decided-corpus counts |
| `GET /panel/corpus-curation/queue?cursor=<opaque>` | Returns `items` and nullable `next_cursor`. Items have `item_id`, `document_id`, `title`, `reason_code`, `submitted_at`. |
| `POST /panel/corpus-curation/{item_id}/decision` | Body `{"decision":"approve","note":"Reviewed source"}`. Decision is `approve`, `reject` or `defer`, optional note at most 2,000 characters. Returns `item_id`, `decision`, `decided_at`. |

Small metric buckets below `PANEL_OVERVIEW_MIN_CARDINALITY`, default `5`,
are suppressed as `null`, not zero. Curation operates on blocked-file logs
in Blob, not chat messages. Signed cursors expire after
`PANEL_CURSOR_TTL_SECONDS`, default `600`, and are caller-bound.
Missing/invalid bearer returns `401`, role/group denial `403`, unknown item
`404`, invalid/conflicting decisions or invalid/expired/cross-user cursor
`422`, and data-store failures `502`.

## UI browser and download routes

The UI also owns these browser/session endpoints, not general-purpose
substitutes for the service APIs above:

- `GET /auth/oauth/azure-ad` and
  `GET /auth/oauth/azure-ad/callback` implement configured-tenant sign-in.
- `GET /api/auth/recovery?ticket=<encrypted>` continues explicit protected-source
  sign-in using an encrypted, principal/login-bound, short-lived context.
  It does not replay a model request or download.
- `POST /copilot/auth/bootstrap`, `POST /copilot/auth/recovery`, and
  `POST /copilot/auth/logout` belong to the
  [embedding protocol](embed-chat.md). Preserve its exact-origin and opaque
  session requirements instead of calling them as backend service auth.
- `GET /api/download/{grant_token}` uses a server-issued signed grant plus the
  current authenticated principal/session. It is not a URL-fetch proxy.
  Native protected downloads recheck user/source authorization.
  Invalid grants do not establish access to a container or conversation.

Use [Conversations & files](conversations.md) for file limits, continuity and
download policy, and [Sign-in & access](application-auth.md) for recovery
expiry and no-replay behavior.
