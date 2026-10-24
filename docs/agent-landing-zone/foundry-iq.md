# Foundry IQ

A **knowledge source** describes searchable content. A **knowledge base** binds
one or more sources and controls retrieval. Foundry Agent Service can call that
knowledge base as a native tool, so the agent can ground answers in retrieved
content and return source references.

This page describes Foundry IQ and the Agent Application's integration limits.
Deployment follows the [Deploy full stack runbook](deploy-full-stack.md).

<span id="before-you-start"></span>
<span id="1-choose-who-manages-the-source"></span>

## Managed and remote sources

Indexed sources copy content into Search for retrieval. Remote sources query
their service at request time, without copying the source corpus into a local
index. Both can return content to the agent and model.

<span id="default-blob-source"></span>

The accelerator defaults to a native Blob source, container `documents`,
standard content extraction and ingestion permission options `["rbacScope"]`.
Search manages the generated indexing assets. Optional Agent App Ingestion is
disabled by default for new environments and is not needed for this source.
[Ingestion](ingestion.md) explains native source ingestion, conversation uploads
and custom processing.

An existing Search index can be registered as a `searchIndex` knowledge source.
The pipeline that owns that index remains responsible for its content, schema
and permission metadata. Registering it does not populate or authorize it.
Microsoft documents [Blob sources](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-blob)
and [Search index sources](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-search-index)
separately.

[SharePoint](sharepoint.md), [Work IQ](work-iq.md) and [Fabric IQ](fabric-iq.md)
describe additional native sources, including previews, and the work needed
to integrate them with Agent Application.

<span id="2-connect-existing-content-or-add-a-source"></span>

## Native tools and the accelerator boundary

Microsoft's [Foundry Agent Service connection guide](https://learn.microsoft.com/azure/foundry/agents/how-to/foundry-iq-connect)
connects a knowledge base through its MCP endpoint and a Foundry `RemoteTool`
project connection. The connection belongs to the agent's native tool definition.

The accelerator also provisions a Microsoft Entra ID-authenticated `CognitiveSearch` project
connection and publishes `KNOWLEDGE_BASE_CONNECTION_ID`. **The shipped retrieval
connector does not consume that ID.** It calls the Search endpoint and knowledge
base name directly. A provisioned connection alone does not attach a native tool
or establish user delegation in the hosted application. A `CognitiveSearch`
connection is not the `RemoteTool` connection in the native-tool procedure.

<span id="3-configure-application-consumption"></span>
<span id="3-configure-agent-application-consumption"></span>

The relevant [Deployment settings](configuration.md) describe distinct objects.
The connector reads runtime values from App Configuration with label `agent-lz`.

| Setting | Meaning in the shipped connector |
| --- | --- |
| `RETRIEVAL_BACKEND` | `foundry_iq` selects knowledge-base retrieval in this connector; it does not attach a native agent tool. |
| `KNOWLEDGE_BASE_ENDPOINT` | Search service root, such as `https://<service>.search.windows.net`, not a Foundry project or retrieve URL. |
| `KNOWLEDGE_BASE_NAME` | Knowledge-base object name, not an index name. |
| `FOUNDRY_IQ_KNOWLEDGE_SOURCE_NAME` | Primary registered source name. |
| `FOUNDRY_IQ_PATTERN` and `FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND` | `azureBlob` for the default source, or matching `searchIndex` for an existing index. |
| `FOUNDRY_IQ_API_VERSION` | The source and connector contract defaults to `2026-05-01-preview`. |
| `KNOWLEDGE_BASE_CONNECTION_ID` | Provisioned project connection metadata, not a connector target selector. |

Current Microsoft source examples use contracts beyond the accelerator's
default API. Adopting a source requires compatibility across registration,
retrieve requests and response parsing, not an API-version edit alone.

!!! warning "Hosted user authorization is not wired end to end"
    The shipped hosted entrypoint supplies empty user context to the retrieval
    strategy. It does not forward the delegated user token required by the
    connector's OBO path. Authenticated retrieval fails closed without that
    token. Native service support and UI sign-in do not resolve this boundary.
    Protected retrieval requires a reviewed integration that carries validated
    per-user context from invocation to the selected retrieval tool.

That integration must retain Foundry's trusted call context, service
authentication and each source's permission enforcement. Tokens do not belong
in prompts, chat history or user-supplied tool arguments.
[Application authentication](application-auth.md) and the
[custom application runbook](build-your-own-app.md) cover the surrounding
application work.

<span id="apply-a-runtime-change-safely"></span>

## Ownership and connectivity

Platform Search setup reconciles named sources and knowledge bases from
`config/search/search.j2`. Later provisioning can replace manual additions to
those objects. Operator-owned sources and knowledge bases need distinct names;
changes to platform-owned objects belong in reviewed templates.
Knowledge-base updates must preserve all intended source references.

Source administration, ingestion and retrieval use separate permissions:
the administrator manages knowledge objects; Search's ingestion identity reads
the source and calls extraction/embedding services; the retrieval identity
authenticates to Search; the end user's delegated identity authorizes protected
content. A service role is not a substitute for user authorization.

Private deployments need both runtime-to-Search access and Search-to-source/model
connectivity. The platform attempts to set generated Blob indexers to private
execution, but skips that update if an indexer does not yet exist.
Generated indexer state and shared private-link approvals still need validation
before sensitive ingestion. See [Network isolation](network-isolation.md).

<span id="4-verify-and-recover"></span>

## Acceptance and recovery

Acceptance includes successful source indexing where applicable, a known-answer
query with the expected document reference, and separate allowed/denied-user
tests. A denied result must exclude the restricted document and its citation.
A missing-token failure calls for identity integration work, not anonymous
retrieval or broader managed-identity grants.

Configuration is cached in the running application. Approved changes require
the [Deploy full stack runbook](deploy-full-stack.md#redeploy-applications-only)
to start a new hosted version. Recovery restores the previous compatible image
and settings while retaining source documents and knowledge objects.
