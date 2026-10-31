# Ask questions about SQL data

**Structured Query Language (SQL)** queries and changes database tables.
Natural-language-to-SQL (NL2SQL) turns a question into a query and summarizes
the result. Agent Application offers two distinct routes. Choose the route
before configuring its metadata, identity and permissions.

Deployment follows the
[full-stack deployment guide](deploy-full-stack.md).

<span id="choose-the-supported-route"></span>

## Structured-data grounding

| Route | Query execution | Supported hosting |
| --- | --- | --- |
| `AGENT_STRATEGY=nl2sql` | The orchestrator selects a configured datasource, generates and validates SQL, executes it through the database connector, then summarizes rows. | Classic Container Apps execution |
| Foundry IQ `fabricDataAgent` source | The published Fabric data agent owns query generation and execution. The orchestrator consumes its retrieved answer. | Foundry IQ retrieval, including the built-in hosted `maf_lite` path |

These are not equivalent settings for one implementation. Changing
`RETRIEVAL_BACKEND` does not redirect the direct SQL strategy to a Fabric agent.
The hosted strategy allowlist excludes `nl2sql`, but that does not make direct
NL2SQL an unimplemented feature in classic execution.
[Strategies & prompts](agent-strategies.md) describes the supported choices.

## Direct NL2SQL strategy

Use this route for an approved SQL database or Fabric SQL endpoint whose
schema and example queries you manage. It does not crawl a database to discover
an unrestricted schema on every question.

The flow first retrieves datasource descriptions and relevant table metadata.
A triage step selects a datasource or answers without a query. For a selected
SQL source, the flow gathers schemas and similar queries, generates SQL,
validates it, executes it, and streams a summary. Failed validation or execution
returns an explanation instead of fabricated rows.

### Prepare datasources and metadata

1. Provide the classic orchestrator's model, Cosmos DB, Search and Key Vault
   dependencies through [Application settings](application-settings.md).
   SQL execution needs ODBC Driver 18 for SQL Server and network access to the
   selected database. The component image includes the ODBC dependencies.
2. Add datasource definitions to the Cosmos container selected by
   `DATASOURCES_CONTAINER`, default `datasources`.
   A `sql_database` definition identifies `id`, `description`, `server` and
   `database`, with optional `uid`. A Fabric `sql_endpoint` also supplies
   `tenant_id` and `client_id`.
