# Work IQ

Work IQ provides the signed-in user's Microsoft 365 context, including documents,
email and meetings. As a Foundry IQ `workIQ` knowledge source, it queries that
context at retrieval time, without Agent App Ingestion or a landing-zone index
copy of the Microsoft 365 corpus.

This page explains the integration contract. Deployment procedures remain in
the [full-stack deployment guide](deploy-full-stack.md).

<span id="check-hosted-support-first"></span>

## Product support and application readiness

Microsoft supports a [Work IQ knowledge source](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-work-iq)
in preview. The source can participate in a Foundry IQ knowledge base called by
Foundry Agent Service. Preview status does not require a custom ingestion
pipeline.

The supplied source template includes the app-authentication contract and the
UI/hosted path keeps Work IQ's app-audience assertion separate from the Search
token. No custom retrieval connector is required. Administrator registration,
consent, federation and billing remain prerequisites.

Enable the named source with `WORK_IQ_ENABLED` and
`WORK_IQ_KNOWLEDGE_SOURCE_NAME`, configure the identity values below, and select
`FOUNDRY_IQ_API_VERSION=2026-08-01-preview`. Missing required settings or
unverified consent stop provisioning instead of silently removing the source.
[Foundry IQ](foundry-iq.md) explains the integrated identity boundary.

For application retrieval, select `RETRIEVAL_BACKEND=foundry_iq`.
`WORK_IQ_ENABLED` defaults to `false` and the source name defaults to empty.
The source must belong to the selected knowledge base. These runtime settings
do not register it or grant Microsoft 365 access.
`FOUNDRY_IQ_MAX_RUNTIME_SECONDS` defaults to `120` and provides the retrieve
runtime ceiling when remote sources are enabled.
[Application settings](application-settings.md) explains effective values and
the restart or new hosted version needed after a change.

<span id="prepare-the-tenant"></span>

## Tenant and governance requirements

The [Work IQ tenant guide](https://learn.microsoft.com/microsoft-365/copilot/extensibility/work-iq/enable-work-iq)
describes administrator enablement and billing. It requires a usage-based billing
plan, its Azure subscription/resource group and assignment of querying users.
Microsoft 365 Copilot licensing does not replace this billing setup.

Tenant enablement, delegated consent and retrieval-service access are separate
requirements. The source administrator needs permission to manage knowledge
objects. Microsoft recommends Search Service Contributor for keyless management.
Network-isolated Azure resources still need the permitted paths to Microsoft 365
and Microsoft Entra services.

!!! warning "Preview scope"
    Microsoft warns that this source can invoke Work IQ capabilities that
    perform actions, not only retrieve information. A pilot needs trusted
    applications/users, reviewed permissions, billing and data-handling approval.
    Preview functionality has no SLA and is not recommended for production.

<span id="configure-the-authentication-contract"></span>
<span id="configure-authentication"></span>

## Authentication contract

The accelerator defaults to Search API `2026-05-01-preview`. Microsoft's current
`2026-08-01-preview` source contract requires
`workIQParameters.entraAppAuthentication`, including the app's client ID and
federated credential object ID. The tenant ID is required for a cross-tenant
app registration. These are distinct Entra objects, not source names.

| Runtime setting | Required value |
| --- | --- |
| `WORK_IQ_APPLICATION_ID` | Work IQ app's application/client ID. The bundled UI requires the same value as `OAUTH_AZURE_AD_CLIENT_ID`. |
| `WORK_IQ_FEDERATED_CREDENTIAL_ID` | Object ID returned when creating the app's federated credential, not the Search principal ID or credential name. |
| `WORK_IQ_TENANT_ID` | App tenant ID when different from Search's tenant. Otherwise optional. It must match the bundled UI's OAuth tenant. |

These are nonsecret UUIDs, published with label `agent-lz` when explicitly
supplied as deployment environment inputs. They do not create the Entra objects
or grant tenant consent.

The customer-owned app exposes `access_as_user` and has the delegated
`WorkIQAgent.Ask` permission with administrator consent. A federated credential
allows the Search managed identity to authenticate as that app without storing
a client secret in the source.

At query time, service authentication to Search is separate from the
signed-in user's assertion:

- The user assertion targets the customer-owned Work IQ app and includes
  `access_as_user`.
- The current contract carries the raw assertion in
  `x-ms-query-work-iq-source-authorization`, **not**
  `x-ms-query-source-authorization`.
- Search exchanges that assertion for delegated Work IQ access. A Search-audience
  user token or the agent's managed-identity token is not a substitute.

The [official authentication procedure](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-work-iq#set-up-microsoft-entra-authentication)
defines registration, federation and client consent. For the bundled UI, use
its OAuth app as the Work IQ application: expose `access_as_user`, grant
`WorkIQAgent.Ask` and configure Search federation on that registration.
The built-in path validates and forwards the original app-audience assertion
through `x-client-work-iq-assertion`. It never substitutes the Search token or
invokes Work IQ as the workload. It does not exchange an assertion for a
separate Work IQ app. Mismatched application or UI-tenant settings fail closed.
Bearer tokens must stay out of prompts, history and logs.

<span id="verify-before-connecting-users"></span>
<span id="diagnose-or-back-out"></span>

The backend's classic OBO helper also needs
`OAUTH_AZURE_AD_TENANT_ID`, `OAUTH_AZURE_AD_CLIENT_ID` and
`OAUTH_AZURE_AD_CLIENT_SECRET` for exchanges where applicable. Keep the secret
server-side as a Key Vault reference. It is not a credential embedded in the
Work IQ knowledge-source definition. Follow
[Application authentication](application-auth.md) for the complete login and
delegation setup.

Do not treat connector-level source omission as successful Work IQ grounding.
The source builder can skip an empty name or missing OBO token with a warning.
The context provider requires user delegation for enabled remote sources, and
the native protected path additionally requires the Work IQ assertion and
compatible API. A Toolbox call ID is not a substitute for either token.
`FOUNDRY_IQ_FORWARD_SOURCE_AUTH` is deprecated and ignored.

## Acceptance and recovery

A pilot needs a known Microsoft 365 document and two accounts with different
permissions. Acceptance includes the allowed user's grounded answer and source
reference, exclusion of that document for the denied user, and rejection of
missing or expired assertions. Concurrent sessions must not share tokens or
retrieved content.

Provisioning can overwrite manual knowledge-base edits. Recovery restores the
previous application/settings and removes the pilot source reference without
deleting shared tenant objects. Revocation of pilot-only grants is a separate,
authorized action.

<span id="direct-work-iq-mcp-is-different"></span>

The separate [Work IQ MCP product](https://learn.microsoft.com/microsoft-365/copilot/extensibility/work-iq/mcp/overview)
exposes callable tools. It is separate from the `workIQ` knowledge source and
does not replace this source's consent or delegated assertion requirements.
See [Tools & MCP](agent-tools.md) for callable operations and
[Monitoring & audit](application-monitoring.md) for operational traces.
