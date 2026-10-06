# Hosted agents

By default (`DEPLOYMENT_TOPOLOGY=hosted-no-panel`) the orchestrator runs as a Foundry hosted agent in Foundry Agent Service instead of a Container App.

## How the deployment works

The hosted agent is deployed in two phases, which `azd up` runs for you:

1. **Provision** — the platform and Foundry project are created.
2. **Prepare** — `prepareHostedDeployment` builds the orchestrator image, records its digest, and enables the hosted parameters.
3. **Provision again** — the hosted agent resource is created with the image digest.
4. **Deploy** — the remaining components are deployed.

Images are built with ACR Tasks. With `NETWORK_ISOLATION=true` they are built on the ACR Tasks agent pool inside the virtual network. The resolved image digest is stored in `AGENTLZ_IMAGE_DIGEST`.

## Validation rules

The deployment stops early when the hosted configuration is invalid:

| Setting | Rule |
| --- | --- |
| `HOSTED_AGENT_RESOURCE_SCOPE` | Required; must end with `/.default` |
| `HOSTED_AGENT_IMAGE_VERSION` | Must be an image digest `sha256:<64 hex characters>`; tags are rejected |
| `HOSTED_AGENT_STARTUP_COMMAND` | Fixed to the orchestrator entry point; a custom value is rejected |

Other parameters:

| Variable | Purpose |
| --- | --- |
| `HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS` | Idle timeout for streamed responses |
| `HOSTED_CONTINUITY_ENABLED` | Enables conversation continuity endpoints |
| `PRESERVE_CLASSIC_RUNTIME` | Keeps the classic Container App until the hosted cutover is complete |

The cutover from classic to hosted is ready only when `HOSTED_AGENT_BASE_URL`, the image digest, and the cutover-complete flag are all set.

## Access bootstrap

Grant callers access to the hosted agent:

```bash
# Bash
./scripts/bootstrapHostedAccess.sh
```

```powershell
# PowerShell
./scripts/bootstrapHostedAccess.ps1
```

The script uses `AGENTLZ_HOSTED_PROJECT` (default `hosted-agent`) and `AGENTLZ_HOSTED_SERVICE` (default `orchestrator-agent`), assigns the required roles, and sends a `Hello!` smoke test. To review the changes before applying them:

```bash
python -m config.hosted_access --plan
python -m config.hosted_access --apply
```

## Calling the agent

- **Responses protocol 2.0.0** is stateless. Sending `conversation` or `previous_response_id` returns HTTP 422; send the full context in each request.
- **`/invocations`** is kept for legacy clients.
- A caller that uses user-delegated identity needs the Foundry user role on the project **and** access to the agent.

## Conversation continuity and panel

Continuity and administrative panel endpoints return HTTP 503 unless they are enabled. Continuity applies only to the hosted topologies. Use `DEPLOYMENT_TOPOLOGY=hosted-panel` to deploy the administrative panel.

## Telemetry content capture

Prompt and completion content is not captured in telemetry by default. Enable content capture only in environments where storing that content in Application Insights is allowed.

## Fall back to the classic topology

```bash
azd env set DEPLOYMENT_TOPOLOGY classic
azd up
```

The legacy flag `DEPLOY_HOSTED_AGENT_ORCHESTRATION=false` has the same effect when `DEPLOYMENT_TOPOLOGY` is not set.
