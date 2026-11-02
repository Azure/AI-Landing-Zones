# Foundry IQ

A **knowledge source** describes searchable content. A **knowledge base** binds
one or more sources and controls retrieval. Foundry Agent Service can call that
knowledge base as a native tool, so the agent can ground answers in retrieved
content and return source references.

This page describes Foundry IQ and the Agent Application's integration limits.
Deployment follows the [full-stack deployment guide](deploy-full-stack.md).

<div class="runbook-diagram" markdown="1">

<div class="runbook-diagram__summary" markdown="1">

**What must be connected before an agent can use a knowledge base?**

1. Search owns the knowledge base and its registered sources.
2. The native Agent uses a project-connection MCP tool, not the direct Search
   connector. The provisioned Search connection is not that MCP connection.
3. Source ingestion, tool registration and end-user authorization are separate
   setup tasks. Test all three before admitting users.

</div>

[![A native Agent calls a reviewed MCP project connection to reach a Search knowledge base. Native Blob ingestion copies content into Search; an existing index keeps its own ingestion owner. Setup must replace the generated Search connection with a compatible MCP connection and verify user authorization.](../media/runbooks/foundry-iq.svg)](../media/runbooks/foundry-iq.svg){: .runbook-diagram__image aria-label="Open full-size Foundry IQ connection diagram"}

[Open full-size diagram](../media/runbooks/foundry-iq.svg){: .runbook-diagram__open}

</div>

<span id="choose-the-retrieval-backend"></span>

## What is shipped, and what you must connect

The default platform topology supplies `RETRIEVAL_BACKEND=foundry_iq`.
That selects Search knowledge-object provisioning. It does not enable a tool
in the native Agent or Workflow. `FOUNDRY_IQ_ENABLED` defaults to `false`.

