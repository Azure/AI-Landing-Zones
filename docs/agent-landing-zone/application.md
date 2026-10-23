<span id="configure-the-application"></span>

# Agent Application

Agent Application is the customizable reference app supplied by Agent Landing Zone.
It includes Agent App UI, Agent App Orchestrator and optional Agent App Ingestion.
These guides focus on the orchestrator in Foundry Agent Service, with the UI in
Azure Container Apps. Start with a [full stack deployment](deploy-full-stack.md),
then choose a task below. To deploy a customer-owned application instead, use
[Bring your own app](build-your-own-app.md).

## Choose a task

### Agent hosting

Use [Agent hosting](hosted-agents.md) to choose where the orchestrator runs and
understand image deployment, runtime access and how clients call the agent.

### Frontend

| I want to | Guide |
| --- | --- |
| Control who can sign in and which documents they can retrieve | [Sign-in and document access](application-auth.md) |
| Put the chat interface inside an existing portal | [Embed chat](embed-chat.md) |
| Collect ratings and comments | [User feedback](user-feedback.md) |

### Ingestion

Use [Ingestion and conversation uploads](ingestion.md) to choose how documents
enter the shared collection and how users attach files to a chat.

### Grounding

| I want to | Guide |
| --- | --- |
| Answer questions from my documents or an existing knowledge base | [Foundry IQ](foundry-iq.md) |
| Use Microsoft 365 knowledge | [Work IQ](work-iq.md) |
| Connect Fabric data, including a data agent over a semantic model | [Fabric IQ](fabric-iq.md) |
| Answer questions from SharePoint content | [SharePoint](sharepoint.md) |

### Capabilities and extensions

| I want to | Guide |
| --- | --- |
| Work with images, documents or voice | [Multimodality](multimodality.md) |
| Ask questions about structured data | [NL2SQL](nl2sql.md) |
| Add an agent tool or connect an MCP server | [Tools and MCP](agent-tools.md) |

Each guide identifies the features integrated into Agent Application, their
supported hosted path and any additional setup or development required.

## Know what you are changing

**Deployment inputs** select Azure resources and application components.
Set them in the selected `azd` environment before the deployment step that reads
them. **Runtime settings** configure application behavior, typically through
Azure App Configuration with label `agent-lz`. The
[configuration reference](configuration.md) distinguishes the two.

**Knowledge sources** supply content through a Foundry IQ knowledge base.
**Tools** let the agent call an additional service or operation. Configure
retrieval sources and callable tools separately. Start with
[Foundry IQ](foundry-iq.md) for knowledge or
[Tools and MCP](agent-tools.md) for an additional operation.

Follow the activation steps in the relevant guide, then verify the change
through the running agent. Before granting access to real data, confirm that
an authorized user can retrieve it and an unauthorized user cannot.
