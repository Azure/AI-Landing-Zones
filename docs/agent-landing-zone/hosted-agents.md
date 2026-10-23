# Hosted agents

Agent Application's orchestrator runs your selected agent strategy as a
**Foundry hosted agent** or a **Container App**. Hosting controls where it runs.
Strategies control how it coordinates models, retrieval and tools. Changing one
does not automatically change the other.

Use this page to choose a topology and understand its contracts. Execute the
ordered procedure in [Deploy the full stack](deploy-full-stack.md), or stop at
the foundation with [Deploy infrastructure only](deploy-infra-only.md).

## Topologies

| `DEPLOYMENT_TOPOLOGY` | Orchestrator runs as | Administrative panel | Agent Application Cosmos DB |
| --- | --- | --- | --- |
| `hosted-no-panel` (fresh default) | Foundry hosted agent | Not deployed | Not deployed |
| `hosted-panel` | Foundry hosted agent | Deployed | Deployed |
| `classic` | Container App | Not applicable | Deployed |

This table describes Agent Application, not resources retained after a
migration. In `hosted-panel`, Agent Application Cosmos DB stores owner-index and
feedback metadata, not hosted transcripts. Foundry Agent Service can have its
own backing Cosmos DB. Continuity and history need separate configuration.

**Topology resolution**

- An explicit `DEPLOYMENT_TOPOLOGY` selects the topology.
- New environments default to `hosted-no-panel`.
- Existing environments retain a recorded topology.
- Older environments without a topology marker resolve to `classic`, rather
  than silently moving an existing runtime.

Choose before provisioning, for example:

```bash
azd env set DEPLOYMENT_TOPOLOGY hosted-panel
```

Ingestion selection is independent of all three topologies. Native source
ingestion does not replace conversation uploads or Agent Application's SharePoint
jobs. See [Ingestion and conversation uploads](ingestion.md).

## Image and deployment handoff

A hosted deployment separates **foundation provisioning**, **image preparation**
and **agent-version deployment**. Preparation builds the manifest-pinned
orchestrator, resolves it to an immutable digest and adds the supported hosted
startup command. Provisioning then records that digest in the deployment handoff.
Provisioning alone does not create a running agent version.

Follow the [full-stack runbook](deploy-full-stack.md) for the exact initial
sequence. A fresh `azd up` does not build a missing hosted image or replace the
required handoff provision. Private builds use the VNet's ACR Tasks agent pool.

### Redeploy the same image or prepare a new one

| Change | Required behavior |
| --- | --- |
| Same digest, compatible source and provisioned handoff | Deployment can reuse the image. |
| Changed manifest orchestrator commit | Prepare a new generated image and provision its handoff before deployment. Deploy-only does not rebuild it or check generated source provenance against the new manifest. |
| Changed process environment in `hosted-agent/azure.yaml` | Deploy a new agent version, potentially using the same digest. Running versions are not mutated. |
| Explicit digest without generated-source provenance | You manage compatibility and registry availability. Preparation does not automatically replace it when source pins change. |

Generated images are reused only when recorded source and startup-command
provenance match. Preparation with `--image-version sha256:<64-hex-characters>`
skips building and clears generated provenance. Promoting identical source pins
does not prove that independently built images have identical digests.

