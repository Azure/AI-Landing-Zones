# Work IQ

Work IQ provides the signed-in user's Microsoft 365 context, including documents,
email and meetings. As a Foundry IQ `workIQ` knowledge source, it queries that
context at retrieval time, without Agent App Ingestion or a landing-zone index
copy of the Microsoft 365 corpus.

This page explains the integration contract. Deployment procedures remain in
the [Deploy full stack runbook](deploy-full-stack.md).

<span id="check-hosted-support-first"></span>

## Product support and application readiness

Microsoft supports a [Work IQ knowledge source](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-work-iq)
in preview. The source can participate in a Foundry IQ knowledge base called by
Foundry Agent Service. Preview status does not require a custom ingestion
pipeline.

**The accelerator does not provide a configuration-only hosted integration.**
Its template emits a `workIQ` source without the app-authentication properties
required by the current service contract. Its connector uses the generic
source-authorization header, and its hosted entrypoint supplies no delegated
user context. Source registration, token delivery and connector authentication
need coordinated implementation before this path can work.

`WORK_IQ_ENABLED` and `WORK_IQ_KNOWLEDGE_SOURCE_NAME` select the source in the
shipped connector; they do not supply the missing integration.
[Foundry IQ](foundry-iq.md) explains the hosted identity integration gap.

<span id="prepare-the-tenant"></span>

## Tenant and governance requirements

The [Work IQ tenant guide](https://learn.microsoft.com/microsoft-365/copilot/extensibility/work-iq/enable-work-iq)
describes administrator enablement and billing. It requires a usage-based billing
plan, its Azure subscription/resource group and assignment of querying users.
Microsoft 365 Copilot licensing does not replace this billing setup.

Tenant enablement, delegated consent and retrieval-service access are separate
requirements. The source administrator needs permission to manage knowledge
objects; Microsoft recommends Search Service Contributor for keyless management.
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
defines registration, federation and client consent. The shipped template and
connector do not implement that complete contract. A reviewed
[custom application](build-your-own-app.md) needs trusted per-user assertion
delivery and matching registration/request changes, not runtime flags alone.
Bearer tokens must stay out of prompts, history and logs.

<span id="verify-before-connecting-users"></span>
<span id="diagnose-or-back-out"></span>

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
exposes callable tools. It is not the `workIQ` knowledge source or a remedy for
the hosted identity gap.
