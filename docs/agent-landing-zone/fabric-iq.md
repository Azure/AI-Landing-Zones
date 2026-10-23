# Fabric data

## Optional Fabric foundation

The Fabric foundation integration retains the existing `azd provision`
lifecycle. Bicep parameter `deployFabric` and environment input `DEPLOY_FABRIC`
default to `false`. Use a platform revision containing the integration; these
files are not deployed from this documentation repository.

The foundation creates only a capacity when needed and a workspace, with
capacity assignment, baseline workspace access, and a native workspace identity.
It grants that identity **Cognitive Services OpenAI User** on the deployed
Foundry account so supported Fabric workloads can call its Azure OpenAI model
deployments. It creates **no Lakehouse, Data Agent, Fabric item, or Foundry IQ
knowledge source**, and is independent of `RETRIEVAL_BACKEND`.

```bash
azd env set DEPLOY_FABRIC true
azd env set FABRIC_CAPACITY_SKU F2
azd provision
```

To reuse a capacity without ARM creation or updates, set
`EXISTING_FABRIC_CAPACITY_NAME` to its exact visible display name before
provisioning. Otherwise Bicep converges the named capacity; reruns do not create
a second capacity. The workspace is also reused by exact display name.

### Inputs and permissions

| Input | Default | Purpose |
| --- | --- | --- |
| `DEPLOY_FABRIC` | `false` | Enables the workspace foundation and scoped inference access. |
| `FABRIC_CAPACITY_NAME` | `fc<resourceToken>` | Capacity name; lowercase letters and digits, starting with a letter. |
| `EXISTING_FABRIC_CAPACITY_NAME` | Empty | Reuse an exact, visible capacity display name; skips ARM capacity creation. |
| `FABRIC_LOCATION` | Deployment location | Capacity region; verify F SKU availability and workspace compatibility. |
| `FABRIC_CAPACITY_SKU` | `F2` | New capacity SKU. |
| `FABRIC_CAPACITY_ADMIN_MEMBERS_JSON` | `[]` | Additional administrator UPNs or supported object IDs; the deploying principal is included automatically. |
| `FABRIC_CAPACITY_LOCK` | `CanNotDelete` | `None`, `CanNotDelete`, or `ReadOnly`. |
| `FABRIC_WORKSPACE_NAME` | `<environment>-fabric` | Workspace display name. |
| `FABRIC_WORKSPACE_DESCRIPTION` | Generated | Workspace description. |
| `FABRIC_DOMAIN_ID` | Empty | Optional domain when creating a workspace. |
| `FABRIC_WORKSPACE_ROLE_ASSIGNMENTS_JSON` | `[]` | Principal/role objects; deploying-principal `Admin` access is retained. |

For workspace access, supply Entra object IDs:

```bash
azd env set FABRIC_WORKSPACE_ROLE_ASSIGNMENTS_JSON '[{"principal":{"id":"<entra-group-object-id>","type":"Group"},"role":"Viewer"}]'
```

Roles are `Admin`, `Member`, `Contributor`, or `Viewer`; principal types are
`User`, `Group`, `ServicePrincipal`, and `ServicePrincipalProfile`.
Use `AZURE_PRINCIPAL_TYPE=ServicePrincipal` for a pipeline deployment identity.
No identities are hardcoded, and tenant-wide grants are not accepted.

The deploying identity needs Azure permission to create the capacity and lock,
register `Microsoft.Fabric` for a new capacity, and assign roles at the Foundry
account scope (`Microsoft.Authorization/roleAssignments/write`, such as scoped
User Access Administrator). Fabric tenant settings must permit workspace
creation, workspace identity provisioning, and the required APIs. An existing
capacity must be accessible for workspace assignment.

### Workspace-to-Foundry identity boundary

A [Fabric workspace identity](https://learn.microsoft.com/fabric/security/workspace-identity)
is a Fabric-managed service principal, **not an Azure user-assigned managed
identity (UAMI)**. The extension creates or reuses the native identity and grants
it the existing repository-defined OpenAI inference role. It does not attach
a UAMI, create an intermediary, or grant Foundry contributor/project roles.

Azure RBAC is reconciled separately from the Fabric REST calls after the
workspace identity exists. The scope is the single deployed
`Microsoft.CognitiveServices/accounts` resource, not the subscription or resource
group. The Foundry account must be included in the deployment.

RBAC is authorization, not a runtime connection. In a supported Fabric
connection/workload, select workspace-identity authentication and the intended
Foundry model endpoint/deployment. Do not assume every Fabric notebook or
connector can obtain a workspace-identity token. Verify that workload's
authentication support, role propagation and network reachability before
testing inference. The foundation does not create a connection or make a test
inference call.

### Outputs, retries, and disabling

The hook persists `FABRIC_CAPACITY_NAME`, `FABRIC_CAPACITY_ID`,
`FABRIC_WORKSPACE_ID`, `FABRIC_WORKSPACE_URL`,
`FABRIC_WORKSPACE_IDENTITY_APPLICATION_ID`,
`FABRIC_WORKSPACE_IDENTITY_PRINCIPAL_ID`,
`FABRIC_FOUNDRY_ACCOUNT_RESOURCE_ID`, and `FABRIC_FOUNDRY_ROLE_ASSIGNMENT_ID`.
`FABRIC_FOUNDATION_CONFIG` is the nonsecret ARM-to-hook handoff.
These outputs are deployment state, not application retrieval settings.

Reruns reuse exact workspace names, wait for capacity assignment and identity
operations, reconcile requested workspace grants, and reuse the exact-scope
Foundry role assignment. Ambiguous names and permission failures stop
provisioning. Correct the cause and rerun `azd provision`.

`DEPLOY_FABRIC=false` skips Fabric-specific CLI/API work. Disabling is not
uninstallation: it does not delete the workspace or revoke existing grants.
Review capacity removal through normal ARM change control and its lock.
Changing the target identity/account does not automatically revoke old grants.
The removed Lakehouse/Data Agent parameters and generated connector handoff are
no longer supported. Any previously created items or independently configured
knowledge sources are not deleted or disabled by this change.

Fabric does not inherit the landing zone's VNet isolation. Review Fabric
outbound access, Foundry firewall/private connectivity, regional residency and
tenant policies separately; an RBAC grant alone does not establish connectivity.

## Query existing Fabric data

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
