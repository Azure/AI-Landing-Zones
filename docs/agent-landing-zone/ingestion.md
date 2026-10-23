# Ingestion and conversation uploads

**Source ingestion** prepares documents for retrieval. **Conversation uploads**
attach files to an individual chat. They have different configuration and
authorization requirements.

Choose ingestion separately from orchestrator hosting and strategy. Hosting
selects where the agent runs; strategy selects how it coordinates models,
retrieval and tools.

## Choose a source ingestion path

| Path | What processes the source | When to use it |
| --- | --- | --- |
| Native Foundry IQ Blob source | Azure AI Search processes the configured `azureBlob` knowledge source | Your documents and permission model fit the supported native Blob configuration. No ingestion Container App is required for this path. |
| Independently populated Search index | Your own ingestion pipeline populates a compatible index | Configure and run that pipeline, then bind `SEARCH_RAG_INDEX_NAME` explicitly using `ai_search` or Foundry IQ `searchIndex`. |
| Agent App Ingestion | The optional ingestion Container App processes documents and writes Search content | You need Agent Application's processing pipeline, its SharePoint jobs, or the conversation-upload path. Review the selected component's supported formats and configuration. |

Agent App Ingestion provides format-specific chunking, text/image embeddings and
ingestion jobs for Agent Application. Native Foundry IQ ingestion uses Search's
service-managed pipeline. Choose based on processing, source and permission
requirements; use [Configuration](configuration.md#ingestion-application-selection)
for the source/index settings.

### SharePoint is a separate integration

Agent App Ingestion's Graph-based SharePoint jobs and Foundry IQ's preview
`indexedSharePoint` knowledge source use separate pipelines and permission
configuration.

The platform includes a preview indexed SharePoint registration template, but
its payload is not compatible with the current documented API contract.
Using that source requires a reviewed template update as well as identifiers
and consent.
See [SharePoint grounding](sharepoint.md) for the supported service setup,
the hosted integration requirements and the distinction from Agent App Ingestion's
Graph jobs.

The Agent Application ingestion opt-out validator supports native `azureBlob` or an
explicit independently populated index. A SharePoint-only deployment without
Agent App Ingestion needs source-specific integration and document authorization
validation before removing an existing ingestion dependency.

<span id="select-the-optional-application"></span>

## Select Agent App Ingestion

To include or omit Agent App Ingestion, set the deployment input
`DEPLOY_INGESTION_CONTAINER_APP` in the selected `azd` environment before the
[deployment workflow](deploy-full-stack.md). It accepts only `true` or `false`:

| Environment | Resolution |
| --- | --- |
| New Agent Application environment | Defaults to `false`. |
| Existing Agent Application environment | Retains its recorded selection. A populated older environment without a selection retains ingestion. After a failed state lookup, restore access or make an explicit choice. |
| Explicit custom definition | Retains its declared components alongside the foundation. This switch controls Agent Application's ingestion component only. |

An empty azd-created resource group is considered fresh. Pre-provision persists
the resolved choice, and configuration publishes the effective value under
App Configuration label `agent-lz`.

For example, to omit Agent App Ingestion:

```bash
azd env set DEPLOY_INGESTION_CONTAINER_APP false
```

For Agent Application, opt-out excludes ingestion from subsequent
provisioning, checkout, build, deployment, endpoint reconciliation and
identity/role reconciliation. The retrieval backend, source/index bindings,
strategy, topology and document authorization retain their configured values.

An ingestion-free `ai_search` deployment needs `SEARCH_RAG_INDEX_NAME`.
For Foundry IQ with an independent index, also select both
`FOUNDRY_IQ_PATTERN=searchIndex` and
`FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND=searchIndex`. The index must pass the existing
schema/upgrade guards. Unsupported combinations, including
`FOUNDRY_IQ_CONVERSATION_UPLOAD_ENABLED=true` with ingestion disabled, fail
validation.

## Conversation uploads are not native source ingestion

Agent App UI reads the effective ingestion flag:

- **`false`** hides attachment controls and rejects server uploads and client
  preflight before ingestion endpoint or Dapr fallback resolution.
- **`true`** permits uploads subject to caller and file eligibility checks.
- **Missing** retains legacy behavior. Use an explicit value to control uploads.

Text chat, delegated authentication and retrieval remain available when uploads
are disabled. When enabled, authenticated-mode eligibility, anonymous Copilot
restrictions, conversation ownership/eligibility, supported file types and
size/count limits still apply. Hosted upload eligibility also requires a
conversation identifier. Use [Images and voice](multimodality.md#attach-a-pdf-to-a-conversation)
to configure the conversation-upload retrieval source and test PDF attachments.

Custom applications define their own upload behavior. Check the application's
implementation and tests before exposing attachment controls.

## Upgrade and retirement safety

Before changing an existing selection, record the current platform revision,
manifest, source/index bindings and ingestion dependencies. Back up relevant
configuration and data. Apply selection changes through the full
[deployment workflow](deploy-full-stack.md), not deploy-only or a manually edited
runtime key. Private environments need a connected runner.

!!! warning "Older UI compatibility"
    The upload gate was introduced in the coordinated Agent Landing Zone
    **v4.3.0 / agent-app-ui v3.3.0** combination. On **v4.2.3 / UI v3.2.2**,
    retain explicit `DEPLOY_INGESTION_CONTAINER_APP=true`: that UI sends
    attachments to ingestion in both hosting modes and does not enforce the
    new gate. An empty endpoint can fall back to a derived URL or Dapr.
    Changing Chainlit TOML or authentication policy is not a supported opt-out.

Upgrade the **complete manifest-pinned combination** before disabling ingestion.
Check that App Configuration publishes the resolved flag and the deployed UI
consumes it. Verify attachment controls are hidden and stale/direct uploads are
rejected, while sign-in, chat, retrieval and document allow/deny tests still work.

Opt-out does not delete an existing Agent App Ingestion deployment, documents or
indexes, or revoke existing identity permissions. Resource retirement and RBAC
cleanup require separate, deliberately authorized actions after validation.

To restore ingestion, restore the previous explicit selection and source/index
configuration, rerun the matching full workflow and retest. Enabling Agent App
Ingestion requires valid endpoint and source bindings. Before rolling back to
a UI without the upload gate, restore ingestion and its required endpoint/source
configuration **first**.
Rollback must not delete documents or indexes.

## Authorization remains a design requirement

Preserve authentication, Entra ID/OBO, RBAC and document-level authorization
across ingestion and retrieval. Test with both an allowed user and a denied
user. Confirm the allowed user retrieves the document and its citation, and
the denied user's retrieved document IDs exclude it.

The default native Blob permission metadata is `["rbacScope"]`. An explicit `[]`
is a deliberate shared-source choice only for supported active non-ADLS native
Blob ingestion, where every admitted user may read the corpus. Keep
private-link and sign-in troubleshooting separate from that access policy. See
[permission options](configuration.md#explicit-shared-source-permission-options)
and [private Blob connectivity](network-isolation.md#private-native-blob-ingestion).

## Related references

- [Configuration](configuration.md#ingestion-application-selection)
- [Hosted agents and topologies](hosted-agents.md#topologies)
- [Custom application definitions](build-your-own-app.md)
- [Ingestion component source](https://github.com/Azure/agent-app-ingestion)
- [Platform ingestion validation](https://github.com/Azure/agent-landing-zone/blob/main/config/deployment/composition.py)
