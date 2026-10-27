# Ingestion and conversation uploads

Foundry IQ provides the standard source-ingestion path. Conversation attachments
and custom processing are separate capabilities that can require optional
**Agent App Ingestion**.

This page explains those boundaries. Deployment steps are in the
[Deploy full stack runbook](deploy-full-stack.md); source and index inputs are
described in [Deployment settings](configuration.md#ingestion-application-selection).

<span id="choose-a-source-ingestion-path"></span>

## 1. Standard ingestion with Foundry IQ

The default source is Azure Blob Storage, with `FOUNDRY_IQ_PATTERN=azureBlob`
and container `documents`. Azure AI Search, which powers Foundry IQ, creates
and manages the indexing pipeline for this knowledge source. It extracts
content, splits it into smaller passages (**chunks**), generates **embeddings**
(vectors used for similarity search) and populates an index used by the
knowledge base.

**Agent App Ingestion is not required** for this path.
New Agent Application environments default to
`DEPLOY_INGESTION_CONTAINER_APP=false`.

Source documents belong in the configured Blob container and optional folder,
not in a chat attachment. Search's ingestion identity needs access to storage
and the configured extraction and embedding services. The default permission
metadata is `["rbacScope"]`; ingestion permissions and the querying user's
authorization remain separate requirements.
Microsoft's [Blob knowledge-source guide](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-blob)
describes the managed pipeline and service requirements.

Successful ingestion does not establish protected retrieval in the hosted
application. The shipped hosted entrypoint supplies empty user context to the
retrieval strategy, so the connector cannot forward an on-behalf-of (OBO) token.
This limitation affects protected Blob retrieval as well as the sources below.

<span id="sharepoint-is-a-separate-integration"></span>

Foundry also supports native SharePoint options, including previews:

| Native option | What happens to the content |
| --- | --- |
| Foundry IQ `indexedSharePoint` source | A service-managed pipeline copies and processes SharePoint content into a Search index. No Agent App Ingestion is required by the service. |
| Foundry IQ `remoteSharePoint` source | The knowledge base queries Microsoft 365 at retrieval time. It does not copy the SharePoint corpus into a landing-zone index. Retrieved text still reaches the agent and model. |
| Foundry Agent Service SharePoint tool | The agent calls a native tool backed by Microsoft 365 retrieval, outside the knowledge-base source list. It does not require the custom ingestion application. |

These product options are not all wired into Agent Application. The indexed
SharePoint template needs a source-contract update; remote retrieval and native
tools need their own connection, consent and trusted delegated-user integration.
Native tool calls require the user's identity, not application-only access.
[SharePoint](sharepoint.md) explains the options and current integration gaps.
Preview status is a governance consideration, not a reason to assume custom
ingestion is required.

The accelerator's ingestion-free validation accepts native Blob or an explicitly
bound, independently populated Search index. A SharePoint-only replacement needs
source-specific integration and authorization validation; a product-supported
source is not automatically a supported deployment selection.

<span id="conversation-uploads-are-not-native-source-ingestion"></span>

## 2. Conversation file uploads

A chat attachment is processed for one conversation, not added to the shared
native Blob corpus. This path **requires Agent App Ingestion**, its reachable
endpoint and a compatible Search index. Alongside the default native Blob
source, the additional conversation `searchIndex` source needs
`FOUNDRY_IQ_CONVERSATION_UPLOAD_ENABLED=true`.
The flag is invalid without the ingestion app.

With `DEPLOY_INGESTION_CONTAINER_APP=false`, Agent App UI hides attachment
controls and rejects server uploads and client preflight before resolving an
ingestion endpoint or Dapr fallback. Setting it to `true` permits the upload
path, but does not make authenticated retrieval work automatically.

The UI's attachment controls require authenticated access. Anonymous Copilot
sessions cannot upload. The chat handler accepts PDFs, up to five files,
15 MiB per file and 25 MiB total. Hosted uploads require the UI's existing hosted
conversation identifier. A text turn establishes it in the non-continuity hosted
path; continuity-enabled chat does not populate that upload identifier.

The upload payload can carry the uploader's object ID as permission metadata.
That is not sufficient by itself: the index must enforce those permissions and
retrieval must preserve conversation scope and trusted user authorization.

**Conversation scope** uses the hosted backend's conversation namespace,
not the local UI thread ID. The same identifier must reach the indexed upload
and retrieval filter. Retrieval must match both `conversationId` and the trusted
uploader in `metadata_security_user_ids`; the identifier alone grants no access.

The default hosted entrypoint supplies no authenticated owner, so the native
Blob conversation-upload source is skipped. The delegated-token gap described
above also affects protected conversation retrieval. Enabling ingestion does not resolve it.
The [conversation PDF reference](multimodality.md#attach-a-pdf-to-a-conversation)
describes source bindings. Hosted use still needs the reviewed
[Foundry IQ identity integration](foundry-iq.md).

<span id="select-the-optional-application"></span>
<span id="select-agent-app-ingestion"></span>
<span id="upgrade-and-retirement-safety"></span>

## 3. Custom ingestion only when needed

Agent App Ingestion is useful when the managed source does not meet processing
requirements, or when conversation uploads or the application's custom
SharePoint jobs are required. Its format-specific processing performs chunking
and embedding generation and writes content to Search. An independent pipeline
can instead populate a compatible index exposed through a Foundry IQ
`searchIndex` source.

The optional application's SharePoint connector uses Microsoft Graph application
credentials and indexing/purge jobs. It copies content and permission metadata
into Search; permission synchronization and query-time enforcement still need
validation.

Every selected item's supported ACLs are reconciled on each
SharePoint index run, even when content is unchanged, without re-downloading or
embedding that content. Grants and revocations replace stored permissions on
all affected documents and chunks. See
[SharePoint permission synchronization](sharepoint.md#permission-synchronization)
for scheduling, filter boundaries, inherited-permission support and recovery.

It is separate from native SharePoint knowledge sources and the
native Foundry tool. Its `SHAREPOINT_*` credentials are not the
`SHAREPOINT_REMOTE_*` retrieval settings. Secrets belong in Key Vault.

For the bundled Agent Application, `DEPLOY_INGESTION_CONTAINER_APP` selects
the optional component through the [Deploy full stack runbook](deploy-full-stack.md),
not a runtime-only edit. Existing environments retain their recorded selection;
custom application definitions retain their declared components. Selection does
not change retrieval bindings or document authorization.
Omitting the application does not delete deployed resources, indexed documents
or identity grants; retirement needs separate authorization.

<span id="authorization-remains-a-design-requirement"></span>
<span id="related-references"></span>

For every path, acceptance includes a document that an allowed user can
retrieve with its citation and that a denied user cannot retrieve. Source
permissions, query-time enforcement and private-network connectivity require
separate validation. Private Blob ingestion is covered in
[Network isolation](network-isolation.md#private-native-blob-ingestion).
