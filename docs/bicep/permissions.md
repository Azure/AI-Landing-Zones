# Permissions

This reference describes the **default Agent Application selection**:
`ORCHESTRATION_HOST=hosted` and `APPLICATION_MODE=conversational`, with execution
in **Foundry Agent Service** and the automatically included `frontend` in
**Azure Container Apps**. No application Cosmos is selected when no consumer
requires it. Native Foundry IQ
ingestion is selected by default; Agent App Ingestion is optional.
Foundry's own backing resources are separate from application data stores.
History, feedback and private attachments independently default to `false`.
Selecting Hosted does not enable history.
Workflow mode, `both`, enabled history, feedback or attachments adds UI product metadata,
not an execution checkpoint database. Durable Container Apps is a separate
native execution choice with DTS.

The [full-stack deployment guide](../agent-landing-zone/deploy-full-stack.md) provisions
the composed layout, not the raw root parameters alone. Custom definitions,
optional services and reused resources can change the assignments below.
Inspect the selected environment's effective principals and scopes before
granting access.

## Keep the identities separate

| Principal | Purpose |
| --- | --- |
| Deployment operator or pipeline | Creates resources, publishes configuration, builds images and deploys agent versions. |
| Frontend managed identity | Reads UI settings/secrets, pulls its image and accesses Blob references. It is not the signed-in user. |
| Foundry project managed identity | Pulls the hosted image and uses configured project connections. It is not the running agent's identity. |
| Hosted agent runtime principal | The actual principal discovered for the deployed agent; receives the runtime grants below. |
| MCP Container App managed identity | Reads approved SQL metadata and models and queries SQL when the component is selected; it is not the orchestrator identity. |
| Administrative metadata importer | Writes approved source/schema/example versions and generates embeddings; separate from the read-only MCP runtime. |
| Signed-in application user | Invokes Foundry through UI OBO and separately needs source/document authorization. |

<span id="container-app-role-assignments"></span>

## Frontend Container App

Bicep assigns the following roles to the **frontend's managed identity** at
the listed resource scopes when those services are selected. Use its actual
principal ID, whether system-assigned or an approved user-assigned identity.

| Role | Scope | Purpose |
| --- | --- | --- |
| App Configuration Data Reader | Application configuration store | Read relevant runtime keys; this does not grant Key Vault access. |
| AcrPull | Application container registry | Pull the UI image. |
| Key Vault Secrets User | Required UI authentication secret references | Only for the declared UI authentication secret consumer, not implicit base access. |
| Search Index Data Reader | Selected Search resource | When the UI's declared retrieval-reader capability needs protected citation authorization. |
| Storage Blob Delegator | Declared existing Storage resource | UI's declared Blob-delegation capability; delegation-key access is not user/source authorization. |
| Scoped Cosmos metadata access | `native-ui-metadata`, `/principal_id` owner `tid:oid` | Frontend-only when workflow mode, `both`, history, feedback or attachments selects product metadata. |

The implicit base grants are configuration read and image pull.
Other assignments follow actual declared consumers; do not add model access,
arbitrary secrets or Cosmos checkpoints to the UI.
Delegated Foundry and shared-source Storage calls use the signed-in user's
token. Broader UI workload grants do not fix a denied user call or authorize
another user's native session.
A Blob Delegator grant does not permit bypassing current user/source
authorization when issuing or consuming a protected file reference.
UI authentication secrets remain secret-scoped; there is no default
vault-wide UI grant.

## Hosted agent runtime

After agent deployment, the hosted access reconciliation discovers the
**actual runtime principal**, then applies the selected runtime/capability grants:

| Role | Scope | Condition |
| --- | --- | --- |
| App Configuration Data Reader | Selected application configuration store | Runtime configuration. |
| Cognitive Services OpenAI User | Selected Foundry account | Direct model calls from the supplied runtime. |
| Key Vault Secrets User | Exact secret referenced by `AUDIT_HMAC_KEY` | Only when the audit key is configured as a Key Vault reference. |
| Key Vault Secrets User | Exact declared MCP/tool secret | Only for the enabled consumer and named secret. |
| Declared retrieval/tool access | Exact selected source/resource | Only for enabled registered capabilities. |
| MCP invocation authorization | Dedicated MCP API application role `MCP.Invoke` and allowed client ID | Only for the selected MCP caller; catalog and SQL grants belong to the MCP identity, not this runtime. |

These are not a blanket grant to every secret, source or tool. Reconciliation
does not automatically grant arbitrary source access or authorize application
users. Review the intended assignments without writing them:

```bash
python -m config.deployment.hosted_access --azd-env --plan
```

