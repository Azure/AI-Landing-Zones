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
Azure in the same Entra tenant. Each querying user needs a qualifying Microsoft
365 Copilot add-on license or enabled Retrieval API pay-as-you-go consumption.
Pay-as-you-go requires administrator billing setup and at least one Microsoft
365 Copilot license in the tenant throughout use.
The native tool also requires eligible licensing or pay-as-you-go, Foundry User
access to the project and Read access to the SharePoint site. Its calls require
the user's delegated identity, not an application managed identity or service
principal.

## What is wired into Agent Application

Native product support does not imply an end-to-end accelerator integration:

- **Indexed source:** the template emits `indexName`, `siteUrl` and `tenantId`.
  The current documented source contract instead uses `connectionString`,
  `containerName`, `query` and `ingestionParameters`. Registration needs a
  reviewed template/API update plus source permissions and consent.
- **Remote source:** the connector recognizes
  `SHAREPOINT_REMOTE_ENABLED` and `SHAREPOINT_REMOTE_KNOWLEDGE_SOURCE_NAME`.
  The source must already exist and belong to the knowledge base. These keys
  do not create it or establish delegation.
- **Native tool:** the service connection and identity-passthrough contract
  need an explicit application integration. The remote-source settings do not
  attach this tool.

The accelerator defaults to Search API `2026-05-01-preview`. Current Microsoft
source recipes use `2026-08-01-preview`; a source extension needs compatible
registration, retrieve requests and response handling, not a version edit alone.
Platform provisioning can replace manual source references in its managed
knowledge base.

!!! warning "Hosted delegated-user boundary"
    The shipped hosted entrypoint supplies empty user context to retrieval.
    The connector cannot forward the delegated user token required for protected
    SharePoint retrieval through that path. UI sign-in and a service managed
    identity do not fill this gap. The native service capability needs a
    reviewed trusted-user integration before hosted Agent Application can use it.

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
