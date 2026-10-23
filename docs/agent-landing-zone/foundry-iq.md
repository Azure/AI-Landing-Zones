# Foundry IQ

Use a Foundry IQ knowledge base as the bundled application's retrieval target.
A **knowledge source** describes searchable content; a **knowledge base** binds
sources and handles retrieval. The application consumes that knowledge base.
Changing application settings does not create a source or ingest documents.

This page covers the orchestrator hosted in Foundry. Start with a working
[full-stack deployment](deploy-full-stack.md) and its pinned application sources.

!!! warning "Hosted authorization boundary"
    In the pinned hosted runtime, the entrypoint clears caller identity context
    and does not pass a delegated user token to the Foundry IQ connector.
    The connector's authenticated retrieval path requires that token and fails
    closed when it is absent. A signed-in UI session or a project connection
    does not fix this. Do not enable anonymous access or remove source permission
    checks to make retrieval succeed. For permission-sensitive content, stop
    before application cutover until a reviewed hosted identity integration
    supplies the required trusted token and passes allow/deny tests.
    See [Application authentication](application-auth.md).

To implement that integration, use the
[custom application workflow](build-your-own-app.md) to pin and deploy reviewed
orchestrator changes. Preserve the trust boundary at hosted request handling,
the connector's OBO requirements and each source's permission enforcement.
This is custom code and security validation, not a shipped enable switch.

## Before you start

- Record the deployed Search endpoint, knowledge-base name, knowledge-source
  name and Foundry project connection ID. Read the current App Configuration
  values with label **`agent-lz`**; do not infer names from examples.
- The source administrator needs Search Service Contributor to manage knowledge
  objects. Native Blob setup also requires Search Index Data Contributor.
  Role assignment changes require separate scoped authorization.
- The retrieval identity needs Search Index Data Reader on the target Search
  service. The hosted bootstrap grants configuration/model access, not every
  source permission; see [Hosted agents](hosted-agents.md).
- For private deployments, use an authorized network-connected administration
  host. Verify runtime-to-Search connectivity and Search-to-storage/model
  connectivity separately. See [Network isolation](network-isolation.md).

The shipped connector pins `FOUNDRY_IQ_API_VERSION=2026-05-01-preview`.
Current Microsoft examples can use newer API versions. Do not replace the
shipped version or copy newer request fields without testing compatibility
with the pinned application and platform.

## 1. Choose who manages the source

| Your case | Action |
| --- | --- |
| Use the deployed Blob corpus | Keep the platform-managed native Blob source below. |
| Connect an existing knowledge base | Leave its sources with their owner; configure application consumption in step 3. |
| Reuse an existing Search index | Register it as a `searchIndex` knowledge source and bind it to an operator-owned knowledge base. The application still retrieves through Foundry IQ, not directly from the index. |
| Add approved content | Add a source to an operator-owned knowledge base, preserving its existing source list; see step 2. |

### Default Blob source

The platform defaults to `FOUNDRY_IQ_PATTERN=azureBlob`, container `documents`,
standard extraction and ingestion permission options `["rbacScope"]`.
Foundry IQ manages the generated ingestion assets.

1. Read `FOUNDRY_IQ_STORAGE_CONTAINER_NAME` and
   `FOUNDRY_IQ_STORAGE_FOLDER_PATH` from the deployed configuration.
2. With an approved storage data-write role, upload a small document with a
   distinctive test sentence to that location. Do not use chat file upload
   to populate this shared corpus.
3. Inspect the source's generated indexer status and retrieve the test sentence
   from the knowledge base. Expect a reference to that document before
   attempting application cutover.

The application ingestion service is optional for this native source. It is
not the same pipeline as conversation uploads or SharePoint jobs; follow
[Ingestion](ingestion.md) for those.

For source setup, use Microsoft's
[Blob knowledge-source procedure](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-blob).
The Search managed identity needs Storage Blob Data Reader on the source
storage account and Cognitive Services User on the Foundry resource.
An asset store can additionally require Storage Blob Data Contributor.
These grants belong to the ingestion identity, not the signed-in chat user.

