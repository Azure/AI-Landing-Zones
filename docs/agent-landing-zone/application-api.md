# API reference

Use this reference when writing a client or changing a component boundary.
Classic orchestration, hosted execution, ingestion, and panel APIs are
different contracts. A bearer accepted by one surface does not automatically
authorize another.

For identity setup, use [Sign-in & access](application-auth.md).
For settings, schedules, administration, and recovery, use
[Application settings](application-settings.md),
[Jobs & schedules](ingestion-jobs.md), [Administration](operations.md), and
[Monitoring & audit](application-monitoring.md).
Examples below illustrate requests, not authorization to run them against
production. Do not put keys or tokens in source, browser code, or logs.

## Select the surface

| Surface | Service | Authentication boundary |
| --- | --- | --- |
| `/orchestrator`, `/conversations` | Classic orchestrator | Service credential, plus a separate user bearer where required |
| `/responses`, `/invocations` | Foundry-hosted orchestrator | Foundry ingress authentication and configured delegated retrieval or Toolbox context |
| `/document-chunking`, `/text-embedding`, `/ingest-documents` | Ingestion | `X-API-KEY`, not a delegated-user replacement |
| `/retrieve` | Ingestion preview | Separately gated delegated user bearer |
| `/api/dashboard/*` | Classic orchestrator dashboard | Conditional mounting and dashboard Admin gate |
| `/api/*`, `/api/panel/*` | Ingestion administration | Mode-specific mounting and distinct admin gates |
| `/panel/conversations/*` | UI backend | Delegated bearer, enabled history/continuity, and owner-index check |
| `/panel/overview/metrics`, `/panel/corpus-curation/*` | Ingestion | Explicit operator role/group and feature gates |

JSON errors commonly contain `detail`, but ingestion skill endpoints also
return record errors and some plain-text `400` responses. Do not impose one
error parser on all routes. An error after a streaming response has started
must be read from the stream, even if the HTTP status was `200`.

## Classic orchestrator

### Authentication

The service-auth dependency checks these credentials in priority order:

1. `X-Service-Authorization: Bearer <service-access-token>`, validated against
   the configured tenant, `ORCHESTRATOR_AUTH_AUDIENCE`, and
   `ORCHESTRATOR_ALLOWED_CALLER_IDS`.
2. `dapr-api-token`, validated against the server's `APP_API_TOKEN` or
   `DAPR_API_TOKEN`.
3. `X-API-KEY`, validated against `ORCHESTRATOR_APP_APIKEY`.

An invalid higher-priority credential fails rather than falling through.
Missing or invalid service credentials return `401`.
`Authorization: Bearer <user-api-token>` is a **separate** user boundary.
`ALLOW_ANONYMOUS` defaults to `true` for the ask route, not for bypassing
service auth or granting access to history.
Use `DISABLE_AUTH=true` only in controlled private development.

The user token must target the configured API, not Microsoft Graph.
The backend derives identity and groups from validated context.
Deprecated `client_principal_id`, `client_principal_name`,
`client_group_names`, and identity-like `user_context` fields do not establish
an authenticated user.

### Ask and stream

`POST /orchestrator`, `Content-Type: application/json`:

```json
{
  "ask": "Summarize the document retention policy.",
  "conversation_id": "an-existing-conversation-id",
  "question_id": "q-123",
  "user_context": {}
}
```

Omit `conversation_id` for a new conversation. `question` is a compatibility
alias for `ask`. A non-feedback request without either returns `400`.
Model/schema violations return `422`. User authentication failures return
`401`, and authorization failures can return `403`.

The response has `Content-Type: text/event-stream` and `X-Correlation-ID`.
Server-sent events, or SSE, normally frame incremental output with event/data
lines. **The classic wire format is a legacy text stream:** it starts with
the conversation ID followed by a space, then emits text chunks, citations,
and tool progress. Normal chunks are not JSON `data:` events.
Preserve this distinction when implementing a client.
An in-stream error is framed as:

```text
event: error
data: An internal server error occurred.

```

Network chunk boundaries are not semantic message boundaries.
Do not treat emitted text as proof that a background Cosmos write completed.
Persistence and feedback behavior are described in
[Conversations & files](conversations.md).

### Feedback

The same `POST /orchestrator` accepts feedback without `ask`:

