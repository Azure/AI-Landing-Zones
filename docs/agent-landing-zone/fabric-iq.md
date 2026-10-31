<span id="fabric-data"></span>

# Fabric IQ

Fabric grounding queries data where it lives rather than ingesting a copy into
a landing-zone index. A Fabric data agent answers analytical questions over
its configured data, including Power BI semantic models. A Fabric IQ ontology
binds business entities and relationships to data.

This page explains the integrated native knowledge-source options and their
authorization requirements.
Deployment procedures are in the
[full-stack deployment guide](deploy-full-stack.md).

For direct database connections, use the separate
[NL2SQL strategy](nl2sql.md#direct-nl2sql-strategy). A Fabric SQL endpoint
configured for that strategy is not a `fabricDataAgent` source, and enabling
the strategy does not publish a Fabric data agent.

<span id="choose-the-connection"></span>

## Data agents and ontologies are different sources

| Foundry IQ source | Fabric object |
| --- | --- |
| `fabricDataAgent` | A published data agent, identified by workspace ID and data agent item ID. |
| `fabricOntology` | An ontology, identified by workspace ID and ontology item ID. |

A semantic model ID is neither a data agent ID nor an ontology ID. These
remote sources query Fabric at retrieval time and do not need Agent App
Ingestion. Both knowledge-source integrations are preview.
Microsoft documents [data agent sources](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-fabric-data-agent)
and [ontology sources](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-fabric-ontology)
separately.

<span id="1-prepare-and-verify-the-fabric-agent"></span>

## Fabric access and governance

A data agent needs a supported capacity, tenant settings, configured data
sources and publication. Consumers need access to both the agent and its
underlying data. For the semantic-model data-agent path, Microsoft specifies
Read permission on the model. Build permission is not required for that
interaction. Authoring permissions are separate.
The [Fabric data agent guide](https://learn.microsoft.com/fabric/data-science/how-to-create-data-agent)
describes the Fabric-side procedure.

Search and the Fabric workspace must share an Entra tenant. Data permissions,
model row-level security and regional data-handling requirements still apply.
Private Azure networking does not configure Fabric workspace networking.
Preview and cross-service data movement require governance review.

<span id="2-understand-the-shipped-registration-contract"></span>
<span id="2-understand-source-registration"></span>

## What the accelerator registers

`FABRIC_DATA_AGENT_ENABLED`, `FABRIC_DATA_AGENT_KNOWLEDGE_SOURCE_NAME`,
`FABRIC_DATA_AGENT_WORKSPACE_ID` and `FABRIC_DATA_AGENT_DATA_AGENT_ID` describe
data-agent source registration. The separate ontology inputs are
`FABRIC_IQ_ENABLED`, `FABRIC_IQ_KNOWLEDGE_SOURCE_NAME`,
`FABRIC_IQ_WORKSPACE_ID` and `FABRIC_IQ_ONTOLOGY_ID`.

Both source flags default to `false` and both source names default to empty.
Select `RETRIEVAL_BACKEND=foundry_iq` for the application paths that use these
sources. The names must identify sources registered on the selected knowledge
base. [Application settings](application-settings.md) covers effective runtime
values. Changing a source binding is not just a prompt edit.

The [Deployment settings](configuration.md) register sources and knowledge-base
references in Search. They do not create Fabric items or grant model access.
The integrated UI obtains the user's delegated Search token. The hosted runtime
forwards it to Search for source authorization. Enabling a source requires its
configured knowledge-base binding. A missing binding fails provisioning instead
of silently omitting that source. Provisioning can overwrite manual edits to
platform-owned objects.

<span id="3-plan-the-hosted-extension"></span>
<span id="integration-work-still-required"></span>

## Integrated hosted retrieval

The built-in hosted `maf_lite` path supports native Fabric sources without
customer-written identity or response-parsing code. Configure the source and
its administrator prerequisites, including `FOUNDRY_IQ_API_VERSION=2026-08-01-preview`:

| Boundary | Integrated behavior |
| --- | --- |
| Delegated identity | The UI obtains a separate Search-audience token from the authenticated user's assertion. The hosted connector forwards the raw token in `x-ms-query-source-authorization`. Its workload token authenticates only Search transport. Fabric user permissions and consent still apply. |
| Retrieval reasoning | Fabric sources require `low` or `medium`. Enabling a bound Fabric source configures `low` reasoning and the configured planning model. Blob-only retrieval retains `minimal`. |
| Response parsing | The connector reads `sourceData.fabricAnswer` and textual `fabricEmbeddedResources`, preserving the Fabric source identity in grounding and citations. |
| API compatibility | Fabric source setup and retrieval require the explicit `2026-08-01-preview` contract. The default Blob API is not silently changed. |

The [official data-agent source contract](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-fabric-data-agent#query-a-knowledge-base)
defines the token audience and response fields. Missing delegation, incompatible
API settings or source failures stop required retrieval. The connector does
not retry without the user credential or substitute application-only access.

An ontology remains a separate source contract, not a substitute data-agent
identifier. It uses the same explicit API, reasoning and delegated Search route.
[Foundry IQ](foundry-iq.md) explains how knowledge bases relate
to Foundry Agent Service tools. [Application access](application-auth.md)
describes sign-in, consent and authentication recovery.

Tokens remain server-side, outside prompts and user-supplied tool arguments.
Authorization comes from validated caller context, not model-provided user IDs
or group lists.

<span id="verify-and-recover"></span>

## Acceptance and recovery

A known-answer query must first succeed in the published Fabric agent as the
intended consumer. End-to-end acceptance then includes the correct source
reference, expected analytical result and any returned structured resources.
It also includes a user denied model access, users with different row-level
security and a missing-token test.

Broader managed-identity grants cannot repair missing delegation. Recovery
restores the previous application and settings, removes only the pilot source
reference and retains Fabric items or Search objects still used elsewhere.
Approved application changes start a new hosted version through the
[full-stack deployment guide](deploy-full-stack.md#redeploy-applications-only).
