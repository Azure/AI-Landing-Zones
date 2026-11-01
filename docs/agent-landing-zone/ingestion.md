# Ingestion and private-input boundaries

Foundry IQ provides the standard shared-source ingestion path.
Private attachments and custom processing are separate capabilities.
**Agent App Ingestion** is optional and disabled by default; it is not the
store for native execution state or UI/BFF product metadata.

This page explains those boundaries. Deployment steps are in the
[full-stack deployment guide](deploy-full-stack.md). Source and index inputs are
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
metadata is `["rbacScope"]`. Ingestion permissions and the querying user's
authorization remain separate requirements.
Microsoft's [Blob knowledge-source guide](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-blob)
describes the managed pipeline and service requirements.

Successful ingestion alone does not establish protected retrieval. The built-in
UI/hosted native path forwards a separately delegated Search token. Ingestion
must still record correct permissions and acceptance must prove allow/deny
behavior. [Application access](application-auth.md) describes the OBO contract.

<span id="sharepoint-is-a-separate-integration"></span>

Foundry also supports native SharePoint options, including previews:

| Native option | What happens to the content |
| --- | --- |
| Foundry IQ `indexedSharePoint` source | A service-managed pipeline copies and processes SharePoint content into a Search index. No Agent App Ingestion is required by the service. |
| Foundry IQ `remoteSharePoint` source | The knowledge base queries Microsoft 365 at retrieval time. It does not copy the SharePoint corpus into a landing-zone index. Retrieved text still reaches the agent and model. |
| Foundry Agent Service SharePoint tool | The agent calls a native tool backed by Microsoft 365 retrieval, outside the knowledge-base source list. It does not require the custom ingestion application. |

These product options are not all wired into Agent Application. The native
indexed SharePoint path includes source registration, permission ingestion
and delegated Search authorization. Remote retrieval and native tools need
their own connection, consent and trusted delegated-user integration.
Native tool calls require the user's identity, not application-only access.
[SharePoint](sharepoint.md) explains the supported bindings and administrator
prerequisites.
Preview status is a governance consideration, not a reason to assume custom
ingestion is required.

The accelerator's ingestion-free validation accepts native Blob or an explicitly
bound, independently populated Search index as its primary selection. Native
indexed SharePoint is an additional configured knowledge source. Enabling it
does not require Agent App Ingestion or replace the primary pattern setting.
Other Microsoft product options are not automatically supported deployment
selections in the accelerator.

<span id="conversation-uploads-are-not-native-source-ingestion"></span>

<span id="2-private-conversation-and-process-attachments"></span>

## 2. Private conversational attachments