3. Prepare JSON table definitions and example queries with matching
   `datasource` identifiers. The orchestrator's
   [SQL examples](https://github.com/Azure/agent-app-orchestrator/tree/main/samples/sql_database)
   and [Fabric examples](https://github.com/Azure/agent-app-orchestrator/tree/main/samples/fabric)
   show the metadata structure. They are illustrative data, not automatically
   provisioned connections.
4. Put metadata JSON in `queries/`, `tables/` and, where needed, `measures/`
   under `NL2SQL_STORAGE_CONTAINER`, default `nl2sql`. Agent App Ingestion's
   `nl2sql_index` job indexes those files and generates metadata embeddings.
   Configure `SEARCH_QUERIES_INDEX_NAME`, `SEARCH_TABLES_INDEX_NAME` and
   `SEARCH_MEASURES_INDEX_NAME` consistently in both services. The orchestrator
   defaults are `nl2sql-queries`, `nl2sql-tables` and `nl2sql-measures`.
   Ingestion needs explicit target names for the content it processes.
5. Run indexing and inspect confirmed results using
   [Jobs & schedules](ingestion-jobs.md). This indexes schema descriptions and
   examples, not copies of all database rows. Another approved pipeline can
   populate compatible metadata indexes instead.
6. Select `AGENT_STRATEGY=nl2sql`, restart the classic orchestrator and ask a
   question with a known result from an approved table.

The metadata search defaults to `SEARCH_APPROACH=hybrid`, with semantic search
off. `SEARCH_TABLES_INDEX_TOP_K` defaults to `10` and
`SEARCH_QUERIES_INDEX_TOP_K` to `3`. Review these alongside the metadata corpus,
not as a way to grant table access. The three NL2SQL prompts cover triage,
SQL generation and synthesis as described in
[Strategies & prompts](agent-strategies.md#configure-prompts).

### Database identity and limits

For `sql_database`, omitting `uid` uses managed identity with Azure CLI as the
local credential fallback. Supplying `uid` uses SQL authentication with the
password read from Key Vault under the normalized `<datasource-id>-secret`
name. Fabric `sql_endpoint` uses the configured service principal and the same
datasource-based secret naming. Grant only read access to approved data.
Do not store passwords or client secrets in datasource JSON.

The direct SQL path runs as that configured database principal. It does not
automatically delegate each chat user's identity to the database or inherit
Foundry IQ's document permission enforcement. Restrict application access,
database grants and any required tenant/data partitioning accordingly.

Validation permits a single read-only `SELECT`, including supported
`WITH` queries, and rejects mutations, `SELECT INTO`, multiple statements and
pass-through functions such as `OPENQUERY`. This is defense in depth, not a
replacement for a read-only database principal, bounded database resources or
reviewed data exposure.

The plugin contains semantic-model and DAX helpers, and samples include
`semantic_model` definitions. **The current `nl2sql` strategy flow rejects a
selected semantic-model datasource.** Do not advertise those lower-level
helpers as an enabled end-to-end semantic-model strategy. Use the Fabric
data-agent route below when appropriate, or treat a custom DAX flow as
application development.

## Fabric data-agent route

Fabric warehouses and lakehouses store analytical data. A Fabric data agent
generates and executes read-only SQL over their tables.
A Power BI semantic model uses Data Analysis Expressions (DAX).
Fabric owns schema context and query execution. The hosted orchestrator consumes
results from the knowledge base.

This route does not require the direct strategy's Cosmos datasource records,
ODBC connection or NL2SQL metadata ingestion jobs.

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
[Application settings](application-settings.md) identifies runtime values.

### Identity and API boundaries

The connector uses workload authentication for Search transport and a separate
Search-audience delegated token for the user's source authorization. The UI
obtains that token from the authenticated user's current assertion. Foundry
forwards it to the hosted runtime, which sends the raw token in
`x-ms-query-source-authorization`. It is not exchanged again in the container.

Missing delegation or a failed required source stops retrieval. The source is
not skipped and the connector does not retry as an application identity.
[Agent Application access](application-auth.md) explains the required
sign-in and consent.

Fabric requires the explicit `FOUNDRY_IQ_API_VERSION=2026-08-01-preview` contract.
Provisioning binds the configured planning model and selects `low` retrieval
reasoning for a bound Fabric source. The connector parses `fabricAnswer` and
textual `fabricEmbeddedResources` as data-agent results, retaining the source
identity in citations. This provides textual grounding, not an interactive
table/chart viewer or direct SQL execution in the hosted container.

<span id="run-a-read-only-pilot"></span>

## Validation boundary

A meaningful pilot compares a fixed, known aggregate from an approved table
with the same question in Fabric and in the hosted application. The published
agent's selected tables, business definition, date boundaries and permissions
all affect the result.
[Creating a Fabric data agent](https://learn.microsoft.com/fabric/data-science/how-to-create-data-agent)
is a separate service procedure, not evidence that application integration works.

Required evidence includes activity from the intended knowledge source,
correctly parsed results and denial for a user without source access.
Use the integrated identity and API settings for that validation.
Read-only execution prevents writes. It does not itself authorize a caller
or guarantee a correct answer.

For direct NL2SQL, compare the generated SQL and returned aggregate with a
reviewed query run under the configured read-only principal. Also verify that
the principal cannot write or read unapproved tables and that unauthorized
users cannot invoke the application. Do not infer per-user database isolation
from a successful question.
[Monitoring & audit](application-monitoring.md) covers correlated evidence.

<span id="diagnose-or-undo"></span>

## Failure boundaries

A Fabric answer missing from chat can indicate denied consent or source access,
an incorrect binding or incompatible API settings. An incorrect aggregate
can instead reflect source schema or business definitions.
Knowledge-base source references and provisioning inputs share a lifecycle.
removing a pilot binding does not require deleting tables or other knowledge sources.

## Need a direct SQL connection?

Use the [classic NL2SQL strategy](#direct-nl2sql-strategy) when its execution and
identity boundaries meet the requirement. Direct SQL in hosted `maf_lite`
would instead need an explicit [tool integration](agent-tools.md) with caller
authorization, read-only database permissions, reviewed data access and bounded
execution. A portal tool attachment does not add that service to the container.
Request payloads belong in the [API reference](application-api.md).
