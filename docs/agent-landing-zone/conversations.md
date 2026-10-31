# Conversations & files

Conversation context, saved history and file uploads are separate capabilities.
Choose the behavior you need before enabling storage or administrative panels.

## Context during a chat

The default hosted orchestrator is stateless. The UI sends the available
conversation transcript with each turn. The hosted container does not load
managed conversation history on its own.

Without optional continuity, context lasts for the active UI session. Reloading
the browser, restarting it or starting a new chat does not provide durable
history. A conversation identifier scopes a request. Knowing that identifier
does not grant access to another person's messages or uploaded documents.

## Resume a saved conversation

Hosted continuity lets the UI read and append messages in a managed Conversations
store. It is disabled by default through `HOSTED_CONTINUITY_ENABLED=false`.
The UI still sends the resulting transcript to the stateless orchestrator.

Before enabling it, configure the store and validate user isolation. In the
default `delegated` ownership mode, the UI's middle-tier identity requires a
reviewed agent-scoped `UserIdentityImpersonation` grant and a deployed Responses
protocol version of at least `2.0.0`. Set
`HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED=true` only after that authorization
has been verified. This setting records evidence, it does not grant permission.

An explicit `capability` ownership mode instead uses signed owner handles and
user OBO for store calls. It requires its own signing-key setup. Do not select
it as a fallback after delegated authorization fails.

### Continuity settings

These settings are ignored while continuity is disabled. Nonblank environment
values override remote settings when the continuity loader reads them.
Invalid required settings fail startup.

| Setting | Default or requirement |
| --- | --- |
| `HOSTED_CONTINUITY_ENABLED` | `false` |
| `HOSTED_CONVERSATION_OWNER_BINDING` | `delegated`. Explicit alternative: `capability`. |
| `HOSTED_CONVERSATION_STORE_BASE_URL` | Required HTTPS Conversations-store URL. HTTP is accepted only for local loopback development. There is no hosted-endpoint fallback. |
| `HOSTED_CONVERSATION_STORE_RESOURCE_SCOPE` | Required data-plane scope ending in `/.default`. Falls back to `HOSTED_AGENT_RESOURCE_SCOPE`, not an ARM management scope. |
| `HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED` | `false`. Required as `true` for validated delegated ownership. |
| `HOSTED_AGENT_PROTOCOL_VERSION` | Required in delegated mode, at least `2.0.0`. |
| `HOSTED_CONVERSATION_CAPABILITY_KEY` | Capability mode only. At least 32 characters after trimming, supplied through a Key Vault reference. |
| `HOSTED_CONVERSATION_CAPABILITY_KEY_ID` | Required with the capability signing key. |
| `HOSTED_CONVERSATION_CAPABILITY_TTL_SECONDS` | `900`, valid range `60` to `86400`. |

The standalone UI loader defaults history limits to `HOSTED_HISTORY_MAX_ITEMS=40`
and `HOSTED_HISTORY_MAX_TOKENS=8000`. Platform composition can publish different
values: its continuity defaults are `100` items and `32000` estimated tokens,
with capability key ID `v1`. These values do not activate continuity.
Valid ranges are `1` to `500` items and `256` to `200000` estimated tokens.

The store client reads one ascending page of at most 100 items and does not
follow pagination. Larger item settings do not extend that read. It trims the
oldest items in the returned page using an approximate character-based token
budget. The last remaining item is retained and the new question is added
afterward. These settings are not hard model-input limits or a guarantee of
the latest complete transcript in a long conversation.

Store read and append failures are reported, not converted into an empty or
successfully saved conversation. A rejected owner handle does not silently
create a replacement conversation. Locks and idempotency tracking are local
to a process, not distributed coordination.

## History and administration

An administrative panel is not required merely to retain active-session context.
User-facing panel history additionally requires actual panel deployment,
active continuity and `PANEL_HISTORY_ENABLED=true`. Delegated enumeration and
operator access have independent authorization gates.

See [Administration](operations.md) for panel setup and
[User feedback](user-feedback.md) for owner-scoped feedback.

The Container Apps orchestrator uses a different path: its classic conversation
API persists messages and feedback in Cosmos DB with authenticated ownership
checks. Some writes run in background tasks. Receiving a streamed answer is
not an acknowledgement that all writes completed. Classic history also does
not enable cross-conversation profile personalization.

## Upload files to a conversation

Conversation uploads require the optional ingestion service.
`DEPLOY_INGESTION_CONTAINER_APP=false` hides controls and rejects attachments
before files are dispatched. `true` retains authentication, validation and
conversation checks. A missing value preserves legacy eligibility, while an
invalid boolean fails configuration loading.

Hosted uploads need a valid issued conversation ID and the authenticated
uploader's object ID before file reads or ingestion dispatch. Uploaded files
remain scoped to that user and conversation. Native Foundry IQ source ingestion
does not replace this conversation-upload path.

Anonymous embedded sessions cannot upload files. Follow
[Ingestion](ingestion.md) to enable the required processing and
[document formats](multimodality.md) to check supported inputs.

## Open citations and downloads

Native hosted citations use a signed, short-lived UI download link. The UI
rechecks the current identity and source authorization when the link is opened.
Shared Blob/ADLS documents use the user's Storage OBO permission.
Conversation uploads require a fresh native Search match for the exact document,
conversation and uploader before a workload Blob read is allowed.

The native route limits streamed documents to 100 MiB and 120 seconds and does
not retry a response after streaming has started. Search ownership checks are
bounded and deny access when the exact authorized document is not found.
Classical standalone citations can retain their separate SAS/direct-link path.
See [Protected citation downloads](application-auth.md#protected-citation-downloads)
for the consent, storage permissions and verification steps.

Restarting the UI invalidates process-local embedded sessions and download
grants. A saved citation or conversation ID alone is never permission to
download a document.
