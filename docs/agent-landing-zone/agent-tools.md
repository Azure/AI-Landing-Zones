<span id="agent-tools"></span>

# Tools & MCP

Tools are approved operations that a MAF Agent or Workflow can call.
Model Context Protocol (MCP) exposes operations through a tool server.
Foundry IQ and Azure AI Search provide knowledge/retrieval capabilities.
These are not competing orchestration strategies.

Select the application experience and host through
[Agents & prompts](agent-strategies.md) and
[Agent hosting](hosted-agents.md), then register the required capabilities.
A portal connection or endpoint string alone does not attach a tool to
the running application.

Native capabilities are **off by default**: `SEARCH_RETRIEVAL_ENABLED`,
`FOUNDRY_IQ_ENABLED`, `MCP_ENABLED`, `NL2SQL_ENABLED` and
`MULTIMODAL_ENABLED`. Select only the capabilities whose source, identity,
network and tool contracts are configured. The multimodal tool flag is
different from custom ingestion `MULTIMODAL` and inline private attachments.
See [Application settings](application-settings.md#native-application-contract).

<span id="choose-the-extension-point"></span>

## Tools, Toolbox and knowledge

| Need | Integration boundary |
| --- | --- |
| Call an operation | A reviewed tool with a narrow schema and explicit authorization |
| Connect an MCP server | Registered MCP tools, authenticated transport and approved destination |
| Ground an answer | A configured Foundry IQ source or Search capability |
| Query approved SQL or Fabric SQL data | Optional registered NL2SQL tool with its own metadata, connector and read-only database principal |
| Wait for a person's decision | Native workflow human input, not a blocking tool socket |
| Change a process graph | Reviewed workflow definition and compatible publication |

A Foundry IQ `mcpServer` source is retrieval configuration, not automatically
a model-callable MCP tool. Its
[knowledge-source settings](foundry-iq.md#generic-mcp-knowledge-sources)
control source planning, output parsing and query credentials.

### Optional direct NL2SQL

An Agent or Workflow can use the registered direct SQL tool without changing
its application mode or host. Enable it only for approved SQL or Fabric SQL
datasources. Its metadata store, schema/example indexes, ODBC driver, network
access and chosen database credential are conditional dependencies.
Applications without the tool do not need those SQL resources.

The configured database principal performs direct queries; no automatic
end-user SQL delegation is supplied. Read-only grants are the primary data
boundary, with generated-query validation as defense in depth.
This is separate from a Foundry IQ `fabricDataAgent` source, where Fabric owns
query generation and execution.
See [Ask questions about SQL data](nl2sql.md) for setup and denial checks.
The reused helper suite includes `validate_sql_query(query)`,
`execute_sql_query(datasource,query)` and `execute_dax_query(datasource,query)`.
Tokens are trusted server context, never model-callable arguments.
Execution is bounded to 30 seconds and 1,000 rows.
DAX and delegated multimodal calls fail closed when native host token
binding is unavailable; end-to-end delegation is not established by the
registered function or local transport tests.

<span id="before-you-start"></span>
<span id="1-check-what-the-hosted-strategy-loads"></span>
<span id="supplied-hosted-execution"></span>

## Application-owned registration

Native host integrations run the application's agent/workflow definitions.
Code defines the model, instructions, tools and retrieval behavior. Foundry
hosting does not automatically consume a portal-managed prompt agent's tool
list, and a durable worker does not infer a process from App Configuration.

Use the registered capabilities for the selected application. Keep naturally
shared agent definitions and tools common where appropriate, but use explicit
Hosted and durable integrations rather than a universal host/state wrapper.

<span id="2-configure-the-mcp-connection"></span>
<span id="3-authorize-and-connect-safely"></span>
<span id="configure-the-mcp-strategy"></span>

## Authorize and connect MCP safely

Review the destination, transport, timeout, data handling and permissions
before enabling an MCP connection. Use HTTPS outside controlled local
development and approved egress from the actual application host.
Credentials belong in Key Vault only when the selected tool really needs
a secret; prefer managed identity where supported.

Authenticate the tool client and preserve the tool's verified end-user
context when user authorization is required. User-context JSON, caller-supplied
groups, an opaque call ID or a shared managed identity is not proof of the
user's entitlement. Keep credentials request-local and out of prompts,
history, functional snapshots and telemetry.

### Authenticated Toolbox contract

Foundry's [hosted Toolbox integration](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/use-toolbox-hosted-agent)
uses an authenticated SDK client and trusted platform invocation context.
The application must actually invoke that supported integration.
Do not fabricate platform context or assume the browser's Authorization
header arrives unchanged inside a Hosted container.

The durable host uses its own explicit authenticated client/tool boundary.
Foundry invocation context must not be simulated on Container Apps.
Source-specific OBO and document permissions remain independently required;
a Search token is not a generic MCP user assertion.
See [Sign-in & access](application-auth.md).

<span id="4-add-code-when-configuration-is-not-enough"></span>

## Application extension boundary

Keep integrations in the owning application's tool/connector modules:

- Validate typed inputs and bound results, timeouts and cancellation.
- Preserve source denial as denial; do not retry under a broader identity.
- Register a capability explicitly for the agent and/or workflow using it.
- Require tool authorization and a native human decision where the process
  calls for approval. A prompt instruction is not an approval control.
- For external writes, implement the target system's idempotency and recovery
  contract. Native durable execution does not guarantee exactly-once writes.

Grant only the required model, source, scheduler and secret access.
App Configuration Reader does not grant Key Vault secret access.
`NATIVE_TOOL_SECRET_NAMES` (default `[]`) is the platform's scoped-grant
declaration of actual names, not values. The native runtime does not consume
that setting to load secrets or enable tools.
Provision resources and grants before activation; startup must not repair
infrastructure. [Customize components](customize-components.md) and
[Bring your own app](build-your-own-app.md) describe ownership and adoption.

<span id="5-deploy-and-verify"></span>

## Deployment and evidence

Changes to code, graph, tool registration or identity require a reviewed image
and compatible publication. Supported functional parameters refresh through
the official provider; workflow runs keep their functional snapshot.
Current source/tool authorization is rechecked rather than frozen in that
snapshot. See [Application settings](application-settings.md).

Verify actual tool calls, denied-user isolation, timeout/outage handling and
the absence of invented results when a required tool fails. A successful
deployment or portal registration is not this evidence.
Correlate operations without retaining secrets or sensitive tool arguments.
See [Monitoring & audit](application-monitoring.md).

<span id="recover-or-undo"></span>

## Failure boundaries

Missing tools can mean the application never registered them.
Authentication failures concern the client, connection and source separately.
Retain the authenticated caller boundary during recovery rather than
substituting service identity or silently dropping a required capability.
