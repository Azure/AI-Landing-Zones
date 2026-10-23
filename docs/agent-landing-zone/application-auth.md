<span id="application-access"></span>

# Agent Application access

Agent Application access has three parts: signing in to Agent App UI, invoking
Agent App Orchestrator as that user, and filtering retrieved documents by the
user's permissions. The UI uses an OAuth on-behalf-of (OBO) exchange to obtain
a Foundry token for the signed-in user.

The steps below configure sign-in with shipped settings. Protected hosted
retrieval also requires the custom integration described in step 3. Validate
each part before opening access to protected content.

## Before you start

- A deployed [Agent Application](deploy-full-stack.md), with the UI using
  `CHAT_BACKEND=hosted_agent`.
- An Entra app registration owner or administrator who can configure a
  confidential web application, plus an administrator authorized to grant the
  required API consent. These Entra permissions are managed separately from
  Azure subscription access.
- Permission to edit the deployment's App Configuration settings and Key Vault
  secrets, and to redeploy the affected component. Use a connected operator
  host for [private deployments](private-access.md).
  The UI runtime identity also needs access to resolve those Key Vault
  references. Grant that access to the runtime identity separately.
- Two test users in the tenant and nonsensitive test documents: one document
  readable by both, and one restricted to user A. User B must have no inherited
  group, source or administrative access to the restricted document.

Keep the Entra **Application (client) ID**, **Directory (tenant) ID**, and user
**Object IDs** separate from URLs. `HOSTED_AGENT_BASE_URL` is the deployed
agent endpoint; `HOSTED_AGENT_RESOURCE_SCOPE` is its data-plane token scope
ending in `/.default`, not an endpoint or an ARM scope.

## 1. Configure UI sign-in