```json
{
  "type": "feedback",
  "conversation_id": "an-existing-conversation-id",
  "question_id": "q-123",
  "is_positive": true,
  "stars_rating": 5,
  "feedback_text": "The answer was useful."
}
```

`conversation_id` is required for this operation. The rating is optional and,
when present, must be `1..5`. A missing conversation ID returns `400`.
Success is JSON, not a stream:

```json
{"status": "success", "message": "Feedback saved successfully"}
```

### User conversation routes

All routes below require service authentication **and** an authenticated user.
Anonymous ask eligibility does not authorize them. Detail and mutation routes
check the authenticated owner. Missing conversations return `404`, denied
ownership can return `403`, and persistence failures return `500`.

| Request | Contract |
| --- | --- |
| `GET /conversations?skip=0&limit=10&name=policy` | Optional name filter. Returns `conversations`, `has_more`, `skip`, `limit`. Each row has `id`, `name`, `created_at`, and `last_updated`. |
| `GET /conversations/{conversation_id}` | Returns `id`, `name`, `principal_id`, `created_at`, `last_updated`, and `messages`. Do not assume every strategy stores a full transcript in Cosmos. |
| `PATCH /conversations/{conversation_id}` | Body `{"name":"Retention policy"}`. Returns `id`, `name`, `last_updated`. Empty names fail schema validation or return `400` after trimming. |
| `DELETE /conversations/{conversation_id}` | Soft delete. Returns `{"status":"success","message":"Conversation deleted successfully"}`. It does not erase every downstream artifact. |

## Hosted orchestrator

The hosted runtime is stateless across turns. It does not create, read, append,
or delete managed Foundry Conversations. The authenticated client supplies
ordered history on every request. An opaque conversation label scopes tagging
and conversation retrieval, not ownership of a stored transcript.

Foundry authenticates ingress. Do not expose the container directly and assume
it implements the classic service-auth dependency.
With native protected retrieval, the configured UI obtains downstream user
tokens through on-behalf-of exchange. The raw Search token travels separately
as `x-client-search-token`. Work IQ can additionally require the original
validated UI API assertion as `x-client-work-iq-assertion`, not a Search token.
These are raw credential values, not `Bearer `-prefixed strings or trusted
principal claims.
For hosted `mcp`, a valid platform-injected `x-agent-foundry-call-id` is
mandatory, including on response-management routes. Missing or malformed
context returns `401`. A caller cannot replace it with claimed groups,
metadata, a static key, or service identity.

Only `maf_lite`, `maf_agent_service`, `single_agent_rag`, and `mcp` are
hosted-eligible. Unsupported strategies fail rather than falling back.

For the non-Toolbox protected retrieval path, missing/malformed required
credentials return `401`, credentials over 8,192 UTF-8 bytes return `431`,
and missing required conversation scope returns `422`.
Unsupported authorization mode or incomplete source configuration can return
`503`. Generic Foundry IQ MCP sources are rejected with `503` in this protected
native path until a verified source-specific delegation contract exists.
That gate is separate from the hosted `mcp` strategy.

### Responses

`POST /responses` is the canonical hosted protocol:

```json
{
  "input": [
    {"role": "user", "content": "What is the retention period?"},
    {"role": "assistant", "content": "It depends on the record category."},
    {"role": "user", "content": "Explain the policy for invoices."}
  ],
  "stream": true,
  "store": false,
  "metadata": {
    "conversation_id": "an-opaque-conversation-label",
    "question_id": "q-124"
  }
}
```

`input` can also be one nonblank string. A message array must be nonempty,
ordered, and end with the current nonblank `user` ask.
Supported roles are `user`, `assistant`, `system`, and `developer`.
Content is text, either a string or `input_text`/`output_text` parts with
`text` strings. Images and other multimodal parts are rejected.
Metadata contains only string keys and values.

The adapter always forces `store=false`, including when the caller omits it
or sends `true`. Non-null `previous_response_id` and `background=true` return
`422`. The adapter ignores routing/sampling fields it does not honor, including
top-level `conversation`, `model`, and `session_id`. They cannot select stored
state or replace the server's agent definition.
Malformed JSON returns `400`. Invalid input contracts return `422`.
Retrieval/context guards can reject the request before streaming.

