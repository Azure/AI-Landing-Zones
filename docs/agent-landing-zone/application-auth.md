<span id="application-access"></span>

# Agent Application access

Agent Application has independent access boundaries: UI admission,
native host invocation, owner-bound execution and document/tool authorization.
Signing in does not grant access to every document or run.
The UI server, also called the backend for frontend (BFF), checks admission
and maps users to their native sessions.

Follow the setup sequence below for the default
Foundry-hosted agent and Container Apps frontend. Azure CLI and azd sign-in
authenticate the deployment operator, not application users.
Deployment and redeployment belong to the
[full-stack deployment guide](deploy-full-stack.md).

<div class="runbook-diagram" markdown="1">

<div class="runbook-diagram__summary" markdown="1">

**Three separate access checks**

1. Entra sign-in supplies a UI API token; the UI checks admission and ownership.
2. With OBO enabled, the UI exchanges delegated credentials for Foundry.
   The user also needs Foundry caller access.
   The managed Foundry Toolbox handles downstream user authorization for retrieval.
   With OBO disabled, component identities authorize supported service calls.
3. Each source enforces its authorization contract. A source requiring user
   delegation fails explicitly when OBO is unavailable. Login and workload roles
   do not grant access to every document.

</div>

[![Entra sign-in reaches the Container Apps UI, which checks admission and ownership. The UI uses OBO to invoke Foundry under the user's delegated identity and caller RBAC. The hosted agent uses the managed Foundry Toolbox to retrieve through Azure AI Search, where source and document permissions apply. Required user delegation fails closed when unavailable.](../media/runbooks/application-auth.svg?v=3e62c999471f)](../media/runbooks/application-auth.svg?v=3e62c999471f){: .runbook-diagram__image aria-label="Open full-size application access diagram"}

[Open full-size diagram](../media/runbooks/application-auth.svg?v=3e62c999471f){: .runbook-diagram__open}

</div>

## Choose user delegation

Both modes require Entra login and UI admission. This choice controls downstream
credentials, not whether users must sign in.

| Operator choice | `HOSTED_AGENT_AUTH_MODE` | Access model |
| --- | --- | --- |
| User delegation enabled - OBO, default | `user_delegated` | User-delegated Foundry invocation and managed Toolbox authorization for protected retrieval. |
| User delegation disabled - without OBO | `service_identity` | Component identities access sources that support service authentication, subject to their grants and authorization rules. |

Use the coordinated platform, UI and native runtime implementation of this
contract. Changing an App Configuration key alone does not upgrade components.
The diagram above illustrates the delegated default.

Select the mode for deployment and persist it in App Configuration under
`agent-lz`. It is a **structural setting**, not a per-user or per-message switch.
To change it later, reconcile the source policy, connections and scoped role
assignments, then publish compatible application revisions and start new
sessions. Do not remove existing source permission metadata or reuse old native
session IDs under another caller identity.

The mode without OBO does not impose a Blob-only source or capability allowlist.
Existing indexes and other source types can be configured through their normal
contracts. This does not guarantee that each provider supports service access.
Tools such as Work IQ that require user delegation must fail at invocation when
that delegation is unavailable, rather than blocking application startup,
disabling the tool silently or changing credentials.

All admitted users share the source access granted to the service identities,
not per-user document authorization. Scope these grants to content approved for
that application audience. An OBO consent failure never selects service
credentials automatically. UI login remains subject to tenant consent and
Conditional Access policies in either mode. Native inline private attachments
retain their separate gate and owner boundary.

## Trusted identity and native state

The UI/BFF binds the authenticated tenant/user to native conversation and
workflow IDs. Validate the owner on reads, history discovery, feedback,
attachments and human replies. For a human reply, also validate the currently
pending request and intended run. A stale, duplicate or wrong-run action must
not advance another or completed execution.

Hosted must use trusted platform invocation context or an explicitly
supported delegation path. Container Apps uses the authenticated BFF boundary
and identity-based scheduler access. A shared managed identity authorizes a
service connection; it does **not** make arbitrary session IDs or body-supplied
user metadata safe for per-user access. Missing required trusted context
fails closed.

Native persistence does not remove the selected mode's source authorization.
Functional configuration snapshots must never freeze user permissions:
recheck current authorization on every interaction.
See [Agent hosting](hosted-agents.md) and
[Workflows & human input](workflows.md).

<span id="before-you-start"></span>
<span id="1-configure-ui-sign-in"></span>
<span id="ui-sign-in"></span>

## Configure login in order

Complete steps 1-2 before first provision. After provisioning supplies the
frontend URL, complete steps 3-5 before deploying the application, then verify
step 6. For an existing deployment, record its current registration, settings,
secret references and grants before changing them.

| Owner | Responsibility |
| --- | --- |
| Entra application administrator | App registration, delegated API permissions, consent and client credential. |
| Deployment/configuration operator | Provisioning, Key Vault references, App Configuration settings and UI deployment/reload. |
| Azure RBAC administrator and data owner | Foundry caller access and source/document permissions, separately. |

### 1. Register the UI application

--8<-- "agent-login-registration.md"

### 2. Authorize delegated Foundry calls

This step describes the default `user_delegated` mode. With `service_identity`,
retain the UI API's login permission and tenant-required consent, but authorize
downstream service calls through the component identities instead. Do not request
delegated Foundry, Search or Storage permissions solely for service access.
An operation requiring user delegation returns an explicit failure in that mode.

--8<-- "agent-login-consent.md"

From the platform checkout root, select the intended azd environment and set
the confirmed audience **before `azd provision`**, for example:

```bash
azd env select <environment-name>
azd env set HOSTED_AGENT_RESOURCE_SCOPE https://ai.azure.com/.default
```

Use the audience approved for your endpoint. This supported deployment input
is separate from the UI login scopes in step 4.

**Check:** Both API permissions have the required consent, and the selected
Foundry audience matches the deployed authorization scheme.

### 3. Register the final HTTPS callback

After `azd provision`, obtain the frontend HTTPS URL from the deployment
outputs. For a private UI, the browser must have private connectivity.
For Application Gateway, use the approved external hostname from its
[sign-in URL procedure](application-gateway.md#3-configure-the-uis-external-sign-in-url).

--8<-- "agent-login-callback.md"

### 4. Store credentials and publish UI settings

--8<-- "agent-login-settings.md"

<span id="2-limit-application-admission"></span>
<span id="2-limit-agent-application-admission"></span>
<span id="application-admission"></span>

### 5. Grant caller access and restrict admission

Have the Azure RBAC administrator grant approved users **Foundry Agent
Consumer** at the individual agent scope, or project scope when access to all
its agent endpoints is intended. Agent-scope grants can be made after the
first agent deployment and before user acceptance. Use Azure CLI for these
scopes following [Foundry RBAC](https://learn.microsoft.com/azure/foundry/concepts/rbac-foundry#agent-scope-role-assignments);
the Azure portal's consumer-role picker currently uses account scope.

Broader authoring roles are not needed just to invoke an endpoint.

With `service_identity`, grant the UI's actual workload identity the scoped
Foundry caller role instead of granting each UI user that downstream role.

The Hosted identity needs declared Foundry User access at the exact project
scope for the Toolbox. The project identity retains scoped Search access and
ingestion needs its declared Blob permissions. A UI caller grant is not an
ingestion or retrieval grant. Keep these grants limited to the approved resources.

--8<-- "agent-login-admission.md"

**Check:** An intended pilot user has both UI admission and Foundry caller
access. Source/document grants remain a separate data-owner decision.

### 6. Reload the UI and verify each boundary

For the first deployment, return to root `azd deploy` in the
[full-stack deployment guide](deploy-full-stack.md#step-4-deploy). For an existing UI,
restart/redeploy its Container App after publishing settings, then sign out
and sign in again. The UI caches settings at startup.

A UI-only authentication change does not require restarting the hosted agent.
Supported functional runtime parameters use App Configuration refresh and
per-run snapshots. Structural host, graph, identity or publication changes
require a compatible new publication; they are not live parameter updates.

First, verify that signed-out chat is denied. Then sign in as an admitted
test user and confirm the return to the exact callback.
Verify that the same user can invoke the intended agent through the selected
credential mode.
Finally, confirm that a user outside the admission lists is denied.
Use sanitized status/correlation information, not raw tokens.

**Login and invocation are not protected retrieval.** Complete the identity
integration and document allow/deny checks below before admitting protected
data. If login fails, use [Failure boundaries](#failure-boundaries) to isolate
callback, consent, credential and caller-access errors.

<span id="3-verify-the-retrieval-identity-boundary"></span>

## Hosted retrieval identity boundary

The UI's OBO exchange obtains a token for `HOSTED_AGENT_RESOURCE_SCOPE`, the
deployed Foundry data-plane audience ending in `/.default`.
`HOSTED_AGENT_BASE_URL` is the endpoint, not that scope. The UI API scope,
Foundry consent and Foundry project/agent access all have distinct roles.
[Microsoft's OBO guidance](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow)
describes downstream consent.

`user_delegated` rejects a missing user token without service-identity fallback.
`service_identity` makes Foundry see the UI service rather than the user.
Neither mode alone establishes authorization inside the hosted container.

Foundry invocation OBO is **not** a delegated Search assertion. The native
runtime connects through the official MAF `FoundryToolbox` integration, which
authenticates to the toolbox and forwards the current trusted Foundry call ID.
The managed service resolves the caller context and handles the knowledge
base's downstream source authorization, including its Search user credential.

The call ID is correlation context for that managed exchange, not a bearer
token or an independent permission grant. It must come from the current Hosted
request and must not be cached across users or fabricated by the application.
The runtime does not acquire or serialize a Search token as a model tool header.

Consent, source permissions and Conditional Access remain independent
requirements. Missing context or denied authorization must not trigger a retry
with workload privileges against protected content.

The UI returns `401 consent_required` when the managed flow reports
`oauth_consent_request`. Complete consent through the organization's approved
Foundry process and retry manually. This implementation does not open
service-returned consent links or automatically resume a request after consent.

Service mode does not retry through OBO or interactive consent.
An explicit consent request in service mode returns `403 user_delegation_required`
with instructions to enable OBO. Other tool failures return a safe `tool_failed`
message that distinguishes service permissions from a possible OBO requirement,
without exposing provider details or initiating a credential fallback.

Required retrieval rejects missing trusted context or denied tool access.
Downstream tokens stay outside application prompts, conversation history and
recovery checkpoints.
Consent, Conditional Access and source denial must be resolved at their own
boundary, not by stripping the credential or retrying as a service.
[Agent tools](agent-tools.md) explains the separate Toolbox extension boundary.

The protected native Blob ingestion default is
`FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS=["rbacScope"]`. Explicit `[]` removes
permission metadata for the supported intentionally shared Blob corpus.
That provides shared-source access, not per-user filtering.
[Foundry IQ](foundry-iq.md) and
[knowledge-base retrieval permissions](https://learn.microsoft.com/azure/search/agentic-retrieval-how-to-retrieve)
describe source-specific requirements.

Without OBO, the native connection authenticates with the declared component
identity and does not send a user Search assertion. The source must accept that
authentication and enforce its own authorization. Omitted or null ingestion
permission options retain the protected default. Mode selection does not clear
metadata, rewrite ACLs or make user-protected content service-accessible.

## Protected citation downloads

Downloads reuse the configured storage and Search bindings,
`SEARCH_SERVICE_QUERY_ENDPOINT`, `SEARCH_RAG_INDEX_NAME` and
`SEARCH_API_VERSION`. There is no separate permission-bypass switch.

Native hosted citations use `/api/download/{grant_token}` on the authenticated
UI rather than public Blob links or Blob SAS. The signed selector is bound to
the principal and UI session; it is not a document permission. Every download
checks the current identity and source authorization again.

In `user_delegated` mode, shared Blob/ADLS documents use the current user's
Storage OBO token. The user
needs actual Blob RBAC or ADLS ACL access, even if retrieval returned a citation.
Missing Storage consent or source access never falls back to the UI identity.

In `service_identity` mode, Blob document reads use the UI workload identity
and Storage enforces its scoped permissions. The route still validates the current
user, session, citation grant and configured storage allowlist. It must not
become a general Blob proxy or expose another user's conversation or files.
Protected conversation-upload downloads still require delegated Search
authorization and are denied without it.

Native private attachments are different: the authenticated UI checks the
owner-bound session and validates bounded inline file content before calling
the native host. They do not use this Blob download route, a Search upload
index, SAS or corporate ingestion. Cosmos stores descriptors only.
See [Private attachments](conversations.md#private-attachments) for the format
and transport limits. Model PDF/image understanding remains unverified.

The route accepts only configured storage locations and enforces bounded
streaming. Embedded sessions retain their own principal/session boundary.
External source links, such as SharePoint citations, remain subject to the
source's authentication rather than being proxied as arbitrary Blob downloads.

<span id="4-run-an-allowdeny-test"></span>

## Authorization evidence

Protected retrieval is only established by tests through the deployed
integration, using independent signed-in users and nonsensitive documents.
An answer without a citation is not sufficient evidence of denial.

The restricted-document cases below apply to OBO. In service mode, all admitted
users share the service's source access. Wrong-owner sessions and grants,
unapproved storage and operations requiring unavailable user delegation must
still be denied. Local mocked checks are not live Foundry acceptance.

| Boundary | Required observation |
| --- | --- |
| Sign-in | Signed-out callers cannot chat. |
| Admission | A user absent from both nonempty admission lists is denied. |
| Foundry invocation | An admitted user invokes through the selected credential mode, with the corresponding user or workload caller grant. |
| Shared document | Both authorized users retrieve its content and reference. |
| Restricted document | Only its authorized user retrieves it; denied retrieval contains no document ID, excerpt or citation, including exact-title questions. |
| Citation download | A permitted user downloads the cited document; another user, an expired session or a revoked source permission cannot redeem its grant. |
| Private attachment | Only its owner-bound conversation accepts the validated inline input; another user's session ID is rejected before native access. This is not a Blob upload/download feature. |
| Conversation/run ownership | A different user cannot open or continue the owner's native state or product history. |
| Human input | Wrong-owner, stale, duplicate and wrong-request/run replies do not advance the workflow. |
| Service identity | A caller cannot obtain user access merely by knowing a native ID or using shared workload credentials. |

Correlation IDs, effective configuration and agent version provide diagnostic
evidence without recording tokens or document contents. Permission changes
also depend on propagation and refreshed source metadata.

<span id="recover-safely"></span>

## Failure boundaries

Redirect mismatch concerns the exact callback URI. Consent/refresh failures
concern UI scopes, tenant and credential lifetime. Invocation denial can instead
indicate missing downstream consent or Foundry user/agent access.
Tool consent is separate from UI consent, as described in
[tool authentication](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/tool-authentication).

Initial UI token acquisition and downstream Search failures retain distinct
authentication outcomes. Recovery accepts only a bounded, validated
claims challenge from the configured Search response. Provider response bodies,
authorization URLs and arbitrary resource hints are not recovery instructions.

The UI offers explicit interactive authentication rather than retrying the
failed turn.

### Standalone chat

- **Sign-in:** use the configured tenant, UI scopes and OAuth callback.
  Existing standalone sessions may need a fresh ordinary login.
- **Recovery window: 180 seconds.** The encrypted recovery context is bound
  to the current principal and session.
- **Session secret:** the existing `CHAINLIT_AUTH_SECRET` must contain at
  least 32 UTF-8 bytes. No additional secret or redirect registration is needed.

### Embedded Entra sessions

Use the portal's MSAL and authenticated bootstrap path, not a standalone
sign-in redirect.

### Gateway and recovery checks

- **Preserve the routes:** gateways must preserve `/api/auth/recovery` and
  the normal OAuth routes.
- **Submit a new turn after verification:** failed or partially streamed
  turns are never replayed automatically.
- **Distinguish source denial:** a source `403` without a usable claims
  challenge remains an authorization denial. Signing in cannot grant missing
  document permissions.
- **Protect claims:** keep them out of URLs, logs, conversation history and
  checkpoints.

A denied user retrieving protected content is an authorization failure that
blocks exposure of that corpus. Recovery does not replace the delegated caller
with a service identity or disable authentication.
