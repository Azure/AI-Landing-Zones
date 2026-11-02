# Conversations & files

Native execution state and user-facing saved history have separate owners.
The UI's backend for frontend (BFF) checks users and maps them to native sessions.
`ENABLE_CHAT_HISTORY` and `ENABLE_USER_FEEDBACK` default to `false`.
Private attachments are an independently selected optional capability.
`ENABLE_PRIVATE_ATTACHMENTS` defaults to `false`.

<div class="runbook-diagram" markdown="1">

<div class="runbook-diagram__summary" markdown="1">

**Conversation state and private files**

1. The authenticated UI checks ownership before calling the selected native host.
2. Foundry owns Hosted state; DTS owns Container Apps execution state.
3. Optional UI Cosmos stores owner mappings, feedback and attachment descriptors,
   never transcripts, file bytes or native checkpoints.
4. Private attachments are validated inline inputs, separate from shared-source
   ingestion. With all product flags off in conversational mode, owner maps
   are volatile and disappear on UI restart.

</div>

[![The UI sends owner-checked turns and optional validated inline files to one native host. Foundry or DTS persists execution; optional UI Cosmos stores only owner-scoped metadata, not transcripts or file bytes.](../media/runbooks/conversations.svg?v=392864a8037b)](../media/runbooks/conversations.svg?v=392864a8037b){: .runbook-diagram__image aria-label="Open full-size conversation and private-file diagram"}

[Open full-size diagram](../media/runbooks/conversations.svg?v=392864a8037b){: .runbook-diagram__open}

</div>

## Enable saved history or private files

