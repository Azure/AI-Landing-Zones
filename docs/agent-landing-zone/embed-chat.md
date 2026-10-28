# Embed chat

Agent App UI provides a floating **Chainlit Copilot** widget for an existing
portal. Its script renders in an open Shadow DOM, a separate part of the
portal page's document structure, not an iframe containing another web page.

This is Agent App UI embedding, not Copilot Studio. The UI remains in Container
Apps, with the orchestrator hosted in Foundry and grounding through Foundry IQ.
The [pinned UI embedding reference](https://github.com/Azure/agent-app-ui/blob/v3.3.0/docs/copilot-embedding.md)
contains the component integration contract.

This page describes requirements, not a turnkey portal integration.
Portal token acquisition, Content Security Policy (CSP) and widget lifecycle
require application work.
Infrastructure deployment and component reloads follow the
[Deploy full stack runbook](deploy-full-stack.md).

<span id="before-you-start"></span>
<span id="1-configure-the-ui"></span>

## UI and portal contract

The portal has its own Entra client registration and acquires a delegated v2
access token for the UI API. The API exposes `user_impersonation`; an ID token
or Graph token is not valid. The portal's
[delegated API permissions](https://learn.microsoft.com/entra/identity-platform/quickstart-configure-app-access-web-apis)
and consent are separate from the UI's server-side Foundry OBO exchange.
[Agent Application access](application-auth.md) explains that downstream path.

| UI runtime setting | Entra embedding contract |
| --- | --- |
| `CHAINLIT_COPILOT_ENABLED` | `true` enables embedding; default is disabled. |
| `CHAINLIT_COPILOT_AUTH_MODE` | `entra`. |
| `CHAINLIT_URL` | Canonical UI HTTPS origin, for example `https://chat.contoso.com`. |
| `CHAINLIT_ALLOWED_ORIGINS` | Exact distinct portal HTTPS origins, for example `https://portal.contoso.com`. |
| `CHAINLIT_COPILOT_ENTRA_TENANT_ID` | Issuing Entra tenant's unique ID. |
| `CHAINLIT_COPILOT_ENTRA_AUDIENCE` | Expected UI API access-token `aud`. |
| `CHAINLIT_COPILOT_ENTRA_REQUIRED_SCOPE` | Scope name, normally `user_impersonation`. |

Origins contain only scheme, host and optional port, without wildcard, `null`,
credentials, path, query or fragment. `CHAINLIT_ROOT_PATH` must be empty.
The validator accepts the configured tenant and v2 issuer only.
For v2 tokens, `aud` is normally the API's application client ID, while the
requested scope uses the API's fully qualified URI.
[Access token claims](https://learn.microsoft.com/entra/identity-platform/access-token-claims-reference)
describes the distinction.

These are UI runtime settings, normally under App Configuration label
`agent-lz`, not azd deployment inputs. Nonempty process environment values
override embedding settings. The UI loads them at startup.
[Deployment settings](configuration.md) identifies their configuration boundary.
The existing session-signing secret stays protected.

The widget requires one Uvicorn process, one active Container Apps revision
and exactly one replica because sessions and rate limits are process-local.
Same-site HTTPS subdomains work with the default `CHAINLIT_COOKIE_SAMESITE=lax`.
Cross-site portals require `none`, with Secure and HttpOnly cookies, but browser
third-party-cookie policy can still prevent a session. A standalone UI link
remains available if browser cookie policy blocks embedding.

<span id="2-allow-the-widget-through-the-portal-and-gateway"></span>

## Browser and gateway boundaries

The portal CSP must permit scripts from the controlled UI origin and HTTPS
and secure WebSocket (WSS) connections to it. The bundle runs with the portal
page's JavaScript privileges; Shadow DOM does not isolate security.

It also injects inline
styles, which can conflict with the portal's CSP. A compatible policy retains
the portal's nonce/hash protections rather than broadly enabling `unsafe-inline`.
Embedding does not require weakening `frame-ancestors` or `X-Frame-Options`.

The gateway contract preserves the external UI origin, cookies, browser
`Origin`, and WebSocket upgrades. Required paths include `/copilot/index.js`,
`/copilot/auth/bootstrap`, `/copilot/auth/logout`, `/project/settings`,
`/ws/socket.io` polling/upgrades and `/api/download/{grant_token}`.
[Container Apps ingress](https://learn.microsoft.com/azure/container-apps/ingress-overview)
supports WebSockets. Browsers still need authorized network access to private
UI ingress; embedding does not make it public.

The origin allow-list constrains browsers, not arbitrary HTTP clients that
can forge `Origin`. Entra validation and network/gateway authorization remain
necessary.

<span id="3-bootstrap-then-mount"></span>

## Session lifecycle

The portal's [Microsoft Authentication Library (MSAL) integration](https://learn.microsoft.com/entra/identity-platform/scenario-spa-acquire-token)
acquires the UI API token in memory. A credentialed
`POST /copilot/auth/bootstrap` carries it in the bearer header before the
widget mounts. Bootstrap validates token and user admission, then creates an
opaque server-side session cookie. The token is not a widget `accessToken`
and does not belong in a URL, local storage or portal source.

The embedded session retains the delegated token server-side for the hosted
client's OBO exchange. `HOSTED_AGENT_AUTH_MODE=user_delegated` preserves that
caller boundary. Protected document access still requires the
[hosted retrieval integration](application-auth.md#3-verify-the-retrieval-identity-boundary);
the bundled UI uses the same Search OBO path as standalone chat. Bootstrap
alone does not establish downstream consent or source permissions.

Native citation downloads use authenticated principal/session-bound selectors
and recheck source access on each click. Shared Blob/ADLS downloads also need
Storage delegated consent and user source permissions.
See [protected citation downloads](application-auth.md#protected-citation-downloads).
Anonymous sessions cannot redeem these selectors.

Session lifetime ends at the earlier of token expiry and
`CHAINLIT_COPILOT_SESSION_TTL_SECONDS` (default 3600 seconds). It has no silent
standalone OAuth refresh. Logout/account switching requires widget unmount,
local thread-state cleanup and credentialed `POST /copilot/auth/logout` before
another account's bootstrap. Restart, revision switch and eviction invalidate
the process-local session and download-grant state.

<span id="4-verify-before-publishing"></span>

## Integration evidence

Successful bootstrap and cookie acceptance allow `/project/settings` and the
chat socket to authenticate. Invalid/expired tokens return `401`; disallowed
origins return `403`. Expiry can also surface as WebSocket `4401` or Socket.IO
authentication failure. Bootstrap throttling returns `429` with `Retry-After`;
authoritative rate limits need gateway enforcement.

An integration is incomplete without account-switch, logout, cookie-policy
and two-user document allow/deny tests. Do not work around token failures with
anonymous fallback or service-identity retrieval.

<span id="recover-or-remove"></span>

## Disabling embedding

The portal widget and `CHAINLIT_COPILOT_ENABLED` control different sides of the
integration. Disabling the UI setting takes effect after a UI process reload.
It does not remove standalone chat or alter the hosted agent.

## Unsupported edges

- Iframes, same-origin subpaths and multi-process/multi-replica embedded
  sessions are unsupported by this widget integration.
- Anonymous embedding supplies no user token and cannot call the default
  user-delegated hosted path. It disables durable threads, uploads and private
  citation downloads; its endpoint is independent of portal login.
- Upload controls require the separately deployed ingestion capability.
  Embedding does not add native hosted-agent uploads.

A separately authenticated client is an application extension under
[Bring your own app](build-your-own-app.md).
