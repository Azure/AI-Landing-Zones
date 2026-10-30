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
| Foundry IQ `remoteSharePoint` source (preview) | Microsoft 365 is queried at retrieval time without a corpus copy in a landing-zone index. | The knowledge base calls the Copilot Retrieval API under the user's permissions. Retrieved text still reaches the agent/model. |
| Foundry Agent Service SharePoint tool (preview) | A native agent tool uses Microsoft 365 retrieval without a custom landing-zone ingestion pipeline. | Tool connection and user identity passthrough are configured in Foundry Agent Service, not as a knowledge-base source. |

Microsoft's guides cover the [indexed source](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-sharepoint-indexed),
[remote source](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-sharepoint-remote)
and [native agent tool](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/sharepoint).
Preview features are available for evaluation under their documented terms.
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
  below. No custom connector or Agent App Ingestion is required.
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

The source creates its own index and indexing assets. An operator-supplied
`SHAREPOINT_INDEXED_INDEX_NAME` does not name those generated resources.
Keep native permission ingestion enabled. Verify ACL propagation and both
Entra-group and SharePoint site-group behavior for your corpus before rollout.

Network-isolated mode selects private model-endpoint access, which requires a
supported Search tier and approved model private links. SharePoint Online itself
is not a Search shared-private-link destination. This does not make the
Microsoft 365 connection private.

Remote knowledge-source retrieval uses `x-ms-query-source-authorization` for the
Search-audience delegated user token, separately from service authentication.
It preserves SharePoint permissions and supported Purview controls.
Filters narrow the requested scope. They are not authorization. Invalid Keyword
Query Language (KQL) filters can be ignored by the Retrieval API.
[Foundry IQ](foundry-iq.md) explains the shared integration boundary.

<span id="when-you-need-indexed-content"></span>

## Custom SharePoint ingestion

Use this path when you need custom processing or the Graph-based connector's
list and document-library ingestion. **Agent App Ingestion** runs indexing and
purge jobs inside its Container App, reads SharePoint through Microsoft Graph,
and writes content, embeddings and supported permission metadata to an
**Azure AI Search index**. That index can then be attached to Foundry IQ as a
`searchIndex` knowledge source. It is not the managed `indexedSharePoint`
source described above.

### 1. Prepare the ingestion application

Select `DEPLOY_INGESTION_CONTAINER_APP=true` through the
[Deploy full stack runbook](deploy-full-stack.md). This is a deployment choice,
not a switch to enable in an otherwise undeployed application. Use the
compatible ingestion component from your platform release.

Before enabling jobs, confirm the ingestion application's identity can read
App Configuration and Cosmos DB, retrieve secrets from Key Vault, write to the
target Search index and job-log storage, and call the configured embedding and
document-analysis services. Confirm network access from the Container App to
those resources, Entra ID and Microsoft Graph. Azure resource access uses the
workload identity. SharePoint access uses the separate application credentials
created in step 3.

### 2. Explore SharePoint with Microsoft Graph

