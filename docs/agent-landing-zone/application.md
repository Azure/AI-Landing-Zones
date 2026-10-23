# Configure the application

These guides focus on the bundled application when its orchestrator runs in
Foundry Agent Service, with the web UI in Azure Container Apps. Start with a
[full stack deployment](deploy-full-stack.md), then choose the task below.
To deploy a different application, use [Bring your own app](build-your-own-app.md).

## Choose a task

| I want to | Guide |
| --- | --- |
| Control who can sign in and which documents they can retrieve | [Sign-in and document access](application-auth.md) |
| Put the chat interface inside an existing portal | [Embed chat](embed-chat.md) |
| Work with images, documents or voice | [Multimodality](multimodality.md) |
| Ask questions about structured data | [NL2SQL](nl2sql.md) |
| Collect ratings and comments | [User feedback](user-feedback.md) |
| Answer questions from my documents or an existing knowledge base | [Foundry IQ](foundry-iq.md) |
| Use Microsoft 365 knowledge | [Work IQ](work-iq.md) |
| Connect Fabric data, including a data agent over a semantic model | [Fabric IQ](fabric-iq.md) |
| Answer questions from SharePoint content | [SharePoint](sharepoint.md) |
| Add an agent tool or connect an MCP server | [Tools and MCP](agent-tools.md) |

Each guide identifies the supported hosted path and any feature-specific
requirements. A capability available in Microsoft Foundry is not automatically
enabled in the bundled application.

## Know what you are changing

**Deployment inputs** select Azure resources and the application composition.
Set them in the selected `azd` environment before the deployment step that reads
them. **Runtime settings** configure application behavior, typically through
Azure App Configuration with label `agent-lz`. The
[configuration reference](configuration.md) distinguishes the two.

**Knowledge sources** supply evidence through a Foundry IQ knowledge base.
**Tools** let the agent call an additional service or operation. Adding a
knowledge source does not register an agent tool, and registering a tool does
not ingest documents. Start with [Foundry IQ](foundry-iq.md) for knowledge or
[Tools and MCP](agent-tools.md) for an additional operation.

Use the activation and verification steps in the relevant guide. Saving a
setting or editing a Foundry resource alone does not prove the running hosted
agent is using the change. Before granting access to real data, verify the
result with both an authorized and an unauthorized user.
