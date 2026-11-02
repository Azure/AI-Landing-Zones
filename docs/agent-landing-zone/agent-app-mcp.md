# Agent App MCP Server

**Agent App MCP Server** hosts tools that an Agent or Workflow calls through
Model Context Protocol (MCP). It is an optional application
component in a **separate Azure Container App**, whether the consuming
orchestrator runs in Foundry Hosted Agents or Azure Container Apps.

MCP is the communication protocol, not a SQL feature. Agent App MCP is the
server component. **NL2SQL is the toolset currently supplied by that server**,
with operations for listing approved sources and asking questions about SQL
data. Other reviewed toolsets can be added to the server without redefining
MCP as NL2SQL.

The server uses the official Python MCP SDK, not Microsoft Agent Framework.
It performs a bounded operation for each request; it does not host conversations,
workflows, a scheduler or a UI.

## Start here: from deployment to the first question

The steps below deploy the server and onboard its current **NL2SQL toolset**.
SQL permissions and catalog import belong to that toolset, not to the MCP
protocol or every possible MCP tool.
Follow these steps in order. **Deploying the component does not connect a SQL
source or populate its catalog.**

| Step | What you do | Ready when |
| --- | --- | --- |
| 1. Deploy | Select `DEPLOY_AGENT_APP_MCP=true` and run the [platform lifecycle](#select-and-deploy) | The MCP Container App and its generated connection are available |
| 2. Authorize SQL | Have the database owner approve the objects and grant the MCP identity read access | The server can reach and read only the approved database objects |
| 3. Describe the data | Prepare an [approved source file](nl2sql.md#example-approved-source-file) with schemas and useful question/query examples | Every approved table or view has matching schema context |
| 4. Import metadata | Run the [administrative importer](nl2sql.md#import-the-approved-file) using a separately authorized managed identity | It reports `Activated metadata_version:` |
| 5. Ask and verify | Sign in to the application and ask a question about that source | A real MCP query returns a known result, and unauthorized access is denied |

You do not add a connection string or an MCP token to the browser. The platform
connects the consuming application to the server. You supply SQL authorization
and approved metadata separately.

## What the component provides

| NL2SQL tool exposed over MCP | Purpose |
| --- | --- |
| `nl2sql.list_sources()` | List approved, enabled sources available to the authenticated application. |
| `nl2sql.query(source_id, question)` | Find approved metadata, generate and validate read-only SQL, execute it and return typed results. |

These are the currently supplied tools, not a fixed limit of MCP or the
server's intended tool catalog. This release does not provide additional
toolsets or automatic plugin installation.
Through the NL2SQL tools, the model cannot submit arbitrary SQL,
change the catalog or pass identities and credentials as tool arguments.
The current NL2SQL toolset supports Azure SQL and SQL Server, not Fabric SQL
endpoints, semantic models or DAX.

The server listens on port `8080` inside its container. The Azure HTTPS
endpoint uses stateless Streamable HTTP at `/mcp`.
`/healthz` checks liveness, not successful authentication, catalog readiness or
SQL connectivity. See [NL2SQL](nl2sql.md) for source onboarding and result limits.

## What you choose and what is automatic

| You choose or approve | The platform coordinates |
| --- | --- |
| Whether to include the component | Container App, its own managed identity and compatible image deployment |
| Application host and mode, independently | The selected consuming Agent/Workflow and its MCP connection |
| Generation and embedding models, including vector dimensions | Reuse of compatible model deployments and matching catalog policies |
| SQL destination, approved objects and a read-only database principal | Application Cosmos resources, container-scoped access and generated settings |
| Approved schemas, descriptions, relationships and query examples | Endpoint, audience, client authorization and activation through the application lifecycle |
| Required network routes and SQL-owner authorization | Declared platform-owned network and access reconciliation |

You do **not** need a second NL2SQL enable flag, a Cosmos connection string,
manual catalog-container creation or an Azure AI Search index for MCP.
Selecting the component does not create a SQL database, database users or
database grants, discover unknown schemas, or import business rows.

The deployment helper creates/configures the dedicated Entra API registration,
service principal and `MCP.Invoke` app role, then authorizes the actual callers.
It reuses the registration by its exact application object ID recorded in
App Configuration, not by approximate name.
The deployer needs directory rights to manage those registrations and assign
application roles, **in addition to** Azure resource/RBAC permissions.
Runtime identities do not need those directory administration rights.

## Select and deploy

The public selector is `DEPLOY_AGENT_APP_MCP`, default `false`. It selects the
server, not the Agent's host or application mode.

### Use the coordinated platform source

The MCP-enabled full-stack integration is available on the platform's
`develop` branch. Use that checkout and its complete `manifest.json` and
application definition together:

```bash
git clone --branch develop https://github.com/Azure/agent-landing-zone.git
cd agent-landing-zone
```

The MCP component has its own release, but installing that component alone
does not add the foundation selector, caller authorization or consumer
integration to another platform checkout. Do not copy only its version into
an unrelated manifest. For an existing installation, review and approve the
complete platform update before changing its selected source.

### Fresh application

Follow the full-stack guide's target, identity, model and network preparation
[with Bicep](deploy-full-stack.md#procedure) or
[with Terraform](deploy-terraform-full-stack.md#procedure).
Before first provision, from the platform root:

```bash
azd env set DEPLOY_AGENT_APP_MCP true
azd provision
```

After provision, complete the full-stack guide's UI callback, credentials and
admission setup, then run `azd deploy` from the same platform root.
Provisioning creates or reuses dependencies and prepares their configuration.
Deployment builds the selected images and publishes the consuming application.
Use `azd up` to combine both stages only when the required login configuration
is already prepared. SQL onboarding is a separate step, described below.

### Add to an existing installation

Use the same compatible platform/component line and the environment's recorded
provider, application ID and resource destinations. Review the infrastructure
changes, select the existing environment, then run from the platform root:

```bash
azd env select <environment-name>
azd env set DEPLOY_AGENT_APP_MCP true
azd provision
azd deploy
```

Do not skip provision: the new component needs resources, identity, catalog
policies and grants. Do not run these commands from the MCP repository;
its scripts deploy an image to an already provisioned Container App and do not
create the foundation.

The lifecycle deploys the MCP image, obtains the actual consuming identities,
grants `MCP.Invoke` and publishes the allowlist and connection settings.
Because server authentication settings are startup-only, it automatically
restarts every active MCP revision after publishing the allowlist, checks
authenticated discovery, then activates the consumers. No manual MCP restart
is required during normal `azd deploy`.
Hosted `both` has separate conversation and workflow callers.
An existing external MCP endpoint conflict must be resolved explicitly;
selection does not silently replace it or create a multi-endpoint integration.

## Why application Cosmos DB is required

The supplied NL2SQL toolset uses the **application-owned Cosmos DB for NoSQL
account**, never Foundry's
backing Cosmos account. The platform reuses the account managed by this
deployment when compatible, or creates it during `azd provision` if absent.
Selecting MCP automatically requires this dependency. Normal application
Cosmos uses serverless throughput.

| Container | Contents | Partition key |
| --- | --- | --- |
| `mcp-sources` | Approved source bindings, allowed objects and active metadata version | `/source_id` |
| `mcp-nl2sql-metadata` | Approved schemas and examples with their embeddings | `/source_id` |

Credentials stay in Key Vault; source records contain only secret references.
Business rows stay in SQL. UI metadata uses its own containers and permissions;
neither catalog nor UI storage owns native execution state.

The platform adds `EnableNoSQLVectorSearch` while preserving existing account
capabilities captured during provision, including `EnableServerless` where
present. New metadata-container
policies use `/embedding`, `float32`, cosine distance and a `quantizedFlat`
index with the selected embedding dimensions (default `3072`).
It does not recreate the account, replace existing containers or convert
throughput to force compatibility. Shared-throughput accounts are incompatible
with this vector-search path; incompatible selections or policies produce an
explicit error for operator review.
If `DEPLOY_COSMOS_DB=false` was deliberately set or persisted, selection fails
explicitly. Unset that input for automatic selection or explicitly set it to
`true`; the lifecycle does not silently override it.
Existing catalog names or embedding dimensions cannot be changed in place.
Those changes are rejected and require an explicit migration/reindexing plan.

MCP selection does not enable `DEPLOY_SEARCH_SERVICE`, create Search indexes
or grant Search access. Search used by Foundry IQ or other retrieval is
independent. Application Cosmos can also be selected **without MCP or the
orchestrator** through `DEPLOY_COSMOS_DB=true` or a custom application capability.
Generic Cosmos does not need vector policies; they are selected for MCP or a
retained MCP catalog.
See [Application Cosmos DB](configuration.md#application-cosmos-db).

## Onboard SQL before inviting users

1. **Approve the exposure.** Select the SQL hostname, database and tables/views.
   Prefer approved views that expose only the application's permitted data.
2. **Authorize the server.** Ask the SQL owner to grant the MCP managed identity
   read access for Azure SQL. For SQL Server without managed-identity support,
   use a dedicated read-only SQL credential referenced from Key Vault.
   Declare the actual password-secret names in `MCP_SQL_SECRET_NAMES` for
   scoped vault grants; leave the default `[]` for managed-identity sources.
   Declare secret consumers before provision, or reprovision and redeploy
   if you add one after the initial installation.
   Arrange DNS, TLS and network access from the MCP Container App.
3. **Supply approved metadata.** Prepare source bindings, schemas,
   relationships, descriptions and query examples using the
   [catalog contract](nl2sql.md#approved-source-and-metadata-contract).
4. **Import administratively.** Run the
   [approved-file importer](nl2sql.md#import-the-approved-file) from the MCP
   repository on an authorized managed-identity runner. It generates schema/example
   embeddings and activates a version only after the complete import succeeds.
   The importer needs catalog write and embedding-model access; the running
   server has catalog read access only.
5. **Check a known result and denials.** Discover the two tools as an authorized
   application, list sources and query a known aggregate. Confirm unauthorized
   callers, sources and objects are denied before admitting users.

For a complete source file and the matching first question, follow
[the NL2SQL walkthrough](nl2sql.md#example-approved-source-file).

No persistent ingestion Container App is required for this import. If you use
an independent metadata pipeline, it must honor the same Cosmos schema, model
dimensions and complete-version activation contract. Import is not an MCP
write tool, startup action or unrestricted database crawl.

All authorized application users share the approved SQL dataset. MCP
authentication does not delegate each user's SQL identity or enforce
Foundry IQ document-level permissions on database rows.

## Operate and extend safely

Inspect generated nonsecret values under the `agent-lz` App Configuration label
using the [MCP settings reference](application-settings.md#agent-app-mcp-contract).
The client uses an Entra token for the dedicated MCP API, with the
`MCP.Invoke` application role and an allowed application client ID.
There is no API-key fallback or authorization from browser-supplied context.
The orchestrator receives MCP invocation access, not catalog or SQL grants.

Use query IDs and metadata versions for correlation. Tokens, generated SQL,
returned rows and internal reasoning are not logged by default.
Changing an embedding model, dimensions or vector policy requires an explicit
reindexing plan; changing a runtime key alone does not rebuild the catalog.
Small catalogs can use a Cosmos vector full scan below the quantization
threshold of 1,000 vectors. Measure RU consumption and latency rather than
assuming index savings.

When `DEPLOY_AGENT_APP_MCP=false` is applied through the platform lifecycle,
both providers preserve application Cosmos, catalog-container declarations and
vector policies. These resources are retained for safe cleanup rather than
automatically destroyed.
The parent publishes `MCP_ENABLED=false` and an empty caller allowlist;
the shared helper restarts any remaining MCP serving revisions to revoke
callers. Terraform removes deselected MCP compute from its managed state,
whereas Bicep incremental deployments can leave the Container App resource
present. Do not assume Bicep automatically deletes that compute. After
confirming disablement has taken effect, the operator may explicitly remove
an unused MCP Container App if desired, but must not delete the Cosmos account
or catalog as part of that compute cleanup. Sources, data and other grants
still need explicit owner review. Recovery uses a compatible image/configuration
or controlled deactivation, never direct SQL inside the orchestrator as a fallback.

The server's transport, authentication, configuration and observability can
be reused for other reviewed tool modules. Adding a tool is development work
with its own schema, permissions, dependencies and tests, plus explicit
registration in the consuming application.
The current startup initializes NL2SQL's Cosmos/model/SQL services. A future
toolset that does not need those services must have its initialization and
deployment dependencies separated accordingly. The current component is not
an automatic, independently configurable plugin platform.
