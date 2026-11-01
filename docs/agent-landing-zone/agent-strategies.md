# Agents & prompts

Microsoft Agent Framework (MAF) provides two application building blocks:
an **Agent** for a conversation and a **Workflow** for a process with explicit
steps, conditions and human input. Hosting and tools are separate choices.
Creating a prompt agent in the Foundry portal does not replace the application
code, its instructions or its registered tools.

## Choose the application experience

`APPLICATION_MODE` selects the experience. The default is `conversational`.
Use the [deployment configuration](configuration.md#native-execution-selection)
to change the selection; this is not a per-message switch.

| Value | Experience |
| --- | --- |
| `conversational` | A MAF Agent answers questions and uses authorized tools. |
| `workflow` | A published MAF Workflow executes a named process and can wait for human input. |
| `both` | The UI offers conversation and a named process. On Hosted, these are two separate publications. |

`ORCHESTRATION_HOST` selects `hosted` or `container_apps`.
[Agent hosting](hosted-agents.md) explains the distinct native integrations
and their state ownership. Neither mode selects a retrieval strategy.
The UI presents the task, not a hosting or strategy picker.

## Choose capabilities independently

MCP, Foundry IQ and Azure AI Search are tools or retrieval capabilities, not
alternative agent implementations. An agent and a workflow can use the same
authorized capability when it is registered in their definitions.

- Use [Foundry IQ](foundry-iq.md) for a knowledge base over native or
  independently indexed sources.
- Use [Tools & MCP](agent-tools.md) for reviewed operations and downstream
  identity requirements.
- Use [NL2SQL](nl2sql.md) to understand the difference between database
  execution and a remote Fabric data agent.
- Use [Document formats & images](multimodality.md) to distinguish document
  processing from direct image input in chat.

A source, model or MCP endpoint in configuration does not automatically make
that capability available. Its definition, permissions and network path must
all be present. Instructions cannot grant document access or turn a retrieval
source into a model-callable operation.

## Configure instructions

Keep agent instructions and workflow definitions with the reviewed application
source. Publish a compatible image when changing code, graph structure,
executor identifiers or packaged prompts.

Use [App Configuration](application-settings.md) for supported functional
parameters, not arbitrary graph replacement or credentials in prompts.
A running workflow retains its functional configuration snapshot; a new
configuration value does not rewrite a process that is already waiting.
Current authorization is checked separately on every interaction.

## Configure and test behavior

1. Select the application mode and host, then verify the required dependencies.
2. Keep instructions focused on task, grounding, citations and tool use.
   Never include user tokens, credentials or private configuration in prompts.
3. Test a representative answer, required-source failure, denied user and
   cancellation. For workflows, also test pending human input, reconnect,
   rejection and a stale or duplicate reply.
4. Follow [Customize components](customize-components.md) and the
   [deployment guide](deploy-full-stack.md) for reviewed source and image
   deployment.

For process operation, see [Workflows & human input](workflows.md).
For caller boundaries, see [Sign-in & access](application-auth.md) and
the [API reference](application-api.md).
