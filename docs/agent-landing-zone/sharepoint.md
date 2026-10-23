# SharePoint

Let a signed-in employee ask hosted Agent Application about a SharePoint document
and follow its citation back to SharePoint. Start with a **remote SharePoint
knowledge source** in Foundry IQ: documents are queried in Microsoft 365 rather
than copied into a retrieval index. Retrieved text is sent to Agent Application
and its model. Retrieval uses the employee's permissions. Optional Agent App
Ingestion is not needed for this source.

!!! warning "Preview and licensing"
    Remote SharePoint and its Copilot Retrieval API are previews, not recommended
    for production workloads and not covered by a service-level agreement.
    Each querying user needs either a Microsoft 365 Copilot add-on license that
    includes Retrieval API usage, or enabled Retrieval API pay-as-you-go
    consumption (also preview). Pay-as-you-go requires at least one Microsoft
    365 Copilot license in the tenant throughout its use, plus administrator
    billing setup. Follow the current
    [remote SharePoint prerequisites](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-sharepoint-remote).
    Have the Microsoft 365 administrator confirm eligibility before setup.

## Before you start

- Complete [full-stack deployment](deploy-full-stack.md) with the orchestrator
  hosted in Foundry and `RETRIEVAL_BACKEND=foundry_iq` working. Use a
  hosted-supported retrieval strategy such as `maf_lite`, not a Toolbox MCP
  strategy.
- Establish authenticated user access and working on-behalf-of (OBO) retrieval.
  The managed identity authenticates the service call; the delegated user token
  authorizes access to SharePoint content. This requires authenticated chat and
  a trusted delegated-token path into retrieval. The pinned hosted entry point
  does not supply that token. Resolve the [hosted identity boundary](foundry-iq.md)
  through a reviewed integration before following this source recipe.
- Use SharePoint in the same Microsoft Entra tenant as Azure. Have an
  administrator confirm licensing or pay-as-you-go eligibility.
- Have permission to create knowledge sources and update the selected knowledge
  base. Microsoft recommends Search Service Contributor for keyless source
  management. Updating Agent Application settings separately requires App
  Configuration data-plane write access.
- Prepare one text document in a test site, a user allowed to read it and a
  second user denied access. Use non-sensitive test content with a distinctive
  fact, such as an invented project deadline.

