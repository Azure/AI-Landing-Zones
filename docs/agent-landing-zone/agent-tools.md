# Agent tools

Customize Agent Application's orchestrator with an MCP tool or a code-defined
strategy, then deploy a new Foundry hosted agent version. The result is a tool
available to Agent Application, not a portal-only change to a prompt agent.

## Choose the extension point

| Need | Where to change it |
| --- | --- |
| Add an action the model can call | Implement a tool in your MCP server, or register a function in a custom orchestrator strategy. |
| Change reasoning, instructions or tool selection | Change the orchestrator strategy in your fork. |
| Add information for knowledge-base retrieval | Configure a Foundry IQ knowledge source; see [Foundry IQ](foundry-iq.md). |

An MCP **tool** and an MCP **knowledge source** are different
contracts. `AGENT_STRATEGY=mcp` discovers callable tools from an MCP server.
`FOUNDRY_IQ_MCP_SOURCES_JSON` describes sources used by the knowledge base; it
does not register arbitrary actions on Agent Application's orchestrator.

Foundry supports [MCP tools and Toolbox connections](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/tools/model-context-protocol?view=foundry).
That platform capability does not mean every Agent Application strategy loads
those connections. [Hosted agents run your containerized code](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/hosted-agents?view=foundry):
editing tools or instructions in the Foundry portal does not change the
source-created hosted orchestrator's code.

## Before you start

- Have a working [hosted Agent Application](hosted-agents.md) and a nonproduction
  environment for testing.
- Use the [custom application and source-pin workflow](build-your-own-app.md)
  to fork the orchestrator and retain reproducible source commits and image
  digests. Do not patch generated build directories.
- Arrange permission to deploy agent versions, update Agent Application's App
  Configuration settings, and have an authorized administrator grant narrowly
  scoped runtime access when required.
- For MCP, have a server reachable from the hosted runtime, a documented
  authentication contract, and a small, reviewed set of tools. Start with a
  read-only operation; do not expose an unrestricted production action catalog.

## 1. Check what the hosted strategy loads

The shipped hosted allowlist is `single_agent_rag`, `maf_lite`,
`maf_agent_service` and `mcp`. Registration in the strategy factory alone is
not enough: the hosted guard rejects strategies outside that list.
`multimodal` and `nl2sql` are registered for the classic runtime but are not
admitted by the hosted guard.

The shipped `mcp` strategy opens one configured server **for each request**,
discovers its functions, wraps them for audit, and supplies them to a local
Microsoft Agent Framework `ChatAgent` inside the hosted container. It does not
load MCP prompts, provide a configurable tool allowlist, or merge a list of
servers. Limit the server's exposed tools or implement filtering in your fork.
The other hosted strategies do not become general MCP action loaders when you
set `MCP_APP_ENDPOINT`.
If you need both Agent Application's knowledge-base retrieval and a new action,
extend the retrieval strategy in your fork rather than assuming that switching
to `mcp` preserves its retrieval behavior.

Hosted `mcp` also requires a validated Foundry call ID. It forwards that
platform-provided ID for Toolbox to resolve the caller; it fails closed when
the context is missing. Use Agent Application's delegated Foundry invocation
path, not a direct container request with a fabricated identity header.

## 2. Configure the MCP connection

In Agent Application's **Azure App Configuration → Configuration explorer**,
create or update these nonsecret keys with label **`agent-lz`**. This example
uses an illustrative server; substitute your reviewed endpoint and its
supported transport.
Record the previous values and labels before changing them so you can undo
the switch. Keep deployment inputs separate from these runtime settings.

| Key | Example | Shipped contract |
| --- | --- | --- |
| `AGENT_STRATEGY` | `mcp` | Selects the MCP strategy rather than adding tools to another strategy. |
| `MCP_APP_ENDPOINT` | `https://tools.example.com` | Server URL; not an agent ID, project endpoint or resource name. |
| `MCP_SERVER_TRANSPORT` | `streamable_http` | `sse` (default) or `streamable_http`. |
| `MCP_CLIENT_TIMEOUT` | `600` | Positive integer, in seconds. |

These are flat runtime settings, not a `servers` JSON document. Using the
shipped `.env.sample` names:

```dotenv
AGENT_STRATEGY=mcp
MCP_APP_ENDPOINT=https://tools.example.com
MCP_SERVER_TRANSPORT=streamable_http
MCP_CLIENT_TIMEOUT=600
```

For Streamable HTTP, the client appends `/mcp` unless already present. For SSE,
it appends `/sse`. A URL ending in the other transport's path is rejected.
Do not assume Agent Application's default SSE transport matches your server.
Local development has a separate behavior: the strategy overrides the endpoint
to `http://localhost:5000` outside Azure.

If the server requires the client's supported API-key header, store the secret
in Key Vault and create an App Configuration **Key Vault reference** named
`MCP_APP_APIKEY`, also labeled `agent-lz`. The client sends it as `X-API-KEY`.
Never paste the key into a command, source file, `.env` committed to Git, or
ordinary App Configuration value.

