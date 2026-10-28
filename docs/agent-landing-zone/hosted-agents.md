# Hosted agents

Agent App Orchestrator runs as a container in Foundry Agent Service. The fresh
default is `DEPLOYMENT_TOPOLOGY=hosted-no-panel` with `maf_lite` orchestration.
The UI remains in Azure Container Apps. This page explains the hosting contract;
the [Deploy full stack runbook](deploy-full-stack.md) contains the ordered
deployment and recovery procedures.

## Topologies

| Hosted topology | Orchestrator | Administrative panel | Agent Application Cosmos DB |
| --- | --- | --- | --- |
| `hosted-no-panel` (default) | Foundry hosted container | Not deployed | Not deployed |

The table describes default application resources, not Foundry Agent Service's
own backing resources. This layout does not activate history, feedback or
operator access. Those capabilities have independent integration and validation gates.
Agent App Ingestion is selected separately, as described in
[Ingestion and conversation uploads](ingestion.md).

## Image and deployment handoff

Hosted deployment separates foundation provisioning from application deployment.
`azd provision` creates the project, registry, network and access prerequisites,
not a running agent or a placeholder. `azd deploy` automatically builds the
manifest-pinned orchestrator with the supported hosted startup command when
needed, records an immutable digest, binds the image to the provisioned
foundation and creates the agent version. No separate preparation command or
second provision is needed; `azd up` performs the full workflow.
Private builds still use the VNet's ACR Tasks agent pool.

### Redeploy the same image or prepare a new one

| Change | Deployment contract |
| --- | --- |
| Same generated digest, matching source and startup provenance | Deployment reuses the image. |
| Missing image or changed generated source/startup provenance | Deployment builds the manifest-pinned image and updates the handoff without reprovisioning. |
| Changed hosted process environment or cached runtime settings | A new agent version is required, potentially with the same compatible digest. |
| Explicit digest without generated-source provenance | Compatibility and registry availability are operator-owned. Deployment does not replace it automatically. |

Generated images are reused only when the recorded source revision and startup
command match. To supply an independently built image, set
`HOSTED_AGENT_IMAGE_VERSION` to its canonical digest and clear
`HOSTED_AGENT_IMAGE_SOURCE_COMMIT` and `HOSTED_AGENT_IMAGE_STARTUP_COMMAND_SHA256`.
The image must be available in the selected registry and repository and already
use the hosted entrypoint. Independent builds of the same source need not
produce the same digest. The standalone preparation scripts remain optional
compatibility commands; they are not required deployment steps.

