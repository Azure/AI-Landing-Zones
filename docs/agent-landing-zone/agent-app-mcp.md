# Agent App MCP Server

**Agent App MCP Server** exposes application tools over Model Context Protocol
(MCP). It runs in its own Azure Container App and uses the official Python MCP
SDK. Agents and Workflows on either supported host can consume its tools.

Configure the server below, then select the toolsets your application needs
through `MCP_TOOLSETS`. The available **NL2SQL** toolset lists approved sources
and answers questions over SQL data.

MCP is the protocol; **Agent App MCP Server** is the optional component;
**NL2SQL** is one explicitly selected toolset. Deploying the component does
not automatically select SQL tools. The foundation remains generic;
application composition owns tool choices and their dependency declarations.

<div class="runbook-diagram" markdown="1">

<div class="runbook-diagram__summary" markdown="1">

**Server compute and tool selection are different choices.** Either native
host calls the separate Container App through Entra-authenticated MCP.
The default `[]` exposes zero tools. Only `["nl2sql"]` activates the supplied
SQL tools and their catalog, model and read-only SQL dependencies.

</div>

[![Either native host invokes Agent App MCP Server in a separate Container App through Entra authentication. Startup selection is either an empty tool list with no SQL clients or the explicit nl2sql toolset with catalog, model and read-only SQL dependencies.](../media/runbooks/agent-app-mcp.svg?v=1502df21e1d2)](../media/runbooks/agent-app-mcp.svg?v=1502df21e1d2){: .runbook-diagram__image aria-label="Open full-size MCP server and toolset diagram"}

[Open full-size diagram](../media/runbooks/agent-app-mcp.svg?v=1502df21e1d2){: .runbook-diagram__open}

</div>

## Before you start

- Have the initialized platform project and selected azd environment.
  Follow the provider-specific prerequisites linked below; isolated
  deployments require a connected runner. For an existing installation,
  verify application sign-in; a fresh installation configures it after provision.
- The deployer needs Azure provisioning/scoped-grant access **and** Entra
  rights to create or reuse the API registration and assign application roles.
- Arrange HTTPS/DNS/egress from each actual agent/workflow caller to the
  server. Selecting Hosted does not move MCP compute into Foundry.
- For `["nl2sql"]` only, have a SQL data owner approve the dataset, read-only
  access and metadata import. An empty server needs none of those SQL inputs.

<span id="select-and-deploy"></span>

## Deploy Agent App MCP Server

For the reference application, `DEPLOY_AGENT_APP_MCP` selects optional server
compute and defaults to `false`. Its Container App has its own managed identity,
independently of `ORCHESTRATION_HOST` and `APPLICATION_MODE`.
Application composition coordinates its image, caller authorization and connection.

<span id="use-the-coordinated-platform-source"></span>