With `stream=true`, parse named SSE events and their JSON `data` payloads.
The lifecycle includes `response.created`, `response.in_progress`, output-item
and content-part events, `response.output_text.delta`, and terminal
`response.completed` or `response.failed`.
The terminal object is not a classic text stream.
The runtime does not emit internal citation/tool-progress events as fabricated
Responses annotation or function-call objects.

### Invocations

`POST /invocations?api-version=v1` is the compatibility protocol used by the
shipped UI hosted client:

```json
{
  "messages": [
    {"role": "user", "content": "What is the retention period?"},
    {"role": "assistant", "content": "It depends on the record category."},
    {"role": "user", "content": "Explain the policy for invoices."}
  ],
  "conversation_id": "an-opaque-conversation-label",
  "metadata": {"question_id": "q-124"}
}
```

`messages` requires at least one entry. Roles are only `user` and `assistant`,
and `content` is a string. The final message must be a nonblank user ask.
Omit `conversation_id` to let the runtime generate a label.
Metadata is an optional object. Caller-provided identity is not trusted.
Malformed JSON returns `400` and model/final-message violations return `422`.
Unsupported strategy selection returns `422`.

The response is named SSE with JSON data and an `X-Response-ID` header.
`response.created` contains a `response` object with `conversation.id`.
The UI also recognizes the legacy `conversation_id` field.
Missing, malformed, or conflicting identifiers fail the UI client explicitly.
Text arrives in `response.output_text.delta` events. Error events and failed
terminal events must not be presented as complete answers.

By default, the UI sends `conversation_id` only after the runtime has issued
one. It resends available Chainlit history without a local item/token cap and
adds the current ask if needed. A Chainlit thread ID is not a hosted
conversation ID.
When optional continuity is enabled, the UI owns separate Conversations store
calls. The hosted invocation then omits a conversation reference.
See [Conversations & files](conversations.md) for store ownership, one-page
history limits, and failure semantics. Do not send a Responses `input` body
to `/invocations` or use `previous_response_id` as continuity.

### Conversations store used by the UI

These are downstream store operations, **not additional routes implemented by
the hosted orchestrator**:

| Store request | UI client contract |
| --- | --- |
| `POST /conversations` | Sends `{}`, requires a nonempty `id` in the response |
| `GET /conversations/{id}/items?order=asc&limit=100` | Expects a `data` array of message items. The requested limit is clamped to `1..100`, and the client does not follow pagination. |
| `POST /conversations/{id}/items` | Sends `{"items":[...]}` containing the turn's message items |
| `DELETE /conversations/{id}` | Deletes the managed conversation, separately from panel metadata cleanup |

Store authentication is independent of hosted invocation authentication.
The default `delegated` owner binding uses a service bearer with a
server-derived `x-ms-user-identity` header and requires the validated
agent-scoped impersonation grant. Explicit `capability` binding uses the
user's OBO bearer and a signed owner handle in the UI flow, not that header.
Never accept a browser-supplied `x-ms-user-identity`.
Store read/append failures are explicit failures, not empty history or a
durable-write acknowledgement. Setup, limits, and ownership validation remain
in [Conversations & files](conversations.md).

### Protected-source stream errors and probes

Both protocols can report `authentication_required`, `interaction_required`,
and `source_denied`. These are non-retryable by automatic model/tool replay.
Only a bounded, validated `claims_challenge` on `interaction_required` is
eligible for the UI's explicit sign-in recovery. Do not render provider error
bodies or follow source-supplied authorization URLs.
Use [Sign-in & access](application-auth.md) for recovery.

`GET /readiness` and compatibility `GET /health` return `status`, immutable
image `version`, and `eligible_strategies`. They report the image contract,
not successful live model, Search, or source authorization.

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
Malformed JSON, schema errors, and missing values return `400`.
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

### Ingest conversation documents

`POST /ingest-documents` chunks, embeds, and uploads records to Search:

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
`recordId`, `fileName`, `contentType`, and `fileBase64`.
The schema rejects unknown fields at the envelope, record, and data levels.
`securityUserIds` is optional in the wire schema. The trusted caller must
derive any uploader ACL from authenticated identity, not user-entered IDs.
An API key alone does not establish user ownership.
The UI checks its upload gate, user, file, and conversation before dispatch.

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