The procedure is in [application redeployment](deploy-full-stack.md#redeploy-applications-only).

## Validation rules

[Deployment settings](configuration.md) distinguishes deployment inputs from
App Configuration keys and hosted process environment.

| Input | Contract |
| --- | --- |
| `HOSTED_AGENT_IMAGE_VERSION` | Immutable `sha256:` digest with 64 hexadecimal characters; tags are rejected. |
| `HOSTED_AGENT_RESOURCE_SCOPE` | Explicit delegated-user audience ending in `/.default`; not the UI API scope. |
| `HOSTED_AGENT_STARTUP_COMMAND` | Fixed to `uvicorn src.api.hosted_entrypoint:app --host 0.0.0.0 --port 8088`. |
| `HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS` | Stream idle timeout, default `60`. |

The supplied `hosted-agent/azure.yaml` declares the agent name, CPU, memory,
protocols and startup command as literal fields. Its image and environment
fields use azd interpolation. A custom application's `source.imageDigest`
instead becomes `AGENTLZ_IMAGE_DIGEST`; it is not interchangeable with
`HOSTED_AGENT_IMAGE_VERSION`. See [source pinning](build-your-own-app.md#source-pinning).

<span id="bootstrap-the-agents-runtime-access"></span>

## Runtime identities and access

| Identity | Responsibility |
| --- | --- |
| Deployment principal | Provisions resources, creates agent versions and reconciles authorized scoped grants. |
| Foundry project managed identity | Pulls the image through the registry grant. |
| Actual deployed agent runtime principal | Reads configuration and calls authorized dependencies. |
| Delegated user | Needs Foundry project/agent access and permission to requested data. |

The post-deploy hook discovers the runtime principal and grants App Configuration
Data Reader on the store and Cognitive Services OpenAI User on the Foundry
account. If `AUDIT_HMAC_KEY` is a Key Vault reference, the bootstrap plan also
includes Key Vault Secrets User on that individual secret. Native retrieval
also uses Search Index Data Reader scoped to the configured Search resource
for transport; native user/source authorization remains separate.

End-user source permissions, other secrets and caller permissions are outside
this closed bootstrap set.
Role reconciliation needs scoped role-assignment authority or an authorized
administrator applying the reviewed plan.
[Hosted access recovery](deploy-full-stack.md#recover-hosted-runtime-access)
contains the operational checks.

Custom services reconcile declared [capability profiles](build-your-own-app.md#capability-profiles)
against the discovered runtime principal.

## Calling the agent

<span id="configure-the-uis-delegated-authentication"></span>

### Delegated UI invocation

Hosted composition routes the UI with `CHAT_BACKEND=hosted_agent`. The UI
defaults to `HOSTED_AGENT_AUTH_MODE=user_delegated`. It exchanges the signed-in
user's UI API token for the Foundry audience through OAuth on-behalf-of (OBO),
without fallback to the UI managed identity.
[Agent Application access](application-auth.md) explains sign-in and consent.
Successful invocation is not evidence of document-level authorization.

Foundry does not forward the invocation Authorization header unchanged.
For native protected retrieval, the UI separately acquires a delegated Search
token and forwards it in `x-client-search-token`. Both hosted adapters keep it
request-local and the connector passes it to native Search permission
enforcement. Missing required credentials fail before retrieval; they never
trigger a service-identity retry.

Downstream Search authentication challenges terminate the current turn with a
safe typed failure. The UI can request explicit interactive verification using
the bounded claims; it does not replay the failed or partially streamed turn.
A source denial without usable claims remains denied.
See [authentication recovery](application-auth.md#recover-safely).

Native citation downloads stay on the authenticated UI and recheck source
authorization at redemption. Shared Blob/ADLS reads use Storage OBO;
conversation uploads require a fresh native Search ownership check before
workload Blob transport. The bundled UI's `retrieval-reader` profile supplies
the Search transport role, not the user's entitlement.
See [protected citation downloads](application-auth.md#protected-citation-downloads)
for consent and source-access requirements.

The container's code still controls model calls, retrieval and tools. Portal
instructions or tool attachments do not automatically reconfigure `maf_lite`;
[Agent tools](agent-tools.md) describes the separate Toolbox extension boundary.

### Protocol and caller access

- **Responses 2.0.0 is stateless.** Non-null `previous_response_id` returns
  HTTP 422. Top-level `conversation` does not load managed history. Input
  contains bounded, ordered prior messages ending in the current user message.
- Agent App UI uses **`/invocations?api-version=v1`**. Its `conversation_id`
  labels conversation-scoped retrieval; it is not permission to load history.
  The UI accepts `response.conversation.id` and `response.conversation_id`,
  and rejects malformed or conflicting IDs.
- A delegated caller needs Foundry project user access and agent access.
  Deployment permission alone is insufficient.

[Publish to Teams and M365](publish-to-teams.md) uses Bot Service authorization
and the Activity endpoint. [Connect Copilot Studio](connect-copilot-studio.md)
uses an authenticated Power Automate flow and VNet delegation, not the
[native connected-agent tool](https://learn.microsoft.com/microsoft-copilot-studio/add-agent-foundry-agent).
These have different caller-identity contracts from the UI.

### Continuity, history and the administrative panel

Without continuity, multi-turn context lasts only for the active UI session.
Reload, browser restart or a new chat loses that context. The hosted container
does not read or write managed Conversations.

`HOSTED_CONTINUITY_ENABLED` defaults to `false`. Delegated continuity requires
validated owner isolation, Responses protocol at least `2.0.0`, and the
middle-tier identity's reviewed agent-scoped `UserIdentityImpersonation` data
action. `HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED` is an evidence gate,
not a way to grant those permissions. Provisioning leaves it false.
When validated continuity is active, the UI sends the authorized transcript
to the stateless container, which still does not load managed history.

Panel user routes additionally require actual panel deployment,
`PANEL_HISTORY_ENABLED` and active continuity; otherwise they return HTTP 503.
The panel's delegated enumeration and operator surfaces have separate gates,
`PANEL_HISTORY_OWNER_BINDING_VALIDATED` and `PANEL_OPERATOR_SURFACES_ENABLED`.
They remain false until their own authorization checks have evidence.
Cosmos holds owner-index/feedback metadata; managed transcripts reside in
Foundry. [User feedback](user-feedback.md) explains the missing UI integration.

## Configuration TLS compatibility

`APP_CONFIG_TLS_COMPATIBILITY` is an opt-in process environment variable,
default `false`, read before remote configuration. It applies only to the
orchestrator loader's configured App Configuration and Key Vault endpoints.
The profile uses P-256 and TCP MSS 1200 while retaining certificate/hostname
verification, custom CAs, TLS 1.2 or later, credentials and retries.
It requires the actual HTTPS `KEY_VAULT_URI`; invalid input fails startup.

An App Configuration key cannot replace this bootstrap input. A changed value
requires a new hosted version. The [TLS diagnosis reference](troubleshooting.md#hosted-configuration-tls-handshake-stalls)
covers transport diagnosis without disabling certificate validation.

<span id="telemetry-and-topology-changes"></span>

## Telemetry

Prompt/completion capture is off by default. The deployment input
`HOSTED_AGENT_CAPTURE_MESSAGE_CONTENT` maps to the hosted process variable
`OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT`. A changed value requires
a new agent version. Capture into Application Insights is a data-retention
and privacy decision, not a prerequisite for chat.
