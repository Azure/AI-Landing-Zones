# Ask questions about SQL data

**Structured Query Language (SQL)** queries and changes database tables.
This integration permits only read-only queries.

Structured-data grounding can connect a Fabric data agent to a Foundry IQ
knowledge base. Agent Application supplies connector code, not a complete
hosted SQL integration. Delegated identity and response compatibility require
additional validation before protected data can be exposed.
This is a concept page; deployment follows the
[Deploy full stack runbook](deploy-full-stack.md).

<span id="choose-the-supported-route"></span>

## Structured-data grounding

Fabric warehouses and lakehouses store analytical data. A Fabric data agent
generates and executes read-only SQL over their tables.
A Power BI semantic model uses Data Analysis Expressions (DAX).
Fabric owns schema context and query execution; the hosted orchestrator consumes
results from the knowledge base.

The default hosted application does not execute a direct
natural-language-to-SQL (NL2SQL) plugin. A direct SQL tool is a custom application
extension described under [Agent tools](agent-tools.md), not a runtime switch
that supplies this feature.

<span id="prerequisites"></span>

## Fabric source contract

The Fabric data agent must be published and shared with the intended users,
who also need permission to its underlying data. The Search service and Fabric
workspace use the same Entra tenant. Supported capacity, tenant settings and
network reachability are source requirements.
[Fabric data agent requirements](https://learn.microsoft.com/fabric/data-science/concept-data-agent)
and the [knowledge-source contract](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-fabric-data-agent)
describe service limits.

The Foundry IQ Fabric Data Agent source is a preview integration.
Its binding is a `fabricDataAgent` knowledge source with workspace and
data-agent item IDs. `FABRIC_DATA_AGENT_ENABLED` and
`FABRIC_DATA_AGENT_KNOWLEDGE_SOURCE_NAME` identify this route.
`FABRIC_IQ_ENABLED` identifies the separate ontology route.
The source supports `low` or `medium` retrieval reasoning effort, not `minimal`.
[Fabric integration](fabric-iq.md) describes the bindings and
[Deployment settings](configuration.md) identifies setting ownership.

### Identity and API boundaries

The connector needs service authentication and a separate Search-audience
delegated user token for remote-source authorization. The supplied hosted
entry point provides neither a user bearer nor authenticated user context to
default retrieval.

Required-user retrieval can fail before the source is
called; the remote-source connector itself skips this source when its
delegated token is absent. UI sign-in and Foundry invocation do not close that gap.
[Agent Application access](application-auth.md) explains the required
authenticated integration.

The supplied parser expects `dataAgentAnswer` and `dataAgentRawData`.
The platform and orchestrator pin `2026-05-01-preview`. The service contract
also documents `fabricAnswer` and `fabricEmbeddedResources` with
`2026-08-01-preview`. The parser's separate ontology branch can read
`fabricAnswer`, but does not handle `fabricEmbeddedResources` and classifies
that answer as ontology content. Compatibility requires a validated API,
parser and response combination, including table/chart handling. Changing
the API setting alone does not implement that compatibility.

<span id="run-a-read-only-pilot"></span>

## Validation boundary

A meaningful pilot compares a fixed, known aggregate from an approved table
with the same question in Fabric and in the hosted application. The published
agent's selected tables, business definition, date boundaries and permissions
all affect the result.
[Creating a Fabric data agent](https://learn.microsoft.com/fabric/data-science/how-to-create-data-agent)
is a separate service procedure, not evidence that hosted integration works.

Required evidence includes activity from the intended knowledge source,
correctly parsed results and denial for a user without source access.
That validation depends on resolving the identity and API boundaries first.
Read-only execution prevents writes; it does not itself authorize a caller
or guarantee a correct answer.

<span id="diagnose-or-undo"></span>

## Failure boundaries

A Fabric answer missing from chat can indicate skipped delegated retrieval,
an incorrect binding or incompatible response fields. An incorrect aggregate
can instead reflect source schema or business definitions.
Knowledge-base source references and provisioning inputs share a lifecycle;
removing a pilot binding does not require deleting tables or other knowledge sources.

## Need a direct SQL connection?

A custom Foundry tool needs a service that enforces caller authorization,
read-only database permissions, allowlisted data access, bounded execution
time/result size and audit logging. Native Foundry tools or a Toolbox connection
do not automatically add that service to the hosted `maf_lite` code.
This path requires implementation and end-to-end security validation.