Only `query` and optional `top` are accepted. Query text is trimmed, nonblank,
and `1..1000` characters. `top` is `1..10`, default `5`.
Identity, groups, and index selection are server-owned, not request fields.

Send a delegated user bearer for the configured
`HOSTED_RETRIEVAL_TOKEN_AUDIENCE`. Toolbox must pass the user's token through.
The service uses its own Search credential for transport and forwards the
user token unchanged in Search's `x-ms-query-source-authorization`.
Neither a static key nor managed identity alone replaces that user token.

The response is `{"results":[...],"count":n}`. Each result has `id`,
`content`, and optional `title`, `url`, `category`, `source`, and `score`.
It excludes ACL/vector fields and caps content at 8,000 characters.
Missing/invalid bearer returns `401`, non-delegated/app-only identity `403`,
schema/bounds violations `422`, missing configuration `500`, and sanitized
Search failures `502`. Cleanup failure can still fail an otherwise completed
query.

## Orchestrator administration

`ENABLE_DASHBOARD=false` by default. When enabled, `/api/dashboard/*` mounts
and `/dashboard` is served if built assets exist.
With Entra configured, protected APIs require a valid API bearer with exact
`Admin` role. Missing/invalid bearer returns `401`, missing role `403`, and
a tenant without client ID `500`. Without a tenant, the development gate is
open. Do not expose that configuration publicly.
`/version` and `/auth-config` are bootstrap exceptions.

| Request under `/api/dashboard` | Contract |
| --- | --- |
| `GET /version`, `GET /auth-config` | Image version and browser tenant/client/authority/scope bootstrap, respectively |
| `GET /overview?days=30` | Counts and daily series. Optional paired `from`/`to` select a bounded date range. Invalid dates/ranges return `400`. |
| `GET /conversations?skip=0&limit=50&search=policy` | Cross-user metadata, `limit` `1..200`, returns `conversations`, `has_more`, `skip`, `limit` |
| `GET /conversations/{id}` | Conversation detail, reconstructed user turns, thread reference, and feedback. Missing ID returns `404`. This is not a full Foundry transcript proxy. |
| `GET /config` | Returns `label` and grouped `sections` of allowlisted settings |
| `PUT /config` | Body `{"settings":[{"key":"AGENT_STRATEGY","value":"maf_lite"}]}` |
| `POST /config/refresh` | Rebuilds the local cache, returns `status:"refreshed"` and `detail` |
| `POST /config/apply` | Refreshes the local cache, returns `status:"applied"` and `detail`, not a container restart |

Configuration validation errors return `422` and per-key `errors` inside
`detail`. Write failures return `500`. Writes are sequential, not transactional.
An error does not roll back earlier writes. Read back effective values because
write labels and provider precedence can differ.

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
| `GET /api/jobs/queue` | Registered job state, scheduled time, in-flight run, and latest-run information |
| `POST /api/jobs/{job_type}/run` | No body. `202` returns `jobType`, `triggerId`, `status:"queued"`. Invalid type format `400`, unknown type `404`, conflicting run `409`, enqueue failure `500`. Queued is not completed. |
| `POST /api/files/unblock?blobName=<encoded-log-path>` | No body. Resets a blocked file-log blob. Requires a path containing `/files/` and ending `.json`. Invalid path `400`, missing log `404`, read/write failure can return `500`. |
| `GET /api/config` | Curated `sections`, flat `settings`, `canEdit`, `authEnabled` |
| `PUT /api/config` | Body `{"updates":[{"key":"RUN_JOBS_ON_STARTUP","value":false}]}` |
| `POST /api/config/reload` | Refreshes local caches, returns `{"status":"ok"}` |
| `POST /api/config/apply` | Refreshes and reapplies schedules. Returns `status`, `rescheduled`, `note`, not a hard container restart. Schedule failures return `500` with failed/rescheduled keys. |

Configuration updates return `applied`, `failed`, and `rescheduled`.
All-success is `200`, partial success `207`, all-invalid/denied entries `422`,
and all-write failure `500`. Confirmed writes remain applied if best-effort
cache refresh fails. Schedule or write errors do not reverse earlier effects.
Use [Application settings](application-settings.md) for allowlists and refresh.
Use the job types reported by the running service, not an invented job name.

### Hosted administrative panel