Initialize the azd project using
[Step 1: Initialize the project](deploy-full-stack.md#step-1-get-the-code).
Use that initialized platform root and its selected environment for the
commands below. This prepares the complete manifest and application definition;
the MCP component repository alone is not a full-stack deployment template.

The manifest binds compatible server and consumer releases. For an existing
installation, review the complete platform update before changing source.

### Fresh application

Complete the full-stack prerequisites and identity/network preparation
[with Bicep](deploy-full-stack.md#procedure) or
[with Terraform](deploy-terraform-full-stack.md#procedure).
From the platform root, select an authenticated server with an empty toolset list:

```bash
azd env set DEPLOY_AGENT_APP_MCP true
azd env set MCP_TOOLSETS '[]'
azd provision
```

Provisioning prepares compute, configuration and access. Complete the full-stack
guide's UI callback, credentials and admission setup, then run `azd deploy`
from the same root. Deployment builds the selected images and publishes the
application. Use `azd up` to combine both stages when login configuration is
already prepared.

To include SQL tools in the first deployment, use the selection in
[Configure NL2SQL](#configure-nl2sql) before provision.

### Add to an existing installation

Retain the environment's recorded provider, application ID and resource
destinations. Review the infrastructure changes and desired
[toolset selection](#select-toolsets), then run from the platform root:

```bash
azd env select <environment-name>
azd env set DEPLOY_AGENT_APP_MCP true
azd provision
azd deploy
```

Provision resolves the selected resources, policies and grants.
Component-repository deployment scripts target an already provisioned Container App.

## Authentication and endpoint

The platform helper configures a dedicated Entra API registration, service
principal and `MCP.Invoke` app role. It reuses the exact application object ID
recorded in App Configuration and authorizes the actual consuming identities.
Hosted `both` has separate conversation and workflow callers.

The deployer needs directory rights for registrations and application-role
assignments, in addition to Azure resource and scoped RBAC permissions.
Runtime identities use their assigned invocation and dependency permissions.

Clients use an Entra token for the dedicated MCP API. The server validates the
tenant's v2 issuer, signature, audience, token validity, allowed application
client ID and `MCP.Invoke` role. These checks also apply to an empty server.
Credentials stay server-side; API keys and browser-supplied user context are
not accepted as authentication.

The container listens on port `8080`. Its Azure HTTPS endpoint serves stateless
Streamable HTTP at `/mcp`. The lifecycle publishes endpoint, audience, scope and
caller settings under the `agent-lz` App Configuration label.
See the [MCP settings contract](application-settings.md#agent-app-mcp-contract).

## Select toolsets

`MCP_TOOLSETS` is application/runtime configuration, published under `agent-lz`.
Application composition translates selected dependencies into generic foundation
inputs for Bicep or Terraform.

| Selection | Server behavior |
| --- | --- |
| `[]` — default | Registers zero tools and initializes no NL2SQL clients or dependencies. New empty-server selection adds no NL2SQL catalog, model, SQL or secret grants. |
| `["nl2sql"]` | Registers `nl2sql.list_sources` and `nl2sql.query`; requires the [NL2SQL configuration](#configure-nl2sql). |

Unknown names, duplicates, malformed JSON and invalid array values fail closed
before dependency initialization. In the reference application, a nonempty
selection requires `DEPLOY_AGENT_APP_MCP=true`.
For custom definitions, use the [custom application contract](#custom-applications).

Selection is **startup-only**. Provision matching dependencies and
restart/redeploy after a change; there is no hot reload.

<span id="operate-and-extend-safely"></span>

## Operate the server

Use the normal root `azd deploy` lifecycle. It deploys the server image and
resolves actual callers. It grants `MCP.Invoke` and publishes the allowlist
and connection. It restarts every active MCP revision to load startup-only
authentication settings. It then verifies authenticated discovery before
activating consumers.

Check `/healthz` for liveness and authenticated discovery for the selected tool
list. Test denied callers as well. A healthy process alone does not establish
tool dependency readiness. Resolve an existing external MCP endpoint conflict
explicitly before selecting the integrated server.

### Verify the deployed selection

After root deployment finishes, use the authorized native consumer for MCP
discovery. Its managed identity must acquire a token for the generated
`MCP_AUTH_RESOURCE_SCOPE`; do not test by pasting a browser token or API key.

| Selection/check | Observable result |
| --- | --- |
| `[]` with an authorized caller | MCP `tools/list` returns an empty `tools` array; `nl2sql.query` is not registered. |
| `["nl2sql"]` with an authorized caller | Discovery returns exactly `nl2sql.list_sources` and `nl2sql.query`; an onboarded synthetic query returns the expected typed result. |
| Missing token, wrong audience, missing role or unapproved client | Invocation is denied, including on an empty server. |
| `/healthz` | Liveness only; it is not an authenticated discovery or SQL-readiness check. |

Use the [NL2SQL admission checks](nl2sql.md#check-before-admitting-users)
after onboarding sources, and the
[MCP troubleshooting procedure](troubleshooting.md#agent-app-mcp-failures)
for configuration, identity or discovery failures.

Inspect individual nonsecret settings and safe correlation fields through
[Monitoring & audit](application-monitoring.md) and
[MCP troubleshooting](troubleshooting.md#agent-app-mcp-failures).
Authentication and configuration changes follow the owning lifecycle.

To disable reference server compute, clear `MCP_TOOLSETS` to `[]`, set
`DEPLOY_AGENT_APP_MCP=false`, then provision/deploy. The lifecycle publishes
`MCP_ENABLED=false`, clears the caller allowlist and restarts remaining serving
revisions to load the revoked authorization.

Terraform removes deselected
compute through its managed deployment; Bicep incremental deployments can
leave the Container App present. After verifying disablement, an operator
may explicitly retire unused compute.

Catalog data and previously granted dependency roles require separate owner
review. See [catalog retention](#catalog-operation-and-retention) before cleanup.

<span id="start-here-from-deployment-to-the-first-question"></span>

## Configure NL2SQL

### Activate the toolset

For the reference application, set both selections before provision/deploy:

```bash
azd env set DEPLOY_AGENT_APP_MCP true
azd env set MCP_TOOLSETS '["nl2sql"]'
azd provision
azd deploy
```

For a fresh installation, complete the [post-provision login setup](application-auth.md#3-register-the-final-https-callback)
before deploy. Existing SQL installations also select `["nl2sql"]` explicitly.

| Operation | Purpose |
| --- | --- |
| `nl2sql.list_sources()` | Lists approved, enabled sources available to the authenticated application. |
| `nl2sql.query(source_id, question)` | Retrieves approved metadata, generates and validates read-only SQL, executes it and returns typed results. |

The toolset supports Azure SQL and SQL Server. For Fabric analytical sources,
use the separate [Fabric data-agent route](nl2sql.md#fabric-data-agent-route).

<span id="why-application-cosmos-db-is-required"></span>
<span id="when-nl2sql-requires-application-cosmos-db"></span>

### Dependencies and permissions

NL2SQL uses application-owned Cosmos DB for NoSQL, generation/embedding models,
approved read-only SQL access and network connectivity. The platform reuses a
compatible application account or creates it during provision. Normal application
Cosmos is serverless; Foundry backing Cosmos has separate ownership.

| Container | Contents | Partition key |
| --- | --- | --- |
| `mcp-sources` | Approved bindings, allowed objects and active metadata version | `/source_id` |
| `mcp-nl2sql-metadata` | Approved schemas/examples and their embeddings | `/source_id` |

Provision preserves existing capabilities, including `EnableServerless` where
present, and adds `EnableNoSQLVectorSearch`. The metadata policy uses
`/embedding`, `float32`, cosine distance and `quantizedFlat`, with the selected
embedding dimensions (default `3072`). Resolve model selection/dimensions
before provision.

Shared-throughput accounts and incompatible policies fail
explicitly; existing catalog-name/dimension changes require migration/reindexing.
An explicit `DEPLOY_COSMOS_DB=false` conflict must be unset for automatic
selection or set to `true`.

The MCP identity receives catalog read and selected model access. The SQL
owner grants read access to approved views/tables. SQL-password sources use
Key Vault references; declare exact secret names in `MCP_SQL_SECRET_NAMES`
(default `[]`) before provision for secret-scoped grants.

The administrative
importer has separately authorized catalog-write and embedding-model access.
The consuming Agent/Workflow receives MCP invocation access.

Business rows stay in SQL; the catalog holds approved metadata. Search and
document ingestion are independent capabilities.

<span id="onboard-sql-before-inviting-users"></span>

### Onboard sources

1. Approve the SQL destination and objects with their owner, preferably
   views exposing the application's permitted dataset.
2. Grant the MCP identity read access, or configure the approved password-secret
   reference. Arrange DNS, TLS and routes from the server to SQL and its dependencies.
3. Prepare the [approved source JSON](nl2sql.md#example-approved-source-file)
   with schemas, relationships, descriptions and question/query examples.
4. Run the [administrative importer](nl2sql.md#3-import-the-approved-file-after-provisioning) on a
   separately authorized managed-identity runner. It generates embeddings and
   activates a metadata version after the complete import succeeds.
5. Verify a known result through the application and check denied callers,
   sources and objects before admitting users.

All authorized application users share the approved SQL dataset. MCP invocation
authorization does not delegate each user's SQL identity or apply Foundry IQ
document permissions to database rows.
The [NL2SQL reference](nl2sql.md) contains the complete JSON/importer walkthrough,
typed results, query limits and error handling.

### Catalog operation and retention

Setting `MCP_TOOLSETS=[]` stops NL2SQL registration and client initialization
after restart/redeployment. Catalog account/container declarations and vector
policies are retained for safe cleanup rather than automatically destroyed.
Deselection does not automatically revoke previously granted roles.

Retain active metadata versions and review data/grant retirement with owners.
Embedding-model, dimension or vector-policy changes require explicit reindexing.
Below 1,000 vectors, Cosmos can use a vector full scan; measure RU consumption
and latency.

Correlate queries with `query_id` and `metadata_version`; tokens,
generated SQL, returned rows and internal reasoning stay out of default logs.
Recover through a compatible image/configuration or controlled deactivation.

## Custom applications

A custom application definition owns its server compute, runtime configuration,
dependency declarations and permissions. It can explicitly supply `MCP_TOOLSETS`
as an application runtime setting without the reference `DEPLOY_AGENT_APP_MCP`
switch or automatic reference catalog/model resources. That compute switch is
reserved for the reference application and is rejected with custom definitions.

Declare and authorize each custom consumer/dependency explicitly. Generic
Cosmos and `COSMOS_VECTOR_SEARCH_ENABLED` can be selected independently of the
reference catalog. Follow [Bring your own app](build-your-own-app.md#application-binding-and-selection).

Adding another packaged toolset requires reviewed MCP server code, an explicit
factory in `src/toolsets.py`, typed inputs/results, dependency lifecycle cleanup
and authorization tests. Updating `MCP_TOOLSETS` alone cannot load arbitrary
modules or add a new implementation. Publish a compatible server image and
declare the custom application's resources/grants before selecting it.
