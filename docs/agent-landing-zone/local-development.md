# Run locally

Use this guide to edit, debug or contribute component source against an existing
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
- Clone only the components whose source you need to edit or debug from
  [orchestrator](https://github.com/Azure/agent-app-orchestrator),
  [ingestion](https://github.com/Azure/agent-app-ingestion), and
  [UI](https://github.com/Azure/agent-app-ui), or optional
  [MCP server](https://github.com/Azure/agent-app-mcp).
  To reproduce the application, use the compatible source revisions in the
  platform's [manifest](https://github.com/Azure/agent-landing-zone/blob/main/manifest.json)
  at your platform release. Repository `main` can contain newer patches.
  For contributions, use the repository's target branch and current checks.

The UI and ingestion configuration providers try managed identity, then Azure
CLI. Native orchestrator configuration uses `DefaultAzureCredential`; its
DTS transport has a separate credential selection described below.
The MCP server and its administrative importer require a
configured managed identity; Azure CLI sign-in is not their fallback.

`AZURE_CLIENT_ID` selects a user-assigned managed identity when applicable.
Do not copy an Azure workload's credentials to a workstation. Store secrets
in Key Vault and never commit local environment files or tokens.

The component `infra/main.bicep` files are empty resource-group entrypoints.
Their `azure.yaml` files and deployment scripts assume an existing platform.
`azd deploy` can build, push, and replace running images. It is not a local
startup or validation command.

## Prepare each repository

For UI, orchestrator and ingestion, run this setup **separately from each component repository root**. Keep separate
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
| Orchestrator | Supply native host/mode and process bootstrap inputs explicitly. Relevant functional settings come from the scoped App Configuration provider. A sample `.env` does not replace the selected native entrypoint's contract. |
| Ingestion | Leave `allow_environment_variables` unset or empty to disable runtime environment overrides. **Any nonempty string, including `false`, enables them.** Use `true` for an intentional opt-in. Do not rely on an automatically loaded `.env`. |
| UI | There is no shared `allow_environment_variables` switch. Specific loaders, such as hosted backend and continuity settings, support environment overrides. Ordinary provider keys still come from App Configuration. An environment-only provider does not make the application ready. |

Bootstrap values such as `APP_CONFIG_ENDPOINT` are direct process inputs.
See [Application settings](application-settings.md) for provider precedence,
required feature settings, and restart behavior.

## Native orchestrator

Use the owning component's explicit native host entrypoint after preparing
its compatible published dependencies. **Before startup**, set process
inputs `APPLICATION_MODE` and `ORCHESTRATION_HOST` to match the development
platform's composition. Do not edit the shared store to redirect other users
to a local process.

| Host | Local-development boundary |
| --- | --- |
| Hosted | Official Responses hosting with request-aware agent/workflow factories. A local listener does not publish an application or simulate trusted Foundry ingress context. |
| Container Apps | Official standalone Durable Extension worker connected to a development DTS backend, with the native durable client. It is not a Hosted ASGI application or an Azure Functions host. |

### How to start the selected native host

From the **orchestrator root**, install the host-specific requirements and
the source package after the common setup. For Hosted:

```text
python -m pip install -r requirements-hosted.txt -r requirements-tools.txt
python -m pip install --no-deps -e .
python -m pip check
python -m native.hosted
```

The editable install exposes `src/native/` as the `native` module. The base
`requirements.txt` alone neither installs the hosting SDK nor exposes that
source package. Hosted listens on port `8080`; a local listener does not
reproduce trusted Foundry invocation context.

For the standalone durable worker, use a **separate environment** and instead run:

```text
python -m pip install -r requirements-container-apps.txt -r requirements-tools.txt
python -m pip install --no-deps -e .
python -m pip check
python -m native.durable
```

The worker has no public HTTP ingress or Dapr. Supply the actual
`DURABLE_TASK_SCHEDULER_CONNECTION_STRING` in its process environment.
The deployed binding uses `TaskHub=agent-lz;Authentication=ManagedIdentity`.
For an explicitly local **worker**, `Authentication=DefaultAzure` selects
`DefaultAzureCredential` instead; it is not an automatic deployment fallback.
Use the provisioned endpoint and a separately authorized development hub.
Keep native names
`agent-lz-conversation` and `agent-lz-research-review` aligned with the UI client.

Confirm package validation succeeds, configuration loads and the intended
listener or worker starts. Exercise the host's maintained
[SDK/behavioral tests](application-testing.md#orchestrator) before a live
turn. CLI sign-in still needs configuration/model permissions and, for local
DTS, scheduler access approved by the scheduler owner.

The selected mode needs its model, configuration and tool dependencies.
Hosted native execution does not require application Cosmos; DTS owns durable
worker execution. UI product metadata and a selected NL2SQL toolset can
have their own storage requirements. Do not require every optional source
credential or secret to start an unrelated capability.

The orchestrator consumes the authenticated MCP endpoint; it does not need an
ODBC driver or SQL/catalog grants for NL2SQL. The separate MCP server owns
those dependencies. Use [Agent App MCP Server](agent-app-mcp.md) for catalog
and identity responsibilities, not direct SQL configuration in this process.

For local MCP development, follow the MCP repository's contributor setup and
frozen dependency lock rather than the `requirements.txt` setup above.

Select toolsets explicitly: `MCP_TOOLSETS=[]` starts an authenticated server
with zero tools and no NL2SQL clients/dependencies; `["nl2sql"]` selects the
SQL toolset. Changes require restart/redeployment, not hot reload.

The NL2SQL execution environment requires Microsoft ODBC Driver 18 for SQL Server
and native ODBC dependencies; installing Python packages alone does not
install the driver. Use approved development metadata and read-only SQL access.

Local startup neither provisions the catalog nor authorizes Azure callers.
The administrative importer is separate from the MCP query service.
Run [catalog import](nl2sql.md#3-import-the-approved-file-after-provisioning) on an authorized
managed-identity runner, not an unconfigured workstation.

Use host-specific native inputs and clients described in the
[API reference](application-api.md#native-execution-contracts).
Test installed SDK call shapes and owner/pending-request denial with synthetic
data before live use. Mocks do not prove deployed checkpoint durability or
private connectivity. [Agent hosting](hosted-agents.md) explains publication
and worker requirements; [Tools & MCP](agent-tools.md) explains registration.

## Ingestion

The ingestion service processes documents and can change Search indexes and
Blob control data.

!!! warning "Starting ingestion can write and delete data"
    Use an isolated development environment. `RUN_JOBS_ON_STARTUP` defaults to
    `true`. Setting it to `false` skips immediate ingestion and purge runs,
    **not scheduled runs or immediate log cleanup**.

    Blob indexing defaults
    to `0 * * * *`, Blob purge to `10 * * * *`, and log cleanup to
    `0 * * * *`. Blank Blob schedules receive defaults rather than disabling
    those jobs. Review [Jobs & schedules](ingestion-jobs.md) before startup.

In the **ingestion root**, after reviewing the effective schedules and completing
the common setup:

```text
python -m uvicorn main:app --host 127.0.0.1 --port 8080
```

Run this ingestion example and the Hosted example as **alternatives**: both
bind port `8080` and cannot run simultaneously on the same address and port.

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

Port `8000` avoids port `8080`, used by either the Hosted or ingestion example.
Configure the local public
origin and sign-in redirect deliberately using
[Sign-in & access](application-auth.md). Features requiring a configured HTTPS
origin, including protected-source recovery, still need that origin and an
appropriate local HTTPS proxy. Changing the listening port alone does not
reconfigure Entra or callback URLs.

`APPLICATION_MODE` selects conversation, workflow or both.
`ORCHESTRATION_HOST` selects the explicit Hosted or durable client.
Hosted `both` requires two publication endpoints; the durable client needs
the actual scheduler binding and the worker's registered names.
Host/client configuration failures are reported rather than silently switching hosts.

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
not-ready app. Private attachments require their explicitly selected file
path and ownership checks; ingestion is not a replacement upload path. See
[Conversations & files](conversations.md).

## Operator dashboard frontend

The ingestion repository contains its React/TypeScript operator dashboard
under `frontend/`. Native orchestrator entrypoints do not mount a dashboard
or ingestion administration APIs. Vite is ingestion's frontend server and build tool.
It proxies API requests to an independently running backend.

| Repository | Node used by current CI | Install from `frontend/` | Development proxy | Build output |
| --- | --- | --- | --- | --- |
| Ingestion | 22 | `npm ci` | `/api` to `http://localhost:8080` | `static/` |

After the repository-specific install, run `npm run dev` from `frontend/`.
Start the corresponding Python backend in another shell using the commands
above. The proxy neither starts the backend nor bypasses authorization.
The ingestion Dockerfile's Node 20 build stage is not the maintained local/CI
Node 22 choice. Do not bypass peer-dependency checks.

`npm run build` writes the static bundle consumed by FastAPI at `/dashboard`
when the administrative surface is mounted. Build it **before backend startup**
if you need `/dashboard`; a frontend build alone does not remount routes in a
running backend. Route mounting belongs to the ingestion component's startup
configuration, not `ORCHESTRATION_HOST`.

It can expose a development admin gate when Entra
is not configured. Keep those endpoints private and follow
[Administration](operations.md) for production setup.

## Verify the intended boundary

After starting the component:

1. For ingestion, read `http://127.0.0.1:8080/healthz` and `/readyz`, then
   inspect the scheduler's effective target and next runs. Do not trigger a job
   until the storage/index owners approve the development corpus.
2. For UI, open `http://127.0.0.1:8000` and complete the configured sign-in.
   Verify the selected host/client and a synthetic owner-bound session.
   Persistent features need the local identity's scoped metadata access,
   not a copied workload credential.
3. After endpoint, host or startup dependency changes, stop and restart the
   affected local process. Use supported functional refresh only for the
   settings covered by [Application settings](application-settings.md).
4. Stop the local servers when finished. Do not leave an ingestion scheduler
   writing to development resources unintentionally.

Check the selected backend, effective configuration, and logs before exercising
a turn or upload. A listening port, successful probe, or local test is not
Azure readiness. Use the existing offline
[quality checks](application-testing.md) first. Any deployment, protected-source
authorization test, or ingestion run requires separate authorization and a
development dataset.
