# Run locally

Run an application component on your workstation while using an existing
development platform. This is not an offline chat demo and does not provision
Azure resources. Local servers still need network access, configured models,
storage, and the permissions used by their selected features.

For code changes, continue with [Customize components](customize-components.md)
and [Tests & quality checks](application-testing.md). For deployment, use
[Deploy full stack](deploy-full-stack.md), not a component's deployment hooks.

## Before you start

- Obtain a compatible development platform and its Azure App Configuration
  endpoint. App Configuration holds runtime settings and references to secrets
  in Key Vault. Use [Application settings](application-settings.md) to check
  effective values and labels.
- Use Python 3.12 and Azure CLI. Sign in to the intended tenant and subscription.
  CLI sign-in supplies a local identity, not automatic permission to read
  configuration, secrets, models, Search, Blob Storage, or Cosmos DB.
- Obtain data-plane role assignments for the services you will use. A
  data-plane permission authorizes access to service data, rather than resource
  creation. Private endpoints also require connected networking and DNS.
- Clone only the components you need from
  [orchestrator](https://github.com/Azure/agent-app-orchestrator),
  [ingestion](https://github.com/Azure/agent-app-ingestion), and
  [UI](https://github.com/Azure/agent-app-ui).
  To reproduce the application, use the compatible source revisions in the
  platform's [manifest](https://github.com/Azure/agent-landing-zone/blob/main/manifest.json)
  at your platform release. Repository `main` can contain newer patches.
  For contributions, use the repository's target branch and current checks.

The credential providers try managed identity, then Azure CLI.
`AZURE_CLIENT_ID` selects a user-assigned managed identity when applicable.
Do not copy an Azure workload's credentials to a workstation. Store secrets
in Key Vault and never commit local environment files or tokens.

The component `infra/main.bicep` files are empty resource-group entrypoints.
Their `azure.yaml` files and deployment scripts assume an existing platform.
`azd deploy` can build, push, and replace running images. It is not a local
startup or validation command.

## Prepare each repository

Run this setup **separately from each component repository root**. Keep separate
virtual environments because the components have different dependency sets.
The examples use an activated environment.

```text
python -m venv .venv
```

In PowerShell:

```powershell
.\.venv\Scripts\Activate.ps1
```

In Bash:

```bash
source .venv/bin/activate
```

Then install that repository's runtime requirements:

```text
python -m pip install -r requirements.txt
az login
```

If PowerShell activation is restricted, use `.\.venv\Scripts\python.exe`
in place of `python` rather than changing execution policy.

Set the endpoint in **each server's shell**. For PowerShell:

```powershell
$env:APP_CONFIG_ENDPOINT = "https://<development-store>.azconfig.io"
```

For Bash:

```bash
export APP_CONFIG_ENDPOINT="https://<development-store>.azconfig.io"
```

Do not assume that setting an environment variable overrides a remote setting:

| Component | Local override behavior |
| --- | --- |
| Orchestrator | Runtime environment overrides require `allow_environment_variables=true`. Its parser also accepts `1` and `yes`. The classic entrypoint loads `.env`, not `.env.sample`. The hosted entrypoint expects process environment configuration. |
| Ingestion | Leave `allow_environment_variables` unset or empty to disable runtime environment overrides. **Any nonempty string, including `false`, enables them.** Use `true` for an intentional opt-in. Do not rely on an automatically loaded `.env`. |
| UI | There is no shared `allow_environment_variables` switch. Specific loaders, such as hosted backend and continuity settings, support environment overrides. Ordinary provider keys still come from App Configuration. An environment-only provider does not make the application ready. |

Bootstrap values such as `APP_CONFIG_ENDPOINT` are direct process inputs.
See [Application settings](application-settings.md) for provider precedence,
required feature settings, and restart behavior.

## Orchestrator

The orchestrator chooses an agent strategy, calls models and tools, and streams
answers. In the **orchestrator root**, after the setup above:

```text
python -m uvicorn main:app --app-dir src --host 127.0.0.1 --port 9000
```

Classic startup needs the shared strategy settings
`AI_FOUNDRY_PROJECT_ENDPOINT`, `AI_FOUNDRY_ACCOUNT_ENDPOINT`, and
`CHAT_DEPLOYMENT_NAME`. Conversation storage also needs
`DATABASE_ACCOUNT_NAME` and `DATABASE_NAME`.
`CONVERSATIONS_DATABASE_CONTAINER` defaults to `conversations`.
Retrieval and optional integrations need their own resources and permissions.
The sample environment file is illustrative, not a complete platform.

SQL and Fabric connectors use `pyodbc`, Python's Open Database Connectivity
adapter. For SQL execution, install Microsoft ODBC Driver 18 for SQL Server and
the native ODBC dependencies for your OS, as illustrated by the repository's
Dockerfile. On Linux, importing `pyodbc` may also require the native ODBC loader
even when you are not executing a SQL strategy. Installing Python requirements
alone does not install a database driver. Use a least-privilege read-only
database identity for generated SQL.

Call `POST /orchestrator` using the
[classic API contract](application-api.md#classic-orchestrator). Service
credentials and the user's bearer token are distinct requirements.
`ALLOW_ANONYMOUS` does not bypass service authentication.
Do not use `DISABLE_AUTH=true` on a shared or publicly reachable service.

For the classic `mcp` strategy, the client uses `http://localhost:5000`
outside Azure detection, even if another `MCP_APP_ENDPOINT` was configured.
Run your local MCP test server there. Detection checks `CONTAINER_APP_NAME`
or `WEBSITE_INSTANCE_ID`, not whether you ran `az login`.
Use [Tools & MCP](agent-tools.md) for transport and endpoint configuration.

### Hosted entrypoint

To develop the hosted protocol adapter, start this **instead of** the classic
entrypoint, from the orchestrator root:

```text
python -m uvicorn api.hosted_entrypoint:app --app-dir src --host 127.0.0.1 --port 8001
```

This selects another ASGI application, the Python web-server entrypoint.
It does not register an agent with Foundry or emulate Foundry ingress and
identity passthrough. Only `maf_lite`, `maf_agent_service`,
`single_agent_rag`, and `mcp` are hosted-eligible. Hosted execution uses
file-backed prompts and caller-supplied text history, not classic Cosmos state.
`mcp` requires a valid platform-injected call ID and is not a bare local HTTP
substitute for Toolbox. See [Hosted agents](hosted-agents.md) and the
[hosted API contracts](application-api.md#hosted-orchestrator).

## Ingestion

The ingestion service processes documents and can change Search indexes and
Blob control data.

!!! warning "Starting ingestion can write and delete data"
    Use an isolated development environment. `RUN_JOBS_ON_STARTUP` defaults to
    `true`. Setting it to `false` skips immediate ingestion and purge runs,
    **not scheduled runs or immediate log cleanup**. Blob indexing defaults
    to `0 * * * *`, Blob purge to `10 * * * *`, and log cleanup to
    `0 * * * *`. Blank Blob schedules receive defaults rather than disabling
    those jobs. Review [Jobs & schedules](ingestion-jobs.md) before startup.

In the **ingestion root**, after reviewing the effective schedules and completing
the common setup:

```text
python -m uvicorn main:app --host 127.0.0.1 --port 8080
```

Configure Search, storage, embedding models, and the analysis service required
by the selected pipeline. Content Understanding is the default analysis path
when `USE_DOCUMENT_INTELLIGENCE=false`. Multimodal processing is a separate
opt-in. There is no universal requirement to configure every source or SQL
database for every pipeline.

`GET /healthz` is a liveness probe. `GET /readyz` checks configuration
initialization and can return `503`. Neither proves that indexing succeeded.
Use [Ingestion APIs](application-api.md#ingestion-document-apis) for request
envelopes and API-key requirements, not an arbitrary multipart upload.

## Chat UI

The UI is a Chainlit Python application, not either service's React dashboard.
In the **UI root**, after the common setup, install its package and start:

```text
python -m pip install --no-deps -e .
python -m uvicorn main:app --host 127.0.0.1 --port 8000
```

Port `8000` avoids the ingestion server on `8080`. Configure the local public
origin and sign-in redirect deliberately using
[Sign-in & access](application-auth.md). Features requiring a configured HTTPS
origin, including protected-source recovery, still need that origin and an
appropriate local HTTPS proxy. Changing the listening port alone does not
reconfigure Entra or callback URLs.

`CHAT_BACKEND` defaults to `hosted_agent`. Use `orchestrator` explicitly for
the classic backend, with its endpoint and service credentials configured.
Hosted failures do not fall back to classic execution.
The default hosted `user_delegated` authentication uses an on-behalf-of
exchange, where the UI exchanges a user's API token for a downstream token.
It needs the confidential-client settings and consent described in
[Sign-in & access](application-auth.md). Do not switch to `service_identity`
to work around login or consent failures.

Keep `.chainlit/`, `public/`, `chainlit.config.yaml`, `chainlit.md`, and
`VERSION` together in a writable application root. A source-checkout `main.py`
uses its adjacent assets. For an installed package staged elsewhere, set
`CHAINLIT_APP_ROOT` to that root or start there. A wheel contains code, not a
self-contained deployed UI. Do not write assets into `site-packages`.
Missing `VERSION` is optional and a missing `.chainlit/config.toml` produces
a warning.

A missing or disconnected App Configuration provider produces an HTTP `503`
not-ready app. Uploads additionally require the optional ingestion application
and an authorized conversation. See [Conversations & files](conversations.md).

## Operator dashboard frontend

The orchestrator and ingestion repositories each contain a React/TypeScript
dashboard under `frontend/`. Vite is their local frontend server and build tool.
It proxies API requests to an independently running backend.

| Repository | Node used by current CI | Install from `frontend/` | Development proxy | Build output |
| --- | --- | --- | --- | --- |
| Orchestrator | 20 | `npm install --no-audit --no-fund` | `/api` to `http://localhost:9000` | `src/static/` |
| Ingestion | 22 | `npm ci` | `/api` to `http://localhost:8080` | `static/` |

After the repository-specific install, run `npm run dev` from `frontend/`.
Start the corresponding Python backend in another shell using the commands
above. The proxy neither starts the backend nor bypasses authorization.
The ingestion Dockerfile's Node 20 build stage is not the maintained local/CI
Node 22 choice. Do not bypass peer-dependency checks.

`npm run build` writes the static bundle consumed by FastAPI at `/dashboard`
when the administrative surface is mounted. A bundle does not enable that
surface. Orchestrator requires `ENABLE_DASHBOARD=true`.
Ingestion mounting depends on hosted/panel mode. Both can expose a development
admin gate when Entra is not configured. Keep them private and follow
[Administration](operations.md) for production setup.

## Verify the intended boundary

Check the selected backend, effective configuration, and logs before exercising
a turn or upload. A listening port, successful probe, or local test is not
Azure readiness. Use the existing offline
[quality checks](application-testing.md) first. Any deployment, protected-source
authorization test, or ingestion run requires separate authorization and a
development dataset.
