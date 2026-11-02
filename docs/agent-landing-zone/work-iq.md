# Work IQ

Work IQ queries the signed-in user's Microsoft 365 context, including documents,
email and meetings. A Foundry IQ `workIQ` knowledge source retrieves that
context at request time. It does not copy the Microsoft 365 corpus into a
landing-zone index or require Agent App Ingestion.

The platform supplies a source-registration template. **The native reference
application does not load the Work IQ connector settings or forward its
source-specific assertion.** This guide separates that shipped provisioning
support from the application integration you must implement and validate.

<div class="runbook-diagram" markdown="1">

<div class="runbook-diagram__summary" markdown="1">

**Which identity authorizes a Work IQ answer?**

1. The source template registers Work IQ, but does not grant Microsoft 365 access.
2. A custom integration must carry a user assertion for the Work IQ app,
   separately from the workload credential that authenticates Search transport.
3. Search exchanges the assertion for delegated Work IQ access. The user's
   permissions apply; a shared managed identity must not replace the user.

</div>

[![Work IQ integration recipe: a trusted application sends a Work IQ app-audience user assertion to Search, separately from workload transport authentication. Search exchanges it for delegated Microsoft 365 access. Source registration and tenant consent are setup, not an installed native application path.](../media/runbooks/work-iq.svg?v=766010d711f9)](../media/runbooks/work-iq.svg?v=766010d711f9){: .runbook-diagram__image aria-label="Open full-size Work IQ identity diagram"}

[Open full-size diagram](../media/runbooks/work-iq.svg?v=766010d711f9){: .runbook-diagram__open}

</div>

<span id="check-hosted-support-first"></span>
<span id="product-support-and-application-readiness"></span>
<span id="tenant-and-governance-requirements"></span>

## Before you start

