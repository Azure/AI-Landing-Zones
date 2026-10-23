# Fabric data

Use a Fabric data agent to answer analytical questions over an existing Power BI
semantic model. The model stays in Fabric; this is live querying, not document
ingestion.

!!! warning "Hosted integration requires custom work"
    Hosted Agent Application does **not** currently provide an end-to-end,
    configuration-only connection to a Fabric data agent. The platform can
    register the knowledge source, but the native retrieval connector requires a
    delegated user token. The shipped hosted entry point does not supply that
    token. Enabling the source alone does not make hosted answers use Fabric.

## Choose the connection

For a customer who already has a semantic model and a Fabric data agent, keep
that data agent. An ontology is not required.

- **Fabric data agent:** queries the selected data, including semantic models,
  and returns analytical answers. Foundry IQ supports a remote
  `fabricDataAgent` knowledge source for it.
- **Fabric IQ ontology:** defines business entities and relationships bound to
  data. Its separate `fabricOntology` knowledge source expects an ontology item,
  not a semantic model ID or a data agent ID.

Fabric IQ is the broader business-context capability, not an endpoint that can
be pasted into Agent Landing Zone. See the official
[data agent knowledge source](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-fabric-data-agent)
and [ontology knowledge source](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-fabric-ontology)
guides.

## 1. Prepare and verify the Fabric agent