Open [Microsoft Graph Explorer](https://developer.microsoft.com/graph/graph-explorer)
and sign in with an account authorized to read the pilot site. Graph Explorer
uses your delegated permissions. A successful Explorer query does not prove
the ingestion application's app-only access.

For `https://contoso.sharepoint.com/sites/SalesAndMarketing`, the
`siteDomain` is `contoso.sharepoint.com` and the `siteName` is
`SalesAndMarketing`.

**Discover the site.**

```http
GET https://graph.microsoft.com/v1.0/sites/contoso.sharepoint.com:/sites/SalesAndMarketing
```

An illustrative response is:

```json
{
  "id": "contoso.sharepoint.com,9f1d115d-9c87-4f37-ba8e-e73ad39c3405,7a3700a7-3a8a-4942-9089-ad84ce9f5837",
  "name": "SalesAndMarketing",
  "displayName": "Sales and Marketing",
  "webUrl": "https://contoso.sharepoint.com/sites/SalesAndMarketing"
}
```

Save the full composite `id` as `{siteId}` for subsequent Graph requests and
the site grant. The current connector resolves this ID at runtime from
`siteDomain` and `siteName`. Storing `siteId` alone does not configure a source.
Its lookup uses `/sites/{siteName}`, so use the corresponding `/sites/` URL
path rather than a site's display title.

**Discover lists and document libraries.**

```http
GET https://graph.microsoft.com/v1.0/sites/{siteId}/lists
```

```json
{
  "value": [
    {
      "id": "7691f86f-8bdc-40eb-bcf5-7a23d0e9006c",
      "name": "Product List",
      "displayName": "Product List",
      "list": { "template": "genericList" }
    },
    {
      "id": "1be0da74-2b71-45e0-a9d3-1ffafa7d0ba7",
      "name": "Shared Documents",
      "displayName": "Shared Documents",
      "list": { "template": "documentLibrary" }
    }
  ]
}
```

Save each selected list's `id`, `name` and `list.template`. A document library
is also a list. No separate `drives` source configuration is needed.
Follow `@odata.nextLink` when a response is paged.

**Discover column names before choosing fields.**

```http
GET https://graph.microsoft.com/v1.0/sites/{siteId}/lists/{listId}/columns
```

```json
{
  "value": [
    { "name": "Title", "displayName": "Title" },
    { "name": "Code_x0020_Name", "displayName": "Code Name" },
    { "name": "Product_x0020_Line", "displayName": "Product Line" },
    { "name": "Modified", "displayName": "Modified" }
  ]
}
```

Use the internal **`name`**, not `displayName`, in `includeFields` and filters.
For example, the internal name for a column created with a space can contain
`_x0020_`.

**Inspect items and test field selection.**

```http
GET https://graph.microsoft.com/v1.0/sites/{siteId}/lists/{listId}/items?$expand=fields
GET https://graph.microsoft.com/v1.0/sites/{siteId}/lists/{listId}/items?$expand=fields($select=Title,Code_x0020_Name,Product_x0020_Line,Modified)
```

```json
{
  "value": [
    {
      "id": "1",
      "lastModifiedDateTime": "2026-10-01T10:30:00Z",
      "fields": {
        "Title": "Product A",
        "Code_x0020_Name": "PROD-A",
        "Product_x0020_Line": "Electronics",
        "Modified": "2026-10-01T10:30:00Z"
      }
    }
  ]
}
```

If you plan to use a collection filter, test it here first, for example
`$filter=fields/Status eq 'Published'` after confirming the internal column
name and Graph's indexed-column requirements. URL-encode query values in your
HTTP client. Keep permission-only changes in scope. Do not use a
modification-time-only filter for the scheduled ACL refresh.

For a document-library file, inspect its associated drive item and content:

```http
GET https://graph.microsoft.com/v1.0/sites/{siteId}/lists/{listId}/items/{itemId}/driveItem
GET https://graph.microsoft.com/v1.0/sites/{siteId}/lists/{listId}/items/{itemId}/driveItem/content
GET https://graph.microsoft.com/v1.0/drives/{driveId}/items/{driveItemId}/permissions
```

The `driveItem` response supplies the file name, MIME type and
`parentReference.driveId`. The connector resolves this relationship to download
and chunk the file. A generic list instead contributes structured field text
and, when selected and available, its attachments.

For generic-list permissions, the connector uses the Graph **beta** endpoint:

```http
GET https://graph.microsoft.com/beta/sites/{siteId}/lists/{listId}/items/{itemId}/permissions
```

Inspect the returned user/group identities, not only display names or emails.
The [permission synchronization](#permission-synchronization) section describes
the supported ACL representation and its limits.

### 3. Register an application and grant selected-site access

**Register the application and consent to `Sites.Selected`.**

In the Azure portal, open **Microsoft Entra ID > App registrations > New
registration**. Give the app a name such as `SharePointDataIngestionApp`, select
**Accounts in this organizational directory only**, leave the redirect URI
empty, and register it. Record the **Application (client) ID** and
**Directory (tenant) ID**.

Under **API permissions > Add a permission > Microsoft Graph > Application
permissions**, add **`Sites.Selected`**. Have an administrator authorized to
consent to Microsoft Graph application permissions grant tenant admin consent
(for example, a Privileged Role Administrator or Global Administrator).
App-registration ownership alone is not sufficient for that consent.

**Grant access to each selected site.**

`Sites.Selected` grants no site access on its own. Use a separate administrative
session to create a site permission:

```http
POST https://graph.microsoft.com/v1.0/sites/{siteId}/permissions
Content-Type: application/json
```

```json
{
  "roles": ["read"],
  "grantedToIdentities": [
    {
      "application": {
        "id": "<ingestion-application-client-id>",
        "displayName": "SharePointDataIngestionApp"
      }
    }
  ]
}
```

Expect `201 Created`, record the returned permission ID, and repeat for each
site. The grant targets the application's **client ID**, not a service
principal object ID.

The [site-permission API](https://learn.microsoft.com/graph/api/site-post-permissions?view=graph-rest-1.0)
requires `Sites.FullControl.All` on the **granting session**. In a delegated
Graph Explorer workflow, the signed-in user also needs SharePoint
Administrator or higher and membership in the target site. A `403` here is a
reason to check that administrator's role, membership and Explorer consent,
not to give the ingestion app tenant-wide access. Keep the ingestion app at
`Sites.Selected` with the reviewed site grant.

Validate that the app-only identity can read the selected items **and their
required permission endpoints**. A readable file with unavailable ACLs is not
a successful protected-ingestion setup. Do not bypass ACL failures or increase
the ingestion app's permissions without a separate review.

**Create and store the client secret.**

Under **Certificates & secrets > Client secrets > New client secret**, create
a credential with an appropriate expiry and rotation owner. Copy its **Value**
(not its Secret ID) directly into the ingestion application's Key Vault as
`sharepointClientSecret`, or a reviewed custom secret name. Do not put the value
in Cosmos DB, plaintext App Configuration, source files or command logs.
The current Graph client uses this client-secret flow. Native indexed
SharePoint's federated credentials are a different configuration.

### 4. Configure runtime settings

In **App Configuration > Configuration explorer**, set the following under
the shared **`agent-lz`** label. Preserve the environment's provisioned
resource endpoints and identities.

<div class="reference-fields responsive-reference" markdown="1">
<table role="table" markdown="1">
<thead role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="col" role="columnheader" markdown="span">Key</th>
<th scope="col" role="columnheader" markdown="span">Value or purpose</th>
</tr>
</thead>
<tbody role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">`SHAREPOINT_TENANT_ID`</th>
<td role="cell" data-label="Value or purpose" markdown="span">Directory/tenant ID of the SharePoint application.</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">`SHAREPOINT_CLIENT_ID`</th>
<td role="cell" data-label="Value or purpose" markdown="span">Application/client ID registered above.</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">`SHAREPOINT_CLIENT_SECRET_NAME`</th>
<td role="cell" data-label="Value or purpose" markdown="span">Key Vault secret **name**, default `sharepointClientSecret`.</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">`SHAREPOINT_FILES_FORMAT`</th>
<td role="cell" data-label="Value or purpose" markdown="span">Comma-separated extensions. The default when omitted or empty is `pdf,docx,pptx`.</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">`KEY_VAULT_URI`</th>
<td role="cell" data-label="Value or purpose" markdown="span">Ingestion Key Vault URI containing that secret.</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">`SEARCH_SERVICE_QUERY_ENDPOINT`</th>
<td role="cell" data-label="Value or purpose" markdown="span">Target Search service root, such as `https://<service>.search.windows.net`.</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">`SEARCH_RAG_INDEX_NAME`</th>
<td role="cell" data-label="Value or purpose" markdown="span">Existing compatible target index for custom ingestion.</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">`DATABASE_ACCOUNT_NAME`, `DATABASE_NAME`</th>
<td role="cell" data-label="Value or purpose" markdown="span">Cosmos DB account name and database containing the source definitions.</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">`COSMOS_DATASOURCES_CONTAINER`</th>
<td role="cell" data-label="Value or purpose" markdown="span">Source-definition container, default `datasources`.</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">`STORAGE_ACCOUNT_NAME`, `JOBS_LOG_CONTAINER`</th>
<td role="cell" data-label="Value or purpose" markdown="span">Job-log storage account and container. The container defaults to `jobs`.</td>
</tr>
</tbody>
</table>
</div>
`APP_CONFIG_ENDPOINT` must already be in the Container App's process
environment so the application can load its settings. The current loader also
reads other labels, including an all-labels selection. Remove conflicting
same-key values and verify the **effective** settings rather than assuming
`agent-lz` wins. See [Application settings](application-settings.md).

Jobs run in the ingestion Container App using the source definitions and
schedules below. There is no separate `SHAREPOINT_CONNECTOR_ENABLED` gate.

### 5. Add the source metadata in Cosmos DB

Open the configured Cosmos DB account's **Data Explorer**, select
`DATABASE_NAME` and the `datasources` container (or
`COSMOS_DATASOURCES_CONTAINER` override), and create one item per site with
`type: "sharepoint_site"`. Use actual Graph-discovered values in this example
and satisfy the existing container's partition-key definition.

```json
{
  "id": "contoso-marketing-site",
  "type": "sharepoint_site",
  "description": "Contoso Marketing pilot",
  "siteDomain": "contoso.sharepoint.com",
  "siteName": "SalesAndMarketing",
  "category": "Marketing",
  "lists": [
    {
      "listId": "1be0da74-2b71-45e0-a9d3-1ffafa7d0ba7",
      "listName": "Shared Documents",
      "listType": "documentLibrary",
      "category": "Contoso Documents",
      "filter": ""
    },
    {
      "listId": "7691f86f-8bdc-40eb-bcf5-7a23d0e9006c",
      "listName": "Product List",
      "listType": "genericList",
      "category": "Contoso Products",
      "filter": "",
      "includeFields": [
        "Title",
        "Code_x0020_Name",
        "Product_x0020_Line",
        "Modified",
        "Attachments"
      ],
      "excludeFields": []
    }
  ]
}
```

Only declared lists are indexed. An absent or empty `lists` array does not
mean "index the whole site."

| Field | How to choose it |
| --- | --- |
| `siteDomain`, `siteName` | Required by the connector's site-ID lookup. Use the URL values discovered above. |
| `listId` | Prefer the Graph GUID. Name-only lookup is a legacy fallback. Retain `listName` for readable logs. |
| `listType` | Use `genericList` or `documentLibrary` from `list.template`. Set it explicitly for libraries. The default is `genericList`. |
| `includeFields` | Internal column names for generic-list text. Omitted or empty means all returned fields. Keep `Title` and `Modified`, and include `Attachments` when classic-list attachments are needed. Modification detection uses the item's `lastModifiedDateTime`, with `fields.Modified` as fallback. |
| `excludeFields` | Optional fields to omit from the generated field text. This is not an authorization control. |
| `category` | List-level value overrides the site's default. |
| `filter` | Optional Graph OData item filter. Empty selects all returned items in the configured list. Test the filter before scheduling. |

For document libraries, leave `includeFields` unset as shown. The connector
downloads the underlying file through `driveItem` and applies
`SHAREPOINT_FILES_FORMAT`. Selecting a field does not add unsupported file
formats or grant access to another site or lookup list.

### 6. Schedule indexing and purge

Add these App Configuration values under `agent-lz` after validating the pilot
source and credentials:

```text
CRON_RUN_SHAREPOINT_INDEX=0 * * * *
CRON_RUN_SHAREPOINT_PURGE=30 */6 * * *
RUN_JOBS_ON_STARTUP=false
```

The runtime uses APScheduler's **five-field crontab** format:
`minute hour day-of-month month day-of-week`. These examples index hourly at
minute 0 and purge every six hours at minute 30. They are not six-field Azure
Functions timers. The scheduler uses the process `SCHEDULER_TIMEZONE` when set
to a valid time-zone name, otherwise the machine's local time zone. Confirm
the effective zone and next scheduled run.

An unset or blank SharePoint cron value means no automatic schedule.
`RUN_JOBS_ON_STARTUP` defaults to `true`, which also immediately runs jobs that
have schedules. `false` avoids those immediate runs but does not disable cron.
It is a shared setting affecting the other scheduled ingestion/purge jobs too.
Invalid cron expressions fail schedule setup.

Restart the ingestion Container App after changing credentials or initial
configuration. Where the authenticated administrative surface is mounted,
its configuration apply operation can reload settings and reschedule jobs.
It also supports manual execution:

```http
POST https://<ingestion-app-host>/api/jobs/sharepoint_index/run
POST https://<ingestion-app-host>/api/jobs/sharepoint_purge/run
```

Use the deployment's configured administrative authentication. Do not expose
an unconfigured development endpoint. These routes require Admin when Entra
authentication is configured and are not mounted in every hosted/panel mode.
`202 Accepted` means queued, not indexed. `409` means that job type is already
running. See [Jobs & schedules](ingestion-jobs.md) for scheduling, conflicts and
cleanup effects, [Administration](operations.md) for route availability, and
[API reference](application-api.md) for request details.

- **Indexing:** handles new/modified content and refreshes the selected
  items' ACLs.
- **Purge:** compares indexed SharePoint item IDs with Graph and removes
  copies for missing items.

!!! warning "Purge is not complete source retirement"
    The current purger scans indexed collections. It does not apply the
    source's item filter and skips deletion when a collection enumeration is
    empty or unavailable.

    None of these actions proves that indexed copies were deleted:

    - Removing a source definition.
    - Changing a filter.
    - Deleting the last item.
    - Revoking site access.

    Do not treat purge as full retirement or filter reconciliation.
    Verify deletion explicitly and use a separately authorized, scoped
    Search cleanup when needed.

### 7. Validate ingestion and connect the index to Foundry IQ

1. Add a distinctive pilot list item and a supported file to the selected
   collections. Run indexing manually or wait for the next scheduled run.
   Inspect the **Container App** logs and job summaries, not Function App logs.
   With writable job storage, the default summaries are under
   `jobs/sharepoint-indexer/runs/` and `jobs/sharepoint-purger/runs/`, with
   per-item indexing logs under the indexer's prefix. Check item failures,
   blocked files and confirmed indexed/deleted counts, not only HTTP status
   or health probes.
2. In Search Explorer, inspect the target index for the pilot's text and
   citation URL. Connector documents use `source: "sharepoint-list"`, including
   document-library chunks. Check `content`, `contentVector`, `url`,
   `parent_id`, `metadata_storage_last_modified`,
   `metadata_security_user_ids` and `metadata_security_group_ids`.
   Change the content and rerun to confirm incremental updates.
3. If using Foundry IQ, register a **`searchIndex`** knowledge source pointing
   to this populated index and reference it in the knowledge base. The index
   and knowledge base must be on the **same Search service**. Keep the
   ingestion target `SEARCH_RAG_INDEX_NAME` and
   `FOUNDRY_IQ_SEARCH_INDEX_NAME` aligned when selecting this index as the
   accelerator's primary source. Select matching
   `FOUNDRY_IQ_PATTERN=searchIndex` and
   `FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND=searchIndex`. An additional source instead
   needs an explicit knowledge-base binding. Do not point at the separate
   index generated for a native Blob or `indexedSharePoint` source.
4. Verify the [Search index source requirements](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-search-index):
   a compatible text/vector schema, semantic configuration, and retrievable
   content/citation fields. Vector dimensions must match the embedding
   deployment. For protected retrieval, retain native permission filtering
   with the user/group ACL field annotations and pass the delegated Search
   user token as described in [Foundry IQ](foundry-iq.md#delegated-native-retrieval).
   Source registration does not ingest content or turn ACL arrays into
   enforced authorization by itself.
5. Run the allowed/denied-user checks below, including a permission-only
   revocation and an unchanged-content rerun. Delete a pilot item while
   another remains in its collection, run purge, and verify that **all**
   indexed copies of the deleted item disappear. Separately test the
   empty-collection cleanup case described above.

Use [Monitoring & audit](application-monitoring.md) for run correlation and
document events. A completed run does not replace checking the indexed content
and its permissions.

### Permission synchronization

Each custom SharePoint indexing run reads current permissions independently of
content modification timestamps. It compares the stored user and group ACLs on
every indexed document for each selected item, including all document-library
chunks and previously indexed file names. Changed ACLs are replaced, so
revocations remove stale principals. A successful empty permission result clears
the stored principal lists.

Equal ACL sets cause no writes. Unchanged content
is not downloaded, chunked or embedded. ACL-only merges change neither content,
vectors nor content timestamps.

Custom target indexes need a filterable `parent_id`, sortable `id`, and
retrievable ACL fields, as provided by the bundled index. Rebuild indexes that
explicitly disable these attributes before running the connector.

The cadence is the ingestion application's `CRON_RUN_SHAREPOINT_INDEX`
schedule, not real-time notification. An unset schedule performs no automatic
refresh. The SharePoint index job can also be run manually.

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
the stored ACL with the current effective result. The connector does not union
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
lookup is not treated as an empty ACL. Search must confirm every merge. A
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
The allowed user receives grounded content and a citation that opens in SharePoint.
the denied user's retrieved IDs, excerpts and citations exclude the document.
Other sources must not expose an unprotected copy. Missing or expired user
credentials must not fall back to service-only access.

Private Azure endpoints do not make Microsoft 365 a private-link source.
Connectivity tests cover the actual calling service, Microsoft 365 and Entra.
Recovery restores the previous application/settings and removes the pilot
knowledge-base reference without deleting shared content or tenant objects.
Permission revocation and retirement of indexed copies remain separate tasks.
