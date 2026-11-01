# Conversations & files

Native execution state and user-facing saved history have separate owners.
`ENABLE_CHAT_HISTORY` and `ENABLE_USER_FEEDBACK` default to `false`.
Private attachments are an independently selected optional capability.
`ENABLE_PRIVATE_ATTACHMENTS` defaults to `false`.

## Context during a chat

A conversational MAF Agent uses the selected host's native session state:
Foundry persistence on Hosted or Durable Task Scheduler (DTS) through the
official Durable Extension on Container Apps.
The UI does not make a stateless adapter stateful by replaying its transcript.

The UI/BFF binds the authenticated owner to native session IDs. Knowing an ID
or calling through a shared service identity does not authorize another
person's messages, pending actions or files.
See [Agent hosting](hosted-agents.md) for the distinct clients.

## Resume a saved conversation

When saved history is enabled, reopen a conversation through the authenticated
UI. The BFF checks its owner
mapping before using the host client to read or continue the native session.
Native state and UI discoverability are different: a persisted session does
not by itself supply a list of the current user's conversations.

The UI/BFF owns titles, owner mappings and other product metadata in its
declared store. That store is not a transcript replay service or a workflow
checkpoint engine. Missing metadata, failed state reads and denied ownership
must not be treated as an empty successful conversation.

<span id="continuity-settings"></span>

### State and metadata dependencies

| Feature | Owner |
| --- | --- |
| Agent conversation/session execution | Selected native host |
| Workflow graph state and pending human input | Selected native host |
| User-to-session/run mapping, titles and discovery | UI/BFF product metadata |
| Message/run feedback | UI/BFF feedback store |
| Private file input and access metadata | Explicit attachment capability; authenticated UI/file boundary and selected native input or authorized tool path |

Hosted execution does not require application Cosmos DB.
Workflow mode or `both` selects UI metadata even with product flags off;
enabled history, feedback or attachments also selects it. The UI reads
`DATABASE_ACCOUNT_NAME`, `DATABASE_NAME` and `NATIVE_UI_METADATA_CONTAINER`
(default `native-ui-metadata`, partition key `/principal_id`, owner value
`tid:oid`).
Only the frontend receives its metadata grant. The container holds owner/run
mappings, references, feedback and attachment descriptors, not bytes,
transcripts, tokens or Foundry/DTS execution checkpoints.
In conversational mode with every product flag off, the UI uses bounded
volatile owner maps. They are lost on UI restart; native host persistence alone
cannot restore the UI mapping or provide saved discovery.
Do not deploy ingestion or a classic orchestrator merely to support metadata.
Saved listing and history reads require `ENABLE_CHAT_HISTORY=true`.
A known owner-bound workflow can resume with history off through
`/api/native/sessions/{id}/resume`; workflow mode already selects metadata.

## History and administration

An administrative panel is not required for native session persistence.
User history and operator access are separately authorized product surfaces;
an operator role does not automatically grant access to every transcript.

Define retention and deletion for native state, owner mappings, feedback,
attachments, audit data and backups separately. A metadata cleanup is not proof
that all downstream artifacts were erased. Confirm partial failures and follow
the installation's retention policy.

Native state is not automatically transferable between hosts or incompatible
workflow publications. Retain the previous deployment and its state for
rollback; do not merge or delete those stores during adoption.
See [Administration](operations.md) and [User feedback](user-feedback.md).

## Private attachments

Enable `ENABLE_PRIVATE_ATTACHMENTS` for conversational operation in
`conversational` or `both`. Workflow attachments are not supported.
The native turn accepts at most **three files**, each at most **64 KiB**:
UTF-8 TXT/Markdown, PDF, PNG or JPEG.

```json
{
  "text": "Use this note in your answer.",
  "attachments": [{
    "name": "note.txt",
    "content_type": "text/plain",
    "data_base64": "SGVsbG8="
  }]
}
```

Send this body to `POST /api/native/sessions/{id}/turns` for an owner-bound
UI session. Strict Base64, content/format signatures and owner checks reject
malformed or mismatched input. Unknown or nonowned session IDs return `404`
before native backend access.

The maximum serialized inline turn is **256 KiB**, checked against both
Hosted and DTS content envelopes. Text, filenames, MIME metadata, data URIs,
Base64 expansion and JSON escaping count toward this budget. Three files
that individually meet their byte limit can still exceed it.
Each name is a basename of `1..128` characters (no path separators, leading
dot or control characters); content type is at most 64 characters.
Base64 text is bounded to 87,384 characters, and decoded input must be
nonempty. Extension and MIME must match:

| Extension | Content type |
| --- | --- |
| `.txt` | `text/plain` |
| `.md` | `text/markdown` |
| `.pdf` | `application/pdf` |
| `.png` | `image/png` |
| `.jpg`, `.jpeg` | `image/jpeg` |

PDF, PNG and JPEG signature checks are input admission checks, not malware
scanning or proof that a model understands the content. Native state capacity
and retention limits remain independent of this UI input budget.

Hosted forwards official `input_file`/image input. DTS carries native
`context_messages` and IDs. This inline path does not use Blob URLs, SAS,
Agent App Ingestion or corporate knowledge publication. UI Cosmos stores
descriptors, not file bytes; review native host input retention separately.
There is no native private-attachment Blob download/reindexing workflow.

Transport tests verify the input path, not model PDF/image understanding.
Use a compatible model and verify its actual output before promising those
capabilities to users.

A model citation, Blob URL or opaque session ID is not a grant.
Shared managed identity does not by itself enforce user isolation.

Custom ingestion remains a separate optional feature, disabled by default.
Select it only when its processing path is actually needed.
[Ingestion](ingestion.md) explains shared-source indexing and
[Document formats & images](multimodality.md) explains processing boundaries.

## Open citations and downloads

Recheck the current identity and source authorization when a protected
citation is opened. Do not trust a browser-supplied object ID,
session ID or document URL as proof of ownership.

Source-delegated access and workload transport credentials are independent.
A source denial cannot be repaired by retrying with the application's broader
identity. Signed selectors and short-lived links do not replace the current
owner/source check.
See [Protected citation downloads](application-auth.md#protected-citation-downloads).

For a process waiting on a person, use
[Workflows & human input](workflows.md). A chat reconnect is not approval.