The deployment operator needs the platform checkout, its selected azd
environment and the [deployment permissions](deploy-full-stack.md#prerequisites).
Complete [application access](application-auth.md) first for an existing UI;
for a new environment, follow that guide's registration and deployment order.
Agree retention and file handling with the data owner before enabling either
feature.

1. From the **platform checkout root**, select the intended environment.
   Set only the features you need, using literal `true` or `false`:

```bash
azd env select <environment-name>
azd env set ENABLE_CHAT_HISTORY true
azd env set ENABLE_PRIVATE_ATTACHMENTS true
```

Omit the attachment command if you only need history, or the history command
if you only need private files. Attachments require `APPLICATION_MODE` to be
`conversational` (the default) or `both`. Do not change an existing mode just
to enable history.

2. Run `azd provision` in that same checkout/environment before deploying.

These are supported lifecycle inputs. Provisioning selects the application
Cosmos dependency, creates its metadata container and configures a
container-scoped frontend grant. The deployment identity needs permission to
create that grant; application users do not need direct Cosmos access.
Then deployment reloads the UI with the matching configuration. Follow this
order for an existing environment too; changing a flag only in the portal
does not provision its dependencies.

In **App Configuration > Configuration explorer**, label `agent-lz`, verify
the selected flags and the generated `DATABASE_ACCOUNT_NAME`, `DATABASE_NAME`
and `NATIVE_UI_METADATA_CONTAINER` bindings. Keep the container default
`native-ui-metadata` unless you have an approved storage change. In
**Cosmos DB > Data Explorer**, confirm its partition key is `/principal_id`.
Do not substitute Foundry's backing Cosmos account.

3. Run `azd deploy` after provision and grants succeed. Sign in again and run
   the checks below using a new harmless conversation.

See
[Enable a product feature](application-settings.md#enable-a-product-feature)
for the canonical configuration procedure and
[User feedback](user-feedback.md) for its independent flag.

## Start the first conversation

After the operator completes [application access](application-auth.md), open
the frontend HTTPS URL from deployment outputs using the required network
connection. Sign in with an admitted account and start a conversation in the
chat experience. Send a simple greeting and check that a real response arrives.

Then test a follow-up that depends on the preceding turn. This checks context
within that session. It does not prove that the UI can list or reopen saved
conversations after a restart.

Ask questions about documents or SQL only after those sources and their
capabilities are configured. The application cannot infer your data sources
from a greeting or from an empty deployed catalog.
For a named process rather than chat, use
[Workflows & human input](workflows.md).

## Context during a chat

A conversational Microsoft Agent Framework (MAF) Agent uses the selected host's native session state:
Foundry persistence on Hosted or Durable Task Scheduler (DTS) through the
official Durable Extension on Container Apps.
The UI does not make a stateless adapter stateful by replaying its transcript.

The UI/BFF binds the authenticated owner to native session IDs. Knowing an ID
or calling through a shared service identity does not authorize another
person's messages, pending actions or files.
See [Agent hosting](hosted-agents.md) for the distinct clients.

## Resume a saved conversation

When saved history is enabled, choose **Abrir histórico** (open history) in
the authenticated chat, then select a saved session. The BFF checks its owner
mapping before using the host client to read or continue the native session.
Native state and UI discoverability are different: a persisted session does
not by itself supply a list of the current user's conversations.

The UI/BFF owns titles, owner mappings and other product metadata in its
declared store. That store is not a transcript replay service or a workflow
checkpoint engine. Missing metadata, failed state reads and denied ownership
must not be treated as an empty successful conversation.

**Verify:** Create a harmless conversation, send a follow-up, sign out and
return as the same user. Open history and confirm the native conversation
can be read and continued. A different signed-in user must not list or reopen
it. Through the authenticated API, unknown/nonowned selectors return `404`;
disabled history does not return a successful empty history.

<span id="continuity-settings"></span>

### State and metadata dependencies

| Feature | Owner |
| --- | --- |
| Agent conversation/session execution | Selected native host |
| Workflow graph state and pending human input | Selected native host |
| User-to-session/run mapping, titles and discovery | UI/BFF product metadata |
| Native result/execution feedback | UI/BFF feedback store |
| Private file input and access metadata | Explicit attachment capability; authenticated UI/file boundary and selected native input or authorized tool path |

Hosted execution does not require application Cosmos DB.
Workflow mode or `both` selects UI metadata even with product flags off;
enabled history, feedback or attachments also selects it.

The UI reads
`DATABASE_ACCOUNT_NAME`, `DATABASE_NAME` and `NATIVE_UI_METADATA_CONTAINER`
(default `native-ui-metadata`, partition key `/principal_id`, owner value
`tid:oid`).
Only the frontend receives its metadata grant. The container holds owner/run
mappings, references, feedback and attachment descriptors, not bytes,
transcripts, tokens or Foundry/DTS execution checkpoints.

The optional NL2SQL toolset on Agent App MCP Server can reuse the same application
Cosmos account with separate source/vector-metadata containers and grants.
An empty MCP server does not select those containers. Selecting MCP does
not enable history, feedback or attachments, and its catalog is not a UI
session store. See [Cosmos ownership](application.md#what-cosmos-means-in-this-application).

In conversational mode with every product flag off, the UI uses bounded
volatile owner maps. They are lost on UI restart; native host persistence alone
cannot restore the UI mapping or provide saved discovery.

Do not deploy ingestion or an additional runtime merely to support metadata.
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

See [Administration](operations.md) and [User feedback](user-feedback.md).

## Private attachments

Enable `ENABLE_PRIVATE_ATTACHMENTS` for conversational operation in
`conversational` or `both`. Workflow attachments are not supported.
The native turn accepts at most **three files**, each at most **64 KiB**:
UTF-8 TXT/Markdown, PDF, PNG or JPEG.

After the provisioning/deployment sequence above, open a **new conversational
chat**, attach a harmless small `.txt` file using the chat attachment control
and send a text instruction with it. For an authenticated API integration,
use the following body instead; obtain the UI session ID from that user's
session creation response, not from a native host ID.

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

**Verify:** The owner receives a real answer using the harmless text file.
A second user submitting to the same UI session ID receives `404`.
Oversize or mismatched-format files are rejected, and disabling attachments
makes new attachment submissions unavailable. Do not treat successful
transport as evidence of PDF/image understanding.

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
