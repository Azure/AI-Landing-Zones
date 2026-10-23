# Fabric data

Use a Fabric data agent to answer analytical questions over an existing Power BI
semantic model. The model stays in Fabric and is queried at retrieval time.

!!! warning "Hosted integration requires custom work"
    Hosted Agent Application does **not** currently provide an end-to-end,
    configuration-only connection to a Fabric data agent. The platform can
    register the knowledge source, but the native retrieval connector requires a
    delegated user token. The shipped hosted entry point does not supply that
    token. Plan the identity and compatibility work below before enabling the source.

## Choose the connection

If you already have a semantic model and a Fabric data agent, use that agent
directly through the data-agent knowledge source.

- **Fabric data agent:** queries the selected data, including semantic models,
  and returns analytical answers. Foundry IQ supports a remote
  `fabricDataAgent` knowledge source for it.
- **Fabric IQ ontology:** defines business entities and relationships bound to
  data. Its separate `fabricOntology` knowledge source expects an ontology item,
  not a semantic model ID or a data agent ID.

Fabric IQ provides business context through data agents and ontologies.
Choose the corresponding knowledge-source integration. See the official
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
to create or edit that item. Grant model access separately from agent sharing.
Follow [Create a Fabric data agent](https://learn.microsoft.com/fabric/data-science/how-to-create-data-agent)
for the complete Fabric procedure.

The Fabric data agent itself is generally available in current documentation;
the **Foundry IQ Fabric data agent knowledge source remains preview**.
Ontology is also preview. Check service availability and governance requirements
for the actual workspace region; results returned to Search can cross regions.

<span id="2-understand-the-shipped-registration-contract"></span>

## 2. Understand source registration

After verifying Fabric, plan the hosted extension in Step 3 before provisioning
the source. Registration creates the Search source and knowledge-base binding.
Set these deployment inputs in a platform checkout with the intended `azd`
environment selected:

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
Create the Fabric workspace, semantic model and data agent, and arrange
permissions and user consent separately. Search and Fabric must be in the same
Entra tenant. The operator creating knowledge sources needs
**Search Service Contributor** when using RBAC.
See [Full stack deploy](deploy-full-stack.md) before provisioning an existing
environment, because provisioning reconciles more than this source.

The hooks also publish the Fabric settings to App Configuration with label
`agent-lz`. Runtime reads the enabled flag and source name; registration uses
the workspace and item IDs. Use provisioning to create the source; later
provisioning can overwrite direct App Configuration edits. Keep deployment
inputs aligned with any approved runtime change.

The shipped platform defaults to knowledge API `2026-05-01-preview`; current
Microsoft Learn examples use `2026-08-01-preview`. Validate provisioning, runtime
requests and response parsing together before adopting a newer API version.

The [Fabric data agent knowledge source requires low or medium retrieval reasoning](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-fabric-data-agent),
but the shipped non-MCP knowledge-base template hardcodes **minimal**. There is
no existing environment override for that branch:
`FOUNDRY_IQ_MCP_REASONING_EFFORT` applies only when MCP sources are enabled.
The native Fabric path therefore also needs a reviewed template change, not
just registration and delegated authentication. A portal-only correction can
be overwritten by provisioning.

For an ontology, the separate inputs are `FABRIC_IQ_ENABLED`,
`FABRIC_IQ_KNOWLEDGE_SOURCE_NAME`, `FABRIC_IQ_WORKSPACE_ID` and
`FABRIC_IQ_ONTOLOGY_ID`. These register an ontology item; use the data-agent
inputs above for a data agent.

## 3. Plan the hosted extension

Choose the integration boundary before changing Agent Application code:

- **Knowledge-base retrieval:** retain the native `fabricDataAgent` source and
  make the following coordinated changes:
    1. Update the non-MCP knowledge-base template to use supported **low** or
       **medium** reasoning and the model configuration required by that mode.
       Keep this change in the native-source template.
    2. Validate the selected preview API's registration, retrieve request and
       response parser together.
    3. Implement a reviewed, authenticated delegated-user path into retrieval.
  The connector sends the user token through
  `x-ms-query-source-authorization`.
  The hosted entry point currently supplies empty user context. Implement token
  delivery through a trusted integration that retains the platform call context
  and service identity. The gateway does not forward the caller's
  `Authorization` header to the container.
- **Remote MCP source or agent tool:** expose or consume an approved Fabric
  integration through the [knowledge-base configuration](foundry-iq.md) or
  [agent tools](agent-tools.md) extension path. This requires a compatible server,
  tool contract and authentication implementation; the native `FABRIC_DATA_AGENT_*`
  settings configure the native source. Set `MCP_APP_ENDPOINT` to the compatible
  MCP server and implement the Fabric delegated-authentication flow.

For custom development, start from [Custom applications](build-your-own-app.md).
Keep tokens server-side, validate the caller and token audience, and obtain the
required delegated permissions and consent for the selected integration.
Derive authorization from validated caller context, never from tokens, user IDs
or group lists in model-generated tool arguments. Preserve Fabric's model
permissions and row-level security.

Use [Agent Application authentication](application-auth.md) to configure UI
sign-in, then validate the custom Fabric delegation path separately. Validate
network reachability from the service making the remote call as well as the
hosted runtime. Configure Fabric workspace networking separately from Agent
Landing Zone private networking.

## Verify and recover

- **Registration:** inspect the Search knowledge source and knowledge base.
  Expect `kind: fabricDataAgent`, the intended workspace/data agent IDs and a
  matching knowledge-base reference.
- **Hosted extension acceptance:** repeat the known-answer question through the
  hosted Agent Application and inspect retrieval activity for the Fabric source.
  Repeat with a user lacking model access and with users subject to different
  row-level security. Confirm each user's results match the permissions and
  row filters applied in Fabric.
- **No Fabric grounding:** check the native connector's logs for “no OBO token”
  or an empty source name. Do not grant broader managed-identity permissions to
  bypass missing delegation. Fix the custom authentication path first.
- **Required retrieval authorization unavailable:** a user-required retrieval
  path can fail before calling Fabric when no delegated token is available.
  Restore trusted user-token delivery with authenticated retrieval enabled.
- **Fabric query failure:** reproduce in the published Fabric agent as the same
  user. Check publication, model access, capacity and tenant settings before
  changing prompts or Search configuration.
- **Undo registration intent:** set `FABRIC_DATA_AGENT_ENABLED` to `false` in
  the selected `azd` environment and use the normal provisioning workflow.
  Verify the knowledge-base reference is removed. Review the standalone Search
  source and Fabric item separately and retain anything still in use.

Runtime configuration is loaded into memory. Apply approved changes through the
[hosted deployment workflow](hosted-agents.md) to create a new version that
loads the updated settings.
Keep the previous Agent Application version and configuration for rollback.
