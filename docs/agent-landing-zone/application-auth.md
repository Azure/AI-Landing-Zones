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

| UI runtime key | Contract |
| --- | --- |
| `OAUTH_AZURE_AD_CLIENT_ID`, `OAUTH_AZURE_AD_TENANT_ID` | Entra application and directory IDs, not URLs. |
| `OAUTH_AZURE_AD_ENABLE_SINGLE_TENANT` | `true` for this contract. |
| `OAUTH_AZURE_AD_CLIENT_SECRET` | Key Vault reference to the credential value, not the secret ID. |
| `OAUTH_AZURE_AD_SCOPES` | UI API scope plus `openid`, `profile`, `offline_access`. Graph scopes such as `User.Read` are rejected by the callback. |
| `CHAINLIT_AUTH_SECRET` | Persistent, protected session-signing secret. |
| `ALLOW_ANONYMOUS` | `false` for authenticated access. |
| `HOSTED_AGENT_AUTH_MODE` | `user_delegated`, the default hosted mode. |

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
