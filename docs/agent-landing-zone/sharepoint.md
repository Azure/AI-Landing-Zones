# SharePoint

Foundry supports SharePoint through native knowledge sources and a native
Foundry Agent Service tool. Custom ingestion is optional for SharePoint grounding.

This page explains content flow, permissions and accelerator readiness.
Deployment procedures are in the
[Deploy full stack runbook](deploy-full-stack.md).

<span id="before-you-start"></span>
<span id="connect-the-source"></span>

## Native SharePoint options

| Option | Content flow | Integration boundary |
| --- | --- | --- |
| Foundry IQ `indexedSharePoint` source (preview) | Search copies and processes content into a managed index. | Protected retrieval requires configured permission ingestion and query-time user authorization. |
| Foundry IQ `remoteSharePoint` source (preview) | Microsoft 365 is queried at retrieval time; no corpus copy is ingested into a landing-zone index. | The knowledge base calls the Copilot Retrieval API under the user's permissions. Retrieved text still reaches the agent/model. |
| Foundry Agent Service SharePoint tool (preview) | A native agent tool uses Microsoft 365 retrieval without a custom landing-zone ingestion pipeline. | Tool connection and user identity passthrough are configured in Foundry Agent Service, not as a knowledge-base source. |

Microsoft's guides cover the [indexed source](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-sharepoint-indexed),
[remote source](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-sharepoint-remote)
and [native agent tool](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/sharepoint).
Preview features are available for evaluation under their documented terms;
they have no preview SLA and are not recommended for production.

Remote SharePoint currently supports textual SharePoint content, not OneDrive,
Copilot connector content or multimodal retrieval. It requires SharePoint and
Azure in the same Entra tenant.

Each querying user needs a qualifying Microsoft
365 Copilot add-on license or enabled Retrieval API pay-as-you-go consumption.
Pay-as-you-go requires administrator billing setup and at least one Microsoft
365 Copilot license in the tenant throughout use.

The native tool also requires eligible licensing or pay-as-you-go, Foundry User
access to the project and Read access to the SharePoint site. Its calls require
the user's delegated identity, not an application managed identity or service
principal.

## What is wired into Agent Application

Native product support does not imply an end-to-end accelerator integration:

- **Indexed source:** the template registers a native source with a secretless
  federated `connectionString`, `defaultSiteLibrary`, an embedding model and
  native `userIds`/`groupIds` permission ingestion. The UI/hosted path carries
  the delegated Search token. Configure the Entra objects and source permissions
  below; no custom connector or Agent App Ingestion is required.
- **Remote source:** the connector recognizes
  `SHAREPOINT_REMOTE_ENABLED` and `SHAREPOINT_REMOTE_KNOWLEDGE_SOURCE_NAME`.
  The source must already exist and belong to the knowledge base. These keys
  do not create it or establish delegation.
- **Native tool:** the service connection and identity-passthrough contract
  need an explicit application integration. The remote-source settings do not
  attach this tool.

The default Blob path uses Search API `2026-05-01-preview`. Indexed SharePoint
requires `FOUNDRY_IQ_API_VERSION=2026-08-01-preview` for the integrated source
contract.
Platform provisioning can replace manual source references in its managed
knowledge base.

!!! important "Source configuration remains a separate requirement"
    The built-in UI/hosted path can forward the delegated Search credential.
    That does not create missing permission metadata or grant access to a site.
    Indexed and remote SharePoint still need their documented registration,
    consent and source-specific configuration.
    App-only indexing access is not proof of per-user trimming.

### Indexed source identity inputs

Set `SHAREPOINT_INDEXED_ENABLED=true`, the knowledge-source name, site URL and
tenant ID. Supply `SHAREPOINT_INDEXED_APPLICATION_ID` for the ingestion Entra
app and `SHAREPOINT_INDEXED_FEDERATED_CREDENTIAL_APPLICATION_ID` for Search's
managed identity application/client ID. This last value is **not** a federated
credential object ID. The app must trust the Search identity through federation
and have the documented SharePoint/Graph permissions and site access.

The source creates its own index and indexing assets; an operator-supplied
`SHAREPOINT_INDEXED_INDEX_NAME` does not name those generated resources.
Keep native permission ingestion enabled. Verify ACL propagation and both
Entra-group and SharePoint site-group behavior for your corpus before rollout.

