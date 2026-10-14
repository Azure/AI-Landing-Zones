# Hosted agents

Agent Landing Zone can run the Agent App Orchestrator in two ways: as a **Foundry hosted agent** in Foundry Agent Service, or as a **Container App** (the classic topology). The topology is selected with `DEPLOYMENT_TOPOLOGY`.

Ingestion is a separate choice: `DEPLOY_INGESTION_CONTAINER_APP` defaults to
`false` for fresh environments and retains the prior selection in existing
ones. Both hosted topologies and classic orchestration support the selected
ingestion path. Disabling the ingestion app preserves chat, delegated
authentication, retrieval and document authorization with the UI v3.3.0
gate, but attachments can require the optional app. Native ingestion applies only to
supported, configured Foundry IQ sources and is not feature-equivalent to
the optional app. See
[Ingestion application selection](configuration.md#ingestion-application-selection).

Ingestion-free hosted and classic deployments require the platform v4.3.0 /
UI v3.3.0 manifest-pinned combination. Follow the
[versioned migration](operations.md#upgrade-ingestion-selection-to-v430).
On v4.2.3 / UI v3.2.2, retain `DEPLOY_INGESTION_CONTAINER_APP=true`;
that older UI does not consume the flag to gate uploads.
In the UI v3.3.0 contract, a missing flag
retains legacy behavior; `false` gates controls and server/client upload
paths, while `true` retains existing eligibility checks. This is not a native
conversation upload implementation or a change to classic/hosted selection.

## Topologies

| `DEPLOYMENT_TOPOLOGY` | Orchestrator runs as | Administrative panel | Cosmos DB |
| --- | --- | --- | --- |
| `hosted-no-panel` (default) | Foundry hosted agent | Not deployed | Not deployed |
| `hosted-panel` | Foundry hosted agent | Deployed | Deployed |
| `classic` | Container App | Not applicable | Deployed |

How the topology is resolved:

- An explicit `DEPLOYMENT_TOPOLOGY` value always wins.
- A new environment gets `hosted-no-panel`.
- An environment that already recorded a topology keeps it.
- An older environment with no topology marker is treated as `classic`, so an existing deployment is never switched silently.

To choose a topology before the first deployment:

```bash
azd env set DEPLOYMENT_TOPOLOGY hosted-panel
```

## Deploy with a hosted topology

A hosted deployment needs the orchestrator image digest before the hosted agent resource can be created. This takes one extra step compared with `classic`:

```bash
# 1. Create the platform and the Foundry project
azd provision

# 2. Build the orchestrator image and record its digest
pwsh scripts/prepareHostedDeployment.ps1     # or: ./scripts/prepareHostedDeployment.sh

# 3. Create the hosted agent resource with the recorded digest
azd provision

# 4. Deploy the application
azd deploy
```

You can use `azd up` instead of step 1. If you run `azd deploy` before step 2, the pre-deploy hook stops and tells you to run `prepareHostedDeployment`.

With `DEPLOYMENT_TOPOLOGY=classic`, a single `azd up` is enough.

During step 4 the hosted deployment:

1. Runs `azd deploy orchestrator-agent` from the `hosted-agent/` folder.
2. Sends a smoke-test request with `azd ai agent invoke`.
3. Publishes `HOSTED_AGENT_BASE_URL` to the environment and to App Configuration.
4. Activates conversation continuity, when enabled.

!!! note "Network isolation"
    With `NETWORK_ISOLATION=true`, images are built by the ACR Tasks agent pool inside the virtual network. See [Image builds in isolated deployments](network-isolation.md#image-builds-in-isolated-deployments).

## Validation rules

The deployment stops early when the hosted configuration is invalid:

| Setting | Rule |
| --- | --- |
| `HOSTED_AGENT_IMAGE_VERSION` | Must be an image digest, `sha256:` followed by 64 hexadecimal characters. Tags are rejected. |
| `HOSTED_AGENT_RESOURCE_SCOPE` | Must end with `/.default`. |
| `HOSTED_AGENT_STARTUP_COMMAND` | Fixed to the orchestrator entry point. A different value is rejected. |

`prepareHostedDeployment` sets the digest for you. `AGENTLZ_IMAGE_DIGEST` is a different variable: it is used only by [custom applications](build-your-own-app.md) whose components are pinned with `source.imageDigest`.

Other hosted settings:

| Variable | Purpose |
| --- | --- |
| `HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS` | Idle timeout for streamed responses. Default `60`. |
| `HOSTED_CONTINUITY_ENABLED` | Enables the conversation continuity endpoints. Default `false`. Requires a hosted topology. |
| `PRESERVE_CLASSIC_RUNTIME` | `true` keeps the classic orchestrator Container App while an existing environment moves to hosted. Default `false`. |

The move from `classic` to a hosted topology is complete only when `HOSTED_AGENT_BASE_URL`, the image digest, and `HOSTED_CUTOVER_COMPLETE` are all set. Until then, the classic runtime stays in place.

The full list of hosted defaults is in [Configuration](configuration.md#hosted-agent).

## Bootstrap the agent's runtime access

The hosted post-deploy hook discovers the actual agent runtime principal and
assigns its minimum declared resource-scoped roles. This is not a caller-access
grant. The deployment principal must be able to create those role assignments,
or an authorized administrator must reconcile the exact read-only plan first.
To rerun the idempotent bootstrap, use the repository root:

```bash
./scripts/bootstrapHostedAccess.sh
```

```powershell
pwsh scripts/bootstrapHostedAccess.ps1
```

The script reads `AGENTLZ_HOSTED_PROJECT` (default `hosted-agent`) and
`AGENTLZ_HOSTED_SERVICE` (default `orchestrator-agent`) and assigns the runtime
roles. The root deployment hook, not this bootstrap script, performs the
greeting smoke afterward.

To review role assignments before applying them, run from the repository root
with `AZURE_ENV_NAME` set to the selected environment:

```bash
python -m config.deployment.hosted_access --azd-env --plan
python -m config.deployment.hosted_access --azd-env --apply
```

`--azd-env` is a flag that loads the selected environment; it does not accept
an environment name. ARM grant visibility does not prove data-plane readiness.
Allow propagation, rerun bootstrap and retry the root deployment before
authorizing cutover. A connected runner without role-management permission
does not need Owner: an authorized administrator can apply only the exact
grants in the plan. Never remove unrelated assignments to recover.

## Calling the agent

### Configure the UI's delegated authentication

The default UI mode is `HOSTED_AGENT_AUTH_MODE=user_delegated`. It exchanges
the signed-in user's access token through OAuth on-behalf-of (OBO); it does
not fall back to the UI's managed identity. Before starting the UI, configure
these keys in App Configuration with label `agent-lz`:

| Key | Required value |
| --- | --- |
| `OAUTH_AZURE_AD_CLIENT_ID` | Client ID of the application's confidential Entra registration. |
| `OAUTH_AZURE_AD_TENANT_ID` | Tenant containing the application registration. |
| `OAUTH_AZURE_AD_CLIENT_SECRET` | Key Vault reference to the client credential, never plaintext. |
| `OAUTH_AZURE_AD_SCOPES` | `api://<client-id>/user_impersonation openid profile offline_access` for the UI's single-token login. |
| `CHAINLIT_URL` | Canonical HTTPS frontend URL, without a trailing slash, matching the registered callback origin. |

Expose the application's `user_impersonation` API scope, request access tokens
version 2, and register the UI's HTTPS
`/auth/oauth/azure-ad/callback` redirect URI. Configure and consent the
downstream delegated permissions needed for the deployed Foundry audience
separately. The UI's own API scope is not proof of Foundry OBO consent, and a
Microsoft Graph token is not a replacement for the UI API token.

Behind TLS-terminating ingress, set `CHAINLIT_URL` explicitly before starting
the UI. Verify that `/auth/oauth/azure-ad` redirects to Entra with an HTTPS
`redirect_uri` that exactly matches the registered callback. An HTTP callback
behind an HTTPS frontend is not a consent problem; correct the canonical URL
and restart the UI rather than registering an insecure callback.

For `hosted-panel` with the optional ingestion app selected, that app also requires the OAuth tenant and client ID;
the administrative panel has no development authentication bypass. Respect
the tenant's credential-lifetime policy, record the credential expiration,
and rotate the Key Vault credential before it expires. A persistent
`CHAINLIT_AUTH_SECRET`, preferably Key Vault-backed, prevents signed-in
sessions from being invalidated by an application restart.

After configuration, verify the intended image revisions are healthy and
that unauthenticated panel data requests are rejected. Complete an actual
user login, OBO invocation, and document-authorization checks before declaring
end-to-end acceptance. A managed-identity greeting or login redirect alone
does not prove these checks.

### Protocol and caller access

- The **Responses 2.0.0** protocol is stateless. A request that sends `conversation` or `previous_response_id` fails with HTTP 422. Send the context the agent needs in each request.
- The **`/invocations`** endpoint is kept for older clients.
- A caller that uses a delegated user identity needs the Foundry user role on the project **and** access to the agent.
- The continuity and administrative panel endpoints return HTTP 503 unless they are enabled.

!!! note "Coordinated runtime corrections"
    The corrections below are included in Agent Landing Zone **v4.2.3**, with
    **agent-app-ui v3.2.2** and **agent-app-orchestrator v5.2.1**.
    Adopt the coordinated umbrella release and hosted deployment definition;
    updating an environment variable alone does not update an existing image.

The corrected UI calls `/invocations?api-version=v1` and accepts the
`response.created` identifier in `response.conversation.id`, retaining
compatibility with `response.conversation_id`. Malformed or conflicting
identifiers fail explicitly rather than continuing under an unknown conversation.
This does not change the stateless Responses protocol.

For `CHAT_BACKEND=hosted_agent`, the corrected UI does not register the classic
orchestrator/Dapr history data layer. OAuth login, chat and feedback callbacks
remain available. Multi-turn context within the active session is not durable
history after a reload, browser restart or new chat; use the separately supported
continuity configuration where applicable. The classic backend retains its
existing history integration.

## Configuration TLS compatibility

The corrected orchestrator supports an opt-in bootstrap profile for environments
where App Configuration or Key Vault TLS handshakes stall after connectivity has
been verified. `APP_CONFIG_TLS_COMPATIBILITY` defaults to `false`, retaining the
SDK's normal transport. When explicitly `true`, the profile uses P-256 and TCP
MSS 1200 only for the configured App Configuration and application Key Vault
endpoints. It retains certificate and hostname verification, custom CA bundles,
TLS 1.2 or later (including TLS 1.3), the existing credentials and retry policy.
It neither grants access nor changes retrieval authorization.

The foundation exports the deployed vault's actual `KEY_VAULT_URI`; the bundled
hosted definition passes it to the container alongside the profile flag. For an
existing foundation, refresh outputs only after the additive output has been
provisioned. For an externally managed vault, supply its actual HTTPS URI.
Enabling the profile without `KEY_VAULT_URI`, or using a flag other than `true`
or `false`, fails startup explicitly.

With the corrected image and hosted definition selected, opt in using:

```bash
azd env set APP_CONFIG_TLS_COMPATIBILITY true
azd deploy
```

Changing this environment variable creates a new hosted-agent version; it does
not mutate a running version. Roll back the profile with
`azd env set APP_CONFIG_TLS_COMPATIBILITY false` and redeploy. Do not enable it
globally, disable certificate verification or infer a proven MTU root cause from
a successful compatibility test. See
[TLS handshake stalls](troubleshooting.md#hosted-configuration-tls-handshake-stalls).

## Telemetry content

Prompt and completion content is not recorded in telemetry by default. Turn it on only where storing that content in Application Insights is allowed by your policies.

## Switch back to classic

```bash
azd env set DEPLOYMENT_TOPOLOGY classic
azd up
```

The older flag `DEPLOY_HOSTED_AGENT_ORCHESTRATION=false` has the same effect when `DEPLOYMENT_TOPOLOGY` is not set.

## Related pages

- [Deploy full stack](deploy-full-stack.md)
- [Configuration](configuration.md)
- [Troubleshooting](troubleshooting.md)
