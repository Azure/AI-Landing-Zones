# Embed chat

Embed Agent Application in a customer portal using Agent App UI's floating
**Chainlit Copilot** widget. In UI v3.3.0 (Chainlit 2.12.0), this is a script
rendered in an open Shadow DOM, **not an iframe**. It is not the Copilot Studio web widget.
The [pinned UI embedding contract](https://github.com/Azure/agent-app-ui/blob/v3.3.0/docs/copilot-embedding.md)
describes the component's session and transport behavior.

This recipe keeps the orchestrator hosted in Foundry and uses Entra
authentication. The UI still runs in Azure Container Apps; embedding changes
neither the hosted agent nor its Foundry IQ knowledge base.

## Before you start

- Have a working [hosted deployment](hosted-agents.md) and confirm a signed-in
  user can chat in the standalone UI. Complete [Agent Application authentication](application-auth.md),
  including the UI API's delegated scope and server-side OBO configuration.
- Have an existing portal MSAL sign-in/token-acquisition integration. In
  **Entra ID → App registrations**, select the **portal's own client app
  registration**, not the UI API registration. Open **API permissions →
  Add a permission → My APIs → your UI API → Delegated permissions**.
  Select `user_impersonation` (or your exposed scope name), then **Add
  permissions**. Obtain consent according to tenant policy; have an
  authorized administrator grant tenant-wide consent where required. See
  [Configure a client application's API permissions](https://learn.microsoft.com/entra/identity-platform/quickstart-configure-app-access-web-apis).
- Be able to change the portal's code and CSP, the UI's configuration and
  Container App deployment. App Configuration data changes require an
  appropriate data-plane role, such as App Configuration Data Owner.
- Choose two distinct HTTPS origins, for example
  `https://portal.contoso.com` and `https://chat.contoso.com`. An origin is
  scheme, host and optional port, not a page URL.
- Ensure users' browsers can reach the UI through the existing authorized
  network/gateway path. Do not make private ingress public for the widget.
  See [Private access](private-access.md).

## 1. Configure the UI

Keep embedding disabled in production until a staged portal is ready. Apply
the following settings to the **UI**, not the hosted orchestrator:

| Setting | Value |
| --- | --- |
| `CHAINLIT_COPILOT_ENABLED` | `true` |
| `CHAINLIT_COPILOT_AUTH_MODE` | `entra` |
| `CHAINLIT_URL` | `https://chat.contoso.com` |
| `CHAINLIT_ALLOWED_ORIGINS` | `https://portal.contoso.com` |
| `CHAINLIT_COPILOT_ENTRA_TENANT_ID` | Your Entra tenant GUID |
| `CHAINLIT_COPILOT_ENTRA_AUDIENCE` | The UI API's expected access-token `aud` |
| `CHAINLIT_COPILOT_ENTRA_REQUIRED_SCOPE` | `user_impersonation`, or your configured delegated scope name |

Use exact origins: no wildcard, `null`, credentials, application path, query
or fragment. Do not include the UI origin in the portal allow-list.
`CHAINLIT_ROOT_PATH` must be empty; same-origin path multiplexing is unsupported.

The audience is **not** the chat URL or the portal client ID. For a v2 access
token, Microsoft documents `aud` as the API's application (client) ID. Request
the API's fully qualified scope in the portal, but configure only the scope
name above. Do not copy an `api://...` scope URI into the audience setting
without checking the actual API token contract. See
[Access token claims](https://learn.microsoft.com/entra/identity-platform/access-token-claims-reference).
The validator accepts the configured tenant and v2 issuer only. An existing
customer-portal login from another identity provider or tenant is not
automatically a supported API identity.

Use runtime App Configuration keys with label `agent-lz`, following
[Configuration](configuration.md), or explicit UI environment variables.
In the Azure portal, open the deployment's App Configuration store →
**Operations → Configuration explorer → Create → Key-value**. Add each
nonsecret key/value above with **Label** set to `agent-lz`, or edit its existing
entry. See [Create a key-value](https://learn.microsoft.com/azure/azure-app-configuration/quickstart-azure-app-configuration-create).
Nonempty environment variables override these embedding settings. These are
not new `azd` deployment inputs. Keep the existing `CHAINLIT_AUTH_SECRET`
protected through the deployment's secret mechanism; never hard-code a token
or secret in portal code, a config command or source control.

The UI loads these settings at startup, not on every request. After saving,
restart/redeploy the **UI Container App** through your normal deployment
process; do not restart the hosted agent for an embedding-only change.
Keep one Uvicorn process, one active Container Apps revision (Single revision
mode), and exactly one replica. Sessions and rate limits are process-local;
affinity alone does not make multiple replicas safe.

Prefer same-site HTTPS subdomains. For a cross-site portal,
`CHAINLIT_COOKIE_SAMESITE=none` is required; cookies remain `Secure` and
`HttpOnly`. Browser third-party-cookie restrictions can still block the
session. The default is `lax`.
If browser policy prevents cookies, offer a normal link to the standalone UI
instead of moving tokens into URLs or weakening authentication.

## 2. Allow the widget through the portal and gateway

Merge the UI origin into the portal's existing CSP, including its secure
WebSocket endpoint:

```text
script-src 'self' https://chat.contoso.com;
connect-src 'self' https://chat.contoso.com wss://chat.contoso.com;
```

These are additions to your policy, not a replacement for its other directives.
Keep your nonce/hash policy for portal JavaScript. Do **not** relax
`frame-ancestors` or `X-Frame-Options`; the widget does not frame the UI.
The bundle executes in the portal page; an open Shadow DOM is not a security
sandbox. Serve it only from the UI origin you control and trust.
The pinned widget bundle also injects inline styles into its Shadow DOM. If your
portal blocks these, review CSP compatibility before adopting it; the example
above is not a complete policy for every portal. Do not broadly enable
`unsafe-inline` to bypass a failed security review.

The gateway must preserve the external UI origin, cookies, browser `Origin`,
and WebSocket upgrades. Preserve `/copilot/index.js`,
`/copilot/auth/bootstrap`, `/copilot/auth/logout`, `/project/settings`,
`/ws/socket.io` (polling and upgrades), and `/api/download/{grant_token}`.
See [Container Apps ingress](https://learn.microsoft.com/azure/container-apps/ingress-overview)
for the service's WebSocket support.

An exact-origin allow-list is a browser control, not authentication. A direct
HTTP client can forge `Origin`; keep Entra validation and network/gateway
authorization in place.

## 3. Bootstrap, then mount

Use the portal's existing MSAL integration to acquire a **delegated v2 access
token for the UI API**, not an ID token or Microsoft Graph token. See
[Acquire a token in a SPA](https://learn.microsoft.com/entra/identity-platform/scenario-spa-acquire-token).
MSAL's `clientId` is the portal app's client ID; its requested scope is the
UI API's exposed Application ID URI plus `/user_impersonation` (or your
configured scope name), not a Microsoft Graph scope.
Keep it in memory and send it only to the UI bootstrap endpoint. Do not pass
it as the widget's `accessToken` or put it in a URL.

Add this code to the portal's CSP-approved JavaScript bundle. Replace the
origin and call `startAssistant(apiAccessToken)` after token acquisition.
Run it once per mounted widget.

```javascript
const chainlitServer = "https://chat.contoso.com";

async function startAssistant(apiAccessToken) {
  const bootstrap = await fetch(`${chainlitServer}/copilot/auth/bootstrap`, {
    method: "POST",
    credentials: "include",
    headers: { Authorization: `Bearer ${apiAccessToken}` },
  });
  if (!bootstrap.ok) {
    throw new Error(`Assistant bootstrap failed (${bootstrap.status})`);
  }

  // Confirm the browser accepted the opaque session cookie.
  const probe = await fetch(`${chainlitServer}/project/settings`, {
    credentials: "include",
    headers: { Accept: "application/json" },
  });
  if (!probe.ok) throw new Error("Assistant session was not established");

  if (typeof window.mountChainlitWidget !== "function") {
    await new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = `${chainlitServer}/copilot/index.js`;
      script.onload = resolve;
      script.onerror = reject;
      document.head.appendChild(script);
    });
  }
  window.mountChainlitWidget({ chainlitServer, theme: "light" });
}
```

Catch errors in the portal and show a non-sensitive status message. Never
retry with anonymous authentication after an Entra failure.

Bootstrap validates the token and user authorization policy, then sets an
opaque server-side session cookie. The embedded session retains the delegated
token server-side for the hosted client's OBO exchange. Keep
`HOSTED_AGENT_AUTH_MODE=user_delegated`; do not switch to service identity to
work around a token failure. Identity propagation does not itself enforce
document permissions: preserve the knowledge base's source ACLs and retrieval
authorization. See [Foundry IQ](foundry-iq.md).
An embedded session expires at the earlier of token expiry and its TTL
(`CHAINLIT_COPILOT_SESSION_TTL_SECONDS`, default 3600 seconds); it does not
silently refresh through standalone OAuth.

## 4. Verify before publishing

From a staged, allow-listed portal in a browser:

1. Sign in and open the widget. Bootstrap and `/project/settings` should
   return `200`; the browser should store a Secure, HttpOnly session cookie.
   Confirm the socket connects and a question receives a hosted-agent answer.
2. Test an invalid/expired token: bootstrap should return `401`. Test a
   non-allow-listed portal origin: access should be denied (`403`).
3. Test two users with different source permissions. An answer or citation
   must not expose a source the current user cannot access.
4. Exercise logout, account switching and expiry before enabling the widget
   for production users.

On logout/account switch, await this cleanup before another bootstrap:

```javascript
async function stopAssistant() {
  window.unmountChainlitWidget?.();
  document.getElementById("chainlit-copilot")?.remove();
  localStorage.removeItem("chainlit-copilot-thread-id");
  const response = await fetch(`${chainlitServer}/copilot/auth/logout`, {
    method: "POST",
    credentials: "include",
  });
  if (!response.ok) throw new Error("Assistant logout failed");
}
```

Clear portal authentication state as appropriate. If cleanup fails, do not
mount another account's widget until the assistant session is invalidated.

## Recover or remove

| Symptom | Action |
| --- | --- |
| UI fails startup | Check explicit auth mode, distinct exact origins, empty root path and Entra settings. |
| Bootstrap `401` / `403` | Check API audience, delegated scope, tenant, expiry, user authorization and exact browser origin. Do not disable auth. |
| Bootstrap succeeds; probe returns `401` | Check cookie acceptance, HTTPS, SameSite and browser third-party-cookie policy. |
| Bundle or socket is blocked | Check CSP, gateway paths, cookie/Origin forwarding and WebSocket upgrades. |
| Session expires or disappears | HTTP `401`, WebSocket `4401` or Socket.IO auth failure requires unmounting and clearing local thread state. Acquire a fresh token and make at most one controlled bootstrap attempt. Restart, revision switch and eviction also invalidate sessions. |
| Bootstrap `429` | Honor `Retry-After`; use gateway throttling for authoritative enforcement. |

To remove embedding, disable the portal widget first, set
`CHAINLIT_COPILOT_ENABLED=false` in the effective UI configuration, then
restart/redeploy the UI. Active embedded sessions and download grants are
not restored after restart.

## Unsupported edges

- An iframe, same-origin subpath deployment and multi-process/multi-replica
  embedded sessions are not supported by this widget integration.
  For a custom presentation, build a separately authenticated client through
  [Custom applications](build-your-own-app.md); that is custom code, not an
  iframe enable switch.
- The UI also implements `anonymous` embedding, but it supplies no user token
  and cannot call Agent Application's default user-delegated hosted path.
  It disables durable threads, uploads and private citation downloads.
  Portal login alone does not protect an anonymously reachable UI endpoint.
- Upload controls require the separately deployed ingestion capability;
  embedding does not add native hosted-agent uploads.