Network-isolated mode selects private model-endpoint access, which requires a
supported Search tier and approved model private links. SharePoint Online itself
is not a Search shared-private-link destination; this does not make the
Microsoft 365 connection private.

Remote knowledge-source retrieval uses `x-ms-query-source-authorization` for the
Search-audience delegated user token, separately from service authentication.
It preserves SharePoint permissions and supported Purview controls.
Filters narrow the requested scope; they are not authorization. Invalid Keyword
Query Language (KQL) filters can be ignored by the Retrieval API.
[Foundry IQ](foundry-iq.md) explains the shared integration boundary.

<span id="when-you-need-indexed-content"></span>

## Custom SharePoint ingestion

Agent App Ingestion provides a separate Graph-based connector with indexing and
purge jobs. It copies content and permission metadata to Search. Permission
changes need synchronization and allow/deny validation.
It uses `SHAREPOINT_*` application credentials, not native remote-source
settings; secrets belong in Key Vault.

This path is appropriate for required custom processing or connector behavior.
Native indexed SharePoint also copies content, but its pipeline is managed by
Search and does not need Agent App Ingestion. Neither approach removes the need
to maintain permissions and enforce them during retrieval.
[Ingestion](ingestion.md#3-custom-ingestion-only-when-needed) explains optional
application selection.

### Permission synchronization

Each custom SharePoint indexing run reads current permissions independently of
content modification timestamps. It compares the stored user and group ACLs on
every indexed document for each selected item, including all document-library
chunks and previously indexed file names. Changed ACLs are replaced, so
revocations remove stale principals. A successful empty permission result clears
the stored principal lists.

Equal ACL sets cause no writes; unchanged content
is not downloaded, chunked or embedded. ACL-only merges change neither content,
vectors nor content timestamps.

Custom target indexes need a filterable `parent_id`, sortable `id`, and
retrievable ACL fields, as provided by the bundled index. Rebuild indexes that
explicitly disable these attributes before running the connector.

The cadence is the ingestion application's `CRON_RUN_SHAREPOINT_INDEX`
schedule, not real-time notification. An unset schedule performs no automatic
refresh; the SharePoint index job can also be run manually.

Refresh applies
only to configured collections and items returned by their source filters.
A modification-time-only filter can omit permission-only changes: include
every item whose access must be synchronized in the scheduled selection.
Content retry blocking does not stop permission refresh for already indexed
documents.

The supported representation is Graph-visible **Entra user and group object
IDs**, with the connector's existing limit of 32 IDs in each ACL field.

Document libraries read effective drive-item sharing permissions, including
inherited grants returned by Graph. Breaking or restoring inheritance replaces
the stored ACL with the current effective result; the connector does not union
parent grants into an item that has broken inheritance.

Generic lists use the
permissions returned by the Graph list-item endpoint. This is not a complete
SharePoint authorization-model replica: SharePoint-local group expansion,
anonymous or organization-wide sharing-link semantics, and grants not exposed
to the connector's application identity are not synthesized.

Configure
application access so Graph can return the permissions required for the selected
content, and validate both allowed and denied retrieval. Purview sensitivity
label enforcement and document decryption are outside this connector's ACL
synchronization.

Permission pages must all succeed before applying an item's ACL. A failed
lookup is not treated as an empty ACL. Search must confirm every merge; a
lookup or partial-update failure marks the item and job failed rather than
reporting complete synchronization. Successful merges are not rolled back.

After restoring Graph/Search access, run the index job again: it compares
current state and retries stale ACLs without reprocessing unchanged content.

Item logs use `acl-updated` for a successful permission-only change, and run
summaries expose `aclUpdatedItems` and `aclUpdatedDocuments` for completed
items. Keep restricted content unavailable until deny-path checks confirm
revocations have reached every indexed copy.

<span id="verify"></span>
<span id="recover-or-disconnect"></span>

## Acceptance and recovery

Acceptance uses a distinctive test document, an allowed user and a denied user.
The allowed user receives grounded content and a citation that opens in SharePoint;
the denied user's retrieved IDs, excerpts and citations exclude the document.
Other sources must not expose an unprotected copy. Missing or expired user
credentials must not fall back to service-only access.

Private Azure endpoints do not make Microsoft 365 a private-link source.
Connectivity tests cover the actual calling service, Microsoft 365 and Entra.
Recovery restores the previous application/settings and removes the pilot
knowledge-base reference without deleting shared content or tenant objects.
Permission revocation and retirement of indexed copies remain separate tasks.
