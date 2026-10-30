# Foundry IQ

A **knowledge source** describes searchable content. A **knowledge base** binds
one or more sources and controls retrieval. Foundry Agent Service can call that
knowledge base as a native tool, so the agent can ground answers in retrieved
content and return source references.

This page describes Foundry IQ and the Agent Application's integration limits.
Deployment follows the [Deploy full stack runbook](deploy-full-stack.md).

## Choose the retrieval backend

The orchestrator's runtime default for `RETRIEVAL_BACKEND` is `ai_search`.
The platform can supply `foundry_iq` for a native knowledge-base topology.
Empty or unknown runtime values fall back to `ai_search`, so read back the
effective setting rather than relying on a misspelled value. Restart after
changing this cached selection.

`ai_search` queries the configured index directly. `foundry_iq` calls a
knowledge base and combines its configured sources. The selector applies to
the shared knowledge-search connector and the MAF Lite, MAF Agent Service and
multimodal context providers. It does not reroute the
[NL2SQL strategy](nl2sql.md#direct-nl2sql-strategy) or replace callable
[MCP tools](agent-tools.md).
[Application settings](application-settings.md) describes how to change runtime
values. [Strategies & prompts](agent-strategies.md) describes hosting eligibility.

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
| `RETRIEVAL_BACKEND` | `foundry_iq` selects knowledge-base retrieval in this connector. It does not attach a native agent tool. |
| `RETRIEVAL_AUTH_MODE` | `native_search` carries the separately delegated Search credential into native permission enforcement. |
| `KNOWLEDGE_BASE_ENDPOINT` | Search service root, such as `https://<service>.search.windows.net`, not a Foundry project or retrieve URL. |
| `KNOWLEDGE_BASE_NAME` | Knowledge-base object name, not an index name. |
| `FOUNDRY_IQ_KNOWLEDGE_SOURCE_NAME` | Primary registered source name. |
| `FOUNDRY_IQ_PATTERN` and `FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND` | `azureBlob` for the default source, or matching `searchIndex` for an existing index. |
| `FOUNDRY_IQ_API_VERSION` | The source and connector contract defaults to `2026-05-01-preview`. |
| `KNOWLEDGE_BASE_CONNECTION_ID` | Provisioned project connection metadata, not a connector target selector. |

Current Microsoft source examples use contracts beyond the accelerator's
default API. Adopting a source requires compatibility across registration,
retrieve requests and response parsing, not an API-version edit alone.

## Delegated native retrieval

The supplied UI and hosted strategy integrate the user authorization path.
The UI obtains a delegated Search token through OBO and forwards it with
`x-client-search-token`. The hosted connector passes the raw token in
`x-ms-query-source-authorization`. The connector's workload credential
authenticates transport to Search, not the user's entitlement to documents.
This path needs no customer-written Toolbox integration.

Native permission filtering is enabled for the application index's user,
group and RBAC scope fields. Indexing must populate the appropriate metadata.
Turning on filtering cannot reconstruct missing ACLs. Conversation uploads
also require their conversation/uploader restrictions.

Source contracts differ. Work IQ uses a distinct app-audience assertion and
`x-ms-query-work-iq-source-authorization`, not the Search token. Indexed
SharePoint requires compatible permission-ingestion configuration. Fabric
sources require compatible preview APIs and user permissions. A source
registration or runtime connector alone does not establish that the complete
deployment combination is supported.

Tokens do not belong in prompts, chat history, recovery checkpoints or
user-supplied tool arguments. Required retrieval fails closed if credentials or
source authorization are unavailable.
[Application authentication](application-auth.md) describes consent and
allowed/denied-user acceptance.

## Generic MCP knowledge sources

Use this default-off preview to retrieve grounding from registered
`mcpServer` knowledge sources. It is not the callable `mcp` agent strategy and
does not create sources. Register each source on the selected knowledge base
first, with the same name, server and tools as the runtime metadata.

| Runtime setting | Default | Required choice |
| --- | --- | --- |
| `FOUNDRY_IQ_MCP_ENABLED` | `false` | Set `true` to enable conversational MCP planning. |
| `FOUNDRY_IQ_MCP_SOURCES_JSON` | `[]` | Supply a non-empty source array when enabled. |
| `FOUNDRY_IQ_API_VERSION` | `2026-05-01-preview` | This exact API contract is required for this MCP preview. |
| `FOUNDRY_IQ_MCP_REASONING_EFFORT` | `low` | `low` or `medium`. |
| `FOUNDRY_IQ_MCP_TRUSTED_HOSTS` | Empty | Exact hostname allowlist, required when enabled. |
| `FOUNDRY_IQ_MAX_RUNTIME_SECONDS` | `120` | Integer from `30` to `600`. |
| `FOUNDRY_IQ_MCP_LOG_TOOL_ARGUMENTS` | `false` | Leave off unless debug argument logging is approved. |

These settings belong in [Application settings](application-settings.md), not
in a chat request. The exact MCP API requirement differs from the remote
Work IQ and Fabric contracts. Do not combine incompatible source requirements
in one connector by changing only the API version.

For example, after registering a reviewed read-only source, configure
`FOUNDRY_IQ_MCP_TRUSTED_HOSTS=mcp.contoso.com` and the following source metadata.
The names and resource scope are illustrative, not provisioned resources.

```json
[
  {
    "name": "monitor-mcp",
    "description": "Read-only monitoring knowledge.",
    "serverURL": "https://mcp.contoso.com/mcp",
    "failOnError": true,
    "maxOutputDocuments": 5,
    "tools": [
      {
        "name": "query_logs",
        "outputParsing": {
          "kind": "json",
          "jsonParameters": {
            "documentsPath": "$.results[*]",
            "includeContext": true
          }
        },
        "inclusionMode": "reranked",
        "maxOutputTokens": 2048
      }
    ],
    "queryHeaders": [
      {
        "name": "Authorization",
        "valueFrom": {
          "kind": "managedIdentity",
          "scope": "api://monitor-mcp/.default"
        }
      }
    ]
  }
]
```

### Source limits and credentials

Each source needs a unique name, HTTPS server URL and non-empty tool list.
Tool names must be unique within the source. Each tool declares output parsing,
`inclusionMode` (`reranked` or `always`) and `maxOutputTokens` from `1` to `8192`.
Parsing kinds are `auto`, `none`, `json` and `split`.
`json` needs a `documentsPath` and optional boolean `includeContext`.
`split` supports page or sentence splitting, positive page length and page-count
limits, non-negative overlap smaller than page length, and a default language.
Do not mix parsing parameters across kinds or add unknown fields.
The [API reference](application-api.md) is the payload reference.

`failOnError=true` makes a reported source failure fail the request.
Choose `false` only when partial grounding is acceptable. Per-source
`maxOutputDocuments` accepts `1` to `50`. The separate
`FOUNDRY_IQ_MAX_OUTPUT_DOCUMENTS` can bound final grounding records.

Trusted hosts are bare hostnames, supplied as comma/newline-separated values
or a JSON array. Matching is exact after lowercasing and removing a trailing
dot, not wildcard or subdomain matching. Server URLs reject embedded credentials,
queries, fragments, IP literals, single-label names and reserved/local names
such as `localhost`, `.internal` or `.test`. This validation does not replace
DNS and network egress controls.

Each query header has a unique valid HTTP field name and `valueFrom` metadata.
Reserved and hop-by-hop headers such as `Host` and `Connection` are rejected.
Do not put literal tokens, API keys or credential values in the source JSON.

| `valueFrom.kind` | Configuration and access |
| --- | --- |
| `managedIdentity` | Explicit resource `scope`. Grant the workload identity access. The credential chain can use Azure CLI locally. |
| `obo` | Explicit target-resource `scope`. Uses the original incoming user assertion, backend OBO configuration and consent, not a reused Search token. |
| `keyVaultSecret` | `secretName` in `KEY_VAULT_URI`. Grant secret-read access and store the complete header value in the vault. |
| `none` | No scope or secret name. Omits that header rather than creating anonymous access to a protected source. |

Only `keyVaultSecret` accepts `secretName`, with `1` to `127` letters, digits or
hyphens. `scope` is forbidden for `keyVaultSecret` and `none`.
Missing credentials or failed delegation fail the request rather than
downgrading to `none`. The retrieve call references registered source names and
relays resolved source-specific query headers. It does not send server URLs or
tool definitions as registration instructions.

Normal telemetry omits tool arguments. Debug logging performs bounded redaction,
which cannot guarantee that arbitrary arguments are safe to export.
Use [Monitoring & audit](application-monitoring.md) for the logging policy.

<span id="apply-a-runtime-change-safely"></span>

## Ownership and connectivity

Platform Search setup reconciles named sources and knowledge bases from
`config/search/search.j2`. Later provisioning can replace manual additions to
those objects. Operator-owned sources and knowledge bases need distinct names.
Changes to platform-owned objects belong in reviewed templates.
Knowledge-base updates must preserve all intended source references.

Source administration, ingestion and retrieval use separate permissions:
the administrator manages knowledge objects. Search's ingestion identity reads
the source and calls extraction/embedding services. The retrieval identity
authenticates to Search. The end user's delegated identity authorizes protected
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
A missing-token failure calls for checking the compatible UI/runtime
configuration, downstream consent and supported header path, not anonymous
retrieval or broader managed-identity grants.

Configuration is cached in the running application. Approved changes require
the [Deploy full stack runbook](deploy-full-stack.md#redeploy-applications-only)
to start a new hosted version. Recovery restores the previous compatible image
and settings while retaining source documents and knowledge objects.