Microsoft's [Work IQ knowledge-source guide](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-work-iq)
defines this preview. The [tenant enablement guide](https://learn.microsoft.com/microsoft-365/copilot/extensibility/work-iq/enable-work-iq)
requires usage-based billing, an Azure subscription/resource group and
assignment of querying users. Microsoft 365 Copilot licensing does not replace
that billing setup.

You need a tenant/billing administrator, an Entra administrator authorized to
grant consent and create federation, a Search source administrator, and an
application owner who can implement the credential path. Search Service
Contributor is the recommended keyless knowledge-object management role.
Private Azure resources still need permitted access to Microsoft 365 and Entra.

!!! warning "Preview and action scope"
    Work IQ can invoke capabilities that perform actions, not only retrieve
    information. Approve trusted applications/users, permissions, billing and
    data handling before a pilot. The preview has no SLA and is not recommended
    for production. Do not describe this integration as guaranteed read-only.

## How to prepare a Work IQ pilot

<span id="prepare-the-tenant"></span>
<span id="configure-the-authentication-contract"></span>
<span id="configure-authentication"></span>
<span id="authentication-contract"></span>

### 1. Prepare tenant access and federation

Initialize the environment through the [full-stack deployment guide](deploy-full-stack.md).
Enable Work IQ billing and assign pilot users. Follow the
[official Entra authentication procedure](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-work-iq#set-up-microsoft-entra-authentication)
for a customer-owned application exposing `access_as_user`.
The application needs delegated `WorkIQAgent.Ask` permission and administrator
consent. The application also needs a federated credential trusting Search's
managed identity.

Record the application's client ID and the federated credential's **object
ID**. Neither is the Search principal ID. Creating the source does not create
these Entra objects or grant consent. If Search does not exist yet, provision
the foundation with Work IQ disabled, establish federation using its actual
identity, then enable and reprovision the source.

### 2. Declare the source before provisioning it

In root `main.parameters.json`, merge these entries into
`parameters.additionalAppConfigurationSettings.value`. Preserve existing
host/mode entries. Values are strings; `agent-lz` is the shared label:

```json
[
  { "name": "WORK_IQ_ENABLED", "value": "true", "label": "agent-lz" },
  { "name": "WORK_IQ_KNOWLEDGE_SOURCE_NAME", "value": "work-iq-pilot", "label": "agent-lz" }
]
```

These are source-setup keys, not native capability switches. Their defaults
are `false` and an empty source name. There is no declared environment mapping
for those two keys; setting same-named `azd` variables alone does not publish
them. Both providers publish explicit additional settings before Search setup.
See [Application settings](application-settings.md) for ownership and effective values.

The following nonsecret identity inputs have an explicit deployment environment
publication path:

```bash
azd env set WORK_IQ_APPLICATION_ID "<work-iq-app-client-id>"
azd env set WORK_IQ_FEDERATED_CREDENTIAL_ID "<federated-credential-object-id>"
azd env set FOUNDRY_IQ_API_VERSION "2026-08-01-preview"
```

Set `WORK_IQ_TENANT_ID` only when the app is in another tenant; it is also a
published nonsecret UUID. Retain `RETRIEVAL_BACKEND=foundry_iq`. The template
uses `workIQParameters.entraAppAuthentication`; the default Blob API
`2026-05-01-preview` is incompatible with this implemented source contract.

### 3. Provision and inspect the knowledge objects

1. Run `azd provision` through the selected deployment guide after the
   identity inputs and source declaration are ready.
2. In Search, inspect the source's app/federation values and its reference
   in the intended knowledge base. Confirm the names are distinct from other
   sources.

Missing bindings, incompatible API settings or unverified Work IQ consent fail
setup rather than silently dropping the source.

Platform setup reconciles its named sources and knowledge base. Later
provisioning can overwrite manual edits. Use reviewed template changes for
platform-owned objects, or separate names and explicit ownership for
operator-managed objects. Neither provider provisions Microsoft 365 billing,
user assignment or consent.

### 4. Implement the application credential and retrieval path

Choose a reviewed native Foundry MCP connection or explicitly integrate the
direct connector. [Foundry IQ](foundry-iq.md#native-tools-and-the-accelerator-boundary)
explains why the generated `CognitiveSearch` connection is not the native
`RemoteTool` MCP connection. Merely enabling `FOUNDRY_IQ_ENABLED` does not
implement Work IQ user delegation.

For the direct-connector recipe, the application must obtain and validate the
original user assertion for the Work IQ app, including `access_as_user`.
It must forward that assertion to the connector in trusted invocation context.
The connector sends the raw assertion in
`x-ms-query-work-iq-source-authorization`. It must not be a Search-audience
token or a workload managed-identity token.

The available UI helper/connector code defines
`x-client-work-iq-assertion`, but the native Responses UI does not call that
helper. Native `ToolIdentity` carries no Work IQ assertion. You must implement
the missing acquisition/forwarding/invocation wiring, or configure and prove
the equivalent native service connection contract. Do not put assertions in
prompts, tool arguments, saved history, checkpoints or logs.

When reusing the UI helper, `WORK_IQ_APPLICATION_ID` must match
`OAUTH_AZURE_AD_CLIENT_ID`, and the optional Work IQ tenant must match the UI's
OAuth tenant. The helper does not exchange an assertion for a separate Work IQ
app. Any confidential OBO client secret stays server-side as a Key Vault
reference; follow [Sign-in & access](application-auth.md).

Publish/deploy the custom integration only after registration, consent and
federation are verified. Source/identity/binding changes require the matching
setup and application redeployment, not just provider refresh. For a direct
connector, `FOUNDRY_IQ_MAX_RUNTIME_SECONDS` defaults to `120`; that setting is
not loaded by native MCP tool composition.

<span id="verify-before-connecting-users"></span>
<span id="diagnose-or-back-out"></span>

<span id="acceptance-and-recovery"></span>

## Verify and recover

Use a known Microsoft 365 document and two pilot accounts with different
permissions. The allowed user must receive the expected answer and source
reference. The denied user's retrieved content and citations must exclude the
document. Missing/expired/wrong-audience assertions must fail, not retry under
the workload identity. Concurrent sessions must not share credentials or content.

Verify actual source activity, not just provisioning or container health.
Source omission is not successful Work IQ grounding. A Foundry call ID does
not substitute for the source's required user assertion. Record application
version, knowledge-base/source names and nonsecret correlation IDs without
logging tokens or Microsoft 365 content.

Recovery restores the prior compatible publication/settings and removes only
the pilot source reference. Do not delete shared tenant objects or other
knowledge sources. Revoking pilot-only consent, assignments and federation
requires the relevant administrator's separate approval.

<span id="direct-work-iq-mcp-is-different"></span>

## Callable Work IQ MCP tools are a different integration

The [Work IQ MCP product](https://learn.microsoft.com/microsoft-365/copilot/extensibility/work-iq/mcp/overview)
exposes callable tools, not this `workIQ` knowledge source. It needs its own
reviewed tool registration and authentication. It does not remove source
consent requirements, and deploying Agent App MCP Server does not install it.
See [Tools & MCP](agent-tools.md).