Run this from the platform root with the prepared Python environment and
intended azd environment selected. Use the
[hosted access bootstrap/recovery procedure](../agent-landing-zone/hosted-agents.md#bootstrap-the-agents-runtime-access)
for approved reconciliation. Do not substitute the UI or project identity
when the runtime principal cannot be discovered.

Tool secret declarations use `NATIVE_TOOL_SECRET_NAMES` (default `[]`), a JSON
array of actual secret names, never values. This is a platform scoped-grant
declaration; the native runtime does not consume it to load secrets.
App Configuration reader permission does not
resolve Key Vault references without the consumer's separate secret grant.

For Container Apps, the native durable worker and UI client need the scheduler's
native data-plane access on the actual configured backend/task hub.
Use its provisioned nonsecret managed-identity binding:
`Endpoint=<actual output>;TaskHub=agent-lz;Authentication=ManagedIdentity`.
Keep it compatible with both the native worker and UI client.
Scheduler service permission is not product-user ownership, and the worker
does not require public HTTP ingress, Dapr or an Azure Functions app.
Hosted and DTS execution do not use application Cosmos checkpoints.

## Agent App MCP Server

The platform helper configures the dedicated Entra API registration/service
principal, `MCP.Invoke` app role and actual caller assignments automatically.
The deployer needs directory rights for those operations in addition to Azure
resource and scoped role-assignment permissions. Azure Contributor does not
grant directory administration. There is no broad ARM-token or API-key
authentication fallback.

| Principal | Required access | Boundary |
| --- | --- | --- |
| MCP Container App identity | Configuration read and image pull | Base application resources |
| MCP Container App identity | Selected generation and embedding models | Only the models it consumes |
| MCP Container App identity | Catalog read | Exact `mcp-sources` and `mcp-nl2sql-metadata` containers in application Cosmos |
| MCP Container App identity | SQL read | SQL owner approves/grants permitted views/tables; platform startup does not create database grants |
| MCP Container App identity | SQL password secret, when required | Exact names declared in `MCP_SQL_SECRET_NAMES` (default `[]`), not vault-wide access |
| Administrative importer | Catalog write and embedding model access | Complete approved-version import, not runtime catalog administration |
| Hosted/Container Apps consumer | `MCP.Invoke`, allowed client ID and MCP-audience token | Invocation only; no MCP catalog or SQL grant |

Normal application Cosmos is serverless and separate from Foundry backing
Cosmos. MCP adds vector policies to its catalog, not UI containers or native
execution state. No Search grants are added by MCP selection.
See [MCP deployment and onboarding](../agent-landing-zone/agent-app-mcp.md).

<span id="microsoft-foundry-and-ai-search-assignments"></span>

## Foundry project, Search and image pull

Bicep creates these cross-service assignments when the associated services
are enabled:

| Assignee | Role | Scope |
| --- | --- | --- |
| Foundry project managed identity | AcrPull | Hosted image registry using standard RBAC. For an external ABAC-mode registry, Container Registry Repository Reader is used instead. |
| Foundry project managed identity | Search Index Data Reader | Selected Azure AI Search service. |
| Foundry project managed identity | Storage Blob Data Reader | Selected grounding Blob storage account. |
| Search managed identity | Storage Blob Data Reader | Selected grounding Blob storage account. |
| Search managed identity | Cognitive Services User | Selected Foundry account for configured AI services/vectorizers. |

The registry grant allows Foundry to pull the hosted image; it does not
authorize the running agent to read application data. Likewise, ingestion
or project connection access does not prove per-user retrieval filtering.
[Sign-in and document access](../agent-landing-zone/application-auth.md)
describes the separate hosted retrieval identity integration.

<span id="executor-role-assignments"></span>

## Deployment operator and pipeline

An administrator must authorize resource deployment and role assignment
**before** provisioning. Runtime roles do not supply these permissions.

| Operation | Access to arrange |
| --- | --- |
| Deploy resources | Contributor-equivalent deployment actions on each approved destination and any required parent/shared scope. Creating missing groups also requires subscription-level resource-group creation permission. |
| Create role assignments | Scoped role-assignment authority wherever Bicep or hosted hooks create grants. Contributor alone cannot create role assignments. |
| Configure and build | App Configuration Data Owner; the selected Key Vault secret-management, Search configuration/index, model and registry/build permissions. Bicep grants selected service roles to the configured executor, but the operator must already be able to deploy those assignments. |
| Author hosted agents | Foundry User-equivalent authoring on the exact project, plus account read access. The default Bicep configuration grants Foundry Project Manager when hosted prerequisites and `grantHostedAgentProjectManager` are enabled; disabling that grant requires separately arranged authoring access. |

Foundry roles might still display their former **Azure AI** names during the
service rename. Cognitive Services User/OpenAI User alone do not authorize
hosted-agent authoring. A subscription Owner assignment is not the default
solution to a missing data-plane permission.

Default Agent environments use separate Foundry/root, application and network
resource groups. Review the [destination scopes](../agent-landing-zone/configuration.md#resource-group-destinations)
and, for pipelines, the [service-connection permissions](../agent-landing-zone/azure-devops.md).
Reused resources can require additional owner-approved grants outside those
groups.

<span id="jumpbox-vm-role-assignments"></span>

An optional **jumpbox managed identity** is a deployment/configuration runner,
not the frontend or chat user. Its grants depend on the enabled services and
registry authorization mode. Review its effective assignments for the actual
deployment rather than copying all operator roles to every runtime identity.

## Application users and optional integrations

Entra registration/consent, UI admission, Foundry caller access and document
access are separate checks. They are **not automatically granted to every
application user by provisioning**. Complete the
[ordered login setup](../agent-landing-zone/application-auth.md#configure-login-in-order).
Foundry Agent Consumer is the least-privilege built-in role for endpoint-only
callers; use the intended agent or project scope.

Optional ingestion, administrative panel, custom tools and protected sources
need their own reviewed grants and integration. Select UI metadata when the
mode/history/feedback/attachment contract requires it, and grant only its frontend
consumer. Private inline attachments require no additional Blob/SAS or
ingestion grant. Do not add runtime checkpoint Cosmos or arbitrary tool access merely because
another topology uses it.
See the [capability readiness matrix](../agent-landing-zone/application.md#capability-readiness)
and [capability profiles](../agent-landing-zone/build-your-own-app.md#capability-profiles).
