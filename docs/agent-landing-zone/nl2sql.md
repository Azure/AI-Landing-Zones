# Ask questions about SQL data

Natural-language-to-SQL (NL2SQL) turns a question into a validated, read-only
database query. In Agent Application, an Agent or Workflow calls
the **NL2SQL tools hosted by [Agent App MCP Server](agent-app-mcp.md)** to query
an approved Azure SQL or SQL Server source. The server owns query generation,
validation and read-only database execution.

<div class="runbook-diagram" markdown="1">

<div class="runbook-diagram__summary" markdown="1">

**Where is SQL generated and authorized?**

1. An authenticated Agent or Workflow invokes Agent App MCP Server, the
   separate Model Context Protocol tool service.
2. Only an explicitly selected `nl2sql` toolset reads its own approved source
   and vector-metadata catalog, generates SQL and validates it.
3. The server executes against the approved database under its read-only
   principal. Users share that approved dataset; there is no per-user database
   delegation.

</div>

[![An agent or workflow invokes the selected NL2SQL toolset on Agent App MCP Server. The server reads approved metadata from the application Cosmos catalog, generates and validates read-only SQL, then queries approved Azure SQL or SQL Server tables and views under its read-only identity. A separate importer activates metadata versions. SQL authorization is not delegated per user.](../media/runbooks/nl2sql.svg?v=88c029a7c8da)](../media/runbooks/nl2sql.svg?v=88c029a7c8da){: .runbook-diagram__image aria-label="Open full-size NL2SQL ownership and execution diagram"}

[Open full-size diagram](../media/runbooks/nl2sql.svg?v=88c029a7c8da){: .runbook-diagram__open}

</div>

## How to enable NL2SQL

### 1. Select the toolset before provision

NL2SQL is optional. It does not change `APPLICATION_MODE` or
`ORCHESTRATION_HOST`, and applications without it do not need its SQL
connectivity or metadata catalog.
For the reference application, select it explicitly before provision/deploy:

```bash
azd env set DEPLOY_AGENT_APP_MCP true
azd env set MCP_TOOLSETS '["nl2sql"]'
```

`MCP_TOOLSETS` defaults to `[]`; choose `["nl2sql"]` for this walkthrough.
These are supported lifecycle inputs; do not enable only an unrelated
`MCP_ENABLED` key in the portal. Initialize and run `azd provision`, then
`azd deploy`, using the [canonical deployment guide](deploy-full-stack.md).
The [MCP deployment guide](agent-app-mcp.md) owns server identity, caller
authorization and catalog dependency setup.

