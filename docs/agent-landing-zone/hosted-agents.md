# Hosted agents

Agent Landing Zone can run the Agent App Orchestrator in two ways: as a **Foundry hosted agent** in Foundry Agent Service, or as a **Container App** (the classic topology). The topology is selected with `DEPLOYMENT_TOPOLOGY`.

Ingestion is a separate choice: `DEPLOY_INGESTION_CONTAINER_APP` defaults to
`false` for fresh environments and retains the prior selection in existing
ones. Both hosted topologies and classic orchestration support the selected
ingestion path. Disabling the ingestion app preserves chat, delegated
authentication, retrieval and document authorization with the UI v3.3.0
gate, but disables conversation attachments. Native ingestion applies only to
supported, configured Foundry IQ sources and is not feature-equivalent to
the optional app. See
[Ingestion application selection](configuration.md#ingestion-application-selection).

Ingestion-free hosted and classic deployments require the platform v4.3.0 /
UI v3.3.0 manifest-pinned combination. Follow the
[versioned migration](operations.md#upgrade-ingestion-selection-to-v430).
On v4.2.3 / UI v3.2.2, retain `DEPLOY_INGESTION_CONTAINER_APP=true`.
That older UI does not consume the flag to gate uploads.
In the UI v3.3.0 contract, a missing flag
retains legacy behavior. `false` gates controls and server/client upload
paths, while `true` retains existing eligibility checks. This is not a native
conversation upload implementation or a change to classic/hosted selection.

Enabling the app is necessary for conversation uploads, not sufficient for
every caller to upload. The UI retains authenticated-mode eligibility,
rejects anonymous Copilot uploads, and enforces its supported file types
and size/count limits. Native source ingestion does not replace this path.

## Topologies

| `DEPLOYMENT_TOPOLOGY` | Orchestrator runs as | Administrative panel | Application Cosmos DB |
| --- | --- | --- | --- |
| `hosted-no-panel` (default) | Foundry hosted agent | Not deployed | Not deployed |
| `hosted-panel` | Foundry hosted agent | Deployed | Deployed |
| `classic` | Container App | Not applicable | Deployed |

The table describes the bundled application in its resolved topology, not
every resource that might remain after a migration. In `hosted-panel`,
Cosmos stores owner-index and feedback metadata, not hosted chat transcripts.
History and continuity require their own configuration. Selecting the
ingestion app does not enable either feature.
Foundry Agent Service can provision its own backing Cosmos DB separately.
Omitting application Cosmos DB does not mean that no Cosmos DB resource
exists anywhere in the foundation.

How the topology is resolved:

- An explicit `DEPLOYMENT_TOPOLOGY` value always wins.
- A new environment gets `hosted-no-panel`.
- An environment that already recorded a topology keeps it.
- An older environment with no topology marker is treated as `classic`, so an existing deployment is never switched silently.

To choose a topology before the first provision:

```bash
azd env set DEPLOYMENT_TOPOLOGY hosted-panel
```

## Deploy with a hosted topology

A first bundled hosted deployment has four stages. Provisioning prepares
the foundation and immutable deployment handoff. It does not create or run
the data-plane agent version. Image preparation builds the manifest-pinned
orchestrator and records its digest. A second provision materializes that
digest in the handoff, and deployment creates the hosted agent version.

Run these commands from the platform repository root, with the intended
environment selected and the [deployment prerequisites](deploy-full-stack.md#prerequisites)
in place:

```bash
# 1. Create the platform and Foundry prerequisites, then run post-provision
azd provision

# 2. Build the orchestrator image and record its digest
pwsh scripts/prepareHostedDeployment.ps1     # or: ./scripts/prepareHostedDeployment.sh

# 3. Provision the immutable deploy handoff with the recorded digest
azd provision

# 4. Create the hosted agent version and deploy the selected applications
azd deploy
```

Starting a fresh hosted environment with `azd up` runs provisioning, but
its deploy stage stops because the image handoff is incomplete. Continue
with steps 2 through 4. Preparation alone is not enough: its output tells
you to provision again before deploying.

With `DEPLOYMENT_TOPOLOGY=classic`, `azd up` can run the complete workflow
when authentication, quota, configuration and network prerequisites are
ready. It is not an unconditional application-readiness guarantee.

During step 4 the hosted deployment:

1. Runs `azd deploy orchestrator-agent` from `hosted-agent/`. The service-level post-deploy hook discovers the actual runtime principal and bootstraps its access.
2. Sends a greeting smoke-test request with `azd ai agent invoke` and checks that the protocol response completes successfully.
3. Publishes `HOSTED_AGENT_BASE_URL` to the environment and to App Configuration.
4. Validates and activates conversation continuity when requested, then deploys the remaining selected components.
5. Publishes the hosted routing and cutover markers only after the selected deployments succeed.

A failed greeting or component deployment blocks cutover. A successful
greeting exercises configuration and model access, not real-user login,
OBO, citations or document allow/deny behavior.

!!! note "Network isolation"
    With `NETWORK_ISOLATION=true`, images are built by the ACR Tasks agent pool inside the virtual network. See [Image builds in isolated deployments](network-isolation.md#image-builds-in-isolated-deployments).

### Redeploy the same image or prepare a new one

For an already-provisioned handoff with the same image digest and compatible
source pin, run `azd deploy` again. It reuses the immutable image rather than
rebuilding the hosted orchestrator. Runtime environment changes declared
in `hosted-agent/azure.yaml`, such as the TLS profile or telemetry-content
flag, can create a new agent version with that same digest.

When the manifest's orchestrator source commit changes, run
`prepareHostedDeployment`, `azd provision`, and `azd deploy` again.
Preparation rebuilds a generated image whose recorded source commit no
longer matches the manifest. It reuses a generated digest when the source
commit and startup-command hash match. Provisioning rejects a generated
digest recorded against a different manifest source commit.
Do not skip that provision after a source change. Deploy-only validation
checks the digest and Foundry context, not the generated image's source
commit against the newly selected manifest.

An explicitly supplied digest without generated-source provenance is
treated as operator-managed and is not rebuilt automatically. The
preparation script's `--image-version sha256:<64-hex-characters>` option
also skips building and clears generated-image provenance. Verify the
image's compatibility and availability yourself, then provision the
handoff before deploying it. Do not assume that changing the platform tag
replaces an operator-managed image.

After an infrastructure-only deployment, the first provision and
post-provision configuration are not sufficient to start hosted
applications. Complete preparation, the second provision, and deployment.

## Validation rules

The deployment stops early when the hosted configuration is invalid:

| Setting | Rule |
| --- | --- |
| `HOSTED_AGENT_IMAGE_VERSION` | Must be an image digest, `sha256:` followed by 64 hexadecimal characters. Tags are rejected. |
| `HOSTED_AGENT_RESOURCE_SCOPE` | Must end with `/.default`. |
| `HOSTED_AGENT_STARTUP_COMMAND` | Fixed to the orchestrator entry point. A different value is rejected. |

`prepareHostedDeployment` sets the hosted digest for you.
For custom definitions, the root hook sets `AGENTLZ_IMAGE_DIGEST` from
`source.imageDigest`. Neither is interchangeable with
`HOSTED_AGENT_IMAGE_VERSION`. See
[Custom applications](build-your-own-app.md).

Other hosted settings:

| Variable | Purpose |
| --- | --- |
| `HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS` | Idle timeout for streamed responses. Default `60`. |
| `HOSTED_CONTINUITY_ENABLED` | Requests UI-managed conversation continuity. Default `false`. Requires a hosted topology and successful activation. |
| `PRESERVE_CLASSIC_RUNTIME` | `true` keeps the classic orchestrator Container App while an existing environment moves to hosted. Default `false`. |

During a migration that preserves classic routing, the runtime selector
stays classic until `HOSTED_AGENT_BASE_URL`, a valid image digest, and
`HOSTED_CUTOVER_COMPLETE=true` are all present. These markers record hook
completion, not full user acceptance. Removing an old runtime is a separate
operator decision.

The full list of hosted defaults is in [Configuration](configuration.md#hosted-agent).

The bundled child `hosted-agent/azure.yaml` fixes the agent name, CPU,
memory, protocols and startup command as literal agent-definition fields.
The corresponding `HOSTED_AGENT_*` inputs used by provisioning do not
automatically customize those fields in the deployed version. Keep any
deliberate child-definition changes compatible with the provisioning
contract. A custom startup command is rejected.

## Bootstrap the agent's runtime access

The bundled hosted post-deploy hook discovers the actual agent runtime principal and
assigns App Configuration Data Reader on the store and Cognitive Services
OpenAI User on the Foundry account. If `AUDIT_HMAC_KEY` is configured as a
Key Vault reference, it also plans Key Vault Secrets User on that individual
secret. This is a closed bootstrap role set, not all component capability
profiles or a caller-access grant. The deployment principal must be able to create those role assignments,
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

`--azd-env` is a flag that loads the selected environment. It does not accept
an environment name. ARM grant visibility does not prove data-plane readiness.
Allow propagation, rerun bootstrap and retry the root deployment before
authorizing cutover. A connected runner without role-management permission
does not need Owner: an authorized administrator can apply only the exact
grants in the plan. Never remove unrelated assignments to recover.

The foundation's Foundry project identity pulls the image. The deployed
agent's runtime principal, the deployment principal and a delegated caller
are separate identities with separate permissions. For custom hosted
services, deployment reconciles the component's declared capability profiles
against the discovered runtime principal. See
[Custom hosted image-pull recovery](troubleshooting.md#custom-hosted-image-pull-fails-with-a-classic-bundled-orchestrator).

## Calling the agent

### Configure the UI's delegated authentication

The default UI mode is `HOSTED_AGENT_AUTH_MODE=user_delegated`. It exchanges
the signed-in user's access token through OAuth on-behalf-of (OBO). It does
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
behind an HTTPS frontend is not a consent problem. Correct the canonical URL
and restart the UI rather than registering an insecure callback.

For `hosted-panel` with the optional ingestion app selected, that app also requires the OAuth tenant and client ID.
The administrative panel has no development authentication bypass. Respect
the tenant's credential-lifetime policy, record the credential expiration,
and rotate the Key Vault credential before it expires. A persistent
`CHAINLIT_AUTH_SECRET`, preferably Key Vault-backed, avoids session resets
caused by replacing a temporary generated signing secret on restart.

After configuration, verify the intended image revisions are healthy and
that unauthenticated panel data requests are rejected. Complete an actual
user login, OBO invocation, and document-authorization checks before declaring
end-to-end acceptance. A managed-identity greeting or login redirect alone
does not prove these checks.

### Protocol and caller access

- The **Responses 2.0.0** adapter is stateless. A non-null `previous_response_id` fails with HTTP 422. Top-level `conversation` and other unhandled routing or sampling fields are ignored, not used to load history. Send the complete, bounded, ordered input on each request, ending with the current user message.
- The **`/invocations`** endpoint is supported and is the path used by the pinned UI, with `api-version=v1`.
- An `/invocations` `conversation_id` is a label for conversation-scoped retrieval, not permission to load managed history. Its presence does not make the runtime stateful.
- A caller that uses a delegated user identity needs the Foundry user role on the project **and** access to the agent.
- Disabled panel history surfaces return HTTP 503. Panel history requires `DEPLOY_ADMINISTRATIVE_PANEL`, `PANEL_HISTORY_ENABLED` and hosted continuity, with their authentication and owner checks. Continuity is a separate UI-coordinated feature, not a generic runtime history endpoint.

!!! note "Coordinated runtime corrections"
    The corrections below are included in Agent Landing Zone **v4.2.3**, with
    **agent-app-ui v3.2.2** and **agent-app-orchestrator v5.2.1**.
    These corrections remain in the v4.3.0 pinned combination. Adopt the
    coordinated umbrella release and hosted deployment definition.
    Updating an environment variable alone does not update an existing image.

The corrected UI calls `/invocations?api-version=v1` and accepts the
`response.created` identifier in `response.conversation.id`, retaining
compatibility with `response.conversation_id`. Malformed or conflicting
identifiers fail explicitly rather than continuing under an unknown conversation.
This does not change the stateless Responses protocol.

For `CHAT_BACKEND=hosted_agent`, the pinned UI does not register the classic
orchestrator/Dapr history data layer. OAuth login, chat and feedback callbacks
remain available. Without continuity, multi-turn context within the active session is not durable
history after a reload, browser restart or new chat. Use the separately supported
continuity configuration where applicable. The classic backend retains its
existing history integration.

Continuity is disabled by default. When enabled and activated, the UI
coordinates managed Conversations reads and writes with owner binding and
agent-scoped permissions, then sends an authorized transcript to the
stateless runtime. It does not give the hosted container general history
access or restore the classic Chainlit history data layer. The panel's
Cosmos owner index and feedback remain metadata, not a second transcript
store. A topology choice, greeting or enabled flag alone does not prove
durable history or cross-user isolation.

## Configuration TLS compatibility

The corrected orchestrator supports an opt-in bootstrap profile for environments
where App Configuration or Key Vault TLS handshakes stall after connectivity has
been verified. `APP_CONFIG_TLS_COMPATIBILITY` defaults to `false`, retaining the
SDK's normal transport. When explicitly `true`, the profile uses P-256 and TCP
MSS 1200 only for the configured App Configuration and application Key Vault
endpoints. It retains certificate and hostname verification, custom CA bundles,
TLS 1.2 or later (including TLS 1.3), the existing credentials and retry policy.
It neither grants access nor changes retrieval authorization. This profile
belongs to the orchestrator configuration loader, not the UI, ingestion app
or every outbound HTTP client.

The foundation exports the deployed vault's actual `KEY_VAULT_URI`. The bundled
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

Changing this environment variable creates a new hosted-agent version. It does
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

The older flag `DEPLOY_HOSTED_AGENT_ORCHESTRATION=false` selects classic
when `DEPLOYMENT_TOPOLOGY` is not set and the legacy flag pair is consistent.
Verify the resolved topology, healthy classic revision and source bindings.
Switching topology does not select ingestion or delete the hosted agent.

## Related pages

- [Deploy full stack](deploy-full-stack.md)
- [Configuration](configuration.md)
- [Troubleshooting](troubleshooting.md)