Remote retrieval supports textual SharePoint content, not OneDrive, Copilot
connector content or multimodal retrieval. See Microsoft's
[limitations](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-sharepoint-remote#limitations-and-considerations)
before choosing a document.

## Connect the source

1. Record Agent Application's existing Foundry IQ knowledge base name and
   configuration. A **knowledge source name** identifies a registered source;
   it is not the SharePoint site URL, a tenant ID or a knowledge base name.

2. Follow Microsoft's
   [remote SharePoint source procedure](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-sharepoint-remote)
   to create a `remoteSharePoint` source and add it to the knowledge base used
   by Agent Application. Keep the existing source references. Create this
   source separately before configuring Agent Application to use it.

   Use the service API version supported by your deployed Agent Application.
   Current Microsoft examples can target a newer preview than the pinned
   Agent Application. Keep `FOUNDRY_IQ_API_VERSION` at its validated version
   until a coordinated compatibility change is ready.
   Record this manually added source reference: a later provisioning run can
   reapply the template-managed knowledge base definition. Check membership
   again after provisioning or an upgrade.

3. Optionally scope the source to the test site's path using the documented KQL
   filter syntax. Validate the filter with test documents inside and outside
   that path. KQL narrows retrieval scope, while SharePoint permissions enforce
   authorization. The Retrieval API can ignore invalid KQL filters.

4. In the deployed Azure App Configuration store, open **Configuration explorer**.
   Add the following non-secret settings with label **`agent-lz`**:

   | Key | Value |
   | --- | --- |
   | `SHAREPOINT_REMOTE_KNOWLEDGE_SOURCE_NAME` | The exact registered source name |
   | `SHAREPOINT_REMOTE_ENABLED` | `true` |

   Leave `SHAREPOINT_REMOTE_FILTER_EXPRESSION_ADD_ON` unset for the first test.
   It narrows retrieval scope using additional KQL. Do not paste
   tokens, passwords or connection strings into these settings.

5. Redeploy hosted Agent Application through the existing
   [deployment workflow](deploy-full-stack.md). The connector loads and caches
   configuration at startup. Confirm the newly deployed hosted version is
   serving the UI before testing.

The connector sends the delegated token in
`x-ms-query-source-authorization`. Remote SharePoint uses that token to enforce
SharePoint permissions and Microsoft Purview sensitivity labels. Source
registration, delegated consent and SharePoint access must all be in place.
The Agent Application connector acquires the source-authorization token for the
Search audience when supplied with the required delegated context;
do not substitute a manually copied Graph token or an application-only token.
See [query-time permissions](https://learn.microsoft.com/azure/search/agentic-retrieval-how-to-retrieve#enforce-permissions-at-query-time-preview).

## Verify

1. Sign in as the allowed user and ask about the distinctive fact in the test
   document, for example, "What is the deadline for Project Cedar?" Expect a
   grounded answer with a SharePoint citation pointing to the intended document.
   Open it to confirm.
2. In a separate signed-in session, ask the same question as the denied user.
   Inspect retrieved document IDs and confirm that the restricted document,
   its content and its citation are absent.
3. Check retrieval diagnostics for the selected remote source and returned
   references. If other knowledge sources are enabled, confirm they cannot
   supply a copied version of the same restricted content.

Do not release the scenario until both allow and deny tests pass. Repeat them
after changing site permissions, OBO configuration or source bindings.

## Recover or disconnect

| Symptom | Check |
| --- | --- |
| Source is absent | Exact source name, knowledge base membership, `agent-lz` label and the serving hosted version. |
| Authentication failure or no delegated token | User sign-in, Agent Application's OBO configuration and required consent. Do not replace user authorization with a service identity or enable anonymous access. |
| Empty results | User can open the document in SharePoint; content is supported; licensing/billing is enabled; filters are valid. Ask about document content rather than its location. |
| Private deployment cannot retrieve | Validate the permitted outbound path and DNS from the actual runtime. Private Azure endpoints do not make Microsoft 365 SharePoint a private-link source. |
| Denied user sees restricted content | Stop rollout. Inspect source ACLs, delegated identity and duplicate content in other sources before retesting. |

To disconnect, restore the recorded Agent Application settings (or set
`SHAREPOINT_REMOTE_ENABLED=false`) and redeploy hosted Agent Application. Remove
the source reference from Agent Application's knowledge base as well; delete the
source only if no other application needs it. Review and revoke source
permissions separately where appropriate.

## When you need indexed content

Indexed retrieval copies content into Search and requires permission metadata
and query-time filtering. Choose the pipeline that owns that work:

| Path | Who ingests content | Authorization requirement |
| --- | --- | --- |
| Native `indexedSharePoint` source (preview) | A service-managed indexing pipeline; no Agent App Ingestion required | Configure supported permission ingestion and forward the querying user's token so retrieval can enforce document-level permissions. |
| Agent Application SharePoint jobs | Optional Agent App Ingestion, using Microsoft Graph application credentials | Preserve indexed permission metadata and retrieval filtering; validate allowed and denied users against the indexed content. |

The shipped indexed SharePoint registration payload uses `indexName`, `siteUrl`
and `tenantId`. It is not compatible with the current documented
`2026-08-01-preview` contract, which uses `connectionString`, `containerName`,
`query` and `ingestionParameters`. Before using `SHAREPOINT_INDEXED_ENABLED`,
update and validate that registration template. An administrator must also
verify the manual Entra/Graph permissions. For a native indexed extension, reconcile the
provisioning template with the supported service API and complete the
[official indexed SharePoint prerequisites and permission configuration](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-sharepoint-indexed)
before adopting it. Make API-field changes in the provisioning template.

If you specifically need Agent Application's SharePoint jobs, select and
deploy optional Agent App Ingestion using
[Ingestion and conversation uploads](ingestion.md). Those jobs use the
`SHAREPOINT_*` Entra app credential settings, not the
`SHAREPOINT_REMOTE_*` settings above. Store secrets in Key Vault, not shell
history. Deploy those jobs separately from native source registration. Plan
how existing indexed content and its permissions will be maintained before
disabling ingestion.
