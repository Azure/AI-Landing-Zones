# Agent tools

Foundry tools let an agent call approved operations. A Toolbox groups configured
tools and their connections; an MCP server exposes operations through Model
Context Protocol. A Foundry IQ knowledge base instead supplies retrieved
grounding. These are different integration boundaries.

This page describes native Foundry integration and the supplied application's
limits. Deployment and redeployment follow the
[Deploy full stack runbook](deploy-full-stack.md); a custom tool integration
requires application development.

<span id="choose-the-extension-point"></span>

## Tools, Toolbox and knowledge

| Need | Integration boundary |
| --- | --- |
| Call a service operation | A reviewed Foundry tool or Toolbox connection, consumed by the application. |
| Ground answers in documents | A Foundry IQ knowledge source bound to the knowledge base. |
| Change instructions or orchestration | Hosted orchestrator source and its configured prompts. |

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

## Authenticated Toolbox contract

Microsoft's [hosted Toolbox integration](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/use-toolbox-hosted-agent)
uses an authenticated `FoundryToolbox` software development kit (SDK) client
with platform-provided hosted call context. The application must actually invoke that client, with
the appropriate connection, tool authorization and source permissions.
An endpoint string or a forwarded call ID without client authentication is
not a complete integration.

The supplied hosted entry point initializes `user_context={}` and does not
pass the caller's bearer token into default retrieval. UI OBO to Foundry is
not an automatic OBO exchange inside the container. Protected knowledge-base
or tool access therefore needs a reviewed authenticated integration, as
described in [Agent Application access](application-auth.md#3-verify-the-retrieval-identity-boundary).
Caller-supplied group IDs, fabricated platform call IDs and browser bearer
forwarding do not satisfy that contract.

Knowledge-base MCP source configuration is separate from callable agent tools.
`FOUNDRY_IQ_MCP_SOURCES_JSON` describes sources consumed by the knowledge-base
connector; it does not register a model-callable Toolbox in `maf_lite`.
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
The standard bootstrap covers only its declared configuration/model/audit
access; extra tool or source access needs separate grants.
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
potentially reusing the compatible digest. [Deployment settings](configuration.md)
distinguishes runtime settings from deployment inputs.

Evidence includes an actual tool call and result, denied-user isolation,
timeout/outage behavior and no invented result when a required tool fails.
Logs and traces can identify calls without retaining credentials, sensitive
arguments or full caller-context headers. Portal registration or successful
deployment alone does not establish this behavior.

<span id="recover-or-undo"></span>

## Failure boundaries

Missing tools can indicate that the code never registered or invoked them,
not just a connection failure. Authentication failures concern the client,
connection and downstream permissions separately. Stale behavior can indicate
a cached process or the wrong deployed version. Recovery retains the
authenticated caller boundary and the previous compatible source/image
combination rather than bypassing authorization.
