# Strategies & prompts

A strategy defines how the orchestrator uses a model, retrieves knowledge and
calls tools. Choose one for the task and hosting mode, then configure its
dependencies and instructions. Creating a prompt agent in the Foundry portal
does not replace the strategy running inside the application.

## Choose a strategy

Set `AGENT_STRATEGY` through [Application settings](application-settings.md).
The runtime default is `maf_lite`. A sample configuration is not the effective
setting in your deployment.

| Strategy key | When to use it | Hosting |
| --- | --- | --- |
| `maf_lite` | Microsoft Agent Framework orchestration with direct Azure OpenAI model access and configured retrieval. | Container Apps or Foundry hosted |
| `maf_agent_service` | Microsoft Agent Framework orchestration backed by Foundry Agent Service. | Container Apps or Foundry hosted |
| `single_agent_rag` | Foundry Agent Service orchestration with intent routing and direct-model paths. | Container Apps or Foundry hosted |
| `mcp` | A request-scoped agent that loads callable tools from an MCP server. | Container Apps or Foundry hosted, with the hosted call-context requirement |
| `multimodal` | Image-aware grounding from the classic Search pipeline. Foundry IQ supplies text grounding instead. | Container Apps only |
| `nl2sql` | Generate, validate and execute read-only SQL over configured SQL databases or Fabric SQL endpoints. | Container Apps only |

Use the exact keys above. `multiagent` is not registered, and `rag` and
`multimodal_rag` are not accepted aliases. Hosted execution rejects unsupported
strategies rather than falling back to another one.
[Agent hosting](hosted-agents.md) explains the execution and state boundaries.

### Choose retrieval separately

`RETRIEVAL_BACKEND` selects `ai_search` or `foundry_iq` for the shared
knowledge-search connector and the MAF Lite, MAF Agent Service and multimodal
context providers. It does not replace every strategy's tools or datasources.
For example, `nl2sql` uses its SQL metadata indexes and database connections,
not a Fabric data-agent knowledge source.

- Use [Foundry IQ](foundry-iq.md) for a knowledge base over native or existing
  indexed sources.
- Use [Tools & MCP](agent-tools.md) for callable operations.
- Use [NL2SQL](nl2sql.md) to choose between direct SQL execution and a remote
  Fabric data agent.
- Use [Document formats & images](multimodality.md) to understand document
  image processing without assuming direct image chat.

The shared strategy base requires `AI_FOUNDRY_PROJECT_ENDPOINT`,
`AI_FOUNDRY_ACCOUNT_ENDPOINT` and `CHAT_DEPLOYMENT_NAME`, even when the strategy
calls the model directly. Classic execution also needs its conversation
database. Retrieval, tools, SQL and prompt storage have their own permissions
and connectivity requirements.

## Configure prompts

`PROMPT_SOURCE` defaults to `file`. File-backed prompts are part of the
orchestrator image, so changing them is an application customization, not a
portal prompt edit.

| Strategy | Bundled prompt location in the orchestrator |
| --- | --- |
| `maf_lite`, `maf_agent_service` | `src/prompts/maf/main.txt` |
| `single_agent_rag` | `src/prompts/single_agent_rag/main.jinja2` |
| `mcp` | `src/prompts/mcp/main.txt` |
| `multimodal` | `src/prompts/multimodal/main.txt` |
| `nl2sql` | `src/prompts/nl2sql/triage_agent.txt`, `sqlquery_agent.txt` and `syntetizer_agent.txt` |

The plain-text loader substitutes supplied `{{placeholders}}` and can resolve
remaining placeholders from common prompt files. An unresolved placeholder
can remain in the prompt with a warning, so inspect the rendered instructions
when customizing. Jinja templates support conditional instructions and use
strict undefined-variable handling. The single-agent RAG strategy explicitly
requires its Jinja template.

Classic execution also supports `PROMPT_SOURCE=cosmos`. It reads the `prompts`
container using IDs such as `<namespace>_<prompt-name>` and the document's
`content` field. Common placeholders use `placeholder_<name>` documents.
The MAF strategies share the `maf` namespace. File templates are not
automatically uploaded or rendered by selecting Cosmos.

**Foundry hosted execution requires file-backed prompts.** Selecting Cosmos
prompts fails construction. The hosted container does not use classic Cosmos
conversation state or profile memory. Automatic profile access is also
suspended by the shared base in classic execution, so conversation history
does not imply cross-conversation personalization.

## Change instructions safely

1. Select the supported hosting and strategy combination.
2. Review the strategy's dependencies and the effective
   [runtime settings](application-settings.md).
3. Keep instructions focused on task, grounding, citations and tool use.
   Do not put credentials, user tokens or private configuration in prompts.
4. For bundled prompt changes, follow
   [Customize components](customize-components.md) and deploy the reviewed
   image through the [deployment runbook](deploy-full-stack.md).
5. Start a new hosted version for hosted settings or image changes. Restart
   affected classic processes after changing strategy or cached dependencies.
6. Check a representative question, a required-source failure and an
   unauthorized-user case. Use [Monitoring & audit](application-monitoring.md)
   to correlate activity without capturing sensitive prompt content.

Instructions cannot grant source access, make an absent tool available, enforce
read-only database permissions or approve a write operation. Those controls
belong at the service and tool boundaries.
[Application authentication](application-auth.md) covers sign-in and delegation.
Request formats belong in the [API reference](application-api.md).