Choosing a retrieval backend is not enabling its native tool. The native
capability flags default to off. Follow [Tools & MCP](agent-tools.md) and the
[native application settings](application-settings.md#native-application-contract)
to select the capability with its required bindings, then verify a real
source-backed answer and a denied-user case.

The native runtime registers Foundry IQ using
`FoundryChatClient.get_mcp_tool(project_connection_id=KNOWLEDGE_BASE_CONNECTION_ID)`.
It does not call `connectors/foundry_iq.py`. Selecting `RETRIEVAL_BACKEND`
does not change that native registration or reroute the
[MCP NL2SQL tools](nl2sql.md) or replace callable
[MCP tools](agent-tools.md).

[Application settings](application-settings.md) describes how to change runtime
values. [Agents & prompts](agent-strategies.md) describes application selection
independently of the host and its tools.

The NL2SQL tools on Agent App MCP Server store approved SQL metadata and vectors
in application Cosmos. This toolset does not require Search.
Enabling the server does not enable Foundry IQ or alter this knowledge base's sources.

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
disabled by default and is not needed for this source.
[Ingestion](ingestion.md) explains native source ingestion, private-input boundaries
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

The accelerator provisions an Entra ID-authenticated `CognitiveSearch` project
connection and publishes its ID as `KNOWLEDGE_BASE_CONNECTION_ID`.
**The native runtime consumes that ID as an MCP project connection.**
A `CognitiveSearch` connection is not the `RemoteTool` connection required by
the native-tool procedure. Default provisioning alone therefore does not
establish a working Foundry IQ MCP tool or source-specific user delegation.

The application owner must create a compatible MCP project connection, bind
the reviewed knowledge base and configure its authentication. Keep the
connection under separate ownership and preserve its binding across later
provisioning. Do not enable protected corporate sources until the complete
native invocation and source-authorization path passes allow/deny tests.

<span id="3-configure-application-consumption"></span>
<span id="3-configure-agent-application-consumption"></span>

The [Deployment settings](configuration.md) describe knowledge-object inputs.
App Configuration uses label `agent-lz`. Distinguish native application settings
from settings used by the separately available direct connector:

| Setting | Consumer and meaning |
| --- | --- |
| `FOUNDRY_IQ_ENABLED` | Native runtime: enables MCP tool registration; structural, requires redeployment. |
| `KNOWLEDGE_BASE_CONNECTION_ID` | Native runtime: actual compatible MCP project connection ID, not merely the generated Search connection. |
| `RETRIEVAL_BACKEND` | Provisioning: `foundry_iq` selects knowledge-base setup. The direct connector also reads this selector; native tool composition does not. |
| `RETRIEVAL_AUTH_MODE` | Application authorization policy; setting `native_search` alone does not implement source delegation for a native MCP connection. |
| `KNOWLEDGE_BASE_ENDPOINT` | Direct connector: Search service root, such as `https://<service>.search.windows.net`, not a Foundry project or retrieve URL. |
| `KNOWLEDGE_BASE_NAME` | Provisioning/direct connector: knowledge-base object name, not an index name. Native configuration also loads the name. |
| `FOUNDRY_IQ_KNOWLEDGE_SOURCE_NAME` | Primary registered source name. |
| `FOUNDRY_IQ_PATTERN` and `FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND` | `azureBlob` for the default source, or matching `searchIndex` for an existing index. |
| `FOUNDRY_IQ_API_VERSION` | The source and connector contract defaults to `2026-05-01-preview`. |

Current Microsoft source examples use contracts beyond the accelerator's
default API. Adopting a source requires compatibility across registration,
retrieve requests and response parsing, not an API-version edit alone.

## How to connect a knowledge base

### 1. Prepare ownership and content before provision

Initialize through the [canonical deployment guide](deploy-full-stack.md).
Identify the Search administrator, content owner, Entra consent administrator
and application publisher. The Search administrator needs knowledge-object
management permission; Search Service Contributor is the keyless management
role. Ingestion identities need source/model access independently of the
querying user's document permissions.

Keep the native Blob defaults unless your content needs another path.
For an existing populated index, set the mapped deployment inputs
`FOUNDRY_IQ_PATTERN=searchIndex` and
`FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND=searchIndex`; set
`FOUNDRY_IQ_SEARCH_INDEX_NAME` to that index. Confirm schema, semantic
configuration, embeddings and ACL metadata before registering it.

### 2. Provision sources, then configure the native connection

1. Run the selected guide's `azd provision` procedure after source inputs and
   grants are ready.
2. Inspect the knowledge base's source references and, for indexed sources,
   successful indexing and permission metadata.

Source setup is not a runtime refresh operation. Provisioning reconciles
platform-owned names and can overwrite manual edits.

Follow Microsoft's [native connection procedure](https://learn.microsoft.com/azure/foundry/agents/how-to/foundry-iq-connect)
to create the compatible `RemoteTool` project connection. Configure the
source's required user authorization there or implement the missing
application identity integration. A project connection or service role must
not turn a user-protected corpus into application-wide access.

### 3. Enable the capability and publish the application

Follow [Configure an agent capability](application-settings.md#configure-an-agent-capability).
In root `main.parameters.json`, merge this entry into
`parameters.additionalAppConfigurationSettings.value`, retaining its host/mode
entries and all other required settings:

```json
{ "name": "FOUNDRY_IQ_ENABLED", "value": "true", "label": "agent-lz" }
```

There is no declared `azd env set FOUNDRY_IQ_ENABLED` mapping.
Run `azd provision` again to publish the capability declaration. This can
restore the generated Search connection ID. After that provision, configure
`KNOWLEDGE_BASE_CONNECTION_ID` under `agent-lz` to the actual compatible
MCP connection using the [nonsecret-key procedure](application-settings.md#edit-an-existing-nonsecret-key).

This is an explicit application-owned binding override; later provisioning
can restore the generated Search ID. Recheck it after every provision.

Deploy/redeploy the affected native publication after the binding is ready.
Capability composition is structural: a provider refresh is not enough to
enable it. Confirm the effective ID, a real tool invocation and the
allow/deny cases below. A successful deployment is not proof of grounding.

<span id="delegated-native-retrieval"></span>

## User authorization boundaries

Protected retrieval requires a source-compatible user credential, separately
from workload authentication. The native UI delegates to the Hosted
Responses endpoint; the native runtime forwards a trusted Foundry call ID.
It does not invoke the direct connector or forward that connector's
`x-client-search-token`/Work IQ assertion headers. Do not assume those headers
are wired into the native MCP tool.

For an application explicitly integrating the direct connector, a delegated
Search token is sent raw as `x-ms-query-source-authorization`; the connector's
workload credential authenticates Search transport only. That recipe needs
trusted credential acquisition/forwarding and invocation wiring, not credentials
as model arguments. See [Sign-in & access](application-auth.md).

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
user-supplied tool arguments. Required retrieval must fail closed if credentials or
source authorization are unavailable; verify this in the selected native
connection or custom integration.
[Application authentication](application-auth.md) describes consent and
allowed/denied-user acceptance.

## Shared-source permission metadata

Ingestion permission metadata records access information alongside indexed
content. `rbacScope` records Azure RBAC scopes; `sensitivityLabels` records
information-protection labels. Retrieval must still enforce the applicable
permissions for the caller.

`FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS` controls the configured source's
ingestion permission metadata. Omission or an actual null value retains the protected default
`["rbacScope"]`. An explicit JSON empty array, `[]`, is an opt-in for a
deliberately shared source **when native Blob ingestion is active**.
An empty array is distinct from an omitted setting.

For active native Blob ingestion, the shared-source empty list is accepted
with `RETRIEVAL_BACKEND=foundry_iq`, `FOUNDRY_IQ_PATTERN=azureBlob`,
`azureBlob` knowledge source kind
and a recognized non-ADLS source. Active ADLS Gen2, mismatched source
configuration and ambiguous ADLS configuration fail closed. Nonempty Blob
permission lists accept only `rbacScope` and `sensitivityLabels`.

The infrastructure also publishes `[]` as **unused metadata** for inactive
native Blob ingestion: `ai_search` with any pattern, or `foundry_iq` with
the `searchIndex` pattern. Those empty lists remain accepted because no
native Blob knowledge source is rendered. They are not shared-source opt-ins
and do not change the independently populated index's authorization.

Malformed JSON, a single value instead of a JSON list, the text `null`,
invalid list entries and unsupported permission names fail with actionable
diagnostics.
Invalid input fails closed rather than silently removing protection.
An actual null and the text `null` are different inputs.

For active native Blob ingestion, `[]` is appropriate only when policy permits
the source's documents to be shared without that ingestion permission metadata.
It does not grant document access by
itself or change other sources, application authentication, Entra ID/OBO,
retrieval authorization, RBAC or private network restrictions.

It is not a
workaround for an authentication or private-link failure. Its use requires
audience review and allow/deny tests with real user identities before activation.

Restoring `["rbacScope"]` requires source reconfiguration and verification
of source/index permission metadata, including already-ingested documents.
Allowed and denied users both need validation before access resumes. The
[Deploy full stack](deploy-full-stack.md) guide covers reconfiguration.
See also
[Private native Blob ingestion](configuration.md#search-shared-private-links).

## Generic MCP knowledge sources

The direct connector includes a default-off preview to retrieve grounding from registered
`mcpServer` knowledge sources. This is distinct from callable MCP tools and
from deploying Agent App MCP Server. The native runtime does not load these
connector settings. Using this planner in your application requires explicit
connector/invocation integration; the settings below are not native Agent
tool switches. They do not create sources.

Register each source on the selected knowledge base
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
before sensitive ingestion. See [Network design](network-isolation.md).

<span id="4-verify-and-recover"></span>

## Acceptance and recovery

Acceptance includes successful source indexing where applicable, a known-answer
query with the expected document reference, and separate allowed/denied-user
tests. A denied result must exclude the restricted document and its citation.
A missing-token failure calls for checking the compatible UI/runtime
configuration, downstream consent and supported header path, not anonymous
retrieval or broader managed-identity grants.

Configuration is cached in the running application. Approved changes require
the [full-stack deployment guide](deploy-full-stack.md#redeploy-applications-only)
to start a new hosted version. Recovery restores the previous compatible image
and settings while retaining source documents and knowledge objects.
