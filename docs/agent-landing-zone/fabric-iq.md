<span id="fabric-data"></span>

# Fabric IQ

Fabric grounding queries data where it lives. A Fabric data agent answers
analytical questions over its configured data, including Power BI semantic
models. A Fabric IQ ontology binds business entities and relationships to data.
Neither route needs a copy of the business dataset in a landing-zone index.

The platform includes templates for both knowledge-source types.
**Source registration is shipped; end-to-end Fabric delegation in the native
reference application is not established by those settings.** This guide
identifies what administrators configure and what the application owner must
connect and test.

<div class="runbook-diagram" markdown="1">

<div class="runbook-diagram__summary" markdown="1">

**Who answers the analytical question, and who authorizes it?**

1. Choose a published Fabric data agent or an ontology; their item IDs are
   different.
2. A Search knowledge base calls the selected remote source with compatible
   delegated user authorization.
3. Fabric owns data access, analytical execution and applicable row-level
   security. Application-managed SQL tools are a separate route.

</div>

[![Fabric integration recipe: a Search knowledge base calls either a published Fabric data agent or an ontology. A compatible user-delegation path must be implemented or configured; Fabric enforces underlying data permissions. The reference source flags register objects, not a turnkey application connection.](../media/runbooks/fabric-iq.svg?v=e4ef1fa6f079)](../media/runbooks/fabric-iq.svg?v=e4ef1fa6f079){: .runbook-diagram__image aria-label="Open full-size Fabric source choice diagram"}

[Open full-size diagram](../media/runbooks/fabric-iq.svg?v=e4ef1fa6f079){: .runbook-diagram__open}

</div>

<span id="choose-the-connection"></span>

## Choose the source

| Knowledge-source kind | Fabric object and binding |
| --- | --- |
| `fabricDataAgent` | Published data agent: workspace ID plus data-agent item ID. |
| `fabricOntology` | Ontology: workspace ID plus ontology item ID. |

A semantic model ID is neither item ID. Both integrations are preview.
Microsoft documents [data-agent sources](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-fabric-data-agent)
and [ontology sources](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-fabric-ontology)
separately. Retrieved answers still reach the agent/model even though the
source corpus is not indexed locally.

For Azure SQL or SQL Server, the separate [NL2SQL toolset](nl2sql.md) on
Agent App MCP Server owns its source/vector metadata catalog and SQL
connection. It does not support Fabric SQL endpoints, semantic models or DAX.
Enabling that server does not publish a Fabric item or install a Fabric tool.

## How to prepare a Fabric pilot

<span id="1-prepare-and-verify-the-fabric-agent"></span>
<span id="fabric-access-and-governance"></span>

### 1. Prepare and test Fabric before source registration

Initialize through the [canonical deployment guide](deploy-full-stack.md).
Have the Fabric administrator approve capacity, tenant settings and regional
data handling. The Fabric author configures and publishes the data agent or
ontology. The data owner grants the intended consumers access to the item
and its underlying data.