**Optional permission ingestion:** `FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS`
controls which permission metadata is ingested; `FOUNDRY_IQ_IS_ADLS_GEN2`
describes an ADLS Gen2 source. These are source-setup inputs, not application
authorization switches. Preserve the source's RBAC/ACL model, rebuild or rerun
ingestion as required by the source procedure, and verify denied users cannot
retrieve restricted content. The hosted token limitation above still applies.

**Private ingestion:** the platform checks shared private-link readiness and
attempts to set generated indexers to private execution for isolated deployments.
If an indexer has not been created yet, setup skips that update: inspect the
generated indexer's execution environment before ingesting sensitive content.
Approvals, DNS and source/model reachability must be ready; a private endpoint
for inbound Search traffic alone is insufficient. Review the current service
tier and preview requirements in the Microsoft Blob procedure before changing
the source or isolation settings.

## 2. Connect existing content or add a source

Do this as the source administrator, separately from application deployment.

1. Export the existing knowledge-base and source definitions and record their
   owner. Do not use the platform's generated source or knowledge-base names
   for externally managed objects.
2. For an existing knowledge source, confirm it is on the same Search service
   as the target knowledge base. For an existing index, follow
   [Create a Search index knowledge source](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-search-index).
   Validate its semantic configuration and the content/reference fields.
   Registering an index does not create missing permission metadata.