`ENABLE_PRIVATE_ATTACHMENTS` selects validated inline conversational input
in `conversational` or `both`. Workflow attachments are unsupported.
Hosted uses official file/image inputs; DTS uses native context messages/IDs.
The path does **not** call Agent App Ingestion, mint Blob SAS, accept input
URLs or publish the file into a corporate knowledge corpus.
It selects UI owner mappings and descriptors, not storage of file bytes.
See [Private attachments](conversations.md#private-attachments) for exact limits.

Do not enable the custom ingestion service simply to retain owner mappings,
history discovery or feedback. Selecting ingestion is a processing decision,
not a way to make native Agent or Workflow persistence work.
The supplied private attachment path has no custom-ingestion fallback.

See [Conversations & files](conversations.md) and
[Application access](application-auth.md) for user and source boundaries.
Shared corpus formats and image extraction are covered in
[Document formats & images](multimodality.md).

<span id="select-the-optional-application"></span>
<span id="select-agent-app-ingestion"></span>

## 3. Custom ingestion only when needed

Agent App Ingestion is useful when the managed source does not meet processing
requirements, or when the application's custom SharePoint jobs are required.
Its format-specific processing performs chunking
and embedding generation and writes content to Search. An independent pipeline
can instead populate a compatible index exposed through a Foundry IQ
`searchIndex` source.

The optional application's SharePoint connector uses Microsoft Graph application
credentials and indexing/purge jobs. It copies content and permission metadata
into Search. Permission synchronization and query-time enforcement still need
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
the optional component through the [full-stack deployment guide](deploy-full-stack.md),
not a runtime-only edit. Existing environments retain their recorded selection.
Custom application definitions retain their declared components. Selection does
not change retrieval bindings or document authorization.
Omitting the application does not delete deployed resources, indexed documents
or identity grants. Retirement needs separate authorization.

## Prepare the custom pipeline

1. Deploy the optional application only for the required processing paths.
   Starting it can immediately run indexing and destructive maintenance work.
   Read [Jobs & schedules](ingestion-jobs.md) before connecting it to a corpus.
2. Supply `APP_CONFIG_ENDPOINT` in its process environment. Runtime configuration
   and Key Vault references are loaded through Azure credentials. A local
   Azure CLI login still needs data-plane RBAC and network access.
   Use [Application settings](application-settings.md) for exact keys and
   effective-value checks rather than creating duplicate service-label values.
3. Configure the target Search endpoint and compatible index, source storage,
   log storage and embedding deployment. The Blob indexer reads
   `SEARCH_SERVICE_QUERY_ENDPOINT`, `STORAGE_ACCOUNT_NAME`,
   `DOCUMENTS_STORAGE_CONTAINER` (default `documents`) and `BLOB_PREFIX`
   (default empty). Its index selection uses `AI_SEARCH_INDEX_NAME` when
   configured, otherwise `SEARCH_RAG_INDEX_NAME`.
4. Add only the dependencies required by the selected format and source.
   PDFs, images and Office documents use the selected analysis service.
   Text, JSON, spreadsheets and transcripts have dedicated paths.
   See [Document formats & images](multimodality.md#custom-document-formats).
   SharePoint additionally needs Graph credentials and source definitions.
   [NL2SQL](nl2sql.md) needs metadata jobs and separate database configuration.
5. Grant the ingestion workload only the required source read, target Search
   write, storage, model and secret access. Verify connectivity from the actual
   service, including private endpoints where configured.
6. Process a small corpus and inspect per-file errors, confirmed indexed chunks,
   citations and allowed/denied-user retrieval before scheduling broader work.

`USE_DOCUMENT_INTELLIGENCE=false` selects Content Understanding by default.
`MULTIMODAL=false` keeps the additional figure extraction and captioning path
off. Neither setting chooses an application mode or changes the native
Foundry IQ source's processing configuration.

An ingestion-maintained index can be attached to Foundry IQ as a `searchIndex`
source on the same Search service. Registration does not populate it, repair
its schema or reconstruct missing ACLs. Keep the index and embedding dimensions
aligned with the source binding.

## Ingestion APIs and retrieval boundaries

`POST /document-chunking`, `POST /text-embedding` and
`POST /ingest-documents` have different JSON envelopes, not a common arbitrary
file-upload contract. They require `X-API-KEY`, accepting
`DATA_INGEST_APP_APIKEY` and its legacy `INGESTION_APP_APIKEY` alias.
Keep the key in secret storage. Successful Azure SDK managed-identity access
does not remove inbound API authentication.

For direct ingestion, inspect each record's errors and confirmed
`indexedChunks`. HTTP success for the envelope is not proof that every record
was indexed. Use the [API reference](application-api.md) for payload details.
The [administrative dashboard](operations.md) and
[Monitoring & audit](application-monitoring.md) provide the operator view.

### Hosted Toolbox retrieval

The separate preview `POST /retrieve` endpoint is not an ingestion API or the
native Foundry IQ retrieve call. It remains unavailable with `503` until both
`HOSTED_RETRIEVAL_ENABLED` and `HOSTED_RETRIEVAL_INV_002_VALIDATED` are enabled.
Both default to `false`. The second is an operator attestation of the required
isolated native-authorization validation, not a test the service runs or an
attestation established by successful deployment.

Before enabling it, configure Toolbox `UserEntraToken` passthrough,
`HOSTED_RETRIEVAL_TOKEN_AUDIENCE`, native Search permission fields and the
required user/service grants. Validate restricted users and negative cross-user
and group cases. This existing authorization gate is separate from application
evaluation.

The route requires a validated delegated user bearer. The service uses its own
credential for Search transport and forwards the user's token unchanged in
`x-ms-query-source-authorization`. It accepts a query and bounded result count,
not caller-supplied identity, groups or index selection. An API key or workload
identity alone cannot replace the delegated user. See
[Application authentication](application-auth.md) and
[API reference](application-api.md) for the token and response contracts.

<span id="authorization-remains-a-design-requirement"></span>
<span id="related-references"></span>

Native upload downloads repeat authorization through Search for the exact
document, conversation and authenticated uploader before workload Blob access.
A signed citation selector or known conversation ID is insufficient.
Shared-source Blob/ADLS downloads instead use user-delegated Storage access.
See [protected citation downloads](application-auth.md#protected-citation-downloads).

For every path, acceptance includes a document that an allowed user can
retrieve with its citation and that a denied user cannot retrieve. Source
permissions, query-time enforcement and private-network connectivity require
separate validation. Private Blob ingestion is covered in
[Network design](configuration.md#search-shared-private-links).