1. In **Microsoft Entra admin center → App registrations**, select the
   registration for this UI, or [register a single-tenant application](https://learn.microsoft.com/entra/identity-platform/quickstart-register-app).
   Record its client and tenant IDs. Reuse this registration when changing
   the existing UI's access policy.
2. Under **Expose an API**, use Application ID URI `api://<client-id>` and
   [add an enabled delegated scope](https://learn.microsoft.com/entra/identity-platform/quickstart-configure-app-expose-web-apis)
   named `user_impersonation`. The Agent App UI callback requires
   `api://<client-id>/user_impersonation` in the UI API token.
3. Under **Authentication**, configure the **Web** redirect URI for the actual
   UI origin and callback. After loading the credentials and settings in
   steps 4–5 and redeploying the UI, obtain the exact URI from its
   authorization request (`redirect_uri` in browser developer tools); register
   that value, including its path and any deployment prefix; an initial Entra
   redirect-mismatch error can occur until it is registered. This callback
   belongs to the UI. Use HTTPS outside local development.
4. Under **Certificates & secrets**, create or rotate the confidential-client
   credential. Put its **value**, not its secret ID, in Key Vault and use a
   Key Vault reference for `OAUTH_AZURE_AD_CLIENT_SECRET`. Do not paste it into
   command history, tickets or source control.
5. Set the following runtime keys in the deployment's App Configuration store.
   Use label **`agent-lz`**, preserving existing secret references:

   | Key | Value |
   | --- | --- |
   | `OAUTH_AZURE_AD_CLIENT_ID` | Registration's client ID |
   | `OAUTH_AZURE_AD_TENANT_ID` | Directory tenant ID |
   | `OAUTH_AZURE_AD_ENABLE_SINGLE_TENANT` | `true` |
   | `OAUTH_AZURE_AD_CLIENT_SECRET` | Key Vault reference to the credential |
   | `OAUTH_AZURE_AD_SCOPES` | `api://<client-id>/user_impersonation,openid,profile,offline_access` |
   | `CHAINLIT_AUTH_SECRET` | Key Vault reference to a persistent session-signing secret |
   | `ALLOW_ANONYMOUS` | `false` |
   | `HOSTED_AGENT_AUTH_MODE` | `user_delegated` |

   `offline_access` is required by the callback's refresh-token exchange.
   The shipped callback rejects `User.Read` and other Graph scopes in this list.
6. Review **API permissions** with the tenant administrator. Grant consent
   for the exposed API scope and the downstream delegated permission required
   by the deployed Foundry data-plane resource. The code consumes
   `HOSTED_AGENT_RESOURCE_SCOPE`, whose permission name depends on the resource.
   Confirm the required permission in that resource's registration. Use
   [Microsoft's OBO guidance](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow)
   to configure downstream consent. Users must sign in again after consent
   changes.

Complete callback registration in the test environment before opening access.
Keep anonymous production access disabled throughout setup.

<span id="2-limit-application-admission"></span>

## 2. Limit Agent Application admission

To restrict who can open the UI, use App Configuration with label `agent-lz`.
Set `ALLOWED_USER_PRINCIPALS` to a comma-separated list
of `tenant-id:object-id` values for admitted users. For the first test, include
only user A. `ALLOWED_USER_NAMES` is an alternative comma-separated list of
sign-in names; the two lists are combined with **OR**, not AND.
Use canonical GUID formatting. Bare user object IDs are accepted for backwards
compatibility, but prefer tenant-qualified IDs for new entries.

Empty lists admit every successfully authenticated user. These lists control
who can open the UI. Foundry access and document access control lists (ACLs)
are enforced separately. The callback matches individual users and does not
fetch Graph group membership; group-based admission requires an extension.

Apply and reload settings deliberately:

1. In **App Configuration → Configuration explorer**, edit only the intended
   keys and label. Record the previous nonsecret values and secret-reference
   targets for rollback.
2. Check for competing process environment settings and component-specific or
   unlabelled keys. The UI reads several labels and bootstraps OAuth settings
   into process environment. Confirm the effective value after reloading.
3. Redeploy the UI through the existing [deployment workflow](deploy-full-stack.md)
   so its process reloads configuration; require a new browser sign-in.
   The UI loads these settings at startup. For orchestrator settings,
   deploy a new **Foundry-hosted agent** version through that workflow too.
   Verify that traffic reaches the new version with the intended configuration.

Runtime keys are not interchangeable with `azd env` deployment inputs.
Provisioning can rewrite template-managed settings: retain approved deployment
inputs and recheck effective values after provisioning. See
[Configuration](configuration.md) for ownership and environment boundaries.

## 3. Verify the retrieval identity boundary

The UI exchanges the user's API token on behalf of the user for the configured
Foundry data-plane scope. `user_delegated` is the default and refuses a missing
user token; it does not silently fall back to a service identity.
`service_identity` makes Foundry see the UI service as caller, so it cannot
preserve this per-user authorization boundary.

The hosted container does **not** receive the caller's `Authorization` header.
Toolbox connects hosted agents to tools using the platform's caller context.
In the pinned orchestrator, `AGENT_STRATEGY=mcp` uses the platform-injected
`x-agent-foundry-call-id` for Toolbox calls and rejects missing or malformed
call context. It does not trust caller-supplied identity/group fields.
The other hosted-eligible strategies use the native connector when configured
with `RETRIEVAL_BACKEND=foundry_iq`; that path has the token gap described in
[Foundry IQ](foundry-iq.md).

**Protected retrieval requires a developer integration.** The shipped generic
MCP client forwards call context but does not acquire a Toolbox bearer token.
Current Microsoft guidance uses the authenticated `FoundryToolbox` SDK
integration, which also forwards hosted call context. A developer must reconcile
the Agent Application MCP integration with that
[hosted Toolbox contract](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/use-toolbox-hosted-agent)
and validate protected retrieval. `AGENT_STRATEGY=mcp` selects the strategy;
the authenticated Toolbox integration must be implemented separately.

The extension path is to connect the
[Foundry IQ knowledge base](foundry-iq.md) through
[Toolbox](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/toolbox)
using that supported SDK integration, the appropriate end-user connection and
source permissions, then redeploy and run the tests below. With this integration,
Foundry passes the caller's identity; the knowledge source must also ingest or
honor the relevant permission metadata, and retrieval must enforce it.
Preview capabilities and source-specific limits still apply; consult
[knowledge-base retrieval permissions](https://learn.microsoft.com/azure/search/agentic-retrieval-how-to-retrieve).
Do not forward a browser bearer token or invent identity headers to bypass the
hosted gateway. A custom integration must preserve the platform call context
and enforce source authorization; see [Agent tools](agent-tools.md).

**Shared-source access:** explicit
`FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS=[]` removes ingestion permission
metadata for the supported shared native Blob case.
The protected default is `["rbacScope"]`. Use the
[shared-source configuration rules](configuration.md) only for a corpus
deliberately readable by every admitted caller. This policy provides shared
access to the corpus rather than per-user filtering.

## 4. Run an allow/deny test

Run the document tests after the authenticated Toolbox integration and source
permissions are in place. Test UI sign-in and admission separately while that
integration is being prepared.

Use separate browser profiles, new conversations and unique phrases that exist
only in the test documents. Inspect retrieved document IDs and citations as
well as the answer. For the denied user, confirm that the restricted document
is absent from retrieval results.

| Test | Expected outcome |
| --- | --- |
| Signed out, open UI | Sign-in required; no anonymous chat |
| A admitted, B absent from both admission lists | A signs in; B is denied by the UI |
| Add B to the principal list, reload UI, both sign in again | Both can open chat and invoke the hosted agent |
| Both ask for the shared test document | Both retrieve the permitted document |
| A asks for the restricted document | A retrieves its content and citation |
| B asks the same question in a new conversation | No restricted content, excerpt or citation is retrieved |
| B asks for the restricted document by its exact title or unique phrase | Still no restricted content or citation |
| B attempts to open A's conversation/history | No disclosure of A's conversation |

Record the user object IDs, effective auth mode, agent version, knowledge base,
source permission assignments and correlation IDs, without tokens or secret
values. Repeat after permission changes have propagated and the source has
refreshed permission metadata as required. For an intentionally shared corpus,
both users should retrieve the same document. Use a protected corpus for
per-user filtering tests.

## Recover safely

- **Redirect mismatch:** compare the request's `redirect_uri` with the
  registration's Web URI, including scheme, host and prefix.
- **UI consent or refresh-token failure:** check API scopes, tenant, credential
  expiry and consent; retain the UI API scope and sign out and back in after
  correction.
- **Foundry invocation denied:** distinguish failed OBO consent from missing
  data-plane access for the user. Confirm the deployed resource scope and
  endpoint. Keep delegated mode while resolving the failure;
  `service_identity` would replace the user with the UI service.
- **Missing platform call context:** invoke through the deployed Foundry
  endpoint and check the Toolbox strategy/connection. Do not fabricate the
  call ID or enable a manual group-filter fallback.
- **Tool requests user consent:** follow the service-generated consent flow
  for that user and resource, then retry. UI login consent and
  [Toolbox per-user consent](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/tool-authentication)
  apply to different resources. Verify document access separately from
  application consent.
- **B retrieves restricted content:** stop access to the affected corpus,
  repair source ACL ingestion or retrieval enforcement, then repeat the
  two-user test before restoring access.

To undo a configuration change, restore the recorded values/references and
redeploy the affected component. Keep `ALLOW_ANONYMOUS=false` and the delegated
identity boundary while investigating.
