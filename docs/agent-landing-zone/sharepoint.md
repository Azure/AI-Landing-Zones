# SharePoint

Let a signed-in employee ask the hosted application about a SharePoint document
and follow its citation back to SharePoint. Start with a **remote SharePoint
knowledge source** in Foundry IQ: documents are queried in Microsoft 365 rather
than copied into a retrieval index. Retrieved text still reaches the application
and model. Retrieval uses the employee's permissions. The optional ingestion
application is not needed for this source.

!!! warning "Preview and licensing"
    Remote SharePoint and its Copilot Retrieval API are previews, not recommended
    for production workloads and not covered by a service-level agreement.
    Each querying user needs either a Microsoft 365 Copilot add-on license that
    includes Retrieval API usage, or enabled Retrieval API pay-as-you-go
    consumption (also preview). Pay-as-you-go requires at least one Microsoft
    365 Copilot license in the tenant throughout its use, plus administrator
    billing setup. Follow the current
    [remote SharePoint prerequisites](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-sharepoint-remote).
    An Azure subscription alone does not establish Microsoft 365 eligibility.

## Before you start

- Complete [full-stack deployment](deploy-full-stack.md) with the orchestrator
  hosted in Foundry and `RETRIEVAL_BACKEND=foundry_iq` working. Use a
  hosted-supported retrieval strategy such as `maf_lite`, not a Toolbox MCP
  strategy.
- Establish authenticated user access and working on-behalf-of (OBO) retrieval.
  A managed identity calling the knowledge base and the delegated user
  authorizing source access are different identities. Do not use anonymous chat
  for this scenario. The hosted caller token must reach the orchestrator for
  its delegated exchange; signing into the Foundry portal alone is not this
  application sign-in flow.
- Use SharePoint in the same Microsoft Entra tenant as Azure. Have an
  administrator confirm licensing or pay-as-you-go eligibility.
- Have permission to create knowledge sources and update the selected knowledge
  base. Microsoft recommends Search Service Contributor for keyless source
  management. Updating application settings separately requires App
  Configuration data-plane write access.
- Prepare one text document in a test site, a user allowed to read it and a
  second user denied access. Use non-sensitive test content with a distinctive
  fact, such as an invented project deadline.

