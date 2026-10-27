<span id="application-access"></span>

# Agent Application access

Agent Application has three independent access boundaries: UI admission,
delegated Foundry invocation and document authorization. Signing in does not
grant access to every document. Follow the setup sequence below for the default
Foundry-hosted agent and Container Apps frontend. Azure CLI and azd sign-in
authenticate the deployment operator, not application users.
Deployment and redeployment belong to the
[Deploy full stack runbook](deploy-full-stack.md).

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

For the standard Foundry-resource authorization scheme (`AzureRbac`, also
known as `Entra`), the downstream scope is `https://ai.azure.com/.default`.
Confirm the deployed endpoint's audience with its owner; do not substitute
the UI API scope or a management-plane audience. Set
`HOSTED_AGENT_RESOURCE_SCOPE` in the selected azd environment before provision,
as shown in the [full-stack runbook](deploy-full-stack.md#orchestrator-topology).
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
`CHAINLIT_AUTH_SECRET` in Key Vault and publish it as a reference too; do not
regenerate an existing session-signing secret during a routine update.

Publish the following values in the same store:

| UI runtime key | Contract |
| --- | --- |
| `OAUTH_AZURE_AD_CLIENT_ID` | Application (client) ID from step 1. |
| `OAUTH_AZURE_AD_TENANT_ID` | Directory (tenant) ID from step 1. |
| `OAUTH_AZURE_AD_ENABLE_SINGLE_TENANT` | `true`. |
| `OAUTH_AZURE_AD_SCOPES` | `api://<client-id>/user_impersonation,openid,profile,offline_access`, replacing `<client-id>`. Do not add Graph scopes such as `User.Read` or the Foundry scope here. |
| `CHAINLIT_URL` | Canonical UI HTTPS URL from step 3. |
| `ALLOW_ANONYMOUS` | `false`. |
| `HOSTED_AGENT_AUTH_MODE` | `user_delegated`. |

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
[full-stack runbook](deploy-full-stack.md#step-4-deploy). For an existing UI,
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

The supplied hosted entry point sets `user_context={}` and does not supply the
user's bearer token to `maf_lite` retrieval. It performs no automatic retrieval
OBO exchange. With `ALLOW_ANONYMOUS=false`, required-user retrieval fails
preflight when that token is unavailable; it does not silently retrieve as a
service identity. Removing source permission metadata alone does not repair
this missing-token contract.

**Protected hosted retrieval requires a developer integration.** Foundry's
[authenticated hosted Toolbox contract](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/use-toolbox-hosted-agent)
uses an authenticated `FoundryToolbox` client and platform-provided call context.
The default `maf_lite` code does not consume portal Toolbox configuration.

A compatible integration must connect the knowledge base through that contract,
retain the platform caller context, and enforce the knowledge source's
permissions. [Agent tools](agent-tools.md) explains the extension boundary.
Browser bearer forwarding or fabricated identity/group headers are not a
substitute.

The protected native Blob ingestion default is
`FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS=["rbacScope"]`. Explicit `[]` removes
permission metadata for the supported intentionally shared Blob corpus.
That provides shared-source access, not per-user filtering.
[Foundry IQ](foundry-iq.md) and
[knowledge-base retrieval permissions](https://learn.microsoft.com/azure/search/agentic-retrieval-how-to-retrieve)
describe source-specific requirements.

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

A denied user retrieving protected content is an authorization failure that
blocks exposure of that corpus. Recovery does not replace the delegated caller
with a service identity or disable authentication.
