# Ingestion and conversation uploads

**Source ingestion** prepares documents for retrieval. **Conversation uploads**
attach files to an individual chat. They have different configuration and
authorization requirements.

Choosing where the orchestrator runs does not choose either path. An agent
strategy controls orchestration behavior, not whether an ingestion service is
deployed.

## Choose a source ingestion path

| Path | What processes the source | When to use it |
| --- | --- | --- |
| Native Foundry IQ Blob source | Azure AI Search processes the configured `azureBlob` knowledge source | Your documents and permission model fit the supported native Blob configuration. No ingestion Container App is required for this path. |
| Independently populated Search index | Your own ingestion pipeline populates a compatible index | You bind `SEARCH_RAG_INDEX_NAME` explicitly, using `ai_search` or Foundry IQ `searchIndex`. Disabling the bundled app does not create this pipeline or populate the index. |
| Agent App Ingestion | The optional ingestion Container App processes documents and writes Search content | You need the application's processing pipeline, its SharePoint jobs, or the conversation-upload path. Review the selected component's supported formats and configuration. |

Agent App Ingestion provides format-specific chunking, text/image embeddings and
application-managed ingestion jobs. It is not simply a deployment wrapper for
native Foundry IQ ingestion. Neither path is a drop-in replacement for the other.

### SharePoint is a separate integration

The optional application's Graph-based SharePoint jobs and Foundry IQ's preview
`indexedSharePoint` knowledge source are **different implementations**.
Configuring native Blob ingestion does not configure SharePoint.

The platform can register the preview indexed SharePoint source when its required
identifiers are supplied. It still requires an Entra application, a federated
identity credential for the configured managed identity, Graph administrator
consent and, for `Sites.Selected`, explicit site access. Incomplete identifiers
cause that source to be omitted with a warning. Registration is not evidence that
the manual permissions work.

The bundled ingestion opt-out validator supports native `azureBlob`, or an
explicit independently populated index. It does **not** establish SharePoint-only
ingestion-free support or parity with the application's SharePoint jobs. Validate
the chosen integration and its document authorization before removing an existing
ingestion dependency.

## Select the optional application

`DEPLOY_INGESTION_CONTAINER_APP` accepts only `true` or `false`:

| Environment | Resolution |
| --- | --- |
| New bundled application | Defaults to `false`. |
| Existing bundled application | Retains its recorded selection. A populated older environment without a selection retains ingestion. A failed state lookup requires restored access or an explicit choice, not a guess. |
| Explicit custom definition | Retains its declared component intent and the current additive foundation composition. The bundled-only switch does not remove its components. |

An empty azd-created resource group is considered fresh. Pre-provision persists
the resolved choice, and configuration publishes the effective value under
App Configuration label `agent-lz`.

Contextual setting, applied before the matching [deployment runbook](deploy-full-stack.md):

```bash
azd env set DEPLOY_INGESTION_CONTAINER_APP false
```

For the bundled application, opt-out excludes ingestion from subsequent
provisioning, checkout, build, deployment, endpoint reconciliation and
identity/role reconciliation. It does not change the retrieval backend,
source/index bindings, strategy, topology or document authorization.

An ingestion-free `ai_search` deployment needs `SEARCH_RAG_INDEX_NAME`.
For Foundry IQ with an independent index, also select both
`FOUNDRY_IQ_PATTERN=searchIndex` and
`FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND=searchIndex`. The index must pass the existing
schema/upgrade guards. Unsupported combinations, including
`FOUNDRY_IQ_CONVERSATION_UPLOAD_ENABLED=true` with ingestion disabled, fail
validation.

## Conversation uploads are not native source ingestion

The bundled UI reads the effective ingestion flag:

- **`false`** hides attachment controls and rejects server uploads and client
  preflight before ingestion endpoint or Dapr fallback resolution.
- **`true`** retains upload eligibility checks. It does not give every caller
  permission to upload.
- **Missing** retains legacy behavior, not a safe opt-out.

Text chat, delegated authentication and retrieval remain available when uploads
are disabled. When enabled, authenticated-mode eligibility, anonymous Copilot
restrictions, conversation ownership/eligibility, supported file types and
size/count limits still apply. Hosted upload eligibility also requires a
conversation identifier. Native source ingestion does not implement this chat
attachment path.

Custom applications own their upload contract. A published capability flag does
not prove that a custom application implements uploads.

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

Opt-out does not delete an existing app, documents or indexes, or revoke existing
identity permissions. Resource retirement and RBAC cleanup require separate,
deliberately authorized actions after validation.

To restore ingestion, restore the previous explicit selection and source/index
configuration, rerun the matching full workflow and retest. Enabling the app alone
does not repair bindings. Before rolling back to a UI without the upload gate,
restore ingestion and its required endpoint/source configuration **first**.
Rollback must not delete documents or indexes.

## Authorization remains a design requirement

Preserve authentication, Entra ID/OBO, RBAC and document-level authorization
across ingestion and retrieval. Test with both an allowed user and a user who
must not see the document. A successful indexer, greeting or hook is insufficient.

The default native Blob permission metadata is `["rbacScope"]`. An explicit `[]`
is a deliberate shared-source choice only for supported active non-ADLS native
Blob ingestion, not a private-link or login repair. See
[permission options](configuration.md#explicit-shared-source-permission-options)
and [private Blob connectivity](network-isolation.md#private-native-blob-ingestion).

## Related references

- [Configuration](configuration.md#ingestion-application-selection)
- [Hosted agents and topologies](hosted-agents.md#topologies)
- [Custom application contracts](build-your-own-app.md)
- [Ingestion component source](https://github.com/Azure/agent-app-ingestion)
- [Platform ingestion validation](https://github.com/Azure/agent-landing-zone/blob/main/config/deployment/composition.py)
