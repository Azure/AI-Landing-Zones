<span id="application-access"></span>

# Agent Application access

Agent Application has three independent access boundaries: UI admission,
delegated Foundry invocation and document authorization. Signing in does not
grant access to every document. Follow the setup sequence below for the default
Foundry-hosted agent and Container Apps frontend. Azure CLI and azd sign-in
authenticate the deployment operator, not application users.
Deployment and redeployment belong to the
[full-stack deployment guide](deploy-full-stack.md).

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

In the [Microsoft Entra admin center](https://entra.microsoft.com/), open
**App registrations > New registration**. Select **Accounts in this
organizational directory only** and record the **Application (client) ID**
and **Directory (tenant) ID**. Use this same registration for the UI's
confidential web client and its exposed API.

Open **Expose an API**, set the Application ID URI to `api://<client-id>`,
and add an enabled delegated scope named `user_impersonation`.
In the registration's manifest, set `api.requestedAccessTokenVersion` to `2`.
The UI needs an access token for this API, not an ID token or a Microsoft
Graph access token. Keep the application confidential; do not enable public
client flows to work around a token error.

Follow Microsoft's [registration](https://learn.microsoft.com/entra/identity-platform/quickstart-register-app)
and [exposed-scope procedure](https://learn.microsoft.com/entra/identity-platform/quickstart-configure-app-expose-web-apis)
for the portal fields. Register the final callback in step 3.

**Check:** The tenant/client IDs, API URI, enabled scope and version-2 token
setting belong to the intended environment.

### 2. Authorize delegated Foundry calls

In **API permissions**, configure consent to the UI API's
`user_impersonation` scope and add the **Foundry resource's delegated
`user_impersonation` permission** for downstream OBO. These are permissions
on two different APIs, even though their scope names are the same.
Have the Entra administrator grant the consent required by tenant policy
before onboarding users.

Protected native retrieval also needs delegated Search consent for
`https://search.azure.com/.default`. Shared Blob/ADLS citation downloads need
delegated Azure Storage `user_impersonation` consent for
`https://storage.azure.com/.default`. These permissions do not grant the user
access to source documents; retain the source's RBAC and ACL checks.

For the standard Foundry-resource authorization scheme (`AzureRbac`, also
known as `Entra`), the downstream scope is `https://ai.azure.com/.default`.
Confirm the deployed endpoint's audience with its owner; do not substitute
the UI API scope or a management-plane audience. Set
`HOSTED_AGENT_RESOURCE_SCOPE` in the selected azd environment before provision,
as shown in the [full-stack deployment guide](deploy-full-stack.md#orchestrator-topology).
This value is separate from the UI login scopes in step 4.

The [Foundry client authorization procedure](https://learn.microsoft.com/azure/foundry/agents/how-to/configure-agent-endpoint-authorization#authorize-the-client-to-request-a-foundry-token)
explains downstream permission and consent. The UI exchanges its user's API
token for a Foundry token server-side; consent alone does not grant that user
permission to invoke the agent.

**Check:** Both API permissions have the required consent, and the selected
Foundry audience matches the deployed authorization scheme.

### 3. Register the final HTTPS callback

After `azd provision`, obtain the frontend HTTPS URL from the deployment
outputs. For a private UI, the browser must have private connectivity.
For Application Gateway, use the approved external hostname from its
[sign-in URL procedure](application-gateway.md#3-configure-the-uis-external-sign-in-url).

In the app registration, open **Authentication > Add a platform > Web**.
Register the exact callback, for example:

```text
https://chat.contoso.com/auth/oauth/azure-ad/callback
```

Set `CHAINLIT_URL` to that UI origin (`https://chat.contoso.com`), without a
trailing slash. Include any supported deployment prefix consistently in the
URL and callback. Keep previously used callbacks only while they are still
approved and required.

**Check:** The configured callback matches the browser-facing scheme, host
and path exactly; it is not the Foundry endpoint.

### 4. Store credentials and publish UI settings

In **Certificates & secrets**, create the client secret under your tenant's
expiry policy. Transfer its **value**, not its secret ID, directly into the
environment's Key Vault through an approved secure process. Record its expiry
and rotation owner. Do not copy the value into source, shell commands or logs.

In **App Configuration > Configuration explorer**, create a **Key Vault
reference** named `OAUTH_AZURE_AD_CLIENT_SECRET`, label `agent-lz`, pointing
to that stored secret. Select the Key Vault reference type, not an ordinary
string containing a secret or URI. Keep a stable, securely generated
`CHAINLIT_AUTH_SECRET` of at least 32 UTF-8 bytes in Key Vault and publish it
as a reference too; do not
regenerate an existing session-signing secret during a routine update.

Publish the following values in the same store:

<dl>
<dt><code>OAUTH_AZURE_AD_CLIENT_ID</code></dt>
<dd>Application (client) ID from step 1.</dd>

<dt><code>OAUTH_AZURE_AD_TENANT_ID</code></dt>
<dd>Directory (tenant) ID from step 1.</dd>

<dt><code>OAUTH_AZURE_AD_ENABLE_SINGLE_TENANT</code></dt>
<dd><code>true</code>.</dd>

<dt><code>OAUTH_AZURE_AD_SCOPES</code></dt>
<dd><code>api://&lt;client-id&gt;/user_impersonation,openid,profile,offline_access</code>,
replacing <code>&lt;client-id&gt;</code>. Do not add Graph scopes such as
<code>User.Read</code> or the Foundry scope here.</dd>

<dt><code>CHAINLIT_URL</code></dt>
<dd>Canonical UI HTTPS URL from step 3.</dd>

<dt><code>ALLOW_ANONYMOUS</code></dt>
<dd><code>false</code>.</dd>

<dt><code>HOSTED_AGENT_AUTH_MODE</code></dt>
<dd><code>user_delegated</code>.</dd>

<dt><code>RETRIEVAL_AUTH_MODE</code></dt>
<dd><code>native_search</code>, the integrated native permission path;
not an anonymous-access switch.</dd>
</dl>

Use label `agent-lz`. The frontend managed identity needs App Configuration
Data Reader and Key Vault Secrets User at the relevant scopes; see
[default hosted permissions](../bicep/permissions.md#frontend-container-app).
Remove or update conflicting UI process-environment or other selected-label
overrides. [Deployment settings](configuration.md#runtime-settings) explains
precedence and provisioning-managed values.

**Check:** The two secrets are Key Vault references, nonsecret keys have the
intended values and the actual frontend identity can resolve the references.
Do not display resolved credentials as verification.

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

`ALLOWED_USER_PRINCIPALS` admits individual users by comma-separated
`tenant-id:object-id` values. `ALLOWED_USER_NAMES` is an alternative list of
sign-in names. The lists combine with **OR**; empty lists admit all successfully
authenticated users. The callback does not fetch Graph group membership.
These lists restrict UI admission, not Foundry access or document access-control
lists (ACLs). Publish the approved admission settings with label `agent-lz`;
for a restricted pilot, do not leave both lists empty.

**Check:** An intended pilot user has both UI admission and Foundry caller
access. Source/document grants remain a separate data-owner decision.

### 6. Reload the UI and verify each boundary

For the first deployment, return to root `azd deploy` in the
[full-stack deployment guide](deploy-full-stack.md#step-4-deploy). For an existing UI,
restart/redeploy its Container App after publishing settings, then sign out
and sign in again. The UI caches settings at startup.
A UI-only authentication change does not require restarting the hosted agent.
Changes to hosted runtime settings require a new agent version instead.

Verify in order: signed-out chat is denied; an admitted test user completes
sign-in and returns to the exact callback; that user can invoke the intended
agent through OBO; and a user outside the admission lists is denied.
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
