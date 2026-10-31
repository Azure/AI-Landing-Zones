<span id="agent-tools"></span>

# Tools & MCP

Foundry tools let an agent call approved operations. A Toolbox groups configured
tools and their connections. An MCP server exposes operations through Model
Context Protocol. A Foundry IQ knowledge base instead supplies retrieved
grounding. These are different integration boundaries.

The supplied `mcp` strategy can consume an MCP server. Other strategies do not
automatically load a portal-managed tool list. This page explains that choice
and the separate hosted authorization contract. Deployment and redeployment
follow the [full-stack deployment guide](deploy-full-stack.md).

<span id="choose-the-extension-point"></span>

## Tools, Toolbox and knowledge

| Need | Integration boundary |
| --- | --- |
| Call a service operation | A reviewed Foundry tool or Toolbox connection, consumed by the application. |
| Ground answers in documents | A Foundry IQ knowledge source bound to the knowledge base. |
| Change instructions or orchestration | Hosted orchestrator source and its configured prompts. |

Select a supported [strategy and prompt source](agent-strategies.md) before
configuring tools. A Foundry IQ `mcpServer` source is retrieval configuration,
not `AGENT_STRATEGY=mcp`. Its separate
[MCP knowledge-source settings](foundry-iq.md#generic-mcp-knowledge-sources)
control source planning, output parsing and query credentials.

Foundry supports [MCP tools](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/tools/model-context-protocol?view=foundry)
and [Toolbox connections](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/toolbox).
Creating either in the portal does not make the default Agent Application
consume it.

<span id="before-you-start"></span>
<span id="1-check-what-the-hosted-strategy-loads"></span>

## Supplied hosted execution

The default `maf_lite` orchestrator constructs a Microsoft Agent Framework
agent inside the hosted container. It calls the configured model deployment
directly and uses a Foundry IQ context provider for knowledge-base retrieval.
It does not read a portal-managed prompt agent's tool list or automatically
instantiate `FoundryToolbox`.

[Hosted agents run containerized application code](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/hosted-agents?view=foundry).
Foundry hosts that code and authenticates invocation, but code defines its
model, instructions, tool registration and retrieval behavior.
A portal tool attachment alone therefore does not change the running
`maf_lite` orchestration.

<span id="2-configure-the-mcp-connection"></span>
<span id="3-authorize-and-connect-safely"></span>

## Configure the MCP strategy

Select `AGENT_STRATEGY=mcp` and configure the following through
[Application settings](application-settings.md). The strategy creates its agent
and MCP connection for the request rather than sharing a tool session between
users.

| Setting | Default | Purpose |
| --- | --- | --- |
| `MCP_APP_ENDPOINT` | `http://localhost:80` in detected Azure execution | Trusted server base URL. Outside detected Azure execution, the runtime overrides it with `http://localhost:5000`. |
| `MCP_SERVER_TRANSPORT` | `sse` | `sse` or `streamable_http`. |
| `MCP_CLIENT_TIMEOUT` | `600` seconds | Positive integer connection/read timeout. |
| `MCP_APP_APIKEY` | Unset | Optional `X-API-KEY`, stored as a Key Vault reference. |
| `AGENT_ID` | Unset | Optional agent ID passed when constructing the request-scoped agent. |

Azure detection checks for `CONTAINER_APP_NAME` or `WEBSITE_INSTANCE_ID` in the
process environment. For local work, run the MCP server on port `5000`.
In Azure, configure the actual trusted destination and confirm the execution
environment is detected as intended. Use HTTPS outside controlled local work.

The client appends `/sse` for SSE or `/mcp` for Streamable HTTP exactly once.
An endpoint ending in the conflicting transport suffix is rejected.
For example, `https://mcp.contoso.com` resolves to
`https://mcp.contoso.com/sse` with the default transport.

The client sends a serialized `user-context` header and the optional API key.
The receiving service must authenticate the request and authorize its
operations. User-context fields alone are not verified downstream identity.
This client does not apply the trusted-host allowlist used by generic Foundry
IQ MCP sources. Review the destination, egress, data handling and permissions
before enabling it.

### Hosted MCP call context

Hosted `mcp` additionally requires the platform's valid
`x-agent-foundry-call-id`, including on response-management routes. Missing or
malformed context is rejected with `401`. The runtime forwards the validated
opaque call ID to the tool server. It does not turn that ID into a user token
or grant downstream consent.

The hosted Toolbox integration resolves the caller through that platform
context. Do not fabricate a call ID, substitute caller-supplied group IDs, or
fall back to the workload identity when caller authorization is required.
See [Application authentication](application-auth.md) and the
[API reference](application-api.md) for the invocation boundary.

## Authenticated Toolbox contract

Microsoft's [hosted Toolbox integration](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/use-toolbox-hosted-agent)
uses an authenticated `FoundryToolbox` software development kit (SDK) client
with platform-provided hosted call context. The application must actually invoke that client, with
the appropriate connection, tool authorization and source permissions.
An endpoint string or a forwarded call ID without client authentication is
not a complete integration.

The supplied `maf_lite` knowledge-base path uses integrated UI OBO and native
Search permission enforcement instead of this Toolbox client. It forwards a
Search-audience delegated token through Foundry's supported custom-header
contract. No customer-written Toolbox integration is needed for that path.
[Agent Application access](application-auth.md#3-verify-the-retrieval-identity-boundary)
describes the separate invocation and retrieval credentials.

Arbitrary tools still require their own authenticated integration. A Search
token cannot be reused as a generic MCP user assertion. Caller-supplied group
IDs, fabricated platform call IDs and a prompt instruction do not authorize a
tool or its source data.

Knowledge-base MCP source configuration is separate from callable agent tools.
`FOUNDRY_IQ_MCP_SOURCES_JSON` describes sources consumed by the knowledge-base
connector. It does not register a model-callable Toolbox in `maf_lite`.
[Foundry IQ](foundry-iq.md) describes retrieval configuration.

<span id="4-add-code-when-configuration-is-not-enough"></span>

## Application extension boundary

A custom integration belongs in the orchestrator's existing strategy and
connector modules, with a narrow tool schema, explicit caller authorization,
bounded results, timeout/cancellation handling and safe failures. Write actions
also need an explicit approval policy. A prompt instruction is not an
authorization or approval control.

The runtime principal needs narrowly scoped dependency grants. Secrets remain
in Key Vault, not tool definitions or ordinary App Configuration values.
The standard bootstrap covers its declared configuration/model/audit access
and scoped Search transport access for native retrieval. That transport role
does not replace end-user source authorization. Extra tool access needs its
own narrowly scoped grants.
[Agent hosting](hosted-agents.md) explains the identities.
Private tools also depend on DNS, TLS and authorized egress from the actual
hosted network path. Tool destinations receive application data and require
data-handling approval.

[Bring your own app](build-your-own-app.md) describes source pins and capability
profiles for custom code. New runtime settings are cross-component contracts
with the platform that publishes them and every consuming component.

<span id="5-deploy-and-verify"></span>

## Deployment and evidence

Changed orchestrator source requires a new image from the reviewed source pin,
an immutable-digest handoff and a new agent version. Runtime settings are
cached at startup, so settings-only changes also require a new hosted version,
potentially reusing the compatible digest.
[Application settings](application-settings.md) explains runtime values and
[Deployment settings](configuration.md) explains deployment inputs.

Evidence includes an actual tool call and result, denied-user isolation,
timeout/outage behavior and no invented result when a required tool fails.
Logs and traces can identify calls without retaining credentials, sensitive
arguments or full caller-context headers. Portal registration or successful
deployment alone does not establish this behavior.
[Monitoring & audit](application-monitoring.md) covers operational evidence.

<span id="recover-or-undo"></span>

## Failure boundaries

Missing tools can indicate that the code never registered or invoked them,
not just a connection failure. Authentication failures concern the client,
connection and downstream permissions separately. Stale behavior can indicate
a cached process or the wrong deployed version. Recovery retains the
authenticated caller boundary and the previous compatible source/image
combination rather than bypassing authorization.
