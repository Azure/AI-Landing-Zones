# Agent App MCP Server

**Agent App MCP Server** gives an Agent or Workflow access to approved SQL
data through Model Context Protocol (MCP). It is an optional application
component in a **separate Azure Container App**, whether the consuming
orchestrator runs in Foundry Hosted Agents or Azure Container Apps.

The server uses the official Python MCP SDK, not Microsoft Agent Framework.
It performs a bounded operation for each request; it does not host conversations,
workflows, a scheduler or a UI.

## What the component provides

| MCP operation | Purpose |
| --- | --- |
| `nl2sql.list_sources()` | List approved, enabled sources available to the authenticated application. |
| `nl2sql.query(source_id, question)` | Find approved metadata, generate and validate read-only SQL, execute it and return typed results. |

These are the only supplied tools. The model cannot submit arbitrary SQL,
change the catalog or pass identities and credentials as tool arguments.
Azure SQL and SQL Server are supported; Fabric SQL endpoints, semantic models
and DAX are not part of this component.

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

### Fresh application

Follow the full-stack guide's target, identity, model and network preparation
[with Bicep](deploy-full-stack.md#procedure) or
[with Terraform](deploy-terraform-full-stack.md#procedure).
Before first provision, from the platform root:

```bash
azd env set DEPLOY_AGENT_APP_MCP true
azd up
```

`azd up` runs provisioning and application deployment. Provisioning creates or
reuses dependencies and prepares their configuration; deployment builds and
deploys the selected images and publishes the consuming application.
SQL onboarding is a separate step, described below.

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

MCP uses the **application-owned Cosmos DB for NoSQL account**, never Foundry's
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
support future reviewed tool modules. Adding a tool is development work with
its own schema, permissions and tests; no additional tools are supplied here.