Remote retrieval supports textual SharePoint content, not OneDrive, Copilot
connector content or multimodal retrieval. See Microsoft's
[limitations](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-sharepoint-remote#limitations-and-considerations)
before choosing a document.

## Connect the source

1. Record the application's existing Foundry IQ knowledge base name and
   configuration. A **knowledge source name** identifies a registered source;
   it is not the SharePoint site URL, a tenant ID or a knowledge base name.

2. Follow Microsoft's
   [remote SharePoint source procedure](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-sharepoint-remote)
   to create a `remoteSharePoint` source and add it to the knowledge base used
   by the application. Keep the existing source references.
   The bundled platform does not provision a remote source merely because a
   runtime setting names it.

   Use the service API version supported by your deployed application.
   Current Microsoft examples can target a newer preview than the pinned
   application; do not change `FOUNDRY_IQ_API_VERSION` just to match an example.
   Record this manually added source reference: a later provisioning run can
   reapply the template-managed knowledge base definition. Check membership
   again after provisioning or an upgrade.

3. Optionally scope the source to the test site's path using the documented KQL
   filter syntax. Validate the filter with test documents inside and outside
   that path. A filter is a relevance/scope aid, **not an authorization boundary**:
   the Retrieval API can ignore invalid KQL filters.

4. In the deployed Azure App Configuration store, open **Configuration explorer**.
   Add the following non-secret settings with label **`agent-lz`**:

   | Key | Value |
   | --- | --- |
   | `SHAREPOINT_REMOTE_KNOWLEDGE_SOURCE_NAME` | The exact registered source name |
   | `SHAREPOINT_REMOTE_ENABLED` | `true` |

   Leave `SHAREPOINT_REMOTE_FILTER_EXPRESSION_ADD_ON` unset for the first test.
   It is an optional additional KQL filter, not an ACL setting. Do not paste
   tokens, passwords or connection strings into these settings.

5. Redeploy the hosted application through the existing
   [deployment workflow](deploy-full-stack.md). The connector caches its
   configuration in-process; do not assume changing the store updates a running
   hosted version. Ensure the newly deployed version is serving the UI.
   Do not restart a Container App as a substitute for updating the hosted agent.

The connector sends the delegated token in
`x-ms-query-source-authorization`. Remote SharePoint uses that token to enforce
SharePoint permissions and Microsoft Purview sensitivity labels. Enabling the
source does not grant the user access, repair OBO consent or create a source.
The application acquires the source-authorization token for the Search audience;
do not substitute a manually copied Graph token or an application-only token.
See [query-time permissions](https://learn.microsoft.com/azure/search/agentic-retrieval-how-to-retrieve#enforce-permissions-at-query-time-preview).

## Verify

1. Sign in as the allowed user and ask about the distinctive fact in the test
   document, for example, "What is the deadline for Project Cedar?" Expect a
   grounded answer with a SharePoint citation pointing to the intended document.
   Open it to confirm.
2. In a separate signed-in session, ask the same question as the denied user.
   Expect no restricted fact or citation in the answer. A greeting or a
   successful model response is not proof of source authorization.
3. Check retrieval diagnostics for the selected remote source and returned
   references. If other knowledge sources are enabled, confirm they cannot
   supply a copied version of the same restricted content.

Do not release the scenario until both allow and deny tests pass. Repeat them
after changing site permissions, OBO configuration or source bindings.

## Recover or disconnect

| Symptom | Check |
| --- | --- |
| Source is absent | Exact source name, knowledge base membership, `agent-lz` label and the serving hosted version. |
| Authentication failure or no delegated token | User sign-in, the application's OBO configuration and required consent. Do not replace user authorization with a service identity or enable anonymous access. |
| Empty results | User can open the document in SharePoint; content is supported; licensing/billing is enabled; filters are valid. Ask about document content rather than its location. |
| Private deployment cannot retrieve | Validate the permitted outbound path and DNS from the actual runtime. Private Azure endpoints do not make Microsoft 365 SharePoint a private-link source. |
| Denied user sees restricted content | Stop rollout. Inspect source ACLs, delegated identity and duplicate content in other sources before retesting. |

To disconnect, restore the recorded application settings (or set
`SHAREPOINT_REMOTE_ENABLED=false`) and redeploy the hosted application. Remove
the source reference from the application's knowledge base as well; delete the
source only if no other application needs it. Disabling the runtime flag alone
does not remove knowledge base membership or revoke permissions.

## When you need indexed content

Do not confuse these alternatives with remote, user-authorized retrieval:

| Path | Who ingests content | Authorization requirement |
| --- | --- | --- |
| Native `indexedSharePoint` source (preview) | A service-managed indexing pipeline; no bundled ingestion app | Configure supported permission ingestion and forward the querying user's token. App permission to read a site is not document-level enforcement for end users. |
| Bundled SharePoint jobs | The optional Agent App Ingestion application, using Microsoft Graph application credentials | Preserve the application's indexed permission metadata and retrieval filtering; validate allowed and denied users. Not the remote source's live permission check. |

The shipped indexed SharePoint registration payload uses `indexName`, `siteUrl`
and `tenantId`. It is not compatible with the current documented
`2026-08-01-preview` contract, which uses `connectionString`, `containerName`,
`query` and `ingestionParameters`. Enabling `SHAREPOINT_INDEXED_ENABLED` is
therefore not a ready-to-use path. The platform also cannot verify the manual
Entra/Graph permissions. For a native indexed extension, reconcile the
provisioning template with the supported service API and complete the
[official indexed SharePoint prerequisites and permission configuration](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-sharepoint-indexed)
before adopting it. Do not copy newer preview API fields into runtime settings.

If you specifically need the bundled application's SharePoint jobs, select and
deploy the optional ingestion application using
[Ingestion and conversation uploads](ingestion.md). Those jobs use the
`SHAREPOINT_*` application credential settings, not the
`SHAREPOINT_REMOTE_*` settings above. Store secrets in Key Vault, not shell
history. Native source registration does not deploy those jobs, and disabling
ingestion is not a migration for existing indexed content.