3. Create an operator-owned knowledge base, or update one you already own,
   using [Create a knowledge base](https://learn.microsoft.com/azure/search/agentic-retrieval-how-to-create-knowledge-base).
   Include the approved source in `knowledgeSources`. When updating, preserve
   all existing source references and other required properties rather than
   replacing the definition with a one-source example.
4. Test retrieval against this knowledge base before changing the application.
   Check both content and source references. For protected content, also test
   an authorized user and a user who must be denied.

!!! warning "Provisioning can overwrite manual changes"
    Platform Search setup creates or updates the named sources and knowledge
    bases from `config/search/search.j2`. A later provision can replace manual
    edits to those objects, including added source references. Setting an
    existing object's name as a provisioning input does not make it read-only.
    Keep externally managed objects under distinct names and endpoints as
    appropriate. For additions to platform-managed objects, maintain a reviewed
    platform template change in your deployment repository instead of relying
    on a portal edit. This page does not change those templates.

An additional source is not automatically an application-supported integration.
Some kinds require source-specific request parameters, consent or delegated
identity. Use [SharePoint](sharepoint.md), [Work IQ](work-iq.md),
[Fabric IQ](fabric-iq.md) or [Agent tools](agent-tools.md) for those contracts;
do not invent a generic “enable source” setting.

Current Microsoft procedures describe service capability, not a guarantee that
every source kind is supported by this pinned hosted application.

## 3. Configure application consumption

For the bundled `single_agent_rag` strategy, verify these runtime settings in
App Configuration. Changing the source kind does not change the hosting mode.
This is the consumption contract, not a configuration-only solution to the
hosted authorization boundary. Complete source setup independently; perform
an authenticated application cutover only after that boundary is resolved.

| Key | Value or meaning |
| --- | --- |
| `AGENT_STRATEGY` | `single_agent_rag` for this recipe. |
| `SEARCH_RETRIEVAL_ENABLED` | `true`; enables the strategy's knowledge retrieval tool. |
| `RETRIEVAL_BACKEND` | `foundry_iq`; set explicitly rather than relying on the connector's fallback. |
| `KNOWLEDGE_BASE_ENDPOINT` | Search service root, for example `https://<service>.search.windows.net`; not a Foundry project URL or `/retrieve` URL. |
| `KNOWLEDGE_BASE_NAME` | Name of the knowledge-base object, not an index name or resource ID. |
| `FOUNDRY_IQ_KNOWLEDGE_SOURCE_NAME` | Registered primary source name in that knowledge base. |
| `FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND` | `azureBlob` for the default native source; `searchIndex` for a registered existing index. |
| `FOUNDRY_IQ_PATTERN` | `azureBlob` or `searchIndex`, matching the primary source. |
| `FOUNDRY_IQ_API_VERSION` | Keep the shipped `2026-05-01-preview` unless a compatibility change has been reviewed. |
| `KNOWLEDGE_BASE_CONNECTION_ID` | Provisioned Foundry project connection resource ID, distinct from the endpoint and knowledge-base name. |

The foundation creates an AAD-authenticated `CognitiveSearch` connection to the
Search service. Its ID has this shape:

```text
/subscriptions/<subscription>/resourceGroups/<group>/providers/Microsoft.CognitiveServices/accounts/<account>/projects/<project>/connections/<connection>
```

In this release the retrieval connector does **not** read
`KNOWLEDGE_BASE_CONNECTION_ID`: it calls the configured Search endpoint and
knowledge-base name directly. Changing only the connection ID cannot redirect
retrieval, authorize a user or register a source. Have the foundation owner
reconcile connection metadata separately when connecting another service;
do not hand-edit a provisioning-owned connection as a retrieval fix.

### Apply a runtime change safely

1. Record the previous values for rollback. Check your deployment inputs too:
   provisioning writes these keys again. A runtime-only edit is not a durable
   change to a platform-managed deployment.
2. With App Configuration Data Owner on the store, update only the reviewed
   nonsecret keys using Entra authentication. For example, in PowerShell:

    ```powershell
    $store = '<app-configuration-store-name>'
    az appconfig kv set --name $store --auth-mode login --label agent-lz `
      --key KNOWLEDGE_BASE_NAME --value '<operator-owned-kb>' --yes
    az appconfig kv show --name $store --auth-mode login --label agent-lz `
      --key KNOWLEDGE_BASE_NAME --query value -o tsv
    ```

    Repeat for the other changed keys in the table, keeping endpoint, name and
    source settings consistent. Do not put access tokens, API keys or connection
    strings in these commands.
3. Deploy a new hosted agent version through the
   [application redeployment procedure](deploy-full-stack.md#redeploy-applications-only).
   The configuration is cached in-process and the backend selector is cached
   separately. A portal save is not a refresh of running versions. Do not
   restart a Container App to refresh a Foundry hosted agent.
4. Confirm traffic uses the new hosted version before verification. Reuse a
   compatible immutable image for configuration-only changes; code changes
   require the image preparation and handoff workflow in
   [Hosted agents](hosted-agents.md).

Do not run provisioning merely to activate a runtime edit against an
operator-owned knowledge base: it can reconcile generated objects and settings.
Record runtime overrides and their reapplication in your deployment process.

## 4. Verify and recover

- **Source check:** the source's indexing run completes and a known document
  is retrievable from the intended knowledge base with an expected reference.
- **Application check:** use a question unique to that document. Confirm the
  new hosted version attempts Foundry IQ retrieval and returns grounded
  content/references, rather than treating a fluent answer as proof.
  This success criterion applies only once the hosted identity integration
  is in place; the pinned authenticated path otherwise stops at its token check.
- **Authorization check:** verify allow/deny behavior independently. If the
  pinned hosted connector reports a missing incoming user token, this is the
  documented boundary, not a reason to grant broader data access.

| Symptom | Check or recovery |
| --- | --- |
| Knowledge base/source not found | Confirm Search endpoint, object names and knowledge-base membership; a project connection does not create these objects. |
| Ingestion fails | Check Search identity roles, generated indexer status and private-link approvals/reachability before changing application keys. |
| Search returns 403 | Check the actual retrieval principal's scoped data role. Do not confuse it with the project identity or ingestion identity. |
| Missing user token or OBO failure | Preserve authentication and source ACLs. A hosted extension must supply validated delegated context; configuration alone cannot do so. |
| Old target still used | Verify the new version is deployed and receiving traffic; review cached settings and later provisioning overwrites. |
| Added source disappears after provision | Restore the saved definition under an operator-owned name, or reconcile the approved source into your managed template. |

To undo a runtime cutover, restore the recorded settings and deploy a new hosted
version using the previous compatible image. Leave the prior knowledge base
and documents intact until verification succeeds; deleting a generated index
is not a rollback procedure.
