# Hosted agents

Agent Landing Zone can run the Agent App Orchestrator in two ways: as a **Foundry hosted agent** in Foundry Agent Service, or as a **Container App** (the classic topology). The topology is selected with `DEPLOYMENT_TOPOLOGY`.

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

Expose the application's `user_impersonation` API scope, request access tokens
version 2, and register the UI's HTTPS
`/auth/oauth/azure-ad/callback` redirect URI. Configure and consent the
downstream delegated permissions needed for the deployed Foundry audience
separately. The UI's own API scope is not proof of Foundry OBO consent, and a
Microsoft Graph token is not a replacement for the UI API token.

For `hosted-panel`, ingestion also requires the OAuth tenant and client ID;
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