For the semantic-model data-agent path, Microsoft specifies Read permission
on the model; Build permission is not required for that interaction.
Authoring permissions are separate. Search and the Fabric workspace must
share an Entra tenant. Data permissions and model row-level security still
apply. See [Create a Fabric data agent](https://learn.microsoft.com/fabric/data-science/how-to-create-data-agent).

First run a known-answer query directly in Fabric as the intended consumer.
Also test a consumer without model access and two users with different
row-level security. Private Azure networking does not configure Fabric
workspace networking or grant access.

<span id="2-understand-the-shipped-registration-contract"></span>
<span id="2-understand-source-registration"></span>
<span id="what-the-accelerator-registers"></span>

### 2. Declare exactly one pilot source before provision

In root `main.parameters.json`, merge the chosen source's entries into
`parameters.additionalAppConfigurationSettings.value`. Preserve existing
host/mode entries. For a **data agent**, replace the illustrative IDs:

```json
[
  { "name": "FABRIC_DATA_AGENT_ENABLED", "value": "true", "label": "agent-lz" },
  { "name": "FABRIC_DATA_AGENT_KNOWLEDGE_SOURCE_NAME", "value": "fabric-sales-pilot", "label": "agent-lz" },
  { "name": "FABRIC_DATA_AGENT_WORKSPACE_ID", "value": "<workspace-id>", "label": "agent-lz" },
  { "name": "FABRIC_DATA_AGENT_DATA_AGENT_ID", "value": "<published-data-agent-item-id>", "label": "agent-lz" }
]
```

For an **ontology**, use these entries instead:

```json
[
  { "name": "FABRIC_IQ_ENABLED", "value": "true", "label": "agent-lz" },
  { "name": "FABRIC_IQ_KNOWLEDGE_SOURCE_NAME", "value": "fabric-ontology-pilot", "label": "agent-lz" },
  { "name": "FABRIC_IQ_WORKSPACE_ID", "value": "<workspace-id>", "label": "agent-lz" },
  { "name": "FABRIC_IQ_ONTOLOGY_ID", "value": "<ontology-item-id>", "label": "agent-lz" }
]
```

Both flags default to `false`; names and bindings default to empty.
These keys have no declared same-named environment mapping. Use explicit
additional settings, not `azd env set FABRIC_IQ_ENABLED` alone.
See [Application settings](application-settings.md) for publication and ownership.

Set the mapped Search API input and retain the Foundry IQ backend:

```bash
azd env set RETRIEVAL_BACKEND foundry_iq
azd env set FOUNDRY_IQ_API_VERSION "2026-08-01-preview"
```

### 3. Provision and verify the source binding

1. Run `azd provision` through the selected deployment guide after Fabric
   publication, sharing and the source declaration are ready.
2. In Search, inspect the registered kind, workspace/item IDs and
   knowledge-base references against the published Fabric item.

Both providers publish additional settings under `agent-lz`; Search setup
consumes them to register the source and knowledge-base reference.
Missing enabled-source bindings or an incompatible API fail setup instead of
silently omitting the source.

Fabric sources require `low` or `medium` retrieval reasoning. The template
selects `low` and the configured planning model for a bound Fabric source;
Blob-only retrieval retains `minimal`. API-version edits alone do not create
Fabric items, consent or user access.

Provisioning reconciles platform-owned knowledge objects and can replace manual
additions. Use reviewed template changes for those objects, or separate names
and ownership for operator-managed objects. Keep all intended source references.

<span id="3-plan-the-hosted-extension"></span>
<span id="integration-work-still-required"></span>
<span id="integrated-hosted-retrieval"></span>

### 4. Connect an authorized application retrieval path

The native runtime registers a project-connection MCP tool; it does not load
`FABRIC_*` keys or invoke the available direct Foundry IQ connector.
The generated `CognitiveSearch` connection is not the native `RemoteTool`
MCP connection. Follow [Foundry IQ connection setup](foundry-iq.md#how-to-connect-a-knowledge-base)
and the [official source contract](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-fabric-data-agent#query-a-knowledge-base)
to configure and prove the selected path.

For a custom direct-connector integration, implement trusted acquisition and
forwarding of the user's delegated **Search-audience** token. The connector
sends it raw in `x-ms-query-source-authorization`, separately from its workload
authentication to Search. Do not exchange it again in the container, replace
it with managed identity, or infer authorization from model-provided user/group
fields.

The direct connector parses `sourceData.fabricAnswer` and textual
`fabricEmbeddedResources`, retaining Fabric source identity in grounding.
Reusing that code still requires application invocation and identity wiring.
A native MCP connection instead needs its own verified service contract.
Neither path implies an interactive chart/table viewer.

Publish/deploy after the connection, permissions and bindings are ready.
Capability, endpoint and identity changes require matching setup and
redeployment, not a functional refresh alone. Keep tokens out of prompts,
history, checkpoints and tool arguments. [Sign-in & access](application-auth.md)
describes consent and failure recovery.

<span id="acceptance-and-recovery"></span>

## Verify and recover

Compare a fixed analytical result directly in Fabric and through the
application, using the same intended consumer, business definitions and date
boundaries. Verify actual source activity and source references, not just
container health. Check a user without model access, different row-level
security outcomes and missing/expired-token rejection.

Required-source failure must stop grounding, not skip the source, invent an
empty success or retry as the workload. Broader managed-identity grants cannot
repair missing delegation. Recovery restores the prior compatible publication
and settings, removes only the pilot source reference and retains Fabric
items and Search objects still used elsewhere.
