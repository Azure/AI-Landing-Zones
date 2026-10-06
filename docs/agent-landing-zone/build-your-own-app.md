# Build your own application

Agent Landing Zone deploys the reference application (UI, orchestrator,
ingestion) by default, but the platform is not tied to it. You can deploy your
own application on the same landing zone by describing it in an
**application definition**: a JSON file validated against
`contracts/app-definition-v1.schema.json`.

The definition declares *what* to deploy and *which capabilities* each
component needs. The platform decides *how*: it provisions the hosting,
assigns least-privilege Azure roles from capability profiles, and publishes
your settings to App Configuration. Your application never names Azure roles,
remote URLs, or lifecycle hooks.

!!! note
    One azd environment hosts exactly one application. To try a custom
    application, use a **new** azd environment.

## Application definition schema

### Top level

| Field | Required | Description |
| --- | --- | --- |
| `schemaVersion` | Yes | Always `1`. |
| `id` | Yes | Stable identifier of the application. |
| `displayName` | Yes | Human-readable name. |
| `components` | Yes | One or more deployable components. |
| `settings` | No | Application settings published to App Configuration. |

### Components

| Field | Required | Description |
| --- | --- | --- |
| `name` | Yes | Lowercase, starts with a letter, 2–24 characters (`^[a-z][a-z0-9-]{1,23}$`). |
| `kind` | Yes | `containerapp` (Azure Container Apps) or `azure.ai.agent` (Microsoft Foundry hosted agent). |
| `path` | Yes | Relative folder containing the component and its own `azure.yaml`. Must not contain `..`. |
| `source` | Yes | Exactly one of `{ "commit": "<40 hex characters>" }` or `{ "imageDigest": "sha256:<64 hex characters>" }`. |
| `profiles` | Yes | Capability profiles (see below). May be empty. |
| `ingress` | No | `external` or `internal` (default `internal`). `containerapp` only. |
| `resources` | No | `cpu` (0.25, 0.5, 0.75, 1.0, 1.5, 2.0; default 0.5) and `memory` (0.5Gi, 1.0Gi, 1.5Gi, 2.0Gi, 3.0Gi, 4.0Gi; default 1.0Gi). `containerapp` only. |

`azure.ai.agent` components must not set `ingress` or `resources`; Foundry
manages their hosting.

### Settings

| Field | Required | Description |
| --- | --- | --- |
| `key` | Yes | Uppercase, 2–64 characters, must not start with `AGENTLZ_` (reserved for the platform). |
| `value` | One of | Plain value published with label `agent-lz`. |
| `secret` | One of | `true` to declare a secret stored in Key Vault and exposed as a Key Vault reference. Never combine with `value`. |

### Example

```json
{
  "$schema": "../../../contracts/app-definition-v1.schema.json",
  "schemaVersion": 1,
  "id": "sample-containerapp",
  "displayName": "Sample custom application (Container App)",
  "components": [
    {
      "name": "web",
      "kind": "containerapp",
      "path": "src",
      "source": { "commit": "0000000000000000000000000000000000000000" },
      "profiles": [],
      "ingress": "external",
      "resources": { "cpu": 0.5, "memory": "1.0Gi" }
    }
  ],
  "settings": [
    { "key": "SAMPLE_GREETING", "value": "Hello from the sample application" }
  ]
}
```

## Capability profiles

Profiles are the only way a component obtains permissions. Each profile maps
to a fixed set of Azure built-in roles scoped to the landing-zone resources.

| Profile | Roles granted |
| --- | --- |
| `base` (always applied) | App Configuration Data Reader, AcrPull, Key Vault Secrets User |
| `model-user` | Cognitive Services User, Cognitive Services OpenAI User |
| `retrieval-reader` | Search Index Data Reader, Storage Blob Data Reader |
| `conversation-store` | Cosmos DB Built-in Data Contributor |
| `blob-delegator` | Storage Blob Data Reader, Storage Blob Delegator |
| `ingestion-writer` | Search Index Data Contributor, Storage Blob Data Contributor |

The default reference application uses them as follows:

| Component | Profiles |
| --- | --- |
| `ui` | `blob-delegator` |
| `orchestrator` | `model-user`, `retrieval-reader`, `conversation-store` |
| `ingestion` | `model-user`, `conversation-store`, `ingestion-writer` |

## Reading platform outputs

Every component receives `APP_CONFIG_ENDPOINT`. From App Configuration (label
`agent-lz`), read `AGENTLZ_PLATFORM_OUTPUTS` to discover the Foundry project
endpoint, Search, Storage, Cosmos DB, and other landing-zone resources. Your
own `settings` are published under the same label. Authenticate with the
component's managed identity.

## Samples

The Agent Landing Zone repository ships two minimal samples in
[`samples/custom-app/`](https://github.com/Azure/agent-landing-zone/tree/main/samples/custom-app):

| Folder | Hosting | What it does |
| --- | --- | --- |
| `containerapp/` | Azure Container Apps | Exposes `GET /health` and `GET /`, which returns the platform outputs. |
| `hosted/` | Microsoft Foundry hosted agent | Answers the responses protocol using the Foundry project endpoint (profile `model-user`). |

## Deploy your application

1. Copy a sample folder into your own repository and replace each component
   `source.commit` with the commit you deploy. The all-zero value is a
   placeholder and is rejected at deploy time.
2. Validate the definition from the Agent Landing Zone repository root:

    ```bash
    python -m config.appdefinition --validate <folder>
    ```

3. In a new azd environment, point the platform at your definition and deploy:

    ```bash
    azd env new my-custom-app
    azd env set AGENTLZ_APP_DEFINITION <folder>
    azd up
    ```

    When `AGENTLZ_APP_DEFINITION` is not set, the platform uses the default
    `app-definition.json` (the reference application).

During `azd deploy`, the `predeploy` hook validates the definition, checks
network prerequisites, and deploys each component: `containerapp` components
through `azd deploy`, and `azure.ai.agent` components through
`azd deploy <name>` followed by an `azd ai agent invoke` smoke test.

## Rules

- No lifecycle hooks in component `azure.yaml` files.
- No remote URLs: components are referenced by relative `path` and pinned
  `source`.
- No role names: request permissions only through capability profiles.
- Setting keys must not use the reserved `AGENTLZ_` prefix.
- With network isolation enabled, the same build prerequisites apply as for
  the reference application. See [Network isolation](network-isolation.md).