The shipped connector does not perform arbitrary server OAuth flows or forward
the incoming `Authorization` header. A server requiring a different
authentication mechanism needs a compatible, reviewed connector change, not
just a portal connection or a new setting name.

## 3. Authorize and connect safely

1. Identify the **actual deployed agent runtime principal**. It is not
   automatically the project's managed identity or the deployment principal.
   Use [Hosted agents](hosted-agents.md) for runtime access and bootstrap recovery.
2. If you added `MCP_APP_APIKEY`, grant that runtime principal secret-read
   access to the individual Key Vault secret and ensure it can reach the vault.
   Agent Application's bootstrap handling of `AUDIT_HMAC_KEY` does not grant
   access to every new secret. App Configuration stores a reference; the
   agent runtime retrieves the secret using its own credentials
   ([Key Vault reference behavior](https://learn.microsoft.com/azure/azure-app-configuration/use-key-vault-references-dotnet-core)).
3. Confirm DNS, TLS and outbound connectivity from the hosted runtime to the
   exact MCP hostname and port. For an isolated deployment, follow
   [Network isolation](network-isolation.md); connectivity from your laptop
   does not prove hosted egress. Do not disable TLS validation to fix a failure.
   Review what prompts, arguments and results can leave Agent Application through
   this server; approve the destination before sending protected data.
4. Define authorization at the tool or downstream service. A call ID, API key
   or propagated identity does not by itself enforce source document ACLs.
   Preserve delegated user/OBO handling and test permitted and denied data
   access. Never replace a denied user request with service-identity retrieval.

## 4. Add code when configuration is not enough

For a custom function or orchestration flow, work in your orchestrator fork:

1. Implement the function and register it on the agent constructed by your
   strategy. Reuse existing strategy and connector modules rather than adding
   an unrelated tool loader. Give each tool a narrow input schema, explicit
   authorization, bounded output and safe failure behavior.
2. For a new strategy, register its key in
   `src/strategies/agent_strategy_factory.py` and explicitly review hosted
   eligibility in `src/strategies/hosted_strategies.py`. Merely adding the key
   to the allowlist does not make classic dependencies hosted-compatible.
   Keep hosted execution stateless; do not introduce classic Cosmos-backed
   conversation state.
3. Extend the existing MCP/strategy tests to cover discovery and invocation,
   caller isolation, denial, timeout, cancellation and cleanup. For write
   actions, implement authorization and an explicit approval policy before
   enabling them; the shipped MCP strategy has no configured approval gate.
4. Coordinate any new runtime setting with the platform configuration that
   publishes it, plus any UI or server contract changes. Record compatible
   component commits, update the consuming manifest pins, and retain the
   previous compatible combination for rollback. Follow
   [Build your own application](build-your-own-app.md) for the pin workflow.

## 5. Deploy and verify

The runtime caches App Configuration in process; these steps do not assume
live reload. After changing settings or secrets, deploy a new hosted version
so that a fresh process loads them. Do not restart an orchestrator Container
App as a substitute for updating the hosted agent.

For changed orchestrator source, prepare a new image from the updated pin,
provision its immutable-digest handoff, then deploy the agent version using
[the full-stack deployment runbook](deploy-full-stack.md).
For settings-only changes, a new version can reuse the same compatible digest;
see [Hosted agents](hosted-agents.md). Keep deployment-managed values aligned
with their provisioning inputs: a later provisioning run can overwrite
manual settings.

Verify through signed-in Agent Application:

1. Ask for the read-only tool's specific operation. Confirm the downstream
   server received the expected call and the answer reflects its result;
   model-generated text alone is not proof of invocation.
2. Inspect Agent Application telemetry for the selected strategy, MCP transport,
   tool count and request status. Do not log credentials, full user-context
   headers or sensitive tool arguments to diagnose a failure.
3. Repeat as a user without permission. Expect denial without protected data
   in the answer, citations or tool output.
4. Test a server outage and a timeout. Expect an explicit failed request,
   not a success answer fabricated without the required tool.

## Recover or undo

| Symptom | Check or recovery |
| --- | --- |
| Unsupported strategy | Restore a hosted-eligible key. A classic strategy is not enabled by portal configuration. |
| Missing Foundry call context | Restore the delegated Foundry invocation path. Do not supply a guessed call ID or fall back to service identity. |
| No tools or connection failure | Check the server's exposed functions, transport/path, DNS, egress and TLS. |
| Authentication or secret-read denial | Check the server's expected header, Key Vault reference label, runtime principal and secret-scoped permission. |
| Old behavior after a change | Confirm source pins, prepared digest and deployed version; deploy a fresh version after runtime configuration changes. |

For upgraded environments, inspect existing service-specific/legacy labels if
the new `agent-lz` value appears ignored. The pinned orchestrator still selects
those labels as well; do not create competing copies of the same setting.

To undo, restore the prior runtime values and compatible source pins/image,
then redeploy using the same workflow. Confirm Agent Application invokes the
intended version before removing obsolete tools, credentials or grants.
Keep the old server contract available until rollback is no longer needed.