1. Confirm that the workspace uses paid **F2 or higher**, or **Power BI Premium
   P1 or higher** with Fabric enabled. Have the Fabric administrator review the
   [data agent tenant settings](https://learn.microsoft.com/fabric/data-science/data-agent-tenant-settings),
   including the applicable cross-geo AI processing and storage settings.
2. Open the existing data agent in its Fabric workspace. In **Explorer**, select
   **+ Data source**, choose the semantic model in the OneLake catalog and select
   **Add** if it is not already attached. Select only the required tables.
3. Ask a question with a known answer, such as a specific month's revenue.
   Inspect the generated DAX and compare the result with the model's expected
   result. Add instructions or example questions where needed.
4. Select **Publish**, supply a useful description and share the published agent
   with the intended consumers. Test as a consumer, not only as its author.

Consumers need access to the data agent **and** the underlying model. Current
Fabric documentation specifies **Read** permission on the semantic model for
data-agent interactions; Build permission and membership in the model's workspace
are not required for this path. Authoring the data agent still requires permission
to create or edit that item. Sharing the agent does not grant model access.
Follow [Create a Fabric data agent](https://learn.microsoft.com/fabric/data-science/how-to-create-data-agent)
for the complete Fabric procedure.

The Fabric data agent itself is generally available in current documentation;
the **Foundry IQ Fabric data agent knowledge source remains preview**.
Ontology is also preview. Check service availability and governance requirements
for the actual workspace region; results returned to Search can cross regions.

## 2. Understand the shipped registration contract

If you have unmodified hosted Agent Application, stop after Fabric
verification and plan the extension in Step 3 before provisioning this source.
The following are registration inputs, not a hosted enablement recipe.
In a platform checkout with the intended `azd` environment selected:

```bash
azd env set FABRIC_DATA_AGENT_ENABLED true
azd env set FABRIC_DATA_AGENT_KNOWLEDGE_SOURCE_NAME fabric-sales
azd env set FABRIC_DATA_AGENT_WORKSPACE_ID <fabric-workspace-guid>
azd env set FABRIC_DATA_AGENT_DATA_AGENT_ID <fabric-data-agent-item-guid>
```

The workspace and data agent values are Fabric item identifiers, not display
names, semantic model IDs or API URLs. Obtain them from the Fabric item's URL.
`fabric-sales` is a name you choose for the Search knowledge source.

With `RETRIEVAL_BACKEND=foundry_iq`, the normal `azd provision` workflow creates
a `fabricDataAgent` source and adds its reference to the shared knowledge base.
It does not create the Fabric workspace, semantic model, data agent, permissions
or user consent. Search and Fabric must be in the same Entra tenant. The operator
creating knowledge sources needs **Search Service Contributor** when using RBAC.
See [Full stack deploy](deploy-full-stack.md) before provisioning an existing
environment, because provisioning reconciles more than this source.

The hooks also publish the Fabric settings to App Configuration with label
`agent-lz`. Runtime reads the enabled flag and source name; registration uses
the workspace and item IDs. Direct App Configuration edits alone do not create
the source and can be overwritten by a later provisioning run. Keep deployment
inputs aligned with any approved runtime change.

The shipped platform defaults to knowledge API `2026-05-01-preview`; current
Microsoft Learn examples use `2026-08-01-preview`. Do not copy a newer API
version into only one part of the deployment. Validate provisioning and runtime
retrieval together before changing the pinned Agent Application API contract.

The [Fabric data agent knowledge source requires low or medium retrieval reasoning](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-fabric-data-agent),
but the shipped non-MCP knowledge-base template hardcodes **minimal**. There is
no existing environment override for that branch:
`FOUNDRY_IQ_MCP_REASONING_EFFORT` applies only when MCP sources are enabled.
The native Fabric path therefore also needs a reviewed template change, not
just registration and delegated authentication. A portal-only correction can
be overwritten by provisioning.

For an ontology, the separate inputs are `FABRIC_IQ_ENABLED`,
`FABRIC_IQ_KNOWLEDGE_SOURCE_NAME`, `FABRIC_IQ_WORKSPACE_ID` and
`FABRIC_IQ_ONTOLOGY_ID`. Do not use them to attach a data agent.

## 3. Plan the hosted extension

Choose the integration boundary before changing Agent Application code:

- **Knowledge-base retrieval:** retain the native `fabricDataAgent` source and
  make the following coordinated changes:
    1. Update the non-MCP knowledge-base template to use supported **low** or
       **medium** reasoning and the model configuration required by that mode.
       Do not enable unrelated MCP sources just to change this setting.
    2. Validate the selected preview API's registration, retrieve request and
       response parser together; registration success alone is insufficient.
    3. Implement a reviewed, authenticated delegated-user path into retrieval.
  The connector sends the user token through
  `x-ms-query-source-authorization`.
  The hosted entry point currently supplies empty user context, not that token.
  A Foundry call ID or hosted managed identity is not a substitute.
  Adding an `Authorization` header to a hosted request does not implement this
  missing delegation path.
- **Remote MCP source or agent tool:** expose or consume an approved Fabric
  integration through the [knowledge-base configuration](foundry-iq.md) or
  [agent tools](agent-tools.md) extension path. This requires a compatible server,
  tool contract and authentication implementation; the native `FABRIC_DATA_AGENT_*`
  settings do not configure MCP. Do not point `MCP_APP_ENDPOINT` at a Fabric item
  URL or assume Agent Application's MCP strategy supplies Fabric delegated authentication.

For custom development, start from [Custom applications](build-your-own-app.md).
Keep tokens server-side, validate the caller and token audience, and obtain the
required delegated permissions and consent for the selected integration.
Never accept a token, user ID or group list from model-generated tool arguments
as proof of authorization. Preserve Fabric's model permissions and row-level
security; Agent Application sign-in alone does not establish source access.

Use the [Agent Application authentication](application-auth.md) guidance for UI
sign-in, not as evidence that Fabric delegation is already implemented. Validate
network reachability from the service making the remote call as well as the
hosted runtime. Agent Landing Zone private networking does not automatically
configure Fabric workspace networking.

## Verify and recover

- **Registration:** inspect the Search knowledge source and knowledge base.
  Expect `kind: fabricDataAgent`, the intended workspace/data agent IDs and a
  matching knowledge-base reference. This proves registration only.
- **Hosted extension acceptance:** repeat the known-answer question through the
  hosted Agent Application and inspect retrieval activity for the Fabric source.
  Repeat with a user lacking model access and with users subject to different
  row-level security. A plausible answer or successful sign-in is not proof.
- **No Fabric grounding:** check the native connector's logs for “no OBO token”
  or an empty source name. Do not grant broader managed-identity permissions to
  bypass missing delegation. Fix the custom authentication path first.
- **Required retrieval authorization unavailable:** a user-required retrieval
  path can fail before calling Fabric when no delegated token is available.
  Enabling anonymous access is not a fix for Fabric delegation.
- **Fabric query failure:** reproduce in the published Fabric agent as the same
  user. Check publication, model access, capacity and tenant settings before
  changing prompts or Search configuration.
- **Undo registration intent:** set `FABRIC_DATA_AGENT_ENABLED` to `false` in
  the selected `azd` environment and use the normal provisioning workflow.
  Verify the knowledge-base reference is removed; do not assume an existing
  standalone knowledge source or Fabric item was deleted.

Runtime configuration is loaded into memory. Apply approved changes through the
[hosted deployment workflow](hosted-agents.md), rather than restarting a
Container App or assuming a portal edit refreshes a running hosted process.
Keep the previous Agent Application version and configuration for rollback.
