<span id="agent-tools"></span>

# Tools & MCP

Tools are operations made available to an Agent or Workflow.
The Agent Application explicitly builds its tool list: Foundry integrations
for Search and Foundry IQ, an application-provided multimodal function,
and tools discovered from a Model Context Protocol (MCP) server.

Microsoft Foundry offers a broader
[tool catalog and Toolbox integrations](https://learn.microsoft.com/azure/foundry/agents/concepts/toolbox-overview#supported-tools),
including web search, code interpreter and OpenAPI tools.
The integrations below are the reference application's starting point, not
the limit of what you can build. You can add other Foundry tools, with
application code, configuration or provisioning changes where required.
Availability in Foundry does not establish compatibility with this
application's model, SDK or selected host.

Select the application experience and host through
[Agents & prompts](agent-strategies.md) and
[Agent hosting](hosted-agents.md), then register the required capabilities.
A portal connection or endpoint string alone does not attach a tool to
the running application.

<div class="runbook-diagram" markdown="1">

<div class="runbook-diagram__summary" markdown="1">

**The application supplies the agent's tools explicitly.** Foundry integrations
provide an Azure AI Search tool and a Foundry IQ tool.
Each tool uses its own project connection.
Application integrations provide the multimodal retrieval function
and selected tools discovered from an MCP server, such as the NL2SQL toolset.
Each integration needs its own configuration and authorization.

</div>

[![The Agent Application supplies Azure AI Search and Foundry IQ tools through Foundry, plus an application multimodal function and selected tools discovered from an MCP server. The explicitly selected NL2SQL toolset is shown as an MCP example.](../media/runbooks/agent-tools.svg)](../media/runbooks/agent-tools.svg){: .runbook-diagram__image aria-label="Open full-size agent tools diagram"}

[Open full-size diagram](../media/runbooks/agent-tools.svg){: .runbook-diagram__open}

</div>

<span id="tools-available-to-the-agent"></span>

## Tools integrated in the reference application

| Integration | What the agent receives |
| --- | --- |
| Azure AI Search | A Foundry search tool targeting a configured index |
| Foundry IQ | Knowledge-base tools discovered through the official managed Foundry Toolbox integration |
| Multimodal retrieval | `multimodal_retrieve`, a function implemented in the application |
| Agent App MCP Server | Tools from the selected toolset; NL2SQL provides `nl2sql.list_sources()` and `nl2sql.query(source_id, question)` |

Search and Foundry IQ use the Foundry client integrations.
The application registers its multimodal function and the tool functions
discovered by its MCP client through Microsoft Agent Framework.
All four integrations are optional; enable only those you have prepared.

## Before you start

Have a working authenticated application and decide which operation or source
it should expose. The deployer prepares connections and scoped grants; the
runtime identity invokes services. Source owners approve the accessible data,
including any delegated-user requirements. Test with synthetic data before
giving the model access to a production tool.

Native capabilities are **off by default**: `SEARCH_RETRIEVAL_ENABLED`,
`FOUNDRY_IQ_ENABLED`, `MCP_ENABLED` and
`MULTIMODAL_ENABLED`. Select only the capabilities whose source, identity,
network and tool contracts are configured.

The multimodal tool flag is
different from custom ingestion `MULTIMODAL` and inline private attachments.
See [Application settings](application-settings.md#native-application-contract).

For the integrated server, select `DEPLOY_AGENT_APP_MCP=true` before provision.
The lifecycle derives MCP connection and caller authorization settings.
Select tools separately with `MCP_TOOLSETS`: default `[]` registers zero tools;
`["nl2sql"]` selects the current SQL toolset. This application/runtime setting
uses label `agent-lz`, not new tool-specific foundation parameters.

## Enable a supported capability

1. **Before provision**, prepare the chosen source/tool and its network path.
    For integrated MCP, use the [server selection procedure](agent-app-mcp.md#select-and-deploy);
    do not manually invent its endpoint, scope or caller allowlist.
2. For native retrieval capabilities, edit the platform root
    `main.parameters.json` at
    `parameters.additionalAppConfigurationSettings.value`, preserving existing
    entries. Use `name`, string `value` and `label: "agent-lz"` as shown in the
    canonical [agent capability procedure](application-settings.md#configure-an-agent-capability).
    These flags are not implicitly mapped azd environment variables.
3. Use only a capability with its required bindings:

    | Capability flag | Required runtime bindings | Preparation |
    | --- | --- | --- |
    | `SEARCH_RETRIEVAL_ENABLED` | `SEARCH_CONNECTION_ID`, `SEARCH_RAG_INDEX_NAME`; optional `SEARCH_RAGINDEX_TOP_K` | An authorized Foundry Search connection and populated index |
    | `FOUNDRY_IQ_ENABLED` | Platform-published `TOOLBOX_ENDPOINT` | [Foundry IQ source and connection](foundry-iq.md#how-to-connect-a-knowledge-base) |
    | `MULTIMODAL_ENABLED` | The [multimodal retrieval bindings](multimodality.md#extract-and-retrieve-figures) | Compatible index, models and invocation-local delegated Search authorization |

4. **Provision/deploy** with the matching
    [Bicep](deploy-full-stack.md#procedure) or
    [Terraform](deploy-terraform-full-stack.md#procedure) lifecycle.
    Changing these capability flags requires a new publication/worker restart:
    their composition is structural, not a functional hot reload.
5. **At runtime**, ask a question that needs the chosen source/tool. Verify
    an actual call, a grounded result and an unauthorized-user/source denial.
    A missing binding or required-tool outage must fail explicitly, not return
    a fabricated answer. Use safe trace correlation, not secret/argument dumps.

The shared native implementation composes these capabilities in the
orchestrator's `src/native/tools.py`. New tool implementations or changed
registration schemas need reviewed code and a compatible image, not just
another configuration key.

## How to add another Foundry tool

Use this procedure when the tool you need is not one of the supplied
integrations. Make source changes in
[Agent App Orchestrator](https://github.com/Azure/agent-app-orchestrator),
not in the platform repository or the chat UI.

1. **Choose the tool and integration path.** Start with Foundry's
    [supported tools](https://learn.microsoft.com/azure/foundry/agents/concepts/toolbox-overview#supported-tools)
    and follow the selected tool's setup guide. Check whether it supports
    direct integration, Toolbox or MCP. A sample for a portal-managed prompt
    agent is not automatically suitable for this application's code-defined
    agents.
2. **Check compatibility before editing.** Confirm the tool's requirements
    for model, region, API/SDK version, network access and preview status.
    Verify its invocation and authentication path for your selected
    [host](hosted-agents.md): Foundry Hosted or Azure Container Apps.
    If you support both, verify both separately. Do not copy Foundry-only
    invocation context into the Container Apps integration.
3. **Prepare the connection and permissions.** Create the resources and
    Foundry project connection required by that tool, if applicable.
    Grant the actual runtime caller only the necessary permissions.
    Preserve delegated-user authorization where the source requires it.
    A project connection alone does not register a callable tool.
    Use managed identity where supported. Keep required secrets in Key Vault.
4. **Wire the tool into the application.** Start at
    `src/native/tools.py::compose_tools()`, which builds the reference
    agent's tool list. Use the supported Foundry client integration or an
    authenticated Toolbox/MCP client.
    Keep custom implementation in focused tool/connector modules.
    Reuse an existing MCP path if it meets the tool's contract.
    Otherwise, add the required client and registration code.
    Check that the application's pinned SDK supports the integration.
    Not every catalog tool has a matching SDK helper.
5. **Add the required configuration and infrastructure.** If the integration
    introduces settings, add their validation and consumption in the component.
    Declare nonsecret runtime settings through the platform's
    [configuration procedure](application-settings.md#configure-an-agent-capability)
    with label `agent-lz`. Add any required resource, connection, network
    or scoped-grant provisioning before activation.
    Platform infrastructure changes must cover both Bicep and Terraform.
    An App Configuration entry alone does not implement a tool or load a secret.
6. **Test, build and deploy the customized component.** Verify registration,
    a real tool call, expected results, denied access and timeout/outage
    behavior. For tools that write to another system, also verify approval,
    idempotency and recovery. Follow
    [component customization and adoption](customize-components.md#how-to-make-and-adopt-a-source-change)
    to build a compatible image, pin the tested revision and deploy it
    through the platform lifecycle. For a code change, update the Hosted
    publication or Container Apps worker.
    Changing a tool in the portal does not publish the customized application.

Keep the previous tested component pins and settings for rollback. A tool
available in Foundry is not a validated reference-application integration
until its selected host, identity and source-access behavior are verified.

<span id="choose-the-extension-point"></span>

## Tools, Toolbox and knowledge

| Need | Integration boundary |
| --- | --- |
| Call an operation | A reviewed tool with a narrow schema and explicit authorization |
| Connect an MCP server | Registered MCP tools, authenticated transport and approved destination |
| Ground an answer | A configured Foundry IQ source or Search capability |
| Query approved Azure SQL or SQL Server data | NL2SQL tools hosted by Agent App MCP Server, with a Cosmos metadata catalog and read-only SQL principal |
| Wait for a person's decision | Native workflow human input, not a blocking tool socket |
| Change a process graph | Reviewed workflow definition and compatible publication |

A Foundry IQ `mcpServer` source is retrieval configuration, not automatically
a model-callable MCP tool. Its
[knowledge-source settings](foundry-iq.md#generic-mcp-knowledge-sources)
control source planning, output parsing and query credentials.

### Optional Agent App MCP Server

Agent App MCP Server exposes explicitly selected toolsets for Agents and
Workflows. Its available NL2SQL toolset provides `nl2sql.list_sources()` and
`nl2sql.query(source_id, question)`.

`DEPLOY_AGENT_APP_MCP=true` selects server compute and authentication.
`MCP_TOOLSETS=["nl2sql"]` selects the application Cosmos catalog and
model/declared-secret access. Search and document ingestion remain independent.

The operator still approves SQL destinations, read permissions and metadata.
The server's NL2SQL implementation—not the orchestrator—owns SQL connectivity,
metadata retrieval and generated-query validation. Operators import approved
metadata through the separate administrative importer.

The configured read-only principal queries the application's approved dataset,
without automatic per-user SQL delegation. This differs from a Foundry IQ
`fabricDataAgent` source, where Fabric owns execution.
Follow [Agent App MCP Server](agent-app-mcp.md) for deployment and
[NL2SQL](nl2sql.md) for source contracts, result limits and denial checks.

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

Agent App MCP Server uses a dedicated Entra API audience. The actual Hosted
or Container Apps caller must have the `MCP.Invoke` application role and an
allowed client ID. The platform coordinates that connection and authorization.
An API key, Foundry call ID, Cosmos/SQL token or browser user-context JSON does
not authenticate this server. SQL access is application-level, not delegated
end-user access.

For other reviewed MCP integrations, use their own supported authentication
and source-authorization contracts. A Foundry Toolbox connection and a
Foundry IQ MCP knowledge source do not replace the integrated server's contract.

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
Native Foundry IQ uses the official MAF `FoundryToolbox` integration rather
than a parallel token-forwarding client. It forwards the current request's
Foundry call ID so that the service can resolve downstream user authorization.
Do not fabricate platform context or assume the browser's Authorization
header arrives unchanged inside a Hosted container.

Provisioning registers and promotes the knowledge-base Toolbox after Search
setup, then publishes the derived `TOOLBOX_ENDPOINT` under `agent-lz`.
This internal binding is not another operator authentication choice.

With OBO enabled, the managed service handles delegated knowledge-base access
subject to consent and source permissions. Without OBO, component identities
may access sources that accept service authentication, subject to scoped grants.
There is no Blob-only capability allowlist. A tool requiring user delegation
fails at invocation when OBO is unavailable, without blocking startup solely
because its source type is enabled.
Changing the operator mode must not silently change a protected source's
audience or cause a privileged retry after user denial.

Managed consent requests produce explicit UI `consent_required` errors.
The UI does not accept dynamic consent links or implement automatic consent
resumption. Complete the approved Foundry consent process and retry manually.
In service mode, an explicit consent request instead returns
`user_delegation_required`, directing the operator to enable OBO.

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

Toolset selection is startup-scoped: provision matching dependencies and
restart/redeploy after a change. See the [server selection and lifecycle](agent-app-mcp.md#select-and-deploy)
for validation, extension and retention requirements.

<span id="recover-or-undo"></span>

## Failure boundaries

Missing tools can mean the application never registered them.
Authentication failures concern the client, connection and source separately.
Retain the authenticated caller boundary during recovery rather than
substituting service identity or silently dropping a required capability.
