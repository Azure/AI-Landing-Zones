<span id="fabric-data"></span>

# Fabric IQ

Fabric grounding queries data where it lives rather than ingesting a copy into
a landing-zone index. A Fabric data agent answers analytical questions over
its configured data, including Power BI semantic models. A Fabric IQ ontology
binds business entities and relationships to data.

This page explains the native knowledge-source options and integration gaps.
Deployment procedures are in the
[Deploy full stack runbook](deploy-full-stack.md).

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
Read permission on the model; Build permission is not required for that
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

The [Deployment settings](configuration.md) register sources and knowledge-base
references in Search. They do not create Fabric items, grant model access or
deliver user tokens. Runtime selects sources by enabled flag and name.
Provisioning can overwrite manual edits to platform-owned objects.

<span id="3-plan-the-hosted-extension"></span>

## Integration work still required

**Hosted Agent Application does not have a configuration-only Fabric path.**
For a native data-agent source, the following boundaries need coordinated work:

| Boundary | Product contract and accelerator gap |
| --- | --- |
| Delegated identity | Fabric uses a Search-audience user token in `x-ms-query-source-authorization`, separately from Search service authentication. The hosted entrypoint supplies empty user context and cannot forward that token through the retrieval strategy. |
| Retrieval reasoning | Fabric data-agent sources require `low` or `medium`. The accelerator's native-source knowledge-base template emits `minimal` and no planning model. There is no native-branch environment override that fixes this. |
| Response parsing | The documented data-agent response uses `sourceData.fabricAnswer` and `fabricEmbeddedResources`. The connector's data-agent parser expects `dataAgentAnswer` and `dataAgentRawData`. Its ontology fallback can read `fabricAnswer`, but misclassifies the source and does not handle the embedded resources. |
| API compatibility | Source setup and the connector default to `2026-05-01-preview`. Current Microsoft examples use `2026-08-01-preview`; registration, retrieve requests and response parsing need validation together. |

The [official data-agent source contract](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-fabric-data-agent#query-a-knowledge-base)
defines the token audience and response fields. Source registration alone
cannot resolve these gaps. A reviewed template change needs supported reasoning
and model configuration, and a reviewed application integration needs trusted
user delegation and compatible parsing.

An ontology remains a separate source contract, not a substitute data-agent
identifier or parser. It also requires `low` or `medium` reasoning and validated
user delegation through the hosted boundary.
[Foundry IQ](foundry-iq.md) explains how knowledge bases relate
to Foundry Agent Service tools; the
[custom application runbook](build-your-own-app.md) covers delivery of reviewed
application changes.

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
[Deploy full stack runbook](deploy-full-stack.md#redeploy-applications-only).
