<span id="application-access"></span>

# Agent Application access

Agent Application has three independent access boundaries: UI admission,
delegated Foundry invocation and document authorization. Signing in does not
grant access to every document. This page describes the supplied authentication
contract; deployment and redeployment belong to the
[Deploy full stack runbook](deploy-full-stack.md).

<span id="before-you-start"></span>
<span id="1-configure-ui-sign-in"></span>

## UI sign-in

**Single-tenant** means sign-in is limited to one Entra directory.
A **confidential web application** keeps its credential on the server, not in
browser code. Its registration defines the login callback and exposed API
permissions.

The UI uses a confidential, single-tenant Entra web application. Its exposed
API scope is `api://<client-id>/user_impersonation`. The Web redirect URI is
the UI's canonical HTTPS origin plus `/auth/oauth/azure-ad/callback`, including
any supported deployment prefix. `CHAINLIT_URL` identifies that external origin;
behind TLS-terminating ingress it prevents an incorrect HTTP callback.

The [single-tenant registration](https://learn.microsoft.com/entra/identity-platform/quickstart-register-app)
and [exposed API scope](https://learn.microsoft.com/entra/identity-platform/quickstart-configure-app-expose-web-apis)
are separate from Azure subscription permissions. Downstream Foundry delegated
permissions and consent are also separate from consent to the UI API.
Protected native retrieval additionally needs delegated Search consent for
`https://search.azure.com/.default`. Shared Blob/ADLS citation downloads need
delegated Azure Storage `user_impersonation` consent for
`https://storage.azure.com/.default`; this does not grant source access.

| UI runtime key | Contract |
| --- | --- |
| `OAUTH_AZURE_AD_CLIENT_ID`, `OAUTH_AZURE_AD_TENANT_ID` | Entra application and directory IDs, not URLs. |
| `OAUTH_AZURE_AD_ENABLE_SINGLE_TENANT` | `true` for this contract. |
| `OAUTH_AZURE_AD_CLIENT_SECRET` | Key Vault reference to the credential value, not the secret ID. |
| `OAUTH_AZURE_AD_SCOPES` | UI API scope plus `openid`, `profile`, `offline_access`. Graph scopes such as `User.Read` are rejected by the callback. |
| `CHAINLIT_AUTH_SECRET` | Persistent, protected session-signing secret. |
| `ALLOW_ANONYMOUS` | `false` for authenticated access. |
| `HOSTED_AGENT_AUTH_MODE` | `user_delegated`, the default hosted mode. |
| `RETRIEVAL_AUTH_MODE` | `native_search` for the integrated native permission path. Published under `agent-lz`; not an anonymous-access switch. |

Runtime keys normally use App Configuration label `agent-lz`. The UI identity
needs permission to resolve its Key Vault references. Credentials are not
plaintext settings or browser code.
[Deployment settings](configuration.md) describes setting ownership and overrides.

<span id="2-limit-application-admission"></span>
<span id="2-limit-agent-application-admission"></span>

## Application admission

`ALLOWED_USER_PRINCIPALS` admits individual users by comma-separated
`tenant-id:object-id` values. `ALLOWED_USER_NAMES` is an alternative list of
sign-in names. The lists combine with **OR**; empty lists admit all successfully
authenticated users. The callback does not fetch Graph group membership.
These lists restrict UI admission, not Foundry access or document access-control
lists (ACLs).

The UI caches configuration at startup. Changes need a UI process reload and
a new sign-in. Hosted orchestrator changes need a new agent version.
Provisioning can republish template-managed values; deployment inputs and
runtime settings are not interchangeable.

<span id="3-verify-the-retrieval-identity-boundary"></span>

## Hosted retrieval identity boundary

The UI's OBO exchange obtains a token for `HOSTED_AGENT_RESOURCE_SCOPE`, the
deployed Foundry data-plane audience ending in `/.default`.
`HOSTED_AGENT_BASE_URL` is the endpoint, not that scope. The UI API scope,
Foundry consent and Foundry project/agent access all have distinct roles.
[Microsoft's OBO guidance](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow)
describes downstream consent.

`user_delegated` rejects a missing user token without service-identity fallback.
`service_identity` would make Foundry see the UI service rather than the user.
Neither mode alone establishes authorization inside the hosted container.

With `RETRIEVAL_AUTH_MODE=native_search`, the supplied UI performs a separate
OBO exchange for `https://search.azure.com/.default` from the same authenticated
UI assertion used for the Foundry exchange. Foundry forwards the resulting
`x-client-search-token` to both hosted adapters. The connector supplies that
raw token in `x-ms-query-source-authorization`, separately from its workload
authentication to Search. It does not exchange the Search token again.

This built-in path does not require customer-written Toolbox integration or
forward the browser's Authorization header unchanged. Native Search evaluates
document permissions; caller-provided identity/group IDs are not entitlement
evidence. The transport identity's Search role alone does not grant the user
access to protected sources.

Required retrieval rejects a missing credential before execution. Tokens stay
request-local, outside prompts, conversation history and recovery checkpoints.
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

## Protected citation downloads

Native hosted citations use `/api/download/{grant_token}` on the authenticated
UI rather than public Blob links or Blob SAS. The signed selector is bound to
the principal and UI session; it is not a document permission. Every download
checks the current identity and source authorization again.

Shared Blob/ADLS documents use the current user's Storage OBO token. The user
needs actual Blob RBAC or ADLS ACL access, even if retrieval returned a citation.
Missing Storage consent or source access never falls back to the UI identity.

Conversation uploads instead require a fresh native Search check for the exact
document URL, conversation and authenticated uploader before the UI workload
reads the Blob. Deployment assigns the bundled UI Search Index Data Reader
through its `retrieval-reader` capability profile for this transport check.
Its existing Blob transport grants do not authorize a user by themselves.
Missing ownership, scope or an exact authorized result denies the download.

The route accepts only configured storage locations and enforces bounded
streaming. Embedded sessions retain their own principal/session boundary.
External source links, such as SharePoint citations, remain subject to the
source's authentication rather than being proxied as arbitrary Blob downloads.

<span id="4-run-an-allowdeny-test"></span>

## Authorization evidence

Protected retrieval is only established by tests through the deployed
integration, using independent signed-in users and nonsensitive documents.
An answer without a citation is not sufficient evidence of denial.

| Boundary | Required observation |
| --- | --- |
| Sign-in | Signed-out callers cannot chat. |
| Admission | A user absent from both nonempty admission lists is denied. |
| Foundry invocation | An admitted, authorized user can invoke the deployed agent through OBO. |
| Shared document | Both authorized users retrieve its content and reference. |
| Restricted document | Only its authorized user retrieves it; denied retrieval contains no document ID, excerpt or citation, including exact-title questions. |
| Citation download | A permitted user downloads the cited document; another user, an expired session or a revoked source permission cannot redeem its grant. |
| Uploaded document | Only the authenticated uploader can retrieve or download it in its conversation; knowing a document URL or conversation ID is insufficient. |
| Conversation ownership | A different user cannot open the owner's history. |

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
authentication outcomes. Both hosted adapters preserve a bounded, validated
claims challenge from the configured Search response. Provider response bodies,
authorization URLs and arbitrary resource hints are not recovery instructions.

The UI offers explicit interactive authentication rather than retrying the
failed turn. Standalone chat uses the configured tenant, UI scopes and OAuth
callback. Its short-lived encrypted recovery context is bound to the current
principal and session. Embedded Entra sessions use the portal's MSAL and
authenticated bootstrap path, not a standalone sign-in redirect.

After verification, submit a new turn. Failed or partially streamed turns are
never replayed automatically. A source `403` without a usable claims challenge
remains an authorization denial; signing in cannot grant missing document
permissions. Keep claims out of URLs, logs, conversation history and checkpoints.

A denied user retrieving protected content is an authorization failure that
blocks exposure of that corpus. Recovery does not replace the delegated caller
with a service identity or disable authentication.
