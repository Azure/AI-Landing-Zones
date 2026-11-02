# Ingestion and private-input boundaries

Foundry IQ provides the standard shared-source ingestion path.
Private attachments and custom processing are separate capabilities.
**Agent App Ingestion** is optional and disabled by default; it is not the
store for native execution state or UI/BFF product metadata.

This page explains those boundaries. Deployment steps are in the
[full-stack deployment guide](deploy-full-stack.md). Source and index inputs are
described in [Deployment settings](configuration.md#ingestion-application-selection).

## Choose the boundary first

<div class="runbook-diagram" markdown="1">

<div class="runbook-diagram__summary" markdown="1">

**Shared sources**

1. A source administrator supplies content and permissions.
2. Foundry IQ's native Blob pipeline manages indexing, or an **optional**
   Agent App Ingestion pipeline writes a compatible Search index.
3. Configure and test source-compatible user authorization separately from
   indexing. Indexing success is not an authorization grant.

**Private conversation input**

1. A signed-in owner submits a bounded inline attachment to the web app backend.
2. The explicit attachment flag and metadata-store access must be configured.
   The web backend checks ownership before calling the native conversational backend.
3. Foundry Agent Service or Durable Task Scheduler owns native state.
   The application's Cosmos web metadata holds owner mappings and descriptors,
   **not file bytes or transcripts**. This path never publishes the attachment
   into shared ingestion.

</div>

[![Shared content flows through native Foundry IQ ingestion into a managed Search index or optional Agent App Ingestion into an application-owned index. Retrieval needs separate tool setup and verified user authorization. Private inline attachments pass through the owner-checking web backend to Foundry Agent Service or Durable Task Scheduler; application Cosmos stores only owner mappings and descriptors, not native state or file bytes. There is no attachment path into shared ingestion.](../media/runbooks/ingestion.svg?v=c710fad05408)](../media/runbooks/ingestion.svg?v=c710fad05408){: .runbook-diagram__image aria-label="Open full-size ingestion and private-input boundary diagram"}

[Open full-size diagram](../media/runbooks/ingestion.svg?v=c710fad05408){: .runbook-diagram__open}

</div>

Neither retrieval nor custom ingestion is required for every application.
Choose only the paths your application uses; private attachments do not
select a shared source.

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

### How to prepare a shared Blob source

1. **Before provision**, use the platform's declared source inputs:
   `FOUNDRY_IQ_PATTERN=azureBlob`,
   `FOUNDRY_IQ_STORAGE_CONTAINER_NAME` and optional
   `FOUNDRY_IQ_STORAGE_FOLDER_PATH`. These have explicit mappings in
   `main.parameters.json`; keep `DEPLOY_INGESTION_CONTAINER_APP=false` for
   this ingestion path. Follow [Foundry IQ setup](foundry-iq.md).
2. Provision through the [deployment guide](deploy-full-stack.md).
   The source/storage owner must approve Search's ingestion access and any
   private connections. This is separate from application-user consent.
3. **After provision**, place a small approved document in the selected
   container/folder and inspect the knowledge source's managed indexing
   status in Search. Confirm extracted chunks and permission metadata.
4. **Before deployment/use**, register the required runtime capability through
   [agent capability configuration](application-settings.md#configure-an-agent-capability).
   A provisioned knowledge base alone does not enable its tool.
5. Query through the deployed application as an allowed user and a denied
   user. Confirm citations for the allowed user and no protected content for
   the denied user. Changing source/model bindings requires the provisioning
   and deployment lifecycle, not only an application restart.

Successful ingestion alone does not establish protected retrieval. The built-in
native UI delegates for hosted invocation; it does not implement the direct
connector's Search-token forwarding path. Native Foundry IQ uses a
project-connection tool. Configure and verify source-compatible user
authorization for that connection, or explicitly integrate trusted credential
forwarding and direct-connector invocation.

Ingestion must still record correct permissions, and acceptance must prove
allow/deny behavior. [Application access](application-auth.md#hosted-retrieval-identity-boundary)
and [Foundry IQ authorization](foundry-iq.md#user-authorization-boundaries)
describe the native-versus-direct integration boundary.

<span id="sharepoint-is-a-separate-integration"></span>

Foundry also supports native SharePoint options, including previews:

| Native option | What happens to the content |
| --- | --- |
| Foundry IQ `indexedSharePoint` source | A service-managed pipeline copies and processes SharePoint content into a Search index. No Agent App Ingestion is required by the service. |
| Foundry IQ `remoteSharePoint` source | The knowledge base queries Microsoft 365 at retrieval time. It does not copy the SharePoint corpus into a landing-zone index. Retrieved text still reaches the agent and model. |
| Foundry Agent Service SharePoint tool | The agent calls a native tool backed by Microsoft 365 retrieval, outside the knowledge-base source list. It does not require the custom ingestion application. |

These product options are not all wired into Agent Application. The native
indexed SharePoint path ships source registration and permission ingestion,
not end-to-end application delegation. Its native tool connection and
source-specific user authorization still require explicit setup and validation.
App-only ingestion access does not authorize users.

Remote retrieval and native tools need
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

### How to enable private conversational input

1. **Before provision**, select `conversational` or `both` and set
   `ENABLE_PRIVATE_ATTACHMENTS=true` in the selected azd environment.
   Use [Enable a product feature](application-settings.md#enable-a-product-feature)
   for the canonical commands. Do not write only the runtime key in the portal.
2. Run provision, then deploy. Composition selects the UI metadata container
   and grants the UI identity access; it does not deploy ingestion for this
   feature. Hosted `both` keeps attachments disabled on the workflow publication.
3. **At runtime**, sign in, create a conversational session and send a small
   TXT attachment through its turn API or UI. Verify the answer and an owner-bound
   descriptor; confirm that another user cannot access that session.
4. Check the [file/turn limits](multimodality.md#private-attachment-boundary)
   and model behavior separately. Enabling this persisted feature in an
   already running UI requires compatible resources and redeployment, not
   just a functional refresh.

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
SharePoint index run, even when content is unchanged.
Unchanged content is not re-downloaded or embedded.
Grants and revocations replace stored permissions on
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

<span id="prepare-the-custom-pipeline"></span>

## How to prepare the custom pipeline

1. **Before provision**, select `DEPLOY_INGESTION_CONTAINER_APP=true` in
   the azd environment using the [deployment guide](deploy-full-stack.md).
   Select it only for the required processing paths. Configure the following
   settings before its first deployment: starting it can immediately run
   indexing and destructive maintenance work.
   Read [Jobs & schedules](ingestion-jobs.md) before connecting it to a corpus.
2. **Before application startup**, supply `APP_CONFIG_ENDPOINT` in its process
   environment. Runtime configuration
   and Key Vault references are loaded through Azure credentials. A local
   Azure CLI login still needs data-plane RBAC and network access.
   Use [Application settings](application-settings.md) for exact keys and
   effective-value checks rather than creating duplicate service-label values.
   Declare nonsecret processing settings in the platform root's
   `parameters.additionalAppConfigurationSettings.value` array:

    ```json
    {"name":"RUN_JOBS_ON_STARTUP","value":"false","label":"agent-lz"}
    ```

    This is an array entry, not a complete parameter file. It suppresses
    immediate indexing/purge only; review cron and log cleanup separately.
    Follow [configuration ownership](configuration.md#configuration-ownership-and-declarations)
    for publishing declarations. Arbitrary `azd env set` names do not publish keys.

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
   [NL2SQL](nl2sql.md) uses a separate administrative Cosmos metadata import;
   it does not require this document pipeline or Search metadata indexes.

5. Grant the ingestion workload only the required source read, target Search
   write, storage, model and secret access. Verify connectivity from the actual
   service, including private endpoints where configured. Complete provisioning
   and deploy through the platform lifecycle with those reviewed settings.

6. Process a small corpus and inspect per-file errors, confirmed indexed chunks,
   citations and allowed/denied-user retrieval before scheduling broader work.
   For **post-deploy** schedule edits, use
   [configure and apply schedules](ingestion-jobs.md#configure-and-apply-schedules).
   Restart ingestion after endpoint/client or analysis-service changes; cache
   refresh does not replace existing module-level clients.

`USE_DOCUMENT_INTELLIGENCE=false` selects Content Understanding by default.
`MULTIMODAL=false` keeps the additional figure extraction and captioning path
off. Neither setting chooses an application mode or changes the native
Foundry IQ source's processing configuration.

An ingestion-maintained index can be attached to Foundry IQ as a `searchIndex`
source on the same Search service. Registration does not populate it, repair
its schema or reconstruct missing ACLs. Keep the index and embedding dimensions
aligned with the source binding.

## SQL metadata is separate from document ingestion

Agent App MCP Server uses approved source bindings, schemas and examples with
vectors in application Cosmos, not the document Search index.
The operator supplies approved metadata to the MCP repository's administrative
Python importer, which generates embeddings and activates only a complete
catalog version. No persistent ingestion Container App is required.

The ingestion service's `nl2sql_index` and `nl2sql_purge` jobs operate on
Search query/table/measure indexes. They do **not** implement the MCP Cosmos
catalog import or complete-version activation contract. Leave those schedules
unset when onboarding MCP SQL. Do not point document indexing or purge work
at the MCP containers. SQL read access belongs to the MCP identity;
metadata import needs its own scoped writer. See
[SQL onboarding](agent-app-mcp.md#onboard-sql-before-inviting-users).

## Ingestion APIs and retrieval boundaries

`POST /document-chunking`, `POST /text-embedding` and
`POST /ingest-documents` have different JSON envelopes, not a common arbitrary
file-upload contract. They require `X-API-KEY`, accepting
`DATA_INGEST_APP_APIKEY` and its supported `INGESTION_APP_APIKEY` alias.
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