Tool registration is startup-scoped; changes require restart/redeployment.
Disabling NL2SQL stops registration and client initialization, not deletion
of retained catalogs or automatic revocation of previously granted roles.
Custom apps follow the [MCP custom application contract](agent-app-mcp.md#custom-applications)
for their own runtime settings, compute and permission declarations.

## Choose the structured-data route

| Route | Who executes the query | What you prepare |
| --- | --- | --- |
| NL2SQL tools on Agent App MCP Server | The tool implementation in a separate Container App generates, validates and executes SQL as the application's read-only principal | Approved SQL source, Cosmos schemas/examples and embeddings, model selection and network access |
| Foundry IQ `fabricDataAgent` source | The published Fabric data agent owns query generation and execution; the application consumes its answer | Published Fabric agent, knowledge-source binding and delegated source access |

The current NL2SQL toolset supports Azure SQL and SQL Server, not Fabric SQL endpoints,
semantic models or DAX. Use the Fabric route for its supported analytical
sources. Changing a retrieval-backend setting does not redirect NL2SQL tool calls.
Search remains a dependency of Foundry IQ, not of the NL2SQL metadata catalog.

<span id="how-an-mcp-question-is-answered"></span>

## How an NL2SQL request is answered

1. The Agent or Workflow lists the approved sources using
   `nl2sql.list_sources()`.
2. It calls `nl2sql.query(source_id, question)` with an approved source ID.
3. The server embeds the question and searches the source's **active metadata
   version** in Cosmos. Retrieval is source-filtered and bounded (default
   `MCP_METADATA_TOP_K=8`), with limited reads for required relationships.
4. The selected generation model produces SQL from that approved context.
5. The server validates the statement and allowed objects, then executes it
   with the configured read-only database principal.
6. Typed rows return to the calling application for presentation.

The server does not copy the business dataset into Cosmos or discover
unapproved objects during a question. Missing or incomplete required metadata
is an explicit failure, not permission to query a broader source.

For example, after a sales view and its metadata are approved, a user can ask
“What were total sales last month?” The source's descriptions and examples
must define the sales measure and date boundaries. The returned aggregate
comes from SQL under the application's read principal, not from copied rows
in the catalog.

<span id="prepare-an-approved-source"></span>

## How to onboard and query an approved source

### 2. Prepare the database and owner-approved metadata

Start with the [MCP deployment and onboarding steps](agent-app-mcp.md#onboard-sql-before-inviting-users).
The operator approves the datasource and metadata. The platform supplies the
Container App, identity, Cosmos policies, scoped grants and connection settings.
Provisioning alone does not make a datasource ready.

### Database identity

For Azure SQL, prefer the MCP Container App's managed identity. The SQL owner
creates or authorizes the database principal and grants only read access to
approved views/tables. Startup and deployment hooks do not execute database
administration or grant SQL permissions.

For SQL Server without managed-identity support, use a dedicated SQL read
principal. Store its password in Key Vault and put only the reference name in
the source record. Grant the server access to that exact secret.
Declare its name in `MCP_SQL_SECRET_NAMES` (default `[]`) so the platform
can apply the scoped grant. The list contains names, not passwords.
Do not send credentials, user identities or arbitrary SQL as tool arguments.

All authorized users of the application share this approved dataset.
Application admission, MCP caller authorization and SQL read permissions are
separate checks. There is no automatic per-user SQL delegation or database-row
isolation from Foundry IQ document permissions.

### Approved source and metadata contract

| Source field | Meaning |
| --- | --- |
| `id`, `source_id` | The same approved source identifier; `source_id` is the partition key |
| `name`, `description`, `enabled` | Operator-reviewed display information and source availability |
| `metadata_version` | Active, completely imported catalog version |
| `sql_server`, `sql_database` | Approved SQL hostname and database |
| `allowed_objects` | Approved qualified tables/views, for example `dbo.ApprovedView` |
| `authentication` | `managed_identity` or `sql_password` |
| `sql_username`, `password_secret_name` | Required only for password authentication; the password itself is never stored here |

Metadata records contain `id`, `source_id`, `metadata_version`, `kind`
(`schema` or `example`), approved `content` and an `embedding` vector.
`object_name` and `related_objects` identify approved objects where needed.
Descriptions should explain relationships, business terms and the meaning of
example queries without including copied business rows.

The embedding deployment and dimensions must match provisioning, import and
query execution. The default is `3072` dimensions. Cosmos vector-search
enablement does not generate embeddings by itself. Model/dimension or policy
changes require explicit reindexing. Existing catalog name/dimension changes
are rejected in place and require an explicit migration plan.

### Example approved source file

Suppose your existing database exposes an approved view named
`dbo.ApprovedProducts` with `ProductId` and `ProductName` columns. The SQL owner
must create or approve that view and grant the **MCP server's identity** read
access before you use it. This example does not create the database or view.

Save this UTF-8 JSON as `approved-products.json`. Replace the illustrative SQL
hostname and database, and describe your actual approved view:

```json
{
  "source": {
    "id": "products",
    "source_id": "products",
    "name": "Approved products",
    "description": "Product counts from the approved product view.",
    "enabled": true,
    "metadata_version": "catalog-v1",
    "sql_server": "approved-sql.database.windows.net",
    "sql_database": "ApprovedDatabase",
    "allowed_objects": ["dbo.ApprovedProducts"],
    "authentication": "managed_identity"
  },
  "records": [
    {
      "id": "products-schema",
      "source_id": "products",
      "metadata_version": "catalog-v1",
      "kind": "schema",
      "object_name": "dbo.ApprovedProducts",
      "content": "dbo.ApprovedProducts(ProductId int, ProductName nvarchar(100)). Each row represents one product."
    },
    {
      "id": "products-count",
      "source_id": "products",
      "metadata_version": "catalog-v1",
      "kind": "example",
      "object_name": "dbo.ApprovedProducts",
      "content": "Question: How many approved products are there? SQL: SELECT COUNT(*) AS ProductCount FROM dbo.ApprovedProducts"
    }
  ]
}
```

`products` is the source identifier, not a database name or credential.
The `schema` record describes the view's columns and business meaning.
The `example` record pairs a useful question with approved read-only SQL.
Neither record contains product rows. For multiple objects, add schema context
for every item in `allowed_objects`, including approved relationships.

<span id="import-the-approved-file"></span>

### 3. Import the approved file after provisioning

Use the MCP repository's administrative Python importer, not a tool call or
document-ingestion job. Run it from the **MCP repository root** on an authorized
managed-identity runner with Python 3.12 and the repository's `uv` tooling.

Supply `APP_CONFIG_ENDPOINT` for the application's store and, when using an
assigned identity, `AZURE_CLIENT_ID`. The identity needs configuration read,
write access to both catalog containers and embedding-model inference access.
Azure CLI login is not an importer credential fallback.

Keep the identities distinct:

| Identity | Access needed | Provisioning responsibility |
| --- | --- | --- |
| Consuming Agent/Workflow | Authenticated MCP invocation | Yes, for the selected application callers |
| MCP server with `nl2sql` selected | Catalog read, selected models and approved SQL read | Platform grants declared catalog/model access only for the selected toolset; SQL owner grants database access |
| Administrative importer | App Configuration read, catalog write and embedding-model access | No, the operator authorizes this separate runner identity |

Use an existing approved Azure runner that can obtain its assigned managed
identity token and reach App Configuration, Cosmos and the embedding endpoint.
An ordinary laptop signed in with `az login` cannot run this importer as-is.
Do not grant catalog write to the MCP server to work around an import error.
See [application permissions](../bicep/permissions.md) for role boundaries.

The UTF-8 JSON file contains a `source` object and a `records` array using the
fields above. Every approved object needs schema context; record source IDs
and metadata versions must match the source. Do not supply precomputed
embeddings or business rows: the importer generates the vectors.

Obtain the manifest-pinned MCP component on that runner through your reviewed
component acquisition process, then install from its frozen lock.
The platform normally downloads runtime components automatically for deployment,
but that does not launch the administrative import:

```text
# From the manifest-pinned MCP repository root:
uv sync --frozen
```

Use the MCP tag/commit in the platform's reviewed `manifest.json`, not an
independently newer component release.
The repository supplies `samples/approved-synthetic.json` for an authorized
development test. Its illustrative source is not an automatically provisioned
SQL connection. For your application, replace the sample path with your
operator-approved JSON file.

Set the application's actual App Configuration endpoint. Set `AZURE_CLIENT_ID`
only when selecting a user-assigned managed identity attached to this runner.
Use that identity's client ID, not its object ID or the MCP API audience.

For your approved file, in Bash:

```bash
export APP_CONFIG_ENDPOINT="https://<application-config-store>.azconfig.io"
# Only for a user-assigned identity attached to this runner:
# export AZURE_CLIENT_ID="<importer-managed-identity-client-id>"
PYTHONPATH=src uv run --frozen python -m tools.nl2sql.importer --file /path/to/approved-products.json
```

In PowerShell:

```powershell
$env:APP_CONFIG_ENDPOINT = 'https://<application-config-store>.azconfig.io'
# Only for a user-assigned identity attached to this runner:
# $env:AZURE_CLIENT_ID = '<importer-managed-identity-client-id>'
$env:PYTHONPATH = 'src'
uv run --frozen python -m tools.nl2sql.importer --file C:\approved\approved-products.json
```

The importer validates the file, generates embeddings, stages a unique catalog
version and activates it only after every metadata write completes. It prints
`Activated metadata_version:` with the resulting active version on success.

Confirm the source's active version and an approved query before admitting
users. Partial staging leaves the previous active version in use.

A failed import does not confirm activation; inspect the source's
active version before retrying. Staged inactive records need separately
approved retention/cleanup, not automatic container deletion.

The import operator needs explicit write access scoped to both catalog
containers and model inference permission. The MCP runtime's catalog reader
identity cannot perform imports.
Import does not create Azure resources or database grants, and requires no
ingestion service, MCP write tool or Search metadata indexes.

<span id="ask-the-first-question"></span>

### 4. Ask and verify the first question at runtime

After a successful import, sign in through the application's normal UI and ask:

> Using the products source, how many approved products are there?

The Agent or a Workflow with the SQL capability registered calls
`nl2sql.list_sources()` and then
`nl2sql.query(source_id="products", question="How many approved products are there?")`.
The user types a question, not SQL or credentials. Verify the count against
the approved view using the same read-only database principal.

No separate ingestion job or application redeploy is needed merely to import
a new catalog version. New SQL destinations, network access or secret consumers
can require their own owner-approved configuration and deployment changes.
Keep generation models and embedding dimensions compatible.

If `products` is absent, first verify import activation and source availability.
If the application never calls an MCP tool, check component selection and
application tool registration. If the tool is invoked but fails, check SQL
permissions, network access and catalog/model configuration using
[MCP troubleshooting](troubleshooting.md#agent-app-mcp-failures).
Do not use `/healthz` alone as proof that SQL questions work.

## Results and execution limits

The result uses `structuredContent` and a typed `outputSchema`, with a
consistent JSON text representation for supported clients that require it.
Schema version `1` includes:

| Field | Meaning |
| --- | --- |
| `schema_version`, `source_id` | Result contract version and approved source |
| `query_id`, `metadata_version` | Correlation ID and catalog version used |
| `columns` | Column names and explicit logical types |
| `rows`, `row_count` | Ordered row values and returned count; nulls remain null |

Decimal, date and binary encodings are identified by column type, preserving
decimal precision. A successful zero-row query is distinct from an error.

| Boundary | Limit |
| --- | --- |
| SQL execution | 30 seconds |
| Rows | 1,000 |
| Serialized result | 256 KiB (`262144` bytes) |
| Complete server query | `MCP_QUERY_TIMEOUT_SECONDS=75` by default; accepted range `1..75` |
| Consuming MCP client | `MCP_CLIENT_TIMEOUT=90` by default; positive and must exceed the NL2SQL whole-query deadline |

The complete deadline covers connection, metadata retrieval, model generation
and SQL. Limits produce explicit errors, not silently truncated results.
Validation allows a single read-only `SELECT`, including supported `WITH`
queries, and rejects mutations, multiple statements, `SELECT INTO` and
pass-through functions such as `OPENQUERY`. Database grants remain the primary
security boundary; model instructions and validation are defense in depth.

### Failures, cancellation and cleanup

Authorization, invalid SQL, unavailable dependencies and exceeded limits must
remain explicit failures. Do not invent rows, report an empty success, switch
source/identity after denial, or fall back to SQL inside the orchestrator.
Cancellation does not guarantee instant SQL-server cancellation. Cursor and
connection cleanup must not close resources beneath a running ODBC worker.

## Check before admitting users

In an authorized test environment, compare a known aggregate with a reviewed
SQL query under the same read-only principal. Check:

- Only the two documented tools are discovered by an authorized application.
- Missing/expired tokens, wrong tenant/audience, disallowed clients and missing
  `MCP.Invoke` role are denied before catalog or SQL access.
- Unapproved sources/objects and writes are denied.
- Nulls, decimals and zero rows have the expected typed result.
- Outages, cancellation and row/byte/time limits are explicit.
- Query ID and metadata version provide correlation without logging sensitive
  SQL, tokens or returned rows.

Use [Troubleshooting](troubleshooting.md#agent-app-mcp-failures) and
[Monitoring & audit](application-monitoring.md). A healthy container or
successful provision does not establish functional SQL readiness.

## Fabric data-agent route

Fabric owns schema context and analytical execution for its data-agent route;
the application consumes grounded results, without the MCP catalog or SQL
connection. Its source-registration template does not install end-to-end
native application delegation. Follow [Fabric IQ](fabric-iq.md) for the
preview prerequisites, exact declaration shape, integration work and
allowed/denied-user tests rather than applying the NL2SQL setup to Fabric.