In ingestion hosted/panel mode, `/api/panel/status` exposes nonsensitive
`mode`, `panelEnabled`, and `authEnabled` bootstrap metadata.
Protected `/api/panel/*` routes require a validated bearer and exact `Admin`
role, with **no tenant-absent development bypass**.

| Request | Contract |
| --- | --- |
| `GET /api/panel/overview` | Ingestion jobs/files and feedback aggregates |
| `GET /api/panel/feedback?conversationId=<id>` | Optional conversation filter, returns a list of feedback records |
| `POST /api/panel/feedback` | Strict body shown below, returns a record with generated `id`, `createdBy`, and `createdAt`, status `201` |
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
`comment` 4,000, and `tags` at most 16 strings of at most 64 characters.
Unknown fields fail validation. Invalid input returns `422`, denied role
`403`, and Cosmos failures or invalid stored records return sanitized `502`.
This admin feedback shape is not the UI owner-feedback contract below.

## UI conversation panel

The UI's `/panel/conversations` routes are distinct from ingestion
administration. They return `503` unless administrative panel, panel history,
and hosted continuity are active. They require a delegated bearer and derive
the user from it. Every per-conversation operation checks the Cosmos owner
index **before** touching the managed Conversations store.
An unknown or nonowned ID returns opaque `404`, not another user's metadata.
Missing/invalid bearer returns `401`, unauthorized identity `403`,
invalid schema/cursor `422`, and store failures `502`.

| Request | Contract |
| --- | --- |
| `GET /panel/conversations?limit=20&cursor=<opaque>` | Limit `1..50`, returns `items` of `id`, `title`, `created_at`, `updated_at`, plus nullable `next_cursor` |
| `GET /panel/conversations/{id}/messages?limit=200` | Limit `1..200`, returns `{"items":[{"role":"user","content":"..."}]}`. Content is capped at 20,000 characters per item and underlying store pagination limits still apply. |
| `POST /panel/conversations/{id}/feedback` | Strict owner-feedback body below, returns the record plus `created_at` |
| `GET /panel/conversations/{id}/feedback` | Returns `{"items":[...]}` of owner feedback |
| `DELETE /panel/conversations/{id}` | Deletes managed conversation first, then feedback/owner metadata. Returns `status:"deleted"` or `status:"partial"` with `detail` if metadata cleanup failed. A store delete failure returns `502` without metadata cleanup. |

```json
{
  "feedback_id": "feedback-1",
  "message_ref": "message-1",
  "rating": 5,
  "category": "helpful",
  "comment": "Answered my question."
}
```

`feedback_id` and `message_ref` are required, each `1..128` characters.
Optional `rating` is `-5..5`, `category` at most 64 characters, and `comment`
at most 2,000. Unknown fields are rejected.
Feedback is user-authored feedback, not a place to copy retrieved documents
or the underlying transcript. Cursors are caller-bound and must not be
transferred between users.

## Operator metrics and corpus curation

These ingestion routes are registered independently and return `503` unless
`DEPLOY_ADMINISTRATIVE_PANEL`, `PANEL_OPERATOR_SURFACES_ENABLED`, an explicit
`PANEL_OPERATOR_APP_ROLE` or `PANEL_OPERATOR_GROUP_ID`, and the
`DATA_INGEST_APP_APIKEY` cursor-signing secret are configured.
They require a validated delegated user with the configured role or group.
App-only tokens return `403`.

| Request | Contract |
| --- | --- |
| `GET /panel/overview/metrics` | Returns `schema_version:1`, `generated_at`, `correlation_id`, and `counts` with conversation, feedback, pending-corpus, and decided-corpus counts |
| `GET /panel/corpus-curation/queue?cursor=<opaque>` | Returns `items` and nullable `next_cursor`. Items have `item_id`, `document_id`, `title`, `reason_code`, `submitted_at`. |
| `POST /panel/corpus-curation/{item_id}/decision` | Body `{"decision":"approve","note":"Reviewed source"}`. Decision is `approve`, `reject`, or `defer`, optional note at most 2,000 characters. Returns `item_id`, `decision`, `decided_at`. |

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

Use [Conversations & files](conversations.md) for file limits, continuity, and
download policy, and [Sign-in & access](application-auth.md) for recovery
expiry and no-replay behavior.