Use [Agent Application redeployment](deploy-full-stack.md#redeploy-applications-only)
or the [upgrade workflow](deploy-full-stack.md#upgrade-to-a-new-release).

## Validation rules

| Setting | Contract |
| --- | --- |
| `HOSTED_AGENT_IMAGE_VERSION` | Immutable `sha256:` digest followed by 64 hexadecimal characters. Image tags are rejected. |
| `HOSTED_AGENT_RESOURCE_SCOPE` | Explicit delegated-user audience ending in `/.default`, supplied before provisioning. It is not the UI's own API scope. |
| `HOSTED_AGENT_STARTUP_COMMAND` | Fixed to `uvicorn src.api.hosted_entrypoint:app --host 0.0.0.0 --port 8088`. Custom values are rejected. |
| `HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS` | Stream idle timeout, default `60`. |
| `HOSTED_CONTINUITY_ENABLED` | Default `false`. Requests separately validated continuity activation, not generic runtime history. |
| `PRESERVE_CLASSIC_RUNTIME` | Default `false`. Can retain classic orchestration during a reviewed hosted migration. |

The Agent Application child definition, `hosted-agent/azure.yaml`, declares agent
name, CPU, memory, protocols and startup command as literal fields. Similarly named provisioning
inputs do not automatically customize those fields. Deliberate child-definition
changes must remain compatible with the provisioning contract.

For a custom definition, `source.imageDigest` becomes `AGENTLZ_IMAGE_DIGEST`.
It is not interchangeable with Agent Application's `HOSTED_AGENT_IMAGE_VERSION`.
See [Custom applications](build-your-own-app.md#source-pinning).

## Bootstrap the agent's runtime access

These identities serve different purposes:

| Identity | Responsibility |
| --- | --- |
| Deployment principal | Provisions resources, authors agent versions and reconciles authorized scoped grants. |
| Foundry project managed identity | Pulls the image using the foundation's registry grant. |
| Actual deployed agent runtime principal | Reads its runtime configuration and calls authorized services. |
| Delegated user | Needs caller/agent access and permission to the requested data. |

Agent Landing Zone's post-deploy hook discovers the actual runtime principal and grants
App Configuration Data Reader on the store and Cognitive Services OpenAI User on
the Foundry account. If `AUDIT_HMAC_KEY` is a Key Vault reference, it also plans
Key Vault Secrets User on that **individual secret**. This is a closed bootstrap
set, not every component capability profile or a caller-access grant.

The deployment principal needs scoped role-assignment authority. Alternatively,
an authorized administrator can review and apply the exact read-only plan.
Do not grant resource-group/subscription Owner or remove unrelated assignments
to resolve a denial. ARM grant visibility is not proof of data-plane readiness.
Allow propagation and use [hosted access recovery](deploy-full-stack.md#recover-hosted-runtime-access).

Custom hosted services instead reconcile their declared capability profiles
against their discovered runtime principal. See
[Capability profiles](build-your-own-app.md#capability-profiles).

## Calling the agent

### Configure the UI's delegated authentication

The UI defaults to `HOSTED_AGENT_AUTH_MODE=user_delegated`. It exchanges the
signed-in user's token using OAuth on-behalf-of (OBO), with **no fallback to the
UI managed identity**. Publish these settings under App Configuration label
`agent-lz` before accepting user sign-in:

| Key | Value |
| --- | --- |
| `OAUTH_AZURE_AD_CLIENT_ID` | Confidential Entra application's client ID. |
| `OAUTH_AZURE_AD_TENANT_ID` | Its tenant ID. |
| `OAUTH_AZURE_AD_CLIENT_SECRET` | Key Vault reference, never plaintext. |
| `OAUTH_AZURE_AD_SCOPES` | `api://<client-id>/user_impersonation openid profile offline_access` for the UI's single-token login. |
| `CHAINLIT_URL` | Canonical HTTPS frontend origin without a trailing slash. |

Expose `user_impersonation`, request version-2 access tokens and register the
exact HTTPS `/auth/oauth/azure-ad/callback` redirect URI. Separately configure
and consent the downstream delegated permissions for the deployed Foundry
audience. A Graph token or the UI's API scope is not Foundry OBO consent.

!!! warning "Verify the user path"
    A successful managed-identity greeting does not prove login, OBO or document
    authorization. Test real-user invocation and document allow/deny behavior,
    and verify unauthenticated panel requests are rejected. The panel has no
    development authentication bypass.

<details markdown="1">
<summary>Callbacks, credentials and panel requirements</summary>

Behind TLS-terminating ingress, explicitly set `CHAINLIT_URL`. Check that
`/auth/oauth/azure-ad` redirects with the exact registered HTTPS callback.
Fix an HTTP callback by correcting the canonical URL and restarting the UI,
not by registering an insecure redirect.

With `hosted-panel` and ingestion selected, ingestion also needs the OAuth
tenant and client ID. Follow tenant credential-lifetime policy, record
expiration and rotate the Key Vault credential before it expires. A stable,
protected `CHAINLIT_AUTH_SECRET` prevents session resets from a newly
generated temporary signing secret.

</details>

### Protocol and caller access

- **Responses 2.0.0 is stateless.** A non-null `previous_response_id` returns
  HTTP 422. Top-level `conversation` and other unhandled routing/sampling fields
  do not load history. Supply bounded, ordered input ending in the user message.
- Agent App UI uses **`/invocations?api-version=v1`**. Its `conversation_id`
  labels conversation-scoped retrieval, not permission to load managed history.
  The UI accepts `response.conversation.id` and the compatibility
  `response.conversation_id`; malformed or conflicting IDs fail explicitly.
- A delegated caller needs Foundry user access on the project **and** agent
  access. Deployment permission alone does not provide this.

For Teams and Microsoft 365 Copilot, follow [Publish to Teams and M365](publish-to-teams.md).
It uses Bot Service authorization and the Foundry Activity endpoint, not the
UI's delegated invocation path.

For a Copilot Studio agent calling a private Foundry hosted agent, follow
[Connect Copilot Studio](connect-copilot-studio.md). It uses a Power Automate
agent flow with an authenticated HTTPS connection and VNet delegation, not the
[native connected-agent tool](https://learn.microsoft.com/microsoft-copilot-studio/add-agent-foundry-agent).
Review its shared-connection identity boundary
before using it with protected data.

<details markdown="1">
<summary>Continuity, history and the administrative panel</summary>

Without continuity, hosted multi-turn context in the active UI session is
not durable history after reload, browser restart or a new chat. Hosted mode
does not register the classic orchestrator/Dapr history data layer. Login,
chat and feedback callbacks remain available.

When enabled and activated, continuity coordinates managed Conversations
reads/writes in the UI with owner binding and agent-scoped permissions. It
sends the authorized transcript to the stateless runtime; it does not grant
the container general history access.

Panel history needs `DEPLOY_ADMINISTRATIVE_PANEL`, `PANEL_HISTORY_ENABLED`
and hosted continuity, plus authentication and owner checks. Disabled
history surfaces return HTTP 503. Cosmos owner-index/feedback data is
metadata, not a second transcript store. A topology or enabled flag alone
proves neither persistence nor cross-user isolation.

</details>

## Configuration TLS compatibility

`APP_CONFIG_TLS_COMPATIBILITY` is an opt-in **process environment variable**,
default `false`, read before remote configuration can load. Consider it only
after verifying private connectivity when App Configuration or Key Vault TLS
handshakes stall. It applies to the orchestrator loader, not every HTTP client.

When enabled, the profile uses P-256 and TCP MSS 1200 only for the configured
App Configuration and Agent Application Key Vault endpoints. Certificate/hostname
verification, custom CAs, TLS 1.2 or later, credentials and retries remain intact.
It requires the actual HTTPS `KEY_VAULT_URI`; missing URI or invalid boolean
fails startup.

Change the process input and deploy a new agent version using the
[redeployment runbook](deploy-full-stack.md#redeploy-applications-only).
An App Configuration key cannot replace this bootstrap input. Disable the
profile to revert it and redeploy. Never disable certificate validation or
infer a proven MTU root cause from a successful compatibility test.
See [TLS diagnosis](troubleshooting.md#hosted-configuration-tls-handshake-stalls).

## Telemetry and topology changes

Prompt/completion capture in telemetry is **off by default**. Enable it only
when your organization's policy permits storing that content in Application
Insights.

During a migration preserving classic runtime, routing stays classic until
`HOSTED_AGENT_BASE_URL`, a valid digest and `HOSTED_CUTOVER_COMPLETE=true`
are present. Cutover markers record hook completion, not user acceptance.
A failed greeting or selected component deployment blocks cutover.

To change topology, use the [full-stack runbook](deploy-full-stack.md), then
verify routing, intended revisions, authentication, source bindings and
authorization. Selecting classic does not select ingestion or delete a hosted
agent. The legacy `DEPLOY_HOSTED_AGENT_ORCHESTRATION=false` selects classic
only when `DEPLOYMENT_TOPOLOGY` is absent and the legacy flag pair is consistent.
Retiring the old runtime is a separate decision.
